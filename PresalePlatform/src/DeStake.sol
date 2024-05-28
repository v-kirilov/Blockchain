// The contract is made with assumptions that for every presale there will be a separate contract deployed.

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DeStake is Ownable {
    using SafeERC20 for IERC20;

    error NotPossible();
    error PresaleOver();
    error PresaleNotStarted();
    error MinMaxBuyNotReached();
    error HardCapReached();
    error UserBlackListed();
    error NoETHProvided();
    error VestingNotStarted();

    // Info for the buyer, the amount of tokens bought and the amount of ETH spent.
    // This should be updated
    struct Buyer {
        address buyerAddress;
        uint256 tokensBought;
        uint256 ethSpent;
        uint256 tokensClaimed;
    }
    //bool isBlackListed;

    // Token must be transfered to the protocol before the presale starts
    // The token being presaled
    IERC20 public immutable token;

    // Tokens that are for sale during presale
    uint256 public tokenHardCap;

    // Presale start date and duration for the tokens
    uint256 public preSaleStartDate;
    uint256 public presaleDuration;
    uint256 public presaleEndDate;

    // Vesting duration after the presale period is over
    uint256 public vestingDuration;

    uint256 claimableTokensPercentige;

    // Price of the token in ETH, which can be change later on depenging on the presale status
    uint256 public ethPricePerToken;

    // Can be private, as public functions are provided to check the status of the presale.
    bool private hasStarted;
    bool private hasEnded;

    // After the presale is over, the liquidity phase can be started.
    bool private isLiquidityPhaseActive;

    // Should be public to allow for the buyer to see the fees.
    // In percentige
    uint256 public protocolFee = 3;

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
        if (block.timestamp > presaleEndDate) {
            revert PresaleOver();
        }
        if (!hasStarted) {
            revert PresaleNotStarted();
        }
        if (block.timestamp < preSaleStartDate) {
            revert PresaleNotStarted();
        }
        _;
    }

    modifier vestingStarted() {
        if (block.timestamp < presaleEndDate) {
            revert VestingNotStarted();
        }
        _;
    }

    //Events
    event TokensPurchased(address indexed buyer, uint256 amount);
    event TokensClaiemd(address indexed buyer, uint256 amount);

    constructor(
        uint256 _preSaleStartDate,
        uint256 _presaleDuration,
        address _token,
        address _protocolFeeAddress,
        uint256 _vestingDuration
    ) Ownable(msg.sender) {
        preSaleStartDate = _preSaleStartDate;
        presaleDuration = _presaleDuration;
        presaleEndDate = preSaleStartDate + presaleDuration;
        protocolFeeAddress = _protocolFeeAddress;
        vestingDuration = _vestingDuration;
        token = IERC20(_token);
        //! Extend presale duration if needed, function onlyonwer
    }

    function buyTokens() external payable notBLackListed presaleActive {
        if (msg.value == 0) {
            revert NoETHProvided();
        }
        if (!hasStarted) {
            revert PresaleNotStarted();
        }
        if (hasEnded) {
            revert PresaleOver();
        }

        //Take into account the fees.
        uint256 fees = msg.value * protocolFee / 100;
        uint256 purchaseValue = msg.value - fees;
        totalFeesAcquired += fees;

        uint256 amount = purchaseValue / ethPricePerToken;
        if (amount < minTokenBuy || amount > maxTokenBuy) {
            revert MinMaxBuyNotReached();
        }

        totalTokensSold += amount;
        if (totalTokensSold >= tokenHardCap) {
            revert HardCapReached();
        }

        totalEthRaised += purchaseValue;
        Buyer memory buyer = buyers[msg.sender];
        if (buyer.buyerAddress == address(0)) {
            buyer.buyerAddress = msg.sender;
        }
        buyer.tokensBought += amount;
        buyer.ethSpent += msg.value;

        buyers[msg.sender] = buyer;

        token.safeTransfer(msg.sender, amount);

        emit TokensPurchased(address(msg.sender), amount);
    }

    function claimTokens() external vestingStarted {
        Buyer memory buyer = buyers[msg.sender];
        require(buyer.tokensBought > 0, "No tokens bought");
        uint256 claimablePercentige = getClaimablePercentige();
        uint256 claimableTokens = buyer.tokensBought * claimablePercentige / 100 - buyer.tokensClaimed;
        require(claimableTokens > 0, "No tokens to claim");

        buyer.tokensClaimed += claimableTokens;
        buyers[msg.sender] = buyer;

        token.safeTransfer(msg.sender, claimableTokens);

        emit TokensClaiemd(address(msg.sender), claimableTokens);
    }

    function withdrawFees() external onlyOwner {
        require(totalFeesAcquired > 0, "No fees to withdraw");
        totalFeesAcquired = 0;
        (bool success,) = payable(protocolFeeAddress).call{value: totalFeesAcquired}("");
        require(success, "Failed to withdraw fees");
    }

    function increasePresaleDuration(uint256 increasedDuration) external onlyOwner presaleActive {
        presaleDuration += increasedDuration;
        presaleEndDate += increasedDuration;
    }

    function increaseVestingDuration(uint256 increaseVestingDuration) external onlyOwner {
        require(increaseVestingDuration > 0, "Increase vesting duration must be greater than 0");

        vestingDuration += increaseVestingDuration;
    }

    function updateEthPricePerToken(uint256 _ethPricePerToken) external onlyOwner {
        require(_ethPricePerToken > 0, "Price per token must be greater than 0");
        ethPricePerToken = _ethPricePerToken;
    }

    function increaseHardCap(uint256 _tokenHardCapIncrement) external onlyOwner presaleActive {
        require(_tokenHardCapIncrement > tokenHardCap, "Token hard cap must be bigger than before");
        tokenHardCap += _tokenHardCapIncrement;
    }

    function blackList(address user) external onlyOwner {
        require(user != address(0), "Invalid address");
        require(!blackListedUsers[user], "User is already blacklisted");
        blackListedUsers[user] = true;
    }

    function whiteList(address user) external onlyOwner {
        require(user != address(0), "Invalid address");
        require(blackListedUsers[user], "User is not blacklisted");
        blackListedUsers[user] = false;
    }

    function hasPresaleStarted() public view returns (bool) {
        return hasStarted;
    }

    function hasPresaleEnded() public view returns (bool) {
        return hasEnded;
    }

    function amountETHRaised() external view onlyOwner returns (uint256) {
        return totalEthRaised;
    }

    function getTokenPrice() external view returns (uint256) {
        return ethPricePerToken;
    }

    function tokensSold() external view onlyOwner returns (uint256) {
        return totalTokensSold;
    }

    function isVestingDurationOver() public view returns (bool) {
        return block.timestamp > presaleEndDate + vestingDuration;
    }

    function getClaimablePercentige() public view returns (uint256) {
        require(block.timestamp > presaleEndDate, "Presale is not over yet");
        uint256 vestingEndDate = presaleEndDate + vestingDuration;
        uint256 percentige;
        if (block.timestamp > presaleEndDate + vestingDuration) {
            percentige = 100;
        } else {
            uint256 vestingTimePassed = vestingEndDate - block.timestamp;
            percentige = vestingTimePassed * 100 / vestingDuration;
        }
        return percentige;
    }
}
