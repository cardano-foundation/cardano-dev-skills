package ogmios

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"math/big"
	"reflect"
	"strconv"
	"strings"
	"time"

	"github.com/SundaeSwap-finance/kugo"
	ogmigo "github.com/SundaeSwap-finance/ogmigo/v6"
	"github.com/SundaeSwap-finance/ogmigo/v6/ouroboros/chainsync/num"
	"github.com/SundaeSwap-finance/ogmigo/v6/ouroboros/shared"
	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/babbage"
	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/gouroboros/ledger/mary"
	"github.com/blinklabs-io/gouroboros/ledger/shelley"

	"github.com/Salvionied/apollo/v2/backend"
	"github.com/Salvionied/apollo/v2/internal/backendutil"
)

// OgmiosChainContext implements backend.ChainContext using Ogmios + Kupo.
type OgmiosChainContext struct {
	ogmios    OgmiosClient
	kupo      KupoClient
	networkId uint8
}

var _ backend.ContextChainContext = (*OgmiosChainContext)(nil)

// Config describes how an OgmiosChainContext reaches its services. Apollo
// owns this type, so which client libraries this package builds - and which
// major versions of them - stay an implementation detail.
type Config struct {
	// OgmiosEndpoint is the Ogmios JSON-RPC endpoint, e.g.
	// "ws://localhost:1337". Ogmios is reached over WebSocket, so http and
	// https URLs are accepted and dialed as ws and wss. Required.
	OgmiosEndpoint string
	// KupoEndpoint is the base URL of a Kupo instance, e.g.
	// "http://localhost:1442". Optional: a context configured without one
	// answers every query Ogmios serves on its own, and reports neither
	// CapabilityUtxos nor CapabilityScriptCbor.
	KupoEndpoint string
	// NetworkId is the Cardano network identifier reported by NetworkId()
	// (mainnet = 1, testnets = 0).
	NetworkId uint8
	// KupoTimeout bounds each Kupo HTTP request. Zero leaves the Kupo client
	// default in place.
	KupoTimeout time.Duration
}

// NewOgmiosChainContext creates an Ogmios chain context from connection
// settings, building the Ogmios and Kupo clients internally. An endpoint that
// is empty, or is not a URL Apollo can reach the service at, is rejected here
// rather than failing on the first query.
func NewOgmiosChainContext(cfg Config) (*OgmiosChainContext, error) {
	ogmiosClient, err := newOgmigoClient(cfg.OgmiosEndpoint)
	if err != nil {
		return nil, err
	}
	chainCtx := &OgmiosChainContext{
		ogmios:    ogmiosClient,
		networkId: cfg.NetworkId,
	}
	if cfg.KupoEndpoint != "" {
		kupoClient, err := newKugoClient(cfg.KupoEndpoint, cfg.KupoTimeout)
		if err != nil {
			return nil, err
		}
		chainCtx.kupo = kupoClient
	}
	return chainCtx, nil
}

// NewOgmiosChainContextFromClients creates an Ogmios chain context from
// caller-supplied clients. It is the escape hatch for tests and for callers
// whose transport Config cannot express; both interfaces are Apollo's own, so
// injecting a client does not pin Apollo to a client library.
//
// ogmiosClient is required. kupoClient may be nil, in which case the context
// reports neither CapabilityUtxos nor CapabilityScriptCbor.
func NewOgmiosChainContextFromClients(
	ogmiosClient OgmiosClient,
	kupoClient KupoClient,
	networkId uint8,
) (*OgmiosChainContext, error) {
	if isNilClient(ogmiosClient) {
		return nil, errors.New("ogmios client is required")
	}
	chainCtx := &OgmiosChainContext{
		ogmios:    ogmiosClient,
		networkId: networkId,
	}
	// A typed nil is normalized to a nil field so Capabilities reports the
	// Kupo-less feature set instead of the context failing on first use.
	if !isNilClient(kupoClient) {
		chainCtx.kupo = kupoClient
	}
	return chainCtx, nil
}

// isNilClient reports whether an interface value is nil or holds a nil
// pointer. A typed nil pointer still satisfies its interface, so without this
// check it would pass the constructor and panic on first use.
func isNilClient(client any) bool {
	if client == nil {
		return true
	}
	value := reflect.ValueOf(client)
	switch value.Kind() {
	case reflect.Chan, reflect.Func, reflect.Map, reflect.Pointer,
		reflect.Slice:
		return value.IsNil()
	default:
		return false
	}
}

// errNoOgmiosClient reports a context that no constructor produced - a zero
// value, say - and so has no client to query. Methods return it instead of
// dereferencing a nil client.
var errNoOgmiosClient = errors.New(
	"ogmios chain context has no Ogmios client: build it with" +
		" NewOgmiosChainContext or NewOgmiosChainContextFromClients",
)

// client returns the configured Ogmios client, or errNoOgmiosClient.
func (o *OgmiosChainContext) client() (OgmiosClient, error) {
	if o == nil || o.ogmios == nil {
		return nil, errNoOgmiosClient
	}
	return o.ogmios, nil
}

// kupoClient returns the configured Kupo client, or an UnsupportedError
// naming the capability the missing client would have provided.
func (o *OgmiosChainContext) kupoClient(
	capability backend.Capability,
) (KupoClient, error) {
	if o == nil || o.kupo == nil {
		return nil, backend.NewUnsupportedError(
			"Ogmios without Kupo", capability,
		)
	}
	return o.kupo, nil
}

// Capabilities reports the operations supported by the configured Ogmios
// client. Address UTxO queries and script lookup require the optional Kupo
// client; UTxO-by-reference queries are served directly by Ogmios.
func (o *OgmiosChainContext) Capabilities() backend.CapabilitySet {
	if o == nil || o.ogmios == nil {
		return 0
	}
	capabilities := backend.CapabilitySet(backend.AllCapabilities)
	if o.kupo == nil {
		capabilities &^= backend.CapabilitySet(
			backend.CapabilityUtxos | backend.CapabilityScriptCbor,
		)
	}
	return capabilities
}

