// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract VPriceFeedMock {
    uint256 public Price = 5000E8; // Mocked price for testing purposes
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
    function getChainlinkDataFeedLatestAnswer() public view returns (uint256) {
        return Price; // Mocked value for testing purposes
    }

    function getDecimals()public pure returns (uint8) {
        return 8;
    }

    function setPrice(uint256 _price) public {
        Price = _price; // Allows setting a new mocked price
    }
}
