## Headless test suite for the Objective system.
##
##  1. Library: 3 objectives load, validate, and the balance resource loads.
##  2. Placement: wave gate, max sites, sites per growth, never on path/blocked/occupied,
##     always claimable, and deterministic for a given rng seed.
##  3. Claim lifecycle: unclaimed -> claimed by tower presence, reverts when sold, recaptures.
##  4. Capture: contested waves flip an unclaimed site to CAPTURED; quiet waves cool down.
##  5. Effects: held sites buff the cult, captured sites buff the enemy, and those values
##     reach TowerSystem (Corruption ceiling, jam duration, enemy spawn HP).
extends Node

const _HexGrid = preload("res://scripts/path/hex_grid.gd")
const _C = preload("res://scripts/path/path_constants.gd")
const _HexMath = preload("res://scripts/core/hex_math.gd")
const _Icons = preload("res://scripts/ui/placeholder_icons.gd")
const _TowerPanel = preload("res://scripts/ui/tower_panel.gd")
const _OverlayView = preload("res://scripts/world/overlay_view.gd")
const _ObjectiveData = preload("res://scripts/objectives/objective_data.gd")
const _ObjectiveInstance = preload("res://scripts/objectives/objective_instance.gd")
const _ObjectiveLibrary = preload("res://scripts/objectives/objective_library.gd")
const _ObjectiveSystem = preload("res://scripts/objectives/objective_system.gd")
const _TowerSystem = preload("res://scripts/towers/tower_system.gd")
const _TowerLibrary = preload("res://scripts/towers/tower_library.gd")
const _UnitLibrary = preload("res://scripts/units/unit_library.gd")


# --- Helpers -----------------------------------------------------------------

func _make_world(seed_val: int = 4242) -> Dictionary:
	var grid := _HexGrid.new(seed_val)
	# The growth stretch is committed path by the time objectives place, exactly as
	# GameState commits a previewed extension before placing sites.
	var path: Array[Vector2i] = []
	for i in range(15):
		path.append(Vector2i(i, 0))
	grid.set_path_hexes(path)
	# Force a clean buildable neighbourhood around the new stretch (i >= 10).
	for i in range(9, 16):
		for off: Vector2i in _HexGrid.get_disk_2_offsets():
			grid.set_terrain_override(Vector2i(i, 0) + off, _C.Terrain.BUILDABLE)
	var ts := _TowerSystem.new(grid, path)
	var new_hexes: Array[Vector2i] = []
	for i in range(10, 15):
		new_hexes.append(Vector2i(i, 0))
	return {"grid": grid, "tower_system": ts, "new_hexes": new_hexes, "path": path}


func _make_objective_system(seed_val: int = 777) -> ObjectiveSystem:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return _ObjectiveSystem.new(_ObjectiveLibrary.load_balance(), rng)


# --- Test 6: Overlay draws the three objective ring layers -------------------

func _get_game_state() -> Node:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		var gs_script: GDScript = load("res://scripts/core/game_state.gd")
		gs = gs_script.new()
		gs.name = "GameState"
		get_tree().root.add_child(gs)
	return gs


