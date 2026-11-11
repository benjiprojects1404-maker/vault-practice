// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// DRILL 1: find the bug. (Answer in PRACTICE.md, don't peek.)
contract RoundingVault is ERC4626 {
    constructor(IERC20 asset_) ERC20("Rounding Vault", "rVAULT") ERC4626(asset_) {}

    /// How many shares to burn for a withdrawal of `assets`.
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }
}
