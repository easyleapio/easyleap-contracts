// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "starknet/IStarknetMessaging.sol";

error InvalidPayload();

/**
   @title Test contract to receive / send messages to starknet.
*/
contract ContractMsg {
    // todo: Should be Ownable, Pausable, ReentrancyGuard

    IStarknetMessaging private _snMessaging;

    // struct Request {
    //  address token;
    //  uint256 amount;
    //  address sender;    
    // }

    // todo Variables:
    // 1. request id starting from 1
    // 2. settings (
    //     fee: uint256, // absolute fee in wei (ETH)
    //     feeReceicer: address, // address to receive fee
    // )
    // 3. requests: mapping (id => Request)

    // todo Events:
    // 1. InitMigration (id, token [indexed], amount, sender [indexed], payload)
    // 2. Refund (id, token [indexed], amount, sender [indexed], payload) // trigged in case of failure

    /**
       @notice Constructor.

       @param snMessaging The address of Starknet Core contract, responsible
       or messaging.
    */
    constructor(address snMessaging) {
        _snMessaging = IStarknetMessaging(snMessaging);
    }


    // TODO
    // USER calls migrate to bridge and perform requested actions.
    function push(
        token, amount, payload: bytes[]
    )
        external
        payable
    {
        // add pause check, reentrancy guard
        // asserts
        // token must be a valid token supported by starknet bridge

        // - transfer token from caller to this contract
        // - if fee is non-zero, also collect the fee from the caller and send to receiver
        // - create payload for L2 (id, token, amount, sender, ...payload)
            // - note: (remember to pass token address as l2 address of the corresponding l1 token)
            // - Does starkgate bridge have a function to get l2 address of l1 token?

        // - bridge and send msg
        // - write to requests
        // - increase request id

        // emit InitMigration
        // close reentrancy guard
    }

    function refund(
        id: uint256,
        receiver: address,
    )
        external
    {
        // add pause check, reentrancy guard
        // asserts
        // id must be valid
        // caller must be the sender of the request
        // check if request is failed (need to see if bridge contract can provide that info)

        // transfer token from this contract to receiver
        // emit Refund
        // close reentrancy guard
    }
}