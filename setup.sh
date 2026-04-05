#!/usr/bin/env bash
# setup.sh — run once by the operator before any agents use pocketchange
# Prerequisites: CouchDB instance running, database "pocketchange" exists,
# user with password created and granted access to the database.
# Usage: POCKETCHANGE_URL=http://user:password@host:5984 ./setup.sh

set -euo pipefail

if [[ -z "${POCKETCHANGE_URL:-}" ]]; then
  echo "Error: POCKETCHANGE_URL is not set." >&2
  echo "Usage: POCKETCHANGE_URL=http://user:password@host:5984 ./setup.sh" >&2
  exit 1
fi

echo "Provisioning indexes on $POCKETCHANGE_URL/pocketchange ..."

curl -sf -X POST "$POCKETCHANGE_URL/pocketchange/_index" \
  -H "Content-Type: application/json" \
  -d '{"index":{"fields":["tags","ts"]},"name":"tags-ts"}'
echo " tags-ts"

curl -sf -X POST "$POCKETCHANGE_URL/pocketchange/_index" \
  -H "Content-Type: application/json" \
  -d '{"index":{"fields":["agent","ts"]},"name":"agent-ts"}'
echo " agent-ts"

curl -sf -X POST "$POCKETCHANGE_URL/pocketchange/_index" \
  -H "Content-Type: application/json" \
  -d '{"index":{"fields":["type","ts"]},"name":"type-ts"}'
echo " type-ts"

curl -sf -X POST "$POCKETCHANGE_URL/pocketchange/_index" \
  -H "Content-Type: application/json" \
  -d '{"index":{"fields":["type","reconciled","ts"]},"name":"type-reconciled-ts"}'
echo " type-reconciled-ts"

echo ""
echo "Done. Set POCKETCHANGE_URL=$POCKETCHANGE_URL in all agent environments."
