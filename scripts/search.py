#!/usr/bin/env python3
"""
search.py — Portable wrapper for collective memory search.

Discovers the collective-memory data store by:
  1. COLLECTIVE_MEMORY_DIR env var (explicit override)
  2. Walking up from this script's location looking for memory.db
  3. Common default paths based on HOME / OPENCLAW_WORKSPACE

This script lives inside the skill folder so it ships with the skill —
no hardcoded absolute paths anywhere.
"""
import os
import sys
import json
import sqlite3
import math
import subprocess
from pathlib import Path


def _find_data_dir() -> Path | None:
    """Locate the collective-memory data directory portably."""
    # 1. Explicit env override
    env_path = os.environ.get("COLLECTIVE_MEMORY_DIR", "")
    if env_path and Path(env_path).is_dir():
        return Path(env_path)

    # 2. Walk up from this file looking for memory.db
    current = Path(__file__).resolve().parent
    for _ in range(8):
        candidate = current / "memory.db"
        if candidate.exists():
            return current
        # Also check collective-memory/ subfolder at each level
        for sub in ("collective-memory", "collective_memory"):
            if (current / sub / "memory.db").exists():
                return current / sub
        current = current.parent

    # 3. Common default locations
    openclaw_workspace = Path(os.environ.get("OPENCLAW_WORKSPACE", str(Path.home() / ".openclaw" / "workspace")))
    defaults = [
        openclaw_workspace / "collective-memory",
        openclaw_workspace / "memory" / "collective-memory",
        Path.home() / "workspace" / "collective-memory",
    ]
    for d in defaults:
        if (d / "memory.db").exists():
            return d

    return None


DATA_DIR = _find_data_dir()
DB_PATH = DATA_DIR / "memory.db" if DATA_DIR else None
EMBED_URL = os.environ.get("COLLECTIVE_EMBED_URL", "http://localhost:8770/embeddings")
API_URL = os.environ.get("COLLECTIVE_MEMORY_API_URL", "http://localhost:8010")
DEFAULT_TOP_K = 3


def cosine(a: list, b: list) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    mag_a = math.sqrt(sum(x * x for x in a))
    mag_b = math.sqrt(sum(x * x for x in b))
    if mag_a == 0 or mag_b == 0:
        return 0.0
    return dot / (mag_a * mag_b)


def embed(text: str) -> list[float] | None:
    # 1. Try HTTP embedding server
    try:
        import requests as _req
        r = _req.post(EMBED_URL, json={"input": text}, timeout=5)
        d = r.json()
        vec = d.get("data", [None])[0]
        if vec:
            return vec
    except Exception:
        pass

    # 2. Fallback: native SentenceTransformer in-process
    try:
        _model_name = os.environ.get(
            "COLLECTIVE_EMBED_MODEL",
            "sentence-transformers/all-MiniLM-L6-v2"
        )
        from sentence_transformers import SentenceTransformer
        _st = SentenceTransformer(_model_name)
        return _st.encode(text).tolist()
    except Exception as e:
        print(f"[search] embed error: {e}", file=sys.stderr)
        return None


def _search_api(query: str, top_k: int = DEFAULT_TOP_K) -> list[dict]:
    """Try shared network API first (multi-agent). Returns [] on any failure."""
    try:
        import requests as _req
        r = _req.get(
            f"{API_URL}/memory/search",
            params={"q": query, "top_k": top_k},
            timeout=10,
        )
        if r.status_code != 200:
            return []

        data = r.json()
        out = []
        for item in data:
            out.append({
                "score": round(float(item.get("score", 0.0)), 4),
                "id": item.get("id"),
                "filename": item.get("key", ""),
                "date": (item.get("created_at", "") or "")[:10],
                "agent": item.get("agent", "unknown"),
                "topic": (item.get("metadata", {}) or {}).get("legacy_topic", "network"),
                "tags": ((item.get("metadata", {}) or {}).get("legacy_tags", "")),
                "title": (item.get("metadata", {}) or {}).get("legacy_title", item.get("key", "memory")),
                "body": (item.get("content_text", "") or "")[:300] + ("..." if len(item.get("content_text", "") or "") > 300 else ""),
            })
        return out
    except Exception:
        return []


def search(query: str, top_k: int = DEFAULT_TOP_K) -> list[dict]:
    # 1) Preferred path: shared multi-agent API
    api_results = _search_api(query, top_k)
    if api_results:
        return api_results

    # 2) Fallback: local legacy sqlite memory
    if not DB_PATH or not DB_PATH.exists():
        return []

    q_vec = embed(query)
    if q_vec is None:
        return []

    db = sqlite3.connect(str(DB_PATH))
    rows = db.execute(
        "SELECT id, filename, date, agent, topic, tags, title, body, embedding FROM entries"
    ).fetchall()
    db.close()

    scored = []
    for row in rows:
        try:
            e_vec = json.loads(row[8])
            score = cosine(q_vec, e_vec)
            scored.append({
                "score": round(score, 4),
                "id": row[0],
                "filename": row[1],
                "date": row[2],
                "agent": row[3],
                "topic": row[4],
                "tags": row[5],
                "title": row[6],
                "body": row[7][:300] + ("..." if len(row[7]) > 300 else ""),
            })
        except Exception:
            continue

    scored.sort(key=lambda x: x["score"], reverse=True)
    return scored[:top_k]


def format_results(results: list[dict]) -> str:
    if not results:
        return ""
    lines = [f"🧠 Collective Memory — top {len(results)} results:\n"]
    for i, r in enumerate(results, 1):
        lines.append(f"**{i}. {r['title']}** (score: {r['score']})")
        lines.append(f"   📅 {r['date']} · 🤖 {r['agent']} · 🏷 {r['topic']}")
        lines.append(f"   {r['body']}\n")
    return "\n".join(lines)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print("Usage: python3 search.py <query> [--top N] [--json]")
        sys.exit(1)

    query = " ".join(args)
    top_k = DEFAULT_TOP_K
    if "--top" in sys.argv:
        try:
            top_k = int(sys.argv[sys.argv.index("--top") + 1])
        except (ValueError, IndexError):
            pass
    as_json = "--json" in sys.argv

    results = search(query, top_k)

    if as_json:
        print(json.dumps(results, indent=2))
    else:
        print(format_results(results))
