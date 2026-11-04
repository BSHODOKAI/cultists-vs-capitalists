## TowerData
##
## Designer-editable definition of a hex-grid cult tower archetype.
## Stored as .tres files under res://data/towers/ and loaded via [TowerLibrary].
class_name TowerData
extends Resource

const _C = preload("res://scripts/path/path_constants.gd")
const _UpgradeNode = preload("res://scripts/towers/upgrade_node.gd")

## Hex-defense targeting/archetype mode.
enum TargetingMode {
	SINGLE_TARGET = 0,
	HIGHEST_HP = 1,
	CHANNELED_CHOIR = 2,
	PULSE_AOE = 3,
	CONTROL_DRAIN = 4,
	DOT_CENSER = 5,
	BUFF_SHRINE = 6,
	SUMMON_CONGREGATION = 7,
	ECONOMY_TITHE = 8,
	CHAIN_ARC = 9,
}

## Unique snake_case identifier (e.g. "hexed_nail_gun").
@export var id: String = ""
@export var display_name: String = "Tower"
@export_multiline var description: String = ""
## Optional mesh override.
@export var mesh: Mesh
## Albedo color applied to the tower's mesh.
@export var color: Color = Color(0.55, 0.8, 1.0, 1.0)
## Build cost (base T1 cost in [member build_currency]).
@export var cost: int = 50
## Currency used to build this tower at T1 (0 = OFFERINGS, 1 = SCRAP).
@export var build_currency: int = _UpgradeNode.Currency.OFFERINGS
## Attack range in axial hex distance.
@export var range_hexes: int = 3
## Damage per shot/tick/pulse (or per member per second for chanting_choir).
@export var damage: float = 10.0
## Damage tag from PathConstants.DamageTag.
@export var damage_tag: int = _C.DamageTag.KINETIC
## Shots or applications per second (0 for non-attacking towers).
@export var fire_rate: float = 1.0

@export_group("Hex Targeting & Detection")
## Allowed domain UnitTags (e.g. [GROUND] or [GROUND, AIR]).
@export var target_tags: Array[int] = [_C.UnitTag.GROUND]
## Archetype targeting mode used by the combat system.
@export var targeting_mode: TargetingMode = TargetingMode.SINGLE_TARGET
## True when this tower continuously reveals Cloaked enemies within range_hexes.
@export var detects_cloaked: bool = false
## Seconds a pulse from this tower reveals Cloaked enemies hit (3.0 for gutter_ritual_circle).
@export var pulse_reveal_duration: float = 0.0

@export_group("Archetype Parameters")
## Starting member count (3 for chanting_choir, 1 otherwise).
@export var starting_members: int = 1
## Maximum simultaneous primary targets (1 default).
@export var max_targets: int = 1
## Pulse ring radius around target/tower (1 for gutter_ritual_circle).
@export var pulse_max_ring: int = 0
## Continuous slow aura strength in range (0.35 for tentacle_storm_drain).
@export var slow_aura_strength: float = 0.0
## Periodic root duration in seconds (1.5 for tentacle_storm_drain).
@export var root_duration: float = 0.0
## Periodic root interval in seconds (8.0 for tentacle_storm_drain).
@export var root_interval: float = 0.0
## Whether enemies slowed or rooted by this tower gain the Entangled status.
@export var applies_entangled: bool = false
## DoT damage per second per stack (6.0 for rust_censer).
@export var dot_damage: float = 0.0
## DoT duration in seconds (4.0 for rust_censer).
@export var dot_duration: float = 0.0
## Maximum DoT stacks on a single enemy (3 for rust_censer).
@export var dot_max_stacks: int = 0
## Armor Shred stacks applied per application (1 for rust_censer).
@export var shred_per_hit: int = 0
## Friendly aura radius in hexes (2 for fever_shrine).
@export var aura_radius_hexes: int = 0
## Friendly aura fire-rate bonus fraction (0.15 for fever_shrine).
@export var aura_fire_rate_bonus: float = 0.0
## Max summoned blockers (2 for the_congregation).
@export var summon_count: int = 0
## Blocker max HP (60.0 for the_congregation).
@export var summon_hp: float = 0.0
## Blocker DPS in Kinetic damage (2.0 for the_congregation).
@export var summon_dps: float = 0.0
## Seconds after a blocker dies before it is resummoned (10.0 for the_congregation).
@export var resummon_time: float = 0.0
## Offerings generated per interval (4 for tithe_box).
@export var income_offerings: int = 0
## Seconds per Offering generation tick (5.0 for tithe_box).
@export var income_interval: float = 0.0
## Base behavior IDs active at T1.
@export var base_behaviors: Array[String] = []

