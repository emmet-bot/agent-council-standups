// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CouncilToken} from "../src/governance/CouncilToken.sol";
import {CouncilTimelock} from "../src/governance/CouncilTimelock.sol";
import {CouncilGovernor} from "../src/governance/CouncilGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/**
 * @title DeployGovernance
 * @notice Foundry deploy script for the Agent Council governance stack.
 *
 *  Deploys:
 *   1. CouncilToken — mints to 4 agents
 *   2. CouncilTimelock — 1 day delay, Governor as proposer, open executor
 *   3. CouncilGovernor — wired to token + timelock
 *
 *  Post-deploy:
 *   - Grants PROPOSER_ROLE and CANCELLER_ROLE to the Governor on the Timelock.
 *   - Revokes deployer's TIMELOCK_ADMIN_ROLE so timelock is self-governed.
 *
 *  Usage:
 *   forge script script/DeployGovernance.s.sol --broadcast --rpc-url <RPC>
 *
 *  Set env vars:
 *   AGENT_1, AGENT_2, AGENT_3, AGENT_4  — council agent addresses
 *   DEPLOYER_PRIVATE_KEY                 — deployer private key
 */
contract DeployGovernance is Script {
    function run() external {
        // Read agent addresses from env
        address agent1 = vm.envAddress("AGENT_1");
        address agent2 = vm.envAddress("AGENT_2");
        address agent3 = vm.envAddress("AGENT_3");
        address agent4 = vm.envAddress("AGENT_4");

        vm.startBroadcast();

        // 1. Deploy CouncilToken
        CouncilToken token = new CouncilToken([agent1, agent2, agent3, agent4]);
        console.log("CouncilToken deployed at:", address(token));

        // 2. Deploy CouncilTimelock
        //    - proposers: empty (will be set after Governor deploy)
        //    - executors: [address(0)] = anyone can execute
        //    - admin: msg.sender (temporary, will be revoked)
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        CouncilTimelock timelock = new CouncilTimelock(proposers, executors, msg.sender);
        console.log("CouncilTimelock deployed at:", address(timelock));

        // 3. Deploy CouncilGovernor
        CouncilGovernor governor = new CouncilGovernor(IVotes(address(token)), TimelockController(payable(address(timelock))));
        console.log("CouncilGovernor deployed at:", address(governor));

        // 4. Grant PROPOSER_ROLE and CANCELLER_ROLE to the Governor
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // 5. Revoke deployer admin so timelock is fully self-governed
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), msg.sender);
        console.log("Admin revoked - timelock is self-governed");

        vm.stopBroadcast();
    }
}
