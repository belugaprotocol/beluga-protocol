pragma solidity 0.5.16;

import "./VaultProxy.sol";
import "./Vault.sol";
import "./Controllable.sol";

/// @title Vault Factory
/// @notice Simplifies the vault deployment process

contract VaultFactory is Controllable {
  address public store;
  address public impl;

  event NewVault(address vault);

  constructor(address _storage) Controllable(_storage) public {
    store = _storage;
  }

  function createVault(
    address _underlying
  ) public onlyGovernance returns(address) {
    VaultProxy proxy = new VaultProxy(impl);
    Vault(address(proxy)).initializeVault(store,
      _underlying,
      999,
      1000
    );
    emit NewVault(address(proxy));
    return address(proxy);
  }

  function changeStorage(address _storage) public onlyGovernance {
    store = _storage;
  }

  function changeImplementation(address _implementation) public onlyGovernance {
    impl = _implementation;
  }

}