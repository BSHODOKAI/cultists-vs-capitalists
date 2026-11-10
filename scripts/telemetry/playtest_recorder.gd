## PlaytestRecorder
##
## Coordinates playtest telemetry for Cultists vs. Capitalists:
##   1. Persists full deterministic command logs, wave-by-wave strategy digests,
##      and Director feedback profiles to `user://playtest_logs/*.json`.
##   2. Streams compact, structured telemetry events (`run_started`, `wave_completed`,
##      `boss_outcome`, `reckoning_triggered`, `run_ended`) to the `ZivaAnalytics`
##      autoload during live play while suppressing network telemetry during
##      headless test suites, bot simulations, and deterministic replays.
##   3. Persists the optional Playtester Handle (`user://playtest_profile.cfg`)
##      and provides 1-click clipboard export for GameOverScreen / InGameMenu.
class_name PlaytestRecorder
extends Node

const LOG_DIR: String = "user://playtest_logs"
const PROFILE_CFG_PATH: String = "user://playtest_profile.cfg"
const MAX_DIGEST_CHARS: int = 1500
const SCHEMA_VERSION: int = 1

var _gs: Node = null
var current_run_id: String = ""
var started_at_utc: String = ""
var started_msec: int = 0
var peak_corruption: int = 0
var reckonings_triggered: int = 0
var rites_drawn_count: int = 0
var last_saved_log_path: String = ""
var _run_finalized: bool = false
var _boss_spawn_time_s: float = 0.0

## Testing / inspection hook: records every analytics event emitted by this recorder
## in memory (`Array[Dictionary]` of `{"name": event_name, "props": props}`).
var recorded_analytics_events: Array[Dictionary] = []
## When true, forces analytics tracking into `recorded_analytics_events` even in headless tests.
var force_enable_in_tests: bool = false


func bind_to_game_state(gs: Node) -> void:
	if _gs == gs and _gs != null:
		return
	_gs = gs
	if _gs == null:
		return

	var saved_handle: String = load_playtester_handle()
	if not saved_handle.is_empty():
		_gs.set("playtester_handle", saved_handle)
		_identify_analytics_player(saved_handle)

	if not _gs.is_connected("state_changed", _on_state_changed):
		_gs.connect("state_changed", _on_state_changed)
	if not _gs.is_connected("wave_started", _on_wave_started):
		_gs.connect("wave_started", _on_wave_started)
	if not _gs.is_connected("wave_strategy_evaluated", _on_wave_strategy_evaluated):
		_gs.connect("wave_strategy_evaluated", _on_wave_strategy_evaluated)
	if not _gs.is_connected("boss_killed", _on_boss_killed):
		_gs.connect("boss_killed", _on_boss_killed)
	if not _gs.is_connected("boss_leaked", _on_boss_leaked):
		_gs.connect("boss_leaked", _on_boss_leaked)
	if not _gs.is_connected("reckoning_started", _on_reckoning_started):
		_gs.connect("reckoning_started", _on_reckoning_started)
	if not _gs.is_connected("corruption_changed", _on_corruption_changed):
		_gs.connect("corruption_changed", _on_corruption_changed)
	if not _gs.is_connected("rites_changed", _on_rites_changed):
		_gs.connect("rites_changed", _on_rites_changed)
	if not _gs.is_connected("loss_report_ready", _on_loss_report_ready):
		_gs.connect("loss_report_ready", _on_loss_report_ready)
	if not _gs.is_connected("run_about_to_restart", _on_run_about_to_restart):
		_gs.connect("run_about_to_restart", _on_run_about_to_restart)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		finalize_active_run("window_close")


# --- Playtester Handle Profile -----------------------------------------------

static func load_playtester_handle() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_CFG_PATH) != OK:
		return ""
	return String(cfg.get_value("playtester", "handle", "")).strip_edges()


func set_playtester_handle(handle: String) -> void:
	var clean: String = handle.strip_edges().left(48)
	var cfg := ConfigFile.new()
	cfg.load(PROFILE_CFG_PATH)
	cfg.set_value("playtester", "handle", clean)
	cfg.save(PROFILE_CFG_PATH)
	if _gs != null:
		_gs.set("playtester_handle", clean)
	if not clean.is_empty():
		_identify_analytics_player(clean)


