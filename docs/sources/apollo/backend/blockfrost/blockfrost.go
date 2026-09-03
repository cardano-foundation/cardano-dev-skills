package blockfrost

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
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/babbage"
	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/gouroboros/ledger/mary"
	"github.com/blinklabs-io/gouroboros/ledger/shelley"

	"github.com/Salvionied/apollo/v2/backend"
	"github.com/Salvionied/apollo/v2/internal/backendutil"
)

// BlockFrostChainContext implements backend.ChainContext using the BlockFrost API.
type BlockFrostChainContext struct {
	baseUrl   string
	projectId string
	networkId uint8
	client    *http.Client

	mu             sync.Mutex
	cachedParams   *backend.ProtocolParameters
	cachedGenesis  *backend.GenesisParameters
	paramsCacheAt  time.Time
	genesisCacheAt time.Time
}

// Capabilities reports the ChainContext feature set implemented by Blockfrost.
//
// CapabilityEvaluateTxAdditionalUtxos is included: EvaluateTx does honour the
// argument, by retrying the plain evaluate endpoint for indexing lag and then
// posting the resolved set to /utils/txs/evaluate/utxos. The hosted endpoint
// cannot decode asset-bearing entries, so those skip the fallback, but that
// degrades to an explicit evaluation error rather than a silently ignored
// argument or an understated budget. Declining the capability instead made the
// fallback unreachable, because callers gate on it and pass nil when it is
// absent, which broke chained and indexing-lagged inputs outright.
func (b *BlockFrostChainContext) Capabilities() backend.CapabilitySet {
	return backend.CapabilitySet(backend.AllCapabilities)
}

const (
	cacheExpiry                   = 5 * time.Minute
	maxBlockfrostResponseBytes    = 10 * 1024 * 1024
	maxBlockfrostErrorSnippetSize = 512
	maxConcurrentUtxoHydrations   = 8
)

// NewBlockFrostChainContext creates a new BlockFrost backend.
func NewBlockFrostChainContext(baseUrl string, networkId uint8, projectId string) *BlockFrostChainContext {
	// Ensure base URL ends with version path
	baseUrl = strings.TrimRight(baseUrl, "/")
	if !strings.HasSuffix(baseUrl, "/api/v0") && !strings.HasSuffix(baseUrl, "/v0") {
		baseUrl += "/api/v0"
	}
	return &BlockFrostChainContext{
		baseUrl:   baseUrl,
		projectId: projectId,
		networkId: networkId,
		client:    &http.Client{Timeout: 30 * time.Second},
	}
}

func (b *BlockFrostChainContext) requestContext(
	ctx context.Context,
	method, path string,
	body io.Reader,
	contentType string,
) ([]byte, error) {
	url := b.baseUrl + path
	req, err := http.NewRequestWithContext(ctx, method, url, body)
	if err != nil {
		return nil, err
	}
	if b.projectId != "" {
		req.Header.Set("project_id", b.projectId)
	}
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	resp, err := b.client.Do(req)
	if err != nil {
		return nil, err
	}
	if resp == nil || resp.Body == nil {
		return nil, errors.New("blockfrost: nil response")
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxBlockfrostResponseBytes+1))
	if err != nil {
		return nil, err
	}
	if len(data) > maxBlockfrostResponseBytes {
		return nil, fmt.Errorf("blockfrost response body exceeds %d bytes", maxBlockfrostResponseBytes)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		snippet := data
		if len(snippet) > maxBlockfrostErrorSnippetSize {
			snippet = snippet[:maxBlockfrostErrorSnippetSize]
		}
		return nil, fmt.Errorf("blockfrost API error %d: %s", resp.StatusCode, string(snippet))
	}
	return data, nil
}

func (b *BlockFrostChainContext) ProtocolParams() (backend.ProtocolParameters, error) {
	return b.ProtocolParamsContext(context.Background())
}

func (b *BlockFrostChainContext) ProtocolParamsContext(ctx context.Context) (backend.ProtocolParameters, error) {
	b.mu.Lock()
	if b.cachedParams != nil && time.Since(b.paramsCacheAt) < cacheExpiry {
		pp := *b.cachedParams
		// Deep copy CostModels to prevent callers from mutating the cache.
		if pp.CostModels != nil {
			cm := make(map[string][]int64, len(pp.CostModels))
			for k, v := range pp.CostModels {
				dup := make([]int64, len(v))
				copy(dup, v)
				cm[k] = dup
			}
			pp.CostModels = cm
		}
		b.mu.Unlock()
		return pp, nil
	}
	b.mu.Unlock()

	data, err := b.requestContext(ctx, "GET", "/epochs/latest/parameters", nil, "")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}

	var raw bfProtocolParams
	if err := json.Unmarshal(data, &raw); err != nil {
		return backend.ProtocolParameters{}, err
	}

	pp, err := raw.toProtocolParams()
	if err != nil {
		return backend.ProtocolParameters{}, err
	}

	// Deep copy CostModels before storing to prevent callers from mutating the cache.
	cached := pp
	if cached.CostModels != nil {
		cm := make(map[string][]int64, len(cached.CostModels))
		for k, v := range cached.CostModels {
			dup := make([]int64, len(v))
			copy(dup, v)
			cm[k] = dup
		}
		cached.CostModels = cm
	}

	b.mu.Lock()
	b.cachedParams = &cached
	b.paramsCacheAt = time.Now()
	b.mu.Unlock()

	return pp, nil
}

func (b *BlockFrostChainContext) GenesisParams() (backend.GenesisParameters, error) {
	return b.GenesisParamsContext(context.Background())
}

func (b *BlockFrostChainContext) GenesisParamsContext(ctx context.Context) (backend.GenesisParameters, error) {
	b.mu.Lock()
	if b.cachedGenesis != nil && time.Since(b.genesisCacheAt) < cacheExpiry {
		gp := *b.cachedGenesis
		b.mu.Unlock()
		return gp, nil
	}
	b.mu.Unlock()

	data, err := b.requestContext(ctx, "GET", "/genesis", nil, "")
	if err != nil {
		return backend.GenesisParameters{}, err
	}

	var raw bfGenesisParams
	if err := json.Unmarshal(data, &raw); err != nil {
		return backend.GenesisParameters{}, err
	}

	gp := backend.GenesisParameters{
		ActiveSlotsCoefficient: raw.ActiveSlotsCoefficient,
		UpdateQuorum:           raw.UpdateQuorum,
		NetworkMagic:           raw.NetworkMagic,
		EpochLength:            raw.EpochLength,
		MaxLovelaceSupply:      strconv.FormatInt(raw.MaxLovelaceSupply, 10),
		SlotLength:             raw.SlotLength,
		SlotsPerKesPeriod:      raw.SlotsPerKesPeriod,
		MaxKesEvolutions:       raw.MaxKesEvolutions,
		SecurityParam:          raw.SecurityParam,
	}

	b.mu.Lock()
	b.cachedGenesis = &gp
	b.genesisCacheAt = time.Now()
	b.mu.Unlock()

	return gp, nil
}

