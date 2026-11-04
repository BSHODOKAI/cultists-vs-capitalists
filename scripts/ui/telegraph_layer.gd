## TelegraphLayer
##
## Displays screen banners (e.g. Stars Are Right, Boss Ability Telegraphs,
## Next Faction Announced) and off-screen edge arrows pointing toward world-space
## ability telegraphs outside the current camera viewport.
class_name TelegraphLayer
extends Control

const _HexMath = preload("res://scripts/core/hex_math.gd")

## Vertical placement and height of the banner bar, and of the larger, pulsing
## bar used for run Events so they read as a distinct, unmissable event.
const _BANNER_TOP: float = 92.0
const _BANNER_HEIGHT: float = 56.0
const _EVENT_BANNER_HEIGHT: float = 96.0

var _banner_root: Control
var _banner_panel: Panel
var _banner_style: StyleBoxFlat
var _banner_label: Label
var _banner_timer: float = 0.0
var _banner_tween: Tween
var _banner_pulse_tween: Tween
var _arrow_labels: Array[Label] = []
var _active_offscreen_events: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	# Full-width banner bar: a tinted panel with a bright accent border and a
	# bold, outlined, centred label so announcements are legible over any scene.
	_banner_root = Control.new()
	_banner_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner_root.offset_left = 0.0
	_banner_root.offset_right = 0.0
	_banner_root.offset_top = _BANNER_TOP
	_banner_root.offset_bottom = _BANNER_TOP + _BANNER_HEIGHT
	_banner_root.visible = false
	add_child(_banner_root)

	_banner_panel = Panel.new()
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner_style = StyleBoxFlat.new()
	_banner_style.bg_color = Color(0.06, 0.05, 0.09, 0.9)
	_banner_style.border_color = Color(1.0, 0.85, 0.30)
	_banner_style.border_width_top = 3
	_banner_style.border_width_bottom = 3
	_banner_style.content_margin_left = 18.0
	_banner_style.content_margin_right = 18.0
	_banner_style.content_margin_top = 6.0
	_banner_style.content_margin_bottom = 6.0
	_banner_panel.add_theme_stylebox_override("panel", _banner_style)
	_banner_root.add_child(_banner_panel)

	_banner_label = Label.new()
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner_label.add_theme_font_size_override("font_size", 22)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	_banner_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_banner_label.add_theme_constant_override("outline_size", 6)
	_banner_root.add_child(_banner_label)


func _connect_signals() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	gs.connect("event_triggered", func(_event_id: String, _display_name: String, category: int, banner_text: String, banner_color: Color) -> void:
		var tag: String = "BUFF" if category == 0 else "DEBUFF"
		show_banner("WAVE %d EVENT  [ %s ]\n%s" % [int(gs.get("current_wave")), tag, banner_text], 5.5, banner_color, true)
	)
	gs.connect("next_faction_announced", func(fac: String, _logo: String) -> void:
		var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
		var lanes_cnt: int = pgen.get_lane_count() if pgen != null else 1
		if lanes_cnt > 1:
			show_banner("COMPANY DROP LANDED (%d LANES ACTIVE)! Next Corporate Faction: %s" % [lanes_cnt, fac.replace("_", " ").to_upper()], 4.8, Color(1.0, 0.62, 0.22))
		else:
			show_banner("PATH EXTENDED! Next Corporate Faction: %s" % fac.replace("_", " ").to_upper(), 4.5, Color(0.45, 0.95, 1.0))
	)
	if gs.has_signal("fork_preview_ready"):
		gs.connect("fork_preview_ready", func(cands: Array, _sel_idx: int) -> void:
			show_banner("COMPANY DROP INBOUND! %d Drop Routes Detected — Choose Route in Intel Panel!" % cands.size(), 5.0, Color(1.0, 0.48, 0.18))
		)
	if gs.has_signal("towers_crushed_by_fork"):
		gs.connect("towers_crushed_by_fork", func(lane_id: int, crushed: Array, b_off: int, b_scr: int) -> void:
			show_banner(
				"%d TOWER(S) CRUSHED BY COMPANY DROP! +%d Off / +%d Scrap Kill Bounty on Lane #%d!" % [
					crushed.size(), b_off, b_scr, lane_id + 1
				],
				5.2,
				Color(1.0, 0.35, 0.35)
			)
		)
	gs.connect("wave_started", func(_w: int) -> void:
		if _banner_root != null and _banner_root.visible and (
			_banner_label.text.begins_with("PATH EXTENDED!")
			or _banner_label.text.begins_with("COMPANY DROP LANDED")
		):
			_banner_root.visible = false
			_banner_timer = 0.0
	)
	gs.connect("ability_telegraphed", _on_ability_telegraphed)


