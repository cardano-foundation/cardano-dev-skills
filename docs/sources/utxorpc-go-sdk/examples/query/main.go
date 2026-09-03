package main

import (
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"net"
	"os"

	"connectrpc.com/connect"
	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/cardano"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/query"
	"github.com/utxorpc/go-sdk"
	utxorpc "github.com/utxorpc/go-sdk/cardano"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/fieldmaskpb"
)

func main() {
	baseUrl := os.Getenv("UTXORPC_URL")
	if baseUrl == "" {
		baseUrl = "https://preview.utxorpc-v0.demeter.run"
	}
	client := utxorpc.NewClient(sdk.WithBaseUrl(baseUrl))
	dmtrApiKey := os.Getenv("DMTR_API_KEY")
	// set API key for demeter
	if dmtrApiKey != "" {
		client.UtxorpcClient.SetHeader("dmtr-api-key", dmtrApiKey)
	}

	fmt.Println("Connecting to utxorpc host:", client.UtxorpcClient.URL())
	fmt.Println()

	// Run them all
	readParams(client)
	fmt.Println()
	readEraSummary(client)
	fmt.Println()
	readGenesis(client)
	fmt.Println()
	readUtxo(
		client,
		"24efe5f12d1d93bb419cfb84338d6602dfe78c614b489edb72df0594a077431c",
		0,
	)
	fmt.Println()
	// everything on address
	getUtxosByAddress(
		client,
		"addr_test1qptfy9zhaeuqfptcu79q6gm9l3r6cfp5gnlqc7m42qwln0lsvex239qmryg4yh3pda3rh3rnce4wd46gdyqlscrq7s4shekqrt",
	)
	fmt.Println()
	// https://preprod.cexplorer.io/asset/asset1tvkt35str8aeepuflxmnjzcdj87em8xrlx4ehz
	// Use policy ID and asset name in hex format (https://cips.cardano.org/cip/CIP-68/)
	// Hunt
	searchUtxos(
		client,
		"addr_test1qptfy9zhaeuqfptcu79q6gm9l3r6cfp5gnlqc7m42qwln0lsvex239qmryg4yh3pda3rh3rnce4wd46gdyqlscrq7s4shekqrt",
		"63f9a5fc96d4f87026e97af4569975016b50eef092a46859b61898e5",
		"0014df1048554e54",
	)
	fmt.Println()
	// Dedi
	searchUtxos(
		client,
		"addr_test1qptfy9zhaeuqfptcu79q6gm9l3r6cfp5gnlqc7m42qwln0lsvex239qmryg4yh3pda3rh3rnce4wd46gdyqlscrq7s4shekqrt",
		"63f9a5fc96d4f87026e97af4569975016b50eef092a46859b61898e5",
		"0014df1044454449",
	)
	fmt.Println()
	// No assets
	searchUtxos(
		client,
		"addr_test1qzrkvcfvd7k5jx54xxkz87p8xn88304jd2g4jsa0hwwmg20k3c7k36lsg8rdupz6e36j5ctzs6lzjymc9vw7djrmgdnqff9z6j",
		"63f9a5fc96d4f87026e97af4569975016b50eef092a46859b61898e5",
		"0014df1044454449",
	)
	fmt.Println()
}

func readParams(client *utxorpc.Client) {
	fmt.Println("getting protocol parameters")
	resp, err := client.GetProtocolParameters()
	if err != nil {
		reportError(err)
		return
	}

	// Uncomment to print the full response for debugging
	// fmt.Printf("Response: %+v\n", resp)

	if resp.Msg.GetLedgerTip() != nil {
		fmt.Printf(
			"Ledger Tip: Slot: %d, Hash: %x\n",
			resp.Msg.GetLedgerTip().GetSlot(),
			resp.Msg.GetLedgerTip().GetHash(),
		)
	}
	if resp.Msg.GetValues() != nil {
		fmt.Printf("Cardano: %+v\n", resp.Msg.GetValues())
	}
}

func readEraSummary(client *utxorpc.Client) {
	fmt.Println("getting era summary")
	req := &query.ReadEraSummaryRequest{
		FieldMask: &fieldmaskpb.FieldMask{Paths: []string{}},
	}
	resp, err := client.UtxorpcClient.ReadEraSummary(connect.NewRequest(req))
	if err != nil {
		reportError(err)
		return
	}
	fmt.Printf("Era Summary Response: %+v\n", resp.Msg)

	if cardanoSummary := resp.Msg.GetCardano(); cardanoSummary != nil {
		for _, summary := range cardanoSummary.GetSummaries() {
			fmt.Printf("Era: %s\n", summary.GetName())
			fmt.Printf("  Start: %s\n", formatEraBoundary(summary.GetStart()))
			fmt.Printf("  End: %s\n", formatEraBoundary(summary.GetEnd()))
		}
	} else {
		fmt.Println("No Cardano era summary returned")
	}
}

