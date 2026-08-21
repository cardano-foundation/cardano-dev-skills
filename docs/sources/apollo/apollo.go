package apollo

import (
	"bytes"
	"context"
	"encoding/hex"
	"errors"
	"fmt"
	"maps"
	"math"
	"math/big"
	"reflect"
	"slices"
	"sort"
	"strconv"
	"strings"

	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/babbage"
	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/gouroboros/ledger/conway"
	"github.com/blinklabs-io/gouroboros/ledger/shelley"

	"github.com/Salvionied/apollo/v2/backend"
)

const (
	ExMemoryBuffer = 0.2
	ExStepBuffer   = 0.2
	StakeDeposit   = 2_000_000
)

// ErrPlutusV4RequiresDijkstra reports that an operation needs a Dijkstra-era
// transaction witness set, while Apollo currently builds Conway transactions.
var ErrPlutusV4RequiresDijkstra = errors.New("plutus V4 requires Dijkstra transaction support; Apollo currently builds Conway transactions")

// Apollo is the main transaction builder.
type Apollo struct {
	Context            backend.ChainContext
	requestContext     context.Context
	payments           []PaymentI
	isEstimateRequired bool
	utxos              []common.Utxo
	preselectedUtxos   []common.Utxo
	inputAddresses     []common.Address
	tx                 *conway.ConwayTransaction
	datums             []common.Datum
	requiredSigners    []common.Blake2b224
	v1scripts          []common.PlutusV1Script
	v2scripts          []common.PlutusV2Script
	v3scripts          []common.PlutusV3Script
	redeemers          map[string]redeemerEntry // keyed by UTxO ref string
	stakeRedeemers     map[string]redeemerEntry
	mintRedeemers      map[string]redeemerEntry
	mint               []Unit
	collaterals        []common.Utxo
	Fee                int64
	FeePadding         int64
	Ttl                int64
	ValidityStart      int64
	totalCollateral    int64
	referenceInputs    []shelley.ShelleyTransactionInput
	collateralReturn   *babbage.BabbageTransactionOutput
	// collateralOverlapRef holds the ref of an auto-selected collateral UTxO
	// that is also allowed to serve as a regular spending input. It is set only
	// when no dedicated (separate) collateral UTxO was available, so wallets
	// with a single UTxO can still build script transactions. The Cardano ledger
	// permits this overlap because collateral is consumed only on phase-2 script
	// failure and regular inputs only on success - the two paths are mutually
	// exclusive. When empty, collateral is reserved out of the coin-selection
	// pool as usual.
	collateralOverlapRef string
	// collateralAutoSelected is true when setCollateral() chose the collateral
	// inputs itself (rather than the caller pinning them via AddCollateral).
	// Only auto-selected collateral is resized by finalizeCollateral(), so
	// caller-pinned collateral is never silently rewritten.
	collateralAutoSelected     bool
	nativescripts              []common.NativeScript
	usedUtxos                  map[string]bool
	wallet                     Wallet
	evaluationWitnessProviders []EvaluationWitnessProvider
	certificates               []common.CertificateWrapper
	withdrawals                map[string]withdrawalEntry
	auxiliaryData              *auxData
	votingProcedures           common.VotingProcedures
	proposalProcedures         []conway.ConwayProposalProcedure
	currentTreasury            int64
	treasuryDonation           int64
	collateralAmount           int64
	scriptHashes               []string
	changeAddress              *common.Address
	estimateExUnits            bool
	forceFee                   bool
	coinSelector               CoinSelector
	err                        error
}

type redeemerEntry struct {
	Tag     common.RedeemerTag
	Data    common.Datum
	ExUnits common.ExUnits
}

type withdrawalEntry struct {
	Address common.Address
	Amount  uint64
}

type auxData struct {
	metadata map[uint64]any
}

// New creates a new Apollo transaction builder with the given chain context.
func New(cc backend.ChainContext) *Apollo {
	a := &Apollo{
		Context:         cc,
		requestContext:  context.Background(),
		redeemers:       make(map[string]redeemerEntry),
		stakeRedeemers:  make(map[string]redeemerEntry),
		mintRedeemers:   make(map[string]redeemerEntry),
		withdrawals:     make(map[string]withdrawalEntry),
		estimateExUnits: true,
	}
	if isNilChainContext(cc) {
		a.setErrOnce(errors.New("chain context must not be nil"))
	}
	return a
}

func (a *Apollo) initState() {
	if a.requestContext == nil {
		a.requestContext = context.Background()
	}
	if a.redeemers == nil {
		a.redeemers = make(map[string]redeemerEntry)
	}
	if a.stakeRedeemers == nil {
		a.stakeRedeemers = make(map[string]redeemerEntry)
	}
	if a.mintRedeemers == nil {
		a.mintRedeemers = make(map[string]redeemerEntry)
	}
	if a.withdrawals == nil {
		a.withdrawals = make(map[string]withdrawalEntry)
	}
}

// WithContext sets the context used by subsequent chain-context operations.
// A nil context is treated as context.Background. The context is retained by
// the builder, so callers should not use a short-lived context for operations
// they intend to perform later.
func (a *Apollo) WithContext(ctx context.Context) *Apollo {
	if ctx == nil {
		ctx = context.Background()
	}
	a.requestContext = ctx
	return a
}

// SetWallet sets the wallet for the transaction builder.
func (a *Apollo) SetWallet(w Wallet) *Apollo {
	a.wallet = w
	return a
}

// AddEvaluationWitnessProvider registers an optional source of witnesses for
// preliminary transaction evaluation. Registered witnesses are never added to
// the completed transaction.
func (a *Apollo) AddEvaluationWitnessProvider(provider EvaluationWitnessProvider) *Apollo {
	if provider != nil {
		a.evaluationWitnessProviders = append(a.evaluationWitnessProviders, provider)
	}
	return a
}

// SetWalletFromMnemonic creates a BursaWallet from a mnemonic and sets it.
func (a *Apollo) SetWalletFromMnemonic(mnemonic string) (*Apollo, error) {
	w, err := NewBursaWallet(mnemonic)
	if err != nil {
		return a, err
	}
	a.wallet = w
	return a, nil
}

// SetWalletFromMnemonicWithPassphrase creates a BursaWallet from a mnemonic and passphrase and sets it.
func (a *Apollo) SetWalletFromMnemonicWithPassphrase(mnemonic string, passphrase string) (*Apollo, error) {
	w, err := NewBursaWalletWithPassphrase(mnemonic, passphrase)
	if err != nil {
		return a, err
	}
	a.wallet = w
	return a, nil
}

// AddPayment adds a payment to the transaction.
func (a *Apollo) AddPayment(payment PaymentI) *Apollo {
	a.initState()
	if isNilPayment(payment) {
		a.setErrOnce(errors.New("payment must not be nil"))
		return a
	}
	a.payments = append(a.payments, payment)
	return a
}

// AddLoadedUTxOs adds UTxOs to the available pool for coin selection.
func (a *Apollo) AddLoadedUTxOs(utxos ...common.Utxo) *Apollo {
	for i, utxo := range utxos {
		if err := validateUtxo(utxo); err != nil {
			a.setErrOnce(fmt.Errorf("loaded UTxO %d is invalid: %w", i, err))
			return a
		}
	}
	a.utxos = append(a.utxos, utxos...)
	return a
}

// AddInput adds a specific UTxO as a transaction input.
func (a *Apollo) AddInput(utxo common.Utxo) *Apollo {
	if err := validateUtxo(utxo); err != nil {
		a.setErrOnce(fmt.Errorf("input UTxO is invalid: %w", err))
		return a
	}
	a.preselectedUtxos = append(a.preselectedUtxos, utxo)
	return a
}

// AddInputAddress adds an address whose UTxOs should be used for coin selection.
func (a *Apollo) AddInputAddress(addr common.Address) *Apollo {
	a.inputAddresses = append(a.inputAddresses, addr)
	return a
}

// AddRequiredSigner adds a required signer by key hash.
func (a *Apollo) AddRequiredSigner(pkh common.Blake2b224) *Apollo {
	a.requiredSigners = append(a.requiredSigners, pkh)
	return a
}

// AddRequiredSignerPaymentKey adds the payment key hash from an address as a required signer.
func (a *Apollo) AddRequiredSignerPaymentKey(addr common.Address) *Apollo {
	switch addr.Type() {
	case common.AddressTypeKeyKey,
		common.AddressTypeKeyScript,
		common.AddressTypeKeyPointer,
		common.AddressTypeKeyNone:
		// These address forms have a payment key credential.
	default:
		a.setErrOnce(fmt.Errorf(
			"AddRequiredSignerPaymentKey: address type %d does not have a payment key credential",
			addr.Type(),
		))
		return a
	}
	a.requiredSigners = append(a.requiredSigners, addr.PaymentKeyHash())
	return a
}

// AddRequiredSignerStakeKey adds the staking key hash from an address as a required signer.
func (a *Apollo) AddRequiredSignerStakeKey(addr common.Address) *Apollo {
	skh := addr.StakeKeyHash()
	if skh != (common.Blake2b224{}) {
		a.requiredSigners = append(a.requiredSigners, skh)
	}
	return a
}

// SetTtl sets the transaction time-to-live.
func (a *Apollo) SetTtl(ttl int64) *Apollo {
	if ttl < 0 {
		a.setErrOnce(errors.New("SetTtl: ttl must be non-negative"))
		return a
	}
	a.Ttl = ttl
	return a
}

// SetValidityStart sets the validity start slot.
func (a *Apollo) SetValidityStart(start int64) *Apollo {
	if start < 0 {
		a.setErrOnce(errors.New("SetValidityStart: start must be non-negative"))
		return a
	}
	a.ValidityStart = start
	return a
}

// SetFee sets a specific fee (disables fee estimation).
func (a *Apollo) SetFee(fee int64) *Apollo {
	if fee < 0 {
		a.setErrOnce(errors.New("SetFee: fee must be non-negative"))
		return a
	}
	a.Fee = fee
	return a
}

// SetFeePadding adds additional fee padding.
func (a *Apollo) SetFeePadding(padding int64) *Apollo {
	if padding < 0 {
		a.setErrOnce(errors.New("SetFeePadding: padding must be non-negative"))
		return a
	}
	a.FeePadding = padding
	return a
}

// SetCoinSelector sets the coin selection algorithm used by Complete to
// choose inputs. When unset, the package default selector is used.
func (a *Apollo) SetCoinSelector(selector CoinSelector) *Apollo {
	a.coinSelector = selector
	return a
}

// ForceFee sets a fixed fee for the transaction, bypassing automatic fee estimation.
func (a *Apollo) ForceFee(fee int64) *Apollo {
	if fee < 0 {
		a.setErrOnce(errors.New("ForceFee: fee must be non-negative"))
		return a
	}
	a.Fee = fee
	a.forceFee = true
	return a
}

// SetChangeAddress sets the address to receive change outputs.
func (a *Apollo) SetChangeAddress(addr common.Address) *Apollo {
	a.changeAddress = &addr
	return a
}

// AddCollateral adds a UTxO as collateral for script transactions.
func (a *Apollo) AddCollateral(utxo common.Utxo) *Apollo {
	if err := validateUtxo(utxo); err != nil {
		a.setErrOnce(fmt.Errorf("collateral UTxO is invalid: %w", err))
		return a
	}
	a.collaterals = append(a.collaterals, utxo)
	return a
}

// AddDatum adds a datum to the witness set.
//
// The datum's wire bytes are pinned onto it (see DatumWireCbor), so a datum
// whose original CBOR cannot be reproduced on the wire is rejected here rather
// than being silently rehashed into a transaction the ledger would refuse.
func (a *Apollo) AddDatum(datum *common.Datum) *Apollo {
	if datum != nil {
		if _, err := DatumWireCbor(datum); err != nil {
			a.setErrOnce(fmt.Errorf("AddDatum: %w", err))
			return a
		}
		a.datums = append(a.datums, *datum)
	}
	return a
}

// AddReferenceInput adds a reference input to the transaction.
func (a *Apollo) AddReferenceInput(txHash string, index int) (*Apollo, error) {
	hashBytes, err := hex.DecodeString(txHash)
	if err != nil {
		return a, fmt.Errorf("invalid tx hash hex: %w", err)
	}
	if len(hashBytes) != common.Blake2b256Size {
		return a, fmt.Errorf("invalid tx hash length: expected %d bytes, got %d", common.Blake2b256Size, len(hashBytes))
	}
	if index < 0 || uint64(index) > uint64(math.MaxUint32) {
		return a, fmt.Errorf("index must be 0-%d, got %d", uint64(math.MaxUint32), index)
	}
	var hash common.Blake2b256
	copy(hash[:], hashBytes)
	input := shelley.ShelleyTransactionInput{
		TxId:        hash,
		OutputIndex: uint32(index),
	}
	a.referenceInputs = append(a.referenceInputs, input)
	return a, nil
}

// Mint adds tokens to mint. If redeemer is provided, sets up script minting.
// When exUnits is nil, execution units will be estimated automatically.
func (a *Apollo) Mint(unit Unit, redeemer *common.Datum, exUnits *common.ExUnits) *Apollo {
	a.initState()
	// Redeemer indexes bind to mint policies in byte-wise sorted order; mixed-case
	// hex would sort differently as a string than as bytes, misbinding redeemers.
	unit.PolicyId = strings.ToLower(unit.PolicyId)
	a.mint = append(a.mint, unit)
	if redeemer != nil {
		eu := common.ExUnits{}
		if exUnits != nil {
			eu = *exUnits
		}
		a.mintRedeemers[unit.PolicyId] = redeemerEntry{
			Tag:     common.RedeemerTagMint,
			Data:    *redeemer,
			ExUnits: eu,
		}
		a.isEstimateRequired = true
	}
	return a
}

// AttachScript attaches a script to the witness set, deduplicating by hash.
// It accepts NativeScript and PlutusV1Script through PlutusV3Script. Plutus V4
// witnesses require Dijkstra-era transaction support and cause Complete to
// return ErrPlutusV4RequiresDijkstra.
func (a *Apollo) AttachScript(script common.Script) *Apollo {
	scriptType, err := scriptRefType(script)
	if err != nil {
		a.setErrOnce(err)
		return a
	}
	if scriptType == common.ScriptRefTypePlutusV4 {
		a.setErrOnce(ErrPlutusV4RequiresDijkstra)
		return a
	}
	hash := script.Hash().String()
	if a.hasScriptHash(hash) {
		return a
	}
	a.scriptHashes = append(a.scriptHashes, hash)
	switch s := script.(type) {
	case common.PlutusV1Script:
		a.v1scripts = append(a.v1scripts, s)
	case *common.PlutusV1Script:
		a.v1scripts = append(a.v1scripts, *s)
	case common.PlutusV2Script:
		a.v2scripts = append(a.v2scripts, s)
	case *common.PlutusV2Script:
		a.v2scripts = append(a.v2scripts, *s)
	case common.PlutusV3Script:
		a.v3scripts = append(a.v3scripts, s)
	case *common.PlutusV3Script:
		a.v3scripts = append(a.v3scripts, *s)
	case common.NativeScript:
		a.nativescripts = append(a.nativescripts, s)
	case *common.NativeScript:
		a.nativescripts = append(a.nativescripts, *s)
	}
	return a
}

// DisableExecutionUnitsEstimation disables automatic ExUnit estimation.
func (a *Apollo) DisableExecutionUnitsEstimation() *Apollo {
	a.estimateExUnits = false
	return a
}

// --- Smart Contract Methods ---

// CollectFrom adds a script UTxO as input with a spending redeemer.
func (a *Apollo) CollectFrom(utxo common.Utxo, redeemer common.Datum, exUnits common.ExUnits) *Apollo {
	a.initState()
	if err := validateUtxo(utxo); err != nil {
		a.setErrOnce(fmt.Errorf("script input UTxO is invalid: %w", err))
		return a
	}
	a.isEstimateRequired = true
	a.preselectedUtxos = append(a.preselectedUtxos, utxo)
	ref := utxoRef(utxo)
	a.redeemers[ref] = redeemerEntry{
		Tag:     common.RedeemerTagSpend,
		Data:    redeemer,
		ExUnits: exUnits,
	}
	return a
}

// PayToContract creates a payment to a script address with an inline datum.
func (a *Apollo) PayToContract(addr common.Address, datum *common.Datum, lovelace int64, units ...Unit) *Apollo {
	p := &Payment{
		Receiver: addr,
		Lovelace: lovelace,
		Units:    units,
		Datum:    datum,
		IsInline: true,
	}
	a.payments = append(a.payments, p)
	return a
}

// PayToContractWithDatumHash creates a payment to a script address with a datum hash.
// The datum is added to the witness set and its hash is placed in the output.
func (a *Apollo) PayToContractWithDatumHash(addr common.Address, datum *common.Datum, lovelace int64, units ...Unit) (*Apollo, error) {
	p := &Payment{
		Receiver: addr,
		Lovelace: lovelace,
		Units:    units,
	}
	if datum != nil {
		// Hash the bytes the datum will occupy in the witness set, so the
		// output's datum hash matches the datum the ledger sees.
		hash, err := DatumHash(datum)
		if err != nil {
			return a, err
		}
		p.DatumHash = hash.Bytes()
		a.datums = append(a.datums, *datum)
	}
	a.payments = append(a.payments, p)
	return a, nil
}

// resolveCredential resolves a credential from various input types.
// Accepts: *common.Credential, common.Credential, common.Address, string (bech32), or nil (wallet fallback).
func (a *Apollo) resolveCredential(v any) (common.Credential, error) {
	switch val := v.(type) {
	case *common.Credential:
		if val != nil {
			return *val, nil
		}
		return a.GetStakeCredentialFromWallet()
	case common.Credential:
		return val, nil
	case common.Address:
		return GetStakeCredentialFromAddress(val)
	case string:
		// ParseAddress rather than common.NewAddress: the latter treats a
		// bech32 checksum failure as a reason to try base58, and Shelley
		// addresses are entirely base58-legal, so a corrupted address would
		// decode to an unrelated credential instead of failing.
		addr, err := ParseAddress(val)
		if err != nil {
			return common.Credential{}, fmt.Errorf("invalid address: %w", err)
		}
		return GetStakeCredentialFromAddress(addr)
	case nil:
		return a.GetStakeCredentialFromWallet()
	default:
		return common.Credential{}, fmt.Errorf("unsupported credential type: %T", v)
	}
}

func (a *Apollo) hasScriptHash(hash string) bool {
	return slices.Contains(a.scriptHashes, hash)
}

// --- Convenience Payment Methods ---

