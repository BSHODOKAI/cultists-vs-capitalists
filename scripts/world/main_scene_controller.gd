## MainSceneController
##
## Root controller for res://scenes/main.tscn.
## Coordinates GameWorld (TerrainView, PathView, OverlayView, Towers, Enemies,
## Effects, CameraRig), HUD (TopBar, BuildPalette, TowerPanel, IntelPanel,
## WaveControls, BossBar, TelegraphLayer, GameOverScreen), DebugPanel,
## mouse ray-to-ground hex picking, and hotkeys (1-9, Space, P, Q/W/E, Home, End, Esc).
class_name MainSceneController
extends Node

const _HexMath = preload("res://scripts/core/hex_math.gd")
const _TowerFactory = preload("res://scripts/world/tower_factory.gd")
const _EnemyVisualPool = preload("res://scripts/world/enemy_visual_pool.gd")
const _SoundManager = preload("res://scripts/audio/sound_manager.gd")

@onready var game_world: Node3D = $GameWorld
@onready var terrain_view: TerrainView = $GameWorld/TerrainView
@onready var path_view: PathView = $GameWorld/PathView
@onready var overlay_view: OverlayView = $GameWorld/OverlayView
@onready var towers_container: Node3D = $GameWorld/Towers
@onready var enemies_container: Node3D = $GameWorld/Enemies
@onready var effects_view: CombatEffectsView = $GameWorld/Effects
@onready var camera_rig: CameraRig = $GameWorld/CameraRig

@onready var hud: CanvasLayer = $HUD
@onready var top_bar: TopBar = $HUD/TopBar
@onready var build_palette: BuildPalette = $HUD/BuildPalette
@onready var tower_panel: TowerPanel = $HUD/TowerPanel
@onready var intel_panel: IntelPanel = $HUD/IntelPanel
@onready var wave_controls: WaveControls = $HUD/WaveControls
@onready var boss_bar: BossBar = $HUD/BossBar
@onready var telegraph_layer: TelegraphLayer = $HUD/TelegraphLayer
@onready var game_over_screen: GameOverScreen = $HUD/GameOverScreen
@onready var in_game_menu: InGameMenu = get_node_or_null("HUD/InGameMenu") as InGameMenu
@onready var debug_panel: DebugPanel = $DebugPanel
@onready var sound_manager: SoundManager = get_node_or_null("SoundManager") as SoundManager

var tower_factory: TowerFactory
var enemy_pool: EnemyVisualPool
var theme_data: VisualThemeData
var _kill_labels_this_frame: int = 0
var _projectiles_this_frame: int = 0
## tower_id -> Array[Dictionary] of {"id": int, "pos": Vector3} hit by that tower's chain arcs this frame.
## The hit-time position is remembered so a target that dies mid-arc leaves the bolt lingering where it died.
var _chain_hits_by_tower: Dictionary = {}


func _ready() -> void:
	theme_data = load("res://data/visual_theme.tres") as VisualThemeData
	tower_factory = _TowerFactory.new(towers_container, theme_data)
	enemy_pool = _EnemyVisualPool.new(enemies_container, theme_data)

	if sound_manager == null:
		sound_manager = _SoundManager.new()
		sound_manager.name = "SoundManager"
		add_child(sound_manager)

	_connect_signals()

	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		sound_manager.bind_to_game_state(gs)
		gs.call("start_new_run", -1)
		_rebuild_world_views()
		if camera_rig != null:
			camera_rig.focus_base()
	if effects_view != null:
		sound_manager.bind_to_effects_view(effects_view)
	if hud != null:
		sound_manager.bind_ui_buttons(hud)