func (o *OgmiosChainContext) ProtocolParams() (backend.ProtocolParameters, error) {
	return o.ProtocolParamsContext(context.Background())
}

func (o *OgmiosChainContext) ProtocolParamsContext(ctx context.Context) (backend.ProtocolParameters, error) {
	client, err := o.client()
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	raw, err := client.ProtocolParameters(ctx)
	if err != nil {
		return backend.ProtocolParameters{}, err
	}

	var params ogmiosProtocolParams
	if err := json.Unmarshal(raw, &params); err != nil {
		return backend.ProtocolParameters{}, fmt.Errorf("failed to parse protocol params: %w", err)
	}

	return params.toProtocolParams()
}

func (o *OgmiosChainContext) GenesisParams() (backend.GenesisParameters, error) {
	return o.GenesisParamsContext(context.Background())
}

func (o *OgmiosChainContext) GenesisParamsContext(ctx context.Context) (backend.GenesisParameters, error) {
	client, err := o.client()
	if err != nil {
		return backend.GenesisParameters{}, err
	}
	raw, err := client.GenesisConfig(ctx, "shelley")
	if err != nil {
		return backend.GenesisParameters{}, err
	}

	var genesis ogmiosGenesisConfig
	if err := json.Unmarshal(raw, &genesis); err != nil {
		return backend.GenesisParameters{}, fmt.Errorf(
			"failed to parse genesis config: %w", err,
		)
	}

	return genesis.toGenesisParams()
}

func (o *OgmiosChainContext) NetworkId() uint8 {
	return o.networkId
}

func (o *OgmiosChainContext) CurrentEpoch() (uint64, error) {
	return o.CurrentEpochContext(context.Background())
}

func (o *OgmiosChainContext) CurrentEpochContext(ctx context.Context) (uint64, error) {
	client, err := o.client()
	if err != nil {
		return 0, err
	}
	return client.CurrentEpoch(ctx)
}

func (o *OgmiosChainContext) MaxTxFee() (uint64, error) {
	return o.MaxTxFeeContext(context.Background())
}

func (o *OgmiosChainContext) MaxTxFeeContext(ctx context.Context) (uint64, error) {
	pp, err := o.ProtocolParamsContext(ctx)
	if err != nil {
		return 0, err
	}
	return backend.ComputeMaxTxFee(pp)
}

func (o *OgmiosChainContext) Tip() (uint64, error) {
	return o.TipContext(context.Background())
}

func (o *OgmiosChainContext) TipContext(ctx context.Context) (uint64, error) {
	client, err := o.client()
	if err != nil {
		return 0, err
	}
	return client.Tip(ctx)
}

func (o *OgmiosChainContext) Utxos(address common.Address) ([]common.Utxo, error) {
	return o.UtxosContext(context.Background(), address)
}

func (o *OgmiosChainContext) UtxosContext(ctx context.Context, address common.Address) ([]common.Utxo, error) {
	client, err := o.kupoClient(backend.CapabilityUtxos)
	if err != nil {
		return nil, err
	}
	return client.UtxosAtAddress(ctx, address)
}

func (o *OgmiosChainContext) SubmitTx(txCbor []byte) (common.Blake2b256, error) {
	return o.SubmitTxContext(context.Background(), txCbor)
}

func (o *OgmiosChainContext) SubmitTxContext(ctx context.Context, txCbor []byte) (common.Blake2b256, error) {
	client, err := o.client()
	if err != nil {
		return common.Blake2b256{}, err
	}
	return client.SubmitTx(ctx, txCbor)
}

func (o *OgmiosChainContext) EvaluateTx(txCbor []byte, additionalUtxos []common.Utxo) (map[common.RedeemerKey]common.ExUnits, error) {
	return o.EvaluateTxContext(context.Background(), txCbor, additionalUtxos)
}

func (o *OgmiosChainContext) EvaluateTxContext(
	ctx context.Context,
	txCbor []byte,
	additionalUtxos []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, error) {
	client, err := o.client()
	if err != nil {
		return nil, err
	}
	// Validated here, not only where the UTxOs are encoded for the wire, so
	// a malformed additional UTxO is rejected whichever client is in use.
	for _, utxo := range additionalUtxos {
		if err := backend.ValidateAdditionalUtxo(utxo); err != nil {
			return nil, err
		}
	}
	return client.EvaluateTx(ctx, txCbor, additionalUtxos)
}

// commonUtxosToShared converts resolved gouroboros UTxOs into the ogmigo
// shared.Utxo wire form expected by EvaluateTxWithAdditionalUtxos.
func commonUtxosToShared(utxos []common.Utxo) ([]shared.Utxo, error) {
	result := make([]shared.Utxo, 0, len(utxos))
	for _, utxo := range utxos {
		su, err := commonUtxoToShared(utxo)
		if err != nil {
			return nil, err
		}
		result = append(result, su)
	}
	return result, nil
}

