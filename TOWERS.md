# TOWERS — Cultist Tower & Upgrade Register

> **This file is the human-readable accounting of every tower and every upgrade node in the game.**
> It exists so a designer (or an agent) can see the *whole* roster — ids, costs, stats, currencies,
> Corruption/Jank side-effects, and per-node effects — without opening 88 `.tres` files.
>
> The **source of truth is the data**, not this document:
> `res://data/towers/*.tres` (11 `TowerData`) and `res://data/upgrades/*.tres` (77 `UpgradeNode`).
> For *why* towers work the way they do see [`AGENTS.md`](AGENTS.md) §5; for *how to build one* see
> the [`create-tower-type`](.ziva/skills/create-tower-type/SKILL.md) skill; for tone see
> [`DESIGN_BIBLE.md`](DESIGN_BIBLE.md).
>
> **Keep this file in sync.** Any change to a `TowerData` or `UpgradeNode` resource (a new tower, a
> retune, a new node, a cost change) MUST be reflected here in the same change. The `create-tower-type`
> skill makes updating this register a required step.

---

## 1. Roster Overview

All 11 cult towers. Every tower is a `TowerData` in `res://data/towers/` with **7 upgrade nodes**
(`1 T2 + 2 Revealed + 2 Rigged + 2 Rite = 7`), for **77 nodes** total.

| # | `id` | Name | Build | Range | Damage (tag) | Rate | Targets | Targeting mode |
|---|---|---|---|---|---|---|---|---|
| 1 | `hexed_nail_gun` | Hexed Nail Gun | 30 Off | 3 | 8 Kinetic | 2.00/s | Ground + Air | `SINGLE_TARGET` (0) |
| 2 | `chanting_choir` | Chanting Choir | 40 Off | 2 | 3 Psychic *(×3 members)* | 1.00/s | Ground | `CHANNELED_CHOIR` (2) |
| 3 | `gutter_ritual_circle` | Gutter Ritual Circle | 50 Off | 3 | 25 Corrosive *per pulse* | 0.40/s | Ground | `PULSE_AOE` (3) |
| 4 | `tentacle_storm_drain` | Tentacle Storm Drain | 35 Off | 2 | 4 Kinetic | 1.00/s | Ground | `CONTROL_DRAIN` (4) |
| 5 | `watcher_in_the_billboard` | Watcher in the Billboard | 70 Scrap | 6 | 90 Void | 0.25/s | Ground + Air | `HIGHEST_HP` (1) |
| 6 | `rust_censer` | Rust Censer | 40 Scrap | 2 | 6 Corrosive *(DoT/s)* | 1.00/s | Ground | `DOT_CENSER` (5) |
| 7 | `fever_shrine` | Fever Shrine | 55 Off | 2 *(aura)* | — *(no attack)* | — | Friendly towers | `BUFF_SHRINE` (6) |
| 8 | `the_congregation` | The Congregation | 45 Off | 1 *(adjacent)* | 2 Kinetic *(blocker)* | 1.00/s | Ground | `SUMMON_CONGREGATION` (7) |
| 9 | `tithe_box` | Tithe Box | 35 Off | 0 | — *(no attack)* | — | None (economy) | `ECONOMY_TITHE` (8) |
| 10 | `substation_effigy` | Substation Effigy | 50 Scrap | 3 | 14 Electric | 0.85/s | Ground + Air | `CHAIN_ARC` (9) |
| 11 | `dead_air_altar` | Dead Air Altar | 45 Off | 3 | — *(no attack)* | — | Air *(slow aura)* | `AIR_CONTROL` (10) |

**Build currency:** 8 towers cost **Offerings**, 3 cost **Scrap** (`watcher_in_the_billboard`,
`rust_censer`, `substation_effigy`). The T2 node is priced in the tower's own build currency; the
Revealed branch is always Offerings, the Rigged branch always Scrap, the Rite branch always Rites.

---

## 2. Shared Upgrade & Stat Systems

Numbers below live in `res://data/tower_balance.tres` (`TowerBalanceData`). See [`AGENTS.md`](AGENTS.md)
§5 for the full mechanics.

