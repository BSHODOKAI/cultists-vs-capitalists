# UNITS — Enemy Unit & Boss Register

> **This file is the human-readable accounting of every enemy in the game.** It exists so a designer
> (or an agent) can see the whole corporate roster — ids, factions, costs, base HP, speed, tags,
> resistances, economy values, and abilities — without opening 22 `.tres` files.
>
> The **source of truth is the data**, not this document: `res://data/units/*.tres` (16 regular +
> `rogue_entity`) and `res://data/units/bosses/*.tres` (5 bosses), loaded via
> [`UnitLibrary`](scripts/units/unit_library.gd). For *why* they work the way they do see
> [`AGENTS.md`](AGENTS.md) §6; for *how to build one* see the
> [`create-enemy-type`](.ziva/skills/create-enemy-type/SKILL.md) skill; for tone see
> [`DESIGN_BIBLE.md`](DESIGN_BIBLE.md).
>
> **Keep this file in sync.** Any change to a `UnitData`/`AbilityData` resource (a new unit or boss, a
> stat retune, a new ability) MUST be reflected here in the same change. The `create-enemy-type` skill
> makes updating this register a required step.
>
> All values below are **base** values (level 0 / boss tier 0). Spawn-time scaling is applied at runtime
> by [`UnitLeveling`](scripts/units/unit_leveling.gd) — see §1.2.

---

## 1. Reference

### 1.1 Factions & roster counts

| Faction `id` | Name | Units | Boss |
|---|---|---|---|
| `swarm_syndicate` | Swarm Syndicate | 4 | `the_disruptor` |
| `iron_board` | Iron Board | 4 | `the_chairman` |
| `hostile_takeover` | Hostile Takeover Inc. | 4 | `the_raider` |
| `skyline_logistics` | Skyline Logistics | 4 | `the_prime_dispatcher` |
| `coalition` | Coalition (mixed) | — *(fields all 16)* | `the_holding_company` |

**Totals:** **16 regular units** (4 per faction) · **5 bosses** · plus **1** special `rogue_entity`
(the player's own Corruption-spawned enemy, Coalition-factioned, not part of the director's roster).

### 1.2 Spawn-time scaling (summary)

Base numbers are snapshotted **at spawn** and fixed for the unit's lifetime. Full formulas in
[`AGENTS.md`](AGENTS.md) §6; tunables in `res://data/unit_balance.tres`.

- **Per-unit-type kill leveling:** `level = floor(pow(kills_of_this_unit_type / 3.0, 0.72))`; regular
  units also have an interval floor of `(interval_index − 1) × 2`. Bosses do not accumulate kill levels.
- **HP:** `health_mult = (1.0 + 0.22 × level) × pow(1.06, max(0, level − 3))`.
- **Speed:** `speed_mult = min(1.0 + 0.025 × level, 1.40)`.
- **Boss HP** is anchored to the **wave**: `tier = max(0, wave / 10 − 1)`,
  `HP = base_hp × (1.0 + 0.55 × tier + 0.15 × tier²)`. Bosses arrive every **5** waves from wave **10**.

### 1.3 Tag & resistance conventions

- **Unit tags** (`PathConstants.UnitTag`): `GROUND, AIR, FAST, FRAGILE, ARMORED, SHIELDED, CLOAKED,
  SWARM, HEALER, SPAWNER, SUPPORT, AURA, HACKER, ELECTRIC, ANTI_MAGIC, CYBERNETIC, TANK, RANGED, BOSS`.
- **Damage tags** (`PathConstants.DamageTag`): `KINETIC, CORROSIVE, PSYCHIC, VOID, ELECTRIC`.
- **Resistances** map a damage tag → multiplier: `0.75` = takes 25% less, `1.3` = takes 30% more. A
  missing tag means `×1.0`.
- **Scrap** drops on death (default `roundi(cost × 0.5)`). **Lives** (leak cost) lost if the unit
  reaches the base — regular units are `1`; bosses and the Rogue Entity are higher.
- **Air units** follow the path at `AIR_ALTITUDE = 1.8`, ignore ground blockers/ground-only towers,
  and are targeted only by air-capable towers.

---

## 2. Swarm Syndicate (`swarm_syndicate`)

Fast, cheap, expendable, and built around **swarming and stealing**. Low HP, high speed, spawners that
multiply the wave.