// commonUtxoToShared converts a single resolved gouroboros UTxO into an
// ogmigo shared.Utxo. The value is encoded as Ogmios expects: the outer key is
// "ada" (with inner key "lovelace") for the coin, and the policy ID hex (with
// inner asset-name hex) for native assets.
func commonUtxoToShared(utxo common.Utxo) (shared.Utxo, error) {
	if err := backend.ValidateAdditionalUtxo(utxo); err != nil {
		return shared.Utxo{}, err
	}

	out := utxo.Output

	coin, err := bigIntToNum(out.Amount())
	if err != nil {
		return shared.Utxo{}, fmt.Errorf("invalid lovelace amount: %w", err)
	}
	value := shared.Value{
		shared.AdaPolicy: {
			shared.AdaAsset: coin,
		},
	}
	if assets := out.Assets(); assets != nil {
		for _, policyId := range assets.Policies() {
			policyHex := hex.EncodeToString(policyId.Bytes())
			for _, assetName := range assets.Assets(policyId) {
				qty, err := bigIntToNum(assets.Asset(policyId, assetName))
				if err != nil {
					return shared.Utxo{}, fmt.Errorf("invalid asset quantity for policy %s: %w", policyHex, err)
				}
				if value[policyHex] == nil {
					value[policyHex] = map[string]num.Int{}
				}
				value[policyHex][hex.EncodeToString(assetName)] = qty
			}
		}
	}

	su := shared.Utxo{
		Transaction: shared.UtxoTxID{ID: hex.EncodeToString(utxo.Id.Id().Bytes())},
		Index:       utxo.Id.Index(),
		Address:     out.Address().String(),
		Value:       value,
	}

	// Datum: inline datum CBOR hex goes in Datum, a bare datum hash in DatumHash.
	if datum := out.Datum(); datum != nil {
		datumCbor, err := datum.MarshalCBOR()
		if err != nil {
			return shared.Utxo{}, fmt.Errorf("failed to encode inline datum: %w", err)
		}
		su.Datum = hex.EncodeToString(datumCbor)
	} else if datumHash := out.DatumHash(); datumHash != nil {
		su.DatumHash = hex.EncodeToString(datumHash.Bytes())
	}

	// Reference script: Ogmios expects {"language": ..., "cbor": ...}.
	if script := out.ScriptRef(); script != nil {
		scriptJSON, err := ogmiosScriptRefJSON(script)
		if err != nil {
			return shared.Utxo{}, err
		}
		su.Script = scriptJSON
	}

	return su, nil
}

// bigIntToNum converts a big.Int quantity into the ogmigo num.Int used by
// shared.Value, preserving the full magnitude (no int64 truncation).
func bigIntToNum(v *big.Int) (num.Int, error) {
	if v == nil {
		return num.Int64(0), nil
	}
	n, ok := num.New(v.String())
	if !ok {
		return num.Int{}, fmt.Errorf("cannot represent quantity %s", v.String())
	}
	return n, nil
}

// ogmiosScriptRefJSON encodes a reference script as the Ogmios script JSON
// object ({"language": "plutus:vN"|"native", "cbor": "<hex>"}) matching the
// shape consumed by ogmiosScriptToScriptRef.
func ogmiosScriptRefJSON(script common.Script) (json.RawMessage, error) {
	var language string
	switch script.(type) {
	case common.PlutusV1Script:
		language = "plutus:v1"
	case common.PlutusV2Script:
		language = "plutus:v2"
	case common.PlutusV3Script:
		language = "plutus:v3"
	case common.PlutusV4Script:
		language = "plutus:v4"
	case common.NativeScript:
		language = "native"
	default:
		return nil, fmt.Errorf("unsupported reference script type %T", script)
	}
	payload := struct {
		Language string `json:"language"`
		Cbor     string `json:"cbor"`
	}{
		Language: language,
		Cbor:     hex.EncodeToString(script.RawScriptBytes()),
	}
	return json.Marshal(payload)
}

// evaluateResponseToExUnits converts an ogmigo EvaluateTxResponse into a
// redeemer ExUnits map. A response with zero evaluation results is an error:
// returning an empty map with a nil error would let callers silently keep
// zero execution budgets for their redeemers.
func evaluateResponseToExUnits(resp *ogmigo.EvaluateTxResponse) (map[common.RedeemerKey]common.ExUnits, error) {
	if resp == nil {
		return nil, errors.New("empty evaluate response")
	}
	if resp.Error != nil {
		return nil, fmt.Errorf("evaluate tx error: %s", resp.Error.Message)
	}
	if len(resp.ExUnits) == 0 {
		return nil, errors.New("script evaluation returned no results")
	}

	result := make(map[common.RedeemerKey]common.ExUnits, len(resp.ExUnits))
	for _, eu := range resp.ExUnits {
		tag, err := backendutil.ParseRedeemerTag(eu.Validator.Purpose)
		if err != nil {
			return nil, fmt.Errorf("invalid redeemer purpose %q: %w", eu.Validator.Purpose, err)
		}
		if eu.Validator.Index > math.MaxUint32 {
			return nil, fmt.Errorf("redeemer index %d exceeds uint32 range", eu.Validator.Index)
		}
		key := common.RedeemerKey{Tag: tag, Index: uint32(eu.Validator.Index)}
		if eu.Budget.Memory > math.MaxInt64 || eu.Budget.Cpu > math.MaxInt64 {
			return nil, fmt.Errorf("ExUnits overflow: memory=%d cpu=%d", eu.Budget.Memory, eu.Budget.Cpu)
		}
		result[key] = common.ExUnits{Memory: int64(eu.Budget.Memory), Steps: int64(eu.Budget.Cpu)}
	}
	return result, nil
}

func (o *OgmiosChainContext) UtxoByRef(txHash common.Blake2b256, index uint32) (*common.Utxo, error) {
	return o.UtxoByRefContext(context.Background(), txHash, index)
}

func (o *OgmiosChainContext) UtxoByRefContext(
	ctx context.Context,
	txHash common.Blake2b256,
	index uint32,
) (*common.Utxo, error) {
	client, err := o.client()
	if err != nil {
		return nil, err
	}
	return client.UtxoByRef(ctx, txHash, index)
}

func (o *OgmiosChainContext) ScriptCbor(scriptHash common.Blake2b224) ([]byte, error) {
	return o.ScriptCborContext(context.Background(), scriptHash)
}

func (o *OgmiosChainContext) ScriptCborContext(
	ctx context.Context,
	scriptHash common.Blake2b224,
) ([]byte, error) {
	client, err := o.kupoClient(backend.CapabilityScriptCbor)
	if err != nil {
		return nil, err
	}
	return client.ScriptCbor(ctx, scriptHash)
}

