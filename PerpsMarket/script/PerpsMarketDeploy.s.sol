
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PerpsMarket} from "../src/PerpsMarket.sol";

contract PerpsMarketDeploy is Script {
    PerpsMarket public perpsMarket;
    address public feeCollector =    0x2B75032D92C780f13Fc0B90d8f649C2e2981994d;
    address public campaignAddress = 0xA6829D9C25CAcbFbCE92B53b85c7171dd7439450;
    address public feePrizeToken =   0x63486d0a5d1CCae7a8EC7EE02D4e581E8604e872;
    address public vPriceFeedAddress = 0x0D7219c29f0212c1a0f19a4Efefa1aa0e59843c2;

    // constructor(address _feeCollector, address _campaignAddress, address _feePrizeToken, address _priceFeed)
     function setUp() public {}
    function run() external {
        vm.startBroadcast();
        perpsMarket = new PerpsMarket(feeCollector, campaignAddress,feePrizeToken,address(vPriceFeedAddress));

        //perpsMarket = new PerpsMarket(feeCollector, campaignAddress, feePrizeToken, priceFeed);
        vm.stopBroadcast();
    }
}
// source .env
//forge script --chain sepolia script/PerpsMarketDeploy.s.sol:PerpsMarketDeploy --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --interactives 1