func (b *BlockFrostChainContext) NetworkId() uint8 {
	return b.networkId
}

func (b *BlockFrostChainContext) CurrentEpoch() (uint64, error) {
	return b.CurrentEpochContext(context.Background())
}

func (b *BlockFrostChainContext) CurrentEpochContext(ctx context.Context) (uint64, error) {
	data, err := b.requestContext(ctx, "GET", "/epochs/latest", nil, "")
	if err != nil {
		return 0, err
	}
	var result struct {
		Epoch int `json:"epoch"`
	}
	if err := json.Unmarshal(data, &result); err != nil {
		return 0, err
	}
	if result.Epoch < 0 {
		return 0, fmt.Errorf("invalid epoch value: %d", result.Epoch)
	}
	return uint64(result.Epoch), nil
}

func (b *BlockFrostChainContext) MaxTxFee() (uint64, error) {
	return b.MaxTxFeeContext(context.Background())
}

func (b *BlockFrostChainContext) MaxTxFeeContext(ctx context.Context) (uint64, error) {
	pp, err := b.ProtocolParamsContext(ctx)
	if err != nil {
		return 0, err
	}
	return backend.ComputeMaxTxFee(pp)
}

func (b *BlockFrostChainContext) Tip() (uint64, error) {
	return b.TipContext(context.Background())
}

func (b *BlockFrostChainContext) TipContext(ctx context.Context) (uint64, error) {
	data, err := b.requestContext(ctx, "GET", "/blocks/latest", nil, "")
	if err != nil {
		return 0, err
	}
	var result struct {
		Slot int `json:"slot"`
	}
	if err := json.Unmarshal(data, &result); err != nil {
		return 0, err
	}
	if result.Slot < 0 {
		return 0, fmt.Errorf("invalid slot value: %d", result.Slot)
	}
	return uint64(result.Slot), nil
}

func (b *BlockFrostChainContext) Utxos(address common.Address) ([]common.Utxo, error) {
	return b.UtxosContext(context.Background(), address)
}

func (b *BlockFrostChainContext) UtxosContext(ctx context.Context, address common.Address) ([]common.Utxo, error) {
	const maxPages = 1000
	var allUtxos []common.Utxo
	resolver := newScriptRefResolver(ctx, b)

	for page := 1; page <= maxPages+1; page++ {
		path := fmt.Sprintf("/addresses/%s/utxos?page=%d", address.String(), page)
		data, err := b.requestContext(ctx, "GET", path, nil, "")
		if err != nil {
			return nil, err
		}

		var rawUtxos []bfAddressUTxO
		if err := json.Unmarshal(data, &rawUtxos); err != nil {
			return nil, err
		}
		if len(rawUtxos) == 0 {
			return allUtxos, nil
		}
		if page > maxPages {
			return nil, fmt.Errorf("UTxO pagination exceeded %d pages; results may be incomplete", maxPages)
		}

		utxos, err := b.hydrateUtxoPage(rawUtxos, address, resolver.resolve)
		if err != nil {
			return nil, err
		}
		allUtxos = append(allUtxos, utxos...)
	}
	return allUtxos, nil
}

func (b *BlockFrostChainContext) SubmitTx(txCbor []byte) (common.Blake2b256, error) {
	return b.SubmitTxContext(context.Background(), txCbor)
}

func (b *BlockFrostChainContext) SubmitTxContext(ctx context.Context, txCbor []byte) (common.Blake2b256, error) {
	body := bytes.NewReader(txCbor)
	data, err := b.requestContext(ctx, "POST", "/tx/submit", body, "application/cbor")
	if err != nil {
		return common.Blake2b256{}, err
	}
	var txHash string
	if err := json.Unmarshal(data, &txHash); err != nil {
		return common.Blake2b256{}, err
	}
	hashBytes, err := hex.DecodeString(txHash)
	if err != nil {
		return common.Blake2b256{}, err
	}
	if len(hashBytes) != common.Blake2b256Size {
		return common.Blake2b256{}, fmt.Errorf("invalid tx hash length: expected %d bytes, got %d", common.Blake2b256Size, len(hashBytes))
	}
	var result common.Blake2b256
	copy(result[:], hashBytes)
	return result, nil
}

// evaluateSimpleRetries / evaluateSimpleRetryWait cover Blockfrost evaluate
// indexing lag right after a tx is confirmed (common when chaining mint/update
// onto a just-confirmed script UTxO). The hosted /evaluate/utxos fallback is
// unsafe for asset-bearing additional UTxOs (Ogmios jsonwsp base16/base64
// faults), so retrying the simple endpoint is preferred.
//
// These are package-level vars so tests can shrink the backoff without sleeping
// for the production intervals.
var (
	evaluateSimpleRetries   = 6
	evaluateSimpleRetryWait = 2 * time.Second
)

func (b *BlockFrostChainContext) EvaluateTx(txCbor []byte, additionalUtxos []common.Utxo) (map[common.RedeemerKey]common.ExUnits, error) {
	return b.EvaluateTxContext(context.Background(), txCbor, additionalUtxos)
}

func (b *BlockFrostChainContext) EvaluateTxContext(
	ctx context.Context,
	txCbor []byte,
	additionalUtxos []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, error) {
	for i, utxo := range additionalUtxos {
		if err := backend.ValidateAdditionalUtxo(utxo); err != nil {
			return nil, fmt.Errorf("invalid additional UTxO at index %d: %w", i, err)
		}
	}

	// Prefer /utils/txs/evaluate (hex body). Apollo always passes spending
	// inputs as additionalUtxos even when they are already on-chain; posting
	// them to /utils/txs/evaluate/utxos re-encodes inline datums and reference
	// scripts into a large JSON body. Hosted Blockfrost→Ogmios rejects that
	// path for additional UTxOs that include native assets (jsonwsp fault:
	// "failed to decode payload from base64 or base16"), while the same txs
	// evaluate successfully via the bare endpoint once inputs are visible.
	//
	// On missing-input failures, retry the simple endpoint (indexing lag)
	// before falling back to /evaluate/utxos, and only fall back when the
	// additional set has no native assets.
	var lastErr error
	for attempt := 1; attempt <= evaluateSimpleRetries; attempt++ {
		result, err := b.evaluateTxSimpleContext(ctx, txCbor)
		if err == nil {
			return result, nil
		}
		lastErr = err
		if !isMissingInputsEvalError(err) {
			return nil, err
		}
		if attempt < evaluateSimpleRetries {
			timer := time.NewTimer(evaluateSimpleRetryWait)
			select {
			case <-ctx.Done():
				timer.Stop()
				return nil, ctx.Err()
			case <-timer.C:
			}
		}
	}
	if len(additionalUtxos) == 0 || additionalUtxosContainNativeAssets(additionalUtxos) {
		return nil, lastErr
	}
	return b.evaluateTxWithAdditionalUtxosContext(ctx, txCbor, additionalUtxos)
}

