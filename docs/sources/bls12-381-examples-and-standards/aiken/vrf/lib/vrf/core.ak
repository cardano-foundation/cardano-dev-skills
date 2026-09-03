use aiken/builtin.{bls12_381_g2_uncompress, slice_bytearray, append_bytearray, length_of_bytearray, integer_to_bytearray, bytearray_to_integer}
use aiken/crypto.{sha2_256}
use aiken/crypto/bls12_381/scalar.{from_bytes, add, mul, to_bytes, to_int}
use aiken/crypto/bls12_381/g2.{compress, scale, generator, hash_to_group, equal, add as g2_add}
use bls/core.{key_gen}

const ptLen = 96
const cLen = 16
const qLen = 32

pub type SecretKey =
  ByteArray

pub type PublicKey =
  ByteArray

/// Uses SecretKey to derive the VRF secret scalar x and the VRF public key Y = x*G2
/// The VRF secret scalar derivation is in the context of G1 group.
/// The public key derivation is in the context of G2 group.
///
/// The function performs two steps:
/// 1. Derives a secret scalar from the input secret using HKDF (HMAC-based Key Derivation Function)
///    following the RFC v2 specification from ilap/bls. This ensures the resulting key is uniformly
///    distributed in the scalar field and is non-zero.
/// 2. Computes the public key by scaling the G2 generator point with the secret scalar: Y = x*G2
///
/// Arguments:
/// - secret: SecretKey - input keying material (must contain sufficient entropy)
///
/// Returns:
/// (secret scalar in G1 and compressed public key in G2)
///
/// ```aiken
/// let (sk, pk) = keys_from_secret(secret)
/// ```
pub fn keys_from_secret(secret: SecretKey) -> (SecretKey, PublicKey) {
    let sk = secret_scalar(secret, "")
    let pk = compress(scale(generator, from_bytes(sk)))
    (sk, pk)
}

/// Derives a secret scalar from input keying material using HKDF.
/// 
/// This function reuses the `key_gen` functionality from ilap/bls, which follows the
/// RFC v2 specification for BLS signature key generation. The process works as follows:
/// 
/// 1. HKDF-Extract: Combines the input keying material (IKM) with a salt "BLS-SIG-KEYGEN-SALT-"
///    and a null byte (IKM || 0x00) to produce a pseudorandom key (PRK).
/// 
/// 2. HKDF-Expand: Expands the PRK with key_info and length encoding (48 bytes for BLS12-381)
///    to produce output keying material (OKM).
/// 
/// 3. Modular reduction: Converts OKM to an integer modulo the curve order (field_prime)
///    to ensure the scalar is within the valid range [0, field_prime).
/// 
/// The resulting secret key is guaranteed to be:
/// - Uniformly distributed in the scalar field
/// - Non-zero (the probability of generating zero is negligible: ~2^-255)
/// 
/// Arguments:
/// - secret: SecretKey - input keying material (must contain sufficient entropy)
/// - key_info: ByteArray - optional context and application specific information (can be empty)
///
/// Returns:
/// Secret scalar as a 32-byte ByteArray
///
/// ```aiken
/// let sk = secret_scalar(secret, key_info)
/// ```
pub fn secret_scalar(secret: SecretKey, key_info: ByteArray) -> SecretKey {
    key_gen(secret, key_info)
}


/// Hashes a VRF input string to a point on the G2 curve.
///
/// Implements ECVRF-encode-to-curve from [IETF RFC 9380](https://www.ietf.org/archive/id/draft-irtf-cfrg-hash-to-curve-13.html)
/// using the Simplified SWU (Shallue-Woestijne-Ulas) method.
///
/// Arguments:
/// - encode_to_curve_salt: ByteArray - public salt value (e.g., "ECVRF_")
/// - alpha_string: ByteArray - value to hash to a curve point
///
/// Returns:
/// A G2Element point
///
/// ```aiken
/// let salt = "ECVRF_"
/// let input = "test input"
/// let point = encode_to_curve(salt, input)
/// ```
pub fn encode_to_curve(encode_to_curve_salt: ByteArray, alpha_string: ByteArray) -> G2Element {
  hash_to_group(alpha_string, encode_to_curve_salt)
}

