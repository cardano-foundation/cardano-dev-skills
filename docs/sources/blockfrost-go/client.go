package blockfrost

import (
	"context"
	"net/http"
	"os"

	"github.com/hashicorp/go-retryablehttp"
)

type apiClient struct {
	server    string
	projectId string
	client    *http.Client
	routines  int
}

// APIClientOptions contains optios used to initialize an API Client using
// NewAPIClient
type APIClientOptions struct {
	// The project_id to use from blockfrost. If not set
	// `BLOCKFROST_PROJECT_ID` is loaded from env
	ProjectID string

	// Server url to use
	Server string

	// Max number of routines to use for *All methods
	MaxRoutines int

	// Underlying http client to use. If not set, default github.com/hashicorp/go-retryablehttp is used.
	Client *http.Client
}

// NewAPIClient creates a client from APIClientOptions. If no options are provided,
// client with default configurations is returned.
func NewAPIClient(options APIClientOptions) APIClient {
	if options.Server == "" {
		options.Server = CardanoMainNet
	}

	if options.Client == nil {
		retryclient := retryablehttp.NewClient()
		retryclient.Logger = nil
		options.Client = retryclient.StandardClient()
	}

	if options.ProjectID == "" {
		options.ProjectID = os.Getenv("BLOCKFROST_PROJECT_ID")
	}

	if options.MaxRoutines == 0 {
		options.MaxRoutines = 10
	}

	client := &apiClient{
		server:    options.Server,
		client:    options.Client,
		projectId: options.ProjectID,
		routines:  options.MaxRoutines,
	}

	return client
}

