---
name: test-scaling-curve
description: Use when checking whether the difficulty curve and scaling "make sense" in cultists-vs-capitalists — e.g. before/after tuning enemy scaling, tower stats, wave size, spawn rate or the essence economy. Runs a headless simulation of the combat loop over N stages and reports the per-stage curve plus a design verdict.
---

# Testing the difficulty curve & scaling

This skill answers: **"given the current tower + enemy inventory and the current
difficulty curves, does the game scale the way we designed?"**

The design intent it checks:

> A player who builds **only basic towers** with **all essence available** should
> be **feeling overwhelmed by stage 10**, and should NOT end up with hundreds of
> towers — the target is a **few dozen**, and at most **25% of the buildable
> slots** filled.
>
> More generally: the player should need to *optimize* tower usage (slow, buff,
> etc.) rather than win by stacking one archetype — and should never reach a state
> where they can walk away because they have "enough towers".

Two **design contracts** encode this and are asserted by the tests:
`test_design_contract_basic_only_is_overwhelmed_by_stage_10` and
`test_design_contract_tower_count_is_bounded`.

## The tool

| Piece | Path | Job |
| --- | --- | --- |
| `ScalingSimulation` | `res://tools/scaling_sim/scaling_simulation.gd` | Headless combat + economy model over N stages |
| `test_scaling_curve` | `res://tests/test_scaling_curve.gd` | Integration tests: structural checks + the design contract |

`ScalingSimulation` is **not a rough approximation**: it reuses the real code —
`LevelGenerator` for the path, a real `StageManager` for wave size / spawn-rate /
type-introduction schedule, `EnemyTier` for variant levels, and the actual
`TowerData` `.tres` files. Only physics/rendering are skipped (enemies walk a 1D
arc; towers fire on their real cadence at the nearest enemy in range; kill rewards
are spent on new towers between stages).

## How to run it

Print the default scenario report:

```gdscript
# execute_script (starts with `extends` so it runs as-is)
extends SceneTree
func _init() -> void:
    var sim = load("res://tools/scaling_sim/scaling_simulation.gd").new()
    sim.stages = 10
    sim.run()
    print(sim.report_text)
    quit()
```

Run the integration tests (also prints the report from the design-contract test):

- `run_tests` on `res://tests/test_scaling_curve.gd`, or on `res://tests/`.

## Reading the report

```
stage  enemies  lvl  enemyHP  towers(+built)  kills  leaks  leak%  hp   path
    1        5    1       25       5(+  5)      5      0      0  100    45
    ...
   10       23    1      451     349(+112)     23      0      0  100   261
VERDICT: ...
```

- **enemies / enemyHP** — wave size and total HP for the stage (the two combat
  scaling axes: count and per-enemy HP from `EnemyTier`).
- **lvl** — highest enemy variant level that spawned (driven by the
  `kills_per_level` / `level_kills_growth` / `max_level` curve). A rising value
  means the enemy self-scaling is engaging; a flat `1` means it is dormant and
  contributing nothing to difficulty.
- **towers(+built)** — how many towers the player has / added this stage. If this
  climbs steeply, the **economy** is the difficulty bottleneck, not combat.
- **leaks / leak% / hp** — how much the defense is failing. Leak rate is the
  cleanest "am I overwhelmed?" signal.
- **path** — enemy-track length in cells (grows every few stages; a longer path
  gives towers more time in range, so it also affects difficulty).

## Verdict thresholds

`ScalingSimulation.overwhelm_leak_rate` (default 0.15) and
`overwhelm_hp_fraction` (default 0.25) define "overwhelmed" for the verdict.
`design_intent_met` is true when the basic-only player is overwhelmed on or before
the final stage, **or** the player is wiped out. Tune the thresholds if the design
team defines "overwhelmed" differently.

## The knobs (what to change to move the curve)

