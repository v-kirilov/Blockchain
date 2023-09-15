//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
//Importing Counters struct for incrementing the id
import "@openzeppelin/contracts/utils/Counters.sol";
using Counters for Counters.Counter;

//Link for my NFT https://api.jsonbin.io/v3/b/645cf1e8b89b1e22999baaad?meta=false
contract MyERC721 {
    string constant META =
        "https://api.jsonbin.io/v3/b/645f607f9d312622a35d5a21?meta=false";
    string private _name;
    string private _symbol;
    address private _owner;
    uint256 private _totalSupply;
    Counters.Counter public _id;

    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _ownerOfNFT;
    mapping(uint256 => string) private _tokensURI;
    //mapping(address => uint256[]) private _owners;
    mapping(address => address) private _approved;

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply
    ) {
        _name = name;
        _symbol = symbol;
        _totalSupply = totalSupply;
        _owner = msg.sender;
        //Set the _id to 1, so that it starts from 1
        _id.increment();
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not owner!");
        _;
    }

    event Mint(uint256 indexed _tokenId);
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );
    event Approval(
        address indexed _owner,
        address indexed _approved,
        uint256 indexed _tokenId
    );
    event Burn(uint256 indexed _tokenId);

    modifier isApproved(address approved) {
        require(_approved[msg.sender] == approved);
        _;
    }

    //How many NFT's I have
    // function myBalance(address owner) external view returns (uint256) {
    //     require(owner != address(0), "Zero account!");
    //     return _balances[_owner];
    // }

    //Who is the owner of NFT with the current ID
    function ownerOf(uint256 _tokenId) external view returns (address) {
        require(
            _ownerOfNFT[_tokenId] != address(0),
            "ERC721: invalid token ID"
        );
        return _ownerOfNFT[_tokenId];
    }

    function mintAndSetUri(address to) public {
        require(_id.current() <= _totalSupply, "Total supply reached.");
        require(to != address(0), "Cant be 0 address!");
        require(to != _owner, "Dont send it to yourself!");
        //Set the URI of the NFT
        _tokensURI[_id.current()] = META;
        //Push the NFT id to a user
        _balances[to] += 1;
        //Set _ownersOf
        _ownerOfNFT[_id.current()] = to;
        //Increase balance of address

        emit Mint(_id.current());
        _id.increment();
    }

    function transfer(address to, uint256 id) public returns (bool) {
        require(_ownerOfNFT[id] == msg.sender, "Not owner!");
        require(to != msg.sender, "Can't send to yourself!");
        _ownerOfNFT[id] = to;
        _balances[to] += 1;
        _balances[msg.sender] -= 1;
        emit Transfer(msg.sender, to, id);
        return true;
    }

    function exist(uint256 id) private view returns (bool) {
        require(id <= _id.current(), "Not existing!");
        require(_ownerOfNFT[id] != address(0), "Burned!");
        return true;
    }

    //How many NFT's I have
    function myBalance() public view returns (uint256) {
        return _balances[msg.sender];
    }

    function burn(uint256 id) public {
        require(_ownerOfNFT[id] == msg.sender, "Not owner!");
        emit Burn(id);
        transfer(address(0), id);
    }

    function Approve(address toApprove, uint256 id) public {
        require(_ownerOfNFT[id] == msg.sender, "Not owner!");
        _approved[msg.sender] = toApprove;
        emit Approval(msg.sender, toApprove, id);
    }
    //TODO - (Mint), (Transfer), (Exist), (Approve), (TotalSupply),(Burn),(MyBalance)
}
