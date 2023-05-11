// contracts/sillycoin.sol
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.20;

/**
 * @title SillyCoin
 * @dev Create SillyCoin Token
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract SillyCoin is ERC20 {
    constructor() ERC20("Silly Coin", "SILLY") {
        _mint(msg.sender, 69690000000 * 10 ** decimals());
    }
}
