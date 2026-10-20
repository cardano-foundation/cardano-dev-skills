#!/usr/bin/env python3
"""Exercise the shipped hook's SessionStart wire output, including path data."""

import datetime
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


HOOK = Path(__file__).resolve().with_name("check-docs.sh")


class SessionStartOutputTests(unittest.TestCase):
    def run_hook(self, root, cwd):
        env = os.environ.copy()
        env["CLAUDE_PLUGIN_ROOT"] = str(root)
        result = subprocess.run(
            [os.environ.get("HOOK_BASH", "bash"), str(HOOK)],
            input='{"hook_event_name":"SessionStart","source":"startup"}',
            text=True,
            capture_output=True,
            env=env,
            cwd=cwd,
            check=False,
            timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(set(output), {"hookSpecificOutput"})
        specific = output["hookSpecificOutput"]
        self.assertEqual(set(specific), {"hookEventName", "additionalContext"})
        self.assertEqual(specific["hookEventName"], "SessionStart")
        self.assertIsInstance(specific["additionalContext"], str)
        return specific["additionalContext"]

    def manifest(self, root, fetched):
        docs = root / "docs" / "sources"
        docs.mkdir(parents=True)
        (docs / ".manifest.yaml").write_text(
            f'last_fetched: "{fetched}"\ntotal_sources: 67\ntotal_files: 3764\n',
            encoding="utf-8",
        )

    def test_fresh_and_stale_docs(self):
        now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        with tempfile.TemporaryDirectory() as tmp:
            cwd = Path(tmp)
            for name, fetched, expected in (
                ("fresh", now, "Docs loaded: 67 sources, 3764 files"),
                ("stale", "2020-01-01T00:00:00Z", "days old (67 sources, 3764 files)"),
            ):
                with self.subTest(name=name):
                    root = cwd / name
                    self.manifest(root, fetched)
                    context = self.run_hook(root, cwd)
                    self.assertIn(expected, context)
                    self.assertIn("third-party reference data", context)

    def test_missing_docs(self):
        with tempfile.TemporaryDirectory() as tmp:
            cwd = Path(tmp)
            context = self.run_hook(cwd / "missing", cwd)
            self.assertIn("Documentation sources not found", context)

    def test_project_context(self):
        with tempfile.TemporaryDirectory() as tmp:
            cwd = Path(tmp)
            root = cwd / "plugin"
            root.mkdir()
            (cwd / "CLAUDE.md").write_text(
                "<!-- BEGIN cardano-dev-skills v3 -->\n", encoding="utf-8"
            )
            self.assertIn("Cardano context active", self.run_hook(root, cwd))

    def test_path_is_data_not_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            cwd = Path(tmp)
            root = cwd / ('plugin-"\\' + "".join(chr(c) for c in range(1, 32)) + "-é")
            self.manifest(root, "2020-01-01T00:00:00Z")
            (root / ".git").mkdir()
            context = self.run_hook(root, cwd)
            self.assertIn(f"cd {root} && git pull", context)


if __name__ == "__main__":
    unittest.main()
