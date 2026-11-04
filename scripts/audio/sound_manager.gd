## SoundManager
##
## Scene node that bridges pure-logic [AudioCueSystem] decisions to a pool of
## [AudioStreamPlayer] nodes and a looping environment [AudioStreamPlayer].
## Connects to [GameStateNode], [CombatEffectsView], and HUD [BaseButton] controls.
class_name SoundManager
extends Node

const _AudioBalance = preload("res://scripts/audio/audio_balance_data.gd")
const _AudioCueSystem = preload("res://scripts/audio/audio_cue_system.gd")
const _AudioSettings = preload("res://scripts/audio/audio_settings.gd")

signal cue_played(cue_info: Dictionary)
signal environment_started(cue_id: String, stream_path: String)

@export var balance: AudioBalanceData
@export var auto_start_environment: bool = true

var audio_settings: AudioSettings = _AudioSettings.new()
var cue_system: AudioCueSystem
var active_environment_cue_id: String = ""

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_remaining_time: Array[float] = []
var _next_player_cursor: int = 0
var _environment_player: AudioStreamPlayer
var _environment_playing: bool = false
var _environment_stream_path: String = ""
var _stream_cache: Dictionary = {}
var _bound_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_initialized()
	_AudioSettings.register_listener(_on_audio_settings_changed)

	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		bind_to_game_state(gs)
		var biome_id: String = String(gs.get("active_biome_id"))
		if auto_start_environment:
			play_environment_for_biome(biome_id if not biome_id.is_empty() else "urban_center")
	elif auto_start_environment:
		play_environment_for_biome("urban_center")


func _exit_tree() -> void:
	_AudioSettings.unregister_listener(_on_audio_settings_changed)
	if _environment_player != null:
		_environment_player.stop()
		_environment_player.stream = null
	for p: AudioStreamPlayer in _sfx_players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	_stream_cache.clear()


func _ensure_initialized() -> void:
	if balance == null:
		var loaded: AudioBalanceData = load(_AudioBalance.DEFAULT_RESOURCE_PATH) as AudioBalanceData
		balance = loaded if loaded != null else _AudioBalance.new()
	if audio_settings == null:
		audio_settings = _AudioSettings.new()
	audio_settings.load_or_default()
	if cue_system == null:
		var seed_val: int = 1337
		var gs: Node = get_node_or_null("/root/GameState")
		if gs != null:
			seed_val = int(gs.get("run_seed"))
		cue_system = _AudioCueSystem.new(balance, null, seed_val)
	cue_system.set_background_volume_scale(audio_settings.background_volume)
	cue_system.set_fx_volume_scale(audio_settings.fx_volume)
	_build_audio_players()


func _build_audio_players() -> void:
	if _environment_player == null:
		_environment_player = AudioStreamPlayer.new()
		_environment_player.name = "EnvironmentPlayer"
		_environment_player.finished.connect(_on_environment_player_finished)
		add_child(_environment_player)

	var pool_sz: int = maxi(4, balance.sfx_pool_size if balance != null else 16)
	while _sfx_players.size() < pool_sz:
		var idx: int = _sfx_players.size()
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer_%02d" % idx
		add_child(p)
		_sfx_players.append(p)
		_sfx_remaining_time.append(0.0)


func _process(delta: float) -> void:
	if cue_system != null:
		var clock: Node = get_node_or_null("/root/SimClock")
		if clock != null:
			cue_system.set_sim_speed_multiplier(float(clock.get("speed_multiplier")))
		cue_system.step(delta)
	for i in range(_sfx_remaining_time.size()):
		if _sfx_remaining_time[i] > 0.0:
			_sfx_remaining_time[i] -= delta
			if _sfx_remaining_time[i] <= 0.0:
				_sfx_remaining_time[i] = 0.0
				var p: AudioStreamPlayer = _sfx_players[i]
				if is_instance_valid(p) and p.playing:
					p.stop()


