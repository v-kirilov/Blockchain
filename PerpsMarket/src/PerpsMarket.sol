// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
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
    uint32 public Fee = 2000; // 2%

    uint256 private accumulatedFees;
    uint256 public lastUpdatedTimestamp;
    address private feeCollector;

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

    constructor() Ownable(msg.sender) {}

    function updatePositions(uint256 amount) public {
        lastUpdatedTimestamp = block.timestamp;
        //Update positions, how can we do that , iterate all positions???
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
        uint256 fees = calculateFeesForPosition(position);
        uint256 profit = uint256(profitBeforeFees) - fees;
        accumulatedFees += fees;
        //Remove user from positions
        usersWithPositions.remove(msg.sender);

        //Save profit in positionProfit mapping
        if (profit > 0) {
            positionProfit[msg.sender] = uint256(profit);
        }
    }

    function withdrawProfit() external {
        uint256 profit = positionProfit[msg.sender];
        require(profit > 0, "No profit to withdraw");
        positionProfit[msg.sender] = 0;

        (bool success,) = msg.sender.call{value: uint256(profit)}("");
        require(success, "Transfer failed.");
    }

    function openPosition(uint256 amount, PositionType positionType) external payable notBLackListed {
        if (msg.value == 0) {
            revert NoETHProvided();
        }
        // Check position size
        int256 ethPrice = PriceFeed.getChainlinkDataFeedLatestAnswer();
        uint256 leverage = calculatePositionLeverage(amount, msg.value);
        uint256 positionLiquidationPrice = calculatePositionLiquidationPrice(uint256(ethPrice), leverage, positionType);

        Position memory newPosition = Position({
            user: msg.sender,
            amountDeposited: msg.value,
            positionAmount: amount,
            positionType: positionType,
            positionEntryPrice: uint256(ethPrice),
            positionLiquidationPrice: positionLiquidationPrice,
            positionLeverage: leverage
        });

        //Save position
        positions[msg.sender] = newPosition;
        usersWithPositions.add(msg.sender);
    }

    function calculatePositionLeverage(uint256 positionAmount, uint256 deposited) private pure returns (uint256) {
        uint256 leverageBips = (positionAmount * TO_BIPS) / deposited;
        if (leverageBips > MAX_BIPS_LEVERAGE) {
            revert LeverageExceded();
        }
        return leverageBips;
    }

    function calculateProfit(Position memory position, uint256 ethPrice) private pure returns (int256) {
        uint256 positionEntryPrice = position.positionEntryPrice;
        int256 profitInUsd = 0;
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
    //2200_00000000 - 2000_00000000 = 200_00000000 / 1e8 = 200 *3 = 600

    function calculateFeesForPosition(Position memory position) private view returns (uint256) {
        return (position.positionAmount * Fee) / TO_BIPS;
    }

    function calculatePositionLiquidationPrice(
        uint256 positionEntryPrice,
        uint256 positionLeverage,
        PositionType positionType
    ) private pure returns (uint256) {
        if (positionType == PositionType.LONG) {
            return positionEntryPrice - ((TO_BIPS * positionEntryPrice) / positionLeverage);
        }
        return positionEntryPrice + ((TO_BIPS * positionEntryPrice) / positionLeverage);
    }
}
