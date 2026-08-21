package utxorpc

import (
	"context"
	"encoding/hex"
	"errors"
	"fmt"
	"math"
	"math/big"
	"sort"
	"strconv"
	"strings"
	"sync"

	"connectrpc.com/connect"
	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/babbage"
	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/gouroboros/ledger/conway"
	"github.com/blinklabs-io/gouroboros/ledger/shelley"
	alphacardano "github.com/utxorpc/go-codegen/utxorpc/v1alpha/cardano"
	alphaquery "github.com/utxorpc/go-codegen/utxorpc/v1alpha/query"
	alphasubmit "github.com/utxorpc/go-codegen/utxorpc/v1alpha/submit"
	alphasync "github.com/utxorpc/go-codegen/utxorpc/v1alpha/sync"
	cardano "github.com/utxorpc/go-codegen/utxorpc/v1beta/cardano"
	query "github.com/utxorpc/go-codegen/utxorpc/v1beta/query"
	submit "github.com/utxorpc/go-codegen/utxorpc/v1beta/submit"
	syncpb "github.com/utxorpc/go-codegen/utxorpc/v1beta/sync"
	sdk "github.com/utxorpc/go-sdk"
	alphasdk "github.com/utxorpc/go-sdk/v1alpha"

	"github.com/Salvionied/apollo/v2/backend"
	"github.com/Salvionied/apollo/v2/internal/backendutil"
)

// UtxoRpcChainContext implements backend.ChainContext using the UTxO RPC protocol.
//
// Requests are made against utxorpc.v1beta. If a server reports that service
// unimplemented, the context falls back to utxorpc.v1alpha and remembers the
// choice, so servers that expose only the older services keep working without
// any configuration. Dolos serves both on the same port.
type UtxoRpcChainContext struct {
	client      *sdk.UtxorpcClient
	alphaClient *alphasdk.UtxorpcClient
	networkId   uint8

	versionMu sync.Mutex
	version   protoVersion
}

var _ backend.ContextChainContext = (*UtxoRpcChainContext)(nil)

// Capabilities reports the UTxO RPC operations supported by this client.
func (u *UtxoRpcChainContext) Capabilities() backend.CapabilitySet {
	return backend.CapabilitySet(backend.AllCapabilities) &^
		backend.CapabilitySet(backend.CapabilityGenesisParams|backend.CapabilityCurrentEpoch|
			backend.CapabilityEvaluateTxAdditionalUtxos|backend.CapabilityScriptCbor)
}

// EvaluationError reports deterministic Cardano transaction-evaluation errors
// returned by the UTxO RPC provider.
type EvaluationError struct {
	Messages []string
}

func (e *EvaluationError) Error() string {
	return strings.Join(e.Messages, "; ")
}

// NewUtxoRpcChainContext creates a new UTxO RPC chain context.
func NewUtxoRpcChainContext(baseUrl string, networkId uint8, headers map[string]string) *UtxoRpcChainContext {
	opts := []sdk.ClientOption{
		sdk.WithBaseUrl(baseUrl),
	}
	if len(headers) > 0 {
		opts = append(opts, sdk.WithHeaders(headers))
	}
	client := sdk.NewClient(opts...)
	// Both clients are built up front because neither constructor performs
	// network I/O; only the one that ends up negotiated is ever used.
	alphaOpts := []alphasdk.ClientOption{
		alphasdk.WithBaseUrl(baseUrl),
	}
	if len(headers) > 0 {
		alphaOpts = append(alphaOpts, alphasdk.WithHeaders(headers))
	}
	return &UtxoRpcChainContext{
		client:      client,
		alphaClient: alphasdk.NewClient(alphaOpts...),
		networkId:   networkId,
	}
}

func bigIntToInt64(bi *cardano.BigInt) int64 {
	if bi == nil {
		return 0
	}
	oneof := bi.GetBigInt()
	if oneof == nil {
		return 0
	}
	switch v := oneof.(type) {
	case *cardano.BigInt_Int:
		if v == nil {
			return 0
		}
		return v.Int
	case *cardano.BigInt_BigUInt:
		if v == nil {
			return 0
		}
		n := new(big.Int).SetBytes(v.BigUInt)
		if !n.IsInt64() {
			return math.MaxInt64
		}
		return n.Int64()
	case *cardano.BigInt_BigNInt:
		if v == nil {
			return 0
		}
		n := new(big.Int).SetBytes(v.BigNInt)
		n.Neg(n)
		if !n.IsInt64() {
			return math.MinInt64
		}
		return n.Int64()
	default:
		return 0
	}
}

