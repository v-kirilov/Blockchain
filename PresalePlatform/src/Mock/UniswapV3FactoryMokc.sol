// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

contract UniswapV3FactoryMock {
    function getPool(address , address, uint24) public pure returns (address) {
        return 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    }
}