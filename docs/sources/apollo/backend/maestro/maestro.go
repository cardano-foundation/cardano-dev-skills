package maestro

import (
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"math/big"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/babbage"
	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/gouroboros/ledger/mary"
	"github.com/blinklabs-io/gouroboros/ledger/shelley"
	maestroClient "github.com/maestro-org/go-sdk/client"
	"github.com/maestro-org/go-sdk/models"
	"github.com/maestro-org/go-sdk/utils"

	"github.com/Salvionied/apollo/v2/backend"
	"github.com/Salvionied/apollo/v2/internal/backendutil"
)

// MaestroChainContext implements backend.ChainContext using the Maestro API.
type MaestroChainContext struct {
	client    *maestroClient.Client
	networkId uint8
	// apiKey is retained alongside the SDK client because the SDK keeps its
	// own copy unexported. EvaluateTx with additional UTxOs issues a raw POST
	// (the SDK's additional_utxos field is []string and cannot carry the
	// object-shaped entries Maestro requires) and needs the key for auth.
	apiKey string
}

const (
	maxMaestroEvaluateErrorResponseBytes = 64 * 1024
	defaultMaestroHTTPTimeout            = 30 * time.Second
)

type contextTransport struct {
	ctx  context.Context
	base http.RoundTripper
}

func (t contextTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	return t.base.RoundTrip(req.Clone(t.ctx))
}

func (m *MaestroChainContext) clientWithContext(ctx context.Context) *maestroClient.Client {
	if ctx == nil {
		ctx = context.Background()
	}
	client := *m.client
	httpClient := client.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: defaultMaestroHTTPTimeout}
	}
	contextClient := *httpClient
	transport := contextClient.Transport
	if transport == nil {
		transport = http.DefaultTransport
	}
	contextClient.Transport = contextTransport{ctx: ctx, base: transport}
	client.HTTPClient = &contextClient
	return &client
}

// Capabilities reports the Maestro operations supported by this client.
func (m *MaestroChainContext) Capabilities() backend.CapabilitySet {
	return backend.CapabilitySet(backend.AllCapabilities) &^ backend.CapabilitySet(backend.CapabilityGenesisParams)
}

// NewMaestroChainContext creates a new Maestro chain context.
func NewMaestroChainContext(networkId uint8, projectId string) (*MaestroChainContext, error) {
	networkStr := networkString(networkId)
	client := maestroClient.NewClient(projectId, networkStr)
	return &MaestroChainContext{
		client:    client,
		networkId: networkId,
		apiKey:    projectId,
	}, nil
}

// networkString maps Cardano network ID to Maestro API network name.
// In Cardano, network ID 1 = mainnet, network ID 0 = testnet.
// For testnet, defaults to "preprod". Use NewMaestroChainContextWithNetwork
// for other testnet variants (e.g. "preview").
func networkString(networkId uint8) string {
	if networkId == 1 {
		return "mainnet"
	}
	return "preprod"
}

// supportedMaestroNetworks are the networks the Maestro API serves
// (https://{network}.gomaestro-api.org/v1).
var supportedMaestroNetworks = map[string]bool{
	"mainnet": true,
	"preprod": true,
	"preview": true,
}

// NewMaestroChainContextWithNetwork creates a Maestro chain context with an explicit network name.
// Use this for testnet variants like "preview" where the network ID alone (0) is ambiguous.
// The network must be one of "mainnet", "preprod" or "preview": the Maestro SDK
// interpolates it into the API hostname, so arbitrary values are rejected.
func NewMaestroChainContextWithNetwork(networkId uint8, projectId string, network string) (*MaestroChainContext, error) {
	normalized := strings.ToLower(network)
	if !supportedMaestroNetworks[normalized] {
		return nil, fmt.Errorf("unsupported maestro network %q: must be one of mainnet, preprod, preview", network)
	}
	client := maestroClient.NewClient(projectId, normalized)
	return &MaestroChainContext{
		client:    client,
		networkId: networkId,
		apiKey:    projectId,
	}, nil
}

func (m *MaestroChainContext) ProtocolParams() (backend.ProtocolParameters, error) {
	return m.ProtocolParamsContext(context.Background())
}

