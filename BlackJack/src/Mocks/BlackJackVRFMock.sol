pragma solidity 0.8.25;
// SPDX-License-Identifier: MIT

import {Test, console} from "forge-std/Test.sol";

contract BlackJackVRFMock is Test {
    uint256[] public randomWords;
    uint256 public lastRequestId;

    function getChainlinkDataFeedLatestAnswer() public pure returns (int256) {
        /**
         * Network: Sepolia
         * Aggregator: ETH/USD
         * Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
         */
        int256 answer = 3000 * 10 ** 8;
        return answer;
    }

    function requestRandomWords(uint32 numWords) external returns (uint256) {
        uint256 newRequestId =
            33838203147020581521695714875145155866072526428617268684953669234682684383888 + numWords * 123;
        for (uint256 i = 0; i < numWords; i++) {
            randomWords.push(844588237001536610969743867305631113212400060182078454427040534666432216 + i*123);
            if (i%2 == 0) {
                randomWords[i] -= i*13;
            }
        }
        lastRequestId = newRequestId;
        return newRequestId;
    }

    function getRequestStatus(uint256) external view returns (bool, uint256[] memory) {
        return (true, randomWords);
    }
}
