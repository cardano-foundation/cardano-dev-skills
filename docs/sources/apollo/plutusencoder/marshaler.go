package plutusencoder

import "github.com/blinklabs-io/plutigo/data"

// PlutusMarshaler is the interface for custom plutus data encoding/decoding.
type PlutusMarshaler interface {
	ToPlutusData() (data.PlutusData, error)
	FromPlutusData(pd data.PlutusData, res any) error
}
