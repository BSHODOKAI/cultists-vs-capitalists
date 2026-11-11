// Stopgap analytics collector for Cultists vs. Capitalists playtest data.
//
// A Cloudflare Worker that accepts the same batch format as Ziva's SDK and the
// AnalyticsMirror autoload:
//
//   POST { "key": "...", "sdk": "...", "events": [ { ... }, ... ] }
//
// It writes one row per event into a D1 (SQLite) database and answers 2xx so the
// client never disables itself. CORS (including the OPTIONS preflight the
// Content-Type: application/json request triggers) is handled explicitly, so an
// itch.io web build can post to it.
//
// Deploy: see README.md in this folder.

export default {
  async fetch(request, env) {
    const cors = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Max-Age": "86400",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }
    if (request.method !== "POST") {
      return json({ error: "method not allowed" }, 405, cors);
    }

    let payload;
    try {
      payload = await request.json();
    } catch (e) {
      return json({ error: "invalid json" }, 400, cors);
    }

    // Optional shared secret: set INGEST_KEY in wrangler.toml to enable the check.
    // Leave it empty for an open endpoint (the data is low-sensitivity playtest telemetry).
    if (env.INGEST_KEY && payload.key !== env.INGEST_KEY) {
      return json({ error: "unknown key" }, 401, cors);
    }

    const events = Array.isArray(payload?.events) ? payload.events : null;
    if (!events || events.length === 0) {
      return json({ error: "no events" }, 400, cors);
    }

    const receivedAt = Math.floor(Date.now() / 1000);
    const stmt = env.DB.prepare(
      `INSERT INTO events
         (id, name, ts_ms, session_id, player_id, player_name, source, platform, app_version, received_at, props)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(id) DO NOTHING`
    );

    const batch = events.map((ev) =>
      stmt.bind(
        String(ev.id ?? crypto.randomUUID()),
        String(ev.name ?? "unknown"),
        Number(ev.ts ?? Date.now()),
        String(ev.session_id ?? ""),
        String(ev.player_id ?? ""),
        ev.player_name != null ? String(ev.player_name) : null,
        String(ev.source ?? ""),
        String(ev.platform ?? ""),
        ev.app_version != null ? String(ev.app_version) : null,
        receivedAt,
        JSON.stringify(ev.props ?? {})
      )
    );

    try {
      await env.DB.batch(batch);
    } catch (e) {
      // 5xx makes the client retry with backoff, so a transient DB error loses nothing.
      return json({ error: "db insert failed", detail: String(e) }, 500, cors);
    }

    return json({ accepted: events.length }, 202, cors);
  },
};

function json(obj, status, cors) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}