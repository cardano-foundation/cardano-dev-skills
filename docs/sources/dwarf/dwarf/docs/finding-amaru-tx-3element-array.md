# Amaru accepts 3‑element (non‑canonical) Conway transactions that cardano‑node rejects at decode

**Component:** `amaru` transaction CBOR decoder (submit‑API / mempool ingress)
**Type:** CBOR decode conformance divergence vs. the Haskell reference node (non‑canonical encoding / transaction malleability)
**Status:** Confirmed at the decode level (root cause identified in source and verified empirically). Mempool‑accept and block‑relay impact are **open** (see *Severity*).
**Found by:** DWARF differential fuzzing — same mutated transaction submitted to Amaru and cardano‑node, comparing decode/accept behaviour.
**Date:** 2026‑07‑22

---

## Summary

A Conway transaction is a **4‑element** CBOR array:

```
transaction = [ transaction_body, transaction_witness_set, bool, auxiliary_data / null ]
```

Amaru’s transaction decoder accepts a **3‑element** array — one that omits the trailing
`auxiliary_data` slot entirely — decoding it as a valid transaction with
`auxiliary_data = None`. The Haskell node (`cardano-node`, via `cardano-submit-api`)
rejects the same bytes at CBOR deserialization.

Because a transaction’s id is the hash of its **body** (element 0) only, the 3‑element and
canonical 4‑element encodings of a null‑auxiliary‑data transaction produce the **same
transaction id**. The same logical transaction therefore has two valid wire encodings in
Amaru but only one in cardano‑node — a non‑canonical‑encoding / malleability divergence.

## Environment

| | |
|---|---|
| Amaru image | `ghcr.io/lambdasistemi/amaru-bootstrap-producer:03d2727b…` (baked testnet_42 store, serve‑only) |
| Reference | `cardano-node` 10.7.1 via `ghcr.io/intersectmbo/cardano-submit-api:10.7.1` |
| Network | testnet_42 (k=5) |
| Endpoint | `POST /api/submit/tx`, `Content-Type: application/cbor` |

## Observed behaviour

Starting from a real, serialized Conway transaction and changing **only** the top‑level CBOR
array header from `0x84` (array‑of‑4) to `0x83` (array‑of‑3):

| Input | cardano‑node | Amaru |
|---|---|---|
| `0x84 …` (canonical, 4 elem) | decodes, rejects at validation | decodes, rejects at validation (same tx id) |
| `0x83 …` (3 elem) | **HTTP 400 — decode error**: `DecoderErrorDeserialiseFailure "Shelley Tx" (DeserialiseFailure … "Size mismatch when decoding Record RecD. Expected 3, but found 4" / "expected list len or indef")` → `TxCmdTxReadError` (no tx id computed) | **decodes** — computes tx id, advances to validation: `failed to prepare transaction <tx_id> for validation` |

Reproducible across multiple distinct base transactions: cardano‑node always fails at decode;
Amaru always decodes and produces a (distinct, per‑input) transaction id.

## Root cause

`crates/amaru-kernel/src/cardano/transaction.rs`:

```rust
#[derive(Debug, Clone, PartialEq, Eq, cbor::Encode, cbor::Decode, serde::Serialize, serde::Deserialize)]
pub struct Transaction {
    #[n(0)] pub body: TransactionBody,
    #[n(1)] pub witnesses: WitnessSet,
    #[n(2)] pub is_expected_valid: bool,
    #[n(3)] pub auxiliary_data: Option<AuxiliaryData>,   // trailing Option
}
```

`crates/amaru/src/submit_api.rs` decodes the request body with
`minicbor::decode::<Transaction>(&body)`.

`minicbor`’s derive encodes this struct as a CBOR **array** and treats a **missing trailing
array element whose field type is `Option<_>` as `None`**. A 3‑element array
`[body, witnesses, is_expected_valid]` therefore decodes successfully with
`auxiliary_data = None`, rather than being rejected for having the wrong arity. The Conway CDDL
requires the 4‑element form (the `auxiliary_data` slot is mandatory and may be `null`), which
is what cardano‑node enforces.

