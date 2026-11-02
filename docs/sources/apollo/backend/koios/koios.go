package koios

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
	"net/url"
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
	"github.com/Salvionied/apollo/v2/internal/ogmiosutil"
)

// KoiosChainContext implements backend.ChainContext using the Koios API.
type KoiosChainContext struct {
	baseUrl   string
	token     string
	networkId uint8
	client    *http.Client

	mu             sync.Mutex
	cachedParams   *backend.ProtocolParameters
	cachedGenesis  *backend.GenesisParameters
	paramsCacheAt  time.Time
	genesisCacheAt time.Time
}

var (
	_ backend.ChainContext        = (*KoiosChainContext)(nil)
	_ backend.ContextChainContext = (*KoiosChainContext)(nil)
	_ backend.CapabilityReporter  = (*KoiosChainContext)(nil)
)

const (
	cacheExpiry              = 5 * time.Minute
	maxKoiosResponseBytes    = 10 * 1024 * 1024
	maxKoiosErrorSnippetSize = 512
	// koiosPageSize is the Koios max-rows limit. A page shorter than this is
	// the last one.
	koiosPageSize = 1000

	// ogmiosOverlappingAdditionalUtxo is the Ogmios v6 evaluateTransaction
	// error returned when supplied additional UTxOs already exist on chain.
	ogmiosOverlappingAdditionalUtxo = 3002
)

// NewKoiosChainContext creates a new Koios backend.
//
// baseUrl is the full API base URL, including the version path, such as
// constants.KoiosBaseUrlMainnet or a self-hosted instance's
// https://koios.example.com/api/v1. It is used as given; only trailing
// slashes are removed before request paths are appended. token is an
// optional Koios bearer token; pass "" for the public tier.
func NewKoiosChainContext(baseUrl string, networkId uint8, token string) *KoiosChainContext {
	return &KoiosChainContext{
		baseUrl:   strings.TrimRight(baseUrl, "/"),
		token:     token,
		networkId: networkId,
		client:    &http.Client{Timeout: 30 * time.Second, CheckRedirect: backendutil.SameOriginRedirect},
	}
}

// Capabilities reports the ChainContext feature set implemented by Koios.
// Evaluation goes through the Koios Ogmios proxy, which accepts additional
// UTxOs for inputs that are not yet on chain.
func (k *KoiosChainContext) Capabilities() backend.CapabilitySet {
	return backend.CapabilitySet(backend.AllCapabilities)
}

func (k *KoiosChainContext) requestContext(
	ctx context.Context,
	method, path string,
	body []byte,
	contentType string,
) ([]byte, error) {
	var reader io.Reader
	if body != nil {
		reader = bytes.NewReader(body)
	}
	req, err := http.NewRequestWithContext(ctx, method, k.baseUrl+path, reader)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	if k.token != "" {
		req.Header.Set("Authorization", "Bearer "+k.token)
	}
	resp, err := k.client.Do(req)
	if err != nil {
		return nil, err
	}
	if resp == nil || resp.Body == nil {
		return nil, errors.New("koios: nil response")
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxKoiosResponseBytes+1))
	if err != nil {
		return nil, err
	}
	if len(data) > maxKoiosResponseBytes {
		return nil, fmt.Errorf("koios response body exceeds %d bytes", maxKoiosResponseBytes)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, &apiError{status: resp.StatusCode, body: data}
	}
	return data, nil
}

// apiError is a non-2xx Koios response. The body is kept because the Ogmios
// proxy reports JSON-RPC errors, which callers must inspect, with status 400.
type apiError struct {
	status int
	body   []byte
}

func (e *apiError) Error() string {
	return fmt.Sprintf("koios API error %d: %s", e.status, errorSnippet(e.body))
}

func (k *KoiosChainContext) postJSON(ctx context.Context, path string, payload any) ([]byte, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to encode koios request: %w", err)
	}
	return k.requestContext(ctx, http.MethodPost, path, body, "application/json")
}

func errorSnippet(data []byte) string {
	if len(data) > maxKoiosErrorSnippetSize {
		data = data[:maxKoiosErrorSnippetSize]
	}
	return string(data)
}

func (k *KoiosChainContext) ProtocolParams() (backend.ProtocolParameters, error) {
	return k.ProtocolParamsContext(context.Background())
}

func (k *KoiosChainContext) ProtocolParamsContext(ctx context.Context) (backend.ProtocolParameters, error) {
	k.mu.Lock()
	if k.cachedParams != nil && time.Since(k.paramsCacheAt) < cacheExpiry {
		pp := backendutil.CloneProtocolParams(*k.cachedParams)
		k.mu.Unlock()
		return pp, nil
	}
	k.mu.Unlock()

	tip, err := k.tipContext(ctx)
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	path := "/epoch_params?_epoch_no=" + strconv.FormatUint(tip.EpochNo, 10)
	data, err := k.requestContext(ctx, http.MethodGet, path, nil, "")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	var rows []koiosEpochParams
	if err := json.Unmarshal(data, &rows); err != nil {
		return backend.ProtocolParameters{}, fmt.Errorf("failed to parse koios epoch_params: %w", err)
	}
	if len(rows) != 1 {
		return backend.ProtocolParameters{}, fmt.Errorf(
			"koios epoch_params returned %d rows for epoch %d, want 1", len(rows), tip.EpochNo,
		)
	}
	pp, err := rows[0].toProtocolParams()
	if err != nil {
		return backend.ProtocolParameters{}, err
	}

	cached := backendutil.CloneProtocolParams(pp)
	k.mu.Lock()
	k.cachedParams = &cached
	k.paramsCacheAt = time.Now()
	k.mu.Unlock()
	return pp, nil
}

