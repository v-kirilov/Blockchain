// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

contract UniswapV3FactoryMock {
    uint256 public pool = 0;

    function getPool(address, address, uint24) public view returns (address) {
        if (pool == 0) {
            return address(0);
        } else if (pool == 1) {
            return address(1);
        } else {
            return 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        }
    }

    function setPool(uint256 _pool) external {
        pool = _pool;
    }
}
