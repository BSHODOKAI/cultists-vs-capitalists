## TelegraphLayer
##
## Displays screen banners (e.g. Stars Are Right, Boss Ability Telegraphs,
## Next Faction Announced) and off-screen edge arrows pointing toward world-space
## ability telegraphs outside the current camera viewport.
class_name TelegraphLayer
extends Control

const _HexMath = preload("res://scripts/core/hex_math.gd")

var _banner_label: Label
var _banner_timer: float = 0.0
var _arrow_labels: Array[Label] = []
var _active_offscreen_events: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner_label.offset_top = 128.0
	_banner_label.offset_bottom = 166.0
	_banner_label.add_theme_font_size_override("font_size", 20)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	_banner_label.visible = false
	add_child(_banner_label)


func _connect_signals() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	gs.connect("stars_are_right_triggered", func(w: int) -> void:
		show_banner("WAVE %d: THE STARS ARE RIGHT (+20%% Revealed Tower Damage)!" % w, 4.0, Color(0.85, 0.45, 1.0))
	)
	gs.connect("next_faction_announced", func(fac: String, _logo: String) -> void:
		show_banner("PATH EXTENDED! Next Corporate Faction: %s" % fac.replace("_", " ").to_upper(), 4.5, Color(0.45, 0.95, 1.0))
	)
	gs.connect("ability_telegraphed", _on_ability_telegraphed)


func show_banner(text: String, duration: float = 3.0, col: Color = Color(1.0, 0.85, 0.30)) -> void:
	if _banner_label == null:
		return
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", col)
	_banner_label.visible = true
	_banner_timer = duration


func _on_ability_telegraphed(ev: Dictionary) -> void:
	var ab_id: String = String(ev.get("ability_id", ""))
	var hex: Vector2i = ev.get("hex", Vector2i.ZERO) as Vector2i
	var lead: float = maxf(1.8, float(ev.get("lead_time", 2.0)))

	match ab_id:
		"SurgePricing":
			show_banner("SIREN: Surge Pricing Incoming (+30% Syndicate Speed)!", lead, Color(1.0, 0.45, 0.25))
		"Restructuring":
			show_banner("CHAIRMAN RESTRUCTURING: Phase Shift & Escorts!", lead, Color(0.85, 0.85, 1.0))
		"LeveragedBuyout":
			show_banner("LEVERAGED BUYOUT: Destroy Bid Drone or Cleanse Tower!", lead, Color(1.0, 0.25, 0.65))
		"SameDayDelivery":
			show_banner("SAME-DAY DELIVERY: Supply Pods Dropping!", lead, Color(0.35, 0.90, 1.0))
		"HoldingCompany":
			var meta: Dictionary = ev.get("metadata", {}) as Dictionary
			show_banner("HOLDING COMPANY PROTOCOL: %s" % String(meta.get("active_mechanic", "")).to_upper(), 2.5, Color(1.0, 0.88, 0.35))

	_active_offscreen_events.append({
		"world_pos": _HexMath.hex_to_world(hex, 0.5),
		"label": ab_id,
		"remaining": lead,
	})


func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and _banner_label != null:
			_banner_label.visible = false

	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	var vp_rect: Rect2 = get_viewport().get_visible_rect() if get_viewport() != null else Rect2(0, 0, 1152, 648)

	for i in range(_active_offscreen_events.size() - 1, -1, -1):
		_active_offscreen_events[i]["remaining"] = float(_active_offscreen_events[i]["remaining"]) - delta
		if float(_active_offscreen_events[i]["remaining"]) <= 0.0:
			_active_offscreen_events.remove_at(i)

	_update_edge_arrows(cam, vp_rect)


func _update_edge_arrows(cam: Camera3D, vp_rect: Rect2) -> void:
	for lbl: Label in _arrow_labels:
		lbl.visible = false
	if cam == null or _active_offscreen_events.is_empty():
		return

	var margin: float = 28.0
	var inner_rect := Rect2(margin, margin, vp_rect.size.x - margin * 2.0, vp_rect.size.y - margin * 2.0)

	var arrow_idx: int = 0
	for item: Dictionary in _active_offscreen_events:
		var wp: Vector3 = item["world_pos"] as Vector3
		var sp: Vector2 = cam.unproject_position(wp)
		if inner_rect.has_point(sp) and not cam.is_position_behind(wp):
			continue
		var clamped := Vector2(
			clampf(sp.x, inner_rect.position.x, inner_rect.end.x),
			clampf(sp.y, inner_rect.position.y, inner_rect.end.y)
		)
		while _arrow_labels.size() <= arrow_idx:
			var nl := Label.new()
			nl.add_theme_font_size_override("font_size", 14)
			nl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			add_child(nl)
			_arrow_labels.append(nl)
		var arrow_lbl: Label = _arrow_labels[arrow_idx]
		arrow_lbl.text = "[! %s !]" % String(item["label"])
		arrow_lbl.position = clamped - Vector2(40.0, 10.0)
		arrow_lbl.visible = true
		arrow_idx += 1
