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
- Boss waves arrive every **5** waves from wave **10** (`10, 15, 20...`; `waves_per_interval = 5`, `first_boss_wave = 10`). When the boss is slain and all wave enemies are cleared, the path extends in `POST_BOSS`.
- **Towers have NO HP in v1.** Enemies interact with towers by disabling (`TowerDisable`), suppressing fire rate (`RangedSuppress`), negating Corruption bonuses (`AntiMagicAura`), or channeling to convert them (`TowerConvert`, `LeveragedBuyout`).
- **Run Events (see §8):** pseudo-random events fire every `3..7` waves, drawn from a shuffled deck of Event cards (never advertised before they happen). They include buffs and debuffs. The classic "Stars Are Right" (+20% Revealed damage, +10% budget) is now one buff card among many rather than a fixed every-5th-wave event.

---

## 2. Currencies & Economy

All player currency spending must route through the single choke point `GameState.spend(currency, amount, reason)`.

- **Offerings (`Start: 150`):**
- Used to build Offerings-cost base towers (8 of the 11 archetypes), unlock `REVEALED` T3/T4 upgrades, perform global **Penance** (`40 Offerings -> -5 Corruption`), and cleanse enemy tower conversions early (`50%` of base tower cost).
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
- **Displacement attacks never waste a knockback on an immune mob.** A tower whose attack displaces (`propane_pulse` knockback, `deep_grasp` drag) is flagged via `TowerBehaviorRegistry` (`applies_displacement`) and `TowerInstance.applies_displacement()`; its primary-target selection prefers a unit that is **not** displacement-immune (`CombatUnit.is_displacement_immune()` — a Boss, or a unit past its 3x budget), falling back to an immune unit only when nothing displaceable is in range. An AoE pulse still damages immune units in its ring; it simply does not attempt to move them.

---

## 4. Hex World & Procedural Path Growth

- **Coordinate System (`HexMath` & `HexGrid`):**
- Sparse Dictionary-based pointy-top axial hex grid `(q, r)` with 6 directions (`HEX_SIZE = 1.0`). No fixed map bounds.
- All gameplay logic uses axial hex coordinates and integer hex distances (`HexMath.distance`). Never use world or pixel distances in gameplay code.
- Terrain is `BUILDABLE` or `BLOCKED` (~12% `BLOCKED_TERRAIN_FRACTION`), generated lazily in chunks (`CHUNK_RADIUS = 8`) deterministically from `run_seed + chunk_coord`, independent of chunk load order. Chunks containing path hexes, towers, or reserved preview hexes are pinned and cannot unload.
- **Initial Path & Growth Lifecycle (`PathGenerator`):**
- Initial path starts at the player's base (`Vector2i.ZERO`, path index `0`) and extends `INITIAL_PATH_LENGTH = 18` hexes to the initial spawn hex.
- **Preview (`PREVIEW_LEAD_WAVES = 2`):** Generated at the intermission before wave `8, 13, 18...` (2 waves before each boss). Immediately reserves `ghost_path_hexes` and any hex in the 2-hex build zone *only* of the previewed extension.
- **Commit:** Happens once after each boss wave in `POST_BOSS` (only when the boss is dead and no enemies remain). Commits the *exact* previewed extension (`10..16` hexes, `MIN_EXT..MAX_EXT`) from the spawn end.
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

All 11 cult towers live in `res://data/towers/*.tres` and their upgrade resources (`11 x [1 T2 + 2 T3 + 2 T4]`, plus the optional Rite branch below, for 77 total) live in `res://data/upgrades/*.tres`. A full human-readable accounting of every tower and node lives in [`TOWERS.md`](TOWERS.md).

