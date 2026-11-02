package apollo

import (
	"errors"

	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/conway"
	"github.com/blinklabs-io/gouroboros/ledger/dijkstra"
)

func dijkstraTransactionFromConway(tx *conway.ConwayTransaction, builder *Apollo) (*dijkstra.DijkstraTransaction, error) {
	if tx == nil {
		return nil, errors.New("cannot convert a nil Conway transaction")
	}
	if builder == nil {
		return nil, errors.New("cannot convert a transaction without its builder state")
	}
	body := tx.Body
	dijkstraOutputs := make([]dijkstra.DijkstraTransactionOutput, len(body.TxOutputs))
	for i := range body.TxOutputs {
		dijkstraOutputs[i].Output = &body.TxOutputs[i]
	}
	var collateralReturn *dijkstra.DijkstraTransactionOutput
	if body.TxCollateralReturn != nil {
		collateralReturn = &dijkstra.DijkstraTransactionOutput{Output: body.TxCollateralReturn}
	}
	guards := builder.dijkstraGuards(body.TxRequiredSigners.Items())
	requiredGuards, err := builder.dijkstraRequiredTopLevelGuards(guards)
	if err != nil {
		return nil, err
	}
	proposals := make([]dijkstra.DijkstraProposalProcedure, 0, len(body.TxProposalProcedures)+len(builder.dijkstraProposalProcedures))
	for _, proposal := range body.TxProposalProcedures {
		proposals = append(proposals, dijkstra.DijkstraProposalProcedure{
			PPDeposit:       proposal.PPDeposit,
			PPRewardAccount: proposal.PPRewardAccount,
			PPGovAction: dijkstra.DijkstraGovAction{
				Type:   proposal.PPGovAction.Type,
				Action: proposal.PPGovAction.Action,
			},
			PPAnchor: proposal.PPAnchor,
		})
	}
	proposals = append(proposals, builder.dijkstraProposalProcedures...)

	dijkstraBody := dijkstra.DijkstraTransactionBody{
		TxInputs:                   body.TxInputs,
		TxOutputs:                  dijkstraOutputs,
		TxFee:                      body.TxFee,
		Ttl:                        body.Ttl,
		TxCertificates:             body.TxCertificates,
		TxWithdrawals:              body.TxWithdrawals,
		TxAuxDataHash:              body.TxAuxDataHash,
		TxValidityIntervalStart:    body.TxValidityIntervalStart,
		TxMint:                     body.TxMint,
		TxScriptDataHash:           body.TxScriptDataHash,
		TxCollateral:               body.TxCollateral,
		TxGuards:                   guards,
		TxRequiredTopLevelGuards:   requiredGuards,
		TxNetworkId:                body.TxNetworkId,
		TxCollateralReturn:         collateralReturn,
		TxTotalCollateral:          body.TxTotalCollateral,
		TxReferenceInputs:          body.TxReferenceInputs,
		TxVotingProcedures:         body.TxVotingProcedures,
		TxProposalProcedures:       proposals,
		TxCurrentTreasuryValue:     body.TxCurrentTreasuryValue,
		TxDonation:                 body.TxDonation,
		TxDirectDeposits:           cloneDijkstraDirectDeposits(builder.directDeposits),
		TxBalanceIntervals:         cloneDijkstraAccountBalanceIntervals(builder.balanceIntervals),
		TxStartingBalanceIntervals: cloneDijkstraAccountBalanceIntervals(builder.startingBalanceIntervals),
	}

	conwayWitnesses := tx.WitnessSet
	witnesses := dijkstra.DijkstraTransactionWitnessSet{
		VkeyWitnesses:      conwayWitnesses.VkeyWitnesses,
		WsNativeScripts:    conwayWitnesses.WsNativeScripts,
		BootstrapWitnesses: conwayWitnesses.BootstrapWitnesses,
		WsPlutusV1Scripts:  conwayWitnesses.WsPlutusV1Scripts,
		WsPlutusData:       conwayWitnesses.WsPlutusData,
		WsPlutusV2Scripts:  conwayWitnesses.WsPlutusV2Scripts,
		WsPlutusV3Scripts:  conwayWitnesses.WsPlutusV3Scripts,
	}
	if redeemers := conwayWitnesses.WsRedeemers.Redeemers; len(redeemers) > 0 {
		witnesses.WsRedeemers = dijkstra.DijkstraRedeemers{Redeemers: redeemers}
	}
	return &dijkstra.DijkstraTransaction{
		Body:       dijkstraBody,
		WitnessSet: witnesses,
		TxIsValid:  tx.TxIsValid,
		TxMetadata: tx.TxMetadata,
	}, nil
}

func cloneDijkstraDirectDeposits(deposits dijkstra.DijkstraDirectDeposits) dijkstra.DijkstraDirectDeposits {
	if deposits == nil {
		return nil
	}
	clone := make(dijkstra.DijkstraDirectDeposits, len(deposits))
	for account, amount := range deposits {
		clone[account] = amount
	}
	return clone
}

func cloneDijkstraAccountBalanceIntervals(intervals dijkstra.DijkstraAccountBalanceIntervals) dijkstra.DijkstraAccountBalanceIntervals {
	if intervals == nil {
		return nil
	}
	clone := make(dijkstra.DijkstraAccountBalanceIntervals, len(intervals))
	for account, interval := range intervals {
		if interval == nil {
			clone[account] = nil
			continue
		}
		clone[account] = cloneDijkstraBalanceInterval(*interval)
	}
	return clone
}

func dijkstraDirectDepositTotal(deposits dijkstra.DijkstraDirectDeposits) (uint64, error) {
	var total uint64
	for _, amount := range deposits {
		if amount == 0 {
			return 0, errors.New("direct deposit amount must be positive")
		}
		if ^uint64(0)-total < amount {
			return 0, errors.New("direct deposit total overflows uint64")
		}
		total += amount
	}
	return total, nil
}

// encodeDijkstraBody returns the body's CBOR. A decoded body keeps its
// original bytes, which define the transaction hash, so re-encoding it could
// change the hash that witnesses sign.
func encodeDijkstraBody(body *dijkstra.DijkstraTransactionBody) ([]byte, error) {
	if body == nil {
		return nil, errors.New("transaction body is nil")
	}
	if raw := body.Cbor(); len(raw) > 0 {
		return raw, nil
	}
	return cbor.Encode(body)
}
