"""The give-feedback send command files exactly the approved draft.

Reads the ```bash template from Step 4 of skills/give-feedback/SKILL.md, fills it
by the rules that section documents, and runs it with bash against a capture `gh`
placed first on PATH: a small script that records its argv and stdin bytes and
does nothing else. The real gh is never invoked and nothing touches the network.

Each case asserts that the captured `--title` argument equals the title exactly,
that stdin equals the body plus the one trailing newline a heredoc always adds,
and that nothing in either was evaluated (no sentinel file appeared).

A draft never contains NUL: SKILL.md has it removed while drafting, before the
draft is shown, because bash drops NUL silently and a delimiter line ending in
NUL would close the heredoc early. The fill helper implements that rule by
refusing such a title or body, so the transport is never run with one.

The mutation controls build broken variants of the same template and require the
same checks to report problems, so a green run shows the checks can see the
defects they exist to catch.

GIVE_FEEDBACK_SKILL_MD overrides the SKILL.md path, so the suite can be pointed
at another revision of the file (it must fail against a template that quotes the
title in double quotes or uses a fixed heredoc delimiter).
"""

import json
import os
import re
import secrets
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SKILL_MD = os.environ.get(
    "GIVE_FEEDBACK_SKILL_MD",
    os.path.join(REPO_ROOT, "skills", "give-feedback", "SKILL.md"),
)

REPO = "cardano-foundation/cardano-dev-skills"
LABELS = {"documentation", "enhancement", "feedback"}
SUFFIX_PLACEHOLDER = "<suffix>"
SENTINEL = "SENTINEL"

TITLE_RE = re.compile(r"""--title (['"])(.*?)\1""")
HEREDOC_RE = re.compile(r"""<<(['"]?)([A-Za-z_][A-Za-z0-9_<>]*)\1[ \t]*$""")

CAPTURE_PY = """\
import json, os, sys
argv = [os.fsencode(a).hex() for a in sys.argv[1:]]
data = sys.stdin.buffer.read().hex()
with open({out!r}, "w") as f:
    json.dump({{"argv": argv, "stdin": data}}, f)
"""


def read_skill():
    with open(SKILL_MD, encoding="utf-8") as f:
        return f.read()


def send_template(text):
    """The single ```bash block of the Step 4 (Send) section."""
    # The body template inside the block has its own "### " lines, so the
    # section ends at the next step or top-level heading, not at any "### ".
    match = re.search(r"^### Step 4: Send\n(.*?)(?=^### Step |^## |\Z)", text, re.M | re.S)
    if match is None:
        raise AssertionError("SKILL.md has no '### Step 4: Send' section")
    blocks = re.findall(r"^```bash\n(.*?)^```", match.group(1), re.M | re.S)
    if len(blocks) != 1:
        raise AssertionError("Step 4 must hold exactly one ```bash block, found %d" % len(blocks))
    return blocks[0]


def quote_title(title, quote):
    """Fill the title by the documented rule for a single-quoted word.

    A double-quoted template gets the title inserted as written, which is what
    a double-quoted template invites and what the mutation control exercises.
    """
    if quote == "'":
        return "'" + title.replace("'", "'\\''") + "'"
    return '"' + title + '"'


def fresh_suffixes():
    while True:
        yield secrets.token_hex(6)  # 12 hex characters


class DraftRuleError(ValueError):
    """The title or body breaks a rule SKILL.md applies while drafting."""


def fill(template, title, body, suffixes=None):
    """Return the shell script for one send, and the delimiter it uses.

    Refuses a title or body containing NUL: by the documented rule the draft
    shown, and so the draft approved, never has one.
    """
    for part, text in (("title", title), ("body", body)):
        if "\0" in text:
            raise DraftRuleError("%s contains a NUL byte; SKILL.md removes it while drafting" % part)
    return fill_without_nul_rule(template, title, body, suffixes)


def fill_without_nul_rule(template, title, body, suffixes=None):
    """fill() minus the NUL refusal; only the mutation control calls it directly."""
    if suffixes is None:
        suffixes = fresh_suffixes()
    lines = template.split("\n")
    if lines and lines[-1] == "":
        lines.pop()

    title_hits = [i for i, line in enumerate(lines) if TITLE_RE.search(line)]
    if len(title_hits) != 1:
        raise AssertionError("template must pass --title exactly once as one quoted word")
    i = title_hits[0]
    lines[i] = TITLE_RE.sub(
        lambda m: "--title " + quote_title(title, m.group(1)), lines[i], count=1
    )

    start = next((i for i, line in enumerate(lines) if HEREDOC_RE.search(line)), None)
    if start is None:
        raise AssertionError("template has no heredoc")
    word = HEREDOC_RE.search(lines[start]).group(2)
    try:
        end = lines.index(word, start + 1)
    except ValueError:
        raise AssertionError("template heredoc %r is never closed" % word)

    body_lines = body.split("\n")
    delimiter = word
    if SUFFIX_PLACEHOLDER in word:
        # Fresh per send; never one that a body line already equals.
        for suffix in suffixes:
            delimiter = word.replace(SUFFIX_PLACEHOLDER, suffix)
            if delimiter not in body_lines:
                break
    lines[start] = lines[start].replace(word, delimiter)
    script = lines[: start + 1] + body_lines + [delimiter] + lines[end + 1 :]
    return "\n".join(script) + "\n", delimiter


