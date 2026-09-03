package apollo

import (
	"bytes"
	"crypto/ed25519"
	"fmt"
	"sort"
	"strings"

	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/gouroboros/ledger/conway"
)

// EvaluationWitnessProvider supplies signing witnesses used only while
// evaluating a preliminary transaction. It is optional so Wallet remains
// compatible with hardware and remote wallets that cannot sign automatically.
type EvaluationWitnessProvider interface {
	EvaluationWitnesses(
		txBodyHash common.Blake2b256,
		requiredSigners []common.Blake2b224,
	) ([]common.VkeyWitness, error)
}

func evaluationBodyHash(body *conway.ConwayTransactionBody) (common.Blake2b256, error) {
	body.SetCbor(nil)
	bodyCbor, err := cbor.Encode(body)
	if err != nil {
		return common.Blake2b256{}, fmt.Errorf("encode evaluation tx body: %w", err)
	}
	return common.Blake2b256Hash(bodyCbor), nil
}

func sortedSignerHashes(hashes []common.Blake2b224) []common.Blake2b224 {
	sorted := append([]common.Blake2b224(nil), hashes...)
	sort.Slice(sorted, func(i, j int) bool {
		return bytes.Compare(sorted[i][:], sorted[j][:]) < 0
	})
	return sorted
}

func missingSignerHashes(required map[common.Blake2b224]struct{}, found map[common.Blake2b224]struct{}) []common.Blake2b224 {
	missing := make([]common.Blake2b224, 0, len(required))
	for hash := range required {
		if _, ok := found[hash]; !ok {
			missing = append(missing, hash)
		}
	}
	return sortedSignerHashes(missing)
}

// evaluationWitnesses resolves and validates witnesses for the exact
// preliminary body sent to an evaluator. These witnesses are intentionally
// local to evaluation and are never retained in a completed transaction.
func (a *Apollo) evaluationWitnesses(body *conway.ConwayTransactionBody) ([]common.VkeyWitness, error) {
	requiredHashes := body.TxRequiredSigners.Items()
	if len(requiredHashes) == 0 {
		return nil, nil
	}

	bodyHash, err := evaluationBodyHash(body)
	if err != nil {
		return nil, err
	}
	required := make(map[common.Blake2b224]struct{}, len(requiredHashes))
	for _, hash := range requiredHashes {
		required[hash] = struct{}{}
	}
	found := make(map[common.Blake2b224]struct{}, len(required))
	witnesses := make([]common.VkeyWitness, 0, len(required))

	addWitnesses := func(candidates []common.VkeyWitness) error {
		for _, witness := range candidates {
			if len(witness.Vkey) != ed25519.PublicKeySize {
				return fmt.Errorf("evaluation witness has malformed vkey: expected %d bytes, got %d", ed25519.PublicKeySize, len(witness.Vkey))
			}
			if len(witness.Signature) != ed25519.SignatureSize {
				return fmt.Errorf("evaluation witness has malformed signature: expected %d bytes, got %d", ed25519.SignatureSize, len(witness.Signature))
			}
			hash := common.Blake2b224Hash(witness.Vkey)
			if _, ok := required[hash]; !ok {
				return fmt.Errorf("evaluation witness has unexpected signer %s", hash.String())
			}
			if _, ok := found[hash]; ok {
				return fmt.Errorf("evaluation witness duplicates signer %s", hash.String())
			}
			if !ed25519.Verify(ed25519.PublicKey(witness.Vkey), bodyHash.Bytes(), witness.Signature) {
				return fmt.Errorf("evaluation witness has invalid signature for signer %s", hash.String())
			}
			found[hash] = struct{}{}
			witnesses = append(witnesses, witness)
		}
		return nil
	}

	if a.wallet != nil {
		// ExternalWallet is watch-only and supplies no evaluation witnesses;
		// callers must register EvaluationWitnessProvider for its required hashes.
		if _, isExternal := a.wallet.(*ExternalWallet); !isExternal {
			paymentHash := a.wallet.PubKeyHash()
			if _, needed := required[paymentHash]; needed {
				witness, err := a.wallet.SignTxBody(bodyHash)
				if err != nil {
					return nil, fmt.Errorf("sign evaluation tx with primary wallet: %w", err)
				}
				if err := addWitnesses([]common.VkeyWitness{witness}); err != nil {
					return nil, err
				}
			}
		}

		if provider, ok := a.wallet.(*BursaWallet); ok {
			missing := missingSignerHashes(required, found)
			if len(missing) > 0 {
				witnesses, err := provider.EvaluationWitnesses(bodyHash, missing)
				if err != nil {
					return nil, fmt.Errorf("get evaluation witnesses from Bursa wallet: %w", err)
				}
				if err := addWitnesses(witnesses); err != nil {
					return nil, err
				}
			}
		}
	}

	for _, provider := range a.evaluationWitnessProviders {
		missing := missingSignerHashes(required, found)
		if len(missing) == 0 {
			break
		}
		providerWitnesses, err := provider.EvaluationWitnesses(bodyHash, missing)
		if err != nil {
			return nil, fmt.Errorf("get evaluation witnesses: %w", err)
		}
		if err := addWitnesses(providerWitnesses); err != nil {
			return nil, err
		}
	}

	missing := missingSignerHashes(required, found)
	if len(missing) > 0 {
		hashes := make([]string, len(missing))
		for i, hash := range missing {
			hashes[i] = hash.String()
		}
		return nil, fmt.Errorf("missing evaluation witnesses for required signers: %s", strings.Join(hashes, ", "))
	}

	sort.Slice(witnesses, func(i, j int) bool {
		left := common.Blake2b224Hash(witnesses[i].Vkey)
		right := common.Blake2b224Hash(witnesses[j].Vkey)
		return bytes.Compare(left[:], right[:]) < 0
	})
	return witnesses, nil
}
