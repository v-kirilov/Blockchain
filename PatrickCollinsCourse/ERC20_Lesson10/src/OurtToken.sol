// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OurToken is ERC20{
    constructor(uint256 initialSupply) ERC20("OurToken", "OT") {
        _mint(msg.sender, initialSupply);
    }
}

// make deploy
// forge script script/DeployOurToken.s.sol:DeployOurToken --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
// make avnil
// anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1