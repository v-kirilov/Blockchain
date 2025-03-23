// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPPCampaign {
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
    error NoSuchParticipant();
    error PrizeCannotBeZero();
    error CampaignHasFinished();
    error CampaignNotStarted();

    ///-///-///-///
    // Events
    ///-///-///-///
    event PrizeAmountsSet(
        uint256 indexed firstPrizeAmount, uint256 indexed secondPrizeAmount, uint256 indexed thirdPrizeAmount
    );
    event PrizeClaimed(address indexed winner, uint256 indexed prizeAmount);
    event ParticipantAdded(address indexed participant);
    event CampaignStarted(uint256 indexed startDate);
    event EndCampaign(uint256 indexed endDate);

    function setPrizeAmounts(uint256 _firstPrizeAmount, uint256 _secondPrizeAmount, uint256 _thirdPrizeAmount)
        external;

    function claimPrize() external;

    function upSertParticipant(address userAdress, uint256 prizePoints) external;

    function startCampaign() external;

    function endCampaign() external;

    function getDuration() external view returns (uint256);

    function getEndDate() external view returns (uint256);

    function getCampaignStartDate() external view returns (uint256);

    function getParticipantInfo(address participant) external view returns (bool, uint256);

    function getCampaignId() external view returns (uint256) ;
}
