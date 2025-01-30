use starknet::{ContractAddress};

#[derive(Default, Drop, Copy, Serde, starknet::Store, PartialEq)]
pub enum Status {
    #[default]
    Pending,
    Successful,
    Refunded,
}

#[derive(Drop, Serde, Copy, starknet::Store, starknet::Event)]
pub struct CommonRequest {
    pub id: felt252,
    // payload[1] = correspondingToken[token]; // starknet token address
    pub token: ContractAddress,
    // payload[2] = amount; // amount
    pub amount: felt252,
    // payload[4] = reciever; // reciever
    pub l2_owner: ContractAddress,
}

#[derive(Drop, Serde)]
pub struct Payload {
    pub request_info: CommonRequest,
    pub calldata: Array<felt252>
}

// #[derive(Serde, Drop, Copy, starknet::Store)]
#[derive(Drop, Serde, Copy, starknet::Store, starknet::Event)]
pub struct Request {
    pub request_info: CommonRequest,
    pub status: Status,
}

#[derive(Drop, Serde, starknet::Event)]
pub struct RequestWithCalldata {
    pub request: Request,
    pub calldata: Array<felt252>
}

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct Settings {
    pub l1_easyleap_manager: felt252,
    pub executor: ContractAddress,
}

#[starknet::interface]
pub trait IReceiver<TContractState> {
    // fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    // fn update_admin(ref self: TContractState, new_admin: ContractAddress);
    // fn get_admin(self: @TContractState) -> ContractAddress;
    fn refund(ref self: TContractState, id: felt252, receiver: ContractAddress);
    fn lock(ref self: TContractState, id: felt252);
    fn unlock(ref self: TContractState, id: felt252);
    fn set_settings(ref self: TContractState, settings: Settings);

    fn get_request(self: @TContractState, id: felt252) -> RequestWithCalldata;
    fn get_settings(self: @TContractState) -> Settings;

    // todo set settings
}
