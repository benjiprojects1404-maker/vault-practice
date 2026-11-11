// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {MockToken, FeeToken} from "../src/Tokens.sol";
import {RoundingVault} from "../src/drills/Drill1_RoundingVault.sol";
import {NaiveVault} from "../src/drills/Drill2_NaiveVault.sol";
import {VaultFactory, SafeVaultFactory} from "../src/drills/Drill3_VaultFactory.sol";
import {StrictVault} from "../src/drills/Drill4_StrictVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// Each drill has a "bug" test (proves the problem exists, so it PASSES) and a "fixed" test.
/// Try the drill first (PRACTICE.md), then read the matching test.
contract DrillsTest is Test {
    MockToken asset;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address attacker = makeAddr("attacker");

    function setUp() public {
        asset = new MockToken();
        asset.mint(alice, 1_000_000e18);
        asset.mint(bob, 1_000_000e18);
        asset.mint(attacker, 1_000_000e18);
    }

    function _approve(address who, address vault) internal {
        vm.prank(who);
        asset.approve(vault, type(uint256).max);
    }

    // ---------------------------------------------------------------- Drill 1: rounding direction
    // Share price ~2 assets per share. Bob deposits 3 wei, gets 1 share, then withdraws 1 wei at a time.
    function _drill1(IERC4626 v) internal returns (uint256 bobShares) {
        _approve(alice, address(v));
        _approve(bob, address(v));
        vm.prank(alice);
        v.deposit(1e18, alice);
        asset.mint(address(v), 1e18); // yield doubles the share price
        vm.prank(bob);
        bobShares = v.deposit(3, bob);
    }

    function test_drill1_bug_withdrawBurnsZeroShares() public {
        RoundingVault v = new RoundingVault(asset);
        uint256 shares = _drill1(IERC4626(address(v)));
        uint256 before = asset.balanceOf(bob);
        for (uint256 i; i < 10; i++) {
            vm.prank(bob);
            v.withdraw(1, bob, bob); // each one burns floor(...) = 0 shares
        }
        assertEq(v.balanceOf(bob), shares, "bob still has all his shares");
        assertEq(asset.balanceOf(bob) - before, 10, "yet took 10 wei out after putting 3 in");
    }

    function test_drill1_fixed_withdrawAlwaysBurnsShares() public {
        Vault v = new Vault(asset); // OpenZeppelin rounds withdraw's shares UP
        _drill1(IERC4626(address(v)));
        vm.prank(bob);
        uint256 burned = v.withdraw(1, bob, bob);
        assertGt(burned, 0);
    }

    // ---------------------------------------------------------------- Drill 2: first-depositor inflation
    function _drill2(IERC4626 v) internal returns (uint256 victimShares) {
        _approve(attacker, address(v));
        _approve(alice, address(v));
        vm.startPrank(attacker);
        v.deposit(1, attacker); // 1 wei: 1 share
        asset.transfer(address(v), 10_000e18); // "donate" to inflate the share price
        vm.stopPrank();
        vm.prank(alice);
        victimShares = v.deposit(10_000e18, alice); // the victim's deposit
    }

    function test_drill2_bug_victimLosesAThird() public {
        NaiveVault v = new NaiveVault(asset);
        uint256 shares = _drill2(IERC4626(address(v)));
        assertEq(shares, 1, "victim gets 1 share for 10,000 tokens");
        assertLt(v.previewRedeem(shares), 7_000e18, "and it's worth about two thirds of the deposit");
    }

    function test_drill2_fixed_virtualSharesProtect() public {
        Vault v = new Vault(asset); // _decimalsOffset() = 6
        uint256 shares = _drill2(IERC4626(address(v)));
        assertApproxEqRel(v.previewRedeem(shares), 10_000e18, 0.01e18, "victim keeps ~all of it");
    }

    // ---------------------------------------------------------------- Drill 3: factory access control
    function test_drill3_bug_anyoneRegistersAFakeVault() public {
        VaultFactory f = new VaultFactory();
        address fake = makeAddr("attackersFakeVault");
        vm.prank(attacker);
        f.registerVault(fake);
        assertTrue(f.isVault(fake), "the app now treats the attacker's contract as genuine");
    }

    function test_drill3_fixed_onlyOwnerCreates() public {
        SafeVaultFactory f = new SafeVaultFactory();
        vm.prank(attacker);
        vm.expectRevert(bytes("not owner"));
        f.createVault(IERC20(address(asset)));
        Vault v = f.createVault(IERC20(address(asset))); // this test contract is the owner
        assertTrue(f.isVault(address(v)));
        assertEq(f.vaultCount(), 1);
    }

    // ---------------------------------------------------------------- Drill 4: fee-on-transfer tokens
    function test_drill4_bug_sharesForMoreThanArrived() public {
        FeeToken fee = new FeeToken();
        fee.mint(alice, 1_000e18);
        Vault v = new Vault(IERC20(address(fee)));
        uint256 expected = v.previewDeposit(100e18);
        vm.startPrank(alice);
        fee.approve(address(v), type(uint256).max);
        uint256 shares = v.deposit(100e18, alice);
        vm.stopPrank();
        assertEq(shares, expected, "shares priced for the full 100 tokens...");
        assertEq(fee.balanceOf(address(v)), 99e18, "...but only 99 arrived");
        assertLt(v.previewRedeem(shares), 100e18, "so alice is short straight away");
    }

    function test_drill4_fixed_strictVaultRefusesFeeTokens() public {
        FeeToken fee = new FeeToken();
        fee.mint(alice, 1_000e18);
        StrictVault v = new StrictVault(IERC20(address(fee)));
        vm.startPrank(alice);
        fee.approve(address(v), type(uint256).max);
        vm.expectRevert(bytes("fee-on-transfer token not supported"));
        v.deposit(100e18, alice);
        vm.stopPrank();
    }
}
