package apollo

import (
	"errors"
	"fmt"
	"strings"

	"github.com/blinklabs-io/gouroboros/ledger/common"
)

// addressHeaderLen is the length of the Shelley-era address header byte.
const addressHeaderLen = 1

// bech32AddressPrefixes are the bech32 human-readable parts Cardano uses for
// payment and reward addresses, each including the bech32 separator. An input
// carrying one of these prefixes is a bech32 address and must never be
// re-interpreted as base58.
var bech32AddressPrefixes = []string{
	"addr1",
	"addr_test1",
	"stake1",
	"stake_test1",
}

// ParseAddress decodes a Cardano address from its textual bech32 (Shelley and
// later) or base58 (Byron) form and validates it before returning.
//
// It exists because common.NewAddress treats *any* bech32 failure - including
// a checksum mismatch - as a reason to retry the input as base58. Every
// character of a mainnet "addr1..." address is also a legal base58 character,
// so a single mistyped character silently re-decodes into unrelated bytes and
// the caller ends up building a payment for a different recipient. Testnet
// addresses are accidentally immune because "_" is not base58, meaning the
// fallthrough only misfires where real funds are.
//
// Validation is threefold:
//
//  1. Non-Byron addresses must re-encode to exactly the input text.
//     Address.String() only ever emits a canonical bech32 string, so an input
//     that survives the comparison necessarily carried a valid checksum, and
//     its human-readable part necessarily agrees with the network id and
//     address type in the header byte. common.NewAddress ignores the
//     human-readable part entirely, so this is also what stops an
//     "addr1..."-prefixed string from being accepted as a testnet address.
//  2. Byron addresses are accepted only when the input does not carry a
//     bech32 address prefix, so a corrupted "addr1..." string can never be
//     laundered through the base58 path. Byron addresses embed their own
//     CRC32 checksum, which gouroboros verifies while decoding.
//  3. The decoded payload length must match the address type exactly, which
//     rejects trailing bytes, and the network id must be one Cardano actually
//     has (0 for testnets, 1 for mainnet).
func ParseAddress(text string) (common.Address, error) {
	if text == "" {
		return common.Address{}, errors.New("address is empty")
	}
	addr, err := common.NewAddress(text)
	if err != nil {
		return common.Address{}, fmt.Errorf(
			"%q is not a valid bech32 or base58 address: %w",
			text,
			err,
		)
	}
	if addr.Type() == common.AddressTypeByron {
		if hasBech32AddressPrefix(text) {
			return common.Address{}, fmt.Errorf(
				"%q has a bech32 address prefix but decoded as a Byron "+
					"address; it is not a valid address",
				text,
			)
		}
	} else {
		canonical, err := canonicalAddressText(addr)
		if err != nil {
			return common.Address{}, fmt.Errorf("invalid address %q: %w", text, err)
		}
		if !strings.EqualFold(canonical, text) {
			return common.Address{}, fmt.Errorf(
				"%q is not a canonical Cardano address: it decodes to %q "+
					"(bad checksum, wrong prefix for the address network or "+
					"type, or a non-canonical encoding)",
				text,
				canonical,
			)
		}
	}
	if err := validateAddress(addr); err != nil {
		return common.Address{}, fmt.Errorf("invalid address %q: %w", text, err)
	}
	return addr, nil
}

// canonicalAddressText returns the canonical textual form of a non-Byron
// address. Serialization is checked first because Address.String() panics
// rather than returning an error when an address cannot be serialized, and a
// malformed address must produce an error.
func canonicalAddressText(addr common.Address) (string, error) {
	if _, err := addr.Bytes(); err != nil {
		return "", fmt.Errorf("address cannot be serialized: %w", err)
	}
	return addr.String(), nil
}

// validateAddress checks the structural invariants of a decoded address: a
// network id that exists on Cardano and a payload whose length matches the
// address type, so trailing bytes are never accepted.
func validateAddress(addr common.Address) error {
	raw, err := addr.Bytes()
	if err != nil {
		return fmt.Errorf("failed to serialize address: %w", err)
	}
	if addr.Type() == common.AddressTypeByron {
		// Byron addresses are CBOR carrying an embedded CRC32 checksum; both
		// are verified while decoding, and their length is not fixed.
		return nil
	}
	if err := validateAddressNetworkId(addr.NetworkId()); err != nil {
		return err
	}
	want, err := expectedAddressLen(addr)
	if err != nil {
		return err
	}
	if len(raw) != want {
		return fmt.Errorf(
			"address type %d payload is %d bytes, expected %d",
			addr.Type(),
			len(raw),
			want,
		)
	}
	return nil
}