func bigIntToString(bi *cardano.BigInt) string {
	if bi == nil {
		return "0"
	}
	oneof := bi.GetBigInt()
	if oneof == nil {
		return "0"
	}
	switch v := oneof.(type) {
	case *cardano.BigInt_Int:
		if v == nil {
			return "0"
		}
		return strconv.FormatInt(v.Int, 10)
	case *cardano.BigInt_BigUInt:
		if v == nil {
			return "0"
		}
		return new(big.Int).SetBytes(v.BigUInt).String()
	case *cardano.BigInt_BigNInt:
		if v == nil {
			return "0"
		}
		n := new(big.Int).SetBytes(v.BigNInt)
		n.Neg(n)
		return n.String()
	default:
		return "0"
	}
}

func (u *UtxoRpcChainContext) ProtocolParams() (backend.ProtocolParameters, error) {
	return u.ProtocolParamsContext(context.Background())
}

func (u *UtxoRpcChainContext) ProtocolParamsContext(ctx context.Context) (backend.ProtocolParameters, error) {
	msg, err := callWithVersionFallback(ctx, u,
		func(ctx context.Context) (*query.ReadParamsResponse, error) {
			req := connect.NewRequest(&query.ReadParamsRequest{})
			u.client.AddHeadersToRequest(req)
			resp, err := u.client.ReadParamsWithContext(ctx, req)
			if err != nil {
				return nil, err
			}
			return resp.Msg, nil
		},
		func(ctx context.Context) (*query.ReadParamsResponse, error) {
			req := connect.NewRequest(&alphaquery.ReadParamsRequest{})
			u.alphaClient.AddHeadersToRequest(req)
			resp, err := u.alphaClient.ReadParamsWithContext(ctx, req)
			if err != nil {
				return nil, err
			}
			return transcodeTo(resp.Msg, &query.ReadParamsResponse{})
		},
	)
	if err != nil {
		return backend.ProtocolParameters{}, err
	}

	params := msg.GetValues().GetCardano()
	if params == nil {
		return backend.ProtocolParameters{}, errors.New("no cardano params in response")
	}

	maxBlockSize, err := backendutil.BoundedIntFromUint64(params.GetMaxBlockBodySize(), "max block body size")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	maxTxSize, err := backendutil.BoundedIntFromUint64(params.GetMaxTxSize(), "max tx size")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	maxBlockHeaderSize, err := backendutil.BoundedIntFromUint64(params.GetMaxBlockHeaderSize(), "max block header size")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	collateralPercent, err := backendutil.BoundedIntFromUint64(params.GetCollateralPercentage(), "collateral percentage")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}
	maxCollateralInputs, err := backendutil.BoundedIntFromUint64(params.GetMaxCollateralInputs(), "max collateral inputs")
	if err != nil {
		return backend.ProtocolParameters{}, err
	}

	pp := backend.ProtocolParameters{
		MinFeeCoefficient:   bigIntToInt64(params.GetMinFeeCoefficient()),
		MinFeeConstant:      bigIntToInt64(params.GetMinFeeConstant()),
		MaxBlockSize:        maxBlockSize,
		MaxTxSize:           maxTxSize,
		MaxBlockHeaderSize:  maxBlockHeaderSize,
		CoinsPerUtxoByte:    bigIntToString(params.GetCoinsPerUtxoByte()),
		MaxValSize:          strconv.FormatUint(params.GetMaxValueSize(), 10),
		CollateralPercent:   collateralPercent,
		MaxCollateralInputs: maxCollateralInputs,
		KeyDeposits:         bigIntToString(params.GetStakeKeyDeposit()),
		PoolDeposits:        bigIntToString(params.GetPoolDeposit()),
	}

	if txEx := params.GetMaxExecutionUnitsPerTransaction(); txEx != nil {
		pp.MaxTxExMem = strconv.FormatUint(txEx.GetMemory(), 10)
		pp.MaxTxExSteps = strconv.FormatUint(txEx.GetSteps(), 10)
	}
	if blockEx := params.GetMaxExecutionUnitsPerBlock(); blockEx != nil {
		pp.MaxBlockExMem = strconv.FormatUint(blockEx.GetMemory(), 10)
		pp.MaxBlockExSteps = strconv.FormatUint(blockEx.GetSteps(), 10)
	}

	prices := params.GetPrices()
	if prices != nil {
		if prices.GetMemory() != nil && prices.GetMemory().GetDenominator() != 0 {
			pp.PriceMem = float64(prices.GetMemory().GetNumerator()) / float64(prices.GetMemory().GetDenominator())
		}
		if prices.GetSteps() != nil && prices.GetSteps().GetDenominator() != 0 {
			pp.PriceStep = float64(prices.GetSteps().GetNumerator()) / float64(prices.GetSteps().GetDenominator())
		}
	}

	// Conway reference-script base price (lovelace per byte for the first tier),
	// exposed as a rational number.
	setReferenceScriptFeePrice(&pp, params.GetMinFeeScriptRefCostPerByte())

	pp.CostModels = costModelsFromRpc(params.GetCostModels())

	return pp, nil
}

