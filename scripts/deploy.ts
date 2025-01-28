import { ACCOUNT_NAME_SN, deployContract, getAccount, getRpcProvider } from "./snUtils";
import { myDeclare } from "./snUtils";
import { ACCOUNT_NAME_EVM, deployEVMContract, getEVMAccount, getEVMArtifact, getEVMProvider } from "./evmUtils"
import { num, Contract, TransactionExecutionStatus, hash, Call, constants, TransactionType } from 'starknet';
import { ethers } from "ethers";

function getEVMFee() {
  if (process.env.NETWORK === "mainnet") {
    return (0.001 * 10**18).toString(); // 0.001 ETH
  }
  return (0.00001 * 10**18).toString(); // 0.00001 ETH
}

function getFeeReceiver() {
  if (process.env.NETWORK === "mainnet") {
    throw new Error("Not implemented");
  }
  return getEVMAccount(ACCOUNT_NAME_EVM).address;
}

function getL1Manager() {
  if (process.env.NETWORK === "mainnet") {
    throw new Error("Not implemented");
  }
  return '0x54636479410d630F72da478Ed85371dDcaE7666a';
}

function getStarknetCore() {
  if (process.env.NETWORK === "mainnet") {
    return '0xc662c410C0ECf747543f5bA90660f6ABeBD9C8c4';
  }
  return '0xE2Bb56ee936fd6433DC0F6e7e3b8365C906AA057'
}

async function deployEVM() {
  // deploy to EVM
  await deployEVMContract("L1Manager", [
    getStarknetCore(), // Starknet core
    getEVMAccount(ACCOUNT_NAME_EVM).address, // owner
    {
      fee_eth: getEVMFee(),
      fee_receiver: getFeeReceiver(),
      l2_easyleap_receiver: num.getDecimalString(getConfig().starknet.receiver)
    }
  ]);
}

async function deploySN() {
  // deploy to StarkNet
  // const { class_hash } = await myDeclare("Executor");
  // const executor = await deployContract("Executor", class_hash, {
  //   _admin: getAccount(ACCOUNT_NAME_SN).address,
  //   settings: {
  //     fee_bps: 5,
  //     fee_receiver: getAccount(ACCOUNT_NAME_SN).address,
  //     l1Receiver: 0
  //   }
  // });

  // // deploy receiver
  // const { class_hash: receiver_class_hash } = await myDeclare("Receiver");
  // const receiver = await deployContract("Receiver", receiver_class_hash, {
  //   _admin: getAccount(ACCOUNT_NAME_SN).address,
  //   settings: {
  //     l1_easyleap_manager: num.getDecimalString(getL1Manager()),
  //     executor: executor.address
  //   }
  // });

  // update settings of executor
  const executor = {address: '0x1bd99991c7923b3853c19c55f7562bbac369be8d72d03e49bba9f9d4e5420c2'};
  const receiver = {address: '0x7ff7ab2241b087f35ca116cc1a3ce218e36234a1a0a1937250c73eeca20b389'};
  let executorCls = await getRpcProvider().getClassAt(executor.address);
  const executorContract = new Contract(executorCls.abi, executor.address, getRpcProvider());
  const call = executorContract.populate('set_settings', {
    settings: {
      fee_bps: 5,
      fee_receiver: getAccount(ACCOUNT_NAME_SN).address,
      l1Receiver: {
        contract_address: receiver.address
      }
    }
  });
  const tx = await getAccount(ACCOUNT_NAME_SN).execute([call]);
  console.log(`Executor settings updated: ${tx.transaction_hash}`);
  await getRpcProvider().waitForTransaction(tx.transaction_hash, {
    successStates: [TransactionExecutionStatus.SUCCEEDED]
  });
  console.log(`Executor settings updated: ${tx.transaction_hash}`);
}

async function setRecieverSettings() {
  let receiverCls = await getRpcProvider().getClassAt(getConfig().starknet.receiver);
  const executorContract = new Contract(receiverCls.abi, getConfig().starknet.receiver, getRpcProvider());
  const call = executorContract.populate('set_settings', {
    settings: {
      l1_easyleap_manager: num.getDecimalString(getL1Manager()),
      executor: getConfig().starknet.executor
    }
  });
  const tx = await getAccount(ACCOUNT_NAME_SN).execute([call]);
  console.log(`Receiver settings updated: ${tx.transaction_hash}`);
  await getRpcProvider().waitForTransaction(tx.transaction_hash, {
    successStates: [TransactionExecutionStatus.SUCCEEDED]
  });
  console.log(`Receiver settings updated: ${tx.transaction_hash}`);
}