- **Placement & Adjacency Rules:**
- 1 hex per tower on a `BUILDABLE`, non-path, non-reserved, unoccupied hex within hex distance `<= 2` of the committed path.
- **Exception:** `the_congregation` (`range_hexes = 1`) **must be placed directly adjacent (`hex_distance == 1`)** to a committed path hex.
- **Upgrade Tree & Branch Locking:**
- `T1 (base) -> T2 (shared, 0.6x base cost) -> fork: REVEALED T3 (1.0x) -> T4 Capstone (1.8x) OR RIGGED T3 (1.0x) -> T4 Capstone (1.8x)`.
- **All 11** towers carry a **third, optional RITE branch** (`rite_t3_upgrade` / `rite_t4_upgrade`, `UpgradeNode.Branch.RITE = 3`) locked to the other two exactly the same way. Damage is meaningless on the towers with no attack of their own (`fever_shrine`, `the_congregation`, `tithe_box`, `dead_air_altar`), so the branch scales whatever stat the tower actually has: `UpgradeNode.corruption_scaled_stat` is a dictionary of additive per-point-Corruption bonuses keyed by stat name (`"damage"` folds into the older `corruption_scaled_damage` field; `"aura_fire_rate"`, `"income"`, `"summon_hp"` and `"slow_aura"` cover the support/control towers). `TowerSystem.get_rite_stat_multiplier(tower, key)` returns `1.0` when a tower carries no such scaling, so every call site multiplies unconditionally.
- The T3 fork is **exclusive**: choosing any one branch permanently locks the other **two** for that tower. The lock is checked **before** the tier-order guards so a locked branch reports `branch_locked_to_<branch>` rather than a misleading `requires_t2_first` (the player would otherwise be told to buy a T2 they already own).
- **Revealed Upgrades:** Paid in **Offerings**; add global **Corruption** (`T3 +4`, `T4 +8`).
- **Rigged Upgrades:** Paid in **Scrap**; set that tower's **Jank** (`T3 -> 10%`, `T4 -> 25%`).
- **Rite Upgrades:** Paid in **Rites** (`Currency.RITES = 2`) at flat cost `T3 = 1`, `T4 = 2` — deliberately NOT base-cost multiples, since Rites are a scarce Corruption-derived currency and scaling them by an Offering cost is meaningless. They add **no Corruption and no Jank**: the price was already paid when the Rites were drawn (Corruption + permanent Attention). Their signature is `UpgradeNode.corruption_scaled_damage` (additive damage per point of current Corruption, consumed via `TowerSystem.get_rite_corruption_multiplier()`), i.e. the branch turns the danger meter into a damage stat. Rites are **never refunded** on sell (`sell` refunds Offerings and Scrap only), so drawing power and then liquidating cannot launder Attention away. Every Rite node also **feeds the meter on its kills** (`corruption_per_kill`, read generically through `TowerInstance.get_behavior_param_sum()`), so the branch's price and its power are the same currency: a Rite tower accelerates its own damage *and* the Reckoning that punishes it. Some nodes also pay a bounty on the kill (`rite_offerings_per_kill`, `rite_scrap_per_kill`). Because the params are read **by name rather than by behaviour id**, adding a new Rite node requires no new branch in the kill code.
- **Corruption (Global `0..100`):**
- Revealed towers deal `+0.25%` additive damage per point (stacks additively with Stars Are Right `+20%`; negated within 2 hexes of a `compliance_officer`).
- At `50+`: `10%` chance at wave start one random Revealed tower misfires (disabled that wave). At `75+`: `20%`.
- At `100`: Spawns hostile **Rogue Entities** (`res://data/units/rogue_entity.tres`: base 550 HP, speed 1.25, 25%–50% all-damage resistance, `Breakthrough`, `TowerDisable` every 5s, `leak_cost = 3+`).
- Rogue Entities level up `+1` every time one is killed (`1.45^level` HP compounding + wave scaling) and spawn in multiples (`1..5`) as Rogue level and wave number rise.
- **Penance:** Pay `40 Offerings` to reduce Corruption by `5`.
- **Rite branch visibility:** the Rite T3 card is **hidden until the cult has received its first Rite** (`TowerSystem.has_ever_drawn_rite()` — holds one, or `rites_drawn_total > 0`). On every tower from wave 1 it was a dead button (0 Rites, no Reservoir) and spoiled the branch. Spending the Rite does **not** re-hide it: the T3 choice is permanent, so a committed player must still see what comes next.
- **Rites & the Reckoning (the price of power):**
- **Rites** are Corruption *spent as a resource*. Drawing a Rite costs `10 Corruption` (`RITE_CORRUPTION_COST`) and banks `1 Rite`. The sink for Rites is the third tower branch.
- Drawing Rites requires the cult to **hold a Corruption Reservoir** site — the Reservoir is what makes the rot drawable, and is the reason to fight for one.
- Each Rite drawn adds `10` **Rite debt** (`RITE_DEBT_PER_RITE`). Debt accrues *since the last reckoning* and scales how bad that reckoning is (`RITE_DEBT_PER_ROGUE_LEVEL = 25` per extra level).
- **THE RECKONING has three rules, and all three matter:**
  1. **Rogues wake from the Corruption held RIGHT NOW** (`corruption >= get_rogue_entity_threshold()`), so spending Corruption on Rites is a genuine way to back off the brink.
  2. **Debt decides how bad they are, not whether they come** — it adds levels (HP, speed, resistances, leak cost, kill reward) and spawn count, clamped to `MAX_ROGUE_ENTITY_SPAWN_COUNT = 8`.
  3. **Debt RESETS to 0 when they come.** This is load-bearing: *without* it a single spending spree compounds into a permanent, unrecoverable Rogue spiral. The reckoning happens, and then it is over.
