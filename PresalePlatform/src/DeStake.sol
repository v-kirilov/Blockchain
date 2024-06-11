// _______              ______  ________   ______   __    __  ________
//  |       \            /      \|        \ /      \ |  \  /  \|        \
//  | $$$$$$$\  ______  |  $$$$$$\\$$$$$$$$|  $$$$$$\| $$ /  $$| $$$$$$$$
//  | $$  | $$ /      \ | $$___\$$  | $$   | $$__| $$| $$/  $$ | $$__
//  | $$  | $$| $$    $$ _\$$$$$$\  | $$   | $$$$$$$$| $$$$$\  | $$$$$
//  | $$__/ $$| $$$$$$$$|  \__| $$  | $$   | $$  | $$| $$ \$$\ | $$_____
//  | $$    $$ \$$     \ \$$    $$  | $$   | $$  | $$| $$  \$$\| $$     \
//  | $$  | $$|  $$$$$$\ \$$    \   | $$   | $$    $$| $$  $$  | $$  \
//   \$$$$$$$   \$$$$$$$  \$$$$$$    \$$    \$$   \$$ \$$   \$$ \$$$$$$$$

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
//node_modules\@uniswap\v3-core\contracts\interfaces\IUniswapV3Factory.sol
import {Test, console} from "forge-std/Test.sol";

/*
 * @title DeStake
 * @author Viktor Kirilov
 *
 * The system is designed to be as minimal as possible.
 * This is a contract design for holding presale of tokens:
 * - For every staking pool there will be a separate contract deployed.
 *
 *
 * @notice This contract is based on the best practises of a staking presale contract.
 */