func (k *KoiosChainContext) GenesisParams() (backend.GenesisParameters, error) {
	return k.GenesisParamsContext(context.Background())
}

func (k *KoiosChainContext) GenesisParamsContext(ctx context.Context) (backend.GenesisParameters, error) {
	k.mu.Lock()
	if k.cachedGenesis != nil && time.Since(k.genesisCacheAt) < cacheExpiry {
		gp := *k.cachedGenesis
		k.mu.Unlock()
		return gp, nil
	}
	k.mu.Unlock()

	data, err := k.requestContext(ctx, http.MethodGet, "/genesis", nil, "")
	if err != nil {
		return backend.GenesisParameters{}, err
	}
	var rows []koiosGenesis
	if err := json.Unmarshal(data, &rows); err != nil {
		return backend.GenesisParameters{}, fmt.Errorf("failed to parse koios genesis: %w", err)
	}
	if len(rows) == 0 {
		return backend.GenesisParameters{}, errors.New("koios genesis returned no rows")
	}
	gp, err := rows[0].toGenesisParams()
	if err != nil {
		return backend.GenesisParameters{}, err
	}

	k.mu.Lock()
	k.cachedGenesis = &gp
	k.genesisCacheAt = time.Now()
	k.mu.Unlock()
	return gp, nil
}

func (k *KoiosChainContext) NetworkId() uint8 {
	return k.networkId
}

type koiosTip struct {
	EpochNo uint64 `json:"epoch_no"`
	AbsSlot uint64 `json:"abs_slot"`
}

func (k *KoiosChainContext) tipContext(ctx context.Context) (koiosTip, error) {
	data, err := k.requestContext(ctx, http.MethodGet, "/tip", nil, "")
	if err != nil {
		return koiosTip{}, err
	}
	var rows []koiosTip
	if err := json.Unmarshal(data, &rows); err != nil {
		return koiosTip{}, fmt.Errorf("failed to parse koios tip: %w", err)
	}
	if len(rows) != 1 {
		return koiosTip{}, fmt.Errorf("koios tip returned %d rows, want 1", len(rows))
	}
	return rows[0], nil
}

func (k *KoiosChainContext) CurrentEpoch() (uint64, error) {
	return k.CurrentEpochContext(context.Background())
}

func (k *KoiosChainContext) CurrentEpochContext(ctx context.Context) (uint64, error) {
	tip, err := k.tipContext(ctx)
	if err != nil {
		return 0, err
	}
	return tip.EpochNo, nil
}

func (k *KoiosChainContext) MaxTxFee() (uint64, error) {
	return k.MaxTxFeeContext(context.Background())
}

func (k *KoiosChainContext) MaxTxFeeContext(ctx context.Context) (uint64, error) {
	pp, err := k.ProtocolParamsContext(ctx)
	if err != nil {
		return 0, err
	}
	return backend.ComputeMaxTxFee(pp)
}

func (k *KoiosChainContext) Tip() (uint64, error) {
	return k.TipContext(context.Background())
}

func (k *KoiosChainContext) TipContext(ctx context.Context) (uint64, error) {
	tip, err := k.tipContext(ctx)
	if err != nil {
		return 0, err
	}
	return tip.AbsSlot, nil
}

func (k *KoiosChainContext) Utxos(address common.Address) ([]common.Utxo, error) {
	return k.UtxosContext(context.Background(), address)
}

func (k *KoiosChainContext) UtxosContext(ctx context.Context, address common.Address) ([]common.Utxo, error) {
	addr := address.String()
	payload := struct {
		Addresses []string `json:"_addresses"`
		Extended  bool     `json:"_extended"`
	}{Addresses: []string{addr}, Extended: true}

	var utxos []common.Utxo
	var references backendutil.UtxoReferenceSet
	for offset := int64(0); ; offset += koiosPageSize {
		query := url.Values{}
		query.Set("offset", strconv.FormatInt(offset, 10))
		query.Set("limit", strconv.Itoa(koiosPageSize))
		// A stable order keeps offset pages from skipping or repeating rows.
		query.Set("order", "tx_hash.asc,tx_index.asc")
		data, err := k.postJSON(ctx, "/address_utxos?"+query.Encode(), payload)
		if err != nil {
			return nil, err
		}
		rows, err := backendutil.DecodeLimitedArray[koiosUtxo](data, koiosPageSize)
		if err != nil {
			return nil, fmt.Errorf("failed to parse koios address_utxos: %w", err)
		}
		if len(rows) == 0 {
			return utxos, nil
		}
		for _, row := range rows {
			if row.Address != addr {
				return nil, fmt.Errorf(
					"koios returned UTxO %s#%s for address %s, want %s",
					row.TxHash, row.TxIndex, row.Address, addr,
				)
			}
			utxo, err := row.toUtxo()
			if err != nil {
				return nil, fmt.Errorf("failed to parse UTxO %s#%s: %w", row.TxHash, row.TxIndex, err)
			}
			if err := references.Add(utxo); err != nil {
				return nil, err
			}
			utxos = append(utxos, utxo)
		}
		if len(rows) < koiosPageSize {
			return utxos, nil
		}
	}
}

func (k *KoiosChainContext) SubmitTx(txCbor []byte) (common.Blake2b256, error) {
	return k.SubmitTxContext(context.Background(), txCbor)
}

func (k *KoiosChainContext) SubmitTxContext(ctx context.Context, txCbor []byte) (common.Blake2b256, error) {
	data, err := k.requestContext(ctx, http.MethodPost, "/submittx", txCbor, "application/cbor")
	if err != nil {
		return common.Blake2b256{}, err
	}
	var txHash string
	if err := json.Unmarshal(data, &txHash); err != nil {
		return common.Blake2b256{}, fmt.Errorf("failed to parse koios submittx response: %w", err)
	}
	result, err := parseBlake2b256(txHash, "tx hash")
	if err != nil {
		return common.Blake2b256{}, err
	}
	if err := backend.VerifySubmittedTxID(txCbor, result); err != nil {
		return common.Blake2b256{}, err
	}
	return result, nil
}