// additionalUtxosContainNativeAssets reports whether any resolved UTxO carries
// a multi-asset balance. Hosted Blockfrost /evaluate/utxos currently faults on
// those entries, so they must not be used as an evaluate fallback.
func additionalUtxosContainNativeAssets(utxos []common.Utxo) bool {
	for _, utxo := range utxos {
		if utxo.Output == nil {
			continue
		}
		if assets := utxo.Output.Assets(); assets != nil && len(assets.Policies()) > 0 {
			return true
		}
	}
	return false
}

// evaluateTxSimple POSTs hex-encoded transaction CBOR to /utils/txs/evaluate.
// BlockFrost expects the hex string in the body with Content-Type
// application/cbor (not raw CBOR bytes).
func (b *BlockFrostChainContext) evaluateTxSimpleContext(
	ctx context.Context,
	txCbor []byte,
) (map[common.RedeemerKey]common.ExUnits, error) {
	body := strings.NewReader(hex.EncodeToString(txCbor))
	data, err := b.requestContext(ctx, "POST", "/utils/txs/evaluate", body, "application/cbor")
	if err != nil {
		return nil, err
	}
	return parseEvaluateTxResponse(data)
}

// evaluateTxWithAdditionalUtxos POSTs to /utils/txs/evaluate/utxos with a JSON
// body carrying the transaction CBOR hex and a resolved additional UTxO set.
func (b *BlockFrostChainContext) evaluateTxWithAdditionalUtxosContext(
	ctx context.Context,
	txCbor []byte,
	additionalUtxos []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, error) {
	reqBody, err := buildEvalUtxosRequest(txCbor, additionalUtxos)
	if err != nil {
		return nil, err
	}
	data, err := b.requestContext(ctx, "POST", "/utils/txs/evaluate/utxos", bytes.NewReader(reqBody), "application/json")
	if err != nil {
		return nil, err
	}
	return parseEvaluateTxResponse(data)
}

// isMissingInputsEvalError reports whether an EvaluateTx failure indicates the
// backend could not resolve transaction inputs from chain state (so supplying
// additionalUtxos may help).
func isMissingInputsEvalError(err error) bool {
	if err == nil {
		return false
	}
	s := strings.ToLower(err.Error())
	switch {
	case strings.Contains(s, "unknowninputs"),
		strings.Contains(s, "unknown inputs"),
		strings.Contains(s, "unknown_inputs"),
		strings.Contains(s, "nonexistinginput"),
		strings.Contains(s, "non-existing input"),
		strings.Contains(s, "non_existing_input"):
		return true
	case strings.Contains(s, "missing") && strings.Contains(s, "input"):
		return true
	default:
		return false
	}
}

// buildEvalUtxosRequest marshals the JSON body for the
// /utils/txs/evaluate/utxos endpoint: the hex tx CBOR plus the resolved
// additional UTxO set as [txIn, txOut] pairs.
func buildEvalUtxosRequest(txCbor []byte, additionalUtxos []common.Utxo) ([]byte, error) {
	items := make([]bfAdditionalUtxoItem, 0, len(additionalUtxos))
	for _, utxo := range additionalUtxos {
		item, err := bfAdditionalUtxoItemFromUtxo(utxo)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	req := bfEvalRequest{
		Cbor:              hex.EncodeToString(txCbor),
		AdditionalUtxoSet: items,
	}
	body, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal evaluate request: %w", err)
	}
	return body, nil
}

// bfAdditionalUtxoItemFromUtxo builds a single [txIn, txOut] additional-UTxO
// entry from a resolved gouroboros UTxO.
func bfAdditionalUtxoItemFromUtxo(utxo common.Utxo) (bfAdditionalUtxoItem, error) {
	if err := backend.ValidateAdditionalUtxo(utxo); err != nil {
		return bfAdditionalUtxoItem{}, err
	}

	out := utxo.Output

	txIn := bfTxIn{
		TxId:  hex.EncodeToString(utxo.Id.Id().Bytes()),
		Index: int(utxo.Id.Index()),
	}

	coins, err := bigIntToInt64(out.Amount())
	if err != nil {
		return bfAdditionalUtxoItem{}, fmt.Errorf("invalid lovelace amount: %w", err)
	}
	val := bfValue{Coins: coins}
	if assets := out.Assets(); assets != nil {
		assetMap := make(map[string]int64)
		for _, policyId := range assets.Policies() {
			policyHex := hex.EncodeToString(policyId.Bytes())
			for _, assetName := range assets.Assets(policyId) {
				// Asset key is policyHex for the empty asset name, otherwise
				// policyHex + "." + assetNameHex.
				key := policyHex
				if len(assetName) > 0 {
					key = policyHex + "." + hex.EncodeToString(assetName)
				}
				qty, err := bigIntToInt64(assets.Asset(policyId, assetName))
				if err != nil {
					return bfAdditionalUtxoItem{}, fmt.Errorf("invalid asset quantity for %s: %w", key, err)
				}
				assetMap[key] = qty
			}
		}
		if len(assetMap) > 0 {
			val.Assets = assetMap
		}
	}

	txOut := bfTxOut{
		Address: out.Address().String(),
		Value:   val,
	}

	// Inline datum CBOR hex goes in Datum; a bare datum hash goes in DatumHash.
	// Prefer the original on-chain CBOR bytes when present so the evaluate
	// endpoint sees a canonical encoding (MarshalCBOR re-encodes Plutus Data
	// and can diverge from the ledger bytes).
	if datum := out.Datum(); datum != nil {
		datumCbor := datum.Cbor()
		if len(datumCbor) == 0 {
			var err error
			datumCbor, err = datum.MarshalCBOR()
			if err != nil {
				return bfAdditionalUtxoItem{}, fmt.Errorf("failed to encode inline datum: %w", err)
			}
		}
		datumHex := hex.EncodeToString(datumCbor)
		txOut.Datum = &datumHex
	} else if datumHash := out.DatumHash(); datumHash != nil {
		datumHashHex := hex.EncodeToString(datumHash.Bytes())
		txOut.DatumHash = &datumHashHex
	}

	// Reference script, tagged by Plutus language version.
	if script := out.ScriptRef(); script != nil {
		ref, err := bfScriptRefFromScript(script)
		if err != nil {
			return bfAdditionalUtxoItem{}, err
		}
		txOut.ScriptRef = ref
	}

	return bfAdditionalUtxoItem{txIn, txOut}, nil
}

