#!/usr/bin/env bash
# Minimal helper for an already-authorized agent that has a real pairing file.
# This script only uploads the file to a claimed relay job; it does NOT pair devices.
set -euo pipefail

: "${RELAY_BASE_URL:?Set RELAY_BASE_URL, e.g. https://relay.example.com}"
: "${IOSPAIR_AGENT_TOKEN:?Set IOSPAIR_AGENT_TOKEN}"
: "${JOB_ID:?Set JOB_ID to a job claimed by GET /v1/agent/jobs/next}"
: "${PAIRING_FILE:?Set PAIRING_FILE to the real pairing record created by your approved host workflow}"

node --input-type=module - "$JOB_ID" "$PAIRING_FILE" <<'NODE' | curl --fail --silent --show-error \
  -X POST "$RELAY_BASE_URL/v1/agent/jobs/$JOB_ID/complete" \
  -H "Authorization: Bearer $IOSPAIR_AGENT_TOKEN" \
  -H 'Content-Type: application/json' \
  --data-binary @-
import fs from 'node:fs';
const [jobId, filePath] = process.argv.slice(2);
const data = fs.readFileSync(filePath);
if (data.length === 0 || data.length > 15 * 1024 * 1024) throw new Error('Pairing file must be 1 byte to 15 MB.');
const fileName = filePath.split(/[\\/]/).pop();
process.stdout.write(JSON.stringify({
  file_name: fileName,
  mime_type: 'application/octet-stream',
  file_base64: data.toString('base64')
}));
NODE