// APIClient defines methods implemented by the api client.
type APIClient interface {
	Info(ctx context.Context) (Info, error)
	Health(ctx context.Context) (Health, error)
	HealthClock(ctx context.Context) (HealthClock, error)
	Metrics(ctx context.Context) ([]Metric, error)
	MetricsEndpoints(ctx context.Context) ([]MetricsEndpoint, error)
	Block(ctx context.Context, hashOrNumber string) (Block, error)
	BlockLatest(ctx context.Context) (Block, error)
	BlockLatestTransactions(ctx context.Context, query APIQueryParams) ([]Transaction, error)
	BlockLatestTransactionsAll(ctx context.Context) <-chan BlockTransactionResult
	BlockTransactions(ctx context.Context, hashOrNumber string, query APIQueryParams) ([]Transaction, error)
	BlockTransactionsAll(ctx context.Context, hashOrNumber string) <-chan BlockTransactionResult
	BlocksNext(ctx context.Context, hashOrNumber string) ([]Block, error)
	BlocksPrevious(ctx context.Context, hashOrNumber string) ([]Block, error)
	BlockBySlot(ctx context.Context, slotNumber int) (Block, error)
	BlocksBySlotAndEpoch(ctx context.Context, slotNumber int, epochNumber int) (Block, error)
	BlocksAddresses(ctx context.Context, hashOrNumber string, query APIQueryParams) ([]BlockAffectedAddresses, error)
	BlocksAddressesAll(ctx context.Context, hashOrNumber string) <-chan BlockAffectedAddressesResult
	EpochLatest(ctx context.Context) (Epoch, error)
	LatestEpochParameters(ctx context.Context) (EpochParameters, error)
	Epoch(ctx context.Context, epochNumber int) (Epoch, error)
	EpochsNext(ctx context.Context, epochNumber int, query APIQueryParams) ([]Epoch, error)
	EpochNextAll(ctx context.Context, epochNumber int) <-chan EpochResult
	EpochsPrevious(ctx context.Context, epochNumber int, query APIQueryParams) ([]Epoch, error)
	EpochPreviousAll(ctx context.Context, epochNumber int) <-chan EpochResult
	EpochStakeDistribution(ctx context.Context, epochNumber int, query APIQueryParams) ([]EpochStake, error)
	EpochStakeDistributionAll(ctx context.Context, epochNumber int) <-chan EpochStakeResult
	EpochStakeDistributionByPool(ctx context.Context, epochNumber int, poolId string, query APIQueryParams) ([]EpochStakeByPool, error)
	EpochStakeDistributionByPoolAll(ctx context.Context, epochNumber int, poolId string) <-chan EpochStakeByPoolResult
	EpochBlockDistribution(ctx context.Context, epochNumber int, query APIQueryParams) ([]string, error)
	EpochBlockDistributionAll(ctx context.Context, epochNumber int) <-chan BlockDistributionResult
	EpochBlockDistributionByPool(ctx context.Context, epochNumber int, poolId string, query APIQueryParams) ([]string, error)
	EpochBlockDistributionByPoolAll(ctx context.Context, epochNumber int, poolId string) <-chan BlockDistributionResult
	EpochParameters(ctx context.Context, epochNumber int) (EpochParameters, error)
	Address(ctx context.Context, address string) (Address, error)
	AddressDetails(ctx context.Context, address string) (AddressDetails, error)
	AddressExtended(ctx context.Context, address string) (AddressExtended, error)
	AddressTransactions(ctx context.Context, address string, query APIQueryParams) ([]AddressTransactions, error)
	AddressTransactionsAll(ctx context.Context, address string) <-chan AddressTxResult
	AddressUTXOs(ctx context.Context, address string, query APIQueryParams) ([]AddressUTXO, error)
	AddressUTXOsAll(ctx context.Context, address string) <-chan AddressUTXOResult
	AddressUTXOsAsset(ctx context.Context, address, asset string, query APIQueryParams) ([]AddressUTXO, error)
	AddressUTXOsAssetAll(ctx context.Context, address, asset string) <-chan AddressUTXOResult
	Account(ctx context.Context, stakeAddress string) (Account, error)
	AccountHistory(ctx context.Context, stakeAddress string, query APIQueryParams) ([]AccountHistory, error)
	AccountHistoryAll(ctx context.Context, address string) <-chan AccountHistoryResult
	AccountRewardsHistory(ctx context.Context, stakeAddress string, query APIQueryParams) ([]AccountRewardsHistory, error)
	AccountRewardsHistoryAll(ctx context.Context, stakeAddress string) <-chan AccountRewardHisResult
	AccountDelegationHistory(ctx context.Context, stakeAddress string, query APIQueryParams) ([]AccountDelegationHistory, error)
	AccountDelegationHistoryAll(ctx context.Context, stakeAddress string) <-chan AccDelegationHistoryResult
	AccountRegistrationHistory(ctx context.Context, stakeAddress string, query APIQueryParams) ([]AccountRegistrationHistory, error)
	AccountRegistrationHistoryAll(ctx context.Context, stakeAddress string) <-chan AccountRegistrationHistoryResult
	AccountWithdrawalHistory(ctx context.Context, stakeAddress string, query APIQueryParams) ([]AccountWithdrawalHistory, error)
	AccountWithdrawalHistoryAll(ctx context.Context, stakeAddress string) <-chan AccountWithdrawalHistoryResult
	AccountMIRHistory(ctx context.Context, stakeAddress string, query APIQueryParams) ([]AccountMIRHistory, error)
	AccountMIRHistoryAll(ctx context.Context, stakeAddress string) <-chan AccountMIRHistoryResult
	AccountAssociatedAddresses(ctx context.Context, stakeAddress string, query APIQueryParams) ([]AccountAssociatedAddress, error)
	AccountAssociatedAddressesAll(ctx context.Context, stakeAddress string) <-chan AccountAssociatedAddressesAll
	AccountAssociatedAssets(ctx context.Context, stakeAddress string, query APIQueryParams) ([]AccountAssociatedAsset, error)
	AccountAssociatedAssetsAll(ctx context.Context, stakeAddress string) <-chan AccountAssociatedAssetsAll
	AccountAddressesTotal(ctx context.Context, stakeAddress string) (AccountAddressesTotal, error)
	AccountTransactions(ctx context.Context, stakeAddress string, query APIQueryParams) ([]AccountTransaction, error)
	AccountTransactionsAll(ctx context.Context, stakeAddress string) <-chan AccountTransactionResult
	Asset(ctx context.Context, asset string) (Asset, error)
	Assets(ctx context.Context, query APIQueryParams) ([]AssetByPolicy, error)
	AssetsAll(ctx context.Context) <-chan AssetByPolicyResult
	AssetHistory(ctx context.Context, asset string, query APIQueryParams) ([]AssetHistory, error)
	AssetHistoryAll(ctx context.Context, asset string) <-chan AssetHistoryResult
	AssetTransactions(ctx context.Context, asset string, query APIQueryParams) ([]AssetTransaction, error)
	AssetTransactionsAll(ctx context.Context, asset string) <-chan AssetTransactionResult
	AssetAddresses(ctx context.Context, asset string, query APIQueryParams) ([]AssetAddress, error)
	AssetAddressesAll(ctx context.Context, asset string) <-chan AssetAddressesAll
	AssetsByPolicy(ctx context.Context, policyId string, query APIQueryParams) ([]AssetByPolicy, error)
	AssetsByPolicyAll(ctx context.Context, policyId string) <-chan AssetByPolicyResult
	Genesis(ctx context.Context) (GenesisBlock, error)
	Mempool(ctx context.Context, query APIQueryParams) ([]Mempool, error)
	MempoolAll(ctx context.Context) <-chan MempoolResult
	MempoolTx(ctx context.Context, hash string) (MempoolTransactionContent, error)
	MempoolByAddress(ctx context.Context, address string, query APIQueryParams) ([]Mempool, error)
	MempoolByAddressAll(ctx context.Context, address string) <-chan MempoolResult
	MetadataTxLabels(ctx context.Context, query APIQueryParams) ([]MetadataTxLabel, error)
	MetadataTxLabelsAll(ctx context.Context) <-chan MetadataTxLabelResult
	MetadataTxContentInJSON(ctx context.Context, label string, query APIQueryParams) ([]MetadataTxContentInJSON, error)
	MetadataTxContentInJSONAll(ctx context.Context, label string) <-chan MetadataTxContentInJSONResult
	MetadataTxContentInCBOR(ctx context.Context, label string, query APIQueryParams) ([]MetadataTxContentInCBOR, error)
	MetadataTxContentInCBORAll(ctx context.Context, label string) <-chan MetadataTxContentInCBORResult
	Network(ctx context.Context) (NetworkInfo, error)
	NetworkEras(ctx context.Context) ([]NetworkEra, error)
	Nutlink(ctx context.Context, address string) (NutlinkAddress, error)
	Tickers(ctx context.Context, address string, query APIQueryParams) ([]Ticker, error)
	TickersAll(ctx context.Context, address string) <-chan TickerResult
	TickerRecords(ctx context.Context, ticker string, query APIQueryParams) ([]TickerRecord, error)
	TickerRecordsAll(ctx context.Context, ticker string) <-chan TickerRecordResult
	AddressTickerRecords(ctx context.Context, address string, ticker string, query APIQueryParams) ([]TickerRecord, error)
	AddressTickerRecordsAll(ctx context.Context, address string, ticker string) <-chan TickerRecordResult
	Script(ctx context.Context, address string) (Script, error)
	Scripts(ctx context.Context, query APIQueryParams) ([]Script, error)
	ScriptsAll(ctx context.Context) <-chan ScriptAllResult
	ScriptRedeemers(ctx context.Context, address string, query APIQueryParams) ([]ScriptRedeemer, error)
	ScriptRedeemersAll(ctx context.Context, address string) <-chan ScriptRedeemerResult
	ScriptJSON(ctx context.Context, scriptHash string) (ScriptJSON, error)
	ScriptCBOR(ctx context.Context, scriptHash string) (ScriptCBOR, error)
	ScriptDatum(ctx context.Context, datumHash string) (ScriptDatum, error)
	ScriptDatumCBOR(ctx context.Context, datumHash string) (ScriptDatumCBOR, error)
	Pool(ctx context.Context, poolID string) (Pool, error)
	Pools(ctx context.Context, query APIQueryParams) (Pools, error)
	PoolsAll(ctx context.Context) <-chan PoolsResult
	PoolsRetired(ctx context.Context, query APIQueryParams) ([]PoolRetired, error)
	PoolsRetiredAll(ctx context.Context) <-chan PoolsRetiredResult
	PoolsRetiring(ctx context.Context, query APIQueryParams) ([]PoolRetiring, error)
	PoolsRetiringAll(ctx context.Context) <-chan PoolsRetiringResult
	PoolHistory(ctx context.Context, poolID string, query APIQueryParams) ([]PoolHistory, error)
	PoolHistoryAll(ctx context.Context, poolId string) <-chan PoolHistoryResult
	PoolMetadata(ctx context.Context, poolID string) (PoolMetadata, error)
	PoolRelays(ctx context.Context, poolID string) ([]PoolRelay, error)
	PoolDelegators(ctx context.Context, poolID string, query APIQueryParams) ([]PoolDelegator, error)
	PoolDelegatorsAll(ctx context.Context, poolId string) <-chan PoolDelegatorsResult
	PoolBlocks(ctx context.Context, poolID string, query APIQueryParams) (PoolBlocks, error)
	PoolBlocksAll(ctx context.Context, poolId string) <-chan PoolBlocksResult
	PoolUpdates(ctx context.Context, poolID string, query APIQueryParams) ([]PoolUpdate, error)
	PoolUpdatesAll(ctx context.Context, poolId string) <-chan PoolUpdateResult
	PoolsExtended(ctx context.Context, query APIQueryParams) ([]PoolExtended, error)
	PoolsExtendedAll(ctx context.Context) <-chan PoolsExtendedResult
	Committee(ctx context.Context) (Committee, error)
	CommitteeVotes(ctx context.Context, query APIQueryParams) ([]CommitteeVote, error)
	CommitteeVotesAll(ctx context.Context) <-chan CommitteeVoteResult
	CommitteeMemberVotes(ctx context.Context, ccID string, query APIQueryParams) ([]CommitteeVote, error)
	CommitteeMemberVotesAll(ctx context.Context, ccID string) <-chan CommitteeVoteResult
	Dreps(ctx context.Context, query APIQueryParams) ([]Drep, error)
	DrepsAll(ctx context.Context) <-chan DrepResult
	DrepDetails(ctx context.Context, drepId string) (DrepDetails, error)
	DrepMetadata(ctx context.Context, drepId string) (DrepMetadata, error)
	DrepDelegators(ctx context.Context, drepId string, query APIQueryParams) ([]DrepDelegator, error)
	DrepDelegatorsAll(ctx context.Context, drepId string) <-chan DrepDelegatorResult
	DrepUpdates(ctx context.Context, drepId string, query APIQueryParams) ([]DrepUpdate, error)
	DrepUpdatesAll(ctx context.Context, drepId string) <-chan DrepUpdateResult
	DrepVotes(ctx context.Context, drepId string, query APIQueryParams) ([]DrepVote, error)
	DrepVotesAll(ctx context.Context, drepId string) <-chan DrepVoteResult
	Proposals(ctx context.Context, query APIQueryParams) ([]Proposal, error)
	ProposalsAll(ctx context.Context) <-chan ProposalResult
	Proposal(ctx context.Context, txHash string, certIndex int) (ProposalDetails, error)
	ProposalParameters(ctx context.Context, txHash string, certIndex int) (ProposalParameters, error)
	ProposalMetadata(ctx context.Context, txHash string, certIndex int) (ProposalMetadata, error)
	ProposalByGovActionID(ctx context.Context, govActionID string) (ProposalDetails, error)
	ProposalParametersByGovActionID(ctx context.Context, govActionID string) (ProposalParameters, error)
	ProposalMetadataByGovActionID(ctx context.Context, govActionID string) (ProposalMetadataV2, error)
	ProposalWithdrawalsByGovActionID(ctx context.Context, govActionID string) ([]ProposalWithdrawal, error)
	ProposalVotesByGovActionID(ctx context.Context, govActionID string, query APIQueryParams) ([]ProposalVote, error)
	ProposalVotesByGovActionIDAll(ctx context.Context, govActionID string) <-chan ProposalVoteResult
	ProposalWithdrawals(ctx context.Context, txHash string, certIndex int, query APIQueryParams) ([]ProposalWithdrawal, error)
	ProposalWithdrawalsAll(ctx context.Context, txHash string, certIndex int) <-chan ProposalWithdrawalResult
	ProposalVotes(ctx context.Context, txHash string, certIndex int, query APIQueryParams) ([]ProposalVote, error)
	ProposalVotesAll(ctx context.Context, txHash string, certIndex int) <-chan ProposalVoteResult
	Transaction(ctx context.Context, hash string) (TransactionContent, error)
	TransactionCBOR(ctx context.Context, hash string) (TransactionCBOR, error)
	TransactionUTXOs(ctx context.Context, hash string) (TransactionUTXOs, error)
	TransactionStakeAddressCerts(ctx context.Context, hash string) ([]TransactionStakeAddressCert, error)
	TransactionWithdrawals(ctx context.Context, hash string) ([]TransactionWidthrawal, error)
	TransactionMIRs(ctx context.Context, hash string) ([]TransactionMIR, error)
	TransactionMetadata(ctx context.Context, hash string) ([]TransactionMetadata, error)
	TransactionMetadataInCBORs(ctx context.Context, hash string) ([]TransactionMetadataCbor, error)
	TransactionRedeemers(ctx context.Context, hash string) ([]TransactionRedeemer, error)
	TransactionRequiredSigners(ctx context.Context, hash string) ([]TransactionRequiredSigner, error)
	TransactionDelegationCerts(ctx context.Context, hash string) ([]TransactionDelegation, error)
	TransactionPoolUpdates(ctx context.Context, hash string) ([]TransactionPoolCert, error)
	TransactionPoolUpdateCerts(ctx context.Context, hash string) ([]TransactionPoolCert, error)
	TransactionPoolRetirementCerts(ctx context.Context, hash string) ([]TransactionPoolRetires, error)
	TransactionSubmit(ctx context.Context, cbor []byte) (string, error)
	TransactionEvaluate(ctx context.Context, cbor []byte) (OgmiosResponse, error)
	TransactionEvaluateUTXOs(ctx context.Context, cbor []byte, additionalUtxoSet AdditionalUtxoSet) (OgmiosResponse, error)
}
