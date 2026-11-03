# AGENTS.md — Cultists vs. Capitalists

**Project:** Endless-mode, orthographic-isometric, axial hex-grid tower defense in Godot 4.7 (typed GDScript, Forward+ renderer). A scrappy Lovecraftian cult (mysticism + salvaged junk) defends its Sanctum against sleek, sponsor-branded cyberpunk corporate warlords across a procedural urban metropolis.

---

## 1. Core Loop & Run State Machine

- **Simulation Clock (`SimClock` Autoload — `res://scripts/core/sim_clock.gd`):**
- Fixed-timestep **30 Hz** (`TICK_DELTA = 1.0 / 30.0`) simulation clock.
- All gameplay logic ticks from `SimClock.tick`, never from `_process(delta)`, ensuring pause (`P`) and speed multipliers (`1x / 2x / 3x` via `Q / W / E`) are deterministic.
- 3D visuals interpolate smoothly between ticks using `SimClock.interpolation_alpha`.
- **Run Coordinator (`GameState` Autoload — `res://scripts/core/game_state.gd`):**
- Finite State Machine: `RUN_SETUP -> INTERMISSION -> WAVE_ACTIVE -> INTERMISSION ...`
- Boss waves transition `WAVE_ACTIVE -> POST_BOSS -> INTERMISSION`.
- Any state can transition to `GAME_OVER`.
- Records a deterministic `command_log`, `event_log`, and `spend_log`, supporting full deterministic replay via `GameState.replay_command_log(seed, commands, total_ticks)`.
- **Path & Base Defense:**
- Enemies spawn at the far end of the procedurally generated hex path (`path_hexes[path_hexes.size() - 1]`) and walk toward the player's Cult Sanctum base at `path_hexes[0]`.
- **Air units** follow the same path at `HexMath.AIR_ALTITUDE = 1.8` (ignoring ground blockers and ground-only towers; targeted only by air-capable towers).
- A leaked enemy costs lives (`leak_cost`, default `1`). Lives start at **20** (`STARTING_LIVES`).
- A leaked **Boss** triggers an immediate `GAME_OVER`. Reaching `0` lives triggers `GAME_OVER` and emits a `LossReport`.
- Every **10th wave** (`10, 20, 30...`) is a Boss wave. When the boss is slain and all wave enemies are cleared, the path extends in `POST_BOSS`.
- **Towers have NO HP in v1.** Enemies interact with towers by disabling (`TowerDisable`), suppressing fire rate (`RangedSuppress`), negating Corruption bonuses (`AntiMagicAura`), or channeling to convert them (`TowerConvert`, `LeveragedBuyout`).
- **Special Event — "Stars Are Right":**
- Occurs every 5th wave that is not a boss wave (`5, 15, 25...`).
- `REVEALED` branch towers deal **+20% additive damage** that wave (`STARS_ARE_RIGHT_REVEALED_BONUS = 0.20`), and the wave director's budget increases by **+10%**.

---

## 2. Currencies & Economy

All player currency spending must route through the single choke point `GameState.spend(currency, amount, reason)`.

- **Offerings (`Start: 150`):**
- Used to build Offerings-cost base towers (7 of the 10 archetypes), unlock `REVEALED` T3/T4 upgrades, perform global **Penance** (`40 Offerings -> -5 Corruption`), and cleanse enemy tower conversions early (`50%` of base tower cost).
- Earned from enemy kills (`round(unit.cost * 1.0)`, boosted by `dark_patron` up to +30%) and `tithe_box` passive income.
- **Scrap (`Start: 40`):**
- Used to build Scrap-cost base towers (`watcher_in_the_billboard` [70 Scrap], `substation_effigy` [50 Scrap], and `rust_censer` [40 Scrap]), unlock `RIGGED` T3/T4 upgrades, perform tower **Maintenance** (`15 Scrap -> -10 Jank`), and pay `solvent_tank` wave upkeep (`4 Scrap/wave`).
- Dropped by killed enemies (`scrap_value` defaults to `round(cost * 0.5)`, overridable per unit such as `sponsor_mech = 12`, boosted by `scrap_collector` up to +75%).
- **Selling Towers:**
- Refunds **70%** (`DEFAULT_SELL_REFUND_RATIO = 0.70`) of total Offerings and total Scrap invested in that tower.

---

## 3. Tags, Resistances & Crowd Control Diminishing Returns

