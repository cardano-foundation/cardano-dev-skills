package constants

// Tunable safety limits for blueprint parsing and Plutus data decoding.
// Change these values here when a deployment needs a different bound.
const (
	// MaxBlueprintBytes is the largest plutus.json document Parse and
	// ParseFile will accept.
	MaxBlueprintBytes = 16 << 20

	// MaxPlutusDataDepth is the deepest Plutus data tree encode, decode, and
	// validation will walk. It matches plutigo's flat decoder limit
	// (maxFlatDecodeDepth). The ledger does not impose a smaller cap. A value
	// nested past this limit is rejected instead of overflowing the stack.
	MaxPlutusDataDepth = 100_000

	// MaxContainerPrealloc is the largest initial slice or map capacity used
	// when decoding or unmarshaling untrusted Plutus data. Larger containers
	// grow as elements pass validation.
	MaxContainerPrealloc = 1024
)
