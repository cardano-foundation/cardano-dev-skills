# Metadata

Auxiliary data is set with Shelley-style metadata maps (label → value):

```go
builder = builder.SetShelleyMetadata(map[uint64]any{
    674: map[string]any{"msg": []any{"hello"}},
})

builder, err = builder.SetShelleyMetadataFromJSON(jsonBytes)
builder, err = builder.SetShelleyMetadataFromJSONWithSchema(jsonBytes, apollo.MetadataJSONDetailedSchema)
```

JSON mappings match cardano-cli:

| Schema | Constant | CLI flag |
|--------|----------|----------|
| No schema (default) | `MetadataJSONNoSchema` | `--metadata-json-file` |
| Detailed schema | `MetadataJSONDetailedSchema` | tagged int/bytes/string/list/map |

Top-level JSON must be an object whose keys are metadata labels. Integers are
bounded to `[-(2^64-1), 2^64-1]`. Strings in no-schema metadata are at most 64
bytes. `MetadataMap` preserves non-string keys (including bytes).

v2 had a bug where metadata never reached the chain: `buildMetadata` returned
a map without storing encoding, and gouroboros serializes auxiliary data from
stored CBOR, so every metadata transaction emitted `auxiliary_data = f6` while
the body committed to a real hash. That is fixed; do not work around it.
