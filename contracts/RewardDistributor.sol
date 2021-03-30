pragma solidity 0.5.16;

interface IRewardPool {
    function notifyRewardAmount(uint256 _rewards) external;
}

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./Governable.sol";

/// @title Beluga Reward Distributor
/// @author Chainvisions
/// @notice Contract that allows for injecting BELUGA into pools without
/// relying on trusting the governance EOA.

contract RewardDistributor is Governable {
    using SafeERC20 for IERC20;
    
    address beluga;

    constructor(address _store, address _beluga) public Governable(_store) {
        beluga = _beluga;
    }

    function inject(address _pool, uint256 _amount) public onlyGovernance {
        IERC20(beluga).safeTransfer(_pool, _amount);
        IRewardPool(_pool).notifyRewardAmount(_amount);
    }

    function salvage(address _token, uint256 _amount) public onlyGovernance {
        require(_token != beluga, "RewardDistributor: Token cannot be BELUGA");
        IERC20(_token).safeTransfer(governance(), _amount);
    }

}