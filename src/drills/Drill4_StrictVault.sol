// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vault} from "../Vault.sol";

/// DRILL 4 (the fix): the reference Vault credits shares for `assets` sent, not for what actually arrived.
/// With a fee-on-transfer token those differ. This version refuses such tokens instead of mis-pricing them.
contract StrictVault is Vault {
    constructor(IERC20 asset_) Vault(asset_) {}

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        IERC20 token = IERC20(asset());
        uint256 before = token.balanceOf(address(this));
        super._deposit(caller, receiver, assets, shares);
        require(token.balanceOf(address(this)) - before == assets, "fee-on-transfer token not supported");
    }
}
