package apollo

import (
	"encoding/hex"
	"errors"
	"fmt"
	"strconv"

	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/gouroboros/ledger/dijkstra"
)

// requiredTopLevelGuard is one entry of Dijkstra transaction body field 24.
type requiredTopLevelGuard struct {
	Credential common.Credential
	Datum      *common.Datum
}

// AddGuard adds a Dijkstra guard credential to transaction body field 14.
//
// A key-hash guard is satisfied by a signature from that key and takes no
// redeemer. A script guard is satisfied by its script, supplied with
// AttachScript or through a reference input: pass a redeemer for a Plutus
// guard script and nil for a native-script guard. A nil exUnits leaves the
// budget to execution-unit evaluation.
//
// Guards are serialized after any required signers, in the order they are
// added; a guarding redeemer's index is its credential's position in that list.
func (a *Apollo) AddGuard(cred common.Credential, redeemer *common.Datum, exUnits *common.ExUnits) *Apollo {
	a.initState()
	if a.targetEra != EraDijkstra {
		a.setErrOnce(errors.New("guards require the Dijkstra target era"))
		return a
	}
	switch cred.CredType {
	case common.CredentialTypeAddrKeyHash:
		if redeemer != nil || exUnits != nil {
			a.setErrOnce(errors.New("key-hash guard must not have a redeemer or execution units"))
			return a
		}
	case common.CredentialTypeScriptHash:
		if redeemer == nil && exUnits != nil {
			a.setErrOnce(errors.New("guard execution units require a redeemer"))
			return a
		}
	default:
		a.setErrOnce(fmt.Errorf("unsupported guard credential type %d", cred.CredType))
		return a
	}
	key := credentialKey(cred)
	existing, hasRedeemer := a.guardRedeemers[key]
	if a.hasGuard(key) {
		if (redeemer == nil) == hasRedeemer {
			a.setErrOnce(fmt.Errorf("conflicting redeemer for guard %s", key))
			return a
		}
	} else {
		a.guards = append(a.guards, common.Credential{CredType: cred.CredType, Credential: cred.Credential})
	}
	if redeemer == nil {
		return a
	}
	entry := redeemerEntry{Tag: common.RedeemerTagGuarding, Data: *redeemer}
	if exUnits != nil {
		entry.ExUnits = *exUnits
	}
	if hasRedeemer && !redeemerEntriesEqual(existing, entry) {
		a.setErrOnce(fmt.Errorf("conflicting redeemer for guard %s", key))
		return a
	}
	a.guardRedeemers[key] = entry
	a.isEstimateRequired = true
	return a
}

// AddRequiredTopLevelGuard adds an entry to Dijkstra transaction body field
// 24, asserting that the transaction's guards include cred. The credential
// must also be added with AddGuard or AddRequiredSigner. A key-hash or
// native-script guard takes a nil datum; a Plutus guard script requires one.
func (a *Apollo) AddRequiredTopLevelGuard(cred common.Credential, datum *common.Datum) *Apollo {
	if a.targetEra != EraDijkstra {
		a.setErrOnce(errors.New("required top-level guards require the Dijkstra target era"))
		return a
	}
	switch cred.CredType {
	case common.CredentialTypeAddrKeyHash:
		if datum != nil {
			a.setErrOnce(errors.New("key-hash required top-level guard must not have a datum"))
			return a
		}
	case common.CredentialTypeScriptHash:
	default:
		a.setErrOnce(fmt.Errorf("unsupported required top-level guard credential type %d", cred.CredType))
		return a
	}
	if datum != nil && datum.Data == nil {
		a.setErrOnce(errors.New("required top-level guard datum is missing Plutus data"))
		return a
	}
	key := credentialKey(cred)
	for _, required := range a.requiredTopLevelGuards {
		if credentialKey(required.Credential) == key {
			a.setErrOnce(fmt.Errorf("duplicate required top-level guard %s", key))
			return a
		}
	}
	entry := requiredTopLevelGuard{
		Credential: common.Credential{CredType: cred.CredType, Credential: cred.Credential},
	}
	if datum != nil {
		var datumCopy common.Datum
		if err := cloneCBORValue(*datum, &datumCopy); err != nil {
			a.setErrOnce(fmt.Errorf("required top-level guard datum: %w", err))
			return a
		}
		entry.Datum = &datumCopy
	}
	a.requiredTopLevelGuards = append(a.requiredTopLevelGuards, entry)
	return a
}

