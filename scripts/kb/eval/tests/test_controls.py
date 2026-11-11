import collections
import io
import os
import subprocess
import sys
import unittest

from scripts.kb import sections as kb_sections
from scripts.kb.eval import retrievers, run, scorer

HERE = os.path.dirname(os.path.abspath(__file__))
EVAL_DIR = os.path.dirname(HERE)
SET_DIR = os.path.join(EVAL_DIR, "fixtures", "set")
RUN_PY = os.path.join(EVAL_DIR, "run.py")


class ConstantRetriever:
    """Returns the same ranking whatever the question."""

    def __init__(self, ranking):
        self.ranking = ranking

    def retrieve(self, question_text, k):
        return list(self.ranking)[:k]


def controls(**overrides):
    out = io.StringIO()
    ok = run.run_controls(SET_DIR, out=out, **overrides)
    return ok, out.getvalue()


def metrics_of(value):
    return {name: value for name in scorer.METRICS}


class ControlsOnFixtureTests(unittest.TestCase):
    def test_controls_pass(self):
        ok, text = controls()
        self.assertTrue(ok, text)
        self.assertEqual(text.count("PASS"), 4)
        self.assertNotIn("FAIL", text)

    def test_oracle_and_removal_values(self):
        questions, labels, doc = run.load_set(SET_DIR)
        root = run.resolve_root(SET_DIR, doc)
        lookup = run.labels_by_text(questions, labels)
        for name, expected in (("oracle", 1.0), ("removal", 0.0)):
            retriever = run.build_retriever(name, root, lookup)
            answerable, negatives = run.evaluate(questions, labels, retriever, 100)
            self.assertEqual(scorer.aggregate([m for _q, m, _r in answerable])["sec@5"], expected)
            self.assertEqual(len(negatives), 1)

    def test_fixture_covers_the_label_shapes(self):
        _q, labels, _d = run.load_set(SET_DIR)
        groups = [len(l["targets"]) for l in labels.values()]
        self.assertIn(1, groups)
        self.assertIn(2, groups)
        self.assertIn(0, groups)
        self.assertTrue(any(len(g) > 1 for l in labels.values() for g in l["targets"]))
        self.assertIn("partial", [l["grade"] for l in labels.values()])

    def test_cli_exit_codes(self):
        proc = subprocess.run([sys.executable, RUN_PY, "controls", "--set", SET_DIR],
                              capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("controls: PASS", proc.stdout)

    def test_negative_questions_have_no_hit_metrics(self):
        questions, labels, doc = run.load_set(SET_DIR)
        retriever = run.build_retriever("grep", run.resolve_root(SET_DIR, doc), {})
        answerable, negatives = run.evaluate(questions, labels, retriever, 100)
        self.assertEqual({q["id"] for q, _m, _r in answerable}, {"q1", "q2", "q3", "q5"})
        self.assertEqual([q["id"] for q, _r in negatives], ["q4"])


class MutationTests(unittest.TestCase):
    """The controls must fail when the instrument is broken."""

    def test_scorer_that_ignores_labels_and_scores_everything_fails(self):
        ok, text = controls(score_fn=lambda ranking, label: metrics_of(1.0))
        self.assertFalse(ok)
        self.assertIn("FAIL removal", text)
        self.assertIn("FAIL random", text)

    def test_scorer_that_ignores_labels_and_scores_nothing_fails(self):
        ok, text = controls(score_fn=lambda ranking, label: metrics_of(0.0))
        self.assertFalse(ok)
        self.assertIn("FAIL oracle", text)

    def test_scorer_that_rewards_any_nonempty_ranking_fails(self):
        ok, text = controls(
            score_fn=lambda ranking, label: metrics_of(1.0 if ranking else 0.0))
        self.assertFalse(ok)

    def test_constant_ranking_oracle_fails(self):
        const = ConstantRetriever([{"path": "docs/sources/alpha/guide.md", "start_line": 1, "end_line": 1}])
        ok, text = controls(oracle=lambda lookup: const)
        self.assertFalse(ok)
        self.assertIn("FAIL oracle", text)

    def test_constant_ranking_standing_in_for_removal_or_random_is_caught(self):
        questions, labels, doc = run.load_set(SET_DIR)
        lookup = run.labels_by_text(questions, labels)
        sections, _ = kb_sections.split_corpus(run.resolve_root(SET_DIR, doc))
        # A "removal" or "random" retriever that actually returns the targets must fail.
        leak = retrievers.oracle(lookup)
        ok, text = controls(removal=lambda base, lk: leak)
        self.assertFalse(ok)
        self.assertIn("FAIL removal", text)
        ok, text = controls(random_=lambda secs, seed: leak)
        self.assertFalse(ok)
        self.assertIn("FAIL random", text)
        self.assertGreater(len(sections), 50)

    def test_constant_ranking_over_every_section_fails_random(self):
        sections, _ = kb_sections.split_corpus(run.resolve_root(SET_DIR, run.load_set(SET_DIR)[2]))
        everything = ConstantRetriever(
            [{"path": s.path, "start_line": s.start_line, "end_line": s.end_line} for s in sections])
        ok, text = controls(random_=lambda secs, seed: everything)
        self.assertFalse(ok)
        self.assertIn("FAIL random", text)


class RandomControlTests(unittest.TestCase):
    def test_expected_chance_matches_a_hand_computed_value(self):
        # 4 sections, one of which hits the single group, k = 2:
        # P(miss) = (3/4) * (2/3) = 1/2, so the chance of a hit is 0.5.
        Sec = collections.namedtuple("Sec", "path start_line end_line")
        sections = [Sec("a.md", i * 10 + 1, i * 10 + 10) for i in range(4)]
        label = {"grade": "full", "targets": [[{"path": "a.md", "start_line": 1, "end_line": 10}]]}
        questions = [{"id": "q", "text": "t"}, {"id": "n", "text": "u"}]
        labels = {"q": label, "n": {"grade": "none", "targets": []}}
        self.assertAlmostEqual(run.expected_chance(questions, labels, sections, 2), 0.5)

    def test_random_control_is_reported_and_passes_on_the_fixture(self):
        ok, text = controls()
        self.assertTrue(ok, text)
        self.assertIn("random mean sec@5 over seeds 0..99", text)
        self.assertIn("measured mean", text)
        self.assertIn("threshold", text)

    def test_random_that_leaks_one_target_per_question_fails(self):
        questions, labels, _doc = run.load_set(SET_DIR)
        leak = retrievers.oracle(run.labels_by_text(questions, labels))

        class OneTarget:
            def retrieve(self, question_text, k):
                return leak.retrieve(question_text, 1)

        ok, text = controls(random_=lambda secs, seed: OneTarget())
        self.assertFalse(ok)
        self.assertIn("FAIL random", text)

    def test_seed_flag_does_not_change_the_random_verdict(self):
        outputs = []
        for seed in ("0", "7"):
            proc = subprocess.run(
                [sys.executable, RUN_PY, "controls", "--set", SET_DIR, "--seed", seed],
                capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            outputs.append(proc.stdout)
        self.assertEqual(outputs[0], outputs[1])

    def test_decoy_scripts_package_on_pythonpath_cannot_shadow_the_harness(self):
        import shutil
        import tempfile
        decoy = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, decoy, True)
        os.makedirs(os.path.join(decoy, "scripts"))
        open(os.path.join(decoy, "scripts", "__init__.py"), "w").close()
        env = dict(os.environ, PYTHONPATH=decoy)
        proc = subprocess.run([sys.executable, RUN_PY, "controls", "--set", SET_DIR],
                              capture_output=True, text=True, env=env)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("controls: PASS", proc.stdout)


class RetrieverTests(unittest.TestCase):
    def test_grep_is_deterministic_and_stopwords_do_not_count(self):
        root = run.resolve_root(SET_DIR, run.load_set(SET_DIR)[2])
        grep = retrievers.grep(root)
        self.assertEqual(grep.retrieve("rotate the signing key", 5), grep.retrieve("rotate the signing key", 5))
        top = grep.retrieve("How do I rotate the signing key?", 1)[0]
        self.assertEqual((top["path"], top["start_line"]), ("docs/sources/beta/ops.md", 29))
        self.assertEqual(grep.retrieve("the of and to", 5), [])
        self.assertEqual(grep.retrieve("zzzzqqq", 5), [])

    def test_random_is_seeded_per_question(self):
        sections, _ = kb_sections.split_corpus(run.resolve_root(SET_DIR, run.load_set(SET_DIR)[2]))
        a = retrievers.random_retriever(sections, 1)
        self.assertEqual(a.retrieve("q", 5), retrievers.random_retriever(sections, 1).retrieve("q", 5))
        self.assertNotEqual(a.retrieve("q", 5), retrievers.random_retriever(sections, 2).retrieve("q", 5))

    def test_oracle_lists_one_hit_per_group_first(self):
        label = {"grade": "full", "targets": [
            [{"path": "a.md", "start_line": 1, "end_line": 2}, {"path": "b.md", "start_line": 1, "end_line": 2}],
            [{"path": "c.md", "start_line": 1, "end_line": 2}]]}
        ranking = retrievers.oracle({"q": label}).retrieve("q", 10)
        self.assertEqual([r["path"] for r in ranking], ["a.md", "c.md", "b.md"])

    def test_removal_drops_every_record_hitting_a_label(self):
        label = {"grade": "full", "targets": [[{"path": "a.md", "start_line": 1, "end_line": 5}]]}
        base = ConstantRetriever([
            {"path": "a.md", "start_line": 4, "end_line": 9},
            {"path": "a.md", "start_line": 6, "end_line": 9}])
        out = retrievers.removal(base, {"q": label}).retrieve("q", 10)
        self.assertEqual(out, [{"path": "a.md", "start_line": 6, "end_line": 9}])


if __name__ == "__main__":
    unittest.main()
