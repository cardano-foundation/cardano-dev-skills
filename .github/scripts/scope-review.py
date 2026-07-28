#!/usr/bin/env python3
"""Run the advisory AI scope review as a single, non-agentic Gemini call.

Reads the rubric (system prompt) and the pre-built review context, sends one
generateContent request, and writes the model's markdown review to
RESPONSE_FILE. Deliberately not an agent: no tools, no repo access, no shell
— this runs on a pull_request_target workflow with a write-capable token, so
the model only ever transforms pre-collected text into a review comment.

If the pinned model returns the "no longer available" 404 (Google retires
model ids faster than anyone updates pins), the script queries ListModels
and retries once with the newest stable flash model that supports
generateContent, logging the substitution.

Env:
  GEMINI_API_KEY      required — Google AI Studio key (free tier is fine)
  GEMINI_MODEL        model id (default: gemini-3.5-flash)
  GEMINI_API_URL      endpoint override, for tests
  SYSTEM_PROMPT_FILE  path to the rubric
  PROMPT_FILE         path to the review context
  RESPONSE_FILE       where to write the review markdown
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

RETRIES = 3
RETRY_DELAY_SECONDS = 30  # free tier is per-minute rate-limited


def read(path_env: str) -> str:
    with open(os.environ[path_env], encoding="utf-8") as fh:
        return fh.read()


def api_get(url: str, api_key: str) -> dict | None:
    req = urllib.request.Request(url, headers={"x-goog-api-key": api_key})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.load(resp)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        return None


def find_replacement_model(base_url: str, api_key: str) -> str | None:
    """Pick the newest stable flash text model from ListModels."""
    data = api_get(f"{base_url}?pageSize=1000", api_key)
    if not isinstance(data, dict):
        return None
    stable = re.compile(r"^models/(gemini-[0-9]+(?:\.[0-9]+)?-flash)$")
    candidates = []
    for m in data.get("models", []):
        if "generateContent" not in m.get("supportedGenerationMethods", []):
            continue
        match = stable.match(m.get("name", ""))
        if match:
            candidates.append(match.group(1))
    # "gemini-3.5-flash" > "gemini-3.1-flash": version-sort on the numbers
    candidates.sort(
        key=lambda n: [float(x) for x in re.findall(r"[0-9]+(?:\.[0-9]+)?", n)])
    return candidates[-1] if candidates else None


def main() -> int:
    api_key = os.environ["GEMINI_API_KEY"]
    model = os.environ.get("GEMINI_MODEL", "gemini-3.5-flash")
    url_template = os.environ.get(
        "GEMINI_API_URL",
        "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
    )
    url = url_template.replace("{model}", model)
    base_url = url.split("/models")[0] + "/models"

    body = json.dumps({
        "system_instruction": {"parts": [{"text": read("SYSTEM_PROMPT_FILE")}]},
        "contents": [{"role": "user",
                      "parts": [{"text": read("PROMPT_FILE")}]}],
        "generationConfig": {
            "maxOutputTokens": 8000,
            "temperature": 0.2,
        },
    }).encode()

    data = None
    model_swapped = False
    for attempt in range(1, RETRIES + 1):
        req = urllib.request.Request(
            url, data=body,
            headers={"Content-Type": "application/json",
                     "x-goog-api-key": api_key})
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.load(resp)
            break
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")[:1000]
            print(f"attempt {attempt}: HTTP {exc.code}: {detail}",
                  file=sys.stderr)
            if exc.code == 404 and not model_swapped:
                # Pinned model retired — ask the API what exists now.
                replacement = find_replacement_model(base_url, api_key)
                if replacement and replacement != model:
                    print(f"model '{model}' unavailable; retrying with "
                          f"'{replacement}'", file=sys.stderr)
                    model, model_swapped = replacement, True
                    url = url_template.replace("{model}", model)
                    continue
                return 1
            if exc.code not in (429, 500, 503) or attempt == RETRIES:
                return 1
        except (urllib.error.URLError, TimeoutError) as exc:
            print(f"attempt {attempt}: {exc}", file=sys.stderr)
            if attempt == RETRIES:
                return 1
        time.sleep(RETRY_DELAY_SECONDS)

    try:
        text = data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError, TypeError):
        print("unexpected response shape:", file=sys.stderr)
        print(json.dumps(data)[:2000], file=sys.stderr)
        return 1

    with open(os.environ["RESPONSE_FILE"], "w", encoding="utf-8") as fh:
        fh.write(text)
    print(f"review written ({len(text)} chars)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
