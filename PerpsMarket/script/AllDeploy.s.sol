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
    address public feePrizeToken =   0x63486d0a5d1CCae7a8EC7EE02D4e581E8604e872;

    uint32 public duration = 29 days;
    address public prizeToken = 0x63486d0a5d1CCae7a8EC7EE02D4e581E8604e872;
    
     function setUp() public {}

    function run() external {
        vm.startBroadcast();

        ppCampaign = new PPCampaign(duration, prizeToken, admin);  

    //perpsMarket = new PerpsMarket(feeCollector, campaignAddress, feePrizeToken, priceFeed);
        perpsMarket = new PerpsMarket(feeCollector,address(ppCampaign)  ,feePrizeToken,address(vPriceFeedAddress)); //
        ppCampaign.setCampaignAdmin(address(perpsMarket));
        vm.stopBroadcast();
    }

}

    // Prereequisites:
    // 1. Grant CAMPAIGN_ADMIN_ROLE to PerpsMarket contract in the PPCampaign contract
    // 2. Give allowance to PerpsMarket contract in the PPToken contract for user.

// ppcampaign 0xC0b24e892529b871aA304C03B41BCdf49B45544C
// Perps 0xB21Eaa5b8B0DaAA086d37EE274c2Ef0F17bdE0f1

// source .env
// forge script --chain sepolia script/AllDeploy.s.sol:AllDeploy --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --interactives 1