func show_banner(text: String, duration: float = 3.0, col: Color = Color(1.0, 0.85, 0.30), emphasis: bool = false) -> void:
	if _banner_root == null:
		return
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", col)
	_banner_label.add_theme_font_size_override("font_size", 30 if emphasis else 22)
	_banner_style.border_color = col
	_banner_style.border_width_top = 5 if emphasis else 3
	_banner_style.border_width_bottom = 5 if emphasis else 3
	_banner_style.bg_color = Color(col.r * 0.16, col.g * 0.16, col.b * 0.16, 0.9)
	_banner_root.offset_top = _BANNER_TOP
	_banner_root.offset_bottom = _BANNER_TOP + _measure_banner_height(emphasis)
	_banner_root.visible = true
	_banner_timer = duration
	_animate_banner_in(emphasis)


## Returns the bar height needed to fit the current (possibly multi-line) banner
## text, so long event descriptions never spill past the bordered bar.
func _measure_banner_height(emphasis: bool) -> float:
	var min_h: float = _EVENT_BANNER_HEIGHT if emphasis else _BANNER_HEIGHT
	if _banner_label == null or _banner_label.text.is_empty():
		return min_h
	var avail_w: float = (size.x if size.x > 0.0 else get_viewport_rect().size.x) - 48.0
	var font: Font = _banner_label.get_theme_font("font")
	if font == null:
		return min_h
	var fs: int = _banner_label.get_theme_font_size("font_size")
	var text_size: Vector2 = font.get_multiline_string_size(
		_banner_label.text, HORIZONTAL_ALIGNMENT_CENTER, maxf(240.0, avail_w), fs
	)
	return maxf(min_h, text_size.y + 22.0)


## Fades the banner in and, for emphasised (event) banners, pulses the background
## so it flashes against the action rather than blending into it.
func _animate_banner_in(emphasis: bool) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	if _banner_pulse_tween != null and _banner_pulse_tween.is_valid():
		_banner_pulse_tween.kill()
	_banner_root.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_root, "modulate:a", 1.0, 0.16)
	if emphasis:
		_banner_pulse_tween = create_tween().set_loops(3)
		_banner_pulse_tween.tween_property(_banner_style, "bg_color:a", 0.5, 0.22)
		_banner_pulse_tween.tween_property(_banner_style, "bg_color:a", 0.9, 0.22)


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

	# Deduplicate off-screen telegraph markers by ability_id so mass regular abilities don't stack overlapping labels
	for existing: Dictionary in _active_offscreen_events:
		if String(existing.get("label", "")) == ab_id:
			existing["world_pos"] = _HexMath.hex_to_world(hex, 0.5)
			existing["remaining"] = maxf(float(existing.get("remaining", 0.0)), lead)
			return

	if _active_offscreen_events.size() < 6:
		_active_offscreen_events.append({
			"world_pos": _HexMath.hex_to_world(hex, 0.5),
			"label": ab_id,
			"remaining": lead,
		})


func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and _banner_root != null:
			_banner_root.visible = false

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
