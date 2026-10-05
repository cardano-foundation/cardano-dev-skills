# Known issues

Problems present on this branch as of 2026-09-29. Each one was confirmed in the code or in a devnet CI run of
the full Playwright suite. Fixed problems are removed, not kept as history.

## Proposal discussion forum (pdf)

- **Treasury withdrawals fail on a constitution without GovTool's guardrail script (7H_2).** The wallet always
  attaches GovTool's compiled guardrail script to treasury withdrawals and parameter changes. The ledger requires
  the proposal's policy hash to equal the current constitution's guardrail script, or to be absent when the
  constitution has none. So these proposals fail on any network whose constitution has no guardrail or a
  different one, including the devnet. Mainnet and preview carry this script. The failure happens before the
  transaction is submitted. **Undecided:** expose the constitution's guardrail hash (the planned
  `GET /api/v1/constitution`) and attach the script only when it matches, or give the devnet constitution
  GovTool's guardrail script.
- **The hard-fork form accepts any non-negative number.** Decimals such as 37.52 are accepted too. The ledger
  accepts only a direct successor of the current protocol version: `(major + 1, 0)` or `(major, minor + 1)`.
  Anything else is rejected on submission.
- **"Go to Data Edit Screen" closes the dialog (7P).** After a metadata URL or hash check fails, the button only
  closes the submission dialog; it does not open the edit form. **Question:** should it open the edit form, as
  7P expects, or should the test change?
- **Budget discussion links are capped at 20.** Proposal references have no cap since #4087. **Question:** does
  that decision cover budget discussions too?
- **Users without a username are logged out when their token expires (#3689).** pdf-ui refreshes the access
  token only while the user has a username.
- **Budget poll votes are public (#4170).** `GET /api/bd-poll-votes` returns each vote with the DRep id and the
  vote, without a login, because the DRep voters dialog reads it. **Question:** should it be restricted?
- **Anchor URLs with a port are rejected outside test mode.** pdf-ui accepts `:port` only when GovTool runs in
  development or test mode, although a URL with a port is a valid anchor. **Question:** accept ports everywhere?
- **Fixed on this branch, not yet confirmed by a run (#3917).** Motions of No Confidence (7H_4) and Updates to
  the Constitution (7H_3) were submitted without the previous action. The ledger rejects that once an action of
  the lineage has been enacted, as on preview and on the devnet.

## GovTool

- **Outcomes filters lose clicks (9C_1A, 9C_1B).** Since the React 19 / react-router 8 upgrade (2026-08-05),
  URL changes reach React in a deferred transition. The outcomes UI builds each filter change from the last
  rendered URL parameters, so a second click made before the re-render overwrites the first. Playwright's
  untick-then-tick leaves the previous filter ticked. Real users hit it too when clicking quickly. Reported to the
  outcomes UI developers for a fix in that package; GovTool's router is left as it is.
- **SPO vote totals differ between the list and the details page (4K, 4G).** For example, 63.97M ₳ in
  `/proposal/list` and 60.41M ₳ on the details page (`/proposal/get`). This also failed on QA with the Haskell
  backend. The cause is not yet pinned down; the list is served from a cached snapshot.
- **A new DRep's id and an updated vote rationale do not appear after the transaction (2N, 5L).** The backend
  caches `/drep/list` per search term and `/drep/getVotes` per DRep, and serves stale-while-revalidate: after
  the 20 s lifetime it still answers the old value once. The frontend fetches once when the transaction settles
  and never again. So a DRep registered moments ago is not found, and a re-vote still shows the first vote,
  which has no rationale. The Haskell backend cached the same way, and both tests also failed on QA.
- **Mobile: DRep share button missing (2P) and no external-link warning (5G).** Both also fail on the preview
  nightly and on QA; the desktop versions pass. Not investigated.
- **"Network: undefined" on the devnet.** The frontend has no name for the devnet network.

## Test infrastructure

- **libcardano-wallet's CIP-30 wrapper has no `getBalance`,** although the underlying wallet has one. The test
  page wallet adds it itself; an upstream fix in libcardano-wallet would remove the workaround.
