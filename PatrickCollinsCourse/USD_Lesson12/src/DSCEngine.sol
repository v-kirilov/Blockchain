// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// forge install smartcontractkit/chainlink-brownie-contracts --no-commit
import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
    error DSCEngine__TransferFailes();

    /////////////////////
    ///State variables///
    /////////////////////

    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collaterlDeposited; //tokenToPriceFeed
    mapping(address user => uint256 amount) private s_DSCMinted; //tokenToPriceFeed
    address[] private s_collaterlTokens;

    DecentralizedStableCoin private immutable i_dsc;

    /////////////
    ///Events///
    ////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

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

    function depositCollateralAndMintDsc() external {}

    /*
     * @param tokenCollateralAddress The address of the token to deposit as collaterall
     * @param amountCollateral The amount of the token to deposit as collaterall
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collaterlDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailes();
        }
    }

    function redeemCollateralForDsc() external {}

    // Threshold to let's say 150%
    // $100 ETH
    // To have $50 DSC you need at least $75 ETH, but if ETH price drops to $74
    //Hey if someone pays back your minted DSC , they can have all your collateral for a discount
    // so someone pays $50 DSC and will get your $74 ETH

    function redeemCollateral() external {}

    /*
     * @param amountDscToMint AMount to mint , must have more collateral than minimum threshold
     */
    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc() external {}

    function liquidate() external {}

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
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        //1. Check health factor
        //2. Revert if not healthy
    }

    /////////////////////////////////////////
    ///Public and External View Functions///
    /////////////////////////////////////////

    function getAccountCollateralValue(address user) public view returns (uint256) {
        // loop through each collateral token , get the amount they have deposited and map it to
        // the price, to get the USD value
        for (uint i = 0; i < s_collaterlTokens.length; i++) {
            address token = s_collaterlTokens[i];
            uint256 amount = s_collaterlDeposited[user][token];
        }
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        
    }
}
