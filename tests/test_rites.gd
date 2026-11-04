## Tests for the Rites + Corporate Attention model.
##
## Rites are Corruption spent as a resource. Drawing them lowers the Corruption
## meter but adds permanent Corporate Attention, and Rogue Entities trigger off
## ATTENTION (corruption + debt) rather than Corruption alone. The point of the
## design is that spending Corruption can never be used to dodge the Rogue spawn.
extends Node

const _HexGrid = preload("res://scripts/path/hex_grid.gd")
const _TowerSystem = preload("res://scripts/towers/tower_system.gd")


func _make_system() -> TowerSystem:
	var grid: HexGrid = _HexGrid.new(11)
	var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	grid.set_path_hexes(path)
	var ts: TowerSystem = _TowerSystem.new(grid, path)
	return ts


# --- Test 1: drawing spends Corruption and accrues Attention ------------------

func test_01_drawing_rites_spends_corruption_and_accrues_attention() -> void:
	var ts: TowerSystem = _make_system()
	ts.set_corruption(40)
	var debt_before: int = ts.rite_debt
	var corruption_before: int = ts.corruption

	assert(ts.can_draw_rites(1), "40 Corruption must be enough to draw a Rite")
	assert(ts.draw_rites(1), "Drawing a Rite must succeed")

	assert(ts.rites == 1, "Drawing must bank 1 Rite")
	assert(
		ts.corruption == corruption_before - ts.get_rite_cost(),
		"Drawing must pay the Rite's Corruption cost"
	)
	assert(ts.rite_debt > debt_before, "Drawing must accrue Corporate Attention")
	assert(
		ts.get_rogue_attention() == ts.corruption + ts.rite_debt,
		"Attention must equal current Corruption plus cumulative Rite debt"
	)


func test_02_cannot_draw_below_cost() -> void:
	var ts: TowerSystem = _make_system()
	ts.set_corruption(ts.get_rite_cost() - 1)
	assert(not ts.can_draw_rites(1), "Below the Rite cost the cult cannot draw")
	assert(not ts.draw_rites(1), "Drawing below cost must fail")
	assert(ts.rites == 0, "A failed draw must not bank a Rite")


# --- Test 3: Corruption is the gate, so spending it backs you off the brink ----

func test_03_draining_corruption_into_rites_backs_you_off_the_brink() -> void:
	var ts: TowerSystem = _make_system()
	ts.set_corruption(ts.get_rogue_entity_threshold())
	assert(
		ts.corruption >= ts.get_rogue_entity_threshold(),
		"Setup: the cult must be sitting ON the Rogue threshold"
	)

	# Draw Rites until Corruption is back under the line.
	var draws: int = 0
	while ts.corruption >= ts.get_rogue_entity_threshold() and ts.can_draw_rites(1) and draws < 50:
		ts.draw_rites(1)
		draws += 1
	assert(draws > 0, "Drawing must be possible at the threshold")
	assert(
		ts.corruption < ts.get_rogue_entity_threshold(),
		"Drawing Rites must pull Corruption back under the Rogue line"
	)

	# Even with Rite debt outstanding, no Rogues: the gate is the Corruption you
	# are holding NOW. This is the whole point of the redesign -- spending has to be
	# a real way to back off the brink, or the branch reads as a trap.
	assert(ts.rite_debt > 0, "Setup: drawing must have accrued Rite debt")
	var info: Dictionary = ts.start_wave(20, RandomNumberGenerator.new())
	var rogues: Array = info.get("rogue_entities", [])
	assert(
		rogues.is_empty(),
		"Rites drawn to pull Corruption under the line must prevent the reckoning (debt %d, corruption %d, threshold %d)"
			% [ts.rite_debt, ts.corruption, ts.get_rogue_entity_threshold()]
	)


# --- Test 4: the reckoning scales with debt, then RESETS (no snowball) --------