@export_group("Upgrade Tree")
@export var t2_upgrade: UpgradeNode
@export var revealed_t3_upgrade: UpgradeNode
@export var revealed_t4_upgrade: UpgradeNode
@export var rigged_t3_upgrade: UpgradeNode
@export var rigged_t4_upgrade: UpgradeNode
## Rite branch (paid in Rites). Only some towers have one -- the fork is optional.
@export var rite_t3_upgrade: UpgradeNode
@export var rite_t4_upgrade: UpgradeNode


## Returns all upgrade nodes belonging to this tower in canonical order:
## [t2, revealed_t3, revealed_t4, rigged_t3, rigged_t4, rite_t3, rite_t4].
func get_all_upgrade_nodes() -> Array[UpgradeNode]:
	var out: Array[UpgradeNode] = []
	if t2_upgrade != null:
		out.append(t2_upgrade)
	if revealed_t3_upgrade != null:
		out.append(revealed_t3_upgrade)
	if revealed_t4_upgrade != null:
		out.append(revealed_t4_upgrade)
	if rigged_t3_upgrade != null:
		out.append(rigged_t3_upgrade)
	if rigged_t4_upgrade != null:
		out.append(rigged_t4_upgrade)
	if rite_t3_upgrade != null:
		out.append(rite_t3_upgrade)
	if rite_t4_upgrade != null:
		out.append(rite_t4_upgrade)
	return out


## Looks up an upgrade node on this tower by its [param node_id], or null.
func get_upgrade_node(node_id: String) -> UpgradeNode:
	for node: UpgradeNode in get_all_upgrade_nodes():
		if node != null and node.id == node_id:
			return node
	return null


func is_scrap_build_cost() -> bool:
	return build_currency == _UpgradeNode.Currency.SCRAP


func get_build_currency_name(short_form: bool = false) -> String:
	if is_scrap_build_cost():
		return "Scrap"
	return "Off" if short_form else "Offerings"


## Returns a human-readable description of this tower, falling back to an
## auto-generated summary when [member description] is empty.
func get_display_description() -> String:
	if not description.strip_edges().is_empty():
		return description.strip_edges()
	var range_val: int = range_hexes if range_hexes > 0 else aura_radius_hexes
	match targeting_mode:
		TargetingMode.ECONOMY_TITHE:
			return "Generates +%d Offerings every %.1f s." % [income_offerings, income_interval]
		TargetingMode.BUFF_SHRINE:
			return "Support aura that boosts nearby friendly towers' fire rate by +%d%% within %d hexes." % [
				roundi(aura_fire_rate_bonus * 100.0), range_val
			]
		TargetingMode.SUMMON_CONGREGATION:
			return "Summons up to %d blockers (%d HP, %.1f DPS) onto adjacent path hexes." % [
				summon_count, roundi(summon_hp), summon_dps
			]
		_:
			return "Deals %.1f %s damage at %.2f/s within %d hexes." % [
				damage, get_damage_tag_name(), fire_rate, range_val
			]


## Human-readable name for [member damage_tag].
func get_damage_tag_name() -> String:
	match damage_tag:
		_C.DamageTag.KINETIC:
			return "Kinetic"
		_C.DamageTag.CORROSIVE:
			return "Corrosive"
		_C.DamageTag.PSYCHIC:
			return "Psychic"
		_C.DamageTag.VOID:
			return "Void"
		_C.DamageTag.ELECTRIC:
			return "Electric"
	return "Kinetic"


## Human-readable summary of what this tower can target.
func get_target_domain_text() -> String:
	if targeting_mode == TargetingMode.ECONOMY_TITHE:
		return "None (Economy)"
	if targeting_mode == TargetingMode.BUFF_SHRINE:
		return "Friendly Towers"
	var has_ground: bool = target_tags.has(_C.UnitTag.GROUND)
	var has_air: bool = target_tags.has(_C.UnitTag.AIR)
	if has_ground and has_air:
		return "Ground & Air"
	if has_air:
		return "Air Only"
	if has_ground:
		return "Ground Only"
	return "None"


