# Bug Report — Ziva Analytics: ingest accepts events (`202`) but the dashboard stays empty

> **Before sending:** fill in the Ziva version (panel → **Settings → About → Version**),
> and attach the `/export-logs` zip.
> Send to https://ziva.sh/contact (or the Ziva Discord).

## Environment

- **Ziva version:** `<Settings → About → Version>`
- **Godot:** 4.7.2.stable
- **OS:** Windows 10/11 x64
- **Project:** `cultists-vs-capitalists`
- **Analytics dashboard:** https://ziva.sh/account/analytics/7ad2612b-b8dd-43d0-a591-0cb286d08c2f
- **Ingest key:** `zva_ac8wCuQ0ddGrrLXsikugRp79MqpAd5oy`
- **Endpoint:** `https://ziva.sh/api/v1/analytics/events`
- Set up via the `setup_analytics` tool; `ZivaAnalytics` autoload registered.

## Summary

Events are accepted by the ingest endpoint (HTTP `202 {"accepted":1}`) but never
appear on the dashboard — not in the live feed, not after >15 minutes, on any
source filter (`player` / `editor` / all) or time range. `setup_analytics` reports
"Events received in the last 15 minutes: 0" before and after every attempt.
Reproduced from the editor, from an exported itch.io web build, and from headless
runs.# Bug Report — Ziva Analytics: ingest accepts events (`202`) but the dashboard stays empty

> **Before sending:** fill in the Ziva version (panel → **Settings → About → Version**),
> and attach the `/export-logs` zip.
> Send to https://ziva.sh/contact (or the Ziva Discord).

## Environment

- **Ziva version:** `<Settings → About → Version>`
- **Godot:** 4.7.2.stable
- **OS:** Windows 10/11 x64
- **Project:** `cultists-vs-capitalists`
- **Analytics dashboard:** https://ziva.sh/account/analytics/7ad2612b-b8dd-43d0-a591-0cb286d08c2f
- **Ingest key:** `zva_ac8wCuQ0ddGrrLXsikugRp79MqpAd5oy`
- **Endpoint:** `https://ziva.sh/api/v1/analytics/events`
- Set up via the `setup_analytics` tool; `ZivaAnalytics` autoload registered.

## Summary

Events are accepted by the ingest endpoint (HTTP `202 {"accepted":1}`) but never
appear on the dashboard — not in the live feed, not after >15 minutes, on any
source filter (`player` / `editor` / all) or time range. `setup_analytics` reports
"Events received in the last 15 minutes: 0" before and after every attempt.
Reproduced from the editor, from an exported itch.io web build, and from headless
runs.

## Steps to reproduce

1. Open the dashboard (`/account/analytics/7ad2612b…`) — live feed is empty on
   every filter and time range.
2. Run the game from the editor (F5 → `scenes/main_menu.tscn`) for ~10 seconds so
   `session_start` / `scene_changed` flush, then quit.
3. Re-check the dashboard and `setup_analytics` → still **0**.
4. Independent of the game, POST a valid batch directly:

   ```bash
   curl -i https://ziva.sh/api/v1/analytics/events \
     -H 'Content-Type: application/json' \
     -d '{"key":"zva_ac8wCuQ0ddGrrLXsikugRp79MqpAd5oy","sdk":"godot/0.1.0","events":[{"id":"b8f9c2a1-7d3e-4a55-9c21-0a1b2c3d4e5f","name":"session_start","ts":1794422879000,"session_id":"1a2b3c4d-5e6f-4a1b-8c2d-3e4f5a6b7c8d","player_id":"9f8e7d6c-5b4a-4392-8170-abcdef012345","source":"player","platform":"Windows","props":{}}]}'
   ```

   → `HTTP/2 202`, body `{"accepted":1}`.

5. Check the dashboard again → nothing, still.

## Expected

The event appears in the dashboard live feed within 5–15 seconds.

## Actual

The server accepts the batch, but no event is ever visible for this project.

## Diagnostics proving the client is not at fault

- Valid key → `202 {"accepted":1}`. The same request with a **bogus** key →
  `401 {"error":"unknown key"}` — so the ingest **is** validating and **is**
  recognizing this project's key.