func formatEraBoundary(boundary *cardano.EraBoundary) string {
	if boundary == nil {
		return "n/a"
	}
	return fmt.Sprintf(
		"slot=%d epoch=%d time_ms=%d",
		boundary.GetSlot(),
		boundary.GetEpoch(),
		boundary.GetTime(),
	)
}

func readGenesis(client *utxorpc.Client) {
	fmt.Println("getting genesis config")
	req := &query.ReadGenesisRequest{
		FieldMask: &fieldmaskpb.FieldMask{
			Paths: []string{
				// "cardano",
			},
		},
	}
	resp, err := client.UtxorpcClient.ReadGenesis(connect.NewRequest(req))
	if err != nil {
		reportError(err)
		return
	}

	if resp.Msg.GetGenesis() != nil {
		fmt.Printf("Genesis Hash: %x\n", resp.Msg.GetGenesis())
	}
	if cardanoGenesis := resp.Msg.GetCardano(); cardanoGenesis != nil {
		fmt.Printf("Cardano Genesis: %+v\n", cardanoGenesis)
		fmt.Printf("Cardano Network ID: %s\n", cardanoGenesis.GetNetworkId())
		fmt.Printf("Cardano Network Magic: %d\n", cardanoGenesis.GetNetworkMagic())
		fmt.Printf("Cardano Epoch Length: %d\n", cardanoGenesis.GetEpochLength())
		fmt.Printf("Cardano Slot Length (ms): %d\n", cardanoGenesis.GetSlotLength())
		fmt.Printf("Cardano System Start: %s\n", cardanoGenesis.GetSystemStart())
	}
}

func readUtxo(
	client *utxorpc.Client,
	txHashStr string,
	txIndex uint32,
) {
	fmt.Println("getting utxo by reference")
	resp, err := client.GetUtxoByRef(txHashStr, txIndex)
	if err != nil {
		reportError(err)
		return
	}

	// Uncomment to print the full response for debugging
	// fmt.Printf("Response: %+v\n", resp)

	if resp.Msg.GetLedgerTip() != nil {
		fmt.Printf(
			"Ledger Tip:\n  Slot: %d\n  Hash: %x\n",
			resp.Msg.GetLedgerTip().GetSlot(),
			resp.Msg.GetLedgerTip().GetHash(),
		)
	}

	for _, item := range resp.Msg.GetItems() {
		fmt.Println("UTxO Data:")
		fmt.Printf("  Tx Hash: %x\n", item.GetTxoRef().GetHash())
		fmt.Printf("  Output Index: %d\n", item.GetTxoRef().GetIndex())
		fmt.Printf("  Native Bytes: %x\n", item.GetNativeBytes())
		if cardano := item.GetCardano(); cardano != nil {
			fmt.Println("  Cardano UTxO:")
			fmt.Printf("    Address: %x\n", cardano.GetAddress())
			fmt.Printf("    Coin: %v\n", cardano.GetCoin())
			if cardano.GetDatum() != nil {
				fmt.Printf("    Datum Hash: %x\n", cardano.GetDatum().GetHash())
			}
		}
	}
}

