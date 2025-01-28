#[starknet::contract]
mod Executor {
    use starknet::{ContractAddress, get_contract_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::account::Call;
    use easyleap::interfaces::IReceiver::{
        IReceiverDispatcher, IReceiverDispatcherTrait, Status
    };
    use easyleap::interfaces::IExecutor::{
        IExecutor, Settings
    };
    use easyleap::utils::errors::Errors;
    use starknet::syscalls::{call_contract_syscall};

    // common comp deps
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::pausable::{PausableComponent};
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent::{
        InternalImpl as ReentrancyGuardInternalImpl,
    };
    use easyleap::components::common::{CommonComp};
    // ---
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: ReentrancyGuardComponent, storage: renack, event: ReentrancyGuardEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: CommonComp, storage: common, event: CommonCompEvent);

    #[abi(embed_v0)]
    impl CommonCompImpl = CommonComp::CommonImpl<ContractState>;
    impl CommonInternalImpl = CommonComp::InternalImpl<ContractState>;

    #[derive(Drop, Serde, starknet::Event)]
    pub struct ExecutionOutput {
        pub id: felt252,
        pub retdata: Array<Span::<core::felt252>>,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        renack: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        common: CommonComp::Storage,

        fee_bps: u128,
        fee_receiver: ContractAddress,
        l1Receiver: IReceiverDispatcher,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        CommonCompEvent: CommonComp::Event,

        ExecutionOutput: ExecutionOutput,
    }


    #[constructor]
    fn constructor(
        ref self: ContractState, _admin: ContractAddress, settings: Settings
    ) {
        self.common.initializer(_admin);
        self._set_settings(settings);
    }

    #[abi(embed_v0)]
    impl StarkPullImpl of IExecutor<ContractState> {
        fn execute(ref self: ContractState, id: felt252) {
            /// println!("Executing request {}", id);
            self.renack.start();

            // assert request is in pending state
            let receiverDisp = self.l1Receiver.read();
            let mut request = receiverDisp.get_request(id);
            assert(request.request.status == Status::Pending, Errors::NOT_PENDING);
            /// println!("Executing request {}", id);

            // lock and receive funds
            // ensures the calldata cannot execute arbitrary code to use other funds
            receiverDisp.lock(id);

            // transfer fee to fee receiver
            let fee_amount = self.get_fee(request.request.request_info.amount.try_into().unwrap());
            let tokenDisp = IERC20Dispatcher { contract_address: request.request.request_info.token };
            if (fee_amount > 0) {
                tokenDisp.transfer(self.fee_receiver.read(), fee_amount.into());
            }
            /// println!("Fee amount {}", fee_amount);

            // conver raw calldata to calls
            let mut calldata_span = request.calldata.span();
            let calls: Array<Call> = Serde::<Array<Call>>::deserialize(ref calldata_span).unwrap();
            let len = calls.len();
            /// println!("Executing {} calls", len);

            // Implementation from Argent account code
            // https://github.com/argentlabs/argent-contracts-starknet/blob/1352198956f36fb35fa544c4e46a3507a3ec20e3/src/utils/calls.cairo#L4
            let mut result: Array<Span::<core::felt252>> = array![];
            let mut index = 0;
            loop {
                if (index >= len) {
                    break;
                }
                let call = calls[index];
                /// println!("Executing call {}", index);
                let retdata = call_contract_syscall(*call.to, *call.selector, *call.calldata).unwrap();
                result.append(retdata);
                index += 1;
            };
            /// println!("execution done");

            // assert no balance left
            let currentBalance: u256 = tokenDisp.balance_of(get_contract_address());
            assert(currentBalance == 0, Errors::SPEND_ERROR);

            // emit execution output
            self.emit(ExecutionOutput {
                id: id,
                retdata: result,
            });
            /// println!("balance check failed");
            
            // unlocks the receive making the transaction done
            // This ensures the lock is closed on the receiver
            receiverDisp.unlock(id);
            self.renack.end();
        }

        fn set_settings(ref self: ContractState, settings: Settings) {
            self.common.assert_only_owner();
            self._set_settings(settings);
        }

        fn get_settings(self: @ContractState) -> Settings {
            Settings {
                fee_bps: self.fee_bps.read(),
                fee_receiver: self.fee_receiver.read(),
                l1Receiver: self.l1Receiver.read(),
            }
        }

        fn get_fee(self: @ContractState, amount: u128) -> u128 {
            return amount * self.fee_bps.read() / 10000;
        }
    }

    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        fn _set_settings(ref self: ContractState, settings: Settings) {
            self.fee_bps.write(settings.fee_bps);
            self.fee_receiver.write(settings.fee_receiver);
            self.l1Receiver.write(settings.l1Receiver);
        }
    }
}



