// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @title FeeVault
/// @notice ERC-4626 savings vault for a fintech treasury product. Users deposit a stablecoin and earn
///         the yield the operator sends in. A small withdrawal fee goes to the treasury.
contract FeeVault is ERC4626 {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_FEE_BPS = 100; // 1%
    address public immutable treasury;
    address public owner;
    uint256 public withdrawFeeBps;

    event WithdrawFeeChanged(uint256 oldBps, uint256 newBps);

    constructor(IERC20 asset_, address treasury_, uint256 feeBps_)
        ERC20("Treasury Savings", "tSAVE")
        ERC4626(asset_)
    {
        require(treasury_ != address(0), "treasury is zero");
        require(feeBps_ <= MAX_FEE_BPS, "fee too high");
        treasury = treasury_;
        withdrawFeeBps = feeBps_;
        owner = msg.sender;
    }

    function setWithdrawFee(uint256 newBps) external {
        require(msg.sender == owner, "not owner");
        require(newBps <= MAX_FEE_BPS, "fee too high");
        emit WithdrawFeeChanged(withdrawFeeBps, newBps);
        withdrawFeeBps = newBps;
    }

    /// @dev Virtual shares against first-depositor inflation.
    function _decimalsOffset() internal pure override returns (uint8) {
        return 6;
    }

    /// @dev Pays the user `assets` minus the withdrawal fee, and sends the fee to the treasury.
    function _withdraw(address caller, address receiver, address owner_, uint256 assets, uint256 shares)
        internal
        override
    {
        uint256 fee = assets * withdrawFeeBps / 10_000;
        _burn(owner_, shares);
        IERC20(asset()).safeTransfer(treasury, fee);
        IERC20(asset()).safeTransfer(receiver, assets - fee);
        emit Withdraw(caller, receiver, owner_, assets, shares);
    }
}