- A held Reservoir raises `get_rogue_entity_threshold()` **alongside** the Corruption cap, so the site genuinely buys "more rot before it wakes" rather than letting the cult climb past its own danger line.
- **Penance** (`40 Offerings -> -5 Corruption`) reduces the *gate*, so it still helps you duck the next reckoning even when debt is high.
- The top bar shows Rites as a currency chip beside Offerings and Scrap (the three read as one resource set), then `Reckoning: +N` (severity of the next wave), the latter hot once Corruption is at the line. The Corruption and Reckoning readouts carry hover tooltips explaining the danger meter, and the Draw Rite button names its Corruption price in its own label (read from balance, never hardcoded).
- **Reckoning alert (the one moment the player learns Rogues are on the board).** Rogue Entities carry no `BOSS` tag, so nothing else announces them. When they spawn, `GameState` emits `reckoning_started(rogue_count, severity, leak_cost, spawn_world_pos)` (after the wave's Run Event, so on a rare event+Reckoning wave the danger warning is the one left on screen). `TelegraphLayer` answers with a three-channel alert: an **emphasized pulsing banner** naming the count and the per-leak life cost, a **full-screen radial danger vignette** that pulses and fades (~1.6s) so it is felt from anywhere, and an **off-screen edge arrow** pointing at `spawn_world_pos`. `SoundManager` plays the bespoke high-priority `rogue_reckoning` stinger (generated: an otherworldly, subliminal laugh — the cosmic creditor collecting the cult's debt).
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
| 11 | `dead_air_altar` | 45 Offerings | 3 | No attack; continuous 45% **Air-only** slow aura, **Grounds** slowed air (+25% Electric damage taken) | `colder_current` -> `the_sky_is_closed` -> `heaven_under_glass` | `salvaged_compressor` -> `blackout_rig` |

---

### Rite Branch Roster (optional third branch, paid in Rites)

All eleven towers carry it. Each scales **the stat it actually has** — damage for attackers, aura fire rate / income / summoned HP / slow-aura strength for the four support & control towers — and every node also converts kills into Corruption to feed the meter it draws on:

| Tower | Rite T3 (1 Rite) | Rite T4 (2 Rites) |
|---|---|---|
| `hexed_nail_gun` | `nail_of_accounting` (+30% dmg, +0.5%/Corruption) | `the_audit_comes_due` (+45% dmg, +30% rate, +0.8%/Corruption) |
| `chanting_choir` | `the_song_is_billed` (+25% dmg, +1 member, +0.4%/Corruption, +1 Corruption/kill) | `unspoken_receipts` (+45% dmg, +1 member, +1 hex, +0.7%/Corruption, +2 Corruption and +1 Offering/kill) |
| `gutter_ritual_circle` | `the_circle_is_paid` (+25% dmg, +1 hex, +0.3%/Corruption) | `communion_of_the_maw` (+40% dmg, +1 hex, +0.6%/Corruption) |
| `tentacle_storm_drain` | `drowned_ledger` (+30% dmg, 45% slow aura, +0.5%/Corruption, +1 Corruption/kill) | `the_fathom_collects` (+50% dmg, 55% slow aura, +1 target, +0.8%/Corruption, +2 Corruption and +1 Scrap/kill) |
| `watcher_in_the_billboard` | `covetous_gaze` (+40% dmg, +0.5%/Corruption) | `the_debt_collector` (+70% dmg, +1 hex, +1.0%/Corruption) |
| `rust_censer` | `corroded_receipts` (+30% dmg, 6.0 s DoT, +0.5%/Corruption, +1 Corruption/kill) | `the_rust_audits` (+50% dmg, 8.0 s DoT, Shred cap 8, +0.8%/Corruption, +2 Corruption and +1 Offering/kill) |
| `substation_effigy` | `metered_current` (+30% dmg, +0.5%/Corruption, +1 Corruption/kill) | `the_grid_forecloses` (+50% dmg, +25% rate, +0.8%/Corruption, +2 Corruption and +1 Scrap/kill) |
| `fever_shrine` | `candles_for_the_ledger` (aura +35% rate, +0.4%/Corruption aura, +1 Corruption/kill) | `the_vigil_pays_interest` (aura +50% rate, +1 hex, +0.7%/Corruption aura, +2 Corruption/kill) |
| `the_congregation` | `paid_in_flesh` (+1 blocker, +0.4%/Corruption blocker HP, +1 Corruption/kill) | `audit_of_the_flock` (+1 blocker, +60% blocker HP, +0.7%/Corruption blocker HP, +2 Corruption/kill) |
| `tithe_box` | `the_plate_never_empties` (+40% income, +0.4%/Corruption income, +1 Corruption/kill) | `the_till_audits_itself` (+75% income, +0.7%/Corruption income, +2 Corruption and +1 Offering/kill) |
| `dead_air_altar` | `tithe_of_stillness` (+0.4%/Corruption slow aura, +1 Corruption/kill) | `the_ledger_holds_its_breath` (+0.7%/Corruption slow aura, +1 hex, +2 Corruption/kill) |

## 6. Factions, Enemy Units, Bosses & Leveling