- **Damage Tags (`PathConstants.DamageTag`):**
- `KINETIC (0)`, `CORROSIVE (1)`, `PSYCHIC (2)`, `VOID (3)`, `ELECTRIC (4)`.
- **Unit Tags (`PathConstants.UnitTag`):**
- `GROUND`, `AIR`, `FAST`, `FRAGILE`, `ARMORED`, `SHIELDED`, `CLOAKED`, `SWARM`, `HEALER`, `SPAWNER`, `SUPPORT`, `AURA`, `HACKER`, `ELECTRIC`, `ANTI_MAGIC`, `CYBERNETIC`, `TANK`, `RANGED`, `BOSS`.
- **Resistances:**
- Per-`DamageTag` multipliers on `UnitData.resistances` (`0.75` = takes 25% less damage; `1.25` = takes 25% more damage).
- **Boss Immunities & Reductions:**
- Bosses are immune to flee, confusion, displacement (knockback/drag), root, and conversion.
- Slows and damage-over-time (DoT) effects apply to Bosses at **50% strength** (`BOSS_SLOW_AND_DOT_STRENGTH = 0.50`).
- **Crowd Control Diminishing Returns (`CombatUnit.cc_lock_counts`):**
- Hard CC is tracked per enemy across 4 categories: `"fear"` (flee + confusion reverse-walk), `"root"`, `"stun"`, and `"displacement"` (knockback/drag).
- Each category allows at most **3 locks** (`CC_MAX_LOCKS_PER_CATEGORY = 3`) with multipliers: **1st = 100%**, **2nd = 50%**, **3rd = 25%**, **4th+ = 0% (permanently immune to that category)**.
- Continuous and timed movement **slows** (`drain_slow`, `flood_slow`, `timed_slow`, `fear_stacks` slow) are exempt from diminishing returns.

---

## 4. Hex World & Procedural Path Growth

- **Coordinate System (`HexMath` & `HexGrid`):**
- Sparse Dictionary-based pointy-top axial hex grid `(q, r)` with 6 directions (`HEX_SIZE = 1.0`). No fixed map bounds.
- All gameplay logic uses axial hex coordinates and integer hex distances (`HexMath.distance`). Never use world or pixel distances in gameplay code.
- Terrain is `BUILDABLE` or `BLOCKED` (~12% `BLOCKED_TERRAIN_FRACTION`), generated lazily in chunks (`CHUNK_RADIUS = 8`) deterministically from `run_seed + chunk_coord`, independent of chunk load order. Chunks containing path hexes, towers, or reserved preview hexes are pinned and cannot unload.
- **Initial Path & Growth Lifecycle (`PathGenerator`):**
- Initial path starts at the player's base (`Vector2i.ZERO`, path index `0`) and extends `INITIAL_PATH_LENGTH = 24` hexes to the initial spawn hex.
- **Preview (`PREVIEW_LEAD_WAVES = 2`):** Generated at the intermission before wave `8, 18, 28...`. Immediately reserves `ghost_path_hexes` and any hex in the 2-hex build zone *only* of the previewed extension.
- **Commit:** Happens once after each boss wave in `POST_BOSS` (only when the boss is dead and no enemies remain). Commits the *exact* previewed extension (`12..20` hexes, `MIN_EXT..MAX_EXT`) from the spawn end.
- **Hard Constraints (H1–H5 — never relaxed):**
- **H1:** Single non-branching chain; no hex visited twice.
- **H2:** Corner spacing: at least `2` straight (non-corner) hexes between consecutive corners, including across the join with the existing path; allowed turns are `±60°` and `±120°`.
- **H3:** Separation: no path hex may be adjacent to a non-consecutive path hex (at least 1 buildable hex separates distinct stretches).
- **H4:** No dead ends / self-trapping: 2-extension DFS lookahead confirms a valid escape path exists from the new spawn end.
- **H5:** Never uses `BLOCKED`, tower-occupied, or reserved hexes.
- **Overlap Hexes:**
- Unoccupied, buildable, non-path hexes within hex distance `2` of path hexes from at least two distinct stretches (path indices differ by `>= PASS_GAP = 6`).
- Extensions require `>= OVERLAP_MIN (3)` new overlap hexes (soft max `8`), with ordered fallbacks: lower `OVERLAP_MIN` to `0` -> reduce extension length (`3..11`) -> skip growth and log error.
- Exposes UI hooks: `ghost_path_hexes`, `preview_overlap_hexes`, and `persistent_overlap_hexes`.

