// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployFundMe is Script {
    function run() external returns (FundMe) {

        //Before stratbroadcast -> Not a real tx
        HelperConfig helperConfig = new HelperConfig();

        //Since its only one property in this struct we can write it like this: , otherwise (address myAddres,address secondAddress, and so on)
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();

        //After startBroadcast Real tx
        vm.startBroadcast();
        //Mock
        FundMe fundMe = new FundMe(ethUsdPriceFeed);
        vm.stopBroadcast();
        return fundMe;
    }
}