// bfScriptRefFromScript encodes a reference script into the Ogmios-v5 TxOut
// "script" wire shape used by /utils/txs/evaluate/utxos:
// {"plutus:v1"|"plutus:v2"|"plutus:v3"|"plutus:v4": "<base16 serialised script>"}.
// The Plutus language version is detected from the concrete script type, and
// the value is the on-chain serialised Plutus script (base16), matching the
// Ogmios encoding consumed by ogmiosScriptToScriptRef on read.
//
// Schema source: Ogmios local-tx-submission TxOut schema (scripts labelled
// "plutus:v1"/"plutus:v2"/"plutus:v3"/"plutus:v4", serialised Plutus scripts as base16),
// cross-checked against cardano-transaction-lib's encodeScriptRef
// (Plutonomicon/cardano-transaction-lib@72e4504). Native reference scripts in
// the additional UTxO set are not supported (their JSON encoding is undefined
// in that schema), so they are rejected rather than mislabelled.
func bfScriptRefFromScript(script common.Script) (*bfScriptRef, error) {
	scriptHex := hex.EncodeToString(script.RawScriptBytes())
	ref := &bfScriptRef{}
	switch script.(type) {
	case common.PlutusV1Script:
		ref.PlutusV1 = &scriptHex
	case common.PlutusV2Script:
		ref.PlutusV2 = &scriptHex
	case common.PlutusV3Script:
		ref.PlutusV3 = &scriptHex
	case common.PlutusV4Script:
		ref.PlutusV4 = &scriptHex
	default:
		return nil, fmt.Errorf("unsupported script type %T in additional UTxO: only Plutus v1/v2/v3/v4 reference scripts can be encoded for /utils/txs/evaluate/utxos", script)
	}
	return ref, nil
}

// bigIntToInt64 converts a big.Int quantity to int64, rejecting values that do
// not fit rather than silently truncating (the Ogmios-v5 value schema used by
// /utils/txs/evaluate/utxos encodes coins/assets as JSON integers).
func bigIntToInt64(v *big.Int) (int64, error) {
	if v == nil {
		return 0, nil
	}
	if !v.IsInt64() {
		return 0, fmt.Errorf("quantity %s does not fit in int64", v.String())
	}
	return v.Int64(), nil
}

// jsonValuePresent reports whether a raw JSON field was present and not null.
func jsonValuePresent(raw json.RawMessage) bool {
	trimmed := strings.TrimSpace(string(raw))
	return trimmed != "" && trimmed != "null"
}

// parseEvaluateTxResponse parses a BlockFrost /utils/txs/evaluate response.
// BlockFrost proxies Ogmios, so the payload may be either the legacy Ogmios v5
// jsonwsp shape ({"result":{"EvaluationResult":{...}}}) or the Ogmios v6 shape
// ({"result":[{"validator":...,"budget":...}, ...]}, with failures reported as
// a top-level {"error":{...}} object). Hosted Blockfrost also sometimes returns
// a bare Ogmios v5 jsonwsp/fault object. Any other shape, and any response with
// zero evaluation results, is an error.
func parseEvaluateTxResponse(data []byte) (map[common.RedeemerKey]common.ExUnits, error) {
	var envelope struct {
		Type   string          `json:"type"`
		Result json.RawMessage `json:"result"`
		Error  json.RawMessage `json:"error"`
		Fault  json.RawMessage `json:"fault"`
	}
	if err := json.Unmarshal(data, &envelope); err != nil {
		return nil, fmt.Errorf("failed to parse evaluate response: %w", err)
	}
	if envelope.Type == "jsonwsp/fault" || jsonValuePresent(envelope.Fault) {
		var fault struct {
			Code   string `json:"code"`
			String string `json:"string"`
		}
		if err := json.Unmarshal(envelope.Fault, &fault); err == nil && fault.String != "" {
			return nil, fmt.Errorf("ogmios evaluate fault (%s): %s", fault.Code, fault.String)
		}
		return nil, fmt.Errorf("ogmios evaluate fault: %s", evalErrorSnippet(data))
	}
	if jsonValuePresent(envelope.Error) {
		var ogmiosErr struct {
			Code    int             `json:"code"`
			Message string          `json:"message"`
			Data    json.RawMessage `json:"data"`
		}
		if err := json.Unmarshal(envelope.Error, &ogmiosErr); err == nil && ogmiosErr.Message != "" {
			if jsonValuePresent(ogmiosErr.Data) {
				return nil, fmt.Errorf("script evaluation failed (code %d): %s: %s",
					ogmiosErr.Code, ogmiosErr.Message, string(ogmiosErr.Data))
			}
			return nil, fmt.Errorf("script evaluation failed (code %d): %s", ogmiosErr.Code, ogmiosErr.Message)
		}
		return nil, fmt.Errorf("script evaluation failed: %s", string(envelope.Error))
	}
	if !jsonValuePresent(envelope.Result) {
		return nil, fmt.Errorf("unrecognized evaluate response (no result or error): %s", evalErrorSnippet(data))
	}
	if strings.HasPrefix(strings.TrimSpace(string(envelope.Result)), "[") {
		return parseOgmiosV6EvaluationResult(envelope.Result)
	}
	return parseOgmiosV5EvaluationResult(envelope.Result)
}

// parseOgmiosV6EvaluationResult parses the Ogmios v6 evaluateTransaction result
// array: [{"validator":{"purpose":...,"index":...},"budget":{"memory":...,"cpu":...}}].
func parseOgmiosV6EvaluationResult(raw json.RawMessage) (map[common.RedeemerKey]common.ExUnits, error) {
	var items []struct {
		Validator struct {
			Purpose string `json:"purpose"`
			Index   uint64 `json:"index"`
		} `json:"validator"`
		Budget struct {
			Memory uint64 `json:"memory"`
			Cpu    uint64 `json:"cpu"`
		} `json:"budget"`
		Error json.RawMessage `json:"error"`
	}
	if err := json.Unmarshal(raw, &items); err != nil {
		return nil, fmt.Errorf("failed to parse evaluation result: %w", err)
	}
	if len(items) == 0 {
		return nil, errors.New("script evaluation returned no results")
	}
	result := make(map[common.RedeemerKey]common.ExUnits, len(items))
	for _, item := range items {
		if jsonValuePresent(item.Error) {
			return nil, fmt.Errorf("script evaluation failed for validator %s:%d: %s",
				item.Validator.Purpose, item.Validator.Index, string(item.Error))
		}
		if item.Validator.Purpose == "" {
			return nil, fmt.Errorf("malformed evaluation result entry: %s", evalErrorSnippet(raw))
		}
		tag, err := backendutil.ParseRedeemerTag(item.Validator.Purpose)
		if err != nil {
			return nil, fmt.Errorf("invalid redeemer purpose %q: %w", item.Validator.Purpose, err)
		}
		if item.Validator.Index > math.MaxUint32 {
			return nil, fmt.Errorf("redeemer index %d exceeds uint32 range", item.Validator.Index)
		}
		if item.Budget.Memory > math.MaxInt64 || item.Budget.Cpu > math.MaxInt64 {
			return nil, fmt.Errorf("ExUnits overflow for validator %s:%d: memory=%d cpu=%d",
				item.Validator.Purpose, item.Validator.Index, item.Budget.Memory, item.Budget.Cpu)
		}
		key := common.RedeemerKey{Tag: tag, Index: uint32(item.Validator.Index)}
		result[key] = common.ExUnits{Memory: int64(item.Budget.Memory), Steps: int64(item.Budget.Cpu)}
	}
	return result, nil
}