func setReferenceScriptFeePrice(pp *backend.ProtocolParameters, price *cardano.RationalNumber) {
	if price == nil || price.GetDenominator() == 0 {
		return
	}
	rational := new(big.Rat).SetFrac(
		big.NewInt(int64(price.GetNumerator())),
		new(big.Int).SetUint64(uint64(price.GetDenominator())),
	)
	pp.MinFeeRefScriptCostPerByteRational = rational
	pp.MinFeeRefScriptCostPerByte, _ = rational.Float64()
}

// costModelsFromRpc translates UTxO RPC cost models to the canonical names
// expected by ComputeScriptDataHash.
func costModelsFromRpc(cm *cardano.CostModels) map[string][]int64 {
	if cm == nil {
		return nil
	}
	models := make(map[string][]int64)
	if v1 := cm.GetPlutusV1(); v1 != nil {
		models["PlutusV1"] = append([]int64(nil), v1.GetValues()...)
	}
	if v2 := cm.GetPlutusV2(); v2 != nil {
		models["PlutusV2"] = append([]int64(nil), v2.GetValues()...)
	}
	if v3 := cm.GetPlutusV3(); v3 != nil {
		models["PlutusV3"] = append([]int64(nil), v3.GetValues()...)
	}
	if v4 := cm.GetPlutusV4(); v4 != nil {
		models["PlutusV4"] = append([]int64(nil), v4.GetValues()...)
	}
	return models
}

func (u *UtxoRpcChainContext) GenesisParams() (backend.GenesisParameters, error) {
	return u.GenesisParamsContext(context.Background())
}

func (u *UtxoRpcChainContext) GenesisParamsContext(ctx context.Context) (backend.GenesisParameters, error) {
	if err := ctx.Err(); err != nil {
		return backend.GenesisParameters{}, err
	}
	return backend.GenesisParameters{}, backend.NewUnsupportedError("UTxO RPC", backend.CapabilityGenesisParams)
}

func (u *UtxoRpcChainContext) NetworkId() uint8 {
	return u.networkId
}

func (u *UtxoRpcChainContext) CurrentEpoch() (uint64, error) {
	return u.CurrentEpochContext(context.Background())
}

func (u *UtxoRpcChainContext) CurrentEpochContext(ctx context.Context) (uint64, error) {
	if err := ctx.Err(); err != nil {
		return 0, err
	}
	return 0, backend.NewUnsupportedError("UTxO RPC", backend.CapabilityCurrentEpoch)
}

func (u *UtxoRpcChainContext) MaxTxFee() (uint64, error) {
	return u.MaxTxFeeContext(context.Background())
}

func (u *UtxoRpcChainContext) MaxTxFeeContext(ctx context.Context) (uint64, error) {
	pp, err := u.ProtocolParamsContext(ctx)
	if err != nil {
		return 0, err
	}
	return backend.ComputeMaxTxFee(pp)
}

func (u *UtxoRpcChainContext) Tip() (uint64, error) {
	return u.TipContext(context.Background())
}

func (u *UtxoRpcChainContext) TipContext(ctx context.Context) (uint64, error) {
	msg, err := callWithVersionFallback(ctx, u,
		func(ctx context.Context) (*syncpb.ReadTipResponse, error) {
			req := connect.NewRequest(&syncpb.ReadTipRequest{})
			u.client.AddHeadersToRequest(req)
			resp, err := u.client.ReadTipWithContext(ctx, req)
			if err != nil {
				return nil, err
			}
			return resp.Msg, nil
		},
		func(ctx context.Context) (*syncpb.ReadTipResponse, error) {
			req := connect.NewRequest(&alphasync.ReadTipRequest{})
			u.alphaClient.AddHeadersToRequest(req)
			resp, err := u.alphaClient.ReadTipWithContext(ctx, req)
			if err != nil {
				return nil, err
			}
			return transcodeTo(resp.Msg, &syncpb.ReadTipResponse{})
		},
	)
	if err != nil {
		return 0, err
	}
	tip := msg.GetTip()
	if tip == nil {
		return 0, errors.New("no tip in response")
	}
	return tip.GetSlot(), nil
}

