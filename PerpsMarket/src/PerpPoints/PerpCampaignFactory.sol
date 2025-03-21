// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "./PPCampaign.sol";

contract PerpCampaignFactory is AccessControl {
    error Unauthorized();

    uint32 private campaignId;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    event PerpPointsCreated(address indexed perpPoints, address indexed owner);

    mapping(uint256 pmID => address markets) public perpMarkets;

    event PerpMarketCreated(address indexed perpMarket, uint256 indexed campaignId);

    constructor(address _admin) {
        _grantRole(ADMIN_ROLE, _admin);
    }

    function createPerpCampaignContract(
        uint32 duration,
        address prizeToken,
        address campaignAdmin,
        uint256 campaignStartDate
    ) external {
        require(hasRole(FACTORY_ROLE, msg.sender), Unauthorized());

        campaignId++;
        uint32 newCampaignId = campaignId;

        bytes32 salt = keccak256(abi.encode(duration, newCampaignId, prizeToken, campaignAdmin, campaignStartDate));
        bytes memory consArguments = abi.encode(duration, newCampaignId, prizeToken, campaignAdmin, campaignStartDate);
        bytes memory bytecode = abi.encodePacked(type(PPCampaign).creationCode, consArguments);
        address campaignAddress = Create2.deploy(0, salt, bytecode);
        //deploy

        emit PerpMarketCreated(campaignAddress, newCampaignId);
    }

    function grantFactoryRole(address _account) external {
        require(hasRole(ADMIN_ROLE, msg.sender), Unauthorized());
        grantRole(FACTORY_ROLE, _account);
    }

    function revokeFactoryRole(address _account) external {
        require(hasRole(ADMIN_ROLE, msg.sender), Unauthorized());
        revokeRole(FACTORY_ROLE, _account);
    }
}