func _identify_analytics_player(handle: String) -> void:
	if handle.is_empty() or not _should_emit_analytics():
		return
	var za: Node = _get_ziva_analytics()
	if za != null and za.has_method("identify"):
		za.call("identify", handle, {
			"debug_build": OS.is_debug_build(),
		})


# --- Run Lifecycle & Signal Handlers -----------------------------------------

func on_new_run_initialized() -> void:
	if _gs == null:
		return
	var dt: String = Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "_")
	var seed_val: int = int(_gs.get("run_seed"))
	current_run_id = "%s_s%d" % [dt, seed_val]
	started_at_utc = Time.get_datetime_string_from_system(true)
	started_msec = Time.get_ticks_msec()
	peak_corruption = int(_gs.get("corruption"))
	reckonings_triggered = 0
	rites_drawn_count = 0
	_run_finalized = false
	_boss_spawn_time_s = 0.0

	_track_event("run_started", {
		"run_id": current_run_id,
		"seed": seed_val,
		"biome": String(_gs.get("active_biome_id")),
		"playtester": String(_gs.get("playtester_handle")),
		"debug_tainted": bool(_gs.get("debug_tainted")),
	})


func _on_state_changed(old_state: int, new_state: int) -> void:
	# RUN_SETUP (0) -> INTERMISSION (1) at wave 0 marks a freshly initialized run
	if old_state == 0 and new_state == 1 and _gs != null and int(_gs.get("current_wave")) == 0:
		on_new_run_initialized()


func _on_wave_started(_wave_number: int) -> void:
	if current_run_id.is_empty():
		on_new_run_initialized()
	_boss_spawn_time_s = 0.0


func _on_corruption_changed(new_corruption: int) -> void:
	if new_corruption > peak_corruption:
		peak_corruption = new_corruption


func _on_rites_changed(_rites: int, _attention: int) -> void:
	rites_drawn_count += 1


func _on_reckoning_started(rogue_count: int, severity: int, leak_cost: int, _spawn_world_pos: Vector3) -> void:
	reckonings_triggered += 1
	if _gs == null:
		return
	_track_event("reckoning_triggered", {
		"run_id": current_run_id,
		"wave": int(_gs.get("current_wave")),
		"rogue_count": rogue_count,
		"severity": severity,
		"leak_cost": leak_cost,
		"corruption": int(_gs.get("corruption")),
	})


func _on_wave_strategy_evaluated(wave_number: int, digest: Dictionary) -> void:
	if _gs == null:
		return
	var tsys: TowerSystem = _gs.get("tower_system") as TowerSystem
	var dir: WaveDirector = _gs.get("director") as WaveDirector
	_track_event("wave_completed", {
		"run_id": current_run_id,
		"wave": wave_number,
		"interval": int(_gs.get("current_interval")),
		"faction": String(digest.get("faction", "")),
		"is_boss": bool(digest.get("is_boss", false)),
		"event_id": String(digest.get("event_id", "")),
		"duration_s": float(digest.get("duration_s", 0.0)),
		"kills": int(digest.get("kills", 0)),
		"leaks": int(digest.get("leaks", 0)),
		"lives_after": int(_gs.get("lives")),
		"offerings": int(_gs.get("offerings")),
		"scrap": int(_gs.get("scrap")),
		"corruption": int(_gs.get("corruption")),
		"rites": tsys.rites if tsys != null else 0,
		"rubber_factor": snappedf(dir.rubber_factor, 0.01) if dir != null else 1.0,
		"tower_count": int(digest.get("tower_count", 0)),
		"branch_counts": digest.get("branch_counts", {}),
		"avg_kill_depth": float(digest.get("avg_kill_depth", 0.0)),
		"unscouted_attack_towers": int(digest.get("unscouted_attack_towers", 0)),
		"counters_spawned": int(digest.get("counters_spawned", 0)),
		"counters_leaked": int(digest.get("counters_leaked", 0)),
		"counter_abilities_fired": int(digest.get("counter_abilities_fired", 0)),
		"intermission_churn_ratio": float(digest.get("intermission_churn_ratio", 0.0)),
		"strategy_flags": digest.get("strategy_flags", []),
		"debug_tainted": bool(_gs.get("debug_tainted")),
	})


