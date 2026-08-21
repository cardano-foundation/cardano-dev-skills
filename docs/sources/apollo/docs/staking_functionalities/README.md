# Staking Functionalities in Apollo

This section documents how to build **staking-related transactions** with the Apollo library: stake key registration and deregistration, delegation to stake pools, vote (DRep) delegation, combined certificates, and reward withdrawals. The APIs align with **cardano-cli** (10.14.0.0) stake-address and transaction build certificate/withdrawal flags.

## Table of Contents

- [Credential Helpers](credential_helpers.md) — `GetStakeCredentialFromWallet`, `GetStakeCredentialFromAddress`; address/wallet stake key assumptions
- [Register Methods](register_methods.md) — `RegisterStake*`, `RegisterAndDelegateStake*`, `RegisterAndDelegateVote*`, `RegisterAndDelegateStakeAndVote*`; deposit behavior and examples
- [Deregister Methods](deregister_methods.md) — `DeregisterStake*`; refund behavior and examples
- [Delegate Stake Methods](delegate_stake_methods.md) — `DelegateStake*`, `DelegateStakeAndVote*`
- [Delegate Vote Methods](delegate_vote_methods.md) — `DelegateVote*`; DRep setup
- [Withdrawal Methods](withdrawal_methods.md) — `AddWithdrawal` including redeemer variant

Each page includes method signatures, behavior, side-by-side Apollo + CLI examples, evidence labels (verified by tests vs implementation-only), and caveats.

## Capability Matrix

| Area | Apollo support | Notes |
|------|----------------|-------|
| Stake key derivation | Yes | Via `SetWalletFromMnemonic` or `NewBursaWallet`; wallet has `StakePubKeyHash()` |
| Stake credential from address/wallet | Yes | `GetStakeCredentialFromAddress`, `GetStakeCredentialFromWallet` |
| Stake registration | Yes | `RegisterStake`, `RegisterStakeFromAddress`, `RegisterStakeFromBech32` |
| Stake deregistration | Yes | `DeregisterStake`, `DeregisterStakeFromAddress`, `DeregisterStakeFromBech32` |
| Stake pool delegation | Yes | `DelegateStake`, `DelegateStakeFromAddress`, `DelegateStakeFromBech32` |
| Register + delegate (combined cert) | Yes | `RegisterAndDelegateStake`, etc. |
| Vote (DRep) delegation | Yes | `DelegateVote`, `RegisterAndDelegateVote`, etc. |
| Stake + vote combined | Yes | `DelegateStakeAndVote`, `RegisterAndDelegateStakeAndVote`, etc. |
| Withdrawals | Yes | `AddWithdrawal(address, amount, redeemer, exUnits)` |
| Deposit handling | Yes | Current network `key_deposit` applied/refunded in `Complete()` (2 ADA fallback) |

## CLI-to-Apollo Mapping Index

| Cardano CLI (10.14.0.0) | Apollo method / pattern |
|-------------------------|--------------------------|
| `stake-address build` | Credential via `GetStakeCredentialFromWallet` / `GetStakeCredentialFromAddress`; build `Address` with staking part |
| `stake-address registration-certificate` | `RegisterStake` / `RegisterStakeFromAddress` / `RegisterStakeFromBech32` |
| `stake-address deregistration-certificate` | `DeregisterStake` / `DeregisterStakeFromAddress` / `DeregisterStakeFromBech32` |
| `stake-address delegation-certificate` | `DelegateStake` / `DelegateStakeFromAddress` / `DelegateStakeFromBech32` |
| `transaction build --withdrawal` | `AddWithdrawal(address, amount, redeemer, exUnits)` |

Combined certificates (register+delegate, vote, stake+vote) are documented in the corresponding method-family pages above.

## See also

- [Data Attachment](../data_attachment/README.md) — Datums and reference scripts on outputs
- [Plutus V3 Support](../plutus_v3_support/README.md) — Plutus V3 scripts and reference inputs

## Reference

- [Cardano CLI repository](https://github.com/IntersectMBO/cardano-cli) — CLI command reference (10.14.0.0)
