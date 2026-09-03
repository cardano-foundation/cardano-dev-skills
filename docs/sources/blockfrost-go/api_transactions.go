package blockfrost

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
)

const (
	resourceTxs               = "txs"
	resourceTx                = "tx"
	resourceTxStakes          = "stakes"
	resourceTxUTXOs           = "utxos"
	resourceTxWithdrawals     = "withdrawals"
	resourceTxMetadata        = "metadata"
	resourceTxRedeemers       = "redeemers"
	resourceTxRequiredSigners = "required_signers"
	resourceCbor              = "cbor"
	resourceTxDelegations     = "delegations"
	resourceTxPoolUpdates     = "pool_updates"
	resourceTxPoolRetires     = "pool_retires"
	resourceTxSubmit          = "submit"
	resourceTxEvaluate        = "utils/txs/evaluate"
	resourceTxEvaluateUtxos   = "utils/txs/evaluate/utxos"
)

type TransactionContent struct {
	// Count of asset mints and burns within the transaction
	AssetMintOrBurnCount int `json:"asset_mint_or_burn_count"`

	// Block hash
	Block string `json:"block"`

	// Block number
	BlockHeight int `json:"block_height"`

	// Block creation time
	BlockTime int `json:"block_time"`

	// Count of the delegations within the transaction
	DelegationCount int `json:"delegation_count"`

	// Deposit within the transaction in Lovelaces
	Deposit string `json:"deposit"`

	// Fees of the transaction in Lovelaces
	Fees string `json:"fees"`

	// Transaction hash
	Hash string `json:"hash"`

	// Transaction index within the block
	Index int `json:"index"`

	// Left (included) endpoint of the timelock validity intervals
	InvalidBefore *string `json:"invalid_before"`

	// Right (excluded) endpoint of the timelock validity intervals
	InvalidHereafter *string `json:"invalid_hereafter"`

	// Count of the MIR certificates within the transaction
	MirCertCount int `json:"mir_cert_count"`
	OutputAmount []struct {
		// The quantity of the unit
		Quantity string `json:"quantity"`

		// The unit of the value
		Unit string `json:"unit"`
	} `json:"output_amount"`

	// Count of the stake pool retirement certificates within the transaction
	PoolRetireCount int `json:"pool_retire_count"`

	// Count of the stake pool registration and update certificates within the transaction
	PoolUpdateCount int `json:"pool_update_count"`

	// Count of redeemers within the transaction
	RedeemerCount int `json:"redeemer_count"`

	// Size of the transaction in Bytes
	Size int `json:"size"`

	// Slot number
	Slot int `json:"slot"`

	// Count of the stake keys (de)registration and delegation certificates within the transaction
	StakeCertCount int `json:"stake_cert_count"`

	// Count of UTXOs within the transaction
	UtxoCount int `json:"utxo_count"`

	// Script passed validation
	ValidContract bool `json:"valid_contract"`

	// Count of the withdrawals within the transaction
	WithdrawalCount int `json:"withdrawal_count"`

	// Treasury donation amount in Lovelaces
	TreasuryDonation string `json:"treasury_donation"`
}

type TransactionCBOR struct {
	Cbor string `json:"cbor"`
}

type TxAmount struct {
	// The quantity of the unit
	Quantity string `json:"quantity"`

	// The unit of the value
	Unit string `json:"unit"`
}

type TransactionInput struct {
	Address             string     `json:"address"`
	Amount              []TxAmount `json:"amount"`
	OutputIndex         float32    `json:"output_index"`
	TxHash              string     `json:"tx_hash"`
	DataHash            *string    `json:"data_hash"`
	Collateral          bool       `json:"collateral"`
	InlineDatum         *string    `json:"inline_datum"`
	ReferenceScriptHash *string    `json:"reference_script_hash"`
	Reference           *bool      `json:"reference"`
}

