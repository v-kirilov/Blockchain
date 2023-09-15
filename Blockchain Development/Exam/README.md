# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract.

Deploy address: 0x31900498D986fD1EB69dd11E1534870a29a8a699
https://sepolia.etherscan.io/address/0x31900498D986fD1EB69dd11E1534870a29a8a699#code

This contract is called Organization, as the name suggests it is a 
organization with treasuries smartcontract that the owner can create a treasury on.
People that contribute to the organization get minted ERC20 tokens that they can use for votes, 
to vote for the specific withdrawals

Withdrawals can be created by the owner with unique Id , amount , description and duration.

The owner can execute withdrawal to e certain address , only if there are more votes for yes , rather than no,
or if noone voted.



```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```