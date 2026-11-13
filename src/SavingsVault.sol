// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @title SavingsVault
/// @notice ERC-4626 vault for a payments app's customer savings. Deposits earn the yield the operator sends in.
///         Includes a deposit cap and a way to rescue tokens sent to the vault by mistake.
contract SavingsVault is ERC4626 {
    using SafeERC20 for IERC20;

    address public owner;
    uint256 public depositCap;

    event CapChanged(uint256 newCap);
    event Rescued(address token, address to, uint256 amount);

    constructor(IERC20 asset_, uint256 cap_) ERC20("Payments Savings", "pSAVE") ERC4626(asset_) {
        owner = msg.sender;
        depositCap = cap_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function setDepositCap(uint256 newCap) external onlyOwner {
        depositCap = newCap;
        emit CapChanged(newCap);
    }

    /// @notice Deposits stop once the vault holds `depositCap` assets.
    function maxDeposit(address) public view override returns (uint256) {
        uint256 total = totalAssets();
        return total >= depositCap ? 0 : depositCap - total;
    }

    /// @dev Virtual shares against first-depositor inflation.
    function _decimalsOffset() internal pure override returns (uint8) {
        return 6;
    }

    /// @notice Sends tokens that were transferred to the vault by mistake to `to`.
    function rescueTokens(address token, address to) external {
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(to, amount);
        emit Rescued(token, to, amount);
    }
}
