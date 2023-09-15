// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./Voting.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Organization is Voting {
    using Counters for Counters.Counter;

    Counters.Counter private _orgId;
    Counters.Counter private _withId;

    //This voter has in this treasury this amount of votes
    mapping(address => mapping(uint256 => uint256))public contributors;
    //mapping(address=>mapping(uint256 => uint256))  votes;
    mapping(address => uint256)public ownersTreasuries;
    mapping(uint256 => Treasury)public treasuries;

    //mapping(address=>mapping(uint256 => uint256)) balances;
    mapping(uint256 => WithDraw)public Withdrawals;

    event TreasuryCreation(address indexed owner,uint256 indexed id);

    struct Treasury {
        uint256 id;
        uint256 balance;
        address owner;
    }

    struct WithDraw {
        uint256 id;
        uint256 amount;
        string description;
        uint256 duration;
        uint256 yes;
        uint256 no;
        address owner;
    }

    function createTreasury() onlyOwner() external {
        Treasury memory newTreasury = Treasury(_orgId.current(), 0, msg.sender);
        treasuries[_orgId.current()] = newTreasury;
        ownersTreasuries[msg.sender] = _orgId.current();
        emit TreasuryCreation(msg.sender,_orgId.current());
        _orgId.increment();
    }

    function storeFunds(uint256 id) external payable {
        require(id < _orgId.current(), "No such treasury");
        require(msg.value > 0, "Funds must be >0");
        contributors[msg.sender][id] += msg.value;
        treasuries[id].balance += msg.value;
        _mint(msg.sender, msg.value);
    }

    function blanaceOfTreasury(uint256 id) external view returns (uint256){
        return treasuries[id].balance;
    }

    //Withdraw Test
    function initiateWithdrawal(
        uint256 id,
        uint256 amount,
        string memory desc,
        uint256 duration
    ) external {
        require(id < _orgId.current(), "No such treasury");
        require(treasuries[id].balance >= amount, "Not enough balance");
        require(treasuries[id].owner == msg.sender, "Not owner");
        WithDraw memory newWithDraw = WithDraw(
            _withId.current(),
            amount,
            desc,
            duration,
            0,
            0,
            msg.sender
        );
        Withdrawals[_withId.current()] = newWithDraw;
        _withId.increment();
    }

    //Voting Test
    function vote(
        uint256 withId,
        bool yourVote,
        uint256 amount
    ) external {
        require(withId < _withId.current(), "No such withdrawal");
        require(amount > 0, "Amount must be >0");

        address owner = Withdrawals[withId].owner;
        uint256 treasuryId = ownersTreasuries[owner];
        require(
            contributors[msg.sender][treasuryId] >= amount,
            "Not enough votes"
        );

        if (yourVote == true) {
            Withdrawals[withId].yes += amount;
            contributors[msg.sender][treasuryId] -= amount;
        } else {
            Withdrawals[withId].no += amount;
            contributors[msg.sender][treasuryId] -= amount;
        }
    }

    function executeWithdrawal(uint256 withId, address to) external payable {
        require(withId < _withId.current(), "No such withdrawal");
        require(to != address(0), "Not addres 0");
        require(
            Withdrawals[withId].duration > block.timestamp,
            "Not over yeat"
        );

        address owner = Withdrawals[withId].owner;
        uint256 treasuryId = ownersTreasuries[owner];

        uint256 yesVotes = Withdrawals[withId].yes;
        uint256 noVotes = Withdrawals[withId].no;

        if ((yesVotes == 0 && noVotes == 0) || (yesVotes > noVotes)) {

            treasuries[treasuryId].balance -= Withdrawals[withId].amount;

            (bool success, ) = payable(to).call{
                value: Withdrawals[withId].amount
            }("");
            require(
                success,
                "Address: unable to send value, recipient may have reverted"
            );
        } else {
            revert("Voters voted NO");
        }

        delete Withdrawals[withId];
    }
}
