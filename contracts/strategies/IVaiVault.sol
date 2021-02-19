pragma solidity 0.5.16;

interface IVaiVault {
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function claim() external;
    function userInfo(address _user) external view returns(uint256, uint256);
}