// PayToAddress creates a simple payment to an address.
func (a *Apollo) PayToAddress(addr common.Address, lovelace int64, units ...Unit) *Apollo {
	p := &Payment{
		Receiver: addr,
		Lovelace: lovelace,
		Units:    units,
	}
	a.payments = append(a.payments, p)
	return a
}

// PayToAddressWithReferenceScript pays to address with a reference script attached.
// The script type is detected automatically. Plutus V4 reference scripts
// require Dijkstra-era transaction support and are rejected by this
// Conway-era builder.
func (a *Apollo) PayToAddressWithReferenceScript(addr common.Address, lovelace int64, script common.Script, units ...Unit) (*Apollo, error) {
	if isPlutusV4Script(script) {
		return a, ErrPlutusV4RequiresDijkstra
	}
	ref, err := NewScriptRef(script)
	if err != nil {
		return a, fmt.Errorf("failed to create script ref: %w", err)
	}
	p := &Payment{Receiver: addr, Lovelace: lovelace, Units: units, ScriptRef: ref}
	a.payments = append(a.payments, p)
	return a, nil
}

// --- UTxO Consumption Methods ---

// ConsumeUTxO adds a utxo as input, deducts payments, and returns remainder as change.
func (a *Apollo) ConsumeUTxO(utxo common.Utxo, payments ...PaymentI) (*Apollo, error) {
	utxoVal, err := a.utxoValue(utxo)
	if err != nil {
		return a, fmt.Errorf("failed to read UTxO value: %w", err)
	}
	totalPayments := Value{}
	for _, p := range payments {
		pv, err := p.ToValue()
		if err != nil {
			return a, fmt.Errorf("failed to compute payment value: %w", err)
		}
		totalPayments, err = totalPayments.Add(pv)
		if err != nil {
			return a, fmt.Errorf("payment value overflow: %w", err)
		}
	}

	remainder, err := utxoVal.Sub(totalPayments)
	if err != nil {
		return a, fmt.Errorf("UTxO value insufficient for payments: %w", err)
	}
	if remainder.Coin > 0 || remainder.HasAssets() {
		if a.wallet == nil {
			return a, errors.New("wallet required to receive UTxO remainder")
		}
	}

	// Mutate state only after all validation succeeds.
	a.preselectedUtxos = append(a.preselectedUtxos, utxo)
	a.payments = append(a.payments, payments...)
	if remainder.Coin > 0 || remainder.HasAssets() {
		remainderPayment, err := NewPaymentFromValue(a.wallet.Address(), remainder)
		if err != nil {
			return a, fmt.Errorf("failed to build remainder payment: %w", err)
		}
		a.payments = append(a.payments, remainderPayment)
	}
	return a, nil
}

func (a *Apollo) utxoValue(utxo common.Utxo) (Value, error) {
	if err := validateUtxo(utxo); err != nil {
		return Value{}, err
	}
	v := Value{}
	amt := utxo.Output.Amount()
	if amt != nil {
		if !amt.IsUint64() {
			return Value{}, errors.New("UTxO amount exceeds uint64 range")
		}
		v.Coin = amt.Uint64()
	}
	if utxo.Output.Assets() != nil {
		v.Assets = CloneMultiAsset(utxo.Output.Assets())
	}
	return v, nil
}

// --- Staking Infrastructure ---

// GetStakeCredentialFromWallet extracts a staking credential from the wallet address.
func (a *Apollo) GetStakeCredentialFromWallet() (common.Credential, error) {
	if a.wallet == nil {
		return common.Credential{}, errors.New("no wallet set")
	}
	return GetStakeCredentialFromAddress(a.wallet.Address())
}

// SetCertificates sets the certificates for the transaction.
func (a *Apollo) SetCertificates(certs []common.CertificateWrapper) *Apollo {
	a.certificates = certs
	return a
}

// --- Stake Registration & Deregistration ---

// RegisterStake creates a stake registration certificate.
// credOrAddr can be: *common.Credential, common.Credential, common.Address, string (bech32), or nil (uses wallet).
func (a *Apollo) RegisterStake(credOrAddr any) (*Apollo, error) {
	cred, err := a.resolveCredential(credOrAddr)
	if err != nil {
		return a, err
	}
	cert := common.StakeRegistrationCertificate{
		CertType:        uint(common.CertificateTypeStakeRegistration),
		StakeCredential: cred,
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypeStakeRegistration),
		Certificate: &cert,
	})
	return a, nil
}

// DeregisterStake creates a stake deregistration certificate.
// credOrAddr can be: *common.Credential, common.Credential, common.Address, string (bech32), or nil (uses wallet).
func (a *Apollo) DeregisterStake(credOrAddr any) (*Apollo, error) {
	cred, err := a.resolveCredential(credOrAddr)
	if err != nil {
		return a, err
	}
	cert := common.StakeDeregistrationCertificate{
		CertType:        uint(common.CertificateTypeStakeDeregistration),
		StakeCredential: cred,
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypeStakeDeregistration),
		Certificate: &cert,
	})
	return a, nil
}

// --- Stake Delegation ---

// DelegateStake creates a stake delegation certificate.
// credOrAddr can be: *common.Credential, common.Credential, common.Address, string (bech32), or nil (uses wallet).
func (a *Apollo) DelegateStake(credOrAddr any, poolHash common.Blake2b224) (*Apollo, error) {
	cred, err := a.resolveCredential(credOrAddr)
	if err != nil {
		return a, err
	}
	cert := common.StakeDelegationCertificate{
		CertType:        uint(common.CertificateTypeStakeDelegation),
		StakeCredential: &cred,
		PoolKeyHash:     poolHash,
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypeStakeDelegation),
		Certificate: &cert,
	})
	return a, nil
}

// RegisterAndDelegateStake creates a combined stake registration and delegation certificate.
// credOrAddr can be: *common.Credential, common.Credential, common.Address, string (bech32), or nil (uses wallet).
func (a *Apollo) RegisterAndDelegateStake(credOrAddr any, poolHash common.Blake2b224, coin int64) (*Apollo, error) {
	cred, err := a.resolveCredential(credOrAddr)
	if err != nil {
		return a, err
	}
	cert := common.StakeRegistrationDelegationCertificate{
		CertType:        uint(common.CertificateTypeStakeRegistrationDelegation),
		StakeCredential: cred,
		PoolKeyHash:     poolHash,
		Amount:          coin,
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypeStakeRegistrationDelegation),
		Certificate: &cert,
	})
	return a, nil
}

// --- Vote Delegation ---

// DelegateVote creates a vote delegation certificate.
// credOrAddr can be: *common.Credential, common.Credential, common.Address, string (bech32), or nil (uses wallet).
func (a *Apollo) DelegateVote(credOrAddr any, drep common.Drep) (*Apollo, error) {
	cred, err := a.resolveCredential(credOrAddr)
	if err != nil {
		return a, err
	}
	cert := common.VoteDelegationCertificate{
		CertType:        uint(common.CertificateTypeVoteDelegation),
		StakeCredential: cred,
		Drep:            drep,
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypeVoteDelegation),
		Certificate: &cert,
	})
	return a, nil
}

// DelegateStakeAndVote creates a combined stake+vote delegation certificate.
// credOrAddr can be: *common.Credential, common.Credential, common.Address, string (bech32), or nil (uses wallet).
func (a *Apollo) DelegateStakeAndVote(credOrAddr any, poolHash common.Blake2b224, drep common.Drep) (*Apollo, error) {
	cred, err := a.resolveCredential(credOrAddr)
	if err != nil {
		return a, err
	}
	cert := common.StakeVoteDelegationCertificate{
		CertType:        uint(common.CertificateTypeStakeVoteDelegation),
		StakeCredential: cred,
		PoolKeyHash:     poolHash,
		Drep:            drep,
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypeStakeVoteDelegation),
		Certificate: &cert,
	})
	return a, nil
}

// RegisterAndDelegateVote creates a combined registration+vote delegation certificate.
// credOrAddr can be: *common.Credential, common.Credential, common.Address, string (bech32), or nil (uses wallet).
func (a *Apollo) RegisterAndDelegateVote(credOrAddr any, drep common.Drep, coin int64) (*Apollo, error) {
	cred, err := a.resolveCredential(credOrAddr)
	if err != nil {
		return a, err
	}
	cert := common.VoteRegistrationDelegationCertificate{
		CertType:        uint(common.CertificateTypeVoteRegistrationDelegation),
		StakeCredential: cred,
		Drep:            drep,
		Amount:          coin,
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypeVoteRegistrationDelegation),
		Certificate: &cert,
	})
	return a, nil
}

// RegisterAndDelegateStakeAndVote creates a combined registration+stake+vote delegation certificate.
// credOrAddr can be: *common.Credential, common.Credential, common.Address, string (bech32), or nil (uses wallet).
func (a *Apollo) RegisterAndDelegateStakeAndVote(credOrAddr any, poolHash common.Blake2b224, drep common.Drep, coin int64) (*Apollo, error) {
	cred, err := a.resolveCredential(credOrAddr)
	if err != nil {
		return a, err
	}
	cert := common.StakeVoteRegistrationDelegationCertificate{
		CertType:        uint(common.CertificateTypeStakeVoteRegistrationDelegation),
		StakeCredential: cred,
		PoolKeyHash:     poolHash,
		Drep:            drep,
		Amount:          coin,
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypeStakeVoteRegistrationDelegation),
		Certificate: &cert,
	})
	return a, nil
}

// --- Pool Operations ---

// RegisterPool adds a pool registration certificate.
func (a *Apollo) RegisterPool(params common.PoolRegistrationCertificate) *Apollo {
	if params.Margin.Rat == nil || params.Margin.Denom().Sign() == 0 {
		a.setErrOnce(errors.New("RegisterPool: margin must not be nil or have a zero denominator"))
		return a
	}
	params.CertType = uint(common.CertificateTypePoolRegistration)
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypePoolRegistration),
		Certificate: &params,
	})
	return a
}

// RegisterDRep adds a DRep registration certificate.
func (a *Apollo) RegisterDRep(cred common.Credential, coin int64, anchor *common.GovAnchor) *Apollo {
	if coin < 0 {
		a.setErrOnce(errors.New("RegisterDRep: coin must be non-negative"))
		return a
	}
	cert := common.RegistrationDrepCertificate{
		CertType:       uint(common.CertificateTypeRegistrationDrep),
		DrepCredential: cred,
		Amount:         coin,
		Anchor:         cloneGovAnchor(anchor),
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypeRegistrationDrep),
		Certificate: &cert,
	})
	return a
}

// RetireDRep adds a DRep deregistration certificate.
func (a *Apollo) RetireDRep(cred common.Credential, coin int64) *Apollo {
	if coin < 0 {
		a.setErrOnce(errors.New("RetireDRep: coin must be non-negative"))
		return a
	}
	cert := common.DeregistrationDrepCertificate{
		CertType:       uint(common.CertificateTypeDeregistrationDrep),
		DrepCredential: cred,
		Amount:         coin,
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypeDeregistrationDrep),
		Certificate: &cert,
	})
	return a
}

// UpdateDRep adds a DRep update certificate.
func (a *Apollo) UpdateDRep(cred common.Credential, anchor *common.GovAnchor) *Apollo {
	cert := common.UpdateDrepCertificate{
		CertType:       uint(common.CertificateTypeUpdateDrep),
		DrepCredential: cred,
		Anchor:         cloneGovAnchor(anchor),
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypeUpdateDrep),
		Certificate: &cert,
	})
	return a
}

// AuthorizeCommitteeHotKey adds a committee hot key authorization certificate.
func (a *Apollo) AuthorizeCommitteeHotKey(cold common.Credential, hot common.Credential) *Apollo {
	cert := common.AuthCommitteeHotCertificate{
		CertType:       uint(common.CertificateTypeAuthCommitteeHot),
		ColdCredential: cold,
		HotCredential:  hot,
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypeAuthCommitteeHot),
		Certificate: &cert,
	})
	return a
}

// ResignCommitteeColdKey adds a committee cold key resignation certificate.
func (a *Apollo) ResignCommitteeColdKey(cold common.Credential, anchor *common.GovAnchor) *Apollo {
	cert := common.ResignCommitteeColdCertificate{
		CertType:       uint(common.CertificateTypeResignCommitteeCold),
		ColdCredential: cold,
		Anchor:         cloneGovAnchor(anchor),
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypeResignCommitteeCold),
		Certificate: &cert,
	})
	return a
}

// DeregisterPool adds a pool retirement certificate.
func (a *Apollo) DeregisterPool(poolHash common.Blake2b224, epoch uint64) *Apollo {
	cert := common.PoolRetirementCertificate{
		CertType:    uint(common.CertificateTypePoolRetirement),
		PoolKeyHash: poolHash,
		Epoch:       epoch,
	}
	a.certificates = append(a.certificates, common.CertificateWrapper{
		Type:        uint(common.CertificateTypePoolRetirement),
		Certificate: &cert,
	})
	return a
}

// --- Withdrawals ---

// AddWithdrawal adds a staking reward withdrawal to the transaction.
// For script-based withdrawals, provide a redeemer and execution units.
func (a *Apollo) AddWithdrawal(address common.Address, amount uint64, redeemerData *common.Datum, exUnits *common.ExUnits) *Apollo {
	a.initState()
	rewardAddress, err := withdrawalRewardAddress(address)
	if err != nil {
		a.setErrOnce(err)
		return a
	}
	wdKey := rewardAddress.String()
	if existing, ok := a.withdrawals[wdKey]; ok {
		if math.MaxUint64-existing.Amount < amount {
			a.setErrOnce(fmt.Errorf("withdrawal amount overflow for %s", wdKey))
			return a
		}
		amount += existing.Amount
	}
	a.withdrawals[wdKey] = withdrawalEntry{Address: rewardAddress, Amount: amount}
	if redeemerData != nil {
		skh := rewardAddress.StakeKeyHash()
		if skh == (common.Blake2b224{}) {
			a.setErrOnce(fmt.Errorf("withdrawal redeemer requires stake credential for %s", wdKey))
			return a
		}
		key := hex.EncodeToString(skh.Bytes())
		entry := redeemerEntry{
			Tag:  common.RedeemerTagReward,
			Data: *redeemerData,
		}
		if exUnits != nil {
			entry.ExUnits = *exUnits
		}
		if existing, ok := a.stakeRedeemers[key]; ok && !redeemerEntriesEqual(existing, entry) {
			a.setErrOnce(fmt.Errorf("conflicting withdrawal redeemer for %s", wdKey))
			return a
		}
		a.stakeRedeemers[key] = entry
		a.isEstimateRequired = true
	}
	return a
}

// withdrawalRewardAddress returns the canonical reward account represented by
// address. Reward addresses are preserved; base addresses are reduced to their
// staking credential. Enterprise, pointer, and Byron addresses have no staking
// credential suitable for a withdrawal.
func withdrawalRewardAddress(address common.Address) (common.Address, error) {
	switch address.Type() {
	case common.AddressTypeNoneKey, common.AddressTypeNoneScript:
		return address, nil
	}

	credential, ok := address.StakeCredential()
	if !ok {
		return common.Address{}, fmt.Errorf(
			"withdrawal address %q does not contain a staking credential",
			address.String(),
		)
	}

	var addressType uint8
	switch credential.CredType {
	case common.CredentialTypeAddrKeyHash:
		addressType = common.AddressTypeNoneKey
	case common.CredentialTypeScriptHash:
		addressType = common.AddressTypeNoneScript
	default:
		return common.Address{}, fmt.Errorf(
			"withdrawal address %q has an unsupported staking credential",
			address.String(),
		)
	}
	networkID := address.NetworkId()
	if networkID > math.MaxUint8 {
		return common.Address{}, fmt.Errorf(
			"withdrawal address %q has an invalid network ID %d",
			address.String(),
			networkID,
		)
	}
	rewardAddress, err := common.NewAddressFromParts(
		addressType,
		uint8(networkID),
		nil,
		credential.Credential.Bytes(),
	)
	if err != nil {
		return common.Address{}, fmt.Errorf("failed to build withdrawal reward address: %w", err)
	}
	return rewardAddress, nil
}

// --- Metadata ---

// SetShelleyMetadata sets transaction metadata from a key-value map.
func (a *Apollo) SetShelleyMetadata(metadata map[uint64]any) *Apollo {
	a.auxiliaryData = &auxData{metadata: metadata}
	return a
}

// SetShelleyMetadataFromJSON parses cardano-cli no-schema metadata JSON and sets it.
func (a *Apollo) SetShelleyMetadataFromJSON(jsonData []byte) (*Apollo, error) {
	return a.SetShelleyMetadataFromJSONWithSchema(jsonData, MetadataJSONNoSchema)
}

// SetShelleyMetadataFromJSONWithSchema parses metadata JSON with the selected schema and sets it.
func (a *Apollo) SetShelleyMetadataFromJSONWithSchema(jsonData []byte, schema MetadataJSONSchema) (*Apollo, error) {
	metadata, err := ShelleyMetadataFromJSONWithSchema(jsonData, schema)
	if err != nil {
		return a, err
	}
	a.SetShelleyMetadata(metadata)
	return a, nil
}

// SetCurrentTreasuryValue sets the Conway current treasury value field.
func (a *Apollo) SetCurrentTreasuryValue(value int64) *Apollo {
	if value < 0 {
		a.setErrOnce(errors.New("SetCurrentTreasuryValue: value must be non-negative"))
		return a
	}
	a.currentTreasury = value
	return a
}

// AddTreasuryDonation adds to the Conway treasury donation amount.
func (a *Apollo) AddTreasuryDonation(amount int64) *Apollo {
	if amount < 0 {
		a.setErrOnce(errors.New("AddTreasuryDonation: amount must be non-negative"))
		return a
	}
	if math.MaxInt64-a.treasuryDonation < amount {
		a.setErrOnce(errors.New("AddTreasuryDonation: donation amount overflow"))
		return a
	}
	a.treasuryDonation += amount
	return a
}

// AddVote adds or replaces a Conway governance vote for a voter/action pair.
func (a *Apollo) AddVote(voter common.Voter, actionId common.GovActionId, procedure common.VotingProcedure) *Apollo {
	if a.votingProcedures == nil {
		a.votingProcedures = make(common.VotingProcedures)
	}
	procedure.Anchor = cloneGovAnchor(procedure.Anchor)
	voterKey := findVotingProcedureVoter(a.votingProcedures, voter)
	if voterKey == nil {
		voterCopy := voter
		voterKey = &voterCopy
		a.votingProcedures[voterKey] = make(map[*common.GovActionId]common.VotingProcedure)
	}
	actionVotes := a.votingProcedures[voterKey]
	if actionVotes == nil {
		actionVotes = make(map[*common.GovActionId]common.VotingProcedure)
		a.votingProcedures[voterKey] = actionVotes
	}
	actionKey := findVotingProcedureAction(actionVotes, actionId)
	if actionKey == nil {
		actionCopy := actionId
		actionKey = &actionCopy
	}
	actionVotes[actionKey] = procedure
	return a
}

