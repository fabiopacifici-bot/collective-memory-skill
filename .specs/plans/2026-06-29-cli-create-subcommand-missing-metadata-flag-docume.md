---
date: 2026-06-29
agent: scout
topic: CLI create subcommand missing --metadata flag documented in SKILL.md
severity: low
tags: [scout, agent-ready]
status: open
---

# CLI create subcommand missing --metadata flag documented in SKILL.md

Root cause: SKILL.md:138-139 documents passing a `metadata` dict when creating memories (e.g. `metadata={"project": "alpha", "phase": 1}`), and `create_memory()` at scripts/memory_api.py:43 accepts it as a parameter. However the CLI `create` subparser defined at lines 150-154 only registers `--agent`, `--key`, and `--text`. The CLI handler at line 184 calls `create_memory(args.agent, args.key, text=args.text)` with no metadata argument, making metadata permanently inaccessible from the command line. Fix: add `p_create.add_argument("--metadata", default=None, help='JSON object string, e.g. \'{"key":"val"}\'' )` to the create subparser, then in the handler parse it with `metadata = json.loads(args.metadata) if args.metadata else None` and pass `metadata=metadata` to `create_memory()`.
