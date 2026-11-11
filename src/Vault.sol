// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @notice The reference vault: OpenZeppelin's ERC-4626, plus virtual shares against the inflation attack.
contract Vault is ERC4626 {
    constructor(IERC20 asset_) ERC20("Vault Share", "vSHARE") ERC4626(asset_) {}

    /// Virtual shares: 10**6 extra shares (and 1 extra asset) in every conversion, so a first depositor
    /// can't push the share price high enough to round the next depositor's shares down to (almost) nothing.
    function _decimalsOffset() internal pure override returns (uint8) {
        return 6;
    }
}
