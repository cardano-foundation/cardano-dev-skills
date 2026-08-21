/*
	Package blockfrost is the official BlockFrost SDK for Go.

	Use it to interact with the BlockFrost API.

	Basic Usage
		The first step is to create an API client, providing at minimum the
		project id from blockfrost.io through blockfrost.APIClientOptions{} or
		environment variable BLOCKFROST_PROJECT_ID

		func main() {
			api, err := blockfrost.NewAPIClient(
				blockfrost.APIClientOptions{},
			)
			...
		}

	Examples can be found at
	https://github.com/blockfrost/blockfrost-go/tree/master/example

	If you find an issue with the SDK, please report through
	https://github.com/blockfrost/blockfrost-go/issues/new
*/

package blockfrost
