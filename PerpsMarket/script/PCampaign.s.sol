// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PPCampaign} from "../src/PerpPoints/PPCampaign.sol";

contract PCampaignDeploy is Script {
    PPCampaign public pPCampaign;
    uint32 public duration = 29 days;
    uint32 public campaingId = 1;
    address public prizeToken = 0x63486d0a5d1CCae7a8EC7EE02D4e581E8604e872;
    address public campaignAdmin = 0x221f314Bc31e5589F546648d3ab20b3dEB1CD8B8;
    
     function setUp() public {}

    function run() external {
        vm.startBroadcast();
        pPCampaign = new PPCampaign(duration , prizeToken, campaignAdmin);
        vm.stopBroadcast();
    }
}
// 11155111
// source .env
// forge script --chain sepolia script/PCampaign.s.sol:PCampaignDeploy --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --interactives 1
// DEPLOYED at 0x281267e0998a1Bb3f91ec0d9dFaae3fc98D65179
     
//deployed ppcampaign 0xb6fE0dc7Fc9778588eaa6812FfD791306b5430c9