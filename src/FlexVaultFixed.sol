// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title FlexVault
/// @notice Flexible savings account for a neobank. Customers can take money out at any time; each withdrawal
///         pays a 0.1% exit fee to the bank's treasury. The bank pays interest by sending funds into the vault,
///         which raises the value of every share.
contract FlexVaultFixed is ERC4626, Ownable {
    using Math for uint256;

    uint256 public constant EXIT_FEE_BPS = 10; // 0.1%
    uint256 private constant BPS = 10_000;

    address public immutable treasury;

    constructor(IERC20 asset_, address treasury_)
        ERC20("Flex Saver", "fSAV")
        ERC4626(asset_)
        Ownable(msg.sender)
    {
        treasury = treasury_;
    }

    /// @notice The bank pays interest into the vault.
    function addInterest(uint256 amount) external onlyOwner {
        SafeERC20.safeTransferFrom(IERC20(asset()), msg.sender, address(this), amount);
    }

    /// @dev Shares burned to pay out `assets` to the customer, plus the exit fee.
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 fee = _feeOnRaw(assets);
        return _convertToShares(assets + fee, Math.Rounding.Ceil); // FIX 1: round up (vault-favouring)
    }

    /// @dev Assets the customer receives for `shares`, after the exit fee.
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        uint256 assets = _convertToAssets(shares, Math.Rounding.Floor);
        return assets - _feeOnTotal(assets);
    }

    /// @dev Pays the customer, then sends the exit fee to the treasury.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        uint256 fee = _feeOnRaw(assets);
        super._withdraw(caller, receiver, owner, assets, shares);
        if (fee > 0) SafeERC20.safeTransfer(IERC20(asset()), treasury, fee);
    }

    /// @dev FIX 3: the most a customer can withdraw is what their shares pay out after the fee.
    function maxWithdraw(address owner) public view override returns (uint256) {
        return previewRedeem(balanceOf(owner));
    }

    /// @dev FIX 4: virtual shares make first-depositor inflation (and price-driven rounding) uneconomic.
    function _decimalsOffset() internal pure override returns (uint8) {
        return 6;
    }

    /// @dev Fee on an amount that doesn't include the fee yet.
    function _feeOnRaw(uint256 assets) private pure returns (uint256) {
        return assets.mulDiv(EXIT_FEE_BPS, BPS, Math.Rounding.Ceil); // FIX 2
    }

    /// @dev Fee contained in an amount that already includes it.
    function _feeOnTotal(uint256 assets) private pure returns (uint256) {
        return assets.mulDiv(EXIT_FEE_BPS, EXIT_FEE_BPS + BPS, Math.Rounding.Ceil); // FIX 2
    }
}
