# BLS12-381 deep dive and app possibilities using it

## Overview

**BLS12-381** is the pairing-friendly elliptic curve that Cardano's Plutus V3 exposes natively (`bls12_381_G1_element`, `bls12_381_G2_element`, `bls12_381_millerLoop`, `bls12_381_finalVerify`). It is the same curve behind Ethereum's consensus proofs, Zcash's Sapling, and Cardano's native scripts — and the one piece of cryptography that makes *both* compact signatures and modern zero-knowledge proofs possible on-chain.

This repository is a working laboratory for that curve: the mathematics derived from scratch in SageMath, low-level Rust tooling, a complete Groth16 prover with trusted-setup ceremonies, and — most importantly — the applications that become reachable once you can pair, hash to a curve, and verify a proof inside a spending script.

| Layer | What it contains | Where |
|-------|-------------------|-------|
| **Mathematics** | Curve parameters, generators, pairings, the BLS signature scheme and its aggregation modes, VRF, KDF — derived and cross-checked in SageMath | [Curve overview](#bls12-381-elliptic-curves-overview) · [BLS](#bls) · [SageMath mechanics](#bls12-381-and-bls-mechanics-in-sagemath) |
| **Tooling** | Rust CLIs for the curve itself, Groth16 proving, setup ceremonies, and sparse Merkle trees | [Command-line tools](#command-line-tools) · [Groth16 with Aiken](#groth16-with-bls12-381-curve-primitives) |
| **zkVM** | Running Aiken programs inside a zero-knowledge VM (OpenVM, Jolt) and verifying the resulting proof on Cardano | [zkVM plan](./zkVM/README.md) |
| **On-chain verification** | Aiken (Plutus V3) verifiers — Groth16 pairing checks, Nova sumcheck verifiers, VRF, KDF, key generation | [Aiken on-chain verification](#aiken-on-chain-verification) |
| **Applications** | Selective disclosure, privacy pools, confidential transfers with auditor reveal, multi-user batch pools | [Spotlight: selective disclosure](#spotlight-selective-disclosure) |

### Command-line tools

Four standalone Rust CLIs, each self-contained under `clis/`:

| CLI | What it does | Docs |
|-----|--------------|------|
| [`bls12-381`](./clis/bls12-381/) | Low-level curve toolkit: seed and key generation (HKDF-SHA256), BLS signing with domain separation tags, G1/G2 point arithmetic (`mul`, `add`, `neg`), compressed ⇄ uncompressed conversion, and the optimal Ate pairing | [README](./clis/bls12-381/README.md) |
| [`groth16`](./clis/groth16/) | Proof lifecycle: `prove` / `verify` over Circom `.r1cs` + `.wtns` artifacts (FFT-QAP + Pippenger MSM, with sparse and h-scalar modes), plus `export-vk`, which emits a ready-to-paste Aiken verifying key | [README](./clis/groth16/README.md) |
| [`trusted-setup`](./clis/trusted-setup/) | Ceremony CLI: an instant single-party `ceremony-dev` for development and CI, and a multi-party Phase-2 MPC (`phase2 new → contribute → verify → finalize`) on top of a public Phase-1 `.ptau` SRS for production | [README](./clis/trusted-setup/README.md) |
| [`smt`](./clis/smt/) | Sparse Merkle trees over BLS12-381 with MiMC(x⁷) hashing: `insert` / `digest` / `path` / `verify`, plus `export` and `compute-inputs`, which produce the Circom witness JSON consumed by the privacy circuits | [README](./clis/smt/README.md) |

The CLIs are deliberately thin: the real work lives in library crates — [`groth16-prover`](./groth16-prover/) (Rust/arkworks Groth16, cross-checked bit-for-bit against Sage), [`nova-prover`](./nova-prover/) (Nova IVC folding and compression), and [`lattice-prover`](./lattice-prover/) (the post-quantum Lova folding track). Two more CLIs round out the set: [`nova`](./clis/nova/) for folding and compressing IVC chains, and [`lattice`](./clis/lattice/) for the Lova research track.

### Nova IVC

Nova-based Incremental Verifiable Computation (IVC) splits a long computation into `N` identical **step circuits**, each proving `state_{i+1} = f(step_i, state_i)`, and proves every step incrementally — keeping ceremony cost and per-step memory tied to the step size rather than to the total computation. The [`nova`](./clis/nova/) CLI drives it (`nova params / ceremony / fold / compress / verify`) on top of the [`nova-prover`](./nova-prover/) crate, which holds the design doc, the Relaxed-R1CS folding + compression SNARK roadmap, and the benchmarks; the steps reuse the classical Groth16 stack ([`groth16-prover`](./groth16-prover/)). The post-quantum counterpart of that track — lattice-based folding — is the [`lattice-prover`](./lattice-prover/) crate, with Lova as its first implementation.

> **Nova is maintained upstream.** The cutting-edge Nova implementation is **NovaSlim**, and it lives in its own repository: **[`paweljakubas/nova-slim`](https://github.com/paweljakubas/nova-slim)** — NIFS folding, transparent sumcheck compression, ~0.4 KiB on-chain proofs, no trusted setup and no pairings, with modular commitment (`pedersen` / `sis` / `hash`) and curve (BLS12-381, BN254, Pallas, Vesta, Grumpkin, Bandersnatch) backends. Everything Nova-related *in this repo* — the [`clis/nova`](./clis/nova/) CLI, the [`nova-prover`](./nova-prover/) crate, the [`aiken/nova`](./aiken/nova/) on-chain verifier, and the `novaslim_e2e.sh` scripts under [`aiken/selective-disclosure`](./aiken/selective-disclosure/) — is the in-tree snapshot of that work. **For new Nova work, start from `nova-slim`**; treat the in-tree copy as the reference point the rest of this repo is pinned to.
>
> **The in-tree `nova` CLI defaults to the paper-faithful path.** `nova compress` produces the Nova paper's construction — fold with NIFS, compress the folded instance with a Groth16 proof, verify with **one pairing** — and needs one trusted setup for the compression circuit. The transparent sumcheck paths (`--sumcheck`, `--slim`) remain one flag away and are what the upstream `nova-slim` CLI drives.

### Aiken on-chain verification

Everything above ends in the same place: a proof that has to be checked *on-chain*, inside a Plutus V3 spending script, cheaply enough to be worth doing. The `aiken/` tree holds those verifiers, each written against Cardano's native BLS12-381 builtins — the [Aiken stdlib primitives](https://aiken-lang.github.io/stdlib/aiken/crypto/bls12_381/g1.html) (`bls12_381_G1_element`, `bls12_381_G2_element`, `bls12_381_millerLoop`, `bls12_381_finalVerify`) and [ilap/bls](https://github.com/ilap/bls):

| Project | What it verifies on-chain | Docs |
|---------|--------------------------|------|
| [`aiken/groth16`](./aiken/groth16/) | Groth16 — the standard pairing check `e(A,B) = e(α,β)·e(C,δ)·e(V,γ)` over an arbitrary verifying key and public-input list; also holds the batched multi-pairing verifier | [README](./aiken/groth16/README.md) |
| [`aiken/nova`](./aiken/nova/) | Slim Nova IVC proofs — a sumcheck argument with on-chain Fiat-Shamir challenge derivation, plus a reusable SD Predicate Gate whose policy lives in the datum rather than in the script. The prover side is upstream in [`paweljakubas/nova-slim`](https://github.com/paweljakubas/nova-slim) | [README](./aiken/nova/README.md) |
| [`aiken/selective-disclosure`](./aiken/selective-disclosure/) | The nine-step selective-disclosure pipeline — predicate → ElGamal → privacy pool → auditor reveal → batch → revocation → delegation → recursion | [README](./aiken/selective-disclosure/README.md) |
| [`aiken/f5`](./aiken/f5/) | Multi-user private pool: one shared Merkle root of note commitments, with N spends verified as a single multi-pairing product | [README](./aiken/f5/README.md) |
| [`aiken/vrf`](./aiken/vrf/) | Verifiable Random Function — deterministic, verifiable, non-interactive randomness | [README](./aiken/vrf/README.md) |
| [`aiken/kdf`](./aiken/kdf/) | HKDF (RFC 5869) and PBKDF2 (RFC 8018) plus BLS12-381 key generation, with an explicit warning about what must never be hashed on-chain | [README](./aiken/kdf/README.md) |
| [`aiken/publickey-aggregation-case`](./aiken/publickey-aggregation-case/) · [`aiken/signature-aggregation-case`](./aiken/signature-aggregation-case/) | The two BLS aggregation modes — aggregate public keys over one message, or aggregate signatures over many — and the rogue-key caveat that forces the choice of `g2_basic` | [PK aggregation](./aiken/publickey-aggregation-case/README.md) · [SIG aggregation](./aiken/signature-aggregation-case/README.md) |

### Spotlight: selective disclosure

<details>
<summary><b>Proving a predicate without revealing the credential — the nine-step pipeline (click to expand)</b></summary>

The application this repository ultimately builds toward is **selective disclosure**: proving a predicate over a credential — *I am over 21*, *I am a doctor*, *I live in an approved jurisdiction* — **without revealing the credential's fields, the holder's identity, or the transaction address**. Authorization comes from a zero-knowledge proof checked by an Aiken gate script, not from a signature by a known address.

The implementation is a nine-step pipeline ([`aiken/selective-disclosure`](./aiken/selective-disclosure/README.md)), and every step is runnable end-to-end from the repo root:

```bash
./aiken/selective-disclosure/step1/groth16_e2e.sh   # predicate proof — the simplest flow
./aiken/selective-disclosure/step6/groth16_e2e.sh   # multi-user batch with full auditor reveal
./aiken/selective-disclosure/f5_pipeline_e2e.sh     # steps 1 → 2 → 3 in a single run
```

| Step | What it proves | Groth16 proof | Nova slim proof |
|------|----------------|---------------|-----------------|
| 1 — Predicate | `age ≥ 21`, membership in an approved set | 192 B | 758 B |
| 2 — Twisted ElGamal | amounts encrypted, each limb range-proven | 192 B | 462 B |
| 3 — Privacy pool | note membership + fresh nullifier + value conservation | 192 B | 610 B |
| 4 — Compliant transfer | amount revealed to a viewing key only | 192 B | 684 B |
| 5 — Full auditor reveal | amount **and** recipient address revealed | 192 B | 758 B |
| 6 — Multi-user batch | N spends, one batched pairing check | 192 B × N | 758 B |
| 7 — Revocable credential | not expired, not revoked (SMT non-membership) | 192 B | ~758 B |
| 8 — Delegation | a proxy may generate proofs, bound and expiring | 192 B | ~758 B |
| 9 — Recursive aggregation | epoch batches folded into one transparent proof | — | ~795 B (scaffold) |

Two proof paths run side by side: **Groth16** (192-byte proofs, per-circuit trusted setup, cheapest on-chain) and **Nova IVC** (~0.45–0.8 KiB across the steps above, no trusted setup, step circuits composable across predicates). Both are checked on-chain by the Aiken validators above — the Groth16 path by a pairing check, the Nova path by a sumcheck. The Nova prover that drives these scripts is upstream in [`paweljakubas/nova-slim`](https://github.com/paweljakubas/nova-slim) — see [Nova IVC](#nova-ivc) above.

The property that makes this interesting: the gate script checks only the *truth value* of a predicate. The holder's address never enters the datum or the redeemer, so any valid proof unlocks any UTxO at that gate — the anonymity set is every user of the gate, not the owner of the funds. Compliance is layered on top rather than baked in: Steps 4–6 encrypt the amount (and the address) to a designated auditor's viewing key, so oversight remains possible without weakening the privacy of the transaction graph.

</details>

### Useful general information about elliptic curve and its basic usage

<details>
<summary><b>BLS12-381 elliptic curves overview (click to expand)</b></summary>

## BLS12-381 elliptic curves overview

The same three letters, **BLS**, stand here for Barreto-Lynn-Scott — the authors of the curve family, not of the signature scheme of the next section, which takes the same abbreviation from Boneh-Lynn-Shacham. The family of curves was introduced in this [seminal paper](https://eprint.iacr.org/2002/088.pdf).
BLS12-381 curve was proposed by [Sean Bowe in the context of ZCash](https://electriccoin.co/blog/new-snark-curve/).
The usage of this curve was adopted in number of other blockchains, like Ethereum 2.0, Skale, Algorand, Dfinity or Chia.
There is also support of this curve in Cardano, see for example, [cardano-crypto-class](https://github.com/IntersectMBO/cardano-base/tree/master/cardano-crypto-class) and the curve is exposed also in [aiken from 3.0 release](https://aiken-lang.github.io/stdlib/aiken/crypto.html). The great introduction and motivation for this curve was written in the blog post [BLS12-381 For The Rest Of Us](https://hackmd.io/@benjaminion/bls12-381#Motivation).
It is especially worth mentioning and repeating that the elliptic curve BLS12-381 is currently in [IETF draft revision 12](https://datatracker.ietf.org/doc/draft-irtf-cfrg-pairing-friendly-curves/12/) stage of ratification and also included in [standards directory](standards/draft-irtf-cfrg-pairing-friendly-curves-12.txt).

</details>

<details>
<summary><b>BLS (click to expand)</b></summary>

## BLS

The abbreviation stands for the names of the scheme's inventors, ie., Boneh-Lynn-Shacham, who proposed the scheme in the
[Short signatures from the Weil pairing](https://mit6875.github.io/FA23HANDOUTS/boneh-lynn-shacham.pdf) paper.

### Secret, public key and pairing as a check

The scheme works for pairings-friendly elliptic curves within which two groups are chosen,  _G1_ and _G2_, with generators _g1_ and _g2_, respectively.
The secret key *sk* is then the number randomly picked between _1_ and _order(G1)_. The corresponding public key is

$pk=sk*g_2$

Having hashing function, $H(msg)*g_1$, we can get signature,

$sig=sk*H(msg)*g_1$

Given a pairing, _e_, verification is checking the equality

$e(H(m)*g_1,pk)==e(sig,g_2)$

Please notice that in any pairing we have elements from two groups, _G1_ and _G2_, the pairing shares.
And due to bilinearity property of the pairing the following holds

```math
e(H(m)*g_1,pk)=e(sk*H(m)*g_1,g_2)=e(sig, g_2)
```

The choices of representation of the different entities are not random and carefully picked. _G2_ is defined over the quadratic
extention of the field and hence the storage demands are larger for _G2_ elements than for elements of _G1_. The arithmetic requirements are harsher for _G2_ in comparison with _G1_.
If we are to store all public keys in application then it would be tempting to represent them in _G1_. If we are to store signatures then it is advantageous to
stick to the scheme proposed above. Especially, if **public keys could be aggregated** (as is the case for multi-signature).
Another performance dimension to ponder the verification of the scheme, as normally pairing operation is costly. Especially if we compare it to other elliptic curve signature schemes like
_Schnorr_ or _EdDSA_. However, as BLS allows for **signature aggregation**, which is not so straightforward in other schemes mentioned, the comparison picture changes dramatically in favor of BLS,
especially for big number multi-party cases (like voting).

The BLS scheme is [IEFT drafted](https://github.com/cfrg/draft-irtf-cfrg-bls-signature) and here we are aimimng to comply with it.

### Aggregate signature case

Let's assume we have _n_ participants that sign n **different** messages (each participant _i_ signs a different and single message $m_i$). Then we have n signatures
$sig_i$ for i=0..n-1. The aggregate signature is then

$\sum_{n=0}^{n-1} sig_i = sig_{agg}$

The verification requires the following pairing as a consequence

```math
e(H(m_0)*g_1,pk_0)*...*e(H(m_{n-1})*g_1,pk_{n-1})=e(sig_{agg}, g_2)
```

Meaning _n-1_ less pairing evaluation during verification thanks to $sig_{agg}$ .

### Aggregate signature and public key case

In multi-signature case, in addition to signature aggregation sketched above, all the signers sign **THE SAME** message.
In that case, we can aggregate also public keys:

$\sum_{n=0}^{n-1} pk_i = pk_{agg}$

and just two pairing evaluations on the verification side:

```math
e(sig_{agg}, g_2)=e(H(m), pk_{agg})
```

And this is regardless of the number of signatures engaged.

</details>

<details>
<summary><b>BLS12-381 and BLS mechanics in sagemath (click to expand)</b></summary>

## BLS12-381 and BLS mechanics in sagemath

The golden are generated using _SageMath_ and compliant with [IETF draft revision 6](https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-bls-signature-06)
and also included in [standards directory](standards/draft-irtf-cfrg-bls-signature-06.txt).
But to get a sense how things look like let's before envisage simple proof of concepts what we are after.

<details>
<summary>
In order to run it do the following:
Download the latest image from docker hub and run the image in Linux CLI </summary>

```bash
$ docker image pull sagemath/sagemath:latest
$ docker run -it sagemath/sagemath:latest
┌────────────────────────────────────────────────────────────────────┐
│ SageMath version 10.6, Release Date: 2025-03-31                    │
│ Using Python 3.12.5. Type "help()" for help.                       │
└────────────────────────────────────────────────────────────────────┘
sage: ZZ(1234)
1234
sage: ZZ.random_element(10**10)
4134169080
sage: quit
```
</details>

<details>
<summary>
Definition of the `g1` and `g2` generators of BLS12-381 are as follows </summary>

```sagemath
$ docker run -it sagemath/sagemath:latest
┌────────────────────────────────────────────────────────────────────┐
│ SageMath version 10.6, Release Date: 2025-03-31                    │
│ Using Python 3.12.5. Type "help()" for help.                       │
└────────────────────────────────────────────────────────────────────┘
sage: # parameters for BLS12-381 with comparison to
sage: # standard/draft-irtf-cfrg-pairing-friendly-curves-12.txt
sage:
sage: z = -0xd201000000010000
sage:
sage: # `q` stands for `r` (line 981)
sage: q = (z^4 - z^2 + 1)
sage: q.str(16)
'73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001'
sage:
sage: # `p` stands for `p` (line 977)
sage: p = ZZ( z + q*(z - 1)^2/3 )
sage: p.str(16)
'1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab'
sage:
sage: # `4` stands for `b` (line 994)
sage: # `h1` stands for `h` (line 992)
sage: h1 = ZZ( (z - 1)^2 / 3 )
sage: h1
76329603384216526031706109802092473003
sage: h1.str(16)
'396c8c005555e1568c00aaab0000aaab'
sage:
sage: # `h2` stands for `h'` (line 992)
sage: h2 = ZZ( (z^8 - 4*z^7 + 5*z^6 - 4*z^4 + 6*z^3 - 4*z^2-4*z + 13) / 9 )
sage: h2
305502333931268344200999753193121504214466019254188142667664032982267604182971884026507427359259977847832272839041616661285803823378372096355777062779109
sage: h2.str(16)
'5d543a95414e7f1091d50792876a202cd91de4547085abaa68a205b2e5a7ddfa628f1cb4d9e82ef21537e293a6691ae1616ec6e786f0c70cf1c38e31c7238e5'
sage:
sage: F = GF(p)
sage: F12.<T> = GF(p^12)
sage: RF.<T> = PolynomialRing(F12)
sage: j = (T^2 + 1).roots(ring=F12, multiplicities=0)[0]
sage:
sage: # `4` stands for `b` (line 994)
sage: E0 = EllipticCurve(F  , [0, 4])
sage: E1 = EllipticCurve(F12, [0, 4])
sage: # `b'` is used here (line 1025)
sage: E2 = EllipticCurve(F12, [0, 4 + 4*j])
sage:
sage: # Generators of G1 and G2 (from https://aandds.com/blog/bls.html)
sage: # and also page 18 in standard/draft-irtf-cfrg-pairing-friendly-curves-12.txt
sage: # `x1` stands for `x` (line 984)
sage: x1 = 0x17f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb
sage: # `y1` stands for `y` (line 988)
sage: y1 = 0x08b3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1
sage: g1 = E1( (x1, y1) )
sage: g1
(3685416753713387016781088315183077757961620795782546409894578378688607592378376318836054947676345821548104185464507 : 1339506544944476473020471379941921221584933875938349620426543736416511423956333506472724655353366534992391756441569 : 1)
sage:
sage: # `x2` encapsulates both `x'_0` (line 996) and `x'_1` (line 1000)
sage: x2 = ( 0x024AA2B2F08F0A91260805272DC51051C6E47AD4FA403B02B4510B647AE3D1770BAC0326A805BBEFD48056C8C121BDB8
....:        + 0x13E02B6052719F607DACD3A088274F65596BD0D09920B61AB5DA61BBDC7F5049334CF11213945D57E5AC7D055D042B7E * j )
sage: # `y2` encapsulates both `y'_0` (line 1013) and `y'_1` (line 1017)
sage: y2 = ( 0x0CE5D527727D6E118CC9CDC6DA2E351AADFD9BAA8CBDD3A76D429A695160D12C923AC9CC3BACA289E193548608B82801
....:        + 0x0606C4A02EA734CC32ACD2B02BC28B99CB3E287E85A763AF267492AB572E99AB3F370D275CEC1DA1AAA9075FF05F79BE * j )
sage: g2 = E2( (x2, y2) )
sage: g2
(1524974934786634869148131047310421674182836367449173499629923666942270478173692664531820817762762612344409858914964*T^11 + 466951167399357819139631101904986341224981495609714517635702448944519312260109086445781162685798203428334155880880*T^10 + 1944629476307696029264710266106104663569401282758349834035384266803502880053233596923517745604293008606776526438813*T^9 + 1064375233906181771446477941731343550152603669242299152704511736901490138163467666912330935749112285497156761812752*T^8 + 524439736117802807566493065558956839033117050732954679474969089293280892348176067052922254028348973140488064346680*T^7 + 139299954118351620793346869471477340669710886265406598127176113079273670344633842262233554267773747834887844661959*T^6 + 739103731826146034717518476459285826868296267538760008155772915279505351525517068683802447801310475600017832001536*T^5 + 896579657303157448006189552190113634690581086624769337632713495534809460193116759284265739854449610289932037083511*T^4 + 843441423355824479944600244225871554713741591724364436154026866899150457470952385866750976645325703303081742979949*T^3 + 1795103225418651429974471490460265646267542049407206684864372758871936629575790147152120418625946616733733618740492*T^2 + 2270793357157838349634671710596689517815160546326318444928655212579690005846921471457165730885514293745964204026559*T + 813014002142981337674656983069970178581719823359786819712640294232766489286415435462948748861707183513679546469441 : 2233067595893406183140797165166489187100525817059352259655242619220390811216367457646110522297226695114452618126428*T^11 + 3602614435636483318959443118205040525998181781525417444771234468139389445877844421472824706983321089450546400870408*T^10 + 3224615712555652661084560310165376476019389757955167724510331501326401626808233747552484652698863330443680962820917*T^9 + 3040382335659451540384754154091661048671599534370655708704703502867830592626379244694086346412062450671231887885165*T^8 + 1459659623750766938694911649253051666276457273093410738960223584589040835447263007618656734237877869272906176926781*T^7 + 525539455293034032098934334132168443354191087251408822811190076148987847200277414420473133234996624365757081282351*T^6 + 1935177694213014925357296420933743720542489252007361846327337055240415803856062332714083431876300729313471329470580*T^5 + 2883239579362127280123556510406854355370944137906162523152958865339387964290988651876855569182930991824507652232201*T^4 + 3942619066893923403018401938436688648248629145749936849043252750084173495049199745561763979760261815776889173528081*T^3 + 1562914866630349508139782242415445213834899573426278635127828361112177413806119582983372787156016586380048149693338*T^2 + 3946024511249678960209495574926206734629277115261246062005271561516945960048572293854026584408693323374250148250856*T + 1779832377062937975389417919695747609689924901440156773060063840000543320473223795889149116063583645025352965406497 : 1)
sage:
sage: iso = E2.isomorphism_to(E1)
sage: k = 12
sage: t = p + 1 - E0.order()
sage:
sage: # points to multiply
sage: p1 = 3 * g1
sage: p2 = 7 * g2
sage:
sage: pairing = p1.ate_pairing(iso(p2), q, k, t, p)
sage: pairing
1387761180978465257476112114847050954511272727021099751707596163090778868843287264887355898156219205646615919788244*T^11 + 1446883575202745040098524998028928188805352441437568605052309003251474833797606339941486005555318295253400449574856*T^10 + 2289356806038184996098713895627084599608283630602663106285535398352867141005601228479347752163145019775636427532012*T^9 + 2487614079649481926416133165448060373372038984938567333577088685317194994073514077232317052321035343791904288247011*T^8 + 3891489328650613869705581914768326688234963543838784031259079251868391300774640519753311173801252953172526822462240*T^7 + 2792435783690433507322189459793051724616954530788354556430819738993112816271592147652996357392630213749489308344656*T^6 + 35111015063507576537592258024431898995755574791121590952023315776751558722050703078334586598819155440635689457708*T^5 + 3783727747182150558562944473240659236675859510095494968580243950919574561954505301371192111500101903932407599056565*T^4 + 873402532902248026825383537764981810447641615734420576800986113571738141480823045073770061259201908983957151880729*T^3 + 2430362863288168000692601594281896253332164292488455504070262876362492167147322899004470395947057992498301611345961*T^2 + 2516516254775662282437328395604952307303479769942541843868334037694383243351020382033415642349702330543329895558588*T + 77785235024769787806807078473160298793133394833594108256424752936500989374455064079184800642853717318883162085283
sage: # bilinearity property of pairings
sage: s = Integer(randrange(1, q))
sage: s
8884357174281045537091591028472861979113457994414036960833850102221027530006
sage: (s*p1).ate_pairing(iso(p2), q, k, t, p) == p1.ate_pairing(iso(s*p2), q, k, t, p)
True
```
</details>

<details>
<summary>How to load sage definitions in docker containers</summary>

```bash
docker run -v /local/path/to/bls/sage:/data -it sagemath/sagemath:latest
```

```sagemath
sage: load('/data/bls13-381.sage')
sage: # the above-mentioned definitions are now available
sage:
sage: # point from G1
sage: p1=3*g1
sage: # point from G2
sage: p2=7*g2
atePairing(p1, p2)
1387761180978465257476112114847050954511272727021099751707596163090778868843287264887355898156219205646615919788244*T^11 + 1446883575202745040098524998028928188805352441437568605052309003251474833797606339941486005555318295253400449574856*T^10 + 2289356806038184996098713895627084599608283630602663106285535398352867141005601228479347752163145019775636427532012*T^9 + 2487614079649481926416133165448060373372038984938567333577088685317194994073514077232317052321035343791904288247011*T^8 + 3891489328650613869705581914768326688234963543838784031259079251868391300774640519753311173801252953172526822462240*T^7 + 2792435783690433507322189459793051724616954530788354556430819738993112816271592147652996357392630213749489308344656*T^6 + 35111015063507576537592258024431898995755574791121590952023315776751558722050703078334586598819155440635689457708*T^5 + 3783727747182150558562944473240659236675859510095494968580243950919574561954505301371192111500101903932407599056565*T^4 + 873402532902248026825383537764981810447641615734420576800986113571738141480823045073770061259201908983957151880729*T^3 + 2430362863288168000692601594281896253332164292488455504070262876362492167147322899004470395947057992498301611345961*T^2 + 2516516254775662282437328395604952307303479769942541843868334037694383243351020382033415642349702330543329895558588*T + 77785235024769787806807078473160298793133394833594108256424752936500989374455064079184800642853717318883162085283
```
</details>

<details>
<summary>Secret, public key and verification pairing scheme</summary>

```sagemath
sage: load('/data/bls13-381.sage')
sage: # prover generates sk and calculates corresponding pk
sage: sk = Integer(randrange(1, E1.order()))
sage: sk
13663622035249999109513796709535022818204304616220558708912565044945058489634024331354766144405089808542334453214885898724206213260782201221743317452788136660011389678255250803597611351201606475516418510793232081394246668498850358555442965033671279401563657165901122065076397973549723722098985040162697722588752124834932870081367603741659373960803179726462161817667903793529082794031789389906154714427457741530664789096774806023819770728387966723250545009329591839146846600158804763629087089060932134420089585839502047561040382283315604397522495184161447901443335373058105716222354826614815814091591511653740069156175744327292848797787647834591079166886915137967893529279925420169919181050765307104049612981505310255671736005248119196536715561680810373282898612915054400559983629951690909595352101526366645079313323514017863445460158607477758109938267213348668987920090758658161367873458672041449087137754112980773507470221038681333134543991421916959464320580714983930859760174691464945012261997691432132090473171953375225129434098275424145265972978460354569596329740233599858393607594229350340499573265176358325082511555203657456141315499920592888448797927739169637082989702957705803552546850731778058778755641143442619542132802530809686724736145634481631178394687622802301187685860010174267845014070405120393290072036772459218644652808484325019895941966887638217095861482509
sage: pk=sk*g2
sage: # due to asymmentry it is extremely difficult to go from pk to sk. Prover hid its sk in point of G2
sage: # now for the sake of simplicity let's assume prover has hash of msg Hmsg=111
sage: # we will have H point from group G1
sage: Hmsg=111
sage: Hpoint=Hmsg*g1
sage: #signature is
sage: sig = sk * Hpoint
sage: # verification requires the calculation of two pairings and comparing them
sage: left = atePairing(Hpoint,pk)
sage: right = atePairing(sig,g2)
sage: left == right
True

# Verifier receives 3 points, Hpoint, pk, and sig and calculates two pairings to verify
# Prover has secret sk, calculates pk point from sk. Having msg also calculates hash and maps it to point.
# signature is multiplication operation between sk and the hash point.
# Caution/disclaimer: hash-to-point is naively calculated here for education purposes.
```
</details>

<details>
<summary>Aggregate signature case</summary>

```sagemath
sage: load('/data/bls13-381.sage')
sage: # Two parties represented by secrets, sk1 and sk2
sage: sk1 = Integer(randrange(1, E1.order()))
sage: sk2 = Integer(randrange(1, E1.order()))
sage: # Two parties represented by the respective public keys, pk1 and pk2
sage: pk1=sk1*g2
sage: pk2=sk2*g2
sage
sage: sk1 == sk2
False
sage: # Let's assume that hashes of two msgs are
sage: Hmsg1=111
sage: Hmsg2=222
sage: # which could be mapped into points of G1
sage: Hpoint1=Hmsg1*g1
sage: Hpoint2=Hmsg2*g1
sage:
sage: # signatures
sage: sig1 = sk1 * Hpoint1
sage: sig2 = sk2 * Hpoint2
sage: sigAggr = sig1 + sig2
sage:
sage: # verification
sage: left1 = atePairing(Hpoint1,pk1)
sage: left2 = atePairing(Hpoint2,pk2)
sage: right = atePairing(sigAggr,g2)
sage: left1*left2 == right
True
```

</details>

<details>
<summary>Aggregate public key and signature case</summary>

```sagemath
sage: load('/data/bls13-381.sage')
sage: # Two parties represented by secrets, sk1 and sk2
sage: sk1 = Integer(randrange(1, E1.order()))
sage: sk2 = Integer(randrange(1, E1.order()))
sage: # Two parties represented by the respective public keys, pk1 and pk2
sage: pk1=sk1*g2
sage: pk2=sk2*g2
sage: pkAggr = pk1 + pk2
sage
sage: sk1 == sk2
False
sage: # Let's assume that hash of ONE msg is
sage: Hmsg=111
sage: # which could be mapped into point of G1
sage: Hpoint=Hmsg*g1
sage:
sage: sig1 = sk1 * Hpoint
sage: sig2 = sk2 * Hpoint
sage: sigAggr = sig1 + sig2
sage:
sage: # verification of aggregates
sage: left = atePairing(Hpoint,pkAggr)
sage: right = atePairing(sigAggr,g2)
sage: left == right
True
```

</details>

</details>

<details>
<summary><b>Solving easy linear and non-linear equations using BLS12-381 curve primitives (click to expand)</b></summary>

## Solving easy linear and non-linear equations using BLS12-381 curve primitives

<details>

Let's start with an easy linear equation `x+y=23`. The setup of interaction is the following: the formula of equation is known for both parties: prover and verifier.
Prover wants to prove it has the solution for the equation and without disclosing them wants the verifier to check his claim.
In order to do it the prover can use either G1 or G2 curve. Let's start with the G1. The prover comes up with the solution x=10 and y=13. Then in order to hide the solution he finds the corresponding elliptic curves in G1:

```bash
# verifier side
λ cargo run --quiet mul --g1 --point generator --scalar 10
0xaf81da25ecf1c84b577fefbedd61077a81dc43b00304015b2b596ab67f00e41c86bb00ebd0f90d4b125eb0539891aeed

λ cargo run --quiet mul --g1 --point generator --scalar 13
0x851f8a0b82a6d86202a61cbc3b0f3db7d19650b914587bde4715ccd372e1e40cab95517779d840416e1679c84a6db24e
```

Now the verifier sends those two points in G1 and claims they are the solution of the equation both sides are aware of.
The prover checks that claim:

```bash
λ cargo run --quiet mul --g1 --point generator --scalar 23
0x8c8b694b04d98a749a0763c72fc020ef61b2bb3f63ebb182cb2e568f6a8b9ca3ae013ae78317599e7e7ba2a528ec754a

λ echo -n 0xaf81da25ecf1c84b577fefbedd61077a81dc43b00304015b2b596ab67f00e41c86bb00ebd0f90d4b125eb0539891aeed | \
> cargo run --quiet add --g1 --point_right 0x851f8a0b82a6d86202a61cbc3b0f3db7d19650b914587bde4715ccd372e1e40cab95517779d840416e1679c84a6db24e
0x8c8b694b04d98a749a0763c72fc020ef61b2bb3f63ebb182cb2e568f6a8b9ca3ae013ae78317599e7e7ba2a528ec754a
```

Indeed! The claim of the prover is validated! The verifier used homomorphic encryption property, meaning `x+y=23` in both number and point space!
The same is true when both parties agree to work within G2 groups.

The non-linear case is where pairings come in. A prover can prove knowledge of `x` and `y` such that `x y = 26`, equations also known by a verifier,
without revealing them — by sending **only points** and relying on bilinearity of pairings.

```bash
# Prover comes up with x=13, y=2 and sends X=13*G1 (uncompressed), Y=2*G2 (uncompressed)
# Verifier checks e(X, Y) == e(G1, 26*G2), a consequence of x*y = 26

# Prover computes points (uncompressed)
λ cargo run --quiet mul --g1 --point generator --scalar 13
0x851f8a0b82a6d86202a61cbc3b0f3db7d19650b914587bde4715ccd372e1e40cab95517779d840416e1679c84a6db24e
λ X_G1=$(echo -n 0x851f8a0b82a6d86202a61cbc3b0f3db7d19650b914587bde4715ccd372e1e40cab95517779d840416e1679c84a6db24e | cargo run --quiet uncompress --g1)
λ $X_G1
0x051f8a0b82a6d86202a61cbc3b0f3db7d19650b914587bde4715ccd372e1e40cab95517779d840416e1679c84a6db24e0b6a63ac48b7d7666ccfcf1e7de0097c5e6e1aacd03507d23fb975d8daec42857b3a471bf3fc471425b63864e045f4df

λ cargo run --quiet mul --g2 --point generator --scalar 2
0xaa4edef9c1ed7f729f520e47730a124fd70662a904ba1074728114d1031e1572c6c886f6b57ec72a6178288c47c335771638533957d540a9d2370f17cc7ed5863bc0b995b8825e0ee1ea1e1e4d00dbae81f14b0bf3611b78c952aacab827a053
λ Y_G2=$(echo 0xaa4edef9c1ed7f729f520e47730a124fd70662a904ba1074728114d1031e1572c6c886f6b57ec72a6178288c47c335771638533957d540a9d2370f17cc7ed5863bc0b995b8825e0ee1ea1e1e4d00dbae81f14b0bf3611b78c952aacab827a053 | cargo run --quiet uncompress --g2)
λ $Y_G2
0x0a4edef9c1ed7f729f520e47730a124fd70662a904ba1074728114d1031e1572c6c886f6b57ec72a6178288c47c335771638533957d540a9d2370f17cc7ed5863bc0b995b8825e0ee1ea1e1e4d00dbae81f14b0bf3611b78c952aacab827a0530f6d4552fa65dd2638b361543f887136a43253d9c66c411697003f7a13c308f5422e1aa0a59c8967acdefd8b6e36ccf30468fb440d82b0630aeb8dca2b5256789a66da69bf91009cbfe6bd221e47aa8ae88dece9764bf3bd999d95d71e4c9899

# Verifier computes 26*G2 (uncompressed)
λ TWENTY_SIX_G2=$(echo $(cargo run --quiet mul --g2 --point generator --scalar 26) | cargo run --quiet uncompress --g2)
λ echo $TWENTY_SIX_G2
0x0bb319a4550c981ee89e3c7e6dcc434283454847792807940f72fd2dbf3625b092e0a0c03e581fd9bd9cf74f95ccef150029ea93c2f1eb48b195815571ea0148198ff1b19462618cab08d037646b592ecab5a66b4bc660ffd02d1b996ca377da05d04aa0b644faae17d4c76a14aa680c69fdfc6b59fee3ef45641f566165fced60cbbda4ca096e132bb6f58ab45166860abb072b8d9011e81c9f5b23ba86fdb6399c878aa4eadee45fb2486afe594dffc53be643598a23e5428894a36f5ac3ce

# Verifier checks e(X_G1, Y_G2) == e(G1, TWENTY_SIX_G2)
# First e(X_G1, Y_G2)
λ echo $X_G1 | cargo run --quiet pairing --g2 $Y_G2
0x0390df3dd3d5a63d5c7c2f911b665b134df8eb3ada0181d15aec93e1dd2e783cf47d0f47eeb642c68a566e9d00b30817a879e82adb993a1efb41c4a807c1c707762b102ee490de8ab6a32211c029f019ea8e743edf34e61b0c8ecd6df6566300ed58a2c2f204178bee12aeba33f89ff40d3408d9f485caa6b403b5759a42f1884c45b71433f491d98d2196e02f667716aefb3dfab74dd28a32d8003a8c471a12805b5fbe39481259e4f181c3af1a924319551bbe9758a9a3dbfa01fa5886fb129cf1fd13a2c970e6abe724cac7177e77b0ae2f5c4644192e446b0065da5e9a3f5dd9807783537d49497667225492b00dbf18211d38a9078f6872d9598852b3b28758d34c21782620e823cea6a50be9926206e42060665d6d03b3920cf2216705738d99f55d6611edc37d2722af1c5668b393ee09a8b84a74fc88c513744ece6ad7e4f67bc26b8d5f02e9266f5a0915182626cdc8649c3ddb029a30f67db391f143b17cb4eddae49f45b98e5a2659350dca820001b488d0c34f186cdf9d832a0bfc6090c4545df018615935bd3427b9dcdcd6abb214ce0f2a0ef4a4f029007bd5af8f2409f0683c64dc1c1f49b16bc50dea411b28e2cb0615ebc532efbbe28e8e699c3850fd31d25f0ca8ad43c90b22976556cd4303f638244bbc20ab48a3960460205ce3c61d7266c12bcdaf1505e0f162d0a0777efe391c0c0c8ceb3cb4a3fcdc9a2278ec3015ca84f7a759ade85819a8b7d201b7a4c88692814ec034b369e34550ed450498c7434152b633cd22e06ddba10f0add047fa3a3f99112f7c22417

λ G1=$(cargo run --quiet uncompress --g1 --point generator)
λ echo $G1
0x17f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb08b3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1
λ echo $G1 | cargo run --quiet pairing --g2 $TWENTY_SIX_G2
0x0390df3dd3d5a63d5c7c2f911b665b134df8eb3ada0181d15aec93e1dd2e783cf47d0f47eeb642c68a566e9d00b30817a879e82adb993a1efb41c4a807c1c707762b102ee490de8ab6a32211c029f019ea8e743edf34e61b0c8ecd6df6566300ed58a2c2f204178bee12aeba33f89ff40d3408d9f485caa6b403b5759a42f1884c45b71433f491d98d2196e02f667716aefb3dfab74dd28a32d8003a8c471a12805b5fbe39481259e4f181c3af1a924319551bbe9758a9a3dbfa01fa5886fb129cf1fd13a2c970e6abe724cac7177e77b0ae2f5c4644192e446b0065da5e9a3f5dd9807783537d49497667225492b00dbf18211d38a9078f6872d9598852b3b28758d34c21782620e823cea6a50be9926206e42060665d6d03b3920cf2216705738d99f55d6611edc37d2722af1c5668b393ee09a8b84a74fc88c513744ece6ad7e4f67bc26b8d5f02e9266f5a0915182626cdc8649c3ddb029a30f67db391f143b17cb4eddae49f45b98e5a2659350dca820001b488d0c34f186cdf9d832a0bfc6090c4545df018615935bd3427b9dcdcd6abb214ce0f2a0ef4a4f029007bd5af8f2409f0683c64dc1c1f49b16bc50dea411b28e2cb0615ebc532efbbe28e8e699c3850fd31d25f0ca8ad43c90b22976556cd4303f638244bbc20ab48a3960460205ce3c61d7266c12bcdaf1505e0f162d0a0777efe391c0c0c8ceb3cb4a3fcdc9a2278ec3015ca84f7a759ade85819a8b7d201b7a4c88692814ec034b369e34550ed450498c7434152b633cd22e06ddba10f0add047fa3a3f99112f7c22417
```

Both pairing outputs are identical, confirming that `xy = 26` holds — without the verifier ever learning `x = 13` or `y = 2`. This technique, known as a **quadratic arithmetic program**, is the foundation of zk-SNARKs built on BLS12-381.

</details>

</details>

<details>
<summary><b>Groth16 with BLS12-381 curve primitives (click to expand)</b></summary>

## Groth16 with BLS12-381 curve primitives

The system was introduced in [seminal paper](https://eprint.iacr.org/2016/260.pdf).
Groth16 prover with circom adapter written in Rust is [here](./groth16-prover/), with its command-line interface in [`clis/groth16`](./clis/groth16/).
Groth16 verifier written in Aiken is [here](./aiken/groth16/).

The full walkthrough — Circom circuit → trusted setup → witness → proof → on-chain
Aiken verification, with explicit inputs and outputs at every step — lives in
[`clis/groth16/README.md`](./clis/groth16/README.md#end-to-end-walkthrough--circom-circuit-to-on-chain-verification).

</details>
