use aiken/builtin.{
  bls12_381_final_verify,
  bls12_381_g1_add,
  bls12_381_g1_uncompress,
  bls12_381_g2_uncompress,
  bls12_381_miller_loop,
  bls12_381_mul_miller_loop_result,
}
use aiken/crypto/bls12_381/g1 as g1
use aiken/crypto/bls12_381/scalar as scalar

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Groth16 proof consisting of three compressed curve points.
pub type Proof {
  a: ByteArray,
  b: ByteArray,
  c: ByteArray,
}

/// Groth16 verification key — everything needed to verify a proof.
///
/// * `alpha_g1` — 48-byte compressed G1 point (`alpha * G1`).
/// * `beta_g2`  — 96-byte compressed G2 point (`beta * G2`).
/// * `gamma_g2` — 96-byte compressed G2 point (`gamma * G2`).
/// * `delta_g2` — 96-byte compressed G2 point (`delta * G2`).
/// * `ic`       — list of 48-byte compressed G1 points. `ic[i] = Psi_V_G1[i]`.
///                  Only the first `n_public` entries are used for `V`.
/// * `n_public` — number of public variables (including the constant wire).
pub type VerificationKey {
  alpha_g1: ByteArray,
  beta_g2: ByteArray,
  gamma_g2: ByteArray,
  delta_g2: ByteArray,
  ic: List<ByteArray>,
  n_public: Int,
}

// ---------------------------------------------------------------------------
// Hard-coded verification key (compressed BLS12-381 points)
// ---------------------------------------------------------------------------

/// alpha * G1  (scalar = 5)
const alpha_g1 =
  #"b0e7791fb972fe014159aa33a98622da3cdc98ff707965e536d8636b5fcc5ac7a91a8c46e59a00dca575af0f18fb13dc"

/// beta * G2  (scalar = 7)
const beta_g2 =
  #"8d0273f6bf31ed37c3b8d68083ec3d8e20b5f2cc170fa24b9b5be35b34ed013f9a921f1cad1644d4bdb14674247234c8049cd1dbb2d2c3581e54c088135fef36505a6823d61b859437bfc79b617030dc8b40e32bad1fa85b9c0f368af6d38d3c"

/// gamma * G2  (scalar = 11)
const gamma_g2 =
  #"a190be857d602284393305bfe0a29e29a6982ed3f04ccaabafb7e59cdc7eda85c22bc3e8690355c7a0fb7590ae40f1b009303f04d568e289a35102b6df883d5ed620355c0eb5d02236718cdaf99fba6e19ef5cee2996268eb9a53ae1ee09bce3"

/// delta * G2  (scalar = 13)
const delta_g2 =
  #"8bf78a97086750eb166986ed8e428ca1d23ae3bbf8b2ee67451d7dd84445311e8bc8ab558b0bc008199f577195fc39b7152110e866f1a6e8c5348f6e005dbd93de671b7d0fbfa04d6614bcdd27a3cb2a70f0deacb3608ba95226268481a0be7c"

/// Psi_V_G1[1] = (w_1(tau) * alpha + u_1(tau) * beta + w_1(tau)) / gamma * G1
/// For our circuit, variable 1 is the public output `a`. Scalar = 3/gamma.
const psi_v_g1_1 =
  #"a087561bc7f3b2650328084de8424253a1846fe77fb0f498a3fade9d70b556016d1de5d0490fa64a444a1f53cc13d70d"

// ---------------------------------------------------------------------------
// Hard-coded proof for the concrete witness [1, 48, 2, 2, 3, 4, 4, 12]
// ---------------------------------------------------------------------------

/// A = (l(tau)+alpha) * G1  (combined scalar = 10)
const proof_a =
  #"af81da25ecf1c84b577fefbedd61077a81dc43b00304015b2b596ab67f00e41c86bb00ebd0f90d4b125eb0539891aeed"

