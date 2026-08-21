package apollo

import (
	"encoding/hex"
	"errors"
	"fmt"
	"math"
	"math/big"

	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/babbage"
	"github.com/blinklabs-io/gouroboros/ledger/common"

	"github.com/Salvionied/apollo/v2/backend"
	"github.com/Salvionied/apollo/v2/constants"
)

// Unit represents a native asset quantity.
type Unit struct {
	PolicyId string
	Name     string
	Quantity int64
}

// NewUnit creates a new Unit.
func NewUnit(policyId, name string, quantity int64) Unit {
	return Unit{
		PolicyId: policyId,
		Name:     name,
		Quantity: quantity,
	}
}

// ToValue converts a Unit to a Value containing this asset.
func (u *Unit) ToValue() (Value, error) {
	if u.PolicyId == "" || u.PolicyId == "lovelace" {
		if u.Quantity < 0 {
			return Value{}, fmt.Errorf("negative lovelace quantity: %d", u.Quantity)
		}
		return NewSimpleValue(uint64(u.Quantity)), nil //nolint:gosec // validated non-negative above
	}
	if u.Quantity < 0 {
		return Value{}, fmt.Errorf("negative native asset quantity: %d for policy %s", u.Quantity, u.PolicyId)
	}
	policyBytes, err := hex.DecodeString(u.PolicyId)
	if err != nil {
		return Value{}, fmt.Errorf("invalid policy ID hex %q: %w", u.PolicyId, err)
	}
	if len(policyBytes) != common.Blake2b224Size {
		return Value{}, fmt.Errorf("invalid policy ID length: expected %d bytes, got %d", common.Blake2b224Size, len(policyBytes))
	}
	var policyId common.Blake2b224
	copy(policyId[:], policyBytes)

	nameBytes, err := hex.DecodeString(u.Name)
	if err != nil {
		return Value{}, fmt.Errorf("invalid asset name hex %q: %w (asset names must be hex-encoded)", u.Name, err)
	}

	data := map[common.Blake2b224]map[cbor.ByteString]common.MultiAssetTypeOutput{
		policyId: {
			cbor.NewByteString(nameBytes): big.NewInt(u.Quantity),
		},
	}
	assets := common.NewMultiAsset[common.MultiAssetTypeOutput](data)
	return NewValue(0, &assets), nil
}

// toMintValue converts a Unit to a Value, allowing negative quantities (for burns).
// This is an internal method used only by mintValue().
func (u *Unit) toMintValue() (Value, error) {
	if u.PolicyId == "" || u.PolicyId == "lovelace" {
		if u.Quantity < 0 {
			return Value{}, fmt.Errorf("negative lovelace quantity: %d", u.Quantity)
		}
		return NewSimpleValue(uint64(u.Quantity)), nil //nolint:gosec // validated non-negative above
	}
	policyBytes, err := hex.DecodeString(u.PolicyId)
	if err != nil {
		return Value{}, fmt.Errorf("invalid policy ID hex %q: %w", u.PolicyId, err)
	}
	if len(policyBytes) != common.Blake2b224Size {
		return Value{}, fmt.Errorf("invalid policy ID length: expected %d bytes, got %d", common.Blake2b224Size, len(policyBytes))
	}
	var policyId common.Blake2b224
	copy(policyId[:], policyBytes)

	nameBytes, err := hex.DecodeString(u.Name)
	if err != nil {
		return Value{}, fmt.Errorf("invalid asset name hex %q: %w (asset names must be hex-encoded)", u.Name, err)
	}

	data := map[common.Blake2b224]map[cbor.ByteString]common.MultiAssetTypeOutput{
		policyId: {
			cbor.NewByteString(nameBytes): big.NewInt(u.Quantity),
		},
	}
	assets := common.NewMultiAsset[common.MultiAssetTypeOutput](data)
	return NewValue(0, &assets), nil
}

// PaymentI is the interface for payment types.
type PaymentI interface {
	EnsureMinUTXO(cc backend.ChainContext) error
	// ToTxOut builds the transaction output for this payment.
	//
	// The return type is era-neutral so that a future ledger era does not
	// require changing this interface, which third parties implement. Apollo
	// builds Conway bodies, whose outputs use the Babbage format, so the
	// builder currently requires a *babbage.BabbageTransactionOutput and
	// reports a clear error for anything else.
	ToTxOut() (common.TransactionOutput, error)
	ToValue() (Value, error)
}