func (u *UtxoRpcChainContext) Utxos(address common.Address) ([]common.Utxo, error) {
	return u.UtxosContext(context.Background(), address)
}

func (u *UtxoRpcChainContext) UtxosContext(ctx context.Context, address common.Address) ([]common.Utxo, error) {
	addrBytes, err := address.Bytes()
	if err != nil {
		return nil, fmt.Errorf("failed to get address bytes: %w", err)
	}

	var utxos []common.Utxo
	seenTokens := make(map[string]struct{})
	const maxPages = 10_000
	var startToken string
	for page := 0; page < maxPages; page++ {
		page, err := u.searchUtxosPage(ctx, addrBytes, startToken)
		if err != nil {
			if startToken == "" {
				return nil, err
			}
			return nil, fmt.Errorf(
				"failed to fetch UTxO RPC page after token %q: %w",
				startToken,
				err,
			)
		}
		utxos = append(utxos, page.utxos...)
		next := page.nextToken
		if next == "" {
			return utxos, nil
		}
		if _, seen := seenTokens[next]; seen {
			return nil, fmt.Errorf("UTxO RPC pagination repeated token %q", next)
		}
		seenTokens[next] = struct{}{}
		startToken = next
	}
	return nil, fmt.Errorf("UTxO RPC pagination exceeded %d pages", maxPages)
}

// utxoPage is one page of a UTxO search, already converted to Apollo's types.
type utxoPage struct {
	utxos     []common.Utxo
	nextToken string
}

// searchUtxosPage fetches one page of UTxOs for an address. An empty startToken
// requests the first page.
//
// Each version converts its own response rather than reprojecting one onto the
// other. Apollo reads only native_bytes and txo_ref, which both versions
// declare identically, so this costs no duplicated logic -- the conversion
// lives once in utxoFromParts -- and it avoids a marshal/unmarshal round trip
// per page as well as any dependence on the parsed Cardano value structures
// agreeing between versions.
//
// v1beta declares start_token as proto3 optional so it takes a pointer, while
// v1alpha declares it as a plain string. GetNextToken() returns a string in
// both and yields "" for an absent token, so the caller's termination check is
// the same either way.
func (u *UtxoRpcChainContext) searchUtxosPage(
	ctx context.Context,
	addrBytes []byte,
	startToken string,
) (utxoPage, error) {
	return callWithVersionFallback(ctx, u,
		func(ctx context.Context) (utxoPage, error) {
			req := connect.NewRequest(&query.SearchUtxosRequest{
				Predicate: &query.UtxoPredicate{
					Match: &query.AnyUtxoPattern{
						UtxoPattern: &query.AnyUtxoPattern_Cardano{
							Cardano: &cardano.TxOutputPattern{
								Address: &cardano.AddressPattern{
									ExactAddress: addrBytes,
								},
							},
						},
					},
				},
			})
			if startToken != "" {
				req.Msg.StartToken = &startToken
			}
			u.client.AddHeadersToRequest(req)
			resp, err := u.client.SearchUtxosWithContext(ctx, req)
			if err != nil {
				return utxoPage{}, err
			}
			page := utxoPage{nextToken: resp.Msg.GetNextToken()}
			for _, item := range resp.Msg.GetItems() {
				utxo, err := utxoFromRpc(item)
				if err != nil {
					return utxoPage{}, err
				}
				page.utxos = append(page.utxos, utxo)
			}
			return page, nil
		},
		func(ctx context.Context) (utxoPage, error) {
			req := connect.NewRequest(&alphaquery.SearchUtxosRequest{
				Predicate: &alphaquery.UtxoPredicate{
					Match: &alphaquery.AnyUtxoPattern{
						UtxoPattern: &alphaquery.AnyUtxoPattern_Cardano{
							Cardano: &alphacardano.TxOutputPattern{
								Address: &alphacardano.AddressPattern{
									ExactAddress: addrBytes,
								},
							},
						},
					},
				},
				StartToken: startToken,
			})
			u.alphaClient.AddHeadersToRequest(req)
			resp, err := u.alphaClient.SearchUtxosWithContext(ctx, req)
			if err != nil {
				return utxoPage{}, err
			}
			page := utxoPage{nextToken: resp.Msg.GetNextToken()}
			for _, item := range resp.Msg.GetItems() {
				utxo, err := utxoFromRpcAlpha(item)
				if err != nil {
					return utxoPage{}, err
				}
				page.utxos = append(page.utxos, utxo)
			}
			return page, nil
		},
	)
}

