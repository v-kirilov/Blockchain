// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {BlackJack} from "../src/BlackJack.sol";
import {BlackJackVRFMock} from "../src/Mocks/BlackJackVRFMock.sol";
import {BUSDC} from "../src/BUSDC.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

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

    function stringToUint(string memory s) public pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
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

    function testFinishBetDealerAndPlayerGetsSoftHands() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(6);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        (bool isDealerHandSoft, bool isPlayerHandSoft) = blackJack.isHandSoft(handId);

        console.log("Is dealer hand soft: ", isDealerHandSoft);
        console.log("Is player hand soft: ", isPlayerHandSoft);

        string memory result = blackJack.finishBet(handId);

        assertEq(isDealerHandSoft, true);
        assertEq(isPlayerHandSoft, true);

        vm.stopPrank();
    }

    function testFinishBetDealerBusts() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(14);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        string memory result = blackJack.finishBet(handId);

        uint256 newHandId = stringToUint(result);

        (uint256 newPlayerHand, uint256 newDealerHand) = blackJack.getHandFromHit(handId, newHandId);

        BlackJack.Hand memory newHand = blackJack.getHandInfo(newHandId);

        string memory resultNewHand = blackJack.finishBet(newHandId);

        uint256 playerFunds = busdc.balanceOf(winner);
        uint256 dealerFunds = blackJack.getDealerFunds();
        assertEq(playerFunds, 4000e18);
        assertEq(dealerFunds, 9000e18);
        assertEq(resultNewHand, "Dealer busts");

        vm.stopPrank();
    }

    function testFinishBetPlayerGetsTwoAces() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(9);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        (bool isDealerHandSoft, bool isPlayerHandSoft) = blackJack.isHandSoft(handId);

        console.log("Is dealer hand soft: ", isDealerHandSoft);
        console.log("Is player hand soft: ", isPlayerHandSoft);

        string memory result = blackJack.finishBet(handId);

        assertEq(isPlayerHandSoft, true);
        assertEq(isDealerHandSoft, false);

        BlackJack.Hand memory hand = blackJack.getHandInfo(handId);
        assertEq(hand.playerHand, 12);
        assertEq(hand.isPlayerHandSoft, true);

        vm.stopPrank();
    }

    function testGetHandHasTwoMonkeysAndDealerHasTwoAces() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(11);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        (bool isDealerHandSoft, bool isPlayerHandSoft) = blackJack.isHandSoft(handId);

        console.log("Is dealer hand soft: ", isDealerHandSoft);
        console.log("Is player hand soft: ", isPlayerHandSoft);

        assertEq(playerHand, 20);
        assertEq(dealerHand, 12);
        assertEq(isPlayerHandSoft, false);
        assertEq(isDealerHandSoft, true);

        vm.stopPrank();
    }

    function testFinishBetDealerHitsAgain() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(8);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));

        string memory result = blackJack.finishBet(handId);
        console.log(result);

        (bool dealerHit, bool playerHit) = blackJack.isHandHit(handId);
        console.log("Dealer hit: ", dealerHit);
        console.log("Player hit: ", playerHit);

        bool isOriginalHandPlayedOut = blackJack.isHandPlayedOut(handId);
        assertEq(isOriginalHandPlayedOut, true);

        uint256 newHandId = stringToUint(result);
        newHandId += 1;
        bjVRFMock.setReturnNumbers(7);
        // (int256 playerHand2, int256 dealerHand2) = blackJack.getHand(newHandId); //! THIS IS PROBLEMATIC
        (uint256 playerHand2, uint256 dealerHand2) = blackJack.getHandFromHit(handId, newHandId);
        console.log("Player hand is: ", uint256(playerHand2));
        console.log("Dealer hand is: ", uint256(dealerHand2));
        //Dealer hits again, will get a new handID

        string memory resultAfterHit = blackJack.finishBet(newHandId);
        console.log(resultAfterHit);

        uint256 playerFunds = busdc.balanceOf(winner);
        uint256 dealerFunds = busdc.balanceOf(address(blackJack));
        assertEq(playerFunds, 2000e18);
        assertEq(dealerFunds, 11000e18);

        vm.stopPrank();
    }

    function testHitRevertsBecausePlayerHasBJ() public {
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

        vm.expectRevert(BlackJack.BlackJackHand.selector);

        uint256 newHandId = blackJack.playerHit(handId);

        vm.stopPrank();
    }

    function testHitRevertsWhenNotOwner() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(1);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        bjVRFMock.setReturnNumbers(7);
        vm.stopPrank();

        vm.startPrank(loser);
        vm.expectRevert(BlackJack.NotOwnerOfHand.selector);
        uint256 newHandId = blackJack.playerHit(handId);
        vm.stopPrank();
    }

    function testHitSecondTimeWhenPlayerHasMoreThan21() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(1);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);
        console.log(uint256(playerHand));
        console.log(uint256(dealerHand));

        bjVRFMock.setReturnNumbers(7);
        uint256 newHandId = blackJack.playerHit(handId);

        (uint256 newPlayerHand, uint256 newDealerHand) = blackJack.getHandFromHit(handId, newHandId);
        console.log(uint256(newPlayerHand));
        console.log(uint256(newDealerHand));
        vm.expectRevert(BlackJack.NotPossible.selector);
        uint256 newHandWillRevert = blackJack.playerHit(newHandId);

        vm.stopPrank();
    }

    function testgetHandFromHitWillRevertWhenHandPlayedout() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(1);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        string memory result = blackJack.finishBet(handId);

        vm.expectRevert(BlackJack.NotPossible.selector);
        (uint256 newPlayerHand, uint256 newDealerHand) = blackJack.getHandFromHit(handId, handId);

        vm.stopPrank();
    }

    function testHitSuccesfullAndGetMonkey() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(1);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        bjVRFMock.setReturnNumbers(7);
        uint256 newHandId = blackJack.playerHit(handId);

        (uint256 newPlayerHand, uint256 newDealerHand) = blackJack.getHandFromHit(handId, newHandId);

        console.log("Player hand is: ", uint256(newPlayerHand));
        console.log("Dealer hand is: ", uint256(newDealerHand));

        string memory result = blackJack.finishBet(newHandId);

        uint256 playerFunds = busdc.balanceOf(winner);
        uint256 dealerFunds = busdc.balanceOf(address(blackJack));
        assertEq(playerFunds, 2000e18);
        assertEq(dealerFunds, 11000e18);
        console.log(result);

        vm.stopPrank();
    }

    function testHitGetsAceAndHandIsSoft() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(12);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);

        console.log("Player hand is: ", uint256(playerHand));
        console.log("Dealer hand is: ", uint256(dealerHand));
        bjVRFMock.setReturnNumbers(13);
        uint256 newHandId = blackJack.playerHit(handId);

        (uint256 newPlayerHand, uint256 newDealerHand) = blackJack.getHandFromHit(handId, newHandId);

        console.log("Player hand is: ", uint256(newPlayerHand));
        console.log("Dealer hand is: ", uint256(newDealerHand));
        (bool isDealerHandSoft, bool isPlayerHandSoft) = blackJack.isHandSoft(newHandId);
        console.log("Player hand is soft: ", isPlayerHandSoft);
        console.log("Dealer hand is soft: ", isDealerHandSoft);

        assertEq(newPlayerHand, 20);
        assertEq(isPlayerHandSoft, true);
        assertEq(isDealerHandSoft, true);
        vm.stopPrank();
    }

    function testHitSuccesfullAndGetAce() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(1);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);
        console.log("Player hand is: ", uint256(playerHand));
        console.log("Delaer hand is: ", uint256(dealerHand));

        bjVRFMock.setReturnNumbers(10);
        uint256 newHandId = blackJack.playerHit(handId);

        (uint256 newPlayerHand, uint256 newDealerHand) = blackJack.getHandFromHit(handId, newHandId);

        console.log("Player hand is: ", uint256(newPlayerHand));
        console.log("Dealer hand is: ", uint256(newDealerHand));

        string memory result = blackJack.finishBet(newHandId);

        uint256 playerFunds = busdc.balanceOf(winner);
        uint256 dealerFunds = busdc.balanceOf(address(blackJack));
        assertEq(playerFunds, 4000e18);
        assertEq(dealerFunds, 9000e18);
        console.log(result);

        vm.stopPrank();
    }

    function testPlayerGetsFirstCardAceAndHitsGetsMonkeyAndBusts() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(15);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);
        console.log("Player hand is: ", uint256(playerHand));
        console.log("Delaer hand is: ", uint256(dealerHand));

        bjVRFMock.setReturnNumbers(7);
        uint256 newHandId = blackJack.playerHit(handId);

        (uint256 newPlayerHand, uint256 newDealerHand) = blackJack.getHandFromHit(handId, newHandId);

        console.log("Player hand is: ", uint256(newPlayerHand));
        console.log("Dealer hand is: ", uint256(newDealerHand));

        string memory result = blackJack.finishBet(newHandId);

        uint256 playerFunds = blackJack.remainingPlayerFunds(winner);
        uint256 dealerFunds = busdc.balanceOf(address(blackJack));
        assertEq(playerFunds, 2000e18);
        assertEq(dealerFunds, 11000e18);
        console.log(result);

        vm.stopPrank();
    }

    function testPlayerTriesToHitButTimeHasPassed() public {
        uint256 bet = 1000e18;
        registerPlayer();
        mintToBJContract();

        vm.startPrank(winner);
        busdc.approve(address(blackJack), bet);

        uint256 handId = blackJack.enterBet(bet);
        bjVRFMock.setReturnNumbers(15);

        (int256 playerHand, int256 dealerHand) = blackJack.getHand(handId);
        console.log("Player hand is: ", uint256(playerHand));
        console.log("Delaer hand is: ", uint256(dealerHand));

        vm.warp(DURATION_OF_HAND + 10);
        vm.roll(10);

        bjVRFMock.setReturnNumbers(7);
        uint256 newHandId = blackJack.playerHit(handId);
        console.log("New hand ID: ", newHandId);

        assertEq(handId, newHandId);

        uint256 playerFunds = blackJack.remainingPlayerFunds(winner);
        uint256 dealerFunds = busdc.balanceOf(address(blackJack));
        assertEq(playerFunds, 2000e18);
        assertEq(dealerFunds, 11000e18);

        BlackJack.Hand memory hand = blackJack.getHandInfo(handId);
        assertEq(hand.isHandPlayedOut, true);

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

        bool isDoubled = blackJack.isHandDoubled(handId);
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

        bool isHandPlayedOut = blackJack.isHandPlayedOut(handId);
        bool isDoubled = blackJack.isHandDoubled(handId);

        assertEq(isDoubled, false);
        assertEq(handId, newHandId);
        assertEq(isHandPlayedOut, true);

        vm.stopPrank();
    }

    function testNotOwner() public {
        vm.startPrank(winner);
        vm.expectRevert();
        blackJack.renounceOwnership();
        vm.stopPrank();
    }

    function testRenounceOwner() public {
        vm.expectRevert(BlackJack.NotPossible.selector);
        blackJack.renounceOwnership();
    }

    function testSendETHDirectToContract() public {
        vm.startPrank(winner);
        vm.expectRevert(BlackJack.NotPossible.selector);
        (bool ok,) = address(winner).call{value: 1 ether}("");
        console.log(ok);
        vm.stopPrank();
    }
}
