# Ziva Analytics

`ziva_analytics.gd` is the Ziva Analytics SDK, registered as the `ZivaAnalytics` autoload by
Ziva's `setup_analytics` tool. Don't edit it: re-running the tool rewrites it.

From any script:

    ZivaAnalytics.track("level_complete", {"level": 3})
    ZivaAnalytics.identify("Bobby")  # names the player on every later event
    ZivaAnalytics.flush()            # optional: send now instead of at the next 2 s tick

session_start, scene_changed, a 60 s heartbeat and session_end are sent automatically.

Dashboard: https://ziva.sh/account/analytics/7ad2612b-b8dd-43d0-a591-0cb286d08c2f

The settings live in project.godot (`ziva/analytics/ingest_key`, `ziva/analytics/endpoint`);
the ingest key is a public write-only key, safe to ship in exports. Docs: https://ziva.sh/docs/analytics
