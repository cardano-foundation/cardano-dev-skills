//// A key interface for deriving private and public keys across
//// supported cryptographic schemes. Currently includes BLS12-381
//// bindings built on top of the G1 prime-field.

use aiken/builtin.{
  bls12_381_g1_compress, bls12_381_g1_scalar_mul, bytearray_to_integer,
  integer_to_bytearray,
}
use aiken/crypto/bls12_381/g1
use aiken/crypto/bls12_381/scalar.{field_prime}
use kdf/hkdf/hkdf
use kdf/pbkdf2/pbkdf2
use kdf/kdf.{HashAlgo, Sha256}

// -------------------------------------------------------------------
// Types
// -------------------------------------------------------------------

/// Supported schemes for key derivation.
pub type KeyDerivationScheme {
  PBKDF2
  HKDF
}

/// Supported cryptographic curves / systems used to represent secret
/// and public keys and to define the correspondence between them.
pub type Cryptography {
  BLS12_381
}

/// A private key is stored as raw bytes.
pub type PrivateKey =
  ByteArray

/// A public key is stored as raw bytes.
pub type PublicKey =
  ByteArray

// -------------------------------------------------------------------
// Public API
// -------------------------------------------------------------------

/// Derive a private key from a raw secret using the chosen
/// cryptographic method.
///
/// The secret is reduced modulo the curve prime order and then
/// serialised back to a `ByteArray` of the requested length.
///
/// # Parameters
///
/// - `method`  – target curve (`BLS12_381`)
/// - `secret`  – raw secret bytes
///
/// Returns a `PrivateKey`.
pub fn to_pk(method: Cryptography, secret: ByteArray) -> PrivateKey {
  when method is {
    BLS12_381 -> to_pk_bls12_381(secret, 32)
  }
}

/// Derive a public key from a private key using the chosen
/// cryptographic method.
///
/// # Parameters
///
/// - `method`  – target curve (`BLS12_381`)
/// - `secret`  – private key bytes
///
/// Returns a `PublicKey`.
pub fn pk_from_sk(method: Cryptography, secret: ByteArray) -> PublicKey {
  when method is {
    BLS12_381 -> pk_from_sk_bls12_381(secret)
  }
}