// AddProposal adds a Conway governance proposal procedure.
func (a *Apollo) AddProposal(proposal conway.ConwayProposalProcedure) *Apollo {
	proposal.PPAnchor = *cloneGovAnchor(&proposal.PPAnchor)
	a.proposalProcedures = append(a.proposalProcedures, proposal)
	return a
}

// --- Signing & Witness Methods ---

// AddVerificationKeyWitness adds a VKey witness to the transaction.
func (a *Apollo) AddVerificationKeyWitness(witness common.VkeyWitness) (*Apollo, error) {
	if a.tx == nil {
		return a, errors.New("transaction not built - call Complete() first")
	}
	var witnesses []common.VkeyWitness
	if existing := a.tx.WitnessSet.VkeyWitnesses.Items(); existing != nil {
		witnesses = existing
	}
	witnesses = append(witnesses, witness)
	a.tx.WitnessSet.VkeyWitnesses = cbor.NewSetType(witnesses, true)
	return a, nil
}

// SignWithSkey signs the transaction with a raw secret key.
func (a *Apollo) SignWithSkey(skey []byte) (*Apollo, error) {
	if a.tx == nil {
		return a, errors.New("transaction not built - call Complete() first")
	}
	bodyCbor, err := cbor.Encode(&a.tx.Body)
	if err != nil {
		return a, fmt.Errorf("failed to encode tx body: %w", err)
	}
	a.tx.Body.SetCbor(bodyCbor)
	// Hash the freshly encoded body directly; Body.Id() caches its hash and
	// SetCbor does not invalidate the cache, so it could return a stale digest
	// if the body was mutated after a previous Id() call.
	txHash := common.Blake2b256Hash(bodyCbor)

	witness, err := NewVkeyWitnessFromSkey(txHash, skey)
	if err != nil {
		return a, err
	}
	return a.AddVerificationKeyWitness(witness)
}

// --- Collateral ---

// SetCollateralAmount sets the target collateral amount.
func (a *Apollo) SetCollateralAmount(amount int64) *Apollo {
	if amount < 0 {
		a.setErrOnce(errors.New("SetCollateralAmount: amount must be non-negative"))
		return a
	}
	a.collateralAmount = amount
	return a
}

// --- Transaction Loading & Utility Methods ---

// LoadTxCbor loads a transaction from hex-encoded CBOR.
func (a *Apollo) LoadTxCbor(txCbor string) (*Apollo, error) {
	txBytes, err := hex.DecodeString(txCbor)
	if err != nil {
		return a, fmt.Errorf("invalid hex: %w", err)
	}
	var tx conway.ConwayTransaction
	if _, err := cbor.Decode(txBytes, &tx); err != nil {
		return a, fmt.Errorf("failed to decode transaction: %w", err)
	}
	a.tx = &tx
	return a, nil
}

// Clone returns a deep copy of builder-owned state. Injected collaborators
// (the chain context, wallet, coin selector, and evaluation witness providers)
// are retained so the clone preserves the original builder's behavior.
func (a *Apollo) Clone() *Apollo {
	clone := &Apollo{
		Context:                    a.Context,
		requestContext:             a.requestContext,
		isEstimateRequired:         a.isEstimateRequired,
		Fee:                        a.Fee,
		FeePadding:                 a.FeePadding,
		forceFee:                   a.forceFee,
		Ttl:                        a.Ttl,
		ValidityStart:              a.ValidityStart,
		totalCollateral:            a.totalCollateral,
		collateralAmount:           a.collateralAmount,
		collateralOverlapRef:       a.collateralOverlapRef,
		collateralAutoSelected:     a.collateralAutoSelected,
		currentTreasury:            a.currentTreasury,
		treasuryDonation:           a.treasuryDonation,
		estimateExUnits:            a.estimateExUnits,
		coinSelector:               a.coinSelector,
		wallet:                     a.wallet,
		evaluationWitnessProviders: append([]EvaluationWitnessProvider(nil), a.evaluationWitnessProviders...),
		err:                        a.err,
		redeemers:                  make(map[string]redeemerEntry),
		stakeRedeemers:             make(map[string]redeemerEntry),
		mintRedeemers:              make(map[string]redeemerEntry),
		withdrawals:                make(map[string]withdrawalEntry),
	}
	for _, p := range a.payments {
		if pp, ok := p.(*Payment); ok {
			if pp == nil {
				clone.setErrOnce(errors.New("clone payment: payment must not be nil"))
				clone.payments = append(clone.payments, p)
				continue
			}
			cp := *pp
			if len(pp.Units) > 0 {
				cp.Units = make([]Unit, len(pp.Units))
				copy(cp.Units, pp.Units)
			}
			if len(pp.DatumHash) > 0 {
				cp.DatumHash = make([]byte, len(pp.DatumHash))
				copy(cp.DatumHash, pp.DatumHash)
			}
			if pp.Datum != nil {
				var datum common.Datum
				if err := cloneCBORValue(*pp.Datum, &datum); err != nil {
					clone.setErrOnce(fmt.Errorf("clone payment datum: %w", err))
				} else {
					cp.Datum = &datum
				}
			}
			if pp.ScriptRef != nil {
				var scriptRef common.ScriptRef
				if err := cloneCBORValue(*pp.ScriptRef, &scriptRef); err != nil {
					clone.setErrOnce(fmt.Errorf("clone payment script reference: %w", err))
				} else {
					cp.ScriptRef = &scriptRef
				}
			}
			clone.payments = append(clone.payments, &cp)
		} else if cloner, ok := p.(PaymentCloner); ok {
			clonedPayment, err := cloner.ClonePayment()
			if err != nil {
				clone.setErrOnce(fmt.Errorf("clone custom payment: %w", err))
			}
			if clonedPayment == nil {
				clone.setErrOnce(errors.New("clone custom payment: ClonePayment returned nil"))
			}
			clone.payments = append(clone.payments, clonedPayment)
		} else {
			clone.setErrOnce(fmt.Errorf(
				"clone custom payment %T: implement PaymentCloner to support deep cloning",
				p,
			))
			clone.payments = append(clone.payments, p)
		}
	}
	clone.utxos = cloneUtxos(a.utxos, clone, "available")
	clone.preselectedUtxos = cloneUtxos(a.preselectedUtxos, clone, "preselected")
	clone.inputAddresses = append(clone.inputAddresses, a.inputAddresses...)
	for _, datum := range a.datums {
		var datumCopy common.Datum
		if err := cloneCBORValue(datum, &datumCopy); err != nil {
			clone.setErrOnce(fmt.Errorf("clone datum: %w", err))
			continue
		}
		clone.datums = append(clone.datums, datumCopy)
	}
	clone.requiredSigners = append(clone.requiredSigners, a.requiredSigners...)
	for _, script := range a.v1scripts {
		clone.v1scripts = append(clone.v1scripts, slices.Clone(script))
	}
	for _, script := range a.v2scripts {
		clone.v2scripts = append(clone.v2scripts, slices.Clone(script))
	}
	for _, script := range a.v3scripts {
		clone.v3scripts = append(clone.v3scripts, slices.Clone(script))
	}
	clone.mint = append(clone.mint, a.mint...)
	clone.collaterals = cloneUtxos(a.collaterals, clone, "collateral")
	clone.referenceInputs = append(clone.referenceInputs, a.referenceInputs...)
	for _, script := range a.nativescripts {
		var scriptCopy common.NativeScript
		if err := cloneCBORValue(script, &scriptCopy); err != nil {
			clone.setErrOnce(fmt.Errorf("clone native script: %w", err))
			continue
		}
		clone.nativescripts = append(clone.nativescripts, scriptCopy)
	}
	clone.usedUtxos = make(map[string]bool, len(a.usedUtxos))
	maps.Copy(clone.usedUtxos, a.usedUtxos)
	for _, certificate := range a.certificates {
		var certificateCopy common.CertificateWrapper
		if err := cloneCBORValue(certificate, &certificateCopy); err != nil {
			clone.setErrOnce(fmt.Errorf("clone certificate: %w", err))
			continue
		}
		clone.certificates = append(clone.certificates, certificateCopy)
	}
	clone.scriptHashes = append(clone.scriptHashes, a.scriptHashes...)
	for _, proposal := range a.proposalProcedures {
		var proposalCopy conway.ConwayProposalProcedure
		if err := cloneCBORValue(proposal, &proposalCopy); err != nil {
			clone.setErrOnce(fmt.Errorf("clone proposal procedure: %w", err))
			continue
		}
		clone.proposalProcedures = append(clone.proposalProcedures, proposalCopy)
	}
	clone.votingProcedures = cloneVotingProcedures(a.votingProcedures)
	cloneRedeemerMap(a.redeemers, clone.redeemers, clone)
	cloneRedeemerMap(a.stakeRedeemers, clone.stakeRedeemers, clone)
	cloneRedeemerMap(a.mintRedeemers, clone.mintRedeemers, clone)
	maps.Copy(clone.withdrawals, a.withdrawals)
	if a.changeAddress != nil {
		addr := *a.changeAddress
		clone.changeAddress = &addr
	}
	if a.collateralReturn != nil {
		var cr babbage.BabbageTransactionOutput
		if err := cloneCBORValue(*a.collateralReturn, &cr); err != nil {
			clone.setErrOnce(fmt.Errorf("clone collateral return: %w", err))
		} else {
			clone.collateralReturn = &cr
		}
	}
	if a.auxiliaryData != nil {
		clonedMeta := make(map[uint64]any, len(a.auxiliaryData.metadata))
		for key, value := range a.auxiliaryData.metadata {
			clonedMeta[key] = cloneMetadataValue(value, clone)
		}
		clone.auxiliaryData = &auxData{metadata: clonedMeta}
	}
	if a.tx != nil {
		txBytes, err := cbor.Encode(a.tx)
		if err != nil {
			clone.setErrOnce(fmt.Errorf("clone transaction: encode CBOR: %w", err))
		} else {
			var txCopy conway.ConwayTransaction
			if _, err := cbor.Decode(txBytes, &txCopy); err != nil {
				clone.setErrOnce(fmt.Errorf("clone transaction: decode CBOR: %w", err))
			} else {
				clone.tx = &txCopy
			}
		}
	}
	return clone
}

func isNilChainContext(ctx backend.ChainContext) bool {
	if ctx == nil {
		return true
	}
	value := reflect.ValueOf(ctx)
	switch value.Kind() {
	case reflect.Chan, reflect.Func, reflect.Interface, reflect.Map, reflect.Pointer, reflect.Slice:
		return value.IsNil()
	default:
		return false
	}
}

func isNilPayment(payment PaymentI) bool {
	if payment == nil {
		return true
	}
	value := reflect.ValueOf(payment)
	switch value.Kind() {
	case reflect.Chan, reflect.Func, reflect.Interface, reflect.Map, reflect.Pointer, reflect.Slice:
		return value.IsNil()
	default:
		return false
	}
}

func cloneCBORValue(src, dst any) error {
	encoded, err := cbor.Encode(src)
	if err != nil {
		return fmt.Errorf("encode CBOR: %w", err)
	}
	if _, err := cbor.Decode(encoded, dst); err != nil {
		return fmt.Errorf("decode CBOR: %w", err)
	}
	return nil
}

func cloneCBORInterface[T any](src T) (T, error) {
	var zero T
	value := reflect.ValueOf(src)
	if !value.IsValid() {
		return zero, errors.New("value is nil")
	}

	encoded, err := cbor.Encode(src)
	if err != nil {
		return zero, fmt.Errorf("encode CBOR: %w", err)
	}

	valueType := value.Type()
	var target reflect.Value
	if valueType.Kind() == reflect.Pointer {
		target = reflect.New(valueType.Elem())
	} else {
		target = reflect.New(valueType)
	}
	if _, err := cbor.Decode(encoded, target.Interface()); err != nil {
		return zero, fmt.Errorf("decode CBOR: %w", err)
	}

	var candidate any
	if valueType.Kind() == reflect.Pointer {
		candidate = target.Interface()
	} else {
		candidate = target.Elem().Interface()
	}
	cloned, ok := candidate.(T)
	if !ok {
		return zero, fmt.Errorf("cloned CBOR value has unexpected type %T", candidate)
	}
	return cloned, nil
}

func cloneUtxos(src []common.Utxo, owner *Apollo, kind string) []common.Utxo {
	if len(src) == 0 {
		return nil
	}
	dst := make([]common.Utxo, 0, len(src))
	for _, utxo := range src {
		id, err := cloneCBORInterface[common.TransactionInput](utxo.Id)
		if err != nil {
			owner.setErrOnce(fmt.Errorf("clone %s UTxO input: %w", kind, err))
			continue
		}
		output, err := cloneCBORInterface[common.TransactionOutput](utxo.Output)
		if err != nil {
			owner.setErrOnce(fmt.Errorf("clone %s UTxO output: %w", kind, err))
			continue
		}
		dst = append(dst, common.Utxo{Id: id, Output: output})
	}
	return dst
}

func cloneRedeemerMap(src, dst map[string]redeemerEntry, owner *Apollo) {
	for key, entry := range src {
		var datum common.Datum
		if err := cloneCBORValue(entry.Data, &datum); err != nil {
			owner.setErrOnce(fmt.Errorf("clone redeemer %q datum: %w", key, err))
			continue
		}
		entry.Data = datum
		dst[key] = entry
	}
}

func cloneMetadataValue(value any, owner *Apollo) any {
	switch typed := value.(type) {
	case nil, string, int, int64, uint64:
		return typed
	case *big.Int:
		if typed == nil {
			return (*big.Int)(nil)
		}
		return new(big.Int).Set(typed)
	case big.Int:
		return *new(big.Int).Set(&typed)
	case []byte:
		return slices.Clone(typed)
	case MetadataMap:
		cloned := make(MetadataMap, len(typed))
		for i, entry := range typed {
			cloned[i] = MetadataMapEntry{
				Key:   cloneMetadataValue(entry.Key, owner),
				Value: cloneMetadataValue(entry.Value, owner),
			}
		}
		return cloned
	case map[string]any:
		cloned := make(map[string]any, len(typed))
		for key, item := range typed {
			cloned[key] = cloneMetadataValue(item, owner)
		}
		return cloned
	case map[uint64]any:
		cloned := make(map[uint64]any, len(typed))
		for key, item := range typed {
			cloned[key] = cloneMetadataValue(item, owner)
		}
		return cloned
	case []any:
		cloned := make([]any, len(typed))
		for i, item := range typed {
			cloned[i] = cloneMetadataValue(item, owner)
		}
		return cloned
	case common.TransactionMetadatum:
		encoded, err := cbor.Encode(typed)
		if err != nil {
			owner.setErrOnce(fmt.Errorf("clone transaction metadatum: encode CBOR: %w", err))
			return typed
		}
		cloned, err := common.DecodeMetadatumRaw(encoded)
		if err != nil {
			owner.setErrOnce(fmt.Errorf("clone transaction metadatum: decode CBOR: %w", err))
			return typed
		}
		return cloned
	default:
		owner.setErrOnce(fmt.Errorf("clone metadata value: unsupported type %T", value))
		return value
	}
}

// UtxoFromRef looks up a UTxO by transaction hash and index.
func (a *Apollo) UtxoFromRef(txHash string, txIndex int) (*common.Utxo, error) {
	hashBytes, err := hex.DecodeString(txHash)
	if err != nil {
		return nil, fmt.Errorf("invalid tx hash hex: %w", err)
	}
	if len(hashBytes) != common.Blake2b256Size {
		return nil, fmt.Errorf("invalid tx hash length: expected %d bytes, got %d", common.Blake2b256Size, len(hashBytes))
	}
	if txIndex < 0 || uint64(txIndex) > uint64(math.MaxUint32) {
		return nil, fmt.Errorf("tx index must be 0-%d, got %d", uint64(math.MaxUint32), txIndex)
	}
	var hash common.Blake2b256
	copy(hash[:], hashBytes)
	return backend.UtxoByRefContext(a.requestContext, a.Context, hash, uint32(txIndex))
}

// GetUsedUTxOs returns a copy of the used UTxO references.
func (a *Apollo) GetUsedUTxOs() map[string]bool {
	cp := make(map[string]bool, len(a.usedUtxos))
	maps.Copy(cp, a.usedUtxos)
	return cp
}

// GetBurns returns the absolute quantities of all assets being burned
// (negative mint amounts), which must be covered by transaction inputs. Use
// GetMints for the net mint value, which retains negative quantities.
func (a *Apollo) GetBurns() (Value, error) {
	return a.burnRequirementValue()
}

// GetWallet returns the current wallet.
func (a *Apollo) GetWallet() Wallet {
	return a.wallet
}

