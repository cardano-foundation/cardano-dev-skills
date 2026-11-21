package plutusencoder

import (
	"errors"
	"fmt"
	"math"
	"math/big"

	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/plutigo/data"
)

// TxOutRef is a Plutus V3 transaction output reference: constructor 0 of a
// 32-byte transaction id and a zero-based output index. Plutus V1 and V2 wrap
// the id again, as constructor 0 of [constructor 0 [txId], index]. A datum
// built for a V1 or V2 validator encodes, then fails on chain.
type TxOutRef struct {
	TxId  []byte
	Index uint32
}

// AssetClass is a Plutus asset class: a policy id and a token name, encoded as
// constructor 0 of those two byte strings. A zero-length policy id and token
// name represent lovelace.
type AssetClass struct {
	PolicyId  []byte
	TokenName []byte
}

func marshalCredential(cred common.Credential) (data.PlutusData, error) {
	switch cred.CredType {
	case common.CredentialTypeAddrKeyHash, common.CredentialTypeScriptHash:
		// Blake2b224 is a fixed array, so the zero value is 28 zero bytes.
		// That is a real hash, and Credential.ToPlutusData encodes it.
		hashLen := len(cred.Credential.Bytes())
		if hashLen != common.Blake2b224Size {
			return nil, fmt.Errorf("expected %d-byte credential hash, got %d", common.Blake2b224Size, hashLen)
		}
		return cred.ToPlutusData(), nil
	default:
		return nil, fmt.Errorf("unsupported credential type %d", cred.CredType)
	}
}

func unmarshalCredential(pd data.PlutusData) (common.Credential, error) {
	constr, ok := pd.(*data.Constr)
	if !ok || constr == nil || len(constr.Fields) != 1 || (!constrTagEqual(constr.Tag, 0) && !constrTagEqual(constr.Tag, 1)) {
		return common.Credential{}, wrongConstrShape("credential constructor 0 or 1 with 1 field", pd)
	}
	raw, ok := constr.Fields[0].(*data.ByteString)
	if !ok || plutusNil(raw) || len(raw.Inner) != common.Blake2b224Size {
		return common.Credential{}, fmt.Errorf("expected %d-byte credential hash", common.Blake2b224Size)
	}
	hash, err := common.NewBlake2b224Checked(raw.Inner)
	if err != nil {
		return common.Credential{}, err
	}
	if constrTagEqual(constr.Tag, 0) {
		return common.Credential{
			CredType:   common.CredentialTypeAddrKeyHash,
			Credential: hash,
		}, nil
	}
	return common.Credential{
		CredType:   common.CredentialTypeScriptHash,
		Credential: hash,
	}, nil
}

func marshalTxOutRef(ref TxOutRef) (data.PlutusData, error) {
	if len(ref.TxId) != common.Blake2b256Size {
		return nil, fmt.Errorf("expected %d-byte transaction id, got %d", common.Blake2b256Size, len(ref.TxId))
	}
	txId := append([]byte(nil), ref.TxId...)
	return data.NewConstr(
		0,
		data.NewByteString(txId),
		data.NewInteger(big.NewInt(int64(ref.Index))),
	), nil
}

func unmarshalTxOutRef(pd data.PlutusData) (TxOutRef, error) {
	constr, ok := pd.(*data.Constr)
	if !ok || constr == nil || !constrTagEqual(constr.Tag, 0) || len(constr.Fields) != 2 {
		return TxOutRef{}, wrongConstrShape("TxOutRef constructor 0 with 2 fields", pd)
	}
	rawId, ok := constr.Fields[0].(*data.ByteString)
	if !ok || plutusNil(rawId) || len(rawId.Inner) != common.Blake2b256Size {
		return TxOutRef{}, fmt.Errorf("expected %d-byte transaction id", common.Blake2b256Size)
	}
	idxInt, ok := constr.Fields[1].(*data.Integer)
	if !ok || plutusNil(idxInt) || idxInt.Inner == nil || idxInt.Inner.Sign() < 0 || !idxInt.Inner.IsUint64() {
		return TxOutRef{}, errors.New("expected unsigned output index")
	}
	idx := idxInt.Inner.Uint64()
	if idx > math.MaxUint32 {
		return TxOutRef{}, fmt.Errorf("output index %d overflows uint32", idx)
	}
	return TxOutRef{
		TxId:  append([]byte(nil), rawId.Inner...),
		Index: uint32(idx),
	}, nil
}

const maxTokenNameSize = 32

func marshalAssetClass(asset AssetClass) (data.PlutusData, error) {
	if len(asset.PolicyId) != 0 && len(asset.PolicyId) != common.Blake2b224Size {
		return nil, fmt.Errorf("expected empty or %d-byte policy id, got %d", common.Blake2b224Size, len(asset.PolicyId))
	}
	if len(asset.TokenName) > maxTokenNameSize {
		return nil, fmt.Errorf("token name exceeds %d bytes: got %d", maxTokenNameSize, len(asset.TokenName))
	}
	if len(asset.PolicyId) == 0 && len(asset.TokenName) != 0 {
		return nil, errors.New("lovelace policy id requires an empty token name")
	}
	return data.NewConstr(
		0,
		data.NewByteString(append([]byte(nil), asset.PolicyId...)),
		data.NewByteString(append([]byte(nil), asset.TokenName...)),
	), nil
}

func unmarshalAssetClass(pd data.PlutusData) (AssetClass, error) {
	constr, ok := pd.(*data.Constr)
	if !ok || constr == nil || !constrTagEqual(constr.Tag, 0) || len(constr.Fields) != 2 {
		return AssetClass{}, wrongConstrShape("AssetClass constructor 0 with 2 fields", pd)
	}
	policy, ok := constr.Fields[0].(*data.ByteString)
	if !ok || plutusNil(policy) || (len(policy.Inner) != 0 && len(policy.Inner) != common.Blake2b224Size) {
		return AssetClass{}, fmt.Errorf("expected empty or %d-byte policy id", common.Blake2b224Size)
	}
	token, ok := constr.Fields[1].(*data.ByteString)
	if !ok || plutusNil(token) || len(token.Inner) > maxTokenNameSize {
		return AssetClass{}, fmt.Errorf("expected token name of at most %d bytes", maxTokenNameSize)
	}
	if len(policy.Inner) == 0 && len(token.Inner) != 0 {
		return AssetClass{}, errors.New("lovelace policy id requires an empty token name")
	}
	return AssetClass{
		PolicyId:  append([]byte(nil), policy.Inner...),
		TokenName: append([]byte(nil), token.Inner...),
	}, nil
}

// wrongConstrShape reports a product that is not the expected constructor.
// A real constructor names its tag and field count. Any other Plutus value
// keeps the concrete type, because there is no tag or width to report.
func wrongConstrShape(expect string, pd data.PlutusData) error {
	constr, ok := pd.(*data.Constr)
	if !ok || constr == nil {
		return fmt.Errorf("expected %s, got %T", expect, pd)
	}
	return fmt.Errorf("expected %s, got constructor %s with %d fields", expect, constr.Tag, len(constr.Fields))
}