//! USE WETH!
contract DeStake is Ownable, Test {
    ///-///-///-///
    // Errors
    ///-///-///-///
    error NotPossible();
    error PresaleOver();
    error PresaleNotStarted();
    error OutOfMinMaxAmount();
    error HardCapReached();
    error UserBlackListed();
    error NoETHProvided();
    error VestingNotStarted();

    ///-///-///-///
    // Types
    ///-///-///-///
    using SafeERC20 for IERC20;

    ///-///-///-///
    // State Variables
    ///-///-///-///
    // Info for the buyer, the amount of tokens bought and the amount of ETH spent.
    struct Buyer {
        address buyerAddress;
        uint256 tokensBought;
        uint256 ethSpent;
        uint256 tokensClaimed;
    }

    // The token being presaled
    IERC20 public immutable token;
    // Uniswap factory contract address on mainnet
    IUniswapV3Factory public factory = IUniswapV3Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    //0xB7f907f7A9eBC822a80BD25E224be42Ce0A698A0 - Sepolia for testing purposes
    //WEH address
    address immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // The address of the Uniswap pair, if the liquidity phase is active should be different than address 0.
    address public uniswapPairAddress;

    // Amount of tokens that are for sale during presale
    uint256 public tokenHardCap;

    // Presale start date and duration for the tokens
    uint256 public preSaleStartDate;
    uint256 public presaleEndDate;

    // Vesting duration after the presale period is over
    uint256 public vestingDuration;

    // Percentige of takens that can be claimed at any point in time
    uint256 claimableTokensPercentige;

    // Price of the token in ETH, which can be change later on depenging on the presale status
    uint256 public ethPricePerToken;

    // Booleans to keep track of the presale status
    bool private hasStarted;
    bool private hasEnded;

    // After the presale is over, the liquidity phase can be started.
    bool private isLiquidityPhaseActive;

    // Fees for the protocol
    uint256 public protocolFee = 0;

    // Min and max token buy per buyer address (can be curcemvented by buyer using multiple addresses)
    uint256 public minTokenBuy;
    uint256 public maxTokenBuy;

    // The address for the protocol fees
    address public protocolFeeAddress;

    // To keep track of the total ETH raised during the presale.
    uint256 private totalEthRaised;

    // The amount of tokens sold.
    uint256 private totalTokensSold;

    // The amount of acquired fees.
    uint256 private totalFeesAcquired;

    // The address of the Uniswap pair, if the liquidity phase is active.
    address public uniswapPair;

    // Mapping to store the buyers.
    mapping(address buyerAddress => Buyer buyers) public buyers;
    // Mapping to store the blacklisted users.
    mapping(address blacklisted => bool isBlackListed) public blackListedUsers;

    ///-///-///-///
    // Events
    ///-///-///-///
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

    ///-///-///-///
    // Modifiers
    ///-///-///-///
    modifier notBLackListed() {
        if (blackListedUsers[msg.sender]) {
            revert UserBlackListed();
        }
        _;
    }

    modifier presaleActive() {
        if (hasPresaleEnded()) {
            revert PresaleOver();
        }
        if (!hasPresaleStarted()) {
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

    ///-///-///-///
    // Functions
    ///-///-///-///
    constructor(
        uint256 _preSaleStartDate,
        uint256 _presaleEndDate,
        address _token,
        address _protocolFeeAddress,
        uint256 _vestingDuration,
        uint256 _ethPricePerToken,
        uint256 _protocolFees,
        uint256 _minTokenBuy,
        uint256 _maxTokenBuy,
        uint256 _tokenHardCap
    ) Ownable(msg.sender) {
        require(_preSaleStartDate > block.timestamp, "Presale start date must be in the future");
        require(_presaleEndDate > _preSaleStartDate, "Presale end date not correct");
        require(_token != address(0), "Invalid token address");
        require(_protocolFeeAddress != address(0), "Invalid protocol fee address");
        require(_vestingDuration > 0, "Vesting duration must be greater than 0");
        require(_ethPricePerToken > 0, "Price per token must be greater than 0");
        require(_protocolFees > 0 && _protocolFees < 100, "Protocol fees must be greater than 0 and less than 100");
        preSaleStartDate = _preSaleStartDate;
        presaleEndDate = _presaleEndDate;
        protocolFeeAddress = _protocolFeeAddress;
        vestingDuration = _vestingDuration;
        ethPricePerToken = _ethPricePerToken;
        protocolFee = _protocolFees;
        minTokenBuy = _minTokenBuy;
        maxTokenBuy = _maxTokenBuy;
        tokenHardCap = _tokenHardCap;
        token = IERC20(_token);
    }

    ///-///-///-///
    // External Functions
    ///-///-///-///
    /// @notice When a buyer wants to buy tokens he will call this function.
    /// @dev Buyer must send ETH when calling the function.
    /// @dev Requires for the buyer to not be blacklisted and the presale to be active.
    function buyTokens() external payable notBLackListed presaleActive {
        if (msg.value == 0) {
            revert NoETHProvided();
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
        require(!isLiquidityPhaseActive, "Liquidity phase is active");
        Buyer memory buyer = buyers[msg.sender];
        uint256 claimed = buyer.tokensClaimed;
        require(buyer.ethSpent > 0, "No ETH to withdraw");
        uint256 spent = buyer.ethSpent;
        buyer.ethSpent = 0;
        buyer.tokensClaimed = 0;
        buyers[msg.sender] = buyer;

        if (claimed > 0) {
            token.safeTransferFrom(msg.sender, address(this), claimed);
        }

        (bool success,) = payable(msg.sender).call{value: spent}("");
        require(success, "Failed to withdraw ETH");
        emit ETHWithdrawn(msg.sender, spent);
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
        emit PresaleDurationIncreased(increasedDuration);
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
        emit TokenPriceUpdated(_ethPricePerToken);
    }

    /// @notice Owner can increase the hard cap of the token.
    /// @dev Can be executed only by the owner and the presale must be active.
    /// @param _tokenHardCapIncrement New hard cap for the token.
    function increaseHardCap(uint256 _tokenHardCapIncrement) external onlyOwner presaleActive {
        require(_tokenHardCapIncrement > 0, "<=0");
        tokenHardCap += _tokenHardCapIncrement;
        emit HardCapIncreased(tokenHardCap);
    }

    /// @notice Owner can blacklist addresses with this function.
    /// @dev Can be executed only by the owner.
    /// @param user The address of the blacklisted user.
    function blackList(address user) external onlyOwner {
        require(user != address(0), "Invalid address");
        require(!blackListedUsers[user], "User is already blacklisted");
        blackListedUsers[user] = true;
        emit UserIsBlackListed(user);
    }

    /// @notice Owner can whitelist addresses with this function if they have been blacklisted.
    /// @dev Can be executed only by the owner.
    /// @param user The address of the whitelisted user.
    function whiteList(address user) external onlyOwner {
        require(user != address(0), "Invalid address");
        require(blackListedUsers[user], "User is not blacklisted");
        blackListedUsers[user] = false;
        emit UserIsWhiteListed(user);
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

    /// @notice Function to check the amount of tokens a user can buy for certain amount of ETH.
    /// @dev Can be executed by anyone.
    /// @param ethAmount The amount of ETH the buyer wants to spend.
    function calculateTokensBought(uint256 ethAmount) external view returns (uint256) {
        return ethAmount / ethPricePerToken;
    }

    function checkTokenLiquidityPhase() external view returns (bool) {
        return isLiquidityPhaseActive;
    }

    /// @notice Function to set the liquidity phase, possible only if liquidity is provided for a Uniswap pair.
    /// @dev getPool function from the UniswapV3Factory contract is used to get the address of the Uniswap pair.
    /// @dev if the pair is existing it will return the address of the pair, otherwise it will return address 0.
    /// @dev Can be executed by the owner of the contract only.
    /// @param _uniswapPairAddress The addres for the uniswap factory.
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip.
    function activateLiquidityPhase(address _uniswapPairAddress, uint24 fee) external onlyOwner {
        address tokenSwapAddress = factory.getPool(address(token), WETH, fee);
        require(tokenSwapAddress != address(0), "Pair not found");
        require(tokenSwapAddress == _uniswapPairAddress, "Invalid pair address");
        uniswapPairAddress = _uniswapPairAddress;
        isLiquidityPhaseActive = true;
    }

    /// @notice Function to set the uniswapv3 factory address.
    /// @dev Can be executed by the owner of the contract only.
    /// @param uniSwapAddress The addres for the uniswap factory.
    function setUniswapFactoryAddres(address uniSwapAddress)  external onlyOwner {
        require(uniSwapAddress != address(0), "Invalid address");
        factory = IUniswapV3Factory(uniSwapAddress);
    }

    function getTokensBoughtByUser(address user) external view returns (uint256) {
        return buyers[user].tokensBought;
    }

    function getETHSpentByUser(address user) external view returns (uint256) {
        return buyers[user].ethSpent;
    }

    ///-///-///-///
    // Public Functions
    ///-///-///-///
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
            emit PresaleStarted();
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
            emit PresaleEnded();
            return true;
        } else {
            return false;
        }
    }

    /// @notice Function to check if the vesting period is over.
    /// @dev Can be executed by anyone.
    function isVestingDurationOver() public view returns (bool) {
        return block.timestamp > presaleEndDate + vestingDuration;
    }

    ///-///-///-///
    // Private Functions
    ///-///-///-///
    /// @notice Function to calculate the percentige of tokens that can be claimed at any point in time.
    /// @dev Can be executed by anyone.
    function getClaimablePercentige() private view returns (uint256) {
        require(block.timestamp > presaleEndDate, "Presale is not over yet");
        uint256 vestingEndDate = presaleEndDate + vestingDuration;
        uint256 percentige;
        if (block.timestamp > presaleEndDate + vestingDuration) {
            percentige = 100;
        } else {
            uint256 vestingTimePassed = block.timestamp - presaleEndDate;
            percentige = vestingTimePassed * 100 / (presaleEndDate + vestingDuration);
        }
        return percentige;
    }
}
