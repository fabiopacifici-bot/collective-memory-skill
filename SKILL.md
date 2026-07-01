---
name: collective-memory
description: Local markdown file entries for OpenClaw agents. Cross-agent facts, decisions, and context stored as curated files.
version: 1.0.0
user-invokable: true
context_provider: true
context_search_cmd: "python3 {skill_dir}/scripts/search.py {query} --top 5"
commands:
  - /memory-read
  - /memory-write
  - /memory-search
---

# Collective Memory Skill — Local Files

Curated markdown entries stored in `$OPENCLAW_WORKSPACE/collective-memory/entries/`. This machine only, text-only, OpenClaw agents.

**Data location:** `/home/pacificDev/.openclaw/workspace/collective-memory/entries/`
**Embedding index:** `/home/pacificDev/.openclaw/workspace/collective-memory/memory.db`

---

## Semantic Search

```bash
python3 {skill_dir}/scripts/search.py "<your question>"
# --top 5 (default 3) | --json (machine-readable)
```

## Browse All Entries

```bash
cat /home/pacificDev/.openclaw/workspace/collective-memory/index.md
```

## Write a New Entry

1. Create file: `$OPENCLAW_WORKSPACE/collective-memory/entries/YYYY-MM-DD-<slug>.md`
2. YAML frontmatter + body:
```markdown
---
date: YYYY-MM-DD
agent: <agent-id>
topic: <lowercase-hyphenated>
tags: [tag1, tag2]
confidence: confirmed | plausible | draft
---
# [Short title]
[2-5 sentences]
```
3. Run `python3 $OPENCLAW_WORKSPACE/collective-memory/scripts/index.py` to embed it

## Index & Embedding

```bash
python3 /home/pacificDev/.openclaw/workspace/collective-memory/scripts/index.py
# --rebuild  (wipe and rebuild)
# --watch    (index then watch for new files)
```

---

## Scripts in this skill

| Script | Purpose |
|--------|---------|
| `scripts/search.py` | Semantic search against local entries |
| `scripts/index.py` | Embed entries into memory.db |