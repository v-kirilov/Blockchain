// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PPCampaign is AccessControl {
    using SafeERC20 for IERC20;

    ///-///-///-///
    // Errors
    ///-///-///-///
    error Unauthorized();
    error ZeroAddress();
    error MaxCamapignDurationExceeded();
    error CampaignStillActive();
    error NothingToClaim();
    error ZeroDuration();
    error IncorrectCampaignStart();

    ///-///-///-///
    // Constants
    ///-///-///-///
    bytes32 public constant CAMPAIGN_ADMIN_ROLE = keccak256("CAMPAIGN_ADMIN_ROLE");

    ///-///-///-///
    // Immutables
    ///-///-///-///
    uint256 public immutable MAX_CAMPAIGN_DURATION = 30 days;
    uint256 private immutable CAMPAIGN_ID;
    uint256 private immutable Duration;
    address private immutable PrizeToken;

    ///-///-///-///
    // Public variables
    ///-///-///-///
    uint256 public firstPrizeAmount;
    uint256 public secontPrizeAmount;
    uint256 public thirdPrizeAmount;
    uint256 public campaignStartDate;
    bool public hasCampaignFinished;

    //When participating in the campaign a user gains points based on his trading, if it's succesfull he gets more points.
    //At the end of a campaign the top 3 users with the most points will get a prize. The prize is a token that is set at the start of the campaign.
    //This token can be used to reduce his trading fees on the platform and other perks.
    struct Participant {
        address userAdress;
        uint256 prizePoints;
    }

    //Points for each participant that has accumulated in the campaign
    mapping(address => Participant) public participants;

    constructor(uint256 _duration, address _prizeToken, address _campaignAdmin,uint256 _campaignId, uint256 _campaignStartDate) {
        if (_duration == 0) {
            revert ZeroDuration();
        }
        if (_duration > MAX_CAMPAIGN_DURATION) {
            revert MaxCamapignDurationExceeded();
        }

        if (_prizeToken == address(0)) {
            revert ZeroAddress();
        }

        if (_campaignStartDate < block.timestamp) {
            revert IncorrectCampaignStart();
        }

        _grantRole(CAMPAIGN_ADMIN_ROLE, _campaignAdmin);
        CAMPAIGN_ID = _campaignId;
        Duration = _duration;
        PrizeToken = _prizeToken;
        campaignStartDate = _campaignStartDate;
    }

    /// @notice Restricts access to campaign admin
    modifier onlyCampaignAdmin() {
        if (!hasRole(CAMPAIGN_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    function setPrizeAmounts(uint256 _firstPrizeAmount, uint256 _secondPrizeAmount, uint256 _thirdPrizeAmount)
        external
        onlyCampaignAdmin
    {
        firstPrizeAmount = _firstPrizeAmount;
        secontPrizeAmount = _secondPrizeAmount;
        thirdPrizeAmount = _thirdPrizeAmount;
    }

    function claimPrize() external {
        Participant storage participant = participants[msg.sender];
        if (!hasCampaignFinished) {
            revert CampaignStillActive();
        }
        require(participant.prizePoints > 0, NothingToClaim());
        participant.prizePoints = 0;
        IERC20(PrizeToken).safeTransfer(msg.sender, participant.prizePoints);
    }

    function upSertParticipant(address _userAdress,  uint256 _prizePoints) external onlyCampaignAdmin {
        Participant memory participant = participants[_userAdress];
        if (participant.userAdress == address(0)) {
            participants[_userAdress] = Participant(_userAdress, _prizePoints);
            return;
        }else {
            participant.prizePoints += _prizePoints;
            participants[_userAdress] = participant;
        }
    }

    function endCampaign() external onlyCampaignAdmin {
        hasCampaignFinished = true;
    }

    function getDuration() external view returns (uint256) {
        return Duration;
    }

    function getEndDate() external view returns (uint256) {
        return campaignStartDate + Duration;
    }

    function getCampaignStartDate() external view returns (uint256) {
        return campaignStartDate;
    }
}