// parseOgmiosV5EvaluationResult parses the legacy Ogmios v5 jsonwsp result
// object: {"EvaluationResult":{"tag:index":{"memory":...,"steps":...}}} or
// {"EvaluationFailure":{...}}.
func parseOgmiosV5EvaluationResult(raw json.RawMessage) (map[common.RedeemerKey]common.ExUnits, error) {
	var v5Result struct {
		EvaluationResult map[string]struct {
			Memory uint64 `json:"memory"`
			Steps  uint64 `json:"steps"`
		} `json:"EvaluationResult"`
		EvaluationFailure json.RawMessage `json:"EvaluationFailure"`
	}
	if err := json.Unmarshal(raw, &v5Result); err != nil {
		return nil, fmt.Errorf("failed to parse evaluation result: %w", err)
	}
	if jsonValuePresent(v5Result.EvaluationFailure) {
		return nil, fmt.Errorf("script evaluation failed: %s", string(v5Result.EvaluationFailure))
	}
	if v5Result.EvaluationResult == nil {
		return nil, fmt.Errorf("unrecognized evaluate response: %s", evalErrorSnippet(raw))
	}
	if len(v5Result.EvaluationResult) == 0 {
		return nil, errors.New("script evaluation returned no results")
	}
	result := make(map[common.RedeemerKey]common.ExUnits, len(v5Result.EvaluationResult))
	for key, budget := range v5Result.EvaluationResult {
		parts := strings.Split(key, ":")
		if len(parts) != 2 {
			return nil, fmt.Errorf("malformed redeemer key %q: expected format 'tag:index'", key)
		}
		tag, err := backendutil.ParseRedeemerTag(parts[0])
		if err != nil {
			return nil, fmt.Errorf("invalid redeemer tag in key %q: %w", key, err)
		}
		idx, err := strconv.ParseUint(parts[1], 10, 32)
		if err != nil {
			return nil, fmt.Errorf("invalid redeemer index %q in key %q: %w", parts[1], key, err)
		}
		rKey := common.RedeemerKey{Tag: tag, Index: uint32(idx)}
		if budget.Memory > math.MaxInt64 || budget.Steps > math.MaxInt64 {
			return nil, fmt.Errorf("ExUnits overflow in key %q: memory=%d steps=%d", key, budget.Memory, budget.Steps)
		}
		result[rKey] = common.ExUnits{Memory: int64(budget.Memory), Steps: int64(budget.Steps)}
	}
	return result, nil
}

// evalErrorSnippet bounds a response payload for inclusion in error messages.
func evalErrorSnippet(data []byte) string {
	if len(data) > maxBlockfrostErrorSnippetSize {
		data = data[:maxBlockfrostErrorSnippetSize]
	}
	return string(data)
}

func (b *BlockFrostChainContext) UtxoByRef(txHash common.Blake2b256, index uint32) (*common.Utxo, error) {
	return b.UtxoByRefContext(context.Background(), txHash, index)
}

func (b *BlockFrostChainContext) UtxoByRefContext(
	ctx context.Context,
	txHash common.Blake2b256,
	index uint32,
) (*common.Utxo, error) {
	hashHex := hex.EncodeToString(txHash.Bytes())
	path := fmt.Sprintf("/txs/%s/utxos", hashHex)
	data, err := b.requestContext(ctx, "GET", path, nil, "")
	if err != nil {
		return nil, err
	}

	// Blockfrost GET /txs/{hash}/utxos returns the tx id only at the top level
	// ("hash"). Output objects omit tx_hash (unlike /addresses/{addr}/utxos).
	// hydrateUtxo/toUtxo require TxHash, so fill it from the request hash (or
	// the response top-level hash) before parsing.
	var txUtxos struct {
		Hash    string          `json:"hash"`
		Outputs []bfAddressUTxO `json:"outputs"`
	}
	if err := json.Unmarshal(data, &txUtxos); err != nil {
		return nil, err
	}
	fallbackHash := hashHex
	if txUtxos.Hash != "" {
		fallbackHash = txUtxos.Hash
	}

	for _, raw := range txUtxos.Outputs {
		if raw.OutputIndex == int64(index) {
			if raw.TxHash == "" {
				raw.TxHash = fallbackHash
			}
			addr, err := common.NewAddress(raw.Address)
			if err != nil {
				return nil, err
			}
			utxo, err := b.hydrateUtxoContext(ctx, raw, addr)
			if err != nil {
				return nil, err
			}
			return &utxo, nil
		}
	}
	return nil, errors.New("utxo not found")
}

func (b *BlockFrostChainContext) ScriptCbor(scriptHash common.Blake2b224) ([]byte, error) {
	return b.ScriptCborContext(context.Background(), scriptHash)
}

func (b *BlockFrostChainContext) ScriptCborContext(
	ctx context.Context,
	scriptHash common.Blake2b224,
) ([]byte, error) {
	hashHex := hex.EncodeToString(scriptHash.Bytes())
	path := fmt.Sprintf("/scripts/%s/cbor", hashHex)
	data, err := b.requestContext(ctx, "GET", path, nil, "")
	if err != nil {
		return nil, err
	}
	var result struct {
		Cbor string `json:"cbor"`
	}
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, err
	}
	scriptCbor, err := hex.DecodeString(result.Cbor)
	if err != nil {
		return nil, fmt.Errorf("invalid script CBOR hex: %w", err)
	}
	return scriptCbor, nil
}

// --- BlockFrost evaluate-with-utxos request types ---
//
// /utils/txs/evaluate/utxos accepts resolved additional UTxOs as [txIn, txOut]
// pairs. The value is {coins, assets}; a bare datum hash is "datum_hash";
// reference scripts are
// {"plutus:v1"|"plutus:v2"|"plutus:v3"|"plutus:v4": "<base16 script>"}.
// Schema source: Blockfrost /utils/txs/evaluate/utxos OpenAPI schema
// (datum_hash key) cross-checked against the production value/coins/assets
// casing in cardano-connector-go.

