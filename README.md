# Term Deposit Vault: technical assessment

`src/LockedVault.sol` is an ERC-4626 term-deposit vault for a neobank (OpenZeppelin 5, Foundry).
Each deposit is locked for 7 days in exchange for a higher rate. After that, customers can withdraw at any time.

## Setup

```bash
./setup.sh    # downloads forge-std and OpenZeppelin, then runs the tests
```

## Task (about 45 minutes)

1. Review `src/LockedVault.sol`. Talk us through what it does.
2. The existing tests pass. Are they enough? What's missing?
3. Find any issues. For each one: explain the impact, prove it with a Foundry test, and propose a fix.
