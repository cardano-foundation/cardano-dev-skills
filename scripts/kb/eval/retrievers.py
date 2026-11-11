"""Retrievers for the evaluation harness.

Interface: retrieve(question_text, k) -> list of records, best first. A record is
{"path", "start_line", "end_line"} and may carry a "score".

grep      lowercase term-overlap baseline over corpus sections
oracle    label locations, one hitting location per AND group first
random    seeded shuffle of all sections (the chance floor)
removal   a base ranking with every label-hitting record removed
"""
import random
import re

from scripts.kb import sections as kb_sections
from scripts.kb.eval import scorer

STOPWORDS = frozenset(
    "a an and are as at be by can do does for from how i if in is it of on or "
    "that the this to was what when where which who why will with you your".split()
)
_TOKEN_RE = re.compile(r"[a-z0-9_]+")


def tokenize(text):
    return _TOKEN_RE.findall(text.lower())


def _record(section, score=None):
    rec = {"path": section.path, "start_line": section.start_line, "end_line": section.end_line}
    if score is not None:
        rec["score"] = round(score, 4)
    return rec


class GrepRetriever:
    """Rank sections by distinct query terms present, then total occurrences,
    then path and start line for determinism. Sections with no query term are
    never returned. score = fraction of distinct query terms present."""

    def __init__(self, root=None):
        self.sections = []
        self.index = {}
        for section, text in kb_sections.iter_corpus_sections(root):
            number = len(self.sections)
            self.sections.append(section)
            counts = {}
            for token in tokenize(text):
                counts[token] = counts.get(token, 0) + 1
            for token, count in counts.items():
                self.index.setdefault(token, []).append((number, count))

    def retrieve(self, question_text, k):
        terms = sorted({t for t in tokenize(question_text) if t not in STOPWORDS})
        distinct = {}
        total = {}
        for term in terms:
            for number, count in self.index.get(term, ()):
                distinct[number] = distinct.get(number, 0) + 1
                total[number] = total.get(number, 0) + count
        ranked = sorted(
            distinct,
            key=lambda n: (
                -distinct[n],
                -total[n],
                self.sections[n].path,
                self.sections[n].start_line,
            ),
        )
        return [_record(self.sections[n], distinct[n] / len(terms)) for n in ranked[:k]]


class OracleRetriever:
    """labels_by_text maps question text to its label."""

    def __init__(self, labels_by_text):
        self.labels = labels_by_text

    def retrieve(self, question_text, k):
        label = self.labels[question_text]
        if not scorer.is_answerable(label):
            return []
        ranking, seen = [], []
        for group in label["targets"]:
            ranking.append(_loc_record(group[0]))
            seen.append(group[0])
        for group in label["targets"]:
            for loc in group:
                if not any(loc is s for s in seen):
                    ranking.append(_loc_record(loc))
                    seen.append(loc)
        return ranking[:k]


def _loc_record(loc):
    return {"path": loc["path"], "start_line": loc["start_line"], "end_line": loc["end_line"]}


class RandomRetriever:
    """Seeded per question text: the same (seed, text) always gives the same ranking."""

    def __init__(self, sections, seed=0):
        self.sections = list(sections)
        self.seed = seed

    def retrieve(self, question_text, k):
        rng = random.Random("%s:%s" % (self.seed, question_text))
        picked = rng.sample(self.sections, min(k, len(self.sections)))
        return [_record(s) for s in picked]


class RemovalRetriever:
    """base ranking minus every record that hits any location of the question's label."""

    def __init__(self, base, labels_by_text):
        self.base = base
        self.labels = labels_by_text

    def retrieve(self, question_text, k):
        label = self.labels[question_text]
        locations = [loc for group in label.get("targets") or [] for loc in group]
        ranking = self.base.retrieve(question_text, k)
        return [r for r in ranking if not any(scorer.hits(r, loc) for loc in locations)]


def grep(root=None):
    return GrepRetriever(root)


def oracle(labels_by_text):
    return OracleRetriever(labels_by_text)


def random_retriever(sections, seed=0):
    return RandomRetriever(sections, seed)


def removal(base, labels_by_text):
    return RemovalRetriever(base, labels_by_text)
