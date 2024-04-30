//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BlackJackDataFeed.sol";
import "./BlackJackVRF.sol";
import "./BUSDC.sol";
import {Test, console} from "forge-std/Test.sol";

pragma solidity ^0.8.19;

contract BlackJack is Ownable, Test {
    error NotPossible();
    error NotEnoughFunds();
    error SameHand();

    struct Dealer {
        uint256 funds;
        uint256 hand;
        uint256 currentHandId;
    }

    struct Player {
        address wallet;
        uint256 funds;
        uint256 hand;
        uint256 currentHandId;
        bool isPlayingHand;
    }

    BUSDC private Btoken;
    BlackJackDataFeed private BjDataFeed;
    BlackJackVRF private BjVRF;

    //mapping (address player => bool hasPlayed) hasPlayed;
    mapping(address => Player) public playerToInfo; //Here we store currentHandId
    //mapping(address => uint256) public dealerToPlayerHandId; //here we store on the side of the dealer the HandId
    mapping(uint256 handId => uint256 dealerHand) public dealerHands; //Here we store the hand of the dealer for the handId
    mapping(uint256 handId => bool isPlayed) isHandPlayed; //Here we store if the hand is played or not
    Dealer private dealer = Dealer(0, 0, 0);

    //address constant USDCAddress = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    modifier onlyowner() {
        require(msg.sender == owner());
        _;
    }

    constructor(address _busdcAddress, address _bjDataFeed, address _bjVRF) Ownable(msg.sender) {
        dealer.funds = ERC20(_busdcAddress).balanceOf(address(this));
        Btoken = BUSDC(_busdcAddress); //0x04965701C86F76a493069bdDB1683C393975C611
        BjDataFeed = BlackJackDataFeed(_bjDataFeed); //0x0654e483Ff874eC41CbB81B775bd72FaA79dcf6e
        BjVRF = BlackJackVRF(_bjVRF);
    }

    /// @notice You call this function to register as a player.
    /// @dev You need to send funds in ETH which will convert to BUSDC(peged to the dollar) to use for playing.

    function registerPlayer() public payable {
        require(msg.value > 0, "No funds sent");
        Player memory player = playerToInfo[msg.sender];
        require(player.wallet == address(0), "Registered already");
        //Calculate funds
        int256 ethPrice = getETHprice();
        uint256 amountToMint = (uint256(ethPrice) * 10 ** 18) / 10 ** 8;
        Player memory newPlayer = Player(msg.sender, amountToMint, 0, 0, false);
        playerToInfo[msg.sender] = newPlayer;

        Btoken.mint(msg.sender, amountToMint);
    }

    function testCallVrf(uint32 numWords) public returns (uint256) {
        return BjVRF.requestRandomWords(numWords);
    }

    function testCallBJDataFeed() public returns (int256) {
        return BjDataFeed.getChainlinkDataFeedLatestAnswer();
    }

    function enterBet(uint256 bet) external returns (uint256) {
        //Gotta make sure we are not playing the same hand over and over again.
        Player storage player = playerToInfo[msg.sender];
        require(!player.isPlayingHand, "Not allowed");
        require(player.wallet != address(0), "Not registered");
        require(bet <= BUSDC(Btoken).balanceOf(msg.sender), "Insufficient player funds");
        require(bet <= BUSDC(Btoken).balanceOf(address(this)), "Insufficient dealer funds");
        uint32 numWords = 2;
        player.funds -= bet;
        dealer.funds += bet;
        Btoken.transferFrom(msg.sender, address(this), bet);
        uint256 newrequestId = BjVRF.requestRandomWords(numWords); //Need 2 to get cards for the player and for the dealer

        player.currentHandId = newrequestId;
        player.isPlayingHand = true;

        return newrequestId;
    }

    /// @notice You call this function after you've registered and entered a bet.
    /// @dev This will return the players hand and the dealers hand.
    /// @param requestId The requestId from the VRF

    function getHand(uint256 requestId) public returns (int256, int256) {
        require(!isHandPlayed[requestId], "Hand played already");
        (bool isFulfilled, uint256[] memory randomNumbers) = BjVRF.getRequestStatus(requestId);
        console.log("Random num arr:", randomNumbers.length);

        for (uint i = 0; i < randomNumbers.length; i++) {
            console.log(randomNumbers[i]);
        }

        require(isFulfilled, "Request not fulfilled");
        console.log(randomNumbers.length);
        uint256[] memory playerPoints = getHandFromOneVRF(randomNumbers[0]);
        console.log("Player arr:", playerPoints.length);

        for (uint256 i = 0; i < playerPoints.length; i++) {
            console.log(playerPoints[i]);
        }
        uint256[] memory dealerPoints = getHandFromOneVRF(randomNumbers[1]);
        console.log("Dealer arr:", dealerPoints.length);
        for (uint256 i = 0; i < dealerPoints.length; i++) {
            console.log(dealerPoints[i]);
        }

        (int256 playerHand, bool isPlayerHandSoft) = calculateHand(playerPoints);
        (int256 dealerHand, bool isDealerHandSoft) = calculateHand(dealerPoints);
        // Record the hands;

        dealerHands[requestId] = uint256(dealerHand);
        playerToInfo[msg.sender].hand = uint256(playerHand);
        isHandPlayed[requestId] = true;

        return (playerHand, dealerHand);
    }

    fallback() external {
        registerPlayer();
    }

    function remainingPlayerFunds() external view returns (uint256) {
        Player memory player = playerToInfo[msg.sender];
        return player.funds; // In BUSDC
    }

    function withdrawFunds(uint256 amount) external {
        Player storage player = playerToInfo[msg.sender];
        require(player.funds > 0, "No funds left");
        require(player.funds >= amount, "No enough funds");
        player.funds -= amount;
        int256 ethPrice = BjDataFeed.getChainlinkDataFeedLatestAnswer();
        uint256 amountToSendToPlayerBack = amount * 10 ** 8 / uint256(ethPrice);
        Btoken.burn(msg.sender, amount);

        (bool success,) = msg.sender.call{value: amountToSendToPlayerBack}("");
        require(success, "Withdraw failed");
    }

    function getETHprice() public view returns (int256) {
        int256 feed = BjDataFeed.getChainlinkDataFeedLatestAnswer();
        return feed;
    }

    function calculateHand(uint256[] memory handPoints) private pure returns (int256, bool) {
        int256 firstCard = int256(handPoints[0]);
        int256 secondCard = int256(handPoints[1]);
        int256 firstCheck = int256(handPoints[2]);
        int256 secondCheck = int256(handPoints[3]);
        int256 hand = 0;

        //Check if we have 10's from 0s
        if (firstCard == 0) {
            firstCard = 10;
        }
        if (secondCard == 0) {
            secondCard = 10;
        }

        //Check if we have 10's by substracting
        if (firstCard != 0 && firstCard != 1) {
            //Make check if it is <0
            if (firstCard - firstCheck < 0) {
                firstCard = 10;
            }
        }
        if (secondCard != 0 && secondCard != 1) {
            //Make check if it is <0
            if (secondCard - secondCheck < 0) {
                secondCard = 10;
            }
        }

        //Check if we have Blackjack
        if ((firstCard == 10 && firstCard == 1) || (secondCard == 10 && secondCard == 1)) {
            hand = 100;
            return (hand, false); //BlackJack!
        }
        //Check if we have two aces
        if (firstCard == 1 && secondCard == 1) {
            hand = 12;

            return (hand, true);
        }
        //Check if we have soft hand
        if (firstCard == 1 || secondCard == 1) {
            if (firstCard == 1) {
                hand = 11 + secondCard;
            }
            if (secondCard == 1) {
                hand = 11 + firstCard;
            }
            return (hand, true);
        }

        hand = firstCard + secondCard;

        return (hand, false);
    }

    function getHandFromOneVRF(uint256 x) public pure returns (uint256[] memory) {
        uint256[] memory y = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            y[i] = (uint8((x / (10 ** i)) % 10));
        }
        return y;
    }

    function divArr(uint256[] memory arr) external pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < arr.length; i++) {
            sum += arr[i] % 10;
        }
        return sum;
    }

    function getPlayerStats(address playerAddress) public view returns (address, uint256, uint256, uint256, bool) {
        Player memory player = playerToInfo[playerAddress];
        return (player.wallet, player.funds, player.hand, player.currentHandId, player.isPlayingHand);
    }

    function renounceOwnership() public view override onlyOwner {
        revert NotPossible();
    }

    //29945765205364088472206773663980124860540389433803418837288208938022581593899
}
