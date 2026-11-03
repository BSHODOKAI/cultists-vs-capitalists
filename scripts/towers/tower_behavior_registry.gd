## TowerBehaviorRegistry
##
## Central registry of all named tower base behaviors (9) and upgrade node
## behaviors (45). UpgradeNode and TowerData resources reference behaviors by
## string ID plus declarative stat modifiers and behavior_params, allowing new
## nodes to be authored as .tres files without engine changes.
class_name TowerBehaviorRegistry
extends RefCounted

static var _registry: Dictionary = {}
static var _initialized: bool = false


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	# --- 9 Base Tower Archetype Behaviors ------------------------------------
	_register("hexed_nail_gun", {"type": "base_tower", "tower_id": "hexed_nail_gun"})
	_register("chanting_choir", {"type": "base_tower", "tower_id": "chanting_choir"})
	_register("gutter_ritual_circle", {"type": "base_tower", "tower_id": "gutter_ritual_circle"})
	_register("tentacle_storm_drain", {"type": "base_tower", "tower_id": "tentacle_storm_drain"})
	_register("watcher_in_the_billboard", {"type": "base_tower", "tower_id": "watcher_in_the_billboard"})
	_register("rust_censer", {"type": "base_tower", "tower_id": "rust_censer"})
	_register("fever_shrine", {"type": "base_tower", "tower_id": "fever_shrine"})
	_register("the_congregation", {"type": "base_tower", "tower_id": "the_congregation"})
	_register("tithe_box", {"type": "base_tower", "tower_id": "tithe_box"})
	_register("substation_effigy", {"type": "base_tower", "tower_id": "substation_effigy"})

	# --- 1. hexed_nail_gun upgrades ------------------------------------------
	_register("rapid_cycling", {"type": "upgrade", "tower_id": "hexed_nail_gun", "tier": 2})
	_register("whispering_nails", {"type": "upgrade", "tower_id": "hexed_nail_gun", "tier": 3, "ignore_resistance": 0.25})
	_register("nails_that_remember", {"type": "upgrade", "tower_id": "hexed_nail_gun", "tier": 4, "return_hit_ratio": 0.50})
	_register("drone_feeder", {"type": "upgrade", "tower_id": "hexed_nail_gun", "tier": 3, "never_reloads": true})
	_register("pneumatic_belt_rig", {"type": "upgrade", "tower_id": "hexed_nail_gun", "tier": 4, "burst_shots": 5, "armored_bonus": 0.50})

	# --- 2. chanting_choir upgrades ------------------------------------------
	_register("deeper_harmony", {"type": "upgrade", "tower_id": "chanting_choir", "tier": 2})
	_register("dissonant_hymn", {"type": "upgrade", "tower_id": "chanting_choir", "tier": 3, "fear_max_stacks": 5})
	_register("the_unspoken_verse", {"type": "upgrade", "tower_id": "chanting_choir", "tier": 4, "flee_duration": 2.0, "flee_cooldown": 10.0})
	_register("bullhorn_array", {"type": "upgrade", "tower_id": "chanting_choir", "tier": 3})
	_register("jammer_choir", {"type": "upgrade", "tower_id": "chanting_choir", "tier": 4, "stun_duration": 1.5, "stun_interval": 8.0})

	# --- 3. gutter_ritual_circle upgrades ------------------------------------
	_register("wider_circle", {"type": "upgrade", "tower_id": "gutter_ritual_circle", "tier": 2, "ring_2_damage_ratio": 0.50})
	_register("ichor_bloom", {"type": "upgrade", "tower_id": "gutter_ritual_circle", "tier": 3, "puddle_duration": 4.0, "puddle_dps": 8.0})
	_register("maw_beneath", {"type": "upgrade", "tower_id": "gutter_ritual_circle", "tier": 4, "maw_interval": 12.0, "execute_ratio": 0.30})
	_register("propane_pulse", {"type": "upgrade", "tower_id": "gutter_ritual_circle", "tier": 3, "knockback_hexes": 1})
	_register("chain_detonator", {"type": "upgrade", "tower_id": "gutter_ritual_circle", "tier": 4, "explosion_ratio": 0.40, "explosion_radius": 1})

	# --- 4. tentacle_storm_drain upgrades ------------------------------------
	_register("more_grates", {"type": "upgrade", "tower_id": "tentacle_storm_drain", "tier": 2})
	_register("deep_grasp", {"type": "upgrade", "tower_id": "tentacle_storm_drain", "tier": 3, "root_duration": 2.5, "drag_hexes": 1})
	_register("leviathan_awakens", {"type": "upgrade", "tower_id": "tentacle_storm_drain", "tier": 4, "sweep_interval": 25.0, "sweep_damage": 120.0})
	_register("flood_pump", {"type": "upgrade", "tower_id": "tentacle_storm_drain", "tier": 3, "flood_slow": 0.40})
	_register("live_wire_flood", {"type": "upgrade", "tower_id": "tentacle_storm_drain", "tier": 4, "electric_dps": 12.0})

	# --- 5. watcher_in_the_billboard upgrades --------------------------------
	_register("dilated_pupil", {"type": "upgrade", "tower_id": "watcher_in_the_billboard", "tier": 2})
	_register("gaze_of_unmaking", {"type": "upgrade", "tower_id": "watcher_in_the_billboard", "tier": 3, "mark_bonus": 0.15, "mark_duration": 6.0})
	_register("the_eye_opens", {"type": "upgrade", "tower_id": "watcher_in_the_billboard", "tier": 4, "nth_shot": 4, "max_hp_ratio": 0.12, "boss_ratio": 0.04})
	_register("rooftop_scope_array", {"type": "upgrade", "tower_id": "watcher_in_the_billboard", "tier": 3, "crit_chance": 0.25, "crit_mult": 2.0})
	_register("ad_hijack", {"type": "upgrade", "tower_id": "watcher_in_the_billboard", "tier": 4, "confuse_duration": 1.5, "confuse_radius": 1})

	# --- 6. rust_censer upgrades ---------------------------------------------
	_register("heavier_incense", {"type": "upgrade", "tower_id": "rust_censer", "tier": 2})
	_register("plague_incense", {"type": "upgrade", "tower_id": "rust_censer", "tier": 3, "spread_radius": 1})
	_register("rust_communion", {"type": "upgrade", "tower_id": "rust_censer", "tier": 4, "shred_cap": 8, "cybernetic_double": true})
	_register("acid_sprayer", {"type": "upgrade", "tower_id": "rust_censer", "tier": 3})
	_register("solvent_tank", {"type": "upgrade", "tower_id": "rust_censer", "tier": 4, "shred_cap": 10, "armored_dot_bonus": 1.0, "scrap_upkeep": 4})

	# --- 7. fever_shrine upgrades --------------------------------------------
	_register("more_candles", {"type": "upgrade", "tower_id": "fever_shrine", "tier": 2})
	_register("frenzy_rites", {"type": "upgrade", "tower_id": "fever_shrine", "tier": 3, "upkeep_per_tower": 4})
	_register("ecstatic_vigil", {"type": "upgrade", "tower_id": "fever_shrine", "tier": 4, "burst_interval": 20.0, "burst_duration": 3.0})
	_register("server_rack_altar", {"type": "upgrade", "tower_id": "fever_shrine", "tier": 3})
	_register("mesh_network", {"type": "upgrade", "tower_id": "fever_shrine", "tier": 4, "rate_per_type": 0.06, "max_bonus": 0.30})

	# --- 8. the_congregation upgrades ----------------------------------------
	_register("bigger_flock", {"type": "upgrade", "tower_id": "the_congregation", "tier": 2})
	_register("devoted", {"type": "upgrade", "tower_id": "the_congregation", "tier": 3, "explosion_damage": 40.0})
	_register("martyrs_chorus", {"type": "upgrade", "tower_id": "the_congregation", "tier": 4, "ghost_duration": 8.0, "ghost_dps": 10.0})
	_register("picket_line", {"type": "upgrade", "tower_id": "the_congregation", "tier": 3, "damage_reduction": 0.30})
	_register("union_strike", {"type": "upgrade", "tower_id": "the_congregation", "tier": 4, "melee_slow": 0.30})

	# --- 9. tithe_box upgrades -----------------------------------------------
	_register("bigger_plate", {"type": "upgrade", "tower_id": "tithe_box", "tier": 2})
	_register("blood_tithe", {"type": "upgrade", "tower_id": "tithe_box", "tier": 3, "corruption_per_wave": 1})
	_register("dark_patron", {"type": "upgrade", "tower_id": "tithe_box", "tier": 4, "kill_offerings_bonus": 0.10, "max_boxes": 3})
	_register("scrap_collector", {"type": "upgrade", "tower_id": "tithe_box", "tier": 3, "kill_scrap_bonus": 0.25, "max_boxes": 3})
	_register("chop_shop", {"type": "upgrade", "tower_id": "tithe_box", "tier": 4, "jank_reduction": 10, "radius_hexes": 3})

	# --- 10. substation_effigy upgrades --------------------------------------
	_register("copper_thieves", {"type": "upgrade", "tower_id": "substation_effigy", "tier": 2})
	_register("astral_conduction", {"type": "upgrade", "tower_id": "substation_effigy", "tier": 3, "bounce_decay": 1.0, "chain_hop_range": 3, "air_damage_bonus": 0.25})
	_register("voice_in_the_static", {"type": "upgrade", "tower_id": "substation_effigy", "tier": 4, "storm_interval": 10.0, "storm_damage": 45.0, "storm_radius": 1, "storm_slow": 0.35, "storm_slow_duration": 3.0})
	_register("substation_tap", {"type": "upgrade", "tower_id": "substation_effigy", "tier": 3})
	_register("breaker_cascade", {"type": "upgrade", "tower_id": "substation_effigy", "tier": 4, "nth_shot": 5, "overload_damage_bonus": 0.50, "stun_duration": 0.8, "tag_damage_bonus": 0.35})


static func _register(behavior_id: String, descriptor: Dictionary) -> void:
	_registry[behavior_id] = descriptor


static func register_behavior(behavior_id: String, descriptor: Dictionary) -> void:
	_ensure_initialized()
	_registry[behavior_id] = descriptor


static func has_behavior(behavior_id: String) -> bool:
	_ensure_initialized()
	return _registry.has(behavior_id)


static func get_descriptor(behavior_id: String) -> Dictionary:
	_ensure_initialized()
	return _registry.get(behavior_id, {})


static func get_all_registered_ids() -> Array[String]:
	_ensure_initialized()
	var out: Array[String] = []
	for k: String in _registry.keys():
		out.append(k)
	return out
