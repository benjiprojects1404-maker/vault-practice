// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FlexVault} from "../src/FlexVault.sol";
import {MockToken} from "../src/Tokens.sol";

contract FlexVaultTest is Test {
    MockToken usd;
    FlexVault vault;
    address treasury = makeAddr("treasury");
    address alice = makeAddr("alice");

    function setUp() public {
        usd = new MockToken();
        vault = new FlexVault(usd, treasury);
        usd.mint(alice, 10_000e18);
        vm.prank(alice);
        usd.approve(address(vault), type(uint256).max);
        usd.mint(address(this), 1_000_000e18);
        usd.approve(address(vault), type(uint256).max);
    }

    function test_depositGivesShares() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1_000e18, alice);
        assertEq(vault.balanceOf(alice), shares);
        assertGt(shares, 0);
    }

    function test_withdrawPaysExitFeeToTreasury() public {
        vm.startPrank(alice);
        vault.deposit(1_000e18, alice);
        vault.withdraw(500e18, alice, alice);
        vm.stopPrank();
        assertEq(usd.balanceOf(treasury), 0.5e18); // 0.1% of 500
        assertEq(usd.balanceOf(alice), 9_500e18);
    }

    function test_interestRaisesShareValue() public {
        vm.prank(alice);
        vault.deposit(1_000e18, alice);
        vault.addInterest(100e18);
        assertGt(vault.convertToAssets(vault.balanceOf(alice)), 1_000e18);
    }

    function test_onlyOwnerAddsInterest() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.addInterest(1e18);
    }
}
