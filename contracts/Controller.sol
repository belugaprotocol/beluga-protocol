pragma solidity 0.5.16;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IController.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IVault.sol";
import "./FeeRewardForwarder.sol";
import "./Governable.sol";
import "./HardRewards.sol";

contract Controller is IController, Governable {

    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Used for notifying profit sharing rewards.
    address public feeRewardForwarder;
    // Currently unused, future variable for the treasury.
    address public treasury;

    // [Grey list]
    // An EOA can safely interact with the system no matter what.
    // If you're using Metamask, you're using an EOA.
    // Only smart contracts may be affected by this grey list.
    //
    // This contract will not be able to ban any EOA from the system
    // even if an EOA is being added to the greyList, he/she will still be able
    // to interact with the whole system as if nothing happened.
    // Only smart contracts will be affected by being added to the greyList.
    mapping (address => bool) public greyList;

    // [Harvester list]
    // This is an exclusive list of accounts that can harvest smart vault rewards.
    // The execution of harvests on Smart Vaults require a trusted address to
    // execute the transaction. 
    //
    // We implement a greylist of harvesters to allow for better extensibility and to
    // allow for more than one account to have the privilege to execute a harvest.
    mapping(address => bool) public harvesterList;

    // All vaults that we have
    mapping (address => bool) public vaults;

    // Rewards for hard work. Nullable.
    HardRewards public hardRewards;

    uint256 public profitSharingNumerator = 5;
    uint256 public constant profitSharingDenominator = 100;

    event SharePriceChangeLog(
      address indexed vault,
      address indexed strategy,
      uint256 oldSharePrice,
      uint256 newSharePrice,
      uint256 timestamp
    );

    modifier validVault(address _vault){
        require(vaults[_vault], "Controller: Vault does not exist");
        _;
    }

    mapping (address => bool) public hardWorkers;

    modifier onlyHardWorkerOrGovernance() {
        require(hardWorkers[msg.sender] || (msg.sender == governance()),
        "Controller: Only hard worker can call this");
        _;
    }

    constructor(address _storage, address _feeRewardForwarder)
    Governable(_storage) public {
        require(_feeRewardForwarder != address(0), "Controller: feeRewardForwarder should not be empty");
        feeRewardForwarder = _feeRewardForwarder;
    }

    function addHardWorker(address _worker) public onlyGovernance {
      require(_worker != address(0), "Controller: _worker must be defined");
      hardWorkers[_worker] = true;
    }

    function removeHardWorker(address _worker) public onlyGovernance {
      require(_worker != address(0), "Controller: _worker must be defined");
      hardWorkers[_worker] = false;
    }

    function hasVault(address _vault) external returns (bool) {
      return vaults[_vault];
    }

    // Only smart contracts will be affected by the greyList.
    function addToGreyList(address _target) public onlyGovernance {
        greyList[_target] = true;
    }

    function removeFromGreyList(address _target) public onlyGovernance {
        greyList[_target] = false;
    }

    function setFeeRewardForwarder(address _feeRewardForwarder) public onlyGovernance {
      require(_feeRewardForwarder != address(0), "Controller: New reward forwarder should not be empty");
      feeRewardForwarder = _feeRewardForwarder;
    }

    function setProfitSharingNumerator(uint256 _profitSharingNumerator) public onlyGovernance {
        require(_profitSharingNumerator < profitSharingDenominator, "Controller: profitSharingNumerator cannot go over the set denominator");
        profitSharingNumerator = _profitSharingNumerator;
    }

    function addVaultAndStrategy(address _vault, address _strategy) external onlyGovernance {
        require(_vault != address(0), "Controller: New vault shouldn't be empty");
        require(!vaults[_vault], "Controller: Vault already exists");
        require(_strategy != address(0), "Controller: New strategy shouldn't be empty");

        vaults[_vault] = true;
        // No need to protect against sandwich, because there will be no call to withdrawAll
        // as the vault and strategy is brand new
        IVault(_vault).setStrategy(_strategy);
    }

    function getPricePerFullShare(address _vault) public view returns(uint256) {
        return IVault(_vault).getPricePerFullShare();
    }

    function doHardWork(address _vault) external 
    onlyHardWorkerOrGovernance 
    validVault(_vault) {
        uint256 oldSharePrice = IVault(_vault).getPricePerFullShare();
        IVault(_vault).doHardWork();
        if (address(hardRewards) != address(0)) {
            // Rewards are an option now
            hardRewards.rewardMe(msg.sender, _vault);
        }
        emit SharePriceChangeLog(
          _vault,
          IVault(_vault).strategy(),
          oldSharePrice,
          IVault(_vault).getPricePerFullShare(),
          block.timestamp
        );
    }

    function withdrawAll(address _vault) external 
    onlyGovernance 
    validVault(_vault) {
        IVault(_vault).withdrawAll();
    }

    function setStrategy(
        address _vault,
        address strategy
    ) external
    onlyGovernance
    validVault(_vault) {
        IVault(_vault).setStrategy(strategy);
    }

    function setHardRewards(address _hardRewards) external onlyGovernance {
        hardRewards = HardRewards(_hardRewards);
    }

    // Transfers token in the controller contract to the governance
    function salvage(address _token, uint256 _amount) external onlyGovernance {
        IERC20(_token).safeTransfer(governance(), _amount);
    }

    function salvageStrategy(address _strategy, address _token, uint256 _amount) external onlyGovernance {
        // The strategy is responsible for maintaining the list of
        // salvagable tokens, to make sure that governance cannot come
        // in and take away the coins
        IStrategy(_strategy).salvage(governance(), _token, _amount);
    }

    function notifyFee(address underlying, uint256 fee) external {
      if (fee > 0) {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), fee);
        IERC20(underlying).safeApprove(feeRewardForwarder, 0);
        IERC20(underlying).safeApprove(feeRewardForwarder, fee);
        FeeRewardForwarder(feeRewardForwarder).poolNotifyFixedTarget(underlying, fee);
      }
    }
}