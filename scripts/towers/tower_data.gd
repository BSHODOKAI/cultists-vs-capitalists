## TowerData
##
## Designer-editable definition of a tower archetype. Create one .tres per tower
## under res://resources/towers/ and assign it to a [Tower].
##
## A tower has a limited [member attack_range] and delivers its payload according
## to its [member attack_type]:
##   • PROJECTILE — launches a travelling projectile at the target;
##   • INSTANT    — applies its payload to the target immediately (hitscan);
##   • AURA       — repeatedly affects every cell around the tower: a debuff on
##     enemies, or a buff on neighbouring towers.
##
## A payload is [member damage] plus an optional status [member effect] (SLOW or
## BURN). Auras aimed at TOWERS instead improve a friendly [member buff_stat].
class_name TowerData
extends Resource

const _C = preload("res://scripts/path/path_constants.gd")
const _UpgradeNode = preload("res://scripts/towers/upgrade_node.gd")

## How a tower delivers its attack.
enum AttackType {
	PROJECTILE, ## Fires a projectile that travels to the target.
	INSTANT,    ## Applies its effect immediately when it fires (hitscan).
	AURA,       ## Continuously affects the cells surrounding the tower.
}

## Optional status an attack also applies (on hit, or once per aura tick).
enum Effect {
	NONE,  ## Pure damage, no extra status.
	SLOW,  ## Slows the enemy to [code](1 - effect_power)[/code] speed for [member effect_duration].
	BURN,  ## Deals [member effect_power] damage per second for [member effect_duration].
}

## What an AURA tower acts on.
enum AuraTarget {
	ENEMIES, ## A debuff: affects enemies caught inside the aura.
	TOWERS,  ## A buff: affects friendly towers inside the aura (not itself).
}

## Friendly-tower stat that an aura buff improves.
enum TowerStat {
	DAMAGE,    ## Multiplies the tower's damage.
	FIRE_RATE, ## Multiplies the tower's shots per second.
	RANGE,     ## Multiplies the tower's attack range.
}

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
}

## Unique snake_case identifier (e.g. "hexed_nail_gun").
@export var id: String = ""
@export var display_name: String = "Tower"
@export_multiline var description: String = ""
## Optional mesh. When left empty the Tower keeps the mesh from its scene.
@export var mesh: Mesh
## Albedo color applied to the tower's mesh.
@export var color: Color = Color(0.55, 0.8, 1.0, 1.0)
## Build cost (base T1 cost in [member build_currency]).
@export var cost: int = 50
## Currency used to build this tower at T1 (0 = OFFERINGS, 1 = SCRAP).
@export var build_currency: int = _UpgradeNode.Currency.OFFERINGS
## Attack range in world units (legacy 3D node compatibility).
@export var attack_range: float = 3.0
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

@export_group("Attack")
## How the tower delivers its attack.
@export var attack_type: AttackType = AttackType.PROJECTILE
## Projectile scene for PROJECTILE towers. Falls back to Projectile.tscn when empty.
@export var projectile_scene: PackedScene
## Optional status the attack also applies (PROJECTILE: on hit; INSTANT/AURA: each shot/tick).
@export var effect: Effect = Effect.NONE
## Strength of [member effect]: slow fraction (0..1) for SLOW, damage-per-second for BURN.
@export var effect_power: float = 0.0
## How long the applied status lasts, in seconds.
@export var effect_duration: float = 0.0

@export_group("Aura")
## Whether the aura debuffs enemies or buffs friendly towers.
@export var aura_target: AuraTarget = AuraTarget.ENEMIES
## Aura pulses per second (how often the aura is re-applied). Falls back to
## [member fire_rate] when left at 0.
@export var aura_tick_rate: float = 0.0
## Which tower stat an aura buff improves (only used when [member aura_target] is TOWERS).
@export var buff_stat: TowerStat = TowerStat.DAMAGE
## Buff strength as a fraction added to the stat (0.25 = +25%).
@export var buff_amount: float = 0.25


