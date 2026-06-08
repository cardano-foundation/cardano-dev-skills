use aiken/builtin

pub const issuance_cbor_hex_token_name = "IssuanceCborHex"

pub type IssuanceCborHex {
  /// Prefix bytes of the minting policy script
  prefix_cbor_hex: ByteArray,
  /// Postfix bytes of the minting policy script
  postfix_cbor_hex: ByteArray,
}

pub fn apply_hashed_parameter(
  prefix: ByteArray,
  postfix: ByteArray,
  hashed_param: ByteArray,
) -> ByteArray {
  // Plutus V3 version header: most significant first encoding of version 3
  let version_header = #"03"

  // Build the script: version + prefix + serialized_param + postfix
  let script_bytes = builtin.append_bytearray(
    version_header,
    builtin.append_bytearray(
      prefix,
      builtin.append_bytearray(hashed_param, postfix),
    ),
  )

  // Hash with blake2b_224 to get the policy ID (28 bytes)
  builtin.blake2b_224(script_bytes)
}
