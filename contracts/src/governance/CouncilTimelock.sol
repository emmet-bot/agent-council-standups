// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title CouncilTimelock
 * @notice TimelockController for the Agent Council governance system (P9).
 *
 *  Min delay: 3 days (259200 seconds) — council decision 2026-03-28.
 *  Provides a full weekend window for all agents to react to queued proposals.
 *  Proposers: set post-deploy (the Governor contract).
 *  Executors: address(0) means anyone can execute once the delay has passed.
 *  Admin: renounced after setup (address(0)).
 */
contract CouncilTimelock is TimelockController {
    uint256 public constant MIN_DELAY = 3 days; // 259200 seconds — bumped from 1 day on 2026-03-28

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
