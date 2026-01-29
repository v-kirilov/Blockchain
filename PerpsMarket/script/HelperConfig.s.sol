// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";

// ETHUSD on sepolia 0x694AA1769357215DE4FAC081bf1f309aDC325306
// my eth sepolia address 0x2B75032D92C780f13Fc0B90d8f649C2e2981994d
// ddress private coordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625; // Sepolia VRFCoordinatorV2
// endpoint url https://eth-sepolia.g.alchemy.com/v2/kXCc0f--1HJ0NTmpPgY47WjTo7vX7roO
// api key kXCc0f--1HJ0NTmpPgY47WjTo7vX7roO

contract HelperConfig is Script {
    struct NetworkConfig {
        address perpCampaignFactory;
        address perpPointsToken;
        address prizePool;
        address prizeStrategy;
        address rng;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    uint256 DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        // if (block.chainid == 1) {
        //     activeNetworkConfig = getMainnetConfig();
        // } else {
        //     activeNetworkConfig = getOrCreateAnvilConfig();
        // }
    }

    // function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
    //     return
    //         NetworkConfig({
    //             ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
    //            // ppTokenAddress: 0xYourSepoliaPPTokenAddress,
    //             // prizePool: 0xYourSepoliaPrizePoolAddress,
    //             // prizeStrategy: 0xYourSepoliaPrizeStrategyAddress,
    //             // rng: 0xYourSepoliaRNGAddress,
    //             // deployerKey: uint256(vm.envBytes32("SEPOLIA_PRIVATE_KEY"))
    //         });
    // }

}