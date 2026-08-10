use aiken/primitive/bytearray

/// Convert Int to 48-byte ByteArray for BLS12-381 field elements
pub fn int_to_field_bytes(value: Int) -> ByteArray {
  bytearray.from_int_big_endian(value, 48)
}
