// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {PerpsMarket} from "../src/PerpsMarket.sol";
import {VPriceFeedMock} from "./Mock/VPriceFeedMock.sol";
import {PerpCampaignFactory} from "../src/PerpPoints/PerpCampaignFactory.sol";
import {PPCampaign} from "../src/PerpPoints/PPCampaign.sol";
import {PPToken} from "../src/PerpPoints/PPToken.sol";

contract PerpsMarketTest is Test {
    error NotPossible();
    error UserBlackListed();
    error NoETHProvided();
    error LeverageExceded();
    error PositionNotExisting();
    error PositionAmountIsTooSmall();
    error NoProfit();
    error TransferFailed();
    error ZeroAddress();
    PerpsMarket public perpsMarket;
    PerpCampaignFactory public ppFactory;
    PPCampaign public ppCampaign;
    PPToken public ppToken;
    VPriceFeedMock public vPriceFeedMock;
    address public alice = makeAddr("alice");
    address public factoryMan = makeAddr("factoryMan");
    address public admin = makeAddr("admin");
    address public feeCollector = makeAddr("feeCollector");
    address public bob = makeAddr("bob");
    uint256 public constant INITIAL_BALANCE = 100 ether;

        enum PositionType {
        LONG,
        SHORT
    }

    function setUp() public {
        vPriceFeedMock = new VPriceFeedMock();
        ppFactory = new PerpCampaignFactory(admin);
        vm.startPrank(admin);
        ppFactory.grantFactoryRole(factoryMan);
        ppToken = new PPToken("Perp Points Token", "PPT");
        vm.stopPrank();

        vm.prank(factoryMan);
        ppCampaign = PPCampaign(ppFactory.createPerpCampaignContract(10 days, address(ppToken), admin, block.timestamp));
        vm.startPrank(admin);
        perpsMarket = new PerpsMarket(feeCollector, address(ppCampaign),address(ppToken),address(vPriceFeedMock));
        ppCampaign.setCampaignAdmin(address(perpsMarket));
    }

        function test_Empty() public {
            console2.log(admin);
    }

    function test_openPositionRevertsNoMsgValue() public {
        vm.startPrank(alice);
        uint256 amount = 1 ether;
        vm.expectRevert(NoETHProvided.selector);
        perpsMarket.openPosition(amount, true);
    }

        function test_openPositionRevertsLessThanMinValue() public {
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);
        uint256 amount = 0.001 ether;
        vm.expectRevert(PositionAmountIsTooSmall.selector);
        perpsMarket.openPosition{value:0.001 ether}(amount, true);
    }

    function test_openPositionRevertsTooBigLeverage() public {
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);
        uint256 amount = 5 ether;
        vm.expectRevert(LeverageExceded.selector);
        perpsMarket.openPosition{value:1 ether}(amount, true);
    }

    function test_openPositionSuccess() public {
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);
        uint256 amount = 2 ether;
        //vm.expectRevert(PositionAmountIsTooSmall.selector);
        perpsMarket.openPosition{value:1 ether}(amount, true);
    }

        function test_startCampaignRevertsIfNotAdmin() public {
        vm.startPrank(bob);
        vm.expectRevert();
        perpsMarket.startCampaign();
    }

        function test_startCampaignAlreadyStarted() public {
        vm.startPrank(admin);
        perpsMarket.startCampaign();
       assertTrue(ppCampaign.hasCampaignStarted());
       console2.log(ppCampaign.hasCampaignStarted());
        vm.expectRevert();
        perpsMarket.startCampaign();
        vm.stopPrank();
    }

    function test_startCampaignSuccess() public {
        vm.startPrank(admin);
        perpsMarket.startCampaign();
        assertTrue(ppCampaign.hasCampaignStarted());
        vm.stopPrank();
    }

        function test_blackListUserSuccess() public {
        vm.startPrank(admin);
        perpsMarket.blackListUser(bob);
        assertTrue(perpsMarket.blackListedUsers(bob));
    }
}