func (m *MaestroChainContext) ProtocolParamsContext(ctx context.Context) (backend.ProtocolParameters, error) {
	resp, err := m.clientWithContext(ctx).ProtocolParameters()
	if err != nil {
		return backend.ProtocolParameters{}, err
	}

	data := resp.Data
	priceMem, err := backendutil.ParseFraction(data.ScriptExecutionPrices.Memory)
	if err != nil {
		return backend.ProtocolParameters{}, fmt.Errorf("invalid memory price: %w", err)
	}
	priceStep, err := backendutil.ParseFraction(data.ScriptExecutionPrices.Steps)
	if err != nil {
		return backend.ProtocolParameters{}, fmt.Errorf("invalid step price: %w", err)
	}

	maxBlockSize, err := backendutil.BoundedInt(data.MaxBlockBodySize.Bytes, "max block body size")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	maxTxSize, err := backendutil.BoundedInt(data.MaxTransactionSize.Bytes, "max transaction size")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	maxBlockHeaderSize, err := backendutil.BoundedInt(data.MaxBlockHeaderSize.Bytes, "max block header size")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	collateralPercent, err := backendutil.BoundedInt(data.CollateralPercentage, "collateral percentage")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	maxCollateralInputs, err := backendutil.BoundedInt(data.MaxCollateralInputs, "max collateral inputs")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}

	pp := backend.ProtocolParameters{
		MinFeeCoefficient:   data.MinFeeCoefficient,
		MinFeeConstant:      data.MinFeeConstant.LovelaceAmount.Lovelace,
		MaxBlockSize:        maxBlockSize,
		MaxTxSize:           maxTxSize,
		MaxBlockHeaderSize:  maxBlockHeaderSize,
		KeyDeposits:         strconv.FormatInt(data.StakeCredentialDeposit.LovelaceAmount.Lovelace, 10),
		PoolDeposits:        strconv.FormatInt(data.StakePoolDeposit.LovelaceAmount.Lovelace, 10),
		MinPoolCost:         strconv.FormatInt(data.MinStakePoolCost.LovelaceAmount.Lovelace, 10),
		MaxTxExMem:          strconv.FormatInt(data.MaxExecutionUnitsPerTransaction.Memory, 10),
		MaxTxExSteps:        strconv.FormatInt(data.MaxExecutionUnitsPerTransaction.Steps, 10),
		MaxBlockExMem:       strconv.FormatInt(data.MaxExecutionUnitsPerBlock.Memory, 10),
		MaxBlockExSteps:     strconv.FormatInt(data.MaxExecutionUnitsPerBlock.Steps, 10),
		MaxValSize:          strconv.FormatInt(data.MaxValueSize.Bytes, 10),
		CollateralPercent:   collateralPercent,
		MaxCollateralInputs: maxCollateralInputs,
		CoinsPerUtxoByte:    strconv.FormatInt(data.MinUtxoDepositCoefficient, 10),
		PriceMem:            priceMem,
		PriceStep:           priceStep,
	}

	// Parse cost models from Maestro response.
	// PlutusCostModels is typed as `any`; when unmarshaled from JSON it is
	// map[string]interface{} with keys like "plutus:v1" through "plutus:v4"
	// and values that are []interface{} of float64.
	// ComputeScriptDataHash expects keys "PlutusV1" through "PlutusV4".
	if rawModels, ok := data.PlutusCostModels.(map[string]any); ok {
		pp.CostModels = make(map[string][]int64, len(rawModels))
		for key, val := range rawModels {
			costs, ok := val.([]any)
			if !ok {
				return backend.ProtocolParameters{}, fmt.Errorf("unexpected cost model format for %s: expected []any, got %T", key, val)
			}
			int64Costs := make([]int64, 0, len(costs))
			for i, c := range costs {
				f, ok := c.(float64)
				if !ok {
					return backend.ProtocolParameters{}, fmt.Errorf("cost model %q element %d: expected float64, got %T", key, i, c)
				}
				// Reject non-integral or out-of-int64-range values rather than
				// silently truncating (out-of-range float-to-int conversion is
				// implementation-defined in Go).
				if f != math.Trunc(f) || f < math.MinInt64 || f >= math.MaxInt64 {
					return backend.ProtocolParameters{}, fmt.Errorf("cost model %q element %d: value %v is not a valid int64", key, i, f)
				}
				int64Costs = append(int64Costs, int64(f))
			}
			pp.CostModels[maestroCostModelKey(key)] = int64Costs
		}
	}

	return pp, nil
}

