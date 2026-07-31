use aiken/builtin.{
  append_bytearray, integer_to_bytearray, length_of_bytearray, replicate_byte,
  sha2_256, xor_bytearray,
}
use aiken/primitive/bytearray

/// HKDF-Expand as defined in RFC 5869
///
/// Inputs:
///   PRK      a pseudorandom key of at least HashLen octets
///   info     optional context and application specific information
///   L        length of output keying material in octets (<= 255*HashLen)
///
/// Output:
///   OKM      output keying material (of L octets)
pub fn hkdf_expand(prk: ByteArray, info: ByteArray, l: Int) -> ByteArray {
  // HashLen = 32 for SHA-256
  let hash_len = 32

  // N = ceil(L/HashLen)
  let n = ( l + hash_len - 1 ) / hash_len

  // T(0) = empty string
  // Start recursion with T(0), iteration 1, and empty OKM
  hkdf_expand_recursive(prk, info, l, n, 1, #"", #"")
}

/// Recursive helper for HKDF-Expand
fn hkdf_expand_recursive(
  prk: ByteArray,
  info: ByteArray,
  l: Int,
  n: Int,
  i: Int,
  // T(i-1)
  t_prev: ByteArray,
  okm: ByteArray,
) -> ByteArray {
  when i > n is {
    True -> builtin.slice_bytearray(0, l, okm)
    False -> {
      let b_i = integer_to_bytearray(True, 1, i)

      // where i is a single octet (0x01, 0x02, ...)
      let to_hash = t_prev |> append_bytearray(info) |> append_bytearray(b_i)

      // T(i) = HMAC-Hash(PRK, T(i-1) | info | i)
      let t_i = hmac_sha256(prk, to_hash)

      // Append T(i) to OKM and continue with next iteration
      let updated_okm = builtin.append_bytearray(okm, t_i)
      hkdf_expand_recursive(prk, info, l, n, i + 1, t_i, updated_okm)
    }
  }
}

/// HKDF-Extract as defined in RFC 5869
///
/// Inputs:
///   salt     optional salt value (a non-secret random value)
///   ikm      input keying material
///
/// Output:
///   PRK      a pseudorandom key (of HashLen octets)
pub fn hkdf_extract(salt: ByteArray, ikm: ByteArray) -> ByteArray {
  let hash_size = 32
  let block_size = 64

  // RFC 5869: default salt to zeros if empty
  let salt =
    when length_of_bytearray(salt) is {
      0 -> replicate_byte(hash_size, 0)
      _ -> salt
    }

  // RFC 2104: if salt longer than block size, hash it first
  let salt =
    when length_of_bytearray(salt) > block_size is {
      True -> sha2_256(salt)
      False -> salt
    }

  // HMAC output
  hmac_sha256(salt, ikm)
}

pub fn hmac_sha256(key: ByteArray, msg: ByteArray) -> ByteArray {
  let block_size = 64

  // Block size for SHA-256 in bytes
  let i_key = xor_bytearray(True, key, replicate_byte(block_size, 0x36))

  let o_key = xor_bytearray(True, key, replicate_byte(block_size, 0x5c))

  sha2_256(append_bytearray(o_key, sha2_256(append_bytearray(i_key, msg))))
}

/// expand_message_xmd as defined in RFC 9380 (Hashing to Elliptic Curves)
/// 
/// Inputs:
///   msg             - message to hash
///   dst             - domain separation tag
///   len_in_bytes    - length of requested output in bytes
///
/// Output:
///   pseudo_random_bytes - of length len_in_bytes
pub fn expand_message_xmd(
  msg: ByteArray,
  dst: ByteArray,
  len_in_bytes: Int,
) -> ByteArray {
  // SHA-256 digest size
  let digest_size = 32

  // SHA-256 block size
  let block_size = 64
  // Validate DST length (must be <= 255 bytes)
  let dst_size = length_of_bytearray(dst)
  expect dst_size <= 255
  // Calculate number of blocks needed
  // ceil(len_in_bytes / digest_size)
  let ell = ( len_in_bytes + digest_size - 1 ) / digest_size
  expect ell <= 255
  expect ell > 0
  // DST_prime = DST || I2OSP(len(DST), 1)
  let dst_prime = append_bytearray(dst, integer_to_bytearray(True, 1, dst_size))
  // Z_pad = zero padding of length block_size
  let z_pad = replicate_byte(block_size, 0)
  // l_i_b_str = I2OSP(len_in_bytes, 2)
  let l_i_b_str = integer_to_bytearray(True, 2, len_in_bytes)
  // b_0 = H(Z_pad || msg || l_i_b_str || I2OSP(0, 1) || DST_prime)
  let b_0_input =
    z_pad
      |> append_bytearray(msg)
      |> append_bytearray(l_i_b_str)
      |> append_bytearray(#"00")
      |> append_bytearray(dst_prime)
  let b_0 = sha2_256(b_0_input)
  // Start recursion with i=1, empty result
  // Note: b_1 uses b_0 directly, not XOR with previous
  expand_message_xmd_recursive(b_0, dst_prime, ell, 1, b_0, #"", len_in_bytes)
}

/// Recursive helper for expand_message_xmd
fn expand_message_xmd_recursive(
  b_0: ByteArray,
  dst_prime: ByteArray,
  ell: Int,
  i: Int,
  prev_block: ByteArray,
  // This is b_{i-1} (for i=1, this is b_0)
  result: ByteArray,
  len_in_bytes: Int,
) -> ByteArray {
  if i > ell {
    // Base case: all blocks generated, return first len_in_bytes bytes
    bytearray.take(result, len_in_bytes)
  } else {
    // Generate block for current iteration
    let block =
      if i == 1 {
        // b_1 = H(b_0 || I2OSP(1, 1) || DST_prime)
        // For i=1, prev_block is b_0, and we don't XOR
        let input =
          prev_block
            |> append_bytearray(#"01")
            |> append_bytearray(dst_prime)
        sha2_256(input)
      } else {
        // b_i = H((b_0 XOR b_{i-1}) || I2OSP(i, 1) || DST_prime)
        let xor_result = xor_bytearray(True, b_0, prev_block)
        let input =
          xor_result
            |> append_bytearray(integer_to_bytearray(True, 1, i))
            |> append_bytearray(dst_prime)
        sha2_256(input)
      }
    // Recursive call with next iteration
    expand_message_xmd_recursive(
      b_0,
      dst_prime,
      ell,
      i + 1,
      block,
      // This becomes b_i for the next iteration
      append_bytearray(result, block),
      len_in_bytes,
    )
  }
}
