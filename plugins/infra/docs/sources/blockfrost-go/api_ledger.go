package blockfrost

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
)

var (
	resourceGenesis = "genesis"
)

// GenesisBlock contains the information of the genesis block of the network.
type GenesisBlock struct {
	// The proportion of slots in which blocks should be issued
	ActiveSlotsCoefficient float32 `json:"active_slots_coefficient"`

	// Determines the quorum needed for votes on the protocol parameter updates
	UpdateQuorum float32 `json:"update_quorum"`

	// The total number of lovelace in the system
	MaxLovelaceSupply string `json:"max_lovelace_supply"`

	// Network identifier
	NetworkMagic int `json:"network_magic"`

	// Number of slots in an epoch
	EpochLength int `json:"epoch_length"`

	// Time of slot 0 in UNIX time
	SystemStart int `json:"system_start"`

	// Number of slots in an KES period
	SlotsPerKesPeriod int `json:"slots_per_kes_period"`

	// Duration of one slot in seconds
	SlotLength int `json:"slot_length"`

	// The maximum number of time a KES key can be evolved before
	// a pool operator must create a new operational certificate
	MaxKesEvolutions int `json:"max_kes_evolutions"`

	// Security parameter k
	SecurityParam int `json:"security_param"`
}

// Genesis returns the information about blockchain genesis.
func (c *apiClient) Genesis(ctx context.Context) (gen GenesisBlock, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourceGenesis))
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

	if err = json.NewDecoder(res.Body).Decode(&gen); err != nil {
		return
	}
	return gen, nil
}
