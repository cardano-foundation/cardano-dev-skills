package localeval

import (
	"errors"
	"fmt"
	"math"
	"time"
)

// SlotConfig converts slot numbers to wall-clock time for a transaction's
// validity interval. Scripts see the interval as POSIX times, so evaluation
// needs this mapping whenever a transaction sets either bound.
//
// The mapping is linear from ZeroSlot onward, which matches every network
// from the start of its Shelley era. Slots before ZeroSlot are rejected.
type SlotConfig struct {
	// ZeroTime is the start of ZeroSlot.
	ZeroTime time.Time
	// ZeroSlot is the first slot the linear mapping covers.
	ZeroSlot uint64
	// SlotLength is the duration of every slot from ZeroSlot onward.
	SlotLength time.Duration
}

// The public networks' Shelley-era slot configurations. Mainnet and preprod
// began with a Byron era of 20-second slots, so their linear mappings start
// at the first Shelley slot rather than at the system start.
var (
	MainnetSlotConfig = SlotConfig{
		ZeroTime:   time.Unix(1596059091, 0).UTC(),
		ZeroSlot:   4492800,
		SlotLength: time.Second,
	}
	PreprodSlotConfig = SlotConfig{
		ZeroTime:   time.Unix(1655769600, 0).UTC(),
		ZeroSlot:   86400,
		SlotLength: time.Second,
	}
	PreviewSlotConfig = SlotConfig{
		ZeroTime:   time.Unix(1666656000, 0).UTC(),
		ZeroSlot:   0,
		SlotLength: time.Second,
	}
)

// Network magics of the public networks.
const (
	MainnetNetworkMagic = 764824073
	PreprodNetworkMagic = 1
	PreviewNetworkMagic = 2
)

// SlotConfigForNetworkMagic returns the slot configuration of a public
// network, or false for any other network magic.
func SlotConfigForNetworkMagic(magic uint32) (SlotConfig, bool) {
	switch magic {
	case MainnetNetworkMagic:
		return MainnetSlotConfig, true
	case PreprodNetworkMagic:
		return PreprodSlotConfig, true
	case PreviewNetworkMagic:
		return PreviewSlotConfig, true
	default:
		return SlotConfig{}, false
	}
}

func (c SlotConfig) validate() error {
	if c.ZeroTime.IsZero() {
		return errors.New("slot config has no zero time")
	}
	if c.SlotLength <= 0 {
		return errors.New("slot config slot length must be positive")
	}
	return nil
}

// SlotToTime returns the start of slot.
func (c SlotConfig) SlotToTime(slot uint64) (time.Time, error) {
	if err := c.validate(); err != nil {
		return time.Time{}, err
	}
	if slot < c.ZeroSlot {
		return time.Time{}, fmt.Errorf(
			"slot %d precedes the slot config's zero slot %d",
			slot,
			c.ZeroSlot,
		)
	}
	elapsed := slot - c.ZeroSlot
	if elapsed > math.MaxInt64 {
		return time.Time{}, fmt.Errorf("slot %d is out of range", slot)
	}
	offset := time.Duration(elapsed) //nolint:gosec // checked against MaxInt64 above
	if offset > math.MaxInt64/c.SlotLength {
		return time.Time{}, fmt.Errorf("slot %d is out of range", slot)
	}
	return c.ZeroTime.Add(offset * c.SlotLength), nil
}

// TimeToSlot returns the slot containing t.
func (c SlotConfig) TimeToSlot(t time.Time) (uint64, error) {
	if err := c.validate(); err != nil {
		return 0, err
	}
	if t.Before(c.ZeroTime) {
		return 0, fmt.Errorf(
			"time %s precedes the slot config's zero time %s",
			t.UTC().Format(time.RFC3339),
			c.ZeroTime.UTC().Format(time.RFC3339),
		)
	}
	elapsed := t.Sub(c.ZeroTime)
	if elapsed == math.MaxInt64 {
		return 0, fmt.Errorf("time %s is out of range", t.UTC().Format(time.RFC3339))
	}
	slots := uint64(elapsed / c.SlotLength) //nolint:gosec // elapsed is non-negative
	if slots > math.MaxUint64-c.ZeroSlot {
		return 0, fmt.Errorf("time %s is out of range", t.UTC().Format(time.RFC3339))
	}
	return c.ZeroSlot + slots, nil
}
