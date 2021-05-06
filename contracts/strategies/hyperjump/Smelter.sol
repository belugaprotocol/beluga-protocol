// SPDX-License-Identifier: None
// Copyright (c) Chainvisions, 2021 - all rights reserved
pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "../../interfaces/IVault.sol";

/// @title Thugs Token Smelter
/// @author Chainvisions
/// @notice Smelts Thugs.fi tokens and automatically invests into bALLOY

contract HyperSmelter is Ownable {
    using SafeERC20 for IERC20;

    // Target vault to invest in
    address public targetVault;
    // Alloy
    address public alloy;
    // Hypercity for smelting
    address public hyperCity;
    // Underlying tokens that can be burned
    address[4] public underlyingTokens;
    // Mapping for function signatures
    mapping(uint256 => string) public functionSignatures;

    constructor(address[4] memory _underlyingTokens, address _targetVault, address _alloy, address _hyperCity) public {
        targetVault = _targetVault;
        underlyingTokens = _underlyingTokens;
        alloy = _alloy;
        hyperCity = _hyperCity;
    }

    /// @notice Smelts token and invests into bALLOY.
    function smeltAndInvest(uint256 _index, uint256 _amount) public {
        address tokenToSmelt = underlyingTokens[_index];
        IERC20(tokenToSmelt).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 toSmelt = IERC20(tokenToSmelt).balanceOf(address(this));
        IERC20(tokenToSmelt).safeApprove(hyperCity, 0);
        IERC20(tokenToSmelt).safeApprove(hyperCity, toSmelt);
        (bool success, ) = hyperCity.call(abi.encodeWithSignature(functionSignatures[_index], toSmelt));
        require(success, "HyperSmelter: Smelting failed");
        uint256 alloyToInvest = IERC20(alloy).balanceOf(address(this));
        IERC20(alloy).safeApprove(targetVault, 0);
        IERC20(alloy).safeApprove(targetVault, alloyToInvest);
        IVault(targetVault).depositFor(alloyToInvest, msg.sender);
    }

    /// @notice Maps a function signature with an index, this is used for smelting.
    function mapSignature(uint256 _index, string memory _signature) public onlyOwner {
        functionSignatures[_index] = _signature;
    }

    /// @notice Allows for recovering any ERC20 token sent to the contract.
    function salvage(address _token, uint256 _amount) public onlyOwner {
        IERC20(_token).safeTransfer(owner(), _amount);
    }

}