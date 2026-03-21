#!/usr/bin/env node

/**
 * council-info.mjs
 * 
 * Read council state: controllers, permissions, on-chain data.
 * 
 * Usage:
 *   RPC_URL=https://... node council-info.mjs
 *   RPC_URL=https://... node council-info.mjs --all-chains
 */

import { ethers } from 'ethers';

const COUNCIL_UP = '0x888033b1492161b5f867573d675d178fa56854ae';
const COUNCIL_KM = '0xE64355744bEdF04757E5b6A340412EAB06b8aF29';
const ERC8004_REGISTRY = '0x8004A169FB4a3325136EB29fA0ceB6D2e539a432';

const KNOWN_AGENTS = {
  '0x1089e1c613db8cb91db72be4818632153e62557a': 'Emmet',
  '0x293e96ebbf264ed7715cff2b67850517de70232a': 'LUKSOAgent',
  '0x1e0267b7e88b97d5037e410bdc61d105e04ca02a': 'Leo',
  '0xdb4dad79d8508656c6176408b25bead5d383e450': 'Ampy',
  '0x7870c5b8bc9572a8001c3f96f7ff59961b23500d': 'Deployer/Fabian?',
  '0x9155b15e2165265d3cc5e1419a58b6115131c631': 'Unknown',
  '0xcdec110f9c255357e37f46cd2687be1f7e9b02f7': 'Fabian UP',
};

const CHAINS = [
  { name: 'LUKSO', rpc: 'https://rpc.mainnet.lukso.network' },
  { name: 'Ethereum', rpc: 'https://ethereum-rpc.publicnode.com' },
  { name: 'Base', rpc: 'https://mainnet.base.org' },
];

const PERMISSION_BITS = {
  0x1: 'CHANGEOWNER',
  0x2: 'ADDCONTROLLER',
  0x4: 'EDITPERMISSIONS',
  0x8: 'ADDEXTENSIONS',
  0x10: 'CHANGEEXTENSIONS',
  0x20: 'ADDUNIVERSALRECEIVERDELEGATE',
  0x40: 'CHANGEUNIVERSALRECEIVERDELEGATE',
  0x80: 'REENTRANCY',
  0x100: 'SUPER_TRANSFERVALUE',
  0x200: 'TRANSFERVALUE',
  0x400: 'SUPER_CALL',
  0x800: 'CALL',
  0x1000: 'SUPER_STATICCALL',
  0x2000: 'STATICCALL',
  0x4000: 'SUPER_DELEGATECALL',
  0x8000: 'DELEGATECALL',
  0x10000: 'DEPLOY',
  0x20000: 'SUPER_SETDATA',
  0x40000: 'SETDATA',
  0x80000: 'ENCRYPT',
  0x100000: 'DECRYPT',
  0x200000: 'SIGN',
  0x400000: 'EXECUTE_RELAY_CALL',
};

function decodePermissions(hexPerms) {
  const value = BigInt(hexPerms);
  const names = [];
  for (const [bit, name] of Object.entries(PERMISSION_BITS)) {
    if (value & BigInt(bit)) names.push(name);
  }
  return names;
}

async function inspectChain(chainName, rpcUrl) {
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const abi = ['function getData(bytes32) view returns (bytes)'];
  const council = new ethers.Contract(COUNCIL_UP, abi, provider);

  console.log(`\n=== ${chainName} ===`);
  console.log(`Council UP: ${COUNCIL_UP}`);
  console.log(`Council KM: ${COUNCIL_KM}`);

  // Check if contract exists
  const code = await provider.getCode(COUNCIL_UP);
  if (code === '0x') {
    console.log('  ⚠️  Council UP not deployed on this chain');
    return;
  }

  // Get controllers
  const arrKey = '0xdf30dba06db6a30e65354d9a64c609861f089545ca58c6b4dbe31a5f338cb0e3';
  const arrLen = await council.getData(arrKey);
  const numControllers = arrLen && arrLen !== '0x' ? parseInt(arrLen, 16) : 0;
  
  console.log(`Controllers: ${numControllers}`);
  
  for (let i = 0; i < numControllers; i++) {
    const hex = i.toString(16).padStart(32, '0');
    const key = '0xdf30dba06db6a30e65354d9a64c60986' + hex;
    let addrData;
    try {
      addrData = await council.getData(key);
    } catch (e) {
      continue;
    }
    if (!addrData || addrData === '0x') continue;
    
    // getData returns raw bytes for addresses (20 bytes = 42 hex chars with 0x prefix)
    const addr = addrData.length === 42 
      ? addrData.toLowerCase() 
      : ('0x' + addrData.slice(-40)).toLowerCase();
    const name = KNOWN_AGENTS[addr] || 'Unknown';
    
    // Get permissions
    let perms, permNames;
    try {
      const permKey = '0x4b80742de2bf82acb3630000' + addr.slice(2);
      perms = await council.getData(permKey);
      permNames = perms && perms !== '0x' ? decodePermissions(perms) : ['NONE'];
    } catch (e) {
      perms = '?';
      permNames = ['ERROR'];
    }
    
    console.log(`  [${i}] ${name} (${addr})`);
    console.log(`      Permissions: ${perms} → ${permNames.join(', ')}`);
  }

  // Check LSP3 Profile
  try {
    const lsp3Key = '0x5ef83ad9559033e6e941db7d7c495acdce616347d28e90c7ce47cbfcfcad3bc5';
    const lsp3 = await council.getData(lsp3Key);
    console.log(`LSP3Profile: ${lsp3 && lsp3 !== '0x' ? lsp3.substring(0, 40) + '...' : 'NOT SET'}`);
  } catch (e) {
    console.log('LSP3Profile: error reading');
  }

  // Check ERC-8004
  try {
    const regABI = ['function balanceOf(address) view returns (uint256)'];
    const reg = new ethers.Contract(ERC8004_REGISTRY, regABI, provider);
    const balance = await reg.balanceOf(COUNCIL_UP);
    console.log(`ERC-8004 tokens: ${balance.toString()}`);
  } catch (e) {
    console.log('ERC-8004: registry not available');
  }
}

async function main() {
  const allChains = process.argv.includes('--all-chains');
  
  if (allChains) {
    for (const chain of CHAINS) {
      await inspectChain(chain.name, chain.rpc);
    }
  } else {
    const rpcUrl = process.env.RPC_URL;
    if (!rpcUrl) {
      console.error('Usage: RPC_URL=https://... node council-info.mjs');
      console.error('   or: node council-info.mjs --all-chains');
      process.exit(1);
    }
    await inspectChain('Custom', rpcUrl);
  }
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
