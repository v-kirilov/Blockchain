// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract VPriceFeedMock {

    /**
     * Network: Sepolia
     * Aggregator: ETH/USD
     * Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
     * Decimals: 8
     */
    constructor() {
        
    }

    /**
     * Returns the latest answer.
     */
    function getChainlinkDataFeedLatestAnswer() public pure returns (int256) {
        return 5000E8; // Mocked value for testing purposes
    }

    function getDecimals()public pure returns (uint8) {
        return 8;
    }
}