func (k *KoiosChainContext) EvaluateTx(
	txCbor []byte,
	additionalUtxos []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, error) {
	return k.EvaluateTxContext(context.Background(), txCbor, additionalUtxos)
}

// EvaluateTxContext evaluates the transaction through the Koios Ogmios proxy.
//
// Apollo supplies every spending input as an additional UTxO whether or not
// it is on chain. Ogmios accepts an entry identical to the ledger's but
// rejects one that differs from it. When Ogmios reports such an overlap, the
// overlapping entries are dropped, so the ledger's versions are used, and the
// evaluation is retried once with the remainder.
func (k *KoiosChainContext) EvaluateTxContext(
	ctx context.Context,
	txCbor []byte,
	additionalUtxos []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, error) {
	for i, utxo := range additionalUtxos {
		if err := backend.ValidateAdditionalUtxo(utxo); err != nil {
			return nil, fmt.Errorf("invalid additional UTxO at index %d: %w", i, err)
		}
	}
	result, rpcErr, err := k.evaluateOnce(ctx, txCbor, additionalUtxos)
	if err != nil {
		return nil, err
	}
	if rpcErr == nil {
		return result, nil
	}
	if rpcErr.Code != ogmiosOverlappingAdditionalUtxo {
		return nil, rpcErr
	}
	overlapping, err := rpcErr.overlappingRefs()
	if err != nil {
		return nil, err
	}
	remaining := make([]common.Utxo, 0, len(additionalUtxos))
	for _, utxo := range additionalUtxos {
		if _, ok := overlapping[utxoRef(utxo.Id)]; !ok {
			remaining = append(remaining, utxo)
		}
	}
	if len(remaining) == len(additionalUtxos) {
		return nil, fmt.Errorf("%w (no supplied UTxO matched the reported overlap)", rpcErr)
	}
	result, rpcErr, err = k.evaluateOnce(ctx, txCbor, remaining)
	if err != nil {
		return nil, err
	}
	if rpcErr != nil {
		return nil, rpcErr
	}
	return result, nil
}

type ogmiosRPCError struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
}

func (e *ogmiosRPCError) Error() string {
	if len(e.Data) > 0 && string(e.Data) != "null" {
		return fmt.Sprintf("script evaluation failed (code %d): %s: %s", e.Code, e.Message, errorSnippet(e.Data))
	}
	return fmt.Sprintf("script evaluation failed (code %d): %s", e.Code, e.Message)
}

// overlappingRefs returns the "txid#index" references listed in an Ogmios
// OverlappingAdditionalUtxo error.
func (e *ogmiosRPCError) overlappingRefs() (map[string]struct{}, error) {
	var data struct {
		Refs []struct {
			Transaction struct {
				ID string `json:"id"`
			} `json:"transaction"`
			Index uint64 `json:"index"`
		} `json:"overlappingOutputReferences"`
	}
	if err := json.Unmarshal(e.Data, &data); err != nil || len(data.Refs) == 0 {
		return nil, fmt.Errorf("%w (malformed overlap data)", e)
	}
	refs := make(map[string]struct{}, len(data.Refs))
	for _, ref := range data.Refs {
		refs[strings.ToLower(ref.Transaction.ID)+"#"+strconv.FormatUint(ref.Index, 10)] = struct{}{}
	}
	return refs, nil
}

func utxoRef(input common.TransactionInput) string {
	return hex.EncodeToString(input.Id().Bytes()) + "#" + strconv.FormatUint(uint64(input.Index()), 10)
}

// evaluateOnce posts one evaluateTransaction request. A JSON-RPC error from
// Ogmios is returned as rpcErr so the caller can inspect its code; err is
// reserved for transport and decoding failures.
func (k *KoiosChainContext) evaluateOnce(
	ctx context.Context,
	txCbor []byte,
	additionalUtxos []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, *ogmiosRPCError, error) {
	type transaction struct {
		Cbor string `json:"cbor"`
	}
	type params struct {
		Transaction    transaction `json:"transaction"`
		AdditionalUtxo any         `json:"additionalUtxo,omitempty"`
	}
	p := params{Transaction: transaction{Cbor: hex.EncodeToString(txCbor)}}
	if len(additionalUtxos) > 0 {
		shared, err := ogmiosutil.UtxosToShared(additionalUtxos)
		if err != nil {
			return nil, nil, err
		}
		p.AdditionalUtxo = shared
	}
	request := struct {
		JSONRPC string `json:"jsonrpc"`
		Method  string `json:"method"`
		Params  params `json:"params"`
	}{JSONRPC: "2.0", Method: "evaluateTransaction", Params: p}

	var response struct {
		Result json.RawMessage `json:"result"`
		Error  *ogmiosRPCError `json:"error"`
	}
	data, err := k.postJSON(ctx, "/ogmios", request)
	if err != nil {
		// Koios returns Ogmios JSON-RPC errors with status 400. Report the
		// JSON-RPC error when the body holds one, and the HTTP error otherwise.
		var httpErr *apiError
		if errors.As(err, &httpErr) && json.Unmarshal(httpErr.body, &response) == nil && response.Error != nil {
			return nil, response.Error, nil
		}
		return nil, nil, err
	}
	if err := json.Unmarshal(data, &response); err != nil {
		return nil, nil, fmt.Errorf("failed to parse koios ogmios response: %w", err)
	}
	if response.Error != nil {
		return nil, response.Error, nil
	}
	if len(response.Result) == 0 || string(response.Result) == "null" {
		return nil, nil, fmt.Errorf("unrecognized evaluate response (no result or error): %s", errorSnippet(data))
	}
	result, err := ogmiosutil.ParseEvaluationResult(response.Result)
	if err != nil {
		return nil, nil, err
	}
	return result, nil, nil
}