| Knob | Where | Effect |
| --- | --- | --- |
| `kills_per_level` | `EnemyProgression` (first threshold) | **The enemy-scaling lever.** Kills for the FIRST promotion (level 2). Lower = level 2 lands sooner. |
| `level_kills_growth` | `EnemyProgression` | How much each level costs more than the last. Higher = variants arrive fast early but slow down harder. |
| `max_level` | `EnemyProgression` | Cap on variant level (bounds enemy HP; `1.5^(max-1)` health multiplier). |
| Tower `cost` | `resources/towers/*.tres` | Higher cost = fewer towers = economy pressure. **Usually the strongest lever.** |
| Enemy `reward` | `resources/enemies/*.tres` | Lower reward = slower economy = fewer towers. |
| `base_enemies`, `enemies_added_per_stage` | `StageManager` | Wave-size axis. |
| `spawn_rate_growth` | `StageManager` | Spawn-rate axis (compounding). |
| `stages_per_path_growth` | `StageManager` | How fast the usable path (and buildable band) grows. |
| `starting_essence` | `PlayerResources` | Opening tower count. |

`ScalingSimulation` exposes the same knobs as fields plus diagnostics:

- `kills_per_level`, `level_kills_growth`, `max_level` — the enemy-scaling curve.
- `tower_cost_override` (0 = use the `.tres` cost) — explore economy tuning without editing resources.
- `reward_multiplier` (1.0 = use the `.tres` rewards) — scale enemy income without editing resources.
- `reinvest_essence` (default `true`): set `false` for a **static defense** run —
  the player never adds towers, isolating pure combat scaling from economy
  snowballing.
- `max_towers` (default `0` = uncapped): cap the tower count to test "even N
  towers can't hold".

## Current finding (tower cost 10, rewards ×2, start 30, curve 5/1.6/10)

Both design contracts are **GREEN**:

- **Tower count**: a basic-only, reinvesting player ends stage 10 with **~53 towers
  (9.5% of the 792 buildable slots)** — a few dozen, well under the 25% cap.
- **Overwhelm**: the player is genuinely pressured early — leaking 44%/55% of
  stages 3-4 and losing HP down to 90 — before the defense stabilises.
- Enemies still level up (to ~4/5), so the combat curve is doing work too.

### Economy tuning notes (measured — the important part)

- The binding lever is the **tower cost : basic-enemy reward ratio**, NOT the enemy
  level curve. The level curve alone never overwhelmed a reinvesting player because
  player DPS is unbounded while enemy HP is capped.
- Ratios ≥ ~10 (e.g. cost 10 vs a base reward of 1) **starve**: no early towers →
  no kills → no income → no towers → wiped. A viable window is roughly **5:1 to
  8:1**, WITH a **starting essence of ~3 towers** (30 at cost 10) to seed the defense.
- Higher ratio = fewer towers, more pressure: ~8:1 gave ~42 towers / 5% slots.
- Because the path **doubles in length** over a run (more tower time-in-range) and
  enemy levels **cap**, difficulty forms a **mid-game hump** rather than a late-game
  ramp — the player is most pressured around stages 3-4 and eases after. If a
  late-game ramp is wanted, the enemy count/HP growth must outpace the path growth.

The economy is currently set to: Basic Tower **cost 10** (all tower costs ×10),
enemy rewards **×2** (basic 2, runner 4, grunt 8, brute 18, auditor 14), and
`PlayerResources.starting_amount = 30`.

## Never do this

- Don't read a green `test_scaling_curve` run as "the curve is fine" — check the
  `test_design_contract_*` result and the printed report.
- Don't tune the level curve (`kills_per_level` / `level_kills_growth` / `max_level`)
  to fix difficulty while towers are effectively free; the unbounded player DPS
  dominates and the knob has almost no visible effect.
- Don't treat the numbers as frame-perfect: projectile travel, misses and exact
  placement are modelled abstractly (see the script header). It is a **curve**
  tool, not a replay.

## Looking ahead (not implemented)

These are tuning knobs the design plans to add; when they land, extend the
simulation rather than bypassing it:

- **Tech tree** — upgrading towers and unlocking new tower types (would let the
  basic-only scenario diverge sharply from a mixed defense).
- **Active buffs** — one-shot or timed player abilities that change game state.

Re-run this skill after wiring any of them so the curve is re-checked against the
design intent for the new inventory.