| Unit (`id`) | Cost | HP | Speed | Tags | Resistances | Scrap | Lives | Abilities |
|---|---|---|---|---|---|---|---|---|
| Gig Runner (`gig_runner`) | 2 | 30 | 1.6 | Ground, Fast, Swarm | — | 1 | 1 | LeakSteal |
| Scooter Courier (`scooter_courier`) | 4 | 55 | 2.0 | Ground, Fast | — | 2 | 1 | SlowResist, CourierPack |
| Hype Influencer (`hype_influencer`) | 6 | 70 | 1.0 | Ground, Support, Aura, Fragile | — | 3 | 1 | SpeedAura, DeathBurst |
| Gig Van (`gig_van`) | 9 | 220 | 0.9 | Ground, Spawner | — | 5 | 1 | SpawnOnTimer |

**Signature abilities**

- **Gig Runner — LeakSteal:** on leaking, steals **5 Offerings** in addition to the life cost.
- **Scooter Courier — SlowResist:** resists slows by **50%**. **CourierPack:** grants **+25% speed** to
  couriers within **2 hex**.
- **Hype Influencer — SpeedAura:** grants **+20% speed** to allies within **2 hex**. **DeathBurst:** on
  death, grants **+40% speed** to allies within **2 hex** for **3s**.
- **Gig Van — SpawnOnTimer:** spawns a **`gig_runner` every 3s** (cap **4** active); releases all
  remaining on death.

---

## 3. Iron Board (`iron_board`)

Slow, armoured, high-HP bruisers. Damage reduction and shields; the board that tanks your front line
and hits towers back with suppression.

| Unit (`id`) | Cost | HP | Speed | Tags | Resistances | Scrap | Lives | Abilities |
|---|---|---|---|---|---|---|---|---|
| Security Contractor (`security_contractor`) | 4 | 100 | 0.8 | Ground, Armored | Kinetic ×0.75 | 2 | 1 | — |
| Riot Shield Unit (`riot_shield_unit`) | 6 | 140 | 0.7 | Ground, Shielded | — | 3 | 1 | ShieldRegen |
| Siege Walker (`siege_walker`) | 10 | 260 | 0.6 | Ground, Ranged, Armored | Kinetic ×0.8 | 5 | 1 | RangedSuppress, Breakthrough |
| Sponsor Mech (`sponsor_mech`) | 15 | 600 | 0.5 | Ground, Tank, Cybernetic, Armored | Kinetic ×0.7, Corrosive ×1.3, Void ×1.2, Electric ×1.25 | **12** | 1 | Breakthrough |

**Signature abilities**

- **Riot Shield Unit — ShieldRegen:** a **120 HP** shield that regenerates **4s** after the last hit;
  **Void** and **Corrosive** damage bypass it straight to HP.
- **Siege Walker — RangedSuppress:** reduces towers' fire rate by **30%** within **3 hex**.
  **Breakthrough:** the mob can crush through blockers.
- **Sponsor Mech — Breakthrough:** same crush behavior; the tankiest regular unit and a big Scrap payout.

---

## 4. Hostile Takeover Inc. (`hostile_takeover`)

Disruption and sabotage. These units don't out-damage you — they **disable, cloak, convert, and suppress**
your towers.

| Unit (`id`) | Cost | HP | Speed | Tags | Resistances | Scrap | Lives | Abilities |
|---|---|---|---|---|---|---|---|---|
| Taser Skirmisher (`taser_skirmisher`) | 5 | 80 | 1.0 | Ground, Electric | Electric ×0.5 | 3 | 1 | TowerDisable |
| Ghost Contractor (`ghost_contractor`) | 7 | 90 | 1.1 | Ground, Cloaked | — | 4 | 1 | Cloak |
| Compliance Officer (`compliance_officer`) | 9 | 160 | 0.8 | Ground, Anti-Magic, Support | Psychic ×0.6 | 5 | 1 | AntiMagicAura |
| Acquisitions Rep (`acquisitions_rep`) | 12 | 140 | 0.7 | Ground, Hacker, Support | Electric ×0.7 | 6 | 1 | TowerConvert |

**Signature abilities**

- **Taser Skirmisher — TowerDisable:** disables the **nearest** tower every **6s** for **2s**.
- **Ghost Contractor — Cloak:** invisible until revealed by a continuous detector aura or a
  `gutter_ritual_circle` pulse (3s reveal).
- **Compliance Officer — AntiMagicAura:** within **2 hex**, negates the global Corruption damage bonus
  on towers.
- **Acquisitions Rep — TowerConvert:** every **15s** channels a **3s** beam onto the **highest-cost**
  tower within **3 hex**, converting it for **8s**, and grants a **+20% enemy speed** aura. Counterable
  by interrupting the channel, killing the rep, or cleansing the conversion for 50% of the tower's base
  cost.

