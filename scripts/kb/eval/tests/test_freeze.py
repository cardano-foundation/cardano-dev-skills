import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

from scripts.kb import corpus
from scripts.kb.eval import run

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURES = os.path.join(os.path.dirname(HERE), "fixtures")
RUN_PY = os.path.join(os.path.dirname(HERE), "run.py")


class FreezeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        shutil.copytree(os.path.join(FIXTURES, "corpus"), os.path.join(self.tmp, "corpus"))
        self.set_dir = os.path.join(self.tmp, "set")
        shutil.copytree(os.path.join(FIXTURES, "set"), self.set_dir)

    def score(self, *extra):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = run.main(["score", "grep", "--set", self.set_dir] + list(extra))
        return code, out.getvalue(), err.getvalue()

    def edit(self, name, mutate):
        path = os.path.join(self.set_dir, name)
        with open(path, encoding="utf-8") as handle:
            doc = json.load(handle)
        mutate(doc)
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(doc, handle, indent=2, sort_keys=True)

    def test_committed_freeze_matches_the_fixture(self):
        code, out, _err = self.score()
        self.assertEqual(code, 0)
        identity = json.loads(out)["identity"]
        self.assertEqual(identity["corpus_id"], corpus.corpus_id(os.path.join(FIXTURES, "corpus")))
        self.assertEqual(identity["scorer_version"], "kb-eval-scorer/1")
        for key in ("questions_sha256", "labels_sha256"):
            self.assertEqual(len(identity[key]), 64)
        self.assertFalse(identity["corpus_mismatch_allowed"])

    def test_output_is_byte_identical_across_runs(self):
        self.assertEqual(self.score()[1], self.score()[1])

    def test_refuses_when_labels_change_after_freeze(self):
        self.edit("labels.json", lambda d: d["labels"]["q1"]["targets"][0][0].update(start_line=1))
        code, out, err = self.score()
        self.assertEqual(code, 2)
        self.assertEqual(out, "")
        self.assertIn("labels changed", err)

    def test_refuses_when_questions_change_after_freeze(self):
        self.edit("questions.json", lambda d: d["questions"][0].update(text="changed"))
        code, _out, err = self.score()
        self.assertEqual(code, 2)
        self.assertIn("questions changed", err)

    def test_labels_change_is_not_overridable_by_the_corpus_flag(self):
        self.edit("labels.json", lambda d: d["labels"]["q1"].update(grade="partial"))
        code, _out, _err = self.score("--allow-corpus-mismatch")
        self.assertEqual(code, 2)

    def test_missing_freeze_refuses(self):
        os.remove(os.path.join(self.set_dir, "freeze.json"))
        self.assertEqual(self.score()[0], 2)

    def test_corpus_mismatch_refuses_then_is_recorded_when_overridden(self):
        target = os.path.join(self.tmp, "corpus", "docs", "sources", "beta", "ops.md")
        with open(target, "a", encoding="utf-8") as handle:
            handle.write("\nappended\n")
        code, _out, err = self.score()
        self.assertEqual(code, 2)
        self.assertIn("corpus_id", err)
        code, out, err = self.score("--allow-corpus-mismatch")
        self.assertEqual(code, 0)
        self.assertIn("WARNING", err)
        identity = json.loads(out)["identity"]
        self.assertTrue(identity["corpus_mismatch_allowed"])
        self.assertNotEqual(identity["corpus_id"], identity["frozen_corpus_id"])

    def test_freeze_command_writes_hashes_and_refuses_to_overwrite(self):
        os.remove(os.path.join(self.set_dir, "freeze.json"))
        with redirect_stdout(io.StringIO()):
            self.assertEqual(run.main(["freeze", "--set", self.set_dir]), 0)
        with open(os.path.join(self.set_dir, "freeze.json"), encoding="utf-8") as handle:
            frozen = json.load(handle)
        self.assertEqual(frozen["questions_sha256"], run.set_hashes(self.set_dir)["questions_sha256"])
        self.assertRegex(frozen["frozen_utc"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")
        with redirect_stderr(io.StringIO()):
            self.assertEqual(run.main(["freeze", "--set", self.set_dir]), 2)
        with redirect_stdout(io.StringIO()):
            self.assertEqual(run.main(["freeze", "--set", self.set_dir, "--force"]), 0)

    def test_cli_score_writes_out_file(self):
        out_file = os.path.join(self.tmp, "result.json")
        proc = subprocess.run(
            [sys.executable, RUN_PY, "score", "oracle", "--set", self.set_dir, "--out", out_file],
            capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        with open(out_file, encoding="utf-8") as handle:
            result = json.load(handle)
        self.assertEqual(result["aggregate"]["sec@5"], 1.0)
        self.assertEqual(result["negatives"]["n"], 1)


if __name__ == "__main__":
    unittest.main()
