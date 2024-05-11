// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {BlackJack} from "../src/BlackJack.sol";
import {BUSDC} from "../src/BUSDC.sol";
import {BlackJackDataFeed} from "../src/BlackJackDataFeed.sol";
import {BlackJackVRF} from "../src/BlackJackVRF.sol";

contract Deploy is Script {
    BlackJack public blackJack;
    BUSDC public busdc;
    BlackJackDataFeed public dataFeed;
    BlackJackVRF public blackJackVRF;
    //For BlackJackDataFeed
    address private constant dataFeedAddress = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // Sepolia ETH/USD

    //For BlackJackVRF
    uint64 private s_subscriptionId = 5550; // Sepolia subscription ID  - vrf.chain.link
    address private coordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625; // Sepolia VRFCoordinatorV2
    bytes32 private keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;


    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY"); //Gotta add 0x at the start of the private key in the .env file
        vm.startBroadcast(deployerPrivateKey);

        busdc = new BUSDC("BlackJack USDC", "BUSDC");
        dataFeed = new BlackJackDataFeed(dataFeedAddress);
        blackJackVRF = new BlackJackVRF(s_subscriptionId,coordinator, keyHash);
        blackJack = new BlackJack(address(busdc), address(dataFeed), address(blackJackVRF));
        
        blackJackVRF.setBJaddress(address(blackJack));

        vm.stopBroadcast();
    }
}