// Complete performs coin selection, fee estimation, and builds the transaction.
func (a *Apollo) Complete() (*Apollo, error) {
	a.initState()
	if a.err != nil {
		return a, a.err
	}
	if a.tx != nil {
		return a, errors.New("transaction already built - call Complete() only once")
	}
	if a.wallet == nil {
		return a, errors.New("wallet is required to complete transaction")
	}

	// Load UTxOs from input addresses if needed (must happen before collateral selection)
	if err := a.loadUtxos(); err != nil {
		return a, err
	}

	// Every address this transaction commits to must be on the network the
	// chain context is on. Checked here because the wallet, change, input and
	// payment addresses are all resolved by this point, and before any
	// selection or fee work so a cross-network build fails closed and early.
	if err := a.validateAddressNetworks(); err != nil {
		return a, err
	}

	// Auto-select collateral if needed (after UTxOs are loaded)
	if err := a.setCollateral(); err != nil {
		return a, err
	}

	// Build outputs from payments
	outputs, err := a.buildOutputs()
	if err != nil {
		return a, err
	}

	// Calculate total required value
	totalRequired, err := a.totalOutputValue(outputs)
	if err != nil {
		return a, err
	}

	// Adjust for certificate deposits using protocol parameter. Only consult
	// the backend when certificates are present, and fail closed on errors:
	// a silently wrong deposit produces a value-non-conserving transaction.
	stakeDeposit := int64(StakeDeposit)
	poolDeposit := int64(0)
	if len(a.certificates) > 0 {
		pp, ppErr := backend.ProtocolParamsContext(a.requestContext, a.Context)
		if ppErr != nil {
			return a, fmt.Errorf("failed to get protocol params for certificate deposit: %w", ppErr)
		}
		d, dErr := strconv.ParseInt(pp.KeyDeposits, 10, 64)
		if dErr != nil || d < 0 {
			return a, fmt.Errorf("invalid key_deposit protocol parameter %q", pp.KeyDeposits)
		}
		stakeDeposit = d
		poolDeposit, dErr = strconv.ParseInt(pp.PoolDeposits, 10, 64)
		if dErr != nil || poolDeposit < 0 {
			return a, fmt.Errorf("invalid pool_deposit protocol parameter %q", pp.PoolDeposits)
		}
	}
	totalRequired, err = a.adjustForCertificateDeposits(totalRequired, stakeDeposit, poolDeposit)
	if err != nil {
		return a, fmt.Errorf("certificate deposit overflow: %w", err)
	}
	governanceRequired, err := a.governanceRequiredValue()
	if err != nil {
		return a, err
	}
	balanceRequired, err := totalRequired.Add(governanceRequired)
	if err != nil {
		return a, fmt.Errorf("governance value overflow: %w", err)
	}

	// Add preselected UTxO value plus implicit inputs (withdrawals, mints)
	totalInput, err := a.totalPreselectedValue()
	if err != nil {
		return a, err
	}
	if len(a.withdrawals) > 0 {
		totalInput, err = totalInput.Add(a.totalWithdrawalValue())
		if err != nil {
			return a, fmt.Errorf("withdrawal value overflow: %w", err)
		}
	}
	if a.hasMint() {
		mv, err := a.mintValue()
		if err != nil {
			return a, err
		}
		// Only positive mint amounts are implicit inputs for coin selection.
		// Burns (negative amounts) are added to the selection target below so
		// the burned tokens are actually selected from available UTxOs.
		burnValue, err := a.burnRequirementValue()
		if err != nil {
			return a, err
		}
		mintInput, err := mv.Add(burnValue)
		if err != nil {
			return a, fmt.Errorf("mint value overflow: %w", err)
		}
		totalInput, err = totalInput.Add(mintInput)
		if err != nil {
			return a, fmt.Errorf("mint value overflow: %w", err)
		}
	}
	// Certificate deregistration refunds are implicit inputs
	refundValue := a.certificateRefundValue(stakeDeposit, poolDeposit)
	if refundValue.Coin > 0 {
		totalInput, err = totalInput.Add(refundValue)
		if err != nil {
			return a, fmt.Errorf("refund value overflow: %w", err)
		}
	}

	// Estimate a preliminary fee for coin selection so we don't under-select.
	// MaxTxFee covers the size-based fee only; Conway reference-script fees are
	// charged separately, so reserve the known reference-input / pinned-input
	// surcharge before coin selection.
	maxFee, feeErr := backend.MaxTxFeeContext(a.requestContext, a.Context)
	if feeErr != nil {
		return a, fmt.Errorf("failed to compute max tx fee for coin selection: %w", feeErr)
	}
	if maxFee > math.MaxInt64 {
		return a, fmt.Errorf("max tx fee out of range: %d", maxFee)
	}
	prelimFee := int64(maxFee)
	refScriptFeeReserve, err := a.referenceScriptFee(a.preselectedUtxos)
	if err != nil {
		return a, fmt.Errorf("failed to compute reference-script fee reserve for coin selection: %w", err)
	}
	if refScriptFeeReserve > math.MaxInt64-prelimFee {
		return a, fmt.Errorf("preliminary fee overflows int64: max fee=%d reference script fee=%d", prelimFee, refScriptFeeReserve)
	}
	prelimFee += refScriptFeeReserve

	// buildSelectionTarget converts a fee reserve into the value coin selection
	// must cover. Tokens being burned must be present in the inputs: mintValue
	// adds them to totalInput as negative amounts, which selection would
	// otherwise ignore, silently building a transaction that cannot conserve
	// value.
	buildSelectionTarget := func(reserve int64) (Value, error) {
		if reserve < 0 {
			return Value{}, fmt.Errorf("negative fee reserve: %d", reserve)
		}
		target, addErr := balanceRequired.Add(NewSimpleValue(uint64(reserve))) //nolint:gosec // checked non-negative above
		if addErr != nil {
			return Value{}, fmt.Errorf("selection target overflow: %w", addErr)
		}
		if a.hasMint() {
			burnValue, burnErr := a.burnRequirementValue()
			if burnErr != nil {
				return Value{}, burnErr
			}
			target, addErr = target.Add(burnValue)
			if addErr != nil {
				return Value{}, fmt.Errorf("selection target overflow: %w", addErr)
			}
		}
		return target, nil
	}

	// Reserving the full MaxTxFee makes selection refuse wallets that can
	// comfortably afford the transaction: MaxTxFee prices a maximum-size
	// transaction (876277 lovelace on mainnet parameters) while a simple
	// transfer costs nearer 170000, so the top ~0.7 ADA of every wallet was
	// unspendable and reported as "insufficient UTxOs to cover required value".
	//
	// Try a reserve estimated from the shape known so far. If the inputs it
	// selects turn out to need more fee than was reserved, roll the reservation
	// bookkeeping back and re-select against the full MaxTxFee ceiling, which is
	// exactly the previous behaviour -- so this never selects less
	// conservatively than before, it only avoids doing so unnecessarily.
	//
	// A smaller reserve is a strictly smaller selection target, so a failure at
	// the estimated reserve would also fail at the ceiling; such failures are
	// genuine insufficiency and are reported directly.
	// The reserve starts at the fee for the shape known before selection and
	// grows to whatever the selected inputs actually cost, re-selecting each
	// time, until the reserve covers the fee it produces. Growth is monotone and
	// capped at prelimFee, so the loop terminates and the last attempt is always
	// the old ceiling behaviour.
	const maxSelectionAttempts = 3
	reserve := prelimFee
	if initialFee, estErr := a.estimateFee(a.preselectedUtxos, outputs); estErr == nil {
		reserve = initialFee + a.FeePadding
		if reserve < 0 || reserve > prelimFee {
			reserve = prelimFee
		}
	}

	var selectedUtxos []common.Utxo
	for attempt := 0; ; attempt++ {
		selectionTarget, targetErr := buildSelectionTarget(reserve)
		if targetErr != nil {
			return a, targetErr
		}
		preSelectionState := a.snapshotSelectionState()
		selectedUtxos, err = a.selectCoinsAllowingCollateralOverlap(
			selectionTarget,
			totalInput,
		)
		if err != nil {
			return a, fmt.Errorf("coin selection failed: %w", err)
		}
		if reserve >= prelimFee || attempt+1 >= maxSelectionAttempts {
			break
		}

		// Price the shape actually selected. estimateFee already includes the
		// reference-script surcharge for the inputs it is given, so its result
		// is directly comparable to the reserve.
		trialInputs := make(
			[]common.Utxo,
			0,
			len(a.preselectedUtxos)+len(selectedUtxos),
		)
		trialInputs = append(trialInputs, a.preselectedUtxos...)
		trialInputs = append(trialInputs, selectedUtxos...)
		selectedFee, feeEstErr := a.estimateFee(SortInputs(trialInputs), outputs)
		needed := prelimFee
		if feeEstErr == nil {
			needed = selectedFee + a.FeePadding
			if needed < 0 || needed > prelimFee {
				needed = prelimFee
			}
		}
		if needed <= reserve {
			break
		}
		// The reserve was too small for what it selected. Roll the reservation
		// bookkeeping back so the next attempt selects from the same pool.
		a.restoreSelectionState(preSelectionState)
		reserve = needed
	}

	// Build inputs (explicit allocation to avoid slice aliasing)
	allInputUtxos := make([]common.Utxo, 0, len(a.preselectedUtxos)+len(selectedUtxos))
	allInputUtxos = append(allInputUtxos, a.preselectedUtxos...)
	allInputUtxos = append(allInputUtxos, selectedUtxos...)
	allInputUtxos = SortInputs(allInputUtxos)
	if err := a.validateCollateral(); err != nil {
		return a, err
	}

	// Estimate the initial fee. The balanced evaluation loop below rebuilds the
	// complete transaction shape (change, collateral, and ExUnits) until stable.
	baseOutputs := make([]babbage.BabbageTransactionOutput, len(outputs))
	copy(baseOutputs, outputs)

	var fee int64
	if a.forceFee {
		fee = a.Fee
	} else {
		fee, err = a.estimateFee(allInputUtxos, outputs)
		if err != nil {
			return a, fmt.Errorf("fee estimation failed: %w", err)
		}
		if a.Fee > 0 {
			fee = a.Fee
		}
	}
	fee += a.FeePadding
	if fee < 0 {
		fee = 0
	}

	// Compute totalInput once (it does not change across iterations).
	totalInput, err = a.sumUtxoValues(allInputUtxos)
	if err != nil {
		return a, err
	}
	if a.hasMint() {
		mv, err := a.mintValue()
		if err != nil {
			return a, err
		}
		totalInput, err = totalInput.Add(mv)
		if err != nil {
			return a, err
		}
	}
	// Withdrawals are implicit inputs in Cardano's balance equation
	if len(a.withdrawals) > 0 {
		totalInput, err = totalInput.Add(a.totalWithdrawalValue())
		if err != nil {
			return a, fmt.Errorf("withdrawal value overflow: %w", err)
		}
	}
	// Certificate deregistration refunds are implicit inputs
	if refundValue.Coin > 0 {
		totalInput, err = totalInput.Add(refundValue)
		if err != nil {
			return a, fmt.Errorf("refund value overflow: %w", err)
		}
	}

	balance := balanceContext{
		totalInput:         totalInput,
		totalRequired:      totalRequired,
		governanceRequired: governanceRequired,
		stakeDeposit:       stakeDeposit,
		changeAddress:      a.getChangeAddress(),
	}
	const maxEvaluationIterations = 5
	var previousShape string
	seenShapes := make(map[string]struct{}, maxEvaluationIterations)
	converged := false
	// requestedFee is the size-based fee that drives the iteration.
	// buildBalancedOutputs may return a larger fee than it was given, by
	// absorbing sub-min-UTxO ADA change into it and dropping the change
	// output. That surcharge is not something estimateFee can predict from the
	// resulting outputs, so convergence is judged on requestedFee while fee
	// carries the amount actually charged. Comparing the absorbed fee against
	// a fresh estimate instead never terminates.
	requestedFee := fee
	for range maxEvaluationIterations {
		balanced, balanceErr := a.buildBalancedOutputs(
			baseOutputs,
			requestedFee,
			balance,
		)
		if balanceErr != nil {
			return a, balanceErr
		}
		outputs, fee = balanced.Outputs, balanced.Fee
		if err := a.finalizeCollateral(fee); err != nil {
			return a, err
		}

		if a.isEstimateRequired && a.estimateExUnits {
			units, evalErr := a.estimateExecutionUnits(allInputUtxos, outputs, fee)
			if evalErr != nil {
				return a, fmt.Errorf("ExUnit estimation failed: %w", evalErr)
			}
			a.applyExecutionUnits(units, allInputUtxos)
		}

		if fee < 0 {
			return a, fmt.Errorf("negative fee: %d", fee)
		}
		body, bodyErr := a.buildBody(allInputUtxos, outputs, uint64(fee)) //nolint:gosec // validated non-negative above
		if bodyErr != nil {
			return a, bodyErr
		}
		bodyBytes, bodyErr := cbor.Encode(&body)
		if bodyErr != nil {
			return a, fmt.Errorf("failed to encode evaluation shape: %w", bodyErr)
		}
		shape := string(bodyBytes)
		nextFee := requestedFee
		if !a.forceFee && a.Fee == 0 {
			nextFee, err = a.estimateFee(allInputUtxos, outputs)
			if err != nil {
				return a, fmt.Errorf("fee re-estimation failed: %w", err)
			}
			nextFee += a.FeePadding
			if nextFee < 0 {
				nextFee = 0
			}
		}
		// Never settle on a fee below one already required by a shape that was
		// considered. Around the change output's min-UTxO threshold the same
		// transaction is bistable: at the lower fee the change clears min-UTxO
		// and is emitted, which pushes the size-based fee up; at the higher fee
		// the change falls below min-UTxO and is absorbed, which pulls the
		// estimate back down. Allowing the fee to move downward alternates
		// between those two shapes indefinitely, and the cheaper of them
		// underpays its own size. Moving only upward terminates and never
		// underpays.
		if nextFee < requestedFee {
			nextFee = requestedFee
		}
		if nextFee == requestedFee && previousShape == shape {
			converged = true
			break
		}
		if _, seen := seenShapes[shape]; seen {
			return a, errors.New("evaluation transaction did not converge after 5 iterations")
		}
		seenShapes[shape] = struct{}{}
		previousShape = shape
		requestedFee = nextFee
	}
	if !converged {
		return a, errors.New("evaluation transaction did not converge after 5 iterations")
	}

	// Build transaction body
	body, err := a.buildBody(allInputUtxos, outputs, uint64(fee))
	if err != nil {
		return a, err
	}

	// Build witness set
	witnessSet := a.buildWitnessSet(allInputUtxos)

	// Assemble transaction
	a.tx = &conway.ConwayTransaction{
		Body:       body,
		WitnessSet: witnessSet,
		TxIsValid:  true,
	}

	// Set metadata if present
	if a.auxiliaryData != nil {
		md, mdErr := a.buildMetadata()
		if mdErr != nil {
			return a, fmt.Errorf("failed to build metadata: %w", mdErr)
		}
		if md != nil {
			a.tx.TxMetadata = md
		}
	}
	pp, ppErr := backend.ProtocolParamsContext(a.requestContext, a.Context)
	if ppErr != nil {
		return a, fmt.Errorf("failed to get protocol params for transaction size validation: %w", ppErr)
	}
	if pp.MaxTxSize > 0 {
		txBytes, encErr := cbor.Encode(a.tx)
		if encErr != nil {
			return a, fmt.Errorf("failed to encode completed transaction: %w", encErr)
		}
		if len(txBytes) > pp.MaxTxSize {
			return a, fmt.Errorf("transaction size %d exceeds max_tx_size %d", len(txBytes), pp.MaxTxSize)
		}
	}
	if err := validateOutputValueSizes(a.tx.Body.TxOutputs, pp); err != nil {
		return a, err
	}

	return a, nil
}

// validateOutputValueSizes rejects any output whose serialized value exceeds
// max_val_size.
//
// The ledger bounds the value portion of an output, not the whole output, so a
// wallet holding many native assets can produce a change output the node
// refuses even though the transaction as a whole is within max_tx_size.
// Reporting it here names the offending output instead of leaving the caller
// with an OutputTooBigUTxO rejection after submission.
func validateOutputValueSizes(
	outputs []babbage.BabbageTransactionOutput,
	pp backend.ProtocolParameters,
) error {
	if pp.MaxValSize == "" {
		return nil
	}
	maxValSize, err := strconv.ParseInt(pp.MaxValSize, 10, 64)
	if err != nil {
		return fmt.Errorf("invalid max_val_size %q: %w", pp.MaxValSize, err)
	}
	if maxValSize <= 0 {
		return nil
	}
	for i := range outputs {
		valueBytes, err := cbor.Encode(outputs[i].OutputAmount)
		if err != nil {
			return fmt.Errorf("failed to encode output %d value: %w", i, err)
		}
		if int64(len(valueBytes)) > maxValSize {
			return fmt.Errorf(
				"output %d value size %d exceeds max_val_size %d; "+
					"split the native assets across more outputs",
				i, len(valueBytes), maxValSize,
			)
		}
	}
	return nil
}

// Sign signs the transaction with the wallet.
func (a *Apollo) Sign() (*Apollo, error) {
	if a.tx == nil {
		return a, errors.New("transaction not built - call Complete() first")
	}
	if a.wallet == nil {
		return a, errors.New("no wallet set")
	}

	// Marshal body to CBOR and set it for downstream consumers
	bodyCbor, err := cbor.Encode(&a.tx.Body)
	if err != nil {
		return a, fmt.Errorf("failed to encode tx body: %w", err)
	}
	a.tx.Body.SetCbor(bodyCbor)

	// Hash the freshly encoded body directly; Body.Id() caches its hash and
	// SetCbor does not invalidate the cache, so it could return a stale digest
	// if the body was mutated after a previous Id() call.
	txHash := common.Blake2b256Hash(bodyCbor)

	witness, err := a.wallet.SignTxBody(txHash)
	if err != nil {
		return a, fmt.Errorf("signing failed: %w", err)
	}

	var witnesses []common.VkeyWitness
	if existing := a.tx.WitnessSet.VkeyWitnesses.Items(); existing != nil {
		witnesses = existing
	}
	witnesses = append(witnesses, witness)
	a.tx.WitnessSet.VkeyWitnesses = cbor.NewSetType(witnesses, true)
	return a, nil
}

// GetTx returns the built transaction.
//
// Apollo builds Conway transactions, so the concrete Conway type is returned:
// it gives callers every body and witness-set field, including ones no
// era-neutral interface exposes, such as the network id. When Apollo gains
// support for a later era, a sibling accessor is added for it rather than this
// one changing meaning.
//
// The returned transaction is constructed rather than decoded, so its Cbor() is
// empty: gouroboros populates stored CBOR only when unmarshalling. Use
// GetTxCbor for the encoding, which is produced fresh on each call and so
// cannot go stale when Sign adds witnesses.
func (a *Apollo) GetTx() *conway.ConwayTransaction {
	return a.tx
}

// GetTxCbor returns the CBOR-encoded transaction.
func (a *Apollo) GetTxCbor() ([]byte, error) {
	if a.tx == nil {
		return nil, errors.New("no transaction built")
	}
	return cbor.Encode(a.tx)
}

// Submit submits the transaction to the chain.
func (a *Apollo) Submit() (common.Blake2b256, error) {
	txCbor, err := a.GetTxCbor()
	if err != nil {
		return common.Blake2b256{}, err
	}
	return backend.SubmitTxContext(a.requestContext, a.Context, txCbor)
}

// --- internal helpers ---

