---
date: 2026-06-29
agent: scout
topic: health() in memory_api.py crashes on requests.Timeout and JSONDecodeError
severity: normal
tags: [scout, agent-ready]
status: open
---

# health() in memory_api.py crashes on requests.Timeout and JSONDecodeError

Root cause: scripts/memory_api.py:39 only catches `requests.ConnectionError`. Two uncaught exceptions can escape: (1) `requests.Timeout` — specifically `ReadTimeout` is not a subclass of `ConnectionError`, so if the service is running but slow (timeout=3s is short), an unhandled exception propagates to the caller instead of the intended `{"status": "unreachable"}` dict. (2) `requests.exceptions.JSONDecodeError` (a subclass of `ValueError`) — if the server responds with a non-JSON body (e.g., a proxy error page), `r.json()` raises, also crashing the caller. Any agent calling `health()` as a connectivity guard can crash with an unhandled exception rather than receiving the documented error dict. Fix: change line 39 to `except (requests.ConnectionError, requests.Timeout, ValueError) as e:` and update the returned dict to include `str(e)`.
