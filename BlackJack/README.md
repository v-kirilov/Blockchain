A game of BlackJack onchain.

Project is build in Foundry.

User can deposit directly to the contract via `registerPlayer` function, which will register him and convert his ETH 
based on current price, to BUSDC token which is 1:1 pegged to the dollar.

Then by using the function `enterBet` the player transfers his BUSDC to the dealer contract and the contract
will request two random words from a chainlink VRF which will be used to calculate the hands of the player
and the dealer. At this point a `hand` struct will be created keeping all of the necessary information.
It is important to keep in mind that the user will have 10 blocks of time to finish his bet.
If user is satisfied with his hand, he can call the `finishBet` function that will transfer the state
into one that will finish the game. At that point if the dealer has less than 16 the contract will call the 
`dealerHit` function to get another random number for a card. A new hand will be created and time will be updated and restarted.
 The player must call the `getHandFromHit` function so that the new state is updated , and after that he can call the `finishBet` function again.
If the player is not satisfied with his hand, he can call the `playerHit` function and follow the same logic.

Upon finishing the bet the contract will calculate the corresponding outcome and transfer the winnings in BUSDC.

At any point the user can decide to withdraw his ETH from the contract, if he is not participating in any hand.



![alt text](https://images.prismic.io/desplaines-rushstreetgaming/1c8e0aa3-6b2d-4f01-a49e-15b556dc0882_03253_March-Blackjack-Blowout-Email_Image_1200x650_v1_210223.jpg?auto=compress,format)

At the moment the codebase has 93% unit test coverage.