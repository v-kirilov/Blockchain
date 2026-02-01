// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPerpCampaignFactory {
    ///-///-///-///
    // Errors
    ///-///-///-///
    error Unauthorized();
    error NotPossible();
    error ZeroAddress();

    ///-///-///-///
    // Events
    ///-///-///-///
    event CampaignCreated(uint32 duration, address indexed prizeToken, address indexed campaignAdmin,address indexed campaignAddress);
    event RoleGranted(address indexed grantedAdress);
    event RoleRevoked(address indexed revokedAddress);
}