### 2.1 Upgrade tree shape and costs

| Slot | Tier | Branch | Currency | Cost formula | Corruption | Jank |
|---|---|---|---|---|---|---|
| T2 | 2 | `SHARED` (0) | tower build currency | `roundi(base_cost × 0.6)` | — | — |
| Revealed T3 | 3 | `REVEALED` (1) | Offerings | `roundi(base_cost × 1.0)` | **+4** | — |
| Revealed T4 | 4 | `REVEALED` (1) | Offerings | `roundi(base_cost × 1.8)` | **+8** | — |
| Rigged T3 | 3 | `RIGGED` (2) | Scrap | `roundi(base_cost × 1.0)` | — | **10%** |
| Rigged T4 | 4 | `RIGGED` (2) | Scrap | `roundi(base_cost × 1.8)` | — | **25%** |
| Rite T3 | 3 | `RITE` (3) | Rites | **flat 1** | — | — |
| Rite T4 | 4 | `RITE` (3) | Rites | **flat 2** | — | — |

- The **T3 fork is a 3-way exclusive lock**: taking any one branch permanently locks the other two for
  that tower.
- **Revealed** upgrades add global Corruption. **Rigged** upgrades set that tower's Jank. **Rite**
  upgrades add *neither* — the Corruption price was already paid when the Rites were drawn, and
  **Rites are never refunded on sell**.
- **Rite signature:** every Rite node carries `corruption_scaled_damage`/`corruption_scaled_stat`
  (additive bonus per point of *current* Corruption) and a `corruption_per_kill` param, so the branch
  turns the danger meter into a stat and feeds the very meter it draws on.

### 2.2 Global Corruption (0..100)

Revealed towers deal **+0.25%** additive damage per Corruption point. At **50+** a random Revealed
tower has a 10% chance to misfire per wave (20% at **75+**); at **100** hostile **Rogue Entities**
spawn. A `compliance_officer` negates the Corruption bonus within 2 hexes. Rev. values are augmented
by the `ley_line` objective (+8% additive Revealed damage, in-region).

### 2.3 Per-tower Jank (0..60%)

Each Rigged tower rolls `min(jank, 60)%` at wave start to jam at a seeded moment, disabling it 10s.
**Maintenance** (15 Scrap) lowers a tower's Jank by 10. `converted_data_center` halves jam duration;
`chop_shop` grants free area maintenance once per wave.

### 2.4 Cross-tower synergies

- **Armor Shred:** each stack = +5% damage taken from all sources (default cap 5). `rust_communion`
  and `the_rust_audits` raise the cap to 8, `solvent_tank` to 10.
- **Entangled:** Ground enemies slowed/rooted by `tentacle_storm_drain` take +25% damage from
  `gutter_ritual_circle` pulses.
- **Variety Bonus:** +3% damage per distinct *other* tower type within 3 hexes (max +12%).
- **Grounding:** `dead_air_altar` makes slowed Air units take +25% Electric damage (upgrades raise it),
  feeding `substation_effigy`.
- **Cost escalation:** from the 10th owned copy of a type, each next copy costs +10% more.

---

## 3. Tower Details

Each entry lists the base (T1) stats and the full 7-node upgrade table. "Off" = Offerings,
"Rite" = Rites. Corruption figures are the global Corruption added by that node; a Rigged node's
figure is the Jank it sets on the tower.

---

### 1. Hexed Nail Gun (`hexed_nail_gun`)

> *Single-target Kinetic nail gun that targets Ground and Air enemies.*

The cheap, fast bread-and-butter attacker; the only T1 that hits both domains with rapid single-target
Kinetic damage. No special traits at T1 (`get_ability_lines()` is empty — its whole job is the stat line).

- **Build:** 30 Offerings · **Range:** 3 hex · **Damage:** 8 Kinetic · **Rate:** 2.00/s · **Targets:** Ground + Air
- **Mode:** `SINGLE_TARGET` · **Max targets:** 1

