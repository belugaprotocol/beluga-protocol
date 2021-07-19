pragma solidity 0.5.16;

interface ISplitter {
    function splitPenalty(address _pool, uint256 _amount) external;
}