// _______              ______  ________   ______   __    __  ________
//  |       \            /      \|        \ /      \ |  \  /  \|        \
//  | $$$$$$$\  ______  |  $$$$$$\\$$$$$$$$|  $$$$$$\| $$ /  $$| $$$$$$$$
//  | $$  | $$ /      \ | $$___\$$  | $$   | $$__| $$| $$/  $$ | $$__
//  | $$  | $$| $$    $$ _\$$$$$$\  | $$   | $$$$$$$$| $$$$$\  | $$$$$
//  | $$__/ $$| $$$$$$$$|  \__| $$  | $$   | $$  | $$| $$ \$$\ | $$_____
//  | $$    $$ \$$     \ \$$    $$  | $$   | $$  | $$| $$  \$$\| $$     \
//  | $$  | $$|  $$$$$$\ \$$    \   | $$   | $$    $$| $$  $$  | $$  \
//   \$$$$$$$   \$$$$$$$  \$$$$$$    \$$    \$$   \$$ \$$   \$$ \$$$$$$$$

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
    error OutOfMinMaxAmount();
    error HardCapReached();
    error UserBlackListed();
    error NoETHProvided();
    error VestingNotStarted();

    // Info for the buyer, the amount of tokens bought and the amount of ETH spent.
    struct Buyer {
        address buyerAddress;
        uint256 tokensBought;
        uint256 ethSpent;
        uint256 tokensClaimed;
    }

    // Token must be transfered to the protocol before the presale starts
    // The token being presaled
    IERC20 public immutable token;

    // Tokens that are for sale during presale
    uint256 public tokenHardCap;

    // Presale start date and duration for the tokens
    uint256 public preSaleStartDate;
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

    // 3% fees for the protocol
    uint256 public protocolFee = 0;

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
        uint256 _vestingDuration,
        uint256 _ethPricePerToken,
        uint256 _protocolFees
    ) Ownable(msg.sender) {
        require(_preSaleStartDate > block.timestamp, "Presale start date must be in the future");
        require(_presaleDuration > 0, "Presale duration must be greater than 0");
        require(_token != address(0), "Invalid token address");
        require(_protocolFeeAddress != address(0), "Invalid protocol fee address");
        require(_vestingDuration > 0, "Vesting duration must be greater than 0");
        require(_ethPricePerToken > 0, "Price per token must be greater than 0");
        require(_protocolFees > 0 && _protocolFees < 100, "Protocol fees must be greater than 0 and less than 100");
        preSaleStartDate = _preSaleStartDate;
        presaleEndDate = preSaleStartDate;
        protocolFeeAddress = _protocolFeeAddress;
        vestingDuration = _vestingDuration;
        ethPricePerToken = _ethPricePerToken;
        protocolFee = _protocolFees;
        token = IERC20(_token);
    }

    /// @notice When a buyer wants to buy tokens he will call this function.
    /// @dev Buyer must send ETH when calling the function.
    /// @dev Requires for the buyer to not be blacklisted and the presale to be active.
    function buyTokens() external payable notBLackListed presaleActive {
        if (msg.value == 0) {
            revert NoETHProvided();
        }
        if (hasStarted) {
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
            revert OutOfMinMaxAmount();
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
        buyer.ethSpent += msg.value - fees;

        buyers[msg.sender] = buyer;

        token.safeTransfer(msg.sender, amount);

        emit TokensPurchased(address(msg.sender), amount);
    }

    /// @notice When a buyer wants to claim his tokens he will call this function.
    /// @notice The buyer can only claim tokens in batches based on the vesting time passed.
    /// @dev Requires for the vesting period to have started.
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

    /// @notice When a buyer wants to exit a presale , or the presale was not succesfull.
    /// @notice The buyer returns the tokens he claimed to the contract and receives the ETH he spent.
    /// @dev Requires that user to have actually spent ETH.
    function withdrawEth() external {
        Buyer memory buyer = buyers[msg.sender];
        require(buyer.ethSpent > 0, "No ETH to withdraw");
        buyer.ethSpent = 0;
        buyers[msg.sender] = buyer;

        if (buyer.tokensClaimed > 0) {
            token.safeTransferFrom(msg.sender, address(this), buyer.tokensClaimed);
        }

        (bool success,) = payable(msg.sender).call{value: buyer.ethSpent}("");
        require(success, "Failed to withdraw ETH");
    }

    /// @notice Owner can withdraw the accumulated fees.
    /// @dev Can be executed only by the owner.
    function withdrawFees() external onlyOwner {
        require(totalFeesAcquired > 0, "No fees to withdraw");
        totalFeesAcquired = 0;
        (bool success,) = payable(protocolFeeAddress).call{value: totalFeesAcquired}("");
        require(success, "Failed to withdraw fees");
    }

    /// @notice Owner can increase duration for the presale, if more tokens are provided or not all were sold.
    /// @dev Can be executed only by the owner and the presale must be active.
    /// @param increasedDuration duration increase variable.
    function increasePresaleDuration(uint256 increasedDuration) external onlyOwner presaleActive {
        require(increasedDuration > 0, "Increase duration must be greater than 0");
        presaleEndDate += increasedDuration;
    }

    /// @notice Owner can increase vesting duration with this function.
    /// @dev Can be executed only by the owner.
    /// @param _increaseVestingDuration vesting duration increase variable.
    function increaseVestingDuration(uint256 _increaseVestingDuration) external onlyOwner {
        require(_increaseVestingDuration > 0, "Increase vesting duration must be greater than 0");

        vestingDuration += _increaseVestingDuration;
    }

    /// @notice Owner can increase the price of the token.
    /// @dev Can be executed only by the owner.
    /// @param _ethPricePerToken New price per token.
    function updateEthPricePerToken(uint256 _ethPricePerToken) external onlyOwner {
        require(_ethPricePerToken > 0, "Price per token must be greater than 0");
        ethPricePerToken = _ethPricePerToken;
    }

    /// @notice Owner can increase the the hard cap of the token.
    /// @dev Can be executed only by the owner and the presale must be active.
    /// @param _tokenHardCapIncrement New hard cap for the token.
    function increaseHardCap(uint256 _tokenHardCapIncrement) external onlyOwner presaleActive {
        require(_tokenHardCapIncrement > tokenHardCap, "Token hard cap must be bigger than before");
        tokenHardCap += _tokenHardCapIncrement;
    }

    /// @notice Owner can blacklist addresses with this function.
    /// @dev Can be executed only by the owner.
    /// @param user The address of the blacklisted user.
    function blackList(address user) external onlyOwner {
        require(user != address(0), "Invalid address");
        require(!blackListedUsers[user], "User is already blacklisted");
        blackListedUsers[user] = true;
    }

    /// @notice Owner can whitelist addresses with this function if they have been blacklisted.
    /// @dev Can be executed only by the owner.
    /// @param user The address of the whitelisted user.
    function whiteList(address user) external onlyOwner {
        require(user != address(0), "Invalid address");
        require(blackListedUsers[user], "User is not blacklisted");
        blackListedUsers[user] = false;
    }

    /// @notice Function to check if presale has started.
    /// @dev Can be executed by anyone.
    function hasPresaleStarted() public returns (bool) {
        if (hasPresaleEnded()) {
            return false;
        }
        if (hasStarted) {
            return true;
        }
        if (preSaleStartDate < block.timestamp && presaleEndDate > block.timestamp) {
            hasStarted = true;
            return true;
        }
        return false;
    }

    /// @notice Function to check if presale has ended.
    /// @dev Can be executed by anyone.
    function hasPresaleEnded() public returns (bool) {
        if (hasEnded) {
            return true;
        }
        if (presaleEndDate < block.timestamp) {
            hasEnded = true;
            return true;
        }else {
            return false;
        }
    }

    /// @notice Function to check the amount of ETH raised by the presale.
    /// @dev Can be executed only by the owner.
    function amountETHRaised() external view onlyOwner returns (uint256) {
        return totalEthRaised;
    }

    /// @notice Function to check the price of a token.
    /// @dev Can be executed by anyone.
    function getTokenPrice() external view returns (uint256) {
        return ethPricePerToken;
    }

    /// @notice Function to check the tokens already sold.
    /// @dev Can be executed only by the owner.
    function tokensSold() external view onlyOwner returns (uint256) {
        return totalTokensSold;
    }

    /// @notice Function to check if the vesting period is over.
    /// @dev Can be executed by anyone.
    function isVestingDurationOver() public view returns (bool) {
        return block.timestamp > presaleEndDate + vestingDuration;
    }

    /// @notice Function to check the amount of tokens a user can buy for certain amount of ETH.
    /// @dev Can be executed by anyone.
    /// @param ethAmount The amount of ETH the buyer wants to spend.
    function calculateTokensBought(uint256 ethAmount) external view returns (uint256) {
        return ethAmount / ethPricePerToken;
    }

    /// @notice Function to calculate the percentige of tokens that can be claimed at any point in time.
    /// @dev Can be executed by anyone.
    function getClaimablePercentige() private view returns (uint256) {
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