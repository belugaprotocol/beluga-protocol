pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IVault.sol";
import "./Governable.sol";

/// @title Beluga Community Points
/// @author Chainvisions
/// @notice Token to reward to Beluga community contributors.

contract BelugaPoints is ERC20, ERC20Detailed, Governable {
    using SafeERC20 for IERC20;

    // Vault to stake in for bToken payouts.
    address targetVault;
    // Underlying token of BP
    address underlying;

    event Redeemed(uint256 indexed amount, address indexed to);

    constructor(address _storage, address _targetVault, address _underlying)  
    Governable(_storage) 
    ERC20Detailed("Beluga Community Points", "BP", 18) 
    public
    {
        targetVault = _targetVault;
        underlying = _underlying;
    }

    function mint(uint256 _amount) public {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
    }

    function redeem(uint256 _amount) public {
        _burn(msg.sender, _amount);
        IERC20(underlying).safeTransfer(msg.sender, _amount);
        emit Redeemed(_amount, msg.sender);
    }

    function redeemForbToken(uint256 _amount) public {
        _burn(msg.sender, _amount);
        IVault(targetVault).depositFor(_amount, msg.sender);
        emit Redeemed(_amount, msg.sender);
    }

    function setTargetVault(address _targetVault) public onlyGovernance {
        require(IVault(_targetVault).underlying() == underlying, "BP: Target vault underlying is not BP underlying");
        targetVault = _targetVault;
    }

}