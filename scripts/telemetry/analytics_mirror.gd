## AnalyticsMirror
##
## Dual-send companion to the `ZivaAnalytics` autoload. While Ziva's hosted ingest
## is unavailable, this mirrors the exact same playtest events to a collector you
## control, so playtests keep producing data without manual JSON exports.
##
## It is a separate channel: it never changes ZivaAnalytics, so the moment Ziva's
## ingest works again the Ziva dashboard resumes with no code changes.
##
## Configure it with these ProjectSettings (Project Settings editor or project.godot):
##   playtest/collector/endpoint  e.g. "https://cvc-analytics.<you>.workers.dev/ingest"
##   playtest/collector/key       optional shared secret, sent as the "key" field
##
## When `playtest/collector/endpoint` is empty the mirror is inert: it makes no
## network calls and costs nothing, so it is safe to ship dormant.
##
## The wire format is identical to Ziva's SDK - POST {"key","sdk","events":[..]} -
## so a collector built for one channel can ingest the other.
##
## NOTE: no `class_name` - it would hide the `AnalyticsMirror` autoload singleton.
## Reach the live singleton via `/root/AnalyticsMirror`, or preload this script.
extends Node

const SDK := "cvc-mirror/0.1.0"
const FLUSH_INTERVAL_S := 2.0
const FLUSH_AT := 20
const MAX_BATCH := 100
const MAX_QUEUE := 1000
const HEARTBEAT_S := 60.0
const SCENE_POLL_S := 0.5
const BACKOFF_MIN_S := 1.0
const BACKOFF_MAX_S := 30.0
const PLAYER_CFG := "user://playtest_collector.cfg"
const GAME_STATE_PATH := "/root/GameState"

var _ready := false
var _enabled := false
var _endpoint := ""
var _key := ""
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
var _timers_started := false

## Test hook: force emission even in headless runs.
var force_enable_in_tests := false
## Observability/test hook: every event queued for the collector.
var recorded_events: Array[Dictionary] = []


func _init() -> void:
	_endpoint = str(ProjectSettings.get_setting("playtest/collector/endpoint", ""))
	_key = str(ProjectSettings.get_setting("playtest/collector/key", ""))
	_app_version = str(ProjectSettings.get_setting("application/config/version", ""))
	_started_ms = Time.get_ticks_msec()
	_ensure_ready()


## Points the mirror at a collector after construction (used by tests and by
## callers that resolve the endpoint at runtime).
func configure(endpoint: String, key: String = "") -> void:
	_endpoint = endpoint
	_key = key
	_ensure_ready()


func _ensure_ready() -> void:
	if _ready or _endpoint.is_empty():
		return
	_ready = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_source = _detect_source()
	_player_id = _load_player_id()
	_session_id = _uuid4()
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)
	_start_timers()
	_enabled = true
	track("session_start", {
		"godot_version": Engine.get_version_info()["string"],
		"debug": OS.is_debug_build(),
		"locale": OS.get_locale(),
		"mirror": true,
	})


func _start_timers() -> void:
	if _timers_started:
		return
	_timers_started = true
	_timer(FLUSH_INTERVAL_S, _send)
	_timer(SCENE_POLL_S, _poll_scene)
	_timer(HEARTBEAT_S, _emit_heartbeat)


## Queues a mirror event. Mirrors the ZivaAnalytics.track() signature.
func track(event_name: String, props: Dictionary = {}) -> void:
	if not _enabled or not _should_emit():
		return
	if _queue.size() >= MAX_QUEUE:
		_queue.pop_front()
		_dropped += 1
	var event: Dictionary = _event(event_name, props)
	recorded_events.append({"name": event_name, "props": props.duplicate(true)})
	_queue.append(event)
	if _queue.size() >= FLUSH_AT:
		_send()


## Mirrors the ZivaAnalytics.identify() signature.
func identify(player_name: String, traits: Dictionary = {}) -> void:
	if not _enabled:
		return
	_player_name = player_name
	track("identify", traits)


## Sends queued events now instead of at the next 2 s tick.
func flush() -> void:
	if not _enabled:
		return
	_flush_requested = true
	_send()


func _should_emit() -> bool:
	if force_enable_in_tests:
		return true
	if DisplayServer.get_name() == "headless":
		return false
	var gs: Node = get_node_or_null(GAME_STATE_PATH)
	if gs != null and bool(gs.get("is_replaying")):
		return false
	return true


func _detect_source() -> String:
	if OS.has_feature("template"):
		return "player"
	return "editor"


func _load_player_id() -> String:
	var cfg := ConfigFile.new()
	var id := ""
	if cfg.load(PLAYER_CFG) == OK:  # absent on the first launch
		id = str(cfg.get_value("player", "id", ""))
	if id == "":
		id = _uuid4()
		cfg.set_value("player", "id", id)
		var save_err: int = cfg.save(PLAYER_CFG)
		if save_err != OK:
			push_warning("AnalyticsMirror: cannot write %s; player_id will not persist" % PLAYER_CFG)
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
	if not _player_name.is_empty():
		event["player_name"] = _player_name
	if not _app_version.is_empty():
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


func _post() -> void:
	var body := JSON.stringify({"key": _key, "sdk": SDK, "events": _in_flight})
	var err := _http.request(_endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		push_error("AnalyticsMirror: request to %s failed: %s" % [_endpoint, error_string(err)])
		_in_flight.clear()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code >= 500 or code < 200:
		_retry("HTTP %d (HTTPRequest result %d)" % [code, result])
		return
	if code >= 400:
		# The collector rejected the batch (unknown key, malformed event): retrying cannot help.
		_disable("%s answered HTTP %d: %s" % [_endpoint, code, body.get_string_from_utf8()])
		return
	_in_flight.clear()
	_backoff_s = BACKOFF_MIN_S
	if _queue.size() >= FLUSH_AT or _flush_requested:
		_send()


func _retry(why: String) -> void:
	push_warning("AnalyticsMirror: %s; retrying in %d s" % [why, _backoff_s])
	get_tree().create_timer(_backoff_s).timeout.connect(_post)
	_backoff_s = minf(_backoff_s * 2.0, BACKOFF_MAX_S)


func _disable(why: String) -> void:
	push_error("AnalyticsMirror: %s. Collector mirror disabled for this session." % why)
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