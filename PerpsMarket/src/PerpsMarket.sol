// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces/IPPCampaign.sol";
import "./VPriceFeed.sol";

contract PerpsMarket is Ownable {
    ///-///-///-///
    // Errors
    ///-///-///-///
    error NotPossible();
    error UserBlackListed();
    error NoETHProvided();
    error LeverageExceded();
    error PositionNotExisting();
    error PositionAmountIsTooSmall();
    error NoProfit();
    error TransferFailed();
    error ZeroAddress();

    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private usersWithPositions;

    ///-///-///-///
    // State Variables
    ///-///-///-///
    //
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
    uint32 public Fee = 1000; // 1%
    uint64 public constant MIN_POSITION_AMOUNT = 0.01 ether;

    uint256 private accumulatedFees;
    uint256 public lastUpdatedTimestamp;
    uint256 private accumulatedLongPositionAmount;
    uint256 private accumulatedShortPositionAmount;
    address private feeCollector;

    IPPCampaign private ppCampaign;

    mapping(address user => bool isBlacklisted) public blackListedUsers;
    //Need it to have it in enumerable set, only 32 byte variables are allowed in the set
    mapping(address user => Position) public positions;
    mapping(address user => uint256 profit) public positionProfit;

    ///-///-///-///
    // Modifiers
    ///-///-///-///
    modifier notBLackListed() {
        if (blackListedUsers[msg.sender]) {
            revert UserBlackListed();
        }
        _;
    }

    constructor(address _feeCollector, address _campaignAddress) Ownable(msg.sender) {
        if (_feeCollector == address(0) || _campaignAddress == address(0)) {
            revert ZeroAddress();
        }

        feeCollector = _feeCollector;
        ppCampaign =  IPPCampaign(_campaignAddress);
    }

    function updatePositions(uint256 deposit, PositionType positionType) public {
        lastUpdatedTimestamp = block.timestamp;
        //Update positions

        //Get position
        Position memory position = positions[msg.sender];

        if (position.positionType != positionType) {
            revert NotPossible();
        }

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
            calculatePositionLiquidationPrice(oldPositionEntryPrice, position.positionLeverage, positionType);

        position.positionLiquidationPrice = newLiquidationPrice;

        //Save updated position
        positions[msg.sender] = position;
    }

    function liquidatePosition(address positionOwner) public {
        //Get position
        Position memory position = positions[positionOwner];
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
        positionProfit[msg.sender] += uint256(fees / 2);

        //delete position
        usersWithPositions.remove(positionOwner);
        // null the position
        delete positions[positionOwner];

        //Reduce accumulated position
        position.positionType == PositionType.LONG
            ? accumulatedLongPositionAmount -= position.positionAmount
            : accumulatedShortPositionAmount -= position.positionAmount;
    }

    function closePosition() public {
        if (!usersWithPositions.contains(msg.sender)) {
            revert PositionNotExisting();
        }
        //get price
        int256 ethPrice = PriceFeed.getChainlinkDataFeedLatestAnswer();

        //get position
        Position memory position = positions[msg.sender];
        //calculate profit
        int256 profitBeforeFees = calculateProfit(position, uint256(ethPrice));

        //calculate fees
        uint256 fees = calculateFeesForPosition(position.positionAmount);
        uint256 profit = uint256(profitBeforeFees) - fees;
        accumulatedFees += fees;
        //Remove user from positions
        usersWithPositions.remove(msg.sender);

        //Save profit in positionProfit mapping
        if (profit > 0) {
            positionProfit[msg.sender] += uint256(profit);
        }
        position.positionAmount = 0;
        position.amountDeposited = 0;
        position.positionEntryPrice = 0;
        position.positionLiquidationPrice = 0;
        position.positionLeverage = 0;
        positions[msg.sender] = position;

        //Reduce accumulated position
        position.positionType == PositionType.LONG
            ? accumulatedLongPositionAmount -= position.positionAmount
            : accumulatedShortPositionAmount -= position.positionAmount;
    }

    function withdrawProfit() external {
        uint256 profit = positionProfit[msg.sender];
        require(profit > 0, NoProfit());
        positionProfit[msg.sender] = 0;

        (bool success,) = msg.sender.call{value: uint256(profit)}("");
        require(success, TransferFailed());
    }

    function openPosition(uint256 amount, PositionType positionType) external payable notBLackListed {
        if (msg.value == 0) {
            revert NoETHProvided();
        }
        if (amount < MIN_POSITION_AMOUNT) {
            revert PositionAmountIsTooSmall();
        }
        // calculate fees
        uint256 fees = calculateFeesForPosition(amount);
        accumulatedFees += fees;
        uint256 amountDepositedMinusFees = msg.value - fees;

        // Check position size
        int256 ethPrice = PriceFeed.getChainlinkDataFeedLatestAnswer();
        uint256 leverage = calculatePositionLeverage(amount, amountDepositedMinusFees);
        uint256 positionLiquidationPrice = calculatePositionLiquidationPrice(uint256(ethPrice), leverage, positionType);

        Position memory newPosition = Position({
            user: msg.sender,
            amountDeposited: amountDepositedMinusFees,
            positionAmount: amount,
            positionType: positionType,
            positionEntryPrice: uint256(ethPrice),
            positionLiquidationPrice: positionLiquidationPrice,
            positionLeverage: leverage
        });

        //Save accumulated position amount
        positionType == PositionType.LONG
            ? accumulatedLongPositionAmount += amount
            : accumulatedShortPositionAmount += amount;

        //Save position
        positions[msg.sender] = newPosition;
        usersWithPositions.add(msg.sender);
    }

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

    function calculateProfit(Position memory position, uint256 ethPrice) private pure returns (int256 profitInUsd) {
        uint256 positionEntryPrice = position.positionEntryPrice;
        if (position.positionType == PositionType.LONG) {
            if (positionEntryPrice > ethPrice) {
                profitInUsd = int256((positionEntryPrice - ethPrice) * position.positionLeverage) / 1e8 / 1e3;
            } else {
                profitInUsd = -int256((ethPrice - positionEntryPrice) * position.positionLeverage) / 1e8 / 1e3;
            }
        }
        //short
        if (positionEntryPrice < ethPrice) {
            profitInUsd = -int256((ethPrice - positionEntryPrice) * position.positionLeverage) / 1e8 / 1e3;
        } else {
            profitInUsd = int256((positionEntryPrice - ethPrice) * position.positionLeverage) / 1e8 / 1e3;
        }
    }

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

    function setNewCampaignAddress(address _campaignAddress) external onlyOwner {
        if (_campaignAddress == address(0)) {
            revert ZeroAddress();
        }
        ppCampaign =IPPCampaign(_campaignAddress) ;
    }

    function setNewFeeCollectorAddress(address _feeCollector) external onlyOwner {
        if (_feeCollector == address(0)) {
            revert ZeroAddress();
        }
        feeCollector = _feeCollector;
    }

    function calculateUpdatedPositionEntryPrice(uint256 oldAmout, int256 oldPrice, uint256 newAmount, int256 newPrice)
        private
        pure
        returns (int256)
    {
        return ((int256(oldAmout) * oldPrice) + (int256(newAmount) * newPrice)) / int256(oldAmout + newAmount);
    }

    function getPosition(address positionAddress) external view returns (Position memory) {
        return positions[positionAddress];
    }

    /// @notice Returns the users with positions
    /// @dev This is an expensive function , can use up too much gas to fit a block
    /// @return	All users with positions
    function getUsersWithPositions() external view returns (address[] memory) {
        return usersWithPositions.values();
    }
}

//! update all positions , check if they are eligible for liquidation
//! calculate fees when updating position
//! caclulate fees when liquidating position