class Sandbox:
    """A temp dir with a capture gh first on PATH and an empty working dir."""

    def __init__(self):
        self.root = tempfile.mkdtemp(prefix="give-feedback-send-")
        self.bin = os.path.join(self.root, "bin")
        self.home = os.path.join(self.root, "home")
        self.work = os.path.join(self.root, "work")
        for d in (self.bin, self.home, self.work):
            os.mkdir(d)
        self.out = os.path.join(self.root, "captured.json")
        capture_py = os.path.join(self.root, "capture.py")
        with open(capture_py, "w") as f:
            f.write(CAPTURE_PY.format(out=self.out))
        gh = os.path.join(self.bin, "gh")
        with open(gh, "w") as f:
            f.write(
                "#!/bin/sh\nexec %s -I %s \"$@\"\n"
                % (shlex.quote(sys.executable), shlex.quote(capture_py))
            )
        os.chmod(gh, 0o755)
        self.gh = gh
        self.path = os.pathsep.join([self.bin, "/usr/bin", "/bin"])

    def close(self):
        shutil.rmtree(self.root, ignore_errors=True)


def run_send(template, title, body, suffixes=None, filler=fill):
    """Fill the template, run it, and return what the capture gh saw."""
    script, delimiter = filler(template, title, body, suffixes)
    box = Sandbox()
    try:
        resolved = shutil.which("gh", path=box.path)
        if resolved != box.gh:
            raise AssertionError("gh resolves to %r, not the capture script" % resolved)
        script_path = os.path.join(box.root, "send.sh")
        with open(script_path, "wb") as f:
            f.write(script.encode("utf-8"))
        proc = subprocess.run(
            ["env", "-i", "PATH=" + box.path, "HOME=" + box.home, "bash", script_path],
            cwd=box.work,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=60,
        )
        captured = None
        if os.path.exists(box.out):
            with open(box.out) as f:
                raw = json.load(f)
            captured = {
                "argv": [bytes.fromhex(a) for a in raw["argv"]],
                "stdin": bytes.fromhex(raw["stdin"]),
            }
        return {
            "returncode": proc.returncode,
            "stderr": proc.stderr.decode("utf-8", "replace"),
            "captured": captured,
            "side_effects": sorted(os.listdir(box.work)),
            "delimiter": delimiter,
        }
    finally:
        box.close()


def problems(result, title, body):
    """Every way the send differs from the approved draft; empty when exact."""
    found = []
    if result["returncode"] != 0:
        found.append("bash exited %d: %s" % (result["returncode"], result["stderr"].strip()))
    if result["side_effects"]:
        found.append("the shell evaluated draft text: created %r" % result["side_effects"])
    captured = result["captured"]
    if captured is None:
        found.append("gh was never invoked")
        return found
    argv = captured["argv"]
    if argv[:2] != [b"issue", b"create"]:
        found.append("not `gh issue create`: %r" % argv[:2])
    rest = argv[2:]
    if len(rest) % 2:
        found.append("odd option list: %r" % rest)
    options = {}
    for key, value in zip(rest[0::2], rest[1::2]):
        if key in options:
            found.append("option %r passed twice" % key)
        options[key] = value
    expected_keys = {b"-R", b"--title", b"--label", b"--body-file"}
    if set(options) != expected_keys:
        found.append("options %r, expected %r" % (sorted(options), sorted(expected_keys)))
    if options.get(b"-R") != REPO.encode():
        found.append("repository %r" % options.get(b"-R"))
    if options.get(b"--label", b"").decode("utf-8", "replace") not in LABELS:
        found.append("label %r is not one of the fixed literals" % options.get(b"--label"))
    if options.get(b"--body-file") != b"-":
        found.append("body not read from stdin: %r" % options.get(b"--body-file"))
    if options.get(b"--title") != title.encode("utf-8"):
        found.append("title %r != %r" % (options.get(b"--title"), title.encode("utf-8")))
    # A heredoc always ends its text with one newline after the last body line.
    expected_stdin = body.encode("utf-8") + b"\n"
    if captured["stdin"] != expected_stdin:
        found.append("stdin %r != %r" % (captured["stdin"], expected_stdin))
    return found


