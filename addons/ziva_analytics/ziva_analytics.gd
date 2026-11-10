extends Node
## Ziva Analytics - game telemetry for Godot 4.2+.
##
## Installed as the `ZivaAnalytics` autoload by Ziva's `setup_analytics` tool,
## which also writes `ziva/analytics/ingest_key` and `ziva/analytics/endpoint`
## into ProjectSettings. Batches events and POSTs them to the ingest endpoint;
## never blocks the game and never crashes it over analytics.
##
##   ZivaAnalytics.track("goal_scored", {"level": 10})
##   ZivaAnalytics.identify("Bobby", {"tier": "gold"})
##   ZivaAnalytics.flush()
##
## Auto events: session_start, scene_changed, heartbeat (every 60 s, with
## playtime_s), session_end (best effort, on window close).

const SDK := "godot/0.1.0"
const FLUSH_INTERVAL_S := 2.0
const FLUSH_AT := 20
const MAX_BATCH := 100
const MAX_QUEUE := 1000
const HEARTBEAT_S := 60.0
const SCENE_POLL_S := 0.5
const BACKOFF_MIN_S := 1.0
const BACKOFF_MAX_S := 30.0
const PLAYER_CFG := "user://ziva_analytics.cfg"
# Left behind by Ziva's run_scene / Playtest Agent while they drive the game.
const AGENT_SIDECARS := ["res://.godot/ziva_qa_session.json", "res://.godot/ziva_playtest_inputs.json"]

var _enabled := false
var _key := ""
var _endpoint := ""
var _source := ""
var _player_id := ""
var _player_name := ""
var _session_id := ""
var _app_version := ""
var _started_ms := 0
var _last_scene := ""
var _rng := RandomNumberGenerator.new()
var _queue: Array = []
var _in_flight: Array = []
var _dropped := 0
var _flush_requested := false
var _backoff_s := BACKOFF_MIN_S
var _http: HTTPRequest


# Set up in _init rather than _ready: Godot instantiates every autoload before
# adding any to the tree, so track() already works from other autoloads' _ready.
func _init() -> void:
	_key = str(ProjectSettings.get_setting("ziva/analytics/ingest_key", ""))
	_endpoint = str(ProjectSettings.get_setting("ziva/analytics/endpoint", ""))
	if _key == "" or _endpoint == "":
		_disable("ziva/analytics/ingest_key or ziva/analytics/endpoint is not set in project settings; ask Ziva to run setup_analytics")
		return
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep flushing while the game is paused
	_source = _detect_source()
	_player_id = _load_player_id()
	_session_id = _uuid4()
	_app_version = str(ProjectSettings.get_setting("application/config/version", ""))
	_started_ms = Time.get_ticks_msec()
	_http = HTTPRequest.new()
	_http.timeout = 15.0  # a stalled connection must not wedge the pipeline
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)
	_timer(FLUSH_INTERVAL_S, _send)
	_timer(SCENE_POLL_S, _poll_scene)
	_timer(HEARTBEAT_S, _emit_heartbeat)
	_enabled = true
	track("session_start", {
		"godot_version": Engine.get_version_info()["string"],
		"debug": OS.is_debug_build(),
		"locale": OS.get_locale(),
	})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		track("session_end", {"playtime_s": _playtime_s()})
		flush()  # best effort: the process may exit before the request completes


## Queues a custom event. `props` must serialize to JSON (≤8 KB).
func track(event_name: String, props: Dictionary = {}) -> void:
	if not _enabled:
		return
	if _queue.size() >= MAX_QUEUE:
		_queue.pop_front()
		_dropped += 1
	_queue.append(_event(event_name, props))
	if _queue.size() >= FLUSH_AT:
		_send()


## Names the player for this and every later event, and records `traits` as an `identify` event.
func identify(player_name: String, traits: Dictionary = {}) -> void:
	_player_name = player_name
	track("identify", traits)


