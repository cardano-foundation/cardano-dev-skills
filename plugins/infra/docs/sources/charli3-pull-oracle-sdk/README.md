# ODV Multisig Charli3 Offchain Core

Core off-chain infrastructure for Charli3's Oracle Data Verification (ODV) system with multisig capabilities. This package provides comprehensive tooling for oracle operations, contract interactions, and blockchain integration.

## 🌟 Features

- **Oracle Data Verification (ODV)**
  - Aggregation of oracle data
  - Multi-signature validation
  - Reward distribution management
  - Oracle node operations
  - Oracle lifecycle management (Multisig Support)
    - Oracle pause
    - Oracle resume
    - Oracle removing
- **Smart Contract Integration**
  - Aiken blueprint parsing and handling
  - Plutus script management
  - Transaction building and validation

- **Blockchain Operations**
  - Chain state queries through Blockfrost or Kupo/Ogmios
  - Transaction validation and monitoring
  - Reference script management

## 📦 Installation & Setup

1. Clone the repository:
```bash
git clone https://github.com/Charli3-Official/charli3-pull-oracle-sdk
cd charli3-pull-oracle-sdk
```

2. Install dependencies using Poetry:
```bash
poetry install
```

3. Set up pre-commit hooks (recommended for development):
```bash
poetry run pre-commit install
```

## 🚀 Quick Start

### Multisig Platform Auth NFT Mint

#### Configure multisig settings in yaml:
Reference: configuration file (e.g., `deploy-testnet.yaml`):
```yaml
multisig:
  # platform_addr: "addr_test1..."
  threshold: 2  # Required signatures
  parties:
    - "wallet1_public_key_hash"
    - "wallet2_public_key_hash"
```

#### Option 1. Single Signature Flow (threshold = 1)
```bash
# Complete flow in single command
# - Builds transaction
# - Signs with configured wallet
# - Submits to network immediately
# - Returns tx ID and policy ID
charli3 platform token mint --config deploy-testnet.yaml
```

#### Option 2.  Multi-Signature Flow (threshold > 1)
```bash
# 1. First Wallet: Build and optionally sign
# - Creates transaction
# - Prompts to sign with current wallet
# - Generates tx_platform_mint.json
charli3 platform token mint --config deploy-testnet-wallet-1.yaml

# 2. Second Wallet: Add signature
# - Validates key hasn't signed
# - Updates transaction file
# - Shows signature progress
charli3 platform token sign-tx --config deploy-testnet-wallet-2.yaml --tx-file tx_platform_mint.json

# 3. Submit when all signatures collected
# - Validates signature threshold
# - Submits to network
# - Returns tx ID and policy ID
charli3 platform token submit-tx --config deploy-testnet-wallet-2.yaml --tx-file tx_platform_mint.json
```


### Basic Oracle Deployment

1. Create a deployment configuration file (e.g., `deploy-testnet.yaml`):
```yaml
network:
  network: "testnet"
  blockfrost:
    project_id: "your-project-id"
  wallet:
    mnemonic: "your 24 word mnemonic"
    # OR use key files:
    # payment_skey_path: "path/to/payment.skey"
    # payment_vkey_path: "path/to/payment.vkey"
    # stake_vkey_path: "path/to/stake.vkey"

addresses:
  admin_address: "addr_test..."  # Address for reference scripts
  script_address: "addr_test..."     # Address for oracle UTxOs

tokens:
  platform_auth_policy: "hex_policy_id_for_platform_auth_nft"
  reward_token_policy: "hex_policy_id_for_reward_token"
  reward_token_name: "hex_asset_name_for_reward_token"

  rate_token_policy: "hex_policy_id_for_rate_token"
  rate_token_name: "hex_asset_name_for_rate_token"
fees:
  node_fee: 1000000      # 1 ADA
  platform_fee: 500000   # 0.5 ADA

timing:
  pause_period: 3600000        # 1 hour in ms
  reward_dismissing_period: 7200000  # 2 hours in ms
  aggregation_liveness: 300000   # 5 minutes in ms
  time_uncertainty_aggregation: 120000 # 2 minutes in ms
  time_uncertainty_platform: 180000 # 3 minutes in ms
  iqr_multiplier: 150           # 1.5x

transport_count: 4  # Number of reward transport UTxOs
blueprint_path: "artifacts/plutus.json"  # Path to Aiken blueprint

nodes:
  nodes:
  - feed_vkh: 007df380aef26e44739db3f4fe67d8137446e630dab3df16d9fbddc5
    payment_vkh: b296714efefe2d991bb7eb002b48b024d1a152691c6fe9e0f76511c5
  - feed_vkh: 018ab1dd5f33ca2e0ae6ccb694ea379d841bf5f4d2d5756452a2117d
    payment_vkh: e12ee69ac72fff83a39d690830595cf11ca5a2f0d2d69b3f859f8f43
  - feed_vkh: e47c436dbd0d1f7642ce2f4a8e36c4facae2b8d9d4c3267380cb1f5f
    payment_vkh: 13bc38b4b81d4b942fc61be4533a165d837db56bedaf1a991e90fcdf
  - feed_vkh: db4d690afb9f75d0a4ce983b41349220f9d0b4ada424f3d625963f85
    payment_vkh: aed02a7e20098dc1415f669a1816473650b295136ff0fc0f9a09be0c
  required_signatures: 4
```

