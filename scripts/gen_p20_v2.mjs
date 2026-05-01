import { ethers } from 'ethers';

const LeoAddr = '0x1e0267b7e88b97d5037e410bdc61d105e04ca02a';
const AmpyAddr = '0xdb4dad79d8508656c6176408b25bead5d383e450';

const prefix = '0x4b80742de2bf82acb3630000';
const keyLeo = prefix + LeoAddr.slice(2).toLowerCase();
const keyAmpy = prefix + AmpyAddr.slice(2).toLowerCase();

const valLeo = '0x';
const valAmpy = '0x0000000000000000000000000000000000000000000000000000000000622600';

const iface = new ethers.Interface(['function setDataBatch(bytes32[] keys, bytes[] values)']);
const calldata = iface.encodeFunctionData('setDataBatch', [[keyLeo, keyAmpy], [valLeo, valAmpy]]);

console.log('P20 v2 Calldata (setDataBatch):');
console.log(calldata);