type bfEvalRequest struct {
	Cbor              string                 `json:"cbor"`
	AdditionalUtxoSet []bfAdditionalUtxoItem `json:"additionalUtxoSet"`
}

// bfAdditionalUtxoItem is a [txIn, txOut] pair.
type bfAdditionalUtxoItem [2]any

type bfTxIn struct {
	TxId  string `json:"txId"`
	Index int    `json:"index"`
}

type bfValue struct {
	Coins int64 `json:"coins"`
	// Assets key is the policy ID hex for the empty asset name, otherwise
	// policyHex + "." + assetNameHex.
	Assets map[string]int64 `json:"assets,omitempty"`
}

type bfScriptRef struct {
	PlutusV1 *string `json:"plutus:v1,omitempty"`
	PlutusV2 *string `json:"plutus:v2,omitempty"`
	PlutusV3 *string `json:"plutus:v3,omitempty"`
	PlutusV4 *string `json:"plutus:v4,omitempty"`
}

type bfTxOut struct {
	Address string  `json:"address"`
	Value   bfValue `json:"value"`
	// DatumHash uses Blockfrost's snake_case key "datum_hash" for a bare datum
	// hash digest; inline datums go under "datum".
	DatumHash *string      `json:"datum_hash,omitempty"`
	Datum     *string      `json:"datum,omitempty"`
	ScriptRef *bfScriptRef `json:"script,omitempty"`
}

// --- BlockFrost response types ---

type bfProtocolParams struct {
	MinFeeA            int64           `json:"min_fee_a"`
	MinFeeB            int64           `json:"min_fee_b"`
	MaxBlockSize       int64           `json:"max_block_size"`
	MaxTxSize          int64           `json:"max_tx_size"`
	MaxBlockHeaderSize int64           `json:"max_block_header_size"`
	KeyDeposit         string          `json:"key_deposit"`
	PoolDeposit        string          `json:"pool_deposit"`
	Decentralisation   float64         `json:"decentralisation_param"`
	MinPoolCost        string          `json:"min_pool_cost"`
	PriceMem           float64         `json:"price_mem"`
	PriceStep          float64         `json:"price_step"`
	MaxTxExMem         string          `json:"max_tx_ex_mem"`
	MaxTxExSteps       string          `json:"max_tx_ex_steps"`
	MaxBlockExMem      string          `json:"max_block_ex_mem"`
	MaxBlockExSteps    string          `json:"max_block_ex_steps"`
	MaxValSize         string          `json:"max_val_size"`
	CollateralPercent  int64           `json:"collateral_percent"`
	MaxCollateralIn    int64           `json:"max_collateral_inputs"`
	CoinsPerUtxoSize   string          `json:"coins_per_utxo_size"`
	CostModels         json.RawMessage `json:"cost_models"`
	// CostModelsRaw is the canonical flat integer array per language. Prefer
	// this over named cost_models: Blockfrost's keyed/named maps can be
	// truncated or reordered after Plutus cost-model parameter bumps, which
	// yields ScriptIntegrityHashMismatch even when EvaluateTx succeeds.
	CostModelsRaw json.RawMessage `json:"cost_models_raw"`
	// BlockFrost exposes the Conway reference-script base price under this flat
	// key (lovelace per byte for the first tier); it does not return the
	// structured min_fee_reference_scripts_{base,range,multiplier} triple.
	MinFeeRefScriptCostPerByte json.Number `json:"min_fee_ref_script_cost_per_byte"`
}

func (p *bfProtocolParams) toProtocolParams() (backend.ProtocolParameters, error) {
	maxBlockSize, err := backendutil.BoundedInt(p.MaxBlockSize, "max_block_size")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	maxTxSize, err := backendutil.BoundedInt(p.MaxTxSize, "max_tx_size")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	maxBlockHeaderSize, err := backendutil.BoundedInt(p.MaxBlockHeaderSize, "max_block_header_size")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	collateralPercent, err := backendutil.BoundedInt(p.CollateralPercent, "collateral_percent")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	maxCollateralInputs, err := backendutil.BoundedInt(p.MaxCollateralIn, "max_collateral_inputs")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	pp := backend.ProtocolParameters{
		MinFeeConstant:      p.MinFeeB,
		MinFeeCoefficient:   p.MinFeeA,
		MaxBlockSize:        maxBlockSize,
		MaxTxSize:           maxTxSize,
		MaxBlockHeaderSize:  maxBlockHeaderSize,
		KeyDeposits:         p.KeyDeposit,
		PoolDeposits:        p.PoolDeposit,
		MinPoolCost:         p.MinPoolCost,
		PriceMem:            p.PriceMem,
		PriceStep:           p.PriceStep,
		MaxTxExMem:          p.MaxTxExMem,
		MaxTxExSteps:        p.MaxTxExSteps,
		MaxBlockExMem:       p.MaxBlockExMem,
		MaxBlockExSteps:     p.MaxBlockExSteps,
		MaxValSize:          p.MaxValSize,
		CollateralPercent:   collateralPercent,
		MaxCollateralInputs: maxCollateralInputs,
		CoinsPerUtxoByte:    p.CoinsPerUtxoSize,
	}
	if p.MinFeeRefScriptCostPerByte != "" {
		price, err := backendutil.ParseRational(p.MinFeeRefScriptCostPerByte.String())
		if err != nil {
			return backend.ProtocolParameters{}, fmt.Errorf("invalid min_fee_ref_script_cost_per_byte: %w", err)
		}
		pp.MinFeeRefScriptCostPerByteRational = price
		pp.MinFeeRefScriptCostPerByte, _ = price.Float64()
	}

	// Parse cost models from BlockFrost JSON.
	// Prefer cost_models_raw (canonical integer arrays). Fall back to
	// cost_models which may be either:
	//   - array format:  {"PlutusV1": [205665, 812, ...]}
	//   - keyed format:  {"PlutusV1": {"addInteger-cpu-arguments-intercept": 205665, ...}}
	// Both formats use keys "PlutusV1" through "PlutusV4" which match the
	// canonical form expected by ComputeScriptDataHash.
	if len(p.CostModelsRaw) > 0 && string(p.CostModelsRaw) != "null" {
		var rawModels map[string][]int64
		if err := json.Unmarshal(p.CostModelsRaw, &rawModels); err != nil {
			return pp, fmt.Errorf("failed to parse cost_models_raw: %w", err)
		}
		if len(rawModels) > 0 {
			pp.CostModels = rawModels
		}
	}
	if pp.CostModels == nil && len(p.CostModels) > 0 {
		var arrayModels map[string][]int64
		if err := json.Unmarshal(p.CostModels, &arrayModels); err == nil {
			pp.CostModels = arrayModels
		} else {
			// Fall back to keyed format (map[string]map[string]int64).
			var keyedModels map[string]map[string]int64
			if err := json.Unmarshal(p.CostModels, &keyedModels); err != nil {
				return pp, fmt.Errorf("failed to parse cost models: %w", err)
			}
			pp.CostModels = make(map[string][]int64, len(keyedModels))
			for lang, costs := range keyedModels {
				// Sort parameter names alphabetically. The Cardano ledger
				// serializes cost models as a flat list of integers whose
				// positions correspond to alphabetically-sorted parameter
				// names (see IntersectMBO/cardano-ledger#2902).
				sortedKeys := make([]string, 0, len(costs))
				for k := range costs {
					sortedKeys = append(sortedKeys, k)
				}
				sort.Strings(sortedKeys)
				values := make([]int64, 0, len(costs))
				for _, k := range sortedKeys {
					values = append(values, costs[k])
				}
				pp.CostModels[lang] = values
			}
		}
	}

	return pp, nil
}

