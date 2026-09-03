use aiken/builtin
use aiken/primitive/bytearray
use kdf/kdf.{HashAlgo, Sha256, Sha3_256, Keccak256, Blake2b_224, Blake2b_256}

// -------------------------------------------------------------------
// Public API
// -------------------------------------------------------------------

/// PBKDF2 as specified in RFC 8018, Section 5.2.
///
/// Parameters:
/// - `algo`       – hash algorithm to use
/// - `password`   – password or private key (octet string)
/// - `salt`       – salt (octet string)
/// - `count`      – iteration count, must be > 0
/// - `dk_len`     – intended length in octets of the derived key
///
/// Returns the derived key as a `ByteArray`.
pub fn kdf(
  algo: HashAlgo,
  password: ByteArray,
  salt: ByteArray,
  count: Int,
  dk_len: Int,
) -> ByteArray {
  let prf = prf_from_algo(algo)
  let h_len = bytearray.length(prf(#"", #""))

  if count <= 0 {
    fail @"iteration count must be a positive integer"
  } else if dk_len > 4294967295 * h_len {
    fail @"derived key too long"
  } else {
    let l = (dk_len + h_len - 1) / h_len
    let r = dk_len - (l - 1) * h_len
    derive_blocks(prf, password, salt, count, h_len, l, r, 1, #"")
  }
}

// -------------------------------------------------------------------
// Internal helpers
// -------------------------------------------------------------------

/// Map a HashAlgo to its corresponding PRF function.
fn prf_from_algo(algo: HashAlgo) -> fn(ByteArray, ByteArray) -> ByteArray {
  when algo is {
    Sha256 -> fn(pwd, data) { builtin.sha2_256(bytearray.concat(pwd, data)) }
    Sha3_256 -> fn(pwd, data) { builtin.sha3_256(bytearray.concat(pwd, data)) }
    Keccak256 -> fn(pwd, data) { builtin.keccak_256(bytearray.concat(pwd, data)) }
    Blake2b_224 -> fn(pwd, data) { builtin.blake2b_224(bytearray.concat(pwd, data)) }
    Blake2b_256 -> fn(pwd, data) { builtin.blake2b_256(bytearray.concat(pwd, data)) }
  }
}

/// Compute a single block  Ti = F(P, S, c, i).
fn compute_block(
  prf: fn(ByteArray, ByteArray) -> ByteArray,
  password: ByteArray,
  salt: ByteArray,
  count: Int,
  index: Int,
) -> ByteArray {
  let u1 =
    prf(
      password,
      bytearray.concat(salt, bytearray.from_int_big_endian(index, 4)),
    )
  xor_iterate(prf, password, count - 1, u1, u1)
}

/// Iterate Uj and accumulate the XOR sum.
fn xor_iterate(
  prf: fn(ByteArray, ByteArray) -> ByteArray,
  password: ByteArray,
  remaining: Int,
  prev: ByteArray,
  acc: ByteArray,
) -> ByteArray {
  if remaining <= 0 {
    acc
  } else {
    let next = prf(password, prev)
    xor_iterate(
      prf,
      password,
      remaining - 1,
      next,
      builtin.xor_bytearray(True, acc, next),
    )
  }
}

/// Concatenate blocks T1..Tl, trimming the last block to `r` octets.
fn derive_blocks(
  prf: fn(ByteArray, ByteArray) -> ByteArray,
  password: ByteArray,
  salt: ByteArray,
  count: Int,
  h_len: Int,
  l: Int,
  r: Int,
  i: Int,
  acc: ByteArray,
) -> ByteArray {
  if i > l {
    acc
  } else {
    let ti = compute_block(prf, password, salt, count, i)
    let ti_trimmed = if i == l { bytearray.take(ti, r) } else { ti }
    derive_blocks(
      prf,
      password,
      salt,
      count,
      h_len,
      l,
      r,
      i + 1,
      bytearray.concat(acc, ti_trimmed),
    )
  }
}
