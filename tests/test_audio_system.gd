## Headless Test Suite for AudioBalanceData, AudioCueSystem, Tower Cooldown Audio Hooks, and SoundManager
extends Node

const _C = preload("res://scripts/path/path_constants.gd")
const _HexGrid = preload("res://scripts/path/hex_grid.gd")
const _TowerSystem = preload("res://scripts/towers/tower_system.gd")
const _AudioBalance = preload("res://scripts/audio/audio_balance_data.gd")
const _AudioCueSystem = preload("res://scripts/audio/audio_cue_system.gd")
const _AudioSettings = preload("res://scripts/audio/audio_settings.gd")
const _SoundManager = preload("res://scripts/audio/sound_manager.gd")


# --- Test 1: Resource & Stream Validation ------------------------------------

func test_01_audio_balance_resource_and_all_wav_files_load() -> void:
	var bal := load(_AudioBalance.DEFAULT_RESOURCE_PATH) as AudioBalanceData
	assert(bal != null, "res://data/audio_balance.tres must load as AudioBalanceData")
	assert(not bal.cues.is_empty(), "AudioBalanceData.cues must not be empty")

	var required_cues: Array[String] = [
		_AudioBalance.CUE_PROJECTILE_FIRE,
		_AudioBalance.CUE_PROJECTILE_FIRE_SNIPER,
		_AudioBalance.CUE_PROJECTILE_FIRE_CENSER,
		_AudioBalance.CUE_PROJECTILE_HIT,
		_AudioBalance.CUE_TOWER_CONSTRUCT,
		_AudioBalance.CUE_TOWER_CD_DEFAULT,
		_AudioBalance.CUE_TOWER_CD_CONGREGATION_RESPAWN,
		_AudioBalance.CUE_TOWER_CD_TENTACLE_ROOT,
		_AudioBalance.CUE_TOWER_CD_LEVIATHAN_SWEEP,
		_AudioBalance.CUE_TOWER_CD_GUTTER_PULSE,
		_AudioBalance.CUE_TOWER_CD_MAW_BENEATH,
		_AudioBalance.CUE_TOWER_CD_CHOIR_SPECIAL,
		_AudioBalance.CUE_TOWER_CD_SHRINE_BURST,
		_AudioBalance.CUE_TOWER_UPGRADE,
		_AudioBalance.CUE_MOB_HIT,
		_AudioBalance.CUE_MOB_DEATH,
		_AudioBalance.CUE_BOSS_HIT,
		_AudioBalance.CUE_BOSS_DEATH,
		_AudioBalance.CUE_BOSS_SPECIAL_ABILITY,
		_AudioBalance.CUE_ENVIRONMENT_URBAN,
		_AudioBalance.CUE_WAVE_STARTED,
		_AudioBalance.CUE_WAVE_ENDED,
		_AudioBalance.CUE_STARS_ARE_RIGHT,
		_AudioBalance.CUE_PATH_EXTENDED,
		_AudioBalance.CUE_ENEMY_LEAKED,
		_AudioBalance.CUE_GAME_OVER,
		_AudioBalance.CUE_TOWER_SOLD,
		_AudioBalance.CUE_TOWER_MAINTAINED,
		_AudioBalance.CUE_PENANCE,
		_AudioBalance.CUE_ENEMY_ABILITY,
		_AudioBalance.CUE_UI_CLICK,
		_AudioBalance.CUE_UI_ERROR,
	]

	for cue_id: String in required_cues:
		var cfg: Dictionary = bal.get_cue_config(cue_id)
		assert(not cfg.is_empty(), "Missing cue configuration for '%s'" % cue_id)
		var path: String = String(cfg.get("path", ""))
		assert(not path.is_empty(), "Empty stream path for cue '%s'" % cue_id)
		assert(ResourceLoader.exists(path), "Audio file does not exist for cue '%s': %s" % [cue_id, path])
		var stream: AudioStream = load(path) as AudioStream
		assert(stream != null, "Failed to load AudioStream for cue '%s': %s" % [cue_id, path])


# --- Test 2: Anti-Clutter Rate Limiting, Voice Caps & Polyphony Ducking ------

