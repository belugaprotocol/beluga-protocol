pragma solidity 0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "./interfaces/IFrictionVault.sol";
import "../interfaces/IController.sol";
import "../interfaces/IUpgradeSource.sol";
import "../ControllableInit.sol";
import "./FrictionVaultStorage.sol";

/// @title Friction Vault
/// @notice Strategy-less, frictionless yield generation through Beluga Vaults.
/// @dev This contract is built for RFI clones and is also subject to a 0.5% withdrawal fee.

contract FrictionVault is ERC20, ERC20Detailed, IFrictionVault, IUpgradeSource, ControllableInit, FrictionVaultStorage {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  event Withdraw(address indexed beneficiary, uint256 amount);
  event Deposit(address indexed beneficiary, uint256 amount);
  event Invest(uint256 amount);
  event UpgradeAnnounced(address newImplementation);

  constructor() public {
  }

  // The function is named differently to not cause an inheritance clash in truffle and to allow for tests
  function initializeVault(address _storage,
    address _underlying
  ) public initializer {

    ERC20Detailed.initialize(
      string(abi.encodePacked("BELUGA Friction ", ERC20Detailed(_underlying).symbol())),
      string(abi.encodePacked("bf", ERC20Detailed(_underlying).symbol())),
      ERC20Detailed(_underlying).decimals()
    );
    ControllableInit.initialize(
      _storage
    );

    uint256 underlyingUnit = 10 ** uint256(ERC20Detailed(address(_underlying)).decimals());
    uint256 implementationDelay = 12 hours;
    FrictionVaultStorage.initialize(
      _underlying,
      underlyingUnit,
      implementationDelay
    );
  }

  function underlying() public view returns(address) {
    return _underlying();
  }

  function underlyingUnit() public view returns(uint256) {
    return _underlyingUnit();
  }

  function nextImplementation() public view returns(address) {
    return _nextImplementation();
  }

  function nextImplementationTimestamp() public view returns(uint256) {
    return _nextImplementationTimestamp();
  }

  function nextImplementationDelay() public view returns(uint256) {
    return _nextImplementationDelay();
  }

  function withdrawalFee() public view returns(uint256) {
      return _withdrawalFee();
  }

  // Only smart contracts will be affected by this modifier
  modifier defense() {
    require(
      (msg.sender == tx.origin) ||                // If it is a normal user and not smart contract,
                                                  // then the requirement will pass
      IController(controller()).greyList(msg.sender), // If it is a smart contract, then
      "Vault: This smart contract has been greylisted"  // make sure that it is not on our greyList.
    );
    _;
  }

  /*
  * Returns the cash balance across all users in this contract.
  */
  function underlyingBalanceInVault() view public returns (uint256) {
    return IERC20(underlying()).balanceOf(address(this));
  }

  function getPricePerFullShare() public view returns (uint256) {
    return totalSupply() == 0
        ? underlyingUnit()
        : underlyingUnit().mul(underlyingBalanceInVault()).div(totalSupply());
  }

  /* Get the user's share (in underlying)
  */
  function underlyingBalanceWithInvestmentForHolder(address holder) view external returns (uint256) {
    if (totalSupply() == 0) {
      return 0;
    }
    return underlyingBalanceInVault()
        .mul(balanceOf(holder))
        .div(totalSupply());
  }

  /*
  * Allows for depositing the underlying asset in exchange for shares.
  * Approval is assumed.
  */
  function deposit(uint256 amount) external defense {
    _deposit(amount, msg.sender, msg.sender);
  }

  /*
  * Allows for depositing the underlying asset in exchange for shares
  * assigned to the holder.
  * This facilitates depositing for someone else (using DepositHelper)
  */
  function depositFor(uint256 amount, address holder) public defense {
    _deposit(amount, msg.sender, holder);
  }

  function withdraw(uint256 numberOfShares) external {
    require(totalSupply() > 0, "Vault: Vault has no shares");
    require(numberOfShares > 0, "Vault: numberOfShares must be greater than 0");
    uint256 totalSupply = totalSupply();
    _burn(msg.sender, numberOfShares);

    uint256 underlyingAmountToWithdraw = underlyingBalanceInVault()
        .mul(numberOfShares)
        .div(totalSupply);
    if (underlyingAmountToWithdraw > underlyingBalanceInVault()) {
      // Recalculate to improve accuracy
      underlyingAmountToWithdraw = Math.min(underlyingBalanceInVault()
          .mul(numberOfShares)
          .div(totalSupply), underlyingBalanceInVault());
    }

    uint256 fee = underlyingAmountToWithdraw.mul(withdrawalFee()).div(1000);
    uint256 amountAfterFee = underlyingAmountToWithdraw.sub(fee);
    
    IERC20(underlying()).safeTransfer(msg.sender, amountAfterFee);
    IERC20(underlying()).safeTransfer(controller(), fee);

    // Update the withdrawal amount for the holder
    emit Withdraw(msg.sender, underlyingAmountToWithdraw);
  }

  function _deposit(uint256 amount, address sender, address beneficiary) internal {
    require(amount > 0, "Vault: Cannot deposit 0");
    require(beneficiary != address(0), "Vault: Holder must be defined");

    uint256 toMint = totalSupply() == 0
        ? amount
        : amount.mul(totalSupply()).div(underlyingBalanceInVault());
    _mint(beneficiary, toMint);

    IERC20(underlying()).safeTransferFrom(sender, address(this), amount);

    // Update the contribution amount for the beneficiary
    emit Deposit(beneficiary, amount);
  }

  /**
  * Schedules an upgrade for this vault's proxy.
  */
  function scheduleUpgrade(address impl) public onlyGovernance {
    _setNextImplementation(impl);
    _setNextImplementationTimestamp(block.timestamp.add(nextImplementationDelay()));
    emit UpgradeAnnounced(impl);
  }

  function shouldUpgrade() external view returns (bool, address) {
    return (
      nextImplementationTimestamp() != 0
        && block.timestamp > nextImplementationTimestamp()
        && nextImplementation() != address(0),
      nextImplementation()
    );
  }

  function finalizeUpgrade() external onlyGovernance {
    _setNextImplementation(address(0));
    _setNextImplementationTimestamp(0);
  }
}