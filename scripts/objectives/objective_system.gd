## ObjectiveSystem
##
## Pure-logic (RefCounted) controller for claimable Objective sites on newly opened
## ground. Objectives are the payload of path growth: they give the player a reason
## to settle the new area, and they give the corporations something to take if the
## area is left alone.
##
## Lifecycle:
##   UNCLAIMED -> CLAIMED   a cult tower stands within claim_radius_hexes and holds it
##   CLAIMED   -> UNCLAIMED the holding tower is sold, destroyed or converted
##   UNCLAIMED -> CAPTURED  enemies linger within capture_radius_hexes for
##                          capture_waves_required consecutive waves
##   CAPTURED  -> CLAIMED   the player re-takes it by building within claim_radius_hexes
##
## Effects are REGION AURAS: a site affects only the ground within aura_radius_hexes
## of itself, so holding a site means garrisoning the ground it sits on and a
## captured site is a dangerous corridor rather than a run-wide tax. Claim state is
## re-evaluated on tower placement/removal and once per wave, so holding a site is a
## live commitment rather than a one-off purchase.
class_name ObjectiveSystem
extends RefCounted

const _HexGrid = preload("res://scripts/path/hex_grid.gd")

signal objective_placed(instance: ObjectiveInstance)
signal objective_state_changed(instance: ObjectiveInstance, old_state: int, new_state: int)

## Maximum hex distance from newly committed path hexes at which a site may appear.
const PLACEMENT_REACH_HEXES: int = 2

var balance: ObjectiveBalanceData
var rng: RandomNumberGenerator
var objectives: Array[ObjectiveInstance] = []
## Id of the last placed objective kind, so consecutive sites vary when possible.
var _last_placed_id: String = ""
## True once an enemy has been near an unclaimed site during the current wave.
var _contested_this_wave: bool = false
var _cached_epoch: int = -1
var _cached_site_count: int = -1
var _cached_aura_radius: int = -1
var _has_claimed_sites: bool = false
var _has_captured_sites: bool = false
var _has_unclaimed_sites: bool = false
var _revealed_bonus_by_hex: Dictionary = {}
var _jam_mult_by_hex: Dictionary = {}
var _capture_speed_by_hex: Dictionary = {}
var _capture_dmg_by_hex: Dictionary = {}


func _init(p_balance: ObjectiveBalanceData = null, p_rng: RandomNumberGenerator = null) -> void:
	balance = p_balance if p_balance != null else ObjectiveBalanceData.new()
	if p_rng != null:
		rng = p_rng
	else:
		rng = RandomNumberGenerator.new()
		rng.seed = 1


func reset() -> void:
	objectives.clear()
	_last_placed_id = ""
	ObjectiveInstance.state_epoch += 1
	_cached_epoch = -1


