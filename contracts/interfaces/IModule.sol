pragma solidity 0.5.16;

interface IModule {
    function runStrategy() external;
    function invest() external;
    function divest(uint256 amount) external;
    function salvage(address recipient, address token, uint256 amount) external;
    // Prevents allocating funding to an EOA.
    function moduleExistenceCheck() external view returns (bool);
}