func test_02_rapid_fire_rate_limiting_voice_caps_and_volume_ducking() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var sys := _AudioCueSystem.new(null, rng)

	# 1. Rapid projectile fire must be short, attenuated, and rate-limited within min_interval
	var first_shot: Dictionary = sys.on_projectile_fired("hexed_nail_gun")
	assert(bool(first_shot["played"]), "First projectile shot must play")
	assert(String(first_shot["cue_id"]) == _AudioBalance.CUE_PROJECTILE_FIRE, "Nail gun must use projectile_fire cue")
	assert(float(first_shot["volume_db"]) <= -10.0, "Rapid projectile fire must be attenuated (<= -10 dB)")

	# Immediate second shot at dt=0.01s (< 0.07s min_interval) must be suppressed by cooldown
	sys.step(0.01)
	var immediate_shot: Dictionary = sys.on_projectile_fired("hexed_nail_gun")
	assert(not bool(immediate_shot["played"]), "Shot within min_interval must be suppressed")
	assert(String(immediate_shot["reason"]) == "cooldown", "Suppression reason must be cooldown")

	# Advance past min_interval (0.08s) while first voice is still active (0.45s active_duration):
	# Second concurrent voice must play and be ducked by polyphony_attenuation_per_voice_db
	sys.step(0.08)
	var second_shot: Dictionary = sys.on_projectile_fired("hexed_nail_gun")
	assert(bool(second_shot["played"]), "Second shot after min_interval must play")
	assert(int(second_shot["concurrent_voices"]) == 2, "Second shot must report 2 concurrent voices")
	assert(
		float(second_shot["volume_db"]) < float(first_shot["volume_db"]),
		"Concurrent voice must be volume-ducked below first voice to prevent clutter"
	)

	# Third concurrent voice after another 0.08s
	sys.step(0.08)
	var third_shot: Dictionary = sys.on_projectile_fired("hexed_nail_gun")
	assert(bool(third_shot["played"]), "Third shot must play (max_voices = 3)")
	assert(int(third_shot["concurrent_voices"]) == 3, "Third shot must report 3 concurrent voices")

	# Fourth shot while all 3 voices are still active must be blocked by max_voices cap
	sys.step(0.08)
	var fourth_shot: Dictionary = sys.on_projectile_fired("hexed_nail_gun")
	assert(not bool(fourth_shot["played"]), "Fourth concurrent shot must be blocked by max_voices cap")
	assert(String(fourth_shot["reason"]) == "max_voices", "Suppression reason must be max_voices")

	# Advance past active_duration (0.50s) so voices expire and new shots can play again
	sys.step(0.50)
	var fifth_shot: Dictionary = sys.on_projectile_fired("hexed_nail_gun")
	assert(bool(fifth_shot["played"]), "Shot after active voices expire must play again")


# --- Test 3: Mob vs Boss Hit/Death & Boss Special Ability Differentiation ----

func test_03_mob_vs_boss_hit_death_and_special_abilities() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var sys := _AudioCueSystem.new(null, rng)

	# Mob hit vs Boss hit
	var mob_hit: Dictionary = sys.on_unit_hit(1001, [_C.UnitTag.GROUND], 10.0, _C.DamageTag.KINETIC)
	assert(bool(mob_hit["played"]) and String(mob_hit["cue_id"]) == _AudioBalance.CUE_MOB_HIT, "Regular unit hit must trigger mob_hit")

	var boss_hit: Dictionary = sys.on_unit_hit(2001, [_C.UnitTag.GROUND, _C.UnitTag.BOSS], 50.0, _C.DamageTag.VOID)
	assert(bool(boss_hit["played"]) and String(boss_hit["cue_id"]) == _AudioBalance.CUE_BOSS_HIT, "Boss unit hit must trigger boss_hit")

	# Register a regular mob (1001) and a boss (2001)
	sys.register_spawned_unit(1001, false)
	sys.register_spawned_unit(2001, true)

	var mob_death: Dictionary = sys.on_enemy_died(1001)
	assert(bool(mob_death["played"]) and String(mob_death["cue_id"]) == _AudioBalance.CUE_MOB_DEATH, "Regular enemy_died must trigger mob_death")

	# When a boss dies, enemy_died must NOT trigger mob_death; boss_killed triggers boss_death
	var boss_enemy_died: Dictionary = sys.on_enemy_died(2001)
	assert(not bool(boss_enemy_died["played"]), "Boss enemy_died must suppress mob_death so boss_death plays cleanly")
	assert(String(boss_enemy_died["reason"]) == "boss_uses_boss_death", "Suppression reason must be boss_uses_boss_death")

	var boss_death: Dictionary = sys.on_boss_died(10)
	assert(bool(boss_death["played"]) and String(boss_death["cue_id"]) == _AudioBalance.CUE_BOSS_DEATH, "boss_killed must trigger boss_death")

	# Boss special ability vs regular enemy ability telegraph
	for boss_ab: String in ["SurgePricing", "Restructuring", "LeveragedBuyout", "SameDayDelivery", "HoldingCompany"]:
		sys.step(1.50)
		var b_ev: Dictionary = sys.on_ability_telegraphed({"ability_id": boss_ab, "unit_id": 2001})
		assert(
			bool(b_ev["played"]) and String(b_ev["cue_id"]) == _AudioBalance.CUE_BOSS_SPECIAL_ABILITY,
			"Boss ability '%s' must trigger boss_special_ability" % boss_ab
		)

	sys.step(0.50)
	var reg_ev: Dictionary = sys.on_ability_telegraphed({"ability_id": "TowerDisable", "unit_id": 1002})
	assert(
		bool(reg_ev["played"]) and String(reg_ev["cue_id"]) == _AudioBalance.CUE_ENEMY_ABILITY,
		"Regular enemy ability must trigger enemy_ability cue"
	)


