// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CharityCampaign is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    struct Campaign {
        uint256 id;
        string name;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 balance;
        bool isFinished;
        address creator;
    }
    mapping(uint256 => Campaign) public campaigns;
    mapping(address => mapping(uint256 => uint256)) public contrirbutors;
    Counters.Counter private _tokenIdCounter;

    event CampaignCreated(address creator);
    string constant _MYURI =
        "https://api.jsonbin.io/v3/b/647835eeb89b1e2299a82a8f?meta=false";

    constructor() ERC721("Charity Token", "CHR") {}

    function _safeMint(address to, string memory uri) private{
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function donate(uint256 id) external payable {
        require(
            (campaigns[id].balance + msg.value) <= campaigns[id].goal,
            "Donation is over goal"
        );
        campaigns[id].balance += msg.value;
        if (campaigns[id].balance == campaigns[id].goal) {
            campaigns[id].isFinished = true;
        }
        contrirbutors[msg.sender][id] += msg.value;

        _safeMint(msg.sender, _MYURI);
    }

    function createCampaign(
        string memory name,
        string memory desc,
        uint256 goal,
        uint256 deadline
    ) public {
        uint256 currTime = block.timestamp;
        Campaign memory camp = Campaign(
            _tokenIdCounter.current(),
            name,
            desc,
            goal,
            deadline + currTime,
            0,
            false,
            msg.sender
        );

        campaigns[_tokenIdCounter.current()] = camp;
        _tokenIdCounter.increment();
        emit CampaignCreated(msg.sender);
    }

    function collectFunds(uint256 id, address collector) external {
        require(campaigns[id].creator == msg.sender, "Not creator");
        require(campaigns[id].isFinished == true, "Not finished");
        if (campaigns[id].deadline > block.timestamp) {
            campaigns[id].isFinished = true;
        }

        campaigns[id].balance = 0;
        (bool success, ) = address(collector).call{value: campaigns[id].goal}(
            ""
        );
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    function refund(uint256 id) external {
        require(campaigns[id].isFinished == false, "Finished!");
        require(campaigns[id].deadline > block.timestamp, "Time out");
        require(contrirbutors[msg.sender][id] > 0, "No contributions");

        contrirbutors[msg.sender][id] = 0;
        (bool success, ) = address(msg.sender).call{
            value: contrirbutors[msg.sender][id]
        }("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
