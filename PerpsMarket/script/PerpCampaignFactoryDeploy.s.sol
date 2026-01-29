// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PerpCampaignFactory} from "../src/PerpPoints/PerpCampaignFactory.sol";

contract DeployPerpCampaignFactory is Script {
    PerpCampaignFactory public perpCampaignFactory;
    address public admin = 0x2B75032D92C780f13Fc0B90d8f649C2e2981994d;
    
     function setUp() public {}

    function run() external {
        vm.startBroadcast();
        perpCampaignFactory = new PerpCampaignFactory(admin);
        vm.stopBroadcast();
    }
}
// 11155111
// source .env
// forge script --chain sepolia script/PerpCampaignFactoryDeploy.s.sol:DeployPerpCampaignFactory --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --interactives 1
// DEPLOYED at 0x281267e0998a1Bb3f91ec0d9dFaae3fc98D65179
     
//deployed ppcampaign 0x2B75032D92C780f13Fc0B90d8f649C2e2981994d