func (m *MaestroChainContext) GenesisParams() (backend.GenesisParameters, error) {
	return m.GenesisParamsContext(context.Background())
}

func (m *MaestroChainContext) GenesisParamsContext(ctx context.Context) (backend.GenesisParameters, error) {
	if ctx != nil {
		if err := ctx.Err(); err != nil {
			return backend.GenesisParameters{}, err
		}
	}
	return backend.GenesisParameters{}, backend.NewUnsupportedError("Maestro", backend.CapabilityGenesisParams)
}

func (m *MaestroChainContext) NetworkId() uint8 {
	return m.networkId
}

func (m *MaestroChainContext) CurrentEpoch() (uint64, error) {
	return m.CurrentEpochContext(context.Background())
}

func (m *MaestroChainContext) CurrentEpochContext(ctx context.Context) (uint64, error) {
	resp, err := m.clientWithContext(ctx).CurrentEpoch()
	if err != nil {
		return 0, err
	}
	if resp.Data.EpochNo < 0 {
		return 0, fmt.Errorf("invalid epoch value: %d", resp.Data.EpochNo)
	}
	return uint64(resp.Data.EpochNo), nil
}

func (m *MaestroChainContext) MaxTxFee() (uint64, error) {
	return m.MaxTxFeeContext(context.Background())
}

func (m *MaestroChainContext) MaxTxFeeContext(ctx context.Context) (uint64, error) {
	pp, err := m.ProtocolParamsContext(ctx)
	if err != nil {
		return 0, err
	}
	return backend.ComputeMaxTxFee(pp)
}

func (m *MaestroChainContext) Tip() (uint64, error) {
	return m.TipContext(context.Background())
}

func (m *MaestroChainContext) TipContext(ctx context.Context) (uint64, error) {
	resp, err := m.clientWithContext(ctx).ChainTip()
	if err != nil {
		return 0, err
	}
	if resp.Data.Slot < 0 {
		return 0, fmt.Errorf("invalid slot value: %d", resp.Data.Slot)
	}
	return uint64(resp.Data.Slot), nil
}

func (m *MaestroChainContext) Utxos(address common.Address) ([]common.Utxo, error) {
	return m.UtxosContext(context.Background(), address)
}

func (m *MaestroChainContext) UtxosContext(ctx context.Context, address common.Address) ([]common.Utxo, error) {
	const maxPages = 1000
	var allUtxos []common.Utxo
	params := utils.NewParameters()
	var lastCursor string
	client := m.clientWithContext(ctx)

	for range maxPages {
		resp, err := client.UtxosAtAddress(address.String(), params)
		if err != nil {
			return nil, err
		}

		for _, raw := range resp.Data {
			utxo, err := maestroUtxoToCommon(raw, address)
			if err != nil {
				return nil, fmt.Errorf("failed to parse UTxO: %w", err)
			}
			allUtxos = append(allUtxos, utxo)
		}

		lastCursor = resp.NextCursor
		if lastCursor == "" {
			break
		}
		params = utils.NewParameters()
		params.Cursor(lastCursor)
	}

	if lastCursor != "" {
		return nil, fmt.Errorf("UTxO pagination exceeded %d pages; results may be incomplete", maxPages)
	}

	return allUtxos, nil
}

func (m *MaestroChainContext) SubmitTx(txCbor []byte) (common.Blake2b256, error) {
	return m.SubmitTxContext(context.Background(), txCbor)
}

