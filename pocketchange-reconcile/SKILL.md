---
name: pocketchange-reconcile
description: On-demand reconciliation of pocketchange memory. Use only when explicitly invoked by the user to synthesize unreconciled observations into wiki pages in the shared CouchDB store. Not for automatic use.
---

# pocketchange-reconcile — on-demand memory reconciliation

You have been explicitly invoked by the user to run a reconciliation pass over pocketchange memory. This is an on-demand operation, not automatic.

The shared CouchDB instance is at `$POCKETCHANGE_URL` (credentials embedded — no `-u` flag needed). The database is named `pocketchange`.

You are the **sole creator and updater of `page::*` documents**. Agents only write `obs::*`. You decide how observations map to pages.

---

## Pass structure

Execute these five steps in order. Do not skip any step.

### 1. Survey — fetch all existing pages

Understand the current knowledge structure before triaging anything.

```bash
curl -s -X POST "$POCKETCHANGE_URL/pocketchange/_find" \
  -H "Content-Type: application/json" \
  -d '{"selector":{"type":"page"}}'
```

### 2. Fetch — get all unreconciled observations

```bash
curl -s -X POST "$POCKETCHANGE_URL/pocketchange/_find" \
  -H "Content-Type: application/json" \
  -d '{"selector":{"type":"obs","reconciled":false},"sort":[{"ts":"asc"}],"limit":50}'
```

If the result contains 50 documents, there may be more. Re-run with `"skip": 50`, `"skip": 100`, etc. until you have fetched all unreconciled obs.

### 3. Triage — decide where each obs belongs

For each unreconciled obs, decide:

- Does it fit an existing page? → update that page in step 4.
- Does it represent a new topic with no existing page? → create a new page in step 4.
- Is it trivial or duplicate? → still mark it reconciled in step 5, but do not create a page for it.

Group obs by the page they belong to before writing.

### 4. Write — create or update pages

#### Create a new page

Choose an `_id` of the form `page::{slug}` where the slug is lowercase, hyphen-separated, and descriptive (e.g. `page::user-preferences`, `page::project-goals`).

```bash
curl -s -X PUT "$POCKETCHANGE_URL/pocketchange/page::new-topic" \
  -H "Content-Type: application/json" \
  -d '{
    "schema_version":  "1",
    "type":            "page",
    "summary":         "One-line description for quick scanning",
    "content":         "## New topic\n\n...",
    "tags":            ["..."],
    "last_reconciled": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",
    "source_obs":      ["obs::..."]
  }'
```

#### Update an existing page

Always fetch first to get the current `_rev`. Without `_rev` the update will be rejected.

```bash
# fetch current revision
curl -s "$POCKETCHANGE_URL/pocketchange/page::user-preferences"

# then update, merging new information into content
curl -s -X PUT "$POCKETCHANGE_URL/pocketchange/page::user-preferences" \
  -H "Content-Type: application/json" \
  -d '{
    "_rev":            "2-abc...",
    "schema_version":  "1",
    "type":            "page",
    "summary":         "...",
    "content":         "## User preferences\n\n...",
    "tags":            ["preference"],
    "last_reconciled": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",
    "source_obs":      ["obs::...","obs::..."]
  }'
```

`source_obs` should contain only the obs IDs processed **in this pass**, not a cumulative list.

### 5. Mark reconciled — bulk update all processed obs

**Preserve every existing field.** Only `reconciled` changes from `false` to `true`. Copy `_id`, `_rev`, `schema_version`, `type`, `content`, `tags`, `agent`, `ts`, and all optional fields exactly as they were.

```bash
curl -s -X POST "$POCKETCHANGE_URL/pocketchange/_bulk_docs" \
  -H "Content-Type: application/json" \
  -d '{"docs":[
    {
      "_id":            "obs::2026-04-04T12:31:00Z::agent-a::f3k9",
      "_rev":           "1-abc...",
      "schema_version": "1",
      "type":           "obs",
      "content":        "...",
      "tags":           ["..."],
      "agent":          "agent-a",
      "ts":             "2026-04-04T12:31:00Z",
      "reconciled":     true,
      "session":        "...",
      "source":         "..."
    }
  ]}'
```

Mark all processed obs in a single `_bulk_docs` call where possible. If you processed more than 50, batch them (50 per call).

---

## Document schemas

### obs schema

| field | type | required | notes |
|---|---|---|---|
| `_id` | string | yes | `obs::{ISO8601}::{agent-id}::{4-char random}` |
| `schema_version` | string | yes | `"1"` |
| `type` | string | yes | `"obs"` |
| `content` | string | yes | freeform observations |
| `tags` | string[] | yes | freeform |
| `agent` | string | yes | agent identifier |
| `ts` | string | yes | ISO8601 UTC timestamp |
| `reconciled` | boolean | yes | `false` → `true` only by you |
| `session` | string | optional | `{cwd}` or `{cwd}:{session_name}` |
| `source` | string | optional | e.g. `tool:bash`, `web_search` |

### page schema

| field | type | required | notes |
|---|---|---|---|
| `_id` | string | yes | `page::{topic}` |
| `schema_version` | string | yes | `"1"` |
| `type` | string | yes | `"page"` |
| `summary` | string | yes | one-liner for quick scanning |
| `content` | string | yes | markdown |
| `tags` | string[] | yes | freeform |
| `last_reconciled` | string | yes | ISO8601 UTC timestamp of this pass |
| `source_obs` | string[] | yes | obs IDs from this pass only |

---

## Rules

- You are the **sole creator and updater of `page::*` documents**.
- Always fetch a page's current `_rev` before updating it.
- `source_obs` on a page lists only the obs processed in the current pass, not all obs ever.
- When marking obs reconciled, preserve **all existing fields** — only flip `reconciled` to `true`.
- Do not create a page for trivial or duplicate obs, but still mark those obs as reconciled.
- Write page `content` in markdown. Use `summary` as a one-liner that agents can scan without fetching the full page.