## Builds a formatted multi-line stat block for build menus and tooltips. When
## [param include_cost] is false the leading "Cost:" line is omitted, so a caller that
## shows the price as its own icon+number chip does not print it twice.
func get_stats_summary(
	effective_cost: int = -1, currency_label: String = "Offerings", include_cost: bool = true
) -> String:
	var shown_cost: int = effective_cost if effective_cost >= 0 else cost
	var lines: PackedStringArray = PackedStringArray()
	if include_cost:
		lines.append("Cost: %d %s" % [shown_cost, currency_label])

	var range_val: int = range_hexes if range_hexes > 0 else aura_radius_hexes
	if targeting_mode == TargetingMode.ECONOMY_TITHE:
		lines.append("Role: Economy (+%d Offerings / %.1fs)" % [income_offerings, income_interval])
	elif targeting_mode == TargetingMode.BUFF_SHRINE:
		lines.append("Aura Range: %d hex | Buff: +%d%% Fire Rate" % [
			range_val, roundi(aura_fire_rate_bonus * 100.0)
		])
	elif targeting_mode == TargetingMode.SUMMON_CONGREGATION:
		lines.append("Range: %d hex | Blockers: %d (%d HP, %.1f DPS)" % [
			range_val, summon_count, roundi(summon_hp), summon_dps
		])
	else:
		lines.append("Range: %d hex | Damage: %.1f %s | Rate: %.2f/s" % [
			range_val, damage, get_damage_tag_name(), fire_rate
		])
	lines.append("Targets: %s" % get_target_domain_text())

	var traits: PackedStringArray = PackedStringArray()
	if detects_cloaked:
		traits.append("Detects Cloaked")
	if pulse_reveal_duration > 0.0:
		traits.append("Reveals Cloaked (%.0fs)" % pulse_reveal_duration)
	if applies_entangled:
		traits.append("Applies Entangled")
	if shred_per_hit > 0:
		traits.append("Armor Shred (+%d/hit)" % shred_per_hit)
	if starting_members > 1:
		traits.append("%d Choir Members" % starting_members)
	if targeting_mode == TargetingMode.CHAIN_ARC and max_targets > 1:
		traits.append("Chains up to %d Targets" % max_targets)
	if not traits.is_empty():
		lines.append("Traits: %s" % ", ".join(traits))

	return "\n".join(lines)