---

## 5. Skyline Logistics (`skyline_logistics`)

The air faction. All units fly (ignoring ground blockers and ground-only towers) and it fields the only
healer and the air spawner.

| Unit (`id`) | Cost | HP | Speed | Tags | Resistances | Scrap | Lives | Abilities |
|---|---|---|---|---|---|---|---|---|
| Courier Drone (`courier_drone`) | 2 | 25 | 1.8 | Air, Fast, Fragile | Electric ×1.3 | 1 | 1 | — |
| Cargo Hauler (`cargo_hauler`) | 7 | 200 | 0.7 | Air, Armored | Kinetic ×0.8 | 4 | 1 | — |
| Medic Drone (`medic_drone`) | 8 | 90 | 1.0 | Air, Healer | — | 4 | 1 | Heal |
| Drone Carrier (`drone_carrier`) | 18 | 450 | 0.6 | Air, Tank, Spawner | Kinetic ×0.75, Electric ×1.3 | 9 | 1 | SpawnOnTimer |

**Signature abilities**

- **Medic Drone — Heal:** heals up to **3 targets** within **2 hex** for **15 HP/s** (cannot heal itself
  or other medics).
- **Drone Carrier — SpawnOnTimer:** spawns **2 `courier_drone`s every 4s** (cap **6** active).
- Air units pay for their mobility: they take **+30% Electric** (courier/carrier) and are only reachable
  by air-capable towers — which is why `dead_air_altar` and `substation_effigy` exist.

---

## 6. Bosses (`res://data/units/bosses/`)

Bosses arrive every **5** waves from wave **10**, are immune to flee/confusion/displacement/root/conversion,
take slows and DoT at **50% strength**, and trigger **immediate game over** on a leak. HP is anchored to
the arrival **wave** (§1.2), not the boss index.

| Boss (`id`) | Faction | Cost | Base HP | Speed | Tags | Scrap | Lives on leak |
|---|---|---|---|---|---|---|---|
| The Disruptor (`the_disruptor`) | Swarm Syndicate | 40 | 1000 | 0.9 | Ground, Boss | 20 | 20 *(= loss)* |
| The Chairman (`the_chairman`) | Iron Board | 60 | 1600 | 0.4 | Ground, Armored, Tank, Boss | 30 | 20 |
| The Raider (`the_raider`) | Hostile Takeover | 50 | 1200 | 0.6 | Ground, Hacker, Boss | 25 | 20 |
| The Prime Dispatcher (`the_prime_dispatcher`) | Skyline Logistics | 55 | 1200 | 0.5 | Air, Tank, Spawner, Boss | 28 | 20 |
| The Holding Company (`the_holding_company`) | Coalition | 80 | 2500 | 0.45 | Ground, Tank, Cybernetic, Boss | 40 | 20 |

**Mechanics**

- **The Disruptor — NetworkEffect:** takes **−8% damage per allied Syndicate unit within 3 hex**
  (max **50%**). **SurgePricing:** every **15s**, after a **1.5s** siren telegraph, grants **+30%
  Syndicate speed** for **4s**.
- **The Chairman — Restructuring:** at **100 / 66 / 33% HP**, shifts **0.4× resistance** to a new
  damage tag, then halts and becomes immune for **3s** while spawning **2 `riot_shield_unit` escorts**
  (3s telegraph).
- **The Raider — LeveragedBuyout:** every **20s**, after a **4s** beam telegraph, channels on the
  **highest-cost** tower within **4 hex** and spawns a **150 HP `bid_drone`**; converts the tower for
  **10s** unless the drone is killed, the channel is interrupted, or it is cleansed for 50% of base cost.
  (A leaked/orphaned `bid_drone` can stall a wave — see memory `project-bid-drone-wave-stall`.)
- **The Prime Dispatcher — SameDayDelivery:** every **15s**, drops **2 `supply_pod`s** (150 HP) with a
  **2s** reticle that open after **3s** into **3 `courier_drone`s** each (cap 2 pods).
- **The Holding Company — HoldingCompany:** switches between the four faction-boss mechanics every **25%
  HP loss** (non-repeating seeded order) at **70% effect** strength.

---

## 7. Rogue Entity (`res://data/units/rogue_entity.tres`)

