//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

contract RepairComplay{

    struct RepairRequest{
        uint256 id;
        uint256 cost;
        uint256 approvals;
        string description;
        bool accepted;
        bool payed;
        uint256 pay;
        bool finished;
        bool verified;
        address payable owner;
        uint256 timestamp;
        bool refunded;
    }

    mapping (uint256=>RepairRequest) private allRequests;
    uint256 id = 1;                                                                                      
    address private owner;
    address payable repairers;

    mapping (uint => string) private request;
    mapping (uint => uint256) private acceptedRequest;
    mapping (uint => uint256) private payedRequests;
    mapping (uint => bool) private doneRequests;
    mapping (uint256=>uint256) private verifiedRequests;

    constructor() {
        owner=msg.sender; 
    }

    function MakeRequest(string memory description) public {
        RepairRequest memory newRequest = RepairRequest(id,0,0,description,false,false,0,false,false,payable(msg.sender),block.timestamp,false);  
        allRequests[id]=newRequest;
        id++;
    }
    function ReviewRequest(uint256 _id)public view returns (string memory){
            require(owner==msg.sender,"Not Admin");
        return allRequests[_id].description;
    }

        function AcceptRequest(uint256 _id,uint256 tax) public {
            require(owner==msg.sender,"Not Admin");
        allRequests[_id].cost = tax;
        allRequests[_id].accepted = true;
    }

    function CheckNeccessaryPay(uint256 _id)external view returns(uint256){
        return allRequests[_id].cost;
    }
      function CheckIfPayed(uint256 _id)external view returns(uint256){
        return allRequests[_id].pay;
    }

    function payForRequest(uint256 _id) payable public returns(string memory,uint256){
        require (allRequests[_id].cost<=msg.value,"Not enough Pay");
        
        allRequests[_id].pay=msg.value;
        allRequests[_id].payed=true;
         allRequests[_id].finished=true;
        return ("Request has money",_id);
    }

        function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }

    function ConfirmRepair(uint256 _id) public view returns(bool){
            require(owner==msg.sender,"Not Admin");
           return allRequests[_id].finished;
    }
    function VerifyJobIsDone(uint256 _id)public returns(string memory){
        require (allRequests[_id].finished==true,"Repair not confirmed");
        allRequests[_id].approvals++;
        if (allRequests[_id].approvals>=2){
            if(allRequests[_id].verified=true){
                return("Repair already executed");
            }
            allRequests[_id].verified=true;
            //Send transfer to repairers
            repairers.transfer(allRequests[_id].cost);
            return ("Request verified and executed");
        }
        return ("Request verified");
    }

    function MoneyBack(uint256 _id)payable external {
        require(allRequests[_id].owner==msg.sender,"You are not the owner of the request!");
        require(!allRequests[_id].verified, "Request is verified");
        require(!allRequests[_id].refunded, "Request must not already be refunded");
        require(block.timestamp > allRequests[_id].timestamp + 2592000, "Cannot request refund before 1 month");
        
        allRequests[_id].refunded = true;
        allRequests[_id].owner.transfer(allRequests[_id].pay);
    }
}