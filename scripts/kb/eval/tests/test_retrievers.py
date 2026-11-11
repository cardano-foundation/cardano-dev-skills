import os
import shutil
import tempfile
import unittest

from scripts.kb.eval import retrievers


def write(root, rel, text):
    path = os.path.join(root, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


class GrepRankingTests(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root, True)

    def ranking(self, question):
        return [(r["path"], r["start_line"]) for r in retrievers.grep(self.root).retrieve(question, 10)]

    def test_more_distinct_terms_beat_more_occurrences(self):
        write(self.root, "docs/sources/p/a.md",
              "# A\nalpha beta\n")
        write(self.root, "docs/sources/p/b.md",
              "# B\nalpha alpha alpha alpha alpha\n")
        # A has two distinct query terms once each; B has one term five times.
        self.assertEqual(self.ranking("alpha beta"),
                         [("docs/sources/p/a.md", 1), ("docs/sources/p/b.md", 1)])

    def test_total_occurrences_break_a_distinct_term_tie(self):
        write(self.root, "docs/sources/p/a.md", "# A\nalpha\n")
        write(self.root, "docs/sources/p/b.md", "# B\nalpha alpha\n")
        self.assertEqual(self.ranking("alpha"),
                         [("docs/sources/p/b.md", 1), ("docs/sources/p/a.md", 1)])

    def test_full_tie_breaks_by_path_then_line(self):
        write(self.root, "docs/sources/p/z.md", "# Z\nalpha\n")
        write(self.root, "docs/sources/p/a.md", "# One\nalpha\n# Two\nalpha\n")
        self.assertEqual(self.ranking("alpha"),
                         [("docs/sources/p/a.md", 1), ("docs/sources/p/a.md", 3),
                          ("docs/sources/p/z.md", 1)])

    def test_tie_break_by_start_line_beats_term_order(self):
        # Both sections hold one distinct term once. Terms are visited alphabetically,
        # so insertion order would put the later section (alpha) first; the start_line
        # key must put the earlier section first.
        write(self.root, "docs/sources/p/a.md", "# One\nbeta\n# Two\nalpha\n")
        self.assertEqual(self.ranking("alpha beta"),
                         [("docs/sources/p/a.md", 1), ("docs/sources/p/a.md", 3)])


if __name__ == "__main__":
    unittest.main()