2. Deploy the oracle based on your platform auth NFT configuration:

#### Option 1: Single-Signature Deployment (threshold = 1)
```bash
# Complete flow in single command when platform auth NFT only requires one signature
charli3 oracle deploy --config deploy-testnet.yaml
```

#### Option 2: Multi-Signature Deployment (threshold > 1)
```bash
# 1. First Wallet: Build transaction
# - Creates deployment transaction
# - Generates tx_oracle_deploy.json
charli3 oracle deploy --config deploy-testnet-wallet-1.yaml

# 2. Additional Wallets: Add signatures
# - Validates key hasn't signed
# - Updates transaction file
# - Shows signature progress
charli3 oracle sign-tx --config deploy-testnet-wallet-2.yaml --tx-file tx_oracle_deploy.json

# 3. Submit when signature threshold is met
# - Validates all required signatures are present
# - Submits deployment transaction to network
# - Shows deployment status and script address
charli3 oracle submit-tx --config deploy-testnet.yaml --tx-file tx_oracle_deploy.json
```
## Aggregate Transactions
### Aggregate and Rewards Calculate

1. Create transaction config (tx_config.yml):
```yaml
network:
  network: "TESTNET"
  ogmios_kupo:
    ogmios_url: "ws://localhost:1337"
    kupo_url: "http://localhost:1442"

oracle_address: "addr_test1..."
policy_id: "1234..."

tokens:
  reward_token_policy: "hex_policy_id_here"
  reward_token_name: "hex_token_name_here"

  rate_token_policy: "hex_policy_id_here"
  rate_token_name: "hex_token_name_here"

wallet:
  mnemonic: "your 24 word mnemonic"
```

2. Prepare feed data (feeds.json):
```json
{
  "node_feeds_sorted_by_feed": {
    "007df380aef26e44739db3f4fe67d8137446e630dab3df16d9fbddc5": 1000,
    "018ab1dd5f33ca2e0ae6ccb694ea379d841bf5f4d2d5756452a2117d": 1001,
    "e47c436dbd0d1f7642ce2f4a8e36c4facae2b8d9d4c3267380cb1f5f": 1001
  },
  "node_feeds_count": 3,
  "timestamp": 1734363765000
}
```

3. Submit ODV transaction:
```bash
charli3 aggregate-tx odv-aggregate submit \
  --config tx_config.yml \
  --feeds-file feeds.json \
  --node-keys-dir node_keys
```

4. Process rewards:
```bash
charli3 aggregate-tx rewards process \
  --config tx_config.yml
```

### Simulation of Aggregate and Rewards Calculate

For testing purposes:

1. Create simulation config (sim_config.yml):
```yaml
# Include standard transaction config
...

simulation:
  node_keys_dir: "node_keys"
  base_feed: 100
  variance: 0.02
  wait_time: 60
```

2. Run simulation:
```bash
charli3 simulator run \
  --config tx_config.yml
```

For detailed informations, see [Aggregate Transactions](docs/oracle_aggregate_tx_cli.md)

### Simulation of ODV aggregation request-response client flow

Configuration process is the same as for Transaction Configuration (tx_config.yml), see [Aggregate Transactions](docs/oracle_aggregate_tx_cli.md),
but with these new fields added:

1. Create odv-client config (tx_config.yml):

```yaml
# Include standard transaction config
...

# This is odv request validity window length, should be <= time_uncertainty_aggregation
odv_validity_length: 180000 # milliseconds

# Nodes network identifiers root url (or ip address) and public key converted to cbor hex
nodes:
  - root_url: "http://0.0.0.0:8000"
    pub_key: "58203565c563de4e55714aa9e0280a8cd4a4271ef8c8a261955446cc7b830021aef8"
  - root_url: "http://0.0.0.0:8001"
    pub_key: "5820f5ca5b53826d2be8b5ab5505c15dd10a498e6d1eee540ded51d52eb7083979f3"

```

2. Run client simulation:

```bash
charli3 client send \
  --config tx_config.yml
```

This will send requests to the oracle nodes and complete odv flow in two steps:

