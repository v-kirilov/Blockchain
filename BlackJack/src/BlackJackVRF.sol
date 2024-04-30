// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

import {VRFCoordinatorV2Interface} from "@chainlink/src/interfaces/vrf/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from
    "@chainlink/lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract BlackJackVRF is VRFConsumerBaseV2, Ownable {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }

    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    address private BlackJack;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    //uint32 public callbackGasLimit = 100000;
    uint32 public callbackGasLimitPerWord = 20000;

    // The default is 3, but you can set this higher.
    uint16 public requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    // uint32 public numWords = 2;

    modifier onlyBJorOwner() {
        require(msg.sender == BlackJack || msg.sender == owner(), "Access denied.");
        _;
    }

    /**
     * HARDCODED FOR SEPOLIA
     * COORDINATOR: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
     */
    constructor(uint64 subscriptionId, address coordinator, address bjAddress, bytes32 _keyHash)
        VRFConsumerBaseV2(coordinator)
        Ownable(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(coordinator);
        s_subscriptionId = subscriptionId;
        BlackJack = bjAddress;
        keyHash = _keyHash;
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords(uint32 _numWords)
        external
        onlyBJorOwner
        returns (uint256 requestId)
    {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash, s_subscriptionId, requestConfirmations, callbackGasLimitPerWord*_numWords, _numWords
        );
        s_requests[requestId] = RequestStatus({randomWords: new uint256[](0), exists: true, fulfilled: false});
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, _numWords);
        return requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(uint256 _requestId)
        external
        view
        returns (bool fulfilled, uint256[] memory randomWords)
    {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    function setRequestConfirmations(uint16 _requestConfirmations) external onlyBJorOwner {
        requestConfirmations = _requestConfirmations;
    }

    function setBJaddress(address bjAddress) external onlyOwner {
        BlackJack = bjAddress;
    }

    function setKeyHash(bytes32 _keyHash) external onlyBJorOwner {
        keyHash = _keyHash;
    }

    function setCallbackGasLimitPerWord(uint32 _callbackGasLimitPerWord) external onlyBJorOwner {
        callbackGasLimitPerWord = _callbackGasLimitPerWord;
    }
}
