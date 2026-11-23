# Generator-safe Cardano context

This protocol is an explicit entrypoint for a caller performing a scaffold or
generator operation that the user requested. Invocation includes context setup
or update and should be reported without asking a redundant setup question.
It is not a standing scan: ordinary development, generators run outside this
workflow, and unrelated project files receive no protection guarantee.

The canonical setup and upgrade algorithm remains Steps 1 through 6 in
`../SKILL.md`. This reference prepares a safe post-generator baseline and then
hands control to those steps; it never reproduces their block matching,
upgrade, import, same-file, symlink, readback, or reporting rules.

## Before any generator write

1. Inventory every path the requested operation may create, replace, update,
   or delete. Include instruction files and relevant host adapter or import
   files for those paths, but do not scan other files or contexts merely
   because they exist.
2. Resolve each inventoried path, including symlink targets. Record which
   logical names resolve to the same file and whether a target is outside the
   project. Preserve the canonical setup's same-file and outside-project
   symlink asks; do not let a generator write through an unresolved layout.
3. Read the complete existing instruction and relevant adapter files. Record
   line endings, marked Cardano regions, bare imports, other owned regions,
   custom text, and newer, malformed, duplicated, or ambiguous content. A
   file's presence alone is not proof that a host loads it.
4. Establish the generator's release and exact selection, the current commit
   when one exists, the generator's predicted write set, and whether its dirty
   tree prerequisite is satisfied. Preview where the supported interface has
   a nonwriting preview, but do not treat preview output as a preservation
   guarantee.
5. Classify ownership before writing. Generator-owned facts require either a
   known generated baseline for that exact release and selection or
   trustworthy recorded provenance. Familiar headings, plausible prose, and
   resemblance to another template are not provenance. Cardano context owns
   only its marked regions; another adapter owns only its documented region;
   developer text is custom only when its provenance or difference from the
   established baseline proves that ownership.

If attribution is ambiguous, a marked region is edited, newer, malformed, or
duplicated, an adapter conflicts with the canonical file, or a destructive
writer step would discard material that cannot be safely preserved, show the
relevant condition and proposed result and ask before the generator writes.
Keep every existing ask from the canonical workflow. Do not use a force or
dirty-bypass flag to avoid one. Routine replacement of generator-owned facts
needs no extra question when their provenance is established and all proven
custom or owned material can be safely preserved.

## Recovery material

For an existing project, before the generator writes, keep a recoverable
pristine copy of only the safe material needed to reconcile this operation:

- generator source or instruction files in the predicted write set;
- relevant adapter/import files;
- bounded diagnostics; and
- the CLI release, exact selection, and existing commit identifier.

Place it in a newly created private directory outside the target project and
disclose that location in the report. Restrict it to this operation. Exclude
the project's `.git`, environment files, secret or key files, dependencies,
build output, and symlink targets outside the project. Inspect a candidate for
unexpected secrets before copying it. If one is found, stop that copy and ask
without displaying or recording the secret. Do not broaden the copy to a
whole tree for convenience.

Retain the recovery directory through the final report. Remove only copies
this workflow specifically created, and only when the user asks or the agreed
operation includes that cleanup. Never delete or overwrite an unknown recovery
directory.

For a fresh scaffold there is no pre-existing target tree. Preserve only safe
pristine generated source, instructions, diagnostics, and identity information
after they exist and before adaptation, under the same exclusions. Do not
invent a pre-generation backup or copy the new repository wholesale.

## Run and reconcile

1. Re-check the dirty-tree prerequisite immediately before a later generator
   command and report it. Let the generator enforce its own prerequisite;
   never force it, make a hidden commit, or modify unrelated files to obtain a
   clean result.
2. Run only the requested generator operation under ordinary host permissions.
   No permission, acquisition, network, or host-setting expansion is implied
   by this protocol.
3. After success, inventory the actual write set and read every changed
   instruction and relevant adapter file in full. Fresh generator-owned facts
   from the requested release and selection are the baseline. Preserve proven
   custom text and owned regions by merging them into that fresh baseline;
   never restore an old whole instruction file over newly generated facts.
4. Before each merge, compare the current file with the saved pre-write state
   or the just-generated expectation, whichever applies. If it changed
   concurrently, stop on that file and ask. Never silently overwrite the
   third state.
5. Keep ownership visible. Generator facts remain outside the Cardano marked
   region. The canonical Cardano directive remains in its one marked region.
   Preserve another adapter's proven owned region without claiming ownership
   of its surrounding file.
6. Once the post-generator baseline is safe, run Steps 1 through 6 in
   `../SKILL.md`. Read back every instruction and relevant adapter file in full
   after the merge and canonical setup. The existing no-downgrade, import,
   same-file, symlink, line-ending, and no-auto-create-`CLAUDE.md` rules still
   apply.

For cardano-init 0.4.1, initial generation emits `AGENTS.md` and a
`CLAUDE.md` containing the bare `@AGENTS.md` import. Reuse that import; do not
add a marked import region beside it. Its existence proves the file shape,
not native loading. There is no universal Claude import syntax across hosts.

Current documented Cursor and Antigravity behavior can consume a project
`AGENTS.md`, so they need no copied Cardano directive or new adapter. For any
other host, inspect only the relevant existing adapter and documented
capability. If it cannot consume the canonical file, report the limitation
and ask before a minimal explicit adapter edit. Do not modify host settings,
install a runtime, or create speculative adapter files.

## Failure, partial output, and recovery

A dirty refusal leaves the target unchanged from this workflow's perspective;
report the refusal, dirty prerequisite, and retained recovery location. A
failed or interrupted write may leave partial output. Preserve bounded error
evidence and the partial instruction state, then merge only material whose
ownership is clear and whose repair is straightforward and in scope.

Stop and ask when recovery is ambiguous, would discard work, would overwrite a
concurrent edit, or requires files outside the requested operation. Never
blindly retry, force the writer, roll back a whole tree or whole instruction
file, reset version control, create a hidden commit, or claim that stale
generated facts are restored safely. Leave unrelated partial output for the
generator caller to handle under its own contract.

## Report

Report all of the following, using observed state rather than intent:

- the generator release and selection, actual outcome, and actual instruction
  files it changed;
- each file's exact Cardano context status from the canonical Step 6 report;
- freshly generated facts retained, proven custom or owned material
  preserved, and every ambiguous item left unresolved;
- the disclosed private recovery directory and what safe categories it holds;
- the dirty-tree prerequisite before any later generator command;
- each host limitation, adapter decision, or unproven loading claim; and
- any partial output, concurrent divergence, or recovery decision still
  requiring the user.

Call the result protocol conformance unless an actual installed host was
evaluated. File shape and documented host support are not proof that a native
agent loaded the directive.
