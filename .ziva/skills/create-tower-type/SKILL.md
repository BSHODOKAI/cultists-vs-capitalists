---
name: create-tower-type
description: Use when adding a new cultist tower, modifying an existing tower, or authoring tower upgrades in cultists-vs-capitalists. Covers theme and role uniqueness rules, TowerData and 5-node UpgradeNode resources, TowerLibrary and TowerBehaviorRegistry wiring, 3D meshes under 1.5 height, 2D procedural icons, audio cues, and non-regression testing.
---

# Adding & Maintaining Towers

Every tower in **Cultists vs. Capitalists** is a data-driven `TowerData` resource (`res://data/towers/<tower_id>.tres`) paired with **5 `UpgradeNode` resources** (`res://data/upgrades/<upgrade_id>.tres`), a 3D procedural model (`PlaceholderModels`), a 2D procedural icon (`PlaceholderIcons`), and audio cue routing (`AudioCueSystem` + `AudioBalanceData`).

---

## 1. Design, Theme & Uniqueness Rules

Before creating or changing a tower, verify it satisfies these design rules:

1. **Theme Fit (Lovecraftian Street Cult + Salvaged Urban Junk):**
   - Every tower is built by a scrappy occult street cult repurposing urban infrastructure and salvaged hardware (nail guns, storm drains, highway billboards, incense burners, subway grates, server racks, collection plates).
   - **T1 -> T2 (Shared):** Enhances the core contraption or ritual.
   - **Revealed Branch (T3 -> T4, paid in Offerings, adds +4 / +8 Global Corruption):** Leans into eldritch entities, forbidden liturgy, void anomalies, and blood rites.
   - **Rigged Branch (T3 -> T4, paid in Scrap, sets 10% / 25% Tower Jank):** Leans into overvolted batteries, jury-rigged propane tanks, hacked drones, industrial solvents, and union picket hardware.
2. **Role Uniqueness (No Two Towers Feel Identical):**
   - Never add a tower that merely duplicates an existing tower's targeting cadence + damage tag + role with slightly different numbers.
   - Every tower must occupy a distinct mechanical niche (targeting mode, range band, damage tag, status/synergy hook, or placement constraint).

### Current 10-Tower Inventory Reference

| # | `id` | Build Cost | Range | `targeting_mode` | Primary Role & Unique Hook |
|---|---|---|---|---|---|
| 1 | `hexed_nail_gun` | 30 Offerings | 3 | `SINGLE_TARGET (0)` | Fast single-target Kinetic (Ground+Air); armor-piercing or burst anti-armor |
| 2 | `chanting_choir` | 40 Offerings | 2 | `CHANNELED_CHOIR (2)` | 3-member continuous Psychic channel (Ground) + **continuous Cloak detector**; fear/flee or sonic stun |
| 3 | `gutter_ritual_circle` | 50 Offerings | 3 | `PULSE_AOE (3)` | Periodic Corrosive ring pulse (Ground) + **3s Cloak reveal** + **+25% vs Entangled**; Void puddles/execute or knockback/chain-explode |
| 4 | `tentacle_storm_drain` | 35 Offerings | 2 | `CONTROL_DRAIN (4)` | Continuous slow aura + periodic root (Ground) + **applies Entangled**; drag/Leviathan sweep or Electric flood |
| 5 | `watcher_in_the_billboard` | 70 **Scrap** | 6 | `HIGHEST_HP (1)` | Long-range Void sniper on highest-HP (Ground+Air) + **continuous Cloak detector**; vulnerability mark/%HP or crits/confusion |
| 6 | `rust_censer` | 40 **Scrap** | 2 | `DOT_CENSER (5)` | Corrosive DoT stacks + **Armor Shred** applier (Ground); plague spread/Cybernetic shred or high-cap solvent upkeep |
| 7 | `fever_shrine` | 55 Offerings | 2 (aura) | `BUFF_SHRINE (6)` | Non-attacking friendly tower fire-rate aura; Offerings upkeep/burst vigil or enemy-disable immunity/variety network |
| 8 | `the_congregation` | 45 Offerings | 1 (adj) | `SUMMON_CONGREGATION (7)` | **Must be placed at hex distance 1 from path**; summons 2 melee blockers onto path hexes; death explosion/ghosts or tanky slow |
| 9 | `tithe_box` | 35 Offerings | 0 | `ECONOMY_TITHE (8)` | Non-attacking economy generator (+Offerings/5s); Corruption-for-Offerings/kill bonus or Scrap collector/Jank-reducing Chop Shop |
| 10 | `substation_effigy` | 50 **Scrap** | 3 | `CHAIN_ARC (9)` | Multi-target Electric chain lightning (Ground+Air, prioritizes Air, 3 targets); 100% bounce retention/Ball Lightning storm or +2 bounces/5th-shot overload stun |