func test_06_overlay_draws_objective_ring_layers() -> void:
	var gs: Node = _get_game_state()
	gs.call("start_new_run", 90210)

	var catalog: Array[ObjectiveData] = _ObjectiveLibrary.load_all()
	var obj: ObjectiveSystem = gs.get("objective_system") as ObjectiveSystem
	obj.reset()

	var unclaimed := _ObjectiveInstance.new(catalog[0], Vector2i(4, 1), 10)
	var claimed := _ObjectiveInstance.new(catalog[1], Vector2i(5, -1), 10)
	var captured := _ObjectiveInstance.new(catalog[2], Vector2i(6, 1), 10)
	claimed.set_state(_ObjectiveInstance.State.CLAIMED, 11)
	captured.set_state(_ObjectiveInstance.State.CAPTURED, 11)
	obj.objectives.append_array([unclaimed, claimed, captured])

	var overlay: OverlayView = _OverlayView.new()
	add_child(overlay)
	var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
	overlay.refresh_path_overlays(pgen)

	assert(overlay._objective_unclaimed_multimesh.multimesh != null, "Unclaimed layer must be drawn")
	assert(
		overlay._objective_unclaimed_multimesh.multimesh.instance_count == 1,
		"Exactly one unclaimed ring expected"
	)
	assert(
		overlay._objective_claimed_multimesh.multimesh != null
			and overlay._objective_claimed_multimesh.multimesh.instance_count == 1,
		"Exactly one claimed ring expected"
	)
	assert(
		overlay._objective_captured_multimesh.multimesh != null
			and overlay._objective_captured_multimesh.multimesh.instance_count == 1,
		"Exactly one captured ring expected"
	)

	# Re-refreshing with unchanged states must be a no-op (the layer is cached by
	# signature); refresh_path_overlays runs every frame, so a rebuild per frame would
	# be a per-frame allocation leak.
	var claimed_mm_before: MultiMesh = overlay._objective_claimed_multimesh.multimesh
	overlay.refresh_path_overlays(pgen)
	assert(
		overlay._objective_claimed_multimesh.multimesh == claimed_mm_before,
		"An unchanged objective signature must not rebuild the layer"
	)

	# A state change must be reflected: claim the unclaimed site, then capture it.
	unclaimed.set_state(_ObjectiveInstance.State.CLAIMED, 12)
	overlay.refresh_path_overlays(pgen)
	assert(
		overlay._objective_claimed_multimesh.multimesh != null
			and overlay._objective_claimed_multimesh.multimesh.instance_count == 2,
		"Claiming a second site must redraw the claimed layer with 2 rings"
	)
	assert(
		overlay._objective_unclaimed_multimesh.multimesh == null,
		"No unclaimed sites left, so the unclaimed layer must be cleared"
	)

	# --- Region-aura fills: only sites that DO something get a fill -----------
	var aura_r: int = obj.get_aura_radius()
	var disk: int = 3 * aura_r * aura_r + 3 * aura_r + 1
	var aura_count: int = (
		overlay._objective_aura_multimesh.multimesh.instance_count
		if overlay._objective_aura_multimesh.multimesh != null else 0
	)
	assert(
		aura_count >= disk,
		"At least one full radius-%d aura must be filled (%d hexes), got %d"
			% [aura_r, disk, aura_count]
	)
	# Two held sites are within aura range of one another here, so the fill is
	# deduped rather than doubled -- never more than two whole disks.
	assert(
		aura_count <= 2 * disk,
		"Overlapping auras must dedupe, never exceeding two disks, got %d" % aura_count
	)

	# Every site floats an icon in a layer keyed to its KIND. Distinct kinds must not share a
	# layer, because the silhouette is what tells them apart.
	var kinds: Dictionary = {}
	for inst: ObjectiveInstance in obj.objectives:
		kinds[inst.data.id] = true
	assert(
		overlay._icon_layers.size() == kinds.size(),
		"Expected one icon layer per site kind (%d), got %d"
			% [kinds.size(), overlay._icon_layers.size()]
	)
	assert(
		_icon_instance_total(overlay) == obj.objectives.size(),
		"Every site must float exactly one icon, got %d for %d sites"
			% [_icon_instance_total(overlay), obj.objectives.size()]
	)
	for kind: String in overlay._icon_layers.keys():
		var icon_layer: MultiMeshInstance3D = overlay._icon_layers[kind] as MultiMeshInstance3D
		assert(
			icon_layer.multimesh != null and icon_layer.multimesh.mesh != null,
			"Icon layer for kind '%s' must carry both a mesh and instances" % kind
		)

	# Clearing objectives must clear the layers, never leave stale rings behind.
	obj.reset()
	overlay.refresh_path_overlays(pgen)
	assert(
		overlay._objective_claimed_multimesh.multimesh == null
			and overlay._objective_captured_multimesh.multimesh == null
			and overlay._objective_unclaimed_multimesh.multimesh == null,
		"Clearing objectives must clear all three ring layers"
	)
	assert(
		overlay._objective_aura_multimesh.multimesh == null,
		"Clearing objectives must clear the aura fill layer"
	)
	assert(
		_icon_instance_total(overlay) == 0,
		"Clearing objectives must clear every site icon, %d left floating"
			% _icon_instance_total(overlay)
	)

	# An UNCLAIMED site must be findable: it gets its ring, a fill across its ground, and a
	# marker column. It used to be ring-only -- and in practice that made the one site a
	# player most needs to FIND invisible against the district art, so this is pinned now.
	obj.objectives.append(_ObjectiveInstance.new(catalog[0], Vector2i(4, 1), 10))
	overlay.refresh_path_overlays(pgen)
	assert(
		overlay._objective_unclaimed_multimesh.multimesh != null,
		"An unclaimed site must still draw its ring"
	)
	assert(
		overlay._objective_aura_multimesh.multimesh != null
			and overlay._objective_aura_multimesh.multimesh.instance_count == disk,
		"An unclaimed site must fill its whole aura disk (%d hexes), got %d"
			% [
				disk,
				overlay._objective_aura_multimesh.multimesh.instance_count
					if overlay._objective_aura_multimesh.multimesh != null else -1
			]
	)
	assert(
		_icon_instance_total(overlay) == 1,
		"An unclaimed site must float exactly one icon, got %d" % _icon_instance_total(overlay)
	)

	overlay.queue_free()

