# Dummy Substandard

The dummy substandard is a minimal implementation for testing. It has no compliance features — transfers always succeed.

## Capabilities

| Operation | Status |
|-----------|--------|
| Transfer | Implemented |
| Register | Not implemented |
| Mint | Not implemented |
| Burn | Not implemented |
| Freeze/Unfreeze/Seize | Not supported |

## Setup

```typescript
import { dummySubstandard } from "@easy1staking/cip113-sdk-ts/dummy";

const dummy = dummySubstandard({ blueprint: dummyBlueprint });

const protocol = CIP113.init({
  client,
  standard: { blueprint: standardBlueprint, deployment },
  substandards: [dummy],
});
```

## Transfer

```typescript
const result = await protocol.transfer({
  senderAddress: "addr_test1...",
  recipientAddress: "addr_test1...",
  tokenPolicyId: "abcd...",
  assetName: "hex_asset_name",
  quantity: 10n,
});
```

The dummy transfer uses redeemer value 200 and does not check any blacklist.

In 0.5.0-alpha.4, `transfer` neither mints nor burns and needs no `issuance_logic`
withdrawal. The dummy substandard does not implement register, mint, or burn.

## Validators

| Validator | Redeemer | Purpose |
|-----------|----------|---------|
| `transfer.issue.withdraw` | 100 | Issue authorization |
| `transfer.transfer.withdraw` | 200 | Transfer authorization |

## Example

See [examples/dummy/](../../examples/dummy/) for runnable scripts.
