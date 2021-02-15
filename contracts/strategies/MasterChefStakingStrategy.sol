pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IVault.sol";
import "./BaseUpgradeableStrategy.sol";
import "./IMasterchef.sol";

/// @title Masterchef Staking Strategy Implementation
/// @author Chainvisions
/// @notice Proxied strategy for any Masterchef contract that uses Pancakeswap's
/// staking code.

contract MasterchefStakingImplementation is IStrategy, BaseUpgradeableStrategy {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bytes32 internal constant _UNDERLYING_OUTPUT_SLOT = 0xe5ec90f1495b7ce7f706cf9f1a2c72320e03eab1fb8db63b336a6df55f86ce59;

    constructor() public BaseUpgradeableStrategy() {
        assert(_UNDERLYING_OUTPUT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.underlyingOutput")) - 1));
    }

    function initializeStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _underlyingOutput,
        address _stakingContract
    )
    public initializer {
        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _stakingContract,
            _underlying,
            false, // Unused
            1e18, // Unused
            12 hours
        );
        setUnderlyingOutput(_underlyingOutput);
    }

    function depositArbCheck() public view returns(bool) {
        return true;
    }

    function unsalvagableTokens(address token) public view returns (bool) {
        return (token == underlyingOutput() || token == underlying());
    }

    /*
    * Performs an emergency exit from the farming contract and
    * pauses the strategy.
    */
    function emergencyExit() public onlyGovernance {
        IMasterchef(rewardPool()).emergencyWithdraw(0);
        // We send the underlying output back to the controller
        // due to emergency withdrawals not causing a burn.
        IERC20(underlyingOutput()).transfer(controller(), IERC20(underlyingOutput()).balanceOf(address(this)));
        _setPausedInvesting(true);
    }

    /*
    * Re-enables investing into the strategy contract.
    */
    function continueInvesting() public onlyGovernance {
        _setPausedInvesting(false);
    }

    function investAllUnderlying() internal onlyNotPausedInvesting {
        if(IERC20(underlying()).balanceOf(address(this)) > 0) {
            IERC20(underlying()).approve(rewardPool(), 0);
            IERC20(underlying()).approve(rewardPool(), IERC20(underlying()).balanceOf(address(this)));
            IMasterchef(rewardPool()).enterStaking(IERC20(underlying()).balanceOf(address(this)));
        }
    }

    /*
    * Collects fees for BELUGA stakers.
    */
    function _collectFees() internal {
        notifyProfitInRewardToken(IERC20(underlying()).balanceOf(address(this)));
    }

    /*
    * Withdraws all of the underlying to the vault. This is used in the case
    * of a problem with the strategy or a bug that compromises the safety of the
    * vault's users.
    */
    function withdrawAllToVault() public restricted {
        uint256 former = IERC20(underlying()).balanceOf(address(this));
        if(rewardPool() != address(0)) {
            (uint256 balanceInContract, ) = IMasterchef(rewardPool()).userInfo(0, address(this));
            IMasterchef(rewardPool()).leaveStaking(balanceInContract);
        }
        _collectFees();
        IERC20(underlying()).safeTransfer(vault(), IERC20(underlying()).balanceOf(address(this)));
    }

    /*
    * Withdraws `amount` of the underlying to the vault.
    */
    function withdrawToVault(uint256 amount) public restricted {
        // Typically there wouldn't be any amount here
        // however, it is possible because of the emergencyExit
        if(amount > IERC20(underlying()).balanceOf(address(this))){
            // While we have the check above, we still using SafeMath below
            // for the peace of mind (in case something gets changed in between)
            uint256 needToWithdraw = amount.sub(IERC20(underlying()).balanceOf(address(this)));
            (uint256 balanceInContract, ) = IMasterchef(rewardPool()).userInfo(0, address(this));
            IMasterchef(rewardPool()).leaveStaking(Math.min(balanceInContract, needToWithdraw));
        }

        IERC20(underlying()).safeTransfer(vault(), amount);
    }

    /*
    * Current amount of underlying invested.
    */
    function investedUnderlyingBalance() external view returns (uint256) {
        if (rewardPool() == address(0)) {
            return IERC20(underlying()).balanceOf(address(this));
        }

        (uint256 _amount, ) = IMasterchef(rewardPool()).userInfo(0, address(this));
        return _amount.add(IERC20(underlying()).balanceOf(address(this)));
    }

    /*
    * Transfers out tokens that the contract is holding. One thing to note
    * is that this contract exposes a list of tokens that cannot be salvaged. 
    * This is to ensure that a malicious admin cannot steal from the vault users.
    */
    function salvage(address recipient, address token, uint256 amount) external restricted {
        require(!unsalvagableTokens(token), "Strategy: Unsalvagable token");
        IERC20(token).transfer(recipient, amount);
    }

    /*
    * Harvests yields generated and reinvests into the underlying. This
    * function call will fail if deposits are paused.
    */
    function doHardWork() external onlyNotPausedInvesting restricted {
        IMasterchef(rewardPool()).enterStaking(0);
        _collectFees();
        investAllUnderlying();
    }

    function setUnderlyingOutput(address _output) internal {
        return setAddress(_UNDERLYING_OUTPUT_SLOT, _output);
    }

    function underlyingOutput() public view returns (string) {
        return getAddress(_UNDERLYING_OUTPUT_SLOT);
    }

    function finalizeUpgrade() external onlyGovernance {
        _finalizeUpgrade();
  }

}