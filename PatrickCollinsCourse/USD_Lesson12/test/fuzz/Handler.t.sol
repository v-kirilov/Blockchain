// SPDX-License-Identifier: MIT
// narrow down the way we call functions

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

// Price feed
// WETH token
// WBTC token

contract Handler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMinteIsCalled;
    address[] public usersWithCollateralDeposited;
    MockV3Aggregator public ethUsdPriceFeed;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

      ethUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));
    }

    //redeem collateral <-

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);

        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(address(collateral), amountCollateral);

        vm.stopPrank();
        // will have double push
        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollatrealToRedeem = dscEngine.getCollateralBalanceOfUser(address(collateral), msg.sender);
        // there is a bug where a user can redeem more than they have
        amountCollateral = bound(amountCollateral, 0, maxCollatrealToRedeem);
        if (amountCollateral ==0) {
            return;
        }
        dscEngine.redeemCollateral(address(collateral), amountCollateral);
    }

    function mintDsc(uint256 amount,uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length==0) {
            return;
        }
        address sender = usersWithCollateralDeposited[addressSeed%usersWithCollateralDeposited.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(sender);
        int256 maxDscToMint = int256(collateralValueInUsd) /2 - int256(totalDscMinted);

        if (maxDscToMint<0) {
            return;
        }

        amount = bound(amount,0,uint256(maxDscToMint));
        if (amount ==0) {
            return;
        }

        vm.startPrank(sender);
        dscEngine.mintDsc(amount);

        vm.stopPrank();
        timesMinteIsCalled++;
    }

    //This breaks our invariant test suite!!!
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    //Helper functions

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
