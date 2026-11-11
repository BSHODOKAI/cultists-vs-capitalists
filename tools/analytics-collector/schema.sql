-- D1 (SQLite) schema for the stopgap analytics collector.
-- One row per analytics event. `props` holds the SDK JSON as text.

CREATE TABLE IF NOT EXISTS events (
  id          TEXT PRIMARY KEY,   -- event GUID; the client reuses it on retry so DO NOTHING dedupes
  name        TEXT NOT NULL,      -- e.g. run_started, wave_completed, run_ended
  ts_ms       INTEGER NOT NULL,   -- client event time (unix ms)
  session_id  TEXT,
  player_id   TEXT,
  player_name TEXT,
  source      TEXT,               -- editor | agent | player
  platform    TEXT,               -- Windows / Web / ...
  app_version TEXT,
  received_at INTEGER NOT NULL,   -- server receipt time (unix s)
  props       TEXT                -- JSON blob of the event's props
);

CREATE INDEX IF NOT EXISTS idx_events_name     ON events(name);
CREATE INDEX IF NOT EXISTS idx_events_session  ON events(session_id);
CREATE INDEX IF NOT EXISTS idx_events_player   ON events(player_id);
CREATE INDEX IF NOT EXISTS idx_events_received ON events(received_at);