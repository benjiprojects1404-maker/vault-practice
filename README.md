# Treasury Savings Vault: technical assessment

`src/FeeVault.sol` is an ERC-4626 savings vault for a fintech treasury product (OpenZeppelin 5, Foundry).
Users deposit a stablecoin and earn yield; withdrawals pay a small fee to the treasury.

## Setup

```bash
./setup.sh    # downloads forge-std and OpenZeppelin, then runs the tests
```

## Task (about 45 minutes)

1. Review `src/FeeVault.sol`. Talk us through what it does.
2. The existing tests pass. Are they enough? What's missing?
3. Find any issues. For each one: explain the impact, prove it with a Foundry test, and propose a fix.
