![alt text](https://unsplash.com/photos/a-red-dollar-sign-sitting-next-to-a-green-arrow-Whh3kzHuGkk?auto=compress,format)
# **DeStake** Presale Platform

Welcome to **DeStake**! This platform is built using Solidity, designed to facilitate secure and transparent token presales. DeStake allows users to participate in early-stage token offerings, with a unique vesting period feature that ensures tokens are gradually released over time, preventing immediate market dumping.

## Features
* Secure and Transparent: All transactions are recorded on the Ethereum blockchain, ensuring transparency and security.
* Customizable Presale Parameters: Easily configure presale parameters such as start and end times for presales and vesting periods, token price, and maximum/minimum investment limits.
* Automated Token Distribution: Tokens are distributed to participants after the presale ends and the vesting period begins.
* Vesting Period: Tokens can be claimed gradually according to the vesting schedule, preventing immediate market sales.
* Whitelist/Blacklist Support: Option to enable a whitelist to restrict participation to approved investors only.
* Fund Management: Collected funds are securely stored in the contract and can be withdrawn only by the project owner.

## Smart Contract Overview
The DeStake platform is implemented through a series of smart contracts and test contracts written in Solidity and tested in Foundry. Here is a brief overview of the main contracts:

### DeStakePresale Contract
The core contract that manages the presale process. Key functions include:
* `buyTokens` : Allows participants to purchase tokens during the presale period.
* `claimTokens` : Enables participants to claim their tokens according to the vesting schedule after the presale has ended.
* `withdrawEth` : Allows the user to withdraw funds in case the presale has failed or liquidity pair is not provided.
* `withdrawFees` : Fees can be colected by the owner at any time.
* `increasePresaleDuration` : Presale duration can be increased by the owner at any point.
* `increaseVestingDuration` : Vesting duration can be increased by the owner at any point.
* `updateEthPricePerToken` : Price for the tokens can be updated by the owner at any point in time.
* `increaseHardCap` : Owner can increase the hardcap for the token.
* `blackList` : Owner can blacklist certain addresses from participating in the presale.
* `whiteList` : Owner can whitelist certain addresses to remove them from the blacklist if he so desires.
* `activateLiquidityPhase` : Owner can activate the liquidity phase of the contract at any point. 

## Vesting Mechanism
Tokens are not immediately available after the presale ends. Instead, they are released over a specified vesting period. The claimTokens function allows users to claim a portion of their purchased tokens based on the vesting schedule. This mechanism helps to prevent large token dumps on the market, promoting price stability.
