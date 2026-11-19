# Charli3 Oracle ODV Client SDK

Python SDK and CLI for interacting with **Charli3 ODV** multisig oracle networks on **Cardano**.

## Installation

### Requirements

- Python 3.10 or 3.11
- [Poetry](https://python-poetry.org/) (recommended)

### Install with Poetry

```bash
git clone https://github.com/Charli3-Official/charli3-pull-oracle-client.git

cd charli3-pull-oracle-client

poetry install
```

## Configuration
Create a YAML configuration file (config.yaml) with the following structure:

```yaml
network: "testnet"
  ogmios_kupo:
    ogmios_url: "ws://127.0.0.1:1337"
    kupo_url: "http://127.0.0.1:1442"


wallet:
  mnemonic: "$WALLET_MNEMONIC"

oracle_address: "addr_test1..."
policy_id: "abc123..."
odv_validity_length: 120000

nodes:
  - root_url: "https://node1.example.com"
    pub_key: "ed25519_pk1..."
  - root_url: "https://node2.example.com"
    pub_key: "ed25519_pk1..."

tokens:
  reward_token_policy: "def456..."
  reward_token_name: "544f4b454e"
```


## CLI Usage
Validate your configuration:

```bash
charli3 validate-config --config config.yaml
```

Collect feed data from oracle nodes:

```bash
charli3 feeds --config config.yaml --output feeds.json
```

Execute the full aggregation workflow:

```bash
charli3 aggregate --config config.yaml
```

Auto-submit transaction without confirmation prompt:

```bash
charli3 aggregate --config config.yaml --auto-submit
```

Use previously saved feed data:

```bash
charli3 aggregate --config config.yaml --feed-data feeds.json
```


## Programmatic Usage
```python
from charli3_odv_client import ODVClient, ODVClientConfig
from charli3_odv_client.cli.utils.shared import create_chain_query, setup_transaction_builder

# Load configuration
config = ODVClientConfig.from_yaml("config.yaml")

# Initialize components
client = ODVClient()
chain_query = create_chain_query(config)
tx_manager, tx_builder = setup_transaction_builder(config, chain_query)

# Collect feed data
node_messages = await client.collect_feed_updates(
    nodes=config.nodes,
    feed_request=feed_request
)

# Build transaction
odv_result = await tx_builder.build_odv_tx(
    node_messages=node_messages,
    signing_key=signing_key,
    change_address=change_address
)
```


## License

This repository is licensed under the **MIT license**.

### License Rationale

Charli3 uses a combination of OSI-approved open-source licenses, primarily AGPL-3.0 and MIT, depending on the role of each repository within the ecosystem.
Repositories that implement core or protocol-critical logic are licensed under AGPL-3.0 to ensure that improvements and modifications remain transparent and benefit the entire ecosystem, including node operators, developers, and token holders, while maintaining full OSI compliance. This may include both on-chain and select off-chain components where protocol logic and token usage are integral.

Repositories focused on tooling, SDKs, and supporting components are typically licensed under the MIT License to promote broad adoption, flexibility, and ease of integration.

AGPL-3.0 is applied where reciprocal openness is important to protect shared protocol infrastructure, while MIT is used where permissiveness and developer flexibility are the primary goals.

Please refer to each repository’s [LICENSE](LICENSE) file for the specific terms that apply.


## Official Deployments

Charli3 maintains and supports only official deployments that use the $C3 token and unmodified protocol economics.
