package plutusencoder

import (
	"errors"
	"fmt"
	"math/big"
	"reflect"

	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/plutigo/data"
)

func marshalAddress(addr common.Address) (data.PlutusData, error) {
	switch addr.Type() {
	case common.AddressTypeByron:
		return nil, errors.New("byron address has no Plutus data representation")
	case common.AddressTypeNoneKey, common.AddressTypeNoneScript:
		return marshalRewardAddress(addr)
	}
	if addr.PayloadPayload() == nil {
		return nil, fmt.Errorf("plutus address requires a Shelley payment credential, got type %d", addr.Type())
	}
	encoded := addr.ToPlutusData()
	if encoded == nil {
		return nil, fmt.Errorf("address type %d has no Plutus data representation", addr.Type())
	}
	if constr, ok := encoded.(*data.Constr); ok {
		for _, field := range constr.Fields {
			if field == nil {
				return nil, fmt.Errorf("plutus address requires a Shelley payment credential, got type %d", addr.Type())
			}
		}
	}
	return encoded, nil
}

func marshalRewardAddress(addr common.Address) (data.PlutusData, error) {
	stake := addr.StakingPayload()
	if stake == nil {
		return nil, fmt.Errorf("reward address requires a %d-byte stake hash", common.AddressHashSize)
	}
	var hash []byte
	switch p := stake.(type) {
	case common.AddressPayloadKeyHash:
		hash = p.Hash.Bytes()
	case common.AddressPayloadScriptHash:
		hash = p.Hash.Bytes()
	default:
		return nil, fmt.Errorf("reward address requires a stake key or script hash, got %T", stake)
	}
	if len(hash) != common.AddressHashSize {
		return nil, fmt.Errorf("reward address requires a %d-byte stake hash, got %d", common.AddressHashSize, len(hash))
	}
	encoded := addr.ToPlutusData()
	if encoded == nil {
		return nil, fmt.Errorf("address type %d has no Plutus data representation", addr.Type())
	}
	return encoded, nil
}

func unmarshalAddress(pd data.PlutusData, network byte) (common.Address, error) {
	root, ok := pd.(*data.Constr)
	if !ok || plutusNil(root) {
		return common.Address{}, fmt.Errorf("expected Address constructor, got %T", pd)
	}
	if (constrTagEqual(root.Tag, 0) || constrTagEqual(root.Tag, 1)) && len(root.Fields) == 1 {
		return unmarshalRewardAddress(root, network)
	}
	if !constrTagEqual(root.Tag, 0) || len(root.Fields) != 2 {
		return common.Address{}, fmt.Errorf("expected Address constructor 0 with 2 fields, got constructor %s with %d fields", root.Tag, len(root.Fields))
	}
	payType, payment, err := credentialHash(root.Fields[0])
	if err != nil {
		return common.Address{}, fmt.Errorf("payment credential: %w", err)
	}
	stake, err := stakingReference(root.Fields[1])
	if err != nil {
		return common.Address{}, fmt.Errorf("staking credential: %w", err)
	}

	addrType := paymentAddressType(payType, stake.kind)
	if stake.kind == stakePointer {
		raw := make([]byte, 1, 1+common.AddressHashSize+len(stake.pointer))
		raw[0] = (addrType << 4) | network
		raw = append(raw, payment...)
		raw = append(raw, stake.pointer...)
		addr, err := common.NewAddressFromBytes(raw)
		if err != nil {
			return common.Address{}, err
		}
		if err := common.CheckAddressPointerInRange(addr); err != nil {
			return common.Address{}, err
		}
		return addr, nil
	}
	return common.NewAddressFromParts(addrType, network, payment, stake.hash)
}

func unmarshalRewardAddress(root *data.Constr, network byte) (common.Address, error) {
	raw, ok := root.Fields[0].(*data.ByteString)
	if !ok || plutusNil(raw) || len(raw.Inner) != common.AddressHashSize {
		return common.Address{}, fmt.Errorf("expected %d-byte stake hash, got constructor %s with %d fields", common.AddressHashSize, root.Tag, len(root.Fields))
	}
	var addrType uint8 = common.AddressTypeNoneKey
	if constrTagEqual(root.Tag, 1) {
		addrType = common.AddressTypeNoneScript
	}
	return common.NewAddressFromParts(addrType, network, nil, append([]byte(nil), raw.Inner...))
}

type stakeKind int

const (
	stakeNone stakeKind = iota
	stakeKey
	stakeScript
	stakePointer
)

type stakeRef struct {
	kind    stakeKind
	hash    []byte
	pointer []byte
}

