---
title: sdk/provider/Maestro.ts
nav_order: 156
parent: Modules
---

## Maestro overview

---

<h2 class="text-delta">Table of contents</h2>

- [constructors](#constructors)
  - [MaestroProvider (class)](#maestroprovider-class)
    - [effect (property)](#effect-property)
    - [getProtocolParameters (property)](#getprotocolparameters-property)
    - [getUtxos (property)](#getutxos-property)
    - [getUtxosWithUnit (property)](#getutxoswithunit-property)
    - [getUtxoByUnit (property)](#getutxobyunit-property)
    - [getUtxosByOutRef (property)](#getutxosbyoutref-property)
    - [getDelegation (property)](#getdelegation-property)
    - [getDatum (property)](#getdatum-property)
    - [awaitTx (property)](#awaittx-property)
    - [submitTx (property)](#submittx-property)
    - [evaluateTx (property)](#evaluatetx-property)
  - [mainnet](#mainnet)
  - [preprod](#preprod)
  - [preview](#preview)

---

# constructors

## MaestroProvider (class)

Maestro provider for Cardano blockchain data access.
Supports mainnet and testnet networks with API key authentication.
Features cursor-based pagination and optional turbo submit for faster transaction processing.
Implements rate limiting to respect Maestro API limits.

**Signature**

```ts
export declare class MaestroProvider { constructor(
    private readonly baseUrl: string,
    private readonly apiKey: string,
    private readonly turboSubmit: boolean = false
  ) }
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

### submitTx (property)

**Signature**

```ts
submitTx: (cbor: Parameters<Provider["submitTx"]>[0]) => Promise<TransactionHash>
```

### evaluateTx (property)

**Signature**

```ts
evaluateTx: (tx: Parameters<Provider["evaluateTx"]>[0], additionalUTxOs?: Parameters<Provider["evaluateTx"]>[1]) =>
  Promise<EvalRedeemer[]>
```

## mainnet

Pre-configured Maestro provider for Cardano mainnet.

**Signature**

```ts
export declare const mainnet: (apiKey: string, turboSubmit?: boolean) => MaestroProvider
```

Added in v2.0.0

## preprod

Pre-configured Maestro provider for Cardano preprod testnet.

**Signature**

```ts
export declare const preprod: (apiKey: string, turboSubmit?: boolean) => MaestroProvider
```

Added in v2.0.0

## preview

Pre-configured Maestro provider for Cardano preview testnet.

**Signature**

```ts
export declare const preview: (apiKey: string, turboSubmit?: boolean) => MaestroProvider
```

Added in v2.0.0