/// B = (r(tau)+beta) * G2  (combined scalar = 33)
const proof_b =
  #"ab0f336a9b3ee493b210f64587b8c1d5fab0a86346812545a822692c40ee4eecb349a69388ba3ad13ea3c5f8d29eb36506547761152a1517a6fffeefff70c7e817bdcf94dfa8e25955a0b4ac6ffcfd9477d7230902453d78bac3bcd06dbbb457"

/// C = (sum_private + h(tau)*T(tau)/delta) * G1  (combined scalar = 151/delta)
const proof_c =
  #"b697c05f3d58d125ed8630e8f547dd5a952c33753b65629e18efcada75d443690fc1f3759dfb55edc35e4d03dd17860e"

// ---------------------------------------------------------------------------
// Convenience constructors (for backward compatibility / tests)
// ---------------------------------------------------------------------------

/// The hard-coded valid proof for the concrete circuit.
pub fn hardcoded_proof() -> Proof {
  Proof { a: proof_a, b: proof_b, c: proof_c }
}

/// The hard-coded verification key for the concrete 3-constraint circuit.
pub fn hardcoded_verification_key() -> VerificationKey {
  VerificationKey {
    alpha_g1,
    beta_g2,
    gamma_g2,
    delta_g2,
    ic: [
      // Variable 0 (constant `1`) — point at infinity
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      // Variable 1 (output `a`) — psi_v_g1_1
      psi_v_g1_1,
      // Variables 2..7 are private — their ic entries are never used by the verifier,
      // but we include them so `ic` has one entry per variable (8 total).
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    ],
    n_public: 2,
  }
}

// ---------------------------------------------------------------------------
// Verifier
// ---------------------------------------------------------------------------

/// Verify a Groth16 proof against a supplied verification key.
///
/// * `proof`         – compressed points `(A, B, C)`.
/// * `public_inputs` – list of public witness values. The length must match
///                     `vk.n_public`. Variable 0 is the constant `1`.
/// * `vk`            – verification key containing CRS points and `ic` list.
///
/// Returns `True` iff the Groth16 pairing equation holds.
pub fn verify(proof: Proof, public_inputs: List<Int>, vk: VerificationKey) -> Bool {
  // Decompress proof points.
  let a = bls12_381_g1_uncompress(proof.a)
  let b = bls12_381_g2_uncompress(proof.b)
  let c = bls12_381_g1_uncompress(proof.c)

  // Decompress VK fixed points.
  let alpha = bls12_381_g1_uncompress(vk.alpha_g1)
  let beta = bls12_381_g2_uncompress(vk.beta_g2)
  let gamma = bls12_381_g2_uncompress(vk.gamma_g2)
  let delta = bls12_381_g2_uncompress(vk.delta_g2)

  // Compute the public-input commitment V.
  let v = compute_public_input_commitment(public_inputs, vk.ic, vk.n_public)

  // Pairing check:
  //   e(A, B) == e(alpha·G1, beta·G2) · e(C, delta·G2) · e(V, gamma·G2)
  let lhs = bls12_381_miller_loop(a, b)

  let rhs = bls12_381_miller_loop(alpha, beta)
  let rhs = bls12_381_mul_miller_loop_result(rhs, bls12_381_miller_loop(c, delta))
  let rhs = bls12_381_mul_miller_loop_result(rhs, bls12_381_miller_loop(v, gamma))

  bls12_381_final_verify(lhs, rhs)
}

/// Compute the public-input commitment `V = Σ a_i · ic[i]`.
///
/// * `public_inputs` – witness values for the public variables.
/// * `ic`            – list of compressed G1 points (`Psi_V_G1`), one per variable.
/// * `n_public`      – number of public variables to consume from the front of the lists.
///
/// Returns the identity point if the input lengths are mismatched or `n_public`
/// is zero — this causes the pairing check to fail for malformed input.
fn compute_public_input_commitment(
  public_inputs: List<Int>,
  ic: List<ByteArray>,
  n_public: Int,
) -> G1Element {
  // Build the MSM over the first `n_public` entries.
  do_compute_v(public_inputs, ic, n_public, g1.zero)
}