All 16 regular units live in `res://data/units/*.tres` and all 5 bosses live in `res://data/units/bosses/*.tres`, loaded via `UnitLibrary` (`res://scripts/units/unit_library.gd`). A full human-readable accounting — including the Rogue Entity and the ability-component reference — lives in [`UNITS.md`](UNITS.md).

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
- **Boss Scaling (WAVE-anchored):** bosses arrive every **5** waves from wave **10** (`10, 15, 20...`). Boss HP is anchored to the WAVE, not the boss index: `tier = max(0, wave / 10 - 1)` and `HP = base_hp * (1.0 + 0.55 * tier + 0.15 * tier^2)`, so a shorter boss interval adds MORE bosses without inflating each boss's HP for the wave it arrives on. Telegraphs and cooldowns shorten after each `5` completed reference cycles by **15%** (`0.85^cycles`, min `0.25x`). The first boss is pinned at wave `10` (`DirectorBalanceData.first_boss_wave`), decoupled from the interval so a shorter cadence never drags it earlier.
- `the_disruptor` (Swarm Syndicate, 1000 base HP, 0.9 speed, Ground): `NetworkEffect` (-8% dmg taken per Syndicate unit within 3 hexes, max 50%) + `SurgePricing` (every 15s, 1.5s siren telegraph, +30% Syndicate speed for 4s).
- `the_chairman` (Iron Board, 1600 base HP, 0.4 speed, Ground, Armored, Tank): `Restructuring` at 100/66/33% HP (shifts 0.4x resistance to a new DamageTag, halts & immune for 3s while 2 `riot_shield_unit` escorts spawn).
- `the_raider` (Hostile Takeover, 1200 base HP, 0.6 speed, Ground, Hacker): `LeveragedBuyout` every 20s (4s beam on highest-cost tower within 4 hexes + 150 HP `bid_drone`; converts tower for 10s unless drone is killed, channel is interrupted, or cleansed for 50% base cost).
- `the_prime_dispatcher` (Skyline Logistics, 1200 base HP, 0.5 speed, Air, Tank, Spawner): `SameDayDelivery` every 15s (drops 2 `supply_pod` units [150 HP] with 2s reticle that open after 3s into 3 `courier_drone` units each).
- `the_holding_company` (Coalition, 2500 base HP, 0.45 speed, Ground, Tank, Cybernetic): Switches between the 4 faction boss mechanics every 25% HP loss (non-repeating seeded order) at **70% effect**.

---

## 7. Adaptive Wave Director

Implemented in `WaveDirector`, `WaveRoster`, `CoverageTracker`, `DirectorBalanceData`, and `DirectorSimulator` (`res://scripts/director/`).

- **Schedule & Factions:**
- 5 waves per interval (`WAVES_PER_INTERVAL = 5`). Intervals `1..4` of each 5-interval cycle are **Faction** intervals (seeded RNG, no consecutive regular faction repeats); the 5th interval of each cycle (waves `21-25`, `46-50`, ...) is a **Coalition Mixed** interval (`all 16 units`, `the_holding_company` boss).
- **Budget & Late-Wave Ramp:**
- Base polynomial: `B(w) = (10 + 5w + 0.06 * w^2) * (1 + 0.10 * completed_cycles) * rubber_factor`
- **Late-Wave Ramp (`w > 15`):** Multiplies budget by `1.0 + 0.02 * (w - 15) + 0.0008 * (w - 15)^2` so waves 20–50+ continue to scale sharply.
- **Event budget modifier:** the active Run Event's `budget_mult` scales `B(w)` (e.g. Stars Are Right `×1.10`).
- **Rubber-Banding:** Starts at `1.0` (`[0.80, 1.25]`); `-0.10` if `2+` lives lost last wave; `+0.10` after `3` consecutive zero-leak waves; else moves `0.05` toward `1.0`. Ignored (`max(1.0, rubber_factor)`) on Boss waves.
- **Boss Waves:** Boss is not bought from budget; escorts receive **60%** of `B(w)` (`40%` withheld) and are capped at `MAX_BOSS_ESCORT_UNITS = 24`.
- **Unit Cost & Excess Budget:** `effective_cost = cost * (1 + 0.03 * level)`. Regular waves cap at `MAX_UNITS_PER_WAVE = 60`. Once the *effective* cap is reached, leftover budget is spent as `+1` bonus spawn level on chosen unit types, bounded per type by `MAX_BONUS_LEVELS_PER_UNIT = 5` (unbounded levels previously reached `+86..+152` spawn levels, i.e. thousands of × HP). Anything still unspendable is recorded on the roster as `unspent_budget` (never silently discarded) and is reserved for future fork/objective budgets. Boss waves gate on their own `MAX_BOSS_ESCORT_UNITS = 24` cap, so escorts receive the same bonus-level compensation. Never cap unit count below `MAX_UNITS_PER_WAVE` from path length — the compensation phase gates on the effective cap, so a lower cap makes waves weaker, not denser.
- **Hard Constraints (H1–H6) & Early-Wave Guards:**
- Total cost `<= budget`; single unit type `<= 50%` of budget; from wave `6+`, `>= 3` distinct unit types; Air `<= 40%` of budget unless Skyline (or interval 1); Spawners `<= 2` and Healers `<= 2` per wave; never exceed path delivery window.
- `Cloaked` units are withheld until after the first boss (`wave > 10`). Early Skyline intervals (`wave <= 10`) mix in basic Ground units so wave 1 is never 100% Air.
- **Scoring, Counter-Biases & Fairness:**
- `score = (weakness_exploit / effective_cost) * diversity * faction_weight * counter_bias * noise` (`noise` in `[0.8, 1.2]`, weighted random pick).
- **Adaptation Lag:** `CoverageTracker` measures player DPS per `UnitTag` from `tower_damaged_enemy` events over the previous **2 completed waves**; idle towers that dealt no damage stay unscouted (`0.0`).
- **Fairness Swap:** If every picked unit targets a tag where player coverage is `< MIN_COVERAGE (5.0)` while the player covers at least one tag, swaps the lowest-value unit for a handleable one.
- **Spawn Order:** Tanks & Spawners first -> core pack with Swarms spread through the middle & Support/Healers inside the pack -> staggered Fast units (never all released in the first `1.0s`) -> Boss last after `1.5s` lead gap.

