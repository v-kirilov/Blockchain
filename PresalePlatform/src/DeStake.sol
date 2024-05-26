// The contract is made with assumptions that for every presale there will be a separate contract deployed.

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeStake  is Ownable{
    error NotPossible();
    error PresaleOver();
    error PresaleNotStarted();
    error MinMaxBuyNotReached();
    error HardCapReached();
    error UserBlackListed();
    error NoETHProvided();

    // Info for the buyer, the amount of tokens bought and the amount of ETH spent.
    // This should be updated
    struct Buyer {
        address buyerAddress;
        uint256 tokensBought;
        uint256 ethSpent;
        uint256 tokensClaimed;
        //bool isBlackListed;
    }

    // Token must be transfered to the protocol before the presale starts
    // The token being presaled
    IERC20 public token;

    // Tokens that are for sale during presale
    uint256 public tokenHardCap;

    // Presale start date and duration for the tokens
    uint256 public preSaleStartDate;
    uint256 public presaleDuration;

    // Vesting duration after the presale period is over
    uint256 public vestingDuration;

    // Price of the token in ETH, which can be change later on depenging on the presale status
    uint256 public ethPricePerToken;

    // Can be private, as public functions are provided to check the status of the presale.
    bool private hasStarted;
    bool private hasEnded;

    // After the presale is over, the liquidity phase can be started.
    bool private isLiquidityPhaseActive;

    // Should be public to allow for the buyer to see the fees.
    uint256 public protocolFee;

    // Min and max token buy per buyer address (can be curcemvented by buyer using multiple addresses)
    uint256 public minTokenBuy;
    uint256 public maxTokenBuy;

    // The address for the protocol fees
    address public protocolFeeAddress;

    // To keep track of the total ETH raised during the presale.
    uint256 private totalEthRaised;

    // Good to have for info, the amount of tokens sold, although this can be checked by the amount of tokens this contract have.
    uint256 private totalTokensSold;

    // Good to have for info, the amount of acquired fees.
    uint256 private totalFeesAcquired;

    // The address of the Uniswap pair, if the liquidity phase is active.
    address public uniswapPair;

    // Mapping to store the buyers.
    mapping(address buyerAddress => Buyer buyers) public buyers;
    // Usefull mapping to store the blacklisted users if neccesarry.
    mapping(address blacklisted => bool isBlackListed) public blackListedUsers;

    //Modifiers
    modifier notBLackListed() {
        if (blackListedUsers[msg.sender]) {
            revert UserBlackListed();
        }
        _;
    }

        modifier presaleActive() {
        if (hasEnded) {
            revert PresaleOver();
        }
        if (!hasStarted) {
            revert PresaleNotStarted();
        }
        _;
    }

    //Events

    constructor(uint256 _preSaleStartDate, uint256 _presaleDuration) Ownable(msg.sender) {
        preSaleStartDate = _preSaleStartDate;
        presaleDuration = _presaleDuration;
        //! Extend presale duration in needed, function onlyonwer
    }

    function buyTokens(uint256 amount)  external  payable  notBLackListed presaleActive
    {
        if (msg.value == 0) {
            revert NoETHProvided();
        }
        if (!hasStarted) {
            revert PresaleNotStarted();
        }
        if (hasEnded) {
            revert PresaleOver();
        }
        if (amount < minTokenBuy || amount > maxTokenBuy) {
            revert MinMaxBuyNotReached();
        }
        if (totalTokensSold >= tokenHardCap) {
            revert HardCapReached();
        }

        uint256 tokensToBuy = msg.value / ethPricePerToken;
        totalTokensSold += tokensToBuy;
        totalEthRaised += msg.value;

        buyers[msg.sender].tokensBought += tokensToBuy;
        buyers[msg.sender].ethSpent += msg.value;

        //emit TokensPurchased(address(this), msg.sender, tokensToBuy);
    }


}
