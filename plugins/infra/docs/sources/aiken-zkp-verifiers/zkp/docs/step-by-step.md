## Step by Step overview of protocols included here:
All we really care about in this library is Verification - we assume setup & proof generation will be done offchain. However, we include the other sections here for context.

- [Groth16](#groth16)
  - [Setup](#1-setup-trusted-parameter-generation)
  - [Proof Generation](#2-proof-generation-provers-side)
  - [Verification](#3-verification-verifiers-side)
- [PLONK](#plonk)
  - [Setup](#1-setup-trusted-parameter-generation-1)
  - [Proof Generation](#2-proof-generation-provers-side-1)
  - [Verification](#3-verification-verifiers-side-1)
- [Bulletproofs](#bulletproofs)
  - [Setup](#1-setup-public-parameters-generation)
  - [Proof Generation](#2-proof-generation-provers-side-2)
  - [Verification](#3-verification-verifiers-side-2)

# **Groth16**

## **1. Setup (Trusted Parameter Generation)**
The setup phase generates public parameters needed for proof generation and verification.

### **Step 1: Define the arithmetic circuit**
- Construct a Rank-1 Constraint System (R1CS) for the function \( f(x) \) to be proven.
- The circuit enforces constraints of the form:
  \[
  A(w) ⋅ B(w) = C(w)
  \]
  where \( w \) represents witness variables.

### **Step 2: Compute the Quadratic Arithmetic Program (QAP)**
- Convert the R1CS into a QAP representation.
- Define polynomials \( A(x), B(x), C(x) \) corresponding to the constraints.

### **Step 3: Perform a trusted setup**
- A trusted authority generates the Structured Reference String (SRS):
  - **Proving key (PK):** Used to generate proofs.
  - **Verification key (VK):** Used to verify proofs.
- This involves selecting a secret scalar \( τ \) and computing:
  \[
  g^τ, g^{τ^2}, \dots, g^{τ^d}
  \]
  in an elliptic curve group.

- The secret \( τ \) is discarded after setup to maintain security.

---

## **2. Proof Generation (Prover's Side)**
The prover constructs a zk-SNARK proof for a statement \( x \) using a witness \( w \).

### **Step 1: Compute witness values**
- Solve for the witness \( w \) such that:
  \[
  A(w) ⋅ B(w) = C(w)
  \]

### **Step 2: Compute the proof elements**
- The proof consists of three group elements \( (A, B, C) \) computed as follows:
  \[
  A = g^{a + r_A τ}
  \]
  \[
  B = g^{b + r_B τ}
  \]
  \[
  C = g^{c + r_C τ + r_A r_B τ}
  \]
  where \( r_A, r_B, r_C \) are random scalars ensuring zero-knowledge.

### **Step 3: Output the proof**
- The prover outputs \( π = (A, B, C) \) as the proof.

---

## **3. Verification (Verifier's Side)**
The verifier checks that the proof is valid using the verification key (VK).

### **Step 1: Compute public input evaluation**
- Use the verification key to compute a weighted sum of public inputs.

### **Step 2: Perform pairings check**
- Verify the following bilinear pairing equation:
  \[
  e(A, B) = e(g^C, g)
  \]
  where \( e \) is a cryptographic pairing function.

### **Step 3: Accept or reject**
- If the pairing equation holds, the proof is valid.
- Otherwise, reject the proof.

# **PLONK**

## **1. Setup (Trusted Parameter Generation)**
The setup phase generates public parameters needed for proof generation and verification.

### **Step 1: Define the arithmetic circuit**
- Express the computation as a Rank-1 Constraint System (R1CS) or a set of custom gates.
- Convert it into a polynomial form using Lagrange interpolation.

### **Step 2: Generate the Structured Reference String (SRS)**
- The SRS contains powers of a secret scalar \( τ \) and is used for polynomial commitments.
- Unlike Groth16, PLONK’s SRS is **universal** and can be reused across circuits.
- It consists of:
  - **Prover Key (PK):** Helps in proof construction.
  - **Verifier Key (VK):** Helps in proof verification.

### **Step 3: Commit to polynomials**
- Commit to the witness polynomials using Kate commitments (evaluations in an elliptic curve group).

---

## **2. Proof Generation (Prover's Side)**
The prover constructs a zk-SNARK proof ensuring correctness of the computation.

### **Step 1: Compute witness values**
- Evaluate the constraint polynomials at secret points.
- Define wire polynomials \( a(X), b(X), c(X) \) corresponding to inputs and outputs.

### **Step 2: Compute permutation argument**
- PLONK uses a permutation argument to check that wires are correctly assigned.
- Compute the permutation product polynomial \( Z(X) \).

### **Step 3: Compute quotient polynomial**
- Construct a quotient polynomial \( t(X) \) that encodes constraint satisfaction.

### **Step 4: Generate proof elements**
- The prover computes and commits to:
  - Wire polynomials \( a(X), b(X), c(X) \)
  - Permutation polynomial \( Z(X) \)
  - Quotient polynomial \( t(X) \)
  - Evaluation proofs via Kate commitments

- The proof consists of commitments to these polynomials and evaluation proofs.

### **Step 5: Output the proof**
- The prover sends the proof \( π \) to the verifier.

---

## **3. Verification (Verifier's Side)**
The verifier checks the validity of the proof using polynomial commitments and pairings.

### **Step 1: Compute public input evaluation**
- Use the verification key to compute a weighted sum of public inputs.

### **Step 2: Perform polynomial checks**
- Verify that the committed polynomials satisfy the circuit constraints.
- Check that the permutation argument holds using the permutation polynomial \( Z(X) \).

### **Step 3: Use Kate commitment opening proof**
- Verify that polynomial evaluations are consistent using Kate commitments.
- This involves checking a bilinear pairing equation.

### **Step 4: Accept or reject**
- If all checks pass, accept the proof.
- Otherwise, reject the proof as invalid.

# **Bulletproofs**

This implementation follows the Bünz et al. (2018) Bulletproofs construction for range proofs over a Pedersen commitment, targeting the BLS12-381 curve on Cardano (Plutus V3 / Aiken). It uses the **O(n) disclosed-vectors variant**: the prover sends \( \mathbf{l}, \mathbf{r} \) in the clear rather than folding them via the recursive inner-product argument (IPA), which would reduce proof size to \( O(\log n) \) at the cost of additional implementation complexity. IPA compression is a planned future phase once a deployment target's transaction-size constraints require it.

## **1. Setup (Public Parameters Generation)**
Bulletproofs require no trusted ceremony. All generators are derived deterministically from a public string.

### **Step 1: Derive independent generators**
- Set \( g \) to the BLS12-381 G1 standard generator.
- Derive \( h \) and \( u \) via `hash_to_group` with distinct domain-separation tags under a fixed `protocol_id` string.
- Derive generator vectors \( \mathbf{g}_{vec}[i] \) and \( \mathbf{h}_{vec}[i] \) for \( i \in [0, n) \) via `hash_to_group` with per-index payloads and separate DSTs. No party ever holds a discrete-log relationship between any two generators.

### **Step 2: Precompute generator sums**
- Store \( g_{sum} = \sum_i \mathbf{g}_{vec}[i] \) and \( h_{sum} = \sum_i \mathbf{h}_{vec}[i] \) in the verification key.
- These avoid re-folding \( 2n \) points on every verification call.

### **Step 3: Establish the Pedersen commitment scheme**
- The commitment to a secret value \( v \) with blinding factor \( \gamma \) is:
  \[
  V = g^v \cdot h^\gamma
  \]
- \( V \) is the only public input the verifier receives about \( v \); the proof never reveals \( v \) or \( \gamma \).

The verification key is computed once off-chain and embedded as a deployed constant; it must not be recomputed per transaction.

---

## **2. Proof Generation (Prover's Side)**
The prover generates a zero-knowledge proof that the committed value \( v \) lies in \( [0, 2^n) \).

### **Step 1: Bit-decompose the value**
- Encode \( v \) as an \( n \)-bit vector: \( \mathbf{a}_L[i] = \text{bit } i \text{ of } v \).
- Set \( \mathbf{a}_R = \mathbf{a}_L - \mathbf{1} \) (component-wise).

### **Step 2: Commit to the bit vectors**
- Sample blinding scalars \( \alpha, \rho \) and blinding vectors \( \mathbf{s}_L, \mathbf{s}_R \) (length \( n \)).
- Compute:
  \[
  A = h^\alpha \cdot \mathbf{g}_{vec}^{\mathbf{a}_L} \cdot \mathbf{h}_{vec}^{\mathbf{a}_R}
  \qquad
  S = h^\rho \cdot \mathbf{g}_{vec}^{\mathbf{s}_L} \cdot \mathbf{h}_{vec}^{\mathbf{s}_R}
  \]

### **Step 3: Derive challenges y, z (Fiat–Shamir)**
- Hash the transcript over \( (V, A, S) \) (with \( g, h, u, n \) bound at transcript initialisation) via `blake2b_256`.
- Derive scalar challenges:
  \[
  y = \text{hash\_to\_scalar}(\text{state} \| \texttt{"y"})
  \qquad
  z = \text{hash\_to\_scalar}(\text{state} \| \texttt{"z"})
  \]

### **Step 4: Build the linear vector polynomials**
- Define length-\( n \) vectors (index \( i \in [0, n) \)):
  \[
  \mathbf{l}_0[i] = a_L[i] - z
  \qquad
  \mathbf{l}_1[i] = s_L[i]
  \]
  \[
  \mathbf{r}_0[i] = y^i \cdot (a_R[i] + z) + z^2 \cdot 2^i
  \qquad
  \mathbf{r}_1[i] = y^i \cdot s_R[i]
  \]
- The inner product \( t(X) = \langle \mathbf{l}_0 + X\mathbf{l}_1,\; \mathbf{r}_0 + X\mathbf{r}_1 \rangle = t_0 + t_1 X + t_2 X^2 \).
- Compute coefficients: \( t_1 = \langle \mathbf{l}_0, \mathbf{r}_1 \rangle + \langle \mathbf{l}_1, \mathbf{r}_0 \rangle \), \( t_2 = \langle \mathbf{l}_1, \mathbf{r}_1 \rangle \).

### **Step 5: Commit to the polynomial coefficients**
- Sample blinding scalars \( \tau_1, \tau_2 \). Compute:
  \[
  T_1 = g^{t_1} \cdot h^{\tau_1}
  \qquad
  T_2 = g^{t_2} \cdot h^{\tau_2}
  \]

### **Step 6: Derive challenge x (Fiat–Shamir)**
- Extend the transcript by absorbing \( (T_1, T_2) \); derive:
  \[
  x = \text{hash\_to\_scalar}(\text{state} \| \texttt{"x"})
  \]

### **Step 7: Evaluate and output the proof**
- Evaluate the polynomial at \( x \):
  \[
  \mathbf{l} = \mathbf{l}_0 + x \cdot \mathbf{l}_1
  \qquad
  \mathbf{r} = \mathbf{r}_0 + x \cdot \mathbf{r}_1
  \]
- Compute the blinding aggregates:
  \[
  \tau_x = z^2 \cdot \gamma + \tau_1 \cdot x + \tau_2 \cdot x^2
  \qquad
  \mu = \alpha + \rho \cdot x
  \]
- The proof is \( (A, S, T_1, T_2, \tau_x, \mu, \mathbf{l}, \mathbf{r}) \). Proof size is \( O(n) \) scalars (4 group elements + \( 2n + 2 \) scalars).

---

## **3. Verification (Verifier's Side)**
The verifier holds only the public inputs: the verification key and the Pedersen commitment \( V \). It never sees \( v \) or \( \gamma \).

### **Step 1: Recompute challenge scalars**
- Reconstruct the identical Fiat–Shamir transcript from \( (V, A, S, T_1, T_2) \) using the same staged hash construction. Derive \( y, z, x \) as the prover did.
- Reject immediately if \( |\mathbf{l}| \neq n \) or \( |\mathbf{r}| \neq n \), or if \( y = 0 \) (singular case).

### **Step 2: Recompute derived values**
- Compute \( \hat{t} = \langle \mathbf{l}, \mathbf{r} \rangle \) directly from the disclosed vectors (no trust required).
- Compute the correction term:
  \[
  \delta(y, z) = (z - z^2) \cdot \sum_{i=0}^{n-1} y^i \;-\; z^3 \cdot \sum_{i=0}^{n-1} 2^i
  \]

### **Step 3: t-commitment check**
Verify that \( \hat{t} \) is consistent with the committed polynomial and the Pedersen commitment \( V \):
\[
g^{\hat{t}} \cdot h^{\tau_x} \;=\; V^{z^2} \cdot g^{\delta(y,z)} \cdot T_1^x \cdot T_2^{x^2}
\]

### **Step 4: Vector-opening check**
Verify that \( \mathbf{l}, \mathbf{r} \) are consistent with the commitments \( A, S \). Rescale the \( h \)-generators as \( h'_i = \mathbf{h}_{vec}[i]^{y^{-i}} \) and set \( \mathbf{r}'[i] = \mathbf{r}[i] - z^2 \cdot 2^i \):
\[
A \cdot S^x \;=\; h^\mu \cdot \mathbf{g}_{vec}^{\mathbf{l}} \cdot (h')^{\mathbf{r}'} \cdot (g_{sum} - h_{sum})^z
\]

### **Step 5: Accept or reject**
- If both checks hold, accept the proof.
- If either fails, reject.

Both checks together bind the proof to a genuine bit-decomposition of a value consistent with \( V \). A prover who did not honestly decompose a value in \( [0, 2^n) \) cannot satisfy both checks simultaneously for challenges they could not have predicted at commitment time (Schwartz–Zippel, Pedersen binding).
