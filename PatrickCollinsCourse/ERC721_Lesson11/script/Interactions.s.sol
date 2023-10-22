// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script,console} from "forge-std/Script.sol";
import {BasicNft} from "../src/BasicNft.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract MintBasicNFT is Script {
    string constant SHIBA =
        "https://ipfs.io/ipfs/QmYx6GsYAKnNzZ9A6NvEKV9nf1VaDzJrqDR23Y8YSkebLU?filename=shiba-inu.png";

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "BasicNft",
            block.chainid
        );
        mintNftOnContract(mostRecentlyDeployed);
        //mintNftOnContract(0x9eaDd843DB422f2D55c6076646e0a92c81DaC7ba);
    }

    function mintNftOnContract(address contractAddress) public {
        vm.startBroadcast();
        BasicNft(contractAddress).mintNft(SHIBA);
        vm.stopBroadcast();
    }
}