---

## 8. Run Events (Event Deck)

Implemented in `RunEventSystem`, `EventData`, `EventBalanceData`, and `EventLibrary`
(`res://scripts/events/`). Event data lives in `res://data/events/*.tres` (7 buffs / 7 debuffs)
with tunables in `res://data/event_balance.tres`.

- **Deck of cards:** every event is a single card. The deck is shuffled with a seeded RNG
  (`run_seed ^ EVENT_SEED_SALT`) and drawn **without replacement**, so a drawn event never
  repeats until the deck is reshuffled — a randomized rotation, not a fixed cycle.
- **Draw constraints:** a card is drawn only if (1) its id differs from the last fired event,
  (2) its id differs from the one before that (no `a → b → a`), and (3) it does not extend a
  same-category run beyond `MAX_SAME_CATEGORY_RUN = 3` (bad-luck protection: never more than
  3 buffs or 3 debuffs in a row). Events do **not** strictly alternate category.
- **Cadence:** after each event, the next fires `GAP_MIN..GAP_MAX = 3..7` waves later. Events
  may fire on any wave except the **first boss wave (10)**.
- **Not advertised:** the upcoming event is resolved at intermission (so its budget modifier is
  baked into the locked roster) but is revealed to the player only at wave start, via the
  `event_triggered` banner (`TelegraphLayer`) and a per-event audio stinger. The `IntelPanel` no
  longer telegraphs it.
- **Effects (mixed instant + wave-duration):** instant effects fire once at wave start
  (Offerings/Scrap grants, percentage drains, Corruption change, +Jank on Rigged towers);
  duration effects last the flagged wave and clear at wave end (additive Revealed damage bonus,
  all-tower damage/fire-rate multipliers, enemy speed/HP multipliers, Scrap-income multiplier,
  Revealed-bonus suppression, and the director `budget_mult`).
- **Announcement:** every Event card has a **unique** stinger mapped by
  `AudioBalanceData.event_cues` (event id -> cue id) and a **larger, pulsing, bordered banner**
  (`TelegraphLayer.show_banner(..., emphasis: true)`), so an event is recognisable by ear and
  unmissable on screen. Unlisted ids fall back to `CUE_RUN_EVENT`.
- **Buff roster (7):** `stars_are_right`, `dark_patron_grant` (Offerings), `black_market_haul`
  (Scrap), `cargo_cult_windfall` (Offerings + Scrap hybrid), `rites_of_haste`, `the_veil_thins`,
  `salvage_bloom`.
- **Debuff roster (7, soft only — no direct life loss, no instant game-over):**
  `market_correction`, `scrap_glut`, `supply_shock`, `hardened_plating`, `static_interference`,
  `creeping_rust`, `corporate_audit`.
- **Fully deterministic:** identical `run_seed` produces an identical event schedule, so replays
  and `DirectorSimulator` runs reproduce exactly.

---

## 8. Objectives (Claimable Sites on New Ground)

Implemented in `ObjectiveSystem`, `ObjectiveInstance`, `ObjectiveData`, `ObjectiveBalanceData`, and
`ObjectiveLibrary` (`res://scripts/objectives/`). Data lives in `res://data/objectives/*.tres`
(3 objectives) with tunables in `res://data/objective_balance.tres`.

Objectives are the **payload of path growth**: each committed extension settles up to
`sites_per_growth = 1` site on the newly opened ground (never before `first_objective_wave = 10`),
at most `max_sites = 8` alive. A site sits on a free, non-path hex within 2 hexes of the new
stretch and always retains a legally buildable hex within its claim radius (the site hex itself
counts, guaranteeing claimability).

- **Lifecycle:** `UNCLAIMED -> CLAIMED` while any cult tower stands within
  `claim_radius_hexes = 2`; `CLAIMED -> UNCLAIMED` the moment that tower is sold, destroyed or
  lost, so holding a site is a live commitment, re-evaluated on every tower placement/removal and
  at each wave start. `UNCLAIMED -> CAPTURED` after `capture_waves_required = 2` consecutive
  waves with an enemy within `capture_radius_hexes = 2`; a quiet wave bleeds progress back down.
  `CAPTURED -> CLAIMED` by building within claim radius again.