func (m *MaestroChainContext) SubmitTxContext(ctx context.Context, txCbor []byte) (common.Blake2b256, error) {
	// The Maestro SDK's Client.SubmitTx posts to a corrupted URL
	// ("/submitmodels.BasicResponse{}/tx") and can never work. Use
	// TxManagerSubmit instead, which posts the hex-encoded transaction
	// CBOR to the documented POST /txmanager submit endpoint.
	txCborHex := hex.EncodeToString(txCbor)
	txHash, err := m.clientWithContext(ctx).TxManagerSubmit(txCborHex)
	if err != nil {
		return common.Blake2b256{}, fmt.Errorf("maestro tx submission failed: %w", err)
	}
	// The endpoint returns the tx hash as a plain-text body; tolerate JSON
	// string quoting and surrounding whitespace.
	txHash = strings.Trim(strings.TrimSpace(txHash), `"`)
	hashBytes, err := hex.DecodeString(txHash)
	if err != nil {
		return common.Blake2b256{}, fmt.Errorf("invalid tx hash %q in submit response: %w", txHash, err)
	}
	if len(hashBytes) != common.Blake2b256Size {
		return common.Blake2b256{}, fmt.Errorf("invalid tx hash length: expected %d bytes, got %d", common.Blake2b256Size, len(hashBytes))
	}
	var result common.Blake2b256
	copy(result[:], hashBytes)
	return result, nil
}

// EvaluateTx evaluates the script execution budgets for a transaction. When
// additionalUtxos is empty it uses the Maestro SDK's EvaluateTx, which posts the
// bare tx CBOR. When resolved UTxOs are supplied (e.g. off-chain or chained
// inputs not yet visible to Maestro) it issues a raw POST to
// /transactions/evaluate with the documented object-shaped additional_utxos
// field. The SDK's own additional_utxos type is []string and cannot represent
// the required {tx_hash, index, txout_cbor} entries, so the request is built
// here against the SDK client's base URL and API key.
func (m *MaestroChainContext) EvaluateTx(txCbor []byte, additionalUtxos []common.Utxo) (map[common.RedeemerKey]common.ExUnits, error) {
	return m.EvaluateTxContext(context.Background(), txCbor, additionalUtxos)
}

func (m *MaestroChainContext) EvaluateTxContext(
	ctx context.Context,
	txCbor []byte,
	additionalUtxos []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, error) {
	txHex := hex.EncodeToString(txCbor)

	if len(additionalUtxos) == 0 {
		evalResp, err := m.clientWithContext(ctx).EvaluateTx(txHex)
		if err != nil {
			return nil, err
		}
		return evaluationsToExUnits(evalResp)
	}

	reqBody, err := buildEvaluateRequest(txHex, additionalUtxos)
	if err != nil {
		return nil, err
	}
	evalResp, err := m.postEvaluateContext(ctx, reqBody)
	if err != nil {
		return nil, err
	}
	return evaluationsToExUnits(evalResp)
}

// maestroAdditionalUtxo is a single additional_utxos entry: a transaction
// reference plus the hex-encoded CBOR of the resolved output.
type maestroAdditionalUtxo struct {
	TxHash    string `json:"tx_hash"`
	Index     int    `json:"index"`
	TxoutCbor string `json:"txout_cbor"`
}

// maestroEvaluateRequest is the JSON body for POST /transactions/evaluate.
type maestroEvaluateRequest struct {
	Cbor            string                  `json:"cbor"`
	AdditionalUtxos []maestroAdditionalUtxo `json:"additional_utxos"`
}

// buildEvaluateRequest marshals the evaluate request body, encoding each
// resolved UTxO into its {tx_hash, index, txout_cbor} entry.
func buildEvaluateRequest(txHex string, additionalUtxos []common.Utxo) ([]byte, error) {
	items := make([]maestroAdditionalUtxo, 0, len(additionalUtxos))
	for _, utxo := range additionalUtxos {
		item, err := maestroAdditionalUtxoFromUtxo(utxo)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	req := maestroEvaluateRequest{
		Cbor:            txHex,
		AdditionalUtxos: items,
	}
	body, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal evaluate request: %w", err)
	}
	return body, nil
}