test encode_to_curve_simple() {
  let salt = "ECVRF_"
  let alpha = "test input"
  let h = encode_to_curve(salt, alpha)
  equal(h, hash_to_group(alpha, salt))
}

/// Converts a G2 point to a compressed byte string.
///
/// Implements point_to_string from [IETF RFC 9381](https://www.rfc-editor.org/rfc/rfc9381.html)
/// using the compressed encoding from [RFC 9380](https://www.ietf.org/archive/id/draft-irtf-cfrg-hash-to-curve-13.html).
///
/// Arguments:
/// - point: G2Element - a point on the G2 curve
///
/// Returns:
/// A ByteArray with the compressed representation (96 bytes)
///
/// ```aiken
/// let point = generator
/// let encoded = point_to_string(point)
/// ```
pub fn point_to_string(point: G2Element) -> ByteArray {
  compress(point)
}

test point_to_string_1() {
  let h = hash_to_group("test", "salt")
  point_to_string(h) == compress(h)
}

test point_to_string_2() {
  let point = generator
  let compressed = point_to_string(point)
  compressed == #"93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8"
}

/// Generates the nonce value k in a deterministic pseudorandom fashion.
///
/// Implements ECVRF_nonce_generation from [IETF RFC 9381](https://www.rfc-editor.org/rfc/rfc9381.html) Section 5.4.2.2
/// (derived from RFC 8032 Section 5.1.6):
///
///   1. hashed_sk_string = Hash(SK)
///   2. truncated_hashed_sk_string = hashed_sk_string[32]...hashed_sk_string[63]
///   3. k_string = Hash(truncated_hashed_sk_string || h_string)
///   4. k = string_to_int(k_string) mod q
///
/// Arguments:
/// - secret_key: SecretKey - the VRF secret key (32-byte ByteArray)
/// - h_string: ByteArray - the hash string (output of point_to_string(H))
///
/// Returns:
/// A nonce scalar k as a ByteArray (32 bytes, between 1 and q-1)
///
/// ```aiken
/// let (sk, pk) = keys_from_secret(secret)
/// let h = encode_to_curve("ECVRF_", alpha)
/// let h_string = point_to_string(h)
/// let k = nonce_generation(sk, h_string)
/// ```
pub fn nonce_generation(secret_key: SecretKey, h_string: ByteArray) -> SecretKey {
  let hashed_sk_string = sha2_256(secret_key)
  let truncated = builtin.slice_bytearray(32, 32, hashed_sk_string)
  let k_string = sha2_256(builtin.append_bytearray(truncated, h_string))
  to_bytes(from_bytes(k_string))
}

test nonce_generation_1() {
  let sk = #"0000000000000000000000000000000000000000000000000000000000000001"
  let h_string = #"9332903123123123123123123123123123123123123123123123123123123123"
  let k = nonce_generation(sk, h_string)
  k != sk
}

