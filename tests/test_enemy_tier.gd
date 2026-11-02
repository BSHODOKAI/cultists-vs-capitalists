## Tests for the enemy type / variant levelling system.
##
## Verifies the [EnemyTier] rules: the fast-early / tapering kill-cost curve (with
## its level cap), compounding stats, speed stepping every 5 levels, and level 1
## pass-through, plus that [EnemyProgression] promotes a type once its threshold
## is crossed.
extends Node

const BASE_PATH := "res://resources/enemies/basic_enemy.tres"


func _base() -> EnemyData:
	return load(BASE_PATH) as EnemyData


func _expect(condition: bool, message: String) -> void:
	assert(condition, message)


func test_level_starts_at_one() -> void:
	_expect(EnemyTier.level_for_kills(0) == 1, "0 kills must be level 1")
	_expect(EnemyTier.level_for_kills(EnemyTier.FIRST_LEVEL_KILLS - 1) == 1,
		"just under the first threshold must still be level 1")


func test_first_promotion_is_cheap() -> void:
	_expect(EnemyTier.level_for_kills(EnemyTier.FIRST_LEVEL_KILLS) == 2,
		"the first threshold must reach level 2")
	_expect(EnemyTier.FIRST_LEVEL_KILLS < 20, "the first promotion must arrive fast")


func test_levels_get_more_expensive_and_cap() -> void:
	# Each level costs strictly more than the one before (fast early, slow later).
	for lv in range(2, EnemyTier.MAX_LEVEL):
		_expect(EnemyTier.kills_in_level(lv + 1) > EnemyTier.kills_in_level(lv),
			"level %d must cost more than level %d" % [lv + 1, lv])
	_expect(EnemyTier.kills_for_level(5) < 100, "the first four promotions must fit in well under 100 kills")
	# Reaching a cumulative threshold yields exactly that level; one fewer never skips it.
	for lv in range(2, EnemyTier.MAX_LEVEL + 1):
		var need := EnemyTier.kills_for_level(lv)
		_expect(EnemyTier.level_for_kills(need) == lv, "%d kills must be level %d" % [need, lv])
		_expect(EnemyTier.level_for_kills(need - 1) == lv - 1, "%d kills must still be level %d" % [need - 1, lv - 1])
	# The cap holds no matter how many kills pile up.
	_expect(EnemyTier.level_for_kills(10_000_000) == EnemyTier.MAX_LEVEL, "levels must cap at MAX_LEVEL")


func test_health_compounds_fifty_percent_per_level() -> void:
	var base := _base()
	var l2 := EnemyTier.scale(base, 2)
	var l3 := EnemyTier.scale(base, 3)
	_expect(is_equal_approx(l2.max_health, base.max_health * 1.5), "level 2 health must be 150% of base")
	_expect(is_equal_approx(l3.max_health, l2.max_health * 1.5), "level 3 health must be 150% of level 2")
	_expect(is_equal_approx(EnemyTier.health_multiplier(5), 5.0625), "level 5 health must be 1.5^4")
	_expect(EnemyTier.health_multiplier(1) == 1.0, "level 1 health must be unscaled")


func test_reward_and_damage_compound_ten_percent_per_level() -> void:
	var base := _base()
	var grunt := load("res://resources/enemies/grunt.tres") as EnemyData
	_expect(EnemyTier.scale(grunt, 2).reward == maxi(1, roundi(float(grunt.reward) * 1.1)),
		"level 2 reward must be the 10% compounded value")
	_expect(EnemyTier.scale(grunt, 5).reward > EnemyTier.scale(grunt, 2).reward,
		"reward must keep growing")
	_expect(EnemyTier.scale(base, 3).damage >= base.damage, "escape damage must never drop below base")
	# Compare the GROWTH ratios (robust to reward values), not absolute numbers:
	# health compounds faster than reward level over level.
	var l1 := EnemyTier.scale(grunt, 1)
	var l2 := EnemyTier.scale(grunt, 2)
	_expect((l2.max_health / l1.max_health) > (float(l2.reward) / float(l1.reward)),
		"health must scale on a steeper curve than reward")


func test_speed_steps_one_percent_every_five_levels() -> void:
	var base := _base()
	for level in [1, 2, 3, 4, 5]:
		var data := EnemyTier.scale(base, level)
		_expect(is_equal_approx(data.speed, base.speed), "level %d speed must be unchanged" % level)
	var l6 := EnemyTier.scale(base, 6)
	var l10 := EnemyTier.scale(base, 10)
	var l11 := EnemyTier.scale(base, 11)
	_expect(is_equal_approx(l6.speed, base.speed * 1.01), "level 6 speed must be +1%")
	_expect(is_equal_approx(l10.speed, base.speed * 1.01), "level 10 speed must still be +1%")
	_expect(is_equal_approx(l11.speed, base.speed * 1.01 * 1.01), "level 11 speed must be +2.01%")


func test_level_one_keeps_base_resource_untouched() -> void:
	var base := _base()
	_expect(EnemyTier.scale(base, 1) == base, "level 1 must reuse the base resource")
	var health_before := base.max_health
	EnemyTier.scale(base, 5)
	_expect(is_equal_approx(base.max_health, health_before), "scaling must never modify the base .tres")


func test_variant_keeps_type_identity() -> void:
	var base := _base()
	var variant := EnemyTier.scale(base, 3)
	_expect(variant.type_id == EnemyData.resolve_id(base), "variant must keep the base type id")
	_expect(not variant.type_id.is_empty(), "type id must never be empty")
	_expect(variant.variant_level == 3, "variant must record its level")


func test_progression_levels_up_after_threshold() -> void:
	var progress := EnemyProgression.new()
	progress.kills_per_level = 3
	var seen_levels: Array[int] = []
	progress.level_up.connect(func(_id: String, level: int) -> void: seen_levels.append(level))
	var base := _base()
	for i in range(3):
		progress.register_kill("basic_enemy")
	_expect(progress.level_for(base) == 2, "3 kills with a threshold of 3 must reach level 2")
	_expect(seen_levels == [2], "level_up must fire exactly once")
	var variant := progress.variant_for(base)
	_expect(is_equal_approx(variant.max_health, base.max_health * 1.5), "spawn must use level 2 health")
	progress.free()


func test_progression_ignores_escapes_and_unknown_types() -> void:
	var progress := EnemyProgression.new()
	progress.kills_per_level = 3
	_expect(progress.register_kill("") == 1, "empty type id must not level up")
	_expect(progress.kills_for("") == 0, "empty type id must not be recorded")
	_expect(progress.kills_until_next_level("basic_enemy") == 3, "fresh type must need a full threshold")
	progress.free()
