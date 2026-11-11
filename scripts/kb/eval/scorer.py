"""Location-based scorer for retrieval evaluation.

A location is {"path", "start_line", "end_line"} (1-based inclusive). A retrieved
record hits a label location when the paths are equal and the line ranges overlap.

A label is {"grade": "full"|"partial"|"none", "targets": [group, ...]}. Groups are
ANDed; each group is a list of alternative locations (OR). Grade "none" marks a
negative question: it has no targets and is excluded from answerable metrics.
"""
import random

SCORER_VERSION = "kb-eval-scorer/1"
ANSWERABLE_GRADES = ("full", "partial")
ALL_GRADES = ANSWERABLE_GRADES + ("none",)
METRICS = ("sec@5", "sec@10", "cov@5", "cov@10", "mrr", "file@5", "file@10")
BOOTSTRAP_RESAMPLES = 10000
_EPS = 1e-12


def is_answerable(label):
    return label["grade"] in ANSWERABLE_GRADES


def hits(record, location):
    return (
        record["path"] == location["path"]
        and record["start_line"] <= location["end_line"]
        and location["start_line"] <= record["end_line"]
    )


def validate_label(label):
    grade = label.get("grade")
    if grade not in ALL_GRADES:
        raise ValueError("grade must be one of %s, got %r" % (ALL_GRADES, grade))
    targets = label.get("targets") or []
    if grade == "none":
        if targets:
            raise ValueError("a negative (grade none) must have no targets")
        return
    if not targets:
        raise ValueError("an answerable label needs at least one target group")
    for group in targets:
        if not group:
            raise ValueError("a target group must hold at least one location")
        for loc in group:
            if loc["start_line"] > loc["end_line"] or loc["start_line"] < 1:
                raise ValueError("bad line range in %r" % (loc,))


def first_hit_rank(group, ranking):
    """1-based rank of the first record hitting any location of the group, or None."""
    for rank, record in enumerate(ranking, start=1):
        if any(hits(record, loc) for loc in group):
            return rank
    return None


def score_question(ranking, label):
    """Per-question metrics for an answerable label."""
    validate_label(label)
    if not is_answerable(label):
        raise ValueError("score_question needs an answerable label")
    groups = label["targets"]
    ranks = [first_hit_rank(group, ranking) for group in groups]
    first_paths = []
    for record in ranking:
        if record["path"] not in first_paths:
            first_paths.append(record["path"])
    result = {}
    for k in (5, 10):
        got = [rank is not None and rank <= k for rank in ranks]
        result["sec@%d" % k] = 1.0 if all(got) else 0.0
        result["cov@%d" % k] = sum(got) / len(groups)
        paths = set(first_paths[:k])
        covered = [any(loc["path"] in paths for loc in group) for group in groups]
        result["file@%d" % k] = 1.0 if all(covered) else 0.0
    found = [rank for rank in ranks if rank is not None]
    result["mrr"] = 1.0 / min(found) if found else 0.0
    return result


def aggregate(scores):
    """Mean of each metric over a list of per-question metric dicts."""
    out = {"n": len(scores)}
    for name in METRICS:
        out[name] = round(sum(s[name] for s in scores) / len(scores), 6) if scores else None
    return out


def aggregate_by_slice(items):
    """items: list of (slice_name, metrics). Returns {slice: aggregate}."""
    grouped = {}
    for name, metrics in items:
        grouped.setdefault(name, []).append(metrics)
    return {name: aggregate(grouped[name]) for name in sorted(grouped)}


def negatives_report(items):
    """items: list of (question_id, ranking). Only the top score is reported."""
    top = {}
    for qid, ranking in items:
        top[qid] = ranking[0].get("score") if ranking else None
    scored = [v for v in top.values() if v is not None]
    return {
        "n": len(items),
        "top_scores": {qid: top[qid] for qid in sorted(top)},
        "mean_top_score": round(sum(scored) / len(scored), 6) if scored else None,
    }


def paired_bootstrap(a, b, seed=0, resamples=BOOTSTRAP_RESAMPLES):
    """Paired bootstrap of mean(a) - mean(b) over aligned per-question values.

    Seeded and deterministic; 95% percentile CI; wins/losses/ties count questions
    where a is higher, lower or equal.
    """
    if len(a) != len(b):
        raise ValueError("paired samples must be the same length")
    if not a:
        raise ValueError("paired samples must not be empty")
    diffs = [x - y for x, y in zip(a, b)]
    n = len(diffs)
    rng = random.Random(seed)
    means = sorted(sum(rng.choices(diffs, k=n)) / n for _ in range(resamples))
    return {
        "n": n,
        "mean_diff": round(sum(diffs) / n, 6),
        "ci_low": round(means[int(0.025 * resamples)], 6),
        "ci_high": round(means[int(0.975 * resamples) - 1], 6),
        "wins": sum(1 for d in diffs if d > _EPS),
        "losses": sum(1 for d in diffs if d < -_EPS),
        "ties": sum(1 for d in diffs if abs(d) <= _EPS),
        "resamples": resamples,
        "seed": seed,
    }
