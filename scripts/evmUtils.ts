import dotenv from 'dotenv';
dotenv.config();
import { ethers } from "ethers";
import * as fs from "fs";
const path = require('path');
const os = require('os');

export const ACCOUNT_NAME_EVM = "easyleapadmin";
export function getEVMAccount(accountName: string) {
  const path_file = path.join(os.homedir(), `.evm-store/accounts_${process.env.NETWORK}.json`);
  if (!fs.existsSync(path_file)) {
    throw new Error(`Accounts file not found: ${path_file}`);
  }
  const accounts = JSON.parse(fs.readFileSync(path_file, "utf8"));
  if (!accounts[accountName]) {
    throw new Error(`Account not found: ${accountName}`);
  }
  return accounts[accountName];
}

export async function getEVMArtifact(contractName: string) {
  const artifact = JSON.parse(
    fs.readFileSync(`evm/out/${contractName}.sol/${contractName}.json`, "utf8")
  );
  return artifact;
}

export function getEVMProvider() {
  return new ethers.JsonRpcProvider(process.env.ETH_RPC);
}

export async function deployEVMContract(contractName: string, args: any[]) {
  const artifact = await getEVMArtifact(contractName);

  const rpcUrl = process.env.ETH_RPC;
  if (!rpcUrl) throw new Error("ETH_RPC is not set");
  const provider = new ethers.JsonRpcProvider(rpcUrl);

  const wallet = new ethers.Wallet(getEVMAccount(ACCOUNT_NAME_EVM).private_key, provider);

  // Create a contract factory
  const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, wallet);

  // Deploy the contract
  const contract = await factory.deploy(...args);
  await contract.waitForDeployment();

  console.log("Contract deployed at:", await contract.getAddress());
  return contract;
}