- **Effects are REGION AURAS:** a site affects only the ground within
  `aura_radius_hexes = 2` of itself, so holding a site means garrisoning the ground it sits on
  rather than collecting a run-wide buff. Kept equal to `claim_radius_hexes` deliberately — a
  wider aura swallows most of the buildable band (sites spawn within 2 hexes of the path) and
  makes "local" indistinguishable from "global". Queried per hex via
  `ObjectiveSystem.get_*_at(hex)` — `get_revealed_damage_bonus_at`, `get_jam_duration_mult_at`,
  `get_capture_speed_mult_at`, `get_capture_damage_taken_mult_at`.
- **Cult benefits while CLAIMED:** `ley_line` grants `+8%` additive Revealed damage;
  `converted_data_center` halves Rigged jam duration; `corruption_reservoir` raises the
  Corruption ceiling by `+25` **and is what unlocks drawing Rites** (see §5).
- **Corporate penalty while CAPTURED:** the site becomes a dangerous corridor — enemies *inside
  its aura* gain `ley_line` `-15%` damage taken, `converted_data_center` `+20%` speed,
  `corruption_reservoir` `+15%` speed and `-10%` damage taken. This is the "leave it alone and it
  costs you" half of the design. Both captured penalties are evaluated as the enemy moves (speed
  per tick, damage-taken per hit) and are **never baked into spawn stats**, so per-unit stats stay
  snapshot at spawn time.
- **The one global effect:** `corruption_reservoir`'s Corruption ceiling. A Corruption cap is a
  meter-wide number and cannot be local; what keeps it honest is the claim rule — lose the tower
  holding the site and the headroom (and Rite access) goes with it.
- **Wiring:** `GameState` places sites in `POST_BOSS` after `commit_extension()`, calls
  `begin_wave`/`note_contested`/`end_wave` around each wave, and attaches the system to
  `TowerSystem.objective_system` via `_sync_objective_effects()` **before** anything spawns.
  `TowerSystem` prefers the attached system (true locality) and falls back to the wave-pushed
  aggregate when it is null, so tests can drive the system without one. Signals:
  `objective_placed(instance)`, `objective_state_changed(instance, old_state, new_state)`,
  `objectives_changed(objective_system)`.
- **Rendering:** `OverlayView._refresh_objective_overlays()` draws three ring layers
  (unclaimed/claimed/captured) from `VisualThemeData` objective colors, rebuilt only when
  `ObjectiveSystem.get_state_signature()` changes.

---

## 9. 3D World, Biomes, Audio, UI & Performance

- **Urban Center Biome & 3D Views (`res://scripts/world/`):**
- `TerrainView`, `BiomeData` (`res://data/biomes/urban_center.tres`), and `BiomeTileModels` render chunks via per-archetype `MultiMeshInstance3D` batches: skyscrapers on `BLOCKED` hexes, urban districts on `BUILDABLE` hexes, cleared street lots under placed towers, and recessed avenue road tiles on path hexes.
- Entering tower build mode dims urban building opacity (`0.45` alpha) and highlights valid/invalid build-zone hexes in `OverlayView`.
- `OverlayView` renders a distinct gold aura ring (`buff_range_ring_color`) for buff towers (`fever_shrine`, `chop_shop`) vs cyan (`range_ring_color`) for attack towers.
- **Objective site signals (three layers, deliberately redundant).** A ring bounds the site's aura hexes, a flat ground fill shows the ground the aura *reaches*, and a **billboarded icon** floats above the hex (at `_ICON_Y`, which is above `HexMath.TOWER_MAX_HEIGHT`, so a tower built on the site's own hex cannot cover its own marker). The icon is **per-KIND** — one MultiMesh layer per site kind, because the silhouette is what tells the three kinds apart — tinted per state from the same `objective_*_color` theme values the ring and fill use. Glyphs come from `PlaceholderIcons.objective_icon()`: white shapes with a **baked dark halo**, so they read over both the pale ground of a zoomed-out view and the dark rooftops of a close-up. Unclaimed sites get a **dimmer** fill but never *no* fill — the unclaimed site is the one a player most needs to FIND. Where auras overlap, the strongest signal wins per hex (captured > claimed > unclaimed), because the hostile state is the one needing action. The `F3` panel prints a `Sites:` state breakdown, so "no site exists" is distinguishable from "a site that reads poorly".
- `TowerView` meshes are strictly under `HexMath.TOWER_MAX_HEIGHT = 1.5`.
- `EnemyMoverView` & `EnemyVisualPool` pool enemy nodes, apply a depth-disabled occlusion silhouette pass, aim projectiles at elevated Air unit models (`get_aim_world_position()`), and offload visual interpolation/label formatting to `WorkerThreadPool` when `>= 32` enemies are active.
- **Audio System (`res://scripts/audio/`):**
- Pure-logic `AudioCueSystem` + `AudioBalanceData` (`res://data/audio_balance.tres`) + `AudioSettings` (`user://audio_settings.cfg`) + `SoundManager` node pool.
- Enforces per-cue `min_interval` cooldowns, per-cue `max_voices`, global voice cap (`max_global_sfx_voices = 8`), high-speed/density interval scaling at `2x/3x` speed, and polyphony volume ducking.
- **UI & Controls (`res://scripts/ui/`):**
- `MainMenu` (`res://scenes/main_menu.tscn`) -> `Main` (`res://scenes/main.tscn`).
- `SettingsMenu` & `DisplaySettings` (`user://display_settings.cfg`): machine-bounded resolution & aspect-ratio filtering, PC window modes (hidden on Steam Deck), 5-second confirmation with auto-revert, and `0..100` Background/FX audio sliders.
- `BuildPalette`: Toggle with `B`, inspect with `1–9` or single click, confirm build with `Enter`, a second click, or double-click.
- `TowerPanel`: **Selling takes two presses** — the first arms the button (`_sell_armed_for`, keyed by `tower_id`, so changing selection disarms), the second sells. Confirming a Rite tower's sale states that the Rite is **not** refunded. Selling is irreversible and Rites are never returned, so a single misclick used to destroy both the tower and a drawn Rite.
- `IntelPanel` & `TelegraphLayer`: Pre-wave Intel preview; post-boss "BOSS SLAIN / Next Faction" banners automatically clear when the next wave starts.
- `CameraRig`: Orthographic (`size 7..48`, default `18`), WASD/arrow pan, middle-mouse drag pan, single-finger touchscreen drag pan, mouse-wheel & two-finger pinch zoom, `Home` (focus base), `End` (focus spawn/preview).
- **HUD window consistency (rules — keep them):**
- **One fixed frame per window.** A HUD window has a single size for its whole life, set by constants (`TowerPanel.PANEL_WIDTH` x `PANEL_HEIGHT`), never derived from its content, so it cannot resize as the player interacts with it. `TowerPanel` is the same size for all 11 towers and every state (build preview, T1, T2 fork, T3, T4).
- **Variable content scrolls vertically, never horizontally.** Anything whose height can grow (readouts, the upgrade ladder, site auras) lives in a `ScrollContainer` inside the fixed frame with `horizontal_scroll_mode = SCROLL_MODE_DISABLED`; overflow scrolls up/down instead of growing or clipping the window. A HUD window never shows a horizontal scrollbar — wide content is wrapped, not scrolled sideways.
- **Text never sets width.** A `Button` does not wrap and its minimum width is the full width of its longest line, so buttons carry only short, pre-broken labels and never a description; all variable text is a wrapping `Label`. A side-by-side pair (the T3 fork) gives each column half the inner width and its buttons must fit that half. Enforced by `test_build_menu_ui.gd::test_04`.
- **HUD scale is bounded.** The whole UI is authored at `DisplaySettings.UI_BASE_SIZE` (1152x648) and scaled by `clampf(window_height / 648, UI_MIN_SCALE, UI_MAX_SCALE)` via the `UiScale` autoload; never set `content_scale_size` from the chosen resolution.