// maestroAdditionalUtxoFromUtxo builds an additional_utxos entry from a resolved
// gouroboros UTxO. txout_cbor is the CBOR encoding of the resolved output; it is
// produced via cbor.Encode (the output's MarshalCBOR) rather than the cached
// Cbor() bytes so outputs built in memory are encoded correctly.
func maestroAdditionalUtxoFromUtxo(utxo common.Utxo) (maestroAdditionalUtxo, error) {
	if utxo.Output == nil {
		return maestroAdditionalUtxo{}, errors.New("additional UTxO is missing its resolved output")
	}
	if utxo.Id == nil {
		return maestroAdditionalUtxo{}, errors.New("additional UTxO is missing its input reference")
	}
	txoutCbor, err := cbor.Encode(utxo.Output)
	if err != nil {
		return maestroAdditionalUtxo{}, fmt.Errorf("failed to encode resolved output CBOR: %w", err)
	}
	return maestroAdditionalUtxo{
		TxHash:    hex.EncodeToString(utxo.Id.Id().Bytes()),
		Index:     int(utxo.Id.Index()),
		TxoutCbor: hex.EncodeToString(txoutCbor),
	}, nil
}

// postEvaluate issues a raw POST to /transactions/evaluate, reusing the SDK
// client's base URL, API key and HTTP client, and decodes the response with the
// same shape the SDK uses.
func (m *MaestroChainContext) postEvaluate(body []byte) (models.EvaluateTxResponse, error) {
	return m.postEvaluateContext(context.Background(), body)
}

func (m *MaestroChainContext) postEvaluateContext(
	ctx context.Context,
	body []byte,
) (models.EvaluateTxResponse, error) {
	url := m.client.BaseUrl + "/transactions/evaluate"
	if ctx == nil {
		ctx = context.Background()
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("api-key", m.apiKey)

	httpClient := m.client.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: defaultMaestroHTTPTimeout}
	}
	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		msg, err := io.ReadAll(io.LimitReader(resp.Body, maxMaestroEvaluateErrorResponseBytes))
		if err != nil {
			return nil, fmt.Errorf("failed to read maestro evaluate error response with status %d: %w", resp.StatusCode, err)
		}
		return nil, fmt.Errorf("maestro evaluate failed with status %d: %s", resp.StatusCode, strings.TrimSpace(string(msg)))
	}

	var evalResp models.EvaluateTxResponse
	if err := json.NewDecoder(resp.Body).Decode(&evalResp); err != nil {
		return nil, fmt.Errorf("failed to decode evaluate response: %w", err)
	}
	return evalResp, nil
}

// evaluationsToExUnits converts a Maestro evaluate response into a redeemer
// ExUnits map. A response with zero evaluation results is an error: returning
// an empty map with a nil error would let callers silently keep zero
// execution budgets for their redeemers.
func evaluationsToExUnits(evals models.EvaluateTxResponse) (map[common.RedeemerKey]common.ExUnits, error) {
	if len(evals) == 0 {
		return nil, errors.New("script evaluation returned no results")
	}
	result := make(map[common.RedeemerKey]common.ExUnits, len(evals))
	for _, eval := range evals {
		if eval.RedeemerIndex < 0 {
			return nil, fmt.Errorf("negative redeemer index: %d", eval.RedeemerIndex)
		}
		if uint64(eval.RedeemerIndex) > uint64(math.MaxUint32) {
			return nil, fmt.Errorf("redeemer index %d exceeds uint32 range", eval.RedeemerIndex)
		}
		tag, err := backendutil.ParseRedeemerTag(eval.RedeemerTag)
		if err != nil {
			return nil, fmt.Errorf("invalid redeemer tag %q: %w", eval.RedeemerTag, err)
		}
		key := common.RedeemerKey{Tag: tag, Index: uint32(eval.RedeemerIndex)}
		if _, exists := result[key]; exists {
			return nil, fmt.Errorf("duplicate evaluation report for redeemer %d:%d", tag, key.Index)
		}
		if eval.ExUnits.Mem < 0 {
			return nil, fmt.Errorf("negative execution memory for redeemer %d:%d: %d", tag, key.Index, eval.ExUnits.Mem)
		}
		if eval.ExUnits.Steps < 0 {
			return nil, fmt.Errorf("negative execution steps for redeemer %d:%d: %d", tag, key.Index, eval.ExUnits.Steps)
		}
		result[key] = common.ExUnits{Memory: eval.ExUnits.Mem, Steps: eval.ExUnits.Steps}
	}
	return result, nil
}

func (m *MaestroChainContext) UtxoByRef(txHash common.Blake2b256, index uint32) (*common.Utxo, error) {
	return m.UtxoByRefContext(context.Background(), txHash, index)
}

