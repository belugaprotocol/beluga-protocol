pragma solidity 0.5.16;

import "./interfaces/IController.sol";
import "./Governable.sol";

contract BatchHarvester is Governable {

    IController public controller;
    mapping(address => bool) public keepers;

    modifier onlyKeeper {
        require(keepers[msg.sender], "BatchHarvester: Not keeper");
        _;
    }

    constructor(address _store, IController _controller) public Governable(_store) {
       controller = _controller;
    }

    function doHardWork(address[] memory _vaults) public onlyKeeper {
        for(uint8 i = 0; i < _vaults.length; i++) {
            controller.doHardWork(_vaults[i]);
        }
    }

}