func paymentAddressType(script bool, stake stakeKind) uint8 {
	switch stake {
	case stakeKey:
		if script {
			return common.AddressTypeScriptKey
		}
		return common.AddressTypeKeyKey
	case stakeScript:
		if script {
			return common.AddressTypeScriptScript
		}
		return common.AddressTypeKeyScript
	case stakePointer:
		if script {
			return common.AddressTypeScriptPointer
		}
		return common.AddressTypeKeyPointer
	case stakeNone:
		if script {
			return common.AddressTypeScriptNone
		}
		return common.AddressTypeKeyNone
	default:
		panic(fmt.Sprintf("plutusencoder: unhandled stake kind %d", stake))
	}
}

func credentialHash(pd data.PlutusData) (script bool, hash []byte, err error) {
	cred, ok := pd.(*data.Constr)
	if !ok || plutusNil(cred) {
		return false, nil, fmt.Errorf("expected credential constructor with 1 field, got %T", pd)
	}
	if len(cred.Fields) != 1 {
		return false, nil, fmt.Errorf("expected credential constructor with 1 field, got constructor %s with %d fields", cred.Tag, len(cred.Fields))
	}
	raw, ok := cred.Fields[0].(*data.ByteString)
	if !ok || plutusNil(raw) || len(raw.Inner) != common.AddressHashSize {
		return false, nil, fmt.Errorf("expected %d-byte credential hash", common.AddressHashSize)
	}
	switch {
	case constrTagEqual(cred.Tag, 0):
		return false, append([]byte(nil), raw.Inner...), nil
	case constrTagEqual(cred.Tag, 1):
		return true, append([]byte(nil), raw.Inner...), nil
	default:
		return false, nil, fmt.Errorf("expected credential constructor 0 or 1, got constructor %s with %d fields", cred.Tag, len(cred.Fields))
	}
}

func stakingReference(pd data.PlutusData) (stakeRef, error) {
	maybe, ok := pd.(*data.Constr)
	if !ok || plutusNil(maybe) {
		return stakeRef{}, fmt.Errorf("expected Maybe StakingCredential, got %T", pd)
	}
	if constrTagEqual(maybe.Tag, 1) {
		if len(maybe.Fields) != 0 {
			return stakeRef{}, fmt.Errorf("nothing staking credential must have no fields, got constructor %s with %d fields", maybe.Tag, len(maybe.Fields))
		}
		return stakeRef{kind: stakeNone}, nil
	}
	if !constrTagEqual(maybe.Tag, 0) || len(maybe.Fields) != 1 {
		return stakeRef{}, fmt.Errorf("expected Just StakingCredential, got constructor %s with %d fields", maybe.Tag, len(maybe.Fields))
	}
	staking, ok := maybe.Fields[0].(*data.Constr)
	if !ok || plutusNil(staking) {
		return stakeRef{}, fmt.Errorf("expected StakingCredential constructor, got %T", maybe.Fields[0])
	}
	switch {
	case constrTagEqual(staking.Tag, 0) && len(staking.Fields) == 1:
		script, hash, err := credentialHash(staking.Fields[0])
		if err != nil {
			return stakeRef{}, err
		}
		kind := stakeKey
		if script {
			kind = stakeScript
		}
		return stakeRef{kind: kind, hash: hash}, nil
	case constrTagEqual(staking.Tag, 1) && len(staking.Fields) == 3:
		slot, err := uint64Integer(staking.Fields[0])
		if err != nil {
			return stakeRef{}, err
		}
		txIndex, err := uint64Integer(staking.Fields[1])
		if err != nil {
			return stakeRef{}, err
		}
		certIndex, err := uint64Integer(staking.Fields[2])
		if err != nil {
			return stakeRef{}, err
		}
		return stakeRef{kind: stakePointer, pointer: encodePointer(slot, txIndex, certIndex)}, nil
	default:
		return stakeRef{}, fmt.Errorf("expected StakingHash or StakingPtr, got constructor %s with %d fields", staking.Tag, len(staking.Fields))
	}
}

func uint64Integer(pd data.PlutusData) (uint64, error) {
	integer, ok := pd.(*data.Integer)
	if !ok || plutusNil(integer) || integer.Inner == nil || integer.Inner.Sign() < 0 || !integer.Inner.IsUint64() {
		return 0, fmt.Errorf("expected unsigned integer, got %T", pd)
	}
	return integer.Inner.Uint64(), nil
}

func encodePointer(slot, txIndex, certIndex uint64) []byte {
	writeVar := func(val uint64) []byte {
		var tmp [10]byte
		i := len(tmp) - 1
		tmp[i] = byte(val & 0x7F)
		val /= 128
		for val > 0 {
			i--
			tmp[i] = byte(val&0x7F) | 0x80
			val /= 128
		}
		return append([]byte(nil), tmp[i:]...)
	}
	out := writeVar(slot)
	out = append(out, writeVar(txIndex)...)
	out = append(out, writeVar(certIndex)...)
	return out
}

