// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PPCampaign} from "../src/PerpPoints/PPCampaign.sol";
import {PerpCampaignFactory} from "../src/PerpPoints/PerpCampaignFactory.sol";
import {PerpsMarket} from "../src/PerpsMarket.sol";

contract AllDeploy is Script {
    PPCampaign public ppCampaign;
    PerpCampaignFactory public perpCampaignFactory;
    address public vPriceFeedAddress = 0x0D7219c29f0212c1a0f19a4Efefa1aa0e59843c2;
    address public admin = 0x2B75032D92C780f13Fc0B90d8f649C2e2981994d;
    PerpsMarket public perpsMarket;
    address public feeCollector =    0x2B75032D92C780f13Fc0B90d8f649C2e2981994d;
    PerpCampaignFactory public ppFactory;

    uint32 public duration = 29 days;
    address public prizeToken = 0x63486d0a5d1CCae7a8EC7EE02D4e581E8604e872;
    
     function setUp() public {}

    function run() external {
        vm.startBroadcast();

        ppCampaign = new PPCampaign(duration, prizeToken, admin);  

        perpsMarket = new PerpsMarket(feeCollector, 0xA6829D9C25CAcbFbCE92B53b85c7171dd7439450,vPriceFeedAddress,address(vPriceFeedAddress)); //0xfb1661217E723b0C83ddFe9D3b93956BA3F96320
        vm.stopBroadcast();
    }
}

// source .env
// forge script --chain sepolia script/AllDeploy.s.sol:AllDeploy --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --interactives 1
