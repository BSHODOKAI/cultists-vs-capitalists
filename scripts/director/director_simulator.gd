## DirectorSimulator
##
## Headless simulation harness that runs 100 waves against the 4 scripted player
## profiles specified in the prompt:
##   • "all_nail_gun" (all Nail Gun)
##   • "balanced"     (balanced mix)
##   • "all_revealed" (all Revealed branch)
##   • "all_rigged"   (all Rigged branch)
##
## Uses synthetic coverage fed through CoverageTracker (via tower_damaged_enemy
## events over the previous 2 waves), tracks unit kill leveling and rubber-banding,
## exports per-wave rosters and tag exposure to CSV, and verifies that no profile
## is trivially safe or trivially punished.
class_name DirectorSimulator
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _Balance = preload("res://scripts/director/director_balance_data.gd")
const _CoverageTracker = preload("res://scripts/director/coverage_tracker.gd")
const _WaveRoster = preload("res://scripts/director/wave_roster.gd")
const _WaveDirector = preload("res://scripts/director/wave_director.gd")

const PROFILE_ALL_NAIL_GUN: String = "all_nail_gun"
const PROFILE_BALANCED: String = "balanced"
const PROFILE_ALL_REVEALED: String = "all_revealed"
const PROFILE_ALL_RIGGED: String = "all_rigged"

const ALL_PROFILES: Array[String] = [
	PROFILE_ALL_NAIL_GUN,
	PROFILE_BALANCED,
	PROFILE_ALL_REVEALED,
	PROFILE_ALL_RIGGED,
]