func _connect_signals() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return

	gs.connect("state_changed", _on_state_changed)
	gs.connect("path_extended", func(_r: Dictionary) -> void: _rebuild_world_views())
	gs.connect("path_preview_ready", func(_p: Dictionary) -> void: _rebuild_world_views())
	if gs.has_signal("fork_preview_ready"):
		gs.connect("fork_preview_ready", func(_c: Array, _idx: int) -> void: _rebuild_world_views())
	if gs.has_signal("fork_candidate_selected"):
		gs.connect("fork_candidate_selected", func(_idx: int, _cand: Dictionary) -> void: _rebuild_world_views())
	if gs.has_signal("lane_bounty_claimed"):
		gs.connect("lane_bounty_claimed", _on_lane_bounty_claimed)
	gs.connect("tower_placed_on_hex", _on_tower_placed)
	gs.connect("tower_upgraded_on_hex", _on_tower_upgraded)
	gs.connect("tower_sold_from_hex", _on_tower_sold)
	gs.connect("tower_maintained", _on_tower_maintained)
	gs.connect("selected_tower_changed", func(_t: Variant) -> void: _refresh_hover_only())
	gs.connect("build_mode_changed", func(_td: Variant) -> void: _refresh_hover_and_overlays())
	gs.connect("enemy_spawned", _on_enemy_spawned)
	gs.connect("enemy_died", _on_enemy_died)
	gs.connect("tower_damaged_enemy", _on_tower_damaged_enemy)
	gs.connect("tower_cooldown_used", _on_tower_cooldown_used)
	gs.connect("currency_earned", _on_currency_earned)
	if gs.has_signal("currency_flow_recorded"):
		gs.connect("currency_flow_recorded", _on_currency_flow_recorded)
	gs.connect("ability_telegraphed", _on_ability_telegraphed)
	gs.connect("camera_focus_requested", func(wp: Vector3, _lbl: String) -> void:
		if camera_rig != null:
			camera_rig.focus_world(wp)
	)

	if camera_rig != null:
		camera_rig.view_moved.connect(func(_fw: Vector3, fh: Vector2i, _z: float) -> void:
			if terrain_view != null:
				terrain_view.refresh_around_hex(fh, 1, false)
		)


func _process(_delta: float) -> void:
	_kill_labels_this_frame = 0
	_projectiles_this_frame = 0
	_flush_chain_lightning()
	var gs: Node = get_node_or_null("/root/GameState")
	var clock: Node = get_node_or_null("/root/SimClock")
	if gs == null:
		return

	var tsys: TowerSystem = gs.get("tower_system") as TowerSystem
	var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
	if tsys == null or pgen == null:
		return

	var alpha: float = float(clock.get("interpolation_alpha")) if clock != null else 1.0
	var prev_pos: Dictionary = gs.get("prev_unit_positions") as Dictionary

	if enemy_pool != null:
		enemy_pool.update_all_views(tsys.units, pgen.path_hexes, prev_pos, alpha, pgen.lanes)
	if tower_factory != null:
		tower_factory.update_all_statuses()
	if effects_view != null:
		effects_view.sync_puddles(tsys.puddles)
	if boss_bar != null:
		boss_bar.update_from_units(tsys.units)