# --- Test 4: Tower Cooldown Usage Events in TowerSystem ----------------------

func test_04_tower_system_emits_cooldown_events_for_tentacle_root_and_congregation_respawn() -> void:
	var grid := _HexGrid.new(99, _C.CHUNK_RADIUS, 0.0)
	var path: Array[Vector2i] = []
	for i in range(10):
		path.append(Vector2i(i, 0))
	var tsys := _TowerSystem.new(grid, path)
	tsys.offerings = 5000
	tsys.scrap = 5000

	var cd_events: Array[Dictionary] = []
	tsys.tower_cooldown_used.connect(func(tid: int, ttype: String, ab_id: String, hex: Vector2i) -> void:
		cd_events.append({
			"tower_id": tid,
			"tower_type": ttype,
			"ability_id": ab_id,
			"hex": hex,
		})
	)

	var cue_sys := _AudioCueSystem.new(null, RandomNumberGenerator.new(), 99)

	# 1. Place Tentacle Storm Drain adjacent to path and spawn a target in range
	var drain: TowerInstance = tsys.place_tower(Vector2i(3, 1), "tentacle_storm_drain", true)
	assert(drain != null, "Must place tentacle_storm_drain")
	var dummy: CombatUnit = tsys.spawn_unit(500.0, [_C.UnitTag.GROUND], 0.0, 3.0)
	assert(dummy != null, "Must spawn dummy unit")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	tsys.step(0.1, rng)

	var saw_root: bool = false
	for ev: Dictionary in cd_events:
		if String(ev["tower_type"]) == "tentacle_storm_drain" and String(ev["ability_id"]) == "tentacle_root":
			saw_root = true
			var cue_res: Dictionary = cue_sys.on_tower_cooldown_used(
				int(ev["tower_id"]), String(ev["tower_type"]), String(ev["ability_id"]), ev["hex"] as Vector2i
			)
			assert(bool(cue_res["played"]), "Tentacle root cooldown cue must play")
			assert(String(cue_res["cue_id"]) == _AudioBalance.CUE_TOWER_CD_TENTACLE_ROOT, "Must map to tentacle root cue")
	assert(saw_root, "Tentacle Storm Drain must emit tower_cooldown_used on periodic root")

	# 2. Place The Congregation adjacent to path, kill a blocker, and advance 10s to trigger respawn
	var cong: TowerInstance = tsys.place_tower(Vector2i(5, 1), "the_congregation", true)
	assert(cong != null and not cong.active_blockers.is_empty(), "Must place the_congregation with active blockers")
	tsys._kill_congregation_blocker(cong, 0, Vector2i(5, 0))
	assert(cong.resummon_timers.size() == 1, "Killed blocker must start a 10s resummon timer")

	for _step_i in range(105):
		cue_sys.step(0.1)
		tsys.step(0.1, rng)

	var saw_respawn: bool = false
	for ev: Dictionary in cd_events:
		if String(ev["tower_type"]) == "the_congregation" and String(ev["ability_id"]) == "congregation_respawn":
			saw_respawn = true
			var cue_res: Dictionary = cue_sys.on_tower_cooldown_used(
				int(ev["tower_id"]), String(ev["tower_type"]), String(ev["ability_id"]), ev["hex"] as Vector2i
			)
			assert(bool(cue_res["played"]), "Congregation respawn cooldown cue must play")
			assert(
				String(cue_res["cue_id"]) == _AudioBalance.CUE_TOWER_CD_CONGREGATION_RESPAWN,
				"Must map to congregation respawn cue (Magic/Resurrection.wav)"
			)
	assert(saw_respawn, "The Congregation must emit tower_cooldown_used when a blocker respawns")


