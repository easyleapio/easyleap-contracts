// SPDX-License-Identifier: Business Source License 1.1

pragma solidity ^0.8.28;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Proxy contract using ERC1967
contract MyProxy is ERC1967Proxy {
    // _data is e.g. abi.encodeWithSelector(ExampleLogic.initialize.selector, _value)
    constructor(address implementation, address _admin, bytes memory _data)
      ERC1967Proxy(implementation, _data)
    {
      _changeAdmin(_admin);
    }
}