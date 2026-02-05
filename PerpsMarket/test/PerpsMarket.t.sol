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
        //  ppFactory = new PerpCampaignFactory(admin);
        vm.startPrank(admin);
        // ppFactory.grantFactoryRole(factoryMan);
        ppToken = new PPToken("Perp Points Token", "PPT");
        vm.stopPrank();

        // vm.prank(factoryMan);
        // ppCampaign = PPCampaign(ppFactory.createPerpCampaignContract(10 days, address(ppToken), admin, block.timestamp));
        vm.startPrank(admin);
        ppCampaign = new PPCampaign(10 days, address(ppToken), admin);
        perpsMarket = new PerpsMarket(feeCollector, address(ppCampaign), address(ppToken), address(vPriceFeedMock));
        ppCampaign.setCampaignAdmin(address(perpsMarket));
        vm.deal(address(perpsMarket), 100 ether);
    }

    function aliceOPpenPositionSuccess() public {
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);
        uint256 amount = 10000000000;
        perpsMarket.openPosition{value: 10000000000}(amount, true);
    }

    function test_openPositionSuccess() public {
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);

        uint256 amount = 1000000000000000;
        perpsMarket.openPosition{value: 1000000000000000}(amount, true);
    }

    function test_closeLoosingLonPosition() public {
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);

        uint256 amount = 1000000000000000;
        perpsMarket.openPosition{value: 1000000000000000}(amount, true);

        vPriceFeedMock.setPrice(4000e8);

        perpsMarket.closePosition();

        vm.stopPrank();
    }

    function test_closeWinningLonPosition() public {
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);

        uint256 amount = 1000000000000000;
        perpsMarket.openPosition{value: 1000000000000000}(amount, true);

        vPriceFeedMock.setPrice(6000e8);

        perpsMarket.closePosition();

        vm.stopPrank();
    }

    function test_closeWinningShortPosition() public {
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);

        uint256 amount = 1000000000000000;
        perpsMarket.openPosition{value: 1000000000000000}(amount, false);

        vPriceFeedMock.setPrice(4000e8);

        perpsMarket.closePosition();

        vm.stopPrank();
    }

    function test_closeWinningShortAndWithdraw() public {
        // Starting ETHPRICE is 5k
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);

        uint256 amount = 2 ether;
        perpsMarket.openPosition{value: 1 ether}(amount, false);

        vPriceFeedMock.setPrice(2500e8);
        uint256 aliceBalanceBefore = alice.balance;
        perpsMarket.closePosition();
        console2.log("Alice balance before withdraw: ", alice.balance);
        perpsMarket.withdrawProfit();
        console2.log("Alice balance after withdraw: ", alice.balance);
        vm.stopPrank();
        assert(alice.balance > aliceBalanceBefore);
    }

    function test_closeLoosingShortAndWithdraw() public {
        // Starting ETHPRICE is 5k
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);

        uint256 amount = 2 ether;
        uint256 aliceBalanceBefore = alice.balance;
        perpsMarket.openPosition{value: 1 ether}(amount, false);

        vPriceFeedMock.setPrice(6000e8);
        perpsMarket.closePosition();
        console2.log("Alice balance before withdraw: ", alice.balance);
        perpsMarket.withdrawProfit();
        console2.log("Alice balance after withdraw: ", alice.balance);
        vm.stopPrank();
        assert(alice.balance < aliceBalanceBefore);
    }

    function test_closeLoosingShortPosition() public {
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);

        uint256 amount = 1000000000000000;
        perpsMarket.openPosition{value: 1000000000000000}(amount, false);

        vPriceFeedMock.setPrice(6000e8);

        perpsMarket.closePosition();

        vm.stopPrank();
    }

    function test_closeLoosingLongPosition() public {
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);
        uint256 aliceBalanceBefore = alice.balance;

        uint256 amount = 2 ether;
        perpsMarket.openPosition{value: 1 ether}(amount, true);

        vPriceFeedMock.setPrice(3000e8);

        perpsMarket.closePosition();

        vm.stopPrank();
        assert(alice.balance < aliceBalanceBefore);
        console2.log("Alice balance before: ", aliceBalanceBefore);
        console2.log("Alice balance after: ", alice.balance);
    }

    function test_closeWinningLongAndWithdraw() public {
        // Starting ETHPRICE is 5k
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = alice.balance;
        uint256 amount = 2 ether;
        perpsMarket.openPosition{value: 1 ether}(amount, true);

        vPriceFeedMock.setPrice(7500e8);
        perpsMarket.closePosition();
        console2.log("Alice balance before withdraw: ", aliceBalanceBefore);
        perpsMarket.withdrawProfit();
        console2.log("Alice balance after withdraw: ", alice.balance);
        vm.stopPrank();
        assert(alice.balance > aliceBalanceBefore);
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
        uint256 amount = 0.000001 ether;
        vm.expectRevert(PositionAmountIsTooSmall.selector);
        perpsMarket.openPosition{value: 0.001 ether}(amount, true);
    }

    function test_openPositionRevertsTooBigLeverage() public {
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);
        uint256 amount = 5 ether;
        vm.expectRevert(LeverageExceded.selector);
        perpsMarket.openPosition{value: 1 ether}(amount, true);
    }

    function test_openWithOneX() public {
        vm.deal(alice, INITIAL_BALANCE);
        vm.startPrank(alice);
        uint256 amount = 1 ether;
        perpsMarket.openPosition{value: 1 ether}(amount, true);
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

    function test_closePositionRevertsPositionNotExisting() public {
        vm.startPrank(bob);
        vm.expectRevert(PositionNotExisting.selector);
        perpsMarket.closePosition();
    }

    // function test_closePositionRevertsNoProfit() public {
    //     aliceOPpenPositionSuccess();
    //     vm.startPrank(alice);
    //     vm.expectRevert(NoProfit.selector);
    //     perpsMarket.closePosition();
    // }

    function test_blackListedUserCannotOpenPosition() public {
        vm.startPrank(admin);
        perpsMarket.blackListUser(bob);
        vm.stopPrank();
        vm.deal(bob, INITIAL_BALANCE);
        vm.startPrank(bob);
        uint256 amount = 2 ether;
        vm.expectRevert(UserBlackListed.selector);
        perpsMarket.openPosition{value: 1 ether}(amount, true);
    }
}
