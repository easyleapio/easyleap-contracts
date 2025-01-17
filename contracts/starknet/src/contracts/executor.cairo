#[starknet::contract]
mod StarkPull {
    use starknet::contract_address::contract_address_const;
    use starkpull::interfaces::IStarkPull::IStarkPull;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use starknet::storage::{Map, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::account::Call;

    // todo add common component

    #[storage]
    struct Storage {
        receiver: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, _admin: ContractAddress
    ) {

    }

    #[abi(embed_v0)]
    impl StarkPullImpl of IStarkPull<ContractState> {
        fn execute(ref self: ContractState, id: felt252) {
            // assert request is in pending state
            let mut request = self.requests.entry(id);
            assert(request.status.read() == 1, 'Not in Pending');

            // ? this will lock and prevent re-entrancy
            // ? this will also send the funds of the request to this contract
            IReceiverDispatcher { contract_address: self.receiver.read() }
                .lock(id);
            
            let mut calldata_span = request.calldata.span();
            let calls: Array<Call> = Serde::<Array<Call>>::deserialize(ref calldata_span).unwrap();
            let len = calls.len();
            let mut i = 0;

            // ? Reference link
            // https://github.com/argentlabs/argent-contracts-starknet/blob/1352198956f36fb35fa544c4e46a3507a3ec20e3/src/utils/calls.cairo#L4
            loop {
                let call = calls[i];
                let mut res = starknet::call_contract_syscall(
                    address: call.target,
                    entry_point_selector: call.selector,
                    calldata: call.calldata,
                );

                // todo remember to unwrap and check result as shown in above github link
            }

            let currentBalance: u256 = IERC20Dispatcher { contract_address: request.token.read() }
                .balance_of(get_contract_address());

            // ? there should be no remaining balance left
            assert(currentBalance == 0, 'spend error');

            // unlocks the receive making the transaction done
            // This ensures the lock is closed on the receiver
            IReceiverDispatcher { contract_address: self.receiver.read() }
                .unlock(id);

            // Emit event Executed
        }
    }
}