| Tier · Branch | Upgrade | Cost | Corruption / Jank | Effect |
|---|---|---|---|---|
| T2 Shared | Rapid Cycling (`rapid_cycling`) | 18 Off | — | +30% fire rate. |
| Revealed T3 | Whispering Nails (`whispering_nails`) | 30 Off | +4 Corruption | Homing; 25% of each hit ignores resistances. |
| Revealed T4 | Nails That Remember (`nails_that_remember`) | 54 Off | +8 Corruption | Each nail returns for a second hit at 50% damage. |
| Rigged T3 | Drone Feeder (`drone_feeder`) | 30 Scrap | Jank 10% | +40% fire rate; never reloads. |
| Rigged T4 | Pneumatic Belt Rig (`pneumatic_belt_rig`) | 54 Scrap | Jank 25% | 5-shot bursts; +50% damage vs Armored. |
| Rite T3 | Nail of Accounting (`nail_of_accounting`) | 1 Rite | +1 Corruption/kill | +30% damage; +0.5% per Corruption. **The Ledger:** each consecutive shot on the same target adds +8% damage (up to +96%), resetting on target switch. |
| Rite T4 | The Audit Comes Due (`the_audit_comes_due`) | 2 Rites | +2 Corruption/kill · +2 Off/kill | +45% damage, +30% fire rate; +0.8% per Corruption. **The Audit Collects:** every kill pays 2 extra Offerings. |

---

### 2. Chanting Choir (`chanting_choir`)

> *Deals 3 Psychic per member per second (starts with 3 members) to Ground targets; detects Cloaked enemies in range.*

A continuous multi-member Psychic channel and the game's cheapest **Cloak detector**. Damage scales
with member count (3 members at T1 = 9 Psychic/s). Ground-only at T1; the Rigged branch grants Air.

- **Build:** 40 Offerings · **Range:** 2 hex · **Damage:** 3 Psychic per member/s · **Rate:** 1.00/s · **Targets:** Ground
- **Mode:** `CHANNELED_CHOIR` · **Members:** 3 · **Detects Cloaked:** yes

| Tier · Branch | Upgrade | Cost | Corruption / Jank | Effect |
|---|---|---|---|---|
| T2 Shared | Deeper Harmony (`deeper_harmony`) | 24 Off | — | +2 choir members (3 → 5). |
| Revealed T3 | Dissonant Hymn (`dissonant_hymn`) | 40 Off | +4 Corruption | Stacking Fear (max 5): −6% speed and +3% damage taken per stack. |
| Revealed T4 | The Unspoken Verse (`the_unspoken_verse`) | 72 Off | +8 Corruption | At 5 Fear stacks an enemy flees backward 2s (once per enemy per 10s). |
| Rigged T3 | Bullhorn Array (`bullhorn_array`) | 40 Scrap | Jank 10% | +1 range; can hit Air. |
| Rigged T4 | Jammer Choir (`jammer_choir`) | 72 Scrap | Jank 25% | Stuns Air and Cybernetic enemies 1.5s every 8s; interrupts Hacker channels in range. |
| Rite T3 | The Song Is Billed (`the_song_is_billed`) | 1 Rite | +1 Corruption/kill | +25% damage, +1 member; +0.4% per Corruption. |
| Rite T4 | Unspoken Receipts (`unspoken_receipts`) | 2 Rites | +2 Corruption/kill · +1 Off/kill | +45% damage, +1 member, +1 range; +0.7% per Corruption. |

---

### 3. Gutter Ritual Circle (`gutter_ritual_circle`)

> *Pulses 25 Corrosive every 2.5 s on target + ring 1 (Ground only); reveals Cloaked enemies hit for 3 s.*

Periodic Corrosive AoE pulse that hits the target and a 1-hex ring, and **reveals Cloaked enemies it
hits for 3 s**. The `entangled` synergy payoff (bonus damage vs enemies slowed/rooted by the storm drain)
is read at the enemy end.

- **Build:** 50 Offerings · **Range:** 3 hex · **Damage:** 25 Corrosive per pulse (~10/s) · **Rate:** 0.40/s · **Targets:** Ground
- **Mode:** `PULSE_AOE` · **Pulse ring:** 1 · **Pulse reveal:** 3s