---

## 2. Architecture Touchpoints

| Layer | File | Responsibility |
|---|---|---|
| **Tower Resource** | `res://scripts/towers/tower_data.gd` | `TowerData` class, `TargetingMode` enum, stats, traits, and 5 `UpgradeNode` slots |
| **Upgrade Resource** | `res://scripts/towers/upgrade_node.gd` | `UpgradeNode` class (`Branch`, `Currency`, stat modifiers, `behaviors`, `behavior_params`) |
| **Balance Constants** | `res://scripts/towers/tower_balance_data.gd` | `res://data/tower_balance.tres` — upgrade cost multipliers (`0.6x / 1.0x / 1.8x`), Corruption (`+4 / +8`), Jank (`10% / 25%`) |
| **Catalog Loader** | `res://scripts/towers/tower_library.gd` | `TOWER_PATHS` and `UPGRADE_PATHS` arrays |
| **Behavior Registry** | `res://scripts/towers/tower_behavior_registry.gd` | Registers base tower ID and all 5 upgrade behavior IDs |
| **Runtime Instance** | `res://scripts/towers/tower_instance.gd` | Per-placed-tower state, derived stat helpers, disable/jam/conversion flags |
| **Combat & Placement** | `res://scripts/towers/tower_system.gd` | Placement validation, `_step_tower()`, upgrade unlocking, synergies, `_does_tower_cover_unit_tag()` |
| **3D Models (GFX)** | `res://scripts/world/placeholder_models.gd` | `get_tower_signature_color()`, `_build_tower_meshes()` (`< 1.5` height), `get_projectile_mesh()` |
| **3D Scene View** | `res://scripts/world/tower_view.gd` | `TOWER_LETTERS` badge map, tier pips, Revealed/Rigged emissive materials |
| **3D Combat VFX** | `res://scripts/world/combat_effects_view.gd` & `overlay_view.gd` | Projectile flight/arcs, beams, puddles, and range ring color (gold buff vs cyan attack) |
| **2D UI Icons** | `res://scripts/ui/placeholder_icons.gd` | `get_tower_icon(tower_id, size)` procedural `ImageTexture` |
| **Audio Cues** | `res://scripts/audio/audio_cue_system.gd` & `audio_balance_data.gd` | `resolve_projectile_fire_cue()`, `resolve_tower_cooldown_cue()`, and `res://data/audio_balance.tres` |

---

## 3. Step-by-Step Guide to Adding a New Tower

### Step 1: Author the 5 `UpgradeNode` Resources (`res://data/upgrades/*.tres`)

Every tower **must** have exactly 5 upgrade nodes following the canonical tree and cost/side-effect formulas from `TowerBalanceData`:

| Slot | `tier` | `branch` | `currency` | `cost` Formula | `prerequisite_id` | `corruption_delta` | `jank_set` |
|---|---|---|---|---|---|---|---|
| `t2_upgrade` | `2` | `0` (`SHARED`) | Base tower currency (`0` or `1`) | `roundi(base_cost * 0.6)` | `""` | `0` | `0` |
| `revealed_t3_upgrade` | `3` | `1` (`REVEALED`) | `0` (`OFFERINGS`) | `roundi(base_cost * 1.0)` | `<t2_id>` | `4` | `0` |
| `revealed_t4_upgrade` | `4` | `1` (`REVEALED`) | `0` (`OFFERINGS`) | `roundi(base_cost * 1.8)` | `<rev_t3_id>` | `8` | `0` |
| `rigged_t3_upgrade` | `3` | `2` (`RIGGED`) | `1` (`SCRAP`) | `roundi(base_cost * 1.0)` | `<t2_id>` | `0` | `10` |
| `rigged_t4_upgrade` | `4` | `2` (`RIGGED`) | `1` (`SCRAP`) | `roundi(base_cost * 1.8)` | `<rig_t3_id>` | `0` | `25` |

