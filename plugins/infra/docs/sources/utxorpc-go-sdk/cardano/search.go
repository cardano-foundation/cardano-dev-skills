package cardano

import (
	"context"
	"errors"
	"iter"
	"slices"

	"connectrpc.com/connect"
	chaincardano "github.com/utxorpc/go-codegen/utxorpc/v1beta/cardano"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/query"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/fieldmaskpb"
)

const defaultSearchMaxItems int32 = 100

// SearchOption configures pagination and field selection for Cardano UTxO
// search helpers.
type SearchOption func(*query.SearchUtxosRequest)

// WithSearchMaxItems sets the maximum number of UTxOs returned per page.
func WithSearchMaxItems(maxItems int32) SearchOption {
	return func(req *query.SearchUtxosRequest) {
		req.MaxItems = proto.Int32(maxItems)
	}
}

// WithSearchStartToken starts a UTxO search at a token returned by an earlier
// SearchUtxos response.
func WithSearchStartToken(startToken string) SearchOption {
	return func(req *query.SearchUtxosRequest) {
		req.StartToken = proto.String(startToken)
	}
}

// WithSearchFieldMask limits the fields returned for each matching UTxO.
// Passing no paths preserves the existing behavior of requesting all fields.
func WithSearchFieldMask(paths ...string) SearchOption {
	return func(req *query.SearchUtxosRequest) {
		req.FieldMask = &fieldmaskpb.FieldMask{
			Paths: slices.Clone(paths),
		}
	}
}

func newSearchRequest(
	predicate *query.UtxoPredicate,
	options ...SearchOption,
) *query.SearchUtxosRequest {
	req := &query.SearchUtxosRequest{
		Predicate:  predicate,
		FieldMask:  &fieldmaskpb.FieldMask{Paths: []string{}},
		MaxItems:   proto.Int32(defaultSearchMaxItems),
		StartToken: proto.String(""),
	}
	for _, option := range options {
		option(req)
	}
	return req
}

func newAddressSearchRequest(
	address []byte,
	options ...SearchOption,
) *query.SearchUtxosRequest {
	return newSearchRequest(
		&query.UtxoPredicate{
			Match: &query.AnyUtxoPattern{
				UtxoPattern: &query.AnyUtxoPattern_Cardano{
					Cardano: &chaincardano.TxOutputPattern{
						Address: &chaincardano.AddressPattern{
							ExactAddress: address,
						},
					},
				},
			},
		},
		options...,
	)
}

func newAddressAssetSearchRequest(
	addressBytes []byte,
	policyIDBytes []byte,
	assetNameBytes []byte,
	options ...SearchOption,
) *query.SearchUtxosRequest {
	pattern := &chaincardano.TxOutputPattern{
		Address: &chaincardano.AddressPattern{
			ExactAddress: addressBytes,
		},
	}

	switch {
	case len(policyIDBytes) > 0 && len(assetNameBytes) > 0:
		pattern.Asset = &chaincardano.AssetPattern{
			PolicyId:  policyIDBytes,
			AssetName: assetNameBytes,
		}
	case len(policyIDBytes) > 0:
		pattern.Asset = &chaincardano.AssetPattern{
			PolicyId: policyIDBytes,
		}
	case len(assetNameBytes) > 0:
		pattern.Asset = &chaincardano.AssetPattern{
			AssetName: assetNameBytes,
		}
	}

	return newSearchRequest(
		&query.UtxoPredicate{
			Match: &query.AnyUtxoPattern{
				UtxoPattern: &query.AnyUtxoPattern_Cardano{
					Cardano: pattern,
				},
			},
		},
		options...,
	)
}

