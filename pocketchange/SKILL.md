---
name: pocketchange
description: Shared agentic memory via CouchDB. Use when starting a task (load relevant pages and recent observations), during a task (write observations about user preferences, project decisions, tool behavior, or any notable fact), or when you need persistent context across sessions.
---

# pocketchange — shared agentic memory

You have access to a shared CouchDB memory store called **pocketchange**. It is available at `$POCKETCHANGE_URL` (credentials embedded — no `-u` flag needed). The database is named `pocketchange`.

Memory is split into two document types:

- **`obs::*`** — raw observations. You write these freely.
- **`page::*`** — synthesized wiki pages. You read these. You never create, update, or delete them.

---

## On task start — load memory

### 1. List all pages (summaries only)

Scan summaries and tags to decide which pages are relevant to your current task.

```bash
curl -s -X POST "$POCKETCHANGE_URL/pocketchange/_find" \
  -H "Content-Type: application/json" \
  -d '{"selector":{"type":"page"},"fields":["_id","summary","tags","last_reconciled"]}'
```

### 2. Fetch a specific page in full

```bash
curl -s "$POCKETCHANGE_URL/pocketchange/page::user-preferences"
```

### 3. (Optional) Pull recent unreconciled observations

Unreconciled obs contain fresh information not yet merged into any page.

```bash
curl -s -X POST "$POCKETCHANGE_URL/pocketchange/_find" \
  -H "Content-Type: application/json" \
  -d '{"selector":{"type":"obs","reconciled":false},"sort":[{"ts":"desc"}],"limit":10}'
```

---

## During the task — write observations

Write an observation whenever you learn something worth preserving: user preferences, project decisions, encountered problems, tool behavior, or any other notable fact.

**Write freely. Do not try to guess which page an observation belongs to.** The reconciler handles that.

```bash
curl -s -X POST "$POCKETCHANGE_URL/pocketchange" \
  -H "Content-Type: application/json" \
  -d '{
    "_id":            "obs::'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'::YOUR_AGENT_ID::'"$(head -c2 /dev/urandom | xxd -p)"'",
    "schema_version": "1",
    "type":           "obs",
    "content":        "...",
    "tags":           ["..."],
    "agent":          "YOUR_AGENT_ID",
    "ts":             "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",
    "reconciled":     false,
    "session":        "'"$PWD"'",
    "source":         "tool:bash"
  }'
```

Replace `YOUR_AGENT_ID` with a stable identifier for your agent (e.g. `claude-code`). Replace `source` with the appropriate value (e.g. `tool:bash`, `file:report.pdf`, `web_search`). `session` and `source` are optional but encouraged.

### obs schema

| field | type | required | notes |
|---|---|---|---|
| `_id` | string | yes | `obs::{ISO8601}::{agent-id}::{4-char random}` |
| `schema_version` | string | yes | `"1"` |
| `type` | string | yes | `"obs"` |
| `content` | string | yes | freeform, one or more observations |
| `tags` | string[] | yes | freeform, e.g. `["preference","formatting"]` |
| `agent` | string | yes | stable agent identifier |
| `ts` | string | yes | ISO8601 UTC timestamp |
| `reconciled` | boolean | yes | always `false` on insert |
| `session` | string | optional | `{cwd}` or `{cwd}:{session_name}` |
| `source` | string | optional | e.g. `tool:bash`, `file:report.pdf`, `web_search` |

### page schema (for reference — you only read these)

| field | type | notes |
|---|---|---|
| `_id` | string | `page::{topic}` |
| `schema_version` | string | `"1"` |
| `type` | string | `"page"` |
| `summary` | string | one-liner for quick scanning |
| `content` | string | markdown |
| `tags` | string[] | freeform |
| `last_reconciled` | string | ISO8601 UTC timestamp |
| `source_obs` | string[] | obs IDs from last reconciliation pass |

---

## Rules

- **Append-only.** Only create new `obs::*` documents. Never update or delete any document.
- **Never touch pages.** Do not create, update, or delete `page::*` documents.
- **Never set `reconciled: true`.** Only the reconciler does that.
- **Do not batch observations.** Write each distinct observation as its own document so the reconciler can triage them independently.