# --- Test 5: SoundManager Scene Integration & Urban Environment Loop ---------

func test_05_sound_manager_in_main_scene_and_urban_environment_loop() -> void:
	var main_packed := load("res://scenes/main.tscn") as PackedScene
	assert(main_packed != null, "res://scenes/main.tscn must load")
	var main_inst: Node = main_packed.instantiate()
	add_child(main_inst)

	var sm: SoundManager = main_inst.get_node_or_null("SoundManager") as SoundManager
	assert(sm != null, "Main scene must contain a SoundManager node")
	assert(sm.is_environment_playing(), "SoundManager must start the urban environment loop on ready")
	assert(
		sm.active_environment_cue_id == _AudioBalance.CUE_ENVIRONMENT_URBAN,
		"Active environment cue must be environment_urban"
	)
	assert(
		sm.get_environment_stream_path().ends_with("Rainy City Alley Loop.wav"),
		"Urban environment stream must be Rainy City Alley Loop.wav"
	)

	# Trigger construction & upgrade via GameState and verify SoundManager logs the cues
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		var tsys: TowerSystem = gs.get("tower_system") as TowerSystem
		var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
		if tsys != null and pgen != null:
			var build_hex: Vector2i = Vector2i.ZERO
			for q in range(-8, 9):
				for r in range(-8, 9):
					var cand := Vector2i(q, r)
					var check: Dictionary = gs.call("validate_placement", cand, "hexed_nail_gun")
					if bool(check.get("ok", false)):
						build_hex = cand
						break
				if build_hex != Vector2i.ZERO:
					break
			if build_hex != Vector2i.ZERO:
				var placed: TowerInstance = gs.call("request_place_tower", build_hex, "hexed_nail_gun") as TowerInstance
				assert(placed != null, "Must place hexed_nail_gun on valid hex")
				var upgraded: bool = bool(gs.call("request_upgrade_tower", placed, "rapid_cycling"))
				assert(upgraded, "Must upgrade hexed_nail_gun to T2 rapid_cycling")

				var played_ids: Array[String] = []
				for entry: Dictionary in sm.cue_system.cue_log:
					played_ids.append(String(entry.get("cue_id", "")))
				assert(played_ids.has(_AudioBalance.CUE_TOWER_CONSTRUCT), "Placing tower must play tower_construct cue")
				assert(played_ids.has(_AudioBalance.CUE_TOWER_UPGRADE), "Upgrading tower must play tower_upgrade cue")

	remove_child(main_inst)
	main_inst.free()


# --- Test 6: SettingsMenu Audio Sliders (0-100, 0 = Muted) & Live Sync -------

