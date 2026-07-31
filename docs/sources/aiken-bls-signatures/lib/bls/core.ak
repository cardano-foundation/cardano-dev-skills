use aiken/builtin.{append_bytearray, integer_to_bytearray}
use aiken/crypto/bls12_381/scalar.{field_prime}
use aiken/primitive/bytearray
use bls/api.{PrivateKey}
use bls/hash.{hkdf_expand, hkdf_extract}

/// Generate a secret key from input keying material.
///
/// The input keying material (`ikm`) MUST contain sufficient entropy.
/// The resulting secret key is derived using a deterministic key
/// derivation function (e.g. HKDF modulo the curve order).
///
/// > [!IMPORTANT]
/// > Implementations MUST ensure that the resulting key is uniformly
/// > distributed in the scalar field and is non-zero.
///
/// ```aiken
/// let sk = key_gen(random_bytes)
/// ```
///
/// > [!NOTE]
/// > It follows the RFC v2 and therefore does not implement recrsive key generation
/// > with new salt if SK == 0, but it is unlikely to happen in practice given the size
/// > of the output space (2^256) and the curve order (2^255).
/// > https://github.com/algorand/bls_sigs_ref/blob/master/rust-impl/src/signature.rs#L21
///
pub fn key_gen(ikm: ByteArray, key_info: ByteArray) -> PrivateKey {
  // Step 1: HKDF-Extract with salt and ikm || 0x00
  let salt = "BLS-SIG-KEYGEN-SALT-"

  let prk = hkdf_extract(salt, ikm |> append_bytearray(#"00"))

  // Step 2: HKDF-Expand with key_info || I2OSP(L, 2)
  // L = ceil((3 * ceil(log2(curve_order))) / 8) == 48 for BLS12-381
  let l = 48
  let l_bytes = integer_to_bytearray(True, 2, l)

  let okm = hkdf_expand(prk, key_info |> append_bytearray(l_bytes), l)

  // Step 3: Convert OKM to integer modulo curve order
  let sk = bytearray.to_int_big_endian(okm) % field_prime

  // Ensure sk is non-zero, we do not implement V6's recursive key generation
  // with new salt as this won't and cannot be used in blockhain scripts as it
  // needs random oracle or a non-unifomr encoding which cannot be guaranteed
  // in a blockhain script.
  expect sk != 0
  // Step 4: return sk
  integer_to_bytearray(True, 32, sk)
}
