pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/IStrategy.sol";
import "../interfaces/IProfitsharingStrategy.sol";
import "../interfaces/IVault.sol";
import "./BaseUpgradeableStrategy.sol";
import "./IStakingRewards.sol";

/// @title Profitsharing Strategy Proxy
/// @author Chainvisions
/// @notice Beluga profitsharing strategy.

contract ProfitsharingStrategy is IProfitsharingStrategy, BaseUpgradeableStrategy {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    constructor() public BaseUpgradeableStrategy() {}

    function initializeStrategy(
        address _storage,
        address _underlying,
        address _vault,
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
    }

    function depositArbCheck() public view returns(bool) {
        return true;
    }

    function unsalvagableTokens(address token) public view returns (bool) {
        return (token == underlying() || token == rewardToken());
    }

    /*
    * Performs an emergency exit from the farming contract and
    * pauses the strategy.
    */
    function emergencyExit() public onlyGovernance {
        IStakingRewards(rewardPool()).exit();
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
            IERC20(underlying()).safeApprove(rewardPool(), 0);
            IERC20(underlying()).safeApprove(rewardPool(), IERC20(underlying()).balanceOf(address(this)));
            IStakingRewards(rewardPool()).stake(IERC20(underlying()).balanceOf(address(this)));
        }
    }

    /*
    * Withdraws all of the underlying to the vault. This is used in the case
    * of a problem with the strategy or a bug that compromises the safety of the
    * vault's users.
    */
    function withdrawAllToVault() public restricted {
        if(rewardPool() != address(0)) {
            IStakingRewards(rewardPool()).exit();
        }
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
            IStakingRewards(rewardPool()).withdraw(Math.min(rewardPoolStake(), needToWithdraw));
        }

        IERC20(underlying()).safeTransfer(vault(), amount);
    }

    function refreshAutostake() external onlyNotPausedInvesting restricted {
        IStakingRewards(rewardPool()).exit();
        IERC20(underlying()).safeApprove(rewardPool(), 0);
        IERC20(underlying()).safeApprove(rewardPool(), IERC20(underlying()).balanceOf(address(this)));
        IStakingRewards(rewardPool()).stake(IERC20(underlying()).balanceOf(address(this)));
    }

    function rewardPoolStake() public view returns (uint256 stake) {
        stake = IStakingRewards(rewardPool()).balanceOf(address(this));
    }

    /*
    * Current amount of underlying invested.
    */
    function investedUnderlyingBalance() external view returns (uint256) {
        if (rewardPool() == address(0)) {
            return IERC20(underlying()).balanceOf(address(this));
        }
        return IStakingRewards(rewardPool()).balanceOf(address(this)).add(IERC20(underlying()).balanceOf(address(this)));
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
        if(rewardPoolStake() > 0) {
            IStakingRewards(rewardPool()).exit();
        }
        investAllUnderlying();
    }

    function finalizeUpgrade() external onlyGovernance {
        _finalizeUpgrade();
  }

}