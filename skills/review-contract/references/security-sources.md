# Security Sources

Every entry in this list is vetted by the cardano-dev-skills maintainers.

This list is the evidence boundary for a contract review. Base every finding on the code under review and on the
bundled `docs/sources/` corpus, citing the exact file. The bundled entries below are its security-specific starting
points: they ship with the plugin, need no network access, and are preferred whenever they cover the point. You may
offer to consult a web entry, for example as corroborating precedent; read one only after the user accepts the offer
in their next message. A GitHub entry covers its repository page and the files on the default branch it names, at
`https://github.com/<owner>/<repo>/blob/<branch>/` or `/tree/<branch>/` and
`https://raw.githubusercontent.com/<owner>/<repo>/<branch>/`. Other branches, tags, commits, forks, issues, pull
requests, releases pages and links out of the repository are not covered. The MLabs entry covers its one page only.
No other web page is evidence for a finding or for the verdict. If a point rests on your own knowledge, say so.

## Bundled entries

Vulnerability classes and mitigations:

- `../../docs/sources/developer-portal/developers/curriculum/smart-contracts/security.md`: what the eUTxO model
  rules out (reentrancy, double spending) and what a validator must still guard against; the entry point to the pages
  below.
- `../../docs/sources/developer-portal/developers/curriculum/smart-contracts/security/vulnerabilities/overview.md`:
  index of the vulnerability classes.
- `../../docs/sources/developer-portal/developers/curriculum/smart-contracts/security/vulnerabilities/double-satisfaction.md`:
  one output satisfying several validators; output tagging and input uniqueness.
- `../../docs/sources/developer-portal/developers/curriculum/smart-contracts/security/vulnerabilities/unchecked-inputs.md`:
  arbitrary datums, other redeemers, other token names and similar unverified data.
- `../../docs/sources/developer-portal/developers/curriculum/smart-contracts/security/vulnerabilities/missing-utxo-authentication.md`:
  script UTxOs created in an invalid state; validity tokens.
- `../../docs/sources/developer-portal/developers/curriculum/smart-contracts/security/vulnerabilities/token-security.md`:
  minting policies, validation tokens, token-name and policy checks.
- `../../docs/sources/developer-portal/developers/curriculum/smart-contracts/security/vulnerabilities/time-handling.md`:
  validity intervals and the attacks that exploit them.
- `../../docs/sources/developer-portal/developers/curriculum/smart-contracts/security/vulnerabilities/staking-and-certificates.md`:
  the staking half of a script address; unguarded staking rights and certificates.
- `../../docs/sources/developer-portal/developers/curriculum/smart-contracts/security/vulnerabilities/resource-exhaustion.md`:
  unbounded value, datum and inputs; contention and cheap spam.
- `../../docs/sources/developer-portal/developers/curriculum/smart-contracts/security/vulnerabilities/evaluation-and-grinding.md`:
  attacker-controlled evaluation and grinding.
- `../../docs/sources/aiken/fundamentals/common-design-patterns.mdx`: double satisfaction and tagged outputs, one-shot
  minting policies, state thread tokens, withdraw-zero, from the Aiken documentation.
- `../../docs/sources/aiken-design-patterns/README.md`: Anastasia Labs' design-pattern library (indexers, transaction-level
  minter, stake validator, linked lists) and its notes on double satisfaction; the modules live beside it.

Exploit examples:

- `../../docs/sources/developer-portal/developers/curriculum/smart-contracts/security/ctf.md`: the Cardano Capture the
  Flag levels and the vulnerability each one teaches.
- `../../docs/sources/mesh-sdk-packages/packages/mesh-contract/README.md`: Mesh's list of purposely vulnerable
  contracts, each linked to its write-up:
  `../../docs/sources/mesh-sdk-packages/packages/mesh-contract/src/swap/double-satisfaction/README.md`,
  `../../docs/sources/mesh-sdk-packages/packages/mesh-contract/src/escrow/unbound-value/README.md`,
  `../../docs/sources/mesh-sdk-packages/packages/mesh-contract/src/giftcard/infinite-mint/README.md`,
  `../../docs/sources/mesh-sdk-packages/packages/mesh-contract/src/marketplace/insufficient-stake-control/README.md`,
  `../../docs/sources/mesh-sdk-packages/packages/mesh-contract/src/plutus-nft/locked-value/README.md`.

Audit process:

- `../../docs/sources/cips/CIP-0052/README.md`: CIP-52 audit best-practice guidelines; what an audit covers, what it
  cannot guarantee, how findings are classified and reported.
- `../../docs/sources/hydra/standalone/audit-guidelines.md`: Hydra's audit guidelines; a worked example of scoping an
  audit of on-chain and off-chain code.

## Web entries

- **Cardano Plutus Script Vulnerability Guide** — https://www.mlabs.city/blog/common-plutus-security-vulnerabilities
  - Publisher: MLabs
  - Evidence for: vulnerability-class definitions; for each class, the property that must hold, a test that refutes
    it, and the impact.
  - Last vetted: 2026-11-20
- **Cardano CTF** — https://github.com/Invariant-0/cardano-ctf
  - Publisher: Invariant0 (formerly Vacuumlabs Auditing)
  - Default branch: `main`
  - Evidence for: exploit examples; a purposely vulnerable contract and its exploit for a given class. Not a
    class definition.
  - Caveats: the last commit on the default branch was 2026-04-03. The original series targets an old Aiken
    version (`v1.0.26-alpha`), and the repository warns that its code is purposely vulnerable and must not be
    copied into a project; never recommend its code.
  - Last vetted: 2026-11-20
- **Published audit reports** — https://github.com/vacuumlabs/audits and https://github.com/Invariant-0/audit-reports
  - Publisher: Vacuumlabs Auditing, continued as Invariant0
  - Default branch: `master` (vacuumlabs/audits), `main` (Invariant-0/audit-reports)
  - Evidence for: audit precedent; how a professional auditor classified a pattern in a named protocol version.
  - Caveats: a dated historical record. Each report describes the protocol version audited on its date, not the
    protocol's current version. The one EVM report in the Vacuumlabs list is not Cardano evidence.
  - Last vetted: 2026-11-20
