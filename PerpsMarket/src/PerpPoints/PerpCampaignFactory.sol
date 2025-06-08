// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "../Interfaces/IPerpCampaignFactory.sol";
import "./PPCampaign.sol";

    /// @title PerpCampaignFactory
    /// @notice This contract is responsible for creating Campaign contracts.
    /// @dev For every campaign a separate contract is deployed.
    /// @dev A contract is deployed by the address with FACTORY_ROLE.

contract PerpCampaignFactory is AccessControl, IPerpCampaignFactory {
    uint32 private campaignId;

    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    mapping(uint256 pmID => address markets) public perpMarkets;

    constructor(address _admin) {
        require(_admin != address(0), ZeroAddress());
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /// @notice Function to create a campaign contract
    /// @param duration Duration for the current campaigns
    /// @param prizeToken  Token address that is set as the prize token
    /// @param campaignAdmin  Campaign admin address
    /// @param campaignStartDate  Campaign start date
    /// @dev Only callable by FACTORY_ROLE
    function createPerpCampaignContract(
        uint32 duration,
        address prizeToken,
        address campaignAdmin,
        uint256 campaignStartDate
    ) external returns (address) {
        require(hasRole(FACTORY_ROLE, msg.sender), Unauthorized());

        campaignId++;
        uint32 newCampaignId = campaignId;

        bytes32 salt = keccak256(abi.encode(duration, newCampaignId, prizeToken, campaignAdmin, campaignStartDate));
        bytes memory consArguments = abi.encode(duration, newCampaignId, prizeToken, campaignAdmin, campaignStartDate);
        bytes memory bytecode = abi.encodePacked(type(PPCampaign).creationCode, consArguments);
        address campaignAddress = Create2.deploy(0, salt, bytecode);
        //deploy

        emit CampaignCreated(duration, prizeToken, campaignAdmin, campaignStartDate, campaignAddress);
        return campaignAddress;
    }

    /// @notice Function to grant factory role
    /// @param _account Address that will be granted the factory role
    /// @dev Only callable by DEFAULT_ADMIN_ROLE
    function grantFactoryRole(address _account) external {
       require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), Unauthorized());
        if (_account == address(0)) {
            revert ZeroAddress();
        }
        if (_account == msg.sender) {
            revert NotPossible();
        }
        grantRole(FACTORY_ROLE, _account);

        emit RoleGranted(_account);
    }

    /// @notice Function to revoke factory role
    /// @param _account Address that will be have the factory role removed
    /// @dev Only callable by ADMIN_ROLE
    function revokeFactoryRole(address _account) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), Unauthorized());
        revokeRole(FACTORY_ROLE, _account);

        emit RoleRevoked(_account);
    }
}
