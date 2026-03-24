# P9 — Governance Token Specification

**Status:** Research phase (approved March 23, 2026)  
**Target:** Contracts ready March 26, testnet deploy March 27-28  
**Latest Update:** March 24, 2026 11:32 CET

## Phase 1: LUKSO Testnet Solo Validation

### Core Parameters (LOCKED)
- **Base Contract:** LSP7VotesInitAbstract (inherits OZ IERC5805/IVotes)
- **Governor:** OpenZeppelin Governor + TimelockController
- **Chain:** LUKSO testnet ONLY
- **Token Name:** COUNCIL (or CNCL ticker)
- **Voting Period:** 3 days
- **Proposal Threshold:** 1 token
- **Quorum:** 10% of total supply
- **Unit Tests:** Required before testnet validation

### Token Distribution (LOCKED - March 24)
**Skewed distribution for adversarial testing:**
- 40% → Agent 1
- 30% → Agent 2  
- 20% → Agent 3
- 10% → Agent 4

**Rationale:** Equal 25/25/25/25 split means any single agent hits quorum solo, making governance testing trivial. The 10% holder cannot meet quorum alone, forcing coalition-building and surfacing realistic failure modes.

### Treasury Balance Hook
**Phase 1 Implementation:** Manual operating rule (see `OPERATING-RULES.md`)
- Proposer includes balance snapshot (chain, wallet, block, balance)
- Second council member confirms before proposal advances
- Target: 0.01 ETH minimum per chain

**Phase 2:** On-chain `_validateTreasuryBalance()` hook in Governor contract

### Deploy Script Requirements
- Documents solo-quorum rationale (250k/agent in equal split = too easy)
- Unit tests for IVotes checkpoints + proposal lifecycle
- Testnet validation before any mainnet discussion

## Phase 2: Multi-Agent Stress Testing
- Skewed distribution implemented on-chain
- Test quorum mechanics, coalition formation, proposal spam resistance
- Validate emergency guardian mechanisms

## Phase 3: Mainnet (NOT APPROVED - Requires Separate Vote)
- Cross-chain deployment (LUKSO + Base + Ethereum)
- Final token economics
- Production treasury hooks
- Guardian key handoff

---

**Related:** 
- Operating Rules: `OPERATING-RULES.md`
- Standup: `standups/2026-03-23.md`
