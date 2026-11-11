import unittest

from scripts.kb.eval import scorer


def loc(path, a, b):
    return {"path": path, "start_line": a, "end_line": b}


def rec(path, a, b, **extra):
    out = loc(path, a, b)
    out.update(extra)
    return out


def full(groups):
    return {"grade": "full", "targets": groups}


class HitTests(unittest.TestCase):
    def test_overlap_and_boundaries(self):
        target = loc("a.md", 10, 20)
        self.assertTrue(scorer.hits(rec("a.md", 20, 30), target))
        self.assertTrue(scorer.hits(rec("a.md", 1, 10), target))
        self.assertTrue(scorer.hits(rec("a.md", 12, 14), target))
        self.assertFalse(scorer.hits(rec("a.md", 21, 30), target))
        self.assertFalse(scorer.hits(rec("a.md", 1, 9), target))

    def test_paths_must_match(self):
        self.assertFalse(scorer.hits(rec("b.md", 10, 20), loc("a.md", 10, 20)))


class QuestionMetricTests(unittest.TestCase):
    def test_single_group_at_rank_three(self):
        label = full([[loc("t.md", 1, 5)]])
        ranking = [rec("x.md", 1, 2), rec("y.md", 1, 2), rec("t.md", 3, 4)]
        m = scorer.score_question(ranking, label)
        self.assertEqual(m["sec@5"], 1.0)
        self.assertAlmostEqual(m["mrr"], 1 / 3)
        self.assertEqual(m["file@5"], 1.0)

    def test_hit_beyond_k(self):
        label = full([[loc("t.md", 1, 5)]])
        ranking = [rec("x%d.md" % i, 1, 1) for i in range(1, 7)] + [rec("t.md", 1, 5)]
        m = scorer.score_question(ranking, label)
        self.assertEqual(m["sec@5"], 0.0)
        self.assertEqual(m["sec@10"], 1.0)
        self.assertEqual(m["file@5"], 0.0)

    def test_and_groups_need_every_group(self):
        label = full([[loc("a.md", 1, 5)], [loc("b.md", 1, 5)]])
        only_first = scorer.score_question([rec("a.md", 1, 5)], label)
        self.assertEqual(only_first["sec@5"], 0.0)
        self.assertEqual(only_first["cov@5"], 0.5)
        both = scorer.score_question([rec("a.md", 1, 5), rec("b.md", 2, 2)], label)
        self.assertEqual(both["sec@5"], 1.0)
        self.assertEqual(both["cov@5"], 1.0)

    def test_or_alternatives_any_location_satisfies_the_group(self):
        label = full([[loc("a.md", 1, 5), loc("b.md", 1, 5)]])
        for path in ("a.md", "b.md"):
            self.assertEqual(scorer.score_question([rec(path, 3, 3)], label)["sec@5"], 1.0)
        self.assertEqual(scorer.score_question([rec("c.md", 3, 3)], label)["sec@5"], 0.0)

    def test_mrr_uses_first_hit_of_any_group(self):
        label = full([[loc("a.md", 1, 5)], [loc("b.md", 1, 5)]])
        ranking = [rec("z.md", 1, 1), rec("b.md", 1, 1), rec("a.md", 1, 1)]
        self.assertAlmostEqual(scorer.score_question(ranking, label)["mrr"], 0.5)

    def test_file_at_k_counts_distinct_paths(self):
        label = full([[loc("t.md", 90, 99)]])
        # Five records from the same file occupy one distinct path slot, so t.md is
        # the second distinct path and file@5 holds although sec@5 fails.
        ranking = [rec("x.md", i, i) for i in range(1, 6)] + [rec("t.md", 1, 2)]
        m = scorer.score_question(ranking, label)
        self.assertEqual(m["file@5"], 1.0)
        self.assertEqual(m["sec@5"], 0.0)

    def test_file_at_k_and_groups_in_different_files(self):
        label = full([[loc("a.md", 1, 1)], [loc("b.md", 1, 1)]])
        ranking = [rec("a.md", 50, 51), rec("a.md", 52, 53), rec("b.md", 50, 51)]
        m = scorer.score_question(ranking, label)
        self.assertEqual(m["file@5"], 1.0)
        self.assertEqual(m["sec@5"], 0.0)

    def test_empty_ranking_scores_zero(self):
        m = scorer.score_question([], full([[loc("a.md", 1, 1)]]))
        self.assertEqual(set(m), set(scorer.METRICS))
        self.assertTrue(all(v == 0.0 for v in m.values()))

    def test_negative_label_is_not_scoreable(self):
        with self.assertRaises(ValueError):
            scorer.score_question([rec("a.md", 1, 1)], {"grade": "none", "targets": []})

    def test_label_validation(self):
        with self.assertRaises(ValueError):
            scorer.validate_label({"grade": "full", "targets": []})
        with self.assertRaises(ValueError):
            scorer.validate_label({"grade": "none", "targets": [[loc("a.md", 1, 1)]]})
        with self.assertRaises(ValueError):
            scorer.validate_label({"grade": "full", "targets": [[loc("a.md", 5, 1)]]})
        with self.assertRaises(ValueError):
            scorer.validate_label({"grade": "bogus", "targets": []})


