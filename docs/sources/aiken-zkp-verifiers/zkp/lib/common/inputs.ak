//// Checks on public inputs, shared by the Groth16 and PLONK verifiers.

use aiken/crypto/bls12_381/scalar.{field_prime}

/// True when `inputs` has exactly `expected` entries and each one lies in
/// `[0, r)`, where `r` is the BLS12-381 scalar field order.
///
/// Both verifiers reduce public inputs mod `r`, so without the range check
/// `x` and `x + r` verify with the same proof, and a validator that also reads
/// the input as a plain `Int` sees a value the proof didn't bind. Without the
/// count check, inputs the circuit has no slot for are never constrained.
pub fn check_public_inputs(inputs: List<Int>, expected: Int) -> Bool {
  when inputs is {
    [] -> expected == 0
    [x, ..rest] -> and {
        expected > 0,
        x >= 0,
        x < field_prime,
        check_public_inputs(rest, expected - 1),
      }
  }
}