Each `.tres` file uses `script = ExtResource("1_up")` (`res://scripts/towers/upgrade_node.gd`), sets `tower_id = "<tower_id>"`, lists its own ID in `behaviors = Array[String](["<upgrade_id>"])`, and puts custom numbers in `behavior_params` (never hardcode magic numbers in `TowerSystem`).

### Step 2: Author the `TowerData` Resource (`res://data/towers/<tower_id>.tres`)

Create `res://data/towers/<tower_id>.tres` with `script_class="TowerData"`:
- Required core fields:
  - `id`: unique `snake_case` string matching filename
  - `display_name`: human-readable title
  - `description`: concise 1-sentence summary of attack/role
  - `cost`: integer base build cost
  - `build_currency`: `0` (`OFFERINGS`) or `1` (`SCRAP`)
  - `range_hexes`: integer axial hex range (`0` for pure economy, `1..6` for combat/aura; use `aura_radius_hexes` if `range_hexes == 0` on an aura tower)
  - `damage`, `damage_tag` (`0=KINETIC, 1=CORROSIVE, 2=PSYCHIC, 3=VOID, 4=ELECTRIC`), `fire_rate`
  - `target_tags`: `Array[int]([0])` for Ground, `Array[int]([0, 1])` for Ground+Air, or `Array[int]([])` for non-attacking towers
  - `targeting_mode`: `TowerData.TargetingMode` enum value
  - `detects_cloaked`, `pulse_reveal_duration`, `starting_members`, `max_targets`
  - `base_behaviors = Array[String](["<tower_id>"])`
  - `t2_upgrade`, `revealed_t3_upgrade`, `revealed_t4_upgrade`, `rigged_t3_upgrade`, `rigged_t4_upgrade`

### Step 3: Register in `TowerBehaviorRegistry` and `TowerLibrary`

1. In `res://scripts/towers/tower_behavior_registry.gd` (`_ensure_initialized()`):
   - Register the base behavior: `_register("<tower_id>", {"type": "base_tower", "tower_id": "<tower_id>"})`
   - Register all 5 upgrade behaviors with `"type": "upgrade"`, `"tower_id": "<tower_id>"`, and `"tier": 2/3/4`.
2. In `res://scripts/towers/tower_library.gd`:
   - Append `"res://data/towers/<tower_id>.tres"` to `TOWER_PATHS`.
   - Append the 5 `"res://data/upgrades/<upgrade_id>.tres"` paths to `UPGRADE_PATHS`.

### Step 4: Wire Combat Logic in `TowerSystem` (Without Breaking Existing Towers)

In `res://scripts/towers/tower_system.gd`:
- **Reuse or add `TargetingMode`:** If the tower uses a new combat pattern, add an enum entry to `TowerData.TargetingMode` and a branch in `TowerSystem._step_tower(tower, delta, rng)`.
- **Determinism:** Always use the passed-in `rng: RandomNumberGenerator` (or `_sim_rng`), never global `randf()` or `randi()`.
- **Damage Routing:** Route all tower damage through `calculate_hit_damage(tower, target, base_dmg, damage_tag, ...)` and `deal_damage_from_tower(tower, target, dmg, damage_tag)` so Corruption bonuses, Stars Are Right (`+20%`), Variety Bonus (`+3%` per distinct neighbor type), Armor Shred, Entangled, resistances, and `tower_damaged_enemy` signals work automatically.
- **Crowd Control:** Route hard CC through `CombatUnit` methods (`apply_flee`, `apply_confusion`, `apply_root`, `apply_stun`, `apply_displacement`) so Boss immunities and 4-category CC diminishing returns (`100% -> 50% -> 25% -> immune`) are enforced.
- **LossReport & Coverage:** Update `_does_tower_cover_unit_tag(tower, tag_int)` in `TowerSystem` so `LossReport` knows which `UnitTag` threats the new tower or its upgrades counter.
- **Stat Caching:** If an upgrade modifies range, aura buffs, or variety bonuses dynamically, ensure `TowerInstance.invalidate_stat_cache()` or `TowerInstance` derived-stat getters (`get_effective_range_hexes()`, etc.) account for it without breaking existing towers.

