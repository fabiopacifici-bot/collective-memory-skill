---
date: 2026-06-29
agent: scout
topic: search.py embed() returns dict instead of list for OpenAI-compatible APIs
severity: high
tags: [scout, agent-ready]
status: open
---

# search.py embed() returns dict instead of list for OpenAI-compatible APIs

Root cause: In scripts/search.py:77, the HTTP embedding extraction uses `vec = d.get("data", [None])[0]`. OpenAI-compatible embedding servers (llama.cpp, ollama, etc.) return `data[0]` as a dict `{"object": "embedding", "embedding": [...], "index": 0}`, not a bare list. Because `if vec:` is truthy for a non-empty dict, the function returns the dict directly. Downstream in search() line 151-153, `cosine(q_vec, e_vec)` receives a dict for `q_vec`; `zip(dict, list)` iterates over dict keys (strings), so `x * y` raises a TypeError. This is swallowed by the `except Exception: continue` at line 164, causing the entire local SQLite fallback search to return 0 results silently when the HTTP embed server uses OpenAI format. Fix: replace line 77 with `raw = d.get("data", [None])[0]; vec = raw.get("embedding", raw) if isinstance(raw, dict) else raw`.