func _on_boss_killed(wave_number: int) -> void:
	_emit_boss_outcome(wave_number, "killed")


func _on_boss_leaked(wave_number: int) -> void:
	_emit_boss_outcome(wave_number, "leaked")


func _emit_boss_outcome(wave_number: int, outcome: String) -> void:
	if _gs == null:
		return
	var roster: WaveRoster = _gs.get("locked_roster") as WaveRoster
	var tsys: TowerSystem = _gs.get("tower_system") as TowerSystem
	var st: StrategyTracker = _gs.get("strategy_tracker") as StrategyTracker
	var boss_id: String = roster.boss_id if roster != null else ""
	var dur: float = snappedf(tsys.wave_elapsed_time - _boss_spawn_time_s, 0.01) if tsys != null else 0.0
	var ab_used: int = st._boss_abilities_used if st != null else 0
	_track_event("boss_outcome", {
		"run_id": current_run_id,
		"wave": wave_number,
		"boss_id": boss_id,
		"outcome": outcome,
		"duration_s": maxf(0.0, dur),
		"abilities_used": ab_used,
	})


func _on_loss_report_ready(report: LossReport) -> void:
	var reason: String = "game_over"
	if _gs != null:
		var ev_log: Array = _gs.get("event_log") as Array
		for i in range(ev_log.size() - 1, -1, -1):
			var e: Dictionary = ev_log[i] as Dictionary
			if String(e.get("event", "")) == "game_over":
				reason = String((e.get("payload", {}) as Dictionary).get("reason", "game_over"))
				break
	finalize_active_run(reason, report)


func _on_run_about_to_restart(_previous_wave: int) -> void:
	finalize_active_run("restart", null)


## Finalizes the current run (if not already finalized and if meaningful play occurred),
## writes the JSON log to `user://playtest_logs/`, and sends `run_ended` + `flush()`.
func finalize_active_run(outcome: String, report: LossReport = null) -> String:
	if _run_finalized or _gs == null:
		return last_saved_log_path
	if not has_meaningful_activity():
		return ""
	_run_finalized = true

	var st: StrategyTracker = _gs.get("strategy_tracker") as StrategyTracker
	var tsys: TowerSystem = _gs.get("tower_system") as TowerSystem
	var fb: Dictionary = (
		st.get_director_feedback_profile(tsys)
		if st != null
		else {}
	)
	var cmd_log: Array = _gs.get("command_log") as Array
	var cmd_digest: String = build_compact_command_digest(cmd_log)
	var playtime_s: float = snappedf(float(Time.get_ticks_msec() - started_msec) / 1000.0, 0.1)

	var counts_by_type: Dictionary = {}
	if tsys != null:
		for t: TowerInstance in tsys.towers.values():
			if t != null:
				var tid: String = t.get_type_id()
				counts_by_type[tid] = int(counts_by_type.get(tid, 0)) + 1

	var fatal_unit: String = report.leaked_unit_id if report != null else ""
	var fatal_idx: int = report.leaked_path_index if report != null else -1
	var dmg_10s: Dictionary = report.damage_by_tower_type_last_10s if report != null else {}

	_track_event("run_ended", {
		"run_id": current_run_id,
		"seed": int(_gs.get("run_seed")),
		"playtester": String(_gs.get("playtester_handle")),
		"outcome": outcome,
		"reached_wave": int(_gs.get("current_wave")),
		"fatal_unit_id": fatal_unit,
		"fatal_path_index": fatal_idx,
		"playtime_s": maxf(0.0, playtime_s),
		"peak_corruption": peak_corruption,
		"rites_drawn": rites_drawn_count,
		"reckonings": reckonings_triggered,
		"debug_tainted": bool(_gs.get("debug_tainted")),
		"tower_counts_by_type": counts_by_type,
		"damage_last_10s": dmg_10s,
		"dominant_strategies": fb.get("dominant_strategies", []),
		"strategy_scores": fb.get("strategy_scores", {}),
		"command_digest": cmd_digest,
	})
	_flush_analytics()

	if _should_auto_save_disk_log():
		save_run_log_to_disk(outcome, report)
	return last_saved_log_path