func (m *MaestroChainContext) UtxoByRefContext(
	ctx context.Context,
	txHash common.Blake2b256,
	index uint32,
) (*common.Utxo, error) {
	hashHex := hex.EncodeToString(txHash.Bytes())
	resp, err := m.clientWithContext(ctx).TransactionOutputFromReference(hashHex, int(index), nil)
	if err != nil {
		return nil, err
	}

	addr, err := common.NewAddress(resp.Data.Address)
	if err != nil {
		return nil, err
	}
	utxo, err := maestroUtxoToCommon(resp.Data, addr)
	if err != nil {
		return nil, err
	}
	return &utxo, nil
}

func (m *MaestroChainContext) ScriptCbor(scriptHash common.Blake2b224) ([]byte, error) {
	return m.ScriptCborContext(context.Background(), scriptHash)
}

func (m *MaestroChainContext) ScriptCborContext(
	ctx context.Context,
	scriptHash common.Blake2b224,
) ([]byte, error) {
	hashHex := hex.EncodeToString(scriptHash.Bytes())
	resp, err := m.clientWithContext(ctx).ScriptByHash(hashHex)
	if err != nil {
		return nil, err
	}
	if resp.Data.Bytes == "" {
		return nil, errors.New("no script CBOR available")
	}
	return hex.DecodeString(resp.Data.Bytes)
}