# --- Test 7: Sites never stack on one hex -------------------------------------

func test_07_forced_sites_never_stack_on_one_hex() -> void:
	var world: Dictionary = _make_world()
	var grid: HexGrid = world["grid"]
	var ts: TowerSystem = world["tower_system"]
	var new_hexes: Array[Vector2i] = world["new_hexes"]
	var catalog: Array[ObjectiveData] = _ObjectiveLibrary.load_all()
	var sys := _make_objective_system(4242)
	var center: Vector2i = new_hexes[0]

	# Reaching a specific site kind for a playtest means forcing several sites at one centre.
	# A hex already holding a site must stop being a candidate, or the repeats pile up on a
	# single hex: on screen that looks like one site while the accounting counts several.
	var seen: Dictionary = {}
	var placed_count: int = 0
	for i in range(4):
		var inst: ObjectiveInstance = sys.debug_force_site(
			catalog[i % catalog.size()], center, grid, ts, 10
		)
		if inst == null:
			continue
		placed_count += 1
		assert(
			not seen.has(inst.hex),
			"Forced site %d stacked on hex %s, which already holds a site" % [i, str(inst.hex)]
		)
		seen[inst.hex] = true
	assert(
		placed_count >= 2,
		"Several forced sites should each find a fresh hex near %s, got %d"
			% [str(center), placed_count]
	)


## Total icons currently floating across every per-kind icon layer.
func _icon_instance_total(overlay: OverlayView) -> int:
	var total: int = 0
	for kind: String in overlay._icon_layers.keys():
		var mmi: MultiMeshInstance3D = overlay._icon_layers[kind] as MultiMeshInstance3D
		if mmi.multimesh != null:
			total += mmi.multimesh.instance_count
	return total


# --- Test 8: Objective icon glyphs --------------------------------------------

func test_08_objective_icon_glyphs_are_distinct_and_not_blank() -> void:
	# The map icon is generated procedurally, so "is it blank?" and "are the kinds actually
	# distinguishable?" are both real failure modes. Image data is CPU-side, so this is an
	# honest headless check.
	var ids: Array[String] = ["ley_line", "converted_data_center", "corruption_reservoir"]
	var coverage: Dictionary = {}
	for id: String in ids:
		var tex: ImageTexture = _Icons.objective_icon(id)
		assert(tex != null, "Objective icon '%s' must generate a texture" % id)
		var img: Image = tex.get_image()
		var opaque: int = 0
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.0:
					opaque += 1
		assert(opaque > 0, "Objective icon '%s' must not be blank" % id)
		var frac: float = float(opaque) / float(img.get_width() * img.get_height())
		# A mostly-solid tile would blot out the board it is meant to mark: these are glyphs.
		assert(
			frac < 0.60,
			"Objective icon '%s' covers %.0f%% of its tile; site icons must stay glyph-like"
				% [id, frac * 100.0]
		)
		coverage[id] = opaque

	assert(
		coverage["ley_line"] != coverage["converted_data_center"]
			and coverage["converted_data_center"] != coverage["corruption_reservoir"],
		"Site kinds must be visually distinguishable, got pixel coverages %s" % str(coverage)
	)

	# Cached: the overlay asks per refresh, so rebuilding each time would leak textures.
	assert(
		_Icons.objective_icon("ley_line") == _Icons.objective_icon("ley_line"),
		"Objective icons must be cached"
	)

	# An unknown kind must still mark the site rather than drawing nothing.
	var fallback: Image = _Icons.objective_icon("not_a_real_kind").get_image()
	var fallback_opaque: int = 0
	for y in range(fallback.get_height()):
		for x in range(fallback.get_width()):
			if fallback.get_pixel(x, y).a > 0.0:
				fallback_opaque += 1
	assert(fallback_opaque > 0, "An unknown site kind must still get a visible fallback glyph")


