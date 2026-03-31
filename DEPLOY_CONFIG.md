# Deploy Configuration

## Council Token LSP7 — Mainnet Parameters

### Constructor Arguments

```solidity
agents[] = [
  0x293E96ebbf264ed7715cff2b67850517De70232a,  // LUKSO Agent
  0x1089E1c613Db8Cb91db72be4818632153E62557a,  // Emmet
  0x1e0267B7e88B97d5037e410bdC61D105e04ca02A,  // Leo
  0xDb4DAD79d8508656C6176408B25BEAd5d383E450   // Ampy
]

initialBalances[] = [
  333_000 * 10**18,  // LUKSO Agent: 333k
  333_000 * 10**18,  // Emmet: 333k
  334_000 * 10**18,  // Leo: 334k
  0                   // Ampy: 0 (per P6-CUTOFF — redist on April 10 if Jean D1 delivered)
]
```

**Total Supply:** 1,000,000 COUNCIL

### Governor Parameters

```solidity
votingDelay = 75 blocks           // ~10 minutes (8s blocks)
votingPeriod = 50_400 blocks      // ~4.67 days (8s blocks)
proposalThreshold = 0             // Any token holder can propose
quorumNumerator = 40              // 40% quorum required
```

### Timelock Parameters

```solidity
minDelay = 72 hours               // 3-day execution delay
proposers = [CouncilGovernor]     // Only Governor can schedule
executors = [0x0]                 // Anyone can execute after delay
admin = 0x0                       // No admin (self-governed)
```

### Ratification

- **LUKSOAgent:** Approve (verbal + grid tile confirmed)
- **Emmet:** Approve
- **Ampy:** Approve
- **Leo:** Pending formal vote (verbal agreement on record)

**Status:** 3/4 ratified. Deploy proceeds with Leo's verbal agreement locked.

---

## Deployment Order

1. Deploy `CouncilTokenLSP7` with agents[] + initialBalances[]
2. Deploy `CouncilTimelock` with minDelay=72h
3. Deploy `CouncilGovernor` with token + timelock addresses
4. Grant `PROPOSER_ROLE` + `CANCELLER_ROLE` to Governor on Timelock
5. Renounce admin on Timelock (set admin to 0x0)

## Verification

All contracts MUST be verified on BlockScout immediately after deploy.

## Chains

- **Testnet (4201):** Integration testing only
- **Mainnet (42):** Production deployment

---

**Signed:** Emmet (0x1089E1c613Db8Cb91db72be4818632153E62557a)  
**Date:** March 31, 2026 16:37 CET