---

## 5. Towers, Upgrade Trees, Corruption & Jank

All 10 cult towers live in `res://data/towers/*.tres` and their 50 upgrades (`10 x [1 T2 + 2 T3 + 2 T4]`) live in `res://data/upgrades/*.tres`.

- **Placement & Adjacency Rules:**
- 1 hex per tower on a `BUILDABLE`, non-path, non-reserved, unoccupied hex within hex distance `<= 2` of the committed path.
- **Exception:** `the_congregation` (`range_hexes = 1`) **must be placed directly adjacent (`hex_distance == 1`)** to a committed path hex.
- **Upgrade Tree & Branch Locking:**
- `T1 (base) -> T2 (shared, 0.6x base cost) -> fork: REVEALED T3 (1.0x) -> T4 Capstone (1.8x) OR RIGGED T3 (1.0x) -> T4 Capstone (1.8x)`.
- Choosing a T3 branch permanently locks the opposite branch for that tower.
- **Revealed Upgrades:** Paid in **Offerings**; add global **Corruption** (`T3 +4`, `T4 +8`).
- **Rigged Upgrades:** Paid in **Scrap**; set that tower's **Jank** (`T3 -> 10%`, `T4 -> 25%`).
- **Corruption (Global `0..100`):**
- Revealed towers deal `+0.25%` additive damage per point (stacks additively with Stars Are Right `+20%`; negated within 2 hexes of a `compliance_officer`).
- At `50+`: `10%` chance at wave start one random Revealed tower misfires (disabled that wave). At `75+`: `20%`.
- At `100`: Spawns hostile **Rogue Entities** (`res://data/units/rogue_entity.tres`: base 550 HP, speed 1.25, 25%–50% all-damage resistance, `Breakthrough`, `TowerDisable` every 5s, `leak_cost = 3+`).
- Rogue Entities level up `+1` every time one is killed (`1.45^level` HP compounding + wave scaling) and spawn in multiples (`1..5`) as Rogue level and wave number rise.
- **Penance:** Pay `40 Offerings` to reduce Corruption by `5`.
- **Jank (Per Rigged Tower `0..60%`):**
- At each wave start, each Rigged tower rolls `min(jank, 60)%` chance to jam at a seeded random moment during the wave, disabling it for `10s`.
- **Maintenance:** Pay `15 Scrap` to lower one Rigged tower's Jank by `10`.
- **Anti-All-In & Synergy Mechanics:**
- **Cost Escalation:** Starting at the **10th owned copy** of a tower type (`DEFAULT_COST_ESCALATION_START_COPIES = 10`), each copy raises the build cost of the next copy of that type by `+10%`.
- **Variety Bonus:** Each tower gains `+3%` damage per distinct *other* tower type within `3` hexes (max `+12%`).
- **Entangled:** Ground enemies slowed or rooted by `tentacle_storm_drain` take `+25%` damage from `gutter_ritual_circle` pulses.
- **Armor Shred:** Each stack adds `+5%` damage taken from all sources (default max `5` stacks; `rust_communion` raises cap to `8` and doubles effect vs `Cybernetic`; `solvent_tank` raises cap to `10`).
- **Detection:** `Cloaked` enemies cannot be targeted until revealed by continuous detector auras (`chanting_choir`, `watcher_in_the_billboard`) or `gutter_ritual_circle` pulses (reveals for `3s`).

### Tower Roster Summary