# --- Test 10: The panel's plain-language site readout -------------------------

func test_10_site_effect_summary_names_the_effect_in_plain_words() -> void:
	# This is the text a player actually reads on the tower panel, so it is worth pinning: the
	# words must come from the site's own data, and the two directions (what a HELD site does
	# for you vs what a CAPTURED one does to you) must not be confused.
	var by_id: Dictionary = {}
	for d: ObjectiveData in _ObjectiveLibrary.load_all():
		by_id[d.id] = d

	var held_dmg: String = _TowerPanel.site_effect_summary(by_id["ley_line"], true)
	assert(
		held_dmg.contains("Revealed damage"),
		"A held Ley Line must read as a Revealed damage bonus, got '%s'" % held_dmg
	)

	var held_jam: String = _TowerPanel.site_effect_summary(by_id["converted_data_center"], true)
	assert(
		held_jam.contains("jams shortened"),
		"A held Data Center must read as shortened jams, got '%s'" % held_jam
	)

	var held_cap: String = _TowerPanel.site_effect_summary(by_id["corruption_reservoir"], true)
	assert(
		held_cap.contains("Corruption ceiling"),
		"A held Reservoir must read as a raised ceiling, got '%s'" % held_cap
	)

	# Captured: the same sites now work AGAINST the cult, and the wording must say so.
	var cap_speed: String = _TowerPanel.site_effect_summary(by_id["converted_data_center"], false)
	assert(
		cap_speed.contains("faster"),
		"A captured Data Center must warn about enemy speed, got '%s'" % cap_speed
	)
	var cap_dmg: String = _TowerPanel.site_effect_summary(by_id["ley_line"], false)
	assert(
		cap_dmg.contains("take -") or cap_dmg.contains("take -%"),
		"A captured Ley Line must warn that enemies take less damage, got '%s'" % cap_dmg
	)

	# A site type with nothing to say must say so rather than printing an empty line.
	var blank := ObjectiveData.new()
	assert(
		_TowerPanel.site_effect_summary(blank, true) == "no effect on this tower",
		"A site with no effect fields must produce an explicit 'no effect' line"
	)
	assert(
		_TowerPanel.site_effect_summary(null, true) == "effect unknown",
		"A null site must not crash the panel"
	)

func test_09_get_sites_covering_reports_only_effective_sites() -> void:
	# The tower panel names the site buffing a tower that stands in its aura, so this query must
	# report only sites that are actually DOING something: an unclaimed site has no effect to
	# explain, and reporting one would put a lie on the panel.
	var catalog: Array[ObjectiveData] = _ObjectiveLibrary.load_all()
	var sys := _make_objective_system(77)
	var site_hex := Vector2i(4, 1)
	var site := _ObjectiveInstance.new(catalog[0], site_hex, 10)
	sys.objectives.append(site)
	var radius: int = sys.get_aura_radius()

	assert(
		sys.get_sites_covering(site_hex).is_empty(),
		"An unclaimed site must not be reported as covering anything"
	)

	site.set_state(_ObjectiveInstance.State.CLAIMED, 12)
	assert(sys.get_sites_covering(site_hex).size() == 1, "A site's own hex is inside its aura")
	assert(
		sys.get_sites_covering(site_hex + Vector2i(radius, 0)).size() == 1,
		"A hex exactly at the aura edge must be covered"
	)
	assert(
		sys.get_sites_covering(site_hex + Vector2i(radius + 1, 0)).is_empty(),
		"A hex one past the aura edge must not be covered"
	)

	# Captured sites still report: the ground under the tower is working for the enemy, and the
	# panel should say so rather than staying silent.
	site.set_state(_ObjectiveInstance.State.CAPTURED, 14)
	assert(
		sys.get_sites_covering(site_hex).size() == 1,
		"A captured site must still be reported -- it is doing something to the tower"
	)