/// Tail-recursive helper that accumulates `v` one public input at a time.
fn do_compute_v(
  public_inputs: List<Int>,
  ic: List<ByteArray>,
  remaining: Int,
  acc: G1Element,
) -> G1Element {
  if remaining <= 0 {
    acc
  } else {
    when (public_inputs, ic) is {
      ([input, ..rest_inputs], [ic_point, ..rest_ic]) -> {
        let pt = bls12_381_g1_uncompress(ic_point)
        let s = scalar.from_int(input)
        let weighted = g1.scale(pt, s)
        do_compute_v(rest_inputs, rest_ic, remaining - 1, bls12_381_g1_add(acc, weighted))
      }
      _ -> g1.zero
    }
  }
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

test test_verify_hardcoded_proof() {
  let proof = hardcoded_proof()
  let vk = hardcoded_verification_key()
  verify(proof, [1, 48], vk)
}

test test_verify_reject_wrong_public_input() {
  let proof = hardcoded_proof()
  let vk = hardcoded_verification_key()
  // Wrong public output (49 instead of 48) changes V and breaks the pairing.
  !verify(proof, [1, 49], vk)
}

test test_verify_reject_tampered_proof() {
  let vk = hardcoded_verification_key()
  // Replace C with the G1 generator: valid point, wrong proof.
  let bad_c =
    #"97f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb"
  let bad_proof = Proof { a: proof_a, b: proof_b, c: bad_c }
  !verify(bad_proof, [1, 48], vk)
}

test test_compute_public_input_commitment_matches_expected_v() {
  let vk = hardcoded_verification_key()
  let v = compute_public_input_commitment([1, 48], vk.ic, vk.n_public)
  let expected_v =
    bls12_381_g1_uncompress(
      #"b5ae7b97f37351dbfa7c343f60ac8c1c53a4ab74b227970e8415d5d7a791498cdb0f4bd32809129a90096188dea1b8a0",
    )
  g1.equal(v, expected_v)
}

// ---------------------------------------------------------------------------
// Tests with a *different* VK (ensures verify is not accidentally falling back
// to hard-coded constants).
// ---------------------------------------------------------------------------

test test_verify_fails_with_wrong_vk_alpha() {
  let proof = hardcoded_proof()
  let vk = hardcoded_verification_key()
  // Tamper with alpha_g1 (replace with G1 generator)
  let bad_vk = VerificationKey {
    ..vk,
    alpha_g1: #"97f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb",
  }
  !verify(proof, [1, 48], bad_vk)
}

test test_verify_fails_with_wrong_vk_beta() {
  let proof = hardcoded_proof()
  let vk = hardcoded_verification_key()
  // Tamper with beta_g2 (replace with G2 generator)
  let bad_vk = VerificationKey {
    ..vk,
    beta_g2: #"93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8",
  }
  !verify(proof, [1, 48], bad_vk)
}

test test_verify_fails_with_wrong_vk_ic() {
  let proof = hardcoded_proof()
  let vk = hardcoded_verification_key()
  // Tamper with ic[1] (replace with point at infinity)
  let bad_ic = [
    vk.ic |> head,
    #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    ..(vk.ic |> tail |> tail)
  ]
  let bad_vk = VerificationKey { ..vk, ic: bad_ic }
  !verify(proof, [1, 48], bad_vk)
}

fn head(list: List<a>) -> a {
  when list is {
    [x, ..] -> x
    _ -> fail @"head called on empty list"
  }
}

fn tail(list: List<a>) -> List<a> {
  when list is {
    [_, ..rest] -> rest
    _ -> []
  }
}

// ---------------------------------------------------------------------------
// Generalization tests — arbitrary-length public inputs
// ---------------------------------------------------------------------------

test test_single_public_input() {
  // A VK with one public variable (just the constant wire).
  let vk = VerificationKey {
    alpha_g1,
    beta_g2,
    gamma_g2,
    delta_g2,
    ic: [
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    ],
    n_public: 1,
  }
  // Any proof paired with this VK will fail because the VK does not match the
  // hard-coded circuit, but the MSM for V should still compute the identity.
  // We only assert that the function runs and returns a Bool.
  let _result = verify(hardcoded_proof(), [1], vk)
  True
}

test test_zero_public_inputs() {
  let vk = VerificationKey {
    alpha_g1,
    beta_g2,
    gamma_g2,
    delta_g2,
    ic: [],
    n_public: 0,
  }
  let _result = verify(hardcoded_proof(), [], vk)
  True
}

// ---------------------------------------------------------------------------
// End-to-end Circom pipeline test
// ---------------------------------------------------------------------------

/// Verification key exported from the Rust dev ceremony on the compiled
/// `SimpleExample/multiplier.circom` circuit (3 constraints, 8 wires,
/// 2 public variables: constant `1` and output `a`).
fn simple_example_vk() -> VerificationKey {
  VerificationKey {
    alpha_g1: #"81802380864a9f81298b8b82413406b4df3e0b5fd97a66e18ca464ed6e0be83b1c09ab2c2f4e3ecf8527bea992aeeb25",
    beta_g2: #"a71f88c45cb4aca43947a6f8b4b45ecd85516b8a9438ee11f301393140c54f594fa01158167dde0d3ca1a383c2f720f20d9d3ec49300f7cf388fb492328eeddc777b7345ecac3fded1d541856e941d315e0a6e7d513fc02a01748f59f36ab002",
    gamma_g2: #"b52ff6d727d7499a6ef7194fecf44fa0a03743fcf58e4727a8f42d1fc0cd0830a37ceece819da818af09721d2c32260f0c647be82c35de92a087eb3a4c85c5dfd60da9d973d7075ae707a2be33c848884ff19a3d13cdc200bb82e978f993c5cf",
    delta_g2: #"a9954557c3215b9e27fe7aafd760087ee842c564739e57ba330dc58e4ee72798aa2a2f5218a90b06616918123588fa50119a7c91ae4f81a68c5cd4f027325b31688fa5c4da9961440c1fac2df4fc5232890f617758210ca3d4afe67c6fe6e3f5",
    ic: [
      // ic[0] — constant wire
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      // ic[1] — public output `a`
      #"99d2c73cb79eaef7a45982beb31c038d69c4d88b835b4ecdcc2d3524677bb7eb35b0cc4b991a1ed0ca1e8e746a80948a",
      // ic[2] — private x1
      #"8857efc20ffabaa6837b770e22ad25c09cb081bbcce6da252d104e9fa08e2e1a5fd9476cb68e4cf2a4fe6bd6450124d2",
      // ic[3] — private x2
      #"936106b42859b335e2cf1c491124c5c18eb0a1cc117373f43cf2d1310748c22444c695a3e81350d68ff18ad5de4885ed",
      // ic[4] — private x3
      #"8592db99ef875c762756ad9518ac22644786c6abe7f15890628328e32498cc85578e793c06412fd940975a6468b25f4a",
      // ic[5] — private x4
      #"988764bb6e7823cf4c83658c458c70e096b419730faac5bb118a491534abc8892aea37bc7518946e836d376c9ef9fce6",
      // ic[6] — intermediate x5
      #"80f042242a53ece532781b2872667d1e66dd1d90dcb934bf9d6fcecd2034509e04eaf73d0ba1e0ab013e7527cb11d64d",
      // ic[7] — intermediate x6
      #"9137a31cdef863c5bbb927f23a7d761a011ae8a46415fe4f8ab6eba18b3a9511be26ff5d1b5c659dce66064698454a9c",
    ],
    n_public: 2,
  }
}

/// Proof generated by the Rust prover (Pippenger, FFT engine) for the
/// witness [1, 48, 2, 2, 3, 4, 4, 12] with the VK above.
fn simple_example_proof() -> Proof {
  Proof {
    a: #"b2d8a0555803aff03b02c7a9de897f6fe1909e728c3a1668497756dfb6d92c8c73633d0a178251182947a552c92f8bd2",
    b: #"8170b0e3032a62c50fe2222467a348f5b2f78f7a91072c1c8524708ddd17c017b5cdec3e2145a2d4f60286a5c034227a159020f5c6cf7309b5050c2b5fa6741593add450583fc7cc935a65baac7df7950357a62580c797a1d3bb2b8452778e7b",
    c: #"b8ea5b9db7f801e194f7c6a5d2c21911cbc0923166327651cdd8c48a7a1f2b5e1ac3bb4c8bcea77b01f460c72a11e293",
  }
}

test test_verify_circom_simple_example_proof() {
  // Public witness values for SimpleExample: [constant 1, output a = 48]
  verify(simple_example_proof(), [1, 48], simple_example_vk())
}

test test_verify_circom_rejects_wrong_public_input() {
  // Changing the public output breaks V and the pairing check fails.
  !verify(simple_example_proof(), [1, 49], simple_example_vk())
}

// ---------------------------------------------------------------------------
// End-to-end Circom pipeline test — spend_depth2 (Merkle Membership)
// ---------------------------------------------------------------------------

/// Verification key exported from the Rust dev ceremony on the compiled
/// `Privacy/spend_depth2.circom` circuit (1107 constraints, 1110 wires,
/// 1 public variable: constant `1`). All user inputs are private.
fn spend_depth2_vk() -> VerificationKey {
  VerificationKey {
    alpha_g1: #"a4e738684ce4f4c452c7f45da24b55ccc1debdbd9fba87adfa289a78e36254bbbf0ce6db30772d5fc3e4c3aac95138e7",
    beta_g2:  #"8057122dd4a4b82f7a5cdb90706f6263cf972b2e92ccf612906c52e77e579d2b2df05768726bd0e4849fb1459d16570016f92a36d8d297c47f476ba5373a596394abcb9c42aeaea2cc902307f0666096b1108c4236aa632a394d536f9608da37",
    gamma_g2: #"a8968e061c90cb6d98955dc818698202dd67c371932254b809aee4b7ca180ac0cb787a082266e495e0e15088777ac7a2056d49974b89e4ab4cee932dd2af73a16793a4b307023896c4edfbc3a11c808a88896482e6ccd3f524eec33d67bd537a",
    delta_g2: #"9280aad4ec158a0f786748da21ad8cbe3e48e2bab2c0f83ad665679b791afa3170527c01e4a13dcc40dc033c2995590c0c35c74784c0e823fc0c483aa8df23db59c22a11ec618e688db88d41b84c485759ce2ec56238c7faba55d48de8c8ae4d",
    ic: [
      // ic[0] — constant wire
      #"b76720bb6ca264c36e0f9edf7d4e342811409fc16e8307ee79a27c5e6ffb296ce86a8fe2841f2ff1d27980cb695fbc46",
    ],
    n_public: 1,
  }
}

/// Proof generated by the Rust prover (Pippenger, FFT engine) for the
/// `spend_depth2` witness with all-private inputs.
fn spend_depth2_proof() -> Proof {
  Proof {
    a: #"a66e9aca5fa3114b86ee55ffac76455dbd938bb8ce47f69648e1d1a58bc9da6ac6b7b3a85abf36d02cbf4f36ff15ba39",
    b: #"a7643167f92361eec2a12a9981a557d4c5d7f2352af4c91a9a2730a0756a0e9a8bc37fcf61dd445953e666c928d5cfd616b4714e11d515794ba71555609747bd53861e23bc09d9a03ccd620d67396e4ca3461d6bd76bb3c768b7a1e0343a9c35",
    c: #"8d63c953ec1e07c04d5b9b6071a8035baefc9837a740999d3742b727000c06861d40b4706d590ef3e114f85562022726",
  }
}

test test_verify_circom_spend_depth2_proof() {
  // Public witness values for spend_depth2: [constant 1]
  verify(spend_depth2_proof(), [1], spend_depth2_vk())
}

// ---------------------------------------------------------------------------
// End-to-end Circom pipeline test — PoseidonPreimage
// ---------------------------------------------------------------------------

/// Verification key exported from the Rust dev ceremony on the compiled
/// `PoseidonPreimage/poseidon_preimage.circom` circuit (635 wires, 633 constraints,
/// 2 public variables: constant `1` and `hash_commitment`).
fn poseidon_preimage_vk() -> VerificationKey {
  VerificationKey {
    alpha_g1: #"aca7fbf7da27b90efa68d4dec1bc82bd5b4f44a2cff94e716fe9e982c2fb759e3fc3f852b500d93c10f6d3c0eb732215",
    beta_g2:  #"98f5e3fd0d98487d71895f8bc41966687c263db208c027044ac3b81e19f3ca091bbd9a56dd618e65c3d7a781aa72b96c1944de41f2755cab4072113c7eb231e4e075e358cd0b6a6ad41c4390ebb8ff873251806be04c49b1da96a3a32c6b6773",
    gamma_g2: #"b3fd12bc82093f85a9c89cce8dc9accdfb49d0d38f084445af9f02b364c68451755f24e0ceeb66cc7bd5027c410b7ed509b9fbd8183467ced65870b270153be6fc4dd6c7644337c9293c30b5efc9fd3fd67170c592c41d46db7861859049d65f",
    delta_g2: #"a0bee6f9c8a269c7bbc6a556b287b5e12f4203f2d2b7a5640317204b4406e95bdbbfcaff2641da7b52469c0f16d0d72f0ada04813bac8d594829bc8c827ebfac0be5ff97bcff70ae2cabb51f47a736a895b938d0e35d77112325136b4d396152",
    ic: [
      // ic[0] — constant wire
      #"a9a48b7eebb158ff92124cf5b6da93595117ee7bbd0f591959855ca0f31f7af5cb619494d3a48c4a19611d757d2d921b",
      // ic[1] — hash_commitment
      #"94f7fa99c3b140bcc918a73e60af97e1515aef73031dfc6444d3c494fc0734ff3e9cd115766425c909b97d2b9166837b",
    ],
    n_public: 2,
  }
}

/// Proof generated by the Rust prover (Pippenger, FFT engine) for the
/// `poseidon_preimage` witness with pre_image=42 and hash_commitment=Poseidon(42,0).
fn poseidon_preimage_proof() -> Proof {
  Proof {
    a: #"a7cbca0f636f1d3d8ccecd3007670e03209cb2e10b1de833afb7aa0ef9b2562695f32c283a2991d7c54225c1e28b6470",
    b: #"a9908b11b4dc9a375cdc9436d69ed9a725ff17cb9abe169a72ba0b2058a3f4403d635bdbb6bdf6194ed04e0485bca8d30ece693a47e7060204882335e66472809a62239a6f0997d8b7a614dd007357d1fa49a5ebee84b2a4a35190c7b00b7e6a",
    c: #"a00f0575e29f288ff88c5907a556272f11c1a6606306d8b203e1da840a3eb79c5405157b71e239ae892110f78940373d",
  }
}

test test_verify_poseidon_preimage_proof() {
  // Public witness values for PoseidonPreimage: [constant 1, hash_commitment]
  verify(poseidon_preimage_proof(), [1, 51191423336626179944841251760023912585519132135457039538281110745651405953568], poseidon_preimage_vk())
}

// ---------------------------------------------------------------------------
// End-to-end Circom pipeline test — PoseidonMerkle depth 2
// ---------------------------------------------------------------------------

/// Verification key exported from the Rust dev ceremony on the compiled
/// `PoseidonMerkle/poseidon_merkle_depth2.circom` circuit (1914 wires,
/// 1911 constraints, 2 public variables: constant `1` and `digest`).
fn poseidon_merkle_depth2_vk() -> VerificationKey {
  VerificationKey {
    alpha_g1: #"a1fdb9a0adbe1d1e6eea412e2949e28ef99fbc1c2cba95c8f297bb449d6fd7bc04038c7a3174a2d2a82d3e878605d041",
    beta_g2:  #"b6f5edacca5e15240e132534ff7875dc183615e0ed8663c6e0a2abbe464ec4c26f03a9fd2a6b1a0a0701621e4bcaa19a0aba25eb98b02185d525d9dd1e7623ae6e8981b2d3a81bb79807e6d3ab2dd63475f4be3aee87da57f932e9af0e39ce23",
    gamma_g2: #"a5a555f8300de66276437a04bdb349a547a1295c3c978048df1f62a69e02a58b4a2510b1d738c667d769e71897518b7a14244a2222128c38671ad7f0aa52e2ab9f06b17f78e99fccb2e252b23d98713cab40caf161964b241b899023382e3eaa",
    delta_g2: #"b18344a45a55f06e1db2f14a604626008a6b0e25c28e2dba1da46544082626812021f7bcb406a35b99254605344e2b220ca2f3b19f71f812a5d0e17532e73e533a374521092f7a2985f2f24ffe61c5cc78a91026ded4ac01a2531c8d5c90e161",
    ic: [
      // ic[0] — constant wire
      #"aafb4852e98aa5d447517c8f58a4f888a2b6754863dd2bb2db670fc383184afbc433163d24707e3c148cfdbdc0748e12",
      // ic[1] — public digest
      #"b1d7927030b340dc43050d5cb446113d52db543161fa32ffce4a5dd5c2558da973a200163efc59433cf0384e8b893f45",
    ],
    n_public: 2,
  }
}

/// Proof generated by the Rust prover (Pippenger, FFT engine) for the
/// `poseidon_merkle_depth2` witness with all-private inputs.
fn poseidon_merkle_depth2_proof() -> Proof {
  Proof {
    a: #"995676c1e1632296db8f0d26e63b745e11b7884c403058eb3a2f0299011ebca23a3253beb604e70ecd071623bf70fd2a",
    b: #"b8cdec8f4c748f9c1a442acaffc44fca47881dc1e608eb0b52cf106d7a4e0c7a069eaf5969e3c5ef51b60831f259641113cd3aca879e3e45e286ba4b18b74294c6242365f64fd155596b5179bb72f2ad1a02a7eb0a3e987c0bcade9f25ce7cf7",
    c: #"90e67db712394c6c51f3f393657c5d3ac427e7d3ff851ec1da648c1b982e34011bf12c0505f8fde12f1caac51d2795a5",
  }
}

test test_verify_poseidon_merkle_depth2_proof() {
  // Public witness values for poseidon_merkle_depth2: [constant 1, digest]
  verify(
    poseidon_merkle_depth2_proof(),
    [1, 27767334007479604591235432116682333146862525275372337062481971253587464115996],
    poseidon_merkle_depth2_vk(),
  )
}

test test_verify_poseidon_merkle_rejects_wrong_public_input() {
  // Changing the public digest breaks V and the pairing check fails.
  !verify(
    poseidon_merkle_depth2_proof(),
    [1, 27767334007479604591235432116682333146862525275372337062481971253587464115997],
    poseidon_merkle_depth2_vk(),
  )
}
