// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CouncilTokenLSP7} from "../src/governance/CouncilTokenLSP7.sol";
import {CouncilGovernor} from "../src/governance/CouncilGovernor.sol";
import {CouncilTimelock} from "../src/governance/CouncilTimelock.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/**
 * @title DeployCouncilTokenLSP7
 * @notice P11 deployment script — CouncilTokenLSP7 + CouncilGovernor + CouncilTimelock.
 *
 * Usage (LUKSO testnet):
 *   forge script script/DeployCouncilTokenLSP7.s.sol \
 *     --rpc-url lukso_testnet \
 *     --broadcast \
 *     --private-key $PRIVATE_KEY \
 *     -vvvv
 *
 * Required env vars:
 *   PRIVATE_KEY      — deployer private key (hex, with 0x prefix)
 *   AGENT1_ADDRESS   — council agent 1 (40% COUNCIL)
 *   AGENT2_ADDRESS   — council agent 2 (30% COUNCIL)
 *   AGENT3_ADDRESS   — council agent 3 (20% COUNCIL)
 *   AGENT4_ADDRESS   — council agent 4 (10% COUNCIL)
 *
 * Optional env vars:
 *   TIMELOCK_DELAY   — timelock min delay in seconds (default: 86400 = 1 day)
 *
 * Deployment sequence:
 *   1. Deploy CouncilTokenLSP7 with agent addresses → mints + auto-delegates
 *   2. Deploy CouncilTimelock (proposers empty, executors = [address(0)] = anyone)
 *   3. Deploy CouncilGovernor pointing at LSP7 token + timelock
 *   4. Grant PROPOSER_ROLE + CANCELLER_ROLE to Governor
 *   5. Revoke DEFAULT_ADMIN_ROLE from deployer
 *
 * After deploy, log all addresses and verify IVotes integration is live.
 */
contract DeployCouncilTokenLSP7 is Script {
    function run() external {
        // ── Load env ──
        address agent1 = vm.envAddress("AGENT1_ADDRESS");
        address agent2 = vm.envAddress("AGENT2_ADDRESS");
        address agent3 = vm.envAddress("AGENT3_ADDRESS");
        address agent4 = vm.envAddress("AGENT4_ADDRESS");
        uint256 timelockDelay = vm.envOr("TIMELOCK_DELAY", uint256(1 days));

        console.log("=== P11 CouncilTokenLSP7 Deployment ===");
        console.log("Agent1:", agent1);
        console.log("Agent2:", agent2);
        console.log("Agent3:", agent3);
        console.log("Agent4:", agent4);
        console.log("Timelock delay:", timelockDelay, "seconds");

        vm.startBroadcast();

        // ── 1. Deploy token ──
        CouncilTokenLSP7 token = new CouncilTokenLSP7([agent1, agent2, agent3, agent4]);
        console.log("CouncilTokenLSP7 deployed at:", address(token));

        // ── 2. Deploy timelock ──
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can execute after delay
        CouncilTimelock timelock = new CouncilTimelock(proposers, executors, msg.sender);
        console.log("CouncilTimelock deployed at:", address(timelock));

        // ── 3. Deploy governor ──
        CouncilGovernor governor = new CouncilGovernor(
            IVotes(address(token)),
            TimelockController(payable(address(timelock)))
        );
        console.log("CouncilGovernor deployed at:", address(governor));

        // ── 4. Wire roles ──
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), msg.sender);
        console.log("Roles granted and admin revoked.");

        vm.stopBroadcast();

        // ── Post-deploy verification log ──
        console.log("\n=== Post-Deploy Checks ===");
        console.log("Token totalSupply:", token.totalSupply());
        console.log("Agent1 balance:", token.balanceOf(agent1));
        console.log("Agent2 balance:", token.balanceOf(agent2));
        console.log("Agent3 balance:", token.balanceOf(agent3));
        console.log("Agent4 balance:", token.balanceOf(agent4));
        console.log("Agent1 votes:", token.getVotes(agent1));
        console.log("Governor token:", address(governor.token()));
        console.log("Governor timelock:", address(governor.timelock()));
        console.log("Quorum (current):", governor.quorum(block.number - 1));

        console.log("\n=== Summary ===");
        console.log("Token:    ", address(token));
        console.log("Timelock: ", address(timelock));
        console.log("Governor: ", address(governor));
    }
}