/// Generate a private / public key pair using **PBKDF2**.
///
/// **Choices made here:**
/// - KDF scheme: `PBKDF2`
/// - Hash algorithm: `Sha256`
/// - Iteration count: `10`  (chosen to stay within the on-chain
///   budget of roughly **10–20 M CPU units** for a 32-byte output)
/// - Curve: `BLS12_381`
/// - Output length: **32 bytes** (fixed)
///
/// **Note:** 10 iterations is far below the traditional 4096 used
/// off-chain, but it is the maximum feasible on-chain while keeping
/// CPU usage affordable. If you need a different count or hash,
/// use `gen_keys_detail`.
///
/// # Parameters
///
/// - `salt`  – salt byte array
/// - `ikm`   – input keying material / password
///
/// Returns a tuple `(PrivateKey, PublicKey)`.
pub fn gen_keys_pbkdf2(
  salt: ByteArray,
  ikm: ByteArray,
) -> (PrivateKey, PublicKey) {
  gen_keys_detail(PBKDF2, BLS12_381, Sha256, salt, ikm, 10, #"")
}

/// Generate a private / public key pair using **HKDF**.
///
/// **Choices made here:**
/// - KDF scheme: `HKDF`
/// - Hash algorithm: `Sha256`
/// - Info string: empty (`#""`)
/// - Curve: `BLS12_381`
/// - Output length: **32 bytes** (fixed)
///
/// HKDF is orders of magnitude cheaper than PBKDF2 (~15 M CPU units
/// for a 32-byte SHA-256 output) and is the recommended choice for
/// high-entropy inputs.
///
/// # Parameters
///
/// - `salt`  – salt byte array
/// - `ikm`   – input keying material / password
///
/// Returns a tuple `(PrivateKey, PublicKey)`.
pub fn gen_keys_hkdf(
  salt: ByteArray,
  ikm: ByteArray,
) -> (PrivateKey, PublicKey) {
  gen_keys_detail(HKDF, BLS12_381, Sha256, salt, ikm, 0, #"")
}

/// Generate a private / public key pair using the selected KDF scheme
/// and elliptic-curve system. This version exposes every tunable
/// parameter and is intended for advanced use-cases or when the
/// shortened helpers (`gen_keys_pbkdf2` / `gen_keys_hkdf`) do not
/// fit your needs.
///
/// The derived secret length is **fixed at 32 bytes** (the standard
/// scalar size for BLS12-381).
///
/// # Parameters
///
/// - `scheme`       – key derivation scheme (`PBKDF2` or `HKDF`)
/// - `cryptography` – target curve (`BLS12_381`)
/// - `algo`         – hash algorithm (e.g. `Sha256`, `Blake2b_256`)
/// - `salt`         – salt byte array (used by both schemes)
/// - `ikm`          – input keying material / password (used by both schemes)
/// - `count`        – iteration count, **used only for PBKDF2**
/// - `info`         – context info, **used only for HKDF**
///
/// Returns a tuple `(PrivateKey, PublicKey)`.
pub fn gen_keys_detail(
  scheme: KeyDerivationScheme,
  cryptography: Cryptography,
  algo: HashAlgo,
  salt: ByteArray,
  ikm: ByteArray,
  count: Int,
  info: ByteArray,
) -> (PrivateKey, PublicKey) {
  when cryptography is {
    BLS12_381 -> gen_keys_bls12_381(scheme, algo, salt, ikm, count, info)
  }
}

// -------------------------------------------------------------------
// BLS12-381 specific key-pair generation
// -------------------------------------------------------------------

/// Runs the chosen KDF (`PBKDF2` or `HKDF`) with a fixed 32-byte
/// output length and then converts the derived material into a
/// BLS12-381 private key (reduced modulo the prime field) and the
/// corresponding compressed public key.
///
/// # Parameters
///
/// - `scheme` – key derivation scheme
/// - `algo`   – hash algorithm
/// - `salt`   – salt
/// - `ikm`    – input keying material / password
/// - `count`  – iteration count (PBKDF2 only)
/// - `info`   – context info (HKDF only)
///
/// Returns a tuple `(PrivateKey, PublicKey)`.
pub fn gen_keys_bls12_381(
  scheme: KeyDerivationScheme,
  algo: HashAlgo,
  salt: ByteArray,
  ikm: ByteArray,
  count: Int,
  info: ByteArray,
) -> (PrivateKey, PublicKey) {
  let secret = when scheme is {
    PBKDF2 -> pbkdf2.kdf(algo, ikm, salt, count, 32)
    HKDF -> hkdf.kdf(algo, salt, ikm, info, 32)
  }
  let sk = to_pk_bls12_381(secret, 32)
  let pk = pk_from_sk_bls12_381(sk)
  (sk, pk)
}

/// Convert an arbitrary byte sequence into a valid BLS12-381 private
/// key that lies inside the prime field.
///
/// The secret is interpreted as a big-endian integer, reduced modulo
/// `field_prime`, and then padded / truncated to `len` bytes.
///
/// # Parameters
///
/// - `secret`  – raw secret bytes
/// - `len`     – desired output length in bytes
///
/// Returns a `PrivateKey`.
pub fn to_pk_bls12_381(secret: ByteArray, len: Int) -> PrivateKey {
  //TO DO - think about possibility of making big endian and little endian option for the user
  let sk = bytearray_to_integer(True, secret) % field_prime
  expect sk != 0
  integer_to_bytearray(True, len, sk)
}

/// Derive a BLS12-381 public key from the provided secret key.
///
/// The public key is computed as the scalar multiplication of the
/// generator point by the secret scalar, then compressed to its
/// byte representation.
///
/// ```aiken
/// let pk = pk_from_sk_bls12_381(secret)
/// ```
///
/// # Parameters
///
/// - `secret`  – private key bytes
///
/// Returns a `PublicKey`.
pub fn pk_from_sk_bls12_381(secret: PrivateKey) -> PublicKey {
  bls12_381_g1_scalar_mul(scalar_from_sk_bls12_381(secret), g1.generator)
    |> bls12_381_g1_compress
}

// -------------------------------------------------------------------
// Internal helpers
// -------------------------------------------------------------------

/// Convert a secret key from its byte representation into a scalar
/// suitable for the BLS12-381 curve.
///
/// The conversion succeeds only when the scalar lies in the valid
/// range `(0, prime_order)`.
fn scalar_from_sk_bls12_381(sk: ByteArray) -> Int {
  let scalar = bytearray_to_integer(True, sk)
  expect scalar > 0 && scalar < field_prime
  scalar
}
