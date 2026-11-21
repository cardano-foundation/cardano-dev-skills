#!/usr/bin/env python3
"""Minimal stdio MCP server for the packaging proof: one read-only tool, corpus_status.

Newline-delimited JSON-RPC 2.0 on stdin/stdout. Stdout carries only responses; diagnostics go
to stderr. Nothing is computed at startup: the corpus is walked and hashed only when the tool
is called. Throwaway scaffolding at the server's final path; it performs no search.
"""

import hashlib
import json
import os
import sys

# abspath, never realpath: a launch through a symlinked copy of this file must report the plugin
# it was launched for, not the plugin the link points into.
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
VERSION = "0.0.1"
DEFAULT_PROTOCOL = "2025-06-18"
TOOL_NAME = "corpus_status"

TOOL = {
    "name": TOOL_NAME,
    "title": "Corpus status",
    "description": (
        "Report this plugin's root, its bundled documentation corpus (file count, bytes, digest), "
        "its skills and whether SQLite FTS5 is available. Read-only."
    ),
    "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    "annotations": {
        "readOnlyHint": True,
        "destructiveHint": False,
        "idempotentHint": True,
        "openWorldHint": False,
    },
}


def log(message):
    sys.stderr.write("mcp_server: %s\n" % message)
    sys.stderr.flush()


def plugin_name():
    for manifest in (".claude-plugin", ".codex-plugin"):
        path = os.path.join(ROOT, manifest, "plugin.json")
        try:
            with open(path, "rb") as handle:
                name = json.loads(handle.read().decode("utf-8")).get("name")
        except (OSError, ValueError, AttributeError):
            continue
        if isinstance(name, str):
            return name
    return None


def corpus_stats(corpus_root):
    """Count regular files (symlinks not followed) and digest `<relpath>\\t<git-blob-sha1>` lines."""
    if not os.path.isdir(corpus_root):
        return {"corpus_files": 0, "corpus_bytes": 0, "corpus_digest": None,
                "corpus_error": "corpus root is not a directory: %s" % corpus_root}
    errors = []
    lines = []
    total = 0
    for dirpath, _dirnames, filenames in os.walk(corpus_root, onerror=errors.append,
                                                 followlinks=False):
        for filename in filenames:
            path = os.path.join(dirpath, filename)
            if os.path.islink(path) or not os.path.isfile(path):
                continue
            with open(path, "rb") as handle:
                content = handle.read()
            blob = hashlib.sha1(b"blob %d\0" % len(content) + content).hexdigest()
            rel = os.path.relpath(path, corpus_root).replace(os.sep, "/")
            lines.append((rel.encode("utf-8", "surrogateescape"), blob.encode("ascii")))
            total += len(content)
    lines.sort()
    digest = hashlib.sha256(b"".join(rel + b"\t" + blob + b"\n" for rel, blob in lines))
    stats = {"corpus_files": len(lines), "corpus_bytes": total, "corpus_digest": digest.hexdigest()}
    if errors:
        stats["corpus_error"] = "; ".join(str(error) for error in errors)
    return stats


def skill_names():
    skills_root = os.path.join(ROOT, "skills")
    try:
        entries = os.listdir(skills_root)
    except OSError:
        return []
    return sorted(name for name in entries
                  if os.path.isfile(os.path.join(skills_root, name, "SKILL.md")))


def fts5_status():
    try:
        import sqlite3
    except ImportError as error:
        return "unavailable: ImportError: %s" % error
    except Exception as error:  # a broken sqlite3 install must not take the server down
        return "unavailable: %s: %s" % (type(error).__name__, error)
    try:
        connection = sqlite3.connect(":memory:")
        try:
            connection.execute("create virtual table probe using fts5(x)")
        finally:
            connection.close()
    except sqlite3.OperationalError as error:
        return "unavailable: OperationalError: %s" % error
    except Exception as error:
        return "unavailable: %s: %s" % (type(error).__name__, error)
    return "available"


def corpus_status():
    corpus_root = os.path.join(ROOT, "docs", "sources")
    status = {
        "plugin_root": ROOT,
        "plugin_name": plugin_name(),
        "corpus_root": corpus_root,
    }
    status.update(corpus_stats(corpus_root))
    status["skills"] = skill_names()
    status["fts5"] = fts5_status()
    status["python"] = list(sys.version_info[:3])
    status["env"] = {key: os.environ.get(key) for key in ("CLAUDE_PLUGIN_ROOT", "PLUGIN_ROOT")}
    return status


def tool_error(text):
    return {"content": [{"type": "text", "text": text}], "isError": True}


def call_tool(params):
    name = params.get("name") if isinstance(params, dict) else None
    if name != TOOL_NAME:
        return tool_error("unknown tool: %r" % (name,))
    status = corpus_status()
    return {
        "content": [{"type": "text", "text": json.dumps(status, sort_keys=True)}],
        "structuredContent": status,
        "isError": False,
    }


def handle(method, params):
    """Return a result object, or raise MethodNotFound."""
    if method == "initialize":
        requested = params.get("protocolVersion") if isinstance(params, dict) else None
        return {
            "protocolVersion": requested if isinstance(requested, str) else DEFAULT_PROTOCOL,
            "capabilities": {"tools": {"listChanged": False}},
            "serverInfo": {"name": plugin_name() or os.path.basename(ROOT), "version": VERSION},
        }
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": [TOOL]}
    if method == "tools/call":
        return call_tool(params)
    raise MethodNotFound(method)


class MethodNotFound(Exception):
    pass


def respond(message):
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def error(request_id, code, message):
    return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}


def process(line):
    try:
        request = json.loads(line.decode("utf-8"))
    except ValueError as exc:  # JSONDecodeError and UnicodeDecodeError are both ValueError
        return error(None, -32700, "parse error: %s" % exc)
    if not isinstance(request, dict) or not isinstance(request.get("method"), str):
        request_id = request.get("id") if isinstance(request, dict) else None
        return error(request_id, -32600, "invalid request")
    method = request["method"]
    if "id" not in request or method.startswith("notifications/"):
        return None
    request_id = request["id"]
    try:
        result = handle(method, request.get("params"))
    except MethodNotFound:
        return error(request_id, -32601, "method not found: %s" % method)
    except Exception as exc:
        log("internal error in %s: %r" % (method, exc))
        return error(request_id, -32603, "internal error: %s" % exc)
    return {"jsonrpc": "2.0", "id": request_id, "result": result}


def main():
    stdin = sys.stdin.buffer
    while True:
        line = stdin.readline()
        if not line:
            return 0
        if not line.strip():
            continue
        response = process(line)
        if response is not None:
            respond(response)


if __name__ == "__main__":
    sys.exit(main())