func (a *Apollo) loadUtxos() error {
	for _, addr := range a.inputAddresses {
		utxos, err := backend.UtxosContext(a.requestContext, a.Context, addr)
		if err != nil {
			return fmt.Errorf("failed to load UTxOs for %s: %w", addr.String(), err)
		}
		if err := validateUtxos(utxos); err != nil {
			return fmt.Errorf("failed to load UTxOs for %s: %w", addr.String(), err)
		}
		a.utxos = append(a.utxos, utxos...)
	}
	// If no UTxOs loaded and wallet is set, load from wallet address
	if len(a.utxos) == 0 && len(a.preselectedUtxos) == 0 && a.wallet != nil {
		utxos, err := backend.UtxosContext(a.requestContext, a.Context, a.wallet.Address())
		if err != nil {
			return fmt.Errorf("failed to load wallet UTxOs: %w", err)
		}
		if err := validateUtxos(utxos); err != nil {
			return fmt.Errorf("failed to load wallet UTxOs: %w", err)
		}
		a.utxos = utxos
	}
	return nil
}

func (a *Apollo) buildOutputs() ([]babbage.BabbageTransactionOutput, error) {
	outputs := make([]babbage.BabbageTransactionOutput, 0, len(a.payments))
	for _, payment := range a.payments {
		if err := payment.EnsureMinUTXO(backend.BindContext(a.requestContext, a.Context)); err != nil {
			return nil, fmt.Errorf("failed to ensure min UTxO: %w", err)
		}
		txOut, err := payment.ToTxOut()
		if err != nil {
			return nil, fmt.Errorf("failed to build payment output: %w", err)
		}
		babbageOut, err := babbageOutputOf(txOut)
		if err != nil {
			return nil, err
		}
		outputs = append(outputs, *babbageOut)
	}
	return outputs, nil
}

func (a *Apollo) totalOutputValue(outputs []babbage.BabbageTransactionOutput) (Value, error) {
	total := Value{}
	for _, out := range outputs {
		var err error
		total, err = total.Add(ValueFromMaryValue(out.OutputAmount))
		if err != nil {
			return Value{}, fmt.Errorf("output value overflow: %w", err)
		}
	}
	return total, nil
}

func (a *Apollo) totalPreselectedValue() (Value, error) {
	return a.sumUtxoValues(a.preselectedUtxos)
}

func (a *Apollo) sumUtxoValues(utxos []common.Utxo) (Value, error) {
	total := Value{}
	for _, utxo := range utxos {
		if err := validateUtxo(utxo); err != nil {
			return Value{}, err
		}
		amt := utxo.Output.Amount()
		// Amounts come from a remote backend; reject anything outside the
		// uint64 lovelace range instead of silently treating it as zero.
		if amt == nil || !amt.IsUint64() {
			return Value{}, fmt.Errorf("UTxO %s has an invalid lovelace amount", utxoRef(utxo))
		}
		sum := total.Coin + amt.Uint64()
		if sum < total.Coin {
			return Value{}, errors.New("total input value overflows uint64")
		}
		total.Coin = sum
		if utxo.Output.Assets() != nil {
			if total.Assets == nil {
				total.Assets = CloneMultiAsset(utxo.Output.Assets())
			} else {
				total.Assets.Add(utxo.Output.Assets())
			}
		}
	}
	return total, nil
}

// pickSingleInput chooses one UTxO to spend when the balance equation is
// already satisfied by implicit inputs and the transaction only needs a
// non-empty input set. A pure-ADA UTxO is preferred so the change output is not
// forced to carry native assets, and candidates are considered in canonical
// order so the choice is deterministic.
func pickSingleInput(available []common.Utxo) (common.Utxo, error) {
	if len(available) == 0 {
		return common.Utxo{}, errors.New(
			"no available UTxO to spend: a transaction must spend at least one input",
		)
	}
	sorted := SortUtxos(available)
	for _, utxo := range sorted {
		assets := utxo.Output.Assets()
		if assets == nil || len(assets.Policies()) == 0 {
			return utxo, nil
		}
	}
	return sorted[0], nil
}

func (a *Apollo) selectCoins(required, currentInput Value) ([]common.Utxo, error) {
	// Withdrawals, mints, and certificate deposit refunds are implicit inputs
	// in the balance equation, so currentInput can already cover the target
	// with no UTxO being spent at all. The ledger still requires a non-empty
	// input set (InputSetEmptyUTxO), and a transaction that spends nothing also
	// carries no payment-key witness and has nothing establishing its
	// uniqueness. If the caller pinned an input we are already satisfied;
	// otherwise selection must contribute one even though no value is needed.
	covered := currentInput.GreaterOrEqual(required)
	if covered && len(a.preselectedUtxos) > 0 {
		return nil, nil
	}

	// Compute remaining using saturating subtraction rather than Sub,
	// because currentInput may contain extra assets (from preselected UTxOs)
	// that are not in required. Sub would error with "asset underflow" in that case.
	remaining := Value{}
	if required.Coin > currentInput.Coin {
		remaining.Coin = required.Coin - currentInput.Coin
	}
	if required.Assets != nil {
		remaining.Assets = CloneMultiAsset(required.Assets)
		if currentInput.Assets != nil {
			subtractAssetsSaturating(remaining.Assets, currentInput.Assets)
		}
	}

	available := make([]common.Utxo, 0, len(a.utxos))
	for _, utxo := range a.utxos {
		if err := validateUtxo(utxo); err != nil {
			return nil, fmt.Errorf("available UTxO is invalid: %w", err)
		}
		if !a.isUsed(utxoRef(utxo)) {
			available = append(available, utxo)
		}
	}

	var selected []common.Utxo
	if covered {
		// The value is already satisfied, so spend exactly one UTxO purely to
		// satisfy the non-empty input set rule. Prefer a pure-ADA UTxO so the
		// change output does not have to carry native assets it did not need
		// to, and pick deterministically so construction stays reproducible.
		pick, pickErr := pickSingleInput(available)
		if pickErr != nil {
			return nil, pickErr
		}
		selected = []common.Utxo{pick}
	} else {
		selector := a.coinSelector
		if selector == nil {
			selector = defaultCoinSelector
		}
		var selErr error
		selected, selErr = selector.Select(
			a.requestContext,
			available,
			remaining,
		)
		if selErr != nil {
			return nil, selErr
		}
	}
	availableByRef := make(map[string]common.Utxo, len(available))
	for _, utxo := range available {
		availableByRef[utxoRef(utxo)] = utxo
	}
	canonical := make([]common.Utxo, 0, len(selected))
	seen := make(map[string]struct{}, len(selected))
	for _, utxo := range selected {
		if err := backend.ValidateAdditionalUtxo(utxo); err != nil {
			return nil, fmt.Errorf("coin selector returned invalid UTxO: %w", err)
		}
		ref := utxoRef(utxo)
		availableUtxo, ok := availableByRef[ref]
		if !ok {
			return nil, fmt.Errorf("coin selector returned unavailable UTxO %s", ref)
		}
		if _, ok := seen[ref]; ok {
			return nil, fmt.Errorf("coin selector returned duplicate UTxO %s", ref)
		}
		seen[ref] = struct{}{}
		canonical = append(canonical, availableUtxo)
	}
	selectedValue, err := a.sumUtxoValues(canonical)
	if err != nil {
		return nil, fmt.Errorf("coin selector returned invalid selection: %w", err)
	}
	if !selectedValue.GreaterOrEqual(remaining) {
		return nil, errors.New("coin selector returned a selection that does not cover the target")
	}

	// Commit to usedUtxos only on success
	for _, utxo := range canonical {
		a.markUsed(utxoRef(utxo))
	}
	return canonical, nil
}

// estimatedWitnessCount reports how many vkey witnesses the transaction is
// expected to carry, for fee sizing.
//
// Counting only the wallet plus explicitly registered required signers
// undercounts whenever the inputs span more than one payment credential or a
// withdrawal or certificate needs a stake-key signature. Each missing witness
// is around 102 bytes, and the converged fee has no slack, so an undercount
// becomes FeeTooSmallUTxO at submission -- which is what made multi-signature
// flows fail.
//
// Credentials are counted as a set, since one signature covers every input
// under the same key. Script credentials are excluded: they are satisfied by a
// script witness, not a vkey witness. The result never drops below the previous
// estimate, so this can only raise a fee, never lower one.
func (a *Apollo) estimatedWitnessCount(inputs []common.Utxo) int {
	signers := make(map[common.Blake2b224]struct{})
	if a.wallet != nil {
		signers[a.wallet.PubKeyHash()] = struct{}{}
	}
	for _, hash := range a.requiredSigners {
		signers[hash] = struct{}{}
	}
	addPaymentKey := func(utxos []common.Utxo) {
		for _, utxo := range utxos {
			if utxo.Output == nil {
				continue
			}
			addr := utxo.Output.Address()
			switch addr.Type() {
			case common.AddressTypeKeyKey,
				common.AddressTypeKeyScript,
				common.AddressTypeKeyPointer,
				common.AddressTypeKeyNone:
				if hash := addr.PaymentKeyHash(); hash != (common.Blake2b224{}) {
					signers[hash] = struct{}{}
				}
			}
		}
	}
	addPaymentKey(inputs)
	addPaymentKey(a.collaterals)
	// A withdrawal is authorised by the stake credential of its reward address.
	for _, entry := range a.withdrawals {
		if hash := entry.Address.StakeKeyHash(); hash != (common.Blake2b224{}) {
			signers[hash] = struct{}{}
		}
	}
	// Stake certificates are authorised by their stake credential. Script
	// credentials are satisfied by a script witness and must not add a vkey
	// witness to the estimate.
	addStakeCredential := func(credential common.Credential) {
		if credential.CredType == common.CredentialTypeAddrKeyHash &&
			credential.Credential != (common.Blake2b224{}) {
			signers[credential.Credential] = struct{}{}
		}
	}
	for _, wrapper := range a.certificates {
		switch certificate := wrapper.Certificate.(type) {
		case *common.StakeRegistrationCertificate:
			addStakeCredential(certificate.StakeCredential)
		case *common.StakeDeregistrationCertificate:
			addStakeCredential(certificate.StakeCredential)
		case *common.StakeDelegationCertificate:
			if certificate.StakeCredential != nil {
				addStakeCredential(*certificate.StakeCredential)
			}
		case *common.RegistrationCertificate:
			addStakeCredential(certificate.StakeCredential)
		case *common.DeregistrationCertificate:
			addStakeCredential(certificate.StakeCredential)
		case *common.VoteDelegationCertificate:
			addStakeCredential(certificate.StakeCredential)
		case *common.StakeVoteDelegationCertificate:
			addStakeCredential(certificate.StakeCredential)
		case *common.StakeRegistrationDelegationCertificate:
			addStakeCredential(certificate.StakeCredential)
		case *common.VoteRegistrationDelegationCertificate:
			addStakeCredential(certificate.StakeCredential)
		case *common.StakeVoteRegistrationDelegationCertificate:
			addStakeCredential(certificate.StakeCredential)
		}
	}
	count := len(signers)
	// Never estimate below the previous behaviour.
	if previous := 1 + len(a.requiredSigners); count < previous {
		count = previous
	}
	return count
}

func (a *Apollo) estimateFee(inputs []common.Utxo, outputs []babbage.BabbageTransactionOutput) (int64, error) {
	pp, err := backend.ProtocolParamsContext(a.requestContext, a.Context)
	if err != nil {
		return 0, err
	}

	// Build a dummy transaction to estimate size. The fee field (body key 2) is
	// `omitempty`, so a zero fee is dropped entirely and a non-trivial fee is
	// encoded as a multi-byte integer. Sizing against a zero fee therefore
	// undercounts the body by the width of the real fee field (up to ~5 bytes),
	// producing a fee that is a few hundred lovelace short and a FeeTooSmallUTxO
	// rejection. Use a placeholder fee whose CBOR width matches (or exceeds) the
	// final fee so the size — and thus the fee — is not underestimated.
	placeholderFee, feeErr := backend.MaxTxFeeContext(a.requestContext, a.Context)
	if feeErr != nil || placeholderFee == 0 {
		placeholderFee = 2_000_000
	}
	body, err := a.buildBody(inputs, outputs, placeholderFee)
	if err != nil {
		return 0, err
	}
	ws := a.buildWitnessSet(inputs)
	// Add placeholder vkey witnesses so the size estimate accounts for the
	// signatures the transaction will carry.
	witnessCount := a.estimatedWitnessCount(inputs)
	fakeWitnesses := make([]common.VkeyWitness, witnessCount)
	for i := range fakeWitnesses {
		fakeWitnesses[i] = common.VkeyWitness{
			Vkey:      make([]byte, 32),
			Signature: make([]byte, 64),
		}
	}
	ws.VkeyWitnesses = cbor.NewSetType(fakeWitnesses, true)

	dummyTx := conway.ConwayTransaction{
		Body:       body,
		WitnessSet: ws,
		TxIsValid:  true,
	}
	if a.auxiliaryData != nil {
		md, mdErr := a.buildMetadata()
		if mdErr != nil {
			return 0, mdErr
		}
		if md != nil {
			dummyTx.TxMetadata = md
		}
	}

	txBytes, err := cbor.Encode(&dummyTx)
	if err != nil {
		return 0, fmt.Errorf("failed to encode dummy tx: %w", err)
	}

	txSize := len(txBytes)
	fee := int64(txSize)*pp.MinFeeCoefficient + pp.MinFeeConstant

	// Add execution unit costs for script transactions.
	// fee += priceMem * totalExMem + priceStep * totalExSteps
	redeemerMap := a.buildRedeemerMap(inputs)
	if len(redeemerMap) > 0 {
		var totalMem, totalSteps int64
		for _, rv := range redeemerMap {
			totalMem += rv.ExUnits.Memory
			totalSteps += rv.ExUnits.Steps
		}
		exUnitFeeFloat := math.Ceil(float64(pp.PriceMem)*float64(totalMem) + float64(pp.PriceStep)*float64(totalSteps))
		// Out-of-range float-to-int conversion is implementation-defined; reject
		// rather than sign a transaction with a corrupted fee. NaN fails this check too.
		if !(exUnitFeeFloat >= 0 && exUnitFeeFloat < float64(math.MaxInt64)) {
			return 0, errors.New("execution unit fee out of range")
		}
		fee += int64(exUnitFeeFloat)
	}

	// Add the Conway tiered reference-script fee.
	refScriptFee, err := a.referenceScriptFeeWithParams(inputs, pp)
	if err != nil {
		return 0, err
	}
	if refScriptFee > math.MaxInt64-fee {
		return 0, fmt.Errorf("fee overflows int64: base fee=%d reference script fee=%d", fee, refScriptFee)
	}
	fee += refScriptFee

	return fee, nil
}

func (a *Apollo) referenceScriptFee(inputs []common.Utxo) (int64, error) {
	refScriptSize, err := a.totalReferenceScriptSize(inputs)
	if err != nil {
		return 0, err
	}
	if refScriptSize == 0 {
		return 0, nil
	}
	pp, err := backend.ProtocolParamsContext(a.requestContext, a.Context)
	if err != nil {
		return 0, err
	}
	return referenceScriptFeeForSize(refScriptSize, pp)
}

// referenceScriptFeeWithParams computes the Conway tiered reference-script fee.
// Scripts attached (via script_ref) to the outputs of the transaction's spending
// inputs AND reference inputs are priced per byte on a growing tier (native
// scripts included, not only Plutus). The ledger counts the union of regular and
// reference inputs regardless of whether the transaction executes scripts, so
// omitting it produces FeeTooSmallUTxO. The fee is naturally zero when no
// referenced UTxO carries a script.
func (a *Apollo) referenceScriptFeeWithParams(inputs []common.Utxo, pp backend.ProtocolParameters) (int64, error) {
	refScriptSize, err := a.totalReferenceScriptSize(inputs)
	if err != nil {
		return 0, err
	}
	return referenceScriptFeeForSize(refScriptSize, pp)
}

func referenceScriptFeeForSize(refScriptSize int, pp backend.ProtocolParameters) (int64, error) {
	if refScriptSize == 0 {
		return 0, nil
	}
	// The transaction uses reference scripts, so the ledger charges the tiered
	// reference-script fee. If the backend did not supply the base price, charging
	// zero would silently underprice the transaction and produce a FeeTooSmallUTxO
	// rejection at submission; fail loudly instead.
	refFeePerByte := pp.RefScriptFeePerByteRational()
	if refFeePerByte == nil || refFeePerByte.Sign() <= 0 {
		return 0, fmt.Errorf(
			"transaction uses %d bytes of reference scripts but the protocol parameters provide no reference-script price (min_fee_ref_script_cost_per_byte); cannot compute a correct minimum fee",
			refScriptSize,
		)
	}
	return backend.TierRefScriptFeeRational(
		refScriptSize,
		refFeePerByte,
		pp.RefScriptSizeIncrement(),
		pp.RefScriptMultiplierRational(),
	), nil
}

// totalReferenceScriptSize resolves the combined byte size of all reference
// scripts that the ledger prices into the reference-script fee. The ledger
// counts the size of every script attached (via script_ref) to the outputs of
// the transaction's spending inputs AND its reference inputs, including native
// scripts (not only Plutus), so any non-nil script is sized. Duplicate input
// references are de-duplicated (matching the ledger), but distinct outputs that
// happen to carry identical scripts are each counted.
//
// Spending inputs are already resolved by the caller. Reference inputs are
// resolved against the chain context; an undercounted size silently underprices
// the fee and gets the tx rejected, so a reference input that fails to resolve
// is a hard error.
func (a *Apollo) totalReferenceScriptSize(inputs []common.Utxo) (int, error) {
	seen := make(map[string]struct{})
	total := 0

	addScript := func(script common.Script) error {
		if script == nil {
			return nil
		}
		if isPlutusV4Script(script) {
			return ErrPlutusV4RequiresDijkstra
		}
		total += len(script.RawScriptBytes())
		return nil
	}

	// Spending inputs already resolved by the caller carry their outputs.
	for _, utxo := range inputs {
		ref := utxoRef(utxo)
		if _, ok := seen[ref]; ok {
			continue
		}
		seen[ref] = struct{}{}
		if err := addScript(utxo.Output.ScriptRef()); err != nil {
			return 0, err
		}
	}

	// Reference inputs must be resolved against the chain context.
	for _, refInput := range a.referenceInputs {
		ref := hex.EncodeToString(refInput.TxId.Bytes()) + "#" + strconv.FormatUint(uint64(refInput.OutputIndex), 10)
		if _, ok := seen[ref]; ok {
			continue
		}
		seen[ref] = struct{}{}
		utxo, err := backend.UtxoByRefContext(a.requestContext, a.Context, refInput.TxId, refInput.OutputIndex)
		if err != nil {
			return 0, fmt.Errorf(
				"failed to resolve reference input %s for reference-script fee: %w",
				ref, err,
			)
		}
		if utxo == nil {
			return 0, fmt.Errorf("reference input %s not found for reference-script fee", ref)
		}
		if err := addScript(utxo.Output.ScriptRef()); err != nil {
			return 0, err
		}
	}

	return total, nil
}