// --- Ogmios response types and conversion ---

type ogmiosProtocolParams struct {
	// The fee- and deposit-critical parameters are decoded through pointers so
	// that a key missing from the response is reported by toProtocolParams
	// instead of defaulting to zero. Ogmios sends all of them in every era.
	MinFeeCoefficient  *int64          `json:"minFeeCoefficient"`
	MinFeeConstant     *ogmiosLovelace `json:"minFeeConstant"`
	MaxBlockBodySize   ogmiosBytes     `json:"maxBlockBodySize"`
	MaxBlockHeaderSize ogmiosBytes     `json:"maxBlockHeaderSize"`
	MaxTxSize          ogmiosBytes     `json:"maxTransactionSize"`
	StakeKeyDeposit    *ogmiosLovelace `json:"stakeCredentialDeposit"`
	PoolDeposit        *ogmiosLovelace `json:"stakePoolDeposit"`
	MinPoolCost        *ogmiosLovelace `json:"minStakePoolCost"`
	CollateralPercent  int             `json:"collateralPercentage"`
	MaxCollateral      int             `json:"maxCollateralInputs"`
	MaxValSize         ogmiosBytes     `json:"maxValueSize"`
	ScriptPrices       ogmiosPrices    `json:"scriptExecutionPrices"`
	MaxTxExUnits       ogmiosExUnits   `json:"maxExecutionUnitsPerTransaction"`
	MaxBlockExUnits    ogmiosExUnits   `json:"maxExecutionUnitsPerBlock"`
	MinUtxoDeposit     *int64          `json:"minUtxoDepositCoefficient"`
	CostModels         json.RawMessage `json:"plutusCostModels"`
	// Ogmios v6 exposes Conway reference-script pricing as a structured object
	// {base, range, multiplier}; base is the lovelace-per-byte first-tier price.
	MinFeeReferenceScripts *ogmiosRefScripts `json:"minFeeReferenceScripts"`
	// maxReferenceScriptsSize arrived in Ogmios v6.5 and was renamed to
	// maxReferenceScriptsSizePerTransaction in v7.0. Both spellings are
	// optional: Ogmios before v6.5 sends neither.
	MaxRefScriptsSize   *ogmiosBytes `json:"maxReferenceScriptsSize"`
	MaxRefScriptsSizeTx *ogmiosBytes `json:"maxReferenceScriptsSizePerTransaction"`
}

type ogmiosRefScripts struct {
	Base       json.Number `json:"base"`
	Range      int         `json:"range"`
	Multiplier json.Number `json:"multiplier"`
}

// ogmiosLovelace decodes a lovelace-valued Ogmios protocol parameter.
//
// Ogmios v6.0.x encoded these as a bare {"lovelace": N}. Since v6.1.0 they are
// Value<AdaOnly>, i.e. {"ada": {"lovelace": N}}. Both shapes are accepted so
// older deployments keep working, and an amount carrying neither key is an
// error rather than a zero: decoding an unrecognized shape to 0 in silence is
// what left every fee short by the whole minFeeConstant.
type ogmiosLovelace struct {
	Lovelace int64
}

func (l *ogmiosLovelace) UnmarshalJSON(data []byte) error {
	var wire struct {
		Ada *struct {
			Lovelace *int64 `json:"lovelace"`
		} `json:"ada"`
		Lovelace *int64 `json:"lovelace"`
	}
	if err := json.Unmarshal(data, &wire); err != nil {
		return err
	}
	switch {
	case wire.Ada != nil && wire.Ada.Lovelace != nil:
		l.Lovelace = *wire.Ada.Lovelace
	case wire.Lovelace != nil:
		l.Lovelace = *wire.Lovelace
	default:
		return fmt.Errorf(
			"unrecognized lovelace amount %s: want "+
				`{"ada":{"lovelace":N}} or {"lovelace":N}`,
			data,
		)
	}
	return nil
}

type ogmiosBytes struct {
	Bytes int `json:"bytes"`
}

type ogmiosPrices struct {
	Memory string `json:"memory"`
	CPU    string `json:"cpu"`
}

type ogmiosExUnits struct {
	Memory int64 `json:"memory"`
	CPU    int64 `json:"cpu"`
}

// missingRequired lists the protocol parameters Apollo cannot balance a
// transaction without. Reporting them is what keeps a renamed or restructured
// Ogmios field from quietly becoming a zero fee, deposit, or min-UTxO cost.
func (p *ogmiosProtocolParams) missingRequired() []string {
	required := []struct {
		name    string
		present bool
	}{
		{"minFeeCoefficient", p.MinFeeCoefficient != nil},
		{"minFeeConstant", p.MinFeeConstant != nil},
		{"minUtxoDepositCoefficient", p.MinUtxoDeposit != nil},
		{"stakeCredentialDeposit", p.StakeKeyDeposit != nil},
		{"stakePoolDeposit", p.PoolDeposit != nil},
		{"minStakePoolCost", p.MinPoolCost != nil},
	}
	missing := make([]string, 0, len(required))
	for _, field := range required {
		if !field.present {
			missing = append(missing, field.name)
		}
	}
	return missing
}

