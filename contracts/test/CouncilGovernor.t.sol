// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CouncilToken} from "../src/governance/CouncilToken.sol";
import {CouncilTimelock} from "../src/governance/CouncilTimelock.sol";
import {CouncilGovernor} from "../src/governance/CouncilGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/**
 * @title CouncilGovernorTest
 * @notice Full propose → vote → queue → execute flow test for Agent Council governance.
 */
contract CouncilGovernorTest is Test {
    CouncilToken public token;
    CouncilTimelock public timelock;
    CouncilGovernor public governor;

    address public agent1 = makeAddr("agent1");
    address public agent2 = makeAddr("agent2");
    address public agent3 = makeAddr("agent3");
    address public agent4 = makeAddr("agent4");

    // Target contract for governance action
    address public target = makeAddr("target");

    function setUp() public {
        // 1. Deploy token — mints to 4 agents
        token = new CouncilToken([agent1, agent2, agent3, agent4]);

        // 2. Deploy timelock — deployer as temp admin
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can execute
        timelock = new CouncilTimelock(proposers, executors, address(this));

        // 3. Deploy governor
        governor = new CouncilGovernor(
            IVotes(address(token)),
            TimelockController(payable(address(timelock)))
        );

        // 4. Grant Governor proposer + canceller roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // 5. Revoke deployer admin
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), address(this));

        // 6. Agents delegate to themselves (activate voting power)
        vm.prank(agent1);
        token.delegate(agent1);
        vm.prank(agent2);
        token.delegate(agent2);
        vm.prank(agent3);
        token.delegate(agent3);
        vm.prank(agent4);
        token.delegate(agent4);

        // 7. Mine one block so delegation checkpoints are active
        vm.roll(block.number + 1);
    }

    function test_fullGovernanceFlow() public {
        // Fund the timelock so it can send ETH
        vm.deal(address(timelock), 1 ether);

        // ── Propose ──
        address[] memory targets = new address[](1);
        targets[0] = target;
        uint256[] memory values = new uint256[](1);
        values[0] = 0.5 ether;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = ""; // just send ETH
        string memory description = "Send 0.5 ETH to target";

        vm.prank(agent1);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Verify proposal is Pending
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));

        // ── Advance past voting delay (1 block) ──
        vm.roll(block.number + 2);

        // Verify proposal is Active
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));

        // ── Vote — 3 of 4 agents vote For ──
        vm.prank(agent1);
        governor.castVote(proposalId, 1); // For
        vm.prank(agent2);
        governor.castVote(proposalId, 1); // For
        vm.prank(agent3);
        governor.castVote(proposalId, 1); // For
        // agent4 doesn't vote

        // ── Advance past voting period (50400 blocks) ──
        vm.roll(block.number + 50401);

        // Verify proposal succeeded
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        // ── Queue ──
        bytes32 descHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descHash);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        // ── Advance past timelock delay (1 day) ──
        vm.warp(block.timestamp + 1 days + 1);

        // ── Execute ──
        uint256 balanceBefore = target.balance;
        governor.execute(targets, values, calldatas, descHash);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
        assertEq(target.balance, balanceBefore + 0.5 ether);
    }

    function test_proposalThreshold() public view {
        assertEq(governor.proposalThreshold(), 1e18);
    }

    function test_votingDelay() public view {
        assertEq(governor.votingDelay(), 1);
    }

    function test_votingPeriod() public view {
        assertEq(governor.votingPeriod(), 50400);
    }

    function test_quorum() public view {
        // 10% of 1,000,000 tokens = 100,000
        uint256 q = governor.quorum(block.number - 1);
        assertEq(q, 100_000 ether);
    }

    function test_proposalFailsWithoutQuorum() public {
        // Fund the timelock
        vm.deal(address(timelock), 1 ether);

        // Propose
        address[] memory targets = new address[](1);
        targets[0] = target;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        string memory description = "No quorum test";

        vm.prank(agent1);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Advance past voting delay
        vm.roll(block.number + 2);

        // Only agent4 votes (25% supply = 250,000) — wait, that's > 10% quorum
        // Let's test with 0 votes by not voting at all

        // Advance past voting period
        vm.roll(block.number + 50401);

        // Proposal should be defeated (no votes)
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }

    function test_cannotProposeWithoutEnoughTokens() public {
        address nobody = makeAddr("nobody");

        address[] memory targets = new address[](1);
        targets[0] = target;
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        vm.prank(nobody);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "Should fail");
    }

    function test_timelockDelayEnforced() public {
        vm.deal(address(timelock), 1 ether);

        // Propose
        address[] memory targets = new address[](1);
        targets[0] = target;
        uint256[] memory values = new uint256[](1);
        values[0] = 0.1 ether;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        string memory description = "Timelock delay test";

        vm.prank(agent1);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + 2);

        // Vote
        vm.prank(agent1);
        governor.castVote(proposalId, 1);
        vm.prank(agent2);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + 50401);

        // Queue
        bytes32 descHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descHash);

        // Try to execute immediately — should revert (timelock not ready)
        vm.expectRevert();
        governor.execute(targets, values, calldatas, descHash);

        // After delay — should succeed
        vm.warp(block.timestamp + 1 days + 1);
        governor.execute(targets, values, calldatas, descHash);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
    }
}