## Returns the synthetic profile definition for [param profile_id].
static func get_profile_config(profile_id: String, wave_number: int = 1) -> Dictionary:
	# Scale synthetic player DPS with wave progression so coverage numbers
	# reflect a defense that grows alongside the wave economy.
	var wf: float = float(maxi(1, wave_number))
	var scale: float = 1.0 + 0.22 * wf + 0.0055 * wf * wf
	match profile_id:
		PROFILE_ALL_NAIL_GUN:
			return {
				"profile_id": PROFILE_ALL_NAIL_GUN,
				"tower_type": "hexed_nail_gun",
				"damage_tag": _C.DamageTag.KINETIC,
				"tower_branch_mix": {"revealed": 0, "rigged": 0, "congregation": 0},
				"tag_efficiency": {
					_C.UnitTag.GROUND: 24.0 * scale,
					_C.UnitTag.AIR: 22.0 * scale,
					_C.UnitTag.FAST: 20.0 * scale,
					_C.UnitTag.FRAGILE: 26.0 * scale,
					_C.UnitTag.ARMORED: 5.5 * scale,     # weak vs armor
					_C.UnitTag.SHIELDED: 6.0 * scale,    # weak vs shields
					_C.UnitTag.CLOAKED: 0.0,             # no detection!
					_C.UnitTag.SWARM: 6.5 * scale,       # single-target struggles vs swarm
					_C.UnitTag.HEALER: 15.0 * scale,
					_C.UnitTag.SPAWNER: 8.0 * scale,
					_C.UnitTag.SUPPORT: 15.0 * scale,
					_C.UnitTag.AURA: 15.0 * scale,
					_C.UnitTag.HACKER: 16.0 * scale,
					_C.UnitTag.ELECTRIC: 16.0 * scale,
					_C.UnitTag.ANTI_MAGIC: 18.0 * scale,
					_C.UnitTag.CYBERNETIC: 12.0 * scale,
					_C.UnitTag.TANK: 7.0 * scale,
					_C.UnitTag.RANGED: 14.0 * scale,
				},
			}
		PROFILE_BALANCED:
			return {
				"profile_id": PROFILE_BALANCED,
				"tower_type": "balanced_mix",
				"damage_tag": _C.DamageTag.CORROSIVE,
				"tower_branch_mix": {"revealed": 3, "rigged": 3, "congregation": 1},
				"tag_efficiency": {
					_C.UnitTag.GROUND: 18.0 * scale,
					_C.UnitTag.AIR: 14.0 * scale,
					_C.UnitTag.FAST: 14.0 * scale,
					_C.UnitTag.FRAGILE: 18.0 * scale,
					_C.UnitTag.ARMORED: 15.0 * scale,
					_C.UnitTag.SHIELDED: 14.0 * scale,
					_C.UnitTag.CLOAKED: 12.0 * scale,
					_C.UnitTag.SWARM: 16.0 * scale,
					_C.UnitTag.HEALER: 13.0 * scale,
					_C.UnitTag.SPAWNER: 12.0 * scale,
					_C.UnitTag.SUPPORT: 14.0 * scale,
					_C.UnitTag.AURA: 14.0 * scale,
					_C.UnitTag.HACKER: 12.0 * scale,
					_C.UnitTag.ELECTRIC: 13.0 * scale,
					_C.UnitTag.ANTI_MAGIC: 13.0 * scale,
					_C.UnitTag.CYBERNETIC: 14.0 * scale,
					_C.UnitTag.TANK: 11.5 * scale,
					_C.UnitTag.RANGED: 13.0 * scale,
				},
			}
		PROFILE_ALL_REVEALED:
			return {
				"profile_id": PROFILE_ALL_REVEALED,
				"tower_type": "revealed_cult",
				"damage_tag": _C.DamageTag.VOID,
				"tower_branch_mix": {"revealed": 6, "rigged": 0, "congregation": 1},
				"tag_efficiency": {
					_C.UnitTag.GROUND: 22.0 * scale,
					_C.UnitTag.AIR: 15.0 * scale,
					_C.UnitTag.FAST: 15.0 * scale,
					_C.UnitTag.FRAGILE: 22.0 * scale,
					_C.UnitTag.ARMORED: 19.0 * scale,
					_C.UnitTag.SHIELDED: 22.0 * scale,
					_C.UnitTag.CLOAKED: 19.0 * scale,
					_C.UnitTag.SWARM: 19.0 * scale,
					_C.UnitTag.HEALER: 15.0 * scale,
					_C.UnitTag.SPAWNER: 16.0 * scale,
					_C.UnitTag.SUPPORT: 14.0 * scale,
					_C.UnitTag.AURA: 14.0 * scale,
					_C.UnitTag.HACKER: 16.0 * scale,
					_C.UnitTag.ELECTRIC: 16.0 * scale,
					_C.UnitTag.ANTI_MAGIC: 3.5 * scale,  # vulnerable to Anti-Magic (Compliance Officer)
					_C.UnitTag.CYBERNETIC: 17.0 * scale,
					_C.UnitTag.TANK: 16.0 * scale,
					_C.UnitTag.RANGED: 13.0 * scale,
				},
			}
		PROFILE_ALL_RIGGED:
			return {
				"profile_id": PROFILE_ALL_RIGGED,
				"tower_type": "rigged_junk",
				"damage_tag": _C.DamageTag.ELECTRIC,
				"tower_branch_mix": {"revealed": 0, "rigged": 6, "congregation": 1},
				"tag_efficiency": {
					_C.UnitTag.GROUND: 22.0 * scale,
					_C.UnitTag.AIR: 17.0 * scale,
					_C.UnitTag.FAST: 17.0 * scale,
					_C.UnitTag.FRAGILE: 22.0 * scale,
					_C.UnitTag.ARMORED: 19.0 * scale,
					_C.UnitTag.SHIELDED: 15.0 * scale,
					_C.UnitTag.CLOAKED: 13.0 * scale,
					_C.UnitTag.SWARM: 19.0 * scale,
					_C.UnitTag.HEALER: 15.0 * scale,
					_C.UnitTag.SPAWNER: 16.0 * scale,
					_C.UnitTag.SUPPORT: 14.0 * scale,
					_C.UnitTag.AURA: 14.0 * scale,
					_C.UnitTag.HACKER: 3.5 * scale,      # vulnerable to Hacker (Acquisitions Rep)
					_C.UnitTag.ELECTRIC: 4.0 * scale,    # vulnerable to Electric (Taser Skirmisher)
					_C.UnitTag.ANTI_MAGIC: 19.0 * scale,
					_C.UnitTag.CYBERNETIC: 17.0 * scale,
					_C.UnitTag.TANK: 16.0 * scale,
					_C.UnitTag.RANGED: 15.0 * scale,
				},
			}
		_:
			return get_profile_config(PROFILE_BALANCED, wave_number)


