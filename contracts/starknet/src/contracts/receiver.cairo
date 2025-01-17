#[starknet::contract]
mod StarkPull {
    use starknet::contract_address::contract_address_const;

    use starkpull::interfaces::IReceiver::IReceiver;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use starknet::account::Call;

    // use starknet::storage::{
    //     StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    // };
    use starknet::storage::{Map, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    // todo add starkpull::components::common component
    use starkpull::interfaces::IReceiver::{
        Payload, Request, Status
    };

    #[storage]
    struct Storage {
        l1_starkpull_manager: ContractAddress,
        requests: Map<felt252, Request>,
        executor: ContractAddress,
        // if executor requests funds for a request id, lock state to prevent re-entrancy
        locked_id: felt252, // the ID of the request that is locked
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, _admin: ContractAddress, executor: ContractAddress
    ) {

    }

    #[abi(embed_v0)]
    impl StarkPullImpl of IReceiver<ContractState> {
        fn refund(ref self: ContractState, id: felt252, receiver: ContractAddress){
            // assert request is in pending state
            let mut request = self.requests.entry(id);
            assert(request.status.read() == 1, 'Not in Pending');

            // assert caller is the l2_fund_owner
            assert(request.l2_fund_owner.read() == get_caller_address(), 'Not the owner');

            // - refund the amount to the receiver
            IERC20Dispatcher { contract_address: request.token.read() }
                .transfer(request.l2_fund_owner.read(), request.amount.read());

            // - update request status to Refunded
            request.status.write(3);  // 3: Refunded /* replace with enum */
        //     // Emit event Refunded
        }

        fn lock(ref self: ContractState, id: felt252) {
            // assert request id is pending
            // assert locked_id is 0
            // assert caller is executor
            
            // self.locked_id.write(id);
            // send funds of request to executor
        }

        fn unlock(ref self: ContractState, id: felt252) {
            // assert request id is pending
            // assert locked_id is id
            // assert caller is executor

            // update request status as success
            // self.locked_id.write(0);
        }
    }


    #[l1_handler]
    fn on_receive(ref self: ContractState, from_address: felt252, payload: Payload) {

        let caller: ContractAddress = from_address.try_into().unwrap();

        let l1_starkpull_manager: ContractAddress = self.l1_starkpull_manager.read();

        assert(
            l1_starkpull_manager == caller,
            'NOT_AUTHORIZED'
        );

        let request = Request {
            id: payload.id,
            token: payload.token,
            amount: payload.amount,
            l2_owner: payload.l2_owner,
            status: Status::Pending,
            calldata: payload.calldata, // todo Create List from Array using alexandria_storage::list
        };

        self.requests.write(request.id, request);
    }


}



