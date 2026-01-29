// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {VPriceFeed} from "../src/VPriceFeed.sol";

contract VPriceFeedDeploy is Script {
    VPriceFeed public vPriceFeed;
    address public dataFeedAddress = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    
     function setUp() public {}

    function run() external {
        vm.startBroadcast();
        vPriceFeed = new VPriceFeed(dataFeedAddress);
        vm.stopBroadcast();
    }
}
// 11155111
// source .env
// forge script --chain sepolia script/VPriceFeed.s.sol:VPriceFeedDeploy --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --interactives 1
// DEPLOYED at 0x0D7219c29f0212c1a0f19a4Efefa1aa0e59843c2

