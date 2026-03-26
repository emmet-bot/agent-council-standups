// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CouncilToken} from "../src/governance/CouncilToken.sol";
import {CouncilTimelock} from "../src/governance/CouncilTimelock.sol";
import {CouncilGovernor} from "../src/governance/CouncilGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract CouncilGovernorTest is Test {
    CouncilToken public token;
    CouncilTimelock public timelock;
    CouncilGovernor public governor;

    address public agent1 = makeAddr("agent1");
    address public agent2 = makeAddr("agent2");
    address public agent3 = makeAddr("agent3");
    address public agent4 = makeAddr("agent4");

    address public target;
    uint256 public constant SHARE = 250_000 * 1e18;

    event ValueChanged(uint256 newValue);

    function setUp() public {
        // Deploy token
        token = new CouncilToken(agent1, agent2, agent3, agent4);

        // Deploy timelock (empty proposers/executors, self-administered with this test as admin)
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can execute
        timelock = new CouncilTimelock(proposers, executors, address(this));

        // Deploy governor
        governor = new CouncilGovernor(
            IVotes(address(token)),
            TimelockController(payable(address(timelock)))
        );

        // Grant roles to governor
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // Renounce admin
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), address(this));

        // Agents self-delegate to activate voting power
        vm.prank(agent1);
        token.delegate(agent1);
        vm.prank(agent2);
        token.delegate(agent2);
        vm.prank(agent3);
        token.delegate(agent3);
        vm.prank(agent4);
        token.delegate(agent4);

        // Deploy a simple target contract for proposals
        target = address(new MockTarget());

        // Roll forward 1 block so delegation checkpoint is in the past
        vm.roll(block.number + 1);
    }

    // ============ Token Tests ============

    function test_TokenSupply() public view {
        assertEq(token.totalSupply(), 1_000_000 * 1e18);
    }

    function test_TokenDistribution() public view {
        assertEq(token.balanceOf(agent1), SHARE);
        assertEq(token.balanceOf(agent2), SHARE);
        assertEq(token.balanceOf(agent3), SHARE);
        assertEq(token.balanceOf(agent4), SHARE);
    }

    function test_TokenVotingPower() public view {
        assertEq(token.getVotes(agent1), SHARE);
        assertEq(token.getVotes(agent2), SHARE);
    }

    function test_TokenName() public view {
        assertEq(token.name(), "Council Token");
        assertEq(token.symbol(), "COUNCIL");
    }

    // ============ Governor Settings Tests ============

    function test_GovernorSettings() public view {
        assertEq(governor.votingDelay(), 1);
        assertEq(governor.votingPeriod(), 50400);
        assertEq(governor.proposalThreshold(), 1e18);
    }

    function test_GovernorName() public view {
        assertEq(governor.name(), "CouncilGovernor");
    }

    function test_Quorum() public view {
        // 10% of 1M = 100K tokens
        assertEq(governor.quorum(block.number - 1), 100_000 * 1e18);
    }

    // ============ Timelock Tests ============

    function test_TimelockMinDelay() public view {
        assertEq(timelock.getMinDelay(), 86400);
    }

    // ============ Proposal Lifecycle Tests ============

    function test_ProposeAndVote() public {
        // Create a proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = target;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setValue(uint256)", 42);

        // Agent1 proposes
        vm.prank(agent1);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Set value to 42");

        // Check state is Pending
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));

        // Advance past voting delay
        vm.roll(block.number + 2);

        // Check state is Active
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));

        // Agent1 votes For (1 = For in GovernorCountingSimple)
        vm.prank(agent1);
        governor.castVote(proposalId, 1);

        // Agent2 votes For
        vm.prank(agent2);
        governor.castVote(proposalId, 1);

        // Check vote counts
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        assertEq(forVotes, SHARE * 2);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function test_FullProposalLifecycle() public {
        // Create a proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = target;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setValue(uint256)", 42);

        // Agent1 proposes
        vm.prank(agent1);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Set value to 42");

        // Advance past voting delay
        vm.roll(block.number + 2);

        // Agent1 + Agent2 vote For (50% > 10% quorum)
        vm.prank(agent1);
        governor.castVote(proposalId, 1);
        vm.prank(agent2);
        governor.castVote(proposalId, 1);

        // Advance past voting period
        vm.roll(block.number + 50401);

        // Check state is Succeeded
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        // Queue the proposal
        governor.queue(targets, values, calldatas, keccak256(bytes("Set value to 42")));
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        // Advance past timelock delay
        vm.warp(block.timestamp + 86401);

        // Execute the proposal
        governor.execute(targets, values, calldatas, keccak256(bytes("Set value to 42")));
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));

        // Verify the target was called
        assertEq(MockTarget(target).value(), 42);
    }

    function test_ProposalBelowThresholdReverts() public {
        // Create an address with no tokens
        address nobody = makeAddr("nobody");

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = target;

        vm.prank(nobody);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "Should fail");
    }

    function test_ProposalDefeated() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = target;
        calldatas[0] = abi.encodeWithSignature("setValue(uint256)", 99);

        vm.prank(agent1);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Doomed proposal");

        // Advance past voting delay
        vm.roll(block.number + 2);

        // Only agent3 votes Against (0 = Against)
        vm.prank(agent3);
        governor.castVote(proposalId, 0);

        // Advance past voting period
        vm.roll(block.number + 50401);

        // Check state is Defeated (no quorum met with only against votes)
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }
}

/// @dev Simple target contract for governance proposals
contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
}
