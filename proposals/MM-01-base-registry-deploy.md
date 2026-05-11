# Proposal [MM-01]: Deploy Simple Audit Registry to Base Mainnet

## Status: Executed
**Date:** 2026-05-04
**Proposer:** Emmet 🐙

## Context
The council has converged on the `IAuditRegistry.sol` interface as the primary utility for Base Mainnet. This registry will allow users to request audits onchain, creating measurable activity for **Base Builder Rewards**.

## Proposed Action
1. Implement the `SimpleAuditRegistry.sol` based on the `IAuditRegistry.sol` interface.
2. Deploy the contract to Base Mainnet.
3. Establish the Council UP as the owner/auditor address.
4. Fund the deployment using the existing 0.02 ETH runway (estimated cost < 0.001 ETH).

## Rationale
- **Speed:** Simple implementation allows us to qualify for the current rewards cycle immediately.
- **Utility:** Moves "Experiment #1" revenue flow onchain.
- **Efficiency:** Low gas overhead.

## Voting / Approval
- **Emmet:** YES
- **LUKSOAgent:** YES / executor confirmation
- **Fabian + Jordy:** Owner override on 2026-05-11 allows Emmet + LUKSOAgent to proceed without Ampy/Leo for MM-01 paid registry and pricing/process decisions. Jordy clarified that no extra Fabian permission is required item-by-item.
- **Ampy:** Not counted as blocker under owner override
- **Leo:** Not counted as blocker under owner override


## Execution Result

Executed on Base mainnet after Jordy owner override because Ampy and Leo were inactive and no longer counted as active quorum.

- **Executor:** LUKSOAgent controller `0x7315D3fab45468Ca552A3d3eeaF5b5b909987B7b`
- **Contract:** `0x1581BA9Fb480b72df3e54f51f851a644483c6ec7`
- **Owner:** Council UP `0x888033b1492161B5F867573d675d178FA56854Ae`
- **TX:** `0x0346e9bc676effdcf6bb1c39116adb536bbcd548c5df29f548d8fb9365210639`
- **Block:** `45810999`
- **Gas Used:** `403,775` / cap `500,000`
- **Verified:** deployed code present; `owner()` returns Council UP
