# Playtest Telemetry, Command Logs & StrategyTracker Director API
	
	This document explains **what** playtest telemetry and strategy instrumentation exist in *Cultists vs. Capitalists*, **why** each signal is measured, and **how** to consume `StrategyTracker.get_director_feedback_profile()` in future `WaveDirector` passes.
	
	---
	
	## 1. Architecture Overview
	
	The telemetry layer is split into two scripts under `res://scripts/telemetry/`:
	
	1. **`StrategyTracker` (`res://scripts/telemetry/strategy_tracker.gd`, `extends RefCounted`):**
	   - Pure-logic, deterministic per-wave and run-wide analyzer owned by `GameState.strategy_tracker`.
	   - Observes intermission board snapshots, player commands, wave-start potential vs. measured coverage, enemy kill depths, and Director counter-unit performance.
	   - Emits per-wave digests (`GameState.wave_strategy_evaluated(wave_number, digest)`) and builds a future-ready Director feedback dictionary via `get_director_feedback_profile()`.
	2. **`PlaytestRecorder` (`res://scripts/telemetry/playtest_recorder.gd`, `extends Node`):**
	   - Child node of `GameState` (`GameState.playtest_recorder` / `GameState.ensure_playtest_recorder()`).
	   - Automatically saves complete JSON run logs to `user://playtest_logs/run_<UTC>_s<seed>_w<wave>_<outcome>.json` on Game Over, run restart, Quit to Main Menu, or window close (whenever at least 1 wave started or >1 command was issued).
	   - Streams compact telemetry events (`run_started`, `wave_completed`, `boss_outcome`, `reckoning_triggered`, `run_ended`) to the `ZivaAnalytics` autoload during live interactive runs, while automatically suppressing analytics/disk writes during headless tests, bot simulations, and `replay_command_log()`.
	
	---
	
	## 2. Why Each Strategy / Exploit Signal Exists
	
	`WaveDirector` makes decisions based on three core inputs:
	- **Measured 2-wave DPS coverage** (`CoverageTracker.get_measured_coverage_profile()`)
	- **Branch counts** (`tower_branch_mix`: Revealed, Rigged, Rite, T1, T2, Congregation)
	- **Path geometry** (`path_layout_summary`: exposed stretches, overlap hexes, undefended preview)
	
	During playtesting, players can discover strategies that exploit the assumptions behind those three inputs. `StrategyTracker` detects **9 specific patterns**:
	
	| Flag Constant & String | What It Detects | Why It Matters / How It Invalidates the Director |
	|---|---|---|
	| `FLAG_SPAWN_CAMP_INVALIDATION` (`"spawn_camp_invalidation"`) | `>= 4` kills, `0` leaks, `avg_kill_depth <= 0.20`, and `max_kill_depth <= 0.38` (`0.0 = spawn hex`, `1.0 = base`). | Front-loaded burst at the spawn gate kills enemies before they reach mid/back-line towers or activate timed abilities (`TowerConvert`, `SpawnOnTimer`, `Heal`). It also starves mid/back-line towers of damage events so `CoverageTracker` thinks they don't exist. |
	| `FLAG_UNSCOUTED_BACKLINE_HIDING` (`"unscouted_backline_hiding"`) | Wave `> 2`, `>= 2` unscouted attack/control towers on the board, and the Director picked units targeting a tag where `measured_coverage < 5.0` while `potential_coverage >= 15.0`. | Because `CoverageTracker` only scouts towers that dealt damage in the last 2 waves, a player can park anti-air (`dead_air_altar`, `substation_effigy`), detectors (`watcher_in_the_billboard`), or armor shredders (`rust_censer`) further down the path. The Director sees `0.0` measured coverage, sends a counter wave for that tag, and walks into a pre-built trap. |
	| `FLAG_INTEL_RETCON_CHURN` (`"intel_retcon_churn"`) | Player sells `>= 2` towers (or `>= 25%` of pre-intermission board value) and builds new towers during `INTERMISSION`. | `WaveDirector` locks `locked_roster` at `_enter_intermission()` so `IntelPanel` can preview the wave. Selling scouted towers for a 70% refund after reading the Intel lets a player pivot away from the Director's counter-picks before pressing Start Wave. |
	| `FLAG_COUNTER_PICK_NEUTRALIZED` (`"counter_pick_neutralized"`) | Director spawned units chosen for `counter_bias > 1.05` or `low_<tag>_coverage`, and those units achieved `0` leaks, `0` ability activations, and `avg_progress <= 0.25`. | Directly measures whether the Director's counter-picks (`compliance_officer`, `acquisitions_rep`, `taser_skirmisher`, `siege_walker`, `sponsor_mech`, etc.) actually pressured the player or died harmlessly. |
	| `FLAG_T2_UNBRANCHED_SPAM` (`"t2_unbranched_spam"`) | Wave `>= 6`, `>= 5` towers on board, `>= 60%` of towers are at `tier == 2` (`branch == SHARED`), and `<= 1` tower is T3/T4 branched. | T2 upgrades cost `0.6x` base cost, add `0` Corruption and `0` Jank, and leave `branch == SHARED`. By refusing to buy T3, the player keeps `revealed == 0` and `rigged == 0`, completely dodging all Revealed/Rigged counter-biases (`compliance_officer`, `acquisitions_rep`, `taser_skirmisher`). |
	| `FLAG_CAP_DODGING` (`"cap_dodging"`) | `>= 12` total towers and `>= 2` tower types sitting at exactly `8..9` copies (`< DEFAULT_COST_ESCALATION_START_COPIES = 10`). | Detects players stopping right below the 10th-copy `+10%` cost escalation threshold across multiple tower types. |
	| `FLAG_MONOCULTURE_SPAM` (`"monoculture_spam"`) | `>= 6` total towers and `>= 65%` of all placed towers are a single archetype. | Identifies single-tower dominance where one archetype out-values the `+3%/type` Variety Bonus and cost escalation. |
	| `FLAG_RITE_BRINKMANSHIP` (`"rite_brinkmanship"`) | Player holds Rite towers or `rite_debt > 0` and keeps wave-start Corruption in `[threshold - 15, threshold - 1]` (e.g. `85..99`) via `draw_rites` or `penance`. | Rite towers scale with current Corruption (`corruption_scaled_stat`), while Rogue Entities only wake at `corruption >= threshold`. Hovering at `85..99` gives maximum Rite scaling without ever paying the Reckoning. |
	| `FLAG_CC_KILLBOX_STALL` (`"cc_killbox_stall"`) | `0` leaks, `>= 2` control towers (`tentacle_storm_drain`, `dead_air_altar`, `the_congregation`), and `wave_duration_s >= 1.75 * wave_time_window`. | Detects stacked continuous slows and blockers stalling waves far past the nominal delivery window. |
	
	---
	
	## 3. How to Use the Director Feedback API in Future Passes
	
	Call `GameState.strategy_tracker.get_director_feedback_profile(GameState.tower_system, window_waves)` (default rolling window: `5` waves) to retrieve a structured dictionary ready to pass into `WaveDirector.generate_wave(wave_number, inputs)`:
	
	```gdscript
	var feedback: Dictionary = strategy_tracker.get_director_feedback_profile(tower_system, 5)
	var roster: WaveRoster = director.generate_wave(next_wave, {
		"tower_branch_mix": branch_mix,
		"path_layout_summary": path_summary,
		"strategy_feedback": feedback, # <-- Ready for future WaveDirector consumption
	})
	```
	
	### Schema of `get_director_feedback_profile()`
	
	```gdscript
	{
		"waves_analyzed": int,                        # Total completed waves in this run
		"recent_window_waves": int,                   # Waves in the rolling window (up to 5)
		"recent_avg_kill_depth": float,               # 0.0 (spawn) .. 1.0 (base)
		"recent_avg_intermission_churn": float,       # Sold tower spend / pre-intermission board value
		"recent_counter_neutralization_rate": float,  # 0.0 .. 1.0 share of counter waves neutralized
		"strategy_scores": {                          # Rolling [0.0 .. 1.0] frequency of each flag in window
			"spawn_camp_invalidation": float,
			"unscouted_backline_hiding": float,
			"intel_retcon_churn": float,
			"counter_pick_neutralized": float,
			"t2_unbranched_spam": float,
			"cap_dodging": float,
			"monoculture_spam": float,
			"rite_brinkmanship": float,
			"cc_killbox_stall": float,
		},
		"flag_occurrence_counts": Dictionary,         # Cumulative run counts per flag
		"dominant_strategies": Array[String],         # Flags sorted by occurrence count descending
		"extended_branch_mix": {                      # Full board breakdown (includes T1, T2, Rite)
			"t1": int,
			"t2_shared": int,
			"revealed": int,
			"rigged": int,
			"rite": int,
			"congregation": int,
			"economy": int,
			"support": int,
		},
		"potential_tag_coverage": Dictionary,         # UnitTag -> estimated board DPS (includes unscouted towers)
		"counter_unit_efficacy": {                    # Per unit_type_id historical performance in this run
			"<unit_id>": {
				"spawned": int,
				"leak_rate": float,
				"abilities_per_unit": float,
				"avg_progress": float,
			}
		}
	}
	```
	
	### Concrete Recipes for Wiring Into `WaveDirector` Later
	
	When you are ready to make `WaveDirector` react to `strategy_feedback`, here is how each signal maps to Director behavior:
	
	1. **Countering `unscouted_backline_hiding`:**
	   - Blend `measured_coverage` with `potential_tag_coverage` when `strategy_scores["unscouted_backline_hiding"] >= 0.40`:
		 `effective_cov[tag] = maxf(measured_cov[tag], 0.50 * potential_cov[tag])` so the Director stops falling for "fake 0-coverage" traps when the player has idle backline counters waiting.
	2. **Countering `spawn_camp_invalidation` & `counter_pick_neutralized`:**
	   - When `recent_avg_kill_depth < 0.20` or `recent_counter_neutralization_rate >= 0.50`:
		 - In `_build_spawn_schedule()`, compress the front-line Tank/Shielded vanguard (`riot_shield_unit`, `sponsor_mech`, `cargo_hauler`) ahead of specialist counter units (`compliance_officer`, `acquisitions_rep`, `medic_drone`) so specialists are screened through the spawn gate.
		 - Down-weight specific counter unit IDs whose `counter_unit_efficacy[uid]["avg_progress"] < 0.20` and shift counter bias toward tankier or ranged specialists (`siege_walker`).
	3. **Countering `t2_unbranched_spam`:**
	   - Read `extended_branch_mix["t2_shared"]`: if `strategy_scores["t2_unbranched_spam"] >= 0.40`, apply a generalist armor/shield pressure bias (`riot_shield_unit`, `security_contractor`, `cargo_hauler`) since unbranched T2 towers lack T3/T4 armor shred, execute, and Corruption/Rigged multipliers.
	4. **Countering `intel_retcon_churn`:**
	   - If `recent_avg_intermission_churn >= 0.30`, reserve a small "blind escort reserve" (`15%–20%` of budget) resolved at `start_wave()` from `potential_tag_coverage` rather than at `_enter_intermission()`, or reduce sell refund ratio on towers built and sold within the same intermission.
	5. **Countering `rite_brinkmanship`:**
	   - If `strategy_scores["rite_brinkmanship"] >= 0.40`, weight `RunEventSystem` or `compliance_officer` / Hacker units higher, or allow `rite_debt >= 40` to lower the effective Rogue Entity threshold by a small debt-pressure offset.
	
	---
	
	## 4. Command Logs, Replay & Ziva Analytics Reference
	
	### Local Playtest Log Files (`user://playtest_logs/`)
	- Every live run with activity writes `user://playtest_logs/run_<UTC>_s<seed>_w<wave>_<outcome>.json`.
	- Players can click **"Copy Run Log"** on the **Game Over** screen or **In-Game Menu (`Esc`)** to copy the full JSON payload to their clipboard.
	- Developers can copy any JSON log to their clipboard, press **`F3`** in-game, and click **"Replay Clip"** (or call `GameState.import_and_replay_json(json_str)` in code/tests) to deterministically replay the exact run tick-for-tick.
	
	### Compact Command Digest Format (`command_digest`)
	Sent in `run_ended` analytics events and stored at the top of every JSON log:
	- Grouped by wave: `W0:B(hexed_nail_gun@2,-1[ov]),B(chanting_choir@1,0),S|W1:U(1:rapid_cycling),S`
	- Tokens:
	  - `B(<tower_id>@<q>,<r>[ov])` — Build tower (`[ov]` if placed on a persistent overlap hex)
	  - `U(<tower_instance_id>:<upgrade_node_id>)` — Unlock upgrade node
	  - `X(<tower_instance_id>)` — Sell tower
	  - `M(<tower_instance_id>)` — Maintain Rigged tower (-10 Jank)
	  - `C(<tower_instance_id>)` — Cleanse enemy conversion
	  - `P` — Global Penance (-5 Corruption)
	  - `R(<count>)` — Draw Rites
	  - `F(<candidate_index>)` — Select fork candidate
	  - `S` — Start Wave
	
	### Ziva Analytics Events (`ZivaAnalytics` Autoload)
	- `run_started`: `{ run_id, seed, biome, playtester, debug_tainted }`
	- `wave_completed`: `{ run_id, wave, interval, faction, is_boss, event_id, duration_s, kills, leaks, lives_after, offerings, scrap, corruption, rites, rubber_factor, tower_count, branch_counts, avg_kill_depth, unscouted_attack_towers, counters_spawned, counters_leaked, counter_abilities_fired, intermission_churn_ratio, strategy_flags, debug_tainted }`
	- `boss_outcome`: `{ run_id, wave, boss_id, outcome, duration_s, abilities_used }`
	- `reckoning_triggered`: `{ run_id, wave, rogue_count, severity, leak_cost, corruption }`
	- `run_ended`: `{ run_id, seed, playtester, outcome, reached_wave, fatal_unit_id, fatal_path_index, playtime_s, peak_corruption, rites_drawn, reckonings, debug_tainted, tower_counts_by_type, damage_last_10s, dominant_strategies, strategy_scores, command_digest }`
	