## Connects all gameplay & economy audio hooks on [param gs] (GameState).
func bind_to_game_state(gs: Node) -> void:
	if gs == null:
		return
	_ensure_initialized()
	_connect_once(gs, "state_changed", _on_game_state_changed)
	_connect_once(gs, "tower_placed_on_hex", _on_tower_placed_on_hex)
	_connect_once(gs, "tower_upgraded_on_hex", _on_tower_upgraded_on_hex)
	_connect_once(gs, "tower_sold_from_hex", _on_tower_sold_from_hex)
	_connect_once(gs, "tower_maintained", _on_tower_maintained)
	_connect_once(gs, "tower_cooldown_used", _on_tower_cooldown_used)
	_connect_once(gs, "penance_performed", _on_penance_performed)
	_connect_once(gs, "tower_damaged_enemy", _on_tower_damaged_enemy)
	_connect_once(gs, "enemy_spawned", _on_enemy_spawned)
	_connect_once(gs, "enemy_died", _on_enemy_died)
	_connect_once(gs, "boss_killed", _on_boss_killed)
	_connect_once(gs, "enemy_leaked", _on_enemy_leaked)
	_connect_once(gs, "ability_telegraphed", _on_ability_telegraphed)
	_connect_once(gs, "wave_started", _on_wave_started)
	_connect_once(gs, "wave_ended", _on_wave_ended)
	_connect_once(gs, "event_triggered", _on_event_triggered)
	_connect_once(gs, "path_extended", _on_path_extended)
	_connect_once(gs, "loss_report_ready", _on_loss_report_ready)
	_connect_once(gs, "biome_changed", _on_biome_changed)


## Connects projectile fire and projectile hit audio hooks on [param effects_view].
func bind_to_effects_view(effects_view: CombatEffectsView) -> void:
	if effects_view == null:
		return
	_ensure_initialized()
	_connect_once(effects_view, "projectile_fired", _on_effects_projectile_fired)
	_connect_once(effects_view, "projectile_hit", _on_effects_projectile_hit)


## Recursively connects button press sounds to all BaseButtons under [param root_node].
func bind_ui_buttons(root_node: Node) -> void:
	if root_node == null:
		return
	_ensure_initialized()
	if root_node is BaseButton:
		var btn: BaseButton = root_node as BaseButton
		var iid: int = btn.get_instance_id()
		if not _bound_buttons.has(iid):
			_bound_buttons[iid] = true
			btn.pressed.connect(func() -> void: play_ui_click())
	for child: Node in root_node.get_children():
		bind_ui_buttons(child)


func _connect_once(emitter: Object, sig_name: String, callable: Callable) -> void:
	if emitter != null and emitter.has_signal(sig_name) and not emitter.is_connected(sig_name, callable):
		emitter.connect(sig_name, callable)


# --- Stream Loading & Playback -----------------------------------------------

func get_or_load_stream(stream_path: String) -> AudioStream:
	if stream_path.is_empty():
		return null
	if _stream_cache.has(stream_path):
		return _stream_cache[stream_path] as AudioStream
	if not ResourceLoader.exists(stream_path):
		return null
	var stream: AudioStream = load(stream_path) as AudioStream
	if stream != null and DisplayServer.get_name() != "headless":
		_stream_cache[stream_path] = stream
	return stream


func _has_valid_stream(stream_path: String) -> bool:
	if stream_path.is_empty():
		return false
	if DisplayServer.get_name() == "headless":
		return ResourceLoader.exists(stream_path)
	return get_or_load_stream(stream_path) != null