func maestroUtxoToCommon(raw models.Utxo, address common.Address) (common.Utxo, error) {
	hashBytes, err := hex.DecodeString(raw.TxHash)
	if err != nil {
		return common.Utxo{}, err
	}
	if len(hashBytes) != common.Blake2b256Size {
		return common.Utxo{}, fmt.Errorf("invalid tx hash length: expected %d bytes, got %d", common.Blake2b256Size, len(hashBytes))
	}
	var txId common.Blake2b256
	copy(txId[:], hashBytes)

	if raw.Index < 0 {
		return common.Utxo{}, fmt.Errorf("negative output index: %d", raw.Index)
	}
	if raw.Index > math.MaxUint32 {
		return common.Utxo{}, fmt.Errorf("output index %d exceeds uint32 range", raw.Index)
	}
	input := shelley.ShelleyTransactionInput{
		TxId:        txId,
		OutputIndex: uint32(raw.Index),
	}

	var lovelace uint64
	assetData := make(map[common.Blake2b224]map[cbor.ByteString]*big.Int)

	for _, asset := range raw.Assets {
		if asset.Unit == "lovelace" {
			if asset.Amount < 0 {
				return common.Utxo{}, fmt.Errorf("negative lovelace amount: %d", asset.Amount)
			}
			lovelace = uint64(asset.Amount) //nolint:gosec // validated non-negative above
		} else {
			if asset.Amount < 0 {
				return common.Utxo{}, fmt.Errorf("negative asset amount %d for unit %s", asset.Amount, asset.Unit)
			}
			policyId, assetName, err := backendutil.ParseAssetUnit(asset.Unit)
			if err != nil {
				return common.Utxo{}, fmt.Errorf("invalid asset unit %q: %w", asset.Unit, err)
			}

			if _, ok := assetData[policyId]; !ok {
				assetData[policyId] = make(map[cbor.ByteString]*big.Int)
			}
			assetData[policyId][assetName] = big.NewInt(asset.Amount)
		}
	}

	var assets *common.MultiAsset[common.MultiAssetTypeOutput]
	if len(assetData) > 0 {
		ma := common.NewMultiAsset[common.MultiAssetTypeOutput](assetData)
		assets = &ma
	}

	output := babbage.BabbageTransactionOutput{
		OutputAddress: address,
		OutputAmount: mary.MaryTransactionOutputValue{
			Amount: lovelace,
			Assets: assets,
		},
	}

	// Map datum to output's DatumOption.
	// Maestro returns the datum field as a JSON object with keys "type", "hash",
	// "bytes", "json". When unmarshaled into `any` it becomes map[string]interface{}.
	// The "type" discriminator is "hash" or "inline"; Maestro can include
	// resolved datum "bytes" even for type "hash" outputs, so the datum kind
	// must be decided by "type", not by the presence of "bytes".
	if datumMap, ok := raw.Datum.(map[string]any); ok {
		datumType, _ := datumMap["type"].(string)
		switch datumType {
		case "inline":
			datumCborHex, _ := datumMap["bytes"].(string)
			if datumCborHex == "" {
				return common.Utxo{}, errors.New("inline datum is missing its CBOR bytes")
			}
			// Inline datum: "bytes" field contains the CBOR hex of the datum.
			datumBytes, err := hex.DecodeString(datumCborHex)
			if err != nil {
				return common.Utxo{}, fmt.Errorf("invalid inline datum CBOR hex %q: %w", datumCborHex, err)
			}
			cborBytes, err := cbor.Encode([]any{1, cbor.Tag{Number: 24, Content: datumBytes}})
			if err != nil {
				return common.Utxo{}, fmt.Errorf("failed to encode inline datum option: %w", err)
			}
			var opt babbage.BabbageTransactionOutputDatumOption
			if err := opt.UnmarshalCBOR(cborBytes); err != nil {
				return common.Utxo{}, fmt.Errorf("failed to unmarshal inline datum option: %w", err)
			}
			output.DatumOption = &opt
		case "hash":
			hashHex, _ := datumMap["hash"].(string)
			if hashHex == "" {
				return common.Utxo{}, errors.New("hash datum is missing its hash")
			}
			// Datum hash reference only.
			hashBytes, err := hex.DecodeString(hashHex)
			if err != nil {
				return common.Utxo{}, fmt.Errorf("invalid datum hash hex %q: %w", hashHex, err)
			}
			if len(hashBytes) != common.Blake2b256Size {
				return common.Utxo{}, fmt.Errorf("invalid datum hash length: expected %d bytes, got %d", common.Blake2b256Size, len(hashBytes))
			}
			var hash common.Blake2b256
			copy(hash[:], hashBytes)
			cborBytes, err := cbor.Encode([]any{0, hash})
			if err != nil {
				return common.Utxo{}, fmt.Errorf("failed to encode datum option hash: %w", err)
			}
			var opt babbage.BabbageTransactionOutputDatumOption
			if err := opt.UnmarshalCBOR(cborBytes); err != nil {
				return common.Utxo{}, fmt.Errorf("failed to unmarshal datum option: %w", err)
			}
			output.DatumOption = &opt
		default:
			return common.Utxo{}, fmt.Errorf("unsupported maestro datum type %q", datumType)
		}
	}

	// Parse reference script if present, verifying the script bytes against
	// the script hash claimed by Maestro.
	if raw.ReferenceScript.Bytes != "" {
		scriptBytes, err := hex.DecodeString(raw.ReferenceScript.Bytes)
		if err != nil {
			return common.Utxo{}, fmt.Errorf("invalid reference script hex: %w", err)
		}
		ref, err := maestroScriptRef(raw.ReferenceScript.Type, scriptBytes, raw.ReferenceScript.Hash)
		if err != nil {
			return common.Utxo{}, fmt.Errorf("failed to parse reference script: %w", err)
		}
		output.TxOutScriptRef = ref
	}

	return common.Utxo{
		Id:     input,
		Output: &output,
	}, nil
}

// maestroScriptRef builds a ScriptRef from the Maestro script type and CBOR
// bytes. When Maestro supplies the script hash (expectedHashHex non-empty),
// the script bytes are verified against it rather than trusted as-is.
func maestroScriptRef(scriptType string, scriptCbor []byte, expectedHashHex string) (*common.ScriptRef, error) {
	var refType uint
	switch scriptType {
	case "native":
		refType = common.ScriptRefTypeNativeScript
	case "plutusv1":
		refType = common.ScriptRefTypePlutusV1
	case "plutusv2":
		refType = common.ScriptRefTypePlutusV2
	case "plutusv3":
		refType = common.ScriptRefTypePlutusV3
	case "plutusv4":
		refType = common.ScriptRefTypePlutusV4
	default:
		return nil, fmt.Errorf("unknown script type %q", scriptType)
	}
	return backendutil.ScriptRefFromBytes(refType, scriptCbor, expectedHashHex)
}

// maestroCostModelKey translates Maestro cost model keys to the canonical form
// expected by ComputeScriptDataHash ("PlutusV1" through "PlutusV4").
func maestroCostModelKey(key string) string {
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
