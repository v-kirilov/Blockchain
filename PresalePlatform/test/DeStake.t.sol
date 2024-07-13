// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DeStake} from "../src/DeStake.sol";
import {DeToken} from "../src/DeToken.sol";
import {UniswapV3FactoryMock} from "../src/Mock/UniswapV3FactoryMokc.sol";

contract DeStakeTest is Test {
    DeStake public destake;
    DeToken public detoken;
    UniswapV3FactoryMock public uniMock;

    uint256 constant PreSaleStartDate = 10;
    uint256 constant ETHPricePerToken = 1e15; // 0.001 ETH per token
    uint256 constant PresaleEndDate = 1000;
    uint256 constant VestingDuration = 1000;
    uint256 constant ProtocolFees = 3; //In percentige
    uint256 constant minTokenAmount = 100; //min amount of tokens to buy
    uint256 constant maxTokenAmount = 10000; //max amount of tokens to buy
    uint256 constant tokenHardCap = 30000; // total tokenCap
    address public FeeAddress = makeAddr("FeeAddress");
    address buyer = makeAddr("buyer");
    address uniswapPairAddr = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    event TokensPurchased(address indexed buyer, uint256 amount);
    event TokensClaiemd(address indexed buyer, uint256 amount);
    event PresaleEnded();
    event PresaleStarted();
    event ETHWithdrawn(address indexed user, uint256 amount);
    event PresaleDurationIncreased(uint256 amount);
    event TokenPriceUpdated(uint256 pricePerToken);
    event HardCapIncreased(uint256 newHardCapAmount);
    event UserIsBlackListed(address indexed user);
    event UserIsWhiteListed(address indexed user);

    function setUp() public {
        detoken = new DeToken("DeToken", "DET");
        uniMock = new UniswapV3FactoryMock();

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

    function setUniswapFactoryAddres() public {
        destake.setUniswapFactoryAddres(address(uniMock));
    }

    function test_witdhrawFeesRevertsWhenNoFees() public {
        vm.expectRevert("No fees to withdraw");
        destake.withdrawFees();
    }

    function test_witdhrawFeesSuccess() public {
        buyTokens();
        destake.withdrawFees();
        assert(FeeAddress.balance > 0);
    }

    function test_IncreasePresaleDurationReverts() public {
        vm.expectRevert(DeStake.PresaleNotStarted.selector);
        destake.increasePresaleDuration(0);
    }

    function test_IncreasePresaleDurationRevertWhenDurationIsZero() public {
        vm.expectRevert("Increase duration must be greater than 0");
        vm.warp(100);
        destake.increasePresaleDuration(0);
    }

    function test_IncreasePresaleDurationSuccess() public {
        vm.warp(100);
        vm.expectEmit();
        emit PresaleDurationIncreased(100);
        destake.increasePresaleDuration(100);
        assertEq(destake.presaleEndDate(), 1100);
    }

    function test_blackListRevertsWhenAddressZero() public {
        vm.expectRevert("Invalid address");
        destake.blackList(address(0));
    }

    function test_BlackListSuccess() public {
        vm.expectEmit();
        emit UserIsBlackListed(address(buyer));
        destake.blackList(buyer);
        assertEq(destake.blackListedUsers(buyer), true);
    }

    function test_blackListRevertsWhenSameAddressIsGiven() public {
        destake.blackList(buyer);
        vm.expectRevert("User is already blacklisted");
        destake.blackList(buyer);
    }

    function test_whiteListRevertsWhenAddressZero() public {
        vm.expectRevert("Invalid address");
        destake.whiteList(address(0));
    }

    function test_whiteListSuccess() public {
        destake.blackList(buyer);
        vm.expectEmit();
        emit UserIsWhiteListed(address(buyer));
        destake.whiteList(buyer);
        assertEq(destake.blackListedUsers(buyer), false);
    }

    function test_whiteListRevertsWhenAddressIsNotBlacklisted() public {
        vm.expectRevert("User is not blacklisted");
        destake.whiteList(address(buyer));
    }

    function test_increaseVestingDurationReverts() public {
        vm.expectRevert("Increase vesting duration must be greater than 0");
        destake.increaseVestingDuration(0);
    }

    function test_increaseVestingDurationSuccess() public {
        uint256 duration = destake.vestingDuration();
        destake.increaseVestingDuration(100);
        uint256 newDuration = destake.vestingDuration();
        assertEq(newDuration, duration + 100);
    }

    function test_updateEthPricePerTokenReverts() public {
        vm.expectRevert("Price per token must be greater than 0");
        destake.updateEthPricePerToken(0);
    }

    function test_updateEthPricePerTokenSuccess() public {
        uint256 newPrice = 1;
        vm.expectEmit();
        emit TokenPriceUpdated(newPrice);
        uint256 price = destake.ethPricePerToken();
        destake.updateEthPricePerToken(newPrice);
        uint256 actualPrice = destake.ethPricePerToken();
        assertEq(actualPrice, 1);
        assert(price != actualPrice);
    }

    function test_setUniswapFactoryAddresRevertsWhenAddress0() public {
        vm.expectRevert("Invalid address");
        destake.setUniswapFactoryAddres(address(0));
    }

    function test_setUniswapFactoryAddresSuccess() public {
        destake.setUniswapFactoryAddres(address(uniMock));
        assertEq(address(destake.factory()), address(uniMock));
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
        vm.startPrank(buyer);
        destake.claimTokens();
        uint256 actualTokens = detoken.balanceOf(buyer);
        uint256 tokensBought = destake.getTokensBoughtByUser(address(buyer));
        assertEq(actualTokens, tokensBought);
        vm.stopPrank();
    }

    function test_ClaimHalfTokensAtMidPointOfVesting() public {
        buyTokens();
        vm.warp(2000);
        vm.roll(15);
        vm.startPrank(buyer);
        destake.claimTokens();
        uint256 actualTokens = detoken.balanceOf(buyer);
        console.log(actualTokens);
        uint256 tokensBought = destake.getTokensBoughtByUser(address(buyer));
        console.log(tokensBought);
        assertEq(actualTokens, tokensBought / 2);
        vm.stopPrank();
    }

    //! Test also when liquidity phase is active!!!
    function test_withdrawEthRevertsWhenNoETHisSpend() public {
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
        assertEq(actualBalance, ethSpent);
        vm.stopPrank();
    }

    function test_withdrawSuccessAndClaimedTokensAreReturned() public {
        //!
        buyTokens();
        vm.warp(2000);
        vm.roll(10);
        vm.startPrank(buyer);
        destake.claimTokens();
        uint256 ethSpent = destake.getETHSpentByUser(address(buyer));
        detoken.approve(address(destake), detoken.balanceOf(buyer));
        destake.withdrawEth();
        uint256 actualBalance = buyer.balance;
        assertEq(actualBalance, ethSpent);
        assertEq(detoken.balanceOf(buyer), 0);

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

    function test_increaseHardCapRevertsPresaleNotStarted() public {
        vm.expectRevert(DeStake.PresaleNotStarted.selector);
        destake.increaseHardCap(0);
    }

    function test_increaseHardCapRevertsPresaleEnded() public {
        vm.warp(100);
        vm.roll(5);
        bool hasStarted = destake.hasPresaleStarted();
        console.log(hasStarted);

        vm.warp(10000);
        vm.roll(50);
        bool hasEnded = destake.hasPresaleEnded();
        console.log(hasEnded);
        vm.expectRevert(DeStake.PresaleOver.selector);
        destake.increaseHardCap(0);
    }

    function test_increaseHardCapSuccess() public {
        vm.warp(100);
        vm.roll(5);
        destake.increaseHardCap(10000);
        uint256 newHardCap = destake.tokenHardCap();
        assertEq(newHardCap, 40000);
        //  uint256 constant tokenHardCap = 30000; // total tokenCap
    }

    function calculateTokensIncludingFees(uint256 ethAmount, uint256 protocolFees, uint256 pricePerToken)
        public
        pure
        returns (uint256)
    {
        uint256 buyAmount = (ethAmount - protocolFees * ethAmount / 100) / pricePerToken;
        return buyAmount;
    }

    function test_buyTokensRevertsCauseBuyerIsBlacklisted() public {
        uint256 ethAmount = 1 ether;
        vm.warp(100);
        vm.roll(5);
        destake.blackList(buyer);
        vm.startPrank(buyer);
        vm.expectRevert(DeStake.UserBlackListed.selector);
        destake.buyTokens{value: ethAmount}();
        vm.stopPrank();
    }

    function test_checkTokenLiqPhaseAndOtherExternalFunctions() public {
        uint256 ethAmount = 1 ether;
        vm.warp(100);
        vm.roll(5);
        vm.startPrank(buyer);
        destake.buyTokens{value: ethAmount}();
        vm.stopPrank();
        bool checkTokenLiquidityPhase = destake.checkTokenLiquidityPhase();
        uint256 tokensSold = destake.tokensSold();
        uint256 tokenPrice = destake.getTokenPrice();
        uint256 ethRaised = destake.amountETHRaised();
        assertEq(tokenPrice, 1000000000000000);
        assertEq(ethRaised, 970000000000000000);
        assertEq(tokensSold, 970);
        assertEq(checkTokenLiquidityPhase, false);
    }
}