- SDK-produced payload (real `ZivaAnalytics.track()` + `flush()`) → `202`, queue
  drains (`in_flight=0`, `dropped=0`).
- Malformed ids are rejected strictly (`400 … "events.0.id: Invalid GUID"`), so
  the endpoint is parsing the SDK's schema and accepting the real payload shape.
- Client clock is correct (matches the response `Date` header), so `ts` filtering
  is not hiding anything.
- Re-running `setup_analytics` (including after clearing
  `ziva/analytics/{ingest_key,endpoint}`) re-issues the **same** key and the
  **same** dashboard id `7ad2612b…` — so this is not a key/project mismatch.
- Requests hit a sharded ingest — response headers include
  `x-ziva-instance: blue-4` / `blue-6`. Suspect the gap is between the ingest
  shard and the dashboard read.

## Request identifiers for tracing (UTC, 2026-11-11)

- Accepted POSTs: `CF-RAY: a58f77850c4f96f5-SLC` (18:47:41) and
  `CF-RAY: a58f7874fc37a42a-SLC` (18:48:20), both `x-ziva-instance: blue-6`.

## Impact

Playtest telemetry cannot be collected at all via Ziva Analytics.

## Workaround in place

A stopgap dual-send (`AnalyticsMirror` autoload) mirrors the same events to a
self-hosted collector while this is investigated. Ziva's channel is left intact.

## Attachments

- `/export-logs` zip.# Bug Report — Ziva Analytics: ingest accepts events (`202`) but the dashboard stays empty

> **Before sending:** fill in the Ziva version (panel → **Settings → About → Version**),
> and attach the `/export-logs` zip.
> Send to https://ziva.sh/contact (or the Ziva Discord).

## Environment

- **Ziva version:** `<Settings → About → Version>`
- **Godot:** 4.7.2.stable
- **OS:** Windows 10/11 x64
- **Project:** `cultists-vs-capitalists`
- **Analytics dashboard:** https://ziva.sh/account/analytics/7ad2612b-b8dd-43d0-a591-0cb286d08c2f
- **Ingest key:** `zva_ac8wCuQ0ddGrrLXsikugRp79MqpAd5oy`
- **Endpoint:** `https://ziva.sh/api/v1/analytics/events`
- Set up via the `setup_analytics` tool; `ZivaAnalytics` autoload registered.

## Summary

Events are accepted by the ingest endpoint (HTTP `202 {"accepted":1}`) but never
appear on the dashboard — not in the live feed, not after >15 minutes, on any
source filter (`player` / `editor` / all) or time range. `setup_analytics` reports
"Events received in the last 15 minutes: 0" before and after every attempt.
Reproduced from the editor, from an exported itch.io web build, and from headless
runs.

## Steps to reproduce

1. Open the dashboard (`/account/analytics/7ad2612b…`) — live feed is empty on
   every filter and time range.
2. Run the game from the editor (F5 → `scenes/main_menu.tscn`) for ~10 seconds so
   `session_start` / `scene_changed` flush, then quit.
3. Re-check the dashboard and `setup_analytics` → still **0**.
4. Independent of the game, POST a valid batch directly:

   ```bash
   curl -i https://ziva.sh/api/v1/analytics/events \
     -H 'Content-Type: application/json' \
     -d '{"key":"zva_ac8wCuQ0ddGrrLXsikugRp79MqpAd5oy","sdk":"godot/0.1.0","events":[{"id":"b8f9c2a1-7d3e-4a55-9c21-0a1b2c3d4e5f","name":"session_start","ts":1794422879000,"session_id":"1a2b3c4d-5e6f-4a1b-8c2d-3e4f5a6b7c8d","player_id":"9f8e7d6c-5b4a-4392-8170-abcdef012345","source":"player","platform":"Windows","props":{}}]}'
   ```

   → `HTTP/2 202`, body `{"accepted":1}`.

5. Check the dashboard again → nothing, still.

## Expected

The event appears in the dashboard live feed within 5–15 seconds.

## Actual

The server accepts the batch, but no event is ever visible for this project.

## Diagnostics proving the client is not at fault

- Valid key → `202 {"accepted":1}`. The same request with a **bogus** key →
  `401 {"error":"unknown key"}` — so the ingest **is** validating and **is**
  recognizing this project's key.