func _play_approved_cue(cue_res: Dictionary) -> Dictionary:
	if not bool(cue_res.get("played", false)):
		return cue_res
	var path: String = String(cue_res.get("path", ""))
	if not _has_valid_stream(path):
		return cue_res

	var player_idx: int = _acquire_sfx_player_index()
	if player_idx >= 0 and player_idx < _sfx_players.size():
		var player: AudioStreamPlayer = _sfx_players[player_idx]
		var active_dur: float = float(cue_res.get("active_duration", 1.0))
		var cue_id: String = String(cue_res.get("cue_id", ""))
		if DisplayServer.get_name() != "headless":
			var stream: AudioStream = get_or_load_stream(path)
			if stream != null:
				player.stop()
				player.stream = stream
				player.volume_db = float(cue_res.get("volume_db", -6.0))
				player.pitch_scale = float(cue_res.get("pitch_scale", 1.0))
				player.play()
		# Cap playback tail for short rapid-fire sounds so long silence/reverb tails free voices promptly
		if active_dur <= 0.60 or cue_id == _AudioBalance.CUE_PROJECTILE_FIRE or cue_id == _AudioBalance.CUE_PROJECTILE_HIT or cue_id == _AudioBalance.CUE_MOB_HIT:
			_sfx_remaining_time[player_idx] = active_dur + 0.18
		else:
			_sfx_remaining_time[player_idx] = active_dur

	cue_played.emit(cue_res)
	return cue_res


func _acquire_sfx_player_index() -> int:
	_ensure_initialized()
	var count: int = _sfx_players.size()
	if count == 0:
		return -1
	for offset in range(count):
		var idx: int = (_next_player_cursor + offset) % count
		if not _sfx_players[idx].playing and _sfx_remaining_time[idx] <= 0.0:
			_next_player_cursor = (idx + 1) % count
			return idx
	var steal_idx: int = _next_player_cursor % count
	_next_player_cursor = (steal_idx + 1) % count
	return steal_idx


## Starts or switches the looping environment ambience for [param biome_id].
func play_environment_for_biome(biome_id: String = "urban_center") -> bool:
	_ensure_initialized()
	var env_cue_id: String = balance.get_environment_cue_for_biome(biome_id)
	var cfg: Dictionary = balance.get_cue_config(env_cue_id)
	if cfg.is_empty():
		return false
	var path: String = String(cfg.get("path", ""))
	if not _has_valid_stream(path) or _environment_player == null:
		return false

	if active_environment_cue_id == env_cue_id and _environment_playing and _environment_stream_path == path:
		return true

	active_environment_cue_id = env_cue_id
	_environment_stream_path = path
	_sync_environment_player_volume()
	_environment_player.pitch_scale = 1.0
	if _AudioSettings.is_scale_muted(audio_settings.background_volume):
		_environment_playing = false
		if _environment_player.playing:
			_environment_player.stop()
	else:
		_environment_playing = true
		if DisplayServer.get_name() != "headless":
			var stream: AudioStream = get_or_load_stream(path)
			if stream != null:
				_environment_player.stream = stream
				_environment_player.play()
	environment_started.emit(env_cue_id, path)
	return true


func _sync_environment_player_volume() -> void:
	if _environment_player == null or balance == null:
		return
	var cfg: Dictionary = balance.get_cue_config(active_environment_cue_id if not active_environment_cue_id.is_empty() else _AudioBalance.CUE_ENVIRONMENT_URBAN)
	var base_db: float = float(cfg.get("volume_db", balance.environment_volume_db))
	var bg_scale: int = audio_settings.background_volume if audio_settings != null else _AudioSettings.DEFAULT_BACKGROUND_VOLUME
	if _AudioSettings.is_scale_muted(bg_scale):
		_environment_player.volume_db = _AudioSettings.MUTED_DB
	else:
		_environment_player.volume_db = base_db + _AudioSettings.scale_to_db_offset(bg_scale)


