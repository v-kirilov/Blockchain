// SPDX-License-Identifier: MIT

// Put it in Remix , call "setImplementation" and try it out
// Call getDataToTransact to get your data for the encodeWithSignature("setValue(uint256)",numberToUpdate)
// Than use that data to call Transact in Remix , which will call you fallback function
// and esentially call the Implementation contract which address you have specified in the "setImplementation" fnction

pragma solidity ^0.8.19;

import "../../lib/openzeppelin-contracts/contracts/proxy/Proxy.sol";

contract SmallProxy is Proxy {
    // This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function setImplementation(address newImplementation) public {
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }
    }

    function _implementation() internal view override returns (address implementationAddress) {
        assembly {
            implementationAddress := sload(_IMPLEMENTATION_SLOT)
        }
    }

    function getDataToTransact(uint256 numberToUpdate)  public pure returns(bytes memory) {
        return abi.encodeWithSignature("setValue(uint256)",numberToUpdate);
    }

    function  readStorage() public view returns(uint256 valueAtStorageSlotZero){
        assembly{
          valueAtStorageSlotZero :=  sload(0)
        }
    }

}

// SmallProxy -> Implementation A

contract ImplementationA {
    uint256 public value;

    function setValue(uint256 newValue) public {
        value = newValue;
    }
}

contract ImplementationB {
    uint256 public value;

    function setValue(uint256 newValue) public {
        value = newValue+2;
    }
}