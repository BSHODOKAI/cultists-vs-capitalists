# Phase 1 — Scaling Ablation Matrix

Real headless runs, one scaling term flattened per preset. `lift` = mean wave
reached minus baseline (averaged over archetypes balanced, mono_kinetic). Higher lift = that term is
a bigger driver of the death curve.
- Seeds: [1337] | Max wave (cap): 26

## Ranked by survival lift

| Rank | Preset | Mean wave reached | Lift vs baseline |
| --- | --- | --- | --- |
| 1 | no_leveling | 26.0 | +6.0 |
| 2 | flat_budget | 25.0 | +5.0 |
| 3 | no_late_ramp | 22.0 | +2.0 |
| 4 | no_interval_floor | 21.5 | +1.5 |
| 5 | no_rogues | 21.5 | +1.5 |
| 6 | baseline | 20.0 | +0.0 |

## Per-archetype detail

| Preset | Archetype | Mean reached | Median WOD | Deaths | Stalls | Censored |
| --- | --- | --- | --- | --- | --- | --- |
| baseline | balanced | 17.0 | 17.0 | 1 | 0 | 0 |
| baseline | mono_kinetic | 23.0 | 23.0 | 1 | 0 | 0 |
| no_leveling | balanced | 26.0 | -1.0 | 0 | 0 | 1 |
| no_leveling | mono_kinetic | 26.0 | -1.0 | 0 | 0 | 1 |
| no_interval_floor | balanced | 20.0 | 20.0 | 1 | 0 | 0 |
| no_interval_floor | mono_kinetic | 23.0 | 23.0 | 1 | 0 | 0 |
| no_late_ramp | balanced | 20.0 | 20.0 | 1 | 0 | 0 |
| no_late_ramp | mono_kinetic | 24.0 | 24.0 | 1 | 0 | 0 |
| flat_budget | balanced | 24.0 | 24.0 | 1 | 0 | 0 |
| flat_budget | mono_kinetic | 26.0 | -1.0 | 0 | 0 | 1 |
| no_rogues | balanced | 20.0 | 20.0 | 1 | 0 | 0 |
| no_rogues | mono_kinetic | 23.0 | 23.0 | 1 | 0 | 0 |