func (p *ogmiosProtocolParams) toProtocolParams() (backend.ProtocolParameters, error) {
	if missing := p.missingRequired(); len(missing) > 0 {
		return backend.ProtocolParameters{}, fmt.Errorf(
			"ogmios protocol parameters missing required fields: %s",
			strings.Join(missing, ", "),
		)
	}

	priceMem, err := backendutil.ParseFraction(p.ScriptPrices.Memory)
	if err != nil {
		return backend.ProtocolParameters{}, fmt.Errorf("invalid memory price: %w", err)
	}
	priceStep, err := backendutil.ParseFraction(p.ScriptPrices.CPU)
	if err != nil {
		return backend.ProtocolParameters{}, fmt.Errorf("invalid CPU price: %w", err)
	}

	pp := backend.ProtocolParameters{
		MinFeeConstant:      p.MinFeeConstant.Lovelace,
		MinFeeCoefficient:   *p.MinFeeCoefficient,
		MaxBlockSize:        p.MaxBlockBodySize.Bytes,
		MaxTxSize:           p.MaxTxSize.Bytes,
		MaxBlockHeaderSize:  p.MaxBlockHeaderSize.Bytes,
		KeyDeposits:         strconv.FormatInt(p.StakeKeyDeposit.Lovelace, 10),
		PoolDeposits:        strconv.FormatInt(p.PoolDeposit.Lovelace, 10),
		MinPoolCost:         strconv.FormatInt(p.MinPoolCost.Lovelace, 10),
		PriceMem:            priceMem,
		PriceStep:           priceStep,
		MaxTxExMem:          strconv.FormatInt(p.MaxTxExUnits.Memory, 10),
		MaxTxExSteps:        strconv.FormatInt(p.MaxTxExUnits.CPU, 10),
		MaxBlockExMem:       strconv.FormatInt(p.MaxBlockExUnits.Memory, 10),
		MaxBlockExSteps:     strconv.FormatInt(p.MaxBlockExUnits.CPU, 10),
		MaxValSize:          strconv.Itoa(p.MaxValSize.Bytes),
		CollateralPercent:   p.CollateralPercent,
		MaxCollateralInputs: p.MaxCollateral,
		CoinsPerUtxoByte:    strconv.FormatInt(*p.MinUtxoDeposit, 10),
	}

	switch {
	case p.MaxRefScriptsSize != nil:
		pp.MaximumReferenceScriptsSize = p.MaxRefScriptsSize.Bytes
	case p.MaxRefScriptsSizeTx != nil:
		pp.MaximumReferenceScriptsSize = p.MaxRefScriptsSizeTx.Bytes
	}

	if p.MinFeeReferenceScripts != nil {
		base, err := backendutil.ParseRational(p.MinFeeReferenceScripts.Base.String())
		if err != nil {
			return backend.ProtocolParameters{}, fmt.Errorf("invalid reference-script base price: %w", err)
		}
		multiplier, err := backendutil.ParseRational(p.MinFeeReferenceScripts.Multiplier.String())
		if err != nil {
			return backend.ProtocolParameters{}, fmt.Errorf("invalid reference-script multiplier: %w", err)
		}
		pp.MinFeeReferenceScriptsRange = p.MinFeeReferenceScripts.Range
		pp.MinFeeRefScriptCostPerByteRational = base
		pp.MinFeeReferenceScriptsMultiplierRational = multiplier
		// Preserve the legacy float fields for callers that read them directly.
		pp.MinFeeRefScriptCostPerByte, _ = base.Float64()
	}

	// Parse cost models from Ogmios JSON.
	// Ogmios uses keys like "plutus:v1" through "plutus:v4".
	// ComputeScriptDataHash expects "PlutusV1" through "PlutusV4".
	if len(p.CostModels) > 0 {
		var rawModels map[string][]int64
		if err := json.Unmarshal(p.CostModels, &rawModels); err != nil {
			return backend.ProtocolParameters{}, fmt.Errorf("failed to parse cost models: %w", err)
		}
		pp.CostModels = make(map[string][]int64, len(rawModels))
		for key, costs := range rawModels {
			pp.CostModels[ogmiosCostModelKey(key)] = costs
		}
	}

	return pp, nil
}

// ogmiosCostModelKey translates Ogmios cost model keys to the canonical form
// expected by ComputeScriptDataHash ("PlutusV1" through "PlutusV4").
func ogmiosCostModelKey(key string) string {
	switch key {
	case "plutus:v1":
		return "PlutusV1"
	case "plutus:v2":
		return "PlutusV2"
	case "plutus:v3":
		return "PlutusV3"
	case "plutus:v4":
		return "PlutusV4"
	default:
		return key
	}
}

type ogmiosGenesisConfig struct {
	// Ogmios reports the system start as an ISO-8601 timestamp, while
	// GenesisParameters carries Unix seconds like the other backends.
	StartTime         string           `json:"startTime"`
	NetworkMagic      int              `json:"networkMagic"`
	EpochLength       int              `json:"epochLength"`
	SlotLength        ogmiosSlotLength `json:"slotLength"`
	SlotsPerKesPeriod int              `json:"slotsPerKesPeriod"`
	MaxKesEvolutions  int              `json:"maxKesEvolutions"`
	SecurityParam     int              `json:"securityParameter"`
	UpdateQuorum      int              `json:"updateQuorum"`
	ActiveSlots       ogmiosRatio      `json:"activeSlotsCoefficient"`
	MaxLovelaceSupply int64            `json:"maxLovelaceSupply"`
}

// ogmiosRatio decodes an Ogmios ratio. Ogmios v6 sends these as exact
// "numerator/denominator" strings (e.g. "1/20" for the mainnet active-slots
// coefficient); v5 sent a bare JSON number. Both are accepted, and a value in
// neither form is an error rather than a zero.
type ogmiosRatio struct {
	Value float64
}

func (r *ogmiosRatio) UnmarshalJSON(data []byte) error {
	var text string
	if err := json.Unmarshal(data, &text); err == nil {
		value, parseErr := backendutil.ParseFraction(text)
		if parseErr != nil {
			return fmt.Errorf("invalid ratio %q: %w", text, parseErr)
		}
		r.Value = value
		return nil
	}
	var number float64
	if err := json.Unmarshal(data, &number); err != nil {
		return fmt.Errorf(
			"unrecognized ratio %s: want a \"num/den\" string or a number",
			data,
		)
	}
	r.Value = number
	return nil
}