func (k *KoiosChainContext) UtxoByRef(txHash common.Blake2b256, index uint32) (*common.Utxo, error) {
	return k.UtxoByRefContext(context.Background(), txHash, index)
}

// UtxoByRefContext returns the output at txHash#index. Like the Blockfrost
// backend, it returns an output that exists on chain even if it has since been
// spent.
func (k *KoiosChainContext) UtxoByRefContext(
	ctx context.Context,
	txHash common.Blake2b256,
	index uint32,
) (*common.Utxo, error) {
	hashHex := hex.EncodeToString(txHash.Bytes())
	ref := hashHex + "#" + strconv.FormatUint(uint64(index), 10)
	payload := struct {
		Refs     []string `json:"_utxo_refs"`
		Extended bool     `json:"_extended"`
	}{Refs: []string{ref}, Extended: true}
	data, err := k.postJSON(ctx, "/utxo_info", payload)
	if err != nil {
		return nil, err
	}
	var rows []koiosUtxo
	if err := json.Unmarshal(data, &rows); err != nil {
		return nil, fmt.Errorf("failed to parse koios utxo_info: %w", err)
	}
	for _, row := range rows {
		utxo, err := row.toUtxo()
		if err != nil {
			return nil, fmt.Errorf("failed to parse UTxO %s: %w", ref, err)
		}
		if utxo.Id.Id() == txHash && utxo.Id.Index() == index {
			return &utxo, nil
		}
	}
	return nil, errors.New("utxo not found")
}

func (k *KoiosChainContext) ScriptCbor(scriptHash common.Blake2b224) ([]byte, error) {
	return k.ScriptCborContext(context.Background(), scriptHash)
}

// ScriptCborContext returns the script with the given hash in the same form
// as the gouroboros script types, verified against the requested hash.
func (k *KoiosChainContext) ScriptCborContext(
	ctx context.Context,
	scriptHash common.Blake2b224,
) ([]byte, error) {
	hashHex := hex.EncodeToString(scriptHash.Bytes())
	payload := struct {
		Hashes []string `json:"_script_hashes"`
	}{Hashes: []string{hashHex}}
	data, err := k.postJSON(ctx, "/script_info", payload)
	if err != nil {
		return nil, err
	}
	var rows []struct {
		ScriptHash *string         `json:"script_hash"`
		Type       string          `json:"type"`
		Bytes      *string         `json:"bytes"`
		Value      json.RawMessage `json:"value"`
	}
	if err := json.Unmarshal(data, &rows); err != nil {
		return nil, fmt.Errorf("failed to parse koios script_info: %w", err)
	}
	for _, row := range rows {
		if row.ScriptHash == nil || !strings.EqualFold(*row.ScriptHash, hashHex) {
			continue
		}
		scriptRef, err := scriptRefFromKoios(row.Type, row.Bytes, row.Value, hashHex)
		if err != nil {
			return nil, err
		}
		return scriptRef.Script.RawScriptBytes(), nil
	}
	return nil, fmt.Errorf("script %s not found", hashHex)
}

// --- Koios response types ---

type koiosEpochParams struct {
	MinFeeA                    json.Number     `json:"min_fee_a"`
	MinFeeB                    json.Number     `json:"min_fee_b"`
	MaxBlockSize               json.Number     `json:"max_block_size"`
	MaxTxSize                  json.Number     `json:"max_tx_size"`
	MaxBhSize                  json.Number     `json:"max_bh_size"`
	KeyDeposit                 *string         `json:"key_deposit"`
	PoolDeposit                *string         `json:"pool_deposit"`
	Decentralisation           json.Number     `json:"decentralisation"`
	ExtraEntropy               *string         `json:"extra_entropy"`
	ProtocolMajor              json.Number     `json:"protocol_major"`
	ProtocolMinor              json.Number     `json:"protocol_minor"`
	MinPoolCost                *string         `json:"min_pool_cost"`
	CostModels                 json.RawMessage `json:"cost_models"`
	PriceMem                   json.Number     `json:"price_mem"`
	PriceStep                  json.Number     `json:"price_step"`
	MaxTxExMem                 json.Number     `json:"max_tx_ex_mem"`
	MaxTxExSteps               json.Number     `json:"max_tx_ex_steps"`
	MaxBlockExMem              json.Number     `json:"max_block_ex_mem"`
	MaxBlockExSteps            json.Number     `json:"max_block_ex_steps"`
	MaxValSize                 json.Number     `json:"max_val_size"`
	CollateralPercent          json.Number     `json:"collateral_percent"`
	MaxCollateralInputs        json.Number     `json:"max_collateral_inputs"`
	CoinsPerUtxoSize           *string         `json:"coins_per_utxo_size"`
	MinFeeRefScriptCostPerByte json.Number     `json:"min_fee_ref_script_cost_per_byte"`
}