async function upgradeSN() {
  // ! set contract address
  const address = "0x7ff7ab2241b087f35ca116cc1a3ce218e36234a1a0a1937250c73eeca20b389";
  const acc = getAccount(ACCOUNT_NAME_SN);
  // const { class_hash } = await myDeclare("Receiver");
  const class_hash = '0x050105a5b191672cc45c3e738fe3f4b7ca9e9f8cefc5e925bf389bde976fe800'
  const provider = getRpcProvider();
  const cls = await provider.getClassAt(address);
  const contract = new Contract(cls.abi, address, provider);
  const call = contract.populate('upgrade', [class_hash]);
  const tx = await acc.execute([call]);
  console.log(tx)
  await provider.waitForTransaction(tx.transaction_hash);
  console.log('Done')
}

declare global {
  interface BigInt {
      toJSON(): string;
  }
}
BigInt.prototype.toJSON = function () {
  return this.toString();
};

export const SEPOLIA_SN_ETH = '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7'

async function mockPush() {
  const SEPOLIA_VESU_ETH = '0x07809bb63f557736e49ff0ae4a64bd8aa6ea60e3f77f26c520cb92c24e3700d3'
  const SEPOLIA_vETH = '0x01ceb6db3ac889e2c0d2881eff602117c340316e55436f37699d91c193ee8aa0'
  
  const amountNumber = 999500000000000 / 10 ** 18;// 0.0001;
  const amount = (amountNumber * 10**18).toString();

  const executorCls = await getRpcProvider().getClassAt(getConfig().starknet.executor);
  const executorContract = new Contract(executorCls.abi, getConfig().starknet.executor, getRpcProvider());
  const feeAmount: any = await executorContract.call('get_fee', [amount]);
  const postAmountFee = BigInt(amount) - BigInt(feeAmount);
  console.log(`Fee: ${feeAmount}, Post Fee: ${postAmountFee}`);
  const snAcc = getAccount(ACCOUNT_NAME_SN);
  const wallet = new ethers.Wallet(getEVMAccount(ACCOUNT_NAME_EVM).private_key, getEVMProvider());

  const calls = [
    4, // 4 calls
    // // // call 1: approve
    num.getDecimalString(SEPOLIA_SN_ETH),
    num.getDecimalString(hash.getSelectorFromName!("transfer")),
    3, // approve callata len
    num.getDecimalString(snAcc.address), // spender
    postAmountFee, // amount u256 low
    0, // amount u256 high

    // call 2 mint vesu eth
    num.getDecimalString(SEPOLIA_VESU_ETH),
    num.getDecimalString(hash.getSelectorFromName!("mint")),
    3, // mint calldata len
    num.getDecimalString(getConfig().starknet.executor), // receiver
    postAmountFee, // amount
    0, // padding

    // call3: approve vesu eth
    num.getDecimalString(SEPOLIA_VESU_ETH),
    num.getDecimalString(hash.getSelectorFromName!("approve")),
    3, // approve callata len
    num.getDecimalString(SEPOLIA_vETH), // spender
    postAmountFee, // amount u256 low
    0, // amount u256 high

    // call 4: deposit
    num.getDecimalString(SEPOLIA_vETH),
    num.getDecimalString(hash.getSelectorFromName!("deposit")),
    3, // deposit calldata len
    postAmountFee, // amount
    0, // padding
    num.getDecimalString(snAcc.address) // my receiver
  ]
  let calldata = [
    0, // some id
    num.getDecimalString(SEPOLIA_SN_ETH), // token
    amount, // amount to receive on L2
    num.getDecimalString(snAcc.address), // my receiver
    calls.length,
    ...calls
  ];

  const args = [{
    l1_token_address: '0x0000000000000000000000000000000000000000',
    l2_token_address: num.getDecimalString(SEPOLIA_SN_ETH),
    bridge_address: '0x8453FC6Cd1bCfE8D4dFC069C400B433054d47bDc', // l1 eth bridge address sepolia
  },
  amount,
  calldata,
  {
    value: ethers.parseEther((amountNumber + 0.001).toString()).toString()
  }]
  // console.log(JSON.stringify(args))
  const l1ManagerAbi = (await getEVMArtifact("L1Manager")).abi;
  const l1ManagerContract = new ethers.Contract(getConfig().evm.l1Manager, l1ManagerAbi, wallet);
  l1ManagerContract.connect(getEVMAccount(ACCOUNT_NAME_EVM));
  const tx = await l1ManagerContract.push(...args);

  // const tx = await l1ManagerContract.push(
  //   {
  //     l1_token_address: '0x0000000000000000000000000000000000000000',
  //     l2_token_address: 2087021424722619777119509474943472645767659996348769578120564519014510906823, // num.getDecimalString(SEPOLIA_SN_ETH),
  //     bridge_address: "0x8453FC6Cd1bCfE8D4dFC069C400B433054d47bDc", // l1 eth bridge address sepolia
  //   },
  //   999500000000000,
  //   ["0","2087021424722619777119509474943472645767659996348769578120564519014510906823","999500000000000","2397760708064053544410361092001864607572455157403473364431858166079429549790","25","4","2087021424722619777119509474943472645767659996348769578120564519014510906823","232670485425082704932579856502088130646006032362877466777181098476241604910","3","782498535370649748679209311272509582861981220566814097983441669476037500001","999500000000000","0","3393421048438376788762228095972693641766161957022472479975584018332231598291","1329909728320632088402217562277154056711815095720684343816173432540100887380","3","787307038887858106250167910035360683689804263625924137819368636516375208130","999500000000000","0","3393421048438376788762228095972693641766161957022472479975584018332231598291","949021990203918389843157787496164629863144228991510976554585288817234167820","3","817545372181659267374335647088928968396058244944410009350411114791606061728","999500000000000","0","817545372181659267374335647088928968396058244944410009350411114791606061728","352040181584456735608515580760888541466059565068553383579463728554843487745","3","999500000000000","0","2397760708064053544410361092001864607572455157403473364431858166079429549790"],
  //   {
  //     value: ethers.parseEther((0.0009995 + 0.001).toString()).toString()
  //   }
  // );

  console.log("Transaction sent!");
  console.log(`Transaction hash: ${tx.hash}`);

  // Wait for the transaction to be mined
  const receipt = await tx.wait();
  console.log("Transaction confirmed!");
  console.log(`Block number: ${receipt.blockNumber}`);
}

