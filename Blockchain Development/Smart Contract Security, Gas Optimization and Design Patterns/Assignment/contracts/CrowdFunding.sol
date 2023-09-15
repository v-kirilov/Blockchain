//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrowdFunding is ERC20, Ownable {
    address[] contributedAddresses;
    uint256 public id;
    string public CrowdFundingName;
    string public description;
    uint256 startTime;
    uint256 endTime;
    uint256 public duration;
    uint256 public goal;
    mapping(address => uint256) contributors;
    mapping(address => uint256) percentige;
    bool public isFinished = false;
    uint256 public balanceLeft;
    uint256 public distributionRound = 0;
    mapping(uint256 => mapping(address => uint256)) claims;
    mapping(address=>uint256) shares;
    //mapping(address=> uint256) balance;
    event Contribution(address indexed contributor);

    constructor(
        
        uint256 _id,
        string memory _name,
        string memory _description,
        uint256 _goal,
        uint256 _duration
    ) ERC20(_name, "CRF") {
        require(_goal > 0, "Goal must be > 0");
        id = _id;
        goal = _goal;
        CrowdFundingName = _name;
        _transferOwnership(msg.sender);
        description = _description;
        duration = _duration;
        startTime = block.timestamp;
        endTime = block.timestamp + duration;
        mint(address(this),goal);
    }

    function contribute() external payable returns (uint256) {
        require(msg.value <= goal, "Cant be more than goal");
        contributors[msg.sender] += msg.value;
        balanceLeft += msg.value;
        if (address(this).balance >= goal) {
            isFinished = true;
        }
        emit Contribution(msg.sender);
        percentige[msg.sender] = (100 * contributors[msg.sender]) / goal;
        contributedAddresses.push(msg.sender);

        _transferAfterContribution(address(this),msg.sender,msg.value);
        return percentige[msg.sender];
    }

    function release() external onlyOwner {
        require(isFinished, "Not finished yet");
        balanceLeft = 0;
        (bool success, ) = payable(owner()).call{value: address(this).balance}(
            ""
        );
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    function rewardDistribution(uint256 toDistribute) external onlyOwner {
        //require(toDistribute <= address(this).balance,"wut");
        require(toDistribute <= balanceLeft, "Must be < than balance");
        balanceLeft -= toDistribute;
        for (uint256 i = 0; i < contributedAddresses.length; i++) {
            claims[distributionRound][contributedAddresses[i]] =
                percentige[contributedAddresses[i]] *
                toDistribute;
        }
       distributionRound++;
    }

    function claimDistribution(uint256 round) external payable {
        require(claims[round][msg.sender]!=0,"Nothing to claim");
        claims[round][msg.sender]=0;
        (bool success,) = payable(msg.sender).call{value:claims[round][msg.sender]}("");
                require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    function refund() external {
        require(block.timestamp > endTime, "Not over yet");
        require(isFinished==false,"Funding finished");
        //require(goal <= address(this).balance, "Goal has been met");
        require(contributors[msg.sender] > 0, "Nothing to refund");

        contributors[msg.sender] = 0;
        (bool success, ) = payable(owner()).call{
            value: contributors[msg.sender]
        }("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    function currentBalance() external view returns (uint256) {
        return address(this).balance;
    }
        function mint(address to, uint256 amount) public onlyOwner {
        shares[to] +=amount;
        _mint(to, amount);
    }

    function transferShares(address to, uint256 amount) public{
        require(shares[msg.sender]>=amount,"Not enough shares");
        shares[msg.sender]-=amount;
        shares[to]+=amount;
    }

    function _transferAfterContribution(address from, address to, uint256 amount) private{
          require(shares[from]>=amount,"Not enough shares");
        shares[from]-=amount;
        shares[to]+=amount;
    }
}