type TransactionOutput struct {
	Address             string     `json:"address"`
	Amount              []TxAmount `json:"amount"`
	OutputIndex         int        `json:"output_index"`
	DataHash            *string    `json:"data_hash"`
	Collateral          bool       `json:"collateral"`
	InlineDatum         *string    `json:"inline_datum"`
	ReferenceScriptHash *string    `json:"reference_script_hash"`
	ConsumedByTx        *string    `json:"consumed_by_tx"`
}
type TransactionUTXOs struct {
	// Transaction hash
	Hash    string              `json:"hash"`
	Inputs  []TransactionInput  `json:"inputs"`
	Outputs []TransactionOutput `json:"outputs"`
}

type TransactionStakeAddressCert struct {
	// Delegation stake address
	Address string `json:"address"`

	// Index of the certificate within the transaction
	CertIndex int `json:"cert_index"`

	// Registration boolean, false if deregistration
	Registration bool `json:"registration"`
}

type TransactionDelegation struct {
	// Epoch in which the delegation becomes active
	ActiveEpoch int `json:"active_epoch"`

	// Bech32 delegation stake address
	Address string `json:"address"`

	// Index of the certificate within the transaction
	CertIndex int `json:"cert_index"`

	// Index of the certificate within the transaction
	Index int `json:"index"`

	// Bech32 ID of delegated stake pool
	PoolId string `json:"pool_id"`
}

type TransactionWidthrawal struct {
	// Bech32 withdrawal address
	Address string `json:"address"`

	// Withdrawal amount in Lovelaces
	Amount string `json:"amount"`
}

type TransactionMIR struct {
	// Bech32 stake address
	Address string `json:"address"`

	// MIR amount in Lovelaces
	Amount string `json:"amount"`

	// Index of the certificate within the transaction
	CertIndex int `json:"cert_index"`

	// Source of MIR funds
	Pot string `json:"pot"`
}

type TransactionPoolCert struct {
	// Epoch that the delegation becomes active
	ActiveEpoch int `json:"active_epoch"`

	// Index of the certificate within the transaction
	CertIndex int `json:"cert_index"`

	// Fixed tax cost of the stake pool in Lovelaces
	FixedCost string `json:"fixed_cost"`

	// Margin tax cost of the stake pool
	MarginCost float32 `json:"margin_cost"`
	Metadata   *struct {
		// Description of the stake pool
		Description string `json:"description"`

		// Hash of the metadata file
		Hash string `json:"hash"`

		// Home page of the stake pool
		Homepage string `json:"homepage"`

		// Name of the stake pool
		Name string `json:"name"`

		// Ticker of the stake pool
		Ticker string `json:"ticker"`

		// URL to the stake pool metadata
		Url string `json:"url"`
	} `json:"metadata"`
	Owners []string `json:"owners"`

	// Stake pool certificate pledge in Lovelaces
	Pledge string `json:"pledge"`

	// Bech32 encoded pool ID
	PoolId string `json:"pool_id"`
	Relays []struct {
		// DNS name of the relay
		Dns string `json:"dns"`

		// DNS SRV entry of the relay
		DnsSrv string `json:"dns_srv"`

		// IPv4 address of the relay
		Ipv4 string `json:"ipv4"`

		// IPv6 address of the relay
		Ipv6 string `json:"ipv6"`

		// Network port of the relay
		Port int `json:"port"`
	} `json:"relays"`

	// Bech32 reward account of the stake pool
	RewardAccount string `json:"reward_account"`

	// VRF key hash
	VrfKey string `json:"vrf_key"`
}

type TransactionPoolRetires struct {
	// Index of the certificate within the transaction
	CertIndex int `json:"cert_index"`

	// Bech32 stake pool ID
	PoolId string `json:"pool_id"`

	// Retiring epoch
	RetiringEpoch int `json:"retiring_epoch"`
}

type TransactionMetadata struct {
	// Content of the metadata
	JsonMetadata interface{} `json:"json_metadata"`

	// Metadata label
	Label string `json:"label"`
}

type TransactionMetadataCbor struct {
	// Deprecated: Use Metadata instead.
	CborMetadata *string `json:"cbor_metadata"`
	// Content of the CBOR metadata
	Metadata string `json:"metadata"`

	// Metadata label
	Label string `json:"label"`
}

type TransactionRedeemer struct {
	TxIndex          int    `json:"tx_index"`
	Purpose          string `json:"purpose"`
	ScriptHash       string `json:"script_hash"`
	RedeemerDataHash string `json:"redeemer_data_hash"`
	UnitMem          string `json:"unit_mem"`
	UnitSteps        string `json:"unit_steps"`
	Fee              string `json:"fee"`
}