## Returns all 5 upgrade nodes belonging to this tower in canonical order:
## [t2, revealed_t3, revealed_t4, rigged_t3, rigged_t4].
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
	match attack_type:
		AttackType.PROJECTILE:
			return "Fires projectiles dealing %.1f damage at %.1f shots/s within range %.1f." % [
				damage, fire_rate, attack_range
			]
		AttackType.INSTANT:
			if effect == Effect.BURN:
				return "Instant beam dealing %.1f damage (%.1f/s) and burning targets for %.1f DPS over %.1fs." % [
					damage, fire_rate, effect_power, effect_duration
				]
			return "Instant hitscan beam dealing %.1f damage at %.1f shots/s within range %.1f." % [
				damage, fire_rate, attack_range
			]
		AttackType.AURA:
			if aura_target == AuraTarget.TOWERS:
				var stat_name: String = "damage"
				if buff_stat == TowerStat.FIRE_RATE:
					stat_name = "fire rate"
				elif buff_stat == TowerStat.RANGE:
					stat_name = "range"
				return "Support aura that boosts nearby friendly towers' %s by +%d%% within range %.1f." % [
					stat_name, roundi(buff_amount * 100.0), attack_range
				]
			if effect == Effect.SLOW:
				return "Chilling aura that slows enemies by %d%% for %.1fs within range %.1f." % [
					roundi(effect_power * 100.0), effect_duration, attack_range
				]
			return "Aura pulsing %.1f damage to enemies within range %.1f." % [damage, attack_range]
	return "Defensive tower."


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
	return "Kinetic"


## Human-readable summary of what this tower can target.
func get_target_domain_text() -> String:
	if targeting_mode == TargetingMode.ECONOMY_TITHE:
		return "None (Economy)"
	if targeting_mode == TargetingMode.BUFF_SHRINE or (attack_type == AttackType.AURA and aura_target == AuraTarget.TOWERS):
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


## Builds a formatted multi-line stat block for build menus and tooltips.
func get_stats_summary(effective_cost: int = -1, currency_label: String = "Offerings") -> String:
	var shown_cost: int = effective_cost if effective_cost >= 0 else cost
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Cost: %d %s" % [shown_cost, currency_label])

	if not id.is_empty():
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
		if not traits.is_empty():
			lines.append("Traits: %s" % ", ".join(traits))
	else:
		var type_str: String = "Projectile"
		if attack_type == AttackType.INSTANT:
			type_str = "Instant Beam"
		elif attack_type == AttackType.AURA:
			type_str = "Aura (Towers)" if aura_target == AuraTarget.TOWERS else "Aura (Enemies)"
		lines.append("Type: %s | Range: %.1f" % [type_str, attack_range])
		if attack_type == AttackType.AURA and aura_target == AuraTarget.TOWERS:
			var stat_name: String = "Damage"
			if buff_stat == TowerStat.FIRE_RATE:
				stat_name = "Fire Rate"
			elif buff_stat == TowerStat.RANGE:
				stat_name = "Range"
			lines.append("Buff: +%d%% %s" % [roundi(buff_amount * 100.0), stat_name])
		else:
			var rate_val: float = aura_tick_rate if (attack_type == AttackType.AURA and aura_tick_rate > 0.0) else fire_rate
			lines.append("Damage: %.1f | Rate: %.1f/s" % [damage, rate_val])
			if effect == Effect.SLOW:
				lines.append("Effect: %d%% Slow for %.1fs" % [roundi(effect_power * 100.0), effect_duration])
			elif effect == Effect.BURN:
				lines.append("Effect: %.1f Burn DPS for %.1fs" % [effect_power, effect_duration])

	return "\n".join(lines)


## Returns a compact summary of the tower's upgrade branches when defined.
func get_upgrade_preview_summary() -> String:
	if t2_upgrade == null and revealed_t3_upgrade == null and rigged_t3_upgrade == null:
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
	return "\n".join(lines)