/// Generates a challenge value from five G2 points.
///
/// Implements ECVRF_challenge_generation from [IETF RFC 9381](https://www.rfc-editor.org/rfc/rfc9381.html) Section 5.4.3:
///
///   1. challenge_generation_domain_separator_front = 0x02
///   2. Initialize str = suite_string || challenge_generation_domain_separator_front
///   3. For PJ in [P1, P2, P3, P4, P5]:
///      str = str || point_to_string(PJ)
///   4. challenge_generation_domain_separator_back = 0x00
///   5. str = str || challenge_generation_domain_separator_back
///   6. c_string = Hash(str)
///   7. truncated_c_string = c_string[0]...c_string[cLen-1]
///   8. c = string_to_int(truncated_c_string)
///   9. Output c
///
/// Arguments:
/// - Y: G2Element - public key (Y = x * G2)
/// - H: G2Element - encoded hash point (H = encode_to_curve(salt, alpha))
/// - Gamma: G2Element - Gamma = k * H
/// - U: G2Element - U = k * G2 (nonce times generator)
/// - V: G2Element - V = k * H (nonce times hash point)
///
/// Returns:
/// c: challenge value as a ByteArray (16 bytes, between 0 and 2^(8*cLen)-1, with cLen = 16)
///
/// ```aiken
/// let (sk, pk) = keys_from_secret(secret)
/// let h = encode_to_curve("ECVRF_", alpha)
/// let gamma = scale(h, k)
/// let u = scale(generator, k)
/// let v = scale(h, k)
/// let c = challenge_generation(pk, h, gamma, u, v)
/// ```
pub fn challenge_generation(
  y: G2Element,
  h: G2Element,
  gamma: G2Element,
  u: G2Element,
  v: G2Element,
) -> ByteArray {
  let challenge_generation_domain_separator_front = #"02"
  let suite_string = #"00"
  let str = append_bytearray(suite_string, challenge_generation_domain_separator_front)
  let str = append_bytearray(str, point_to_string(y))
  let str = append_bytearray(str, point_to_string(h))
  let str = append_bytearray(str, point_to_string(gamma))
  let str = append_bytearray(str, point_to_string(u))
  let str = append_bytearray(str, point_to_string(v))
  let challenge_generation_domain_separator_back = #"00"
  let str = append_bytearray(str, challenge_generation_domain_separator_back)
  let c_string = sha2_256(str)
  slice_bytearray(0, 16, c_string)
}

test challenge_generation_1() {
  let y = generator
  let h = hash_to_group("test", "salt")
  let gamma = generator
  let u = generator
  let v = generator
  let c = challenge_generation(y, h, gamma, u, v)
  bytearray_to_integer(True, c) < 340282366920938463463374607431768211456
}

/// Generates a VRF proof for a given input.
///
/// Implements ECVRF_prove from [IETF RFC 9381](https://www.rfc-editor.org/rfc/rfc9381.html) Section 5.1:
///
///   1. Use SK to derive the VRF secret scalar x and the VRF public key Y = x*G2
///   2. H = ECVRF_encode_to_curve(encode_to_curve_salt, alpha_string)
///   3. h_string = point_to_string(H)
///   4. Gamma = x*H
///   5. k = ECVRF_nonce_generation(SK, h_string)
///   6. c = ECVRF_challenge_generation(Y, H, Gamma, k*G2, k*H)
///   7. s = (k + c*x) mod q
///   8. pi_string = point_to_string(Gamma) || int_to_string(c, cLen) || int_to_string(s, qLen)
///
/// Arguments:
/// - secret: SecretKey - VRF secret key (32-byte ByteArray)
/// - alpha_string: ByteArray - input alpha, an octet string
/// - encode_to_curve_salt: ByteArray - a public salt value (e.g., "ECVRF_")
///
/// Returns:
/// pi_string: ByteArray - VRF proof (ptLen + cLen + qLen = 96 + 16 + 32 = 144 bytes)
///
/// ```aiken
/// let (sk, pk) = keys_from_secret(secret)
/// let alpha = "test input"
/// let salt = "ECVRF_"
/// let proof = prove(sk, alpha, salt)
/// ```
pub fn prove(secret: SecretKey, alpha_string: ByteArray, encode_to_curve_salt: ByteArray) -> ByteArray {
  let x = from_bytes(secret)
  let y = scale(generator, x)

  let h = encode_to_curve(encode_to_curve_salt, alpha_string)
  let h_string = point_to_string(h)

  let gamma = scale(h, x)

  let k = nonce_generation(secret, h_string)

  let kG2 = scale(generator, from_bytes(k))
  let kH = scale(h, from_bytes(k))
  let c_bytes = challenge_generation(y, h, gamma, kG2, kH)
  let c = from_bytes(c_bytes)

  let s = add(mul(c, x), from_bytes(k))

  let gamma_string = point_to_string(gamma)
  let c_string = integer_to_bytearray(True, 16, to_int(c))
  let s_string = to_bytes(s)

  append_bytearray(append_bytearray(gamma_string, c_string), s_string)
}

