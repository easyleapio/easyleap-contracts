// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "starknet/IStarknetMessaging.sol";

error InvalidPayload();

/**
   @title Test contract to receive / send messages to starknet.
*/
contract ContractMsg {

    //
    IStarknetMessaging private _snMessaging;

    /**
       @notice Constructor.

       @param snMessaging The address of Starknet Core contract, responsible
       or messaging.
    */
    constructor(address snMessaging) {
        _snMessaging = IStarknetMessaging(snMessaging);
    }


    // TODO
    // USER calls migrate to bridge and deposit.
    function migrate(uint256  amount, address _starknet_reviever, uint256 _dapp, uint256 _entry_point)
        external
        payable
    {
        _depositAndSendMessage(amount, _starknet_reviever, _dapp, _entry_point);
    }



    // _depositAndSendMessage: deposit the given amount and send message to L2
    function _depositAndSendMessage(uint256 amount, address _market, address _starknet_reviever, uint256 _dapp, uint256 _entry_point) internal {

        // send tokens to L2
        _depositToBridge(amount, _market);

        // send message and payload, calldata to l2 handler
        _sendMessageToL2(amount, _market, ........);

    }



    // send tokens to L2
    function _depositToBridge(uint256 amount, address _market) internal {

        // TODO get_token_bridge_contract will get the token specific address.
        let token_bridge_contract = get_token_bridge_contract()

        //TODO calculate the fees.
        IStarknetTokenBridge(token_bridge_contract).deposit{
            value: ethAmount + fees
        }(amount, l2_starkPull_address);

        emit DepositToStarkgateBridge(amount, uint256(l2_starkPull_address));
    }



    // send message and payload, calldata to specific l2 handler

    // array [] calldata, according to the need
    function _sendMessageToL2(uint256 _param1, uint256 _param2, uint256 _param3, uint256 _param4, uint8 _entry_point, array [] calldata)
        private
    {


        // condition
        // based on the dapp the user selects and type of action(deposit/stake [based on the function selector]), 
        // it will call seperate l1_handler in cairo contracts.
        if (_entry_point == STRK_FARM_DEPOSIT) {
            _sendMessage(
                // params are passed as defind in L2 handler
                _strkFarmMessagePayload(_param1, _param2, _param3, _param4), 
                l2_handeler_selector_strkFarm
            );
        } else if ((_entry_point == ZKLEND_DEPOSIT)) {
            _sendMessage(
                _zkLendMessagePayload(
                    _param1, _param2, _param3, _param4, other_params, other_params2
                ),
                l2_handeler_selector
            );
        }
    }

    function _sendMessage(uint256[] memory _payload, uint256 _l2Selector) internal {
        IStarknetMessaging(starknetCoreContract_address).sendMessageToL2{
            value: protocolSettings().starknetMessagingFee
        }(this_address, _l2Selector, _payload);
    }



    //  function that will construct the payload according to the need in l2.
    function _strkFarmMessagePayload(uint256 _id, uint256 _amount, uint256 _l2_reciever, uint256 _otherparams)
        private
        pure
        returns (uint256[] memory)
    {
        uint256[] memory messagePayload = new uint256[](4);
        messagePayload[0] = _id;
        messagePayload[1] = _amount;
        messagePayload[2] = _l2_reciever;
        messagePayload[3] = _otherparams;
        return messagePayload;
    }

    //  function that will construct the payload according to the need in l2.
    function _zkLendMessagePayload(uint256 _id, uint256 _amount, uint256 _l2_reciever, uint256 _otherparams)
        private
        pure
        returns (uint256[] memory)
    {
        uint256[] memory messagePayload = new uint256[](4);
        messagePayload[0] = _id;
        messagePayload[1] = _amount;
        messagePayload[2] = _l2_reciever;
        messagePayload[3] = _otherparams;
        return messagePayload;
    }

        //      id: felt252,
        //     amount: felt252,
        //     l2_fund_owner: felt252,
        //     entry_point: felt252,
        //     dapp: felt252

    
}