## True when the player has either started at least wave 1 or issued commands beyond `start_run`.
func has_meaningful_activity() -> bool:
	if _gs == null:
		return false
	if int(_gs.get("current_wave")) >= 1:
		return true
	var cmd_log: Array = _gs.get("command_log") as Array
	return cmd_log.size() > 1


# --- Disk Persistence & Clipboard Export -------------------------------------

## Builds the complete JSON-serializable Dictionary for the current run.
func build_run_payload(outcome: String = "snapshot", report: LossReport = null) -> Dictionary:
	if _gs == null:
		return {}
	if current_run_id.is_empty():
		var seed_v: int = int(_gs.get("run_seed"))
		current_run_id = "run_s%d" % seed_v
	var tsys: TowerSystem = _gs.get("tower_system") as TowerSystem
	var st: StrategyTracker = _gs.get("strategy_tracker") as StrategyTracker
	var export_dict: Dictionary = _gs.call("export_command_log_dict") as Dictionary
	var cmd_log: Array = _gs.get("command_log") as Array
	var playtime_s: float = snappedf(float(Time.get_ticks_msec() - started_msec) / 1000.0, 0.1) if started_msec > 0 else 0.0

	var loss_rep: LossReport = report
	if loss_rep == null and tsys != null:
		loss_rep = tsys.last_loss_report

	return {
		"schema_version": SCHEMA_VERSION,
		"meta": {
			"run_id": current_run_id,
			"playtester_handle": String(_gs.get("playtester_handle")),
			"seed": int(_gs.get("run_seed")),
			"biome": String(_gs.get("active_biome_id")),
			"started_at_utc": started_at_utc,
			"ended_at_utc": Time.get_datetime_string_from_system(true),
			"duration_s": maxf(0.0, playtime_s),
			"outcome": outcome,
			"reached_wave": int(_gs.get("current_wave")),
			"total_ticks": int(export_dict.get("total_ticks", 0)),
			"debug_tainted": bool(_gs.get("debug_tainted")),
			"peak_corruption": peak_corruption,
			"rites_drawn": rites_drawn_count,
			"reckonings": reckonings_triggered,
		},
		"command_digest": build_compact_command_digest(cmd_log),
		"strategy_summary": (
			GameStateNode.to_json_safe(st.get_director_feedback_profile(tsys))
			if st != null
			else {}
		),
		"wave_digests": (
			GameStateNode.to_json_safe(st.wave_digests)
			if st != null
			else []
		),
		"loss_report": (
			GameStateNode.to_json_safe(loss_rep.to_dict())
			if loss_rep != null
			else {}
		),
		"command_log": export_dict.get("command_log", []),
		"spend_log": GameStateNode.to_json_safe(_gs.get("spend_log")),
	}


## Serializes the current run to a formatted JSON string.
func to_json_string(outcome: String = "snapshot", report: LossReport = null) -> String:
	var payload: Dictionary = build_run_payload(outcome, report)
	return JSON.stringify(payload, "\t")


## Saves the current run log to `user://playtest_logs/` and returns the `user://` file path.
func save_run_log_to_disk(outcome: String = "manual", report: LossReport = null) -> String:
	if _gs == null:
		return ""
	var abs_dir: String = ProjectSettings.globalize_path(LOG_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	var wave_num: int = int(_gs.get("current_wave"))
	var safe_outcome: String = outcome.replace(":", "_").replace(" ", "_").replace("/", "_")
	if current_run_id.is_empty():
		current_run_id = "%s_s%d" % [
			Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "_"),
			int(_gs.get("run_seed")),
		]
	var filename: String = "run_%s_w%d_%s.json" % [current_run_id, wave_num, safe_outcome]
	var full_path: String = LOG_DIR + "/" + filename

	var json_text: String = to_json_string(outcome, report)
	var f: FileAccess = FileAccess.open(full_path, FileAccess.WRITE)
	if f == null:
		push_warning("PlaytestRecorder: could not write %s" % full_path)
		return ""
	f.store_string(json_text)
	f.close()
	last_saved_log_path = full_path
	return full_path