## Finds a hex within [param radius] of [param center] where the tower system will
## actually accept a placement (buildable, within build distance of the path, free).
func _first_placeable(ts: TowerSystem, grid: HexGrid, center: Vector2i, radius: int) -> Vector2i:
	for off: Vector2i in _HexGrid.get_disk_2_offsets():
		var h: Vector2i = center + off
		if _HexGrid.hex_distance(h, center) > radius:
			continue
		if not grid.is_tower_occupied(h) and ts.can_place_at_hex(h):
			return h
	return Vector2i(9999, 9999)

# --- Test 1: Library ---------------------------------------------------------

func test_01_objective_library_loads_and_validates() -> void:
	var catalog: Array[ObjectiveData] = _ObjectiveLibrary.load_all()
	assert(catalog.size() == 3, "Expected 3 objective resources, got %d" % catalog.size())
	var ids: Array[String] = []
	for d: ObjectiveData in catalog:
		assert(d.validate() == "", "Objective '%s' failed validation: %s" % [d.id, d.validate()])
		ids.append(d.id)
	for required: String in ["ley_line", "converted_data_center", "corruption_reservoir"]:
		assert(ids.has(required), "Missing objective '%s' in catalog %s" % [required, str(ids)])

	var balance: ObjectiveBalanceData = _ObjectiveLibrary.load_balance()
	assert(balance != null, "ObjectiveBalanceData must load")
	assert(balance.claim_radius_hexes >= 1, "claim_radius_hexes must be >= 1")
	assert(balance.capture_waves_required >= 1, "capture_waves_required must be >= 1")


# --- Test 2: Placement -------------------------------------------------------

func test_02_placement_rules_and_determinism() -> void:
	var world: Dictionary = _make_world()
	var grid: HexGrid = world["grid"]
	var ts: TowerSystem = world["tower_system"]
	var new_hexes: Array[Vector2i] = world["new_hexes"]
	var catalog: Array[ObjectiveData] = _ObjectiveLibrary.load_all()

	var sys_a := _make_objective_system(555)
	var sys_b := _make_objective_system(555)
	var sys_c := _make_objective_system(999)

	# Wave gate: nothing before first_objective_wave.
	var too_early: Array[ObjectiveInstance] = sys_a.place_for_growth(new_hexes, grid, ts, 1, catalog)
	assert(too_early.is_empty(), "No objective may be placed before first_objective_wave")
	assert(sys_a.get_site_count() == 0, "Wave gate must not place a site")

	var placed_a: Array[ObjectiveInstance] = sys_a.place_for_growth(new_hexes, grid, ts, 10, catalog)
	assert(placed_a.size() == sys_a.balance.sites_per_growth, "Must place sites_per_growth sites")
	var placed_b: Array[ObjectiveInstance] = sys_b.place_for_growth(new_hexes, grid, ts, 10, catalog)
	var placed_c: Array[ObjectiveInstance] = sys_c.place_for_growth(new_hexes, grid, ts, 10, catalog)

	assert(
		placed_a[0].hex == placed_b[0].hex and placed_a[0].get_id() == placed_b[0].get_id(),
		"Same rng seed must place the same site"
	)
	assert(
		placed_a[0].hex != placed_c[0].hex or placed_a[0].get_id() != placed_c[0].get_id(),
		"A different rng seed must be able to place differently"
	)

	# Placement sanity: free, non-path hex, adjacent-ish to the new stretch.
	for inst: ObjectiveInstance in placed_a:
		assert(not grid.is_path_hex(inst.hex), "Objective must not sit on a path hex")
		assert(not grid.is_blocked(inst.hex), "Objective must not sit on blocked terrain")
		assert(not grid.is_tower_occupied(inst.hex), "Objective must not sit on a tower")
		assert(inst.state == _ObjectiveInstance.State.UNCLAIMED, "New sites start UNCLAIMED")

	# Max sites cap.
	for i in range(20):
		sys_a.place_for_growth(new_hexes, grid, ts, 10, catalog)
	assert(
		sys_a.get_site_count() <= sys_a.balance.max_sites,
		"Site count must never exceed max_sites (%d)" % sys_a.balance.max_sites
	)