func (u *UtxoRpcChainContext) SubmitTx(txCbor []byte) (common.Blake2b256, error) {
	return u.SubmitTxContext(context.Background(), txCbor)
}

func (u *UtxoRpcChainContext) SubmitTxContext(ctx context.Context, txCbor []byte) (common.Blake2b256, error) {
	msg, err := callWithVersionFallback(ctx, u,
		func(ctx context.Context) (*submit.SubmitTxResponse, error) {
			req := connect.NewRequest(&submit.SubmitTxRequest{
				Tx: &submit.AnyChainTx{
					Type: &submit.AnyChainTx_Raw{Raw: txCbor},
				},
			})
			u.client.AddHeadersToRequest(req)
			resp, err := u.client.SubmitTxWithContext(ctx, req)
			if err != nil {
				return nil, err
			}
			return resp.Msg, nil
		},
		func(ctx context.Context) (*submit.SubmitTxResponse, error) {
			req := connect.NewRequest(&alphasubmit.SubmitTxRequest{
				Tx: &alphasubmit.AnyChainTx{
					Type: &alphasubmit.AnyChainTx_Raw{Raw: txCbor},
				},
			})
			u.alphaClient.AddHeadersToRequest(req)
			resp, err := u.alphaClient.SubmitTxWithContext(ctx, req)
			if err != nil {
				return nil, err
			}
			return transcodeTo(resp.Msg, &submit.SubmitTxResponse{})
		},
	)
	if err != nil {
		return common.Blake2b256{}, err
	}
	ref := msg.GetRef()
	if len(ref) == 0 {
		return common.Blake2b256{}, errors.New("no tx ref in submit response")
	}
	if len(ref) != common.Blake2b256Size {
		return common.Blake2b256{}, fmt.Errorf("invalid tx ref length: expected %d bytes, got %d", common.Blake2b256Size, len(ref))
	}
	var result common.Blake2b256
	copy(result[:], ref)
	return result, nil
}

// EvaluateTx evaluates the scripts in a transaction. UTxO RPC has no wire
// field for additional/resolved UTxOs, so off-chain or chained inputs cannot
// be evaluated by this backend.
func (u *UtxoRpcChainContext) EvaluateTx(txCbor []byte, additionalUtxos []common.Utxo) (map[common.RedeemerKey]common.ExUnits, error) {
	return u.EvaluateTxContext(context.Background(), txCbor, additionalUtxos)
}

func (u *UtxoRpcChainContext) EvaluateTxContext(
	ctx context.Context,
	txCbor []byte,
	additionalUtxos []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if len(additionalUtxos) > 0 {
		return nil, backend.NewUnsupportedError("UTxO RPC", backend.CapabilityEvaluateTxAdditionalUtxos)
	}
	expected, err := expectedRedeemerKeys(txCbor)
	if err != nil {
		return nil, err
	}
	msg, err := callWithVersionFallback(ctx, u,
		func(ctx context.Context) (*submit.EvalTxResponse, error) {
			req := connect.NewRequest(&submit.EvalTxRequest{
				Tx: &submit.AnyChainTx{
					Type: &submit.AnyChainTx_Raw{Raw: txCbor},
				},
			})
			u.client.AddHeadersToRequest(req)
			resp, err := u.client.EvalTxWithContext(ctx, req)
			if err != nil {
				return nil, err
			}
			return resp.Msg, nil
		},
		func(ctx context.Context) (*submit.EvalTxResponse, error) {
			req := connect.NewRequest(&alphasubmit.EvalTxRequest{
				Tx: &alphasubmit.AnyChainTx{
					Type: &alphasubmit.AnyChainTx_Raw{Raw: txCbor},
				},
			})
			u.alphaClient.AddHeadersToRequest(req)
			resp, err := u.alphaClient.EvalTxWithContext(ctx, req)
			if err != nil {
				return nil, err
			}
			return transcodeTo(resp.Msg, &submit.EvalTxResponse{})
		},
	)
	if err != nil {
		return nil, fmt.Errorf("evaluate transaction: %w", err)
	}
	return evalTxResponseToExpectedExUnits(msg, expected)
}

