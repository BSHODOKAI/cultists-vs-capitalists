## BossBar
##
## Displays active Boss HP bar, phase, currently resisted damage type (Chairman),
## Network Effect stacks (Disruptor), and active mechanic icon/faction (Holding Company).
class_name BossBar
extends PanelContainer

const _C = preload("res://scripts/path/path_constants.gd")

const DAMAGE_TAG_LABELS: Dictionary = {
	_C.DamageTag.KINETIC: "KINETIC",
	_C.DamageTag.CORROSIVE: "CORROSIVE",
	_C.DamageTag.PSYCHIC: "PSYCHIC",
	_C.DamageTag.VOID: "VOID",
	_C.DamageTag.ELECTRIC: "ELECTRIC",
}

var _title_label: Label
var _hp_bar: ProgressBar
var _details_label: Label


func _ready() -> void:
	_build_ui()
	visible = false


func _build_ui() -> void:
	custom_minimum_size = Vector2(460.0, 66.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.06, 0.10, 0.94)
	style.border_color = Color(0.95, 0.25, 0.35, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75))
	vbox.add_child(_title_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(420.0, 18.0)
	_hp_bar.show_percentage = false
	vbox.add_child(_hp_bar)

	_details_label = Label.new()
	_details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details_label.add_theme_font_size_override("font_size", 12)
	_details_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	vbox.add_child(_details_label)


func update_from_units(units: Array[CombatUnit]) -> void:
	var boss: CombatUnit = null
	for u: CombatUnit in units:
		if u != null and u.is_alive() and u.is_boss():
			boss = u
			break
	if boss == null:
		visible = false
		return

	visible = true
	_hp_bar.max_value = maxf(1.0, boss.max_hp)
	_hp_bar.value = clampf(boss.hp, 0.0, boss.max_hp)
	_title_label.text = "%s — %d / %d HP" % [boss.unit_name.to_upper(), ceili(boss.hp), ceili(boss.max_hp)]

	var extras: Array[String] = []
	if boss.restructuring_phase > 1 or boss.active_resisted_damage_tag >= 0:
		var rname: String = String(DAMAGE_TAG_LABELS.get(boss.active_resisted_damage_tag, "NONE"))
		extras.append("Phase %d | Resisting: %s (%.0f%%)" % [
			boss.restructuring_phase, rname, (1.0 - boss.active_resisted_multiplier) * 100.0
		])
	if boss.network_effect_stacks > 0:
		extras.append("Network Effect: %d stacks (-%d%% dmg)" % [
			boss.network_effect_stacks, roundi(boss.network_damage_reduction * 100.0)
		])
	if not boss.active_holding_mechanic.is_empty():
		extras.append("Active Protocol: %s [%s]" % [
			boss.active_holding_mechanic.replace("_", " ").to_upper(),
			boss.active_faction_logo.to_upper()
		])
	if boss.phase_immunity_timer > 0.0:
		extras.append("IMMUNE (%.1fs)" % boss.phase_immunity_timer)

	_details_label.text = " | ".join(extras) if not extras.is_empty() else "Corporate Executive Threat"