func _ensure_aura_cache() -> void:
	var r: int = get_aura_radius()
	if (
		_cached_epoch == ObjectiveInstance.state_epoch
		and _cached_site_count == objectives.size()
		and _cached_aura_radius == r
	):
		return
	_cached_epoch = ObjectiveInstance.state_epoch
	_cached_site_count = objectives.size()
	_cached_aura_radius = r
	_has_claimed_sites = false
	_has_captured_sites = false
	_has_unclaimed_sites = false
	_revealed_bonus_by_hex.clear()
	_jam_mult_by_hex.clear()
	_capture_speed_by_hex.clear()
	_capture_dmg_by_hex.clear()

	if objectives.is_empty():
		return
	var disk_offsets: Array[Vector2i] = _HexGrid.hex_disk(Vector2i.ZERO, r)
	for o: ObjectiveInstance in objectives:
		if o == null:
			continue
		if o.state == ObjectiveInstance.State.UNCLAIMED:
			_has_unclaimed_sites = true
		elif o.state == ObjectiveInstance.State.CLAIMED:
			_has_claimed_sites = true
			if o.data != null:
				var rev_b: float = o.data.revealed_damage_bonus
				var jam_m: float = maxf(0.0, o.data.jam_duration_mult)
				for off: Vector2i in disk_offsets:
					var h: Vector2i = o.hex + off
					if rev_b != 0.0:
						_revealed_bonus_by_hex[h] = float(_revealed_bonus_by_hex.get(h, 0.0)) + rev_b
					if not is_equal_approx(jam_m, 1.0):
						_jam_mult_by_hex[h] = float(_jam_mult_by_hex.get(h, 1.0)) * jam_m
		elif o.state == ObjectiveInstance.State.CAPTURED:
			_has_captured_sites = true
			if o.data != null:
				var spd_m: float = 1.0 + maxf(0.0, o.data.capture_enemy_speed_bonus)
				var dmg_m: float = 1.0 - o.data.capture_enemy_damage_reduction
				for off: Vector2i in disk_offsets:
					var h: Vector2i = o.hex + off
					if not is_equal_approx(spd_m, 1.0):
						_capture_speed_by_hex[h] = float(_capture_speed_by_hex.get(h, 1.0)) * spd_m
					if not is_equal_approx(dmg_m, 1.0):
						_capture_dmg_by_hex[h] = float(_capture_dmg_by_hex.get(h, 1.0)) * dmg_m


# --- Queries -----------------------------------------------------------------

func get_site_count() -> int:
	return objectives.size()


func get_objectives_in_state(state: int) -> Array[ObjectiveInstance]:
	var out: Array[ObjectiveInstance] = []
	for o: ObjectiveInstance in objectives:
		if o.state == state:
			out.append(o)
	return out


func get_objective_at(hex: Vector2i) -> ObjectiveInstance:
	for o: ObjectiveInstance in objectives:
		if o.hex == hex:
			return o
	return null


func get_objective_hexes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for o: ObjectiveInstance in objectives:
		out.append(o.hex)
	return out


## True when at least one site is still UNCLAIMED (i.e. capturable). Lets callers
## skip the per-tick enemy scan entirely when nothing can change.
func has_unclaimed_sites() -> bool:
	_ensure_aura_cache()
	return _has_unclaimed_sites


## True when the cult currently holds a site of [param kind].
func has_claimed_kind(kind: int) -> bool:
	for o: ObjectiveInstance in objectives:
		if o.is_claimed() and o.data != null and o.data.kind == kind:
			return true
	return false


## Cheap change signature (hex + state per site) so UI layers can skip redraws.
func get_state_signature() -> String:
	var parts: PackedStringArray = []
	for o: ObjectiveInstance in objectives:
		parts.append("%d,%d,%d" % [o.hex.x, o.hex.y, o.state])
	return "|".join(parts)


