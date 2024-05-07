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

    struct Player {
        address wallet;
        bool isPlayingHand;
    }

    struct Hand {
        address player;
        uint256 id;
        uint256 dealerHand;
        bool isDealerHandSoft;
        uint256 playerHand;
        bool isPlayerHandSoft;
        bool isHandPlayedOut;
        bool isHandDealt;
        uint256 timeHandIsDealt;
        uint256 playerBet;
    }

    BUSDC private Btoken;
    BlackJackDataFeed private BjDataFeed;
    BlackJackVRF private BjVRF;
    uint256 constant DURATION_OF_HAND = 10 * 20; //Max of 10 blocks

    mapping(address => Player) public playerToInfo; //Here we store player info
    mapping(uint256 handId => Hand hands) hands; //Store information about hands

    //address constant USDCAddress = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    modifier onlyowner() {
        require(msg.sender == owner());
        _;
    }

    constructor(address _busdcAddress, address _bjDataFeed, address _bjVRF) Ownable(msg.sender) {
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
        Player memory newPlayer = Player(msg.sender, false);
        playerToInfo[msg.sender] = newPlayer;

        Btoken.mint(msg.sender, amountToMint);
    }

    function testCallVrf(uint32 numWords) public returns (uint256) {
        return BjVRF.requestRandomWords(numWords);
    }

    function testCallBJDataFeed() public returns (int256) {
        return BjDataFeed.getChainlinkDataFeedLatestAnswer();
    }

    /// @notice You call this function to enter a bet as a player.
    /// @dev Player enters bet, funds are being transfered to the contract from the player.
    /// @dev Requires for the player to not be playing a hand.

    function enterBet(uint256 bet) external returns (uint256) {
        //Gotta make sure we are not playing the same hand over and over again.
        require(bet <= BUSDC(Btoken).balanceOf(msg.sender), "Insufficient player funds");
        require(bet <= BUSDC(Btoken).balanceOf(address(this)), "Insufficient dealer funds");

        Player storage player = playerToInfo[msg.sender];
        require(!player.isPlayingHand, "Not allowed");
        require(player.wallet != address(0), "Not registered");
        uint32 numWords = 2;
        Btoken.transferFrom(msg.sender, address(this), bet);
        uint256 newrequestId = BjVRF.requestRandomWords(numWords); //Need 2 to get cards for the player and for the dealer

        Hand memory hand = Hand(msg.sender, newrequestId, 0, false, 0, false, false, false, block.timestamp, bet);
        hands[newrequestId] = hand;

        player.isPlayingHand = true;

        return newrequestId;
    }

    /// @notice You call this function after you've registered and entered a bet.
    /// @dev This will return the players hand and the dealers hand.
    /// @param requestId The requestId from the VRF

    function getHand(uint256 requestId) public returns (int256, int256) {
        //require(!isHandPlayed[requestId], "Hand played already");
        Hand storage hand = hands[requestId];
        require(!hand.isHandPlayedOut, "Hand played already");
        require(!hand.isHandDealt, "Hand dealt already");
        (bool isFulfilled, uint256[] memory randomNumbers) = BjVRF.getRequestStatus(requestId);

        require(isFulfilled, "Request not fulfilled");
        uint256[] memory playerPoints = getHandFromOneVRF(randomNumbers[0]);

        uint256[] memory dealerPoints = getHandFromOneVRF(randomNumbers[1]);

        (int256 playerHand, bool isPlayerHandSoft) = calculateHand(playerPoints);
        (int256 dealerHand, bool isDealerHandSoft) = calculateHand(dealerPoints);

        // Record the hands;
        hand.playerHand = uint256(playerHand);
        hand.dealerHand = uint256(dealerHand);
        hand.isHandDealt = true;
        hand.timeHandIsDealt = block.timestamp;
        hand.isDealerHandSoft = isDealerHandSoft;
        hand.isPlayerHandSoft = isPlayerHandSoft;
        //! How to handle 'HIT' and 'DOUBLE' logic?

        return (playerHand, dealerHand);
    }

    /// @notice You call this function when you want to get another card for your hand.
    /// @dev This will return the players hand and the dealers hand.
    /// @param requestId The requestId from the VRF
    function hit(uint256 requestId) external returns (uint256) {
        Hand storage hand = hands[requestId];
        require(hand.isHandDealt, "Hand not dealt yet!");
        require(!hand.isHandPlayedOut, "Hand is played out!");
        if (hand.timeHandIsDealt + DURATION_OF_HAND < block.timestamp) {
            finishBet(requestId);
            return requestId;
            //Finish Hand
        }
    /// @notice You call this function when you want to get another card for your hand.
    /// @dev This will return the hand points for both player and dealer.
    /// @param handId The hand Id
    /// @param newRequestId The new requestId from the VRF
    function getHandFromHit(uint256 handId, uint256 newRequestId) public returns (uint256, uint256) {
        Hand memory hand = hands[handId];
        if (hand.playerHand == 100 && hand.dealerHand == 100) {
            revert BlackJack();
        }
        if (hand.playerHand > 21 || hand.dealerHand > 21) {
            revert NotPossible();
        }

        require(!hand.isHandPlayedOut, "Hand played already");
        require(hand.isHandDealt, "Hand not dealt");
        (bool isFulfilled, uint256[] memory randomNumbers) = BjVRF.getRequestStatus(newRequestId);
        require(isFulfilled, "Request not fulfilled yet!");
        if (msg.sender != address(this)) {
            (uint256 playerCard, uint256 playerCardCheck) = getCardFromOneVrf(randomNumbers[0]);
            (hand.playerHand, hand.isPlayerHandSoft) = calculateHit(hand.playerHand, playerCard, playerCardCheck);
        } else {
            (uint256 dealerCard, uint256 dealerCardCheck) = getCardFromOneVrf(randomNumbers[0]);
            (hand.dealerHand, hand.isDealerHandSoft) = calculateHit(hand.dealerHand, dealerCard, dealerCardCheck);
        }

        // Record hand
        makeNewHand(
            handId, newRequestId, hand.dealerHand, hand.isDealerHandSoft, hand.playerHand, hand.isPlayerHandSoft
        );
        return (hand.playerHand, hand.dealerHand);
        }

    function calculateHit(uint256 hand, uint256 newCard, uint256 cardCheck)
        private
        returns (uint256, bool isSoftHand)
    {
        if (newCard == 1) {
            if (newCard + 11 > 21) {
                return (hand + 1, false);
            } else {
                return (hand + 11, true);
            }
        } else if (newCard - cardCheck > 0) {
            return (hand + newCard, false);
        } else {
            return (hand + 10, false);
        }
    }

    function makeNewHand(
        uint256 requestId,
        uint256 newRequestId,
        uint256 dealerPoints,
        bool isDealerHandSoft,
        uint256 playerPoints,
        bool isPlayerHandSoft
    ) private {
        Hand memory oldHand = hands[requestId];
        Hand memory newHand = Hand(
            oldHand.player,
            newRequestId,
            dealerPoints,
            isDealerHandSoft,
            playerPoints,
            isPlayerHandSoft,
            oldHand.isHandPlayedOut,
            oldHand.isHandDealt,
            block.timestamp,
            oldHand.playerBet
        );
        hands[newRequestId] = newHand;
    }

    //! Here we can incorporate the logic for the dealer to hit or not.
    //! Remember 100 is BlackJack
    function finishBet(uint256 requestId) public {
        Hand storage hand = hands[requestId];
        require(hand.isHandDealt, "Hand not dealt yet!");
        require(!hand.isHandPlayedOut, "Hand is played out!");
        hand.isHandPlayedOut = true;
        Player storage player = playerToInfo[hand.player];
        if (hand.playerHand == 100 && hand.dealerHand == 100) {
            Btoken.transferFrom(address(this), msg.sender, hand.playerBet);
        } else if (hand.playerHand == 100) {
            Btoken.transferFrom(address(this), msg.sender, hand.playerBet * 25 / 10);
        } else if (hand.dealerHand == 100) {
            return;
        }

        if (hand.playerHand > 21) {
            return;
        } else if (hand.dealerHand > 21) {
            Btoken.transferFrom(address(this), msg.sender, hand.playerBet * 2);
        }

        if (hand.playerHand > hand.dealerHand) {
            Btoken.transferFrom(address(this), msg.sender, hand.playerBet * 2);
        } else if (hand.playerHand == hand.dealerHand) {
            Btoken.transferFrom(address(this), msg.sender, hand.playerBet);
        }
        player.isPlayingHand = false;

        //Finish Hand
    }

    fallback() external {
        registerPlayer();
    }

    function remainingPlayerFunds() external view returns (uint256) {
        Player memory player = playerToInfo[msg.sender];
        return Btoken.balanceOf(msg.sender); // In BUSDC
    }

    function withdrawFunds(uint256 amount) external {
        Player storage player = playerToInfo[msg.sender];
        require(Btoken.balanceOf(msg.sender) >= amount, "Not enough funds");
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

    function getHandFromOneVRF(uint256 num) public pure returns (uint256[] memory) {
        uint256[] memory y = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            y[i] = (uint8((num / (10 ** i)) % 10));
        }
        return y;
    }

    function getCardFromOneVrf(uint256 x) public pure returns (uint256 card, uint256 cardCheck) {
        card = (uint8(x % 10));
        cardCheck = (uint8((x / 10) % 10));
    }

    function divArr(uint256[] memory arr) external pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < arr.length; i++) {
            sum += arr[i] % 10;
        }
        return sum;
    }

    function getPlayerStats(address playerAddress) public view returns (address, uint256, bool) {
        Player memory player = playerToInfo[playerAddress];
        return (player.wallet, Btoken.balanceOf(playerAddress), player.isPlayingHand);
    }

    function renounceOwnership() public view override onlyOwner {
        revert NotPossible();
    }

    //29945765205364088472206773663980124860540389433803418837288208938022581593899
}
