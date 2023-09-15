// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is ERC20, Ownable {
    constructor() ERC20("VoteToken", "VTK") {}

    function mint(address to, uint256 amount) internal {
        _mint(to, amount);
    }
}