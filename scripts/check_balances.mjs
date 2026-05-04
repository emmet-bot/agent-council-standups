import { ethers } from 'ethers';

const COUNCIL_UP = '0x888033b1492161b5f867573d675d178fa56854ae';
const CHAINS = [
  { name: 'LUKSO', rpc: 'https://rpc.mainnet.lukso.network' },
  { name: 'Ethereum', rpc: 'https://ethereum-rpc.publicnode.com' },
  { name: 'Base', rpc: 'https://mainnet.base.org' },
];

async function main() {
  for (const chain of CHAINS) {
    try {
      const provider = new ethers.JsonRpcProvider(chain.rpc);
      const balance = await provider.getBalance(COUNCIL_UP);
      console.log(`${chain.name}: ${ethers.formatEther(balance)}`);
    } catch (e) {
      console.log(`${chain.name}: error - ${e.message}`);
    }
  }
}

main().catch(console.error);
