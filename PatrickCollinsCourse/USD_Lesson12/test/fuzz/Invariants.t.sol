// SPDX-License-Identifier: MIT

// have our invariants aka properteis

// What are our invariants?

//1. The total supply of DSC should be less than the total value of collateral
//2. Getter view functions should never revert <- evergreen invariant

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDsc} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invariants is StdInvariant, Test {
    DeployDsc deployer;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler hanlder;

    function setUp() external {
        deployer = new DeployDsc();
        (dsc, dscEngine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();

        // call redeemCollateral only if we have deposited collateral
        hanlder = new Handler(dscEngine,dsc);
        targetContract(address(hanlder));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get all the collateral
        // compare it to all debt
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));

        uint256 wethValue = dscEngine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dscEngine.getUsdValue(wbtc, totalBtcDeposited);

        console.log("weth Value:", wethValue);
        console.log("wtc Value:", wbtcValue);
        console.log("total supply:", totalSupply);
        console.log("total mints called:", hanlder.timesMinteIsCalled());

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersShouldNotRevert() public {
        dscEngine.getLiquidationBonus();
        dscEngine.getPrecision();
    }
}
