// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/*
 * @title DSCEngine
 * @author Viktor Kirilov
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */
contract DSCEngine {
    function depositCollateralAndMintDsc() external {}

    function depositCollateral() external {}

    function redeemCollateralForDsc() external {}

    // Threshold to let's say 150%
    // $100 ETH
    // To have $50 DSC you need at least $75 ETH, but if ETH price drops to $74
    //Hey if someone pays back your minted DSC , they can have all your collateral for a discount
    // so someone pays $50 DSC and will get your $74 ETH

    function redeemCollateral() external {}

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external {}
}
