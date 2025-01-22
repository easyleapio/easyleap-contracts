// SPDX-License-Identifier: Business Source License 1.1
pragma solidity ^0.8.13;

import {Test, console} from "../dependencies/forge-std/src/Test.sol";
import {L1Manager, IStarkgateTokenBridge} from "../src/L1_Manager.sol";
import "../src/interfaces/IStarknetMessaging.sol";
import { StarknetMessaging } from "../src/SNMessage.sol";
import "../src/interfaces/IERC20.sol";
  
contract L1ManagerTest is Test {
    L1Manager public l1Manager;
    address fee_receiver = 0xF5FdA0DF5546C6F10Bd82Ab9a0daC3B912328f6c;
    address starknetCore = 0xc662c410C0ECf747543f5bA90660f6ABeBD9C8c4;
    address l1_eth_bridge_address = 0xae0Ee0A63A2cE6BaeEFFE56e7714FB4EFE48D419;

    function setUp() public {
      L1Manager.Settings memory settings = L1Manager.Settings({
        fee_eth: 0.001 ether,
        fee_receiver: fee_receiver,
        l2_starkpull_receiver: 2524392021852001135582825949054576525094493216367559068627275826195272239197
      });
      l1Manager = new L1Manager(
        address(starknetCore),
        address(this),
        settings
      );
    }

    function test_push_ether() public {
        uint256 amount = 1 ether;
        L1Manager.TokenConfig memory config = L1Manager.TokenConfig({
            l1_token_address: address(0),
            l2_token_address: 2087021424722619777119509474943472645767659996348769578120564519014510906823, // ETH L2 address
            bridge_address: l1_eth_bridge_address
        });
        uint256[] memory _calldata = new uint256[](5);
        _calldata[0] = 1;
        _calldata[1] = config.l2_token_address;
        _calldata[2] = amount;
        _calldata[3] = 1; // l2_recipient
        _calldata[4] = 1; // 1 Calls length

        uint256 amountToSend = 1.005 ether;
        uint256 balance = address(this).balance;
        require(balance > amountToSend, "balance should be greater than 0");
        l1Manager.push{value: amountToSend}(config, amount, _calldata);
    }

    function test_push_strk() public {
      // fund the contract with STRK
      address STRKAddr = address(0xCa14007Eff0dB1f8135f4C25B34De49AB0d42766);
      address STRKHolder = address(0x1521f00f0D805b4Aefc518D163F7ab84e4dfD68c);
      vm.startPrank(STRKHolder);
      IERC20(STRKAddr).transfer(address(this), 1 ether);
      vm.stopPrank();

      uint256 strkBal = IERC20(STRKAddr).balanceOf(address(this));
      uint256 amount = 1 ether;
      require(strkBal >= amount, "STRK balance should be greater than 1");

      // prepare parameters for push
      L1Manager.TokenConfig memory config = L1Manager.TokenConfig({
          l1_token_address: address(STRKAddr),
          l2_token_address: 2009894490435840142178314390393166646092438090257831307886760648929397478285, // STRK L2 address
          bridge_address: 0xcE5485Cfb26914C5dcE00B9BAF0580364daFC7a4 // STRK L1 bridge address
      });
      uint256[] memory _calldata = new uint256[](5);
      _calldata[0] = 1;
      _calldata[1] = config.l2_token_address;
      _calldata[2] = amount;
      _calldata[3] = 1; // l2_recipient
      _calldata[4] = 1; // 1 Calls length

      uint256 amountToSend = 0.002 ether;
      uint256 balance = address(this).balance;
      require(balance > amountToSend, "balance should be greater than 0");

      // approve and push
      IERC20(STRKAddr).approve(address(l1Manager), amount);
      l1Manager.push{value: amountToSend}(config, amount, _calldata);
    }
}