// PaymentCloner is implemented by custom PaymentI implementations that can
// produce an independent copy for Apollo.Clone. Apollo's built-in Payment
// implementation is cloned directly.
type PaymentCloner interface {
	ClonePayment() (PaymentI, error)
}

// Payment represents a transaction output with receiver, lovelace, and optional assets.
type Payment struct {
	Lovelace  int64
	Receiver  common.Address
	Units     []Unit
	Datum     *common.Datum
	DatumHash []byte
	IsInline  bool
	ScriptRef *common.ScriptRef
}

// NewPayment creates a new Payment.
func NewPayment(receiver string, lovelace int64, units []Unit) (*Payment, error) {
	addr, err := ParseAddress(receiver)
	if err != nil {
		return nil, fmt.Errorf("invalid receiver address: %w", err)
	}
	return &Payment{
		Lovelace: lovelace,
		Receiver: addr,
		Units:    units,
	}, nil
}

// NewPaymentFromValue creates a Payment from an Address and Value.
// It returns an error if a native-asset quantity exceeds the int64 range,
// rather than silently truncating or saturating it to a wrong value.
func NewPaymentFromValue(receiver common.Address, value Value) (*Payment, error) {
	if value.Coin > math.MaxInt64 {
		return nil, fmt.Errorf("lovelace quantity %d exceeds int64 range", value.Coin)
	}
	payment := &Payment{
		Receiver: receiver,
		Lovelace: int64(value.Coin),
	}
	if value.Assets != nil {
		for _, policyId := range value.Assets.Policies() {
			for _, assetName := range value.Assets.Assets(policyId) {
				qty := value.Assets.Asset(policyId, assetName)
				if !qty.IsInt64() {
					return nil, fmt.Errorf("asset quantity %s for policy %s exceeds int64 range", qty.String(), hex.EncodeToString(policyId.Bytes()))
				}
				payment.Units = append(payment.Units, Unit{
					PolicyId: hex.EncodeToString(policyId.Bytes()),
					Name:     hex.EncodeToString(assetName),
					Quantity: qty.Int64(),
				})
			}
		}
	}
	return payment, nil
}

// PaymentFromTxOut creates a Payment from a BabbageTransactionOutput.
// It returns an error if a native-asset quantity exceeds the int64 range,
// rather than silently truncating or saturating it to a wrong value.
func PaymentFromTxOut(txOut *babbage.BabbageTransactionOutput) (*Payment, error) {
	if txOut == nil {
		return nil, nil
	}
	if txOut.OutputAmount.Amount > math.MaxInt64 {
		return nil, fmt.Errorf("lovelace quantity %d exceeds int64 range", txOut.OutputAmount.Amount)
	}
	payment := &Payment{
		Receiver: txOut.OutputAddress,
		Lovelace: int64(txOut.OutputAmount.Amount),
	}
	if txOut.OutputAmount.Assets != nil {
		for _, policyId := range txOut.OutputAmount.Assets.Policies() {
			for _, assetName := range txOut.OutputAmount.Assets.Assets(policyId) {
				qty := txOut.OutputAmount.Assets.Asset(policyId, assetName)
				if !qty.IsInt64() {
					return nil, fmt.Errorf("asset quantity %s for policy %s exceeds int64 range", qty.String(), hex.EncodeToString(policyId.Bytes()))
				}
				payment.Units = append(payment.Units, Unit{
					PolicyId: hex.EncodeToString(policyId.Bytes()),
					Name:     hex.EncodeToString(assetName),
					Quantity: qty.Int64(),
				})
			}
		}
	}
	payment.ScriptRef = txOut.TxOutScriptRef
	if d := txOut.Datum(); d != nil {
		payment.Datum = d
		payment.IsInline = true
	} else if h := txOut.DatumHash(); h != nil {
		payment.DatumHash = h.Bytes()
	}
	return payment, nil
}

// ToValue converts a Payment to a Value.
func (p *Payment) ToValue() (Value, error) {
	if p.Lovelace < 0 {
		return Value{}, fmt.Errorf("negative lovelace amount: %d", p.Lovelace)
	}
	coin := uint64(p.Lovelace) //nolint:gosec // validated non-negative above
	v := NewSimpleValue(coin)
	for _, unit := range p.Units {
		if unit.Quantity < 0 {
			return Value{}, fmt.Errorf("negative asset quantity %d for policy %s", unit.Quantity, unit.PolicyId)
		}
		uv, err := unit.ToValue()
		if err != nil {
			return Value{}, fmt.Errorf("invalid unit %s: %w", unit.PolicyId, err)
		}
		v, err = v.Add(uv)
		if err != nil {
			return Value{}, err
		}
	}
	return v, nil
}