The special enemy the **player spawns on themselves**: reaching **100 Corruption** (or the raised
threshold granted by a held `corruption_reservoir`) triggers **THE RECKONING**. Rogue Entities carry no
`BOSS` tag, so `GameState.reckoning_started(...)` and the `TelegraphLayer` alert are the only warning.

| Field | Value |
|---|---|
| `id` | `rogue_entity` |
| `faction` | `coalition` |
| Base HP | 550 |
| Base speed | 1.25 |
| Tags | Ground *(no Boss tag)* |
| Resistances | **all tags ×0.75** (25% reduction, floor 0.50 as it levels) |
| Leak cost | **3** (+1 per 3 levels) |
| Scrap | 0 |
| Kill reward | 10 Offerings (+5 per level) |

**Behavior (code-driven, not `AbilityData`):** `Breakthrough` and a `TowerDisable` pulse every **5s**.
Rogues **level up +1 each time one is killed** (`1.45^level` HP compounding plus wave ramp), spawn in
multiples (`1..5`) as Rogue level and wave rise (clamped to `MAX_ROGUE_ENTITY_SPAWN_COUNT = 8`), and
gain speed/resistances/leak cost/kill reward with level. **Rite debt** decides how bad a Reckoning is
and **resets to 0** when it arrives. Full rules: [`AGENTS.md`](AGENTS.md) §5.

---

## 8. Ability Component Reference

Every ability is an [`AbilityData`](scripts/units/ability_data.gd) resource attached to a unit's
`abilities` array; ids are registered and validated by
[`UnitAbilityRegistry`](scripts/units/unit_ability_registry.gd). Each has a non-empty `telegraph_event`
for UI legibility.

### 8.1 Regular ability ids

| `ability_id` | Meaning | Key parameters |
|---|---|---|
| `LeakSteal` | Steals Offerings when it leaks | `offerings` |
| `SlowResist` | Reduces the effect of slows | `pct` |
| `CourierPack` | Grants a speed bonus to nearby couriers | `pct`, `radius` |
| `SpeedAura` | Continuous speed aura over allies | `pct`, `radius` |
| `DeathBurst` | One-shot speed buff to allies on death | `pct`, `radius`, `duration`, `effect` |
| `SpawnOnTimer` | Spawns `unit_id` on an interval | `unit_id`, `interval`, `cap`, `spawn_count`, `release_on_death` |
| `ShieldRegen` | Regenerating shield absorbing non-bypass damage | `shield_hp`, `regen_delay`, `bypass_tags` |
| `RangedSuppress` | Reduces nearby towers' fire rate | `radius`/`range_hexes`, `fire_rate_penalty` |
| `TowerDisable` | Disables a tower for a duration | `interval`, `duration`, `effect` (e.g. `nearest`) |
| `Cloak` | Untargetable until revealed | — |
| `AntiMagicAura` | Negates Corruption damage bonus in range | `radius` |
| `TowerConvert` | Channels to convert a tower | `interval`, `channel`, `duration`, `range_hexes`, `effect` (`highest_cost`), `pct`, `cleanse_rules` |
| `Heal` | Heals allies per second | `hps`, `radius`, `max_targets` |
| `Breakthrough` | Can crush through blockers | — |

### 8.2 Boss ability ids

| `ability_id` | Meaning | Key parameters |
|---|---|---|
| `NetworkEffect` | Damage reduction per nearby same-faction unit | `pct`, `max_pct`, `radius` |
| `SurgePricing` | Timed faction speed surge (telegraphed) | `interval`, `pct`, `duration`, `telegraph_*` |
| `Restructuring` | HP-threshold resistance shift + escorts | `pct`, `duration`, `unit_id`, `spawn_count` |
| `LeveragedBuyout` | Channels a tower conversion via a bid drone | `interval`, `channel`, `duration`, `range_hexes`, `shield_hp`, `cleanse_rules` |
| `SameDayDelivery` | Drops supply pods that open into drones | `interval`, `spawn_count`, `unit_id`, `cap`, `duration`, `shield_hp` |
| `HoldingCompany` | Cycles the four faction-boss mechanics | `pct` (effect strength) |

### 8.3 Parameter key (shared `AbilityData` fields)

`offerings`, `pct`, `max_pct`, `radius`, `range_hexes`, `duration`, `interval`, `channel`, `unit_id`,
`cap`, `spawn_count`, `release_on_death`, `shield_hp`, `regen_delay`, `bypass_tags`, `fire_rate_penalty`,
`hps`, `max_targets`, `effect`, `cleanse_rules`, `telegraph_event`, `telegraph_lead_time`. Unused keys
default to `0`/empty/`false`.