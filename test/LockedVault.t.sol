// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LockedVault} from "../src/LockedVault.sol";
import {MockToken} from "../src/Tokens.sol";

contract LockedVaultTest is Test {
    MockToken usd;
    LockedVault vault;
    address alice = makeAddr("alice");

    function setUp() public {
        usd = new MockToken();
        vault = new LockedVault(usd);
        usd.mint(alice, 10_000e18);
        vm.prank(alice);
        usd.approve(address(vault), type(uint256).max);
    }

    function test_cannotWithdrawDuringLock() public {
        vm.startPrank(alice);
        vault.deposit(1_000e18, alice);
        vm.expectRevert();
        vault.withdraw(1_000e18, alice, alice);
        vm.stopPrank();
    }

    function test_canWithdrawAfterLock() public {
        vm.prank(alice);
        vault.deposit(1_000e18, alice);
        vm.warp(block.timestamp + 7 days);
        vm.prank(alice);
        vault.withdraw(1_000e18, alice, alice);
        assertEq(usd.balanceOf(alice), 10_000e18);
    }

    function test_maxWithdrawIsZeroDuringLock() public {
        vm.prank(alice);
        vault.deposit(1_000e18, alice);
        assertEq(vault.maxWithdraw(alice), 0);
    }
}
