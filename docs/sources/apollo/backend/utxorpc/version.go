package utxorpc

import (
	"context"
	"errors"
	"fmt"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/proto"
)

// protoVersion identifies which UTxO RPC proto package a server answers on.
//
// The connect protocol derives the request path from the protobuf package, so
// utxorpc.v1alpha and utxorpc.v1beta are distinct services that a server may
// expose independently. Dolos serves both on the same port, and older
// deployments serve only v1alpha.
type protoVersion int

const (
	// protoVersionUnknown means no call has succeeded yet, so the server's
	// supported version has not been established.
	protoVersionUnknown protoVersion = iota
	protoVersionV1Beta
	protoVersionV1Alpha
)

func (v protoVersion) String() string {
	switch v {
	case protoVersionV1Beta:
		return "v1beta"
	case protoVersionV1Alpha:
		return "v1alpha"
	default:
		return "unknown"
	}
}

// negotiatedVersion returns the version already established for this context,
// or protoVersionUnknown if none has been.
func (u *UtxoRpcChainContext) negotiatedVersion() protoVersion {
	u.versionMu.Lock()
	defer u.versionMu.Unlock()
	return u.version
}

// rememberVersion records the version that answered, so later calls go straight
// to it instead of probing again.
func (u *UtxoRpcChainContext) rememberVersion(v protoVersion) {
	u.versionMu.Lock()
	defer u.versionMu.Unlock()
	u.version = v
}

// isUnimplemented reports whether err means the server does not serve the
// requested service at all.
//
// Only this condition triggers a fallback. A transport failure, timeout,
// cancellation or authentication error says nothing about which proto version
// the server speaks, and retrying those against the other version would both
// double the failure latency and mask the real cause.
func isUnimplemented(err error) bool {
	if err == nil {
		return false
	}
	return connect.CodeOf(err) == connect.CodeUnimplemented
}

// callWithVersionFallback runs a request against v1beta and, only when the
// server reports that service as unimplemented, retries it against v1alpha.
//
// The version that answers is memoized for the lifetime of the chain context,
// so a v1alpha-only server costs one extra round trip on the first call rather
// than on every call.
func callWithVersionFallback[T any](
	ctx context.Context,
	u *UtxoRpcChainContext,
	beta func(context.Context) (T, error),
	alpha func(context.Context) (T, error),
) (T, error) {
	switch u.negotiatedVersion() {
	case protoVersionV1Beta:
		return beta(ctx)
	case protoVersionV1Alpha:
		return alpha(ctx)
	}

	result, betaErr := beta(ctx)
	if betaErr == nil {
		u.rememberVersion(protoVersionV1Beta)
		return result, nil
	}
	if !isUnimplemented(betaErr) {
		// Not a version problem: report it as-is and stay unnegotiated so a
		// later call can still establish the version.
		return result, betaErr
	}

	result, alphaErr := alpha(ctx)
	if alphaErr != nil {
		if isUnimplemented(alphaErr) {
			return result, fmt.Errorf(
				"server implements neither utxorpc.v1beta nor utxorpc.v1alpha: %w",
				alphaErr,
			)
		}
		return result, fmt.Errorf(
			"utxorpc.v1beta unimplemented, and the utxorpc.v1alpha fallback failed: %w",
			alphaErr,
		)
	}
	u.rememberVersion(protoVersionV1Alpha)
	return result, nil
}

// transcode reprojects a v1alpha message onto its v1beta counterpart so the
// conversion helpers in this package only ever read v1beta types.
//
// This is sound because the two proto packages assign the same field numbers to
// every message Apollo reads, which is what protobuf wire compatibility depends
// on; v1beta only adds messages. transcodeGuard pins that property so a future
// divergence fails a test rather than silently dropping fields, and the
// unknown-field check below fails at runtime if a field ever arrives that the
// destination cannot represent.
func transcode(src, dst proto.Message) error {
	encoded, err := proto.Marshal(src)
	if err != nil {
		return fmt.Errorf("failed to encode v1alpha response: %w", err)
	}
	if err := proto.Unmarshal(encoded, dst); err != nil {
		return fmt.Errorf("failed to reproject v1alpha response onto v1beta: %w", err)
	}
	if unknown := dst.ProtoReflect().GetUnknown(); len(unknown) > 0 {
		return fmt.Errorf(
			"v1alpha response carries %d bytes of fields the v1beta message cannot represent; "+
				"the proto packages have diverged",
			len(unknown),
		)
	}
	return nil
}

// transcodeTo converts a v1alpha message into a freshly allocated v1beta
// message of the requested type.
func transcodeTo[T proto.Message](src proto.Message, dst T) (T, error) {
	if src == nil || !src.ProtoReflect().IsValid() {
		var zero T
		return zero, errors.New("empty v1alpha response")
	}
	if err := transcode(src, dst); err != nil {
		var zero T
		return zero, err
	}
	return dst, nil
}
