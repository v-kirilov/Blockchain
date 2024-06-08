// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DeStake} from "../src/DeStake.sol";
import {DeToken} from "../src/DeToken.sol";

contract DeStakeTest is Test {
    DeStake public destake;
    DeToken public detoken;
    uint256 constant PreSaleStartDate = 10;
    uint256 constant ETHPricePerToken = 1e15; // 0.001 ETH per token
    uint256 constant PresaleEndDate = 1000;
    uint256 constant VestingDuration = 1000;
    uint256 constant ProtocolFees = 3; //In percentige
    uint256 constant minTokenAmount = 100; //min amount of tokens to buy
    uint256 constant maxTokenAmount = 10000; //max amount of tokens to buy
    uint256 constant tokenHardCap = 30000; // total tokenCap
    address public FeeAddress;
    address buyer = makeAddr("buyer");

    function setUp() public {
        detoken = new DeToken("DeToken", "DET");

        FeeAddress = address(0x1);
        destake = new DeStake(
            PreSaleStartDate,
            PresaleEndDate,
            address(detoken),
            FeeAddress,
            VestingDuration,
            ETHPricePerToken,
            ProtocolFees,
            minTokenAmount,
            maxTokenAmount,
            tokenHardCap
        );
        detoken.mint(address(destake), tokenHardCap);
        vm.deal(buyer, 1 ether);
    }

    function buyTokens() public {
        uint256 ethAmount = 1 ether;
        vm.warp(100);
        vm.roll(5);
        vm.startPrank(buyer);
        destake.buyTokens{value: ethAmount}();

        vm.stopPrank();
    }

    function test_buyTokensSuccess() public {
        uint256 ethAmount = 1 ether;
        vm.warp(100);
        vm.roll(5);
        vm.startPrank(buyer);
        destake.buyTokens{value: ethAmount}();
        uint256 expectedTokens = calculateTokensIncludingFees(ethAmount, ProtocolFees, ETHPricePerToken);
        console.log(expectedTokens);

        uint256 actualTokens = destake.getTokensBoughtByUser(address(buyer));
        assertEq(actualTokens, expectedTokens);
        vm.stopPrank();
    }

    function test_buyTokensRevertsWhenNoEthIsSent() public {
        uint256 ethAmount = 0 ether;
        vm.warp(100);
        vm.roll(5);
        vm.startPrank(buyer);
        vm.expectRevert(DeStake.NoETHProvided.selector);
        destake.buyTokens{value: ethAmount}();

        vm.stopPrank();
    }

    function test_buyTokensRevertsWhenUnderMinTokensToBuy() public {
        uint256 ethAmount = 0.001 ether;
        vm.warp(100);
        vm.roll(5);
        vm.startPrank(buyer);
        vm.expectRevert(DeStake.OutOfMinMaxAmount.selector);
        destake.buyTokens{value: ethAmount}();

        vm.stopPrank();
    }

    function test_buyTokensRevertsWhenUnderMaxTokensToBuy() public {
        uint256 ethAmount = 100 ether;
        vm.warp(100);
        vm.roll(5);
        vm.deal(buyer, 100 ether);
        vm.startPrank(buyer);
        vm.expectRevert(DeStake.OutOfMinMaxAmount.selector);
        destake.buyTokens{value: ethAmount}();

        vm.stopPrank();
    }

    function test_buyTokensRevertsWhenMaxCapReached() public {
        uint256 ethAmount = 10 ether;
        vm.warp(100);
        vm.roll(5);

        address buyer1 = makeAddr("buyer1");
        vm.deal(buyer1, 10 ether);
        vm.prank(buyer1);
        destake.buyTokens{value: ethAmount}();

        address buyer2 = makeAddr("buyer2");
        vm.deal(buyer2, 10 ether);
        vm.prank(buyer2);
        destake.buyTokens{value: ethAmount}();

        address buyer3 = makeAddr("buyer3");
        vm.deal(buyer3, 10 ether);
        vm.prank(buyer3);
        destake.buyTokens{value: ethAmount}();

        vm.deal(buyer, 10 ether);
        vm.startPrank(buyer);
        vm.expectRevert(DeStake.HardCapReached.selector);
        destake.buyTokens{value: ethAmount}();

        vm.stopPrank();
    }

    function test_claimTokensRevertsWhenVestingNotStarted() public {
        vm.warp(100);
        vm.roll(5);

        vm.deal(buyer, 10 ether);
        vm.startPrank(buyer);
        vm.expectRevert(DeStake.VestingNotStarted.selector);
        destake.claimTokens();

        vm.stopPrank();
    }

      function test_claimTokensRevertsWhenNoTokenBought() public {
        vm.warp(1005);
        vm.roll(50);

        vm.deal(buyer, 10 ether);
        vm.startPrank(buyer);
        vm.expectRevert("No tokens bought");
        destake.claimTokens();

        vm.stopPrank();
    }

    function test_ClaimTokensRevertWhenClaimableAreZero() public {
        buyTokens();
        vm.warp(1001);
        vm.roll(5);
        console.log(block.timestamp);
        vm.startPrank(buyer);
        vm.expectRevert("No tokens to claim");
        destake.claimTokens();
        vm.stopPrank();
    }

        function test_ClaimTokensSuccess() public {
        buyTokens();
        vm.warp(3001);
        vm.roll(15);
        console.log(block.timestamp);
        vm.startPrank(buyer);
        destake.claimTokens();
        uint256 actualTokens = detoken.balanceOf(buyer);
        uint256 tokensBought = destake.getTokensBoughtByUser(address(buyer));
        assertEq(actualTokens, tokensBought);
        vm.stopPrank();
    }

    //! Test also when liquidity phase is active!!!
    function test_withdrawEthRevertsWhenNoETHisSpend()  public {
        vm.startPrank(buyer);
        vm.expectRevert("No ETH to withdraw");
        destake.withdrawEth();
        vm.stopPrank();
    }

    function test_withdrawEthSuccess() public {
        buyTokens();
        vm.warp(1001);
        vm.roll(5);
        vm.startPrank(buyer);
        uint256 ethSpent = destake.getETHSpentByUser(address(buyer));
        destake.withdrawEth();
        uint256 actualBalance = buyer.balance;
       assertEq(actualBalance,ethSpent);
        vm.stopPrank();
    }

    function test_hasPresaleStartedReturnsFalse() public {
        bool hasStarted = destake.hasPresaleEnded();
        assertEq(hasStarted, false);
    }

    function test_hasPresaleStartedReturnsTrue() public {
        vm.warp(100);
        vm.roll(5);
        bool hasStarted = destake.hasPresaleEnded();
        assertEq(hasStarted, false);
    }

    function test_hasPresaleEndedReturnsFalse() public {
        vm.warp(100);
        vm.roll(5);
        bool hasEnded = destake.hasPresaleEnded();
        assertEq(hasEnded, false);
    }

    function test_hasPresaleEndedReturnsTrue() public {
        vm.warp(10000);
        vm.roll(5);
        bool hasEnded = destake.hasPresaleEnded();
        assertEq(hasEnded, true);
    }

    function calculateTokensIncludingFees(uint256 ethAmount, uint256 protocolFees, uint256 pricePerToken)
        public
        pure
        returns (uint256)
    {
        uint256 buyAmount = (ethAmount - protocolFees * ethAmount / 100) / pricePerToken;
        return buyAmount;
    }
}