class AggregationTests(unittest.TestCase):
    def test_aggregate_means_and_empty(self):
        a = {name: 1.0 for name in scorer.METRICS}
        b = {name: 0.0 for name in scorer.METRICS}
        agg = scorer.aggregate([a, b])
        self.assertEqual(agg["n"], 2)
        self.assertEqual(agg["sec@5"], 0.5)
        empty = scorer.aggregate([])
        self.assertEqual(empty["n"], 0)
        self.assertIsNone(empty["sec@5"])

    def test_by_slice(self):
        one = {name: 1.0 for name in scorer.METRICS}
        zero = {name: 0.0 for name in scorer.METRICS}
        out = scorer.aggregate_by_slice([("x", one), ("y", zero), ("x", zero)])
        self.assertEqual(out["x"]["sec@5"], 0.5)
        self.assertEqual(out["y"]["n"], 1)

    def test_negatives_report_top_score_only(self):
        report = scorer.negatives_report(
            [("n1", [rec("a.md", 1, 1, score=0.5), rec("b.md", 1, 1, score=0.2)]), ("n2", [])]
        )
        self.assertEqual(report["top_scores"], {"n1": 0.5, "n2": None})
        self.assertEqual(report["mean_top_score"], 0.5)
        self.assertNotIn("sec@5", report)


class BootstrapTests(unittest.TestCase):
    def test_deterministic_for_a_seed(self):
        a = [1.0, 1.0, 0.0, 1.0, 0.5, 1.0]
        b = [0.0, 1.0, 0.0, 0.0, 0.5, 0.0]
        first = scorer.paired_bootstrap(a, b, seed=7, resamples=2000)
        second = scorer.paired_bootstrap(a, b, seed=7, resamples=2000)
        self.assertEqual(first, second)
        self.assertEqual((first["wins"], first["losses"], first["ties"]), (3, 0, 3))

    def test_default_resamples_and_ci_brackets_mean(self):
        a = [1.0] * 8 + [0.0] * 2
        b = [0.0] * 5 + [1.0] * 5
        out = scorer.paired_bootstrap(a, b)
        self.assertEqual(out["resamples"], 10000)
        self.assertLessEqual(out["ci_low"], out["mean_diff"])
        self.assertGreaterEqual(out["ci_high"], out["mean_diff"])

    def test_identical_samples_have_zero_width_interval(self):
        out = scorer.paired_bootstrap([1.0, 0.0], [1.0, 0.0], resamples=500)
        self.assertEqual((out["ci_low"], out["ci_high"], out["ties"]), (0.0, 0.0, 2))

    def test_rejects_mismatched_or_empty(self):
        with self.assertRaises(ValueError):
            scorer.paired_bootstrap([1.0], [1.0, 0.0])
        with self.assertRaises(ValueError):
            scorer.paired_bootstrap([], [])


if __name__ == "__main__":
    unittest.main()
