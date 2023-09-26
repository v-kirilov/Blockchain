//Fund
//Withdraw

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script,console} from "forge-std/Script.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";
import {FundMe} from "../src/FundMe.sol";

contract FundFundMe is Script {
    uint256 constant SEND_VALUE = 0.01 ether;

    function fundFundMe(address mostRecentlyDeployd)  public{
        vm.startBroadcast();
        FundMe(payable(mostRecentlyDeployd)).fund{value:SEND_VALUE}();
        vm.stopBroadcast();
        console.log("Funded FundMe with %s",SEND_VALUE);
    }

    function run() external {
        address mostRecentlyDeployd = DevOpsTools.get_most_recent_deployment(
            "FundMe",
            block.chainid
        );
        fundFundMe(mostRecentlyDeployd);
    }
}

contract WithdrawFundMe is Script {
     function withdrawFundMe(address mostRecentlyDeployd)  public{
        vm.startBroadcast();
        FundMe(payable(mostRecentlyDeployd)).withdraw();
        vm.stopBroadcast();
        console.log("Withdraw FundMe balance!");
    }

    function run() external {
        address mostRecentlyDeployd = DevOpsTools.get_most_recent_deployment(
            "FundMe",
            block.chainid
        );
        withdrawFundMe(mostRecentlyDeployd);
    }
}