// ogmiosSlotLength decodes an Ogmios slot length. Ogmios v6 sends
// {"milliseconds": N}; v5 sent a bare number of seconds. Both are accepted and
// normalized to the whole seconds that GenesisParameters.SlotLength reports.
//
// That field is defined in seconds across every backend, so a sub-second slot
// length is not representable and is truncated toward zero. No Cardano network
// uses one: Shelley onward is 1000ms and Byron was 20000ms. Should that ever
// change, the field's unit has to change with it rather than this conversion.
type ogmiosSlotLength struct {
	Seconds int
}

func (s *ogmiosSlotLength) UnmarshalJSON(data []byte) error {
	var wire struct {
		Milliseconds *int64 `json:"milliseconds"`
	}
	if err := json.Unmarshal(data, &wire); err == nil &&
		wire.Milliseconds != nil {
		millis := *wire.Milliseconds
		if millis < 0 || millis/1000 > math.MaxInt32 {
			return fmt.Errorf("slot length out of range: %d ms", millis)
		}
		s.Seconds = int(millis / 1000)
		return nil
	}
	var seconds int
	if err := json.Unmarshal(data, &seconds); err != nil {
		return fmt.Errorf(
			`unrecognized slot length %s: want {"milliseconds":N} or N`,
			data,
		)
	}
	s.Seconds = seconds
	return nil
}

func (g *ogmiosGenesisConfig) toGenesisParams() (
	backend.GenesisParameters,
	error,
) {
	systemStart, err := parseOgmiosStartTime(g.StartTime)
	if err != nil {
		return backend.GenesisParameters{}, err
	}

	return backend.GenesisParameters{
		ActiveSlotsCoefficient: g.ActiveSlots.Value,
		UpdateQuorum:           g.UpdateQuorum,
		NetworkMagic:           g.NetworkMagic,
		EpochLength:            g.EpochLength,
		MaxLovelaceSupply:      strconv.FormatInt(g.MaxLovelaceSupply, 10),
		SystemStart:            systemStart,
		SlotLength:             g.SlotLength.Seconds,
		SlotsPerKesPeriod:      g.SlotsPerKesPeriod,
		MaxKesEvolutions:       g.MaxKesEvolutions,
		SecurityParam:          g.SecurityParam,
	}, nil
}

// parseOgmiosStartTime converts an Ogmios ISO-8601 genesis start time to the
// Unix seconds reported by GenesisParameters. The Ogmios schema makes the
// trailing zone designator optional, so a bare local-style timestamp is
// accepted as UTC. An empty value yields zero; anything unparseable is an
// error rather than a zero timestamp.
func parseOgmiosStartTime(value string) (int64, error) {
	if value == "" {
		return 0, nil
	}
	for _, layout := range []string{time.RFC3339, "2006-01-02T15:04:05"} {
		if parsed, err := time.Parse(layout, value); err == nil {
			return parsed.Unix(), nil
		}
	}
	return 0, fmt.Errorf("invalid genesis start time %q", value)
}

// datumFetcher resolves a datum's CBOR (hex-encoded) by its hash. It is
// implemented by *kugo.Client via the Kupo /v1/datums/{hash} endpoint.
type datumFetcher interface {
	Datum(ctx context.Context, datumHash string) (string, error)
}

// Kugo v1.3.1 does not export a Plutus V4 language constant yet. Retain the
// wire value here so this conversion supports it as soon as Kugo can decode
// a "plutus:v4" response.
const kupoScriptLanguagePlutusV4 kugo.ScriptLanguage = 4

func matchToUtxo(ctx context.Context, match kugo.Match, address common.Address, datums datumFetcher) (common.Utxo, error) {
	hashBytes, err := hex.DecodeString(match.TransactionID)
	if err != nil {
		return common.Utxo{}, err
	}
	if len(hashBytes) != common.Blake2b256Size {
		return common.Utxo{}, fmt.Errorf("invalid tx hash length: expected %d bytes, got %d", common.Blake2b256Size, len(hashBytes))
	}
	var txId common.Blake2b256
	copy(txId[:], hashBytes)
	if match.OutputIndex < 0 {
		return common.Utxo{}, fmt.Errorf("negative output index: %d", match.OutputIndex)
	}
	if uint64(match.OutputIndex) > uint64(math.MaxUint32) {
		return common.Utxo{}, fmt.Errorf("output index %d exceeds uint32 range", match.OutputIndex)
	}
	utxo, err := sharedValueToUtxo(txId, uint32(match.OutputIndex), shared.Value(match.Value), address)
	if err != nil {
		return common.Utxo{}, err
	}
	output, ok := utxo.Output.(*babbage.BabbageTransactionOutput)
	if !ok {
		return common.Utxo{}, fmt.Errorf("unexpected UTxO output type: %T", utxo.Output)
	}

	// Set datum option from kupo match data. Kupo only returns the datum hash
	// in matches; its datum_type discriminator says whether the on-chain
	// output carried an inline datum or just the hash.
	if match.DatumHash != "" {
		switch match.DatumType {
		case "inline":
			opt, err := fetchInlineDatumOption(ctx, datums, match.DatumHash)
			if err != nil {
				return common.Utxo{}, err
			}
			output.DatumOption = opt
		case "hash":
			opt, err := parseDatumOption(match.DatumHash)
			if err != nil {
				return common.Utxo{}, fmt.Errorf("failed to parse datum option: %w", err)
			}
			output.DatumOption = opt
		default:
			return common.Utxo{}, fmt.Errorf("unsupported kupo datum type %q for datum hash %s", match.DatumType, match.DatumHash)
		}
	}

	// Set script reference from kupo match data, verifying the script bytes
	// against the script hash claimed by kupo.
	if match.Script.Script != "" {
		ref, err := kupoScriptToScriptRef(match.Script, match.ScriptHash)
		if err != nil {
			return common.Utxo{}, fmt.Errorf("failed to parse script ref: %w", err)
		}
		output.TxOutScriptRef = ref
	}

	return utxo, nil
}

