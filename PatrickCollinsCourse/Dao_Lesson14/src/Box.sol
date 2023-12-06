// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Box is Ownable(msg.sender) {
    uint256 private s_number;

    event  NumberChange(uint256 number);

    function store(uint256 newNumber) public onlyOwner  {
        s_number = newNumber;
        emit NumberChange(newNumber);
    }

    function getNumber() external view  returns (uint256) {
        return s_number;
    }
}