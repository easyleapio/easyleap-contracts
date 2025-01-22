// SPDX-License-Identifier: Business Source License 1.1

pragma solidity ^0.8.28;

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

    struct Request {
     address token;
     uint256 amount;
     address sender;    
    }

    struct Settings {
        uint256 fee_eth;
        address fee_receiver;
        address eth_address;
        uint256 l2_starkpull_receiver;
    }

    struct TokenConfig {
        address l1_token_address;
        uint256 l2_token_address;
        address token_bridge;
    }
    
    // address public mock;
    // bytes32 constant MANAGER_ADMIN = keccak256("MANAGER_ADMIN");

    address admin;
    uint256 current_request_id;
    Settings settings;

    uint256 constant L2_SELECTOR = 480768629706071032051132431608482761444818804172389941599997570483678682398; // on_receive;
    IStarknetMessaging STARKNET_CORE_CONTRACT;

    // 3. requests: mapping (id => Request)
     mapping(uint256 => Request) public idToRequest;

    // events list
    event InitMigration(uint256 id, address indexed token, uint256 amount, address  indexed sender);
    event Refund(uint256 id, address indexed token, uint256 amount, address  indexed sender);
    event EthReceived(uint256 amount, address);
    event FeeReceived(address indexed sender, uint256 amount, address receiver);

    constructor(
        address snMessaging,
        address _admin,
        Settings memory _settings
    ) {
        _initialize(snMessaging, _admin, _settings);
    }

    function initialize(
        address snMessaging,
        address _admin,
        Settings memory _settings
    ) external initializer {
        // todo assert only initizlied once
        _initialize(snMessaging, _admin, _settings);
    }

    function _initialize(
        address snMessaging,
        address _admin,
        Settings memory _settings
    ) internal initializer {
        STARKNET_CORE_CONTRACT = IStarknetMessaging(snMessaging);
        settings = _settings;
        
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
        TokenConfig memory tokenConfig, 
        uint256 amount, 
        uint256 reciever, 
        uint256[] memory _calldata
    )
        external
        payable
    {
        // asserts
        require(amount > 0,"Invalid amount");
        require(_calldata.length > 0,"Empty calldata");
        require(
            tokenConfig.l2_token_address != 0, // not checking others cause it will fail this tx anyways
            "Invalid L2 token"
        );

        // collect fee
        uint256 _fee = settings.fee_eth;
        if (_fee > 0) {
            require(msg.value >= _fee, "Insufficient fee");
            payable(settings.fee_receiver).transfer(_fee);
            emit FeeReceived(msg.sender, _fee, settings.fee_receiver);
        }

        // increase request id
        uint256 current_id = ++current_request_id;

        uint256 msg_fee = 0; // use remaining amount for paying l1 l2 msging fee
        // receive tokens from caller to transfer
        if (settings.eth_address == tokenConfig.l1_token_address) {
            // ensure enough ETH is received
            require(msg.value > _fee + amount, "Incorrect ETH amount");
            msg_fee = msg.value - amount - _fee;

            // bridge eth
            IStarknetTokenBridge(tokenConfig.token_bridge).deposit{ value: amount }(amount, settings.l2_starkpull_receiver);
        } else {
            require(msg.value == _fee, "Incorrect Fee amount");
            msg_fee = msg.value - _fee;

            // - transfer token from caller to this contract
            IERC20 _token = IERC20(tokenConfig.l1_token_address);
            bool success = _token.transferFrom(msg.sender, address(this), amount);
            require(success, "Transfer failed");

            // bridge token
            // todo approve tokens
            IStarknetTokenBridge(tokenConfig.token_bridge).deposit(amount, settings.l2_starkpull_receiver);
        }

        /**
         * Payload structure
         * {
         *      request_id: felt252,
         *      l2_token: ContractAddress,
         *      amount: felt252,
         *      l2_owner: ContractAddress,
         *      calls: Call[] // Call is like a StarknetJS object
         * }
         */

        // assert valid payload
        // these are just basic accounting checks
        // if invalid flat(Call[]) is passed, l2 execution will fail but l2 owner can collect funds anyways
        _calldata[0] = current_id;
        require(_calldata[1] == tokenConfig.l2_token_address, "Invalid payload [2]");
        require(_calldata[2] == amount, "Invalid payload [3]");
        require(_calldata[3] != 0, "Invalid payload [4]"); // l2 receiver
        require(_calldata[4] > 0, "Invalid payload [5]"); // non-zero Starknet Call[] length required

        // todo should we assert a max calldata length to prevent gas limit issues?
        
        // - bridge and send msg
        _sendMessage(tokenConfig, amount, _calldata, msg_fee);

        // - write to requests
        idToRequest[current_id] = Request({
            token: tokenConfig.l1_token_address,
            amount: amount,
            sender: msg.sender
        });
        
        // emit InitMigration
        emit InitMigration(current_id, tokenConfig.l1_token_address, amount, msg.sender);
    }

    function refund(
        uint256 _id,
        address receiver
    )
        external
    {
        // asserts
        // id must be valid
        // caller must be the sender of the request
        // check if request is failed (need to see if bridge contract can provide that info)

        // transfer token from this contract to receiver
        // emit Refund
    }

    function _sendMessage(TokenConfig memory tokenConfig, uint256 amount, uint256[] memory _payload, uint256 _msg_fee) internal {
        // send the message
        STARKNET_CORE_CONTRACT.sendMessageToL2{
            value: _msg_fee
        }(settings.l2_starkpull_receiver, L2_SELECTOR, _payload);
    }

    function set_settings(Settings memory _settings) external
        onlyRole(DEFAULT_ADMIN_ROLE) {
        settings = _settings;
    }

    function getSettings() external view returns (Settings memory) {
        return settings;
    }

    function nextRequestId() external view returns (uint256) {
        return current_request_id + 1;
    }

    function getRequest(uint256 id) external view returns (Request memory) {
        return idToRequest[id];
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