## Runs a 100-wave simulation for a single [param profile_id] with [param run_seed].
func run_profile_simulation(
	profile_id: String,
	total_waves: int = 100,
	run_seed: int = 1337
) -> Dictionary:
	var director := _WaveDirector.new(run_seed)
	var wave_rows: Array[Dictionary] = []
	var total_leaks: int = 0
	var waves_with_leaks: int = 0
	var zero_leak_waves: int = 0
	var min_rubber: float = 1.0
	var max_rubber: float = 1.0
	var total_counter_picks: int = 0
	var total_regular_units: int = 0

	for w in range(1, total_waves + 1):
		var prof: Dictionary = get_profile_config(profile_id, w)
		var branch_mix: Dictionary = prof["tower_branch_mix"]
		var tag_eff: Dictionary = prof["tag_efficiency"]

		var path_summary: Dictionary = {
			"wave_time_window": 36.0,
			"long_exposed_stretches": 6 if (w % 4 == 0) else 2,
			"dense_overlap_zones": 3 + (w / 10),
			"has_undefended_preview_stretch": (w % 10 == 8 or w % 10 == 9),
		}

		var roster: WaveRoster = director.generate_wave(w, {
			"tower_branch_mix": branch_mix,
			"path_layout_summary": path_summary,
		})

		# Simulate combat damage events into director.coverage_tracker for wave w
		var wave_duration: float = 30.0
		director.coverage_tracker.on_wave_started(w)
		var unmitigated_threat: float = 0.0
		var mitigated_threat: float = 0.0

		for entry: Dictionary in roster.entries:
			var uid: String = String(entry["unit_id"])
			var cnt: int = int(entry["count"])
			var tags: Array = entry["tags"]
			var e_cost: float = float(entry["total_cost"])
			total_regular_units += cnt

			# Check if this unit exploits the profile's specific weakness
			if profile_id == PROFILE_ALL_REVEALED and tags.has(_C.UnitTag.ANTI_MAGIC):
				total_counter_picks += cnt
			elif profile_id == PROFILE_ALL_RIGGED and (tags.has(_C.UnitTag.HACKER) or tags.has(_C.UnitTag.ELECTRIC)):
				total_counter_picks += cnt
			elif profile_id == PROFILE_ALL_NAIL_GUN and (
				tags.has(_C.UnitTag.ARMORED) or tags.has(_C.UnitTag.SHIELDED) or tags.has(_C.UnitTag.CLOAKED) or tags.has(_C.UnitTag.SWARM)
			):
				total_counter_picks += cnt
			elif profile_id == PROFILE_BALANCED and (
				tags.has(_C.UnitTag.TANK) or tags.has(_C.UnitTag.SPAWNER) or tags.has(_C.UnitTag.HACKER) or tags.has(_C.UnitTag.CLOAKED)
			):
				total_counter_picks += cnt

			# Compute synthetic damage dealt to this entry's tags over wave_duration
			var min_tag_dps: float = INF
			for t: int in tags:
				var tdps: float = float(tag_eff.get(t, 10.0))
				if tdps < min_tag_dps:
					min_tag_dps = tdps
			if min_tag_dps == INF:
				min_tag_dps = 10.0

			var dmg_dealt: float = min_tag_dps * wave_duration * (float(cnt) / maxf(1.0, float(roster.get_total_regular_unit_count())))
			director.coverage_tracker.on_tower_damaged_enemy(
				1,
				String(prof["tower_type"]),
				0,
				tags,
				dmg_dealt,
				int(prof["damage_tag"]),
				w
			)

			var required_dps: float = e_cost * 1.35
			if min_tag_dps >= required_dps * 0.45:
				mitigated_threat += e_cost
				director.leveling.record_kill(uid, false, cnt)
			else:
				unmitigated_threat += e_cost * (1.0 - clampf(min_tag_dps / maxf(1.0, required_dps), 0.0, 1.0))
				var killed_part: int = maxi(0, cnt - 1)
				director.leveling.record_kill(uid, false, killed_part)

		director.coverage_tracker.on_wave_ended(w, wave_duration)
		if roster.is_boss_wave:
			director.on_boss_killed(w)

		# Estimate leaks from unmitigated_threat relative to wave budget
		var threat_ratio: float = unmitigated_threat / maxf(1.0, roster.budget)
		var leaks_this_wave: int = 0
		if threat_ratio > 0.38:
			leaks_this_wave = 2
		elif threat_ratio > 0.20:
			leaks_this_wave = 1

		total_leaks += leaks_this_wave
		if leaks_this_wave > 0:
			waves_with_leaks += 1
		else:
			zero_leak_waves += 1

		director.update_rubber_factor(leaks_this_wave)
		min_rubber = minf(min_rubber, director.rubber_factor)
		max_rubber = maxf(max_rubber, director.rubber_factor)

		var roster_summary_parts: Array[String] = []
		for e: Dictionary in roster.entries:
			roster_summary_parts.append("%s:%d(L%d)" % [
				String(e["unit_id"]),
				int(e["count"]),
				int(e["spawn_level"]),
			])

		var row: Dictionary = {
			"profile": profile_id,
			"wave": w,
			"interval": roster.interval_index,
			"cycle": roster.completed_cycles,
			"faction": roster.active_faction,
			"is_boss": roster.is_boss_wave,
			"is_stars": roster.is_stars_are_right,
			"rubber_factor": roster.effective_rubber_factor,
			"budget": roster.budget,
			"spent": roster.total_cost,
			"unit_count": roster.get_total_regular_unit_count(),
			"distinct_types": roster.get_distinct_unit_type_count(),
			"roster_summary": ";".join(roster_summary_parts),
			"ground_share": float(roster.per_tag_exposure["GROUND"]["budget_share"]),
			"air_share": float(roster.per_tag_exposure["AIR"]["budget_share"]),
			"armored_share": float(roster.per_tag_exposure["ARMORED"]["budget_share"]),
			"anti_magic_share": float(roster.per_tag_exposure["ANTI_MAGIC"]["budget_share"]),
			"hacker_share": float(roster.per_tag_exposure["HACKER"]["budget_share"]),
			"electric_share": float(roster.per_tag_exposure["ELECTRIC"]["budget_share"]),
			"cloaked_share": float(roster.per_tag_exposure["CLOAKED"]["budget_share"]),
			"leaks": leaks_this_wave,
		}
		wave_rows.append(row)

	# A profile is neither trivially safe (must face pressure / counter picks or leaks)
	# nor trivially punished (must clear a majority of waves without endless max-leak wipeouts).
	var not_trivially_safe: bool = (total_counter_picks > 0 or waves_with_leaks > 0)
	var not_trivially_punished: bool = (zero_leak_waves >= int(total_waves * 0.30) and total_leaks < total_waves * 2)

	return {
		"profile_id": profile_id,
		"total_waves": total_waves,
		"rows": wave_rows,
		"total_leaks": total_leaks,
		"waves_with_leaks": waves_with_leaks,
		"zero_leak_waves": zero_leak_waves,
		"total_counter_picks": total_counter_picks,
		"total_regular_units": total_regular_units,
		"min_rubber": min_rubber,
		"max_rubber": max_rubber,
		"not_trivially_safe": not_trivially_safe,
		"not_trivially_punished": not_trivially_punished,
	}


