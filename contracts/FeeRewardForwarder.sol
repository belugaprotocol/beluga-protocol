pragma solidity 0.5.16;

import "./Governable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./hardworkInterface/IRewardPool.sol";
import "./interfaces/uniswap/IUniswapV2Router02.sol";

contract FeeRewardForwarder is Governable {
  using SafeERC20 for IERC20;

  address constant public cake = address(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
  address constant public dot = address(0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402);
  address constant public wbnb = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
  address constant public busd = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
  address constant public ust = address(0x23396cF899Ca06c4472205fC903bDB4de249D6fC);

  mapping (address => mapping (address => address[])) public routes;

  // The targeted reward token to convert everything to
  address public targetToken;
  address public profitSharingPool;

  address public router;

  event TokenPoolSet(address token, address pool);

  constructor(address _storage, address _router) public Governable(_storage) {
    require(_router != address(0), "FeeRewardForwarder: Router not defined");
    router = _router;
    // Predefined routes
    routes[cake][busd] = [cake, wbnb, busd];
    routes[dot][busd] = [dot, wbnb, busd];
    routes[wbnb][busd] = [wbnb, busd];
    routes[ust][busd] = [yfi, weth, dai];
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
    require(from == _route[0],
      "FeeRewardForwarder: The first token of the route must be the from token");
    require(to == _route[_route.length - 1],
      "FeeRewardForwarder: The last token of the route must be the to token");
    routes[from][to] = _route;
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

        IERC20(_token).safeApprove(router, 0);
        IERC20(_token).safeApprove(router, balanceToSwap);

        IUniswapV2Router02(router).swapExactTokensForTokens(
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