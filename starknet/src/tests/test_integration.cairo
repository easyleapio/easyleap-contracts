#[cfg(test)]
pub mod test_integration {
    use starknet::{ContractAddress, get_contract_address, contract_address::contract_address_const};
    use snforge_std::{
        declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address, L1HandlerTrait
    };
    use snforge_std::{DeclareResultTrait};
    use easyleap::interfaces::IExecutor::{
        Settings as ExecutorSettings, IExecutorDispatcher, IExecutorDispatcherTrait
    };
    use easyleap::interfaces::IReceiver::{
        IReceiverDispatcher, Settings as ReceiverSettings, IReceiverDispatcherTrait,
        Payload, Request, Status, RequestWithCalldata, CommonRequest
    };
    use openzeppelin::utils::serde::SerializedAppend;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use easyleap::mocks::test_dapp::{
        ITestDappDispatcher
    };

    fn deploy_executor(fee_bps: u128) -> IExecutorDispatcher {
        let mut calldata: Array<felt252> = array![
            get_contract_address().into()
        ];
        let settings = ExecutorSettings {
            fee_bps,
            fee_receiver: get_contract_address(),
            l1Receiver: IReceiverDispatcher{ contract_address: contract_address_const::<0>() }
        };

        settings.serialize(ref calldata); // settings

        let cls = declare("Executor").unwrap().contract_class();
        let (addr, _) = cls.deploy(@calldata).expect('Executor deploy failed');

        IExecutorDispatcher{ contract_address: addr }
    }

    fn l1_easyleap_manager() -> felt252 {
        100
    }

    fn deploy_receiver(executor: ContractAddress) -> IReceiverDispatcher {
        let cls = declare("Receiver").unwrap().contract_class();

        let mut calldata: Array<felt252> = array![
            get_contract_address().into()
        ];
        let settings = ReceiverSettings {
            l1_easyleap_manager: l1_easyleap_manager(),
            executor: executor
        };
        settings.serialize(ref calldata); // settings

        let (addr, _) = cls.deploy(@calldata).expect('Receiver deploy failed');

        IReceiverDispatcher{ contract_address: addr }
    }

    fn deploy_mocks() -> (IERC20Dispatcher, ITestDappDispatcher) {
        let cls = declare("ERC20").unwrap().contract_class();
        let mut calldata: Array<felt252> = array![];
        let name: ByteArray = "Test Token";
        let symbol: ByteArray = "TT";
        calldata.append_serde(name);
        calldata.append_serde(symbol);
        calldata.append(1000 * 1000000000000000000); // max supply, 18 decimals
        calldata.append(0);
        calldata.append(get_contract_address().into()); // receiver
        let (addr, _) = cls.deploy(@calldata).expect('ERC20 deploy failed');

        // deploy test dapp
        let cls = declare("TestDApp").unwrap().contract_class();
        let mut calldata: Array<felt252> = array![addr.into()];
        let (addr2, _) = cls.deploy(@calldata).expect('TestDapp deploy failed');

        (IERC20Dispatcher{ contract_address: addr }, ITestDappDispatcher{ contract_address: addr2 })
    }

    fn set_executor_receiver(executor: IExecutorDispatcher, receiver: IReceiverDispatcher) {
        start_cheat_caller_address(executor.contract_address, get_contract_address());
        let mut settings = executor.get_settings();
        settings.l1Receiver = receiver;
        executor.set_settings(settings);
        stop_cheat_caller_address(executor.contract_address);
    }

    fn full_setup() -> (IExecutorDispatcher, IReceiverDispatcher, IERC20Dispatcher, ITestDappDispatcher) {
        let executor = deploy_executor(0);
        let receiver = deploy_receiver(executor.contract_address);
        println!("Deployed executor and receiver");
        set_executor_receiver(executor, receiver);
        println!("Set executor receiver");
        let (mockToken, mockDapp) = deploy_mocks();
        println!("Setup done");

        (executor, receiver, mockToken, mockDapp)
    }

    #[test]
    fn test_valid_calldata_message_fee_zero() {
        let (_executor, receiver, mockToken, mockDapp) = full_setup();

        // send funds to receiver
        let amount: felt252 = 100 * 1000000000000000000;
        mockToken.transfer(receiver.contract_address, amount.into());

        // approve and deposit
        let mut calldata: Array<felt252> = array![
            2, // 2 calls
            // call 1: approve
            mockToken.contract_address.into(), // token address
            selector!("approve"),
            3, // approve callata len
            mockDapp.contract_address.into(), // spender
            amount, // amount u256 low
            0, // amount u256 high
            // call2: deposit
            mockDapp.contract_address.into(), // dAPp address
            selector!("deposit"),
            2, // deposit calldata len
            amount, // amount
            0 // padding
        ];

        let payload = Payload {
            request_info: CommonRequest {
                id: 1,
                token: mockToken.contract_address,
                amount: amount,
                l2_owner: get_contract_address()
            },
            calldata: calldata
        };
        let mut flat_calldata: Array<felt252> = array![];
        payload.serialize(ref flat_calldata);

        let l1Handler = L1HandlerTrait::new(receiver.contract_address, selector!("on_receive"));
        l1Handler.execute(l1_easyleap_manager(), flat_calldata.span()).unwrap();

        let dappBalance = mockToken.balance_of(mockDapp.contract_address);
        assert(dappBalance == amount.into(), 'dapp balance incorrect');
    }

