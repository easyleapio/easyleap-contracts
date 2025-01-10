

// NOTE
// - decide on either to use the one click migration and deposit on l2.
          // cons - funds might be stuck for 5 days.

// OR 

// - use two steps, 
      // first bridge token and then
      // - user calls another function in l2, to deposit.
      // cons - not one click migration.





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
        admin: ContractAddress,


        l2_fund_owner_id: LegacyMap<ContractAddress, felt252>,
        amount: LegacyMap<felt252, felt252>,
        entry_point: LegacyMap<felt252, felt252>,
        dapp: LegacyMap<felt252, felt252>,
        isSpend: LegacyMap<felt252, bool>,

        // to be updated by the admin,
        // address of the 3rd party contracts
        dapp_address: LegacyMap<felt252, ContractAddress>,

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



        // TOBE ignored
        // fn spend(ref self: ContractState, entry_point: felt252, dapp: felt252, calldata: Array<ContractAddress>,) {
        //     // TODO, improve the id assignment
        //     let id : felt252 = self.l2_fund_owner_id.read(get_caller_address());
        //     assert(self.isSpend.read(id) == true, 'already spend');

        //     let dapp_address: ContractAddress = self.dapp_address.read(dapp);
            
        //     // conditions based on entry point
        //     if(entry_point == strkDeposit) { // strkDeposit -> eg function for depositing in one of the strkFarm pool

        //         //handle the calldata and call deposit
        //     }

        //     // conditions based on entry point
        //     if(entry_point == zkLendDeposit) { // strkDeposit -> eg function for depositing in one of the strkFarm pool

        //         //handle the calldata and call deposit
        //     }

        //     // TODO
        //     // Transfer LP tokens to the caller.


        //     self.isSpend.write(id, true);
        // }



        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.accesscontrol.assert_only_role('DEFAULT_ADMIN_ROLE');
            self.upgradeable._upgrade(new_class_hash);
        }


        // TODO
        fn update_admin(ref self: ContractState, new_admin: ContractAddress) {
            // self.accesscontrol.assert_only_role('DEFAULT_ADMIN_ROLE');
            // assert(!new_admin.is_zero(), Errors::ZERO_ADDRESS);
            // let old_admin: ContractAddress = self.get_admin();
            // self.accesscontrol._grant_role('DEFAULT_ADMIN_ROLE', new_admin);
            // self._set_admin(new_admin);
            // self.accesscontrol._revoke_role('DEFAULT_ADMIN_ROLE', old_admin);
        }

    }

    #[l1_handler]
    fn handle_arival_strk_farm(ref self: ContractState, from_address: felt252, payload: Payload) {

        // TODO _l1_handler to be implemented, returns l1 address
        let l1_stark_pull: ContractAddress = self._l1_handler();

        assert(
            contract_address_to_felt252(l1_stark_pull) == from_address,
            Errors::NOT_AUTHORIZED
        );

        let id: u128 = self._handle_arival(payload);

        self._spend_strk_farm(entry_point, dapp, payload);

        // self
        //     .emit(
        //         DepositFromL1 { id: payload.id, dapp: payload.dapp, l1_recipient: from_address, }
        //     )
    }

    #[l1_handler]
    fn handle_arival_zklend(ref self: ContractState, from_address: felt252, payload: Payload) {

       
    }


    #[generate_trait]
    impl StarkPull of StarkPullInternalTrait {

        fn _spend_strk_farm(ref self: ContractState, entry_point: felt252, dapp: felt252, calldata: Array<ContractAddress>,) {



            // TODO, improve the id assignment
            let id : felt252 = self.l2_fund_owner_id.read(get_caller_address());
            assert(self.isSpend.read(id) == true, 'already spend');

            let dapp_address: ContractAddress = self.dapp_address.read(dapp);
            

            // deconstruct payload, and use
            //handle the calldata and call deposit
            

            self.isSpend.write(id, true);
        }


        // handles the spending of bridged funds to 3rd party dapps.
        fn _handle_arival(ref self: ContractState, payload: Payload) -> u128 {
            

            // store user data
            self.l2_fund_owner_id.write(payload.l2_fund_owner, payload.id);
            
            self.amount.write(payload.id, payload.amount);
            self.entry_point.write(payload.id, payload.entry_point);
            self.dapp.write(payload.id, payload.dapp);
            
            payload.id

        }
        

        fn _erc20_camel(self: @ContractState) -> IERC20CamelDispatcher {
            IERC20CamelDispatcher { contract_address: self.token.read() }
        }

        
    }
}

