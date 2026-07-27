#!/usr/bin/env python3
"""Routing eval runner: does each eval prompt auto-trigger the right skill?

Runs each prompt in a fresh headless `claude -p` session from an empty temp
directory (so no project CLAUDE.md biases routing) and checks which skill the
agent invokes first. Manual tool — not wired into CI, since every eval is a
live model session with real API cost.

Prerequisites:
  - `claude` CLI on PATH with the cardano-dev-skills plugin installed
    (for a working clone: `claude plugin marketplace add <clone-path>` then
    `claude plugin install cardano-dev-skills@cardano-dev-skills`).
  - Default permission mode. Do NOT wrap in `--permission-mode acceptEdits`:
    empirically (2026-07-27) that mode denies Skill tool execution outright
    in headless sessions, which would score every eval as no-trigger.

Usage:
  python3 scripts/run-evals.py                     # all skills/*/evals/evals.json
  python3 scripts/run-evals.py --skill explain-cip --skill explain-eutxo
  python3 scripts/run-evals.py --model claude-haiku-4-5-20251001 --jobs 2
  python3 scripts/run-evals.py --list              # show evals without running

Scoring:
  expect=trigger    -> PASS iff the first Skill invocation is the owning skill.
  expect=no-trigger -> PASS iff the owning skill is never invoked; if
                       `expected_instead` is set and something else (or
                       nothing) fired, that is reported as INFO, not FAIL —
                       the sibling's own trigger eval owns that assertion.

Exit code 0 if no FAIL/ERROR, 1 otherwise — usable as a manual regression
gate before/after editing skill descriptions.
"""

import argparse
import concurrent.futures
import json
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PLUGIN_PREFIX = "cardano-dev-skills:"


def discover(skill_filters):
    evals = []
    for path in sorted(REPO_ROOT.glob("skills/*/evals/evals.json")):
        skill = path.parent.parent.name
        if skill_filters and skill not in skill_filters:
            continue
        data = json.loads(path.read_text())
        if data.get("skill") != skill:
            print(f"WARNING: {path} declares skill={data.get('skill')!r}, "
                  f"directory says {skill!r}; using directory name")
        for i, ev in enumerate(data.get("evals", [])):
            evals.append({
                "skill": skill,
                "index": i,
                "prompt": ev["prompt"],
                "expect": ev["expect"],
                "expected_instead": ev.get("expected_instead"),
            })
    return evals


def first_skill_invocation(stream_json_text):
    """Return the first Skill tool_use's skill name (prefix stripped), or None."""
    for line in stream_json_text.splitlines():
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if ev.get("type") != "assistant":
            continue
        for c in ev.get("message", {}).get("content", []):
            if isinstance(c, dict) and c.get("type") == "tool_use" \
                    and c.get("name") == "Skill":
                name = c.get("input", {}).get("skill", "")
                if name.startswith(PLUGIN_PREFIX):
                    name = name[len(PLUGIN_PREFIX):]
                return name
    return None


def run_eval(ev, args):
    cmd = [
        "claude", "-p", ev["prompt"],
        "--max-turns", str(args.max_turns),
        "--output-format", "stream-json", "--verbose",
    ]
    if args.model:
        cmd += ["--model", args.model]
    # Fresh empty cwd per eval: no CLAUDE.md, no git, no bias.
    with tempfile.TemporaryDirectory(prefix="cds-eval-") as cwd:
        try:
            proc = subprocess.run(
                cmd, cwd=cwd, capture_output=True, text=True,
                timeout=args.timeout,
            )
        except subprocess.TimeoutExpired:
            return {**ev, "status": "ERROR", "invoked": None,
                    "detail": f"timeout after {args.timeout}s"}
    invoked = first_skill_invocation(proc.stdout)

    if ev["expect"] == "trigger":
        status = "PASS" if invoked == ev["skill"] else "FAIL"
        detail = f"invoked={invoked}"
    else:  # no-trigger
        if invoked == ev["skill"]:
            status, detail = "FAIL", f"owning skill fired on a sibling's prompt"
        else:
            status = "PASS"
            detail = f"invoked={invoked}"
            if ev["expected_instead"] and invoked != ev["expected_instead"]:
                status = "PASS"  # sibling assertion is informational here
                detail += f" (INFO: expected_instead={ev['expected_instead']})"
    return {**ev, "status": status, "invoked": invoked, "detail": detail}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--skill", action="append", default=[],
                    help="only run evals for this skill (repeatable)")
    ap.add_argument("--model", help="model override passed to claude --model")
    ap.add_argument("--jobs", type=int, default=4,
                    help="concurrent sessions (default 4)")
    ap.add_argument("--max-turns", type=int, default=4,
                    help="max turns per session (default 4)")
    ap.add_argument("--timeout", type=int, default=240,
                    help="per-session timeout in seconds (default 240)")
    ap.add_argument("--json", dest="json_out",
                    help="also write machine-readable results to this path")
    ap.add_argument("--list", action="store_true",
                    help="list discovered evals and exit without running")
    args = ap.parse_args()

    evals = discover(args.skill)
    if not evals:
        print("No evals found.")
        return 1
    if args.list:
        for ev in evals:
            print(f"{ev['skill']}[{ev['index']}] {ev['expect']:10s} {ev['prompt']}")
        print(f"\n{len(evals)} evals (each is one live claude -p session)")
        return 0

    print(f"Running {len(evals)} evals, {args.jobs} at a time "
          f"(each is a live claude -p session)...\n")
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as ex:
        futures = {ex.submit(run_eval, ev, args): ev for ev in evals}
        for fut in concurrent.futures.as_completed(futures):
            r = fut.result()
            results.append(r)
            print(f"{r['status']:5s} {r['skill']}[{r['index']}] "
                  f"{r['expect']:10s} {r['detail']}")

    results.sort(key=lambda r: (r["skill"], r["index"]))
    fails = [r for r in results if r["status"] in ("FAIL", "ERROR")]
    print(f"\n{len(results) - len(fails)}/{len(results)} passed")
    for r in fails:
        print(f"  {r['status']} {r['skill']}[{r['index']}]: {r['prompt']!r} "
              f"-> {r['detail']}")
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(results, indent=1))
        print(f"Results written to {args.json_out}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
