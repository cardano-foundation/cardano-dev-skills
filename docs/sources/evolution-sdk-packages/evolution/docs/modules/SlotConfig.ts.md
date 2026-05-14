---
title: SlotConfig.ts
nav_order: 164
parent: Modules
---

## SlotConfig overview

---

<h2 class="text-delta">Table of contents</h2>

- [Time](#time)
  - [SLOT_CONFIG_NETWORK](#slot_config_network)
  - [SlotConfig (interface)](#slotconfig-interface)
  - [getSlotConfig](#getslotconfig)

---

# Time

## SLOT_CONFIG_NETWORK

Network-specific slot configurations for all Cardano networks.

- **Mainnet**: Production network starting at Shelley era
- **Preview**: Preview testnet for protocol updates
- **Preprod**: Pre-production testnet
- **Custom**: Customizable for emulator/devnet (initialized with zeros)

**Signature**

```ts
export declare const SLOT_CONFIG_NETWORK: Record<"Mainnet" | "Preview" | "Preprod" | "Custom", SlotConfig>
```

Added in v2.0.0

## SlotConfig (interface)

Slot configuration for a Cardano network.
Defines the relationship between slots and Unix time.

**Signature**

```ts
export interface SlotConfig {
  /**
   * Unix timestamp (in milliseconds) of the network start (Shelley era).
   */
  readonly zeroTime: bigint

  /**
   * First slot number of the Shelley era.
   */
  readonly zeroSlot: bigint

  /**
   * Duration of each slot in milliseconds (typically 1000ms = 1 second).
   */
  readonly slotLength: number
}
```

Added in v2.0.0

## getSlotConfig

Get slot configuration for a network.

**Signature**

```ts
export declare const getSlotConfig: (network: Network.Network) => SlotConfig
```

Added in v2.0.0
