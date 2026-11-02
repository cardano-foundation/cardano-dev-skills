package localeval

import (
	"errors"
	"fmt"
	"time"

	"github.com/blinklabs-io/gouroboros/ledger/common"

	"github.com/Salvionied/apollo/v2/backend"
)

// errNotForEvaluation is returned by the ledger-state queries script
// evaluation does not make. Script contexts are built from the transaction,
// its resolved UTxOs and slot times; certificate, pool, reward and governance
// state are only consulted by phase-one validation rules.
var errNotForEvaluation = errors.New("ledger state is not available to local script evaluation")

// utxoResolver returns the UTxO an input refers to.
type utxoResolver func(common.TransactionInput) (common.Utxo, error)

type utxoKey struct {
	id    common.Blake2b256
	index uint32
}

func keyForInput(input common.TransactionInput) utxoKey {
	return utxoKey{id: input.Id(), index: input.Index()}
}

// evalLedgerState is the ledger view the gouroboros evaluator runs against.
// It answers UTxO and slot queries and fails every other query, so a future
// evaluator that starts depending on chain state reports an error instead of
// silently reading an empty ledger.
type evalLedgerState struct {
	resolve utxoResolver
	slots   SlotConfig
}

var _ common.LedgerState = (*evalLedgerState)(nil)

func (s *evalLedgerState) UtxoById(input common.TransactionInput) (common.Utxo, error) {
	if input == nil {
		return common.Utxo{}, errors.New("nil transaction input")
	}
	return s.resolve(input)
}

func (s *evalLedgerState) SlotToTime(slot uint64) (time.Time, error) {
	return s.slots.SlotToTime(slot)
}

func (s *evalLedgerState) TimeToSlot(t time.Time) (uint64, error) {
	return s.slots.TimeToSlot(t)
}

// NetworkId and CostModels are not read by script evaluation. Only phase-one
// validation rules read the network id, and the evaluator receives cost
// models from the protocol parameters.
func (s *evalLedgerState) NetworkId() uint { return 0 }

func (s *evalLedgerState) CostModels() map[common.PlutusLanguage]common.CostModel {
	return nil
}

func (s *evalLedgerState) StakeRegistration([]byte) ([]common.StakeRegistrationCertificate, error) {
	return nil, errNotForEvaluation
}

func (s *evalLedgerState) IsStakeCredentialRegistered(common.Credential) bool { return false }

func (s *evalLedgerState) PoolCurrentState(common.PoolKeyHash) (*common.PoolRegistrationCertificate, *uint64, error) {
	return nil, nil, errNotForEvaluation
}

func (s *evalLedgerState) IsPoolRegistered(common.PoolKeyHash) bool { return false }

func (s *evalLedgerState) IsVrfKeyInUse(common.Blake2b256) (bool, common.PoolKeyHash, error) {
	return false, common.PoolKeyHash{}, errNotForEvaluation
}

func (s *evalLedgerState) CalculateRewards(
	common.AdaPots,
	common.RewardSnapshot,
	common.RewardParameters,
) (*common.RewardCalculationResult, error) {
	return nil, errNotForEvaluation
}

func (s *evalLedgerState) GetAdaPots() common.AdaPots { return common.AdaPots{} }

func (s *evalLedgerState) UpdateAdaPots(common.AdaPots) error { return errNotForEvaluation }

func (s *evalLedgerState) GetRewardSnapshot(uint64) (common.RewardSnapshot, error) {
	return common.RewardSnapshot{}, errNotForEvaluation
}

func (s *evalLedgerState) IsRewardAccountRegistered(common.Credential) bool { return false }

func (s *evalLedgerState) RewardAccountBalance(common.Credential) (*uint64, error) {
	return nil, errNotForEvaluation
}

func (s *evalLedgerState) CommitteeMember(common.Blake2b224) (*common.CommitteeMember, error) {
	return nil, errNotForEvaluation
}

func (s *evalLedgerState) CommitteeMembers() ([]common.CommitteeMember, error) {
	return nil, errNotForEvaluation
}

func (s *evalLedgerState) DRepRegistration(common.Credential) (*common.DRepRegistration, error) {
	return nil, errNotForEvaluation
}

func (s *evalLedgerState) DRepRegistrations() ([]common.DRepRegistration, error) {
	return nil, errNotForEvaluation
}

func (s *evalLedgerState) Constitution() (*common.Constitution, error) {
	return nil, errNotForEvaluation
}

func (s *evalLedgerState) TreasuryValue() (uint64, error) { return 0, errNotForEvaluation }

func (s *evalLedgerState) GovActionById(common.GovActionId) (*common.GovActionState, error) {
	return nil, errNotForEvaluation
}

func (s *evalLedgerState) GovActionExists(common.GovActionId) bool { return false }

// staticResolver resolves inputs from a fixed set of UTxOs.
func staticResolver(utxos []common.Utxo) (utxoResolver, error) {
	byRef := make(map[utxoKey]common.Utxo, len(utxos))
	for i, utxo := range utxos {
		if err := backend.ValidateAdditionalUtxo(utxo); err != nil {
			return nil, fmt.Errorf("utxo %d: %w", i, err)
		}
		key := keyForInput(utxo.Id)
		if _, exists := byRef[key]; exists {
			return nil, fmt.Errorf("utxo %d duplicates %s", i, utxo.Id.String())
		}
		byRef[key] = utxo
	}
	return func(input common.TransactionInput) (common.Utxo, error) {
		if utxo, ok := byRef[keyForInput(input)]; ok {
			return utxo, nil
		}
		return common.Utxo{}, fmt.Errorf("utxo %s was not supplied", input.String())
	}, nil
}
