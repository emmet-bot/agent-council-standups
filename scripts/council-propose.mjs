#!/usr/bin/env node

/**
 * council-propose.mjs
 *
 * Submit a governance proposal to CouncilGovernor via `propose()`.
 *
 * The proposal encodes a single target call. After submission the script
 * prints the proposal ID so callers can track it through
 * vote → queue → execute.
 *
 * Usage:
 *   CONTROLLER_PRIVATE_KEY=0x... \
 *   RPC_URL=https://...           \
 *   GOVERNOR_ADDRESS=0x...        \
 *     node council-propose.mjs \
 *       <targetAddress> \
 *       <calldata> \
 *       "Proposal description"
 *
 * Environment:
 *   CONTROLLER_PRIVATE_KEY   — EOA that controls the proposer's UP
 *   RPC_URL                  — JSON-RPC endpoint (LUKSO testnet or mainnet)
 *   GOVERNOR_ADDRESS         — CouncilGovernor contract address
 *
 * Example (no-op proposal for lifecycle test):
 *   CONTROLLER_PRIVATE_KEY=0x... \
 *   RPC_URL=https://rpc.testnet.lukso.network \
 *   GOVERNOR_ADDRESS=0xEB8774FF46313a49e832fC2d70DE8668DbEFaF20 \
 *     node council-propose.mjs \
 *       0xEB8774FF46313a49e832fC2d70DE8668DbEFaF20 \
 *       0x \
 *       "ACD-P9: Mainnet Governance Deployment"
 *
 * Notes:
 *   - The proposer must hold governance tokens (or meet the proposalThreshold).
 *   - Proposal description hash is included in the proposal ID — keep it
 *     consistent across vote/queue/execute calls.
 *   - Written by LUKSOAgent during P9 lifecycle test on 2026-03-30.
 */

import { ethers } from 'ethers';

const GOVERNOR_ABI = [
  'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) returns (uint256)',
  'function proposalThreshold() view returns (uint256)',
  'function state(uint256 proposalId) view returns (uint8)',
  'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) pure returns (uint256)',
];

const STATES = ['Pending', 'Active', 'Canceled', 'Defeated', 'Succeeded', 'Queued', 'Expired', 'Executed'];

async function main() {
  const privateKey = process.env.CONTROLLER_PRIVATE_KEY;
  const rpcUrl = process.env.RPC_URL;
  const governorAddress = process.env.GOVERNOR_ADDRESS;

  if (!privateKey || !rpcUrl || !governorAddress) {
    console.error('Required env vars: CONTROLLER_PRIVATE_KEY, RPC_URL, GOVERNOR_ADDRESS');
    process.exit(1);
  }

  const [targetAddress, calldata, description] = process.argv.slice(2);

  if (!targetAddress || calldata === undefined || !description) {
    console.error('Usage: node council-propose.mjs <targetAddress> <calldata> "<description>"');
    console.error('  calldata can be "0x" for a no-op proposal');
    process.exit(1);
  }

  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const wallet = new ethers.Wallet(privateKey, provider);

  console.log('Proposer EOA:  ', wallet.address);
  console.log('Governor:      ', governorAddress);
  console.log('Target:        ', targetAddress);
  console.log('Description:   ', description);
  console.log('Chain ID:      ', (await provider.getNetwork()).chainId.toString());
  console.log('');

  const governor = new ethers.Contract(governorAddress, GOVERNOR_ABI, wallet);

  const threshold = await governor.proposalThreshold();
  console.log('Proposal threshold:', threshold.toString(), 'COUNCIL tokens required');

  const targets = [targetAddress];
  const values = [0n];
  const calldatas = [calldata === '0x' ? '0x' : calldata];

  console.log('Submitting propose()...');
  const tx = await governor.propose(targets, values, calldatas, description);
  console.log('TX submitted:', tx.hash);

  const receipt = await tx.wait();
  console.log('Confirmed! Block:', receipt.blockNumber);

  // Decode ProposalCreated event to get proposalId
  const iface = new ethers.Interface([
    'event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)',
  ]);

  let proposalId = null;
  for (const log of receipt.logs) {
    try {
      const parsed = iface.parseLog(log);
      if (parsed && parsed.name === 'ProposalCreated') {
        proposalId = parsed.args.proposalId;
        console.log('');
        console.log('Proposal ID:  ', proposalId.toString());
        console.log('Vote start:   block', parsed.args.voteStart.toString());
        console.log('Vote end:     block', parsed.args.voteEnd.toString());
        break;
      }
    } catch (_) {}
  }

  if (!proposalId) {
    // Fallback: compute from hashProposal
    proposalId = await governor.hashProposal(
      targets,
      values,
      calldatas,
      ethers.keccak256(ethers.toUtf8Bytes(description))
    );
    console.log('Proposal ID (computed):', proposalId.toString());
  }

  const state = await governor.state(proposalId);
  console.log('Current state:', STATES[state] || state.toString());

  console.log('');
  console.log('Next steps:');
  console.log('  1. Wait for voteStart block, then cast votes');
  console.log('  2. After voteEnd, call queue() if Succeeded');
  console.log('  3. After timelock delay, call execute()');
  console.log('');
  console.log('cast send example for castVote (support=1 = FOR):');
  console.log(`  cast send ${governorAddress} "castVote(uint256,uint8)" ${proposalId} 1`);
}

main().catch(err => {
  console.error('Error:', err.reason || err.shortMessage || err.message);
  process.exit(1);
});
