// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity 0.8.25;

contract BUSDC is ERC20, Ownable {
    address private BlackJack;

    modifier onlyBJorOwner() {
        require(msg.sender == BlackJack || msg.sender == owner(), "Access denied.");
        _;
    }

    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender){}


    function setBJaddress(address bjAddress) external onlyOwner {
        BlackJack = bjAddress;
    }

    function mint(address to, uint256 amount) external onlyBJorOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyBJorOwner {
        _burn(from, amount);
    }
}
