import io
import json
import os
import shutil
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

from scripts.kb.eval import retrievers, run

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURES = os.path.join(os.path.dirname(HERE), "fixtures")


class GroundingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.corpus = os.path.join(self.tmp, "corpus")
        shutil.copytree(os.path.join(FIXTURES, "corpus"), self.corpus)
        self.set_dir = os.path.join(self.tmp, "set")
        shutil.copytree(os.path.join(FIXTURES, "set"), self.set_dir)

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = run.main(list(argv) + ["--set", self.set_dir])
        return code, out.getvalue(), err.getvalue()

    def edit_labels(self, mutate):
        path = os.path.join(self.set_dir, "labels.json")
        with open(path, encoding="utf-8") as handle:
            doc = json.load(handle)
        mutate(doc)
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(doc, handle, indent=2, sort_keys=True)

    @staticmethod
    def first_location(doc, qid="q1"):
        return doc["labels"][qid]["targets"][0][0]

    def assert_refused_everywhere(self, fragment):
        for argv in (["score", "grep"], ["controls"], ["freeze", "--force"]):
            code, out, err = self.run_cli(*argv)
            self.assertEqual(code, 2, argv)
            self.assertIn("not grounded", err)
            self.assertIn(fragment, err)
            self.assertIn("question q1 group 0 location 0", err)
            self.assertNotIn("PASS", out)

    def test_valid_set_is_grounded_and_scores(self):
        code, out, err = self.run_cli("score", "grep")
        self.assertEqual(code, 0, err)
        code, out, err = self.run_cli("controls")
        self.assertEqual(code, 0, err)
        self.assertIn("controls: PASS", out)

    def test_missing_path_is_refused(self):
        self.edit_labels(lambda d: self.first_location(d).update(path="docs/sources/beta/nope.md"))
        self.assert_refused_everywhere("docs/sources/beta/nope.md")

    def test_short_prefix_is_refused_without_silent_stripping(self):
        self.edit_labels(lambda d: self.first_location(d, "q2").update(path="alpha/api.md"))
        code, _out, err = self.run_cli("score", "grep")
        self.assertEqual(code, 2)
        self.assertIn("'alpha/api.md' is not a corpus manifest path", err)
        self.assertIn("question q2", err)

    def test_range_beyond_end_of_file_is_refused(self):
        self.edit_labels(lambda d: self.first_location(d).update(end_line=9999))
        self.assert_refused_everywhere("end_line 9999 is beyond the 95 lines")

    def test_range_ending_on_the_last_line_is_valid(self):
        self.edit_labels(lambda d: self.first_location(d).update(end_line=95))
        code, _out, err = self.run_cli("controls")
        self.assertEqual(code, 0, err)

    def test_controls_cannot_report_a_perfect_oracle_for_an_imaginary_target(self):
        self.edit_labels(lambda d: self.first_location(d).update(path="docs/sources/ghost.md"))
        with self.assertRaises(ValueError):
            run.run_controls(self.set_dir, root=self.corpus, out=io.StringIO())
        code, out, _err = self.run_cli("controls")
        self.assertEqual(code, 2)
        self.assertNotIn("oracle", out)

    def test_negative_with_no_targets_stays_valid(self):
        _q, labels, _d = run.load_set(self.set_dir)
        self.assertEqual(labels["q4"], {"grade": "none", "targets": []})
        code, _out, err = self.run_cli("score", "grep")
        self.assertEqual(code, 0, err)


class IdentityBindingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.corpus = os.path.join(self.tmp, "corpus")
        shutil.copytree(os.path.join(FIXTURES, "corpus"), self.corpus)
        self.set_dir = os.path.join(self.tmp, "set")
        shutil.copytree(os.path.join(FIXTURES, "set"), self.set_dir)
        self.target = os.path.join(self.corpus, "docs", "sources", "beta", "ops.md")

    def touch_corpus(self):
        with open(self.target, "a", encoding="utf-8") as handle:
            handle.write("\nchanged between the check and the build\n")

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = run.main(list(argv) + ["--set", self.set_dir])
        return code, out.getvalue(), err.getvalue()

    def test_score_refuses_a_corpus_change_after_the_identity_check(self):
        original = run.build_retriever

        def racing(*args, **kwargs):
            self.touch_corpus()
            return original(*args, **kwargs)

        run.build_retriever = racing
        self.addCleanup(setattr, run, "build_retriever", original)
        code, out, err = self.run_cli("score", "grep")
        self.assertEqual(code, 2)
        self.assertEqual(out, "")
        self.assertIn("corpus changed while the retriever was being built", err)

    def test_controls_refuse_a_corpus_change_after_the_identity_check(self):
        original = retrievers.grep

        def racing(root=None):
            self.touch_corpus()
            return original(root)

        retrievers.grep = racing
        self.addCleanup(setattr, retrievers, "grep", original)
        code, out, err = self.run_cli("controls")
        self.assertEqual(code, 2)
        self.assertNotIn("PASS", out)
        self.assertIn("corpus changed while the retriever was being built", err)

    def test_unchanged_corpus_still_scores(self):
        code, _out, err = self.run_cli("score", "grep")
        self.assertEqual(code, 0, err)

    def test_hashes_come_from_the_bytes_that_were_parsed(self):
        before = run.set_hashes(self.set_dir)
        original = run.ground_labels

        def rewriting(questions, labels, root):
            with open(os.path.join(self.set_dir, "labels.json"), "a", encoding="utf-8") as handle:
                handle.write("\n")
            return original(questions, labels, root)

        run.ground_labels = rewriting
        self.addCleanup(setattr, run, "ground_labels", original)
        *_rest, hashes = run.load_grounded(self.set_dir)
        self.assertEqual(hashes, before)
        self.assertNotEqual(run.set_hashes(self.set_dir), before)


if __name__ == "__main__":
    unittest.main()