### Mechanism verified empirically

Same base transaction, only the array header varied, submitted to a live Amaru:

| Array header | Amaru response |
|---|---|
| `0x82` (2 elem) | `Invalid CBOR transaction: missing value at index 2 (Transaction::is_expected_valid)` — **rejected** (the required, non‑`Option` `bool` field is enforced) |
| `0x83` (3 elem) | decodes → `failed to prepare transaction 9aa53384…464c83 for validation` |
| `0x84` (4 elem) | decodes → **same** tx id `9aa53384…464c83` |

array(2) failing on the required field while array(3) succeeds confirms the leniency is
specifically the trailing `Option<AuxiliaryData>` being omittable — not a length‑agnostic
decoder — and array(3)/array(4) sharing a tx id confirms the malleability.

## Severity

**Confirmed:** a genuine decode‑conformance divergence. Amaru accepts a transaction encoding the
reference node rejects.

**Open (not yet demonstrated):** In the test environment both nodes ultimately return `400` — the
synthetic seed transaction fails Amaru’s validation for unrelated reasons (it spends no real
UTxO), *not* because of the arity. To grade real‑world impact, on a network where a valid, funded
transaction can be built:

1. **Mempool divergence** — does Amaru’s mempool **accept** (`HTTP 202`) the 3‑element form of an
   otherwise‑valid transaction while cardano‑node rejects it? Nodes would then hold different
   mempool contents for the “same” transaction id.
2. **Block‑relay / chain‑split potential** — when Amaru (as a block producer) includes such a
   transaction, does it re‑serialize canonically or preserve the 3‑element bytes? If preserved, a
   block produced by Amaru would contain a transaction encoding that cardano‑node rejects on block
   validation.

These were not reachable in this setup (the local devnet’s configurator does not expose the
genesis UTxO signing key, so a valid funded transaction could not be built).

## Reproduction

```bash
# 1. Obtain any real serialized Conway transaction (e.g. cardano-cli conway transaction
#    build-raw + sign, then take the envelope's cborHex), as tx.cbor.

# 2. Flip the leading CBOR array header 0x84 -> 0x83:
python3 -c 'b=bytearray(open("tx.cbor","rb").read()); assert b[0]==0x84; b[0]=0x83; open("tx3.cbor","wb").write(bytes(b))'

# 3. Submit the 3-element form to each node:
curl -s -X POST http://<cardano-submit-api>:8090/api/submit/tx \
     -H 'Content-Type: application/cbor' --data-binary @tx3.cbor
# -> 400, DecoderErrorDeserialiseFailure (decode rejected)

curl -s -X POST http://<amaru>:3011/api/submit/tx \
     -H 'Content-Type: application/cbor' --data-binary @tx3.cbor
# -> "failed to prepare transaction <tx_id> for validation" (decoded)
```

## Suggested remediation

Make `Transaction` decoding require the full 4‑element array — reject a transaction whose
top‑level array omits the `auxiliary_data` slot rather than defaulting it to `None`. (The
canonical encoding of a transaction with no auxiliary data uses `null` as element 3, not a
2‑ or 3‑element array.) More broadly, audit other array‑encoded ledger types with trailing
`Option` fields for the same `minicbor` derive behaviour.

## How this was found

DWARF ran a differential: the same fuzzed transaction CBOR is POSTed to both Amaru’s submit‑API
and cardano‑node’s `cardano-submit-api`, and the responses are compared. Because the submit‑API
returns `400` for both “failed to decode” and “decoded but invalid”, the oracle parses the
response body to distinguish **decode failure** from **validation failure**, and asserts that the
two implementations agree on whether the bytes *decode as a transaction*. This divergence was
surfaced by a single‑byte mutation (`0x84`→`0x83`) of a real transaction on the first pass.