func get_state_hexes(state: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for o: ObjectiveInstance in objectives:
		if o.state == state:
			out.append(o.hex)
	return out


# --- Placement ---------------------------------------------------------------

## Places up to [param balance].sites_per_growth sites beside a completed growth.
## Returns the newly placed instances. Deterministic for a given rng state.
func place_for_growth(
	new_hexes: Array[Vector2i],
	grid: HexGrid,
	tower_system: TowerSystem,
	wave: int,
	catalog: Array[ObjectiveData]
) -> Array[ObjectiveInstance]:
	var placed: Array[ObjectiveInstance] = []
	if new_hexes.is_empty() or catalog.is_empty():
		return placed
	if wave < balance.first_objective_wave:
		return placed
	if objectives.size() >= balance.max_sites:
		return placed

	var candidates: Array[Vector2i] = _collect_candidates(new_hexes, grid, tower_system)
	var wanted: int = mini(balance.sites_per_growth, balance.max_sites - objectives.size())
	for _i in range(wanted):
		if candidates.is_empty():
			break
		var pick_idx: int = rng.randi_range(0, candidates.size() - 1)
		var hex: Vector2i = candidates[pick_idx]
		candidates.remove_at(pick_idx)
		var data: ObjectiveData = _pick_data(catalog)
		if data == null:
			break
		var inst := ObjectiveInstance.new(data, hex, wave)
		objectives.append(inst)
		_last_placed_id = data.id
		objective_placed.emit(inst)
		placed.append(inst)
	return placed


## Debug helper: forces a site of [param data] beside [param center], ignoring the
## `first_objective_wave` gate, so a specific site kind can be reached without
## clearing a boss. Reuses the real candidate rules, so the forced site is legal.
func debug_force_site(
	data: ObjectiveData,
	center: Vector2i,
	grid: HexGrid,
	tower_system: TowerSystem,
	wave: int
) -> ObjectiveInstance:
	if data == null:
		return null
	var candidates: Array[Vector2i] = _collect_candidates([center], grid, tower_system)
	if candidates.is_empty():
		return null
	var inst := ObjectiveInstance.new(data, candidates[0], wave)
	objectives.append(inst)
	_last_placed_id = data.id
	objective_placed.emit(inst)
	return inst


## Deterministic candidate list: buildable, unoccupied, unreserved hexes within
## PLACEMENT_REACH_HEXES of the new stretch that retain at least one placeable hex
## within claim radius (so the site can actually be claimed).
func _collect_candidates(
	new_hexes: Array[Vector2i],
	grid: HexGrid,
	tower_system: TowerSystem
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen: Dictionary = {}
	for nh: Vector2i in new_hexes:
		for off: Vector2i in _HexGrid.get_disk_2_offsets():
			var h: Vector2i = nh + off
			if seen.has(h):
				continue
			seen[h] = true
			if _HexGrid.hex_distance(h, nh) > PLACEMENT_REACH_HEXES:
				continue
			if not _is_free_site(h, grid, tower_system):
				continue
			if not _has_claim_spot(h, grid, tower_system):
				continue
			out.append(h)
	return out


func _is_free_site(hex: Vector2i, grid: HexGrid, tower_system: TowerSystem) -> bool:
	if grid.is_path_hex(hex) or grid.is_blocked(hex):
		return false
	if grid.is_tower_occupied(hex) or grid.is_reserved(hex):
		return false
	if has_site_at(hex):
		return false
	if tower_system != null and tower_system.towers_by_hex.has(hex):
		return false
	return true


## True when a site already stands on [param hex]. Two sites never share a hex: their rings,
## fills and markers would draw on top of one another and read as a single site, while the
## claim and capture accounting quietly counted two.
func has_site_at(hex: Vector2i) -> bool:
	for inst: ObjectiveInstance in objectives:
		if inst.hex == hex:
			return true
	return false


func _has_claim_spot(center: Vector2i, grid: HexGrid, tower_system: TowerSystem) -> bool:
	var radius: int = maxi(1, balance.claim_radius_hexes)
	for off: Vector2i in _HexGrid.get_disk_2_offsets():
		var h: Vector2i = center + off
		if _HexGrid.hex_distance(h, center) > radius:
			continue
		if grid.is_path_hex(h) or grid.is_blocked(h):
			continue
		if grid.is_tower_occupied(h) or grid.is_reserved(h):
			continue
		if tower_system != null and tower_system.towers_by_hex.has(h):
			continue
		return true
	return false


## Picks a catalog entry, avoiding an immediate repeat while more than one exists.
func _pick_data(catalog: Array[ObjectiveData]) -> ObjectiveData:
	if catalog.size() == 1:
		return catalog[0]
	var pool: Array[ObjectiveData] = []
	for d: ObjectiveData in catalog:
		if d.id != _last_placed_id:
			pool.append(d)
	if pool.is_empty():
		pool = catalog
	return pool[rng.randi_range(0, pool.size() - 1)]


# --- Claim & capture ---------------------------------------------------------

## Re-evaluates every site's claim against the current towers. A site is CLAIMED
## while a cult tower stands within its claim radius; it reverts to UNCLAIMED when
## that tower is sold, destroyed or converted (tower conversion is still a cult
## tower occupying the hex, so it keeps or takes the site — see caller).
## Returns the instances whose state changed.
func refresh_claims(tower_system: TowerSystem, wave: int) -> Array[ObjectiveInstance]:
	var changed: Array[ObjectiveInstance] = []
	for inst: ObjectiveInstance in objectives:
		if inst.data == null:
			continue
		var held: bool = _has_cult_tower_within(inst.hex, inst.data.claim_radius_hexes, tower_system)
		var desired: int = inst.state
		if held:
			desired = ObjectiveInstance.State.CLAIMED
		elif inst.state == ObjectiveInstance.State.CLAIMED:
			desired = ObjectiveInstance.State.UNCLAIMED
		var old_state: int = inst.state
		if inst.set_state(desired, wave):
			changed.append(inst)
			objective_state_changed.emit(inst, old_state, desired)
	return changed


func _has_cult_tower_within(center: Vector2i, radius: int, tower_system: TowerSystem) -> bool:
	if tower_system == null:
		return false
	var r: int = maxi(1, radius)
	for t: TowerInstance in tower_system.towers.values():
		if t == null:
			continue
		if _HexGrid.hex_distance(center, t.hex) <= r:
			return true
	return false


## Advances capture for every UNCLAIMED site that was contested this wave.
## Call begin_wave -> note_contested (any number of times) -> end_wave once per wave.
## Returns the instances captured by this call.
func begin_wave(_wave: int) -> void:
	_contested_this_wave = false


## Records that enemies are currently near an unclaimed site. Cheap no-op when no
## site is unclaimed, so the caller may call this every tick.
func note_contested(enemy_hexes: Array[Vector2i]) -> void:
	if _contested_this_wave or enemy_hexes.is_empty():
		return
	var radius: int = maxi(1, balance.capture_radius_hexes)
	for inst: ObjectiveInstance in objectives:
		if inst.state != ObjectiveInstance.State.UNCLAIMED:
			continue
		for eh: Vector2i in enemy_hexes:
			if _HexGrid.hex_distance(inst.hex, eh) <= radius:
				_contested_this_wave = true
				return


func end_wave(wave: int) -> Array[ObjectiveInstance]:
	var captured: Array[ObjectiveInstance] = []
	for inst: ObjectiveInstance in objectives:
		if inst.state != ObjectiveInstance.State.UNCLAIMED:
			continue
		if not _contested_this_wave:
			# Quiet wave: progress bleeds off instead of banking toward capture.
			inst.capture_progress = maxi(0, inst.capture_progress - 1)
			continue
		inst.capture_progress += 1
		if inst.capture_progress >= maxi(1, balance.capture_waves_required):
			var old_state: int = inst.state
			if inst.set_state(ObjectiveInstance.State.CAPTURED, wave):
				captured.append(inst)
				objective_state_changed.emit(inst, old_state, ObjectiveInstance.State.CAPTURED)
	return captured


func was_contested_this_wave() -> bool:
	return _contested_this_wave


# --- Effect aggregation ------------------------------------------------------
#
# Region auras: a site only affects the ground around it, so effects are queried
# PER HEX rather than summed into a global. That is what makes the fight for new
# ground matter -- a Ley Line buffs the towers you actually garrison on it, and a
# captured site is a dangerous corridor rather than a run-wide tax.

## Sites whose aura covers [param hex], for UI readout. Only sites that are actually doing
## something are returned -- an unclaimed site has no effect to explain. The live instances are
## returned so a panel can name the site AND read the numbers off its own data.
func get_sites_covering(hex: Vector2i) -> Array[ObjectiveInstance]:
	var out: Array[ObjectiveInstance] = []
	for o: ObjectiveInstance in objectives:
		if (o.is_claimed() or o.is_captured()) and _in_aura(o, hex):
			out.append(o)
	return out


## Hex radius of a site's local effect aura.
func get_aura_radius() -> int:
	return maxi(1, balance.aura_radius_hexes)


## Additive Revealed-tower damage from held Ley Line sites whose aura covers
## [param hex]. Zero when the hex is outside every held site.
func get_revealed_damage_bonus_at(hex: Vector2i) -> float:
	_ensure_aura_cache()
	if not _has_claimed_sites:
		return 0.0
	return float(_revealed_bonus_by_hex.get(hex, 0.0))


## Multiplier on Rigged-tower jam duration from held Data Center sites covering
## [param hex] (< 1.0 = shortened jam).
func get_jam_duration_mult_at(hex: Vector2i) -> float:
	_ensure_aura_cache()
	if not _has_claimed_sites:
		return 1.0
	return float(_jam_mult_by_hex.get(hex, 1.0))


## Speed multiplier for an enemy at [param hex] from CORPORATE-CAPTURED sites.
func get_capture_speed_mult_at(hex: Vector2i) -> float:
	_ensure_aura_cache()
	if not _has_captured_sites:
		return 1.0
	return float(_capture_speed_by_hex.get(hex, 1.0))


## Damage-taken multiplier for an enemy at [param hex] from CORPORATE-CAPTURED
## sites (< 1.0 = takes less damage).
func get_capture_damage_taken_mult_at(hex: Vector2i) -> float:
	_ensure_aura_cache()
	if not _has_captured_sites:
		return 1.0
	return float(_capture_dmg_by_hex.get(hex, 1.0))


## True when [param hex] is already inside some site's aura of the same kind, so
## placement can avoid stacking identical auras on top of each other.
func _in_aura(inst: ObjectiveInstance, hex: Vector2i) -> bool:
	return _HexGrid.hex_distance(inst.hex, hex) <= get_aura_radius()


# --- Global-only effects -----------------------------------------------------

## Corruption ceiling is a meter-wide number, so a Reservoir's headroom cannot be
## local. What keeps it honest is the CLAIM rule: hold a tower near the site or
## the Reservoir (and its headroom) is lost.
func get_corruption_cap_bonus() -> int:
	var total: int = 0
	for o: ObjectiveInstance in objectives:
		if o.is_claimed() and o.data != null:
			total += o.data.corruption_cap_bonus
	return total


## Run-summary totals. These are aggregates for reporting, NOT what the live game
## applies -- the live game queries the per-hex aura functions above.
func get_revealed_damage_bonus() -> float:
	var total: float = 0.0
	for o: ObjectiveInstance in objectives:
		if o.is_claimed() and o.data != null:
			total += o.data.revealed_damage_bonus
	return total


func get_jam_duration_mult() -> float:
	var mult: float = 1.0
	for o: ObjectiveInstance in objectives:
		if o.is_claimed() and o.data != null:
			mult *= maxf(0.0, o.data.jam_duration_mult)
	return mult


func get_capture_enemy_speed_bonus() -> float:
	var total: float = 0.0
	for o: ObjectiveInstance in objectives:
		if o.is_captured() and o.data != null:
			total += o.data.capture_enemy_speed_bonus
	return total


func to_dict() -> Dictionary:
	var rows: Array[Dictionary] = []
	for o: ObjectiveInstance in objectives:
		rows.append(o.to_dict())
	return {
		"count": objectives.size(),
		"claimed": get_objectives_in_state(ObjectiveInstance.State.CLAIMED).size(),
		"captured": get_objectives_in_state(ObjectiveInstance.State.CAPTURED).size(),
		"revealed_bonus": snappedf(get_revealed_damage_bonus(), 0.001),
		"corruption_cap_bonus": get_corruption_cap_bonus(),
		"jam_duration_mult": snappedf(get_jam_duration_mult(), 0.001),
		"sites": rows,
	}