| Tier · Branch | Upgrade | Cost | Corruption / Jank | Effect |
|---|---|---|---|---|
| T2 Shared | Wider Circle (`wider_circle`) | 30 Off | — | Pulse also hits ring 2 at 50% damage. |
| Revealed T3 | Ichor Bloom (`ichor_bloom`) | 50 Off | +4 Corruption | Each pulse leaves a 4s puddle dealing 8 Void/s. |
| Revealed T4 | Maw Beneath (`maw_beneath`) | 90 Off | +8 Corruption | Every 12s a maw kills non-Tank, non-Boss Ground units under 30% max HP inside the pulse area. |
| Rigged T3 | Propane Pulse (`propane_pulse`) | 50 Scrap | Jank 10% | +40% pulse damage; knocks the target back 1 hex along the path (not Bosses). |
| Rigged T4 | Chain Detonator (`chain_detonator`) | 90 Scrap | Jank 25% | Pulse kills explode for 40% of the victim's max HP in radius 1; chains. |
| Rite T3 | The Circle Is Paid (`the_circle_is_paid`) | 1 Rite | +1 Corruption/kill | +25% pulse damage, +1 hex radius; +0.3% per Corruption. Each enemy caught past the first adds +15% pulse damage (up to +90%). |
| Rite T4 | Communion of the Maw (`communion_of_the_maw`) | 2 Rites | +2 Corruption/kill · +1 Off per enemy hit | +40% pulse damage, +1 hex radius; +0.6% per Corruption. |

---

### 4. Tentacle Storm Drain (`tentacle_storm_drain`)

> *Deals 4 Kinetic/s to Ground enemies; 35% slow aura; roots target 1.5 s every 8 s; applies Entangled.*

A control tower first and a damage dealer second: a continuous 35% slow aura, a periodic root, and the
**Entangled** applier that feeds `gutter_ritual_circle`. Ground-only.

- **Build:** 35 Offerings · **Range:** 2 hex · **Damage:** 4 Kinetic/s · **Rate:** 1.00/s · **Targets:** Ground
- **Mode:** `CONTROL_DRAIN` · **Slow aura:** 35% · **Root:** 1.5s every 8s · **Entangled:** yes

| Tier · Branch | Upgrade | Cost | Corruption / Jank | Effect |
|---|---|---|---|---|
| T2 Shared | More Grates (`more_grates`) | 21 Off | — | +1 target; slow aura 35% → 45%. |
| Revealed T3 | Deep Grasp (`deep_grasp`) | 35 Off | +4 Corruption | Root 2.5s and drag 1 hex backward (not Bosses). |
| Revealed T4 | Leviathan Awakens (`leviathan_awakens`) | 63 Off | +8 Corruption | Every 25s a sweep hits all enemies in range +2 for 120 Void and roots 1s. |
| Rigged T3 | Flood Pump (`flood_pump`) | 35 Scrap | Jank 10% | A 40% slow puddle on path hexes within radius 1; wet hexes conduct Electric. |
| Rigged T4 | Live Wire Flood (`live_wire_flood`) | 63 Scrap | Jank 25% | Flooded hexes deal 12 Electric/s. |
| Rite T3 | Drowned Ledger (`drowned_ledger`) | 1 Rite | +1 Corruption/kill | +30% damage, slow aura 45%; +0.5% per Corruption. |
| Rite T4 | The Fathom Collects (`the_fathom_collects`) | 2 Rites | +2 Corruption/kill · +1 Scrap/kill | +50% damage, slow aura 55%, +1 simultaneous target; +0.8% per Corruption. |

---

### 5. Watcher in the Billboard (`watcher_in_the_billboard`)

> *Fires 90 Void every 4 s at the highest-HP Ground or Air enemy; detects Cloaked enemies in range.*

The long-range (6 hex) Void sniper: always targets the highest-HP enemy, hits both domains, and is a
continuous **Cloak detector**. Costly (70 Scrap) and slow, but the highest per-shot damage in the game.

