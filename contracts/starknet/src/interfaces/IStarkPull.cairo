use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
pub trait IStarkPull<TContractState> {
    // fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    // fn update_admin(ref self: TContractState, new_admin: ContractAddress);
    // fn get_admin(self: @TContractState) -> ContractAddress;


    fn execute(ref self: TContractState, id: felt252);
    fn refund(ref self: TContractState, id: felt252, receiver: ContractAddress);

}
