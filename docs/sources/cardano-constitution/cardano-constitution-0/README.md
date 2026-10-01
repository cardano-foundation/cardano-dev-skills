# Interim Constitution (Cardano Constitution 0)

This *interim* constitution was included within the [genesis files](https://book.world.dev.cardano.org/environments/mainnet/conway-genesis.json) included for Cardano's Conway ledger era.

This constitution came into effect via the Chang hardfork.

## On-chain details

- Constitution URI: <ipfs://bafkreifnwj6zpu3ixa4siz2lndqybyc5wnnt3jkwyutci4e2tmbnj3xrdm>

- Constitution Hash (`BLAKE2b-256`): `ca41a91f399259bcefe57f9858e91f6d00e1a38d6d9c63d4052914ea7bd70cb2`

- Guardrails Script Hash: `fa24fb305126805cf2164c161d852a0e7330cf988f1fe558cf7d4a64`

## Copies of Files

- [Raw document file](./cardano-constitution-0.txt)

- [Document converted to markdown (best for reading)](./cardano-constitution-0.txt.md)

#### Hosted Copies

- Github (this repo): <https://raw.githubusercontent.com/IntersectMBO/cardano-constitution/refs/heads/main/2024-12-05/cardano-constitution-1.txt>

- IPFS with dweb gateway: <https://bafkreifnwj6zpu3ixa4siz2lndqybyc5wnnt3jkwyutci4e2tmbnj3xrdm.ipfs.dweb.link>

- IPFS with ipfs.io gateway: <https://ipfs.io/ipfs/bafkreifnwj6zpu3ixa4siz2lndqybyc5wnnt3jkwyutci4e2tmbnj3xrdm>

- IPFS with web3 storage gateway: <https://bafkreifnwj6zpu3ixa4siz2lndqybyc5wnnt3jkwyutci4e2tmbnj3xrdm.ipfs.w3s.link>

#### How-to Verify the Constitution document hash

#### Using cardano-cli

Using Cardano CLI, pull file from IPFS via the ipfs.io gateway.

```shell
export IPFS_GATEWAY_URI="https://ipfs.io/"
cardano-cli hash anchor-data --url ipfs://bafkreifnwj6zpu3ixa4siz2lndqybyc5wnnt3jkwyutci4e2tmbnj3xrdm
```

Using Cardano CLI, pull file from IPFS via the dweb gateway.

```shell
cardano-cli hash anchor-data --url https://bafkreifnwj6zpu3ixa4siz2lndqybyc5wnnt3jkwyutci4e2tmbnj3xrdm.ipfs.dweb.link
```
