// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {PerpsMarket} from "../src/PerpsMarket.sol";
import {PerpCampaignFactory} from "../src/PerpPoints/PerpCampaignFactory.sol";
import {PPCampaign} from "../src/PerpPoints/PPCampaign.sol";
import {PPToken} from "../src/PerpPoints/PPToken.sol";

contract PerpsMarketTest is Test {
    PerpsMarket public perpsMarket;
    PerpCampaignFactory public ppFactory;
    PPCampaign public ppCampaign;
    PPToken public ppToken;
    address public alice = makeAddr("alice");
    address public factoryMan = makeAddr("factoryMan");
    address public admin = makeAddr("admin");
    address public feeCollector = makeAddr("feeCollector");
    address public bob = makeAddr("bob");
    uint256 public constant INITIAL_BALANCE = 100 ether;

    function setUp() public {
        ppFactory = new PerpCampaignFactory(admin);
        vm.startPrank(admin);
        ppFactory.grantFactoryRole(factoryMan);
        ppToken = new PPToken("Perp Points Token", "PPT");
        vm.stopPrank();

        vm.prank(factoryMan);
        ppCampaign = PPCampaign(ppFactory.createPerpCampaignContract(10 days, address(ppToken), admin, block.timestamp)); //! Need prize token address
        vm.prank(admin);
        perpsMarket = new PerpsMarket(feeCollector, address(ppCampaign),address(ppToken));

    }

    function test_Initialization() public {}
}