func test_04_reckoning_scales_with_debt_then_resets_so_it_cannot_snowball() -> void:
	var ts: TowerSystem = _make_system()

	# Accrue a pile of debt, then climb back over the threshold.
	ts.set_corruption(ts.balance.corruption_max)
	while ts.can_draw_rites(1):
		ts.draw_rites(1)
	var severity: int = ts.get_rite_debt_severity()
	assert(severity > 0, "Drawing Rites must build Rite-debt severity, got %d" % severity)

	ts.set_corruption(ts.get_rogue_entity_threshold())
	var info: Dictionary = ts.start_wave(20, RandomNumberGenerator.new())
	var rogues: Array = info.get("rogue_entities", [])
	assert(not rogues.is_empty(), "At the threshold the Rogues must wake")
	var first: CombatUnit = rogues[0] as CombatUnit
	assert(
		first.spawn_level >= severity,
		"The reckoning must carry the debt severity it was earned with (%d >= %d)"
			% [first.spawn_level, severity]
	)

	# THE RESET: the reckoning consumes the debt, so it cannot compound.
	assert(ts.rite_debt == 0, "The reckoning must reset Rite debt, got %d" % ts.rite_debt)
	assert(ts.get_rite_debt_severity() == 0, "Severity must be 0 after the reckoning")
	assert(ts.rogue_reckonings == 1, "The reckoning must be counted")

	# Staying over the threshold means they keep coming -- but milder.
	var info2: Dictionary = ts.start_wave(21, RandomNumberGenerator.new())
	var rogues2: Array = info2.get("rogue_entities", [])
	assert(not rogues2.is_empty(), "Staying at the threshold means Rogues keep coming")
	var second: CombatUnit = rogues2[0] as CombatUnit
	assert(
		second.spawn_level < first.spawn_level,
		"The next reckoning must be MILDER -- no snowball (%d < %d)"
			% [second.spawn_level, first.spawn_level]
	)


func test_05_no_corruption_means_no_rogues() -> void:
	var ts: TowerSystem = _make_system()
	ts.set_corruption(0)
	assert(ts.rite_debt == 0, "A fresh cult has no Rite debt")
	assert(ts.get_rite_debt_severity() == 0, "A fresh cult has no reckoning severity")
	var info: Dictionary = ts.start_wave(11, RandomNumberGenerator.new())
	var rogues: Array = info.get("rogue_entities", [])
	assert(rogues.is_empty(), "No Corruption means no Rogue Entities")


# --- Test 6: a Reservoir raises the Rogue threshold WITH the cap ----------------

func test_06_held_reservoir_raises_the_rogue_threshold_with_the_cap() -> void:
	var ts: TowerSystem = _make_system()
	var base_threshold: int = ts.get_rogue_entity_threshold()
	assert(
		base_threshold == ts.balance.corruption_rogue_entity_threshold,
		"With no Reservoir the threshold must be the base value"
	)

	# A held Reservoir grants +25 Corruption headroom. The threshold must move with
	# it, or the site would let the cult climb past its own danger line.
	ts.corruption_cap_bonus = 25
	assert(ts.get_corruption_cap() > ts.balance.corruption_max, "A Reservoir must raise the cap")
	assert(
		ts.get_rogue_entity_threshold() == base_threshold + 25,
		"A held Reservoir must raise the Rogue threshold alongside the cap (got %d, expected %d)"
			% [ts.get_rogue_entity_threshold(), base_threshold + 25]
	)


# --- Test 5: the Rite bank --------------------------------------------------

func test_07_spending_rites_decrements_the_bank() -> void:
	var ts: TowerSystem = _make_system()
	ts.set_corruption(50)
	assert(ts.draw_rites(2), "Drawing 2 Rites must succeed with 50 Corruption")
	assert(ts.rites == 2, "Must bank 2 Rites")

	assert(ts.spend_rites(1), "Spending a banked Rite must succeed")
	assert(ts.rites == 1, "Spending must decrement the bank")
	assert(not ts.spend_rites(5), "Cannot overspend the Rite bank")
	assert(ts.rites == 1, "A failed spend must not change the bank")