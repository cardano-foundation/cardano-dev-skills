//// Property-based tests for the Groth16 verifier.
////
//// `prop_*` tests state behaviour the verifier must keep. `known_issue_*`
//// tests pin down a filed bug: they pass today *because* the bug exists, so
//// fixing the issue makes them fail. When that happens, replace the test with
//// the property named in its comment.

use aiken/builtin
use aiken/collection/list
use aiken/crypto/bls12_381/g1
use aiken/crypto/bls12_381/g2
use aiken/crypto/bls12_381/scalar.{field_prime}
use aiken/fuzz
use groth/groth.{CompressedProof, CompressedVK, verify_compressed}

/// Same fixture as `groth_verify_pass_1`: a proof valid for `[561, 3]`.
pub const groth_vk: CompressedVK =
  CompressedVK {
    alpha: #"8e3d9e248feda194cb6fa0a3b64fd2a380cb5e94836bf8148bf97ebcbb5819d9a78f63102f0293c104bcbb2f810d8eb4",
    beta: #"8cd68a7186a908212680a0234d8210c20328f8fb3ce1d69c9aec9330a5802d6cfaf6d7cf3176133221c19188590cb4141874ea7bbfcb9872931e115d882c46b90c3dcbcee10062d1c9b9b0a691d7bec7d2735f06495c7f71dea210e55b2782df",
    gamma: #"93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8",
    delta: #"938231fcec443fbdeb1079ff126b8f69bd8579ffe82d39923214d4345395beee60200288fa20c97ae50f3212131b6f8802af2f9f515c65af6a9a6c294c738590104376a0af44731d6699db6a286608774243f7d1dddc4605eb340e65e15060a5",
    vkIC: [
      #"b5813c90d3455acb8608fdf66e8601f24ef048f3fdf9384862d77c72cb5cddfde2b307976b1b0319c42ba985f94be60a",
      #"a41a0e6370c054be0f9acce08e97f6d5702d9daa9e9a934e8a377f553593baa1c58062adc73d63558653422d54d6f50c",
      #"8e02a87c519c3145f984d25fdf769f74fbc36626c385d4554fb4bc1d7a12cbf669d40f257023b8b3c9a31e631aa8f981",
    ],
  }

pub const groth_proof: CompressedProof =
  CompressedProof {
    a: #"8b84d092731c653b1accdda79c51e3f5d289bed7311189d927deadef0470e437e6d1d400634726512a79a015867424e3",
    b: #"92cb1c125816e4b522c7f430a5d74a61116b6189de7b2341f040194c02f10d9ef0cf081f4029444a65ea74e69d98b1cf08d3864087d5d2dee2ed6ab102f9b78e65d341f0824341a9fc25d0ea9dacccc5d355b4eddb0057949370a19c47135b0e",
    c: #"a4ef633c858a3ff194db50eacdf715f7296fb3d1202c54b543284e9656b69aa90f33ac0e2572d3ab847b88268dcd1f7e",
  }

pub const groth_inputs: List<Int> = [561, 3]

/// A uniformly random non-zero scalar in `[1, r)`.
pub fn nonzero_scalar() -> Fuzzer<Int> {
  fuzz.int_between(1, field_prime - 1)
}

/// Replace the element at `index` with `f(element)`.
pub fn update_at(xs: List<Int>, index: Int, f: fn(Int) -> Int) -> List<Int> {
  list.indexed_map(
    xs,
    fn(j, x) {
      if j == index {
        f(x)
      } else {
        x
      }
    },
  )
}

// ---------------------------------------------------------------------------
// Properties
// ---------------------------------------------------------------------------

/// Moving any public input to a different value in `[0, r)` must break the
/// proof.
test prop_groth_rejects_changed_input(
  (index, delta) via fuzz.tuple(fuzz.int_between(0, 1), nonzero_scalar()),
) {
  let inputs =
    update_at(groth_inputs, index, fn(x) { ( x + delta ) % field_prime })
  !verify_compressed(groth_vk, groth_proof, inputs)
}

/// Replacing one proof element with an unrelated valid curve point must break
/// the proof. (`k` hitting the real discrete log has probability ~2^-255.)
test prop_groth_rejects_replaced_proof_point(
  (which, k) via fuzz.tuple(fuzz.int_between(0, 2), nonzero_scalar()),
) {
  let s = scalar.from_int(k)
  let proof =
    if which == 0 {
      CompressedProof {
        ..groth_proof,
        a: g1.compress(g1.scale(g1.generator, s)),
      }
    } else if which == 1 {
      CompressedProof {
        ..groth_proof,
        b: g2.compress(g2.scale(g2.generator, s)),
      }
    } else {
      CompressedProof {
        ..groth_proof,
        c: g1.compress(g1.scale(g1.generator, s)),
      }
    }
  !verify_compressed(groth_vk, proof, groth_inputs)
}

/// Fewer inputs than the key expects must fail.
test groth_rejects_missing_input() fail {
  verify_compressed(groth_vk, groth_proof, [561])
}

// ---------------------------------------------------------------------------
// Known issues
// ---------------------------------------------------------------------------

/// ADAOcommunity/zk#11: inputs past the end of `vkIC` are ignored.
/// Once fixed, replace with `prop_groth_rejects_extra_inputs` (the same call
/// must fail).
test known_issue_11_groth_extra_inputs_ignored(
  extra via fuzz.list_between(fuzz.int(), 1, 5),
) {
  verify_compressed(groth_vk, groth_proof, list.concat(groth_inputs, extra))
}

/// ADAOcommunity/zk#12: an input of `x + k * r` verifies like `x`.
/// Once fixed, replace with `prop_groth_rejects_input_out_of_field` (the same
/// call must fail).
test known_issue_12_groth_input_not_range_checked(
  (index, k) via fuzz.tuple(fuzz.int_between(0, 1), fuzz.int_between(1, 1000)),
) {
  let inputs = update_at(groth_inputs, index, fn(x) { x + k * field_prime })
  verify_compressed(groth_vk, groth_proof, inputs)
}

/// Sanity check that the builtin really reduces mod `r`, which is what makes
/// #12 possible. Unlike the test above, this one should keep passing after #12
/// is fixed, since the fix belongs in the verifier.
test prop_g1_scalar_mul_reduces_mod_r(
  (x, k) via fuzz.tuple(fuzz.int_between(0, 10000), fuzz.int_between(1, 1000)),
) {
  builtin.bls12_381_g1_scalar_mul(x + k * field_prime, g1.generator) == builtin.bls12_381_g1_scalar_mul(
    x,
    g1.generator,
  )
}
