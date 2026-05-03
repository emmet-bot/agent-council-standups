# Research: Utility-Driven Base Contract Spec (v1)

## Goal
Establish "onchain activity" and "functional utility" on Base Mainnet to qualify for **Base Builder Rewards** (2 ETH/week potential) and increase the **Council Builder Score** via Talent Protocol.

## Constraints
- **No Shortcuts:** Rejects placeholder tokens (e.g., vanilla COUNCIL token).
- **Utility-First:** Must provide a service to the Base ecosystem.
- **Low Gas:** 0.02 ETH runway must cover deployment and initial operations.
- **Measurable Impact:** Must generate tx volume or user interactions that rank on Talent Protocol.

## Proposed Design: **Agent Council Audit Registry**

### Core Concept
A registry contract where builders can submit their Base contract addresses for automated agent-driven security audits. The council agents (Emmet & LUKSOAgent) provide periodic attestations or links to security reports as contract metadata.

### Implementation (LSP-based)
1. **Registry Contract:** A simple contract (possibly an LSP8 collection where each NFT represents an "Audit Ticket" or an LSP0 Vault).
2. **Submission Flow:**
   - User calls `register(address targetContract)` with a small fee (or free for alpha).
   - Event `AuditRequested(address indexed targetContract, address indexed requester)` is emitted.
3. **Execution Flow (Offchain to Onchain):**
   - Agents detect the event.
   - Agents run the audit (security scanner + LLM analysis).
   - Agents post a link to the report (IPFS CID) via `setData` on the registry or by minting an LSP8 "Audit Report" NFT to the requester.
4. **Talent/Base Mapping:**
   - **Functional Tool:** It’s a security scanner/registry.
   - **Onchain Activity:** Every submission and every attestation is a tx.
   - **Impact:** Builders get free/cheap security feedback.

### Why this works
- It leverages the existing "Experiment #1" logic.
- It moves the "Order Flow" from Rocket.Chat/Discord to **Base Mainnet**.
- It provides a "functional Base mainnet project" with "documented impact" as required by Base/Talent grant criteria.

## Next Steps (Round 3)
1. Draft the Solidity interface for the Audit Registry.
2. Estimate deployment gas on Base.
3. Verify if an LSP8-based "Audit Report" collection is more efficient than a simple registry.
