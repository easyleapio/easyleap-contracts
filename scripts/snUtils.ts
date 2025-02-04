import dotenv from 'dotenv';
dotenv.config();
import assert from 'assert'
import {Account, RawArgs, RpcProvider, TransactionExecutionStatus, extractContractHashes, hash, json, provider} from 'starknet'
import { readFileSync, existsSync, writeFileSync } from 'fs'
import { IConfig, Network, Store, getDefaultStoreConfig } from '@strkfarm/sdk';

export const ACCOUNT_NAME_SN = 'strkfarmadmin';
export function getRpcProvider(rpcUrl: string | undefined = process.env.SN_RPC) {
    assert(rpcUrl, 'invalid SN_RPC');
    console.log(`RPC: ${rpcUrl}`);
    return new RpcProvider({nodeUrl: rpcUrl})
}

function getContracts() {
    const PATH = './contracts.json'
    if (existsSync(PATH)) {
        return JSON.parse(readFileSync(PATH, {encoding: 'utf-8'}))
    }
    return {}
}

function saveContracts(contracts: any) {
    const PATH = './contracts.json'
    writeFileSync(PATH, JSON.stringify(contracts));
}

export function getAccount(accountKey: string) {
    const config: IConfig = {
        provider: <any>new RpcProvider({nodeUrl: process.env.SN_RPC}),
        network: process.env.NETWORK == 'mainnet' ? Network.mainnet : Network.sepolia,
        stage: 'production'
    }
    const storeConfig = getDefaultStoreConfig(Network.mainnet);
    storeConfig.ACCOUNTS_FILE_NAME = 'accounts-orig.json';
    const store = new Store(config, {
        ...storeConfig,
        PASSWORD: process.env.ACCOUNT_SECURE_PASSWORD || '',
    });
    
    return store.getAccount(accountKey);
}

export async function myDeclare(contract_name: string, package_name: string = 'easyleap') {
    const provider = getRpcProvider();
    const acc = getAccount(ACCOUNT_NAME_SN);
    const compiledSierra = json.parse(
        readFileSync(`./starknet/target/release/${package_name}_${contract_name}.contract_class.json`).toString("ascii")
    )
    const compiledCasm = json.parse(
    readFileSync(`./starknet/target/release/${package_name}_${contract_name}.compiled_contract_class.json`).toString("ascii")
    )
    
    const contracts = getContracts();
    const payload = {
        contract: compiledSierra,
        casm: compiledCasm
    };
    
    const fee = await acc.estimateDeclareFee({
        contract: compiledSierra,
        casm: compiledCasm, 
    })
    console.log('declare fee', Number(fee.suggestedMaxFee) / 10 ** 18, 'ETH')
    const result = extractContractHashes(payload);
    console.log("classhash:", result.classHash);
    
    const tx = await acc.declareIfNot(payload)
    console.log(`Declaring: ${contract_name}, tx:`, tx.transaction_hash);
    await provider.waitForTransaction(tx.transaction_hash, {
        successStates: [TransactionExecutionStatus.SUCCEEDED]
    })
    
    if (!contracts.class_hashes) {
        contracts['class_hashes'] = {};
    }

    // Todo attach cairo and scarb version. and commit ID
    contracts.class_hashes[contract_name] = tx.class_hash;
    saveContracts(contracts);
    console.log(`Contract declared: ${contract_name}`)
    console.log(`Class hash: ${tx.class_hash}`)
    return tx;
}

export async function deployContract(contract_name: string, classHash: string, constructorData: RawArgs) {
    const provider = getRpcProvider();
    const acc = getAccount(ACCOUNT_NAME_SN);

    const fee = await acc.estimateDeployFee({
        classHash,
        constructorCalldata: constructorData,
    })
    console.log("Deploy fee", contract_name, Number(fee.suggestedMaxFee) / 10 ** 18, 'ETH')

    return deploy(classHash, constructorData, contract_name);
}

export async function deploy(
    classHash: string,
    constructorData: RawArgs,
    contract_name: string
) {
    const provider = getRpcProvider();
    const acc = getAccount(ACCOUNT_NAME_SN);
    const tx = await acc.deployContract({
        classHash,
        constructorCalldata: constructorData,
    })
    console.log('Deploy tx: ', tx.transaction_hash);
    await provider.waitForTransaction(tx.transaction_hash, {
        successStates: [TransactionExecutionStatus.SUCCEEDED]
    })
    const contracts = getContracts();
    if (!contracts.contracts) {
        contracts['contracts'] = {};
    }
    contracts.contracts[contract_name] = tx.contract_address;
    saveContracts(contracts);
    console.log(`Contract deployed: ${contract_name}`)
    console.log(`Address: ${tx.contract_address}`)
    return tx;
}