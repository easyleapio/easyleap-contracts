use starknet::{ContractAddress, ClassHash};

#[derive(Default, Drop, Copy, Serde, starknet::Store, PartialEq)]
pub enum Status {
    #[default]
    Pending,
    Successful,
    Refunded,
}

#[derive(Drop, Serde, starknet::Event)]
pub struct Payload {
    pub id: felt252,
    // payload[1] = correspondingToken[token]; // starknet token address
    pub token: ContractAddress,
    // payload[2] = amount; // amount
    pub amount: felt252,
    // payload[4] = reciever; // reciever
    pub l2_owner: ContractAddress,
    pub calldata: Array<felt252>
}

// #[derive(Serde, Drop, Copy, starknet::Store)]
#[derive(Drop, Serde, Copy, starknet::Store, starknet::Event)]
pub struct Request {
    pub id: felt252,
    // payload[1] = correspondingToken[token]; // starknet token address
    pub token: ContractAddress,
    // payload[2] = amount; // amount
    pub amount: felt252,
    // payload[4] = reciever; // reciever
    pub l2_owner: ContractAddress,
    pub status: Status,
    pub calldata: List<felt252> // alexandria_storage::list 
}

#[starknet::interface]
pub trait IReceiver<TContractState> {
    // fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    // fn update_admin(ref self: TContractState, new_admin: ContractAddress);
    // fn get_admin(self: @TContractState) -> ContractAddress;
    fn refund(ref self: TContractState, id: felt252, receiver: ContractAddress);
    fn lock(ref self: TContractState, id: felt252) -> u256;
    fn unlock(ref self: TContractState, id: felt252);
}