func _unhandled_input(event: InputEvent) -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	var clock: Node = get_node_or_null("/root/SimClock")
	if gs == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var ke_esc: InputEventKey = event as InputEventKey
		if ke_esc.keycode == KEY_ESCAPE or ke_esc.physical_keycode == KEY_ESCAPE:
			handle_escape()
			get_viewport().set_input_as_handled()
			return

	if in_game_menu != null and in_game_menu.is_menu_open():
		return

	# Touchscreen tap & drag handling (delegates drag panning to CameraRig; taps select/place on release)
	if event is InputEventScreenDrag and camera_rig != null:
		if camera_rig._last_handled_touch_event != event:
			camera_rig._unhandled_input(event)
		return

	if event is InputEventScreenTouch and camera_rig != null:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if camera_rig._last_handled_touch_event != event:
			camera_rig._unhandled_input(event)
		if camera_rig._last_touch_event_consumed:
			return
		if st.pressed:
			var touched_hex: Variant = camera_rig.pick_hex_at_screen(st.position)
			if touched_hex != null:
				gs.set("hovered_hex", touched_hex as Vector2i)
				gs.set("has_hovered_hex", true)
			else:
				gs.set("has_hovered_hex", false)
			_refresh_hover_only()
		elif not st.canceled:
			_handle_hex_tap_or_click(st.position, false, gs)
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
		return

	# Mouse motion -> update hovered hex via camera ray to Y = 0 (ignore touch-emulated motion during touch)
	if event is InputEventMouseMotion and camera_rig != null:
		if event.device == InputEvent.DEVICE_ID_EMULATION or camera_rig.has_active_touch():
			return
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var picked: Variant = camera_rig.pick_hex_at_screen(mm.position)
		var new_has_hover: bool = (picked != null)
		var new_hover_hex: Vector2i = (picked as Vector2i) if new_has_hover else Vector2i.ZERO
		var old_has_hover: bool = bool(gs.get("has_hovered_hex"))
		var old_hover_hex: Vector2i = gs.get("hovered_hex") as Vector2i
		if new_has_hover != old_has_hover or (new_has_hover and new_hover_hex != old_hover_hex):
			gs.set("hovered_hex", new_hover_hex)
			gs.set("has_hovered_hex", new_has_hover)
			_refresh_hover_only()

	# Mouse button clicks on the hex grid (ignore touch-emulated left clicks; touch taps fire on release above)
	if event is InputEventMouseButton and event.pressed and camera_rig != null:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION or camera_rig.has_active_touch():
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if gs.get("selected_build_tower") != null:
				gs.call("cancel_build_mode")
				get_viewport().set_input_as_handled()
				return
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if _handle_hex_tap_or_click(mb.position, mb.shift_pressed, gs):
				get_viewport().set_input_as_handled()
				return

	# Keyboard hotkeys: B build menu, 1-9 towers, Enter confirm build, Space start wave, P pause, Q/W/E speed 1x/2x/3x, Esc cancel/menu
	if event.is_action_pressed(&"toggle_tower_menu"):
		if build_palette != null:
			build_palette.toggle_menu()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_B or ke.physical_keycode == KEY_B:
			if build_palette != null:
				build_palette.toggle_menu()
			get_viewport().set_input_as_handled()
		elif ke.keycode >= KEY_1 and ke.keycode <= KEY_9:
			if build_palette != null:
				build_palette.select_hotkey(ke.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_0:
			if build_palette != null:
				build_palette.select_hotkey(9)
			get_viewport().set_input_as_handled()
		elif (ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER) and build_palette != null and build_palette.is_menu_open:
			build_palette.confirm_build()
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_SPACE:
			gs.call("start_wave")
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_P and clock != null:
			clock.call("toggle_pause")
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_Q and clock != null:
			clock.call("set_speed", 1.0)
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_W and not Input.is_physical_key_pressed(KEY_SHIFT) and clock != null:
			# Note: W also pans camera when held, but pressing Q/W/E adjusts speed per hotkey spec
			clock.call("set_speed", 2.0)
		elif ke.keycode == KEY_E and clock != null:
			clock.call("set_speed", 3.0)
			get_viewport().set_input_as_handled()


## Returns true if any item or build menu is currently selected/open.
func _handle_hex_tap_or_click(screen_pos: Vector2, keep_build_mode: bool, gs: Node) -> bool:
	if camera_rig == null or gs == null:
		return false
	var picked_hex: Variant = camera_rig.pick_hex_at_screen(screen_pos)
	if picked_hex == null:
		return false
	var hex: Vector2i = picked_hex as Vector2i
	gs.set("hovered_hex", hex)
	gs.set("has_hovered_hex", true)
	var build_def: TowerData = gs.get("selected_build_tower") as TowerData
	if build_def != null:
		var placed: TowerInstance = gs.call("request_place_tower", hex, build_def) as TowerInstance
		if placed != null:
			if not keep_build_mode:
				gs.call("cancel_build_mode")
				gs.call("select_placed_tower", placed)
		elif sound_manager != null:
			sound_manager.play_ui_error("placement_rejected")
		_refresh_hover_and_overlays()
	else:
		# Select placed tower by hex lookup (never physics picking), or select a fork candidate
		# if the player clicked anywhere along or adjacent (<= 1 hex) to a fork candidate ribbon.
		var existing: TowerInstance = gs.call("get_tower_at_hex", hex) as TowerInstance
		var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
		if existing == null and pgen != null and pgen.preview_is_fork:
			var picked_fork_idx: int = -1
			for c_idx in range(pgen.fork_candidates.size()):
				var c_nh: Array = pgen.fork_candidates[c_idx].get("new_hexes", []) as Array
				if c_nh.has(hex):
					picked_fork_idx = c_idx
					break
			if picked_fork_idx < 0:
				var best_dist: int = 2
				for c_idx in range(pgen.fork_candidates.size()):
					var c_nh: Array = pgen.fork_candidates[c_idx].get("new_hexes", []) as Array
					for fh_var: Variant in c_nh:
						var d: int = _HexMath.distance(hex, fh_var as Vector2i)
						if d < best_dist:
							best_dist = d
							picked_fork_idx = c_idx
			if picked_fork_idx >= 0:
				gs.call("request_select_fork_candidate", picked_fork_idx)
		gs.call("select_placed_tower", existing)
		_refresh_hover_and_overlays()
	return true


func has_active_selection() -> bool:
	if build_palette != null and build_palette.is_menu_open:
		return true
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.get("selected_build_tower") != null:
			return true
		if gs.get("selected_placed_tower") != null:
			return true
	return false


## Deselects any currently selected item (placed tower, active build tower, or open build menu).
## Returns true if something was deselected.
func deselect_all() -> bool:
	var had_selection: bool = false
	if build_palette != null and build_palette.is_menu_open:
		build_palette.close_menu()
		had_selection = true
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.get("selected_build_tower") != null:
			gs.call("cancel_build_mode")
			had_selection = true
		if gs.get("selected_placed_tower") != null:
			gs.call("select_placed_tower", null)
			had_selection = true
	if had_selection:
		_refresh_hover_and_overlays()
	return had_selection


## Handles Esc key press:
## - If InGameMenu is open, backs out of Display Settings or closes InGameMenu.
## - Else if anything is selected, deselects it without opening InGameMenu.
## - Else (nothing selected), opens InGameMenu.
func handle_escape() -> void:
	if in_game_menu != null and in_game_menu.is_menu_open():
		in_game_menu.handle_escape()
		return
	if deselect_all():
		return
	if in_game_menu != null:
		in_game_menu.open_menu()


func _on_state_changed(old_state: int, new_state: int) -> void:
	if new_state == 0 or (old_state == 0 and new_state == 1):
		if tower_factory != null:
			tower_factory.clear_all()
		if enemy_pool != null:
			enemy_pool.clear_all()
		if effects_view != null:
			effects_view.clear_all()
		_rebuild_world_views()


func _rebuild_world_views() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
	if pgen == null:
		return

	var focus_h: Vector2i = pgen.path_hexes[0] if not pgen.path_hexes.is_empty() else Vector2i.ZERO
	if camera_rig != null:
		focus_h = _HexMath.world_to_hex(camera_rig.global_position)

	if terrain_view != null:
		terrain_view.refresh_around_hex(focus_h, 1, true)
	if path_view != null:
		path_view.refresh_lanes(pgen.lanes)
	if overlay_view != null:
		overlay_view.refresh_path_overlays(pgen)
	_refresh_hover_and_overlays()


func _refresh_hover_only() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or overlay_view == null:
		return
	var tsys: TowerSystem = gs.get("tower_system") as TowerSystem
	var h_hex: Vector2i = gs.get("hovered_hex") as Vector2i
	var has_h: bool = bool(gs.get("has_hovered_hex"))
	var build_td: TowerData = gs.get("selected_build_tower") as TowerData
	var sel_t: TowerInstance = gs.get("selected_placed_tower") as TowerInstance

	var val: Dictionary = gs.call("validate_placement", h_hex, build_td) if build_td != null else {"ok": true, "reason": ""}
	if terrain_view != null:
		terrain_view.set_build_mode_active(build_td != null)
	overlay_view.update_hover(h_hex, has_h, build_td, val, sel_t, tsys)


func _refresh_hover_and_overlays() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or overlay_view == null:
		return
	var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
	if pgen != null:
		overlay_view.refresh_path_overlays(pgen)
	_refresh_hover_only()


func _on_tower_placed(inst: TowerInstance) -> void:
	if tower_factory != null:
		tower_factory.spawn_tower_view(inst)
	if terrain_view != null and inst != null:
		terrain_view.refresh_hex(inst.hex)
	_refresh_hover_and_overlays()


func _on_tower_upgraded(inst: TowerInstance, _node_id: String) -> void:
	if tower_factory != null:
		tower_factory.refresh_tower_view(inst)
	_refresh_hover_only()


func _on_tower_sold(tower_id: int, _hex: Vector2i, refund: Dictionary) -> void:
	if tower_factory != null:
		tower_factory.remove_tower_view(tower_id)
	if effects_view != null:
		var off_r: int = int(refund.get("offerings_refund", 0))
		var scr_r: int = int(refund.get("scrap_refund", 0))
		if off_r > 0:
			effects_view.spawn_floating_text(_HexMath.hex_to_world(_hex, 0.5), "+%d Off" % off_r, Color(0.85, 0.65, 1.0))
		if scr_r > 0:
			effects_view.spawn_floating_text(_HexMath.hex_to_world(_hex, 0.8), "+%d Scrap" % scr_r, Color(1.0, 0.65, 0.25))
	if terrain_view != null:
		terrain_view.refresh_hex(_hex)
	_refresh_hover_and_overlays()


func _on_tower_maintained(inst: TowerInstance) -> void:
	if tower_factory != null:
		tower_factory.refresh_tower_view(inst)


func _on_enemy_spawned(unit: CombatUnit) -> void:
	if enemy_pool != null:
		enemy_pool.ensure_view_for_unit(unit)


func _on_enemy_died(unit_id: int) -> void:
	if enemy_pool != null and enemy_pool.active_views.has(unit_id):
		enemy_pool.release_unit_view(unit_id)


func _on_currency_flow_recorded(
	source: String,
	offerings_delta: int,
	scrap_delta: int,
	hex: Vector2i,
	unit_id: int,
	tower_id: int
) -> void:
	if effects_view == null:
		return
	match source:
		"kills":
			if _kill_labels_this_frame >= 6:
				return
			_kill_labels_this_frame += 1
			var pos: Vector3 = _HexMath.hex_to_world(hex, 0.5)
			if unit_id >= 0 and enemy_pool != null and enemy_pool.active_views.has(unit_id):
				var ev: EnemyMoverView = enemy_pool.active_views[unit_id] as EnemyMoverView
				if is_instance_valid(ev):
					pos = ev.get_aim_world_position()
			var parts: PackedStringArray = []
			if offerings_delta > 0:
				parts.append("+%d Off" % offerings_delta)
			if scrap_delta > 0:
				parts.append("+%d Scrap" % scrap_delta)
			if not parts.is_empty():
				var col: Color = Color(1.0, 0.86, 0.36) if (offerings_delta > 0 and scrap_delta > 0) else (
					Color(0.86, 0.58, 1.0) if offerings_delta > 0 else Color(1.0, 0.65, 0.25)
				)
				effects_view.spawn_floating_text(pos, "  ".join(parts), col, 0.90)
		"tithe_box":
			var t_pos: Vector3 = _HexMath.hex_to_world(hex, 0.55)
			if tower_id >= 0 and tower_factory != null and tower_factory.views.has(tower_id):
				var tv: TowerView = tower_factory.views[tower_id] as TowerView
				if is_instance_valid(tv):
					t_pos = tv.global_position + Vector3(0.0, 0.55, 0.0)
			if offerings_delta > 0:
				effects_view.spawn_floating_text(t_pos, "+%d Off" % offerings_delta, Color(0.95, 0.78, 1.0), 1.0)
				effects_view.spawn_telegraph_reticle(hex, 0.45, Color(0.85, 0.55, 1.0, 0.70))
		"rite_bounties":
			var r_pos: Vector3 = _HexMath.hex_to_world(hex, 0.75)
			if unit_id >= 0 and enemy_pool != null and enemy_pool.active_views.has(unit_id):
				var ev_r: EnemyMoverView = enemy_pool.active_views[unit_id] as EnemyMoverView
				if is_instance_valid(ev_r):
					r_pos = ev_r.get_aim_world_position() + Vector3(0.0, 0.32, 0.0)
			elif tower_id >= 0 and tower_factory != null and tower_factory.views.has(tower_id):
				var tv_r: TowerView = tower_factory.views[tower_id] as TowerView
				if is_instance_valid(tv_r):
					r_pos = tv_r.global_position + Vector3(0.0, 0.75, 0.0)
			var r_parts: PackedStringArray = []
			if offerings_delta > 0:
				r_parts.append("+%d Off" % offerings_delta)
			if scrap_delta > 0:
				r_parts.append("+%d Scrap" % scrap_delta)
			if not r_parts.is_empty():
				effects_view.spawn_floating_text(
					r_pos,
					"RITE %s" % " ".join(r_parts),
					Color(1.0, 0.52, 0.65),
					1.0
				)
		"upkeep_and_steal":
			var u_pos: Vector3 = _HexMath.hex_to_world(hex, 0.65)
			var u_parts: PackedStringArray = []
			if offerings_delta < 0:
				u_parts.append("%d Off" % offerings_delta)
			if scrap_delta < 0:
				u_parts.append("%d Scrap" % scrap_delta)
			if not u_parts.is_empty():
				effects_view.spawn_floating_text(
					u_pos,
					" ".join(u_parts),
					Color(1.0, 0.36, 0.32),
					1.05
				)
		"events":
			if offerings_delta < 0 or scrap_delta < 0:
				var e_parts: PackedStringArray = []
				if offerings_delta < 0:
					e_parts.append("%d Off" % offerings_delta)
				if scrap_delta < 0:
					e_parts.append("%d Scrap" % scrap_delta)
				if not e_parts.is_empty():
					effects_view.spawn_floating_text(
						Vector3(0.0, 1.35, 0.0),
						" ".join(e_parts),
						Color(1.0, 0.36, 0.32),
						1.15
					)


func _on_tower_damaged_enemy(
	tower_id: int,
	_tower_type: String,
	unit_id: int,
	_unit_tags: Array,
	_amount: float,
	damage_tag: int
) -> void:
	if _amount < 0.75 or _projectiles_this_frame >= 24:
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		var tsys: TowerSystem = gs.get("tower_system") as TowerSystem
		if tsys != null and tsys._in_continuous_dot_tick:
			return
	if effects_view == null or tower_factory == null or enemy_pool == null:
		return
	if not tower_factory.views.has(tower_id) or not enemy_pool.active_views.has(unit_id):
		return
	var tv: TowerView = tower_factory.views[tower_id] as TowerView
	var ev: EnemyMoverView = enemy_pool.active_views[unit_id] as EnemyMoverView
	if is_instance_valid(tv) and is_instance_valid(ev):
		_projectiles_this_frame += 1
		var to_p: Vector3 = ev.get_aim_world_position()
		if _tower_type == "the_congregation" or _tower_type == "gutter_ritual_circle" or _tower_type == "tentacle_storm_drain":
			# Melee, ground pulse AoE, and drain effects appear directly on the affected mob/hex (no projectile from tower)
			effects_view.spawn_impact_burst(to_p, damage_tag)
		elif _tower_type == "substation_effigy":
			# Chain lightning links the tower and every enemy it hits this frame into one arc that tracks the units.
			# Remember each hit's world position now (the view may be gone by the time the arc is flushed).
			if not _chain_hits_by_tower.has(tower_id):
				_chain_hits_by_tower[tower_id] = [] as Array[Dictionary]
			(_chain_hits_by_tower[tower_id] as Array[Dictionary]).append({"id": unit_id, "pos": to_p})
		else:
			var from_p: Vector3 = tv.global_position + Vector3(0.0, 0.72, 0.0)
			effects_view.spawn_projectile(from_p, to_p, _tower_type, damage_tag)


## Builds and spawns one following chain-lightning arc per substation_effigy that
## dealt chain damage this frame: tower apex -> each chained enemy, tracked live.
func _flush_chain_lightning() -> void:
	if _chain_hits_by_tower.is_empty():
		return
	if effects_view != null:
		for tower_id: int in _chain_hits_by_tower.keys():
			var hits: Array = _chain_hits_by_tower[tower_id] as Array
			if hits.is_empty():
				continue
			var providers: Array[Callable] = []
			var initial_points: Array[Vector3] = []
			var apex: Vector3 = Vector3.ZERO
			if tower_factory != null and tower_factory.views.has(tower_id):
				var tv0: TowerView = tower_factory.views[tower_id] as TowerView
				if is_instance_valid(tv0):
					apex = tv0.global_position + Vector3(0.0, 1.15, 0.0)
			providers.append(_make_tower_anchor_provider(tower_id))
			initial_points.append(apex)
			for hit: Dictionary in hits:
				var hit_pos: Vector3 = hit["pos"] as Vector3
				providers.append(_make_unit_anchor_provider(int(hit["id"])))
				initial_points.append(hit_pos)
			effects_view.spawn_following_chain_lightning(providers, 1.6, 0.055, initial_points)
	_chain_hits_by_tower.clear()


## Callable that returns the current world apex position of a placed tower (or null if gone).
func _make_tower_anchor_provider(tower_id: int) -> Callable:
	return func() -> Variant:
		if tower_factory != null and tower_factory.views.has(tower_id):
			var tv: TowerView = tower_factory.views[tower_id] as TowerView
			if is_instance_valid(tv):
				return tv.global_position + Vector3(0.0, 1.15, 0.0)
		return null


## Callable that returns the current aim position of an enemy (or null if it left/died,
## so the arc keeps the enemy's last live position for that anchor).
func _make_unit_anchor_provider(unit_id: int) -> Callable:
	return func() -> Variant:
		if enemy_pool != null and enemy_pool.active_views.has(unit_id):
			var ev: EnemyMoverView = enemy_pool.active_views[unit_id] as EnemyMoverView
			if is_instance_valid(ev):
				return ev.get_aim_world_position()
		return null


func _on_tower_cooldown_used(_tower_id: int, tower_type: String, _ability_id: String, hex: Vector2i) -> void:
	if effects_view == null:
		return
	var col := Color(0.42, 0.95, 0.28, 0.80)
	match tower_type:
		"tentacle_storm_drain":
			col = Color(0.22, 0.85, 0.76, 0.80)
		"chanting_choir":
			col = Color(0.88, 0.38, 0.96, 0.80)
		"fever_shrine":
			col = Color(0.98, 0.36, 0.42, 0.80)
		"the_congregation":
			col = Color(0.76, 0.62, 0.96, 0.80)
		"substation_effigy":
			col = Color(0.28, 0.88, 1.0, 0.85)
	effects_view.spawn_telegraph_reticle(hex, 0.55, col)


func _on_currency_earned(currency: int, amount: int, _reason: String) -> void:
	if effects_view == null or amount <= 0:
		return
	var label_txt: String = ("+%d Off" % amount) if currency == 0 else ("+%d Scrap" % amount)
	var col: Color = Color(0.85, 0.55, 1.0) if currency == 0 else Color(1.0, 0.65, 0.25)
	effects_view.spawn_floating_text(Vector3(0.0, 1.2, 0.0), label_txt, col)


func _on_lane_bounty_claimed(_lane_id: int, unit_id: int, offerings_paid: int, scrap_paid: int) -> void:
	if effects_view == null:
		return
	var pos: Vector3 = Vector3(0.0, 1.4, 0.0)
	if enemy_pool != null and enemy_pool.active_views.has(unit_id):
		var ev: EnemyMoverView = enemy_pool.active_views[unit_id] as EnemyMoverView
		if is_instance_valid(ev):
			pos = ev.get_aim_world_position() + Vector3(0.0, 0.35, 0.0)
	var parts: PackedStringArray = []
	if offerings_paid > 0:
		parts.append("+%d Off" % offerings_paid)
	if scrap_paid > 0:
		parts.append("+%d Scrap" % scrap_paid)
	if not parts.is_empty():
		effects_view.spawn_floating_text(pos, "BOUNTY %s" % " ".join(parts), Color(1.0, 0.68, 0.20))


func _on_ability_telegraphed(ev: Dictionary) -> void:
	if effects_view == null:
		return
	var hex: Vector2i = ev.get("hex", Vector2i.ZERO) as Vector2i
	var lead: float = maxf(1.0, float(ev.get("lead_time", 1.5)))
	var ab_id: String = String(ev.get("ability_id", ""))
	var meta: Dictionary = ev.get("metadata", {}) as Dictionary

	if ab_id == "LeveragedBuyout" or ab_id == "TowerConvert":
		if meta.has("target_hex"):
			var t_hex: Vector2i = meta["target_hex"] as Vector2i
			# Conversion/hack effect is shown on the affected tower hex (reticle + tower HACKING status), never as a line from the mob
			effects_view.spawn_telegraph_reticle(t_hex, lead, Color(1.0, 0.2, 0.6, 0.9))
	elif ab_id == "SameDayDelivery":
		effects_view.spawn_telegraph_reticle(hex, lead, Color(0.25, 0.90, 1.0, 0.9))
	else:
		effects_view.spawn_telegraph_reticle(hex, lead, Color(1.0, 0.65, 0.20, 0.8))
