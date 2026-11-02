---
name: create-enemy-type
description: Use when adding a new enemy type, or a new variant/upgrade of an enemy, to cultists-vs-capitalists. Covers the EnemyData resource, the kill-based variant levelling system and how to wire the new type into spawning.
---

# Adding an enemy type

Every enemy TYPE is one `EnemyData` resource in `res://resources/enemies/`. That
resource always holds the **level 1** numbers. Stronger variants are not authored
by hand — they are generated at spawn time.

## How the levelling works (already built)

| Piece | File | Job |
| --- | --- | --- |
| `EnemyData` | `scripts/enemies/enemy_data.gd` | Base (level 1) stats + stable `type_id` |
| `EnemyTier` | `scripts/enemies/enemy_tier.gd` | Pure math: level from kills, scaled stats, variant tint |
| `EnemyProgression` | `scripts/enemies/enemy_progression.gd` | Counts kills per type, owns `level_up` |
| `EnemySpawner` | `scripts/level/spawner.gd` | Applies the variant before the enemy spawns; reports kills; interleaves types |
| `BasicEnemy` | `scripts/enemies/basic_enemy.gd` | Carries `type_id` + `level`, applies the type's mesh and color |
| `EnemyLibrary` | `scripts/enemies/enemy_library.gd` | Ordered roster: the order types are introduced in a run |
| `StageManager` | `scripts/level/stage_manager.gd` | Wave size, spawn-rate curve, type introduction schedule |

Rules: kills of a type promote **future spawns** of it. The kill cost is NOT flat —
the first promotion is cheap (`FIRST_LEVEL_KILLS`, default 5) and each later level
costs `LEVEL_KILLS_GROWTH` (default 1.6) times the one before, up to `MAX_LEVEL`
(default 10). So variants arrive fast early and slow to a stop. All three knobs are
exposed on the `EnemyProgression` node (`kills_per_level`, `level_kills_growth`,
`max_level`) — tune them there. Health is the steep curve — level 2 has 150% of
level 1's health, level 3 has 150% of level 2's (compounding); reward and escape
damage compound at 10%. Speed is the exception — it steps up 1% every 5 levels, so
levels 1–5 keep the base speed. Change the stat curves only in `EnemyTier`'s
constants (`HEALTH_SCALE`, `STAT_SCALE`, `SPEED_SCALE`, `SPEED_LEVELS_PER_STEP`).

## How stages use the types

- Stage 1 sends only the FIRST roster entry. A new type joins every
  `StageManager.stages_per_type_min` .. `stages_per_type_max` stages (default 1–3,
  rolled at random), in roster order, and stays in the mix from then on.
- `StageManager.build_wave()` splits the stage's enemy count evenly across the
  unlocked types (leftovers go to the newest). `EnemySpawner.spawn_mix()` then
  interleaves them, so a stage is a mix rather than blocks of one type.
- Spawn rate compounds: `spawn_rate_multiplier(stage) = (1 + spawn_rate_growth)^(stage-1)`,
  5% per stage by default. The spawner's gap is `interval / spawn_rate`.

## Steps

1. Copy `resources/enemies/basic_enemy.tres` to `resources/enemies/<name>.tres`.
2. Set the level 1 stats: `display_name`, `color`, `max_health`, `speed`,
   `reward` (kill currency) and `damage` (player HP lost on escape).
3. Set `type_id` to a unique, stable string such as `"skeleton"`. Kills are
   counted per `type_id`, so two resources sharing an id level up together; an
   empty id falls back to the resource path, which also works but breaks if the
   file moves.
4. Visuals: `scenes/BasicEnemy.tscn` serves every type — set `EnemyData.mesh` to a
   `CapsuleMesh` of a different size to change the silhouette, and `color` to tell
   types apart. Do not bake variant colors into the mesh: the level tint comes from
   `EnemyTier.variant_color`.
5. Register it: append the new `.tres` path to `EnemyLibrary.TYPE_PATHS` (append at
   the END so the introduction order of a run stays stable), then run
   `res://tests/enemy_type_showcase.tscn` to eyeball the lineup.
6. Custom spawning outside the stage loop should ask the progression, never do the
   math itself: `enemy.data = EnemyProgression.of(self).variant_for(base)` before
   `add_child`, so `_ready()` reads the variant stats.
7. Verify: `run_tests` on `res://tests/` (tier math, spawn variants, stage waves),
   then run `res://scenes/MainStage.tscn`. To see a promotion quickly, set
   `EnemyProgression.kills_per_level = 1` in `MainStage.tscn`, run, and put it back
   to 5; to see a new type quickly, set `StageManager.stages_per_type_max = 1`.

## Never do this

- Do not put pre-scaled numbers into a `.tres`; health compounds at ×1.5 per level,
  so pre-scaled stats double-count and the curve explodes.
- Do not reuse a `type_id` between unrelated enemies.
- Do not mutate the shared `.tres` at runtime — `EnemyTier.scale` returns a copy
  above level 1 and the base resource itself at level 1.
- Do not reorder `EnemyLibrary.TYPE_PATHS`: the index IS the introduction order.

