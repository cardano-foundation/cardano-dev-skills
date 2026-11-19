# Evaluation witnesses

Apollo sends unsigned preliminary transactions for execution-unit evaluation
by default. It does not ask the wallet or registered witness providers to sign
those drafts. Some evaluators reject a draft whose body lists required signers
without their signatures. In that case, use a trusted evaluator and explicitly
enable signed evaluation, or set the redeemers' `ExUnits` and call
`DisableExecutionUnitsEstimation()`.

`AllowSignedEvaluation()` lets Apollo obtain valid signatures for each
preliminary body and send them to the evaluator. Although these witnesses are
not kept in the unsigned transaction `Complete()` returns, the evaluator may
be able to submit the signed draft. This can spend inputs or consume collateral.
Only enable it when the evaluator is trusted with that authority.

## Who supplies them

When signed evaluation is enabled:

1. A non-external `Wallet` signs with its payment key when that hash is
   required.
2. `BursaWallet` also signs with its stake key for remaining required hashes it
   controls (`EvaluationWitnesses` on the wallet).
3. Any number of `EvaluationWitnessProvider` values registered with
   `AddEvaluationWitnessProvider`.

`ExternalWallet` is watch-only and is skipped in step 1–2. Hardware and remote
signers implement the provider:

```go
type remoteEvaluationSigner struct{}

func (remoteEvaluationSigner) EvaluationWitnesses(
    bodyHash common.Blake2b256,
    required []common.Blake2b224,
) ([]common.VkeyWitness, error) {
    // Return valid witnesses for requested hashes this signer controls.
    return nil, nil
}

builder.AddEvaluationWitnessProvider(remoteEvaluationSigner{}).
    AllowSignedEvaluation()
```

Witnesses are checked: ed25519 vkey and signature lengths, hash must be in the
required set, no duplicates, signature must verify over the preliminary body
hash. Missing required hashes fail evaluation with a list of hashes.

Providers are asked only for hashes not yet found. Signatures are sorted by
vkey hash before the evaluator sees them.

## When this matters

- Script transactions with `AddRequiredSigner*` (for example a spend that
  checks extra signatures).
- Watch-only builders using signed evaluation: without a provider, `Complete()`
  fails with missing evaluation witnesses.

Turn estimation off with `DisableExecutionUnitsEstimation()` only when you
already set `ExUnits` on every redeemer (`CollectFrom`, `Mint`, withdrawals).