// missingRequired lists Babbage/Conway parameters that a transaction cannot
// be priced or validated without. Reporting them keeps a null or renamed
// Koios field from silently becoming a zero fee, deposit, or limit.
func (p *koiosEpochParams) missingRequired() []string {
	required := []struct {
		name    string
		present bool
	}{
		{"min_fee_a", p.MinFeeA != ""},
		{"min_fee_b", p.MinFeeB != ""},
		{"max_tx_size", p.MaxTxSize != ""},
		{"key_deposit", p.KeyDeposit != nil},
		{"pool_deposit", p.PoolDeposit != nil},
		{"protocol_major", p.ProtocolMajor != ""},
		{"protocol_minor", p.ProtocolMinor != ""},
		{"min_pool_cost", p.MinPoolCost != nil},
		{"cost_models", len(p.CostModels) > 0 && string(p.CostModels) != "null"},
		{"price_mem", p.PriceMem != ""},
		{"price_step", p.PriceStep != ""},
		{"max_tx_ex_mem", p.MaxTxExMem != ""},
		{"max_tx_ex_steps", p.MaxTxExSteps != ""},
		{"max_val_size", p.MaxValSize != ""},
		{"collateral_percent", p.CollateralPercent != ""},
		{"max_collateral_inputs", p.MaxCollateralInputs != ""},
		{"coins_per_utxo_size", p.CoinsPerUtxoSize != nil},
	}
	var missing []string
	for _, field := range required {
		if !field.present {
			missing = append(missing, field.name)
		}
	}
	return missing
}

func (p *koiosEpochParams) toProtocolParams() (backend.ProtocolParameters, error) {
	if missing := p.missingRequired(); len(missing) > 0 {
		return backend.ProtocolParameters{}, fmt.Errorf(
			"koios protocol parameters missing required fields: %s", strings.Join(missing, ", "),
		)
	}
	var errs []error
	integer := func(n json.Number, name string) int64 {
		v, err := parseNonNegativeInt64(string(n), name)
		errs = append(errs, err)
		return v
	}
	bounded := func(n json.Number, name string) int {
		if n == "" {
			return 0
		}
		v, err := backendutil.BoundedInt(integer(n, name), name)
		errs = append(errs, err)
		return v
	}
	integerString := func(n json.Number, name string) string {
		if n == "" {
			return ""
		}
		return strconv.FormatInt(integer(n, name), 10)
	}
	lovelace := func(s *string, name string) string {
		_, err := parseNonNegativeInt64(*s, name)
		errs = append(errs, err)
		return *s
	}
	price := func(n json.Number, name string) float64 {
		r, err := backendutil.ParseRational(string(n))
		if err == nil && r.Sign() < 0 {
			err = fmt.Errorf("%s is negative: %s", name, n)
		}
		if err != nil {
			errs = append(errs, fmt.Errorf("invalid %s: %w", name, err))
			return 0
		}
		f, _ := r.Float64()
		return f
	}

	pp := backend.ProtocolParameters{
		MinFeeCoefficient:    integer(p.MinFeeA, "min_fee_a"),
		MinFeeConstant:       integer(p.MinFeeB, "min_fee_b"),
		MaxBlockSize:         bounded(p.MaxBlockSize, "max_block_size"),
		MaxTxSize:            bounded(p.MaxTxSize, "max_tx_size"),
		MaxBlockHeaderSize:   bounded(p.MaxBhSize, "max_bh_size"),
		KeyDeposits:          lovelace(p.KeyDeposit, "key_deposit"),
		PoolDeposits:         lovelace(p.PoolDeposit, "pool_deposit"),
		ProtocolMajorVersion: bounded(p.ProtocolMajor, "protocol_major"),
		ProtocolMinorVersion: bounded(p.ProtocolMinor, "protocol_minor"),
		MinPoolCost:          lovelace(p.MinPoolCost, "min_pool_cost"),
		PriceMem:             price(p.PriceMem, "price_mem"),
		PriceStep:            price(p.PriceStep, "price_step"),
		MaxTxExMem:           integerString(p.MaxTxExMem, "max_tx_ex_mem"),
		MaxTxExSteps:         integerString(p.MaxTxExSteps, "max_tx_ex_steps"),
		MaxBlockExMem:        integerString(p.MaxBlockExMem, "max_block_ex_mem"),
		MaxBlockExSteps:      integerString(p.MaxBlockExSteps, "max_block_ex_steps"),
		MaxValSize:           integerString(p.MaxValSize, "max_val_size"),
		CollateralPercent:    bounded(p.CollateralPercent, "collateral_percent"),
		MaxCollateralInputs:  bounded(p.MaxCollateralInputs, "max_collateral_inputs"),
		CoinsPerUtxoByte:     lovelace(p.CoinsPerUtxoSize, "coins_per_utxo_size"),
	}
	if p.Decentralisation != "" {
		pp.DecentralizationParam = price(p.Decentralisation, "decentralisation")
	}
	if p.ExtraEntropy != nil {
		pp.ExtraEntropy = *p.ExtraEntropy
	}
	if err := errors.Join(errs...); err != nil {
		return backend.ProtocolParameters{}, fmt.Errorf("invalid koios protocol parameters: %w", err)
	}

	if p.MinFeeRefScriptCostPerByte != "" {
		refPrice, err := backendutil.ParseRational(string(p.MinFeeRefScriptCostPerByte))
		if err != nil {
			return backend.ProtocolParameters{}, fmt.Errorf("invalid min_fee_ref_script_cost_per_byte: %w", err)
		}
		if refPrice.Sign() < 0 {
			return backend.ProtocolParameters{}, fmt.Errorf(
				"min_fee_ref_script_cost_per_byte is negative: %s", p.MinFeeRefScriptCostPerByte,
			)
		}
		pp.MinFeeRefScriptCostPerByteRational = refPrice
		pp.MinFeeRefScriptCostPerByte, _ = refPrice.Float64()
	}

	costModels, err := parseCostModels(p.CostModels)
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	pp.CostModels = costModels
	return pp, nil
}

