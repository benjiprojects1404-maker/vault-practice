# Treasury Savings Vault: technical assessment

`src/SavingsVault.sol` is an ERC-4626 savings vault for a payments app (OpenZeppelin 5, Foundry).
Customers deposit a stablecoin and earn yield. There is a deposit cap and a rescue function for tokens sent by mistake.

## Setup

```bash
./setup.sh    # downloads forge-std and OpenZeppelin, then runs the tests
```

## Task (about 45 minutes)

1. Review `src/SavingsVault.sol`. Talk us through what it does.
2. The existing tests pass. Are they enough? What's missing?
3. Find any issues. For each one: explain the impact, prove it with a Foundry test, and propose a fix.
