---
title: Add a skill
description: How to scaffold, write, validate, and ship a new developer skill.
---

Skills live flat under `skills/<name>/SKILL.md`. No category subdirectories.

## 1. Scaffold

```bash
./scripts/new-skill.sh my-new-skill
```

This creates:

```
skills/my-new-skill/
├── SKILL.md          # template
└── references/       # deeper content (one level only)
```

## 2. Write the SKILL.md

```yaml
---
name: my-new-skill
description: >-
  What this skill does. Include 3–5 trigger phrases users would say.
allowed-tools: Read Grep Glob
---

# my-new-skill

## When to use
- Specific scenario 1
- Specific scenario 2

## When NOT to use
- Wrong scenario (redirect to correct skill)

## Key principles
- Domain-specific principle 1
- Domain-specific principle 2

## Workflow

### Step 1: Name
Instructions...

### Step 2: Name
Instructions...

## References
- See [reference-name](references/file.md) for details
```

## 3. Quality checklist

- [ ] SKILL.md under 500 lines
- [ ] Name is kebab-case, max 64 chars
- [ ] Name is task-oriented, not a project/brand name — `monetize-agent`,
      not `masumi`; `query-chain`, not `blockfrost` (CI fails brand-named
      skills)
- [ ] `name:` matches directory name
- [ ] Description includes trigger phrases
- [ ] Has "When to use", "When NOT to use", "Key principles", "Workflow"
      sections
- [ ] No MCP dependency (no `search_docs` references)
- [ ] Deep content in `references/`, one level only — no nested
      subdirectories
- [ ] No mention of specific deployed dApps; teach categories generically
- [ ] No mention of grants, treasuries, or governance proposals — the skill
      must read as a neutral community contribution

## 4. Validate and submit

```bash
python3 scripts/validate.py
./scripts/update-doc-counts.sh    # refresh counts in README/CLAUDE
python3 scripts/check-pr-policy.py  # PR policy checks (vs origin/main)
```

Open a PR. CI runs validation, the count-drift check, and the PR policy
checks (mechanical vetting + an advisory AI scope review comment).

## Quality standards

- **Behavioural guidance over reference dumps.** Tell the agent *what to do*
  and *when* — link to upstream docs for *how*.
- **Explain WHY, not just WHAT.** Trade-offs, decision criteria, common
  mistakes.
- **Prescriptiveness scales with risk.** Security skills should be strict.
  Exploratory skills can be flexible.
- **No hardcoded paths.** Use relative references and
  `${CLAUDE_PLUGIN_ROOT}` where appropriate.
