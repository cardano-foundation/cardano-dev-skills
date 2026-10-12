# Account-Ownership Recovery

Prove you are the real owner of a Cardano address **in zero knowledge** — so a compromised wallet
can be refunded to the genuine owner without ever exposing the recovery phrase, and without an
attacker or a front-runner stealing the refund.

Built on [ZeroJ](https://github.com/bloxbean/zeroj) (Groth16 over BLS12-381, pure Java).

---

## The problem

A wallet or custodial account gets compromised. An attacker obtains the **leaf signing keys** — the
day-to-day keys that sign transactions — and drains the funds. This happens through phishing, a
leaked hot-wallet key, malware, a bad browser extension, and so on.

The genuine owner still holds the **master seed** (the 24-word recovery phrase) that the whole wallet
is derived from. The attacker, by assumption, does **not** — they only grabbed the leaf keys.

A service provider — say an exchange or wallet operator (call them **the operator**) — decides to
**refund the affected users**. That immediately raises hard questions:

- **Who is the real owner?** The attacker can show up and claim too. Signing with a leaf key proves
  nothing — the attacker can do that.
- **The owner can't just hand over their seed** to prove ownership. Revealing a recovery phrase to
  anyone is catastrophic; it would defeat the whole point.
- **A refund can be stolen in transit.** If the owner submits a proof on-chain, anyone watching the
  mempool could copy it and redirect the money to themselves.
- **Nobody should be able to claim twice.**

So the operator needs a way for the true owner — and *only* the true owner — to prove ownership
**without revealing the seed**, and to make sure the refund goes **only** to the address the owner
chose.

---

## The solution (with ZeroJ)

The owner produces a **zero-knowledge proof** that says, in effect:

> "I know the master seed that this address is derived from, and I want the refund sent to *this*
> address" — while revealing **nothing** about the seed.

How it works, in plain terms:

1. **Derivation, in a circuit.** Every Cardano address comes from the master seed through a standard
   derivation path (CIP-1852). ZeroJ runs that whole derivation *inside a zero-knowledge circuit* and
   checks it lands on the address's payment key hash. Because it starts from the **root seed**, only
   someone who has the seed can produce a valid proof. An attacker with just the leaf keys **cannot**.
2. **Nothing leaks.** The proof reveals only what's already public — the address and the chosen
   recipient. The seed and the derivation path stay secret (that's the "zero-knowledge" part).
3. **The refund is bound to a recipient.** The proof is tied to the payout address the owner picked,
   so a copied proof **can't be redirected** — a front-runner gets nothing.
4. **Verify anywhere.** The proof can be checked **off-chain** in a fraction of a second, or
   **on-chain** by a small Cardano (Plutus) validator that runs the verifier *and* enforces that the
   payout actually goes to the bound recipient. A per-account refund voucher (a UTxO that can be spent
   only once) prevents double-claims.

The result: the operator refunds the genuine owner, the owner never exposes their seed, the attacker
can't claim, and the money can't be hijacked on the way.

---

## Two ways to use it

| | For whom | What it does |
|---|---|---|
| **Desktop app** (`ui/`) | end users | A simple point-and-click app: set up keys, enter your recovery phrase (hidden — it never leaves your machine) and the address to receive the refund, generate a proof, and verify it off-chain or on-chain. |
| **Command-line tool** (`cli/`) | developers, operators, scripting | The same flow from the terminal — `setup` → `prove` → `verify` — plus key-bundle management and the on-chain demo. Ships as a Java zip. |

Both are pure Java and run the same underlying flow; nothing about your seed is ever stored or sent.

---

## Run the desktop UI

### Install a released build

Download the installer for your platform from
[GitHub Releases](https://github.com/bloxbean/zeroj-usecases/releases). The release assets are named:

| Platform | Asset |
|---|---|
| macOS, Apple Silicon | `account-ownership-proof-ui-macos_arm64_<version>.dmg` |
| Linux, x86-64 | `account-ownership-proof-ui-linux_x86_64_<version>.deb` |
| Linux, ARM64 | `account-ownership-proof-ui-linux_arm64_<version>.deb` |
| Windows, x86-64 | `account-ownership-proof-ui-windows_x86_64_<version>.msi` |

The installers include a Java runtime, so Java does not need to be installed separately. Install the
downloaded package, then launch **AccountOwnershipProof** as follows:

| Platform | Install and launch |
|---|---|
| macOS | Open the `.dmg`, install the app, then open `AccountOwnershipProof` from `/Applications`. |
| Windows | Open the `.msi`, then run `C:\Program Files\AccountOwnershipProof\AccountOwnershipProof.exe`. |
| Linux | Install the `.deb` as shown below, then use the application menu or the installed launcher path. |

```bash
sudo apt install ./account-ownership-proof-ui-linux_x86_64_*.deb
/opt/AccountOwnershipProof/bin/AccountOwnershipProof
```

Use the ARM64 asset instead on an ARM64 Linux machine.

### Run from source

Install Java 25, clone this repository, and run the JavaFX application through Gradle:

```bash
cd account-ownership
./gradlew :ui:run
```

The Gradle task supplies the required native-access and development trusted-setup JVM options. To
build a self-contained installer for the current operating system instead:

```bash
./gradlew :ui:jpackageInstaller
```

The installer is written to `ui/build/dist/`. Packaging requires the platform's native tooling
(`dpkg` on Linux and WiX Toolset on Windows); macOS packaging uses the JDK's built-in DMG support.

The app stores downloaded or locally generated keys under `~/.account-ownership/keys` and proofs
under `~/.account-ownership/proofs`. Generating a local development key bundle is the heavy step:
allow roughly 10 GB of free disk and use a machine with at least 16 GB RAM. Yaci DevKit is only
required for the optional on-chain verification flow.

---

## Documentation

- **[CLI — getting started](cli/README.md)** — install, the five commands, distributions, measured
  performance.
- **[CLI — full usage reference](cli/USAGE.md)** — every command and option, key-bundle setup,
  Docker, on-chain verification.
- **[Verification & on-chain validator flow](docs/verification-and-validator-flow.md)** — the
  technical reference: the circuit's public interface, how a proof is produced and verified off-chain
  and on-chain, the validator's checks, and the on-chain cost.
- **[On-chain verification: options & decision record](docs/account-ownership-onchain-verification-options.md)**
  — the design analysis (replay protection, recipient binding, nullifiers) behind the chosen approach.

---

## A note on trust

- **Your seed never leaves your machine** — it's read from a hidden prompt, used to build the proof
  in memory, and discarded. It is never written to disk or sent over the network.
- **The proof discloses only** the address's payment key hash and the recipient — both of which are
  already public on-chain.
- **Keys come from a trusted setup.** For trying it out, generate a **local, development-only** key
  bundle. For production, the setup is run as a multi-party ceremony (see the CLI docs). A production
  refund program should also confirm the recipient through its own authenticated channel.

### Circuit fingerprints in key bundles

New locally generated bundles preserve ZeroJ's exact circuit fingerprint, including the R1CS
hash, in `bundle.properties`. The key-store manifest, bundle metadata, and generated proof
metadata therefore use the same identity. Two circuits with equal dimensions are not necessarily
the same circuit.

If an older bundle has a hash-bearing `circuitFingerprint` in `manifest.properties` but only a
`c...-w...-p...` label in `bundle.properties`, its metadata was produced by the older bundle writer.
Regenerate the bundle metadata and `SHA256SUMS` from the validated key store using the corrected
writer; a newly generated bundle does this automatically. Do not remove the hash or weaken the
pipeline check. Stores without an exact binding are not automatically certified or rebound by
this metadata fix.

For the gated regression test, `-Daor.e2e=true` generates a fresh key bundle and checks two
ownership proofs. To run the same proof/negative-verification checks against an existing
exact-bound bundle without repeating setup:

```bash
./gradlew :cli:test --tests '*FlowsE2ETest' -Daor.e2e.keys=/path/to/keys
```

The test uses the public BIP-39 test mnemonic, writes proofs to a temporary directory, and does
not regenerate the proving keys. The normal prover may recreate a missing relation cache.