func searchUtxos(
	client *utxorpc.Client,
	rawAddress string,
	policyID string,
	assetName string,
) {
	// Use to support bech32/base58 addresses
	addr, err := common.NewAddress(rawAddress)
	if err != nil {
		log.Fatalf("failed to create address: %v", err)
	}
	addrCbor, err := addr.Bytes()
	if err != nil {
		log.Fatalf("failed to convert address: %v", err)
	}

	var txOutputPattern *cardano.TxOutputPattern
	if policyID != "" && assetName != "" {
		// Convert policyID from hex to bytes
		policyIDBytes, err := hex.DecodeString(policyID)
		if err != nil {
			log.Fatalf("failed to decode policy ID: %v", err)
		}

		// Convert assetName to bytes
		assetNameBytes, err := hex.DecodeString(assetName)
		if err != nil {
			log.Fatalf("failed to decode asset name: %v", err)
		}

		// Define the asset pattern with policy ID and asset name
		assetPattern := &cardano.AssetPattern{
			PolicyId:  policyIDBytes,
			AssetName: assetNameBytes,
		}

		// Define the TxOutput pattern including the asset filter
		txOutputPattern = &cardano.TxOutputPattern{
			Address: &cardano.AddressPattern{
				ExactAddress: addrCbor,
			},
			Asset: assetPattern,
		}
	} else {
		// Define the TxOutput pattern with only the address filter
		txOutputPattern = &cardano.TxOutputPattern{
			Address: &cardano.AddressPattern{
				ExactAddress: addrCbor,
			},
		}
	}

	// Wrap the TxOutput pattern in AnyUtxoPattern for Cardano
	anyUtxoPattern := &query.AnyUtxoPattern{
		UtxoPattern: &query.AnyUtxoPattern_Cardano{
			Cardano: txOutputPattern,
		},
	}

	// Define the UtxoPredicate with the pattern
	utxoPredicate := &query.UtxoPredicate{
		Match: anyUtxoPattern,
	}

	// Define the field mask
	fieldMask := &fieldmaskpb.FieldMask{
		Paths: []string{
			// "native_bytes",
		},
	}

	// Prepare the search request
	searchRequest := &query.SearchUtxosRequest{
		Predicate:  utxoPredicate,
		FieldMask:  fieldMask,
		MaxItems:   proto.Int32(100), // Adjust based on your requirements
		StartToken: proto.String(""), // For pagination; empty for the first page
	}

	fmt.Printf("searching utxos: address: %s, policy: %s, asset: %s\n", rawAddress, policyID, assetName)
	resp, err := client.UtxorpcClient.SearchUtxos(connect.NewRequest(searchRequest))
	if err != nil {
		reportError(err)
		return
	}

	// Uncomment to print the full response for debugging
	// fmt.Printf("Response: %+v\n", resp)

	if resp.Msg.GetLedgerTip() != nil {
		fmt.Printf(
			"Ledger Tip:\n  Slot: %d\n  Hash: %x\n",
			resp.Msg.GetLedgerTip().GetSlot(),
			resp.Msg.GetLedgerTip().GetHash(),
		)
	}

	for _, item := range resp.Msg.GetItems() {
		fmt.Println("UTxO Data:")
		fmt.Printf("  Tx Hash: %x\n", item.GetTxoRef().GetHash())
		fmt.Printf("  Output Index: %d\n", item.GetTxoRef().GetIndex())
		fmt.Printf("  Native Bytes: %x\n", item.GetNativeBytes())
		if cardano := item.GetCardano(); cardano != nil {
			fmt.Println("  Cardano UTxO:")
			fmt.Printf("    Address: %x\n", cardano.GetAddress())
			fmt.Printf("    Coin: %v\n", cardano.GetCoin())
			fmt.Println("    Assets:")
			for _, multiasset := range cardano.GetAssets() {
				fmt.Printf("      Policy ID: %x\n", multiasset.GetPolicyId())
				for _, asset := range multiasset.GetAssets() {
					fmt.Printf(
						"        Asset Name: %s\n",
						string(asset.GetName()),
					)
					fmt.Printf(
						"        Quantity: %v\n",
						asset.GetQuantity(),
					)
				}
			}
		}
	}
}

func getUtxosByAddress(
	client *utxorpc.Client,
	rawAddress string,
) {
	// Use to support bech32/base58 addresses
	addr, err := common.NewAddress(rawAddress)
	if err != nil {
		log.Fatalf("failed to create address: %v", err)
	}
	addrCbor, err := addr.Bytes()
	if err != nil {
		log.Fatalf("failed to convert address: %v", err)
	}

	fmt.Printf("searching utxos: address: %s\n", rawAddress)
	resp, err := client.GetUtxosByAddress(addrCbor)
	if err != nil {
		reportError(err)
		return
	}

	// Uncomment to print the full response for debugging
	// fmt.Printf("Response: %+v\n", resp)

	if resp.Msg.GetLedgerTip() != nil {
		fmt.Printf(
			"Ledger Tip:\n  Slot: %d\n  Hash: %x\n",
			resp.Msg.GetLedgerTip().GetSlot(),
			resp.Msg.GetLedgerTip().GetHash(),
		)
	}

	for _, item := range resp.Msg.GetItems() {
		fmt.Println("UTxO Data:")
		fmt.Printf("  Tx Hash: %x\n", item.GetTxoRef().GetHash())
		fmt.Printf("  Output Index: %d\n", item.GetTxoRef().GetIndex())
		fmt.Printf("  Native Bytes: %x\n", item.GetNativeBytes())
		if cardano := item.GetCardano(); cardano != nil {
			fmt.Println("  Cardano UTxO:")
			fmt.Printf("    Address: %x\n", cardano.GetAddress())
			fmt.Printf("    Coin: %v\n", cardano.GetCoin())
			fmt.Println("    Assets:")
			for _, multiasset := range cardano.GetAssets() {
				fmt.Printf("      Policy ID: %x\n", multiasset.GetPolicyId())
				for _, asset := range multiasset.GetAssets() {
					fmt.Printf(
						"        Asset Name: %s\n",
						string(asset.GetName()),
					)
					fmt.Printf(
						"        Quantity: %v\n",
						asset.GetQuantity(),
					)
				}
			}
		}
	}
}

func reportError(err error) {
	var transportErr net.Error
	if errors.As(err, &transportErr) {
		fmt.Printf("transport error: %v\n", transportErr)
		return
	}
	if connectErr, ok := sdk.AsConnectError(err); ok {
		fmt.Printf(
			"RPC error: code=%s message=%q metadata=%v details=%v\n",
			connectErr.Code(),
			connectErr.Message(),
			connectErr.Meta(),
			connectErr.Details(),
		)
		return
	}
	fmt.Printf("local error: %v\n", err)
}
