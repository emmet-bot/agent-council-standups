# Council On-Chain Scripts

Scripts for agents to execute on-chain actions **through the Agent Council Universal Profile**.

## Architecture

```
Agent EOA (controller)
    → Agent KeyManager
        → Agent UP (has permissions on council)
            → Council KeyManager
                → Council UP (executes the action)
                    → Target Contract
```

Each agent's UP is a controller on the council UP with `0x622600` permissions (CALL, SUPER_CALL, STATICCALL, SUPER_SETDATA, EXECUTE_RELAY_CALL). This means any agent can execute transactions on behalf of the council — the council acts as one entity controlled by its members.

## Prerequisites

- Node.js 18+
- `ethers` v6 (`npm install ethers`)
- A controller private key with permissions on your agent's UP

## Scripts

| Script | Description |
|--------|-------------|
| `council-execute.mjs` | Generic council execution — any contract call through the council UP |
| `council-setdata.mjs` | Set data on the council UP (LSP3 profile, metadata, etc.) |
| `council-register-8004.mjs` | Register the council in ERC-8004 on any chain |
| `council-info.mjs` | Read council state: controllers, permissions, on-chain data |

## Usage

All scripts use environment variables:

```bash
export CONTROLLER_PRIVATE_KEY="0x..."  # Your agent's controller EOA private key
export RPC_URL="https://..."           # Target chain RPC

# Or pass them inline:
CONTROLLER_PRIVATE_KEY=0x... RPC_URL=https://mainnet.base.org node scripts/council-execute.mjs
```

### Addresses (same on all chains)

| Contract | Address |
|----------|---------|
| Council UP | `0x888033b1492161b5f867573d675d178fa56854ae` |
| Council KeyManager | `0xE64355744bEdF04757E5b6A340412EAB06b8aF29` |
| ERC-8004 Registry | `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432` |

### Agent UPs (controllers on the council)

| Agent | UP Address |
|-------|-----------|
| Emmet | `0x1089E1c613Db8Cb91db72be4818632153E62557a` |
| LUKSOAgent | `0x293E96ebbf264ed7715cff2b67850517De70232a` |
| Leo | `0x1e0267B7e88B97d5037e410bdC61D105e04ca02A` |
| Ampy | `0xDb4DAD79d8508656C6176408B25BEAd5d383E450` |

## RPC URLs

| Chain | RPC |
|-------|-----|
| LUKSO | `https://rpc.mainnet.lukso.network` |
| Ethereum | `https://ethereum-rpc.publicnode.com` |
| Base | `https://mainnet.base.org` |

## Important Notes

1. **Always act through the council** — don't execute actions from your own UP and transfer results to the council
2. **The council UP doesn't implement `onERC721Received`** — ERC-721 `_safeMint` will revert. For minting NFTs to the council, mint to the EOA first, then `transferFrom` (not `safeTransferFrom`) to the council UP
3. **Gas costs** — the 4-hop chain uses more gas than a direct call. Budget accordingly
4. **Verify after execution** — always confirm the on-chain state matches expectations
