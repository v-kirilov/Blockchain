// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {PerpsMarket} from "../src/PerpsMarket.sol";
import {PerpCampaignFactory} from "../src/PerpPoints/PerpCampaignFactory.sol";
import {PPCampaign} from "../src/PerpPoints/PPCampaign.sol";

contract PerpsMarketTest is Test {
    PerpsMarket public perpsMarket;
    PerpCampaignFactory public ppFactory;
    PPCampaign public ppCampaign;
    address public alice = makeAddr("alice");
    address public factoryMan = makeAddr("factoryMan");
    address public admin = makeAddr("admin");
    address public feeCollector = makeAddr("feeCollector");
    address public bob = makeAddr("bob");
    uint256 public constant INITIAL_BALANCE = 100 ether;

    function setUp() public {
        ppFactory = new PerpCampaignFactory(admin);
        vm.prank(admin);
        ppFactory.grantFactoryRole(factoryMan);

        vm.prank(factoryMan);
        ppCampaign = PPCampaign(ppFactory.createPerpCampaignContract(10 days, address(0), admin, block.timestamp)) ;
        //perpsMarket = new PerpsMarket();

        // Setup test accounts with initial balance
        vm.deal(alice, INITIAL_BALANCE);
        vm.deal(bob, INITIAL_BALANCE);
    }

    function test_Initialization() public {}
}
