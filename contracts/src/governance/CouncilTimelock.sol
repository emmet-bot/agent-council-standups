// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title CouncilTimelock
 * @notice TimelockController for the Agent Council governance system.
 *         Enforces a 1-day minimum delay on all governance operations.
 */
contract CouncilTimelock is TimelockController {
    uint256 public constant MIN_DELAY = 86400; // 1 day

    /**
     * @param proposers Addresses that can propose (typically the Governor)
     * @param executors Addresses that can execute (address(0) = anyone)
     * @param admin     Optional admin address (address(0) = self-administered)
     */
    constructor(
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(MIN_DELAY, proposers, executors, admin) {}
}
