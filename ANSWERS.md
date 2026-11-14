# Mock 4 (FlexVault): answers

Don't read this until you've tried the task on the `mock-4` branch.

Run the proofs: `forge test --match-contract FlexVaultAnswersTest -vv`
The fixed contract is `src/FlexVaultFixed.sol` (every change is marked `FIX`).

## What it does (step 1)

An ERC-4626 vault with a 0.1% **exit fee** sent to a treasury, and an owner-only `addInterest` that raises
the share price. It follows OpenZeppelin's fee-vault pattern: `previewWithdraw` adds the fee to the shares
burned, `previewRedeem` takes the fee out of what's paid, and `_withdraw` forwards the fee.

## Are the tests enough? (step 2)

No. They only test the happy path with round numbers at a 1:1 price. Missing: small amounts, a share price
above 1 (after interest), `withdraw(maxWithdraw(...))`, a first depositor, and fuzzing of
withdraw vs. previewWithdraw. Every bug below hides in those gaps.

## Findings (step 3), most severe first

### 1. `previewWithdraw` rounds down: withdrawals can burn zero shares (High; Critical with #4)

`_convertToShares(assets + fee, Math.Rounding.Floor)`. The usual suspect: **rounding direction**. Rounding
must always favour the vault: when the user *receives* assets, the shares they *give up* round **up**
(OpenZeppelin's own `previewWithdraw` uses `Ceil`).

- Proof: `test_bug1_withdrawBurnsZeroShares`. After interest a share is worth ~2 assets; withdrawing 1 wei
  burns floor(0.5) = 0 shares.
- On its own it's dust per call, but it breaks the core invariant (assets leave, no shares burned) and the
  amount scales with the share price. See #4.
- Fix: `Math.Rounding.Ceil`.

### 2. The fee rounds down too (Low)

`_feeOnRaw` and `_feeOnTotal` use `Floor`, so any withdrawal under 1,000 wei pays no fee, and every fee is
slightly under. Same rule: a fee the user pays rounds **up**. Proof: same test, the treasury gets 0.
Fix: `Ceil` in both.

### 3. `maxWithdraw` ignores the fee, so withdrawing the max always reverts (Medium)

`maxWithdraw` isn't overridden, so it returns the full value of the shares. Withdrawing that much needs
0.1% more shares than the user has, so `withdraw(maxWithdraw(owner))` reverts. ERC-4626 says it must not.
Any wallet, aggregator or "withdraw all" button built on the standard breaks. This is the **pairs rule**
again: the fee was added to `previewWithdraw`/`previewRedeem`, but not to their partner `maxWithdraw`.

- Proof: `test_bug3_withdrawMaxReverts`.
- Fix: `maxWithdraw(owner) = previewRedeem(balanceOf(owner))`.

### 4. No `_decimalsOffset`: first-depositor inflation, which turns #1 into a drain (High)

The **first depositor** suspect. With no virtual shares, an attacker deposits 1 wei (1 share) and donates
10,000 directly, so one share is worth 10,000. Later depositors lose to rounding, and with bug #1 the
attacker can then withdraw just under 10,000 at a time while burning **zero** shares, again and again.

- Proof: `test_bug1and4_attackerDrainsVault`. Eve still holds her 1 share and takes over 90,000 of Alice's
  100,000.
- Fix: `_decimalsOffset() = 6` (plus fix #1). With the fix, the same steps burn shares on every withdrawal
  and Alice keeps nearly all her deposit (`test_bug1and4_fixed_noFreeWithdrawals`).

### Also worth saying in an interview (no test needed)

- **Owner trust:** `addInterest` is owner-only (fine), but anyone can still donate, which is what #4 abuses.
- **Odd tokens:** with a fee-on-transfer asset, `_deposit` would mint shares for more than arrived. Fine for
  USDC; say "I'd confirm the asset".
- **The good bits:** SafeERC20, the fee is paid after `super._withdraw` (state first, then transfers), and the
  OpenZeppelin fee pattern is the right starting point. It just had to keep the rounding right.

## The one-line lesson

When you override a preview function, re-check two things: **which way it rounds** (always in the vault's
favour), and **its partner functions** (`max*` and the other preview/action pair).