// fetchInlineDatumOption fetches the inline datum bytes for the given datum
// hash from Kupo and builds an inline datum option. The fetched bytes are
// verified against the datum hash before use; a mismatch fails closed.
func fetchInlineDatumOption(ctx context.Context, datums datumFetcher, datumHashHex string) (*babbage.BabbageTransactionOutputDatumOption, error) {
	if datums == nil {
		return nil, fmt.Errorf("kupo client required to resolve inline datum %s", datumHashHex)
	}
	expectedBytes, err := hex.DecodeString(datumHashHex)
	if err != nil {
		return nil, fmt.Errorf("invalid datum hash hex %q: %w", datumHashHex, err)
	}
	if len(expectedBytes) != common.Blake2b256Size {
		return nil, fmt.Errorf("invalid datum hash length: expected %d bytes, got %d", common.Blake2b256Size, len(expectedBytes))
	}
	var expected common.Blake2b256
	copy(expected[:], expectedBytes)

	datumCborHex, err := datums.Datum(ctx, datumHashHex)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch inline datum %s: %w", datumHashHex, err)
	}
	if datumCborHex == "" {
		return nil, fmt.Errorf("kupo returned no datum for inline datum hash %s", datumHashHex)
	}
	datumBytes, err := hex.DecodeString(datumCborHex)
	if err != nil {
		return nil, fmt.Errorf("invalid inline datum CBOR hex %q: %w", datumCborHex, err)
	}
	if computed := common.Blake2b256Hash(datumBytes); computed != expected {
		return nil, fmt.Errorf("inline datum hash mismatch for %s: fetched datum hashes to %s",
			datumHashHex, hex.EncodeToString(computed.Bytes()))
	}
	return parseInlineDatumCbor(datumCborHex)
}

func ogmiosUtxoToCommon(raw shared.Utxo, addr common.Address) (common.Utxo, error) {
	hashBytes, err := hex.DecodeString(raw.Transaction.ID)
	if err != nil {
		return common.Utxo{}, err
	}
	if len(hashBytes) != common.Blake2b256Size {
		return common.Utxo{}, fmt.Errorf("invalid tx hash length: expected %d bytes, got %d", common.Blake2b256Size, len(hashBytes))
	}
	var txId common.Blake2b256
	copy(txId[:], hashBytes)
	utxo, err := sharedValueToUtxo(txId, raw.Index, raw.Value, addr)
	if err != nil {
		return common.Utxo{}, err
	}
	output, ok := utxo.Output.(*babbage.BabbageTransactionOutput)
	if !ok {
		return common.Utxo{}, fmt.Errorf("unexpected UTxO output type: %T", utxo.Output)
	}

	// Set datum option from ogmios UTxO data.
	// Ogmios provides inline datum CBOR hex in the Datum field,
	// and the datum hash in DatumHash.
	if raw.Datum != "" {
		// Inline datum: Datum field contains the CBOR hex of the datum.
		opt, err := parseInlineDatumCbor(raw.Datum)
		if err != nil {
			return common.Utxo{}, fmt.Errorf("failed to parse inline datum: %w", err)
		}
		output.DatumOption = opt
	} else if raw.DatumHash != "" {
		// Datum hash only.
		opt, err := parseDatumOption(raw.DatumHash)
		if err != nil {
			return common.Utxo{}, fmt.Errorf("failed to parse datum hash: %w", err)
		}
		output.DatumOption = opt
	}

	// Set script reference from ogmios UTxO data.
	if len(raw.Script) > 0 && string(raw.Script) != "null" {
		ref, err := ogmiosScriptToScriptRef(raw.Script)
		if err != nil {
			return common.Utxo{}, fmt.Errorf("failed to parse script ref: %w", err)
		}
		if ref != nil {
			output.TxOutScriptRef = ref
		}
	}

	return utxo, nil
}

func sharedValueToUtxo(txId common.Blake2b256, outputIndex uint32, value shared.Value, addr common.Address) (common.Utxo, error) {
	input := shelley.ShelleyTransactionInput{
		TxId:        txId,
		OutputIndex: outputIndex,
	}

	// Require int64 range (not just uint64) to match the other backends and
	// keep downstream signed lovelace arithmetic safe.
	lovelaceBig := value.AdaLovelace().BigInt()
	if lovelaceBig.Sign() < 0 || !lovelaceBig.IsInt64() {
		return common.Utxo{}, fmt.Errorf("invalid lovelace quantity %s", lovelaceBig.String())
	}
	lovelace := lovelaceBig.Uint64()
	assetData := make(map[common.Blake2b224]map[cbor.ByteString]*big.Int)

	for policyIdStr, assets := range value {
		if policyIdStr == "ada" {
			continue
		}
		policyBytes, err := hex.DecodeString(policyIdStr)
		if err != nil {
			return common.Utxo{}, fmt.Errorf("invalid policy ID hex %q: %w", policyIdStr, err)
		}
		if len(policyBytes) != common.Blake2b224Size {
			return common.Utxo{}, fmt.Errorf("invalid policy ID length for %q: expected %d bytes, got %d", policyIdStr, common.Blake2b224Size, len(policyBytes))
		}
		var policyId common.Blake2b224
		copy(policyId[:], policyBytes)

		for assetName, qty := range assets {
			qtyBig := qty.BigInt()
			if qtyBig.Sign() < 0 {
				return common.Utxo{}, fmt.Errorf("negative asset quantity %s for policy %s asset %s", qtyBig.String(), policyIdStr, assetName)
			}
			nameBytes, err := hex.DecodeString(assetName)
			if err != nil {
				return common.Utxo{}, fmt.Errorf("invalid asset name hex %q: %w (asset names must be hex-encoded)", assetName, err)
			}
			if _, ok := assetData[policyId]; !ok {
				assetData[policyId] = make(map[cbor.ByteString]*big.Int)
			}
			assetData[policyId][cbor.NewByteString(nameBytes)] = new(big.Int).Set(qtyBig)
		}
	}

	var assets *common.MultiAsset[common.MultiAssetTypeOutput]
	if len(assetData) > 0 {
		ma := common.NewMultiAsset[common.MultiAssetTypeOutput](assetData)
		assets = &ma
	}

	output := babbage.BabbageTransactionOutput{
		OutputAddress: addr,
		OutputAmount: mary.MaryTransactionOutputValue{
			Amount: lovelace,
			Assets: assets,
		},
	}

	return common.Utxo{
		Id:     input,
		Output: &output,
	}, nil
}