NORMAL_BODY = (
    "### Where\n"
    "skills/write-validator/SKILL.md (section \"Workflow\")\n"
    "\n"
    "### What happened\n"
    "The example compiled but the redeemer index was off by one.\n"
    "\n"
    "### What would have helped\n"
    "One sentence on input ordering.\n"
    "\n"
    "Agent: Claude Code"
)

# (name, title, body). Each must reach gh byte for byte, with nothing evaluated.
CASES = [
    ("normal body (control)", "[docs] skills/write-validator/SKILL.md: index off by one", NORMAL_BODY),
    ("body line equal to ISSUE_BODY", "[docs] heredoc", "before\nISSUE_BODY\n$(touch SENTINEL)\nafter"),
    ("body line equal to the delimiter prefix", "[docs] prefix", "before\nCDS_FEEDBACK_\nafter"),
    (
        "command substitution and backticks",
        "[docs] $(touch SENTINEL) and `touch SENTINEL`",
        "run $(touch SENTINEL)\nor `touch SENTINEL`\n$(touch SENTINEL)",
    ),
    ("parameter expansion", "[docs] ${HOME} $HOME", "home is ${HOME}\nand $HOME\n${HOME:-x}"),
    (
        "single and double quotes",
        "[feedback] it's \"quoted\" ''",
        "it's \"fine\"\n'single' \"double\" '\"mixed\"'\n'",
    ),
    (
        "backslashes including a trailing one",
        "[docs] a\\b \\n trailing\\",
        "C:\\path\\to\nline ends in a backslash \\\n\\\\double\n\\$HOME \\`x\\`\n\\",
    ),
    (
        "unicode including non-BMP",
        "[feedback] caf\u00e9 \u2014 \u65e5\u672c \U0001D11E \U00020000",
        "\u00e9\u00e8 \u2014 \u03bb\n\U0001D11E \U00020000\n\u202e reversed",
    ),
    ("CRLF and multiple lines", "[docs] crlf", "line one\r\nline two\r\n\r\nlast\r"),
    ("title with an apostrophe", "[docs] the validator's datum isn't checked", "short body"),
]

# A body line that is the first candidate delimiter plus a NUL. It differs from
# the delimiter, so the collision check keeps that delimiter; bash drops the NUL,
# reads the line as the delimiter and runs the next line as shell.
NUL_SUFFIX = "0123456789ab"
NUL_COLLISION_BODY = "before\nCDS_FEEDBACK_%s\0\n$(touch SENTINEL)\nafter" % NUL_SUFFIX


def nul_suffixes():
    return iter([NUL_SUFFIX, "ba9876543210"])


class SendTemplateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.template = send_template(read_skill())

    def assertSendsExactly(self, template, title, body, suffixes=None):
        result = run_send(template, title, body, suffixes)
        self.assertEqual(problems(result, title, body), [])
        return result

    def test_cases_send_the_draft_byte_for_byte(self):
        for name, title, body in CASES:
            with self.subTest(name):
                self.assertSendsExactly(self.template, title, body)

    def test_delimiter_is_fresh_and_long_enough(self):
        result_a = self.assertSendsExactly(self.template, "[docs] a", "a")
        result_b = self.assertSendsExactly(self.template, "[docs] b", "b")
        for result in (result_a, result_b):
            self.assertRegex(result["delimiter"], r"^CDS_FEEDBACK_[0-9a-f]{12,}$")
        self.assertNotEqual(result_a["delimiter"], result_b["delimiter"])

    def test_delimiter_colliding_with_a_body_line_is_replaced(self):
        first, second = "0123456789ab", "ba9876543210"
        body = "before\nCDS_FEEDBACK_%s\n$(touch SENTINEL)\nafter" % first
        result = self.assertSendsExactly(self.template, "[docs] collide", body, iter([first, second]))
        self.assertEqual(result["delimiter"], "CDS_FEEDBACK_" + second)


class NulRuleTests(unittest.TestCase):
    """A draft with NUL is refused before any shell runs."""

    @classmethod
    def setUpClass(cls):
        cls.template = send_template(read_skill())

    def assertRefusedWithoutShell(self, title, body, suffixes=None):
        with mock.patch.object(subprocess, "run") as run, mock.patch.object(
            tempfile, "mkdtemp"
        ) as mkdtemp:
            with self.assertRaises(DraftRuleError):
                run_send(self.template, title, body, suffixes)
        self.assertFalse(run.called, "a shell ran for a draft containing NUL")
        self.assertFalse(mkdtemp.called, "a sandbox was built for a draft containing NUL")

    def test_nul_in_title_is_refused(self):
        self.assertRefusedWithoutShell("[docs] a\0b", "body")

    def test_nul_in_body_is_refused(self):
        self.assertRefusedWithoutShell("[docs] t", "a\0b")

    def test_nul_after_the_delimiter_is_refused_before_any_shell(self):
        cwd = tempfile.mkdtemp(prefix="give-feedback-nul-")
        try:
            old = os.getcwd()
            os.chdir(cwd)
            try:
                self.assertRefusedWithoutShell("[docs] t", NUL_COLLISION_BODY, nul_suffixes())
            finally:
                os.chdir(old)
            self.assertEqual(os.listdir(cwd), [], "the refused draft created a file")
        finally:
            shutil.rmtree(cwd, ignore_errors=True)


