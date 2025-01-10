use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait IStarkPull<TContractState> {
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn update_admin(ref self: TContractState, new_admin: ContractAddress);
    fn get_admin(self: @TContractState) -> ContractAddress;
}
