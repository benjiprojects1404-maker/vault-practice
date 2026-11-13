// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SavingsVault} from "../src/SavingsVault.sol";
import {MockToken} from "../src/Tokens.sol";

contract SavingsVaultTest is Test {
    MockToken usd;
    SavingsVault vault;
    address alice = makeAddr("alice");

    function setUp() public {
        usd = new MockToken();
        vault = new SavingsVault(usd, 1_000_000e18);
        usd.mint(alice, 10_000e18);
        vm.prank(alice);
        usd.approve(address(vault), type(uint256).max);
    }

    function test_depositAndRedeem() public {
        vm.startPrank(alice);
        uint256 shares = vault.deposit(1_000e18, alice);
        uint256 back = vault.redeem(shares, alice, alice);
        vm.stopPrank();
        assertApproxEqAbs(back, 1_000e18, 1);
    }

    function test_capStopsDeposits() public {
        vault.setDepositCap(500e18);
        assertEq(vault.maxDeposit(alice), 500e18);
    }

    function test_onlyOwnerSetsCap() public {
        vm.prank(alice);
        vm.expectRevert(bytes("not owner"));
        vault.setDepositCap(1);
    }

    function test_rescueStrayToken() public {
        MockToken stray = new MockToken();
        stray.mint(address(vault), 5e18);
        vault.rescueTokens(address(stray), address(this));
        assertEq(stray.balanceOf(address(this)), 5e18);
    }
}