class MutationControlTests(unittest.TestCase):
    """Broken variants of the shipped template; the same checks must catch each."""

    @classmethod
    def setUpClass(cls):
        cls.template = send_template(read_skill())

    def assertCaught(self, template, title, body):
        result = run_send(template, title, body)
        found = problems(result, title, body)
        self.assertNotEqual(found, [], "mutation passed the checks")
        return found

    def test_unquoted_heredoc_delimiter_is_caught(self):
        mutant, n = re.subn(r"<<'([^']+)'", r"<<\1", self.template)
        self.assertEqual(n, 1, "template has no quoted heredoc to unquote")
        found = self.assertCaught(mutant, "[docs] t", "$(touch SENTINEL)\n${HOME}\na\\\nb")
        self.assertTrue(any("evaluated" in p for p in found), found)

    def test_fixed_issue_body_delimiter_is_caught(self):
        word = HEREDOC_RE.search(
            next(l for l in self.template.split("\n") if HEREDOC_RE.search(l))
        ).group(2)
        mutant = self.template.replace(word, "ISSUE_BODY")
        self.assertNotEqual(mutant, self.template)
        found = self.assertCaught(mutant, "[docs] t", "before\nISSUE_BODY\n$(touch SENTINEL)\nafter")
        self.assertTrue(any("evaluated" in p for p in found), found)

    def test_title_in_double_quotes_is_caught(self):
        mutant, n = re.subn(r"--title '([^']*)'", r'--title "\1"', self.template)
        self.assertEqual(n, 1, "template has no single-quoted title to mutate")
        found = self.assertCaught(mutant, "[docs] $(touch SENTINEL) ${HOME}", "body")
        self.assertTrue(any("evaluated" in p for p in found), found)
        self.assertTrue(any(p.startswith("title ") for p in found), found)

    def test_fill_without_the_nul_rule_is_caught(self):
        # Without the refusal, the NUL-suffixed body line passes the exact-line
        # collision check, bash closes the heredoc on it and runs the next line.
        result = run_send(
            self.template, "[docs] t", NUL_COLLISION_BODY, nul_suffixes(),
            filler=fill_without_nul_rule,
        )
        self.assertEqual(result["delimiter"], "CDS_FEEDBACK_" + NUL_SUFFIX)
        found = problems(result, "[docs] t", NUL_COLLISION_BODY)
        self.assertTrue(any("evaluated" in p for p in found), found)
        self.assertTrue(any(p.startswith("stdin ") for p in found), found)
        for title, body in (("[docs] a\0b", "body"), ("[docs] t", "a\0b")):
            with self.subTest(title=title, body=body):
                result = run_send(self.template, title, body, filler=fill_without_nul_rule)
                self.assertNotEqual(problems(result, title, body), [], "NUL reached gh unchanged")


class SkillTextTests(unittest.TestCase):
    """Static checks on the SKILL.md wording.

    The re-show-after-edit rule is behaviour of the agent, not of the shell, so
    it is checked textually only: these tests prove the rule is stated, not
    that an agent follows it.
    """

    @classmethod
    def setUpClass(cls):
        cls.text = read_skill()

    def test_fixed_issue_body_delimiter_is_gone(self):
        self.assertTrue("ISSUE_BODY" not in self.text, "SKILL.md still names ISSUE_BODY")

    def test_apply_and_send_is_gone(self):
        self.assertTrue(
            "apply and send" not in self.text.lower(), "SKILL.md still says 'apply and send'"
        )

    def test_reshow_after_edit_rule_is_stated(self):
        flat = " ".join(self.text.split()).lower()
        for phrase in ("show the complete final draft again", "exactly as last shown"):
            self.assertTrue(phrase in flat, "SKILL.md does not state %r" % phrase)

    def test_nul_rule_is_stated(self):
        flat = " ".join(self.text.split()).lower()
        for phrase in (
            "nul byte (u+0000)",
            "remove any while drafting, never after approval",
            "nul-free body that was shown",
        ):
            self.assertTrue(phrase in flat, "SKILL.md does not state %r" % phrase)

    def test_template_uses_gh_issue_create_with_fixed_repository(self):
        template = send_template(self.text)
        self.assertIn("gh issue create -R " + REPO, template)
        self.assertIn("--body-file -", template)
        self.assertRegex(template, r"--label (%s)\b" % "|".join(sorted(LABELS)))


if __name__ == "__main__":
    unittest.main()
