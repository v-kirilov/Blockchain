// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/*=========================================================================*
 * ██████╗ ███████╗██████╗ ██████╗ ███████╗    ███╗   ███╗██╗  ██╗████████╗
 * ██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝    ████╗ ████║██║ ██╔╝╚══██╔══╝
 * ██████╔╝█████╗  ██████╔╝██████╔╝███████╗    ██╔████╔██║█████╔╝    ██║
 * ██╔═══╝ ██╔══╝  ██╔══██╗██╔═══╝ ╚════██║    ██║╚██╔╝██║██╔═██╗    ██║
 * ██║     ███████╗██║  ██║██║     ███████║    ██║ ╚═╝ ██║██║  ██╗   ██║
 * ╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝
 * A Decentralized Perpetual Exchange Market
 *=========================================================================*/

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./Interfaces/IPPCampaign.sol";
import "./VPriceFeed.sol";

contract PerpsMarket is Ownable, Pausable {
    ///-///-///-///
    // Errors
    ///-///-///-///
    error NotPossible();
    error UserBlackListed();
    error NoETHProvided();
    error PositionAmountIsTooSmall();
    error LeverageExceded();
    error PositionNotExisting();
    error NoProfit();
    error TransferFailed();
    error ZeroAddress();
    error CampaignNotSet();

    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private usersWithPositions;

    ///-///-///-///
    // State Variables
    ///-///-///-///
    struct Position {
        address user;
        uint256 amountDeposited;
        uint256 positionAmount;
        PositionType positionType;
        uint256 positionEntryPrice;
        uint256 positionLiquidationPrice;
        uint256 positionLeverage;
    }

    enum PositionType {
        LONG,
        SHORT
    }

    VPriceFeed public PriceFeed;
    uint32 private constant MAX_BIPS_LEVERAGE = 30_000; // 3x
    uint32 private constant TO_BIPS = 10_000;
    uint32 public Fee = 100; // 1%
    uint64 public constant MIN_POSITION_AMOUNT = 0.001 ether;

    uint256 private accumulatedFees;
    uint256 public lastUpdatedTimestamp;
    uint256 private accumulatedLongPositionAmount;
    uint256 private accumulatedShortPositionAmount;
    address private feeCollector;

    IPPCampaign private ppCampaign;
    IERC20 private feePrizeToken;
    bool private isCampaignActive;

    mapping(address user => bool isBlacklisted) public blackListedUsers;
    //Need it to have it in enumerable set, only 32 byte variables are allowed in the set
    mapping(address user => Position) public positions;
    mapping(address user => uint256 profit) public positionProfit;

    ///-///-///-///
    // Events
    ///-///-///-///
    event PositionOpened(address indexed user, uint256 indexed deposited, uint256 indexed positionAmount, bool isLong);
    event PositionLiquidated(
        address indexed user, uint256 indexed positionAmount, uint256 indexed ethPrice, uint256 positionEntryPrice
    );
    event PositionClosed(address indexed user, uint256 indexed profit);

    ///-///-///-///
    // Modifiers
    ///-///-///-///
    modifier notBLackListed() {
        if (blackListedUsers[msg.sender]) {
            revert UserBlackListed();
        }
        _;
    }

    /// @notice Constructor for the contract
    /// @param _feeCollector the address where the fees will be collected
    /// @param _campaignAddress the address of the campaign contract
    /// @param _feePrizeToken the address of the prize token that will be used for fees and prizes
    constructor(address _feeCollector, address _campaignAddress, address _feePrizeToken, address _priceFeed)
        Ownable(msg.sender)
    {
        if (_feeCollector == address(0) || _feePrizeToken == address(0) || _priceFeed == address(0)) {
            revert ZeroAddress();
        }
        PriceFeed = VPriceFeed(_priceFeed);
        feeCollector = _feeCollector;
        ppCampaign = IPPCampaign(_campaignAddress);
        feePrizeToken = IERC20(_feePrizeToken);
    }

    ///-///-///-///
    //  Public functions
    ///-///-///-///

    /// @notice Function to update a position
    /// @param deposit The amount deposited to update a position

    function updatePositions(uint256 deposit) public {
        lastUpdatedTimestamp = block.timestamp;
        //Update positions

        //Get position
        Position memory position = positions[msg.sender];

        //Get price
        int256 ethPrice = PriceFeed.getChainlinkDataFeedLatestAnswer();

        uint256 newAmount = position.amountDeposited + deposit;
        position.amountDeposited += newAmount;
        position.positionLeverage = calculatePositionLeverage(newAmount, position.amountDeposited);
        int256 updatedPositionEntryPrice = calculateUpdatedPositionEntryPrice(
            position.amountDeposited, int256(position.positionEntryPrice), newAmount, ethPrice
        );
        uint256 oldPositionEntryPrice = position.positionEntryPrice;
        position.positionEntryPrice = uint256(updatedPositionEntryPrice);
        uint256 newLiquidationPrice;

        // update  liquidation price
        newLiquidationPrice =
            calculatePositionLiquidationPrice(oldPositionEntryPrice, position.positionLeverage, position.positionType);

        position.positionLiquidationPrice = newLiquidationPrice;

        //Save updated position
        positions[msg.sender] = position;
    }

    /// @notice Function to liquidate a position
    /// @param positionOwner The address of the position owner
    /// @notice Can be called by anyone

    function liquidatePosition(address positionOwner) public {
        //Get position
        Position memory position = positions[positionOwner];
        address liquidator = msg.sender;
        if (position.positionEntryPrice == 0) {
            revert PositionNotExisting();
        }
        //check if position is liquideable
        int256 ethPrice = PriceFeed.getChainlinkDataFeedLatestAnswer();
        if (position.positionType == PositionType.LONG && uint256(ethPrice) > position.positionLiquidationPrice) {
            revert NotPossible();
        } else if (position.positionType == PositionType.SHORT && uint256(ethPrice) < position.positionLiquidationPrice)
        {
            revert NotPossible();
        }
        // Give half of fee to liquidator
        uint256 fees = calculateFeesForPosition(position.positionAmount);
        positionProfit[liquidator] += uint256(fees / 2);

        //delete position
        usersWithPositions.remove(positionOwner);
        // null the position
        delete positions[positionOwner];

        //Reduce accumulated position
        position.positionType == PositionType.LONG
            ? accumulatedLongPositionAmount -= position.positionAmount
            : accumulatedShortPositionAmount -= position.positionAmount;
    }

    function isLiquidated(Position memory position, int256 profitInETHBeforeFees)
        internal
        pure
        returns (bool isGettingLiquidated)
    {
        if (profitInETHBeforeFees < 0) {
            if (uint256(-profitInETHBeforeFees) > position.amountDeposited) {
                return true;
            }
        }
        return isGettingLiquidated;
    }

    /// @notice Function to close a position
    /// @notice Called by the position owner

    function closePosition() public {
        address user = msg.sender;
        if (!usersWithPositions.contains(user)) {
            revert PositionNotExisting();
        }
        //get price
        uint256 ethPrice = uint256(PriceFeed.getChainlinkDataFeedLatestAnswer());

        //get position
        Position memory position = positions[user];

        if (position.positionAmount == 0) {
            revert PositionNotExisting();
        }
        //calculate profit
        int256 profitInETHBeforeFees = calculateProfitInETH(position, ethPrice);

        // Pay with prize token if user has enough balance or pay with ETH
        uint256 profit;
        uint256 userBalanceInPPToken = feePrizeToken.balanceOf(user);
        uint256 marketAllowance = feePrizeToken.allowance(user, address(this));

        bool isWin;
        if (profitInETHBeforeFees <= 0) {
            // liquidated
            if (isLiquidated(position, profitInETHBeforeFees)) {
                position.positionAmount = 0;
                position.amountDeposited = 0;
                position.positionEntryPrice = 0;
                position.positionLiquidationPrice = 0;
                position.positionLeverage = 0;
                positions[user] = position;
                emit PositionLiquidated(user, position.positionAmount, ethPrice, position.positionEntryPrice);
                return;
            } else {
                // Calculate the loss and reduce from deposited amount
                profit = uint256((-profitInETHBeforeFees));

                isWin = false;
            }
        } else {
            profit = uint256(profitInETHBeforeFees);
            isWin = true;
        }
        uint256 fees = calculateFeesForPosition(profit);

        uint256 amountFeesToPayWithPrizeToken = (fees * ethPrice) / 1e24;

        if (userBalanceInPPToken > amountFeesToPayWithPrizeToken && marketAllowance >= amountFeesToPayWithPrizeToken) {
            // Pay fee with token
            feePrizeToken.transferFrom(user, feeCollector, amountFeesToPayWithPrizeToken);
        } else {
            // Pay fee with ETH
            accumulatedFees += fees;
            if (isWin) {
                profit = uint256(profitInETHBeforeFees) - fees;
            } else {
                profit = uint256(-profitInETHBeforeFees) - fees;
            }
        }

        //Remove user from positions
        usersWithPositions.remove(user);

        //Save profit in positionProfit mapping
        // Save profit in mapping , if it is loquidated , dont save profit, close position only
        if (!isWin) {
            positionProfit[user] = position.amountDeposited - profit;
        } else {
            positionProfit[user] += profit + position.amountDeposited;
        }
        if (isCampaignActive && isWin) {
            ppCampaign.upSertParticipant(user, profit);
        }

        position.positionAmount = 0;
        position.amountDeposited = 0;
        position.positionEntryPrice = 0;
        position.positionLiquidationPrice = 0;
        position.positionLeverage = 0;
        positions[user] = position;

        //Reduce accumulated position
        position.positionType == PositionType.LONG
            ? accumulatedLongPositionAmount -= position.positionAmount
            : accumulatedShortPositionAmount -= position.positionAmount;
    }

    ///-///-///-///
    //  Private functions
    ///-///-///-///

    /// @notice Function to calculate a position's leverage
    /// @param positionAmount Current position amount
    /// @param deposited Amount deposited
    /// @return leverageBips Leverage in basis points

    function calculatePositionLeverage(uint256 positionAmount, uint256 deposited) private pure returns (uint256) {
        if (deposited >= positionAmount) {
            //no leverage
            return 0;
        }
        uint256 leverageBips = (positionAmount * TO_BIPS) / deposited;
        if (leverageBips > MAX_BIPS_LEVERAGE) {
            revert LeverageExceded();
        }
        return leverageBips;
    }

    /// @notice Function to calculate a position's profit
    /// @param position Current position of user
    /// @param ethPrice Price of ETH in USD
    /// @return profitInETH Profit in ETH

    function calculateProfitInETH(Position memory position, uint256 ethPrice)
        private
        pure
        returns (int256 profitInETH)
    {
        uint256 positionEntryPrice = position.positionEntryPrice;
        int256 profitInUsd;
        if (position.positionType == PositionType.LONG) {
            if (positionEntryPrice > ethPrice) {
                // Loosing long position
                profitInUsd = -int256((positionEntryPrice - ethPrice) * position.positionLeverage) / 1e4;
            } else {
                profitInUsd = int256((ethPrice - positionEntryPrice) * position.positionLeverage) / 1e4;
            }
        } else {
            //short
            if (positionEntryPrice < ethPrice) {
                // Short and loosing
                profitInUsd = -int256((ethPrice - positionEntryPrice) * position.positionLeverage) / 1e4;
            } else {
                //Short and winning
                profitInUsd = int256((positionEntryPrice - ethPrice) * position.positionLeverage) / 1e4;
            }
        }
        profitInETH = (1e18 * profitInUsd) / int256(ethPrice);
        // -2040_80000000
    }

    /// @notice Function to calculate fee for a position
    /// @param positionAmount Amount of the position
    /// @return uint256 Position's fee

    function calculateFeesForPosition(uint256 positionAmount) private view returns (uint256) {
        return (positionAmount * Fee) / TO_BIPS;
    }

    function calculatePositionLiquidationPrice(
        uint256 positionEntryPrice,
        uint256 positionLeverage,
        PositionType positionType
    ) private pure returns (uint256) {
        if (positionLeverage == 0) {
            if (positionType == PositionType.LONG) {
                return 0;
            }
            return type(uint256).max;
        }
        if (
            positionType == PositionType.LONG && (TO_BIPS * positionEntryPrice) / positionLeverage >= positionEntryPrice
        ) {
            return 0;
        }
        if (positionType == PositionType.LONG) {
            return positionEntryPrice - ((TO_BIPS * positionEntryPrice) / positionLeverage);
        }
        return positionEntryPrice + ((TO_BIPS * positionEntryPrice) / positionLeverage);
    }

    /// @notice Function to calculate the new position entry price after updating a position
    /// @param oldAmout Old amout for position
    /// @param oldPrice Old price at which the position was opened
    /// @param newAmount New amout for the position
    /// @param newPrice New price at which the position is updated
    /// @return newPrice New position's entry price

    function calculateUpdatedPositionEntryPrice(uint256 oldAmout, int256 oldPrice, uint256 newAmount, int256 newPrice)
        private
        pure
        returns (int256)
    {
        return ((int256(oldAmout) * oldPrice) + (int256(newAmount) * newPrice)) / int256(oldAmout + newAmount);
    }

    ///-///-///-///
    //  External functions
    ///-///-///-///

    /// @notice Function to withdraw profit from a position
    /// @notice Can be called only by the position owner
    /// @dev Position is updated with new properties
    //! MAKE SURE IT IS NOT LIQUIDATABLE AFTER WITHDRAWING PROFIT

    function withdrawProfit() external whenNotPaused {
        address user = msg.sender;
        uint256 profit = positionProfit[user];
        require(profit > 0, NoProfit());
        positionProfit[user] = 0;

        (bool success,) = user.call{value: uint256(profit)}("");
        require(success, TransferFailed());
    }

    function openPosition(uint256 amount, bool isLong) external payable notBLackListed whenNotPaused {
        PositionType positionType = isLong ? PositionType.LONG : PositionType.SHORT;
        uint256 amountDeposited = msg.value;
        address depositor = msg.sender;

        if (amountDeposited == 0) {
            revert NoETHProvided();
        }
        if (amount < MIN_POSITION_AMOUNT) {
            revert PositionAmountIsTooSmall();
        }
        //Fetch ETH price
        uint256 ethPrice = uint256(PriceFeed.getChainlinkDataFeedLatestAnswer());

        // calculate fees
        uint256 amountDepositedMinusFees;
        uint256 fees = calculateFeesForPosition(amount);
        // Pay with prize token if user has enough balance or pay with ETH
        uint256 userBalance = feePrizeToken.balanceOf(depositor);

        uint256 marketAllowance = feePrizeToken.allowance(depositor, address(this));

        uint256 amountToPayWithPrizeToken = (fees * ethPrice) / 1e24;
        bool isSuccess;
        if (userBalance > amountToPayWithPrizeToken && marketAllowance >= amountToPayWithPrizeToken) {
            isSuccess = feePrizeToken.transferFrom(depositor, feeCollector, amountToPayWithPrizeToken);
        }

        if (isSuccess) {
            amountDepositedMinusFees = amountDeposited;
        } else {
            accumulatedFees += fees;
            amountDepositedMinusFees = amountDeposited - fees;
        }

        // Check position size
        uint256 leverage = calculatePositionLeverage(amount, amountDepositedMinusFees);
        uint256 positionLiquidationPrice = calculatePositionLiquidationPrice(ethPrice, leverage, positionType);

        Position memory newPosition = Position({
            user: depositor,
            amountDeposited: amountDepositedMinusFees,
            positionAmount: amount,
            positionType: positionType,
            positionEntryPrice: ethPrice,
            positionLiquidationPrice: positionLiquidationPrice,
            positionLeverage: leverage
        });

        //Save accumulated position amount
        positionType == PositionType.LONG
            ? accumulatedLongPositionAmount += amount
            : accumulatedShortPositionAmount += amount;

        //Save position
        positions[depositor] = newPosition;
        usersWithPositions.add(depositor);

        emit PositionOpened(depositor, amountDeposited, amount, isLong);
    }

    /// @notice Function to set the address of the new campaign contract
    /// @param  _campaignAddress The address of the new campaign contract
    /// @dev Callable only by the owner of the contract and sets the new campaign address

    function setNewCampaignAddress(address _campaignAddress) external onlyOwner {
        if (_campaignAddress == address(0)) {
            revert ZeroAddress();
        }
        ppCampaign = IPPCampaign(_campaignAddress);
    }

    /// @notice Function to set the address of the new collector address
    /// @param  _feeCollector The address of the new collector
    /// @dev Callable only by the owner of the contract and sets the new campaign address

    function setNewFeeCollectorAddress(address _feeCollector) external onlyOwner {
        if (_feeCollector == address(0)) {
            revert ZeroAddress();
        }
        feeCollector = _feeCollector;
    }

    /// @notice Function to get a certain position
    /// @param  positionAddress The address of the position
    /// @return Position The position struct of the user
    function getPosition(address positionAddress) external view returns (Position memory) {
        return positions[positionAddress];
    }

    /// @notice Returns the users with positions
    /// @dev This is an expensive function , can use up too much gas to fit a block
    /// @return address[] All users with positions
    function getUsersWithPositions() external view returns (address[] memory) {
        return usersWithPositions.values();
    }

    /// @notice Function to start a campaign
    /// @dev Starts a campaign in PPCampaign contract and sets the isCampaignActive flag to true
    function startCampaign() external onlyOwner {
        if (address(ppCampaign) == address(0)) {
            revert CampaignNotSet();
        }
        ppCampaign.startCampaign();
        isCampaignActive = true;
    }

    /// @notice Function to end a campaign
    /// @dev Ends a campaign in PPCampaign contract and sets the isCampaignActive flag to false
    function endCampaign() external onlyOwner {
        if (address(ppCampaign) == address(0)) {
            revert CampaignNotSet();
        }
        ppCampaign.endCampaign();
        isCampaignActive = false;
    }

    /// @notice Function to blacklist a user
    /// @param  userToBlackList The address of the position
    function blackListUser(address userToBlackList) external onlyOwner {
        blackListedUsers[userToBlackList] = true;
    }

    /// @notice Function to check if a campaign is active
    /// @return bool Returns a bool signaling if the campaign is active or not
    /// @dev Checks if camapign is active and updates the state in this contract
    function checkIfCampaignActive() external returns (bool) {
        if (address(ppCampaign) == address(0)) {
            revert CampaignNotSet();
        }
        if (ppCampaign.isCampaignActive()) {
            isCampaignActive = true;
            return true;
        }
        isCampaignActive = false;
        return false;
    }
}

//! update all positions , check if they are eligible for liquidation

//! 1. Who creates the campaign contract?
//! 3. Add stable coin for the prize token?