// evalTxResponseToExUnits converts an EvalTxResponse into a redeemer ExUnits
// map. A missing report, missing cardano report, or zero evaluation results
// is an error: returning an empty map with a nil error would let callers
// silently keep zero execution budgets for their redeemers.
func evalTxResponseToExUnits(msg *submit.EvalTxResponse) (map[common.RedeemerKey]common.ExUnits, error) {
	return parseEvalTxResponse(msg, utxorpcPurposeToRedeemerTag)
}

func evalTxResponseToExpectedExUnits(
	msg *submit.EvalTxResponse,
	expected map[common.RedeemerKey]struct{},
) (map[common.RedeemerKey]common.ExUnits, error) {
	standard, standardErr := parseEvalTxResponse(msg, utxorpcPurposeToRedeemerTag)
	var evaluationErr *EvaluationError
	if errors.As(standardErr, &evaluationErr) {
		return nil, standardErr
	}
	fallback, fallbackErr := parseEvalTxResponse(msg, utxorpcZeroBasedPurposeToRedeemerTag)

	standardMatches := standardErr == nil && sameRedeemerKeySet(standard, expected)
	fallbackMatches := fallbackErr == nil && sameRedeemerKeySet(fallback, expected)
	switch {
	case standardMatches && fallbackMatches:
		if !sameRedeemerKeySet(standard, redeemerKeySet(fallback)) {
			return nil, fmt.Errorf(
				"ambiguous redeemer purpose encoding: expected keys %s; standard observed keys %s; zero-based observed keys %s",
				formatRedeemerKeys(redeemerKeySet(expected)),
				formatRedeemerKeys(redeemerKeySet(standard)),
				formatRedeemerKeys(redeemerKeySet(fallback)),
			)
		}
		return standard, nil
	case standardMatches:
		return standard, nil
	case fallbackMatches:
		return fallback, nil
	default:
		return nil, fmt.Errorf(
			"redeemer purpose encoding does not match transaction: expected keys %s; standard observed keys %s (%v); zero-based observed keys %s (%v)",
			formatRedeemerKeys(redeemerKeySet(expected)),
			formatRedeemerKeys(redeemerKeySet(standard)),
			standardErr,
			formatRedeemerKeys(redeemerKeySet(fallback)),
			fallbackErr,
		)
	}
}

func expectedRedeemerKeys(txCbor []byte) (map[common.RedeemerKey]struct{}, error) {
	var tx conway.ConwayTransaction
	if _, err := cbor.Decode(txCbor, &tx); err != nil {
		return nil, fmt.Errorf("failed to decode submitted transaction: %w", err)
	}
	expected := make(map[common.RedeemerKey]struct{}, len(tx.WitnessSet.WsRedeemers.Redeemers))
	for key := range tx.WitnessSet.WsRedeemers.Redeemers {
		expected[key] = struct{}{}
	}
	return expected, nil
}

func parseEvalTxResponse(
	msg *submit.EvalTxResponse,
	mapPurpose func(cardano.RedeemerPurpose) (common.RedeemerTag, error),
) (map[common.RedeemerKey]common.ExUnits, error) {
	if msg == nil {
		return nil, errors.New("empty evaluate response")
	}
	report := msg.GetReport()
	if report == nil {
		return nil, errors.New("no evaluation report in response")
	}
	cardanoReport := report.GetCardano()
	if cardanoReport == nil {
		return nil, errors.New("no cardano evaluation report in response")
	}
	if responseErrors := cardanoReport.GetErrors(); len(responseErrors) > 0 {
		messages := make([]string, 0, len(responseErrors))
		for _, responseError := range responseErrors {
			message := strings.TrimSpace(responseError.GetMsg())
			if message != "" {
				messages = append(messages, message)
			}
		}
		if len(messages) == 0 {
			messages = []string{"script evaluation failed without an error message"}
		}
		return nil, &EvaluationError{Messages: messages}
	}
	result := make(map[common.RedeemerKey]common.ExUnits)
	for _, redeemer := range cardanoReport.GetRedeemers() {
		tag, err := mapPurpose(redeemer.GetPurpose())
		if err != nil {
			return result, fmt.Errorf("failed to map redeemer purpose: %w", err)
		}
		key := common.RedeemerKey{
			Tag:   tag,
			Index: redeemer.GetIndex(),
		}
		if _, exists := result[key]; exists {
			return result, fmt.Errorf("duplicate evaluation report for redeemer %d:%d", tag, redeemer.GetIndex())
		}
		eu := redeemer.GetExUnits()
		if eu == nil {
			return result, fmt.Errorf("no ExUnits in evaluation report for redeemer %d:%d", tag, redeemer.GetIndex())
		}
		mem := eu.GetMemory()
		steps := eu.GetSteps()
		if mem > math.MaxInt64 || steps > math.MaxInt64 {
			return result, fmt.Errorf("ExUnits overflow: memory=%d steps=%d", mem, steps)
		}
		result[key] = common.ExUnits{
			Memory: int64(mem),
			Steps:  int64(steps),
		}
	}
	if len(result) == 0 {
		return nil, errors.New("script evaluation returned no results")
	}
	return result, nil
}