function getConfig() {
  return {
    evm: {
      l1Manager: '0x54636479410d630F72da478Ed85371dDcaE7666a'
    },
    starknet: {
      executor: '0x1bd99991c7923b3853c19c55f7562bbac369be8d72d03e49bba9f9d4e5420c2',
      receiver: '0x7ff7ab2241b087f35ca116cc1a3ce218e36234a1a0a1937250c73eeca20b389'
    }
  }
}

if (require.main === module) {
  // deployEVM()
  // deploySN()
  upgradeSN().then(() => {
    // mockPush()
    // setRecieverSettings();
  })
  // mockPush()

}

/**
 * ***
 * Sepolia
 * ***
 * 
 * EVM: 
 * L1 Manager: 0x54636479410d630F72da478Ed85371dDcaE7666a
 * 
 * Starknet:
 * Executor: 0x1bd99991c7923b3853c19c55f7562bbac369be8d72d03e49bba9f9d4e5420c2
 * Receiver: 0x7ff7ab2241b087f35ca116cc1a3ce218e36234a1a0a1937250c73eeca20b389
*/


// [{"l1_token_address":"0x0000000000000000000000000000000000000000","l2_token_address":"2087021424722619777119509474943472645767659996348769578120564519014510906823","bridge_address":"0x8453FC6Cd1bCfE8D4dFC069C400B433054d47bDc"},"999500000000000",[1,"2087021424722619777119509474943472645767659996348769578120564519014510906823","999500000000000","2397760708064053544410361092001864607572455157403473364431858166079429549790",25,4,"2087021424722619777119509474943472645767659996348769578120564519014510906823","232670485425082704932579856502088130646006032362877466777181098476241604910",3,"2397760708064053544410361092001864607572455157403473364431858166079429549790","999000250000000",0,"3393421048438376788762228095972693641766161957022472479975584018332231598291","1329909728320632088402217562277154056711815095720684343816173432540100887380",3,"787307038887858106250167910035360683689804263625924137819368636516375208130","999000250000000",0,"3393421048438376788762228095972693641766161957022472479975584018332231598291","949021990203918389843157787496164629863144228991510976554585288817234167820",3,"817545372181659267374335647088928968396058244944410009350411114791606061728","999000250000000",0,"817545372181659267374335647088928968396058244944410009350411114791606061728","352040181584456735608515580760888541466059565068553383579463728554843487745",3,"999000250000000",0,"2397760708064053544410361092001864607572455157403473364431858166079429549790"],{"value":"1999500000000000"}]