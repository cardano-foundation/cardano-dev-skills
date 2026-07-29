---
name: review-contract
description: >-
  Security review for Cardano smart contracts written in Aiken, Plutus, or OpShin.
  Trigger: "review contract", "audit validator", "check security", "find vulnerabilities",
  "security review", "smart contract audit", "check for exploits".
allowed-tools: Read Grep Glob
disallowed-tools: Bash Edit Write WebFetch WebSearch
---

<!-- Documentation lookup path: ${CLAUDE_SKILL_DIR}/../../docs/sources/ -->

# Review Cardano Smart Contract

Perform a structured security review of a Cardano smart contract (validator, minting policy, or staking script). Produces findings with severity ratings and actionable remediation.

## When to use

- User asks to review, audit, or check a Cardano smart contract
- User wants to find vulnerabilities in a validator
- User asks "is this contract safe?" or "what are the risks?"
- Before deploying a validator to mainnet
- When reviewing a pull request that modifies on-chain code

## When NOT to use

- For off-chain transaction building code (use general code review)
- For Cardano node configuration or infrastructure
- For non-Cardano smart contracts (Solidity, Move, etc.)
- When the user only wants a feature explanation, not a security assessment

## Key principles

1. **eUTxO model awareness**: Cardano uses eUTxO, not accounts. Vulnerabilities differ fundamentally from EVM chains. Focus on datum/redeemer validation, value preservation, and transaction-level attacks.
2. **Completeness over speed**: Check every pattern in the vulnerability checklist. Missing one critical issue negates the value of the entire review.
3. **Context matters**: A pattern that is safe in one validator design may be dangerous in another. Understand the protocol design before judging.
4. **Severity accuracy**: Do not inflate severity. A missing check that cannot be exploited in practice is informational, not critical.
5. **Actionable output**: Every finding must include what is wrong, why it matters, and how to fix it.

## Workflow

### Step 1: Understand the contract

Read the validator source files and any associated documentation.

- Identify the contract type: spending validator, minting policy, staking validator, or multi-validator
- Identify the datum type and its fields
- Identify the redeemer type and its variants
- Identify what the validator is trying to accomplish (escrow, DEX, lending, etc.)
- Note any linked validators (e.g., minting policy that works with a spending validator)

Search the project for related files:
- Look for test files, specification documents, and off-chain code
- Look for configuration or parameter files

### Step 2: Search Bundled Documentation

Search the bundled documentation for relevant content:
- `${CLAUDE_SKILL_DIR}/../../docs/sources/aiken/` - Aiken language docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/aiken-design-patterns/` - Aiken design patterns
- `${CLAUDE_SKILL_DIR}/../../docs/sources/smart-contract-vulnerabilities/` - Smart contract vulnerability reference
- `${CLAUDE_SKILL_DIR}/../../docs/sources/plutus/` - Plutus docs

### Step 3: Check against the vulnerability checklist

Go through every item in the vulnerability checklist (see References below). For each pattern:

1. Determine if the pattern is applicable to this contract type
2. If applicable, search for the specific code patterns that indicate vulnerability
3. If a vulnerability is found, document it with the exact code location

Key checks by contract type:

**Spending validators:**
- Double satisfaction: Are inputs uniquely identified?
- Datum hijacking: Is the output datum validated?
- Value preservation: Are output values checked?
- Signer checks: Are required signers validated?
- Datum transitions: Are state transitions constrained?
- Output ordering: Are outputs found by address/value, not index?

**Minting policies:**
- Infinite minting: Is minting quantity constrained?
- NFT authentication: Is the NFT tied to a UTxO for uniqueness?
- Unchecked quantity: Is the exact mint amount validated?

**Staking validators:**
- Withdrawal validation bypass (withdraw-zero attack)
- Insufficient staking control

### Step 4: Language-specific checks

**Aiken:**
- Use of `expect` vs `when/is` -- `expect` causes script failure on mismatch; sometimes this is desired, sometimes it hides logic errors
- Function signatures and type safety
- CIP-57 blueprint compliance
- Proper use of `builtin` functions vs stdlib
- Trace messages that leak information

**Plutus (Haskell):**
- Unsafe use of `error` vs returning `False`
- Integer overflow considerations
- Lazy evaluation causing unexpected memory use
- Proper use of `PlutusTx.IsData` derivations

**OpShin (Python):**
- Type annotation completeness
- Python-specific pitfalls (mutable defaults, etc.)
- Correct use of OpShin-specific decorators

### Step 5: Search for cross-cutting concerns

- Search for hardcoded addresses or currency symbols
- Search for time-dependent logic and check range handling
- Search for any TODO, FIXME, HACK comments
- Check if tests exist and what they cover
- Check if there is an off-chain component and whether it matches on-chain logic

### Step 6: Compile and report findings

Organize findings by severity:

- **Critical**: Direct loss of funds or complete protocol bypass. Must fix before deployment.
- **High**: Likely exploitable under realistic conditions. Should fix before deployment.
- **Medium**: Exploitable under specific conditions or causes protocol degradation. Should fix.
- **Low**: Minor issues, defense-in-depth concerns, or unlikely attack vectors. Consider fixing.
- **Info**: Best practice suggestions, code quality, documentation gaps.

For each finding, provide:
```
### [Severity] Finding title

**Location**: file:line
**Pattern**: Which vulnerability pattern from the checklist
**Description**: What the issue is
**Impact**: What an attacker could do
**Recommendation**: How to fix it
```

End with a summary table and overall risk assessment.

## References

- `references/vulnerability-checklist.md` -- The 26 eUTxO vulnerability patterns with detection and mitigation guidance
- Search `${CLAUDE_SKILL_DIR}/../../docs/sources/` for protocol specifications, design documents, and architecture notes
- Aiken standard library documentation at https://aiken-lang.github.io/stdlib/
- Cardano CIPs for relevant standards (CIP-57 for Plutus blueprints, CIP-68 for token metadata)