func redeemerKeySet[V any](values map[common.RedeemerKey]V) map[common.RedeemerKey]struct{} {
	keys := make(map[common.RedeemerKey]struct{}, len(values))
	for key := range values {
		keys[key] = struct{}{}
	}
	return keys
}

func sameRedeemerKeySet[V any](actual map[common.RedeemerKey]V, expected map[common.RedeemerKey]struct{}) bool {
	if len(actual) != len(expected) {
		return false
	}
	for key := range actual {
		if _, ok := expected[key]; !ok {
			return false
		}
	}
	return true
}

func formatRedeemerKeys(keys map[common.RedeemerKey]struct{}) string {
	sorted := make([]common.RedeemerKey, 0, len(keys))
	for key := range keys {
		sorted = append(sorted, key)
	}
	sort.Slice(sorted, func(i, j int) bool {
		return common.CompareRedeemerKeys(sorted[i], sorted[j]) < 0
	})
	formatted := make([]string, 0, len(sorted))
	for _, key := range sorted {
		formatted = append(formatted, fmt.Sprintf("%d:%d", key.Tag, key.Index))
	}
	return "[" + strings.Join(formatted, ", ") + "]"
}

func (u *UtxoRpcChainContext) UtxoByRef(txHash common.Blake2b256, index uint32) (*common.Utxo, error) {
	return u.UtxoByRefContext(context.Background(), txHash, index)
}

func (u *UtxoRpcChainContext) UtxoByRefContext(
	ctx context.Context,
	txHash common.Blake2b256,
	index uint32,
) (*common.Utxo, error) {
	// Converted per version rather than reprojected: see searchUtxosPage.
	found, err := callWithVersionFallback(ctx, u,
		func(ctx context.Context) ([]common.Utxo, error) {
			req := connect.NewRequest(&query.ReadUtxosRequest{
				Keys: []*query.TxoRef{
					{Hash: txHash.Bytes(), Index: index},
				},
			})
			u.client.AddHeadersToRequest(req)
			resp, err := u.client.ReadUtxosWithContext(ctx, req)
			if err != nil {
				return nil, err
			}
			return convertUtxoItems(resp.Msg.GetItems(), utxoFromRpc)
		},
		func(ctx context.Context) ([]common.Utxo, error) {
			req := connect.NewRequest(&alphaquery.ReadUtxosRequest{
				Keys: []*alphaquery.TxoRef{
					{Hash: txHash.Bytes(), Index: index},
				},
			})
			u.alphaClient.AddHeadersToRequest(req)
			resp, err := u.alphaClient.ReadUtxosWithContext(ctx, req)
			if err != nil {
				return nil, err
			}
			return convertUtxoItems(resp.Msg.GetItems(), utxoFromRpcAlpha)
		},
	)
	if err != nil {
		return nil, err
	}
	if len(found) == 0 {
		return nil, errors.New("utxo not found")
	}
	utxo := found[0]
	return &utxo, nil
}

func (u *UtxoRpcChainContext) ScriptCbor(scriptHash common.Blake2b224) ([]byte, error) {
	return u.ScriptCborContext(context.Background(), scriptHash)
}

func (u *UtxoRpcChainContext) ScriptCborContext(ctx context.Context, _ common.Blake2b224) ([]byte, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	return nil, backend.NewUnsupportedError("UTxO RPC", backend.CapabilityScriptCbor)
}

func utxoFromRpc(item *query.AnyUtxoData) (common.Utxo, error) {
	ref := item.GetTxoRef()
	return utxoFromParts(item.GetNativeBytes(), ref.GetHash(), ref.GetIndex())
}

// convertUtxoItems maps a version's UTxO items through its converter.
func convertUtxoItems[T any](
	items []T,
	convert func(T) (common.Utxo, error),
) ([]common.Utxo, error) {
	out := make([]common.Utxo, 0, len(items))
	for _, item := range items {
		utxo, err := convert(item)
		if err != nil {
			return nil, err
		}
		out = append(out, utxo)
	}
	return out, nil
}