| # | ID | Cost & Currency | Range | Base Attack & Role | T2 -> Revealed (T3 -> T4) | Rigged (T3 -> T4) |
|---|---|---|---|---|---|---|
| 1 | `hexed_nail_gun` | 30 Offerings | 3 | 8 Kinetic, 2.0/s, Ground+Air, single target | `rapid_cycling` -> `whispering_nails` -> `nails_that_remember` | `drone_feeder` -> `pneumatic_belt_rig` |
| 2 | `chanting_choir` | 40 Offerings | 2 | 3 Psychic/member/s (3 members), Ground, Detector | `deeper_harmony` -> `dissonant_hymn` -> `the_unspoken_verse` | `bullhorn_array` -> `jammer_choir` |
| 3 | `gutter_ritual_circle` | 50 Offerings | 3 | 25 Corrosive pulse / 2.5s (target + ring 1), Ground, 3s reveal | `wider_circle` -> `ichor_bloom` -> `maw_beneath` | `propane_pulse` -> `chain_detonator` |
| 4 | `tentacle_storm_drain` | 35 Offerings | 2 | 4 Kinetic/s, Ground, 35% slow aura, 1.5s root / 8s, Entangled | `more_grates` -> `deep_grasp` -> `leviathan_awakens` | `flood_pump` -> `live_wire_flood` |
| 5 | `watcher_in_the_billboard` | 70 **Scrap** | 6 | 90 Void / 4s, Ground+Air, highest HP, Detector | `dilated_pupil` -> `gaze_of_unmaking` -> `the_eye_opens` | `rooftop_scope_array` -> `ad_hijack` |
| 6 | `rust_censer` | 40 **Scrap** | 2 | 6 Corrosive/s DoT (4s, 3 stacks) + 1 Armor Shred, Ground | `heavier_incense` -> `plague_incense` -> `rust_communion` | `acid_sprayer` -> `solvent_tank` |
| 7 | `fever_shrine` | 55 Offerings | 2 (aura) | No attack; +15% fire rate aura to towers (non-stacking) | `more_candles` -> `frenzy_rites` -> `ecstatic_vigil` | `server_rack_altar` -> `mesh_network` |
| 8 | `the_congregation` | 45 Offerings | 1 (adj) | Summons 2 blockers (60 HP, 2 Kinetic/s, 10s resummon) | `bigger_flock` -> `devoted` -> `martyrs_chorus` | `picket_line` -> `union_strike` |
| 9 | `tithe_box` | 35 Offerings | 0 | No attack; +4 Offerings every 5s | `bigger_plate` -> `blood_tithe` -> `dark_patron` | `scrap_collector` -> `chop_shop` |
| 10 | `substation_effigy` | 50 **Scrap** | 3 | 14 Electric, 0.85/s, Ground+Air (Air prio), chains 3 targets | `copper_thieves` -> `astral_conduction` -> `voice_in_the_static` | `substation_tap` -> `breaker_cascade` |

---

## 6. Factions, Enemy Units, Bosses & Leveling

All 16 regular units live in `res://data/units/*.tres` and all 5 bosses live in `res://data/units/bosses/*.tres`, loaded via `UnitLibrary` (`res://scripts/units/unit_library.gd`).

