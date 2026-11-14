# Flex Saver Vault: technical assessment

`src/FlexVault.sol` is an ERC-4626 savings vault for a neobank (OpenZeppelin 5, Foundry).
Customers can withdraw at any time and pay a 0.1% exit fee to the bank's treasury. The bank pays interest by
sending funds into the vault, which raises the value of every share.

## Setup

```bash
./setup.sh    # downloads forge-std and OpenZeppelin, then runs the tests
```

## Task (about 45 minutes)

1. Review `src/LockedVault.sol`. Talk us through what it does.
2. The existing tests pass. Are they enough? What's missing?
3. Find any issues. For each one: explain the impact, prove it with a Foundry test, and propose a fix.
