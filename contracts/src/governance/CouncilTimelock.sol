// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title CouncilTimelock
 * @notice TimelockController for the Agent Council governance system (P9).
 *
 *  Min delay: 1 day (86400 seconds).
 *  Proposers: set post-deploy (the Governor contract).
 *  Executors: address(0) means anyone can execute once the delay has passed.
 *  Admin: renounced after setup (address(0)).
 */
contract CouncilTimelock is TimelockController {
    uint256 public constant MIN_DELAY = 1 days; // 86400 seconds

    /**
     * @param proposers Addresses allowed to schedule operations (typically the Governor).
     * @param executors Addresses allowed to execute operations. Pass [address(0)] for open execution.
     * @param admin     Initial admin. Pass address(0) to leave self-administered only.
     */
    constructor(
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(MIN_DELAY, proposers, executors, admin) {}
}
