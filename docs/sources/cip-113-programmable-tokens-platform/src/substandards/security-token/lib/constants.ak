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
pub const minting_logic_script_registry_node_index = 2

pub const transfer_logic_script_registry_node_index = 3

pub const third_party_transfer_logic_script_registry_node_index = 4

// Added in CIP-113 v0.4.0. `VerificationKey(#"")` (core's `empty_vkey`) means
// unfracking is FORBIDDEN for the policy — the least-permission default. This
// repo ships no unfracking hook, so registration must leave it unset.
pub const unfracking_logic_script_registry_node_index = 5

// The GlobalState NFT policy the registry node declares for this token. v0.4.0
// pushed it from 5 to 6 when `unfracking_logic_script` was inserted ahead of it.
pub const global_state_cs_registry_node_index = 6
