# iOS Pair HTTPS Relay

This small Node.js service transports a pairing record created by a separately authorized host agent. It does **not** pair an iPhone, generate Apple credentials, or replace Apple's trust prompts.

## Run locally

Requires Node.js 20 or later. No third-party packages are required.

```sh
cp .env.example .env
# Edit .env and replace both placeholder values, then load it into the shell.
set -a
. ./.env
set +a
node relay-server.mjs
```

The service binds to `127.0.0.1` by default. Before internet use, put it behind a correctly configured HTTPS reverse proxy. Do not expose the plain HTTP listener directly to the internet. Use separate client and agent credentials; never embed the agent token in the iPhone app.

## API contract

- `POST /v1/jobs` — client token; body includes `os_version`, `device_model`, and `requested_format`.
- `GET /v1/jobs/{uuid}` — client token; returns `queued`, `completed`, or `failed`. On completion, `file_base64` contains the pairing file.
- `POST /v1/agent/jobs/{uuid}/complete` — agent token; body: `file_name`, `mime_type`, `file_base64`.
- `POST /v1/agent/jobs/{uuid}/fail` — agent token; body: `message`.

Jobs and file data are held in memory and expire after 15 minutes. Restarting the service clears all jobs. Add persistent encrypted storage, audit controls, rate limiting, and operational monitoring before production deployment.

## Host-agent responsibility

A trusted host agent must perform the actual pairing using a supported Apple pairing workflow and submit the resulting genuine file. The relay intentionally does not synthesize a pairing record. The agent should only complete a job after the device owner has approved the pairing on their own device.

- `GET /v1/agent/jobs/next` — agent token; atomically claims the next queued job and returns its ID and device metadata. An empty queue returns HTTP 204.

An agent should poll this route at a modest interval, show the user which device request it is handling, complete the pairing only after the device owner approves it, then submit the genuine file. Never send an agent token to the iPhone client.
