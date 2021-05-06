pragma solidity 0.5.16;

interface IStakingRewards {
    function getReward() external;
    function stake(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function exit() external;
    function notifyRewardAmount(uint256 _reward) external;
    function balanceOf(address) external view returns (uint256);
}