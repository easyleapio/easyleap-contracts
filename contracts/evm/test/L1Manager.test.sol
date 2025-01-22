// SPDX-License-Identifier: Business Source License 1.1
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {L1Manager} from "../src/L1_Manager.sol";

contract L1ManagerTest is Test {
    L1Manager public l1Manager;

    function setUp() public {
        l1Manager = new L1Manager();
        counter.setNumber(0);
    }

    function test_Increment() public {
        counter.increment();
        assertEq(counter.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
}
