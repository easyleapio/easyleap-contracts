// SPDX-License-Identifier: Business Source License 1.1
pragma solidity ^0.8.28;

interface IStarknetTokenBridge {
    function deposit(uint256 amount, uint256 l2Recipient) external payable;
    function transferOutFunds(uint256 amount, address recipient) external;
    function isTokenContractRequired() external pure returns (bool);
    function bridgedToken() external view returns (address);
    function messagingContract() external view returns (address);
    function l2TokenBridge() external view returns (uint256);
    function maxTotalBalance() external view returns (uint256);
    function maxDeposit() external view returns (uint256);
    function isActive() external view returns (bool);
    function depositors(uint256) external view returns (address);
    function l2AddressToL1Address(uint256) external view returns (address);
    function setActive() external;
}