func test_06_audio_settings_sliders_0_to_100_mute_at_0_and_live_sync_with_sound_manager() -> void:
	var test_cfg_path: String = "user://test_audio_settings.cfg"
	if FileAccess.file_exists(test_cfg_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_cfg_path))
	if FileAccess.file_exists(_AudioSettings.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_AudioSettings.SAVE_PATH))

	var main_packed := load("res://scenes/main.tscn") as PackedScene
	assert(main_packed != null, "res://scenes/main.tscn must load")
	var main_inst: Node = main_packed.instantiate()
	add_child(main_inst)

	var sm: SoundManager = main_inst.get_node_or_null("SoundManager") as SoundManager
	var in_game_menu: InGameMenu = main_inst.get_node_or_null("HUD/InGameMenu") as InGameMenu
	assert(sm != null and in_game_menu != null, "Main must have SoundManager and HUD/InGameMenu")

	var settings_menu: SettingsMenu = in_game_menu.get_settings_menu()
	assert(settings_menu != null, "InGameMenu must have a SettingsMenu")
	settings_menu.audio_settings.save_path = test_cfg_path
	sm.audio_settings.save_path = test_cfg_path

	var bg_slider: HSlider = settings_menu.get_node_or_null("VBox/BackgroundAudioRow/BackgroundAudioSlider") as HSlider
	var bg_val_lbl: Label = settings_menu.get_node_or_null("VBox/BackgroundAudioRow/BackgroundAudioValueLabel") as Label
	var fx_slider: HSlider = settings_menu.get_node_or_null("VBox/FxAudioRow/FxAudioSlider") as HSlider
	var fx_val_lbl: Label = settings_menu.get_node_or_null("VBox/FxAudioRow/FxAudioValueLabel") as Label

	assert(bg_slider != null and bg_val_lbl != null, "SettingsMenu must have BackgroundAudioSlider and BackgroundAudioValueLabel")
	assert(fx_slider != null and fx_slider != null and fx_val_lbl != null, "SettingsMenu must have FxAudioSlider and FxAudioValueLabel")
	assert(is_equal_approx(bg_slider.min_value, 0.0) and is_equal_approx(bg_slider.max_value, 100.0), "BackgroundAudioSlider range must be 0..100")
	assert(is_equal_approx(fx_slider.min_value, 0.0) and is_equal_approx(fx_slider.max_value, 100.0), "FxAudioSlider range must be 0..100")
	assert(int(bg_slider.value) == 100 and bg_val_lbl.text == "100%", "Background audio must default to 100%")
	assert(int(fx_slider.value) == 100 and fx_val_lbl.text == "100%", "FX audio must default to 100%")

	var env_vol_at_100: float = sm.get_environment_volume_db()
	assert(sm.is_environment_playing(), "Environment audio must be playing at 100%")

	# 1. Adjust Background Audio slider to 50 -> attenuates by ~6.02 dB
	bg_slider.value = 50.0
	assert(settings_menu.get_background_volume() == 50, "Background volume must update to 50")
	assert(bg_val_lbl.text == "50%", "Background value label must show '50%'")
	var env_vol_at_50: float = sm.get_environment_volume_db()
	assert(env_vol_at_50 < env_vol_at_100 - 5.5, "Environment dB at 50% must be ~6 dB lower than at 100%")
	assert(sm.is_environment_playing(), "Environment audio must still play at 50%")

	# 2. Adjust Background Audio slider to 0 -> Muted
	bg_slider.value = 0.0
	assert(settings_menu.get_background_volume() == 0, "Background volume must update to 0")
	assert(bg_val_lbl.text == "0% (Muted)", "Background value label at 0 must show '0% (Muted)'")
	assert(not sm.is_environment_playing(), "Environment loop must stop/mute when Background Audio is 0")
	assert(is_equal_approx(sm.get_environment_volume_db(), _AudioSettings.MUTED_DB), "Environment dB must be MUTED_DB at 0")

	# 3. Restore Background Audio slider to 80 -> resumes playing
	bg_slider.value = 80.0
	assert(bg_val_lbl.text == "80%", "Background value label must show '80%'")
	assert(sm.is_environment_playing(), "Environment loop must resume when Background Audio is raised above 0")

	# 4. Adjust FX Audio slider to 50 -> attenuates FX cues; then 0 -> Mutes FX cues
	sm.cue_system.step(2.0)
	fx_slider.value = 100.0
	var fx_100: Dictionary = sm.play_tower_constructed("hexed_nail_gun")
	assert(bool(fx_100["played"]), "FX must play at 100%")

	sm.cue_system.step(2.0)
	fx_slider.value = 50.0
	assert(fx_val_lbl.text == "50%", "FX value label must show '50%'")
	var fx_50: Dictionary = sm.play_tower_constructed("hexed_nail_gun")
	assert(bool(fx_50["played"]), "FX must play at 50%")
	assert(float(fx_50["volume_db"]) < float(fx_100["volume_db"]) - 5.5, "FX dB at 50% must be ~6 dB lower than at 100%")

	sm.cue_system.step(2.0)
	fx_slider.value = 0.0
	assert(fx_val_lbl.text == "0% (Muted)", "FX value label at 0 must show '0% (Muted)'")
	var fx_muted: Dictionary = sm.play_tower_constructed("hexed_nail_gun")
	assert(not bool(fx_muted["played"]) and String(fx_muted["reason"]) == "muted", "FX at 0 must be muted")

	# 5. Verify persistence round-trip via ConfigFile
	fx_slider.value = 65.0
	var reloaded := _AudioSettings.new()
	reloaded.save_path = test_cfg_path
	reloaded.load_or_default()
	assert(reloaded.background_volume == 80, "Saved background_volume (80) must reload from disk")
	assert(reloaded.fx_volume == 65, "Saved fx_volume (65) must reload from disk")

	# Reset defaults and clean up test config file
	settings_menu.set_background_volume(100, false)
	settings_menu.set_fx_volume(100, false)
	if FileAccess.file_exists(test_cfg_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_cfg_path))
	if FileAccess.file_exists(_AudioSettings.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_AudioSettings.SAVE_PATH))

	remove_child(main_inst)
	main_inst.free()