1. Send odv message request, when nodes sign a message containing node feed and timestamp;
2. Send odv tx request, when nodes sign transaction constructed with messages supplied on the first step.

##  Governance Operations
### Update Oracle Settings

This transaction allows you to modify the following settings:

1. **Aggregation Liveness Period**
2. **Time Absolute Uncertainty**
3. **IQR Fence Multiplier**
4. **UTxO Size Safety Buffer**
5. **Required Node Signature Count**

Command: `charli3 oracle update-settings --config testnet.yaml`

### Add Nodes

The command compares the node list in the config file, and if any changes are detected (new nodes), it proceeds to add them. The built-in menu helps users identify the required validations.

Command: `charli3 oracle add-nodes --config testnet.yaml`
### Remove Nodes

This command manages node removal from the contract configuration:

1. Removes nodes listed in the config file from the contract's existing node list
2. If nodes are found, they are removed from the configuration

Payment handling differs based on the reward type:
- For CNT rewards: Payments are sent to an escrow contract where operators must withdraw them and pay back the associated minimum UTxO
- For ADA rewards: Payments are sent directly to the operators' payment verification keys

Command: `charli3 oracle del-nodes --config testnet.yaml`

### Oracle Scaling Operations

You can adjust the Oracle Data Verification (ODV) capacity by scaling up (adding new UTxO pairs) or scaling down (removing unused UTxO pairs).

#### Scale Up

Increase ODV capacity by creating new pairs of RewardTransport and AggregationState UTxOs.

Command:
```bash
charli3 oracle scale-up --config deploy-testnet.yaml --amount 2
```

#### Scale Down

Decrease ODV capacity by removing empty UTxO pairs and burning tokens.

Command:
```bash
charli3 oracle scale-down --config deploy-testnet.yaml --amount 2
```
**Note:** When scaling down, only empty transport UTxOs and empty/expired aggregation state UTxOs will be removed. The system will validate that there are enough eligible UTxOs before building the transaction.

## Rewards Operations
### Node Collect
This command provides a guided process for Node Operators to withdraw their accumulated rewards.  Node Operators must provide their payment verification key hash (VKH) to authenticate and initiate the withdrawal. The tool then allows the selection of a  withdrawal address, either a derived enterprise address or a user-specified address. Finally, it constructs the necessary transaction to withdraw the rewards, supporting both ADA and any token as reward currencies.

Command: `charli3 oracle node-collect --config testnet.yaml`

### Platform Collect
To withdraw accumulated rewards, platform operators must use this command to specify the destination address and confirm the withdrawal amount. The command then constructs and executes the withdrawal transaction after validating the safety buffer.

Command: `charli3 oracle platform-collect --config testnet.yaml`

### Dismiss Rewards (Platform)
  This command collects all rewards from reward transport UTxOs once the dismissal period for rewards has been completed. Batching of multiple reward transport UTxOs is possible

Command: `charli3 oracle dismiss-rewards --batch-size N --config testnet.yaml`

### Oracle Pause

#### Option 1: Single Signature Flow (threshold = 1)
```bash
# Complete flow in single command
# - Builds pause transaction
# - Signs with configured wallet
# - Submits to network immediately
charli3 oracle pause --config deploy-testnet.yaml
```

#### Option 2: Multi-Signature Flow (threshold > 1)
```bash
# 1. First Wallet: Build transaction
# - Creates pause transaction
# - Generates tx_oracle_pause.json
charli3 oracle pause --config deploy-testnet-wallet-1.yaml

# 2. Additional Wallets: Add signatures
# - Validates key hasn't signed
# - Updates transaction file
# - Shows signature progress
charli3 oracle sign-tx --config deploy-testnet-wallet-2.yaml --tx-file tx_oracle_pause.json

# 3. Submit when signature threshold is met
# - Validates all required signatures are present
# - Submits pause transaction to network
charli3 oracle submit-tx --config deploy-testnet.yaml --tx-file tx_oracle_pause.json
```

### Oracle Removing

#### Option 1: Single Signature Flow (threshold = 1)
```bash
# Builds and submits a removal transaction to burn all associated NFTs or a specified number of pairs.
# - For single signature (threshold = 1), signs and submits immediately.
# - For multi-signature (threshold > 1), generates tx_oracle_remove.json for signing.
#
# Optional: Specify the number of AggState and Reward Transport NFT pairs to burn using [--pair-count <number_of_pairs>]
charli3 oracle remove --config deploy-testnet.yaml [--pair-count <number_of_pairs>]
```

*Note: If `--pair-count` is omitted, all associated NFTs will be burned.*

