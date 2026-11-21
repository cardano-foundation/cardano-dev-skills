package sdk

import (
	"slices"

	"connectrpc.com/connect"
)

func copyRequestHeaders[T any](
	dst *connect.Request[T],
	src *connect.Request[T],
) {
	for key, values := range src.Header() {
		dst.Header()[key] = slices.Clone(values)
	}
}
