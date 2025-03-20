// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract PPCampaign is AccessControl {
    ///-///-///-///
    // Errors
    ///-///-///-///
    error Unauthorized();
    error ZeroAddress();

    bytes32 public constant CAMPAIGN_ADMIN_ROLE = keccak256("CAMPAIGN_ADMIN_ROLE");

    uint256 private immutable Duration;
    address private immutable PrizeToken;
    uint256 public firstPrizeAmount;
    uint256 public immutable secontPrizeAmount;
    uint256 public immutable thirdPrizeAmount;

    //When participating in the campaign a user gains points based on his trading, if it's succesfull he gets more points.
    //At the end of a campaign the top 3 users with the most points will get a prize. The prize is a token that is set at the start of the campaign.
    //This token can be used to reduce his trading fees on the platform and other perks.
    struct Participant {
        address userAdress;
        uint256 points;
        uint256 campaignId;
        uint256 prizePoints;
    }

    
    //Points for each participant that has accumulated in the campaign
    mapping(address => Participant) public participantsPoints;


    constructor(uint256 _duration, address _prizeToken, address _campaignAdmin) {
        if (_duration == 0) {
            revert("Duration cannot be 0");
        }

        if (_prizeToken == address(0)) {
            revert ZeroAddress();
        }
        _grantRole(CAMPAIGN_ADMIN_ROLE, _campaignAdmin);
        Duration = _duration;
        PrizeToken = _prizeToken;
    }

    /// @notice Restricts access to campaign admin
    modifier onlyCampaignAdmin() {
        if (!hasRole(CAMPAIGN_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _;
    }
}