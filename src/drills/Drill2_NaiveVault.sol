// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// DRILL 2: this vault looks fine and uses OpenZeppelin. What can the very first depositor do?
contract NaiveVault is ERC4626 {
    constructor(IERC20 asset_) ERC20("Naive Vault", "nVAULT") ERC4626(asset_) {}
}
