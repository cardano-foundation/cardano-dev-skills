package apollo

import (
	"fmt"

	"github.com/blinklabs-io/gouroboros/ledger/common"
)

// --- Bech32 Convenience Methods ---

// AddInputAddressFromBech32 adds a bech32 address whose UTxOs should be used for coin selection.
func (a *Apollo) AddInputAddressFromBech32(bech32 string) (*Apollo, error) {
	addr, err := ParseAddress(bech32)
	if err != nil {
		return a, fmt.Errorf("invalid bech32 address: %w", err)
	}
	a.inputAddresses = append(a.inputAddresses, addr)
	return a, nil
}

// PayToAddressBech32 creates a simple payment to a bech32 address.
func (a *Apollo) PayToAddressBech32(bech32 string, lovelace int64, units ...Unit) (*Apollo, error) {
	addr, err := ParseAddress(bech32)
	if err != nil {
		return a, fmt.Errorf("invalid bech32 address: %w", err)
	}
	a = a.PayToAddress(addr, lovelace, units...)
	return a, nil
}

// SetChangeAddressBech32 sets the change address from a bech32 string.
func (a *Apollo) SetChangeAddressBech32(bech32 string) (*Apollo, error) {
	addr, err := ParseAddress(bech32)
	if err != nil {
		return a, fmt.Errorf("invalid bech32 address: %w", err)
	}
	a = a.SetChangeAddress(addr)
	return a, nil
}

// --- Datum Convenience Methods ---

// AttachDatum adds a datum to the witness set. Alias for AddDatum.
func (a *Apollo) AttachDatum(datum *common.Datum) *Apollo {
	return a.AddDatum(datum)
}

// PayToContractAsHash creates a payment to a script address with a pre-computed datum hash.
// Unlike PayToContractWithDatumHash, the full datum is NOT added to the witness set.
func (a *Apollo) PayToContractAsHash(addr common.Address, datumHash []byte, lovelace int64, units ...Unit) *Apollo {
	p := &Payment{
		Receiver:  addr,
		Lovelace:  lovelace,
		Units:     units,
		DatumHash: datumHash,
	}
	a.payments = append(a.payments, p)
	return a
}

// --- Version-Specific Reference Script Methods ---

// PayToAddressWithV1ReferenceScript pays to an address with a Plutus V1 reference script attached.
func (a *Apollo) PayToAddressWithV1ReferenceScript(addr common.Address, lovelace int64, script common.PlutusV1Script, units ...Unit) (*Apollo, error) {
	return a.PayToAddressWithReferenceScript(addr, lovelace, script, units...)
}

// PayToAddressWithV2ReferenceScript pays to an address with a Plutus V2 reference script attached.
func (a *Apollo) PayToAddressWithV2ReferenceScript(addr common.Address, lovelace int64, script common.PlutusV2Script, units ...Unit) (*Apollo, error) {
	return a.PayToAddressWithReferenceScript(addr, lovelace, script, units...)
}

// PayToAddressWithV3ReferenceScript pays to an address with a Plutus V3 reference script attached.
func (a *Apollo) PayToAddressWithV3ReferenceScript(addr common.Address, lovelace int64, script common.PlutusV3Script, units ...Unit) (*Apollo, error) {
	return a.PayToAddressWithReferenceScript(addr, lovelace, script, units...)
}

// PayToContractWithReferenceScript pays to a script address with an inline datum and a reference script.
func (a *Apollo) PayToContractWithReferenceScript(addr common.Address, datum *common.Datum, lovelace int64, script common.Script, units ...Unit) (*Apollo, error) {
	ref, err := NewScriptRef(script)
	if err != nil {
		return a, fmt.Errorf("failed to create script ref: %w", err)
	}
	p := &Payment{
		Receiver:  addr,
		Lovelace:  lovelace,
		Units:     units,
		Datum:     datum,
		IsInline:  true,
		ScriptRef: ref,
	}
	a.payments = append(a.payments, p)
	return a, nil
}

// PayToContractWithV1ReferenceScript pays to a script address with an inline datum and a Plutus V1 reference script.
func (a *Apollo) PayToContractWithV1ReferenceScript(addr common.Address, datum *common.Datum, lovelace int64, script common.PlutusV1Script, units ...Unit) (*Apollo, error) {
	return a.PayToContractWithReferenceScript(addr, datum, lovelace, script, units...)
}

// PayToContractWithV2ReferenceScript pays to a script address with an inline datum and a Plutus V2 reference script.
func (a *Apollo) PayToContractWithV2ReferenceScript(addr common.Address, datum *common.Datum, lovelace int64, script common.PlutusV2Script, units ...Unit) (*Apollo, error) {
	return a.PayToContractWithReferenceScript(addr, datum, lovelace, script, units...)
}

// PayToContractWithV3ReferenceScript pays to a script address with an inline datum and a Plutus V3 reference script.
func (a *Apollo) PayToContractWithV3ReferenceScript(addr common.Address, datum *common.Datum, lovelace int64, script common.PlutusV3Script, units ...Unit) (*Apollo, error) {
	return a.PayToContractWithReferenceScript(addr, datum, lovelace, script, units...)
}