func (a *Apollo) hasGuard(key string) bool {
	for _, guard := range a.guards {
		if credentialKey(guard) == key {
			return true
		}
	}
	return false
}

// dijkstraGuardList returns the ordered guard credentials: required signers
// as key-hash credentials, then guards added with AddGuard, without
// duplicates. It returns nil when no credential guards were added, in which
// case required signers alone use the key-hash guard encoding.
func (a *Apollo) dijkstraGuardList(signers []common.Blake2b224) []common.Credential {
	if len(a.guards) == 0 {
		return nil
	}
	seen := make(map[string]struct{}, len(signers)+len(a.guards))
	guards := make([]common.Credential, 0, len(signers)+len(a.guards))
	add := func(cred common.Credential) {
		key := credentialKey(cred)
		if _, ok := seen[key]; ok {
			return
		}
		seen[key] = struct{}{}
		guards = append(guards, cred)
	}
	for _, signer := range signers {
		add(common.Credential{CredType: common.CredentialTypeAddrKeyHash, Credential: signer})
	}
	for _, guard := range a.guards {
		add(guard)
	}
	return guards
}

// dijkstraGuards builds transaction body field 14 from the body's required
// signers and the builder's guards.
func (a *Apollo) dijkstraGuards(signers []common.Blake2b224) *dijkstra.DijkstraGuards {
	if credentials := a.dijkstraGuardList(signers); len(credentials) > 0 {
		return &dijkstra.DijkstraGuards{Credentials: credentials}
	}
	if len(signers) == 0 {
		return nil
	}
	seen := make(map[common.Blake2b224]struct{}, len(signers))
	keyHashes := make([]common.Blake2b224, 0, len(signers))
	for _, signer := range signers {
		if _, ok := seen[signer]; ok {
			continue
		}
		seen[signer] = struct{}{}
		keyHashes = append(keyHashes, signer)
	}
	return &dijkstra.DijkstraGuards{KeyHashes: keyHashes}
}

// dijkstraRequiredTopLevelGuards builds transaction body field 24, rejecting
// an entry whose credential is not among guards.
func (a *Apollo) dijkstraRequiredTopLevelGuards(guards *dijkstra.DijkstraGuards) (dijkstra.DijkstraRequiredTopLevelGuards, error) {
	if len(a.requiredTopLevelGuards) == 0 {
		return nil, nil
	}
	present := make(map[string]struct{})
	if guards != nil {
		for _, cred := range guards.Credentials {
			present[credentialKey(cred)] = struct{}{}
		}
		for _, hash := range guards.KeyHashes {
			present[credentialKey(common.Credential{CredType: common.CredentialTypeAddrKeyHash, Credential: hash})] = struct{}{}
		}
	}
	required := make(dijkstra.DijkstraRequiredTopLevelGuards, len(a.requiredTopLevelGuards))
	for _, entry := range a.requiredTopLevelGuards {
		key := credentialKey(entry.Credential)
		if _, ok := present[key]; !ok {
			return nil, fmt.Errorf("required top-level guard %s is not among the transaction guards", key)
		}
		cred := entry.Credential
		required[&cred] = entry.Datum
	}
	return required, nil
}

// guardRedeemerIndex returns the guarding redeemer index for key.
func (a *Apollo) guardRedeemerIndex(key string) (uint32, bool) {
	for i, cred := range a.dijkstraGuardList(a.requiredSigners) {
		if credentialKey(cred) == key {
			return uint32(i), true //nolint:gosec // guard count is bounded by transaction size
		}
	}
	return 0, false
}

// guardRedeemerKeyAt returns the guard key at a guarding redeemer index.
func (a *Apollo) guardRedeemerKeyAt(index uint32) (string, bool) {
	guards := a.dijkstraGuardList(a.requiredSigners)
	if uint64(index) >= uint64(len(guards)) {
		return "", false
	}
	return credentialKey(guards[index]), true
}

func credentialKey(cred common.Credential) string {
	return strconv.FormatUint(uint64(cred.CredType), 10) + ":" + hex.EncodeToString(cred.Credential.Bytes())
}