    // todo re-execution should fail
    #[test]
    fn test_invalid_calldata_message_fee_zero() {
        let (_executor, receiver, mockToken, mockDapp) = full_setup();

        // send funds to receiver
        let amount: felt252 = 100 * 1000000000000000000;
        mockToken.transfer(receiver.contract_address, amount.into());

        // approve and deposit
        let mut calldata: Array<felt252> = array![
            2, // 2 calls
            // call 1: approve
            mockToken.contract_address.into(), // token address
            selector!("approve"),
            3, // approve callata len
            mockDapp.contract_address.into(), // spender
            amount, // amount u256 low
            0, // amount u256 high
            // call2: deposit
            mockDapp.contract_address.into(), // dAPp address
            selector!("deposit"),
            2, // deposit calldata len
            amount + 1, // amount
            0 // padding
        ];

        let payload = Payload {
            request_info: CommonRequest {
                id: 1,
                token: mockToken.contract_address,
                amount: amount,
                l2_owner: get_contract_address()
            },
            calldata: calldata
        };
        let mut flat_calldata: Array<felt252> = array![];
        payload.serialize(ref flat_calldata);

        let l1Handler = L1HandlerTrait::new(receiver.contract_address, selector!("on_receive"));
        l1Handler.execute(l1_easyleap_manager(), flat_calldata.span()).unwrap();

        let dappBalance = mockToken.balance_of(mockDapp.contract_address);
        assert(dappBalance == amount.into(), 'dapp balance incorrect');
    }

    #[test]
    #[should_panic(expected: ('SPEND_ERROR',))]
    fn test_fail_calldata_message_fee_zero_balance_unused() {
        let (executor, receiver, mockToken, mockDapp) = full_setup();

        // send funds to receiver
        let amount: felt252 = 100 * 1000000000000000000;
        mockToken.transfer(receiver.contract_address, amount.into());

        // approve and deposit
        let mut calldata: Array<felt252> = array![
            1,
            // call 1: approve
            mockToken.contract_address.into(), // token address
            selector!("approve"),
            3, // approve callata len
            mockDapp.contract_address.into(), // spender
            amount, // amount u256 low
            0, // amount u256 high
        ];

        let payload = Payload {
            request_info: CommonRequest {
                id: 1,
                token: mockToken.contract_address,
                amount: amount,
                l2_owner: get_contract_address()
            },
            calldata: calldata
        };
        let mut flat_calldata: Array<felt252> = array![];
        payload.serialize(ref flat_calldata);

        let l1Handler = L1HandlerTrait::new(receiver.contract_address, selector!("on_receive_without_execute"));
        l1Handler.execute(l1_easyleap_manager(), flat_calldata.span()).unwrap();
        println!("Executed l1 handler");
        executor.execute(1);
    }

    #[test]
    #[should_panic(expected: ('ALREADY_LOCKED',))]
    fn test_fail_calldata_message_fee_zero_lock_again() {
        let (executor, receiver, mockToken, _mockDapp) = full_setup();

        // send funds to receiver
        let amount: felt252 = 100 * 1000000000000000000;
        mockToken.transfer(receiver.contract_address, amount.into());

        // approve and deposit
        let mut calldata: Array<felt252> = array![
            1,
            // call 1: approve
            receiver.contract_address.into(), // receiver
            selector!("lock"),
            1, // lock callata len
            1, // id
        ];

        let payload = Payload {
            request_info: CommonRequest {
                id: 1,
                token: mockToken.contract_address,
                amount: amount,
                l2_owner: get_contract_address()
            },
            calldata: calldata
        };
        let mut flat_calldata: Array<felt252> = array![];
        payload.serialize(ref flat_calldata);

        let l1Handler = L1HandlerTrait::new(receiver.contract_address, selector!("on_receive_without_execute"));
        l1Handler.execute(l1_easyleap_manager(), flat_calldata.span()).unwrap();
        println!("Executed l1 handler");
        executor.execute(1);
    }

    #[test]
    #[should_panic(expected: ('INVALID_LOCK',))]
    fn test_fail_calldata_message_fee_zero_unlock_again() {
        let (executor, receiver, mockToken, mockDapp) = full_setup();

        // send funds to receiver
        let amount: felt252 = 100 * 1000000000000000000;
        mockToken.transfer(receiver.contract_address, amount.into());

        // approve and deposit
        let mut calldata: Array<felt252> = array![
            3,
            // call 1: approve
            mockToken.contract_address.into(), // token address
            selector!("approve"),
            3, // approve callata len
            mockDapp.contract_address.into(), // spender
            amount, // amount u256 low
            0, // amount u256 high
            // call2: deposit
            mockDapp.contract_address.into(), // dAPp address
            selector!("deposit"),
            2, // deposit calldata len
            amount, // amount
            0, // padding
            // call 3: approve
            receiver.contract_address.into(), // receiver
            selector!("unlock"),
            1, // lock callata len
            1, // id
        ];

        let payload = Payload {
            request_info: CommonRequest {
                id: 1,
                token: mockToken.contract_address,
                amount: amount,
                l2_owner: get_contract_address()
            },
            calldata: calldata
        };
        let mut flat_calldata: Array<felt252> = array![];
        payload.serialize(ref flat_calldata);

        let l1Handler = L1HandlerTrait::new(receiver.contract_address, selector!("on_receive_without_execute"));
        l1Handler.execute(l1_easyleap_manager(), flat_calldata.span()).unwrap();
        println!("Executed l1 handler");
        executor.execute(1);
    }
}