## Copies the full run JSON to the system clipboard (and ensures a local file copy exists).
func copy_run_log_to_clipboard(outcome: String = "clipboard_export") -> String:
	var json_text: String = to_json_string(outcome)
	if last_saved_log_path.is_empty() and has_meaningful_activity():
		save_run_log_to_disk(outcome)
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(json_text)
	return json_text


## Encodes the command log into a compact, human-readable build-order string
## suitable for ZivaAnalytics event props (<= MAX_DIGEST_CHARS).
static func build_compact_command_digest(cmd_log: Array) -> String:
	var by_wave: Dictionary = {}
	var wave_order: Array[int] = []
	for item: Variant in cmd_log:
		if not (item is Dictionary):
			continue
		var cmd: Dictionary = item as Dictionary
		var cname: String = String(cmd.get("command", ""))
		if cname == "start_run":
			continue
		var w: int = int(cmd.get("wave", 0))
		if not by_wave.has(w):
			by_wave[w] = []
			wave_order.append(w)
		var token: String = _format_command_token(cname, cmd.get("payload", {}) as Dictionary)
		if not token.is_empty():
			(by_wave[w] as Array).append(token)

	var wave_chunks: Array[String] = []
	for w: int in wave_order:
		var tokens: Array = by_wave[w] as Array
		if tokens.is_empty():
			continue
		wave_chunks.append("W%d:%s" % [w, ",".join(PackedStringArray(tokens))])

	var full: String = "|".join(wave_chunks)
	if full.length() > MAX_DIGEST_CHARS:
		return full.left(MAX_DIGEST_CHARS - 3) + "..."
	return full


static func _format_command_token(cname: String, p: Dictionary) -> String:
	match cname:
		"place_tower":
			var h: Vector2i = GameStateNode._parse_hex_variant(p.get("hex", Vector2i.ZERO))
			var ov: String = "[ov]" if bool(p.get("is_overlap_hex", false)) else ""
			return "B(%s@%d,%d%s)" % [String(p.get("tower_id", "")), h.x, h.y, ov]
		"upgrade_tower":
			return "U(%d:%s)" % [int(p.get("tower_id", 0)), String(p.get("node_id", ""))]
		"sell_tower":
			return "X(%d)" % int(p.get("tower_id", 0))
		"start_wave":
			return "S"
		"penance":
			return "P"
		"draw_rites":
			return "R(%d)" % maxi(1, int(p.get("count", 1)))
		"maintenance":
			return "M(%d)" % int(p.get("tower_id", 0))
		"cleanse_tower":
			return "C(%d)" % int(p.get("tower_id", 0))
		"select_fork_candidate":
			return "F(%d)" % int(p.get("index", 0))
	return cname


# --- Internal Analytics Guards -----------------------------------------------

func _should_emit_analytics() -> bool:
	if _gs != null and bool(_gs.get("is_replaying")):
		return false
	if force_enable_in_tests:
		return true
	if DisplayServer.get_name() == "headless":
		return false
	return true


func _should_auto_save_disk_log() -> bool:
	if _gs != null and bool(_gs.get("is_replaying")):
		return false
	if force_enable_in_tests:
		return true
	if DisplayServer.get_name() == "headless":
		return false
	return true


func _get_ziva_analytics() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/ZivaAnalytics")


func _track_event(event_name: String, props: Dictionary) -> void:
	if not _should_emit_analytics():
		return
	var safe_props: Dictionary = GameStateNode.to_json_safe(props) as Dictionary
	recorded_analytics_events.append({
		"name": event_name,
		"props": safe_props,
	})
	var za: Node = _get_ziva_analytics()
	if za != null and za.has_method("track"):
		za.call("track", event_name, safe_props)


func _flush_analytics() -> void:
	if not _should_emit_analytics():
		return
	var za: Node = _get_ziva_analytics()
	if za != null and za.has_method("flush"):
		za.call("flush")
