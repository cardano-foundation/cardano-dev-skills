package backend

import (
	"errors"
	"fmt"

	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/common"
)

// VerifySubmittedTxID checks that a provider's reported ID names the exact
// transaction body supplied for submission.
func VerifySubmittedTxID(txCbor []byte, reported common.Blake2b256) error {
	want, err := submittedTxID(txCbor)
	if err != nil {
		return err
	}
	return verifySubmittedTxID(want, reported)
}

func submittedTxID(txCbor []byte) (common.Blake2b256, error) {
	var elements []cbor.RawMessage
	if _, err := cbor.DecodeExact(txCbor, &elements); err != nil {
		return common.Blake2b256{}, fmt.Errorf("decode submitted transaction: %w", err)
	}
	if len(elements) == 0 || len(elements[0]) == 0 {
		return common.Blake2b256{}, errors.New("submitted transaction has no body")
	}
	return common.Blake2b256Hash(elements[0]), nil
}

func verifySubmittedTxID(want, reported common.Blake2b256) error {
	if reported != want {
		return fmt.Errorf("provider transaction ID %s does not match submitted body %s", reported, want)
	}
	return nil
}
