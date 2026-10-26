package apollo

import (
	"bytes"
	"errors"
	"fmt"
	"reflect"

	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/plutigo/data"
	"github.com/blinklabs-io/plutigo/syn"
)

// ApplyParamsToScript applies Plutus data parameters to a parameterized
// Plutus script and returns the resulting script.
//
// The script must be in the form used by gouroboros Plutus script types and
// by the compiledCode field of Aiken blueprints: a CBOR byte string wrapping
// the flat-encoded UPLC program. Each parameter is applied in order as a
// data constant, so ApplyParamsToScript(s, a, b) yields the program [[s a] b].
// Applying parameters one call at a time gives the same result as applying
// them together. The returned script has a new script hash.
//
// The input script is not modified. With no parameters, the script is still
// validated and a copy of it is returned.
func ApplyParamsToScript[
	S common.PlutusV1Script | common.PlutusV2Script | common.PlutusV3Script,
](script S, params ...data.PlutusData) (S, error) {
	var inner []byte
	bytesRead, err := cbor.Decode([]byte(script), &inner)
	if err != nil {
		return nil, fmt.Errorf("decode script CBOR: %w", err)
	}
	if bytesRead != len(script) {
		return nil, fmt.Errorf(
			"decode script CBOR: %d trailing bytes",
			len(script)-bytesRead,
		)
	}
	program, err := syn.Decode[syn.DeBruijn](inner)
	if err != nil {
		return nil, fmt.Errorf("decode script program: %w", err)
	}
	if len(params) == 0 {
		return S(bytes.Clone(script)), nil
	}

	term := program.Term
	for i, param := range params {
		if err := validateScriptParam(param); err != nil {
			return nil, fmt.Errorf("parameter %d %w", i, err)
		}
		term = &syn.Apply[syn.DeBruijn]{
			Function: term,
			Argument: &syn.Constant{Con: &syn.Data{Inner: param}},
		}
	}
	program.Term = term

	flat, err := syn.Encode(program)
	if err != nil {
		return nil, fmt.Errorf("encode script program: %w", err)
	}
	wrapped, err := cbor.Encode(flat)
	if err != nil {
		return nil, fmt.Errorf("encode script CBOR: %w", err)
	}
	return S(wrapped), nil
}

// validateScriptParam rejects nil parameters and parameters whose CBOR
// encoding is not valid Plutus data, such as a list holding a typed nil.
func validateScriptParam(param data.PlutusData) error {
	if param == nil {
		return errors.New("is nil")
	}
	if v := reflect.ValueOf(param); v.Kind() == reflect.Pointer && v.IsNil() {
		return errors.New("is nil")
	}
	encoded, err := data.Encode(param)
	if err != nil {
		return fmt.Errorf("cannot be encoded: %w", err)
	}
	if _, err := data.Decode(encoded); err != nil {
		return fmt.Errorf("is not valid Plutus data: %w", err)
	}
	return nil
}
