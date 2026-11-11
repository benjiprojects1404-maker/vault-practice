// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vault} from "../Vault.sol";

/// DRILL 3: the app and its backend treat `isVault[x] == true` as "x is one of our genuine vaults"
/// and happily route user deposits to it. Find the bug.
contract VaultFactory {
    address public immutable owner;
    mapping(address => bool) public isVault;
    address[] public allVaults;

    event VaultCreated(address indexed vault, address indexed asset);

    constructor() { owner = msg.sender; }

    function createVault(IERC20 asset) external returns (Vault vault) {
        require(msg.sender == owner, "not owner");
        vault = new Vault(asset);
        _register(address(vault));
        emit VaultCreated(address(vault), address(asset));
    }

    /// Lets a vault deployed elsewhere be added to the list.
    function registerVault(address vault) external {
        _register(vault);
    }

    function _register(address vault) internal {
        require(!isVault[vault], "already registered");
        isVault[vault] = true;
        allVaults.push(vault);
    }

    function vaultCount() external view returns (uint256) { return allVaults.length; }
}

/// The fixed factory: only vaults it created itself are ever registered.
contract SafeVaultFactory {
    address public immutable owner;
    mapping(address => bool) public isVault;
    address[] public allVaults;

    event VaultCreated(address indexed vault, address indexed asset);

    constructor() { owner = msg.sender; }

    function createVault(IERC20 asset) external returns (Vault vault) {
        require(msg.sender == owner, "not owner");
        vault = new Vault(asset);
        isVault[address(vault)] = true;
        allVaults.push(address(vault));
        emit VaultCreated(address(vault), address(asset));
    }

    function vaultCount() external view returns (uint256) { return allVaults.length; }
}
