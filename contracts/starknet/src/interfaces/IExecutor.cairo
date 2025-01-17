use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
pub trait IExecutor<TContractState> {
    fn execute(ref self: TContractState, id: felt252);
}
