use starknet::{ContractAddress};
use starkpull::interfaces::IReceiver::{
    IReceiverDispatcher
};

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Settings {
    pub fee_bps: u128,
    pub fee_receiver: ContractAddress,
    pub l1Receiver: IReceiverDispatcher
}

#[starknet::interface]
pub trait IExecutor<TContractState> {
    fn execute(ref self: TContractState, id: felt252);
    fn set_settings(ref self: TContractState, settings: Settings);
    fn get_settings(self: @TContractState) -> Settings;
    fn get_fee(self: @TContractState, amount: u128) -> u128;
}
