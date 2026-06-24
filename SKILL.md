---
name: collective-memory
description: Shared collective memory — local markdown entries + multi-agent network API. Cross-agent facts, decisions, and context.
version: 2.0.0
user-invokable: true
context_provider: true
context_search_cmd: "python3 {skill_dir}/scripts/search.py {query} --top 5"
commands:
  - /memory-read
  - /memory-write
  - /memory-search
  - /memory-create
  - /memory-recent
---

# Collective Memory Skill v2

Shared knowledge for all NSA Agency agents — **dual mode**:

1. **Local entries** (curated, permanent) — markdown files in entries/
2. **Network API** (shared, ephemeral) — REST service on port 8010, accessible by any agent on the mesh

**Location:** `/home/pacificDev/.openclaw/workspace/collective-memory/`
**API Service:** `http://localhost:8010` (Swagger: `/docs`)

---

## 🔧 Service Management (Olly's machine)

The Multi-Agent Collective Memory service runs on Olly's machine (port 8010). Other agents access it over the network — no local service needed.

```bash
# Status (Olly's workspace only)
bash {skill_dir}/scripts/manage_service.sh status

# Start (Olly's workspace only)
bash {skill_dir}/scripts/manage_service.sh start

# Stop (Olly's workspace only)
bash {skill_dir}/scripts/manage_service.sh stop

# Restart (Olly's workspace only)
bash {skill_dir}/scripts/manage_service.sh restart
```

Health check (any agent):
```bash
curl http://<olly-host>:8010/health
```

---

## Part 1 — Local File Entries (curated, permanent — Olly's workspace)

For facts, decisions, and knowledge that should persist indefinitely. Stored in `/home/pacificDev/.openclaw/workspace/collective-memory/entries/`.

### Semantic search
```bash
python3 {skill_dir}/scripts/search.py "<your question>"
# --top 5 (default 3) | --json (machine-readable)
```

### Browse all entries
```bash
cat /home/pacificDev/.openclaw/workspace/collective-memory/index.md
```

### Write a new entry (Olly only)
1. Create file: `/home/pacificDev/.openclaw/workspace/collective-memory/entries/YYYY-MM-DD-<slug>.md`
2. YAML frontmatter + body:
```markdown
---
date: YYYY-MM-DD
agent: <your-agent-id>
topic: <topic>
tags: [tag1, tag2]
confidence: confirmed
---

# [Short title]
[2-5 sentences — the fact, decision, or event]
```
3. Run `python3 /home/pacificDev/.openclaw/workspace/collective-memory/scripts/index.py` to embed it

---

## Part 2 — Network API (shared, multi-agent)

For cross-agent context, ephemeral data, or anything multiple agents need to share over the network.

### CLI client
```bash
# Create a memory
python3 {skill_dir}/scripts/memory_api.py create \
  --agent olly --key decision-ip-model --text "Agreed on 18% revenue share model for NSA courses"

# Get by key
python3 {skill_dir}/scripts/memory_api.py get key decision-ip-model

# Semantic search across all agents
python3 {skill_dir}/scripts/memory_api.py search "NSA revenue share" --top 5

# Recent memories
python3 {skill_dir}/scripts/memory_api.py recent --limit 10

# Filter by agent
python3 {skill_dir}/scripts/memory_api.py recent --agent marty --limit 5

# Delete
python3 {skill_dir}/scripts/memory_api.py delete decision-old-key
```

### Python import (for agent scripts)
```python
from memory_api import (
    create_memory, search_memory, get_memory_by_key,
    update_memory, delete_memory, recent_memories, health
)

# Check service
status = health()

# Write
result = create_memory("marty", "project-alpha-status",
    text="Phase 1 complete, all tests passing",
    metadata={"project": "alpha", "phase": 1})

# Search
results = search_memory("project alpha tests", top_k=3)
for r in results:
    print(f"{r['key']}: {r['content_text'][:100]}")
```

*(The file `memory_api.py` is in the same directory as this skill — any agent that has the skill installed can import it.)*

### Raw HTTP (any agent, any language)
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Service status |
| `POST` | `/memory` | Create memory `{"agent","key","content":{"text","images"},"metadata"}` |
| `GET` | `/memory/{id}` | Get by numeric ID |
| `GET` | `/memory/key/{key}` | Get by logical key |
| `PUT` | `/memory/{key}` | Update by key |
| `DELETE` | `/memory/{key}` | Delete by key |
| `GET` | `/memory/search?q=...&top_k=5` | Semantic search |
| `GET` | `/memory/recent?limit=10&agent=...` | Recent memories |
| `POST` | `/embed` | Debug embedding |

Example — any agent creating memory via curl:
```bash
curl -X POST http://localhost:8010/memory \
  -H "Content-Type: application/json" \
  -d '{"agent":"marty","key":"tweet-schedule-v2","content":{"text":"3x daily rotation: 10:45, 13:12, 17:05"},"metadata":{"updated":"2026-06-23"}}'
```

---

## When to Use Which

| Use case | Mode | Reason |
|----------|------|--------|
| Permanent decisions, IP docs | Local files | Version-controlled, curated |
| Cross-agent context during work | Network API | Any agent on mesh can read/write |
| Ephemeral data (temp notes) | Network API | Clean up with DELETE when done |
| Embedding-heavy search | Both | Local uses embeddinggemma, API uses Qwen3-VL-2B |
| Large data (>100 entries) | Network API | SQLite handles scale better than file index |

---

## Index & Embedding (Olly's workspace)

After writing local entries:
```bash
python3 /home/pacificDev/.openclaw/workspace/collective-memory/scripts/index.py
# --rebuild  (wipe and rebuild from scratch)
# --watch    (index then watch for new files)
```

Network API entries are automatically embedded on creation (via Qwen3-VL-Embedding-2B).

---

**Canonical skill location:** `~/.openclaw/skills/collective-memory/`

Updates to this skill are distributed from there to each agent's workspace.