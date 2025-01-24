#[starknet::contract]
mod Receiver {
    use starknet::event::EventEmitter;
    use easyleap::interfaces::IReceiver::IReceiver;
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use alexandria_storage::list::{List, ListTrait};
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

    // todo add easyleap::components::common component
    use easyleap::interfaces::IReceiver::{
        Payload, Request, Status, RequestWithCalldata, Settings
    };

    #[derive(Drop, Serde, starknet::Event)]
    pub struct ExecuteFailed {
        pub id: felt252,
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

        // common settings
        l1_easyleap_manager: felt252,
        executor: ContractAddress,

        // - if executor requests funds for a request id, lock state to prevent re-entrancy
        locked_id: felt252, // the ID of the request that is locked

        // request settings
        requests: Map<felt252, Request>,
        requests_calldata_map: Map<felt252, List<felt252>>,
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

        RequestWithCalldata: RequestWithCalldata,
        Request: Request,
        ExecuteFailed: ExecuteFailed,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, _admin: ContractAddress, settings: Settings
    ) {
        self.common.initializer(_admin);
        self.l1_easyleap_manager.write(settings.l1_easyleap_manager);
        self.executor.write(settings.executor);
    }

    #[abi(embed_v0)]
    impl StarkPullImpl of IReceiver<ContractState> {
        fn refund(ref self: ContractState, id: felt252, receiver: ContractAddress) {
            // Validations
            let mut request = self.requests.read(id);
            assert(request.status == Status::Pending, Errors::NOT_PENDING);
            assert(request.request_info.l2_owner == get_caller_address(), Errors::NOT_AUTHORIZED);

            // - refund the amount to the receiver
            IERC20Dispatcher { contract_address: request.request_info.token }
                .transfer(request.request_info.l2_owner, request.request_info.amount.into());

            // - update request status to Refunded
            request.status = Status::Refunded;
            self.requests.write(id, request);
            
            // emit current request status
            self.emit(request);
        }

        fn lock(ref self: ContractState, id: felt252) {
            // Validations
            let mut request = self.requests.read(id);
            assert(request.status == Status::Pending, Errors::NOT_PENDING);
            assert(self.locked_id.read() == 0, Errors::ALREADY_LOCKED);
            assert(self.executor.read() == get_caller_address(), Errors::NOT_AUTHORIZED);

            // Lock now with the request ID
            self.locked_id.write(id);
            // send funds of request to executor
            IERC20Dispatcher { contract_address: request.request_info.token }
                .transfer(self.executor.read(), request.request_info.amount.into());
        }

        fn unlock(ref self: ContractState, id: felt252) {
            // Validations
            let mut request = self.requests.read(id);
            assert(request.status == Status::Pending, Errors::NOT_PENDING);
            assert(self.locked_id.read() == id, Errors::INVALID_LOCK);
            assert(self.executor.read() == get_caller_address(), Errors::NOT_AUTHORIZED);

            // unlock
            self.locked_id.write(0);

            // update request status as success
            request.status = Status::Successful;
            self.emit(request);
        }

        fn get_request(ref self: ContractState, id: felt252) -> RequestWithCalldata {
            RequestWithCalldata {
                request: self.requests.read(id),
                calldata: self.requests_calldata_map.read(id).array().unwrap(),
            }
        }

        fn get_settings(self: @ContractState) -> Settings {
            Settings {
                l1_easyleap_manager: self.l1_easyleap_manager.read(),
                executor: self.executor.read(),
            }
        }

    }


    #[l1_handler]
    fn on_receive(ref self: ContractState, from_address: felt252, payload: Payload) {
        self._on_receive(from_address, payload);
    }

    #[l1_handler]
    fn on_receive_with_execute(ref self: ContractState, from_address: felt252, payload: Payload) {
        let request = self._on_receive(from_address, payload);

        // try to execute the request
        let execute_calldata: Array<felt252> = array![request.request_info.id];
        match call_contract_syscall(
            self.executor.read(),
            selector!("execute"),
            execute_calldata.span()
        ) {
            Result::Ok(_retdata) => {
                // ok great
            },
            Result::Err(_revert_reason) => {
                // sad, may be user will request refund
                self.emit(ExecuteFailed { id: request.request_info.id });
            },
        };

    }

    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        fn _on_receive(ref self: ContractState, from_address: felt252, payload: Payload) -> Request {
            assert(
                self.l1_easyleap_manager.read() == from_address,
                Errors::NOT_AUTHORIZED
            );
    
            let request = Request {
                request_info: payload.request_info,
                status: Status::Pending,
            };
            let existing_request = self.requests.read(request.request_info.id);
            assert(existing_request.request_info.id == 0, Errors::REQUEST_EXISTS);
    
            // save request
            self.requests.write(request.request_info.id, request);
    
            // save calldata
            let mut request_calldata = self.requests_calldata_map.read(request.request_info.id);
            request_calldata.append_span(payload.calldata.span()).unwrap();
    
            return request;
        }
    }
}



