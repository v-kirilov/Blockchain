pragma solidity 0.8.28;
// SPDX-License-Identifier: MIT

import {AggregatorV3Interface} from "../lib/foundry-chainlink-toolkit/src/interfaces/feeds/AggregatorV3Interface.sol";

contract VPriceFeed {
    error DataFeedError();
    AggregatorV3Interface internal dataFeed;

    /**
     * Network: Sepolia
     * Aggregator: ETH/USD
     * Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
     * Decimals: 8
     */
    constructor(address _dataFeedAddress) {
        dataFeed = AggregatorV3Interface(_dataFeedAddress);
    }

    /**
     * Returns the latest answer.
     */
    function getChainlinkDataFeedLatestAnswer() public view returns (int256) {
        // prettier-ignore
        (
            /* uint80 roundID */
            ,
            int256 answer,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        if (answer == 0) {
            revert DataFeedError();
        }
        return answer;
    }

    function getDecimals()public view returns (uint8) {
        return dataFeed.decimals();
    }
}