## Applies updated Background Audio (0..100) and FX Audio (0..100) volumes live.
func apply_audio_volumes(bg_vol: int, fx_vol: int) -> void:
	_ensure_initialized()
	var clamped_bg: int = _AudioSettings.clamp_scale(bg_vol)
	var clamped_fx: int = _AudioSettings.clamp_scale(fx_vol)
	audio_settings.background_volume = clamped_bg
	audio_settings.fx_volume = clamped_fx
	if cue_system != null:
		cue_system.set_background_volume_scale(clamped_bg)
		cue_system.set_fx_volume_scale(clamped_fx)

	_sync_environment_player_volume()
	if _AudioSettings.is_scale_muted(clamped_bg):
		_environment_playing = false
		if _environment_player != null and _environment_player.playing:
			_environment_player.stop()
	elif not active_environment_cue_id.is_empty():
		_environment_playing = true
		if DisplayServer.get_name() != "headless" and _environment_player != null and not _environment_player.playing:
			var stream: AudioStream = get_or_load_stream(_environment_stream_path)
			if stream != null:
				_environment_player.stream = stream
				_environment_player.play()

	if _AudioSettings.is_scale_muted(clamped_fx):
		for i in range(_sfx_players.size()):
			_sfx_remaining_time[i] = 0.0
			if is_instance_valid(_sfx_players[i]) and _sfx_players[i].playing:
				_sfx_players[i].stop()


func get_environment_volume_db() -> float:
	if _environment_player == null:
		return _AudioSettings.MUTED_DB
	return _environment_player.volume_db


func _on_audio_settings_changed(bg_vol: int, fx_vol: int) -> void:
	apply_audio_volumes(bg_vol, fx_vol)


func stop_environment() -> void:
	if _environment_player != null and _environment_player.playing:
		_environment_player.stop()
	_environment_playing = false
	active_environment_cue_id = ""


func is_environment_playing() -> bool:
	return _environment_playing or (_environment_player != null and _environment_player.playing)


func get_environment_stream_path() -> String:
	if not _environment_stream_path.is_empty():
		return _environment_stream_path
	if _environment_player == null or _environment_player.stream == null:
		return ""
	return _environment_player.stream.resource_path


func _on_environment_player_finished() -> void:
	if not active_environment_cue_id.is_empty() and _environment_player != null and _environment_player.stream != null:
		_environment_player.play()


# --- Public Trigger API ------------------------------------------------------

func play_projectile_fired(tower_type: String, damage_tag: int = 0) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_projectile_fired(tower_type, damage_tag))


func play_projectile_hit(tower_type: String = "", damage_tag: int = 0) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_projectile_hit(tower_type, damage_tag))


func play_tower_constructed(tower_type: String, hex: Vector2i = Vector2i.ZERO) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_tower_constructed(tower_type, hex))


func play_tower_cooldown_used(tower_id: int, tower_type: String, ability_id: String, hex: Vector2i = Vector2i.ZERO) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_tower_cooldown_used(tower_id, tower_type, ability_id, hex))


func play_tower_upgraded(tower_type: String, node_id: String) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_tower_upgraded(tower_type, node_id))


func play_unit_hit(unit_id: int, unit_tags: Array, amount: float = 0.0, damage_tag: int = 0) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_unit_hit(unit_id, unit_tags, amount, damage_tag))


func play_enemy_died(unit_id: int, is_boss_override: bool = false) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_enemy_died(unit_id, is_boss_override))


func play_boss_died(wave_number: int) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_boss_died(wave_number))


func play_ability_telegraphed(event: Dictionary) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_ability_telegraphed(event))


func play_wave_started(wave_number: int) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_wave_started(wave_number))


func play_wave_ended(wave_number: int) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_wave_ended(wave_number))


func play_run_event(event_id: String) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_run_event(event_id))


func play_path_extended(growth_result: Dictionary = {}) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_path_extended(growth_result))


func play_enemy_leaked(unit_id: int, leak_cost: int) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_enemy_leaked(unit_id, leak_cost))


func play_game_over() -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_game_over())


func play_tower_sold(tower_id: int, hex: Vector2i = Vector2i.ZERO) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_tower_sold(tower_id, hex))


func play_tower_maintained(tower_id: int) -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_tower_maintained(tower_id))


