import copy
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

from scripts.kb.eval import run, scorer

HERE = os.path.dirname(os.path.abspath(__file__))
EVAL_DIR = os.path.dirname(HERE)
FIXTURES = os.path.join(EVAL_DIR, "fixtures")
RUN_PY = os.path.join(EVAL_DIR, "run.py")


def result(retriever, per_question, **identity):
    ident = {"questions_sha256": "q", "labels_sha256": "l", "corpus_id": "c",
             "scorer_version": scorer.SCORER_VERSION, "corpus_mismatch_allowed": False}
    ident.update(identity)
    return {"identity": ident, "retriever": retriever, "k": 100, "per_question": [
        {"id": qid, "split": split, "metrics": {name: value for name in scorer.METRICS}}
        for qid, split, value in per_question]}


A = result("a", [("q1", "calibration", 0.0), ("q2", "calibration", 0.0),
                 ("q3", "held_out", 0.0), ("q5", "held_out", 1.0)])
B = result("b", [("q1", "calibration", 1.0), ("q2", "calibration", 1.0),
                 ("q3", "held_out", 1.0), ("q5", "held_out", 1.0)])


class CompareResultsTests(unittest.TestCase):
    def test_paired_bootstrap_of_b_minus_a_on_a_split(self):
        out = run.compare_results(A, B, split="held_out")
        self.assertEqual(out["n"], 2)
        self.assertEqual(out["mean_diff"], 0.5)
        self.assertEqual((out["wins"], out["losses"], out["ties"]), (1, 0, 1))
        self.assertEqual((out["split"], out["metric"], out["direction"]), ("held_out", "sec@5", "B - A"))

    def test_split_all_uses_every_answerable_question(self):
        self.assertEqual(run.compare_results(A, B)["n"], 4)
        self.assertEqual(run.compare_results(A, B, split="calibration")["mean_diff"], 1.0)

    def test_deterministic_and_seed_is_recorded(self):
        first = run.compare_results(A, B, "all", "sec@5", seed=7)
        self.assertEqual(first, run.compare_results(A, B, "all", "sec@5", seed=7))
        self.assertEqual(first["seed"], 7)

    def test_direction_is_b_minus_a(self):
        self.assertEqual(run.compare_results(B, A)["mean_diff"], -0.75)

    def test_refuses_each_identity_mismatch(self):
        for key in ("questions_sha256", "labels_sha256", "corpus_id", "scorer_version"):
            other = copy.deepcopy(B)
            other["identity"][key] = "different"
            with self.assertRaises(ValueError, msg=key) as ctx:
                run.compare_results(A, other)
            self.assertIn(key, str(ctx.exception))

    def test_refuses_a_missing_identity(self):
        other = copy.deepcopy(B)
        del other["identity"]
        with self.assertRaises(ValueError):
            run.compare_results(A, other)
        with self.assertRaises(ValueError):
            run.compare_results(other, other)

    def test_refuses_a_corpus_mismatch_override_on_either_side(self):
        for flagged in (result("a", [("q1", None, 0.0)], corpus_mismatch_allowed=True),):
            plain = result("b", [("q1", None, 1.0)])
            with self.assertRaises(ValueError):
                run.compare_results(flagged, plain)
            with self.assertRaises(ValueError):
                run.compare_results(plain, flagged)

    def test_refuses_an_empty_split_an_unknown_metric_and_different_k(self):
        no_split = [result("a", [("q1", None, 0.0)]), result("b", [("q1", None, 1.0)])]
        with self.assertRaises(ValueError):
            run.compare_results(*no_split, split="held_out")
        with self.assertRaises(ValueError):
            run.compare_results(A, B, metric="bogus")
        other = copy.deepcopy(B)
        other["k"] = 10
        with self.assertRaises(ValueError):
            run.compare_results(A, other)


class CompareCliTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.set_dir = os.path.join(FIXTURES, "set")
        self.a = os.path.join(self.tmp, "a.json")
        self.b = os.path.join(self.tmp, "b.json")
        for name, path in (("grep", self.a), ("random", self.b)):
            proc = subprocess.run([sys.executable, RUN_PY, "score", name, "--set", self.set_dir,
                                   "--out", path], capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, proc.stderr)

    def compare(self, *extra):
        return subprocess.run([sys.executable, RUN_PY, "compare", self.a, self.b] + list(extra),
                              capture_output=True, text=True)

    def test_score_reports_every_split(self):
        with open(self.a, encoding="utf-8") as handle:
            scored = json.load(handle)
        self.assertEqual(sorted(scored["by_split"]), ["calibration", "held_out"])
        self.assertEqual(scored["by_split"]["calibration"]["n"], 2)
        self.assertEqual(scored["by_split"]["held_out"]["n"], 2)
        self.assertEqual(sorted(scored["by_split_slice"]["held_out"]), ["how-to"])
        self.assertEqual({r["id"]: r["split"] for r in scored["per_question"]},
                         {"q1": "calibration", "q2": "calibration", "q3": "held_out", "q5": "held_out"})

    def test_compare_prints_a_confidence_interval(self):
        proc = self.compare("--split", "held_out")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        out = json.loads(proc.stdout)
        self.assertEqual((out["split"], out["n"], out["retriever_a"], out["retriever_b"]),
                         ("held_out", 2, "grep", "random"))
        self.assertIn("95% CI", proc.stderr)
        self.assertLessEqual(out["ci_low"], out["mean_diff"])
        self.assertEqual(proc.stdout, self.compare("--split", "held_out").stdout)

    def test_altered_identity_makes_compare_refuse(self):
        with open(self.b, encoding="utf-8") as handle:
            doc = json.load(handle)
        doc["identity"]["labels_sha256"] = "0" * 64
        with open(self.b, "w", encoding="utf-8") as handle:
            json.dump(doc, handle)
        proc = self.compare("--split", "held_out")
        self.assertEqual(proc.returncode, 2)
        self.assertEqual(proc.stdout, "")
        self.assertIn("labels_sha256", proc.stderr)

    def test_split_validation_in_load_set(self):
        bad = os.path.join(self.tmp, "set")
        shutil.copytree(self.set_dir, bad)
        path = os.path.join(bad, "questions.json")
        with open(path, encoding="utf-8") as handle:
            doc = json.load(handle)
        doc["questions"][0]["split"] = "test"
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(doc, handle)
        with self.assertRaises(ValueError):
            run.load_set(bad)
        doc["questions"][0].pop("split")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(doc, handle)
        self.assertNotIn("split", run.load_set(bad)[0][0])


if __name__ == "__main__":
    unittest.main()
