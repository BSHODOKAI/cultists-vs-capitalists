# Stopgap Analytics Collector

A Cloudflare Worker + D1 database that receives playtest telemetry from the
`AnalyticsMirror` autoload (and accepts the same batch format as Ziva's SDK).
Use it while Ziva's own ingest is unavailable; Ziva keeps its channel, and once
their ingest is fixed you can disable the mirror by clearing one setting.

## Why a Worker

- **Free** and always-on (100k requests/day on the free plan — this game sends a
  handful of requests per run).
- **You own CORS.** The game posts `Content-Type: application/json`, which forces
  a browser preflight; the Worker answers `OPTIONS` explicitly, so an itch.io
  **web** build can post. (A collector that omits this silently kills the
  client's analytics, because `AnalyticsMirror` disables itself on failure.)
- **Data lands in SQL**, so you can query runs later, unlike a webhook log.

## Deploy

```bash
npm install -g wrangler        # or: npx wrangler
wrangler login

# 1. Create the database and copy the printed database_id into wrangler.toml
wrangler d1 create cvc_analytics

# 2. Apply the schema
wrangler d1 execute cvc_analytics --remote --file schema.sql

# 3. Deploy the Worker
wrangler deploy
```

`wrangler deploy` prints the Worker URL, e.g.
`https://cvc-analytics.<your-subdomain>.workers.dev`.

## Point the game at it

Set these in Godot (Project Settings, or `project.godot`):

```ini
[playtest]
collector/endpoint="https://cvc-analytics.<your-subdomain>.workers.dev/"
collector/key=""
```

- `collector/endpoint` — the Worker URL. **Empty = mirror disabled** (the default).
- `collector/key` — optional; if you set `INGEST_KEY` in `wrangler.toml`, put the
  same value here. Leave both empty to accept anything.

Re-export the game. Playtesters' runs then flow into D1 automatically; no manual
JSON exports.

## Verify

Quick manual check (replace the URL):

```bash
curl -i https://cvc-analytics.gi-dev.workers.dev \
  -H 'Content-Type: application/json' \
  -d '{"key":"feb33189aead971796af5564594ee382d220e1c31af2d22d","sdk":"manual","events":[{"id":"b8f9c2a1-7d3e-4a55-9c21-0a1b2c3d4e5f","name":"session_start","ts":1794422879000,"session_id":"1a2b3c4d-5e6f-4a1b-8c2d-3e4f5a6b7c8d","player_id":"9f8e7d6c-5b4a-4392-8170-abcdef012345","source":"player","platform":"Windows","props":{}}]}'
```

Expect `HTTP/2 202` with `{"accepted":1}`. Then:

```bash
wrangler d1 execute cvc_analytics --remote \
  --command "SELECT name, count(*) FROM events GROUP BY name ORDER BY 2 DESC"
```

## Useful queries

```sql
-- Runs reaching each wave
SELECT json_extract(props, '$.reached_wave') AS wave, count(*)
FROM events WHERE name = 'run_ended' GROUP BY wave ORDER BY wave;

-- Leaks by wave
SELECT json_extract(props, '$.wave') AS wave, sum(json_extract(props, '$.leaks')) AS leaks
FROM events WHERE name = 'wave_completed' GROUP BY wave ORDER BY wave;

-- One player's full timeline
SELECT ts_ms, name, props FROM events WHERE player_name = 'derek' ORDER BY ts_ms;
```

## Alternatives

- **Pipedream** HTTP trigger → Google Sheets: no deploy, handles CORS.
- **Supabase** Edge Function + table: Postgres + SQL if you prefer it.
- **webhook.site**: 2-minute smoke test only.

All of them just need to answer `OPTIONS`/`POST` with a 2xx and CORS headers.