- **Per-Unit-Type Kill Leveling (`UnitLeveling` & `UnitBalanceData`):**
- Kills are counted per `unit_id` across all factions (Bosses do not accumulate kill levels).
- `level = floor(pow(kills_of_this_unit_type / 3.0, 0.72))`
- **Interval Level Floor:** Regular units have a minimum level floor of `(interval_index - 1) * 2`.
- **Spawn-Time Snapshotting:** Stats are scaled at spawn time and fixed for the unit's lifetime:
- `health_mult = (1.0 + 0.22 * level) * pow(1.06, max(0, level - 3))`
- `speed_mult = min(1.0 + 0.025 * level, 1.40)`
- **Factions & 16 Regular Units (cost / base HP / speed / tags & abilities):**
- **Swarm Syndicate (`swarm_syndicate`):**
- `gig_runner` (2 / 30 / 1.6 / Ground, Fast, Swarm — `LeakSteal(5)`)
- `scooter_courier` (4 / 55 / 2.0 / Ground, Fast — `SlowResist(50%)`, `CourierPack(2 hexes, +25% speed)`)
- `hype_influencer` (6 / 70 / 1.0 / Ground, Support, Aura, Fragile — `SpeedAura(2, +20%)`, `DeathBurst(2, +40% speed for 3s)`)
- `gig_van` (9 / 220 / 0.9 / Ground, Spawner — `SpawnOnTimer(gig_runner, 3s, cap 4, release_on_death)`)
- **Iron Board (`iron_board`):**
- `security_contractor` (4 / 100 / 0.8 / Ground, Armored — Kinetic 0.75)
- `riot_shield_unit` (6 / 140 / 0.7 / Ground, Shielded — `ShieldRegen(120 HP, 4s delay, bypass Void & Corrosive)`)
- `siege_walker` (10 / 260 / 0.6 / Ground, Ranged, Armored — Kinetic 0.8, `RangedSuppress(3 hexes, -30% fire rate)`, `Breakthrough`)
- `sponsor_mech` (15 / 600 / 0.5 / Ground, Tank, Cybernetic, Armored — Kinetic 0.7, Corrosive 1.3, Void 1.2, Electric 1.25, `Breakthrough`, `scrap_value = 12`)
- **Hostile Takeover Inc. (`hostile_takeover`):**
- `taser_skirmisher` (5 / 80 / 1.0 / Ground, Electric — Electric 0.5, `TowerDisable(every 6s, 2s duration, nearest tower)`)
- `ghost_contractor` (7 / 90 / 1.1 / Ground, Cloaked — `Cloak`)
- `compliance_officer` (9 / 160 / 0.8 / Ground, Anti-Magic, Support — Psychic 0.6, `AntiMagicAura(2 hexes)`)
- `acquisitions_rep` (12 / 140 / 0.7 / Ground, Hacker, Support — Electric 0.7, `TowerConvert(every 15s, 3s channel, 8s duration, highest-cost tower in 3 hexes, +20% enemy speed aura)`)
- **Skyline Logistics (`skyline_logistics`):**
- `courier_drone` (2 / 25 / 1.8 / Air, Fast, Fragile — Electric 1.3)
- `cargo_hauler` (7 / 200 / 0.7 / Air, Armored — Kinetic 0.8)
- `medic_drone` (8 / 90 / 1.0 / Air, Healer — `Heal(2 hexes, 15 HP/s, 3 targets, not self/medics)`)
- `drone_carrier` (18 / 450 / 0.6 / Air, Tank, Spawner — Kinetic 0.75, Electric 1.3, `SpawnOnTimer(courier_drone, 4s, cap 6, batch 2)`)
- **5 Bosses (`Boss` tag):**
- **Boss Scaling:** `HP = base_hp * (1.0 + 0.55 * (n - 1) + 0.15 * (n - 1)^2)` for 1-based `boss_index = n`. Every completed 5-interval cycle shortens boss telegraphs and cooldowns by **15%** (`0.85^cycle`, min `0.25x`).
- `the_disruptor` (Swarm Syndicate, 1000 base HP, 0.9 speed, Ground): `NetworkEffect` (-8% dmg taken per Syndicate unit within 3 hexes, max 50%) + `SurgePricing` (every 15s, 1.5s siren telegraph, +30% Syndicate speed for 4s).
- `the_chairman` (Iron Board, 1600 base HP, 0.4 speed, Ground, Armored, Tank): `Restructuring` at 100/66/33% HP (shifts 0.4x resistance to a new DamageTag, halts & immune for 3s while 2 `riot_shield_unit` escorts spawn).
- `the_raider` (Hostile Takeover, 1200 base HP, 0.6 speed, Ground, Hacker): `LeveragedBuyout` every 20s (4s beam on highest-cost tower within 4 hexes + 150 HP `bid_drone`; converts tower for 10s unless drone is killed, channel is interrupted, or cleansed for 50% base cost).
- `the_prime_dispatcher` (Skyline Logistics, 1200 base HP, 0.5 speed, Air, Tank, Spawner): `SameDayDelivery` every 15s (drops 2 `supply_pod` units [150 HP] with 2s reticle that open after 3s into 3 `courier_drone` units each).
- `the_holding_company` (Coalition, 2500 base HP, 0.45 speed, Ground, Tank, Cybernetic): Switches between the 4 faction boss mechanics every 25% HP loss (non-repeating seeded order) at **70% effect**.

---

## 7. Adaptive Wave Director

Implemented in `WaveDirector`, `WaveRoster`, `CoverageTracker`, `DirectorBalanceData`, and `DirectorSimulator` (`res://scripts/director/`).

