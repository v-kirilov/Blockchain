# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Deploy address: 0xeC665842FD8aB1613f0DB843bEb98Ffc9E5ed50B
Try running some of the following tasks:

This contract is called CharityCamapaign, as the name suggests it is a 
charity campaign smartcontract thats create a campaign with unique Id, Name,
Description, a funding goal in ETH, and a deadline.

Any user can create a campaign and donate to one of his choosing.
For every donation an NFT is minted for the donator.

When a camapihn has reached it's goal, the creator can collect the Funds stored in the contract.
If the deadline has been reached but not the goal , every donator can withdraw his donation through the Refund function.


```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```