# --- Test 3: Claim lifecycle -------------------------------------------------

func test_03_claim_lifecycle_requires_a_live_tower() -> void:
	var world: Dictionary = _make_world()
	var grid: HexGrid = world["grid"]
	var ts: TowerSystem = world["tower_system"]
	var new_hexes: Array[Vector2i] = world["new_hexes"]
	var catalog: Array[ObjectiveData] = _ObjectiveLibrary.load_all()

	var sys := _make_objective_system(31337)
	sys.place_for_growth(new_hexes, grid, ts, 10, catalog)
	var site: ObjectiveInstance = sys.objectives[0]

	# No tower: stays unclaimed.
	sys.refresh_claims(ts, 10)
	assert(site.state == _ObjectiveInstance.State.UNCLAIMED, "A site with no tower must stay UNCLAIMED")

	# Find a legally placeable hex within claim radius and build there.
	var build_hex: Vector2i = _first_placeable(ts, grid, site.hex, site.data.claim_radius_hexes)
	assert(
		build_hex != Vector2i(9999, 9999),
		"Placement must guarantee a claimable hex within claim radius of %s" % str(site.hex)
	)

	var tower: TowerInstance = ts.place_tower(build_hex, ts._resolve_tower_def("hexed_nail_gun"), true)
	assert(tower != null, "Test tower must be placeable at %s" % str(build_hex))
	sys.refresh_claims(ts, 10)
	assert(site.state == _ObjectiveInstance.State.CLAIMED, "A tower within claim radius must CLAIM the site")

	# Selling the tower reverts the site: holding it is a live commitment.
	ts.sell_tower(tower)
	sys.refresh_claims(ts, 11)
	assert(site.state == _ObjectiveInstance.State.UNCLAIMED, "Selling the holding tower must revert the site")

	# Rebuilding re-claims it.
	ts.place_tower(build_hex, ts._resolve_tower_def("hexed_nail_gun"), true)
	sys.refresh_claims(ts, 12)
	assert(site.state == _ObjectiveInstance.State.CLAIMED, "Rebuilding must re-claim the site")


# --- Test 4: Capture --------------------------------------------------------

func test_04_contested_waves_capture_unclaimed_sites() -> void:
	var world: Dictionary = _make_world()
	var grid: HexGrid = world["grid"]
	var ts: TowerSystem = world["tower_system"]
	var new_hexes: Array[Vector2i] = world["new_hexes"]
	var catalog: Array[ObjectiveData] = _ObjectiveLibrary.load_all()

	var sys := _make_objective_system(24680)
	sys.place_for_growth(new_hexes, grid, ts, 10, catalog)
	var site: ObjectiveInstance = sys.objectives[0]
	var enemy_hexes: Array[Vector2i] = [site.hex]

	# Wave 1: contested but not yet enough.
	sys.begin_wave(11)
	sys.note_contested(enemy_hexes)
	sys.end_wave(11)
	assert(site.state == _ObjectiveInstance.State.UNCLAIMED, "One contested wave must not capture yet")
	assert(site.capture_progress == 1, "Contested wave must bank capture progress")

	# Wave 2: quiet -> progress bleeds back off.
	sys.begin_wave(12)
	sys.end_wave(12)
	assert(site.capture_progress == 0, "A quiet wave must cool capture progress back down")

	# Two consecutive contested waves -> captured.
	for w in [13, 14]:
		sys.begin_wave(w)
		sys.note_contested(enemy_hexes)
		sys.end_wave(w)
	assert(
		site.state == _ObjectiveInstance.State.CAPTURED,
		"%d consecutive contested waves must CAPTURE an unclaimed site" % sys.balance.capture_waves_required
	)

	# A captured site can be taken back by building within claim radius.
	var build_hex: Vector2i = _first_placeable(ts, grid, site.hex, site.data.claim_radius_hexes)
	assert(build_hex != Vector2i(9999, 9999), "A captured site must remain claimable")
	ts.place_tower(build_hex, ts._resolve_tower_def("hexed_nail_gun"), true)
	sys.refresh_claims(ts, 15)
	assert(site.state == _ObjectiveInstance.State.CLAIMED, "Building at a captured site must retake it")