// utxoFromRpcAlpha is the v1alpha counterpart of utxoFromRpc.
//
// Apollo reads only native_bytes and txo_ref from a UTxO response, and both
// proto versions declare those identically, so each version converts its own
// response and shares utxoFromParts. That avoids reprojecting these messages
// between versions, which would mean a marshal/unmarshal round trip per page
// and a dependency on the parsed Cardano value structures agreeing -- they
// nearly do, but v1alpha carries Asset.mint_coin and Multiasset.redeemer with
// no v1beta counterpart.
func utxoFromRpcAlpha(item *alphaquery.AnyUtxoData) (common.Utxo, error) {
	ref := item.GetTxoRef()
	return utxoFromParts(item.GetNativeBytes(), ref.GetHash(), ref.GetIndex())
}

// utxoFromParts builds a UTxO from the raw output CBOR and its reference.
func utxoFromParts(
	nativeBytes []byte,
	refHash []byte,
	refIndex uint32,
) (common.Utxo, error) {
	if len(nativeBytes) == 0 {
		return common.Utxo{}, fmt.Errorf("no native bytes for utxo %s#%d",
			hex.EncodeToString(refHash), refIndex)
	}

	// Parse the CBOR-encoded transaction output
	output, err := babbage.NewBabbageTransactionOutputFromCbor(nativeBytes)
	if err != nil {
		return common.Utxo{}, fmt.Errorf("failed to parse utxo CBOR: %w", err)
	}

	if len(refHash) != common.Blake2b256Size {
		return common.Utxo{}, fmt.Errorf("invalid tx hash length: expected %d bytes, got %d", common.Blake2b256Size, len(refHash))
	}
	var txId common.Blake2b256
	copy(txId[:], refHash)

	input := shelley.ShelleyTransactionInput{
		TxId:        txId,
		OutputIndex: refIndex,
	}
	return common.Utxo{
		Id:     input,
		Output: output,
	}, nil
}

// utxorpcPurposeToRedeemerTag maps UTxO RPC redeemer purpose enum to gouroboros RedeemerTag.
// UTxO RPC uses 1-based enum (SPEND=1, MINT=2, ...) while gouroboros uses 0-based (Spend=0, Mint=1, ...).
func utxorpcPurposeToRedeemerTag(purpose cardano.RedeemerPurpose) (common.RedeemerTag, error) {
	switch purpose {
	case cardano.RedeemerPurpose_REDEEMER_PURPOSE_SPEND:
		return common.RedeemerTagSpend, nil
	case cardano.RedeemerPurpose_REDEEMER_PURPOSE_MINT:
		return common.RedeemerTagMint, nil
	case cardano.RedeemerPurpose_REDEEMER_PURPOSE_CERT:
		return common.RedeemerTagCert, nil
	case cardano.RedeemerPurpose_REDEEMER_PURPOSE_REWARD:
		return common.RedeemerTagReward, nil
	case cardano.RedeemerPurpose_REDEEMER_PURPOSE_VOTE:
		return common.RedeemerTagVoting, nil
	case cardano.RedeemerPurpose_REDEEMER_PURPOSE_PROPOSE:
		return common.RedeemerTagProposing, nil
	default:
		return 0, fmt.Errorf("unsupported redeemer purpose: %d", purpose)
	}
}

func utxorpcZeroBasedPurposeToRedeemerTag(purpose cardano.RedeemerPurpose) (common.RedeemerTag, error) {
	switch purpose {
	case cardano.RedeemerPurpose_REDEEMER_PURPOSE_UNSPECIFIED:
		return common.RedeemerTagSpend, nil
	case cardano.RedeemerPurpose_REDEEMER_PURPOSE_SPEND:
		return common.RedeemerTagMint, nil
	case cardano.RedeemerPurpose_REDEEMER_PURPOSE_MINT:
		return common.RedeemerTagCert, nil
	case cardano.RedeemerPurpose_REDEEMER_PURPOSE_CERT:
		return common.RedeemerTagReward, nil
	case cardano.RedeemerPurpose_REDEEMER_PURPOSE_REWARD:
		return common.RedeemerTagVoting, nil
	case cardano.RedeemerPurpose_REDEEMER_PURPOSE_VOTE:
		return common.RedeemerTagProposing, nil
	default:
		return 0, fmt.Errorf("unsupported zero-based redeemer purpose: %d", purpose)
	}
}