- **Build:** 70 Scrap · **Range:** 6 hex · **Damage:** 90 Void · **Rate:** 0.25/s · **Targets:** Ground + Air
- **Mode:** `HIGHEST_HP` · **Detects Cloaked:** yes

| Tier · Branch | Upgrade | Cost | Corruption / Jank | Effect |
|---|---|---|---|---|
| T2 Shared | Dilated Pupil (`dilated_pupil`) | 42 Scrap | — | +2 range, +20% damage. |
| Revealed T3 | Gaze of Unmaking (`gaze_of_unmaking`) | 70 Off | +4 Corruption | Ignores shields and 50% of armor; marks the target (+15% damage from all sources for 6s). |
| Revealed T4 | The Eye Opens (`the_eye_opens`) | 126 Off | +8 Corruption | Every 4th shot adds 12% of target max HP as Void (4% vs Bosses). |
| Rigged T3 | Rooftop Scope Array (`rooftop_scope_array`) | 70 Scrap | Jank 10% | +25% crit chance (2× damage). |
| Rigged T4 | Ad Hijack (`ad_hijack`) | 126 Scrap | Jank 25% | Each shot also confuses enemies within 1 hex (reverse-walk 1.5s, not Bosses) and cancels Hacker channels. |
| Rite T3 | Covetous Gaze (`covetous_gaze`) | 1 Rite | +1 Corruption/kill | +40% damage; +0.5% per Corruption. Damage rises as the target's HP falls, up to +60%. |
| Rite T4 | The Debt Collector (`the_debt_collector`) | 2 Rites | +2 Corruption/kill · +5% of max HP as Off/kill | +70% damage, +1 range; +1.0% per Corruption. |

---

### 6. Rust Censer (`rust_censer`)

> *Applies a 6 Corrosive/s DoT for 4 s (stacks to 3) and 1 Armor Shred per application to Ground enemies.*

The **Armor Shred** applier and Corrosive DoT stacker — a force-multiplier that makes everything else hit
harder. Ground-only. Its capstone choices (Revealed vs Rigged) raise the Shred cap differently.

- **Build:** 40 Scrap · **Range:** 2 hex · **Damage:** 6 Corrosive/s DoT · **Rate:** 1.00/s · **Targets:** Ground
- **Mode:** `DOT_CENSER` · **DoT:** 6/s for 4s, up to 3 stacks · **Armor Shred:** 1/hit

| Tier · Branch | Upgrade | Cost | Corruption / Jank | Effect |
|---|---|---|---|---|
| T2 Shared | Heavier Incense (`heavier_incense`) | 24 Scrap | — | DoT +30%; duration 4s → 6s. |
| Revealed T3 | Plague Incense (`plague_incense`) | 40 Off | +4 Corruption | On death, the remaining DoT spreads to enemies within 1 hex. |
| Revealed T4 | Rust Communion (`rust_communion`) | 72 Off | +8 Corruption | Shred cap 8; Shred counts double vs Cybernetic. |
| Rigged T3 | Acid Sprayer (`acid_sprayer`) | 40 Scrap | Jank 10% | +1 range, +50% application rate. |
| Rigged T4 | Solvent Tank (`solvent_tank`) | 72 Scrap | Jank 25% | Shred cap 10; +100% DoT vs Armored; consumes 4 Scrap per wave and is disabled at 0 Scrap. |
| Rite T3 | Corroded Receipts (`corroded_receipts`) | 1 Rite | +1 Corruption/kill | +30% corrosion damage, DoT duration 6s; +0.5% per Corruption. |
| Rite T4 | The Rust Audits (`the_rust_audits`) | 2 Rites | +2 Corruption/kill · +1 Off/kill | +50% corrosion damage, DoT duration 8s, Shred cap 8; +0.8% per Corruption. |

---

### 7. Fever Shrine (`fever_shrine`)

> *No attack; aura radius 2 grants +15% fire rate to towers in range (multiple shrines do not stack).*

A pure **support aura**: no attack, but boosts nearby friendly towers' fire rate. Meant to sit in the
middle of a firing line. Both non-attacking and aura-scaling, so its Rite branch raises *aura fire rate*
rather than damage.