// parseDatumOption constructs a BabbageTransactionOutputDatumOption from a datum hash hex string.
// It always creates a datum hash reference (type 0). For inline datums, use parseInlineDatumCbor
// which requires the full datum CBOR.
func parseDatumOption(datumHashHex string) (*babbage.BabbageTransactionOutputDatumOption, error) {
	hashBytes, err := hex.DecodeString(datumHashHex)
	if err != nil {
		return nil, fmt.Errorf("invalid datum hash hex %q: %w", datumHashHex, err)
	}
	if len(hashBytes) != common.Blake2b256Size {
		return nil, fmt.Errorf("invalid datum hash length: expected %d bytes, got %d", common.Blake2b256Size, len(hashBytes))
	}
	var hash common.Blake2b256
	copy(hash[:], hashBytes)

	cborBytes, err := cbor.Encode([]any{0, hash})
	if err != nil {
		return nil, fmt.Errorf("failed to encode datum option: %w", err)
	}
	var opt babbage.BabbageTransactionOutputDatumOption
	if err := opt.UnmarshalCBOR(cborBytes); err != nil {
		return nil, fmt.Errorf("failed to unmarshal datum option: %w", err)
	}
	return &opt, nil
}

// parseInlineDatumCbor constructs a BabbageTransactionOutputDatumOption for an inline datum
// from its CBOR hex representation (as returned by Ogmios).
func parseInlineDatumCbor(datumCborHex string) (*babbage.BabbageTransactionOutputDatumOption, error) {
	datumBytes, err := hex.DecodeString(datumCborHex)
	if err != nil {
		return nil, fmt.Errorf("invalid datum CBOR hex %q: %w", datumCborHex, err)
	}
	// Inline datum option: [1, #6.24(datum_cbor)]
	cborBytes, err := cbor.Encode([]any{1, cbor.Tag{Number: 24, Content: datumBytes}})
	if err != nil {
		return nil, fmt.Errorf("failed to encode inline datum option: %w", err)
	}
	var opt babbage.BabbageTransactionOutputDatumOption
	if err := opt.UnmarshalCBOR(cborBytes); err != nil {
		return nil, fmt.Errorf("failed to unmarshal inline datum option: %w", err)
	}
	return &opt, nil
}

// kupoScriptToScriptRef converts a kugo Script to a common.ScriptRef. When
// kupo supplies the script hash (expectedHashHex non-empty), the script bytes
// are verified against it rather than trusted as-is.
func kupoScriptToScriptRef(script kugo.Script, expectedHashHex string) (*common.ScriptRef, error) {
	scriptBytes, err := hex.DecodeString(script.Script)
	if err != nil {
		return nil, fmt.Errorf("invalid script hex %q: %w", script.Script, err)
	}

	var scriptType uint
	switch script.Language {
	case kugo.ScriptLanguageNative:
		scriptType = common.ScriptRefTypeNativeScript
	case kugo.ScriptLanguagePlutusV1:
		scriptType = common.ScriptRefTypePlutusV1
	case kugo.ScriptLanguagePlutusV2:
		scriptType = common.ScriptRefTypePlutusV2
	case kugo.ScriptLanguagePlutusV3:
		scriptType = common.ScriptRefTypePlutusV3
	case kupoScriptLanguagePlutusV4:
		scriptType = common.ScriptRefTypePlutusV4
	default:
		return nil, fmt.Errorf("unsupported kupo script language: %d", script.Language)
	}

	return backendutil.ScriptRefFromBytes(scriptType, scriptBytes, expectedHashHex)
}

// ogmiosScriptToScriptRef converts an Ogmios script JSON to a common.ScriptRef.
// Ogmios v6 uses: {"language": "plutus:v1" through "plutus:v4"|"native", "cbor": "hex"}
// Ogmios does not include the script hash in UTxO responses, so no hash
// verification is possible here.
func ogmiosScriptToScriptRef(scriptJSON json.RawMessage) (*common.ScriptRef, error) {
	var raw struct {
		Language string `json:"language"`
		Cbor     string `json:"cbor"`
	}
	if err := json.Unmarshal(scriptJSON, &raw); err != nil {
		return nil, fmt.Errorf("failed to parse script JSON: %w", err)
	}
	if raw.Cbor == "" {
		// Native scripts may use "json" field instead of "cbor"; skip these for now.
		return nil, nil
	}

	scriptBytes, err := hex.DecodeString(raw.Cbor)
	if err != nil {
		return nil, fmt.Errorf("invalid script CBOR hex %q: %w", raw.Cbor, err)
	}

	var scriptType uint
	switch raw.Language {
	case "native":
		scriptType = common.ScriptRefTypeNativeScript
	case "plutus:v1":
		scriptType = common.ScriptRefTypePlutusV1
	case "plutus:v2":
		scriptType = common.ScriptRefTypePlutusV2
	case "plutus:v3":
		scriptType = common.ScriptRefTypePlutusV3
	case "plutus:v4":
		scriptType = common.ScriptRefTypePlutusV4
	default:
		return nil, fmt.Errorf("unsupported ogmios script language %q", raw.Language)
	}

	return backendutil.ScriptRefFromBytes(scriptType, scriptBytes, "")
}