---

## 10. Playtest Telemetry, Command Logs & StrategyTracker Director API

Full reference and future `WaveDirector` integration recipes live in `res://PLAYTEST_TELEMETRY_AND_DIRECTOR_API.md`.

- **Cloud Telemetry (`ZivaAnalytics` Autoload — `res://addons/ziva_analytics/ziva_analytics.gd`):**
- Coordinated by `PlaytestRecorder` (`res://scripts/telemetry/playtest_recorder.gd`, attached at `GameState.playtest_recorder`).
- Emits `run_started`, `wave_completed`, `boss_outcome`, `reckoning_triggered`, and `run_ended` (followed by `ZivaAnalytics.flush()`) during live interactive runs; automatically suppressed during headless tests, bot simulations, and `replay_command_log()`.
- Optional Playtester Handle on `MainMenu` is persisted in `user://playtest_profile.cfg` and passed to `ZivaAnalytics.identify()`.
- Any F3 `DebugPanel` cheat or `--start-*` launch override marks `GameState.debug_tainted = true` and logs a `debug_action` event so debug runs are distinguishable from organic playtest data.
- **Persistent Command Logs & Deterministic JSON Replay (`user://playtest_logs/*.json`):**
- `GameState._log_command()` records `tick`, `wave`, `state`, and spatial placement context (`is_overlap_hex`, `min_path_dist`, `path_progress_ratio`).
- `PlaytestRecorder` auto-saves full run JSON files to `user://playtest_logs/` on Game Over, run restart, Quit to Main Menu, and window close, and provides **"Copy Run Log"** buttons on `GameOverScreen`, `InGameMenu`, and `DebugPanel`.
- `GameState.export_command_log_dict()` and `GameState.import_and_replay_json(json_str)` (or **"Replay Clip"** in `F3` `DebugPanel`) round-trip hex coordinates (`{"q": x, "r": y}`) through JSON with 100% deterministic fidelity via `replay_command_log()`.
- **Strategy & Director-Invalidation Detection (`StrategyTracker` — `res://scripts/telemetry/strategy_tracker.gd`):**
- Pure-logic (`RefCounted`) analyzer owned by `GameState.strategy_tracker`; emits `GameState.wave_strategy_evaluated(wave_number, digest)` at the end of every wave.
- Detects 9 strategy/exploit flags: `spawn_camp_invalidation`, `unscouted_backline_hiding`, `intel_retcon_churn`, `counter_pick_neutralized`, `t2_unbranched_spam`, `cap_dodging`, `monoculture_spam`, `rite_brinkmanship`, and `cc_killbox_stall`.
- Exposes `StrategyTracker.get_director_feedback_profile(tower_system, window_waves)` returning rolling `[0.0..1.0]` strategy scores, `extended_branch_mix`, `potential_tag_coverage` (including unscouted towers), and `counter_unit_efficacy` ready to feed into `WaveDirector.generate_wave()`.

