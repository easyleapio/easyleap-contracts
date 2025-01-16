#[starknet::contract]
mod StarkPull {
    use starknet::contract_address::contract_address_const;

    use starkpull::interfaces::IStarkPull::IStarkPull;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};


    // use starknet::storage::{
    //     StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    // };
    use starknet::storage::{Map, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};


    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    struct Request {
        id: felt252,
        token: ContractAddress,
        amount: felt252,
        l2_fund_owner: ContractAddress,
        // status: Enum (Pending, Successful, Refunded), // default is Pending  
        status : felt252, // 1: pending, 2: successful, 3: Refunded /* replace with enum */
        // calls: Array<Call>,
        entry_point: felt252,
        calldata: Array<felt252>
    }

    #[derive(Drop, Serde)]
    struct Payload {

        id: felt252,
        // payload[1] = correspondingToken[token]; // starknet token address
        token: felt252,
        // payload[2] = amount; // amount
        amount: felt252,
        // payload[3] = uint256(uint160(msg.sender)); // sender
        l1_owner: felt252,
        // payload[4] = reciever; // reciever
        l2_owner: felt252,

        entry_point: felt252,
        // payload[5] = uint256(keccak256(abi.encode(_calldata))); // calldata
        calldata: Array<felt252>

    }


    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,

        l1_starkpull_manager: ContractAddress,

        requests: LegacyMap<felt252, Request>,

        dapp_adderess: LegacyMap<felt252, ContractAddress>,


    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
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
            assert(self.requests.read(id).status == 1, 'Not in Pending');


            let dapp_adderess: ContractAddress = self.dapp_adderess.read(self.requests.read(id).entry_point);
            
            // - execute calls (Check argent account execute code to understand how calls are executed)

            let prevBalance: u256 = IERC20Dispatcher { contract_address: self.requests.read(id).token }
                .balance_of(get_contract_address());
            

            IERC20Dispatcher { contract_address: self.requests.read(id).token }
                .approve(self.cl_vault.read(), self.requests.read(id).amount);

            let mut res = starknet::call_contract_syscall(
                address: dapp_adderess,
                entry_point_selector: self.requests.read(id).entry_point,
                calldata: self.requests.read(id).calldata,
            );

            let currentBalance: u256 = IERC20Dispatcher { contract_address: self.requests.read(id).token }
                .balance_of(get_contract_address());

            // - Post execution, the balance change of the token should be equal to the amount (to ensure funds are actually spent)
            assert(currentBalance == prevBalance - self.requests.read(id).amount, 'spend error');

            // - update request status to Successful

            self.requests.write(
                id,
                Request {
                            id: id,
                            token: token,
                            amount: amount,
                            l2_fund_owner: l2_owner,
                            status : 2, //2: successful, /* replace with enum */
                            entry_point: entry_point,
                            calldata: calldata
                        }
            );


            // Emit event Executed
        }

        fn refund(ref self: ContractState, id: felt252, receiver: ContractAddress){
            // assert request is in pending state
            assert(self.requests.read(id).status == 1, 'Not in Pending');

            // assert caller is the l2_fund_owner
            assert(self.requests.read(id).l2_fund_owner == get_caller_address(), 'Not the owner');

            // - refund the amount to the receiver
            IERC20Dispatcher { contract_address: self.requests.read(id).token }
                .transfer(self.requests.read(id).l2_fund_owner, self.requests.read(id).amount);

            // - update request status to Refunded

            self.requests.write(
                id,
                Request {
                            id: id,
                            token: token,
                            amount: amount,
                            l2_fund_owner: l2_owner,
                            status : 3,  // 3: Refunded /* replace with enum */
                            entry_point: entry_point,
                            calldata: calldata
                        }
            );
            
            // Emit event Refunded
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

        let id : felt252 = payload.id;
        let token : ContractAddress = payload.token.try_into().unwrap();
        let amount : u256 = payload.amount.try_into().unwrap();
        let l2_owner : ContractAddress = payload.l2_owner.try_into().unwrap();
        let entry_point: felt252 = payload.entry_point;
        let calldata : Array<felt252> = payload.calldata;

        // assert the caller is valid

        // assert payload has valid request id, non-zero token, non-zero amount, non-zero l2_fund_owner and calls.length > 0
        // assert(payload.id > 0, 'invalid id');

        assert(id != 0, 'invalid id');
        assert(token != contract_address_const::<0>(), 'invalid token');
        assert(amount > 0, 'invalid amount');
        assert(l2_owner != contract_address_const::<0>(), 'invalid l2 owner');
        assert(entry_point != 0, 'invalid entry point');
        assert(calldata.len() > 0, 'invalid calldata');

        
        // create a new request

        self.requests.write(
            id,
            Request {
                        id: id,
                        token: token,
                        amount: amount,
                        l2_fund_owner: l2_owner,
                        status : 1, // 1: pending, 2: successful, 3: Refunded /* replace with enum */
                        entry_point: entry_point,
                        calldata: calldata
                    }
        );


        
        // Emit event Received
        


    }


}



