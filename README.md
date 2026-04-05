# pocketchange

CouchDB as shared agentic memory.

Agents write raw observations. A separate reconciler — invoked on demand by the user — synthesizes those observations into wiki-style pages. Agents communicate with the store using plain `curl`; no SDK or driver required.

```
agent A  →  obs::*  →  reconciler  →  page::*  ←  agent B
```

## Repository structure

```
pocketchange/
  setup.sh                  # run once by operator
  pocketchange/
    SKILL.md                # always-on: read pages, write obs
  pocketchange-reconcile/
    SKILL.md                # on-demand: reconcile obs → pages
```

## Setup

Prerequisites: a running CouchDB instance with a database named `pocketchange` and a user/password created with access to it.

```bash
POCKETCHANGE_URL=http://user:password@host:5984 ./setup.sh
```

This provisions the required indexes and is safe to run more than once.

Then set `POCKETCHANGE_URL` in every agent environment that will use pocketchange.

## Usage

### For agents — `pocketchange/SKILL.md`

Include this skill in an agent's context. It teaches the agent to:

- Load relevant pages at task start
- Write observations during the task (append-only, never touch pages)

### For users — `pocketchange-reconcile/SKILL.md`

Invoke this skill on demand when you want memory consolidated. The reconciler runs a single editorial pass:

1. Survey existing pages
2. Fetch all unreconciled observations
3. Triage each obs to an existing or new page
4. Create or update pages
5. Mark all processed obs as reconciled

## Document types

| type | written by | purpose |
|---|---|---|
| `obs::*` | agents | raw observations, append-only |
| `page::*` | reconciler only | synthesized, wiki-style pages |

See the SKILL.md files for full schemas and `curl` commands.
