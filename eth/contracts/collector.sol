// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

/**
 * @title Collector
 * @dev Retrieve value and store
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract Collector { // 0x45EB13b669b2E503914FB4855f97CaEA10cD8eA6
    address public owner;
    uint256 public balance;

    constructor() {
        owner = msg.sender;
    }

    // Accept any incoming amount
    receive() payable external {
        balance += msg.value;
    }
}
