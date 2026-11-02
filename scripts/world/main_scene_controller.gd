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

var tower_factory: TowerFactory
var enemy_pool: EnemyVisualPool
var theme_data: VisualThemeData


func _ready() -> void:
	theme_data = load("res://data/visual_theme.tres") as VisualThemeData
	tower_factory = _TowerFactory.new(towers_container, theme_data)
	enemy_pool = _EnemyVisualPool.new(enemies_container, theme_data)

	_connect_signals()

	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("start_new_run", -1)
		_rebuild_world_views()
		if camera_rig != null:
			camera_rig.focus_base()


func _connect_signals() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return

	gs.connect("state_changed", _on_state_changed)
	gs.connect("path_extended", func(_r: Dictionary) -> void: _rebuild_world_views())
	gs.connect("path_preview_ready", func(_p: Dictionary) -> void: _rebuild_world_views())
	gs.connect("tower_placed_on_hex", _on_tower_placed)
	gs.connect("tower_upgraded_on_hex", _on_tower_upgraded)
	gs.connect("tower_sold_from_hex", _on_tower_sold)
	gs.connect("tower_maintained", _on_tower_maintained)
	gs.connect("selected_tower_changed", func(_t: Variant) -> void: _refresh_hover_and_overlays())
	gs.connect("build_mode_changed", func(_td: Variant) -> void: _refresh_hover_and_overlays())
	gs.connect("enemy_spawned", _on_enemy_spawned)
	gs.connect("enemy_died", _on_enemy_died)
	gs.connect("tower_damaged_enemy", _on_tower_damaged_enemy)
	gs.connect("currency_earned", _on_currency_earned)
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
		enemy_pool.update_all_views(tsys.units, pgen.path_hexes, prev_pos, alpha)
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

	# Mouse motion -> update hovered hex via camera ray to Y = 0
	if event is InputEventMouseMotion and camera_rig != null:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var picked: Variant = camera_rig.pick_hex_at_screen(mm.position)
		if picked != null:
			gs.set("hovered_hex", picked as Vector2i)
			gs.set("has_hovered_hex", true)
		else:
			gs.set("has_hovered_hex", false)
		_refresh_hover_and_overlays()

	# Mouse button clicks on the hex grid
	if event is InputEventMouseButton and event.pressed and camera_rig != null:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if gs.get("selected_build_tower") != null:
				gs.call("cancel_build_mode")
				get_viewport().set_input_as_handled()
				return
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var picked_hex: Variant = camera_rig.pick_hex_at_screen(mb.position)
			if picked_hex != null:
				var hex: Vector2i = picked_hex as Vector2i
				var build_def: TowerData = gs.get("selected_build_tower") as TowerData
				if build_def != null:
					var placed: TowerInstance = gs.call("request_place_tower", hex, build_def) as TowerInstance
					if placed != null and not mb.shift_pressed:
						gs.call("cancel_build_mode")
						gs.call("select_placed_tower", placed)
					_refresh_hover_and_overlays()
				else:
					# Select placed tower by hex lookup (never physics picking)
					var existing: TowerInstance = gs.call("get_tower_at_hex", hex) as TowerInstance
					gs.call("select_placed_tower", existing)
					_refresh_hover_and_overlays()
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
		path_view.refresh_path(pgen.path_hexes)
	if overlay_view != null:
		overlay_view.refresh_path_overlays(pgen)
	_refresh_hover_and_overlays()


func _refresh_hover_and_overlays() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or overlay_view == null:
		return
	var tsys: TowerSystem = gs.get("tower_system") as TowerSystem
	var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
	var h_hex: Vector2i = gs.get("hovered_hex") as Vector2i
	var has_h: bool = bool(gs.get("has_hovered_hex"))
	var build_td: TowerData = gs.get("selected_build_tower") as TowerData
	var sel_t: TowerInstance = gs.get("selected_placed_tower") as TowerInstance

	var val: Dictionary = gs.call("validate_placement", h_hex, build_td) if build_td != null else {"ok": true, "reason": ""}
	if terrain_view != null:
		terrain_view.set_build_mode_active(build_td != null)
	overlay_view.update_hover(h_hex, has_h, build_td, val, sel_t, tsys)
	if pgen != null:
		overlay_view.refresh_path_overlays(pgen)


