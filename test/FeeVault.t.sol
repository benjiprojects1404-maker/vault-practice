// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FeeVault} from "../src/FeeVault.sol";
import {MockToken} from "../src/Tokens.sol";

contract FeeVaultTest is Test {
    MockToken usd;
    FeeVault vault;
    address treasury = makeAddr("treasury");
    address alice = makeAddr("alice");

    function setUp() public {
        usd = new MockToken();
        vault = new FeeVault(usd, treasury, 50); // 0.5% withdrawal fee
        usd.mint(alice, 10_000e18);
        vm.prank(alice);
        usd.approve(address(vault), type(uint256).max);
    }

    function test_depositAndWithdrawChargesFee() public {
        vm.startPrank(alice);
        vault.deposit(1_000e18, alice);
        vault.withdraw(1_000e18, alice, alice);
        vm.stopPrank();
        assertEq(usd.balanceOf(treasury), 5e18);
        assertEq(usd.balanceOf(alice), 10_000e18 - 5e18);
    }

    function test_onlyOwnerSetsFee() public {
        vm.prank(alice);
        vm.expectRevert(bytes("not owner"));
        vault.setWithdrawFee(10);
    }

    function test_feeCapped() public {
        vm.expectRevert(bytes("fee too high"));
        vault.setWithdrawFee(101);
    }
}
