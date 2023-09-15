//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

contract AuctionPlatform {
    address private _owner;
    uint256 private _id = 1;

    struct Auction {
        //uint256 id;
        uint256 startTime;
        uint256 endTime;
        uint256 duration;
        string name;
        string description;
        uint256 highestBid;
        bool finalized;
        address payable creator;
    }

    mapping(uint256 => address) public HighestBidder;
    mapping(uint256 => Auction) public AllAuctions;
    mapping(address => uint256) public availableToWithdrawal;

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyActiveAuction(uint256 id) {
        require(AllAuctions[id].finalized == false);
        _;
    }

    event CreateAction(uint256 indexed id, string name, string description);
    event HighestBid(uint256 indexed id, uint256 indexed highestBid);

    function createAuction(
        uint256 startTime,
        uint256 duration,
        string calldata name,
        string calldata description
    ) external {
        require(duration > 0, "Duration must be >0");
        require(startTime > block.timestamp, "Start must be in the future!");
        Auction memory newAuction = Auction(
            startTime + block.timestamp,
            duration + startTime + block.timestamp,
            duration,
            name,
            description,
            0,
            false,
            payable(msg.sender)
        );
        AllAuctions[_id] = newAuction;
        emit CreateAction(_id, name, description);
        _id++;
    }

    function placeBid(uint256 id)
        public
        payable
        onlyActiveAuction(id)
    {
        require(
            AllAuctions[id].highestBid < msg.value,
            "Bid must be > than current!"
        );
        if (AllAuctions[id].highestBid > 0) {
            //If there is a bid higher than current than transfer the smaller amount back to the one that made it
            availableToWithdrawal[HighestBidder[id]] = AllAuctions[id]
                .highestBid;
        }
        //Set the new highest bidder
        HighestBidder[id] = msg.sender;
        //Set the new highest bid to the Auction
        AllAuctions[id].highestBid = msg.value;
        emit HighestBid(id, msg.value);
    }

    function finalizeBid(uint256 id) public onlyActiveAuction(id) {
        AllAuctions[id].finalized = true;
        if (AllAuctions[id].highestBid > 0) {
            AllAuctions[id].creator.transfer(AllAuctions[id].highestBid);
        }
    }

    function withdraw() public {
        require(availableToWithdrawal[msg.sender] > 0, "Nothing to withdraw!");
        //To avoid re-entrancy attack!
        uint256 toTransfer = availableToWithdrawal[msg.sender];
        availableToWithdrawal[msg.sender] = 0;
        payable(msg.sender).transfer(toTransfer);
    }

        function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