## Fragments describing the tower's ACTUAL distinguishing abilities, built entirely from its
## own fields. The short [member description] sells the theme; this is the reference a player
## reaches for when they have forgotten what a tower on the field does. Because every fragment
## is derived from data rather than hand-written per tower, retuning a tower can never leave
## the panel describing an ability it no longer has (or omitting one it gained). The generic
## "deals X damage" case is deliberately OMITTED: it merely repeats the stat line above it.
func get_ability_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()

	# 1. Role / primary effect -- only for towers whose whole point is not damage (an attacker
	#    already has its damage spelled out in the stat line, so it is not repeated here).
	match targeting_mode:
		TargetingMode.ECONOMY_TITHE:
			lines.append("Economy: +%d Offerings every %.1f s (no attack)" % [
				income_offerings, income_interval
			])
		TargetingMode.BUFF_SHRINE:
			lines.append("Support aura: +%d%% fire rate to towers within %d hexes, not stacking (no attack)" % [
				roundi(aura_fire_rate_bonus * 100.0), aura_radius_hexes
			])
		TargetingMode.SUMMON_CONGREGATION:
			lines.append(
				"Summons up to %d blockers (%d HP, %.1f DPS) onto the adjacent path hex, resummoned %.0f s after death"
				% [summon_count, roundi(summon_hp), summon_dps, resummon_time]
			)
		_:
			pass

	# 2. Targeting behaviour that makes the archetype distinct.
	match targeting_mode:
		TargetingMode.HIGHEST_HP:
			lines.append("Always fires at the highest-HP enemy in range")
		TargetingMode.CHANNELED_CHOIR:
			if starting_members > 1:
				lines.append("%d members each deal the damage above, independently" % starting_members)
		TargetingMode.PULSE_AOE:
			if pulse_max_ring > 0:
				lines.append("Each pulse also hits every enemy within %d hex of the target" % pulse_max_ring)
		TargetingMode.CHAIN_ARC:
			if max_targets > 1:
				lines.append("Chain lightning arcs to up to %d enemies" % max_targets)
		TargetingMode.CONTROL_DRAIN:
			lines.append("Primarily a control tower: it slows and roots foes more than it kills")
		TargetingMode.DOT_CENSER:
			lines.append("Primarily a damage-over-time tower: it stacks a burn rather than burst damage")
		_:
			pass

	# 3. Shared mechanics, each shown only when the tower actually carries it.
	if detects_cloaked:
		lines.append("Detects Cloaked enemies continuously in range, letting other towers target them")
	if pulse_reveal_duration > 0.0:
		lines.append("Reveals Cloaked enemies hit for %.0f s" % pulse_reveal_duration)
	if slow_aura_strength > 0.0:
		lines.append("Slows every Ground enemy in range by %d%%" % roundi(slow_aura_strength * 100.0))
	if root_duration > 0.0 and root_interval > 0.0:
		lines.append("Roots a target for %.1f s every %.1f s" % [root_duration, root_interval])
	if applies_entangled:
		lines.append("Slowed or rooted enemies become Entangled (+25% damage from Gutter Ritual Circle pulses)")
	if dot_damage > 0.0:
		lines.append("Applies a %.1f/s %s burn for %.0f s, stacking up to %d times" % [
			dot_damage, get_damage_tag_name(), dot_duration, dot_max_stacks
		])
	if shred_per_hit > 0:
		lines.append("Each hit adds %d Armor Shred (+5%% damage taken per stack)" % shred_per_hit)
	if aura_fire_rate_bonus > 0.0 and targeting_mode != TargetingMode.BUFF_SHRINE:
		lines.append("Boosts friendly towers within %d hexes by +%d%% fire rate" % [
			aura_radius_hexes, roundi(aura_fire_rate_bonus * 100.0)
		])
	if income_offerings > 0 and targeting_mode != TargetingMode.ECONOMY_TITHE:
		lines.append("Generates +%d Offerings every %.1f s" % [income_offerings, income_interval])
	if summon_count > 0 and targeting_mode != TargetingMode.SUMMON_CONGREGATION:
		lines.append("Summons %d blockers (%d HP, %.1f DPS)" % [
			summon_count, roundi(summon_hp), summon_dps
		])
	if max_targets > 1 and targeting_mode != TargetingMode.CHAIN_ARC:
		lines.append("Strikes up to %d enemies at once" % max_targets)

	return lines


## The ability fragments as ONE compact wrapped "ABILITIES: a; b; c." sentence, or "" when the
## tower has no distinguishing abilities to call out (e.g. a plain single-target gun). A single
## wrapped sentence packs far tighter than one bullet per line, which keeps the fixed-height
## tower panel from scrolling.
func get_ability_summary() -> String:
	var lines: PackedStringArray = get_ability_lines()
	if lines.is_empty():
		return ""
	return "ABILITIES: " + "; ".join(lines) + "."


## Returns a compact summary of the tower's upgrade branches when defined.
func get_upgrade_preview_summary() -> String:
	if (
		t2_upgrade == null
		and revealed_t3_upgrade == null
		and rigged_t3_upgrade == null
		and rite_t3_upgrade == null
	):
		return ""
	var lines: PackedStringArray = PackedStringArray()
	if t2_upgrade != null:
		lines.append("T2: %s — %s" % [t2_upgrade.display_name, t2_upgrade.description])
	if revealed_t3_upgrade != null:
		var rev4_name: String = (" -> " + revealed_t4_upgrade.display_name) if revealed_t4_upgrade != null else ""
		lines.append("Revealed (Cult): %s%s" % [revealed_t3_upgrade.display_name, rev4_name])
	if rigged_t3_upgrade != null:
		var rig4_name: String = (" -> " + rigged_t4_upgrade.display_name) if rigged_t4_upgrade != null else ""
		lines.append("Rigged (Scrap): %s%s" % [rigged_t3_upgrade.display_name, rig4_name])
	if rite_t3_upgrade != null:
		var rite4_name: String = (" -> " + rite_t4_upgrade.display_name) if rite_t4_upgrade != null else ""
		lines.append("Rite (Draw on Corruption): %s%s" % [rite_t3_upgrade.display_name, rite4_name])
	return "\n".join(lines)
