# Vault practice kit

A small Foundry project for rehearsing an ERC-4626 technical assessment: one correct vault, four broken ones
to find the bug in, and tests that prove each bug and each fix. Everything runs on your own machine, offline
after setup. Nothing here touches a wallet or a real network.

## Setup (once)

```bash
git clone https://github.com/benjiprojects1404-maker/vault-practice.git
cd vault-practice
./setup.sh          # downloads forge-std and OpenZeppelin, then runs every test
```

You should see all tests pass. Useful commands:

| Command | What it does |
| --- | --- |
| `forge test` | run every test |
| `forge test --match-test drill1 -vvv` | run one drill's tests, with traces if one fails |
| `forge test --match-contract VaultTest` | run one test file |
| `forge build` | compile only |

## How to practise

Do each drill as if the Tech Manager is watching: **talk out loud** while you work. Thinking out loud matters
more than finishing. Time-box each one to 15 minutes. Only open the answer when the time is up.

The pattern for every drill:

1. **Read the contract** and say what it's for in one sentence.
2. **Say what you check first**: rounding direction, who can call what, where money moves, unusual tokens.
3. **Find the bug** and explain the attack in plain words: who does what, in what order, and who loses.
4. **Prove it** with a test (or find the matching test in `test/Drills.t.sol` and explain it line by line).
5. **Say the fix**, and why it works.

---

### Warm-up: the reference vault (`src/Vault.sol`, `test/Vault.t.sol`)

Read the four tests in `test/Vault.t.sol` and run them. Be able to explain:

- why `previewDeposit` must equal what `deposit` actually gives;
- how yield reaches shareholders without anyone calling anything (`totalAssets` goes up, so each share is worth more);
- what the fuzz test proves (`testFuzz_noFreeMoney`) and what `bound` does.

### Drill 1: `src/drills/Drill1_RoundingVault.sol`

One function is overridden. What's wrong with it, and how would you steal from this vault?

<details><summary>Answer</summary>

`previewWithdraw` rounds the shares to burn **down** (`Floor`). When a share is worth more than 1 wei, withdrawing
1 wei burns `floor(0.5) = 0` shares, so anyone holding a share can withdraw 1 wei at a time for free, forever.
`test_drill1_bug_withdrawBurnsZeroShares`: Bob puts in 3 wei and takes out 10 while keeping his share.

**Rule:** always round in the vault's favour. `deposit`/`redeem` round down (user gets less); `mint`/`withdraw`
round up (user pays more). **Fix:** delete the override; OpenZeppelin rounds `previewWithdraw` up (`Ceil`).
</details>

### Drill 2: `src/drills/Drill2_NaiveVault.sol`

It's plain OpenZeppelin. What can the very first depositor do?

<details><summary>Answer</summary>

The **first-depositor (inflation) attack**. The attacker deposits 1 wei (1 share), then sends 10,000 tokens straight
to the vault. The share price is now ~10,000 tokens. The victim deposits 10,000 tokens and gets **1 share**
(10,000 / 10,000 rounds down), worth about two thirds of the deposit. `test_drill2_bug_victimLosesAThird`.

**Fixes:** virtual shares (`_decimalsOffset()`, as in `src/Vault.sol`, which makes the attack cost the attacker
far more than it can take), burning a small first deposit ("dead shares", like Uniswap's `MINIMUM_LIQUIDITY`, which
you know from Reef), or tracking assets internally instead of reading `balanceOf`.
`test_drill2_fixed_virtualSharesProtect`: the victim keeps ~100%.
</details>

### Drill 3: `src/drills/Drill3_VaultFactory.sol`

The app trusts `isVault[x]` to mean "x is genuine" and routes deposits to it. Find the bug.

<details><summary>Answer</summary>

`registerVault` has **no access control**: anyone can register any address, including a fake vault that keeps
deposits. `test_drill3_bug_anyoneRegistersAFakeVault`.

**Fix:** only vaults the factory deployed itself are registered (`SafeVaultFactory`), and creation is owner-only.
In a real system, the owner would be a multisig, ideally behind a timelock. Mention also: emit an event for every
vault (the backend indexes them), validate inputs (asset not zero), and consider CREATE2 for predictable addresses.
</details>

### Drill 4: fee-on-transfer tokens (`src/Tokens.sol` `FeeToken`, `test_drill4_*`)

Deposit 100 `FeeToken` into the reference `Vault`. What goes wrong?

<details><summary>Answer</summary>

`FeeToken` burns 1% of every transfer, so only 99 arrive, but ERC-4626 credits shares for the 100 that were *sent*.
The depositor is credited more than the vault holds, at the expense of everyone else.
`test_drill4_bug_sharesForMoreThanArrived`.

**Fixes:** refuse such tokens by checking the balance before and after (`StrictVault`), or price shares from the
amount actually received. The same goes for rebasing tokens. You know this one from Reef: its router can buy tax
tokens but can't sell them.
</details>

### Drill 5: write a test live

Without looking, write a fuzz test for the reference `Vault`: "two users deposit any amounts; when both redeem
everything, the vault never pays out more than it holds." Use `bound`, `vm.prank`, `assertLe`. Run it with
`forge test --match-test <yourName> -vvv`. If it fails, read the trace out loud and fix it.

---

## Before the real session

- [ ] Run `./setup.sh` and see every test pass on the machine you'll share.
- [ ] Do all five drills once, out loud, timed.
- [ ] Test screen sharing on that machine, with a headset plugged in.
- [ ] For **their** code: read it on GitHub first. Check `foundry.toml` for `ffi = true` before running any test
  (that setting lets tests run shell commands). Never run their install or setup scripts, or `forge script`, on a
  machine with wallets or keys.
