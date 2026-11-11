#!/usr/bin/env python3
"""Retrieval evaluation CLI.

  run.py score <retriever> --set DIR [--k 100] [--out FILE]
  run.py controls --set DIR
  run.py freeze --set DIR [--force]
  run.py compare A.json B.json [--split all|calibration|held_out] [--metric sec@5] [--seed 0]

DIR holds questions.json, labels.json and (once frozen) freeze.json. The corpus
root is --root, else the "corpus_root" of questions.json (relative to DIR), else
the repository root. A question may carry "split": "calibration" or "held_out".
"""
import argparse
import datetime
import hashlib
import json
import os
import sys
import tempfile

if __package__ in (None, ""):
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))

from scripts.kb import corpus, sections as kb_sections  # noqa: E402
from scripts.kb.eval import retrievers, scorer  # noqa: E402

RETRIEVERS = ("grep", "oracle", "random", "removal")
ORACLE_REQUIRED = 1.0
REMOVAL_REQUIRED = 0.0
RANDOM_SEEDS = 100
RANDOM_SLACK_FACTOR = 1.5
RANDOM_SLACK_ABS = 0.005
_TOL = 1e-9


class FreezeError(Exception):
    pass


def sha256_path(path):
    return corpus.sha256_file(path)


def read_set_files(set_dir):
    """Raw bytes of questions.json and labels.json, each read exactly once."""
    out = []
    for name in ("questions.json", "labels.json"):
        with open(os.path.join(set_dir, name), "rb") as handle:
            out.append(handle.read())
    return out


def parse_set(questions_bytes, labels_bytes):
    """(questions, labels_by_id, questions_doc) parsed from the bytes that were hashed."""
    doc = json.loads(questions_bytes.decode("utf-8"))
    labels = json.loads(labels_bytes.decode("utf-8"))["labels"]
    questions = doc["questions"]
    ids = [q["id"] for q in questions]
    if len(set(ids)) != len(ids):
        raise ValueError("duplicate question ids")
    if set(ids) != set(labels):
        raise ValueError("questions and labels must cover the same ids")
    texts = [q["text"] for q in questions]
    if len(set(texts)) != len(texts):
        raise ValueError("duplicate question texts")
    for q in questions:
        if "split" in q and q["split"] not in scorer.SPLITS:
            raise ValueError("question %s: split must be one of %s, got %r"
                             % (q["id"], scorer.SPLITS, q["split"]))
    for label in labels.values():
        scorer.validate_label(label)
    return questions, labels, doc


def hashes_of(questions_bytes, labels_bytes):
    return {
        "questions_sha256": hashlib.sha256(questions_bytes).hexdigest(),
        "labels_sha256": hashlib.sha256(labels_bytes).hexdigest(),
    }


def load_set(set_dir):
    """(questions, labels_by_id, questions_doc) from questions.json and labels.json."""
    return parse_set(*read_set_files(set_dir))


def ground_labels(questions, labels, root):
    """Refuse a label location that does not point into the corpus.

    Every location must name a canonical manifest path exactly as corpus.py lists it,
    the file must be readable text, and end_line must not exceed its line count.
    """
    manifest = set(corpus.file_paths(root))
    line_counts = {}
    problems = []
    for q in questions:
        for g, group in enumerate(labels[q["id"]].get("targets") or []):
            for l, loc in enumerate(group):
                where = "question %s group %d location %d" % (q["id"], g, l)
                path = loc.get("path")
                if not isinstance(path, str) or path not in manifest:
                    problems.append("%s: path %r is not a corpus manifest path" % (where, path))
                    continue
                if path not in line_counts:
                    text = kb_sections.read_text(os.path.join(root, *path.split("/")))
                    line_counts[path] = None if text is None else len(kb_sections.text_lines(text))
                count = line_counts[path]
                if count is None:
                    problems.append("%s: %r is not readable text" % (where, path))
                elif loc["end_line"] > count:
                    problems.append("%s: end_line %d is beyond the %d lines of %r"
                                    % (where, loc["end_line"], count, path))
    if problems:
        raise ValueError("labels are not grounded in the corpus:\n  " + "\n  ".join(problems))