func _on_tower_placed(inst: TowerInstance) -> void:
	if tower_factory != null:
		tower_factory.spawn_tower_view(inst)
	_rebuild_world_views()


func _on_tower_upgraded(inst: TowerInstance, _node_id: String) -> void:
	if tower_factory != null:
		tower_factory.refresh_tower_view(inst)
	_refresh_hover_and_overlays()


func _on_tower_sold(tower_id: int, _hex: Vector2i, refund: Dictionary) -> void:
	if tower_factory != null:
		tower_factory.remove_tower_view(tower_id)
	if effects_view != null:
		var off_r: int = int(refund.get("offerings_refund", 0))
		if off_r > 0:
			effects_view.spawn_floating_text(_HexMath.hex_to_world(_hex, 0.5), "+%d Off" % off_r, Color(0.85, 0.65, 1.0))
	_rebuild_world_views()


func _on_tower_maintained(inst: TowerInstance) -> void:
	if tower_factory != null:
		tower_factory.refresh_tower_view(inst)


func _on_enemy_spawned(unit: CombatUnit) -> void:
	if enemy_pool != null:
		enemy_pool.ensure_view_for_unit(unit)


func _on_enemy_died(unit_id: int) -> void:
	if enemy_pool != null and enemy_pool.active_views.has(unit_id):
		var v: EnemyMoverView = enemy_pool.active_views[unit_id] as EnemyMoverView
		if is_instance_valid(v) and effects_view != null:
			effects_view.spawn_floating_text(v.global_position, "+Kill", Color(1.0, 0.88, 0.35))
		enemy_pool.release_unit_view(unit_id)


func _on_tower_damaged_enemy(
	tower_id: int,
	_tower_type: String,
	unit_id: int,
	_unit_tags: Array,
	_amount: float,
	damage_tag: int
) -> void:
	if effects_view == null or tower_factory == null or enemy_pool == null:
		return
	if not tower_factory.views.has(tower_id) or not enemy_pool.active_views.has(unit_id):
		return
	var tv: TowerView = tower_factory.views[tower_id] as TowerView
	var ev: EnemyMoverView = enemy_pool.active_views[unit_id] as EnemyMoverView
	if is_instance_valid(tv) and is_instance_valid(ev):
		var to_p: Vector3 = ev.global_position + Vector3(0.0, 0.50, 0.0)
		if _tower_type == "the_congregation":
			# Congregation blockers fight in melee on the path tile rather than shooting from the tower roof
			effects_view.spawn_impact_burst(to_p, damage_tag)
		else:
			var from_p: Vector3 = tv.global_position + Vector3(0.0, 0.72, 0.0)
			effects_view.spawn_projectile(from_p, to_p, _tower_type, damage_tag)


func _on_currency_earned(currency: int, amount: int, _reason: String) -> void:
	if effects_view == null or amount <= 0:
		return
	var label_txt: String = ("+%d Off" % amount) if currency == 0 else ("+%d Scrap" % amount)
	var col: Color = Color(0.85, 0.55, 1.0) if currency == 0 else Color(1.0, 0.65, 0.25)
	effects_view.spawn_floating_text(Vector3(0.0, 1.2, 0.0), label_txt, col)


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
			effects_view.spawn_telegraph_reticle(t_hex, lead, Color(1.0, 0.2, 0.6, 0.9))
			effects_view.spawn_beam(
				_HexMath.hex_to_world(hex, 0.8),
				_HexMath.hex_to_world(t_hex, 0.8),
				4,
				lead,
				0.12
			)
	elif ab_id == "SameDayDelivery":
		effects_view.spawn_telegraph_reticle(hex, lead, Color(0.25, 0.90, 1.0, 0.9))
	else:
		effects_view.spawn_telegraph_reticle(hex, lead, Color(1.0, 0.65, 0.20, 0.8))