type bfGenesisParams struct {
	ActiveSlotsCoefficient float64 `json:"active_slots_coefficient"`
	UpdateQuorum           int     `json:"update_quorum"`
	NetworkMagic           int     `json:"network_magic"`
	EpochLength            int     `json:"epoch_length"`
	MaxLovelaceSupply      int64   `json:"max_lovelace_supply,string"`
	SlotLength             int     `json:"slot_length"`
	SlotsPerKesPeriod      int     `json:"slots_per_kes_period"`
	MaxKesEvolutions       int     `json:"max_kes_evolutions"`
	SecurityParam          int     `json:"security_param"`
}

type bfAddressUTxO struct {
	TxHash string `json:"tx_hash"`
	// OutputIndex is int64 rather than int so the range guards in toUtxo stay
	// meaningful on 32-bit platforms, where int tops out at 2^31-1 and could
	// never hold an out-of-range uint32 to reject in the first place.
	OutputIndex         int64             `json:"output_index"`
	Address             string            `json:"address"`
	Amount              []bfAddressAmount `json:"amount"`
	DataHash            string            `json:"data_hash"`
	InlineDatum         json.RawMessage   `json:"inline_datum"`
	ReferenceScriptHash string            `json:"reference_script_hash"`
}

type bfAddressAmount struct {
	Unit     string `json:"unit"`
	Quantity string `json:"quantity"`
}