- **Build:** 55 Offerings · **Aura range:** 2 hex · **Effect:** +15% fire rate (non-stacking) · **Targets:** Friendly towers
- **Mode:** `BUFF_SHRINE`

| Tier · Branch | Upgrade | Cost | Corruption / Jank | Effect |
|---|---|---|---|---|
| T2 Shared | More Candles (`more_candles`) | 33 Off | — | Aura radius 2 → 3 hex. |
| Revealed T3 | Frenzy Rites (`frenzy_rites`) | 55 Off | +4 Corruption | Aura +30% fire rate; upkeep 4 Offerings per buffed tower per wave. |
| Revealed T4 | Ecstatic Vigil (`ecstatic_vigil`) | 99 Off | +8 Corruption | Every 20s buffed towers fire at double rate for 3s. |
| Rigged T3 | Server Rack Altar (`server_rack_altar`) | 55 Scrap | Jank 10% | +10% range on buffed towers; buffed towers cannot be disabled or converted. |
| Rigged T4 | Mesh Network (`mesh_network`) | 99 Scrap | Jank 25% | Replaces the flat buff with +6% fire rate per distinct tower type in the aura (max +30%). |
| Rite T3 | Candles for the Ledger (`candles_for_the_ledger`) | 1 Rite | +1 Corruption/kill | Aura raised to +35% fire rate; +0.4% aura fire rate per Corruption. |
| Rite T4 | The Vigil Pays Interest (`the_vigil_pays_interest`) | 2 Rites | +2 Corruption/kill | Aura +50% fire rate and +1 hex; +0.7% per Corruption. |

---

### 8. The Congregation (`the_congregation`)

> *Must be placed adjacent to the path. Summons up to 2 cultist blockers (60 HP, 2 Kinetic/s) onto the adjacent path hex; resummons 10 s after death.*

The only tower with a **placement constraint**: it must sit directly adjacent (hex distance 1) to the
path, and it summons melee blockers onto path hexes to physically body-block enemies. A summon/blocking
role; its Rite branch scales summoned HP.

- **Build:** 45 Offerings · **Range:** 1 hex (must be adjacent) · **Blockers:** 2 × (60 HP, 2 Kinetic/s)
- **Mode:** `SUMMON_CONGREGATION` · **Resummon:** 10s

| Tier · Branch | Upgrade | Cost | Corruption / Jank | Effect |
|---|---|---|---|---|
| T2 Shared | Bigger Flock (`bigger_flock`) | 27 Off | — | Summons up to 3 blockers; +30 HP each (60 → 90). |
| Revealed T3 | Devoted (`devoted`) | 45 Off | +4 Corruption | Blockers explode on death for 40 Void in radius 1. |
| Revealed T4 | Martyr's Chorus (`martyrs_chorus`) | 81 Off | +8 Corruption | Fallen blockers rise as ghosts for 8s (10 Psychic/s). |
| Rigged T3 | Picket Line (`picket_line`) | 45 Scrap | Jank 10% | Blockers get riot shields (+100% HP, −30% damage taken). |
| Rigged T4 | Union Strike (`union_strike`) | 81 Scrap | Jank 25% | Blockers taunt enemies in melee and slow them 30%. |
| Rite T3 | Paid in Flesh (`paid_in_flesh`) | 1 Rite | +1 Corruption/kill | +1 blocker; +0.4% blocker HP per Corruption. |
| Rite T4 | Audit of the Flock (`audit_of_the_flock`) | 2 Rites | +2 Corruption/kill | +1 blocker, +60% blocker HP; +0.7% blocker HP per Corruption. |

---

### 9. Tithe Box (`tithe_box`)

> *No attack; generates +4 Offerings every 5 s.*

The **economy** tower: no attack, passive Offerings income, and the home of most economy-scaling upgrades
(kill-bonus Offerings/Scrap, Jank maintenance). Pure economy, so its Rite branch scales **income**.

- **Build:** 35 Offerings · **Range:** 0 · **Income:** +4 Offerings / 5s · **Targets:** None
- **Mode:** `ECONOMY_TITHE`

