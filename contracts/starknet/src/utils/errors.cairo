pub mod Errors {
    pub const NOT_PENDING: felt252 = 'NOT_PENDING';
    pub const NOT_AUTHORIZED: felt252 = 'NOT_AUTHORIZED';
    pub const NOT_LOCKED: felt252 = 'NOT_LOCKED';
    pub const ALREADY_LOCKED: felt252 = 'ALREADY_LOCKED';
    pub const INVALID_LOCK : felt252 = 'INVALID_LOCK';
    pub const REQUEST_EXISTS: felt252 = 'REQUEST_EXISTS';
    pub const EXECUTE_FAILED: felt252 = 'EXECUTE_FAILED';
    pub const SPEND_ERROR: felt252 = 'SPEND_ERROR';
}