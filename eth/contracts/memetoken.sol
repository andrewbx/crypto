// contracts/memetoken.sol
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

pragma solidity ^0.8.20;

/**
 * @title MemeToken
 * @dev Create Meme Token
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract MemeToken is ERC20, ERC20Burnable, Ownable {
    uint256 private constant INITIAL_SUPPLY = 69690000000 * 10**18;

    constructor() ERC20("MemeToken", "MEME") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function distributeTokens(address distributionWallet) external onlyOwner {
        uint256 supply = balanceOf(msg.sender);
        require(supply == INITIAL_SUPPLY, "Tokens already distributed");

        _transfer(msg.sender, distributionWallet, supply);
    }
}
