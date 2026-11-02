package plutusencoder

import (
	"errors"
	"fmt"

	"github.com/blinklabs-io/gouroboros/ledger/common"
)

// decodeConfig carries caller options through one UnmarshalPlutus call.
// Plutus data has no network id, so address decoding needs one from here.
type decodeConfig struct {
	network byte
}

func defaultDecodeConfig() decodeConfig {
	return decodeConfig{network: common.AddressNetworkTestnet}
}

// UnmarshalOption adjusts one UnmarshalPlutus call.
type UnmarshalOption func(*decodeConfig) error

// WithAddressNetwork selects the network byte written into a decoded
// common.Address. Only testnet (0) and mainnet (1) are accepted. The datum
// itself does not contain a network id.
func WithAddressNetwork(network byte) UnmarshalOption {
	return func(cfg *decodeConfig) error {
		if network != common.AddressNetworkTestnet && network != common.AddressNetworkMainnet {
			return fmt.Errorf("address network %d is not testnet (0) or mainnet (1)", network)
		}
		cfg.network = network
		return nil
	}
}

func applyUnmarshalOptions(opts []UnmarshalOption) (decodeConfig, error) {
	cfg := defaultDecodeConfig()
	for _, opt := range opts {
		if opt == nil {
			return decodeConfig{}, errors.New("nil unmarshal option")
		}
		if err := opt(&cfg); err != nil {
			return decodeConfig{}, err
		}
	}
	return cfg, nil
}
