---
title: sdk/provider/Kupmios.ts
nav_order: 155
parent: Modules
---

## Kupmios overview

---

<h2 class="text-delta">Table of contents</h2>

- [constructors](#constructors)
  - [KupmiosProvider (class)](#kupmiosprovider-class)
    - [effect (property)](#effect-property)
    - [getProtocolParameters (property)](#getprotocolparameters-property)
    - [getUtxos (property)](#getutxos-property)
    - [getUtxosWithUnit (property)](#getutxoswithunit-property)
    - [getUtxoByUnit (property)](#getutxobyunit-property)
    - [getUtxosByOutRef (property)](#getutxosbyoutref-property)
    - [getDelegation (property)](#getdelegation-property)
    - [getDatum (property)](#getdatum-property)
    - [awaitTx (property)](#awaittx-property)
    - [evaluateTx (property)](#evaluatetx-property)
    - [submitTx (property)](#submittx-property)

---

# constructors

## KupmiosProvider (class)

Kupmios provider for Cardano blockchain data access.
Provides support for interacting with both Kupo and Ogmios APIs.
Supports custom headers for authentication with Demeter or other providers.

**Signature**

```ts
export declare class KupmiosProvider {
  constructor(
    kupoUrl: string,
    ogmiosUrl: string,
    headers?: {
      ogmiosHeader?: Record<string, string>
      kupoHeader?: Record<string, string>
    }
  )
}
```

Added in v2.0.0

### effect (property)

**Signature**

```ts
readonly effect: ProviderEffect
```

### getProtocolParameters (property)

**Signature**

```ts
getProtocolParameters: () => Promise<ProtocolParameters>
```

### getUtxos (property)

**Signature**

```ts
getUtxos: (addressOrCredential: Parameters<Provider["getUtxos"]>[0]) => Promise<UTxO[]>
```

### getUtxosWithUnit (property)

**Signature**

```ts
getUtxosWithUnit: (
  addressOrCredential: Parameters<Provider["getUtxosWithUnit"]>[0],
  unit: Parameters<Provider["getUtxosWithUnit"]>[1]
) => Promise<UTxO[]>
```

### getUtxoByUnit (property)

**Signature**

```ts
getUtxoByUnit: (unit: Parameters<Provider["getUtxoByUnit"]>[0]) => Promise<UTxO>
```

### getUtxosByOutRef (property)

**Signature**

```ts
getUtxosByOutRef: (outRefs: Parameters<Provider["getUtxosByOutRef"]>[0]) => Promise<UTxO[]>
```

### getDelegation (property)

**Signature**

```ts
getDelegation: (rewardAddress: Parameters<Provider["getDelegation"]>[0]) => Promise<Delegation>
```

### getDatum (property)

**Signature**

```ts
getDatum: (datumHash: Parameters<Provider["getDatum"]>[0]) => Promise<Data>
```

### awaitTx (property)

**Signature**

```ts
awaitTx: (
  txHash: Parameters<Provider["awaitTx"]>[0],
  checkInterval?: Parameters<Provider["awaitTx"]>[1],
  timeout?: Parameters<Provider["awaitTx"]>[2]
) => Promise<boolean>
```

### evaluateTx (property)

**Signature**

```ts
evaluateTx: (tx: Parameters<Provider["evaluateTx"]>[0], additionalUTxOs?: Parameters<Provider["evaluateTx"]>[1]) =>
  Promise<EvalRedeemer[]>
```

### submitTx (property)

**Signature**

```ts
submitTx: (tx: Parameters<Provider["submitTx"]>[0]) => Promise<TransactionHash>
```
