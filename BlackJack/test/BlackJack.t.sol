// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {BlackJack} from "../src/BlackJack.sol";
import {BlackJackVRFMock} from "../src/Mocks/BlackJackVRFMock.sol";
import {BUSDC} from "../src/BUSDC.sol";

contract BlackJackTest is Test {
    BlackJack public blackJack;
    BlackJackVRFMock public bjVRFMock;
    BUSDC public busdc;

    address public player;

    struct Player {
        address wallet;
        uint256 funds;
        uint256 hand;
        uint256 currentHandId;
        bool isPlayingHand;
    }

    function setUp() public {
        bjVRFMock = new BlackJackVRFMock();
        busdc = new BUSDC("BlackJack USDC", "BUSDC");
        blackJack = new BlackJack(address(busdc), address(bjVRFMock), address(bjVRFMock));
        busdc.setBJaddress(address(blackJack));
        player = address(0x123);
        vm.deal(player, 1 ether);
    }

    function registerPlayer() public {
        vm.prank(player);
        blackJack.registerPlayer{value: 1 ether}();
    }

    function testregisterPlayerRevertsWhenNoFundsAreSent() public {
        vm.prank(player);
        vm.expectRevert("No funds sent");
        blackJack.registerPlayer{value: 0 ether}();
    }

    function testregisterPlayerRevertsWhenIsAlreadyRegistered() public {
        vm.startPrank(player);
        blackJack.registerPlayer{value: 0.5 ether}();
        vm.expectRevert("Registered already");
        blackJack.registerPlayer{value: 0.5 ether}();
        vm.stopPrank();
    }

    function mintToBJContract() public {
        busdc.mint(address(blackJack), 10000e18);
    }

    function testRegisterPlayer() public {
        vm.prank(player);
        blackJack.registerPlayer{value: 1 ether}();

        uint256 playerFunds = busdc.balanceOf(player);
        assertEq(playerFunds, 3000e18);
        console.log("Player funds: ", playerFunds);
        console.log("Player eth balance: ", player.balance);
    }

    function testwithdrawFunds() public {
        console.log("Player ETH balance before withdraw: ", player.balance);

        registerPlayer();
        (, uint256 funds,) = blackJack.getPlayerStats(player);
        console.log("Player BUSDC funds: ", funds / 1e18);

        vm.prank(player);
        blackJack.withdrawFunds(1000e18);
        uint256 playerFunds = busdc.balanceOf(player);
        assertEq(playerFunds, 2000e18);
        console.log("Player BUSDC funds: ", playerFunds / 1e18);
        console.log("Player ETH balance after withdraw: ", player.balance);
    }

    function testEnterBetRevertsWithInsufficientDealerFunds() public {
        uint256 bet = 1000e18;
        registerPlayer();
        vm.startPrank(player);

        busdc.approve(address(blackJack), bet);
        vm.expectRevert("Insufficient dealer funds");
        uint256 handId = blackJack.enterBet(bet);

        vm.stopPrank();
    }

    function testEnterBetRevertsWithNotAllowed() public {
        uint256 bet = 1000e18;

        testEnterBetSuccess();
        vm.startPrank(player);
        vm.expectRevert("Not allowed");
        uint256 handId = blackJack.enterBet(bet);

        vm.stopPrank();
    }

    function testRequestRandomWords() public {
        vm.prank(address(blackJack));
        uint256 newRequestId = bjVRFMock.requestRandomWords(2);
        console.log("New Request ID: ", newRequestId);
    }

    function testEnterBetSuccess() public {
        uint256 bet = 1000e18;
        mintToBJContract();
        registerPlayer();
        vm.startPrank(player);
        busdc.approve(address(blackJack), bet);
        uint256 handId = blackJack.enterBet(bet);

        uint256 dealerFunds = busdc.balanceOf(address(blackJack));
        assertEq(dealerFunds, 10000e18 + bet);
        vm.stopPrank();
        console.log("Hand ID: ", handId);
    }

    function testPlaceBetAndGetHandSuccess() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();
        vm.startPrank(player);
        busdc.approve(address(blackJack), bet);
        uint256 handId = blackJack.enterBet(bet);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        vm.stopPrank();
        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));
    }

    function testgetHandRevertsWithHandDealtAlready() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();
        vm.startPrank(player);
        busdc.approve(address(blackJack), bet);
        uint256 handId = blackJack.enterBet(bet);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);
        vm.expectRevert("Hand dealt already");
        (int256 playerHand2, int256 dealerHand2) = blackJack.getHand(handId);

        vm.stopPrank();
    }

    function testFinishBetSuccess() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();
        vm.startPrank(player);
        busdc.approve(address(blackJack), bet);
        uint256 handId = blackJack.enterBet(bet);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        string memory result = blackJack.finishBet(handId);

        console.log("Result: ", result);

        uint256 playerFunds = busdc.balanceOf(player);
        assertEq(playerFunds, 3000e18);
        vm.stopPrank();
    }
}