// estimateExecutionUnits builds a preliminary transaction and evaluates it
// against the chain to get actual execution units for script redeemers.
// The returned ExUnits include a buffer for safety.
func (a *Apollo) estimateExecutionUnits(
	inputs []common.Utxo,
	outputs []babbage.BabbageTransactionOutput,
	fee int64,
) (map[common.RedeemerKey]common.ExUnits, error) {
	// Build preliminary tx with current (possibly zero) ExUnits. The fee field
	// is `omitempty`, so a zero fee is dropped from the CBOR and the body has no
	// fee (key 2). Strict evaluators (Ogmios, and Blockfrost which proxies it)
	// reject such a body with "field fee with key 2, not decoded". Use a
	// non-zero placeholder fee so the field is always present; its value does
	// not affect script evaluation.
	if fee < 0 {
		return nil, fmt.Errorf("negative fee: %d", fee)
	}
	body, err := a.buildBody(inputs, outputs, uint64(fee)) //nolint:gosec // validated non-negative above
	if err != nil {
		return nil, fmt.Errorf("failed to build preliminary tx body: %w", err)
	}
	ws := a.buildWitnessSet(inputs)

	witnesses, err := a.evaluationWitnesses(&body)
	if err != nil {
		return nil, err
	}
	ws.VkeyWitnesses = cbor.NewSetType(witnesses, true)

	prelimTx := conway.ConwayTransaction{
		Body:       body,
		WitnessSet: ws,
		TxIsValid:  true,
	}
	if a.auxiliaryData != nil {
		md, mdErr := a.buildMetadata()
		if mdErr != nil {
			return nil, mdErr
		}
		if md != nil {
			prelimTx.TxMetadata = md
		}
	}
	txBytes, err := cbor.Encode(&prelimTx)
	if err != nil {
		return nil, fmt.Errorf("failed to encode preliminary tx: %w", err)
	}

	// Only backends reporting CapabilityEvaluateTxAdditionalUtxos accept a
	// resolved UTxO set. The ChainContext contract lets the rest ignore the
	// argument or reject it outright, and backend/utxorpc rejects it, so
	// forwarding the spending inputs unconditionally made every Plutus build
	// fail there. Send nil instead and let the evaluator resolve inputs from
	// its own chain view.
	//
	// That is correct for on-chain inputs. Apollo cannot narrow it further:
	// there is no off-chain UTxO API and no provenance flag, so caller-supplied
	// inputs (AddInput, AddLoadedUTxOs, CollectFrom) are indistinguishable from
	// chain-loaded ones. Erroring on them would leave these backends as broken
	// as before, because every script input arrives that way. Degrading is safe
	// because it cannot understate a budget: an evaluator that cannot resolve an
	// input either fails the call or omits that redeemer, and the validation
	// below rejects a response missing any registered redeemer. Off-chain and
	// chained inputs therefore fail loudly, and need a backend that reports the
	// capability.
	additionalUtxos := inputs
	if !backend.Supports(
		a.Context,
		backend.CapabilityEvaluateTxAdditionalUtxos,
	) {
		additionalUtxos = nil
	}
	evalResult, err := backend.EvaluateTxContext(
		a.requestContext,
		a.Context,
		txBytes,
		additionalUtxos,
	)
	if err != nil {
		return nil, fmt.Errorf("EvaluateTx failed: %w", err)
	}
	if len(evalResult) == 0 {
		return nil, errors.New("EvaluateTx returned no results")
	}

	// Validate every result before changing registered redeemers. Results that do not
	// match a registered redeemer indicate a misbehaving evaluation backend;
	// fail closed rather than sign a transaction with zero execution budgets.
	validated := make(map[common.RedeemerKey]common.ExUnits, len(evalResult))
	seenSpend := make(map[string]bool, len(a.redeemers))
	seenMint := make(map[string]bool, len(a.mintRedeemers))
	seenStake := make(map[string]bool, len(a.stakeRedeemers))
	pp, ppErr := backend.ProtocolParamsContext(a.requestContext, a.Context)
	if ppErr != nil {
		return nil, fmt.Errorf("failed to get protocol params for execution-unit validation: %w", ppErr)
	}
	maxMem, memErr := strconv.ParseInt(pp.MaxTxExMem, 10, 64)
	maxSteps, stepsErr := strconv.ParseInt(pp.MaxTxExSteps, 10, 64)
	for evalKey, evalUnits := range evalResult {
		bufferedUnits := common.ExUnits{
			Memory: bufferExUnits(evalUnits.Memory, 1+ExMemoryBuffer),
			Steps:  bufferExUnits(evalUnits.Steps, 1+ExStepBuffer),
		}
		if memErr == nil && maxMem > 0 && bufferedUnits.Memory > maxMem {
			return nil, fmt.Errorf("buffered execution memory %d exceeds max_tx_ex_mem %d", bufferedUnits.Memory, maxMem)
		}
		if stepsErr == nil && maxSteps > 0 && bufferedUnits.Steps > maxSteps {
			return nil, fmt.Errorf("buffered execution steps %d exceeds max_tx_ex_steps %d", bufferedUnits.Steps, maxSteps)
		}
		switch evalKey.Tag {
		case common.RedeemerTagSpend:
			// Find the spending redeemer for this input index
			if uint64(evalKey.Index) >= uint64(len(inputs)) {
				return nil, fmt.Errorf("EvaluateTx returned spend redeemer index %d out of range (%d inputs)", evalKey.Index, len(inputs))
			}
			ref := utxoRef(inputs[evalKey.Index])
			entry, ok := a.redeemers[ref]
			if !ok {
				return nil, fmt.Errorf("EvaluateTx returned a result for input %s, which has no registered redeemer", ref)
			}
			_ = entry
			seenSpend[ref] = true
		case common.RedeemerTagMint:
			sortedPolicies := a.sortedMintPolicyIds()
			if uint64(evalKey.Index) >= uint64(len(sortedPolicies)) {
				return nil, fmt.Errorf("EvaluateTx returned mint redeemer index %d out of range (%d policies)", evalKey.Index, len(sortedPolicies))
			}
			policyHex := sortedPolicies[evalKey.Index]
			entry, ok := a.mintRedeemers[policyHex]
			if !ok {
				return nil, fmt.Errorf("EvaluateTx returned a result for mint policy %s, which has no registered redeemer", policyHex)
			}
			_ = entry
			seenMint[policyHex] = true
		case common.RedeemerTagReward:
			sortedWdAddrs := a.sortedWithdrawalKeys()
			if uint64(evalKey.Index) >= uint64(len(sortedWdAddrs)) {
				return nil, fmt.Errorf("EvaluateTx returned withdrawal redeemer index %d out of range (%d withdrawals)", evalKey.Index, len(sortedWdAddrs))
			}
			addrKey := sortedWdAddrs[evalKey.Index]
			wd := a.withdrawals[addrKey]
			skhHex := hex.EncodeToString(wd.Address.StakeKeyHash().Bytes())
			entry, ok := a.stakeRedeemers[skhHex]
			if !ok {
				return nil, fmt.Errorf("EvaluateTx returned a result for withdrawal %s, which has no registered redeemer", skhHex)
			}
			_ = entry
			seenStake[skhHex] = true
		default:
			return nil, fmt.Errorf("EvaluateTx returned unsupported redeemer tag %d", evalKey.Tag)
		}
		validated[evalKey] = bufferedUnits
	}

	// Every registered redeemer must have received an execution budget; a
	// redeemer left at zero ExUnits would fail phase-2 validation on-chain
	// and forfeit the collateral.
	for ref := range a.redeemers {
		if !seenSpend[ref] {
			return nil, fmt.Errorf("execution-unit evaluation returned no result for spend redeemer on input %s", ref)
		}
	}
	for policyHex := range a.mintRedeemers {
		if !seenMint[policyHex] {
			return nil, fmt.Errorf("execution-unit evaluation returned no result for mint redeemer on policy %s", policyHex)
		}
	}
	for skhHex := range a.stakeRedeemers {
		if !seenStake[skhHex] {
			return nil, fmt.Errorf("execution-unit evaluation returned no result for withdrawal redeemer on stake key %s", skhHex)
		}
	}

	return validated, nil
}

// applyExecutionUnits is deliberately separate from estimateExecutionUnits:
// callers only reach it after the complete evaluator response was validated.
func (a *Apollo) applyExecutionUnits(units map[common.RedeemerKey]common.ExUnits, inputs []common.Utxo) {
	for key, exUnits := range units {
		switch key.Tag {
		case common.RedeemerTagSpend:
			ref := utxoRef(inputs[key.Index])
			entry := a.redeemers[ref]
			entry.ExUnits = exUnits
			a.redeemers[ref] = entry
		case common.RedeemerTagMint:
			policy := a.sortedMintPolicyIds()[key.Index]
			entry := a.mintRedeemers[policy]
			entry.ExUnits = exUnits
			a.mintRedeemers[policy] = entry
		case common.RedeemerTagReward:
			wd := a.withdrawals[a.sortedWithdrawalKeys()[key.Index]]
			stakeKey := hex.EncodeToString(wd.Address.StakeKeyHash().Bytes())
			entry := a.stakeRedeemers[stakeKey]
			entry.ExUnits = exUnits
			a.stakeRedeemers[stakeKey] = entry
		}
	}
}

// bufferExUnits scales evaluated execution units by a safety factor, saturating
// at MaxInt64. Out-of-range float-to-int conversion is implementation-defined in
// Go, so an unguarded conversion of a huge backend-supplied value could wrap
// negative and corrupt the fee calculation.
func bufferExUnits(v int64, factor float64) int64 {
	if v <= 0 {
		return 0
	}
	f := float64(v) * factor
	if f >= float64(math.MaxInt64) {
		return math.MaxInt64
	}
	return int64(f)
}

func (a *Apollo) buildBody(
	inputs []common.Utxo,
	outputs []babbage.BabbageTransactionOutput,
	fee uint64,
) (conway.ConwayTransactionBody, error) {
	// Build input set
	txInputs := make([]shelley.ShelleyTransactionInput, 0, len(inputs))
	for _, utxo := range inputs {
		txId := utxo.Id.Id()
		idx := utxo.Id.Index()
		input := shelley.ShelleyTransactionInput{
			TxId:        txId,
			OutputIndex: idx,
		}
		txInputs = append(txInputs, input)
	}

	inputSet := conway.NewConwayTransactionInputSet(txInputs)

	body := conway.ConwayTransactionBody{
		TxInputs:  inputSet,
		TxOutputs: outputs,
		TxFee:     fee,
	}

	if a.Ttl > 0 {
		body.Ttl = uint64(a.Ttl)
	}
	if a.ValidityStart > 0 {
		body.TxValidityIntervalStart = uint64(a.ValidityStart)
	}

	// Mint
	if a.hasMint() {
		mintAsset, err := a.buildMintAsset()
		if err != nil {
			return body, err
		}
		body.TxMint = mintAsset
	}

	// Required signers
	if len(a.requiredSigners) > 0 {
		body.TxRequiredSigners = cbor.NewSetType(a.requiredSigners, true)
	}

	// Reference inputs
	if len(a.referenceInputs) > 0 {
		body.TxReferenceInputs = cbor.NewSetType(a.referenceInputs, true)
	}

	// Certificates
	if len(a.certificates) > 0 {
		body.TxCertificates = a.certificates
	}

	// Withdrawals
	if len(a.withdrawals) > 0 {
		wdMap := make(map[*common.Address]uint64, len(a.withdrawals))
		for _, wd := range a.withdrawals {
			addr := wd.Address
			wdMap[&addr] = wd.Amount
		}
		body.TxWithdrawals = wdMap
	}

	if len(a.votingProcedures) > 0 {
		body.TxVotingProcedures = a.votingProcedures
	}
	if len(a.proposalProcedures) > 0 {
		body.TxProposalProcedures = a.proposalProcedures
	}
	if a.currentTreasury > 0 {
		body.TxCurrentTreasuryValue = a.currentTreasury
	}
	if a.treasuryDonation > 0 {
		body.TxDonation = uint64(a.treasuryDonation) //nolint:gosec // validated non-negative above
	}

	// Auxiliary data hash
	if a.auxiliaryData != nil {
		auxHash, auxErr := a.computeAuxDataHash()
		if auxErr != nil {
			return body, fmt.Errorf("failed to compute aux data hash: %w", auxErr)
		}
		body.TxAuxDataHash = auxHash
	}

	// Collateral
	if len(a.collaterals) > 0 {
		collInputs := make([]shelley.ShelleyTransactionInput, 0, len(a.collaterals))
		for _, utxo := range a.collaterals {
			txId := utxo.Id.Id()
			idx := utxo.Id.Index()
			collInputs = append(collInputs, shelley.ShelleyTransactionInput{
				TxId:        txId,
				OutputIndex: idx,
			})
		}
		body.TxCollateral = cbor.NewSetType(collInputs, true)
		if a.totalCollateral > 0 {
			body.TxTotalCollateral = uint64(a.totalCollateral)
		}
		if a.collateralReturn != nil {
			body.TxCollateralReturn = a.collateralReturn
		}
	}

	// Script data hash
	if len(a.redeemers) > 0 || len(a.mintRedeemers) > 0 || len(a.stakeRedeemers) > 0 || len(a.datums) > 0 {
		pp, err := backend.ProtocolParamsContext(a.requestContext, a.Context)
		if err != nil {
			return body, err
		}
		redeemerMap := a.buildRedeemerMap(inputs)
		usedCostModels, err := a.usedScriptCostModels(inputs, pp.CostModels)
		if err != nil {
			return body, err
		}
		hash, err := ComputeScriptDataHash(redeemerMap, a.datums, usedCostModels)
		if err != nil {
			return body, err
		}
		body.TxScriptDataHash = hash
	}

	// Network ID
	netId := a.Context.NetworkId()
	body.TxNetworkId = &netId

	return body, nil
}

func (a *Apollo) buildWitnessSet(inputs []common.Utxo) conway.ConwayTransactionWitnessSet {
	ws := conway.ConwayTransactionWitnessSet{}

	if len(a.v1scripts) > 0 {
		ws.WsPlutusV1Scripts = cbor.NewSetType(a.v1scripts, true)
	}
	if len(a.v2scripts) > 0 {
		ws.WsPlutusV2Scripts = cbor.NewSetType(a.v2scripts, true)
	}
	if len(a.v3scripts) > 0 {
		ws.WsPlutusV3Scripts = cbor.NewSetType(a.v3scripts, true)
	}
	if len(a.nativescripts) > 0 {
		ws.WsNativeScripts = cbor.NewSetType(a.nativescripts, true)
	}
	if len(a.datums) > 0 {
		ws.WsPlutusData = WitnessPlutusData(a.datums)
	}

	redeemerMap := a.buildRedeemerMap(inputs)
	if len(redeemerMap) > 0 {
		ws.WsRedeemers = WitnessRedeemers(redeemerMap)
	}

	return ws
}

func (a *Apollo) buildRedeemerMap(inputs []common.Utxo) map[common.RedeemerKey]common.RedeemerValue {
	result := make(map[common.RedeemerKey]common.RedeemerValue)

	// Spending redeemers - index based on sorted input position
	for ref, entry := range a.redeemers {
		found := false
		idx := uint32(0)
		for i, utxo := range inputs {
			if utxoRef(utxo) == ref {
				idx = uint32(i)
				found = true
				break
			}
		}
		if !found {
			continue
		}
		key := common.RedeemerKey{Tag: entry.Tag, Index: idx}
		result[key] = common.RedeemerValue{Data: entry.Data, ExUnits: entry.ExUnits}
	}

	// Mint redeemers - index based on sorted policy ID position in mint field
	if len(a.mintRedeemers) > 0 {
		sortedPolicies := a.sortedMintPolicyIds()
		for policyHex, entry := range a.mintRedeemers {
			found := false
			idx := uint32(0)
			for i, p := range sortedPolicies {
				if p == policyHex {
					idx = uint32(i)
					found = true
					break
				}
			}
			if !found {
				continue
			}
			key := common.RedeemerKey{Tag: common.RedeemerTagMint, Index: idx}
			result[key] = common.RedeemerValue{Data: entry.Data, ExUnits: entry.ExUnits}
		}
	}

	// Stake redeemers - index based on sorted withdrawal address position
	if len(a.stakeRedeemers) > 0 {
		sortedWdAddrs := a.sortedWithdrawalKeys()
		for skhHex, entry := range a.stakeRedeemers {
			found := false
			idx := uint32(0)
			for i, addrKey := range sortedWdAddrs {
				wd := a.withdrawals[addrKey]
				addrSKH := hex.EncodeToString(wd.Address.StakeKeyHash().Bytes())
				if addrSKH == skhHex {
					idx = uint32(i)
					found = true
					break
				}
			}
			if !found {
				continue
			}
			key := common.RedeemerKey{Tag: common.RedeemerTagReward, Index: idx}
			result[key] = common.RedeemerValue{Data: entry.Data, ExUnits: entry.ExUnits}
		}
	}

	return result
}

func (a *Apollo) usedScriptCostModels(
	inputs []common.Utxo,
	available map[string][]int64,
) (map[string][]int64, error) {
	used := make(map[string]struct{})
	if len(a.v1scripts) > 0 {
		used["PlutusV1"] = struct{}{}
	}
	if len(a.v2scripts) > 0 {
		used["PlutusV2"] = struct{}{}
	}
	if len(a.v3scripts) > 0 {
		used["PlutusV3"] = struct{}{}
	}
	for _, utxo := range inputs {
		if err := addScriptLanguage(used, utxo.Output.ScriptRef()); err != nil {
			return nil, err
		}
	}
	for _, refInput := range a.referenceInputs {
		utxo, err := backend.UtxoByRefContext(a.requestContext, a.Context, refInput.TxId, refInput.OutputIndex)
		if err != nil {
			return nil, fmt.Errorf(
				"failed to resolve reference input %s#%d for script data hash: %w",
				hex.EncodeToString(refInput.TxId.Bytes()),
				refInput.OutputIndex,
				err,
			)
		}
		if utxo != nil {
			if err := addScriptLanguage(used, utxo.Output.ScriptRef()); err != nil {
				return nil, err
			}
		}
	}
	if len(available) == 0 {
		return nil, nil
	}
	if len(used) == 0 {
		if len(a.redeemers) == 0 && len(a.mintRedeemers) == 0 && len(a.stakeRedeemers) == 0 {
			return nil, nil
		}
		if len(available) == 1 {
			for lang, costs := range available {
				return map[string][]int64{lang: slices.Clone(costs)}, nil
			}
		}
		return nil, errors.New("unable to determine Plutus language for script data hash; attach the script or provide a reference input with a script reference")
	}
	result := make(map[string][]int64, len(used))
	for lang := range used {
		costs, ok := available[lang]
		if !ok {
			return nil, fmt.Errorf("missing cost model for %s", lang)
		}
		result[lang] = slices.Clone(costs)
	}
	return result, nil
}