def load_grounded(set_dir, root_override=None):
    """Load a set, resolve its corpus root and ground its labels.

    Returns (questions, labels, doc, root, hashes); the hashes come from the same
    bytes that were parsed.
    """
    questions_bytes, labels_bytes = read_set_files(set_dir)
    questions, labels, doc = parse_set(questions_bytes, labels_bytes)
    root = resolve_root(set_dir, doc, root_override)
    ground_labels(questions, labels, root)
    return questions, labels, doc, root, hashes_of(questions_bytes, labels_bytes)


def resolve_root(set_dir, doc, override=None):
    if override:
        return override
    if doc.get("corpus_root"):
        return os.path.normpath(os.path.join(set_dir, doc["corpus_root"]))
    return corpus.default_root()


def set_hashes(set_dir):
    return hashes_of(*read_set_files(set_dir))


def write_freeze(set_dir, root, force=False, hashes=None):
    target = os.path.join(set_dir, "freeze.json")
    if os.path.exists(target) and not force:
        raise FreezeError("freeze.json already exists; pass --force to replace it")
    record = dict(hashes or set_hashes(set_dir))
    record["corpus_id"] = corpus.corpus_id(root)
    record["frozen_utc"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    record["version"] = 1
    with open(target, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(record, indent=2, sort_keys=True) + "\n")
    return record


def check_freeze(set_dir, current_corpus_id, allow_corpus_mismatch=False, hashes=None):
    """Return the identity dict, or raise FreezeError.

    hashes are the question and label hashes of the bytes already parsed; without
    them the files are read again.
    """
    target = os.path.join(set_dir, "freeze.json")
    if not os.path.exists(target):
        raise FreezeError("freeze.json missing: run `run.py freeze --set %s` first" % set_dir)
    with open(target, encoding="utf-8") as handle:
        frozen = json.load(handle)
    now = hashes or set_hashes(set_dir)
    for key in ("questions_sha256", "labels_sha256"):
        if frozen.get(key) != now[key]:
            raise FreezeError("%s changed since the freeze; refusing to score" % key.split("_")[0])
    mismatch = frozen.get("corpus_id") != current_corpus_id
    if mismatch:
        if not allow_corpus_mismatch:
            raise FreezeError(
                "corpus_id %s differs from the frozen %s; refusing to score"
                % (current_corpus_id, frozen.get("corpus_id"))
            )
        print(
            "WARNING: scoring against a corpus that differs from the frozen one "
            "(frozen %s, current %s)" % (frozen.get("corpus_id"), current_corpus_id),
            file=sys.stderr,
        )
    identity = dict(now)
    identity.update(
        {
            "corpus_id": current_corpus_id,
            "frozen_corpus_id": frozen.get("corpus_id"),
            "corpus_mismatch_allowed": bool(mismatch),
            "scorer_version": scorer.SCORER_VERSION,
        }
    )
    return identity


def labels_by_text(questions, labels):
    return {q["text"]: labels[q["id"]] for q in questions}


def in_corpus_copy(root, build):
    """Run build(copy_root) on a private copy of the corpus at root.

    Returns (build's result, read_hashes): read_hashes maps every file of the copy
    to the sha256 of exactly the bytes build could read. The copy is removed once
    build returns, so build must read everything it needs before then.
    """
    with tempfile.TemporaryDirectory(prefix="kb-eval-corpus-") as copy_root:
        read_hashes = corpus.copy_corpus(root, copy_root)
        return build(copy_root), read_hashes


def make_retriever(name, root, lookup, seed=0):
    if name == "grep":
        return retrievers.grep(root)
    if name == "oracle":
        return retrievers.oracle(lookup)
    if name == "random":
        return retrievers.random_retriever(kb_sections.split_corpus(root)[0], seed)
    if name == "removal":
        return retrievers.removal(retrievers.grep(root), lookup)
    raise ValueError("unknown retriever %r" % name)


def build_retriever(name, root, lookup, seed=0):
    """(retriever, read_hashes) for a retriever built from a private copy of root."""
    if name not in RETRIEVERS:
        raise ValueError("unknown retriever %r" % name)
    return in_corpus_copy(root, lambda copy_root: make_retriever(name, copy_root, lookup, seed))


def evaluate(questions, labels, retriever, k, score_fn=None):
    """Score a retriever. Returns (answerable [(q, metrics, ranking)], negatives [(q, ranking)])."""
    score_fn = score_fn or scorer.score_question
    answerable, negatives = [], []
    for q in questions:
        ranking = retriever.retrieve(q["text"], k)
        label = labels[q["id"]]
        if scorer.is_answerable(label):
            answerable.append((q, score_fn(ranking, label), ranking))
        else:
            negatives.append((q, ranking))
    return answerable, negatives


def assert_corpus_unchanged(root, checked_id):
    """Refuse when the corpus changed between the identity check and now.

    Called after the retriever is built, so a file edited while the index was being
    built cannot slip into a score that claims the checked identity.
    """
    now = corpus.corpus_id(root)
    if now != checked_id:
        raise ValueError("corpus changed while the retriever was being built "
                         "(checked %s, now %s); refusing to score" % (checked_id, now))


def assert_read_matches(manifest, read_hashes):
    """Refuse unless the bytes the retriever read are the files of the checked manifest.

    A file changed and then restored while the retriever was built leaves the
    manifest unchanged, so only the hashes of what was read can catch it.
    """
    expected = {entry["path"]: entry["sha256"] for entry in manifest["files"]}
    if read_hashes == expected:
        return
    problems = []
    for kind, paths in (
        ("changed", sorted(p for p in set(expected) & set(read_hashes) if expected[p] != read_hashes[p])),
        ("missing", sorted(set(expected) - set(read_hashes))),
        ("extra", sorted(set(read_hashes) - set(expected))),
    ):
        if paths:
            problems.append("%s: %s" % (kind, ", ".join(paths)))
    raise ValueError("the retriever read a corpus that differs from the checked manifest (%s); "
                     "refusing to score" % "; ".join(problems))


def cmd_score(args):
    questions, labels, doc, root, hashes = load_grounded(args.set, args.root)
    manifest = corpus.build_manifest(root)
    checked_id = manifest["corpus_id"]
    identity = check_freeze(args.set, checked_id, args.allow_corpus_mismatch, hashes)
    retriever, read_hashes = build_retriever(args.retriever, root, labels_by_text(questions, labels), args.seed)
    assert_corpus_unchanged(root, checked_id)
    assert_read_matches(manifest, read_hashes)
    answerable, negatives = evaluate(questions, labels, retriever, args.k)
    by_split, by_split_slice = scorer.aggregate_by_split(
        [(q.get("split"), q.get("slice", ""), m) for q, m, _r in answerable])
    result = {
        "identity": identity,
        "retriever": args.retriever,
        "seed": args.seed if args.retriever == "random" else None,
        "k": args.k,
        "per_question": [
            {
                "id": q["id"],
                "slice": q.get("slice", ""),
                "split": q.get("split"),
                "grade": labels[q["id"]]["grade"],
                "metrics": metrics,
                "top10": ranking[:10],
            }
            for q, metrics, ranking in answerable
        ],
        "aggregate": scorer.aggregate([m for _q, m, _r in answerable]),
        "by_slice": scorer.aggregate_by_slice([(q.get("slice", ""), m) for q, m, _r in answerable]),
        "by_split": by_split,
        "by_split_slice": by_split_slice,
        "negatives": scorer.negatives_report([(q["id"], r) for q, r in negatives]),
    }
    text = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.out:
        with open(args.out, "w", encoding="utf-8") as handle:
            handle.write(text)
    else:
        sys.stdout.write(text)
    return 0


def expected_chance(questions, labels, sections, k):
    """Analytic upper bound on random sec@k: mean over answerable questions of the
    probability that the least likely target group is hit by k random sections."""
    total = len(sections)
    values = []
    for q in questions:
        label = labels[q["id"]]
        if not scorer.is_answerable(label):
            continue
        worst = 1.0
        for group in label["targets"]:
            matching = sum(1 for s in sections if any(
                scorer.hits({"path": s.path, "start_line": s.start_line, "end_line": s.end_line}, loc)
                for loc in group))
            miss = 1.0
            for i in range(min(k, total)):
                miss *= max(total - matching - i, 0) / (total - i)
            worst = min(worst, 1.0 - miss)
        values.append(worst)
    return sum(values) / len(values) if values else 0.0


def run_controls(set_dir, root=None, score_fn=None, oracle=None, random_=None,
                 removal=None, out=None):
    """Run the oracle, random and removal controls. Returns True when all pass.

    The random control is the mean sec@5 over seeds 0..RANDOM_SEEDS-1, so it is
    meaningful however few answerable questions the set has. It passes when the mean
    is at most RANDOM_SLACK_FACTOR * expected_chance + RANDOM_SLACK_ABS.

    score_fn, oracle(lookup), random_(sections, seed) and removal(base, lookup)
    replace the real parts; the mutation tests use them to prove the controls fail
    when the instrument is broken.
    """
    out = out or sys.stdout
    questions, labels, _doc, root, _hashes = load_grounded(set_dir, root)
    manifest = corpus.build_manifest(root)
    lookup = labels_by_text(questions, labels)
    makers = {
        "oracle": oracle or retrievers.oracle,
        "random": random_ or retrievers.random_retriever,
        "removal": removal or retrievers.removal,
    }
    (sections, base), read_hashes = in_corpus_copy(
        root, lambda copy_root: (kb_sections.split_corpus(copy_root)[0], retrievers.grep(copy_root)))
    assert_corpus_unchanged(root, manifest["corpus_id"])
    assert_read_matches(manifest, read_hashes)

    def sec5_of(retriever):
        answerable, _neg = evaluate(questions, labels, retriever, 100, score_fn)
        return scorer.aggregate([m for _q, m, _r in answerable])["sec@5"] if answerable else None

    sec5 = {
        "oracle": sec5_of(makers["oracle"](lookup)),
        "removal": sec5_of(makers["removal"](base, lookup)),
    }
    seeded = [sec5_of(makers["random"](sections, seed)) for seed in range(RANDOM_SEEDS)]
    mean = None if any(v is None for v in seeded) else sum(seeded) / len(seeded)
    chance = expected_chance(questions, labels, sections, 5)
    threshold = RANDOM_SLACK_FACTOR * chance + RANDOM_SLACK_ABS
    checks = [
        ("oracle sec@5 == %.1f" % ORACLE_REQUIRED, sec5["oracle"],
         sec5["oracle"] is not None and abs(sec5["oracle"] - ORACLE_REQUIRED) <= _TOL),
        ("removal sec@5 == %.1f" % REMOVAL_REQUIRED, sec5["removal"],
         sec5["removal"] is not None and abs(sec5["removal"] - REMOVAL_REQUIRED) <= _TOL),
        ("random mean sec@5 over seeds 0..%d <= %.4f" % (RANDOM_SEEDS - 1, threshold), mean,
         mean is not None and mean <= threshold + _TOL),
    ]
    ok = True
    for label, value, passed in checks:
        ok = ok and passed
        shown = "n/a" if value is None else "%.4f" % value
        print("%s %s (got %s)" % ("PASS" if passed else "FAIL", label, shown), file=out)
    print("info random: measured mean %s, analytic expected chance %.4f, threshold %.4f "
          "(%.1f * chance + %.3f) over %d sections"
          % ("n/a" if mean is None else "%.4f" % mean, chance, threshold,
             RANDOM_SLACK_FACTOR, RANDOM_SLACK_ABS, len(sections)), file=out)
    print("controls: %s" % ("PASS" if ok else "FAIL"), file=out)
    return ok


def cmd_controls(args):
    return 0 if run_controls(args.set, args.root) else 1


def cmd_freeze(args):
    _q, _l, _doc, root, hashes = load_grounded(args.set, args.root)
    record = write_freeze(args.set, root, args.force, hashes)
    print("froze %s (corpus_id %s)" % (args.set, record["corpus_id"]))
    return 0


IDENTITY_KEYS = ("questions_sha256", "labels_sha256", "corpus_id", "scorer_version")
COMPARE_SPLITS = ("all",) + scorer.SPLITS


def compare_results(result_a, result_b, split="all", metric="sec@5", seed=0):
    """Paired bootstrap of B - A over the answerable questions of a split.

    Refuses unless both results were scored on the same evaluation identity and
    neither overrode the corpus mismatch check.
    """
    if metric not in scorer.METRICS:
        raise ValueError("unknown metric %r; choose one of %s" % (metric, ", ".join(scorer.METRICS)))
    ids = {}
    for name, result in (("A", result_a), ("B", result_b)):
        identity = result.get("identity") or {}
        if identity.get("corpus_mismatch_allowed"):
            raise ValueError("%s recorded a corpus mismatch override; refusing to compare" % name)
        ids[name] = identity
    for key in IDENTITY_KEYS:
        if ids["A"].get(key) is None or ids["A"].get(key) != ids["B"].get(key):
            raise ValueError("evaluation identity differs on %s (A %s, B %s); refusing to compare"
                             % (key, ids["A"].get(key), ids["B"].get(key)))
    if result_a.get("k") != result_b.get("k"):
        raise ValueError("k differs (A %s, B %s); refusing to compare" % (result_a.get("k"), result_b.get("k")))

    def values(result):
        return {r["id"]: r["metrics"][metric] for r in result["per_question"]
                if split == "all" or r.get("split") == split}

    a, b = values(result_a), values(result_b)
    if set(a) != set(b):
        raise ValueError("A and B scored different questions in split %s" % split)
    if not a:
        raise ValueError("no answerable questions in split %s" % split)
    order = sorted(a)
    out = scorer.paired_bootstrap([b[i] for i in order], [a[i] for i in order], seed=seed)
    out.update({"metric": metric, "split": split, "retriever_a": result_a.get("retriever"),
                "retriever_b": result_b.get("retriever"), "identity": ids["A"], "direction": "B - A"})
    return out


def cmd_compare(args):
    results = []
    for path in (args.a, args.b):
        with open(path, encoding="utf-8") as handle:
            results.append(json.load(handle))
    out = compare_results(results[0], results[1], args.split, args.metric, args.seed)
    print("%s %s on %s (n=%d): B - A mean %+.4f, 95%% CI [%+.4f, %+.4f], wins %d losses %d ties %d"
          % (out["retriever_b"], out["metric"], out["split"], out["n"], out["mean_diff"],
             out["ci_low"], out["ci_high"], out["wins"], out["losses"], out["ties"]), file=sys.stderr)
    sys.stdout.write(json.dumps(out, indent=2, sort_keys=True) + "\n")
    return 0


def build_parser():
    parser = argparse.ArgumentParser(description="Retrieval evaluation harness.")
    sub = parser.add_subparsers(dest="command", required=True)

    def common(p):
        p.add_argument("--set", required=True, help="directory with questions.json and labels.json")
        p.add_argument("--root", help="directory containing docs/sources")
        p.add_argument("--seed", type=int, default=0, help="seed for the random retriever (score only; controls average seeds 0..99)")

    score = sub.add_parser("score", help="score a retriever on a frozen set")
    score.add_argument("retriever", choices=RETRIEVERS)
    common(score)
    score.add_argument("--k", type=int, default=100)
    score.add_argument("--out", help="write the JSON result here instead of stdout")
    score.add_argument("--allow-corpus-mismatch", action="store_true",
                       help="score even though the corpus differs from the frozen one (recorded)")
    score.set_defaults(func=cmd_score)

    controls = sub.add_parser("controls", help="run oracle, random and removal controls")
    common(controls)
    controls.set_defaults(func=cmd_controls)

    freeze = sub.add_parser("freeze", help="write freeze.json for a set")
    common(freeze)
    freeze.add_argument("--force", action="store_true", help="replace an existing freeze.json")
    freeze.set_defaults(func=cmd_freeze)

    compare = sub.add_parser("compare", help="paired bootstrap of B - A from two score outputs")
    compare.add_argument("a", help="score output of the baseline retriever")
    compare.add_argument("b", help="score output of the retriever under test")
    compare.add_argument("--split", choices=COMPARE_SPLITS, default="all")
    compare.add_argument("--metric", default="sec@5")
    compare.add_argument("--seed", type=int, default=0, help="bootstrap seed")
    compare.set_defaults(func=cmd_compare)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except (FreezeError, FileNotFoundError, ValueError, KeyError) as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
