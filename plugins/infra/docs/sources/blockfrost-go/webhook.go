package blockfrost

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"
)

type WebhookEventType string

const (
	WebhookEventTypeBlock       WebhookEventType = "block"
	WebhookEventTypeDelegation  WebhookEventType = "delegation"
	WebhookEventTypeEpoch       WebhookEventType = "epoch"
	WebhookEventTypeTransaction WebhookEventType = "transaction"
)

type TransactionPayload struct {
	Tx      TransactionContent  `json:"tx"`
	Inputs  []TransactionInput  `json:"inputs"`
	Outputs []TransactionOutput `json:"outputs"`
}

type StakeDelegationPayload struct {
	Tx          TransactionContent `json:"tx"`
	Delegations []struct {
		TransactionDelegation
		Pool Pool `json:"pool"`
	}
}

type EpochPayload struct {
	PreviousEpoch Epoch `json:"previous_epoch"`
	CurrentEpoch  struct {
		Epoch     int   `json:"epoch"`
		StartTime int64 `json:"start_time"`
		EndTime   int64 `json:"end_time"`
	} `json:"current_epoch"`
}

type WebhookEventCommon struct {
	ID         string `json:"id"`
	WebhookID  string `json:"webhook_id"`
	Created    int    `json:"created"`
	APIVersion int    `json:"api_version,omitempty"` // omitempty because test fixtures do not include it
	Type       string `json:"type"`                  // block, transaction, delegation, epoch
}

type WebhookEventBlock struct {
	WebhookEventCommon
	Payload Block `json:"payload"`
}

type WebhookEventTransaction struct {
	WebhookEventCommon
	Payload []TransactionPayload `json:"payload"`
}

type WebhookEventEpoch struct {
	WebhookEventCommon
	Payload EpochPayload `json:"payload"`
}

type WebhookEventDelegation struct {
	WebhookEventCommon
	Payload []StakeDelegationPayload `json:"payload"`
}

type WebhookEvent struct {
	WebhookEventCommon
}

const (
	// Signatures older than this will be rejected by ConstructEvent
	DefaultTolerance time.Duration = 600 * time.Second
	signingVersion   string        = "v1"
)

var (
	ErrNotSigned        error = errors.New("Missing blockfrost-signature header")
	ErrInvalidHeader    error = errors.New("Invalid blockfrost-signature header format")
	ErrTooOld           error = errors.New("Signature's timestamp is not within time tolerance")
	ErrNoValidSignature error = errors.New("No valid signature")
)

func computeSignature(t time.Time, payload []byte, secret string) []byte {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(fmt.Sprintf("%d", t.Unix())))
	mac.Write([]byte("."))
	mac.Write(payload)
	return mac.Sum(nil)
}

type signedHeader struct {
	timestamp  time.Time
	signatures [][]byte
}

func parseSignatureHeader(header string) (*signedHeader, error) {
	sh := &signedHeader{}

	if header == "" {
		return sh, ErrNotSigned
	}

	// Signed header looks like "t=1495999758,v1=ABC,v1=DEF,v0=GHI"
	pairs := strings.Split(header, ",")
	for _, pair := range pairs {
		parts := strings.Split(pair, "=")
		if len(parts) != 2 {
			return sh, ErrInvalidHeader
		}

		switch parts[0] {
		case "t":
			timestamp, err := strconv.ParseInt(parts[1], 10, 64)
			if err != nil {
				return sh, ErrInvalidHeader
			}
			sh.timestamp = time.Unix(timestamp, 0)

		case signingVersion:
			sig, err := hex.DecodeString(parts[1])
			if err != nil {
				continue // Ignore invalid signatures
			}

			sh.signatures = append(sh.signatures, sig)

		default:
			fmt.Printf("WARNING: Cannot parse part of the signature header, key \"%s\" is not supported by this version of Blockfrost SDK.\n", parts[0])
			continue // Ignore unknown parts of the header
		}
	}

	if len(sh.signatures) == 0 {
		return sh, ErrNoValidSignature
	}

	if sh.timestamp == (time.Time{}) {
		return sh, ErrInvalidHeader

	}

	return sh, nil
}

func VerifyWebhookSignature(payload []byte, header string, secret string) (*WebhookEvent, error) {
	return VerifyWebhookSignatureWithTolerance(payload, header, secret, DefaultTolerance)
}

func VerifyWebhookSignatureWithTolerance(payload []byte, header string, secret string, tolerance time.Duration) (*WebhookEvent, error) {
	return verifyWebhookSignature(payload, header, secret, tolerance, true)
}

func VerifyWebhookSignatureIgnoringTolerance(payload []byte, header string, secret string) (*WebhookEvent, error) {
	return verifyWebhookSignature(payload, header, secret, 0*time.Second, false)
}

func verifyWebhookSignature(payload []byte, sigHeader string, secret string, tolerance time.Duration, enforceTolerance bool) (*WebhookEvent, error) {
	// First unmarshal into a generic map to inspect the type
	var genericEvent map[string]interface{}
	if err := json.Unmarshal(payload, &genericEvent); err != nil {
		return nil, fmt.Errorf("Failed to parse webhook body json: %s", err)
	}

	var event WebhookEvent

	if err := json.Unmarshal(payload, &event); err != nil {
		return nil, fmt.Errorf("Failed to parse specific webhook event json: %s", err)
	}

	header, err := parseSignatureHeader(sigHeader)
	if err != nil {
		return &event, err
	}

	expectedSignature := computeSignature(header.timestamp, payload, secret)
	expiredTimestamp := time.Since(header.timestamp) > tolerance
	if enforceTolerance && expiredTimestamp {
		return &event, ErrTooOld
	}

	for _, sig := range header.signatures {
		if hmac.Equal(expectedSignature, sig) {
			return &event, nil
		}
	}

	return &event, ErrNoValidSignature
}
