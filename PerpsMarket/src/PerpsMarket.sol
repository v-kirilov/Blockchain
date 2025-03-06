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
    uint32 private MaxBipsLeverage = 3000;

    mapping(address user => bool isBlacklisted) public blackListedUsers;
    //Need it to have it in enumerable set, only 32 byte variables are allowed in the set
    mapping(address user => Position) public positions;

    uint256 public lastUpdatedTimestamp;

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

    function updatePositions() public {
        lastUpdatedTimestamp = block.timestamp;
        //Update positions
    }

    function openPosition(uint256 amount, PositionType positionType) public payable notBLackListed {
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

    function calculatePositionLeverage(uint256 positionAmount, uint256 deposited) private view returns (uint256) {
        uint256 leverageBips = (positionAmount * 1000) / deposited;
        if (leverageBips > MaxBipsLeverage) {
            revert LeverageExceded();
        }
        return leverageBips;
    }

    function calculatePositionLiquidationPrice(
        uint256 positionEntryPrice,
        uint256 positionLeverage,
        PositionType positionType
    ) private pure returns (uint256) {
        if (positionType == PositionType.LONG) {
            return positionEntryPrice - ((1000 * positionEntryPrice) / positionLeverage);
        }
        return positionEntryPrice + ((1000 * positionEntryPrice) / positionLeverage);
    }
}