#### Option 2: Multi-Signature Flow (threshold > 1)
```bash
# 1. Additional Wallets: Add signatures
# - Validates key hasn't signed
# - Updates transaction file
# - Shows signature progress
charli3 oracle sign-tx --config deploy-testnet-wallet-2.yaml --tx-file tx_oracle_remove.json

# 2. Submit when signature threshold is met
# - Validates all required signatures are present
# - Submits removal transaction to network
charli3 oracle submit-tx --config deploy-testnet.yaml --tx-file tx_oracle_remove.json
```

### Oracle Resuming

You can resume a paused oracle instance using the following commands:

#### Option 1: Single Signature Flow (threshold = 1)
```bash
# Complete flow in single command
# - Builds resume transaction
# - Signs with configured wallet
# - Submits to network immediately
charli3 oracle resume --config deploy-testnet.yaml
```

#### Option 2: Multi-Signature Flow (threshold > 1)
```bash
# 1. First Wallet: Build transaction
# - Creates resume transaction
# - Generates tx_oracle_resume.json
charli3 oracle resume --config deploy-testnet-wallet-1.yaml

# 2. Additional Wallets: Add signatures
# - Validates key hasn't signed
# - Updates transaction file
# - Shows signature progress
charli3 oracle sign-tx --config deploy-testnet-wallet-2.yaml --tx-file tx_oracle_resume.json

# 3. Submit when signature threshold is met
# - Validates all required signatures are present
# - Submits resume transaction to network
charli3 oracle submit-tx --config deploy-testnet.yaml --tx-file tx_oracle_resume.json
```

### Reference Scripts Management

Create reference scripts separately:
```bash
poetry run charli3 oracle create-reference-scripts \
    --config deploy-testnet.yaml \
    --manager \
    --nft
```

## Reward Escrow contract management

Managing reward script is easy, we only need to create a reference script for it.
Locking rewards inside the escrow script is a part of delete-nodes tx, while spending the escrow script is a part of reward-collect for the nodes/platform.

The following command will:

- Lookup the existing reference script utxos;
- Interactively create the reference script.

```bash
charli3 escrow create-reference-script --config deploy-testnet.yaml
```

Configuration for this command builds on the previous oracle configuration (see [guide](#configuration-guide)) by reusing network, wallet and blueprint config.
A new field `reference_script_addr` is added to configure which address is used for locking the reference script utxo.

## 📖 Documentation

### Configuration Guide

The deployment configuration supports multiple options and backends:

1. **Network Configuration**
   - Support for Mainnet and Testnet
   - Choose between Blockfrost or Kupo/Ogmios backends
   - Wallet configuration through mnemonic or key files

2. **Address Configuration**
   - Reference address for storing reference scripts
   - Script address for oracle UTxOs

3. **Token Configuration**
   - Platform authorization NFT policy ID
   - Fee token specifications
   - Configurable token names for oracle NFTs

4. **Timing Parameters**
   - Pause period length
   - Reward dismissing period
   - Aggregation liveness period
   - Time uncertainty handling
   - IQR fence multiplier for outlier detection

For detailed configuration options, see [Configuration Guide](docs/configuration.md).

### Deployment Process

The oracle deployment process consists of several steps:

1. **Reference Script Creation**
   - Oracle manager script (reusable across deployments)
   - NFT minting policy script (unique per deployment)

2. **Oracle Start Transaction**
   - Mints oracle NFTs
   - Creates initial UTxOs with proper datums
   - Sets up reward transport system

3. **Post-Deployment Verification**
   - Confirms UTxO creation
   - Verifies NFT minting
   - Validates script parameters

For detailed deployment instructions, see [Deployment Guide](docs/deployment.md).

### Running Tests

```bash
poetry run pytest
```

## License

This repository is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**.

### License Rationale

Charli3 uses a combination of OSI-approved open-source licenses, primarily AGPL-3.0 and MIT, depending on the role of each repository within the ecosystem.
Repositories that implement core or protocol-critical logic are licensed under AGPL-3.0 to ensure that improvements and modifications remain transparent and benefit the entire ecosystem, including node operators, developers, and token holders, while maintaining full OSI compliance. This may include both on-chain and select off-chain components where protocol logic and token usage are integral.

Repositories focused on tooling, SDKs, and supporting components are typically licensed under the MIT License to promote broad adoption, flexibility, and ease of integration.

AGPL-3.0 is applied where reciprocal openness is important to protect shared protocol infrastructure, while MIT is used where permissiveness and developer flexibility are the primary goals.

Please refer to each repository’s [LICENSE](LICENSE) file for the specific terms that apply.

Full commercial licenses available upon request by contacting sales@charli3.io.

## Official Deployments

Charli3 maintains and supports only official deployments that use the $C3 token and unmodified protocol economics.
