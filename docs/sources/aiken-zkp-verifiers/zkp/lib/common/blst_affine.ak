use aiken/primitive/bytearray
use common/common.{bls12_381_base_prime, bls12_381_half_prime}

/// Affine representation of a point on the BLS12-381 G1 curve
pub type G1Affine {
  /// Point at infinity
  G1Infinity
  /// Finite point with x and y coordinates
  G1Point { x: ByteArray, y: ByteArray }
}

/// Affine representation of a point on the BLS12-381 G2 curve
pub type G2Affine {
  /// Point at infinity
  G2Infinity
  /// Finite point with x and y coordinates (each coordinate is 2 field elements)
  G2Point { x: (ByteArray, ByteArray), y: (ByteArray, ByteArray) }
}

/// Compress a G1 affine point to 48 bytes using BLS12-381 standard
pub fn g1_affine_compress(point: G1Affine) -> ByteArray {
  when point is {
    G1Infinity -> {
      // BLS12-381 infinity encoding: compression bit (0x80) + infinity bit (0x40) = 0xc0
      let infinity_byte = #"c0"
      let zeros = bytearray.from_int_big_endian(0, 47)
      // 47 bytes of zeros
      bytearray.concat(infinity_byte, zeros)
    }
    G1Point { x, y } -> {
      // Manual BLS12-381 G1 compression
      // Set compression bit (0x80) and determine y-coordinate lexicographic ordering
      let first_x_byte = bytearray.take(x, 1)
      let rest_x = bytearray.drop(x, 1)
      // Check if y > (p-1)/2 to determine which of the two possible y values this is.
      // The sort bit (0x20) indicates the "lexicographically larger" y-coordinate.
      let y_int = bytearray.to_int_big_endian(y)
      let y_is_larger = y_int > bls12_381_half_prime
      // Set the compression bit (0x80) and y-coordinate bit if needed
      let compressed_first_byte =
        if y_is_larger {
          // 0x80 | 0x20 = 0xa0: compression + sort bit
          bytearray.or_bytes(first_x_byte, #"a0", False)
        } else {
          // 0x80 only: compression bit, no sort bit
          bytearray.or_bytes(first_x_byte, #"80", False)
        }
      bytearray.concat(compressed_first_byte, rest_x)
    }
  }
}

/// Compress a G2 affine point to 96 bytes using BLS12-381 standard
pub fn g2_affine_compress(point: G2Affine) -> ByteArray {
  when point is {
    G2Infinity -> {
      // BLS12-381 G2 infinity encoding: compression bit (0x80) + infinity bit (0x40) = 0xc0
      let infinity_byte = #"c0"
      let zeros = bytearray.from_int_big_endian(0, 95)
      // 95 bytes of zeros
      bytearray.concat(infinity_byte, zeros)
    }
    G2Point { x: (x0, x1), y: (y0, y1) } -> {
      // Manual BLS12-381 G2 compression
      // G2 uses Fp2 elements: each coordinate is (c0, c1) representing c0 + c1*u
      // where x0=c0 (real), x1=c1 (imaginary) per snarkjs convention.
      //
      // BLST serialization format: [c1_with_flags | c0] (imaginary first, real second)
      // So we put x1 first (with flags), then x0.
      let first_x1_byte = bytearray.take(x1, 1)
      let rest_x1 = bytearray.drop(x1, 1)
      // Determine y sort bit using Fp2 lexicographic ordering:
      // Compare c1 (imaginary) of y first. If c1 is zero, compare c0 (real).
      let y1_int = bytearray.to_int_big_endian(y1)
      let y0_int = bytearray.to_int_big_endian(y0)
      let y_is_larger =
        if y1_int == 0 {
          y0_int > bls12_381_half_prime
        } else {
          y1_int > bls12_381_half_prime
        }
      // Set compression and y-ordering bits
      let compressed_first_byte =
        if y_is_larger {
          // 0x80 | 0x20 = 0xa0: compression + sort bit
          bytearray.or_bytes(first_x1_byte, #"a0", False)
        } else {
          // 0x80 only: compression bit, no sort bit
          bytearray.or_bytes(first_x1_byte, #"80", False)
        }
      // Return compressed form: [c1_with_flags | c0] (96 bytes total)
      bytearray.concat(bytearray.concat(compressed_first_byte, rest_x1), x0)
    }
  }
}

pub fn g1_on_curve(point: G1Affine) -> Bool {
  when point is {
    G1Infinity -> True
    G1Point { x, y } -> {
      // Check if the point satisfies the BLS12-381 G1 curve equation: y^2 = x^3 + 4
      let x_int = bytearray.to_int_big_endian(x)
      let y_int = bytearray.to_int_big_endian(y)
      let lhs = y_int * y_int % bls12_381_base_prime
      let rhs = ( x_int * x_int * x_int + 4 ) % bls12_381_base_prime
      lhs == rhs
    }
  }
}