- **Schedule & Factions:**
- 10 waves per interval (`WAVES_PER_INTERVAL = 10`). Intervals `1..4` of each 5-interval cycle are **Faction** intervals (seeded RNG, no consecutive regular faction repeats); Interval `5` (`5, 10, 15...`) is a **Coalition Mixed** interval (`all 16 units`, `the_holding_company` boss).
- **Budget & Late-Wave Ramp:**
- Base polynomial: `B(w) = (10 + 5w + 0.12 * w^2) * (1 + 0.15 * completed_cycles) * rubber_factor`
- **Late-Wave Ramp (`w > 15`):** Multiplies budget by `1.0 + 0.035 * (w - 15) + 0.0018 * (w - 15)^2` so waves 20–50+ continue to scale sharply.
- **Stars Are Right:** `B(w) * 1.10`.
- **Rubber-Banding:** Starts at `1.0` (`[0.80, 1.25]`); `-0.10` if `2+` lives lost last wave; `+0.10` after `3` consecutive zero-leak waves; else moves `0.05` toward `1.0`. Ignored (`max(1.0, rubber_factor)`) on Boss waves.
- **Boss Waves:** Boss is not bought from budget; escorts receive **60%** of `B(w)` (`40%` withheld) and are capped at `MAX_BOSS_ESCORT_UNITS = 24`.
- **Unit Cost & Excess Budget:** `effective_cost = cost * (1 + 0.03 * level)`. Regular waves cap at `MAX_UNITS_PER_WAVE = 60` and spend remaining budget as `+1` bonus spawn level on chosen unit types.
- **Hard Constraints (H1–H6) & Early-Wave Guards:**
- Total cost `<= budget`; single unit type `<= 50%` of budget; from wave `6+`, `>= 3` distinct unit types; Air `<= 40%` of budget unless Skyline (or interval 1); Spawners `<= 2` and Healers `<= 2` per wave; never exceed path delivery window.
- `Cloaked` units are withheld until after the first boss (`wave > 10`). Early Skyline intervals (`wave <= 10`) mix in basic Ground units so wave 1 is never 100% Air.
- **Scoring, Counter-Biases & Fairness:**
- `score = (weakness_exploit / effective_cost) * diversity * faction_weight * counter_bias * noise` (`noise` in `[0.8, 1.2]`, weighted random pick).
- **Adaptation Lag:** `CoverageTracker` measures player DPS per `UnitTag` from `tower_damaged_enemy` events over the previous **2 completed waves**; idle towers that dealt no damage stay unscouted (`0.0`).
- **Fairness Swap:** If every picked unit targets a tag where player coverage is `< MIN_COVERAGE (5.0)` while the player covers at least one tag, swaps the lowest-value unit for a handleable one.
- **Spawn Order:** Tanks & Spawners first -> core pack with Swarms spread through the middle & Support/Healers inside the pack -> staggered Fast units (never all released in the first `1.0s`) -> Boss last after `1.5s` lead gap.

---

## 8. 3D World, Biomes, Audio, UI & Performance

- **Urban Center Biome & 3D Views (`res://scripts/world/`):**
- `TerrainView`, `BiomeData` (`res://data/biomes/urban_center.tres`), and `BiomeTileModels` render chunks via per-archetype `MultiMeshInstance3D` batches: skyscrapers on `BLOCKED` hexes, urban districts on `BUILDABLE` hexes, cleared street lots under placed towers, and recessed avenue road tiles on path hexes.
- Entering tower build mode dims urban building opacity (`0.45` alpha) and highlights valid/invalid build-zone hexes in `OverlayView`.
- `OverlayView` renders a distinct gold aura ring (`buff_range_ring_color`) for buff towers (`fever_shrine`, `chop_shop`) vs cyan (`range_ring_color`) for attack towers.
- `TowerView` meshes are strictly under `HexMath.TOWER_MAX_HEIGHT = 1.5`.
- `EnemyMoverView` & `EnemyVisualPool` pool enemy nodes, apply a depth-disabled occlusion silhouette pass, aim projectiles at elevated Air unit models (`get_aim_world_position()`), and offload visual interpolation/label formatting to `WorkerThreadPool` when `>= 32` enemies are active.
- **Audio System (`res://scripts/audio/`):**
- Pure-logic `AudioCueSystem` + `AudioBalanceData` (`res://data/audio_balance.tres`) + `AudioSettings` (`user://audio_settings.cfg`) + `SoundManager` node pool.
- Enforces per-cue `min_interval` cooldowns, per-cue `max_voices`, global voice cap (`max_global_sfx_voices = 8`), high-speed/density interval scaling at `2x/3x` speed, and polyphony volume ducking.
- **UI & Controls (`res://scripts/ui/`):**
- `MainMenu` (`res://scenes/main_menu.tscn`) -> `Main` (`res://scenes/main.tscn`).
- `SettingsMenu` & `DisplaySettings` (`user://display_settings.cfg`): machine-bounded resolution & aspect-ratio filtering, PC window modes (hidden on Steam Deck), 5-second confirmation with auto-revert, and `0..100` Background/FX audio sliders.
- `BuildPalette`: Toggle with `B`, inspect with `1–9` or single click, confirm build with `Enter`, a second click, or double-click.
- `IntelPanel` & `TelegraphLayer`: Pre-wave Intel preview; post-boss "BOSS SLAIN / Next Faction" banners automatically clear when the next wave starts.
- `CameraRig`: Orthographic (`size 7..48`, default `18`), WASD/arrow pan, middle-mouse drag pan, single-finger touchscreen drag pan, mouse-wheel & two-finger pinch zoom, `Home` (focus base), `End` (focus spawn/preview).

