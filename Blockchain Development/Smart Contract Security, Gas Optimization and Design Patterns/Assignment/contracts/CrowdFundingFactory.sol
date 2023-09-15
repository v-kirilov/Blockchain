//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./CrowdFunding.sol";
using Counters for Counters.Counter;

contract CrowdFundingFactory {
    Counters.Counter public _id;
    address[] public CrowdFundings;

    event NewCrodFunding(address creator, address CrowdFundingAddress,uint256 id);

    function createCrowdFunding(string memory name, string memory description,uint256 fundingGoal,uint256 duration) external {
         address newCrodFunding = address(new CrowdFunding(_id.current(),name,description,fundingGoal,duration));

         CrowdFundings.push(newCrodFunding);
         emit NewCrodFunding(msg.sender,newCrodFunding,_id.current());
         _id.increment();
    }
}