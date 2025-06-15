// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../Interfaces/IPPCampaign.sol";
    /// @title PPCampaign
    /// @notice This contract implements a campaign for Perp Points, where users can earn points based on their trading activity.
    /// @dev For every campaign a seperate contract is deployed.
contract PPCampaign is AccessControl, IPPCampaign, Pausable {
    using SafeERC20 for IERC20;

    ///-///-///-///
    // Constants
    ///-///-///-///
    bytes32 public constant CAMPAIGN_ADMIN_ROLE = keccak256("CAMPAIGN_ADMIN_ROLE");

    ///-///-///-///
    // Immutables
    ///-///-///-///
    uint32 public immutable MAX_CAMPAIGN_DURATION = 30 days;
    uint32 private immutable CAMPAIGN_ID;
    uint192 private immutable Duration;
    address private immutable PrizeToken;

    ///-///-///-///
    // Public variables
    ///-///-///-///
    uint256 public firstPrizeAmount;
    uint256 public secontPrizeAmount;
    uint256 public thirdPrizeAmount;

    address public firstPrizeWinner;
    uint256 public firstPrizePoints;

    address public secondPrizeWinner;
    uint256 public secondPrizePoints;

    address public thirdPrizeWinner;
    uint256 public thirdPrizePoints;

    uint256 public campaignStartDate;
    bool public hasCampaignFinished;
    bool public hasCampaignStarted;

    event CampaignAdminSet(address indexed admin);

    //When participating in the campaign a user gains points based on his trading, if it's succesfull he gets more points.
    //At the end of a campaign the top 3 users with the most points will get a prize. The prize is a token that is set at the start of the campaign.
    //This token can be used to reduce his trading fees on the platform and other perks.
    struct ParticipantInfo {
        uint256 prizePoints;
        bool isWinner;
    }

    //Points for each participant that has accumulated in the campaign
    mapping(address => ParticipantInfo) public participants;

    constructor(
        uint32 _duration,
        uint32 _campaignId,
        address _prizeToken,
        address _campaignAdmin,
        uint256 _campaignStartDate
    ) {
        if (_duration == 0) {
            revert ZeroDuration();
        }
        if (_duration > MAX_CAMPAIGN_DURATION) {
            revert MaxCamapignDurationExceeded();
        }

        if (_prizeToken == address(0)) {
            revert ZeroAddress();
        }

              if (_campaignAdmin == address(0)) {
            revert ZeroAddress();
        }

        if (_campaignStartDate < block.timestamp) {
            revert IncorrectCampaignStart();
        }
        
        _grantRole(DEFAULT_ADMIN_ROLE, _campaignAdmin);
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

        /// @notice Restricts access to campaign admin
    modifier onlyDefaultAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    /// @notice Checks if camaping has ended and reverts if it has.
    modifier campaignEnded() {
        if (hasCampaignFinished) {
            revert CampaignHasFinished();
        }
        _;
    }

    /// @notice Checks if camaping has started and reverts if it has not.
    modifier campaignStarted() {
        if (!hasCampaignStarted) {
            revert CampaignNotStarted();
        }
        _;
    }

    /// @notice Function to set the prize amounts for the top 3 winners
    /// @param _firstPrizeAmount Amount for the first prize
    /// @param _secondPrizeAmount  Amount for the second prize
    /// @param _thirdPrizeAmount  Amount for the third prize
    /// @dev Only callable by DEFAULT_ADMIN_ROLE and only if the campaign has not finished
    function setPrizeAmounts(uint256 _firstPrizeAmount, uint256 _secondPrizeAmount, uint256 _thirdPrizeAmount)
        external
        onlyCampaignAdmin
        campaignEnded
    {
        if (_firstPrizeAmount == 0 || _secondPrizeAmount == 0 || _thirdPrizeAmount == 0) {
            revert PrizeCannotBeZero();
        }

        firstPrizeAmount = _firstPrizeAmount;
        secontPrizeAmount = _secondPrizeAmount;
        thirdPrizeAmount = _thirdPrizeAmount;

        emit PrizeAmountsSet(_firstPrizeAmount, _secondPrizeAmount, _thirdPrizeAmount);
    }

    /// @notice Function to claim the prize for the top 3 winners, only callable after the campaign has finished
    /// @dev Only callable by CAMPAIGN_ADMIN_ROLE
    function claimPrize() external whenNotPaused {
        if (!hasCampaignFinished) {
            revert CampaignStillActive();
        }
        if (msg.sender != firstPrizeWinner && msg.sender != secondPrizeWinner && msg.sender != thirdPrizeWinner) {
            revert NothingToClaim();
        }

        ParticipantInfo storage participant = participants[msg.sender];

        require(participant.prizePoints > 0, NothingToClaim());
        participant.prizePoints = 0;
        IERC20(PrizeToken).safeTransfer(msg.sender, participant.prizePoints);

        emit PrizeClaimed(msg.sender, participant.prizePoints);
    }

    /// @notice Function to update or create a participant in the campaign
    /// @param userAdress The address of the participant
    /// @param prizePoints  The points that the participant has gained
    /// @dev Only callable by CAMPAIGN_ADMIN_ROLE and only if the campaign has not finished and has started
    function upSertParticipant(address userAdress, uint256 prizePoints)
        external
        onlyCampaignAdmin
        campaignStarted
        whenNotPaused
    {
        if (hasCampaignFinished) {
            revert CampaignHasFinished();
        }
        ParticipantInfo storage participant = participants[userAdress];
        uint256 participantPoints = participant.prizePoints + prizePoints;
        updateWinners(userAdress, participantPoints);

        emit ParticipantAdded(userAdress);
    }

    /// @notice Function to check if the participant is a winner and update the top 3 winners
    /// @param userAdress The address of the participant that will be updated
    /// @param prizePoints  The points that the participant has gained and will be added to the existing points
    /// @dev This is a private function that is called every time upSertParticipant is called
    function updateWinners(address userAdress, uint256 prizePoints) private {
        if (prizePoints > firstPrizePoints) {
            thirdPrizePoints = secondPrizePoints;
            thirdPrizeWinner = secondPrizeWinner;
            secondPrizePoints = firstPrizePoints;
            secondPrizeWinner = firstPrizeWinner;
            firstPrizePoints = prizePoints;
            firstPrizeWinner = userAdress;
        } else if (prizePoints > secondPrizePoints) {
            thirdPrizePoints = secondPrizePoints;
            thirdPrizeWinner = secondPrizeWinner;
            secondPrizePoints = prizePoints;
            secondPrizeWinner = userAdress;
        } else if (prizePoints > thirdPrizePoints) {
            thirdPrizePoints = prizePoints;
            thirdPrizeWinner = userAdress;
        }
    }

    /// @notice Function to start the campaign early
    /// @dev Only callable by CAMPAIGN_ADMIN_ROLE and if the campaign has not finished
    function startCampaign() external onlyCampaignAdmin campaignEnded whenNotPaused {
        if (hasCampaignStarted) {
            revert CampaignAlreadyStarted();
        }
        campaignStartDate = block.timestamp;
        hasCampaignStarted = true;

        emit CampaignStarted(campaignStartDate);
    }

    /// @notice Function to end the campaign
    /// @dev Only callable by CAMPAIGN_ADMIN_ROLE and if the campaign has not finished and has started
    function endCampaign() external onlyCampaignAdmin campaignStarted campaignEnded {
        hasCampaignFinished = true;
        ParticipantInfo storage firstPrizeParticipant = participants[firstPrizeWinner];
        firstPrizeParticipant.isWinner = true;
        ParticipantInfo storage secondPrizeParticipant = participants[secondPrizeWinner];
        secondPrizeParticipant.isWinner = true;
        ParticipantInfo storage thirdPrizeParticipant = participants[thirdPrizeWinner];
        thirdPrizeParticipant.isWinner = true;

        emit EndCampaign(campaignStartDate + Duration);
    }

    /// @notice Function to get the duration of the campaign
    /// @return uint256 duration of campaign
    function getDuration() external view returns (uint256) {
        return Duration;
    }

    /// @notice Function to get the end date of the campaign
    /// @return uint256 end date of campaign
    function getEndDate() external view returns (uint256) {
        return campaignStartDate + Duration;
    }

    /// @notice Function to get the start date of the campaign
    /// @return uint256 campaignStartDate
    function getCampaignStartDate() external view returns (uint256) {
        return campaignStartDate;
    }

    /// @notice Function to get the prize token of the campaign
    /// @return bool is winner
    /// @return uint256 prize points
    function getParticipantInfo(address participant) external view returns (bool, uint256) {
        if (participants[participant].prizePoints == 0) {
            revert NoSuchParticipant();
        }
        return (participants[participant].isWinner, participants[participant].prizePoints);
    }

    /// @notice Function to get the prize token of the campaign
    /// @return uint256 CAMPAIGN_ID
    function getCampaignId() external view returns (uint256) {
        return CAMPAIGN_ID;
    }

    /// @notice Function to get the status of the campaign
    /// @return bool hasCampaignStarted
    function isCampaignActive() external view returns (bool) {
        return hasCampaignStarted;
    }

    function setCampaignAdmin(address newAdmin) external onlyDefaultAdmin {
        if (newAdmin == address(0)) {
            revert ZeroAddress();
        }
        if ( hasRole(DEFAULT_ADMIN_ROLE, newAdmin)) {
            revert CmapgainAdminCantBeDefaultAdmin();
        }
        _grantRole(CAMPAIGN_ADMIN_ROLE, newAdmin);
        emit CampaignAdminSet(newAdmin);
    }
    
}

//! Pausable!
//! multiple campains to run simultaneously?