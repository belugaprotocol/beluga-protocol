// SPDX-License-Identifier: None
// Copyright (c) Chainvisions, 2021 - all rights reserved
pragma solidity 0.5.16;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Controllable.sol";
import "../interfaces/IModule.sol";
import "../interfaces/uniswap/IUniswapV2Router02.sol";

/// @title Beluga Protocol Treasury
/// @author Chainvisions
/// @notice An implementation of a high yield treasury to be used for Beluga Protocol

contract Treasury is Controllable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // List of modules
    mapping (address => bool) public modules;

    event Payment(address indexed to, string indexed note);
    event ModuleInstalled(address indexed module, uint256 indexed timestamp);
    event ModuleUninstalled(address indexed module, uint256 indexed timestamp);
    event ModuleFunded(address indexed module, uint256 indexed amount, address indexed token);
    event ModuleDivest(address indexed module, uint256 indexed amount);
    event StrategyExecution(address indexed module, uint256 indexed timestamp);
    event TradeExecution(address indexed input, address indexed output, uint256 indexed timestamp);

    constructor(address _storage) Controllable(_storage) public {}

    /// @notice Installs a module onto the treasury system.
    function installModule(address _module) public onlyGovernance {
        modules[_module] = true;
        emit ModuleInstalled(_module, block.timestamp);
    }

    /// @notice Uninstalls a module off the treasury system.
    function uninstallModule(address _module) public onlyGovernance {
        modules[_module] = false;
        emit ModuleUninstalled(_module, block.timestamp);
    }

    /// @notice Performs a payment from the treasury to a specified recipient.
    function makePayment(address _token, uint256 _amount, address _recipient, string memory _note) public onlyGovernance {
        IERC20(_token).safeTransfer(_recipient, _amount);
        emit Payment(_recipient, _note);
    }

    /// @notice Allocates funding to a specified module and puts the
    /// allocated funds to work.
    function allocateFunding(address _token, uint256 _funds, address _module) public onlyGovernance {
        // We perform two checks to ensure
        // A. The module is installed in our system.
        // B. The module is not an EOA.
        require(modules[_module], "Treasury: Module must be installed");
        require(IModule(_module).moduleExistenceCheck(), "Treasury: Cannot allocate funding to an EOA");
        IERC20(_token).safeTransfer(_module, _funds);
        IModule(_module).invest();
        emit ModuleFunded(_module, _funds, _token);
    }

    /// @notice Divests funding from the specified module.
    function divestFunding(address _module, uint256 _amount) public onlyGovernance {
        IModule(_module).divest(_amount);
        emit ModuleDivest(_module, _amount);
    }

    /// @notice Executes the specified module's strategy to generate profit
    /// off of the allocated funds.
    function executeStrategy(address _module) public onlyGovernance {
        require(modules[_module], "Treasury: Module must be installed");
        IModule(_module).runStrategy();
        emit StrategyExecution(_module, block.timestamp);
    }

    /// @notice Executes Fan AMM trade.
    function executeTrade(address _router, uint256 _amount, address[] memory _route) public onlyGovernance {
        address tokenIn = _route[0];
        IERC20(_route[0]).approve(_router, 0);
        IERC20(_route[0]).approve(_router, IERC20(tokenIn).balanceOf(address(this)));
        IUniswapV2Router02(_router).swapExactTokensForTokens(_amount, 0, _route, address(this), now.add(600));
        emit TradeExecution(_route[0], _route[_route.length - 1], block.timestamp);
    }

}