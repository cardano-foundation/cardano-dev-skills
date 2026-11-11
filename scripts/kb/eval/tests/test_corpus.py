import builtins
import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

from scripts.kb import corpus

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURE_ROOT = os.path.join(os.path.dirname(HERE), "fixtures", "corpus")
CORPUS_PY = os.path.join(os.path.dirname(os.path.dirname(HERE)), "corpus.py")


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.root = os.path.join(self.tmp, "corpus")
        shutil.copytree(FIXTURE_ROOT, self.root)

    def test_deterministic(self):
        first = corpus.build_manifest(self.root)
        second = corpus.build_manifest(self.root)
        self.assertEqual(json.dumps(first, sort_keys=True), json.dumps(second, sort_keys=True))

    def test_paths_sorted_posix_relative_regular_files(self):
        paths = [e["path"] for e in corpus.build_manifest(self.root)["files"]]
        self.assertEqual(paths, sorted(paths))
        self.assertEqual(len(paths), 4)
        self.assertTrue(all(p.startswith("docs/sources/") and "\\" not in p for p in paths))

    def test_corpus_id_formula(self):
        manifest = corpus.build_manifest(self.root)
        import hashlib
        text = "".join("%s\0%s\n" % (e["path"], e["sha256"]) for e in manifest["files"])
        self.assertEqual(manifest["corpus_id"], hashlib.sha256(text.encode()).hexdigest())

    def test_one_byte_changes_corpus_id(self):
        before = corpus.corpus_id(self.root)
        target = os.path.join(self.root, "docs", "sources", "beta", "ops.md")
        with open(target, "rb") as handle:
            data = bytearray(handle.read())
        data[0] ^= 1
        with open(target, "wb") as handle:
            handle.write(bytes(data))
        self.assertNotEqual(before, corpus.corpus_id(self.root))

    def test_added_file_changes_corpus_id(self):
        before = corpus.corpus_id(self.root)
        with open(os.path.join(self.root, "docs", "sources", "extra.txt"), "w") as handle:
            handle.write("x")
        self.assertNotEqual(before, corpus.corpus_id(self.root))

    def test_missing_corpus_directory_is_an_error(self):
        with self.assertRaises(FileNotFoundError):
            corpus.build_manifest(self.tmp)

    @unittest.skipUnless(hasattr(os, "symlink"), "needs symlinks")
    def test_symlinks_are_not_regular_files(self):
        before = corpus.corpus_id(self.root)
        link = os.path.join(self.root, "docs", "sources", "link.md")
        try:
            os.symlink(os.path.join(self.root, "docs", "sources", "beta", "ops.md"), link)
        except OSError:
            self.skipTest("symlinks unavailable")
        self.assertEqual(before, corpus.corpus_id(self.root))

    def test_copy_hashes_the_bytes_it_wrote_not_a_second_read(self):
        # The first read of each source returns bytes that differ from the file on
        # disk; any later read sees the disk. A hash of the bytes written matches
        # the destination; a hash from re-reading the source would not.
        sources = os.path.join(self.root, "docs", "sources") + os.sep
        real_open = builtins.open
        seen = set()

        def first_read_differs(file, mode="r", *args, **kwargs):
            path = os.fspath(file)
            if mode == "rb" and path.startswith(sources) and path not in seen:
                seen.add(path)
                with real_open(path, "rb") as handle:
                    return io.BytesIO(handle.read() + b"\nbytes the copy read\n")
            return real_open(file, mode, *args, **kwargs)

        dest = os.path.join(self.tmp, "copy")
        with mock.patch.object(corpus, "open", first_read_differs, create=True):
            hashes = corpus.copy_corpus(self.root, dest)
        self.assertEqual(sorted(hashes), corpus.file_paths(self.root))
        self.assertEqual(len(seen), len(hashes))
        for rel, digest in hashes.items():
            with open(os.path.join(dest, *rel.split("/")), "rb") as handle:
                written = hashlib.sha256(handle.read()).hexdigest()
            live = corpus.sha256_file(os.path.join(self.root, *rel.split("/")))
            self.assertNotEqual(written, live, rel)
            self.assertEqual(digest, written, rel)


class CliTests(unittest.TestCase):
    def run_cli(self, *args):
        return subprocess.run([sys.executable, CORPUS_PY] + list(args),
                              capture_output=True, text=True)

    def test_prints_corpus_id_twice_identically(self):
        a = self.run_cli("--root", FIXTURE_ROOT)
        b = self.run_cli("--root", FIXTURE_ROOT)
        self.assertEqual(a.returncode, 0)
        self.assertEqual(a.stdout, b.stdout)
        self.assertEqual(a.stdout.strip(), corpus.corpus_id(FIXTURE_ROOT))

    def test_json_flag_prints_manifest(self):
        out = self.run_cli("--root", FIXTURE_ROOT, "--json")
        self.assertEqual(json.loads(out.stdout)["corpus_id"], corpus.corpus_id(FIXTURE_ROOT))


if __name__ == "__main__":
    unittest.main()