// --- Staking FromAddress / FromBech32 Convenience Methods ---

// RegisterStakeFromAddress creates a stake registration certificate from an address.
func (a *Apollo) RegisterStakeFromAddress(addr common.Address) (*Apollo, error) {
	return a.RegisterStake(addr)
}

// RegisterStakeFromBech32 creates a stake registration certificate from a bech32 address.
func (a *Apollo) RegisterStakeFromBech32(bech32 string) (*Apollo, error) {
	return a.RegisterStake(bech32)
}

// DeregisterStakeFromAddress creates a stake deregistration certificate from an address.
func (a *Apollo) DeregisterStakeFromAddress(addr common.Address) (*Apollo, error) {
	return a.DeregisterStake(addr)
}

// DeregisterStakeFromBech32 creates a stake deregistration certificate from a bech32 address.
func (a *Apollo) DeregisterStakeFromBech32(bech32 string) (*Apollo, error) {
	return a.DeregisterStake(bech32)
}

// DelegateStakeFromAddress creates a stake delegation certificate from an address.
func (a *Apollo) DelegateStakeFromAddress(addr common.Address, poolHash common.Blake2b224) (*Apollo, error) {
	return a.DelegateStake(addr, poolHash)
}

// DelegateStakeFromBech32 creates a stake delegation certificate from a bech32 address.
func (a *Apollo) DelegateStakeFromBech32(bech32 string, poolHash common.Blake2b224) (*Apollo, error) {
	return a.DelegateStake(bech32, poolHash)
}

// DelegateVoteFromAddress creates a vote delegation certificate from an address.
func (a *Apollo) DelegateVoteFromAddress(addr common.Address, drep common.Drep) (*Apollo, error) {
	return a.DelegateVote(addr, drep)
}

// DelegateVoteFromBech32 creates a vote delegation certificate from a bech32 address.
func (a *Apollo) DelegateVoteFromBech32(bech32 string, drep common.Drep) (*Apollo, error) {
	return a.DelegateVote(bech32, drep)
}

// DelegateStakeAndVoteFromAddress creates a combined stake+vote delegation certificate from an address.
func (a *Apollo) DelegateStakeAndVoteFromAddress(addr common.Address, poolHash common.Blake2b224, drep common.Drep) (*Apollo, error) {
	return a.DelegateStakeAndVote(addr, poolHash, drep)
}

// DelegateStakeAndVoteFromBech32 creates a combined stake+vote delegation certificate from a bech32 address.
func (a *Apollo) DelegateStakeAndVoteFromBech32(bech32 string, poolHash common.Blake2b224, drep common.Drep) (*Apollo, error) {
	return a.DelegateStakeAndVote(bech32, poolHash, drep)
}

// RegisterAndDelegateStakeFromAddress creates a combined registration+delegation certificate from an address.
func (a *Apollo) RegisterAndDelegateStakeFromAddress(addr common.Address, poolHash common.Blake2b224, coin int64) (*Apollo, error) {
	return a.RegisterAndDelegateStake(addr, poolHash, coin)
}

// RegisterAndDelegateStakeFromBech32 creates a combined registration+delegation certificate from a bech32 address.
func (a *Apollo) RegisterAndDelegateStakeFromBech32(bech32 string, poolHash common.Blake2b224, coin int64) (*Apollo, error) {
	return a.RegisterAndDelegateStake(bech32, poolHash, coin)
}

// RegisterAndDelegateVoteFromAddress creates a combined registration+vote delegation certificate from an address.
func (a *Apollo) RegisterAndDelegateVoteFromAddress(addr common.Address, drep common.Drep, coin int64) (*Apollo, error) {
	return a.RegisterAndDelegateVote(addr, drep, coin)
}

// RegisterAndDelegateVoteFromBech32 creates a combined registration+vote delegation certificate from a bech32 address.
func (a *Apollo) RegisterAndDelegateVoteFromBech32(bech32 string, drep common.Drep, coin int64) (*Apollo, error) {
	return a.RegisterAndDelegateVote(bech32, drep, coin)
}

// RegisterAndDelegateStakeAndVoteFromAddress creates a combined registration+stake+vote certificate from an address.
func (a *Apollo) RegisterAndDelegateStakeAndVoteFromAddress(addr common.Address, poolHash common.Blake2b224, drep common.Drep, coin int64) (*Apollo, error) {
	return a.RegisterAndDelegateStakeAndVote(addr, poolHash, drep, coin)
}

// RegisterAndDelegateStakeAndVoteFromBech32 creates a combined registration+stake+vote certificate from a bech32 address.
func (a *Apollo) RegisterAndDelegateStakeAndVoteFromBech32(bech32 string, poolHash common.Blake2b224, drep common.Drep, coin int64) (*Apollo, error) {
	return a.RegisterAndDelegateStakeAndVote(bech32, poolHash, drep, coin)
}
