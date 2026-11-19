# Bug: TxBuilder doesn't account for cert deposits in change calculation

> Patch handoff. Building a tx that contains a stake-registration (or any other deposit-bearing) cert produces unbalanced change — `auto-change = totInputValue − requiredOutputValue − fee` ignores the deposit. The ledger rejects at phase-1 with `valueNotConservedUTxO`, valueProduced exceeding valueConsumed by exactly the deposit amount.

## Pre-flight: requires `cardano-ledger-ts ≥ 0.5.4`

This patch's `import { ConwayCertRegistrationDeposit, … } from "@harmoniclabs/cardano-ledger-ts"` block compiles but evaluates to `undefined` at runtime against `0.5.3` — every `instanceof Conway*` would throw `Right-hand side of instanceof is not callable`. The `Conway*`-prefixed cert classes are not reachable from the top-level barrel.

**Don't try to "just uncomment `export * from "./governance"`" in `src/eras/conway/index.ts`.** That triggers ~50 `TS2308` ambiguous-name errors because there's a top-level `src/governance/` already exporting `Anchor` / `DRep` / `Vote` / `GovAction` / `VotingProcedure` / etc. (which is also why that line was commented out in the first place — commit `e03b246` "fixing tests").

The fix is a **named re-export of only the Conway cert classes** in `src/eras/conway/index.ts`. Full handoff brief at [`cardano-ledger-ts/CONWAY_CERTS_BARREL_EXPORT_FIX.md`](../cardano-ledger-ts/CONWAY_CERTS_BARREL_EXPORT_FIX.md). Apply that first, bump to `0.5.4`, re-pack, then bump this repo's `cardano-ledger-ts` dep to the new tarball.

Verification once consumed:

```js
require("@harmoniclabs/cardano-ledger-ts").ConwayCertRegistrationDeposit  // → function
require("@harmoniclabs/cardano-ledger-ts").ConwayCertUnRegistrationDeposit // → function
// (… and every other Conway-prefixed cert class used below)
```