// parseCostModels accepts only the flat integer-array form of cost models.
// A keyed (parameter name to value) form is rejected rather than reordered,
// because the ledger's parameter order is not alphabetical for every
// language and a wrong order produces a script integrity hash mismatch.
func parseCostModels(raw json.RawMessage) (map[string][]int64, error) {
	var models map[string][]int64
	if err := json.Unmarshal(raw, &models); err != nil {
		return nil, fmt.Errorf("failed to parse cost_models as integer arrays: %w", err)
	}
	result := make(map[string][]int64, len(models))
	for language, costs := range models {
		key := canonicalCostModelKey(language)
		if _, ok := result[key]; ok {
			return nil, fmt.Errorf("duplicate cost model for %s", key)
		}
		result[key] = costs
	}
	return result, nil
}

// canonicalCostModelKey maps Koios cost model keys to the "PlutusV1" through
// "PlutusV4" form expected by ComputeScriptDataHash.
func canonicalCostModelKey(key string) string {
	switch strings.ToLower(strings.ReplaceAll(key, ":", "")) {
	case "plutusv1":
		return "PlutusV1"
	case "plutusv2":
		return "PlutusV2"
	case "plutusv3":
		return "PlutusV3"
	case "plutusv4":
		return "PlutusV4"
	default:
		return key
	}
}

type koiosGenesis struct {
	NetworkMagic      string      `json:"networkmagic"`
	EpochLength       string      `json:"epochlength"`
	SlotLength        string      `json:"slotlength"`
	MaxLovelaceSupply string      `json:"maxlovelacesupply"`
	SystemStart       json.Number `json:"systemstart"`
	ActiveSlotCoeff   string      `json:"activeslotcoeff"`
	SlotsPerKesPeriod string      `json:"slotsperkesperiod"`
	MaxKesRevolutions string      `json:"maxkesrevolutions"`
	SecurityParam     string      `json:"securityparam"`
	UpdateQuorum      string      `json:"updatequorum"`
}

func (g *koiosGenesis) toGenesisParams() (backend.GenesisParameters, error) {
	var errs []error
	bounded := func(s, name string) int {
		v, err := parseNonNegativeInt64(s, name)
		if err == nil {
			var n int
			n, err = backendutil.BoundedInt(v, name)
			if err == nil {
				return n
			}
		}
		errs = append(errs, err)
		return 0
	}
	gp := backend.GenesisParameters{
		NetworkMagic:      bounded(g.NetworkMagic, "networkmagic"),
		EpochLength:       bounded(g.EpochLength, "epochlength"),
		SlotLength:        bounded(g.SlotLength, "slotlength"),
		SlotsPerKesPeriod: bounded(g.SlotsPerKesPeriod, "slotsperkesperiod"),
		MaxKesEvolutions:  bounded(g.MaxKesRevolutions, "maxkesrevolutions"),
		SecurityParam:     bounded(g.SecurityParam, "securityparam"),
		UpdateQuorum:      bounded(g.UpdateQuorum, "updatequorum"),
		MaxLovelaceSupply: g.MaxLovelaceSupply,
	}
	if _, err := parseNonNegativeInt64(g.MaxLovelaceSupply, "maxlovelacesupply"); err != nil {
		errs = append(errs, err)
	}
	systemStart, err := parseNonNegativeInt64(string(g.SystemStart), "systemstart")
	errs = append(errs, err)
	gp.SystemStart = systemStart
	coeff, err := backendutil.ParseRational(g.ActiveSlotCoeff)
	if err != nil || coeff.Sign() <= 0 || coeff.Cmp(big.NewRat(1, 1)) > 0 {
		errs = append(errs, fmt.Errorf("invalid activeslotcoeff %q", g.ActiveSlotCoeff))
	} else {
		gp.ActiveSlotsCoefficient, _ = coeff.Float64()
	}
	if err := errors.Join(errs...); err != nil {
		return backend.GenesisParameters{}, fmt.Errorf("invalid koios genesis: %w", err)
	}
	return gp, nil
}

// parseNonNegativeInt64 parses a provider integer, accepting the decimal and
// exponent forms a JSON number may take as long as the value is integral.
func parseNonNegativeInt64(s, name string) (int64, error) {
	r, err := backendutil.ParseRational(s)
	if err != nil || !r.IsInt() {
		return 0, fmt.Errorf("invalid %s: %q is not an integer", name, s)
	}
	if r.Sign() < 0 {
		return 0, fmt.Errorf("%s is negative: %s", name, s)
	}
	if !r.Num().IsInt64() {
		return 0, fmt.Errorf("%s out of range: %s", name, s)
	}
	return r.Num().Int64(), nil
}

type koiosUtxo struct {
	TxHash          string                `json:"tx_hash"`
	TxIndex         json.Number           `json:"tx_index"`
	Address         string                `json:"address"`
	Value           string                `json:"value"`
	DatumHash       *string               `json:"datum_hash"`
	InlineDatum     *koiosInlineDatum     `json:"inline_datum"`
	ReferenceScript *koiosReferenceScript `json:"reference_script"`
	AssetList       []koiosAsset          `json:"asset_list"`
}

type koiosInlineDatum struct {
	Bytes string `json:"bytes"`
}

type koiosReferenceScript struct {
	Hash  string          `json:"hash"`
	Type  string          `json:"type"`
	Bytes *string         `json:"bytes"`
	Value json.RawMessage `json:"value"`
}

type koiosAsset struct {
	PolicyID  string  `json:"policy_id"`
	AssetName *string `json:"asset_name"`
	Quantity  string  `json:"quantity"`
}