| Tier · Branch | Upgrade | Cost | Corruption / Jank | Effect |
|---|---|---|---|---|
| T2 Shared | Bigger Plate (`bigger_plate`) | 21 Off | — | +50% Offerings income. |
| Revealed T3 | Blood Tithe (`blood_tithe`) | 35 Off | +4 Corruption | +50% income; +1 Corruption per wave per box. |
| Revealed T4 | Dark Patron (`dark_patron`) | 63 Off | +8 Corruption | +10% of each wave's kill Offerings (max 3 boxes count). |
| Rigged T3 | Scrap Collector (`scrap_collector`) | 35 Scrap | Jank 10% | +25% Scrap from kills (max 3 boxes count). |
| Rigged T4 | Chop Shop (`chop_shop`) | 63 Scrap | Jank 25% | Once per wave, free maintenance: −10 Jank on every Rigged tower within 3 hexes. |
| Rite T3 | The Plate Never Empties (`the_plate_never_empties`) | 1 Rite | +1 Corruption/kill | +40% income; +0.4% income per Corruption. |
| Rite T4 | The Till Audits Itself (`the_till_audits_itself`) | 2 Rites | +2 Corruption/kill · +1 Off/kill | +75% income; +0.7% income per Corruption. |

---

### 10. Substation Effigy (`substation_effigy`)

> *High-voltage Scrap coil that arcs Electric chain lightning across up to 3 Ground or Air enemies.*

The **chain-lightning** attacker: Electric damage that arcs across up to 3 targets, hits both domains,
and prioritizes Air. The natural partner of `dead_air_altar`'s Grounding.

- **Build:** 50 Scrap · **Range:** 3 hex · **Damage:** 14 Electric per target · **Rate:** 0.85/s · **Targets:** Ground + Air
- **Mode:** `CHAIN_ARC` · **Chain targets:** 3

| Tier · Branch | Upgrade | Cost | Corruption / Jank | Effect |
|---|---|---|---|---|
| T2 Shared | Copper Thieves (`copper_thieves`) | 30 Scrap | — | +1 chain target (3 → 4), +20% damage. |
| Revealed T3 | Astral Conduction (`astral_conduction`) | 50 Off | +4 Corruption | Chain arcs retain 100% damage across 3-hex hops; +25% damage to Air units. |
| Revealed T4 | Voice in the Static (`voice_in_the_static`) | 90 Off | +8 Corruption | Every 10s calls a Ball Lightning storm on the densest cluster in range (45 Electric AoE + 35% slow for 3s). |
| Rigged T3 | Substation Tap (`substation_tap`) | 50 Scrap | Jank 10% | +2 chain targets, +25% fire rate. |
| Rigged T4 | Breaker Cascade (`breaker_cascade`) | 90 Scrap | Jank 25% | Every 5th discharge overloads for +50% damage and a 0.8s stun; +35% damage vs Air, Shielded, and Cybernetic. |
| Rite T3 | Metered Current (`metered_current`) | 1 Rite | +1 Corruption/kill | +30% Electric damage; +0.5% per Corruption. |
| Rite T4 | The Grid Forecloses (`the_grid_forecloses`) | 2 Rites | +2 Corruption/kill · +1 Scrap/kill | +50% Electric damage, +25% fire rate; +0.8% per Corruption. |

---

### 11. Dead Air Altar (`dead_air_altar`)

> *Anti-air control: slows Air enemies within 3 hexes by 45% and grounds them (+25% Electric damage taken); no attack of its own.*

The dedicated **anti-air control** tower: a continuous 45% **Air-only** slow aura that **Grounds** the
slowed air (+25% Electric damage taken), setting them up for `substation_effigy`. No attack of its own,
so its Rite branch scales **slow aura strength**.

- **Build:** 45 Offerings · **Range:** 3 hex (aura) · **Slow:** 45% (Air) · **Grounding:** +25% Electric
- **Mode:** `AIR_CONTROL` · **Targets:** Air

