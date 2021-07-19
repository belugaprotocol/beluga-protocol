pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IRewardPool.sol";
import "./interfaces/uniswap/IUniswapV2Router02.sol";
import "./Governable.sol";

contract FeeRewardForwarder is Governable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Tokens for predefined routes.
  address public constant beluga = address(0x181dE8C57C4F25eBA9Fd27757BBd11Cc66a55d31);
  address public constant cake = address(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
  address public constant wbnb = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
  address public constant busd = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
  address public constant wings = address(0x0487b824c8261462F88940f97053E65bDb498446);
  address public constant fts = address(0x4437743ac02957068995c48E08465E0EE1769fBE);
  address public constant stbb = address(0xE1316066af35fbfF54f870eA6d1468255602a696);

  // Routers for predefined routes.
  address public constant pancakeRouter = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
  address public constant jetswapRouter = address(0xBe65b8f75B9F20f4C522e0067a3887FADa714800);

  mapping(address => mapping (address => address[])) public routes;
  mapping(address => mapping(address => address)) public targetRouter;

  // The targeted reward token to convert everything to
  address public targetToken;
  address public profitSharingPool;

  event TokenPoolSet(address token, address pool);

  constructor(address _storage) public Governable(_storage) {
    // Predefined routes
    routes[cake][wbnb] = [cake, wbnb];
    routes[wings][wbnb] = [wings, wbnb];
    routes[fts][wbnb] = [fts, wbnb];
    routes[stbb][wbnb] = [stbb, wbnb];
    // Predefined routers
    targetRouter[cake][wbnb] = pancakeRouter;
    targetRouter[wings][wbnb] = jetswapRouter;
    targetRouter[fts][wbnb] = pancakeRouter;
    targetRouter[stbb][wbnb] = pancakeRouter;
  }

  /*
  *   Set the pool that will receive the reward token
  *   based on the address of the reward Token
  */
  function setTokenPool(address _pool) public onlyGovernance {
    targetToken = IRewardPool(_pool).rewardToken();
    profitSharingPool = _pool;
    emit TokenPoolSet(targetToken, _pool);
  }

  /**
  * Sets the path for swapping tokens to the to address
  * The to address is not validated to match the targetToken,
  * so that we could first update the paths, and then,
  * set the new target
  */
  function setConversionPath(address from, address to, address[] memory _route)
  public onlyGovernance {

    routes[from][to] = _route;
  }

  function setConversionRouter(address _from, address _to, address _router)
  public onlyGovernance {
    require(_router != address(0), "FeeRewardForwarder: The router cannot be empty");
    targetRouter[_from][_to] = _router;
  }

  // Transfers the funds from the msg.sender to the pool
  // under normal circumstances, msg.sender is the strategy
  function poolNotifyFixedTarget(address _token, uint256 _amount) external {
    if (targetToken == address(0)) {
      return; // a No-op if target pool is not set yet
    }
    if (_token == targetToken) {
      // This is already the right token
      IERC20(_token).safeTransferFrom(msg.sender, profitSharingPool, _amount);
      IRewardPool(profitSharingPool).notifyRewardAmount(_amount);
    } else {
      // We need to convert
      if (routes[_token][targetToken].length > 1) {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 balanceToSwap = IERC20(_token).balanceOf(address(this));
        address swapRouter = targetRouter[_token][targetToken];

        IERC20(_token).safeApprove(swapRouter, 0);
        IERC20(_token).safeApprove(swapRouter, balanceToSwap);

        IUniswapV2Router02(swapRouter).swapExactTokensForTokens(
          balanceToSwap,
          1, // We will accept any amount
          routes[_token][targetToken],
          address(this),
          block.timestamp
        );
        // Now we can send this token forward
        uint256 convertedRewardAmount = IERC20(targetToken).balanceOf(address(this));
        IERC20(targetToken).safeTransfer(profitSharingPool, convertedRewardAmount);
        IRewardPool(profitSharingPool).notifyRewardAmount(convertedRewardAmount);
      }
      // Else the route does not exist for this token
      // do not take any fees - leave them in the controller
    }
  }
}