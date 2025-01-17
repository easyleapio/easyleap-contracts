// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IStarknetMessaging.sol";
import "./interfaces/IStarknetTokenBridge.sol";

import "./interfaces/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";


// error InvalidPayload();

/**
   @title Test contract to receive / send messages to starknet.
*/
contract ContractMsg is AccessControlUpgradeable {
    // // todo: Should be Ownable, Pausable, ReentrancyGuard

    IStarknetMessaging private _snMessaging;

    struct Request {
     address token;
     uint256 amount;
     address sender;    
    }

    // address public mock;
    // bytes32 constant MANAGER_ADMIN = keccak256("MANAGER_ADMIN");

    // todo Variables:
    // 1. request id starting from 1
    uint256 id;

    // 2. settings (
    //     fee: uint256, // absolute fee in wei (ETH)
    //     feeReceicer: address, // address to receive fee
    // )
    uint256 fee;
    // address feeReceicer;
    address ethAddress;

    address admin;

    uint256 l2_starkpull_address;
    uint256 l2_selector;
    address starknet_core_contract;

    // 3. requests: mapping (id => Request)
     mapping(uint256 => Request) public idToRequest;

     mapping(address => bool) public supportedToken;

     mapping(address => uint256) public correspondingToken;

     mapping(address => address) public tokenBridge;


    // // todo Events:
    // // 1. InitMigration (id, token [indexed], amount, sender [indexed], payload)
    event InitMigration(uint256 id, address indexed token, uint256 amount, address  indexed sender);

    // // 2. Refund (id, token [indexed], amount, sender [indexed], payload) // trigged in case of failure
    event Refund(uint256 id, address indexed token, uint256 amount, address  indexed sender);

    event EthReceived(uint256 amount, address);

    event FeeReceived(address indexed sender, uint256 amount);

    event DepositToStarkgateBridge(uint256 amount, uint256 l2_starkpull_address);



    // // /**
    // //    @notice Constructor.

    // //    @param snMessaging The address of Starknet Core contract, responsible
    // //    or messaging.
    // // */
    // constructor(address snMessaging) {
    //     _snMessaging = IStarknetMessaging(snMessaging);
    // }

    function initialize(address _admin) external initializer {
        zeroAddressCheck(_admin);
        _setAdmin(_admin);
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }


    function _setAdmin(address _admin) internal {
        admin = _admin;
    }

    /* ****************************************************************************************************************************** */

    function getAdmin() public view returns (address) {
        return admin;
    }

    function updateAdmin(address _admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        zeroAddressCheck(_admin);
        address oldAdmin = getAdmin();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _setAdmin(_admin);
        _revokeRole(DEFAULT_ADMIN_ROLE, oldAdmin);
    }

    fallback() external payable {
        if (msg.value > 0) {
            emit EthReceived(msg.value, msg.sender);
        }
    }

    receive() external payable {
        if (msg.value > 0) {
            emit EthReceived(msg.value, msg.sender);
        }
    }



    // USER calls migrate to bridge and perform requested actions.
    function push(
        address token, uint256 amount, uint256 reciever, bytes memory entry_point, bytes[] memory _calldata
    )
        external
        payable
    {
        // add pause check, reentrancy guard


        // asserts
        require(amount > 0,"Invalid amount");
        require(_calldata.length > 0,"Empty calldata");


        // token must be a valid token supported by starknet bridge
        require(
            is_token_suppported(token) == true,
            "Token not supported"
        );

        // get the bridging fee;
        uint256 _fee = get_bridging_fee();


        // - if fee is non-zero, also collect the fee from the caller and send to receiver

        if (ethAddress == token) {
            require(msg.value == _fee + amount, "Incorrect ETH amount");

            // Emit an event for successful receipt
            emit FeeReceived(msg.sender, msg.value - amount);
        }else {
            require(msg.value == _fee, "Incorrect Fee amount");

            // Emit an event for successful receipt
            emit FeeReceived(msg.sender, msg.value);


            // - transfer token from caller to this contract
            IERC20 _token = IERC20(token);
            uint256 allowance = _token.allowance(msg.sender, address(this));
            require(allowance >= amount, "Allowance not sufficient");

            // Perform the transfer
            bool success = _token.transferFrom(msg.sender, address(this), amount);
            require(success, "Transfer failed");
        }

        

        


        // - create payload for L2 (id, token, amount, sender, ...payload)
            // - note: (remember to pass token address as l2 address of the corresponding l1 token)
            // - Does starkgate bridge have a function to get l2 address of l1 token?

        uint256[] memory payload = new uint256[](6);
        payload[0] = id + 1;
        payload[1] = correspondingToken[token]; // starknet token address
        payload[2] = amount; // amount
        payload[3] = uint256(uint160(msg.sender)); // sender
        payload[4] = reciever; // reciever
        payload[5] = abi.decode(entry_point, (uint256));
        payload[6] = uint256(keccak256(abi.encode(_calldata))); // calldata


        // - bridge and send msg
        _depositAndSendMessage(token, amount, payload);

        // - write to requests
        idToRequest[id] = Request({
            token: token,
            amount: amount,
            sender: msg.sender
        });
        
        // - increase request id
        id++;

        // emit InitMigration
        emit InitMigration(id, token, amount, msg.sender);
        // close reentrancy guard
    }

    function refund(
        uint256 _id,
        address receiver
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



    function _depositTokenToBridge(address token, uint256 amount) internal {
        IStarknetTokenBridge(tokenBridge[token]).deposit{
            value: amount + get_bridging_fee()
        }(amount, l2_starkpull_address);
        emit DepositToStarkgateBridge(amount, l2_starkpull_address);
    }


    function _sendMessage(uint256[] memory _payload, uint256 _l2Selector) internal {
        IStarknetMessaging(starknet_core_contract).sendMessageToL2{
            value: fee
        }(l2_starkpull_address, _l2Selector, _payload);
    }

    function _depositAndSendMessage(address token, uint256 amount, uint256[] memory _payload) internal {
        _depositTokenToBridge(token, amount);
        _sendMessage(_payload, l2_selector);
    }



    function is_token_suppported(address _token) public view returns (bool) {
        bool _is_token_suppported = supportedToken[_token];
        return _is_token_suppported;  
    }


    function set_token_suppport(address _token) external
        onlyRole(DEFAULT_ADMIN_ROLE) {
        supportedToken[_token] = true;
    }

    function set_bridging_fee(uint256 _fee) external
        onlyRole(DEFAULT_ADMIN_ROLE) {
        fee = _fee;
    }

    function set_l2_starkpull_address(uint256 _l2_starkpull_address) external
        onlyRole(DEFAULT_ADMIN_ROLE) {
        l2_starkpull_address = _l2_starkpull_address;
    }

    function set_l2_selector(uint256 _l2_selector) external
        onlyRole(DEFAULT_ADMIN_ROLE) {
        l2_selector = _l2_selector;
    }

    function set_starknet_core_contract(address _starknet_core_contract) external
        onlyRole(DEFAULT_ADMIN_ROLE) {
        starknet_core_contract = _starknet_core_contract;
    }

    function get_bridging_fee() public view returns (uint256) {
        return fee;  
    }

    function set_eth_address(address _ethAddress) external
        onlyRole(DEFAULT_ADMIN_ROLE) {
        ethAddress = _ethAddress;
    }

    function set_correspondingToken(address token, uint256 corToken) external
        onlyRole(DEFAULT_ADMIN_ROLE) {
        correspondingToken[token] = corToken;
    }

    function set_token_bridge_address(address token, address _token_bridge) external
        onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenBridge[token] = _token_bridge;
    }



    function zeroAddressCheck(address _address) internal pure {
        if (!_assembly_notZero(_address)) {
            revert ZeroAddress();
        }
    }

    function _assembly_notZero(address toCheck) internal pure returns (bool success) {
        assembly {
            if iszero(toCheck) {
                let ptr := mload(0x40) // The 0x40 is the location where free memory starts in Ethereum.
                mstore(ptr, 0xd92e233d00000000000000000000000000000000000000000000000000000000) // selector for `ZeroAddress()`
                revert(ptr, 0x4) // revert with the first 4 bytes, as function selector is 4 bytes in length
            }
        }
        return true;
    }

    error ZeroAddress();



}