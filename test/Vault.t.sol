// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {MockToken} from "../src/Tokens.sol";

/// The basics: what a correct ERC-4626 vault does. Read these first.
contract VaultTest is Test {
    MockToken asset;
    Vault vault;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        asset = new MockToken();
        vault = new Vault(asset);
        for (uint256 i; i < 2; i++) {
            address u = i == 0 ? alice : bob;
            asset.mint(u, 1_000_000e18);
            vm.prank(u);
            asset.approve(address(vault), type(uint256).max);
        }
    }

    function test_depositThenRedeemGivesBackTheSame() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(100e18, alice);
        vm.prank(alice);
        uint256 back = vault.redeem(shares, alice, alice);
        assertEq(back, 100e18);
    }

    function test_previewMatchesActual() public {
        uint256 preview = vault.previewDeposit(100e18);
        vm.prank(alice);
        uint256 actual = vault.deposit(100e18, alice);
        assertEq(actual, preview);
    }

    function test_yieldGoesToShareholders() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(100e18, alice);
        asset.mint(address(vault), 10e18); // 10% yield arrives
        assertApproxEqAbs(vault.previewRedeem(shares), 110e18, 1);
    }

    /// Fuzz: whatever the amount, a deposit followed by a full redeem never pays out more than went in.
    function testFuzz_noFreeMoney(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000e18);
        vm.prank(alice);
        uint256 shares = vault.deposit(amount, alice);
        vm.prank(alice);
        uint256 back = vault.redeem(shares, alice, alice);
        assertLe(back, amount);
    }
}