func (raw *koiosUtxo) toUtxo() (common.Utxo, error) {
	txId, err := parseBlake2b256(raw.TxHash, "tx hash")
	if err != nil {
		return common.Utxo{}, err
	}
	index, err := parseNonNegativeInt64(string(raw.TxIndex), "tx_index")
	if err != nil {
		return common.Utxo{}, err
	}
	if index > math.MaxUint32 {
		return common.Utxo{}, fmt.Errorf("output index %d exceeds uint32 range", index)
	}
	address, err := common.NewAddress(raw.Address)
	if err != nil {
		return common.Utxo{}, fmt.Errorf("invalid address %q: %w", raw.Address, err)
	}
	lovelace, err := parseNonNegativeInt64(raw.Value, "value")
	if err != nil {
		return common.Utxo{}, err
	}

	assetData := make(map[common.Blake2b224]map[cbor.ByteString]*big.Int)
	for _, asset := range raw.AssetList {
		assetName := ""
		if asset.AssetName != nil {
			assetName = *asset.AssetName
		}
		policyId, name, err := backendutil.ParseAssetUnit(asset.PolicyID + assetName)
		if err != nil {
			return common.Utxo{}, fmt.Errorf("invalid asset %s.%s: %w", asset.PolicyID, assetName, err)
		}
		qty, ok := new(big.Int).SetString(asset.Quantity, 10)
		if !ok || qty.Sign() <= 0 {
			return common.Utxo{}, fmt.Errorf("invalid quantity %q for asset %s.%s", asset.Quantity, asset.PolicyID, assetName)
		}
		if assetData[policyId] == nil {
			assetData[policyId] = make(map[cbor.ByteString]*big.Int)
		}
		if _, ok := assetData[policyId][name]; ok {
			return common.Utxo{}, fmt.Errorf("duplicate asset %s.%s", asset.PolicyID, assetName)
		}
		assetData[policyId][name] = qty
	}
	var assets *common.MultiAsset[common.MultiAssetTypeOutput]
	if len(assetData) > 0 {
		ma := common.NewMultiAsset[common.MultiAssetTypeOutput](assetData)
		assets = &ma
	}

	output := babbage.BabbageTransactionOutput{
		OutputAddress: address,
		OutputAmount: mary.MaryTransactionOutputValue{
			Amount: uint64(lovelace), //nolint:gosec // validated non-negative above
			Assets: assets,
		},
	}

	switch {
	case raw.InlineDatum != nil:
		datumOpt, err := inlineDatumOption(raw.InlineDatum.Bytes, raw.DatumHash)
		if err != nil {
			return common.Utxo{}, err
		}
		output.DatumOption = datumOpt
	case raw.DatumHash != nil && *raw.DatumHash != "":
		datumOpt, err := datumHashOption(*raw.DatumHash)
		if err != nil {
			return common.Utxo{}, err
		}
		output.DatumOption = datumOpt
	}

	if raw.ReferenceScript != nil {
		scriptRef, err := scriptRefFromKoios(
			raw.ReferenceScript.Type, raw.ReferenceScript.Bytes, raw.ReferenceScript.Value, raw.ReferenceScript.Hash,
		)
		if err != nil {
			return common.Utxo{}, err
		}
		output.TxOutScriptRef = scriptRef
	}

	return common.Utxo{
		Id: shelley.ShelleyTransactionInput{
			TxId:        txId,
			OutputIndex: uint32(index), //nolint:gosec // range checked above
		},
		Output: &output,
	}, nil
}

func parseBlake2b256(hashHex, name string) (common.Blake2b256, error) {
	hashBytes, err := hex.DecodeString(hashHex)
	if err != nil {
		return common.Blake2b256{}, fmt.Errorf("invalid %s hex %q: %w", name, hashHex, err)
	}
	if len(hashBytes) != common.Blake2b256Size {
		return common.Blake2b256{}, fmt.Errorf(
			"invalid %s length: expected %d bytes, got %d", name, common.Blake2b256Size, len(hashBytes),
		)
	}
	var hash common.Blake2b256
	copy(hash[:], hashBytes)
	return hash, nil
}

// inlineDatumOption builds an inline datum option from the datum's CBOR hex,
// preserving the original bytes so the datum hash is unchanged. When Koios
// also reports the datum hash, it must match those bytes.
func inlineDatumOption(datumHex string, datumHash *string) (*babbage.BabbageTransactionOutputDatumOption, error) {
	datumBytes, err := hex.DecodeString(datumHex)
	if err != nil || len(datumBytes) == 0 {
		return nil, fmt.Errorf("invalid inline datum CBOR hex %q", datumHex)
	}
	if datumHash != nil && *datumHash != "" {
		want, err := parseBlake2b256(*datumHash, "datum hash")
		if err != nil {
			return nil, err
		}
		if got := common.Blake2b256Hash(datumBytes); got != want {
			return nil, fmt.Errorf("inline datum hash mismatch: computed %s, provider claimed %s", got, *datumHash)
		}
	}
	cborBytes, err := cbor.Encode([]any{1, cbor.Tag{Number: 24, Content: datumBytes}})
	if err != nil {
		return nil, fmt.Errorf("failed to encode inline datum option: %w", err)
	}
	var opt babbage.BabbageTransactionOutputDatumOption
	if err := opt.UnmarshalCBOR(cborBytes); err != nil {
		return nil, fmt.Errorf("failed to decode inline datum: %w", err)
	}
	return &opt, nil
}

func datumHashOption(hashHex string) (*babbage.BabbageTransactionOutputDatumOption, error) {
	hash, err := parseBlake2b256(hashHex, "datum hash")
	if err != nil {
		return nil, err
	}
	cborBytes, err := cbor.Encode([]any{0, hash})
	if err != nil {
		return nil, fmt.Errorf("failed to encode datum option hash: %w", err)
	}
	var opt babbage.BabbageTransactionOutputDatumOption
	if err := opt.UnmarshalCBOR(cborBytes); err != nil {
		return nil, fmt.Errorf("failed to decode datum option: %w", err)
	}
	return &opt, nil
}