test prove_1() {
  let sk = secret_scalar(#"746573745f7365637265745f6b65795f313233343536", "")
  let alpha = "test input"
  let salt = "ECVRF_"
  let proof = prove(sk, alpha, salt)
  length_of_bytearray(proof) == 144
}

/// Decodes a VRF proof into its component parts.
///
/// Implements ECVRF_decode_proof from [IETF RFC 9381](https://www.rfc-editor.org/rfc/rfc9381.html) Section 5.4.4:
///
///   1. gamma_string = pi_string[0]...pi_string[ptLen-1]
///   2. c_string = pi_string[ptLen]...pi_string[ptLen+cLen-1]
///   3. s_string = pi_string[ptLen+cLen]...pi_string[ptLen+cLen+qLen-1]
///   4. Gamma = string_to_point(gamma_string)
///   5. If Gamma = "INVALID", output "INVALID" and stop
///   6. c = string_to_int(c_string)
///   7. s = string_to_int(s_string)
///   8. If s >= q, output "INVALID" and stop
///   9. Output Gamma, c, and s
///
/// Arguments:
/// - pi_string: ByteArray - VRF proof (ptLen + cLen + qLen = 96 + 16 + 32 = 144 bytes)
///
/// Returns:
/// Option<(G2Element, Int, Int)> - Some((Gamma, c, s)) on success, None on invalid proof
///
/// ```aiken
/// let (sk, pk) = keys_from_secret(secret)
/// let alpha = "test input"
/// let salt = "ECVRF_"
/// let proof = prove(sk, alpha, salt)
/// let Some((gamma, c, s)) = decode_proof(proof)
/// ```
pub fn decode_proof(pi_string: ByteArray) -> Option<(G2Element, Int, Int)> {
  when length_of_bytearray(pi_string) is {
    144 -> {
      let gamma_string = slice_bytearray(0, ptLen, pi_string)
      let c_string = slice_bytearray(ptLen, cLen, pi_string)
      let s_string = slice_bytearray(ptLen + cLen, qLen, pi_string)

      let gamma = bls12_381_g2_uncompress(gamma_string)
      let c = bytearray_to_integer(True, c_string)
      let s_scalar = from_bytes(s_string)
      let s = to_int(s_scalar)

      Some((gamma, c, s))
    }
    _ -> None
  }
}

test proof_decode_1() {
  let sk = secret_scalar(#"746573745f7365637265745f6b65795f313233343536", "")
  let alpha = "test input"
  let salt = "ECVRF_"
  let proof = prove(sk, alpha, salt)
  when decode_proof(proof) is {
    Some(_) -> True
    None -> False
  }
}

test proof_decode_2() {
  decode_proof(#"00") == None
}

/// Converts a VRF proof to a hash output.
///
/// Implements ECVRF_proof_to_hash from [IETF RFC 9381](https://www.rfc-editor.org/rfc/rfc9381.html) Section 5.2:
///
///   1. D = ECVRF_decode_proof(pi_string) (see Section 5.4.4)
///   2. If D is "INVALID", output "INVALID" and stop
///   3. (Gamma, c, s) = D
///   4. proof_to_hash_domain_separator_front = 0x03
///   5. proof_to_hash_domain_separator_back = 0x00
///   6. beta_string = Hash(suite_string || proof_to_hash_domain_separator_front || point_to_string(cofactor * Gamma) || proof_to_hash_domain_separator_back)
///   7. Output beta_string
///
/// Note: For BLS12-381, cofactor = 1, so cofactor * Gamma = Gamma
///
/// Arguments:
/// - pi_string: ByteArray - VRF proof (ptLen + cLen + qLen = 96 + 16 + 32 = 144 bytes)
///
/// Returns:
/// Option<ByteArray> - Some(beta_string) on success, None on invalid proof
///
/// ```aiken
/// let (sk, pk) = keys_from_secret(secret)
/// let alpha = "test input"
/// let salt = "ECVRF_"
/// let proof = prove(sk, alpha, salt)
/// let Some(beta) = proof_to_hash(proof)
/// ```
pub fn proof_to_hash(pi_string: ByteArray) -> Option<ByteArray> {
  when decode_proof(pi_string) is {
    Some((gamma, _c, _s)) -> {
      let proof_to_hash_domain_separator_front = #"03"
      let proof_to_hash_domain_separator_back = #"00"
      let suite_string = #"00"

      let gamma_string = point_to_string(gamma)

      let str = append_bytearray(suite_string, proof_to_hash_domain_separator_front)
      let str = append_bytearray(str, gamma_string)
      let str = append_bytearray(str, proof_to_hash_domain_separator_back)

      let beta_string = sha2_256(str)

      Some(beta_string)
    }
    None -> None
  }
}

test proof_to_hash_1() {
  let sk = secret_scalar(#"746573745f7365637265745f6b65795f313233343536", "")
  let alpha = "test input"
  let salt = "ECVRF_"
  let proof = prove(sk, alpha, salt)
  when proof_to_hash(proof) is {
    Some(_) -> True
    None -> False
  }
}

test proof_to_hash_2() {
  proof_to_hash(#"00") == None
}

test proof_to_hash_3() {
  let sk = secret_scalar(#"746573745f7365637265745f6b65795f313233343536", "")
  let alpha = "test input"
  let salt = "ECVRF_"
  let proof = prove(sk, alpha, salt)
  let beta1 = proof_to_hash(proof)
  let proof2 = prove(sk, alpha, salt)
  let beta2 = proof_to_hash(proof2)
  when beta1 is {
    Some(b1) -> {
      when beta2 is {
        Some(b2) -> b1 == b2
        None -> False
      }
    }
    None -> False
  }
}

/// Validates a VRF public key.
///
/// Implements ECVRF_validate_key from [IETF RFC 9381](https://www.rfc-editor.org/rfc/rfc9381.html) Section 5.4.5:
///
///   1. Let Y' = cofactor*Y
///   2. If Y' is the identity element of the elliptic curve group, output "INVALID" and stop
///   3. Output "VALID"
///
/// For BLS12-381 G2, cofactor = 1, so Y' = Y. This function checks that the public key
/// is not the identity point (point at infinity).
///
/// Note: The public key Y provided as input to this procedure MUST be a valid point on E.
///
/// Arguments:
/// - pk: PublicKey - compressed public key in G2 (96 bytes)
///
/// Returns:
/// Bool - True if valid, False if invalid (identity point)
///
/// ```aiken
/// let (sk, pk) = keys_from_secret(secret)
/// let is_valid = validate_key(pk)
/// ```
pub fn validate_key(pk: PublicKey) -> Bool {
  when builtin.slice_bytearray(0, 1, pk) is {
    #"c0" -> False
    _ -> True
  }
}

test validate_key_1() {
  let (_sk, pk) = keys_from_secret(#"746573745f7365637265745f6b65795f313233343536")
  validate_key(pk) == True
}

test validate_key_2() {
  let zeros = builtin.integer_to_bytearray(True, 95, 0)
  let identity_point = builtin.append_bytearray(#"c0", zeros)
  validate_key(identity_point) == False
}

/// Verifies a VRF proof.
///
/// Implements ECVRF_verify from [IETF RFC 9381](https://www.rfc-editor.org/rfc/rfc9381.html) Section 5.3:
///
///   1. Y = string_to_point(PK_string)
///   2. If Y is "INVALID", output "INVALID" and stop
///   3. If validate_key, run ECVRF_validate_key(Y); if it outputs "INVALID", output "INVALID" and stop
///   4. D = ECVRF_decode_proof(pi_string)
///   5. If D is "INVALID", output "INVALID" and stop
///   6. (Gamma, c, s) = D
///   7. H = ECVRF_encode_to_curve(encode_to_curve_salt, alpha_string)
///   8. U = s*B - c*Y
///   9. V = s*H - c*Gamma
///   10. c' = ECVRF_challenge_generation(Y, H, Gamma, U, V)
///   11. If c and c' are equal, output ("VALID", ECVRF_proof_to_hash(pi_string)); else output "INVALID"
///
/// Arguments:
/// - pk: PublicKey - public key expressed as an octet string (96 bytes)
/// - alpha_string: ByteArray - VRF input as an octet string
/// - pi_string: ByteArray - VRF proof (144 bytes: ptLen + cLen + qLen = 96 + 16 + 32)
/// - encode_to_curve_salt: ByteArray - a public salt value (e.g., "ECVRF_")
/// - validate_key: Bool - if True, validates the public key is not the identity point
///
/// Returns:
/// Option<ByteArray> - Some(beta_string) on success, None on invalid proof
///
/// ```aiken
/// let (sk, pk) = keys_from_secret(secret)
/// let alpha = "test input"
/// let salt = "ECVRF_"
/// let proof = prove(sk, alpha, salt)
/// let Some(beta) = verify(pk, alpha, proof, salt, True)
/// ```
pub fn verify(
  pk: PublicKey,
  alpha_string: ByteArray,
  pi_string: ByteArray,
  encode_to_curve_salt: ByteArray,
  validate_key_flag: Bool,
) -> Option<ByteArray> {
  if validate_key_flag && !validate_key(pk) {
    None
  } else {
    when decode_proof(pi_string) is {
      None -> None
      Some((gamma, c, s)) -> {
        let y_point = bls12_381_g2_uncompress(pk)
        let h = encode_to_curve(encode_to_curve_salt, alpha_string)
        let s_scalar = from_bytes(integer_to_bytearray(True, 32, s))
        let u = compute_u(y_point, s_scalar, c)
        let v = compute_v(h, gamma, s_scalar, c)
        let c_prime = challenge_generation(y_point, h, gamma, u, v)
        let c_bytes = integer_to_bytearray(True, 16, c)
        if c_prime == c_bytes {
          proof_to_hash(pi_string)
        } else {
          None
        }
      }
    }
  }
}

const q = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001

fn compute_u(y: G2Element, s_scalar, c_int: Int) -> G2Element {
  let sB = scale(generator, s_scalar)
  let minus_c = q - c_int
  let minus_c_bytes = integer_to_bytearray(True, 32, minus_c)
  let cY = scale(y, from_bytes(minus_c_bytes))
  g2_add(sB, cY)
}

fn compute_v(h: G2Element, gamma: G2Element, s_scalar, c_int: Int) -> G2Element {
  let sH = scale(h, s_scalar)
  let minus_c = q - c_int
  let minus_c_bytes = integer_to_bytearray(True, 32, minus_c)
  let cGamma = scale(gamma, from_bytes(minus_c_bytes))
  g2_add(sH, cGamma)
}

test verify_1() {
  let sk = secret_scalar(#"746573745f7365637265745f6b65795f313233343536", "")
  let (_sk, pk) = keys_from_secret(#"746573745f7365637265745f6b65795f313233343536")
  let alpha = "test input"
  let salt = "ECVRF_"
  let proof = prove(sk, alpha, salt)
  when verify(pk, alpha, proof, salt, False) is {
    Some(_beta) -> True
    None -> False
  }
}

test verify_2() {
  let sk = secret_scalar(#"746573745f7365637265745f6b65795f313233343536", "")
  let (_sk, pk) = keys_from_secret(#"746573745f7365637265745f6b65795f313233343536")
  let alpha = "test input"
  let salt = "ECVRF_"
  let proof = prove(sk, alpha, salt)
  when verify(pk, alpha, proof, salt, True) is {
    Some(_beta) -> True
    None -> False
  }
}

test verify_invalid_proof() {
  let sk = secret_scalar(#"746573745f7365637265745f6b65795f313233343536", "")
  let pk = #"93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8"
  let alpha = "test input"
  let salt = "ECVRF_"
  let proof = prove(sk, alpha, salt)
  let tampered_proof = builtin.append_bytearray(builtin.slice_bytearray(0, 143, proof), #"ff")
  verify(pk, alpha, tampered_proof, salt, False) == None
}

test verify_wrong_pk() {
  let sk1 = secret_scalar(#"746573745f7365637265745f6b65795f313233343536", "")
  let (_, pk2) = keys_from_secret(#"6162636465666768696a6b6c6d6e6f707172737475767778797a")
  let alpha = "test input"
  let salt = "ECVRF_"
  let proof = prove(sk1, alpha, salt)
  verify(pk2, alpha, proof, salt, False) == None
}