// sortedMintPolicyIds returns unique policy IDs from mint units in sorted order.
func (a *Apollo) sortedMintPolicyIds() []string {
	seen := make(map[string]bool)
	var policies []string
	for _, unit := range a.mint {
		if !seen[unit.PolicyId] {
			seen[unit.PolicyId] = true
			policies = append(policies, unit.PolicyId)
		}
	}
	sort.Strings(policies)
	return policies
}

// totalWithdrawalValue returns the total lovelace from all withdrawals.
func (a *Apollo) totalWithdrawalValue() Value {
	var total uint64
	for _, wd := range a.withdrawals {
		sum := total + wd.Amount
		if sum < total {
			// Overflow: saturate at max uint64
			total = math.MaxUint64
			break
		}
		total = sum
	}
	return NewSimpleValue(total)
}

// sortedWithdrawalKeys returns withdrawal map keys sorted by raw address bytes.
// This matches CBOR canonical ordering used by the Cardano ledger for redeemer indices.
func (a *Apollo) sortedWithdrawalKeys() []string {
	type entry struct {
		key       string
		addrBytes []byte
	}
	entries := make([]entry, 0, len(a.withdrawals))
	for k, wd := range a.withdrawals {
		b, err := wd.Address.Bytes()
		if err != nil {
			// Use empty bytes for addresses that fail to encode;
			// this preserves deterministic ordering.
			b = nil
		}
		entries = append(entries, entry{key: k, addrBytes: b})
	}
	sort.Slice(entries, func(i, j int) bool {
		return bytes.Compare(entries[i].addrBytes, entries[j].addrBytes) < 0
	})
	keys := make([]string, len(entries))
	for i, e := range entries {
		keys[i] = e.key
	}
	return keys
}

func (a *Apollo) governanceRequiredValue() (Value, error) {
	total := uint64(0)
	if a.treasuryDonation > 0 {
		total = uint64(a.treasuryDonation) //nolint:gosec // validated non-negative by AddTreasuryDonation
	}
	for _, proposal := range a.proposalProcedures {
		deposit := proposal.Deposit()
		if math.MaxUint64-total < deposit {
			return Value{}, errors.New("governance proposal deposits overflow")
		}
		total += deposit
	}
	return NewSimpleValue(total), nil
}

func (a *Apollo) hasMint() bool {
	return len(a.mint) > 0
}

func (a *Apollo) mintValue() (Value, error) {
	total := Value{}
	for _, unit := range a.mint {
		// Use toMintValue which allows negative quantities (burns).
		uv, err := unit.toMintValue()
		if err != nil {
			return Value{}, fmt.Errorf("invalid mint unit %s: %w", unit.PolicyId, err)
		}
		total, err = total.Add(uv)
		if err != nil {
			return Value{}, fmt.Errorf("mint value overflow: %w", err)
		}
	}
	return total, nil
}

// GetMints returns all pending mints (both positive and negative quantities) as a Value.
func (a *Apollo) GetMints() (Value, error) {
	return a.mintValue()
}

// burnRequirementValue returns the absolute quantities of all assets being
// burned (negative mint amounts). These must be covered by transaction inputs.
func (a *Apollo) burnRequirementValue() (Value, error) {
	mv, err := a.mintValue()
	if err != nil {
		return Value{}, err
	}
	if mv.Assets == nil {
		return Value{}, nil
	}
	data := make(map[common.Blake2b224]map[cbor.ByteString]common.MultiAssetTypeOutput)
	for _, policyId := range mv.Assets.Policies() {
		for _, assetName := range mv.Assets.Assets(policyId) {
			qty := mv.Assets.Asset(policyId, assetName)
			if qty == nil || qty.Sign() >= 0 {
				continue
			}
			if data[policyId] == nil {
				data[policyId] = make(map[cbor.ByteString]common.MultiAssetTypeOutput)
			}
			data[policyId][cbor.NewByteString(assetName)] = new(big.Int).Neg(qty)
		}
	}
	if len(data) == 0 {
		return Value{}, nil
	}
	assets := common.NewMultiAsset[common.MultiAssetTypeOutput](data)
	return Value{Assets: &assets}, nil
}

func (a *Apollo) buildMintAsset() (*common.MultiAsset[common.MultiAssetTypeMint], error) {
	data := make(map[common.Blake2b224]map[cbor.ByteString]*big.Int)
	for _, unit := range a.mint {
		policyBytes, err := hex.DecodeString(unit.PolicyId)
		if err != nil {
			return nil, fmt.Errorf("invalid mint policy ID hex %q: %w", unit.PolicyId, err)
		}
		if len(policyBytes) != common.Blake2b224Size {
			return nil, fmt.Errorf("invalid policy ID length for %q: expected %d bytes, got %d", unit.PolicyId, common.Blake2b224Size, len(policyBytes))
		}
		var policyId common.Blake2b224
		copy(policyId[:], policyBytes)

		nameBytes, err := hex.DecodeString(unit.Name)
		if err != nil {
			return nil, fmt.Errorf("invalid asset name hex %q: %w (asset names must be hex-encoded)", unit.Name, err)
		}

		if _, ok := data[policyId]; !ok {
			data[policyId] = make(map[cbor.ByteString]*big.Int)
		}
		key := cbor.NewByteString(nameBytes)
		if existing, ok := data[policyId][key]; ok {
			data[policyId][key] = new(big.Int).Add(existing, big.NewInt(unit.Quantity))
		} else {
			data[policyId][key] = big.NewInt(unit.Quantity)
		}
	}
	result := common.NewMultiAsset[common.MultiAssetTypeMint](data)
	return &result, nil
}

func (a *Apollo) isUsed(ref string) bool {
	if a.usedUtxos[ref] {
		return true
	}
	// Also check preselected
	for _, utxo := range a.preselectedUtxos {
		if utxoRef(utxo) == ref {
			return true
		}
	}
	for _, utxo := range a.collaterals {
		// A collateral UTxO flagged for overlap is intentionally left available
		// to coin selection so it can ALSO be picked as a regular spending input
		// (see collateralOverlapRef). Treat it as not-used here.
		cref := utxoRef(utxo)
		if cref == a.collateralOverlapRef {
			continue
		}
		if cref == ref {
			return true
		}
	}
	return false
}

// markUsed records a UTxO key as used, lazily initializing the map if needed.
func (a *Apollo) markUsed(ref string) {
	if a.usedUtxos == nil {
		a.usedUtxos = make(map[string]bool)
	}
	a.usedUtxos[ref] = true
}

func utxoRef(utxo common.Utxo) string {
	return hex.EncodeToString(utxo.Id.Id().Bytes()) + "#" + strconv.FormatUint(uint64(utxo.Id.Index()), 10)
}

func validateUtxo(utxo common.Utxo) error {
	if err := backend.ValidateAdditionalUtxo(utxo); err != nil {
		return fmt.Errorf("UTxO is malformed: %w", err)
	}
	return nil
}

func validateUtxos(utxos []common.Utxo) error {
	for i, utxo := range utxos {
		if err := validateUtxo(utxo); err != nil {
			return fmt.Errorf("UTxO %d is invalid: %w", i, err)
		}
	}
	return nil
}

// getChangeAddress returns the change address (explicit or wallet).
func (a *Apollo) getChangeAddress() common.Address {
	if a.changeAddress != nil {
		return *a.changeAddress
	}
	return a.wallet.Address()
}

// hasScripts returns true if the transaction involves script execution
// (attached scripts or redeemers from reference scripts).
func (a *Apollo) hasScripts() bool {
	return len(a.v1scripts) > 0 || len(a.v2scripts) > 0 || len(a.v3scripts) > 0 ||
		len(a.redeemers) > 0 || len(a.mintRedeemers) > 0 || len(a.stakeRedeemers) > 0
}

// setCollateral auto-selects collateral from UTxOs if needed.
//
// Selection prefers a SEPARATE eligible vkey UTxO that is reserved out of the
// coin-selection pool (the common multi-UTxO case, where the tx shape is
// unchanged). When no dedicated UTxO is free, it falls back to a UTxO that may
// ALSO be used as a regular spending input: the candidate is recorded in
// collateralOverlapRef and is NOT reserved, so coin selection can still pick
// it. This lets a wallet with a single UTxO build a script transaction. The
// ledger permits the overlap because collateral is consumed only on phase-2
// script failure and regular inputs only on success.
//
// totalCollateral and collateralReturn are sized here from a preliminary
// (max-by-size) fee; finalizeCollateral() resizes them once the final fee is
// known.
func (a *Apollo) setCollateral() error {
	if len(a.collaterals) > 0 || !a.hasScripts() {
		return nil
	}
	// Compute collateral from protocol params when possible.
	// Total collateral = maxFee * collateralPercent / 100.
	minCollateral := int64(5_000_000) // conservative fallback
	if a.collateralAmount > 0 {
		minCollateral = a.collateralAmount
	} else if pp, err := backend.ProtocolParamsContext(a.requestContext, a.Context); err == nil {
		if maxFee, err := backend.MaxTxFeeContext(a.requestContext, a.Context); err == nil && pp.CollateralPercent > 0 &&
			maxFee <= math.MaxInt64/uint64(pp.CollateralPercent) {
			computed := int64(maxFee) * int64(pp.CollateralPercent) / 100 //nolint:gosec // bounded above
			if computed > 0 {
				minCollateral = computed
			}
		}
	}

	candidates := a.utxos
	if len(candidates) == 0 && a.wallet != nil {
		loaded, err := backend.UtxosContext(a.requestContext, a.Context, a.wallet.Address())
		if err != nil {
			return fmt.Errorf("failed to load UTxOs for collateral selection: %w", err)
		}
		candidates = loaded
	}

	// collateralEligible reports whether a UTxO can back collateral: it must be
	// vkey-locked (never a script address), hold a representable lovelace amount
	// of at least minCollateral, and -- if it carries native assets -- leave a
	// positive ADA remainder so the assets can be returned via collateral_return.
	collateralEligible := func(utxo common.Utxo, requirePureLovelace bool) bool {
		assets := utxo.Output.Assets()
		if requirePureLovelace && assets != nil {
			return false
		}
		addr := utxo.Output.Address()
		if addr.Type() != common.AddressTypeKeyKey && addr.Type() != common.AddressTypeKeyNone {
			return false
		}
		amt := utxo.Output.Amount()
		if amt == nil || !amt.IsInt64() {
			return false
		}
		lovelace := amt.Int64()
		if lovelace < minCollateral {
			return false
		}
		// An asset-bearing UTxO needs a positive remainder to carry the assets
		// forward in the collateral return.
		if assets != nil && lovelace-minCollateral == 0 {
			return false
		}
		return true
	}

	// selectCollateral records the chosen UTxO as collateral, reserves it out of
	// the coin-selection pool (markUsed), and sizes the preliminary total and
	// return. The reservation is provisional: if coin selection cannot then meet
	// its target (a wallet with no other UTxO to spare), Complete() releases it
	// for overlap via releaseCollateralForOverlap().
	selectCollateral := func(utxo common.Utxo) {
		ref := utxoRef(utxo)
		a.collaterals = append(a.collaterals, utxo)
		a.collateralAutoSelected = true
		a.markUsed(ref)
		a.totalCollateral = minCollateral
		lovelace := utxo.Output.Amount().Int64()
		remainder := lovelace - minCollateral
		assets := utxo.Output.Assets()
		if remainder > 0 || assets != nil {
			returnVal := Value{Coin: uint64(remainder)} //nolint:gosec // remainder >= 0 (eligibility checked)
			if assets != nil {
				returnVal.Assets = CloneMultiAsset(assets)
			}
			ret := NewBabbageOutput(a.getChangeAddress(), returnVal, nil, nil)
			a.collateralReturn = &ret
		}
	}

	// First pass: prefer a pure-lovelace UTxO (no assets). Selection keeps the
	// first-eligible candidate so a multi-UTxO wallet produces the same tx shape
	// as before this change; the overlap fallback in Complete() handles the case
	// where reserving a dedicated collateral starves coin selection.
	for _, utxo := range candidates {
		if a.isUsed(utxoRef(utxo)) {
			continue
		}
		if collateralEligible(utxo, true) {
			selectCollateral(utxo)
			return nil
		}
	}
	// Second pass: a UTxO that may carry assets.
	for _, utxo := range candidates {
		if a.isUsed(utxoRef(utxo)) {
			continue
		}
		if collateralEligible(utxo, false) {
			selectCollateral(utxo)
			return nil
		}
	}
	return errors.New("script transaction requires collateral, but no eligible collateral UTxO was found")
}

// releaseCollateralForOverlap un-reserves an auto-selected collateral UTxO so
// coin selection can also pick it as a regular spending input. The ledger
// permits a UTxO to be both a spending input and collateral because the two are
// consumed on mutually exclusive paths (success vs phase-2 script failure).
//
// It only acts on a single auto-selected collateral input that has not already
// been flagged for overlap, and reports whether anything was released so the
// caller knows a retry is worthwhile. Caller-pinned collateral is never touched.
func (a *Apollo) releaseCollateralForOverlap() bool {
	if !a.collateralAutoSelected || a.collateralOverlapRef != "" || len(a.collaterals) != 1 {
		return false
	}
	ref := utxoRef(a.collaterals[0])
	delete(a.usedUtxos, ref)
	a.collateralOverlapRef = ref
	return true
}

// restoreCollateralReservation reverses releaseCollateralForOverlap: it re-marks
// the released collateral UTxO as used and clears the overlap flag. It is called
// when the overlap retry still fails, so the builder is left in the same state
// it had before the release and a subsequent Complete() is not skewed by a
// half-applied overlap.
func (a *Apollo) restoreCollateralReservation() {
	if a.collateralOverlapRef == "" {
		return
	}
	a.markUsed(a.collateralOverlapRef)
	a.collateralOverlapRef = ""
}

// selectionState captures the UTxO reservation bookkeeping that coin selection
// mutates, so a speculative selection can be rolled back and retried against a
// different fee reserve.
type selectionState struct {
	usedUtxos            map[string]bool
	collateralOverlapRef string
}

func (a *Apollo) snapshotSelectionState() selectionState {
	return selectionState{
		usedUtxos:            maps.Clone(a.usedUtxos),
		collateralOverlapRef: a.collateralOverlapRef,
	}
}

func (a *Apollo) restoreSelectionState(s selectionState) {
	a.usedUtxos = maps.Clone(s.usedUtxos)
	a.collateralOverlapRef = s.collateralOverlapRef
}

// selectCoinsAllowingCollateralOverlap runs coin selection, and on failure
// retries once with the auto-selected collateral released. setCollateral()
// reserves a collateral UTxO out of the pool so multi-UTxO wallets keep a
// separate collateral and an unchanged tx shape; when that reservation starves
// selection (a wallet with a single UTxO, say) the ledger does permit one UTxO
// to be both a spending input and collateral. If the retry also fails, the
// reservation is restored so a subsequent Complete() starts from consistent
// state.
func (a *Apollo) selectCoinsAllowingCollateralOverlap(
	target, totalInput Value,
) ([]common.Utxo, error) {
	selected, err := a.selectCoins(target, totalInput)
	if err == nil {
		return selected, nil
	}
	if a.releaseCollateralForOverlap() {
		selected, retryErr := a.selectCoins(target, totalInput)
		if retryErr == nil {
			return selected, nil
		}
		a.restoreCollateralReservation()
		return nil, retryErr
	}
	return nil, err
}

