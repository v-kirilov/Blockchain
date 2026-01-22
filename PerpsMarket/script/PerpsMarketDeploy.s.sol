
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PerpsMarket} from "../src/PerpsMarket.sol";

contract PerpsMarketDeploy is Script {
    PerpsMarket public perpsMarket;
    address public feeCollector =    0x2B75032D92C780f13Fc0B90d8f649C2e2981994d;
    address public campaignAddress = 0x281267e0998a1Bb3f91ec0d9dFaae3fc98D65179;
    address public feePrizeToken =   0x63486d0a5d1CCae7a8EC7EE02D4e581E8604e872;
    address public priceFeed =       0x694AA1769357215DE4FAC081bf1f309aDC325306;
    
     function setUp() public {}
    function run() external {
        vm.startBroadcast();
        perpsMarket = new PerpsMarket(feeCollector, campaignAddress, feePrizeToken, priceFeed);
        vm.stopBroadcast();
    }
}
//forge script --chain sepolia script/PerpsMarketDeploy.s.sol:PerpsMarketDeploy --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --interactives 1
// constructor(address _feeCollector, address _campaignAddress, address _feePrizeToken, address _priceFeed)

// Deployed at 0x77A2fB679344a891f010a6c419816035D27Dc389