pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IVault.sol";

/// @title BELUGA Vote Proxy
/// @author Chainvisions
/// @notice Vote proxy for BELUGA.

contract BelugaVote {
    using SafeMath for uint256;

    string public name = "BELUGA Vote";
    string public symbol = "vBELUGA";
    uint8 public decimals = 18;

    address public beluga;
    address public sBELUGA;

    constructor(address _beluga, address _sBELUGA) public {
        beluga = _beluga;
        sBELUGA = _sBELUGA;
    }

    /**
    * @dev Returns the total supply of vBELUGA (Should be same as BELUGA's supply)
    */
    function totalSupply() public view returns (uint256) {
        return IERC20(beluga).totalSupply();
    }

    /**
    * @dev Returns the total votes that `_account` holds.
    */
    function balanceOf(address _account) public view returns (uint256) {
        uint256 belugaBalance = IERC20(beluga).balanceOf(_account);
        uint256 sBELUGABalance = IVault(sBELUGA).underlyingBalanceWithInvestmentForHolder(_account);
        return belugaBalance.add(sBELUGABalance);
    }

}