func marshalMaybe(fieldVal reflect.Value) (data.PlutusData, error) {
	if fieldVal.Kind() != reflect.Pointer {
		return nil, fmt.Errorf("maybe requires a pointer, got %s", fieldVal.Kind())
	}
	if fieldVal.IsNil() {
		return data.NewConstr(1), nil
	}
	inner, err := marshalMaybeInner(fieldVal.Elem())
	if err != nil {
		return nil, err
	}
	return data.NewConstr(0, inner), nil
}

func marshalMaybeInner(elem reflect.Value) (data.PlutusData, error) {
	if elem.CanAddr() {
		if m, ok := elem.Addr().Interface().(PlutusMarshaler); ok {
			return m.ToPlutusData()
		}
	}
	if elem.CanInterface() {
		if m, ok := elem.Interface().(PlutusMarshaler); ok {
			return m.ToPlutusData()
		}
	}
	if elem.Type() == reflect.TypeOf(common.Address{}) {
		return marshalAddress(elem.Interface().(common.Address))
	}
	if elem.Type() == reflect.TypeOf(big.Int{}) || elem.Type() == reflect.TypeFor[*big.Int]() {
		return marshalBigInt(elem)
	}
	if elem.Kind() == reflect.Struct {
		return marshalValue(elem)
	}
	switch elem.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return data.NewInteger(big.NewInt(elem.Int())), nil
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return data.NewInteger(new(big.Int).SetUint64(elem.Uint())), nil
	case reflect.String:
		return data.NewByteString([]byte(elem.String())), nil
	case reflect.Slice:
		if elem.Type().Elem().Kind() == reflect.Uint8 {
			return data.NewByteString(elem.Bytes()), nil
		}
	default:
		return nil, fmt.Errorf("unsupported Maybe element type %s", elem.Type())
	}
	return nil, fmt.Errorf("unsupported Maybe element type %s", elem.Type())
}

func unmarshalMaybe(pd data.PlutusData, fieldVal reflect.Value, cfg decodeConfig) error {
	if fieldVal.Kind() != reflect.Pointer {
		return fmt.Errorf("maybe requires a pointer, got %s", fieldVal.Kind())
	}
	constr, ok := pd.(*data.Constr)
	if !ok || plutusNil(constr) {
		return fmt.Errorf("expected Maybe constructor, got %T", pd)
	}
	if constrTagEqual(constr.Tag, 1) {
		if len(constr.Fields) != 0 {
			return fmt.Errorf("nothing must have no fields, got constructor %s with %d fields", constr.Tag, len(constr.Fields))
		}
		fieldVal.SetZero()
		return nil
	}
	if !constrTagEqual(constr.Tag, 0) || len(constr.Fields) != 1 {
		return fmt.Errorf("expected Just with 1 field, got constructor %s with %d fields", constr.Tag, len(constr.Fields))
	}
	ptr := reflect.New(fieldVal.Type().Elem())
	if err := unmarshalMaybeInner(constr.Fields[0], ptr.Elem(), cfg); err != nil {
		return err
	}
	fieldVal.Set(ptr)
	return nil
}

func unmarshalMaybeInner(pd data.PlutusData, elem reflect.Value, cfg decodeConfig) error {
	if elem.CanAddr() {
		if m, ok := elem.Addr().Interface().(PlutusMarshaler); ok {
			return m.FromPlutusData(pd, elem.Addr().Interface())
		}
	}
	if elem.CanInterface() {
		if m, ok := elem.Interface().(PlutusMarshaler); ok {
			return m.FromPlutusData(pd, elem.Interface())
		}
	}
	if elem.Type() == reflect.TypeOf(common.Address{}) {
		addr, err := unmarshalAddress(pd, cfg.network)
		if err != nil {
			return err
		}
		elem.Set(reflect.ValueOf(addr))
		return nil
	}
	if elem.Type() == reflect.TypeOf(big.Int{}) || elem.Type() == reflect.TypeFor[*big.Int]() {
		return unmarshalBigInt(pd, elem)
	}
	if elem.Kind() == reflect.Struct {
		return unmarshalValue(pd, elem, cfg)
	}
	switch elem.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return unmarshalInt(pd, elem)
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return unmarshalInt(pd, elem)
	case reflect.String:
		return unmarshalStringBytes(pd, elem)
	case reflect.Slice:
		if elem.Type().Elem().Kind() == reflect.Uint8 {
			return unmarshalBytes(pd, elem)
		}
	default:
		return fmt.Errorf("unsupported Maybe element type %s", elem.Type())
	}
	return fmt.Errorf("unsupported Maybe element type %s", elem.Type())
}