// validateAddressNetworkId rejects the network ids that fit in the address
// header nibble but do not exist on Cardano. Only 0 (testnets) and 1
// (mainnet) are defined; common.Address.populateFromBytes accepts 2-15.
func validateAddressNetworkId(networkId uint) error {
	switch networkId {
	case common.AddressNetworkTestnet, common.AddressNetworkMainnet:
		return nil
	default:
		return fmt.Errorf(
			"unknown network id %d: Cardano defines only %d (testnet) and "+
				"%d (mainnet)",
			networkId,
			common.AddressNetworkTestnet,
			common.AddressNetworkMainnet,
		)
	}
}

// expectedAddressLen returns the exact serialized length of a non-Byron
// address of the given type.
func expectedAddressLen(addr common.Address) (int, error) {
	switch addr.Type() {
	case common.AddressTypeKeyKey,
		common.AddressTypeScriptKey,
		common.AddressTypeKeyScript,
		common.AddressTypeScriptScript:
		return addressHeaderLen + 2*common.AddressHashSize, nil
	case common.AddressTypeKeyNone,
		common.AddressTypeScriptNone,
		common.AddressTypeNoneKey,
		common.AddressTypeNoneScript:
		return addressHeaderLen + common.AddressHashSize, nil
	case common.AddressTypeKeyPointer, common.AddressTypeScriptPointer:
		pointer, ok := addr.StakingPayload().(common.AddressPayloadPointer)
		if !ok {
			return 0, errors.New("pointer address has no pointer payload")
		}
		return addressHeaderLen + common.AddressHashSize +
			varUintLen(pointer.Slot) +
			varUintLen(pointer.TxIndex) +
			varUintLen(pointer.CertIndex), nil
	default:
		return 0, fmt.Errorf("unsupported address type %d", addr.Type())
	}
}

// varUintLen returns the number of bytes the variable-length integer encoding
// used by pointer addresses needs for v.
func varUintLen(v uint64) int {
	n := 1
	for v >= 128 {
		v /= 128
		n++
	}
	return n
}

// hasBech32AddressPrefix reports whether text starts with a Cardano bech32
// address human-readable part. bech32 allows an all-uppercase encoding, so the
// comparison is case-insensitive.
func hasBech32AddressPrefix(text string) bool {
	lower := strings.ToLower(text)
	for _, prefix := range bech32AddressPrefixes {
		if strings.HasPrefix(lower, prefix) {
			return true
		}
	}
	return false
}

// validateAddressNetworks fails closed when any address the transaction
// commits to belongs to a different network than the chain context. Nothing
// else in the builder compares addresses against Context.NetworkId(), which
// is copied into the transaction body verbatim, so without this check a
// mainnet-derived wallet pointed at a preprod context (or a preprod payee
// pasted into a mainnet builder) builds and signs a transaction that either
// is rejected by the node as WrongNetwork or looks valid while paying an
// address the sender cannot reach.
func (a *Apollo) validateAddressNetworks() error {
	network := uint(a.Context.NetworkId())
	if err := validateAddressNetworkId(network); err != nil {
		return fmt.Errorf("chain context has an invalid network: %w", err)
	}
	check := func(role string, index int, addr common.Address) error {
		if addr.NetworkId() == network {
			return nil
		}
		if index < 0 {
			return fmt.Errorf(
				"network mismatch: %s %s is on network %d, but the chain "+
					"context is on network %d",
				role,
				addr.String(),
				addr.NetworkId(),
				network,
			)
		}
		return fmt.Errorf(
			"network mismatch: %s %d (%s) is on network %d, but the chain "+
				"context is on network %d",
			role,
			index,
			addr.String(),
			addr.NetworkId(),
			network,
		)
	}
	if a.wallet != nil {
		if err := check("wallet address", -1, a.wallet.Address()); err != nil {
			return err
		}
	}
	// The resolved change address is either the explicit one or the wallet
	// address, which is checked above.
	if a.changeAddress != nil {
		if err := check("change address", -1, *a.changeAddress); err != nil {
			return err
		}
	}
	for i, addr := range a.inputAddresses {
		if err := check("input address", i, addr); err != nil {
			return err
		}
	}
	for i, payment := range a.payments {
		txOut, err := payment.ToTxOut()
		if err != nil {
			return fmt.Errorf("failed to resolve payment %d: %w", i, err)
		}
		if txOut == nil {
			continue
		}
		if err := check("payment receiver", i, txOut.Address()); err != nil {
			return err
		}
	}
	utxoGroups := []struct {
		role  string
		utxos []common.Utxo
	}{
		{"input UTxO", a.preselectedUtxos},
		{"available UTxO", a.utxos},
		{"collateral UTxO", a.collaterals},
	}
	for _, group := range utxoGroups {
		for i, utxo := range group.utxos {
			if utxo.Output == nil {
				continue
			}
			if err := check(group.role, i, utxo.Output.Address()); err != nil {
				return err
			}
		}
	}
	return nil
}