| Tier · Branch | Upgrade | Cost | Corruption / Jank | Effect |
|---|---|---|---|---|
| T2 Shared | Colder Current (`colder_current`) | 27 Off | — | Slow aura 45% → 55%; +1 hex. |
| Revealed T3 | The Sky Is Closed (`the_sky_is_closed`) | 45 Off | +4 Corruption | 70% slow aura; grounded air take +35% Electric damage. |
| Revealed T4 | Heaven Under Glass (`heaven_under_glass`) | 81 Off | +8 Corruption | 80% slow aura; +50% Electric damage to grounded air; +1 range. |
| Rigged T3 | Salvaged Compressor (`salvaged_compressor`) | 45 Scrap | Jank 10% | 65% slow aura, plus a periodic 12 Electric discharge into grounded air. |
| Rigged T4 | Blackout Rig (`blackout_rig`) | 81 Scrap | Jank 25% | 75% slow aura; the discharge fires harder and more often (20 Electric every 4s). |
| Rite T3 | Tithe of Stillness (`tithe_of_stillness`) | 1 Rite | +1 Corruption/kill | +0.4% slow aura per Corruption. |
| Rite T4 | The Ledger Holds Its Breath (`the_ledger_holds_its_breath`) | 2 Rites | +2 Corruption/kill | +0.7% slow aura per Corruption; +1 range. |

---

## 4. Upgrade Node Index (all 77)

Flat lookup of every `UpgradeNode` id by tower and slot. Useful for `grep`-style reference and for
confirming counts (`11 × 7 = 77`).

| Tower | T2 | Revealed T3 | Revealed T4 | Rigged T3 | Rigged T4 | Rite T3 | Rite T4 |
|---|---|---|---|---|---|---|---|
| `hexed_nail_gun` | `rapid_cycling` | `whispering_nails` | `nails_that_remember` | `drone_feeder` | `pneumatic_belt_rig` | `nail_of_accounting` | `the_audit_comes_due` |
| `chanting_choir` | `deeper_harmony` | `dissonant_hymn` | `the_unspoken_verse` | `bullhorn_array` | `jammer_choir` | `the_song_is_billed` | `unspoken_receipts` |
| `gutter_ritual_circle` | `wider_circle` | `ichor_bloom` | `maw_beneath` | `propane_pulse` | `chain_detonator` | `the_circle_is_paid` | `communion_of_the_maw` |
| `tentacle_storm_drain` | `more_grates` | `deep_grasp` | `leviathan_awakens` | `flood_pump` | `live_wire_flood` | `drowned_ledger` | `the_fathom_collects` |
| `watcher_in_the_billboard` | `dilated_pupil` | `gaze_of_unmaking` | `the_eye_opens` | `rooftop_scope_array` | `ad_hijack` | `covetous_gaze` | `the_debt_collector` |
| `rust_censer` | `heavier_incense` | `plague_incense` | `rust_communion` | `acid_sprayer` | `solvent_tank` | `corroded_receipts` | `the_rust_audits` |
| `fever_shrine` | `more_candles` | `frenzy_rites` | `ecstatic_vigil` | `server_rack_altar` | `mesh_network` | `candles_for_the_ledger` | `the_vigil_pays_interest` |
| `the_congregation` | `bigger_flock` | `devoted` | `martyrs_chorus` | `picket_line` | `union_strike` | `paid_in_flesh` | `audit_of_the_flock` |
| `tithe_box` | `bigger_plate` | `blood_tithe` | `dark_patron` | `scrap_collector` | `chop_shop` | `the_plate_never_empties` | `the_till_audits_itself` |
| `substation_effigy` | `copper_thieves` | `astral_conduction` | `voice_in_the_static` | `substation_tap` | `breaker_cascade` | `metered_current` | `the_grid_forecloses` |
| `dead_air_altar` | `colder_current` | `the_sky_is_closed` | `heaven_under_glass` | `salvaged_compressor` | `blackout_rig` | `tithe_of_stillness` | `the_ledger_holds_its_breath` |

**Counts:** 11 towers · 77 upgrade nodes (11 T2 + 22 Revealed + 22 Rigged + 22 Rite).