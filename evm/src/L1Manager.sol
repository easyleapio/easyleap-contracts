// SPDX-License-Identifier: Business Source License 1.1

pragma solidity ^0.8.28;

import "./interfaces/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

interface IStarkgateTokenBridge {
    function deposit(
        uint256 amount,
        uint256 l2Recipient
    ) external payable;
}

interface IStarknetCore {
    function sendMessageToL2(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload
    ) external payable returns (bytes32, uint256);
    function l1ToL2MessageNonce() external view returns (uint256);
}

// error InvalidPayload();

/**
   @title Test contract to receive / send messages to starknet.
*/
contract L1Manager is Initializable, OwnableUpgradeable {
    struct Request {
     address token;
     uint256 amount;
     address sender;    
    }

    struct Settings {
        uint256 fee_eth;
        address fee_receiver;
        uint256 l2_easyleap_receiver;
    }

    struct TokenConfig {
        address l1_token_address;
        uint256 l2_token_address;
        address bridge_address;
    }
    
    // avoids storage collisions
    bytes32 constant STORAGE_SLOT = keccak256("MY_STORAGE_SLOT");

    // to keep it upgradeable
    struct MyStorage {
        address admin;
        uint256 current_request_id;
        Settings settings;
        IStarknetCore starknetCore;
        mapping(uint256 => Request) idToRequest;
    }
    
    uint256 constant L2_SELECTOR = 0x01101afb9568fc98d91b25365fb0f498486ed49680b8d2625a0b45a850311d1e; // on_receive;

    // events list
    // todo emit l2 reciever addr too
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
        starknetCore = IStarknetCore(snMessaging);
        settings = _settings;
        
        zeroAddressCheck(_admin);
        __Ownable_init(_admin);
    }

    function _setAdmin(address _admin) internal {
        admin = _admin;
    }

    /* ****************************************************************************************************************************** */

    function getAdmin() public view returns (address) {
        return admin;
    }

    function updateAdmin(address _admin) external onlyOwner {
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
            uint256 balance = address(this).balance;
            require(balance >= _fee, "Insufficient balance");
            payable(address(settings.fee_receiver)).transfer(_fee);
            emit FeeReceived(msg.sender, _fee, settings.fee_receiver);
        }

        // increase request id
        uint256 current_id = ++current_request_id;

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

        // receive tokens from caller to transfer
        uint256 remaining_eth_bal = address(this).balance;
        uint256 deposit_fee = 0.00001 ether; // is hard coding ok?
        if (tokenConfig.l1_token_address == address(0)) {
            // ensure enough ETH is received
            require(remaining_eth_bal > amount, "Incorrect ETH amount");
            
            // bridge eth
            IStarkgateTokenBridge(tokenConfig.bridge_address).deposit{ value: amount + deposit_fee }(amount, settings.l2_easyleap_receiver);
        } else {
            require(remaining_eth_bal > 0, "Invalid messaging Fee amount");

            // - transfer token from caller to this contract
            IERC20 _token = IERC20(tokenConfig.l1_token_address);
            bool success = _token.transferFrom(msg.sender, address(this), amount);
            require(success, "Transfer failed");

            // bridge token
            _token.approve(address(tokenConfig.bridge_address), amount);
            IStarkgateTokenBridge(tokenConfig.bridge_address).deposit{ value: deposit_fee }(amount, settings.l2_easyleap_receiver);
        }
        
        _sendMessage(_calldata);

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

    function _sendMessage(uint256[] memory _payload) internal {
        // send the message
        // use remaining amount as msg fee
        uint256 bal = address(this).balance;
        starknetCore.sendMessageToL2{
            value: bal
        }(settings.l2_easyleap_receiver, L2_SELECTOR, _payload);
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