## Read-only post-run interpretation of the combat ledger and deterministic event log.
class_name QuarterlyReport
extends RefCounted

const COUNTER_NOTES = {
	"counter_revealed_anti_magic": "Anti-magic units received extra weight against a Revealed-heavy build.",
	"counter_rigged_hacker_electric": "Hacker and electric units received extra weight against a Rigged-heavy build.",
	"counter_congregation_breakthrough": "Breakthrough units received extra weight against heavy Congregation use.",
	"path_exposed_fast_ranged": "Fast and ranged units received extra weight on an exposed route.",
	"path_overlap_armored_spawner": "Armored units and spawners received extra weight where routes passed close together.",
	"path_preview_undefended": "Mobile or hard-to-answer units received extra weight while an undefended route extension was on the books.",
}

var wave: int = 0
var cause: String = "No fatal breach was recorded."
var bosses: String = "No executives deployed."
var reckoning: String = "No Reckoning came due."
var dossier: Array[Dictionary] = []
var assets: Array[Dictionary] = []


static func build(reached_wave: int, loss: LossReport, events: Array[Dictionary], tower_totals: Dictionary) -> QuarterlyReport:
	var report: QuarterlyReport = QuarterlyReport.new()
	report.wave = reached_wave
	var fatal_id: String = loss.leaked_unit_id if loss != null else ""
	var reason: String = ""
	var boss_spawns: Dictionary = {}
	var boss_results: Dictionary = {}
	var last_boss_result: String = ""
	var bosses_slain: int = 0
	var rogue_instances: Dictionary = {}
	var rogue_waves: Dictionary = {}
	var waves_cleared: Dictionary = {}
	var rogue_kills: int = 0
	var rogue_leaks: int = 0
	var rogue_lives: int = 0
	var picks: Dictionary = {}
	var excluded: Dictionary = {}
	var deployed: Dictionary = {}
	var candidates: Array[Dictionary] = []

	for event: Dictionary in events:
		var payload: Dictionary = event.get("payload", {})
		var event_wave: int = int(payload.get("wave", 0))
		var instance_id: int = int(payload.get("unit_id", -1))
		var kind: String = String(event.get("event", ""))
		match kind:
			"wave_started":
				picks[event_wave] = payload.get("pick_rationales", [])
				var swapped: Dictionary = {}
				for swap: Dictionary in payload.get("fairness_swaps", []):
					# Rationale is pre-swap. Neither side's deployment can be safely matched.
					swapped[swap.get("removed_unit_id", "")] = true
					swapped[swap.get("added_unit_id", "")] = true
				excluded[event_wave] = swapped
			"unit_spawned":
				var unit_type: String = String(payload.get("type", ""))
				if bool(payload.get("is_boss", false)):
					boss_spawns[event_wave] = unit_type
				elif not unit_type.is_empty():
					if not deployed.has(event_wave):
						deployed[event_wave] = {}
					var counts: Dictionary = deployed[event_wave]
					counts[unit_type] = int(counts.get(unit_type, 0)) + 1
			"boss_killed", "boss_leaked":
				boss_results[event_wave] = true
				var slain: bool = kind == "boss_killed"
				bosses_slain += int(slain)
				var boss_type: String = String(boss_spawns.get(event_wave, "" if slain else fatal_id))
				var boss_name: String = unit_name(boss_type) if not boss_type.is_empty() else "Executive"
				last_boss_result = "Wave %d: %s %s." % [event_wave, boss_name, "slain" if slain else "breached the Sanctum"]
			"rogue_entity_spawned":
				rogue_instances[instance_id] = true
				rogue_waves[event_wave] = true
			"enemy_died":
				rogue_kills += int(rogue_instances.erase(instance_id))
			"enemy_leaked":
				if rogue_instances.erase(instance_id):
					rogue_leaks += 1
					rogue_lives += int(payload.get("leak_cost", 0))
			"wave_ended":
				waves_cleared[event_wave] = true
			"game_over":
				reason = String(payload.get("reason", ""))
				break # Ignore anything emitted after the fatal breach in the same tick.

	if not fatal_id.is_empty():
		var fatal_name: String = unit_name(fatal_id)
		report.cause = "%s breached the Sanctum. No lives remained." % fatal_name
		if reason == "boss_leaked":
			report.cause = "%s breached the Sanctum. An executive breach ends the run immediately." % fatal_name
	elif reason == "lives_depleted":
		report.cause = "The Sanctum ran out of lives. The final attacker was not recorded."

	if not boss_spawns.is_empty() or not boss_results.is_empty():
		report.bosses = "Executives slain: %d." % bosses_slain
		if boss_spawns.has(reached_wave) and not boss_results.has(reached_wave):
			report.bosses += " Wave %d: %s was still in play at the breach." % [reached_wave, unit_name(boss_spawns[reached_wave])]
		elif not last_boss_result.is_empty():
			report.bosses += " " + last_boss_result
	if not rogue_waves.is_empty():
		var survived: int = 0
		for w: int in rogue_waves:
			survived += int(waves_cleared.has(w))
		report.reckoning = "Waves survived: %d/%d. Rogues slain: %d. Breaches: %d (%d in leak costs)." % [survived, rogue_waves.size(), rogue_kills, rogue_leaks, rogue_lives]
		if not rogue_instances.is_empty():
			report.reckoning += " Unresolved Rogues: %d." % rogue_instances.size()

	for w: int in picks:
		var counts: Dictionary = deployed.get(w, {})
		var skip: Dictionary = excluded.get(w, {})
		for pick: Dictionary in picks[w]:
			var unit_type: String = String(pick.get("unit_id", ""))
			if not counts.has(unit_type) or skip.has(unit_type):
				continue
			var note: Dictionary = _pick_note(String(pick.get("dominant_reason", "")), waves_cleared.has(w - 1))
			if not note.is_empty():
				note.merge({"wave": w, "unit_id": unit_type, "count": counts[unit_type], "fatal": unit_type == fatal_id and w == reached_wave})
				candidates.append(note)
	candidates.sort_custom(_evidence_first)
	var shown_units: Dictionary = {}
	var shown_reasons: Dictionary = {}
	for note: Dictionary in candidates:
		var unit_type: String = note["unit_id"]
		var text: String = note["text"]
		if shown_units.has(unit_type) or shown_reasons.has(text):
			continue
		report.dossier.append(note)
		shown_units[unit_type] = true
		shown_reasons[text] = true
		if report.dossier.size() == 2:
			break

	for total: Dictionary in tower_totals.values():
		report.assets.append(total.duplicate())
	report.assets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["damage"] != b["damage"]:
			return a["damage"] > b["damage"]
		return a["tower_id"] < b["tower_id"]
	)
	return report


