pragma solidity 0.5.16;

interface IBeluga {
    function mint(address _to, uint256 _amount) external;
    function renounceOwnership() external;
}