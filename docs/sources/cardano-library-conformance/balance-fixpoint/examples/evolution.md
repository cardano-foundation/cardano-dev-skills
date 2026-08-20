# Evolution SDK reusable outer loop

This complete Evolution SDK 0.5.12 example exposes `balanceWith`, which accepts the builder provider, offline provider handles, a fee-dependent `computeOutputs` callback, and a caller-owned bound. `runExample` wires the defaults and preserves the distinct `NonConvergent` error.

## Complete source


```typescript
import * as Assets from "@evolution-sdk/evolution/Assets";
import type * as Address from "@evolution-sdk/evolution/Address";
import type * as UTxO from "@evolution-sdk/evolution/UTxO";
import {
  makeTxBuilder,
  type BuildOptions,
  type TxBuilderConfig,
} from "@evolution-sdk/evolution/sdk/builders/TransactionBuilder";

const INPUT = 5_000_000n;
const TIP = 1_000_000n;
const MAX_PASSES = 8;

export class NonConvergent extends Error {
  constructor(readonly bound: number) {
    super(`fee did not converge in ${bound} passes`);
  }
}

export interface OfflineFixture {
  readonly config: TxBuilderConfig & { readonly wallet?: undefined };
  readonly address: Address.Address;
  readonly utxos: readonly [UTxO.UTxO];
  readonly buildOptions: BuildOptions;
}

export type BuilderProvider = typeof makeTxBuilder;

export interface ComputedOutputs {
  readonly refund: bigint;
}

export type ComputeOutputs = (feeGuess: bigint) => ComputedOutputs;

export async function balanceWith(
  builderProvider: BuilderProvider,
  fixture: OfflineFixture,
  computeOutputs: ComputeOutputs,
  bound: number,
): Promise<{ fee: bigint; refund: bigint; passes: number }> {
  let feeGuess = 0n;
  for (let pass = 1; pass <= bound; pass += 1) {
    const { refund } = computeOutputs(feeGuess);
    if (refund < 0n) throw new Error("fee exceeds fixture input");

    // The operation list and its fresh build state are recreated for every candidate.
    const result = await builderProvider(fixture.config)
      .collectFrom({ inputs: fixture.utxos })
      .payToAddress({
        address: fixture.address,
        assets: Assets.fromLovelace(refund),
      })
      .build({
        ...fixture.buildOptions,
        availableUtxos: fixture.utxos,
        changeAddress: fixture.address,
      });
    const required = await result.estimateFee();
    const tx = await result.toTransaction();
    if (required === feeGuess) {
      if (!tx) throw new Error("builder did not expose the converged transaction");
      if (INPUT !== refund + required + TIP) {
        throw new Error("lovelace is not conserved");
      }
      return { fee: required, refund, passes: pass };
    }
    feeGuess = required;
  }
  throw new NonConvergent(bound);
}

export function feeDependentOutputs(feeGuess: bigint): ComputedOutputs {
  return { refund: INPUT - TIP - feeGuess };
}

export function runExample(
  fixture: OfflineFixture,
  bound = MAX_PASSES,
): Promise<{ fee: bigint; refund: bigint; passes: number }> {
  return balanceWith(makeTxBuilder, fixture, feeDependentOutputs, bound);
}
```


## Run or check

```sh
nix build .#checks.x86_64-linux.example-evolution-outer-loop
```
