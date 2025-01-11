

#[starknet::contract]
mod StarkPull {
    use starkpull::utils::errors::Errors;

    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};

    // use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::upgrades::UpgradeableComponent;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
        
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    use integer::BoundedU256;

    struct Request {
        id: u128,
        token: ContractAddress,
        amount: felt252,
        l2_fund_owner: ContractAddress,
        status: Enum (Pending, Successful, Refunded), // default is Pending
        calls: Array<Call>,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,

        // Components
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        
        // todo add src/components/common.cairo component as well
        // it has logic to hanle ownership, pausing, and upgrading

        requests: Map<u128, Request>,
    }

    #[derive(Drop, Serde)]
    struct Payload {
        id: felt252,
        amount: felt252,
        l2_fund_owner: felt252,
        entry_point: felt252,
        dapp: felt252
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AccessControlEvent: AccessControlComponent::Event,
        SRC5Event: SRC5Component::Event,
        UpgradeableEvent: UpgradeableComponent::Event,

        // todo
        // Received (request: Request);
        // Executed (request: Request);
        // Refunded (request: Request);
    }


    #[constructor]
    fn constructor(
        ref self: ContractState, _admin: ContractAddress
    ) {
        assert(!_admin.is_zero(), Errors::ZERO_ADDRESS);
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role('DEFAULT_ADMIN_ROLE', _admin);

    }

    #[abi(embed_v0)]
    impl StarkPullImpl of IStarkPull<ContractState> {

        fn execute(id) {
            // assert request is in pending state
            
            // - execute calls (Check argent account execute code to understand how calls are executed)
            // - Post execution, the balance change of the token should be equal to the amount (to ensure funds are actually spent)
            // - update request status to Successful
            // Emit event Executed
        }

        fn refund(id, receiver) {
            // assert request is in pending state
            // assert caller is the l2_fund_owner

            // - refund the amount to the receiver
            // - update request status to Refunded
            // Emit event Refunded
        }
    }

    #[l1_handler]
    fn on_receive(ref self: ContractState, from_address: felt252, payload: Payload) {
        // assert the caller is valid
        // assert payload has valid request id, non-zero token, non-zero amount, non-zero l2_fund_owner and calls.length > 0
        
        // create a new request
        // Emit event Received
    }
}

