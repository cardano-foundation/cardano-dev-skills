# Evaluation witnesses

When a script transaction lists required signers, the execution-unit evaluator
sees a preliminary body and will reject it unless those signatures are valid.
Apollo builds **evaluation-only** witnesses for that draft. They are not kept
in the unsigned transaction `Complete()` returns.

## Who supplies them

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

builder.AddEvaluationWitnessProvider(remoteEvaluationSigner{})
```

Witnesses are checked: ed25519 vkey and signature lengths, hash must be in the
required set, no duplicates, signature must verify over the preliminary body
hash. Missing required hashes fail evaluation with a list of hashes.

Providers are asked only for hashes not yet found. Signatures are sorted by
vkey hash before the evaluator sees them.

## When this matters

- Script transactions with `AddRequiredSigner*` (for example a spend that
  checks extra signatures).
- Watch-only builders: without a provider, `Complete()` cannot estimate
  execution units and fails with missing evaluation witnesses.

Turn estimation off with `DisableExecutionUnitsEstimation()` only when you
already set `ExUnits` on every redeemer (`CollectFrom`, `Mint`, withdrawals).
