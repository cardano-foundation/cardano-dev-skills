use aiken/builtin
use aiken/primitive/bytearray
use kdf/kdf.{HashAlgo, Sha256, Sha3_256, Keccak256, Blake2b_224, Blake2b_256}

// -------------------------------------------------------------------
// Public API
// -------------------------------------------------------------------

/// HKDF as specified in RFC 5869.
///
/// Combines Extract (salt + IKM -> PRK) and Expand (PRK + info -> OKM)
/// into a single call.
///
/// Parameters:
/// - `algo`   – hash algorithm to use
/// - `salt`   – optional salt (if empty, defaults to HashLen zero octets)
/// - `ikm`    – input keying material
/// - `info`   – optional context and application-specific information
/// - `length` – length of output keying material in octets (> 0, <= 255*HashLen)
///
/// Returns the output keying material `OKM`.
pub fn kdf(
  algo: HashAlgo,
  salt: ByteArray,
  ikm: ByteArray,
  info: ByteArray,
  length: Int,
) -> ByteArray {
  let prk = extract(algo, salt, ikm)
  expand(algo, prk, info, length)
}

/// HKDF-Extract as specified in RFC 5869, Section 2.2.
///
/// Derives a pseudorandom key (`PRK`) from the salt and input keying
/// material.  If `salt` is empty it defaults to a zero octet string of
/// the hash output length.
///
/// # Parameters
///
/// - `algo`  – hash algorithm to use
/// - `salt`  – optional salt byte array
/// - `ikm`   – input keying material
///
/// Returns the pseudorandom key `PRK`.
pub fn extract(algo: HashAlgo, salt: ByteArray, ikm: ByteArray) -> ByteArray {
  let h_len = hash_len(algo)
  let salt_or_default =
    if bytearray.is_empty(salt) {
      builtin.replicate_byte(h_len, 0)
    } else {
      salt
    }
  hmac(algo, salt_or_default, ikm)
}

/// HKDF-Expand as specified in RFC 5869, Section 2.3.
///
/// Expands the pseudorandom key `prk` into `length` bytes of output
/// keying material (`OKM`) using the optional `info` string.
///
/// `length` must be between 1 and 255 * hash_len inclusive.
///
/// # Parameters
///
/// - `algo`    – hash algorithm to use
/// - `prk`     – pseudorandom key (from `extract`)
/// - `info`    – optional context and application-specific information
/// - `length`  – length of output keying material in octets
///
/// Returns the output keying material `OKM`.
pub fn expand(algo: HashAlgo, prk: ByteArray, info: ByteArray, length: Int) -> ByteArray {
  let h_len = hash_len(algo)
  let max_len = 255 * h_len

  if length <= 0 {
    fail @"length must be a positive integer"
  } else if length > max_len {
    fail @"length too large"
  } else {
    let n = (length + h_len - 1) / h_len
    expand_iter(algo, prk, info, length, h_len, n, 1, #"", #"")
  }
}

// -------------------------------------------------------------------
// Internal helpers
// -------------------------------------------------------------------

/// Return the output length in octets for the given hash algorithm.
fn hash_len(algo: HashAlgo) -> Int {
  when algo is {
    Sha256 -> 32
    Sha3_256 -> 32
    Keccak256 -> 32
    Blake2b_224 -> 28
    Blake2b_256 -> 32
  }
}

/// Map a HashAlgo to its corresponding hash function.
fn hash_from_algo(algo: HashAlgo) -> fn(ByteArray) -> ByteArray {
  when algo is {
    Sha256 -> fn(data) { builtin.sha2_256(data) }
    Sha3_256 -> fn(data) { builtin.sha3_256(data) }
    Keccak256 -> fn(data) { builtin.keccak_256(data) }
    Blake2b_224 -> fn(data) { builtin.blake2b_224(data) }
    Blake2b_256 -> fn(data) { builtin.blake2b_256(data) }
  }
}

/// HMAC as specified in RFC 2104.
fn hmac(algo: HashAlgo, key: ByteArray, msg: ByteArray) -> ByteArray {
  let block_size = 64
  let hash = hash_from_algo(algo)

  // If the key is longer than the block size, hash it first.
  let key_or_hash =
    if bytearray.length(key) > block_size {
      hash(key)
    } else {
      key
    }

  // Pad the key (or its hash) with zeros to the block size.
  let key_padded =
    builtin.append_bytearray(
      key_or_hash,
      builtin.replicate_byte(block_size - bytearray.length(key_or_hash), 0),
    )

  let i_key = builtin.xor_bytearray(True, key_padded, builtin.replicate_byte(block_size, 0x36))

  let o_key = builtin.xor_bytearray(True, key_padded, builtin.replicate_byte(block_size, 0x5c))

  hash(builtin.append_bytearray(o_key, hash(builtin.append_bytearray(i_key, msg))))
}

/// Iterate T(1)..T(N) and accumulate.
fn expand_iter(
  algo: HashAlgo,
  prk: ByteArray,
  info: ByteArray,
  length: Int,
  h_len: Int,
  n: Int,
  i: Int,
  prev: ByteArray,
  acc: ByteArray,
) -> ByteArray {
  if i > n {
    bytearray.take(acc, length)
  } else {
    let ti = hmac(algo, prk, bytearray.concat(prev, bytearray.concat(info, bytearray.from_int_big_endian(i, 1))))
    expand_iter(algo, prk, info, length, h_len, n, i + 1, ti, bytearray.concat(acc, ti))
  }
}