type TransactionRequiredSigner struct {
	WitnessHash string `json:"witness_hash"`
}

type Quantity string

// MarshalJSON marshals Quantity as a JSON number (without quotes).
// The API expects numeric values for coins/assets in request payloads
// like additionalUtxoSet, even though responses return them as strings.
func (q Quantity) MarshalJSON() ([]byte, error) {
	s := string(q)
	if s == "" {
		return []byte("0"), nil
	}
	// Validate it's a proper integer to avoid injection
	for _, c := range s {
		if c < '0' || c > '9' {
			return nil, fmt.Errorf("invalid quantity: non-digit character in %q", s)
		}
	}
	// Reject leading zeros (invalid JSON number), except for "0" itself
	if len(s) > 1 && s[0] == '0' {
		return nil, fmt.Errorf("invalid quantity: leading zeros in %q", s)
	}
	return []byte(s), nil
}

// UnmarshalJSON unmarshals Quantity from both JSON numbers and JSON strings.
func (q *Quantity) UnmarshalJSON(data []byte) error {
	if len(data) == 0 {
		return fmt.Errorf("unexpected end of JSON input")
	}
	// JSON string (quoted)
	if data[0] == '"' {
		var s string
		if err := json.Unmarshal(data, &s); err != nil {
			return err
		}
		*q = Quantity(s)
		return nil
	}
	// JSON number (unquoted) or null
	if string(data) == "null" {
		*q = ""
		return nil
	}
	*q = Quantity(data)
	return nil
}

type Value struct {
	Coins  Quantity            `json:"coins"`
	Assets map[string]Quantity `json:"assets,omitempty"`
}

type TxOutScript interface{}

type AdditionalUtxoSetTxIn struct {
	TxID  string `json:"txId"`
	Index int    `json:"index"`
}

type AdditionalUtxoSetTxOut struct {
	Address   string       `json:"address"`
	Value     Value        `json:"value"`
	DatumHash *string      `json:"datum_hash,omitempty"`
	Datum     interface{}  `json:"datum,omitempty"` // Could be various types
	Script    *TxOutScript `json:"script,omitempty"`
}

// AdditionalUtxoSet represents a slice of tuples (TxIn, TxOut)
type AdditionalUtxoSet []struct {
	TxIn  AdditionalUtxoSetTxIn  `json:"txIn"`
	TxOut AdditionalUtxoSetTxOut `json:"txOut"`
}

type OgmiosResponse struct {
	Type        string `json:"type"`
	Version     string `json:"version"`
	ServiceName string `json:"servicename"`
	MethodName  string `json:"methodname"`
	Reflection  struct {
		Id string `json:"id"`
	} `json:"reflection"`
	Result json.RawMessage `json:"result"`
}

func (c *apiClient) Transaction(ctx context.Context, hash string) (tc TransactionContent, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s", c.server, resourceTxs, hash))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&tc); err != nil {
		return
	}
	return tc, nil
}

func (c *apiClient) TransactionCBOR(ctx context.Context, hash string) (tc TransactionCBOR, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceTxs, hash, resourceCbor))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&tc); err != nil {
		return
	}
	return tc, nil
}

func (c *apiClient) TransactionUTXOs(ctx context.Context, hash string) (tu TransactionUTXOs, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceTxs, hash, resourceTxUTXOs))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&tu); err != nil {
		return
	}
	return tu, nil
}

func (c *apiClient) TransactionStakeAddressCerts(ctx context.Context, hash string) (tc []TransactionStakeAddressCert, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceTxs, hash, resourceTxStakes))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&tc); err != nil {
		return
	}
	return tc, nil
}

func (c *apiClient) TransactionWithdrawals(ctx context.Context, hash string) (tw []TransactionWidthrawal, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceTxs, hash, resourceTxWithdrawals))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&tw); err != nil {
		return
	}
	return tw, nil
}

