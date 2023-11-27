// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
// forge install openzeppelin/openzeppelin-contracts --no-commit
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// forge install smartcontractkit/chainlink-brownie-contracts --no-commit
import {AggregatorV3Interface} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
contract DSCEngine is ReentrancyGuard {
    ///////////////
    ///Errors///
    ///////////////

    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256);
    error DSCEngine__MintFailes();
    error DSCEngine__HealthFactorOk();

    /////////////////////
    ///State variables///
    /////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHLOD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATOR_BONUS = 10; // 10% bonus

    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collaterlDeposited; //tokenToPriceFeed
    mapping(address user => uint256 amount) private s_DSCMinted; //tokenToPriceFeed
    address[] private s_collaterlTokens;

    DecentralizedStableCoin private immutable i_dsc;

    /////////////
    ///Events///
    ////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed user, address indexed tokenCollateralAddres, uint256 indexed amountCollateral
    );

    ///////////////
    ///Modifiers///
    ///////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    ///////////////
    ///Functions///
    ///////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedsAddresses, address dscAddress) {
        //USD price feeds
        if (tokenAddresses.length != priceFeedsAddresses.length) {
            revert DSCEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedsAddresses[i];
            s_collaterlTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ////////////////////////
    ///External Functions///
    ////////////////////////

    /*
     * @param tokenCollateralAddress The address of the token to deposit as collaterall
     * @param amountCollateral The amount of the token to deposit as collaterall
     * @param amountDscToMint  AMount to mint , must have more collateral than minimum threshold
     * @notice this function will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) public {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /*
     * @param tokenCollateralAddress The address of the token to deposit as collaterall
     * @param amountCollateral The amount of the token to deposit as collaterall
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collaterlDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /*
     * @param tokenCollateralAddress The address of the token to deposit as collaterall
     * @param amountCollateral The amount of the token to deposit as collaterall
     * @param amoutToBurn The amount DSC to burn
     * This function burns DSC and redeem underline collateral in one tx
     */
    function redeemCollateralForDsc(address tokenCollateralAddres, uint256 amountCollateral, uint256 amoutToBurn)
        external
    {
        burnDsc(amoutToBurn);
        redeemCollateral(tokenCollateralAddres, amountCollateral);
        // redeemCollateral already checks health factor
    }

    // Threshold to let's say 150%
    // $100 ETH
    // To have $50 DSC you need at least $75 ETH, but if ETH price drops to $74
    //Hey if someone pays back your minted DSC , they can have all your collateral for a discount
    // so someone pays $50 DSC and will get your $74 ETH

    // in order to redeem
    //1. health factor must ve over 1 AFTER pulling collateral
    // DRY: Don't repeat yourself

    //CEI follow
    function redeemCollateral(address tokenCollateralAddres, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        s_collaterlDeposited[msg.sender][tokenCollateralAddres] -= amountCollateral;
        emit CollateralRedeemed(msg.sender, tokenCollateralAddres, amountCollateral);

        bool success = IERC20(tokenCollateralAddres).transfer(msg.sender, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @param amountDscToMint AMount to mint , must have more collateral than minimum threshold
     */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailes();
        }
    }

    function burnDsc(uint256 amount) public moreThanZero(amount) {
        s_DSCMinted[msg.sender] -= amount;
        bool success = i_dsc.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amount);

        _revertIfHealthFactorIsBroken(msg.sender); // Not really feasable!
    }

    // If we do start nearing undercollateralization we need someone to liquidate positions
    // $100 ETH backing $50 DSC
    // If price eth tanks $20 ETH back $50DSC  <- DSC isnt worth $1

    //If someone is almost undercollateralized, we will pay you to liquidate them.
    /*
     * @param collateral The ERC20 collateral address to liquidate from the user
     * @param user The user who has broken the health factor, their factor should be below MIN_HEALTH_FACTOR
     * @param debtToCover The amount of DSC you want to burn to improve the users health factor
     * @notice You can partially liquidate a user
     * @notice You will get a liquidation bonus for taking users funds.
     * @notice This function wokring assumes the protocol will be roighly 200% overcoll. for this to work
     * @notice A known bug will be if the protocoll were 100% or less collaterized then we wouldnt be able to incetive the liquidators
     * |For example if the price of the collateral plummeted before anyone could be liquidated
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // need to check health factor of user
        uint256 startingHealthFactor = _healthFactor(user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }
        // We want to burn their DSC "debt"
        // And take their collateral
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        //And give them a 10% bonus
        // SO we are giving the liquidator $110 of WETH for 100 DSC
        // we Should implement a feature to liquidate in the event the protocol is onsolvent
        // And sweep extra amounts into a treasury
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATOR_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
    }

    function getHealthFactor() external {}

    /////////////////////////////////////////
    ///Private and Internal View Functions///
    /////////////////////////////////////////

    /*
     * Returns how close to a liquidation a user is
     * If a user goes below 1 then they can get liquidated
     */
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        // total DSC minted
        // total collateral Value
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd / LIQUIDATION_THRESHLOD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
        // 1000 ETH * 50 = 50,000/ 100 = 500
        // 150 ETH / 100 DSC = 1.5
        // 150 * 50 = 7500 / 100 = (75 / 100) < 1

        // $1000ETH / 100 DSC
        // 1000 * 50 = 50000 / 100 = (500/100) > 1
    }

    //1. Check health factor
    //2. Revert if not healthy
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    /////////////////////////////////////////
    ///Public and External View Functions////
    /////////////////////////////////////////

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // loop through each collateral token , get the amount they have deposited and map it to
        // the price, to get the USD value
        for (uint256 i = 0; i < s_collaterlTokens.length; i++) {
            address token = s_collaterlTokens[i];
            uint256 amount = s_collaterlDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1ETH = $1000
        // The returned value from CL will be 1000*1e8
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION;
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }
}
