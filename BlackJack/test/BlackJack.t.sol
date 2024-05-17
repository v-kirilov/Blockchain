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

    uint256 constant DURATION_OF_HAND = 10 * 20; //Max of 10 blocks
    uint256 constant PUSH = 0;
    uint256 constant PLAYER_WIN = 1;
    uint256 constant DEALER_WIN = 2;

    address public winner;
    address public loser;
    address public pusher;

    struct Player {
        address wallet;
        uint256 funds;
        uint256 hand;
        uint256 currentHandId;
        bool isPlayingHand;
    }

    struct Hand {
        address player;
        uint256 id;
        uint256 dealerHand;
        bool isDealerHandSoft;
        uint256 playerHand;
        bool isPlayerHandSoft;
        bool isHandPlayedOut;
        bool isHandDealt;
        uint256 timeHandIsDealt;
        uint256 playerBet;
        bool isDouble;
    }

    function setUp() public {
        bjVRFMock = new BlackJackVRFMock();
        busdc = new BUSDC("BlackJack USDC", "BUSDC");
        blackJack = new BlackJack(address(busdc), address(bjVRFMock), address(bjVRFMock));
        busdc.setBJaddress(address(blackJack));
        winner = address(0x1);
        loser = address(0x2);
        pusher = address(0x3);
        vm.deal(winner, 1 ether);
    }

    function registerPlayer() public {
        vm.prank(winner);
        blackJack.registerPlayer{value: 1 ether}();
    }

    function testregisterPlayerRevertsWhenNoFundsAreSent() public {
        vm.prank(winner);
        vm.expectRevert("No funds sent");
        blackJack.registerPlayer{value: 0 ether}();
    }

    function testregisterPlayerRevertsWhenIsAlreadyRegistered() public {
        vm.startPrank(winner);
        blackJack.registerPlayer{value: 0.5 ether}();
        vm.expectRevert("Registered already");
        blackJack.registerPlayer{value: 0.5 ether}();
        vm.stopPrank();
    }

    function mintToBJContract() public {
        busdc.mint(address(blackJack), 10000e18);
    }

    function testRegisterPlayer() public {
        vm.prank(winner);
        blackJack.registerPlayer{value: 1 ether}();

        uint256 playerFunds = busdc.balanceOf(winner);
        assertEq(playerFunds, 3000e18);
        console.log("Player funds: ", playerFunds);
        console.log("Player eth balance: ", winner.balance);
    }

    function testwithdrawFunds() public {
        console.log("Player ETH balance before withdraw: ", winner.balance);

        registerPlayer();
        (, uint256 funds,) = blackJack.getPlayerStats(winner);
        console.log("Player BUSDC funds: ", funds / 1e18);

        vm.prank(winner);
        blackJack.withdrawFunds(1000e18);
        uint256 playerFunds = busdc.balanceOf(winner);
        assertEq(playerFunds, 2000e18);
        console.log("Player BUSDC funds: ", playerFunds / 1e18);
        console.log("Player ETH balance after withdraw: ", winner.balance);
    }

    function testEnterBetRevertsWithInsufficientDealerFunds() public {
        uint256 bet = 1000e18;
        registerPlayer();
        vm.startPrank(winner);

        busdc.approve(address(blackJack), bet);
        vm.expectRevert("Insufficient dealer funds");
        uint256 handId = blackJack.enterBet(bet);

        vm.stopPrank();
    }

    function testEnterBetRevertsWithNotAllowed() public {
        uint256 bet = 1000e18;

        testEnterBetSuccess();
        vm.startPrank(winner);
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
        vm.startPrank(winner);
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
        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);
        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(1);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        vm.stopPrank();
        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));
    }

    function testgetHandRevertsWithHandDealtAlready() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();
        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);
        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(1);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);
        vm.expectRevert("Hand dealt already");
        (int256 playerHand2, int256 dealerHand2) = blackJack.getHand(handId);

        vm.stopPrank();
    }

    function testFinishBetSuccessWithPush() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(0);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        string memory result = blackJack.finishBet(handId);

        console.log("Result: ", result);

        uint256 playerFunds = busdc.balanceOf(winner);
        uint256 dealerFunds = busdc.balanceOf(address(blackJack));
        assertEq(dealerFunds, 10000e18);
        assertEq(playerFunds, 3000e18);
        vm.stopPrank();
    }

    function testFinishBetSuccessWithPlayerWin() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(1);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        string memory result = blackJack.finishBet(handId);

        console.log("Result: ", result);

        uint256 playerFunds = busdc.balanceOf(winner);
        uint256 dealerFunds = busdc.balanceOf(address(blackJack));

        assertEq(playerFunds, 4000e18);
        assertEq(dealerFunds, 9000e18);
        vm.stopPrank();
    }

    function testFinishBetSuccessWithDealerWin() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(2);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        string memory result = blackJack.finishBet(handId);

        console.log("Result: ", result);

        uint256 playerFunds = busdc.balanceOf(winner);
        uint256 dealerFunds = busdc.balanceOf(address(blackJack));
        assertEq(playerFunds, 2000e18);
        assertEq(dealerFunds, 11000e18);
        vm.stopPrank();
    }

    function testFinishBetDealerAndPlayerGetBJ() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(3);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        string memory result = blackJack.finishBet(handId);

        console.log("Result: ", result);

        uint256 playerFunds = busdc.balanceOf(winner);
        uint256 dealerFunds = busdc.balanceOf(address(blackJack));
        assertEq(playerFunds, 3000e18);
        assertEq(dealerFunds, 10000e18);
        vm.stopPrank();
    }

        function testFinishBetDealerGetsBJ() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(4);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        string memory result = blackJack.finishBet(handId);

        console.log("Result: ", result);

        uint256 playerFunds = busdc.balanceOf(winner);
        uint256 dealerFunds = busdc.balanceOf(address(blackJack));
        assertEq(playerFunds, 2000e18);
        assertEq(dealerFunds, 11000e18);
        vm.stopPrank();
    }

            function testFinishBetPlayerGetsBJ() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(5);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        string memory result = blackJack.finishBet(handId);

        console.log("Result: ", result);

        uint256 playerFunds = busdc.balanceOf(winner);
        uint256 dealerFunds = busdc.balanceOf(address(blackJack));
        assertEq(playerFunds, 4500e18);
        assertEq(dealerFunds, 8500e18);
        vm.stopPrank();
    }

    function testDoubleRevertsWithPlayedoutHand() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(2);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        string memory result = blackJack.finishBet(handId);

        console.log("Result: ", result);

        vm.expectRevert("Hand is played out!");
        uint256 newHandId = blackJack.double(handId);

        vm.stopPrank();
    }

    function testDoubleRevertsWhenHandIsNotExisting() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = 1;

        vm.expectRevert("Hand not dealt yet!");
        uint256 newHandId = blackJack.double(handId);

        vm.stopPrank();
    }

    function testDoubleSuccess() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(2);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        busdc.approve(address(blackJack), bet);
        uint256 newHandId = blackJack.double(handId);
        console.log("New hand ID: ", newHandId);

        (,,,,,,,,,, bool isDoubled) = blackJack.getHandInfo(handId);
        assertEq(isDoubled, true);

        vm.stopPrank();
    }

    function testDoubleFinishesHandInstead() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        console.log("Old hand ID: ", handId);

        bjVRFMock.setReturnNumbers(2);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        vm.warp(DURATION_OF_HAND + 10);
        vm.roll(10);

        busdc.approve(address(blackJack), bet);
        uint256 newHandId = blackJack.double(handId);
        console.log("New hand ID: ", newHandId);

        (,,,,,, bool isHandPlayedOut,,,, bool isDoubled) = blackJack.getHandInfo(handId);
        assertEq(isDoubled, false);
        assertEq(handId, newHandId);
        assertEq(isHandPlayedOut, true);

        vm.stopPrank();
    }
}