## Runs all 4 scripted player profiles for [param total_waves] waves and returns
## full results + CSV text.
func run_all_profiles(
	total_waves: int = 100,
	run_seed: int = 1337,
	print_csv: bool = false,
	save_csv_path: String = ""
) -> Dictionary:
	var profile_results: Dictionary = {}
	var csv_lines: Array[String] = [
		"profile,wave,interval,cycle,faction,is_boss,is_stars,rubber_factor,budget,spent,unit_count,distinct_types,roster,ground_share,air_share,armored_share,anti_magic_share,hacker_share,electric_share,cloaked_share,leaks"
	]

	var all_fair: bool = true
	for pid: String in ALL_PROFILES:
		var res: Dictionary = run_profile_simulation(pid, total_waves, run_seed)
		profile_results[pid] = res
		if not bool(res["not_trivially_safe"]) or not bool(res["not_trivially_punished"]):
			all_fair = false
		var rows: Array = res["rows"]
		for r: Dictionary in rows:
			csv_lines.append(
				"%s,%d,%d,%d,%s,%s,%s,%.2f,%.2f,%.2f,%d,%d,\"%s\",%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d" % [
					String(r["profile"]),
					int(r["wave"]),
					int(r["interval"]),
					int(r["cycle"]),
					String(r["faction"]),
					str(bool(r["is_boss"])),
					str(bool(r["is_stars"])),
					float(r["rubber_factor"]),
					float(r["budget"]),
					float(r["spent"]),
					int(r["unit_count"]),
					int(r["distinct_types"]),
					String(r["roster_summary"]),
					float(r["ground_share"]),
					float(r["air_share"]),
					float(r["armored_share"]),
					float(r["anti_magic_share"]),
					float(r["hacker_share"]),
					float(r["electric_share"]),
					float(r["cloaked_share"]),
					int(r["leaks"]),
				]
			)

	var csv_text: String = "\n".join(csv_lines)
	if not save_csv_path.is_empty():
		var f := FileAccess.open(save_csv_path, FileAccess.WRITE)
		if f != null:
			f.store_string(csv_text)
			f.close()

	if print_csv:
		print(csv_text)

	return {
		"profiles": profile_results,
		"csv": csv_text,
		"csv_line_count": csv_lines.size(),
		"all_profiles_fair": all_fair,
	}