static func _evidence_first(a: Dictionary, b: Dictionary) -> bool:
	if a["priority"] != b["priority"]:
		return a["priority"] > b["priority"]
	if a["fatal"] != b["fatal"]:
		return a["fatal"]
	if a["wave"] != b["wave"]:
		return a["wave"] > b["wave"]
	if a["count"] != b["count"]:
		return a["count"] > b["count"]
	return a["unit_id"] < b["unit_id"]


static func _pick_note(reason: String, has_prior_wave: bool) -> Dictionary:
	var key: String = reason.get_slice("(", 0)
	if COUNTER_NOTES.has(key):
		return {"priority": 3, "text": COUNTER_NOTES[key]}
	if key.begins_with("low_") and key.ends_with("_coverage"):
		var tag: String = key.trim_prefix("low_").trim_suffix("_coverage").replace("_", "-").capitalize()
		if has_prior_wave:
			return {"priority": 2, "text": "Recent scouting logged little damage against targets tagged %s. That favored this pick; it does not prove the cult lacked an answer." % tag}
		return {"priority": 1, "text": "The Director had no prior-wave damage record. It scored this pick without evidence of the cult’s defenses."}
	match key:
		"faction_specialty":
			return {"priority": 1, "text": "The assigned faction gave this unit extra weight as a specialty. This was not a response to the cult’s build."}
		"fresh_diversity":
			return {"priority": 1, "text": "Recent roster repetition did not penalize this pick."}
		"cost_efficiency":
			return {"priority": 1, "text": "The pick’s recorded rationale was its value against the wave budget."}
	return {}


static func unit_name(unit_id: String) -> String:
	var unit: UnitData = UnitLibrary.get_unit(unit_id)
	return unit.display_name if unit != null else unit_id.replace("_", " ").capitalize()