// finalizeCollateral sizes and validates the total collateral and the
// collateral-return output against the final transaction fee. The ledger
// requires
//
//	totalCollateral >= ceil(fee * collateralPercent / 100)
//
// computed against the ACTUAL fee. setCollateral() only had a preliminary
// (max-by-size) fee available, so its sizing is stale once coin selection and
// fee estimation have run.
//
// The computation uses the collateral inputs' value ALONE: on phase-2 script
// failure only the collateral is consumed, so collateral_return = (collateral
// input ADA - total_collateral) plus all native assets on the collateral. This
// never touches the success-path input/output/fee balance.
//
// Three modes:
//   - auto-selected, no explicit amount: total/return are (re)computed from the
//     final fee.
//   - explicit SetCollateralAmount: total_collateral is pinned to the requested
//     amount (raised to the ledger minimum if the caller asked for too little is
//     rejected rather than silently bumped), and the return is recomputed so the
//     requested amount is actually emitted in the body.
//   - fully manual AddCollateral with no amount: the sizing is left to the
//     ledger's implicit "all collateral inputs" rule, but it is still validated
//     so an under-funded or asset-stranding collateral set is rejected locally
//     rather than built into an invalid tx.
func (a *Apollo) finalizeCollateral(fee int64) error {
	if len(a.collaterals) == 0 {
		return nil
	}
	pp, err := backend.ProtocolParamsContext(a.requestContext, a.Context)
	if err != nil {
		return fmt.Errorf("failed to get protocol params for collateral sizing: %w", err)
	}
	if pp.CollateralPercent <= 0 || fee <= 0 {
		return nil
	}
	if fee > (math.MaxInt64-99)/int64(pp.CollateralPercent) {
		return fmt.Errorf("collateral sizing overflows: fee=%d collateralPercent=%d", fee, pp.CollateralPercent)
	}
	// Ceil division: ceil(fee * percent / 100).
	required := (fee*int64(pp.CollateralPercent) + 99) / 100
	if required <= 0 {
		return nil
	}

	// Sum the lovelace and assets across the collateral inputs so the collateral
	// return can carry the remainder (and any tokens) forward.
	var totalLovelace int64
	var collateralAssets *common.MultiAsset[common.MultiAssetTypeOutput]
	hasAssets := false
	for _, utxo := range a.collaterals {
		amt := utxo.Output.Amount()
		if amt == nil || !amt.IsInt64() {
			return fmt.Errorf("collateral UTxO %s has an invalid lovelace amount", utxoRef(utxo))
		}
		sum := totalLovelace + amt.Int64()
		if sum < totalLovelace {
			return errors.New("collateral lovelace total overflows int64")
		}
		totalLovelace = sum
		if assets := utxo.Output.Assets(); assets != nil {
			hasAssets = true
			if collateralAssets == nil {
				collateralAssets = CloneMultiAsset(assets)
			} else {
				collateralAssets.Add(assets)
			}
		}
	}

	if required > totalLovelace {
		return fmt.Errorf(
			"insufficient collateral: need %d lovelace (ceil(fee %d * %d%%)), collateral inputs hold %d",
			required, fee, pp.CollateralPercent, totalLovelace,
		)
	}

	// Fully manual collateral with no explicit amount: the caller pinned the
	// inputs and did not ask for a specific total_collateral, so leave the body
	// untouched (the ledger consumes the whole collateral set on failure). Still
	// validate: the implicit collateral cannot carry assets forward without a
	// collateral return, so asset-bearing manual collateral must be rejected.
	if !a.collateralAutoSelected && a.collateralAmount == 0 {
		if hasAssets {
			return errors.New(
				"manual collateral carries native assets but no collateral return is set; " +
					"set a collateral amount/return or use ADA-only collateral",
			)
		}
		return nil
	}

	// Explicit SetCollateralAmount: honor the requested total_collateral (it must
	// still meet the ledger minimum and fit within the collateral inputs). This
	// raises the effective total above `required` when the caller wants a larger
	// margin; a request below the minimum is rejected rather than silently bumped.
	if a.collateralAmount > 0 {
		if a.collateralAmount < required {
			return fmt.Errorf(
				"insufficient collateral: requested amount %d is below the required %d (ceil(fee %d * %d%%))",
				a.collateralAmount, required, fee, pp.CollateralPercent,
			)
		}
		if a.collateralAmount > totalLovelace {
			return fmt.Errorf(
				"requested collateral amount %d exceeds collateral inputs %d",
				a.collateralAmount, totalLovelace,
			)
		}
		required = a.collateralAmount
	}

	remainder := totalLovelace - required

	// Asset-bearing collateral mandates a collateral_return to carry the tokens
	// forward, and that return must meet min-ADA. If the ADA remainder cannot
	// cover min-ADA, lowering total_collateral to free more ADA could break the
	// >= required invariant, so report a clear error rather than build an
	// invalid transaction.
	if hasAssets {
		returnVal := Value{Coin: uint64(remainder), Assets: collateralAssets} //nolint:gosec // remainder >= 0
		ret := NewBabbageOutput(a.getChangeAddress(), returnVal, nil, nil)
		minReturn, mErr := MinLovelacePostAlonzo(&ret, pp.CoinsPerUtxoByteValue())
		if mErr != nil {
			return fmt.Errorf("failed to compute min UTxO for collateral return: %w", mErr)
		}
		if minReturn < 0 {
			return fmt.Errorf("invalid min UTxO for collateral return: %d", minReturn)
		}
		if remainder < minReturn {
			return fmt.Errorf(
				"collateral return for native assets needs %d lovelace but only %d is available after total collateral %d; supply a larger or additional collateral UTxO",
				minReturn, remainder, required,
			)
		}
		a.totalCollateral = required
		a.collateralReturn = &ret
		return nil
	}

	// ADA-only collateral. If the remainder is too small to form a valid return
	// output (below min-ADA), absorb it into total_collateral and omit the
	// return rather than emit a sub-min-ADA output.
	if remainder > 0 {
		returnVal := Value{Coin: uint64(remainder)} //nolint:gosec // remainder > 0
		ret := NewBabbageOutput(a.getChangeAddress(), returnVal, nil, nil)
		minReturn, mErr := MinLovelacePostAlonzo(&ret, pp.CoinsPerUtxoByteValue())
		if mErr != nil {
			return fmt.Errorf("failed to compute min UTxO for collateral return: %w", mErr)
		}
		if minReturn < 0 {
			return fmt.Errorf("invalid min UTxO for collateral return: %d", minReturn)
		}
		if remainder >= minReturn {
			a.totalCollateral = required
			a.collateralReturn = &ret
			return nil
		}
		// Dust remainder below min-ADA. For an explicitly requested amount we may
		// not silently raise total_collateral (that would forfeit the dust on
		// failure and exceed what the caller asked for); reject instead. Only the
		// auto-sized path is free to absorb the dust into total_collateral.
		if a.collateralAmount > 0 {
			return fmt.Errorf(
				"requested collateral amount %d leaves a %d lovelace return below the %d min-ADA; choose an amount that leaves no return or at least min-ADA",
				required, remainder, minReturn,
			)
		}
		// Auto-sized dust remainder: absorb into total_collateral, no return.
		a.totalCollateral = totalLovelace
		a.collateralReturn = nil
		return nil
	}

	// Exact match: total collateral consumes the whole input, no return.
	a.totalCollateral = required
	a.collateralReturn = nil
	return nil
}

// validateCollateral checks the collateral input set against the ledger rules
// that apollo can enforce locally: no duplicate collateral inputs and no more
// than MaxCollateralInputs of them.
//
// It deliberately does NOT reject a UTxO that is also a regular spending input.
// The Cardano ledger permits that overlap because collateral is consumed only
// on phase-2 script failure and regular inputs only on success; the two paths
// are mutually exclusive. This matches mesh, lucid, and lucid-evolution and
// lets a single-UTxO wallet build a script transaction.
func (a *Apollo) validateCollateral() error {
	if len(a.collaterals) == 0 {
		return nil
	}
	seen := make(map[string]struct{}, len(a.collaterals))
	for _, collateral := range a.collaterals {
		ref := utxoRef(collateral)
		if _, ok := seen[ref]; ok {
			return fmt.Errorf("duplicate collateral input %s", ref)
		}
		seen[ref] = struct{}{}
		// Collateral must be vkey-locked: the ledger rejects collateral at a
		// script address. Auto-selection already filters on this, but
		// caller-pinned collateral (AddCollateral) is validated here so a
		// script-address UTxO never reaches the body.
		if out := collateral.Output; out != nil {
			if addr := out.Address(); addr.Type() != common.AddressTypeKeyKey &&
				addr.Type() != common.AddressTypeKeyNone {
				return fmt.Errorf("collateral input %s is not vkey-locked (script-address collateral is rejected by the ledger)", ref)
			}
		}
	}
	// Enforce the protocol max on collateral inputs when known.
	if pp, err := backend.ProtocolParamsContext(a.requestContext, a.Context); err == nil && pp.MaxCollateralInputs > 0 &&
		len(a.collaterals) > pp.MaxCollateralInputs {
		return fmt.Errorf(
			"too many collateral inputs: %d exceeds protocol maximum of %d",
			len(a.collaterals), pp.MaxCollateralInputs,
		)
	}
	return nil
}

// adjustForCertificateDeposits adjusts the total required value for certificate deposits.
func (a *Apollo) adjustForCertificateDeposits(required Value, stakeDeposit, poolDeposit int64) (Value, error) {
	adj := a.certificateDepositAdjustment(stakeDeposit, poolDeposit)
	if adj > 0 {
		deposit := NewSimpleValue(uint64(adj))
		return required.Add(deposit)
	}
	return required, nil
}

// certificateRefundValue returns the total deposit refund from deregistration certificates.
// These refunds are implicit inputs in Cardano's balance equation.
func (a *Apollo) certificateRefundValue(stakeDeposit, poolDeposit int64) Value {
	adj := a.certificateDepositAdjustment(stakeDeposit, poolDeposit)
	if adj < 0 {
		return NewSimpleValue(uint64(-adj))
	}
	return NewSimpleValue(0)
}

// certificateDepositAdjustment calculates the net deposit change from certificates.
// Positive means deposits needed, negative means refunds.
func (a *Apollo) certificateDepositAdjustment(stakeDeposit int64, poolDeposits ...int64) int64 {
	poolDeposit := int64(0)
	if len(poolDeposits) > 0 {
		poolDeposit = poolDeposits[0]
	}
	var adjustment int64
	for _, cert := range a.certificates {
		switch cert.Type {
		case uint(common.CertificateTypeStakeRegistration):
			adjustment += stakeDeposit
		case uint(common.CertificateTypePoolRegistration):
			adjustment += poolDeposit
		case uint(common.CertificateTypeStakeDeregistration):
			adjustment -= stakeDeposit
		case uint(common.CertificateTypeDeregistration):
			if c, ok := cert.Certificate.(*common.DeregistrationCertificate); ok {
				adjustment -= c.Amount
			}
		case uint(common.CertificateTypeRegistration):
			if c, ok := cert.Certificate.(*common.RegistrationCertificate); ok {
				adjustment += c.Amount
			}
		case uint(common.CertificateTypeStakeRegistrationDelegation),
			uint(common.CertificateTypeVoteRegistrationDelegation),
			uint(common.CertificateTypeStakeVoteRegistrationDelegation):
			// These certificates carry their explicit deposit in Amount.
			switch c := cert.Certificate.(type) {
			case *common.StakeRegistrationDelegationCertificate:
				adjustment += c.Amount
			case *common.VoteRegistrationDelegationCertificate:
				adjustment += c.Amount
			case *common.StakeVoteRegistrationDelegationCertificate:
				adjustment += c.Amount
			}
		case uint(common.CertificateTypeRegistrationDrep):
			if c, ok := cert.Certificate.(*common.RegistrationDrepCertificate); ok {
				adjustment += c.Amount
			}
		case uint(common.CertificateTypeDeregistrationDrep):
			if c, ok := cert.Certificate.(*common.DeregistrationDrepCertificate); ok {
				adjustment -= c.Amount
			}
		}
	}
	return adjustment
}

func (a *Apollo) setErrOnce(err error) {
	if err != nil && a.err == nil {
		a.err = err
	}
}

func redeemerEntriesEqual(lhs, rhs redeemerEntry) bool {
	if lhs.Tag != rhs.Tag || lhs.ExUnits != rhs.ExUnits {
		return false
	}
	lhsBytes, lhsErr := cbor.Encode(lhs.Data)
	rhsBytes, rhsErr := cbor.Encode(rhs.Data)
	if lhsErr != nil || rhsErr != nil {
		return false
	}
	return bytes.Equal(lhsBytes, rhsBytes)
}

func addScriptLanguage(used map[string]struct{}, script common.Script) error {
	switch script.(type) {
	case common.PlutusV1Script, *common.PlutusV1Script:
		used["PlutusV1"] = struct{}{}
	case common.PlutusV2Script, *common.PlutusV2Script:
		used["PlutusV2"] = struct{}{}
	case common.PlutusV3Script, *common.PlutusV3Script:
		used["PlutusV3"] = struct{}{}
	case common.PlutusV4Script, *common.PlutusV4Script:
		return ErrPlutusV4RequiresDijkstra
	}
	return nil
}

func isPlutusV4Script(script common.Script) bool {
	switch script.(type) {
	case common.PlutusV4Script, *common.PlutusV4Script:
		return true
	default:
		return false
	}
}

func cloneGovAnchor(anchor *common.GovAnchor) *common.GovAnchor {
	if anchor == nil {
		return nil
	}
	cp := *anchor
	return &cp
}

func findVotingProcedureVoter(votes common.VotingProcedures, voter common.Voter) *common.Voter {
	for existing := range votes {
		if existing.Type == voter.Type && existing.Hash == voter.Hash {
			return existing
		}
	}
	return nil
}

func findVotingProcedureAction(
	votes map[*common.GovActionId]common.VotingProcedure,
	actionId common.GovActionId,
) *common.GovActionId {
	for existing := range votes {
		if existing.TransactionId == actionId.TransactionId && existing.GovActionIdx == actionId.GovActionIdx {
			return existing
		}
	}
	return nil
}

func cloneVotingProcedures(src common.VotingProcedures) common.VotingProcedures {
	if len(src) == 0 {
		return nil
	}
	dst := make(common.VotingProcedures, len(src))
	for voter, votes := range src {
		voterCopy := *voter
		voteCopy := make(map[*common.GovActionId]common.VotingProcedure, len(votes))
		for actionId, procedure := range votes {
			actionCopy := *actionId
			procedure.Anchor = cloneGovAnchor(procedure.Anchor)
			voteCopy[&actionCopy] = procedure
		}
		dst[&voterCopy] = voteCopy
	}
	return dst
}

// computeAuxDataHash computes the blake2b-256 hash of the CBOR-encoded auxiliary data.
// It must encode the same MetaMap structure used in the transaction to ensure the hash matches.
func (a *Apollo) computeAuxDataHash() (*common.Blake2b256, error) {
	if a.auxiliaryData == nil {
		return nil, nil
	}
	md, err := a.buildMetadata()
	if err != nil {
		return nil, fmt.Errorf("failed to build metadata: %w", err)
	}
	if md == nil {
		return nil, nil
	}
	// Hash the exact bytes buildMetadata stored, which are the bytes that will
	// be serialized as auxiliary_data. Re-encoding here instead would let the
	// declared hash and the wire representation drift apart.
	mdBytes := md.Cbor()
	if len(mdBytes) == 0 {
		return nil, errors.New("metadata has no stored CBOR encoding")
	}
	hash := common.Blake2b256Hash(mdBytes)
	return &hash, nil
}

// buildMetadata converts auxiliary data to a MetaMap with deterministic key ordering.
func (a *Apollo) buildMetadata() (*common.MetaMap, error) {
	if a.auxiliaryData == nil {
		return nil, nil
	}
	// Sort keys for deterministic CBOR encoding (required for consistent hashing)
	keys := make([]uint64, 0, len(a.auxiliaryData.metadata))
	for k := range a.auxiliaryData.metadata {
		keys = append(keys, k)
	}
	slices.Sort(keys)

	pairs := make([]common.MetaPair, 0, len(a.auxiliaryData.metadata))
	for _, k := range keys {
		v := a.auxiliaryData.metadata[k]
		key := common.MetaInt{Value: new(big.Int).SetUint64(k)}
		val, err := toMetadatum(v)
		if err != nil {
			return nil, fmt.Errorf("metadata key %d: %w", k, err)
		}
		pairs = append(pairs, common.MetaPair{Key: key, Value: val})
	}
	md := &common.MetaMap{Pairs: pairs}
	// gouroboros serializes auxiliary data from the value's stored CBOR
	// (ConwayTransaction.MarshalCBOR emits TxMetadata.Cbor()), so a freshly
	// built MetaMap must carry its own encoding. Without this the transaction
	// is emitted with auxiliary_data set to CBOR null while the body still
	// declares auxiliary_data_hash, and the metadata is silently dropped.
	mdBytes, err := cbor.Encode(md)
	if err != nil {
		return nil, fmt.Errorf("failed to encode metadata: %w", err)
	}
	md.SetCbor(mdBytes)
	return md, nil
}

// toMetadatum converts a Go value to a TransactionMetadatum.
// Supports scalars (string, int, int64, uint64, []byte), nested maps, and lists.
func toMetadatum(v any) (common.TransactionMetadatum, error) {
	switch tv := v.(type) {
	case common.TransactionMetadatum:
		return tv, nil
	case string:
		if err := validateMetadataText(tv, "metadata"); err != nil {
			return nil, err
		}
		return common.MetaText{Value: tv}, nil
	case int:
		return common.MetaInt{Value: big.NewInt(int64(tv))}, nil
	case int64:
		return common.MetaInt{Value: big.NewInt(tv)}, nil
	case uint64:
		return common.MetaInt{Value: new(big.Int).SetUint64(tv)}, nil
	case *big.Int:
		if tv == nil {
			return nil, errors.New("nil metadata integer")
		}
		if tv.Cmp(minMetadataInteger) < 0 || tv.Cmp(maxMetadataInteger) > 0 {
			return nil, fmt.Errorf("metadata integer %s is outside the supported range", tv.String())
		}
		return common.MetaInt{Value: new(big.Int).Set(tv)}, nil
	case big.Int:
		if tv.Cmp(minMetadataInteger) < 0 || tv.Cmp(maxMetadataInteger) > 0 {
			return nil, fmt.Errorf("metadata integer %s is outside the supported range", tv.String())
		}
		return common.MetaInt{Value: new(big.Int).Set(&tv)}, nil
	case []byte:
		if err := validateMetadataBytes(tv, "metadata"); err != nil {
			return nil, err
		}
		return common.MetaBytes{Value: tv}, nil
	case MetadataMap:
		pairs := make([]common.MetaPair, 0, len(tv))
		for idx, entry := range tv {
			key, err := toMetadatum(entry.Key)
			if err != nil {
				return nil, fmt.Errorf("map entry %d key: %w", idx, err)
			}
			val, err := toMetadatum(entry.Value)
			if err != nil {
				return nil, fmt.Errorf("map entry %d value: %w", idx, err)
			}
			pairs = append(pairs, common.MetaPair{Key: key, Value: val})
		}
		return common.MetaMap{Pairs: pairs}, nil
	case map[string]any:
		sortedKeys := make([]string, 0, len(tv))
		for mk := range tv {
			sortedKeys = append(sortedKeys, mk)
		}
		sort.Strings(sortedKeys)
		pairs := make([]common.MetaPair, 0, len(tv))
		for _, mk := range sortedKeys {
			if err := validateMetadataText(mk, "metadata map key"); err != nil {
				return nil, err
			}
			val, err := toMetadatum(tv[mk])
			if err != nil {
				return nil, fmt.Errorf("map key %q: %w", mk, err)
			}
			pairs = append(pairs, common.MetaPair{
				Key:   common.MetaText{Value: mk},
				Value: val,
			})
		}
		return common.MetaMap{Pairs: pairs}, nil
	case map[uint64]any:
		sortedKeys := make([]uint64, 0, len(tv))
		for mk := range tv {
			sortedKeys = append(sortedKeys, mk)
		}
		slices.Sort(sortedKeys)
		pairs := make([]common.MetaPair, 0, len(tv))
		for _, mk := range sortedKeys {
			val, err := toMetadatum(tv[mk])
			if err != nil {
				return nil, fmt.Errorf("map key %d: %w", mk, err)
			}
			pairs = append(pairs, common.MetaPair{
				Key:   common.MetaInt{Value: new(big.Int).SetUint64(mk)},
				Value: val,
			})
		}
		return common.MetaMap{Pairs: pairs}, nil
	case []any:
		items := make([]common.TransactionMetadatum, 0, len(tv))
		for i, item := range tv {
			m, err := toMetadatum(item)
			if err != nil {
				return nil, fmt.Errorf("list index %d: %w", i, err)
			}
			items = append(items, m)
		}
		return common.MetaList{Items: items}, nil
	default:
		return nil, fmt.Errorf("unsupported metadata value type %T", v)
	}
}
