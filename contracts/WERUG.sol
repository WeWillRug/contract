// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WeRug is ERC20 {
    constructor() ERC20("WeWillRug", "WERUG") {
        _mint(msg.sender, 300000000 * 10 ** decimals());
    }
}
