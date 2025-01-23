#[starknet::interface]
pub trait ITestDapp<TContractState> {
    fn deposit(self: @TContractState, amount: u256);
}

#[starknet::contract]
mod TestDApp {
    use starknet::{
        get_caller_address,
        get_contract_address
    };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::ITestDapp;

    #[storage]
    pub struct Storage {
        pub token: IERC20Dispatcher
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token: IERC20Dispatcher
    ) {
        self.token.write(token);
    }

    #[abi(embed_v0)]
    impl TestDAppImpl of ITestDapp<ContractState> {
        fn deposit(self: @ContractState, amount: u256) {
            let token = self.token.read();
            token.transfer_from(get_caller_address(), get_contract_address(), amount);
        }
    }
}