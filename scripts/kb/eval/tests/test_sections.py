import os
import shutil
import tempfile
import unittest

from scripts.kb import sections


def trails(text, path="x.md"):
    return [(s.trail, s.start_line, s.end_line) for s in sections.split_text(path, text)]


class MarkdownTests(unittest.TestCase):
    def test_headings_trail_and_ranges(self):
        text = "# A\nintro\n## B\nbody\n## C\nmore\n# D\nend\n"
        self.assertEqual(trails(text), [
            (("A",), 1, 2), (("A", "B"), 3, 4), (("A", "C"), 5, 6), (("D",), 7, 8)])

    def test_preamble_before_first_heading(self):
        self.assertEqual(trails("intro\n\n# A\nx\n"), [((), 1, 2), (("A",), 3, 4)])

    def test_blank_preamble_is_dropped(self):
        self.assertEqual(trails("\n\n# A\nx\n"), [(("A",), 3, 4)])

    def test_backtick_fence_hides_headings(self):
        text = "# A\n```sh\n# not a heading\n## nor this\n```\n## B\nx\n"
        self.assertEqual(trails(text), [(("A",), 1, 5), (("A", "B"), 6, 7)])

    def test_tilde_fence_hides_headings(self):
        text = "# A\n~~~\n# no\n~~~\n## B\n"
        self.assertEqual(trails(text), [(("A",), 1, 4), (("A", "B"), 5, 5)])

    def test_longer_fence_needs_matching_close(self):
        text = "# A\n````\n```\n# still code\n```\n````\n## B\n"
        self.assertEqual(trails(text), [(("A",), 1, 6), (("A", "B"), 7, 7)])

    def test_other_fence_marker_does_not_close(self):
        text = "# A\n```\n~~~\n# code\n```\n# B\n"
        self.assertEqual(trails(text), [(("A",), 1, 5), (("B",), 6, 6)])

    def test_unclosed_fence_swallows_the_rest(self):
        self.assertEqual(trails("# A\n```\n# x\n## y\n"), [(("A",), 1, 4)])

    def test_not_headings(self):
        self.assertEqual(trails("#hashtag\n####### seven\n    # indented code\n"), [((), 1, 3)])

    def test_closing_hashes_and_level_pop(self):
        text = "## A ##\n### B\n## C\n"
        self.assertEqual([t for t, _a, _b in trails(text)], [("A",), ("A", "B"), ("C",)])

    def test_front_matter_comment_is_not_a_heading(self):
        text = "---\n# comment\ntitle: x\n---\n# Real\nbody\n"
        self.assertEqual(trails(text), [((), 1, 4), (("Real",), 5, 6)])

    def test_empty_file_and_crlf(self):
        self.assertEqual(trails(""), [])
        self.assertEqual(trails("# A\r\nx\r\n## B\r\n"), [(("A",), 1, 2), (("A", "B"), 3, 3)])

    def test_mdx_extension_splits_like_markdown(self):
        self.assertEqual(len(sections.split_text("d/page.mdx", "# A\n## B\n")), 2)


class WindowTests(unittest.TestCase):
    def test_fixed_windows_of_eighty_lines(self):
        text = "\n".join("line %d" % i for i in range(1, 201)) + "\n"
        got = [(s.trail, s.start_line, s.end_line) for s in sections.split_text("f.txt", text)]
        self.assertEqual(got, [((), 1, 80), ((), 81, 160), ((), 161, 200)])

    def test_heading_syntax_is_ignored_in_plain_text(self):
        got = sections.split_text("f.py", "# comment\ncode\n")
        self.assertEqual([(s.start_line, s.end_line) for s in got], [(1, 2)])


class CorpusTests(unittest.TestCase):
    def test_binary_and_undecodable_files_are_skipped_and_counted(self):
        tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tmp, True)
        base = os.path.join(tmp, "docs", "sources", "p")
        os.makedirs(base)
        with open(os.path.join(base, "ok.md"), "w") as handle:
            handle.write("# A\nx\n")
        with open(os.path.join(base, "bin.dat"), "wb") as handle:
            handle.write(b"ab\0cd")
        with open(os.path.join(base, "bad.txt"), "wb") as handle:
            handle.write(b"\xff\xfe\xfa not utf8")
        found, skipped = sections.split_corpus(tmp)
        self.assertEqual(skipped, 2)
        self.assertEqual([s.path for s in found], ["docs/sources/p/ok.md"])


if __name__ == "__main__":
    unittest.main()