- SDK-produced payload (real `ZivaAnalytics.track()` + `flush()`) → `202`, queue
  drains (`in_flight=0`, `dropped=0`).
- Malformed ids are rejected strictly (`400 … "events.0.id: Invalid GUID"`), so
  the endpoint is parsing the SDK's schema and accepting the real payload shape.
- Client clock is correct (matches the response `Date` header), so `ts` filtering
  is not hiding anything.
- Re-running `setup_analytics` (including after clearing
  `ziva/analytics/{ingest_key,endpoint}`) re-issues the **same** key and the
  **same** dashboard id `7ad2612b…` — so this is not a key/project mismatch.
- Requests hit a sharded ingest — response headers include
  `x-ziva-instance: blue-4` / `blue-6`. Suspect the gap is between the ingest
  shard and the dashboard read.

## Request identifiers for tracing (UTC, 2026-11-11)

- Accepted POSTs: `CF-RAY: a58f77850c4f96f5-SLC` (18:47:41) and
  `CF-RAY: a58f7874fc37a42a-SLC` (18:48:20), both `x-ziva-instance: blue-6`.

## Impact

Playtest telemetry cannot be collected at all via Ziva Analytics.

## Workaround in place

A stopgap dual-send (`AnalyticsMirror` autoload) mirrors the same events to a
self-hosted collector while this is investigated. Ziva's channel is left intact.

## Attachments

- `/export-logs` zip.

## Steps to reproduce

1. Open the dashboard (`/account/analytics/7ad2612b…`) — live feed is empty on
   every filter and time range.
2. Run the game from the editor (F5 → `scenes/main_menu.tscn`) for ~10 seconds so
   `session_start` / `scene_changed` flush, then quit.
3. Re-check the dashboard and `setup_analytics` → still **0**.
4. Independent of the game, POST a valid batch directly:

   ```bash
   curl -i https://ziva.sh/api/v1/analytics/events \
     -H 'Content-Type: application/json' \
     -d '{"key":"zva_ac8wCuQ0ddGrrLXsikugRp79MqpAd5oy","sdk":"godot/0.1.0","events":[{"id":"b8f9c2a1-7d3e-4a55-9c21-0a1b2c3d4e5f","name":"session_start","ts":1794422879000,"session_id":"1a2b3c4d-5e6f-4a1b-8c2d-3e4f5a6b7c8d","player_id":"9f8e7d6c-5b4a-4392-8170-abcdef012345","source":"player","platform":"Windows","props":{}}]}'
   ```

   → `HTTP/2 202`, body `{"accepted":1}`.

5. Check the dashboard again → nothing, still.

## Expected

The event appears in the dashboard live feed within 5–15 seconds.

## Actual

The server accepts the batch, but no event is ever visible for this project.

## Diagnostics proving the client is not at fault

- Valid key → `202 {"accepted":1}`. The same request with a **bogus** key →
  `401 {"error":"unknown key"}` — so the ingest **is** validating and **is**
  recognizing this project's key.
- SDK-produced payload (real `ZivaAnalytics.track()` + `flush()`) → `202`, queue
  drains (`in_flight=0`, `dropped=0`).
- Malformed ids are rejected strictly (`400 … "events.0.id: Invalid GUID"`), so
  the endpoint is parsing the SDK's schema and accepting the real payload shape.
- Client clock is correct (matches the response `Date` header), so `ts` filtering
  is not hiding anything.
- Re-running `setup_analytics` (including after clearing
  `ziva/analytics/{ingest_key,endpoint}`) re-issues the **same** key and the
  **same** dashboard id `7ad2612b…` — so this is not a key/project mismatch.
- Requests hit a sharded ingest — response headers include
  `x-ziva-instance: blue-4` / `blue-6`. Suspect the gap is between the ingest
  shard and the dashboard read.

## Request identifiers for tracing (UTC, 2026-11-11)

- Accepted POSTs: `CF-RAY: a58f77850c4f96f5-SLC` (18:47:41) and
  `CF-RAY: a58f7874fc37a42a-SLC` (18:48:20), both `x-ziva-instance: blue-6`.

## Impact

Playtest telemetry cannot be collected at all via Ziva Analytics.