// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CouncilToken} from "../src/governance/CouncilToken.sol";
import {CouncilTimelock} from "../src/governance/CouncilTimelock.sol";
import {CouncilGovernor} from "../src/governance/CouncilGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title DeployGovernance
 * @notice Deploys the full Agent Council governance stack:
 *         1. CouncilToken (ERC20Votes)
 *         2. CouncilTimelock (TimelockController)
 *         3. CouncilGovernor
 *         Then grants PROPOSER_ROLE and EXECUTOR_ROLE to the Governor on the Timelock.
 *
 * @dev Usage:
 *   forge script script/DeployGovernance.s.sol:DeployGovernance \
 *     --rpc-url $RPC_URL --broadcast --verify
 *
 *   Env vars: AGENT1, AGENT2, AGENT3, AGENT4 (addresses of the 4 council agents)
 */
contract DeployGovernance is Script {
    function run() external {
        address agent1 = vm.envAddress("AGENT1");
        address agent2 = vm.envAddress("AGENT2");
        address agent3 = vm.envAddress("AGENT3");
        address agent4 = vm.envAddress("AGENT4");

        vm.startBroadcast();

        // 1. Deploy token
        CouncilToken token = new CouncilToken(agent1, agent2, agent3, agent4);
        console.log("CouncilToken deployed at:", address(token));

        // 2. Deploy timelock (empty proposers/executors initially, self-administered)
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        CouncilTimelock timelock = new CouncilTimelock(proposers, executors, msg.sender);
        console.log("CouncilTimelock deployed at:", address(timelock));

        // 3. Deploy governor
        CouncilGovernor governor = new CouncilGovernor(IVotes(address(token)), TimelockController(payable(address(timelock))));
        console.log("CouncilGovernor deployed at:", address(governor));

        // 4. Grant roles to governor on timelock
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 cancellerRole = timelock.CANCELLER_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(governor));
        timelock.grantRole(cancellerRole, address(governor));

        // 5. Revoke admin role from deployer (self-administered)
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), msg.sender);

        vm.stopBroadcast();

        console.log("Governance stack deployed successfully");
    }
}
