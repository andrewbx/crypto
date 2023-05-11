// contracts/mytoken.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MyToken
 * @dev Create My Token
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract MyToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("MyToken", "MYT") {
        _mint(msg.sender, initialSupply);
    }
}