func (raw *bfAddressUTxO) toUtxo(address common.Address) (common.Utxo, error) {
	hashBytes, err := hex.DecodeString(raw.TxHash)
	if err != nil {
		return common.Utxo{}, err
	}
	if len(hashBytes) != common.Blake2b256Size {
		return common.Utxo{}, fmt.Errorf("invalid tx hash length: expected %d bytes, got %d", common.Blake2b256Size, len(hashBytes))
	}
	var txId common.Blake2b256
	copy(txId[:], hashBytes)

	if raw.OutputIndex < 0 {
		return common.Utxo{}, fmt.Errorf("negative output index: %d", raw.OutputIndex)
	}
	if raw.OutputIndex > math.MaxUint32 {
		return common.Utxo{}, fmt.Errorf("output index %d exceeds uint32 range", raw.OutputIndex)
	}
	input := shelley.ShelleyTransactionInput{
		TxId:        txId,
		OutputIndex: uint32(raw.OutputIndex), //nolint:gosec // range checked above
	}

	// Parse amounts
	var lovelace uint64
	assetData := make(map[common.Blake2b224]map[cbor.ByteString]*big.Int)

	for _, amt := range raw.Amount {
		if amt.Unit == "lovelace" {
			qty, err := strconv.ParseInt(amt.Quantity, 10, 64)
			if err != nil {
				return common.Utxo{}, fmt.Errorf("invalid lovelace quantity %q: %w", amt.Quantity, err)
			}
			if qty < 0 {
				return common.Utxo{}, fmt.Errorf("negative lovelace quantity: %d", qty)
			}
			lovelace = uint64(qty) //nolint:gosec // validated non-negative above
		} else if len(amt.Unit) >= 56 {
			qty, ok := new(big.Int).SetString(amt.Quantity, 10)
			if !ok {
				return common.Utxo{}, fmt.Errorf("invalid asset quantity %q for unit %s", amt.Quantity, amt.Unit)
			}
			if qty.Sign() < 0 {
				return common.Utxo{}, fmt.Errorf("negative asset quantity %s for unit %s", qty.String(), amt.Unit)
			}
			policyId, assetName, err := backendutil.ParseAssetUnit(amt.Unit)
			if err != nil {
				return common.Utxo{}, fmt.Errorf("invalid asset unit %q: %w", amt.Unit, err)
			}

			if _, ok := assetData[policyId]; !ok {
				assetData[policyId] = make(map[cbor.ByteString]*big.Int)
			}
			assetData[policyId][assetName] = qty
		} else {
			return common.Utxo{}, fmt.Errorf("unrecognized unit format %q: expected \"lovelace\" or hex string >= 56 chars (policy_id + asset_name)", amt.Unit)
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

	// Map datum hash to output's DatumOption when no inline datum is available.
	if raw.DataHash != "" && (len(raw.InlineDatum) == 0 || string(raw.InlineDatum) == "null") {
		hashBytes, err := hex.DecodeString(raw.DataHash)
		if err != nil {
			return common.Utxo{}, fmt.Errorf("invalid data hash hex %q: %w", raw.DataHash, err)
		}
		if len(hashBytes) != common.Blake2b256Size {
			return common.Utxo{}, fmt.Errorf("invalid data hash length: expected %d bytes, got %d", common.Blake2b256Size, len(hashBytes))
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
	}

	return common.Utxo{
		Id:     input,
		Output: &output,
	}, nil
}

func (b *BlockFrostChainContext) hydrateUtxo(raw bfAddressUTxO, address common.Address) (common.Utxo, error) {
	return b.hydrateUtxoWithScriptResolver(raw, address, b.scriptRefByHash)
}

func (b *BlockFrostChainContext) hydrateUtxoContext(
	ctx context.Context,
	raw bfAddressUTxO,
	address common.Address,
) (common.Utxo, error) {
	return b.hydrateUtxoWithScriptResolver(
		raw,
		address,
		func(hashHex string) (*common.ScriptRef, error) {
			return b.scriptRefByHashContext(ctx, hashHex)
		},
	)
}

func (b *BlockFrostChainContext) hydrateUtxoPage(
	rawUtxos []bfAddressUTxO,
	address common.Address,
	resolveScript func(string) (*common.ScriptRef, error),
) ([]common.Utxo, error) {
	utxos := make([]common.Utxo, len(rawUtxos))
	errs := make([]error, len(rawUtxos))

	workers := min(len(rawUtxos), maxConcurrentUtxoHydrations)
	jobs := make(chan int)
	var wg sync.WaitGroup
	for range workers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for index := range jobs {
				utxo, err := b.hydrateUtxoWithScriptResolver(rawUtxos[index], address, resolveScript)
				if err != nil {
					errs[index] = fmt.Errorf(
						"failed to parse UTxO %s#%d: %w",
						rawUtxos[index].TxHash,
						rawUtxos[index].OutputIndex,
						err,
					)
					continue
				}
				utxos[index] = utxo
			}
		}()
	}
	for index := range rawUtxos {
		jobs <- index
	}
	close(jobs)
	wg.Wait()

	for _, err := range errs {
		if err != nil {
			return nil, err
		}
	}
	return utxos, nil
}

func (b *BlockFrostChainContext) hydrateUtxoWithScriptResolver(
	raw bfAddressUTxO,
	address common.Address,
	resolveScript func(string) (*common.ScriptRef, error),
) (common.Utxo, error) {
	utxo, err := raw.toUtxo(address)
	if err != nil {
		return common.Utxo{}, err
	}
	output, ok := utxo.Output.(*babbage.BabbageTransactionOutput)
	if !ok {
		return common.Utxo{}, fmt.Errorf("unexpected UTxO output type: %T", utxo.Output)
	}
	if len(raw.InlineDatum) > 0 && string(raw.InlineDatum) != "null" {
		datumOpt, err := inlineDatumOptionFromBlockfrost(raw.InlineDatum)
		if err != nil {
			return common.Utxo{}, fmt.Errorf("failed to decode inline datum: %w", err)
		}
		output.DatumOption = datumOpt
	}
	if raw.ReferenceScriptHash != "" {
		scriptRef, err := resolveScript(raw.ReferenceScriptHash)
		if err != nil {
			return common.Utxo{}, fmt.Errorf("failed to resolve reference script %s: %w", raw.ReferenceScriptHash, err)
		}
		output.TxOutScriptRef = scriptRef
	}
	return utxo, nil
}

type scriptRefResolver struct {
	requestContext context.Context
	chainContext   *BlockFrostChainContext

	mu      sync.Mutex
	entries map[string]*scriptRefResolveResult
}

type scriptRefResolveResult struct {
	done      chan struct{}
	scriptRef *common.ScriptRef
	err       error
}

func newScriptRefResolver(ctx context.Context, chainContext *BlockFrostChainContext) *scriptRefResolver {
	return &scriptRefResolver{
		requestContext: ctx,
		chainContext:   chainContext,
		entries:        make(map[string]*scriptRefResolveResult),
	}
}

func (r *scriptRefResolver) resolve(hashHex string) (*common.ScriptRef, error) {
	// Script hashes are hexadecimal, so normalize the key to coalesce case-only
	// variants returned by upstream services.
	key := strings.ToLower(hashHex)

	r.mu.Lock()
	entry, ok := r.entries[key]
	if !ok {
		entry = &scriptRefResolveResult{done: make(chan struct{})}
		r.entries[key] = entry
	}
	r.mu.Unlock()

	if ok {
		select {
		case <-r.requestContext.Done():
			return nil, r.requestContext.Err()
		case <-entry.done:
			return entry.scriptRef, entry.err
		}
	}

	entry.scriptRef, entry.err = r.chainContext.scriptRefByHashContext(r.requestContext, key)
	close(entry.done)
	return entry.scriptRef, entry.err
}

// inlineDatumOptionFromBlockfrost builds an inline datum option from BlockFrost's
// inline_datum field, which is a CBOR-encoded datum serialized as a hex string.
// The original CBOR bytes are preserved exactly (no JSON decode/re-encode
// round-trip) so the datum hash is not altered by a non-canonical re-encoding.
func inlineDatumOptionFromBlockfrost(raw json.RawMessage) (*babbage.BabbageTransactionOutputDatumOption, error) {
	var datumCborHex string
	if err := json.Unmarshal(raw, &datumCborHex); err != nil {
		return nil, fmt.Errorf("inline datum must be a CBOR hex string: %w", err)
	}
	datumBytes, err := hex.DecodeString(datumCborHex)
	if err != nil {
		return nil, fmt.Errorf("invalid inline datum CBOR hex %q: %w", datumCborHex, err)
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

func (b *BlockFrostChainContext) scriptRefByHash(hashHex string) (*common.ScriptRef, error) {
	return b.scriptRefByHashContext(context.Background(), hashHex)
}

func (b *BlockFrostChainContext) scriptRefByHashContext(
	ctx context.Context,
	hashHex string,
) (*common.ScriptRef, error) {
	hashBytes, err := hex.DecodeString(hashHex)
	if err != nil {
		return nil, fmt.Errorf("invalid script hash hex %q: %w", hashHex, err)
	}
	if len(hashBytes) != common.Blake2b224Size {
		return nil, fmt.Errorf("invalid script hash length: expected %d bytes, got %d", common.Blake2b224Size, len(hashBytes))
	}
	var scriptHash common.Blake2b224
	copy(scriptHash[:], hashBytes)
	scriptCbor, err := b.ScriptCborContext(ctx, scriptHash)
	if err != nil {
		return nil, err
	}
	return scriptRefFromHash(scriptHash, scriptCbor)
}

func scriptRefFromHash(
	scriptHash common.Blake2b224,
	scriptCbor []byte,
) (*common.ScriptRef, error) {
	var native common.NativeScript
	if _, err := cbor.Decode(scriptCbor, &native); err == nil && native.Hash() == scriptHash {
		return &common.ScriptRef{
			Type:   common.ScriptRefTypeNativeScript,
			Script: native,
		}, nil
	}
	v1 := common.PlutusV1Script(scriptCbor)
	if v1.Hash() == scriptHash {
		return &common.ScriptRef{
			Type:   common.ScriptRefTypePlutusV1,
			Script: v1,
		}, nil
	}
	v2 := common.PlutusV2Script(scriptCbor)
	if v2.Hash() == scriptHash {
		return &common.ScriptRef{
			Type:   common.ScriptRefTypePlutusV2,
			Script: v2,
		}, nil
	}
	v3 := common.PlutusV3Script(scriptCbor)
	if v3.Hash() == scriptHash {
		return &common.ScriptRef{
			Type:   common.ScriptRefTypePlutusV3,
			Script: v3,
		}, nil
	}
	v4 := common.PlutusV4Script(scriptCbor)
	if v4.Hash() == scriptHash {
		return &common.ScriptRef{
			Type:   common.ScriptRefTypePlutusV4,
			Script: v4,
		}, nil
	}
	return nil, errors.New("unable to determine reference script language from script hash")
}
