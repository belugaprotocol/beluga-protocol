pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../Controllable.sol";
import "../interfaces/uniswap/IUniswapV2Router02.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IVault.sol";
import "./IVaiVault.sol";
import "./ProfitNotifier.sol";

/// @title VAI Vault Strategy
/// @author Chainvisions
/// @notice Strategy for Venus' VAI vault.

contract VaiVaultStrategy is IStrategy, Controllable, ProfitNotifier {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    ERC20Detailed public underlying;
    address public rewardToken;
    IVaiVault public vaiVault;
    IUniswapV2Router02 public router;
    address[] public liquidationRoute;
    address public vault;
    bool paused = false;

    // Tokens that cannot be salvaged.
    mapping (address => bool) public unsalvagableTokens;

    // Used for restricting interaction with certain functions
    // to only governance, the vault or the controller.
    modifier restricted() {
        require(msg.sender == vault || msg.sender == controller()
        || msg.sender == governance(),
        "Strategy: The sender has to be the controller, governance, or vault");
        _;
    }

    // This is only used in `investAllUnderlying()`
    // The user can still freely withdraw from the strategy.
    modifier onlyNotPausedInvesting() {
        require(!paused, "Strategy: Action blocked as the strategy is in an emergency state");
        _;
    }


    constructor(
        address _storage,
        address _underlying,
        address _rewardToken,
        address _stakingContract,
        address _vault
    )
    ProfitNotifier(_storage, _underlying)
    public {
        underlying = ERC20Detailed(_underlying);
        rewardToken = _rewardToken;
        vaiVault = IVaiVault(_stakingContract);
        vault = _vault;
        unsalvagableTokens[_underlying] = true;
    }

    function depositArbCheck() public view returns(bool) {
        return true;
    }

    /*
    * Performs an emergency exit from the farming contract and
    * pauses the strategy.
    */
    function emergencyExit() public onlyGovernance {
        // VAI Vault has no native emergency withdraw function.
        (uint256 balanceInContract, ) = vaiVault.userInfo(address(this));
        vaiVault.withdraw(balanceInContract);
        paused = true;
    }

    /*s
    * Re-enables investing into the strategy contract.
    */
    function continueInvesting() public onlyGovernance {
        paused = false;
    }

    function investAllUnderlying() internal onlyNotPausedInvesting {
        if(underlying.balanceOf(address(this)) > 0) {
            underlying.approve(address(vaiVault), 0);
            underlying.approve(address(vaiVault), underlying.balanceOf(address(this)));
            vaiVault.deposit(underlying.balanceOf(address(this)));
        }
    }

    function setLiquidationRoute(address[] memory _liquidationRoute) public onlyGovernance {
        require(rewardToken == _liquidationRoute[0], "Strategy: The route must start with the reward token");
        require(address(underlying) == _liquidationRoute[(_liquidationRoute.length).sub(1)], "Strategy: The route must end with the underlying");
        liquidationRoute = _liquidationRoute;
    }

    /*
    * Sells XVS for VAI and 
    */
    function _liquidateReward() internal {
        uint256 balanceBefore = underlying.balanceOf(address(this));
        uint256 rewards = IERC20(rewardToken).balanceOf(address(this));
        if(rewards > 0) {
            IERC20(rewardToken).approve(address(router), 0);
            IERC20(rewardToken).approve(address(router), rewards);
            router.swapExactTokensForTokens(rewards, 0, liquidationRoute, address(this), now.add(600)); 
        }
        notifyProfit(balanceBefore, underlying.balanceOf(address(this)));
    }

    /*
    * Withdraws all of the underlying to the vault. This is used in the case
    * of a problem with the strategy or a bug that compromises the safety of the
    * vault's users.
    */
    function withdrawAllToVault() public restricted {
        uint256 former = underlying.balanceOf(address(this));
        if(address(vaiVault) != address(0)) {
            (uint256 balanceInContract, ) = vaiVault.userInfo(address(this));
            vaiVault.withdraw(balanceInContract);
        }
        _liquidateReward();
        IERC20(underlying).safeTransfer(vault, underlying.balanceOf(address(this)));
    }

    /*
    * Withdraws `amount` of the underlying to the vault.
    */
    function withdrawToVault(uint256 amount) public restricted {
        // Typically there wouldn't be any amount here
        // however, it is possible because of the emergencyExit
        if(amount > underlying.balanceOf(address(this))){
            // While we have the check above, we still using SafeMath below
            // for the peace of mind (in case something gets changed in between)
            uint256 needToWithdraw = amount.sub(underlying.balanceOf(address(this)));
            (uint256 balanceInContract, ) = vaiVault.userInfo(address(this));
            vaiVault.withdraw(Math.min(balanceInContract, needToWithdraw));
        }

        IERC20(underlying).safeTransfer(vault, amount);
    }

    /*
    * Current amount of underlying invested.
    */
    function investedUnderlyingBalance() external view returns (uint256) {
        if (address(vaiVault) == address(0)) {
            return underlying.balanceOf(address(this));
        }

        (uint256 _amount, ) = vaiVault.userInfo(address(this));
        return _amount.add(underlying.balanceOf(address(this)));
    }

    /*
    * Transfers out tokens that the contract is holding. One thing to note
    * is that this contract exposes a list of tokens that cannot be salvaged. 
    * This is to ensure that a malicious admin cannot steal from the vault users.
    */
    function salvage(address recipient, address token, uint256 amount) external restricted {
        require(!unsalvagableTokens[token], "Strategy: Unsalvagable token");
        IERC20(token).transfer(recipient, amount);
    }

    /*
    * Harvests yields generated and reinvests into the underlying. This
    * function call will fail if deposits are paused.
    */
    function doHardWork() external onlyNotPausedInvesting restricted {
        vaiVault.claim();
        _liquidateReward();
        investAllUnderlying();
    }

}