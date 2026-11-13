// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @title LockedVault
/// @notice Term-deposit vault for a neobank. Each deposit is locked for 7 days to earn a higher rate;
///         after the lock ends, the customer can take their money out at any time.
contract LockedVault is ERC4626 {
    uint256 public constant LOCK_PERIOD = 7 days;

    /// @notice When each account's current lock started (its most recent deposit).
    mapping(address => uint256) public lockStart;

    constructor(IERC20 asset_) ERC20("Term Deposit", "tDEP") ERC4626(asset_) {}

    function unlockTime(address account) public view returns (uint256) {
        return lockStart[account] + LOCK_PERIOD;
    }

    /// @dev Every deposit (re)starts the receiver's 7-day lock.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        lockStart[receiver] = block.timestamp;
        super._deposit(caller, receiver, assets, shares);
    }

    /// @notice Nothing can be withdrawn while the lock is running.
    function maxWithdraw(address owner) public view override returns (uint256) {
        if (block.timestamp < unlockTime(owner)) return 0;
        return super.maxWithdraw(owner);
    }

    /// @dev Virtual shares against first-depositor inflation.
    function _decimalsOffset() internal pure override returns (uint8) {
        return 6;
    }
}