---

## 11. Engineering Conventions & Project Layout

- **Data-Driven Resources:** All game data lives in `.tres` files under `res://data/` (`data/towers/`, `data/upgrades/`, `data/units/`, `data/units/bosses/`, `data/biomes/`, and `data/*_balance.tres`). Never scatter balance numbers through logic.
- **Pure Logic vs. Nodes:** Core systems (`HexGrid`, `HexMath`, `HexSpatialIndex`, `PathGenerator`, `TowerSystem`, `TowerInstance`, `CombatUnit`, `UnitLeveling`, `WaveDirector`, `WaveRoster`, `CoverageTracker`, `StrategyTracker`, `AudioCueSystem`, `DisplaySettings`, `AudioSettings`) extend `RefCounted` so they can be tested headlessly without a scene tree.
- **Deterministic RNG:** All randomness uses seeded `RandomNumberGenerator` instances passed into systems. Never call global `randf()` or `randi()`.
- **Typing:** Always use `class_name` and explicit static type annotations on every `var`, parameter, return type, and signal.
- **Cross-System Signals (`GameState` & `TowerSystem`):**
- `wave_started(wave_number)`
- `wave_ended(wave_number)`
- `wave_strategy_evaluated(wave_number, digest)`
- `command_recorded(entry)`
- `enemy_spawned(unit)`
- `enemy_died(unit_id)`
- `enemy_leaked(unit_id, leak_cost)`
- `boss_killed(wave_number)`
- `boss_leaked(wave_number)`
- `path_extended(growth_result)`
- `tower_damaged_enemy(tower_id, tower_type, unit_id, unit_tags, amount, damage_tag)`
- `event_triggered(event_id, display_name, category, banner_text, banner_color)`

### Directory Structure

```text
res://
├── AGENTS.md
├── TOWERS.md            # Register: all 11 towers + 77 upgrade nodes (ids, costs, effects, node index)
├── UNITS.md             # Register: all 16 units + 5 bosses + Rogue Entity + ability reference
├── PLAYTEST_TELEMETRY_AND_DIRECTOR_API.md
├── data/
│   ├── audio_balance.tres
│   ├── director_balance.tres
│   ├── path_balance.tres
│   ├── tower_balance.tres
│   ├── unit_balance.tres
│   ├── visual_theme.tres
│   ├── biomes/         # BiomeData resources (urban_center.tres)
│   ├── towers/         # 11 TowerData resources
│   ├── upgrades/       # 77 UpgradeNode resources
│   └── units/          # 16 regular UnitData + rogue_entity.tres + bosses/ (5 Boss UnitData)
├── scenes/
│   ├── main_menu.tscn              # Main entry scene (MainMenu + SettingsMenu)
│   ├── main.tscn                   # Primary gameplay scene (MainSceneController)
│   └── benchmark_300_enemies.tscn  # 3D performance benchmark scene
├── scripts/
│   ├── audio/          # AudioBalanceData, AudioCueSystem, AudioSettings, SoundManager
│   ├── core/           # SimClock, GameState, HexMath, HexSpatialIndex, DisplaySettings, VisualThemeData
│   ├── director/       # WaveDirector, WaveRoster, CoverageTracker, DirectorBalanceData, DirectorSimulator
│   ├── events/         # RunEventSystem, EventData, EventBalanceData, EventLibrary
│   ├── objectives/     # ObjectiveSystem, ObjectiveInstance, ObjectiveData, ObjectiveBalanceData, ObjectiveLibrary
│   ├── path/           # HexGrid, PathGenerator, PathConstants, PathBalanceData
│   ├── telemetry/      # StrategyTracker, PlaytestRecorder
│   ├── towers/         # TowerData, UpgradeNode, TowerInstance, CombatUnit, TowerSystem, TowerLibrary, TowerBehaviorRegistry, TowerBalanceData
│   ├── ui/             # MainMenu, InGameMenu, SettingsMenu, TopBar, BuildPalette, TowerPanel, IntelPanel, WaveControls, BossBar, TelegraphLayer, GameOverScreen, DebugPanel, PlaceholderIcons
│   ├── units/          # UnitData, AbilityData, UnitAbilityRegistry, UnitLeveling, UnitLibrary, UnitBalanceData, LossReport
│   └── world/          # MainSceneController, TerrainView, PathView, OverlayView, TowerFactory, TowerView, EnemyVisualPool, EnemyMoverView, CombatEffectsView, CameraRig, BiomeData, BiomeLibrary, BiomeTileModels, PlaceholderModels, Benchmark300Enemies
└── tests/              # Headless & scene test suites (run via run_tests on res://tests)
```