func (c *apiClient) TransactionMIRs(ctx context.Context, hash string) (tw []TransactionMIR, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceTxs, hash, resourceTxWithdrawals))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&tw); err != nil {
		return
	}
	return tw, nil
}

func (c *apiClient) TransactionMetadata(ctx context.Context, hash string) (tm []TransactionMetadata, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceTxs, hash, resourceTxMetadata))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&tm); err != nil {
		return
	}
	return tm, nil
}

func (c *apiClient) TransactionMetadataInCBORs(ctx context.Context, hash string) (tmc []TransactionMetadataCbor, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s/%s", c.server, resourceTxs, hash, resourceTxMetadata, resourceCbor))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&tmc); err != nil {
		return
	}
	return tmc, nil
}

func (c *apiClient) TransactionRedeemers(ctx context.Context, hash string) (tm []TransactionRedeemer, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceTxs, hash, resourceTxRedeemers))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&tm); err != nil {
		return
	}
	return tm, nil
}

func (c *apiClient) TransactionDelegationCerts(ctx context.Context, hash string) (td []TransactionDelegation, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceTxs, hash, resourceTxDelegations))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&td); err != nil {
		return
	}
	return td, nil
}

func (c *apiClient) TransactionPoolUpdates(ctx context.Context, hash string) (td []TransactionPoolCert, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceTxs, hash, resourceTxPoolUpdates))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&td); err != nil {
		return
	}
	return td, nil
}

func (c *apiClient) TransactionPoolUpdateCerts(ctx context.Context, hash string) (tcs []TransactionPoolCert, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceTxs, hash, resourceTxPoolUpdates))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&tcs); err != nil {
		return
	}
	return tcs, nil
}

func (c *apiClient) TransactionPoolRetirementCerts(ctx context.Context, hash string) (tcs []TransactionPoolRetires, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceTxs, hash, resourceTxPoolRetires))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&tcs); err != nil {
		return
	}
	return tcs, nil
}

func (c *apiClient) TransactionRequiredSigners(ctx context.Context, hash string) (tm []TransactionRequiredSigner, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceTxs, hash, resourceTxRequiredSigners))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&tm); err != nil {
		return
	}
	return tm, nil
}

func (c *apiClient) TransactionSubmit(ctx context.Context, cbor []byte) (hash string, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s", c.server, resourceTx, resourceTxSubmit))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, requestUrl.String(), bytes.NewReader(cbor))
	if err != nil {
		return
	}
	req.Header.Add("Content-Type", "application/cbor")
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&hash); err != nil {
		return
	}
	return hash, nil
}

func (c *apiClient) TransactionEvaluate(ctx context.Context, cbor []byte) (jsonResponse OgmiosResponse, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourceTxEvaluate))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, requestUrl.String(), bytes.NewReader(cbor))
	if err != nil {
		return
	}
	req.Header.Add("Content-Type", "application/cbor")
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}

	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&jsonResponse); err != nil {
		return
	}
	return jsonResponse, nil
}

func (c *apiClient) TransactionEvaluateUTXOs(ctx context.Context, cbor []byte, additionalUtxoSet AdditionalUtxoSet) (jsonResponse OgmiosResponse, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourceTxEvaluateUtxos))
	if err != nil {
		return
	}

	// Convert addition utxo set from custom go data type (array of struct with TxIn, TxOut properties) to
	// format required by the API endpoint ([[TxIn, TxOut], ...])
	convertedAdditionalUtxoSet := make([][]interface{}, len(additionalUtxoSet))
	for i, utxo := range additionalUtxoSet {
		convertedAdditionalUtxoSet[i] = []interface{}{utxo.TxIn, utxo.TxOut}
	}

	payload := struct {
		Cbor              string          `json:"cbor"`
		AdditionalUtxoSet [][]interface{} `json:"additionalUtxoSet"`
	}{
		Cbor:              string(cbor),
		AdditionalUtxoSet: convertedAdditionalUtxoSet,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, requestUrl.String(), bytes.NewBuffer(jsonData))
	if err != nil {
		return
	}
	req.Header.Add("Content-Type", "application/json")
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()
	if err = json.NewDecoder(res.Body).Decode(&jsonResponse); err != nil {
		return
	}

	return jsonResponse, nil
}