// EnsureMinUTXO ensures the payment meets the minimum UTxO requirement.
// It iterates because raising Lovelace can increase the CBOR-encoded output size,
// which in turn may require a slightly higher min UTxO. Converges in 1-2 iterations.
func (p *Payment) EnsureMinUTXO(cc backend.ChainContext) error {
	if len(p.Units) == 0 && p.Lovelace >= constants.MinLovelace && p.Datum == nil && len(p.DatumHash) == 0 && p.ScriptRef == nil {
		return nil
	}
	pp, err := cc.ProtocolParams()
	if err != nil {
		return fmt.Errorf("failed to get protocol params: %w", err)
	}
	for range 3 {
		txOut, err := p.babbageTxOut()
		if err != nil {
			return err
		}
		coins, err := MinLovelacePostAlonzo(txOut, pp.CoinsPerUtxoByteValue())
		if err != nil {
			return fmt.Errorf("failed to compute min UTxO: %w", err)
		}
		if p.Lovelace >= coins {
			return nil
		}
		p.Lovelace = coins
	}
	// If we exhausted iterations without converging, verify one final time.
	txOut, err := p.babbageTxOut()
	if err != nil {
		return err
	}
	coins, err := MinLovelacePostAlonzo(txOut, pp.CoinsPerUtxoByteValue())
	if err != nil {
		return fmt.Errorf("failed to compute min UTxO: %w", err)
	}
	if p.Lovelace < coins {
		return fmt.Errorf("min UTxO did not converge after 3 iterations: need %d, have %d", coins, p.Lovelace)
	}
	return nil
}

// babbageTxOut returns this payment's output in the Babbage format the Conway
// body requires, or an error naming the type it got instead.
func (p *Payment) babbageTxOut() (*babbage.BabbageTransactionOutput, error) {
	txOut, err := p.ToTxOut()
	if err != nil {
		return nil, fmt.Errorf("failed to build tx output: %w", err)
	}
	return babbageOutputOf(txOut)
}

// babbageOutputOf narrows an era-neutral output to the Babbage format used by
// Conway transaction bodies.
//
// PaymentI.ToTxOut is deliberately era-neutral so the interface survives a new
// ledger era, but Apollo builds Conway bodies today, so anything other than a
// Babbage-format output cannot be placed in one. A third-party PaymentI that
// returns some other implementation gets this error rather than a panic.
func babbageOutputOf(
	txOut common.TransactionOutput,
) (*babbage.BabbageTransactionOutput, error) {
	if txOut == nil {
		return nil, errors.New("payment produced no transaction output")
	}
	out, ok := txOut.(*babbage.BabbageTransactionOutput)
	if !ok {
		return nil, fmt.Errorf(
			"payment produced a %T output; Apollo builds Conway bodies, which "+
				"require the Babbage output format",
			txOut,
		)
	}
	return out, nil
}

// ToTxOut converts a Payment to a transaction output.
//
// The concrete type is *babbage.BabbageTransactionOutput, which is the output
// format Conway bodies use; the declared type is era-neutral so the PaymentI
// contract survives a new era.
func (p *Payment) ToTxOut() (common.TransactionOutput, error) {
	val, err := p.ToValue()
	if err != nil {
		return nil, fmt.Errorf("failed to compute payment value: %w", err)
	}
	output := NewBabbageOutput(p.Receiver, val, nil, p.ScriptRef)

	if p.IsInline && p.Datum != nil {
		datumOpt, err := NewDatumOptionInline(p.Datum)
		if err != nil {
			return nil, fmt.Errorf("failed to create inline datum: %w", err)
		}
		output.DatumOption = datumOpt
	} else if len(p.DatumHash) > 0 {
		if len(p.DatumHash) != common.Blake2b256Size {
			return nil, fmt.Errorf("invalid datum hash length: expected %d bytes, got %d", common.Blake2b256Size, len(p.DatumHash))
		}
		var hash common.Blake2b256
		copy(hash[:], p.DatumHash)
		datumOpt, err := NewDatumOptionHash(hash)
		if err != nil {
			return nil, fmt.Errorf("failed to create datum hash: %w", err)
		}
		output.DatumOption = datumOpt
	}
	return &output, nil
}
