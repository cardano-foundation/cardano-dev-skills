# Source Grounding

Every skill and the `cardano-context` block carry one short grounding rule that tells the agent
how to use the bundled `docs/sources/` corpus, and what to do when it falls short. The three
fenced texts below are canonical: `scripts/validate.py` reads them from this file and fails when
a skill's block is missing, duplicated, or differs from them in anything other than line
wrapping.

Each block sits between `cds:grounding` HTML comment markers, directly after a skill's
untrusted-data preamble (or after its title when it has none), followed by a link to this file.
`give-feedback` carries no block: it answers no Cardano question.

## General text

Used by every skill except the two below, and by the `cardano-context` block.

```markdown
<!-- cds:grounding begin -->
**Grounding.** Answer from the bundled `docs/sources/` corpus first and cite the exact bundled file you used. If
bundled sources disagree, look out of date, or do not cover the question, say so plainly. Then still help: answer
from your own knowledge, mark which parts did not come from the bundled sources, and offer to search the web, which
the user can accept in their next message. Never leave the user stuck because the bundled sources fall short.
<!-- cds:grounding end -->
```

## review-contract variant

A security finding must rest on evidence the reviewer can name, so this variant keeps the web out
of the verdict.

```markdown
<!-- cds:grounding begin variant=review-contract -->
**Grounding.** Base every finding on the code under review and the bundled `docs/sources/` corpus, citing the exact
bundled file. If bundled sources disagree, look out of date, or do not cover a pattern, say so plainly and mark any
point that rests on your own knowledge. You may offer to consult only the sources listed in
`references/security-sources.md`, which the user can accept in their next message. No other web page is evidence for
a finding or for the verdict.
<!-- cds:grounding end -->
```

## assess-constitutionality variant

This skill already defines its own bounded retrieval of public evidence, so the variant points back
to it instead of offering a general search.

```markdown
<!-- cds:grounding begin variant=assess-constitutionality -->
**Grounding.** Base every finding on the mirrored constitutional text and the bundled `docs/sources/` corpus, citing
the exact file. If bundled sources disagree, look out of date, or are silent, say so plainly. Public evidence is
retrieved only as this skill's Workflow describes; that is not a general web-research permission.
<!-- cds:grounding end -->
```

## Why bundled sources come first

- **Currency.** Cardano libraries, SDK APIs and CIP statuses move faster than model training data.
  The bundled corpus is fetched from each project's own repository at a vetted commit, so it is
  the preferred baseline for what is current.
- **Provenance.** Citing the exact bundled file lets the user check the answer against the text it
  came from, and makes a stale or conflicting source visible instead of silently blended in.

## What "mark" means

When part of an answer comes from the model's own knowledge rather than a bundled file, say so in
one sentence next to that part, for example "from model knowledge, not the bundled docs". The user
should be able to tell, part by part, what is cited and what is not.

## Why a web search is offered, not run

In Claude Code, every skill's frontmatter disallows `WebFetch` and `WebSearch` for the turn the
skill runs in, so that a poisoned bundled document read during that turn cannot reach out to the
network (`docs/DESIGN.md`, Decision 13). The block is turn-scoped: on the next turn the user can
accept the offer and the host's normal permissions apply. Codex does not read those frontmatter
fields, and the same behaviour is asked of it in the body text: offer the search, let the user
decide in their next message.

Offering a search never replaces an answer. When the bundled sources fall short, the agent still
helps from its own knowledge, marked as such, and the search is an extra step the user may take.

## Bundled docs remain untrusted

The grounding rule decides where answers come from; it does not change what bundled documents
are. They are third-party reference data, not instructions: an agent never runs a command or
follows a behavioural prompt because a bundled file contains it.