// scriptRefFromKoios builds a reference script from a Koios script type and
// hex bytes, verifying it against hashHex. Koios reports Plutus script bytes
// from db-sync, so they are tried both as given and with one CBOR byte-string
// wrapper added or removed; only a form whose hash matches is accepted.
// Koios reports native scripts with null bytes and only their JSON form, so
// a native script is rebuilt from value when bytes are absent.
func scriptRefFromKoios(scriptType string, bytesHex *string, value json.RawMessage, hashHex string) (*common.ScriptRef, error) {
	native := false
	switch strings.ToLower(scriptType) {
	case "timelock", "multisig", "native":
		native = true
	}
	if bytesHex == nil || *bytesHex == "" {
		if native {
			return nativeScriptRefFromJSON(value, hashHex)
		}
		return nil, fmt.Errorf("koios returned no bytes for %s script %s", scriptType, hashHex)
	}
	scriptBytes, err := hex.DecodeString(*bytesHex)
	if err != nil {
		return nil, fmt.Errorf("invalid script bytes hex: %w", err)
	}
	if native {
		return backendutil.ScriptRefFromBytes(common.ScriptRefTypeNativeScript, scriptBytes, hashHex)
	}
	var refType uint
	switch strings.ToLower(scriptType) {
	case "plutusv1":
		refType = common.ScriptRefTypePlutusV1
	case "plutusv2":
		refType = common.ScriptRefTypePlutusV2
	case "plutusv3":
		refType = common.ScriptRefTypePlutusV3
	case "plutusv4":
		refType = common.ScriptRefTypePlutusV4
	default:
		return nil, fmt.Errorf("unsupported koios script type %q", scriptType)
	}
	candidates := [][]byte{scriptBytes}
	if wrapped, err := cbor.Encode(scriptBytes); err == nil {
		candidates = append(candidates, wrapped)
	}
	var unwrapped []byte
	if n, err := cbor.Decode(scriptBytes, &unwrapped); err == nil && n == len(scriptBytes) {
		candidates = append(candidates, unwrapped)
	}
	var lastErr error
	for _, candidate := range candidates {
		scriptRef, err := backendutil.ScriptRefFromBytes(refType, candidate, hashHex)
		if err == nil {
			return scriptRef, nil
		}
		lastErr = err
	}
	return nil, lastErr
}

// koiosNativeScript is the cardano-cli simple-script JSON form Koios returns
// for native scripts.
type koiosNativeScript struct {
	Type     string              `json:"type"`
	KeyHash  string              `json:"keyHash"`
	Slot     *uint64             `json:"slot"`
	Required *uint64             `json:"required"`
	Scripts  []koiosNativeScript `json:"scripts"`
}

// maxNativeScriptDepth bounds recursion over provider-supplied JSON.
const maxNativeScriptDepth = 64

// nativeScriptRefFromJSON encodes a native script from its JSON form and
// accepts it only if its hash matches hashHex.
func nativeScriptRefFromJSON(value json.RawMessage, hashHex string) (*common.ScriptRef, error) {
	var script koiosNativeScript
	if err := json.Unmarshal(value, &script); err != nil {
		return nil, fmt.Errorf("invalid native script JSON: %w", err)
	}
	if script.Type == "" {
		return nil, fmt.Errorf("koios returned neither bytes nor JSON for native script %s", hashHex)
	}
	encoded, err := script.toCBORValue(0)
	if err != nil {
		return nil, fmt.Errorf("invalid native script %s: %w", hashHex, err)
	}
	scriptCbor, err := cbor.Encode(encoded)
	if err != nil {
		return nil, fmt.Errorf("failed to encode native script %s: %w", hashHex, err)
	}
	return backendutil.ScriptRefFromBytes(common.ScriptRefTypeNativeScript, scriptCbor, hashHex)
}

// toCBORValue returns the ledger CBOR structure of a native script:
// [0, keyhash] | [1, [scripts]] | [2, [scripts]] | [3, n, [scripts]] |
// [4, slot] (valid from slot) | [5, slot] (valid before slot).
func (s *koiosNativeScript) toCBORValue(depth int) ([]any, error) {
	if depth > maxNativeScriptDepth {
		return nil, fmt.Errorf("nesting exceeds %d levels", maxNativeScriptDepth)
	}
	children := func() ([]any, error) {
		out := make([]any, 0, len(s.Scripts))
		for i := range s.Scripts {
			child, err := s.Scripts[i].toCBORValue(depth + 1)
			if err != nil {
				return nil, err
			}
			out = append(out, child)
		}
		return out, nil
	}
	slot := func() (uint64, error) {
		if s.Slot == nil {
			return 0, fmt.Errorf("%s script has no slot", s.Type)
		}
		return *s.Slot, nil
	}
	switch s.Type {
	case "sig":
		keyHash, err := hex.DecodeString(s.KeyHash)
		if err != nil || len(keyHash) != common.Blake2b224Size {
			return nil, fmt.Errorf("invalid key hash %q", s.KeyHash)
		}
		return []any{0, keyHash}, nil
	case "all", "any":
		scripts, err := children()
		if err != nil {
			return nil, err
		}
		tag := 1
		if s.Type == "any" {
			tag = 2
		}
		return []any{tag, scripts}, nil
	case "atLeast":
		if s.Required == nil {
			return nil, errors.New("atLeast script has no required count")
		}
		if *s.Required > uint64(len(s.Scripts)) {
			return nil, fmt.Errorf("atLeast requires %d of %d scripts", *s.Required, len(s.Scripts))
		}
		scripts, err := children()
		if err != nil {
			return nil, err
		}
		return []any{3, *s.Required, scripts}, nil
	case "after":
		v, err := slot()
		if err != nil {
			return nil, err
		}
		return []any{4, v}, nil
	case "before":
		v, err := slot()
		if err != nil {
			return nil, err
		}
		return []any{5, v}, nil
	default:
		return nil, fmt.Errorf("unsupported native script type %q", s.Type)
	}
}