## Sends queued events now instead of at the next 2 s tick.
func flush() -> void:
	_flush_requested = true
	_send()


func _detect_source() -> String:
	for path in AGENT_SIDECARS:
		if FileAccess.file_exists(path):
			return "agent"
	return "player" if OS.has_feature("template") else "editor"


func _load_player_id() -> String:
	var cfg := ConfigFile.new()
	var id := ""
	if cfg.load(PLAYER_CFG) == OK:  # absent on the first launch
		id = str(cfg.get_value("player", "id", ""))
	if id == "":
		id = _uuid4()
		cfg.set_value("player", "id", id)
		if cfg.save(PLAYER_CFG) != OK:
			push_warning("ZivaAnalytics: cannot write %s; player_id will not persist across launches" % PLAYER_CFG)
	return id


func _timer(wait_s: float, callback: Callable) -> void:
	var timer := Timer.new()
	timer.wait_time = wait_s
	timer.autostart = true
	timer.timeout.connect(callback)
	add_child(timer)


func _event(event_name: String, props: Dictionary) -> Dictionary:
	var event := {
		"id": _uuid4(),
		"name": event_name,
		"ts": int(Time.get_unix_time_from_system() * 1000.0),
		"session_id": _session_id,
		"player_id": _player_id,
		"source": _source,
		"platform": OS.get_name(),
		"props": props.duplicate(true),
	}
	if _player_name != "":
		event["player_name"] = _player_name
	if _app_version != "":
		event["app_version"] = _app_version
	return event


func _poll_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null or String(scene.name) == _last_scene:
		return
	_last_scene = String(scene.name)
	track("scene_changed", {"scene": _last_scene})


func _emit_heartbeat() -> void:
	track("heartbeat", {"playtime_s": _playtime_s()})


func _playtime_s() -> int:
	return int((Time.get_ticks_msec() - _started_ms) / 1000.0)


func _send() -> void:
	if not _enabled or not is_inside_tree() or _queue.is_empty() or not _in_flight.is_empty():
		return
	_flush_requested = false
	_in_flight = _queue.slice(0, MAX_BATCH)
	_queue = _queue.slice(MAX_BATCH)
	if _dropped > 0:
		_in_flight[0]["props"]["dropped"] = _dropped
		_dropped = 0
	_post()


# Posts `_in_flight` as-is, so a retry re-sends the identical batch (same ids) and the server can dedupe.
func _post() -> void:
	var body := JSON.stringify({"key": _key, "sdk": SDK, "events": _in_flight})
	var err := _http.request(_endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		_disable("HTTPRequest.request(%s) failed: %s" % [_endpoint, error_string(err)])


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code >= 500 or code < 200:
		_retry("HTTP %d (HTTPRequest result %d)" % [code, result])
		return
	if code >= 400:
		# The server rejected the batch (unknown key, malformed event): retrying cannot help.
		_disable("%s answered HTTP %d: %s" % [_endpoint, code, body.get_string_from_utf8()])
		return
	_in_flight.clear()
	_backoff_s = BACKOFF_MIN_S
	if _queue.size() >= FLUSH_AT or _flush_requested:
		_send()


func _retry(why: String) -> void:
	push_warning("ZivaAnalytics: %s; retrying in %d s" % [why, _backoff_s])
	get_tree().create_timer(_backoff_s).timeout.connect(_post)
	_backoff_s = minf(_backoff_s * 2.0, BACKOFF_MAX_S)


func _disable(why: String) -> void:
	push_error("ZivaAnalytics: %s. Analytics disabled for this session." % why)
	_enabled = false
	_queue.clear()
	_in_flight.clear()


func _uuid4() -> String:
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in 16:
		bytes[i] = _rng.randi_range(0, 255)
	bytes[6] = (bytes[6] & 0x0f) | 0x40  # version 4
	bytes[8] = (bytes[8] & 0x3f) | 0x80  # RFC 4122 variant
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