func newAssetSearchRequest(
	policyIDBytes []byte,
	assetNameBytes []byte,
	options ...SearchOption,
) (*query.SearchUtxosRequest, error) {
	if policyIDBytes == nil && assetNameBytes == nil {
		return nil, errors.New(
			"at least one of policyId or assetName must be provided",
		)
	}

	assetPattern := &chaincardano.AssetPattern{}
	if policyIDBytes != nil {
		assetPattern.PolicyId = policyIDBytes
	}
	if assetNameBytes != nil {
		assetPattern.AssetName = assetNameBytes
	}

	return newSearchRequest(
		&query.UtxoPredicate{
			Match: &query.AnyUtxoPattern{
				UtxoPattern: &query.AnyUtxoPattern_Cardano{
					Cardano: &chaincardano.TxOutputPattern{
						Asset: assetPattern,
					},
				},
			},
		},
		options...,
	), nil
}

// GetUtxosByAddressPages calls
// [Client.GetUtxosByAddressPagesWithContext] with a background context.
func (c *Client) GetUtxosByAddressPages(
	address []byte,
	options ...SearchOption,
) iter.Seq2[*connect.Response[query.SearchUtxosResponse], error] {
	return c.GetUtxosByAddressPagesWithContext(
		context.Background(),
		address,
		options...,
	)
}

// GetUtxosByAddressPagesWithContext lazily returns all SearchUtxos pages for
// an exact Cardano address.
func (c *Client) GetUtxosByAddressPagesWithContext(
	ctx context.Context,
	address []byte,
	options ...SearchOption,
) iter.Seq2[*connect.Response[query.SearchUtxosResponse], error] {
	req := connect.NewRequest(newAddressSearchRequest(address, options...))
	return c.UtxorpcClient.SearchUtxosPagesWithContext(ctx, req)
}

// GetUtxosByAddressWithAssetPages calls
// [Client.GetUtxosByAddressWithAssetPagesWithContext] with a background
// context.
func (c *Client) GetUtxosByAddressWithAssetPages(
	addressBytes []byte,
	policyIDBytes []byte,
	assetNameBytes []byte,
	options ...SearchOption,
) iter.Seq2[*connect.Response[query.SearchUtxosResponse], error] {
	return c.GetUtxosByAddressWithAssetPagesWithContext(
		context.Background(),
		addressBytes,
		policyIDBytes,
		assetNameBytes,
		options...,
	)
}

// GetUtxosByAddressWithAssetPagesWithContext lazily returns all SearchUtxos
// pages for an exact Cardano address and optional native asset.
func (c *Client) GetUtxosByAddressWithAssetPagesWithContext(
	ctx context.Context,
	addressBytes []byte,
	policyIDBytes []byte,
	assetNameBytes []byte,
	options ...SearchOption,
) iter.Seq2[*connect.Response[query.SearchUtxosResponse], error] {
	req := connect.NewRequest(
		newAddressAssetSearchRequest(
			addressBytes,
			policyIDBytes,
			assetNameBytes,
			options...,
		),
	)
	return c.UtxorpcClient.SearchUtxosPagesWithContext(ctx, req)
}

// GetUtxosByAssetPages calls [Client.GetUtxosByAssetPagesWithContext] with a
// background context.
func (c *Client) GetUtxosByAssetPages(
	policyIDBytes []byte,
	assetNameBytes []byte,
	options ...SearchOption,
) iter.Seq2[*connect.Response[query.SearchUtxosResponse], error] {
	return c.GetUtxosByAssetPagesWithContext(
		context.Background(),
		policyIDBytes,
		assetNameBytes,
		options...,
	)
}

// GetUtxosByAssetPagesWithContext lazily returns all SearchUtxos pages for a
// Cardano native asset. Invalid filters are yielded as the sequence's first
// error without making an RPC.
func (c *Client) GetUtxosByAssetPagesWithContext(
	ctx context.Context,
	policyIDBytes []byte,
	assetNameBytes []byte,
	options ...SearchOption,
) iter.Seq2[*connect.Response[query.SearchUtxosResponse], error] {
	req, err := newAssetSearchRequest(
		policyIDBytes,
		assetNameBytes,
		options...,
	)
	if err != nil {
		return func(yield func(
			*connect.Response[query.SearchUtxosResponse],
			error,
		) bool,
		) {
			yield(nil, err)
		}
	}
	return c.UtxorpcClient.SearchUtxosPagesWithContext(
		ctx,
		connect.NewRequest(req),
	)
}