### Step 5: Add 3D Graphics (GFX) in `PlaceholderModels`, `TowerView` & Views

Every tower requires a distinct 3D model, a badge letter, and combat VFX:

1. **Signature Color (`PlaceholderModels.get_tower_signature_color`):**
   - Add a `match tower_id:` branch in `res://scripts/world/placeholder_models.gd` returning a distinct `Color`.
2. **3D Mesh (`PlaceholderModels._build_tower_meshes`):**
   - Add a `match tower_id:` branch building `base` (structural dark stone / iron / wood parts) and `accent` (glowing coils, crystals, lenses, flames that tint purple for `REVEALED` and orange for `RIGGED`).
   - **Height Constraint:** All geometry **must stay strictly below `HexMath.TOWER_MAX_HEIGHT = 1.5`** world units (keep highest vertex `<= 1.45`) so towers never clip overhead Air units (`AIR_ALTITUDE = 1.8`) or status labels (`Y = 1.24..1.44`).
   - **Single Draw Call:** Assemble all primitives via `MeshAccumulator` (`add_box`, `add_cyl`, `add_cone`, `add_sphere`, `add_capsule`, `add_prism`, `add_torus`) so `base` and `accent` each compile into a single vertex-colored `ArrayMesh`.
3. **Projectile Mesh & Effect Visual Rule (`PlaceholderModels` + `CombatEffectsView` + `MainSceneController`):**
   - **Projectiles Get Graphical Projectiles Only (No Tracer Lines):** If the tower fires visible projectiles, add a `match tower_type:` case in `PlaceholderModels.get_projectile_mesh()` oriented along `-Z`. Never attach a line/beam (`spawn_beam`) along a projectile's flight path—`CombatEffectsView.spawn_projectile()` must only fly the 3D projectile mesh and trigger `spawn_impact_burst()` on arrival.
   - **No Enemy→Tower Lines Either:** Mob abilities that target towers (Hacker `TowerConvert`, Boss `LeveragedBuyout`) must not draw a line from the mob to the tower. Show the effect on the affected tower hex instead (telegraph reticle + the tower's own `HACKING`/`CONVERTED` status).
   - **Instant Multi-Target Beams Use a Following Chain Polyline:** For a chain/beam attack that links several units in one instant discharge (e.g. `substation_effigy` chain lightning), do not fly one projectile per hop. Accumulate the hit unit ids + hit-time positions per tower per frame and call `CombatEffectsView.spawn_following_chain_lightning(providers, duration, thickness, initial_points)` once, passing a `Callable` per anchor (tower apex first, then each enemy) that returns its live world position (or null once gone). The effect re-resolves anchors and rebuilds a smooth continuous 6-sided tube every frame (`_process`) so the arc stays glued to the units as they travel, keeps a stable crackle shape (no flicker/disconnects), and never scales past `MAX_ACTIVE_CHAINS`. A provider that returns null keeps the anchor frozen at its last live position (`initial_points` seeds that for anchors already dead on the first frame) so a mob that dies mid-arc leaves the bolt lingering where it died instead of snapping to the world origin. Keyframe it blue → white glow → fade and keep it on screen for under 2 seconds.
   - **Cooldowns, AoE Pulses & Secondary Effects Appear on the Mob/Hex (Not Shot from the Tower):** Non-projectile attacks, ground pulses, drains, melee blockers, and cooldown effects must never spawn projectile lines from the tower. Instead, display an impact burst (`spawn_impact_burst`) and status badge (`EnemyMoverView` status label: `SLOW`, `ROOT`, `STUN`, `FEAR`, `FLEE`, `SHRED`, `MARK`, `DOT`, `ENTANGLED`, `WET`) on the affected mob, or a hex ring/puddle (`spawn_telegraph_reticle` / `sync_puddles`) on the affected hex.
4. **Badge Letter (`TowerView.TOWER_LETTERS`):**
   - Add `"<tower_id>": "<Letter>"` to `TOWER_LETTERS` in `res://scripts/world/tower_view.gd`.
5. **Range Ring Color (`OverlayView`):**
   - Friendly buff/support towers (`fever_shrine`, `chop_shop`, etc.) use `theme_data.buff_range_ring_color` (gold); offensive towers use `theme_data.range_ring_color` (cyan). Check `OverlayView` if adding a new buff-only tower.

### Step 6: Add 2D Icon in `PlaceholderIcons`

1. Open `res://scripts/ui/placeholder_icons.gd` and add a `match tower_id:` branch in `get_tower_icon(tower_id: String, size: int = 40) -> ImageTexture`.
2. Start with `_draw_frame(img, accent_color, bg)` and draw a recognizable silhouette using `_draw_rect`, `_draw_circle`, `_draw_ring`, `_draw_line`, and `_draw_triangle`, scaling all coordinates by `f = float(size) / 40.0`.
3. Verify `BuildPalette` (`res://scripts/ui/build_palette.gd`) displays the new tower cleanly in its grid and inspection drawer.

### Step 7: Wire Sounds in `AudioBalanceData` & `AudioCueSystem`

Every tower needs audio feedback for construction, upgrading, attacking, and cooldown abilities:

1. **Construction, Upgrade, Sell & Maintenance:** Handled automatically via `GameState` signals (`CUE_TOWER_CONSTRUCT`, `CUE_TOWER_UPGRADE`, `CUE_TOWER_SOLD`, `CUE_TOWER_MAINTAINED`).
2. **Projectile Fire Sound (`AudioCueSystem.resolve_projectile_fire_cue`):**
   - In `res://scripts/audio/audio_cue_system.gd`, map `tower_type` in `resolve_projectile_fire_cue(tower_type)` to an existing or new `CUE_PROJECTILE_FIRE_*` constant.
3. **Cooldown / Pulse / Summon Ability Sound (`AudioCueSystem.resolve_tower_cooldown_cue`):**
   - When the tower triggers a periodic pulse, root, summon, or capstone burst in `TowerSystem`, emit `tower_cooldown_used.emit(tower.tower_id, tower.get_type_id(), "<ability_id>", tower.hex)`.
   - Map `<ability_id>` and `<tower_id>` in `AudioCueSystem.resolve_tower_cooldown_cue(tower_type, ability_id)`.
4. **New Cue Definitions (`AudioBalanceData`):**
   - If adding a new cue constant to `res://scripts/audio/audio_balance_data.gd`, add its default entry in `build_default_cues()` **and** add it to `res://data/audio_balance.tres` with a valid `.wav` path, `volume_db`, `min_interval`, `max_voices`, `pitch_min`, `pitch_max`, and `active_duration`.

---

## 4. Verification & Non-Regression Checklist

Whenever you add or modify a tower, run the headless test suites via `run_tests` to confirm nothing broke:

1. **Update Roster Expectations (if tower count changed):**
   - Update `EXPECTED_TOWERS` and catalog count assertions in `res://tests/test_tower_system.gd` and `res://tests/test_build_menu_ui.gd`.
2. **Run Core Test Suites:**
   - `run_tests` on `res://tests/test_tower_system.gd` (validates all `.tres` references, upgrade costs/currencies, Corruption/Jank math, branch locking, targeting, and deterministic combat sim for every tower).
   - `run_tests` on `res://tests/test_build_menu_ui.gd` (validates icons, meshes, projectile visuals, and `BuildPalette` UI).
   - `run_tests` on `res://tests/test_audio_system.gd` (validates all audio cues and streams exist and rate-limit properly).
   - `run_tests` on `res://tests/test_integration.gd` (validates full placement, economy, replay determinism, and wave loop).
