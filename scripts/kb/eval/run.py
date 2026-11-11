#!/usr/bin/env python3
"""Retrieval evaluation CLI.

  run.py score <retriever> --set DIR [--k 100] [--out FILE]
  run.py controls --set DIR
  run.py freeze --set DIR [--force]

DIR holds questions.json, labels.json and (once frozen) freeze.json. The corpus
root is --root, else the "corpus_root" of questions.json (relative to DIR), else
the repository root.
"""
import argparse
import datetime
import hashlib
import json
import os
import sys

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


def load_set(set_dir):
    """(questions, labels_by_id, questions_doc) from questions.json and labels.json."""
    with open(os.path.join(set_dir, "questions.json"), encoding="utf-8") as handle:
        doc = json.load(handle)
    with open(os.path.join(set_dir, "labels.json"), encoding="utf-8") as handle:
        labels = json.load(handle)["labels"]
    questions = doc["questions"]
    ids = [q["id"] for q in questions]
    if len(set(ids)) != len(ids):
        raise ValueError("duplicate question ids")
    if set(ids) != set(labels):
        raise ValueError("questions and labels must cover the same ids")
    texts = [q["text"] for q in questions]
    if len(set(texts)) != len(texts):
        raise ValueError("duplicate question texts")
    for label in labels.values():
        scorer.validate_label(label)
    return questions, labels, doc


def resolve_root(set_dir, doc, override=None):
    if override:
        return override
    if doc.get("corpus_root"):
        return os.path.normpath(os.path.join(set_dir, doc["corpus_root"]))
    return corpus.default_root()


def set_hashes(set_dir):
    return {
        "questions_sha256": sha256_path(os.path.join(set_dir, "questions.json")),
        "labels_sha256": sha256_path(os.path.join(set_dir, "labels.json")),
    }


def write_freeze(set_dir, root, force=False):
    target = os.path.join(set_dir, "freeze.json")
    if os.path.exists(target) and not force:
        raise FreezeError("freeze.json already exists; pass --force to replace it")
    record = dict(set_hashes(set_dir))
    record["corpus_id"] = corpus.corpus_id(root)
    record["frozen_utc"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    record["version"] = 1
    with open(target, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(record, indent=2, sort_keys=True) + "\n")
    return record


def check_freeze(set_dir, current_corpus_id, allow_corpus_mismatch=False):
    """Return the identity dict, or raise FreezeError."""
    target = os.path.join(set_dir, "freeze.json")
    if not os.path.exists(target):
        raise FreezeError("freeze.json missing: run `run.py freeze --set %s` first" % set_dir)
    with open(target, encoding="utf-8") as handle:
        frozen = json.load(handle)
    now = set_hashes(set_dir)
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


def build_retriever(name, root, lookup, seed=0):
    if name == "grep":
        return retrievers.grep(root)
    if name == "oracle":
        return retrievers.oracle(lookup)
    if name == "random":
        return retrievers.random_retriever(kb_sections.split_corpus(root)[0], seed)
    if name == "removal":
        return retrievers.removal(retrievers.grep(root), lookup)
    raise ValueError("unknown retriever %r" % name)


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


def cmd_score(args):
    questions, labels, doc = load_set(args.set)
    root = resolve_root(args.set, doc, args.root)
    identity = check_freeze(args.set, corpus.corpus_id(root), args.allow_corpus_mismatch)
    retriever = build_retriever(args.retriever, root, labels_by_text(questions, labels), args.seed)
    answerable, negatives = evaluate(questions, labels, retriever, args.k)
    result = {
        "identity": identity,
        "retriever": args.retriever,
        "seed": args.seed if args.retriever == "random" else None,
        "k": args.k,
        "per_question": [
            {
                "id": q["id"],
                "slice": q.get("slice", ""),
                "grade": labels[q["id"]]["grade"],
                "metrics": metrics,
                "top10": ranking[:10],
            }
            for q, metrics, ranking in answerable
        ],
        "aggregate": scorer.aggregate([m for _q, m, _r in answerable]),
        "by_slice": scorer.aggregate_by_slice([(q.get("slice", ""), m) for q, m, _r in answerable]),
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
    questions, labels, doc = load_set(set_dir)
    root = resolve_root(set_dir, doc, root)
    lookup = labels_by_text(questions, labels)
    sections, _skipped = kb_sections.split_corpus(root)
    makers = {
        "oracle": oracle or retrievers.oracle,
        "random": random_ or retrievers.random_retriever,
        "removal": removal or retrievers.removal,
    }
    base = retrievers.grep(root)

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
    questions, labels, doc = load_set(args.set)
    record = write_freeze(args.set, resolve_root(args.set, doc, args.root), args.force)
    print("froze %s (corpus_id %s)" % (args.set, record["corpus_id"]))
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
