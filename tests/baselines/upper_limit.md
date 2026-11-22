# Upper-Limit (Wall) Probe

Real headless combat via `BalanceBaseline.run_run`, high ceiling MAX_WAVE=120, 
wall-clock budget 240 s (elapsed 180.1 s). Seeds: [1337].

`died @ Wn` = found the wall. `time_capped` = outran the budget (NOT a survival;
wall unknown). `not_run` = budget was already exhausted before it started.

| Archetype | Outcome | Wall (wave) | Reached | Bosses | Growths | Max towers | Cause |
| --- | --- | --- | --- | --- | --- | --- | --- |
| naive | death | 10 | 10 | 1 | 0 | 12 | boss_leaked |
| mono_electric | death | 23 | 23 | 3 | 2 | 18 | lives_depleted |
| rite_gambler | death | 15 | 15 | 2 | 1 | 17 | boss_leaked |
| mono_corrosive | death | 24 | 24 | 3 | 2 | 18 | lives_depleted |
| turtle | death | 26 | 26 | 4 | 3 | 24 | lives_depleted |
| mono_kinetic | death | 25 | 25 | 4 | 2 | 18 | boss_leaked |
| mono_psychic | death | 27 | 27 | 4 | 3 | 18 | lives_depleted |
| balanced | death | 31 | 31 | 5 | 4 | 23 | lives_depleted |
| mono_void | death | 24 | 24 | 3 | 2 | 18 | lives_depleted |
| balanced_uncapped | death | 46 | 46 | 8 | 6 | 400 | lives_depleted |

Deaths found: 10 | Censored by budget: 0 | Runs: 10