---

## 9. Engineering Conventions & Project Layout

- **Data-Driven Resources:** All game data lives in `.tres` files under `res://data/` (`data/towers/`, `data/upgrades/`, `data/units/`, `data/units/bosses/`, `data/biomes/`, and `data/*_balance.tres`). Never scatter balance numbers through logic.
- **Pure Logic vs. Nodes:** Core systems (`HexGrid`, `HexMath`, `HexSpatialIndex`, `PathGenerator`, `TowerSystem`, `TowerInstance`, `CombatUnit`, `UnitLeveling`, `WaveDirector`, `WaveRoster`, `CoverageTracker`, `AudioCueSystem`, `DisplaySettings`, `AudioSettings`) extend `RefCounted` so they can be tested headlessly without a scene tree.
- **Deterministic RNG:** All randomness uses seeded `RandomNumberGenerator` instances passed into systems. Never call global `randf()` or `randi()`.
- **Typing:** Always use `class_name` and explicit static type annotations on every `var`, parameter, return type, and signal.
- **Cross-System Signals (`GameState` & `TowerSystem`):**
- `wave_started(wave_number)`
- `wave_ended(wave_number)`
- `enemy_spawned(unit)`
- `enemy_died(unit_id)`
- `enemy_leaked(unit_id, leak_cost)`
- `boss_killed(wave_number)`
- `boss_leaked(wave_number)`
- `path_extended(growth_result)`
- `tower_damaged_enemy(tower_id, tower_type, unit_id, unit_tags, amount, damage_tag)`

### Directory Structure

```text
res://
├── AGENTS.md
├── data/
│   ├── audio_balance.tres
│   ├── director_balance.tres
│   ├── path_balance.tres
│   ├── tower_balance.tres
│   ├── unit_balance.tres
│   ├── visual_theme.tres
│   ├── biomes/         # BiomeData resources (urban_center.tres)
│   ├── towers/         # 9 TowerData resources
│   ├── upgrades/       # 45 UpgradeNode resources
│   └── units/          # 16 regular UnitData + rogue_entity.tres + bosses/ (5 Boss UnitData)
├── scenes/
│   ├── main_menu.tscn              # Main entry scene (MainMenu + SettingsMenu)
│   ├── main.tscn                   # Primary gameplay scene (MainSceneController)
│   └── benchmark_300_enemies.tscn  # 3D performance benchmark scene
├── scripts/
│   ├── audio/          # AudioBalanceData, AudioCueSystem, AudioSettings, SoundManager
│   ├── core/           # SimClock, GameState, HexMath, HexSpatialIndex, DisplaySettings, VisualThemeData
│   ├── director/       # WaveDirector, WaveRoster, CoverageTracker, DirectorBalanceData, DirectorSimulator
│   ├── path/           # HexGrid, PathGenerator, PathConstants, PathBalanceData
│   ├── towers/         # TowerData, UpgradeNode, TowerInstance, CombatUnit, TowerSystem, TowerLibrary, TowerBehaviorRegistry, TowerBalanceData
│   ├── ui/             # MainMenu, InGameMenu, SettingsMenu, TopBar, BuildPalette, TowerPanel, IntelPanel, WaveControls, BossBar, TelegraphLayer, GameOverScreen, DebugPanel, PlaceholderIcons
│   ├── units/          # UnitData, AbilityData, UnitAbilityRegistry, UnitLeveling, UnitLibrary, UnitBalanceData, LossReport
│   └── world/          # MainSceneController, TerrainView, PathView, OverlayView, TowerFactory, TowerView, EnemyVisualPool, EnemyMoverView, CombatEffectsView, CameraRig, BiomeData, BiomeLibrary, BiomeTileModels, PlaceholderModels, Benchmark300Enemies
└── tests/              # Headless & scene test suites (run via run_tests on res://tests)
```
