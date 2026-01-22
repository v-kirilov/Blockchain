// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PPToken} from "../src/PerpPoints/PPToken.sol";

contract PPTokenDeploy is Script {
    PPToken public ppToken;
    
     function setUp() public {}

    function run() external {
        vm.startBroadcast();
        ppToken = new PPToken("Perp Points Token", "PPT");
        vm.stopBroadcast();
    }
}
// 11155111
// source .env
// forge script --chain sepolia script/PPTokenDeploy.s.sol:PPTokenDeploy --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --interactives 1
// DEPLOYED at 0x63486d0a5d1CCae7a8EC7EE02D4e581E8604e872

