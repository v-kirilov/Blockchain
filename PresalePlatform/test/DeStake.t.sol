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
    uint256 constant maxTokenAmount = 100000; //max amount of tokens to buy
    uint256 constant tokenHardCap = 1e8; // total tokenCap
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

    function test_buyTokens() public {
        uint256 ethAmount = 1 ether;
        vm.warp(100);
        vm.roll(5);
        vm.startPrank(buyer);
        destake.buyTokens{value: ethAmount}();
        uint256 expectedTokens = calculateTokensIncludingFees(ethAmount, ProtocolFees, ETHPricePerToken);
        console.log(expectedTokens);

        uint256 actualTokens = detoken.balanceOf(buyer);
        assertEq(actualTokens, expectedTokens);
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
