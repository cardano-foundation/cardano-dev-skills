//Asset name of the configuration NFT
pub const config_asset_name = "Config"

//Asset name of the global state NFT
pub const global_state_asset_name = "GlobalState"

//Linked list constants (matching v1.2.0 defaults for on-chain compatibility)
pub const linked_list_root_key = #""

pub const linked_list_node_key_prefix = "Node"

pub const linked_list_node_key_prefix_length = 4

// Indexes of the fields in the registry node which are used to verify the correctness of the registry node
// and extract the hashed params for deriving the issuance policy id
// It is derived by index to allow the extension of the registry node in the future without breaking the logic of deriving the issuance policy id from the registry node
//
// NOTE: indices SWAPPED from upstream (2↔3) to match the CIP-113 directory node
// layout used by this integration. See `model/onchain/RegistryNode.java`:
//   field 0: issuance policy id (key)
//   field 1: next link
//   field 2: Script(transfer_logic hash)   ← was minting_logic in upstream
//   field 3: Script(issue/mint logic hash) ← was transfer_logic in upstream
//   field 4: global_state_policy_id
// This is the ONLY divergence from the verbatim BaFin port. Changing these
// constants invalidates the script hashes of every BaFin validator that
// inlines them — regenerate plutus.json with `aiken build` after editing.
pub const minting_logic_script_registry_node_index = 3

pub const transfer_logic_script_registry_node_index = 2

pub const third_party_transfer_logic_script_registry_node_index = 4
