// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

contract MyToken {
    mapping(address => uint) private s_balances;
    string public name = "Manual Token";

    constructor() {}

    // function name() public pure returns (string memory) {
    //     return "Manuaa Token";
    // }

    function totalSupply() public pure returns (uint256) {
        return 100 ether;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function balanceOf(address owner) public view returns (uint256) {
        return s_balances[owner];
    }

    function transfer(address _to, uint256 _amount) public {
        uint256 previousBalance = balanceOf(msg.sender) + balanceOf(_to);
        s_balances[msg.sender] -= _amount;
        s_balances[_to] += _amount;
        require(balanceOf(msg.sender) + balanceOf(_to) == previousBalance);
    }
}