func play_penance() -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_penance())


func play_ui_click() -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_ui_click())


func play_ui_error(reason: String = "") -> Dictionary:
	_ensure_initialized()
	return _play_approved_cue(cue_system.on_ui_error(reason))


# --- Signal Callbacks --------------------------------------------------------

func _on_game_state_changed(old_state: int, new_state: int) -> void:
	if new_state == 0 or (old_state == 0 and new_state == 1):
		var gs: Node = get_node_or_null("/root/GameState")
		if gs != null and cue_system != null:
			cue_system.reset(int(gs.get("run_seed")))


func _on_tower_placed_on_hex(inst: TowerInstance) -> void:
	if inst != null:
		play_tower_constructed(inst.get_type_id(), inst.hex)


func _on_tower_upgraded_on_hex(inst: TowerInstance, node_id: String) -> void:
	if inst != null:
		play_tower_upgraded(inst.get_type_id(), node_id)


func _on_tower_sold_from_hex(tower_id: int, hex: Vector2i, _refund: Dictionary) -> void:
	play_tower_sold(tower_id, hex)


func _on_tower_maintained(inst: TowerInstance) -> void:
	play_tower_maintained(inst.tower_id if inst != null else 0)


func _on_tower_cooldown_used(tower_id: int, tower_type: String, ability_id: String, hex: Vector2i) -> void:
	play_tower_cooldown_used(tower_id, tower_type, ability_id, hex)


func _on_penance_performed(_corruption: int) -> void:
	play_penance()


func _on_tower_damaged_enemy(
	_tower_id: int,
	_tower_type: String,
	unit_id: int,
	unit_tags: Array,
	amount: float,
	damage_tag: int
) -> void:
	# Skip microscopic per-frame DoT sub-ticks (e.g. 6 DPS * 0.033s = 0.2 dmg) and continuous DoT/puddle ticks
	if amount < 0.75:
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		var tsys: TowerSystem = gs.get("tower_system") as TowerSystem
		if tsys != null and tsys._in_continuous_dot_tick:
			return
	play_unit_hit(unit_id, unit_tags, amount, damage_tag)


func _on_enemy_spawned(unit: CombatUnit) -> void:
	if unit != null and cue_system != null:
		cue_system.register_spawned_unit(unit.unit_id, unit.is_boss())


func _on_enemy_died(unit_id: int) -> void:
	var is_boss: bool = cue_system.is_registered_boss(unit_id) if cue_system != null else false
	play_enemy_died(unit_id, is_boss)


func _on_boss_killed(wave_number: int) -> void:
	play_boss_died(wave_number)


func _on_enemy_leaked(unit_id: int, leak_cost: int) -> void:
	if leak_cost > 0:
		play_enemy_leaked(unit_id, leak_cost)


func _on_ability_telegraphed(event: Dictionary) -> void:
	play_ability_telegraphed(event)


func _on_wave_started(wave_number: int) -> void:
	play_wave_started(wave_number)


func _on_wave_ended(wave_number: int) -> void:
	play_wave_ended(wave_number)


func _on_event_triggered(event_id: String, _display_name: String, _category: int, _banner_text: String, _banner_color: Color) -> void:
	play_run_event(event_id)


func _on_path_extended(growth_result: Dictionary) -> void:
	play_path_extended(growth_result)


func _on_loss_report_ready(_report: Variant) -> void:
	play_game_over()


func _on_biome_changed(biome: BiomeData) -> void:
	var bid: String = biome.id if biome != null else "urban_center"
	play_environment_for_biome(bid)


func _on_effects_projectile_fired(_from_w: Vector3, _to_w: Vector3, tower_type: String, damage_tag: int) -> void:
	play_projectile_fired(tower_type, damage_tag)


func _on_effects_projectile_hit(_world_pos: Vector3, tower_type: String, damage_tag: int) -> void:
	play_projectile_hit(tower_type, damage_tag)