# --- Test 5: Effects are REGION AURAS, not global ---------------------------

func test_05_objective_effects_are_region_auras() -> void:
	var catalog: Array[ObjectiveData] = _ObjectiveLibrary.load_all()
	var by_id: Dictionary = {}
	for d: ObjectiveData in catalog:
		by_id[d.id] = d

	var sys := _make_objective_system(1357)
	var grid := _HexGrid.new(7)
	var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	grid.set_path_hexes(path)
	for i in range(0, 4):
		for off: Vector2i in _HexGrid.get_disk_2_offsets():
			grid.set_terrain_override(Vector2i(i, 0) + off, _C.Terrain.BUILDABLE)
	var ts := _TowerSystem.new(grid, path)
	# Same wiring GameState performs, so effects resolve per-hex.
	ts.objective_system = sys

	# Sites sit beside the path, where a tower can actually reach them. The two
	# sites are placed at OPPOSITE ends of the path so "inside aura" and "outside
	# aura" hexes genuinely exist (aura 3 is broad relative to a short test path).
	var ley: ObjectiveInstance = _ObjectiveInstance.new(by_id["ley_line"], Vector2i(3, 1), 10)
	var data_center: ObjectiveInstance = _ObjectiveInstance.new(
		by_id["converted_data_center"], Vector2i(1, 1), 10
	)
	var reservoir: ObjectiveInstance = _ObjectiveInstance.new(
		by_id["corruption_reservoir"], Vector2i(9, 9), 10
	)
	sys.objectives.append_array([ley, data_center, reservoir])

	var aura: int = sys.get_aura_radius()
	assert(aura >= 1, "An aura radius must be configured")

	# Unclaimed: every hex is neutral.
	assert(
		is_equal_approx(sys.get_revealed_damage_bonus_at(Vector2i(1, 1)), 0.0),
		"Unclaimed Ley Line must give no bonus"
	)
	assert(
		is_equal_approx(sys.get_jam_duration_mult_at(Vector2i(3, 1)), 1.0),
		"Unclaimed Data Center must give no jam reduction"
	)
	assert(sys.get_corruption_cap_bonus() == 0, "Unclaimed Reservoir must give no cap bonus")

	for inst: ObjectiveInstance in sys.objectives:
		inst.set_state(_ObjectiveInstance.State.CLAIMED, 11)
	ts.apply_objective_effects(
		sys.get_revealed_damage_bonus(),
		sys.get_corruption_cap_bonus(),
		sys.get_jam_duration_mult()
	)

	# --- Ley Line: the bonus reaches only towers inside the aura --------------
	var inside_hex := Vector2i(3, -1)
	var outside_hex := Vector2i(0, -2)
	assert(
		_HexGrid.hex_distance(inside_hex, ley.hex) <= aura,
		"Setup: inside_hex (%s) must sit inside the Ley Line aura" % str(inside_hex)
	)
	assert(
		_HexGrid.hex_distance(outside_hex, ley.hex) > aura,
		"Setup: outside_hex (%s) must sit outside the Ley Line aura" % str(outside_hex)
	)
	var inside_tower: TowerInstance = ts.place_tower(
		inside_hex, ts._resolve_tower_def("hexed_nail_gun"), true
	)
	var outside_tower: TowerInstance = ts.place_tower(
		outside_hex, ts._resolve_tower_def("hexed_nail_gun"), true
	)
	assert(
		inside_tower != null and outside_tower != null,
		"Both test towers must be placeable (%s / %s)" % [str(inside_hex), str(outside_hex)]
	)
	inside_tower.force_revealed = true
	outside_tower.force_revealed = true

	assert(
		is_equal_approx(ts.get_revealed_additive_bonus(inside_tower), ley.data.revealed_damage_bonus),
		"A Revealed tower inside the Ley Line aura must get the full bonus"
	)
	assert(
		is_equal_approx(ts.get_revealed_additive_bonus(outside_tower), 0.0),
		"A Revealed tower OUTSIDE the aura must get nothing -- the bonus is local"
	)

	# --- Data Center: jam shortening reaches only towers inside the aura ------
	var dc_inside_hex := Vector2i(1, -1)
	assert(
		_HexGrid.hex_distance(dc_inside_hex, data_center.hex) <= aura,
		"Setup: dc_inside_hex must sit inside the Data Center aura"
	)
	var dc_tower: TowerInstance = ts.place_tower(
		dc_inside_hex, ts._resolve_tower_def("tithe_box"), true
	)
	assert(dc_tower != null, "Test tower inside the Data Center aura must be placeable")
	assert(
		ts.get_effective_jam_duration(dc_tower) < ts.balance.jank_disable_duration,
		"A Rigged tower inside the Data Center aura must jam for less time"
	)
	assert(
		is_equal_approx(
			ts.get_effective_jam_duration(outside_tower), ts.balance.jank_disable_duration
		),
		"A tower outside every Data Center aura must jam for the full duration"
	)

	# --- Reservoir: the ONE genuinely global effect --------------------------
	assert(
		ts.get_corruption_cap() > ts.balance.corruption_max,
		"Held Reservoir must raise the Corruption ceiling above the base max"
	)
	# Corruption may now exceed the old hard cap but never the raised one.
	ts.set_corruption(ts.balance.corruption_max + 5)
	assert(
		ts.corruption == ts.balance.corruption_max + 5,
		"Corruption must be allowed above the base max while a Reservoir is held"
	)

	# --- Captured ground: a local corridor, not a run-wide tax ---------------
	ley.set_state(_ObjectiveInstance.State.CAPTURED, 12)
	assert(
		is_equal_approx(sys.get_revealed_damage_bonus_at(inside_hex), 0.0),
		"A captured Ley Line must stop buffing the cult"
	)
	assert(
		sys.get_capture_damage_taken_mult_at(inside_hex) < 1.0,
		"Enemies on corporate-captured ground must take less damage"
	)
	assert(
		is_equal_approx(sys.get_capture_damage_taken_mult_at(outside_hex), 1.0),
		"Enemies on cult ground must be unaffected -- the penalty is local"
	)
	assert(
		is_equal_approx(ts.get_objective_capture_speed_mult_at(inside_hex), 1.0),
		"A captured Ley Line grants no speed bonus; its penalty is damage reduction"
	)

	# The Data Center's captured penalty IS speed, and it is local too.
	data_center.set_state(_ObjectiveInstance.State.CAPTURED, 12)
	assert(
		ts.get_objective_capture_speed_mult_at(dc_inside_hex) > 1.0,
		"A captured Data Center must speed enemies on its own ground"
	)
	assert(
		is_equal_approx(ts.get_objective_capture_speed_mult_at(outside_hex), 1.0),
		"Outside every captured aura enemies must move normally"
	)

	# The damage path must consume the captured penalty.
	var unit: CombatUnit = ts.spawn_unit_from_data("gig_runner", 5.0)
	assert(unit != null, "Test unit must spawn")
	assert(
		ts.get_unit_damage_taken_multiplier(unit) > 0.0,
		"Damage-taken multiplier must stay usable on a real unit"
	)

	# --- Fallback: with no ObjectiveSystem attached, pushed aggregates apply --
	ts.objective_system = null
	ts.apply_objective_effects(0.05, 0, 1.0)
	assert(
		is_equal_approx(ts.get_objective_revealed_bonus_at(Vector2i(50, 50)), 0.05),
		"Without an ObjectiveSystem the pushed aggregate must be the fallback"
	)