(Workaround if you really can't bump cardano-ledger-ts right now: deep-import from `"@harmoniclabs/cardano-ledger-ts/dist/eras/conway/governance/certs"`. Works today but brittle to dist-layout changes — strongly not recommended.)

## TL;DR

`TxBuilder._initBuild` walks `outputs` to compute `requiredOutputValue` (sum of declared output values) but does **not** walk `certificates` to fold registration deposits into that total — nor does it fold de-registration refunds into `totInputValue`. Auto-change is therefore short by the deposit amount on every cert-bearing tx.

This must be fixed at the buildooor level — there is no clean consumer-side workaround for cert + script combos. Any consumer trick (lying about input lovelace, mutating the change output post-`buildSync`) causes the Plutus ScriptContext bytes to differ between buildooor's off-chain script evaluation and the chain's re-evaluation. exec_units diverge → `"Invalid transaction submitted as valid"` ("transaction failed unexpectedly"). Empirically reproduced; that's why this PR exists rather than papering it over downstream.

Fix is contained to `_initBuild` plus a small `ValidatedTxBuilderProtocolParams` typing widen.

## Symptom

```ts
import { TxBuilder } from "@harmoniclabs/buildooor";
import { CertRegistrationDeposit, Credential } from "@harmoniclabs/cardano-ledger-ts";

const cert = new CertRegistrationDeposit({ stakeCredential, deposit: 2_000_000n });

const tx = txBuilder.buildSync({
    inputs,
    certificates: [{ cert, script }],
    changeAddress,
    requiredSigners,
});

// Submission fails phase-1:
//   valueConsumed.ada.lovelace: X
//   valueProduced.ada.lovelace: X + 2_000_000   ← exactly the deposit
//   "In and out value not conserved"
```

The same imbalance triggers for `CertStakeRegistration` (deposit implicit via `protocolParameters.stakeAddressDeposit`), `ConwayCertStakeRegistrationDeleg`, `ConwayCertVoteRegistrationDeleg`, `ConwayCertStakeVoteRegistrationDeleg`, `ConwayCertRegistrationDrep`, and the symmetric refund cases (`CertStakeDeRegistration`, `ConwayCertUnRegistrationDeposit`, `ConwayCertUnRegistrationDrep`) — all of which the chain factors into the value-conservation check but `TxBuilder._initBuild` ignores.

## Reproducer

Runnable repro using the same shape as `gravity-sdk/src/GravityAccount/GravityAccount.ts:registerAccountStake`:

```js
const { TxBuilder, defaultPreprodGenesisInfos } = require("@harmoniclabs/buildooor");
const {
    CertRegistrationDeposit, Credential, Hash28, DataI, Tx, TxOut, UTxO, Value,
} = require("@harmoniclabs/cardano-ledger-ts");

// any preprod protocol params object containing real deposit values
const pp = await provider.getProtocolParameters();
const txBuilder = new TxBuilder( pp, defaultPreprodGenesisInfos );

const stakeCredential = Credential.script( accountScriptHash );
const deposit = pp.stakeAddressDeposit;  // e.g. 2_000_000n on preprod/mainnet
const cert = new CertRegistrationDeposit({ stakeCredential, deposit });

const tx = txBuilder.buildSync({
    inputs: walletInputs.map( utxo => ({ utxo }) ),
    certificates: [{
        cert,
        script: { ref: accountRefUtxo, redeemer: new DataI( 0 ) },
    }],
    changeAddress: walletInputs[0].resolved.address,
    requiredSigners: [ ownerPkh ],
});

// Inspect the auto-change output:
const change = tx.body.outputs.find( o => /* … the auto-change one */ );
// change.value.lovelaces === sumInputLovelaces - tx.body.fee
//   (NOT sumInputLovelaces - fee - deposit). Bug.

// Submitting through CIP-30 fails phase-1 with `valueNotConservedUTxO`,
// produced − consumed === deposit (= 2_000_000n).
```

## Diagnosis

[src/TxBuilder/TxBuilder.ts](src/TxBuilder/TxBuilder.ts) — find `_initBuild`. The accumulator that determines auto-change is at the top of the function:

```ts
const requiredOutputValue = outs.reduce(
    ( acc, out ) => Value.add( acc, out.value ),
    Value.zero
);
```

Auto-change is later computed at `src/TxBuilder/TxBuilder.ts:602` (final balance) and `:1629` (dummy build pass) as:

```ts
value: Value.sub(
    totInputValue,
    Value.add( requiredOutputValue, Value.lovelaces( fee ) )
)
```

Both call sites need to use balanced values (see Fix below). At runtime in the compiled output, these are around `dist/TxBuilder/TxBuilder.js:449` and `:1090`.

`certificates` is consumed for redeemer/script wiring further down, but the cert payload is never inspected for its `deposit`/`refund` field, and `protocolParameters.stakeAddressDeposit` / `.drepDeposit` are not consulted. By the time `_initBuild` walks certs, [src/txBuild/ITxBuildCert.ts:40](src/txBuild/ITxBuildCert.ts#L40)'s `normalizeITxBuildCert` has already routed each cert through `certificateFromCertificateLike`, so all certs are eras-flavoured class instances — Conway-prefixed for cert types that have a Conway variant, eras un-prefixed otherwise.

Result: the ledger applies the deposit on the OUT side of the value-conservation equation, but the SDK never compensates. Off by `deposit` exactly.

## Fix

Walk `certificates` once in `_initBuild` (after `normalizeITxBuildCert` runs, so the cert classes are already eras-flavoured) and accumulate the net deposit/refund effect.

```ts
let totRegistrationDeposit = 0n;
let totRefundedDeposit = 0n;
const pp = this.protocolParamters;

const ensure = ( name: string, v: bigint | number | undefined ): bigint => {
    if( v === undefined ) throw new Error(
        `missing protocolParamters.${name}; required to balance cert-bearing tx`
    );
    return BigInt( v );
};

for( const { cert } of (certificates ?? []) )
{
    // Conway-era certs carry the deposit/refund explicitly on the cert payload.
    if(
        cert instanceof ConwayCertRegistrationDeposit
        || cert instanceof ConwayCertStakeRegistrationDeleg
        || cert instanceof ConwayCertVoteRegistrationDeleg
        || cert instanceof ConwayCertStakeVoteRegistrationDeleg
    ) {
        totRegistrationDeposit += BigInt( cert.deposit );
        continue;
    }
    if( cert instanceof ConwayCertUnRegistrationDeposit ) {
        totRefundedDeposit += BigInt( cert.refund ?? cert.deposit );
        continue;
    }
    if( cert instanceof ConwayCertRegistrationDrep ) {
        totRegistrationDeposit += BigInt( cert.deposit );
        continue;
    }
    if( cert instanceof ConwayCertUnRegistrationDrep ) {
        totRefundedDeposit += BigInt( cert.refund ?? cert.deposit );
        continue;
    }
    // Pre-Conway types use protocol-param defaults.
    if( cert instanceof CertStakeRegistration ) {
        totRegistrationDeposit += ensure( "stakeAddressDeposit", pp.stakeAddressDeposit );
        continue;
    }
    if( cert instanceof CertStakeDeRegistration ) {
        totRefundedDeposit += ensure( "stakeAddressDeposit", pp.stakeAddressDeposit );
        continue;
    }
    // CertPoolRegistration, CertPoolRetirement: out of scope (see "Out of scope" below).
}

// Fold the totals into the change calc:
const requiredOutputValue = outs.reduce(
    ( acc, out ) => Value.add( acc, out.value ),
    Value.zero
);
const balancedRequiredOutputValue =
    Value.add( requiredOutputValue, Value.lovelaces( totRegistrationDeposit ) );
const balancedTotInputValue =
    Value.add( totInputValue, Value.lovelaces( totRefundedDeposit ) );
```

Then in the change-output computation at `:602` and `:1629` of `src/TxBuilder/TxBuilder.ts`, swap `requiredOutputValue` → `balancedRequiredOutputValue` and `totInputValue` → `balancedTotInputValue`.

Run `npm run build` after editing source to regenerate `dist/`. Don't manually edit `dist/TxBuilder/TxBuilder.js` — it drifts from source on the next build and bites later.

### Imports

Add to the existing import block at the top of `src/TxBuilder/TxBuilder.ts`:

```ts
import {
    // ... existing imports …
    CertStakeRegistration,
    CertStakeDeRegistration,
    ConwayCertRegistrationDeposit,
    ConwayCertUnRegistrationDeposit,
    ConwayCertStakeRegistrationDeleg,
    ConwayCertVoteRegistrationDeleg,
    ConwayCertStakeVoteRegistrationDeleg,
    ConwayCertRegistrationDrep,
    ConwayCertUnRegistrationDrep,
} from "@harmoniclabs/cardano-ledger-ts";
```

These resolve cleanly only **after** the `cardano-ledger-ts ≥ 0.5.4` pre-flight has been applied. The deposit/refund fields on the Conway cert classes are publicly typed — no `as any` cast needed.

### `protocolParameters` typing

`this.protocolParamters` is currently the stripped fee/budget view — it doesn't include `stakeAddressDeposit` / `drepDeposit`. Widen `ValidatedTxBuilderProtocolParams` (or whichever interface the TxBuilder constructor accepts) to expose them. They're already on the full `ProtocolParameters` from `cardano-ledger-ts`; just propagate.

The `ensure()` helper above hard-throws if a deposit param is missing. **Don't** ship hardcoded mainnet defaults (`?? 2_000_000n`) — that silently produces wrong txs on testnets / custom devnets where deposits differ, with confusing submit-time errors.

## Out of scope

- `CertPoolRegistration` / `CertPoolRetirement` are intentionally not handled here. Pool deposit (~500 ADA) is paid only on FIRST registration; subsequent `CertPoolRegistration` certs (parameter updates: cost, margin, owners) re-use the same cert type but don't pay it again. `_initBuild` can't disambiguate without on-chain state. Pool-cert flows are caller-responsibility today; if first-class support is wanted, add a `poolIsAlreadyRegistered?: boolean` flag to `ITxBuildCert` and gate the deposit on it. Separate ticket.
- `ConwayMoveInstantRewardsCert` — pre-Conway-style MIR cert variant. No deposit, no refund, no balance impact.

## Verify after fix

Pack `buildooor`, install in a consumer (e.g. `gravity-sdk`), run the `registerAccountStake` flow that's been failing. Expected: tx submits, ~2 ADA deposit deducted from wallet, `GET /accounts/{stake_test1...}` returns 200 with `active: true`.

Add a regression test with the reproducer above so future cert-balance regressions get caught — somewhere under `src/__tests__/` mirroring the existing `TxBuilder.build.*.test.ts` files. Cover both registration (deposit out) and de-registration (refund in) balance.

## Don't

- **Don't pull deposit from `this.protocolParamters` for Conway-era certs that carry the deposit on their own payload** (`ConwayCertRegistrationDeposit` etc.). Read it from `cert.deposit` directly — the cert is the source of truth for those types.
- **Don't forget the symmetric refund path** (`CertStakeDeRegistration`, `ConwayCertUnRegistrationDeposit`, `ConwayCertUnRegistrationDrep`). These move lovelace into the IN side. If only registration is handled, de-registration txs will be off-by-deposit in the other direction.
- **Don't break the dummy-build pass** (`src/TxBuilder/TxBuilder.ts:1629`). The change calc happens twice and both call sites need the new `balanced*` values.
- **Don't ship `?? <mainnet_default>` fallbacks for missing deposit params.** Hard-throw instead. Silent defaults produce wrong txs on testnets and the failure surfaces only at submit time.
- **Don't manually patch `dist/`.** Always go through `npm run build`. Manual dist edits drift from source on the next compile.

## Once this lands

The consumer `gravity-sdk/src/GravityAccount/GravityAccount.ts:registerAccountStake` is already in clean shape — no workaround code; passes `userInputs` straight to `buildSync`. After this fix lands and the consumer bumps `@harmoniclabs/buildooor`, the existing call works as-is.

## Files to touch

| File | Action |
|---|---|
| `src/TxBuilder/TxBuilder.ts` (`_initBuild`) | Walk `certificates`, accumulate `totRegistrationDeposit` / `totRefundedDeposit`; fold into `requiredOutputValue` / `totInputValue` at lines 602 and 1629 |
| `src/TxBuilder/protocolParams.ts` (or wherever `ValidatedTxBuilderProtocolParams` lives) | Widen to expose `stakeAddressDeposit` and `drepDeposit` |
| `src/__tests__/TxBuilder.build.cert_deposit.test.ts` (NEW) | Regression test covering registration + de-registration balance |
| `package.json` | Bump version |

Run `npm run build` to regenerate `dist/`. Don't edit `dist/TxBuilder/TxBuilder.js` by hand.
