# UPGRADE AUDIT — Cultist Tower Upgrade Register (77 nodes)

> **Why this file exists.** A full observational run (seed `4624212`, 58 waves) showed a player
> winning ~50 waves on a **wide, shallow** net (198 towers, every node T2, zero T3/T4). The
> diagnosis is that the T3/T4 "bargain" competes against unbounded tower *count* — and count wins
> whenever a capstone only adds **more** of a value a new tower could already supply. This audit
> separates the two kinds of node so retunes target the ones that actually lose to width.
>
> **Source of truth is the data:** `res://data/towers/*.tres` (11 `TowerData`) and
> `res://data/upgrades/*.tres` (77 `UpgradeNode`). Keep this file in sync with any retune.
> Human-readable node prose lives in [`TOWERS.md`](TOWERS.md); this file is the *classification*.

---

## Legend

Every node is tagged by the kind of value it adds:

- **MORE** — raises a number the tower already has (damage, fire rate, range, targets, members,
  income, slow strength, blocker HP). A cheaper/extra copy of the tower can supply the same value,
  so a MORE node loses to width by construction.
- **DIFFERENT** — adds a capability the net cannot replicate by building more copies (hard CC,
  displacement, grounding, contagion, execute, storms, stun/interrupt, anti-armor/shield, crit,
  air targeting, diversity synergies). These are the **bargain-defining** nodes.
- A few nodes are both; the tag records the *dominant* character, and the rare hybrid is noted.

The **RITE** branch (22 nodes, 2 per tower) is the Corruption-scaling branch: it is *almost
entirely MORE by design* (it turns the danger meter into a stat). That is expected — its job is a
payoff shape, not new coverage.

---

## 1. Roster — every node classified

### `hexed_nail_gun` — cheap Kinetic single-target
| Tier | Branch | Node | Cost | Effect | Class |
|---|---|---|---|---|---|
| T2 | Shared | `rapid_cycling` | 18 Off | +30% fire rate | **MORE** |
| T3 | Revealed | `whispering_nails` | 30 Off | homing shots; ignore 25% resistance | **DIFFERENT** |
| T3 | Rigged | `drone_feeder` | 30 Scrap | +40% fire rate; never reloads | **MORE** |
| T3 | Rite | `nail_of_accounting` | 1 Rite | +30% dmg, +0.5%/Corruption; consecutive-shot stacking (+8%/shot, max 12) | **DIFFERENT** (stacking) |
| T4 | Revealed | `nails_that_remember` | 54 Off | 50% chance to hit a second time | **DIFFERENT** |
| T4 | Rigged | `pneumatic_belt_rig` | 54 Scrap | 5-shot burst; +50% vs Armored | **DIFFERENT** (anti-armor) |
| T4 | Rite | `the_audit_comes_due` | 2 Rites | +45% dmg, +30% rate, +0.8%/Corruption | **MORE** |

### `chanting_choir` — Psychic multi-member detector
| Tier | Branch | Node | Cost | Effect | Class |
|---|---|---|---|---|---|
| T2 | Shared | `deeper_harmony` | 24 Off | +2 members | **MORE** |
| T3 | Revealed | `dissonant_hymn` | 40 Off | Fear stacks (slow + damage-taken) | **DIFFERENT** |
| T3 | Rigged | `bullhorn_array` | 40 Scrap | +1 range; **grants Air targeting** | **DIFFERENT** (coverage) |
| T3 | Rite | `the_song_is_billed` | 1 Rite | +25% dmg, +1 member, +0.4%/Corruption | **MORE** |
| T4 | Revealed | `the_unspoken_verse` | 72 Off | Forces enemies to **flee** | **DIFFERENT** |
| T4 | Rigged | `jammer_choir` | 72 Scrap | Stun + interrupt hackers | **DIFFERENT** |
| T4 | Rite | `unspoken_receipts` | 2 Rites | +45% dmg, +1 range, +1 member, +0.7%/Corruption | **MORE** |

### `gutter_ritual_circle` — Corrosive AoE pulse
| Tier | Branch | Node | Cost | Effect | Class |
|---|---|---|---|---|---|
| T2 | Shared | `wider_circle` | 30 Off | Adds a 2nd damage ring (50%) | **MORE** |
| T3 | Revealed | `ichor_bloom` | 50 Off | Leaves a lingering damage puddle | **DIFFERENT** |
| T3 | Rigged | `propane_pulse` | 50 Scrap | +40% dmg; **knockback** | **DIFFERENT** (displacement) |
| T3 | Rite | `the_circle_is_paid` | 1 Rite | +25% dmg, +1 range, +0.3%/Corruption; extra-target scaling | **MORE** |
| T4 | Revealed | `maw_beneath` | 90 Off | **Execute** below 30% HP (periodic) | **DIFFERENT** |
| T4 | Rigged | `chain_detonator` | 90 Scrap | Death-explosion (% max HP, radius 1) | **DIFFERENT** |
| T4 | Rite | `communion_of_the_maw` | 2 Rites | +40% dmg, +1 range, +0.6%/Corruption; Offerings/hit | **MORE** |

### `tentacle_storm_drain` — Kinetic control + slow aura
| Tier | Branch | Node | Cost | Effect | Class |
|---|---|---|---|---|---|
| T2 | Shared | `more_grates` | 21 Off | +1 target; 45% slow aura | **MORE** |
| T3 | Revealed | `deep_grasp` | 35 Off | **Drag + root** | **DIFFERENT** (displacement/root) |
| T3 | Rigged | `flood_pump` | 35 Scrap | Conductive flood (Electric synergy) | **DIFFERENT** |
| T3 | Rite | `drowned_ledger` | 1 Rite | +30% dmg, 45% slow, +0.5%/Corruption | **MORE** |
| T4 | Revealed | `leviathan_awakens` | 63 Off | Periodic 120-dmg sweep + root | **DIFFERENT** |
| T4 | Rigged | `live_wire_flood` | 63 Scrap | Electric-DPS field | **DIFFERENT** |
| T4 | Rite | `the_fathom_collects` | 2 Rites | +50% dmg, +1 target, 55% slow, +0.8%/Corruption | **MORE** |

### `watcher_in_the_billboard` — high-cost Void, highest HP, detector
| Tier | Branch | Node | Cost | Effect | Class |
|---|---|---|---|---|---|
| T2 | Shared | `dilated_pupil` | 42 Scrap | +20% dmg, +2 range | **MORE** |
| T3 | Revealed | `gaze_of_unmaking` | 70 Off | Ignore 50% armor; ignores shields; Mark (+15% taken, 6s) | **DIFFERENT** |
| T3 | Rigged | `rooftop_scope_array` | 70 Scrap | 25% crit (x2) | **DIFFERENT** |
| T3 | Rite | `covetous_gaze` | 1 Rite | +40% dmg, +0.5%/Corruption; +60% vs wounded | **DIFFERENT** (injury bonus) |
| T4 | Revealed | `the_eye_opens` | 126 Off | 4th shot deals % max HP (4% bosses / 12% others) | **DIFFERENT** (anti-boss) |
| T4 | Rigged | `ad_hijack` | 126 Scrap | Confuse (1.5s) + interrupt hackers | **DIFFERENT** |
| T4 | Rite | `the_debt_collector` | 2 Rites | +70% dmg, +1 range, +1.0%/Corruption; Offerings per max-HP | **MORE** |

### `rust_censer` — Corrosive DoT + armor shred
| Tier | Branch | Node | Cost | Effect | Class |
|---|---|---|---|---|---|
| T2 | Shared | `heavier_incense` | 24 Scrap | +30% dmg; DoT 6.0s | **MORE** |
| T3 | Revealed | `plague_incense` | 40 Off | DoT **spreads** on death | **DIFFERENT** (contagion) |
| T3 | Rigged | `acid_sprayer` | 40 Scrap | +50% rate, +1 range | **MORE** |
| T3 | Rite | `corroded_receipts` | 1 Rite | +30% dmg, 6s DoT, +0.5%/Corruption | **MORE** |
| T4 | Revealed | `rust_communion` | 72 Off | Shred cap 8; x2 vs Cybernetic | **DIFFERENT** (cap + anti-cybernetic) |
| T4 | Rigged | `solvent_tank` | 72 Scrap | Shred cap 10; +100% Armored DoT; 4 Scrap/wave upkeep | **DIFFERENT** (cap) |
| T4 | Rite | `the_rust_audits` | 2 Rites | +50% dmg, 8s DoT, shred 8, +0.8%/Corruption | **MORE** |

### `substation_effigy` — Electric chain, Air-priority
| Tier | Branch | Node | Cost | Effect | Class |
|---|---|---|---|---|---|
| T2 | Shared | `copper_thieves` | 30 Scrap | +20% dmg, +1 target | **MORE** |
| T3 | Revealed | `astral_conduction` | 50 Off | +25% vs Air; longer chain hops | **DIFFERENT** (air answer) |
| T3 | Rigged | `substation_tap` | 50 Scrap | +25% rate, +2 targets | **MORE** |
| T3 | Rite | `metered_current` | 1 Rite | +30% dmg, +0.5%/Corruption | **MORE** |
| T4 | Revealed | `voice_in_the_static` | 90 Off | Periodic storm (damage + slow AoE) | **DIFFERENT** |
| T4 | Rigged | `breaker_cascade` | 90 Scrap | Every 5th shot: overload + **stun** + tag bonus | **DIFFERENT** |
| T4 | Rite | `the_grid_forecloses` | 2 Rites | +50% dmg, +25% rate, +0.8%/Corruption | **MORE** |

### `fever_shrine` — fire-rate aura (no attack)
| Tier | Branch | Node | Cost | Effect | Class |
|---|---|---|---|---|---|
| T2 | Shared | `more_candles` | 33 Off | +1 aura range | **MORE** |
| T3 | Revealed | `frenzy_rites` | 55 Off | Aura +30% rate; **4 Offerings/wave upkeep per buffed tower** | **MORE** |
| T3 | Rigged | `server_rack_altar` | 55 Scrap | +10% buffed range; **prevents disable & convert** | **DIFFERENT** (immunity) |
| T3 | Rite | `candles_for_the_ledger` | 1 Rite | Aura +35%, +0.4%/Corruption | **MORE** |
| T4 | Revealed | `ecstatic_vigil` | 99 Off | Periodic x2 burst window | **DIFFERENT** |
| T4 | Rigged | `mesh_network` | 99 Scrap | Aura rate scales with distinct types nearby | **DIFFERENT** (diversity synergy) |
| T4 | Rite | `the_vigil_pays_interest` | 2 Rites | +1 range, aura +50%, +0.7%/Corruption | **MORE** |

### `the_congregation` — summons blockers (no attack)
| Tier | Branch | Node | Cost | Effect | Class |
|---|---|---|---|---|---|
| T2 | Shared | `bigger_flock` | 27 Off | +1 blocker, +30 HP each | **MORE** |
| T3 | Revealed | `devoted` | 45 Off | Blockers **explode** on death (40 dmg, r1) | **DIFFERENT** |
| T3 | Rigged | `picket_line` | 45 Scrap | +100% blocker HP; 30% blocker DR | **MORE** |
| T3 | Rite | `paid_in_flesh` | 1 Rite | +1 blocker, +0.4%/Corruption HP | **MORE** |
| T4 | Revealed | `martyrs_chorus` | 81 Off | Blockers leave damaging **ghosts** (8s, 10 dps) | **DIFFERENT** |
| T4 | Rigged | `union_strike` | 81 Scrap | Melee slow + **taunt** aura | **DIFFERENT** |
| T4 | Rite | `audit_of_the_flock` | 2 Rites | +1 blocker, +60% HP, +0.7%/Corruption HP | **MORE** |

### `tithe_box` — economy (no attack)
| Tier | Branch | Node | Cost | Effect | Class |
|---|---|---|---|---|---|
| T2 | Shared | `bigger_plate` | 21 Off | +50% income | **MORE** |
| T3 | Revealed | `blood_tithe` | 35 Off | +50% income, +1 Corruption/wave | **MORE** |
| T3 | Rigged | `scrap_collector` | 35 Scrap | +25% kill Scrap (up to 3 boxes) | **MORE** |
| T3 | Rite | `the_plate_never_empties` | 1 Rite | +40% income, +0.4%/Corruption | **MORE** |
| T4 | Revealed | `dark_patron` | 63 Off | +10% kill Offerings (up to 3 boxes) | **MORE** |
| T4 | Rigged | `chop_shop` | 63 Scrap | Aura: −10 Jank to nearby Rigged towers | **DIFFERENT** (utility) |
| T4 | Rite | `the_till_audits_itself` | 2 Rites | +75% income, +0.7%/Corruption | **MORE** |

### `dead_air_altar` — Air-only slow aura + grounding (no attack)
| Tier | Branch | Node | Cost | Effect | Class |
|---|---|---|---|---|---|
| T2 | Shared | `colder_current` | 27 Off | +1 range; 55% slow | **MORE** |
| T3 | Revealed | `the_sky_is_closed` | 45 Off | 70% slow; **grounds** air (+35% Electric taken) | **DIFFERENT** (air answer) |
| T3 | Rigged | `salvaged_compressor` | 45 Scrap | 65% slow; periodic discharge damage | **DIFFERENT** (adds damage) |
| T3 | Rite | `tithe_of_stillness` | 1 Rite | +0.4%/Corruption slow aura | **MORE** |
| T4 | Revealed | `heaven_under_glass` | 81 Off | +1 range; 80% slow; grounds (+50% Electric) | **DIFFERENT** (air answer) |
| T4 | Rigged | `blackout_rig` | 81 Scrap | 75% slow; stronger discharge | **DIFFERENT** |
| T4 | Rite | `the_ledger_holds_its_breath` | 2 Rites | +1 range, +0.7%/Corruption slow | **MORE** |

---

## 2. Tally

| Branch | Nodes | MORE | DIFFERENT |
|---|---|---|---|
| T2 Shared | 11 | 11 | 0 |
| T3 Revealed | 11 | 2 | 9 |
| T3 Rigged | 11 | 5 | 6 |
| T4 Revealed | 11 | 1 | 10 |
| T4 Rigged | 11 | 0 | 11 |
| T3 Rite | 11 | 9 | 2 |
| T4 Rite | 11 | 11 | 0 |
| **Total** | **77** | **39** | **38** |

- **The RITE branch is a damage branch, by design.** 20 of 22 Rite nodes are MORE. That is
  intentional (Corruption-as-stat), but it means the Rite branch is **not** a coverage answer; a
  player who wants air/armor/boss answers must still fork REV or RIG.
- **The T3 fork already offers a real choice**: in 10 of 11 towers at least one T3 branch is
  DIFFERENT, and the T4 capstones are overwhelmingly DIFFERENT (21 of 22 REV+RIG T4s; the lone MORE
  is `dark_patron`).
- **The problem the audit confirms is not weak capstones — it is unreached capstones.** The observed
  loss was a fast AIR swarm; the air answers all exist (`bullhorn_array` air targeting,
  `astral_conduction` air bonus, `the_sky_is_closed` / `heaven_under_glass` grounding), and the
  player took none of them because width never needed them until wave 56.

## 3. Implication — where "MORE" loses to width

A T4 that is pure MORE competes directly with ~4-6 more T1/T2 towers (the T4 costs ~1.8x base plus
the T3), each of which also feeds the variety bonus and shrine auras. The pure-MORE **T4 capstones**
are the ones to watch:

- `the_audit_comes_due` (nail gun, Rite T4) — +45% dmg / +30% rate.
- `unspoken_receipts` (choir, Rite T4) — +45% dmg / +1 range / +1 member.
- `communion_of_the_maw` (gutter, Rite T4) — +40% dmg / +1 range.
- `the_fathom_collects` (tentacle, Rite T4) — +50% dmg / +1 target.
- `the_debt_collector` (watcher, Rite T4) — +70% dmg / +1 range.
- `the_rust_audits` (censer, Rite T4) — +50% dmg / 8s DoT.
- `the_grid_forecloses` (substation, Rite T4) — +50% dmg / +25% rate.
- `the_vigil_pays_interest` (shrine, Rite T4) — aura +50%.
- `audit_of_the_flock` (congregation, Rite T4) — +1 blocker / +60% HP.
- `the_till_audits_itself` (tithe, Rite T4) — +75% income.
- `the_ledger_holds_its_breath` (dead-air, Rite T4) — +1 range / ramped slow.
- `dark_patron` (tithe, Revealed T4) — the only *non-Rite* MORE T4: +10% kill Offerings.

These are *fine as the Rite branch's payoff* (it is meant to be Corruption-scaled), but they are the
nodes that read as "just more" if the player is already awash in Offerings. They are the natural
place for a **bounded retune** that gives the Rite T4 a *mechanic hook* (see §4) rather than another
percentage.

## 4. Bounded capstone retune — status (4 of 11 Rite T4s now carry a working mechanic)

Give a **mechanic hook** to the Rite T4s that are currently pure MORE, so the Corruption-scaling
branch pays off in a *shape* width cannot supply, not just a number. Each is a small
`behavior_params` + a reading in the attack path (no new branch in the kill code, per the "read
params by name" convention in §5 of `AGENTS.md`). The flavor/name is kept; the *effect* is the part
that changes, because three of the four first-draft ideas could not work as written.

1. **`the_debt_collector` (watcher) — IMPLEMENTED.** A periodic **% -of-max-HP debt strike** on the
   highest-HP enemy in range: every 12 s, 15% of max HP (5% to Bosses) as raw Void (not routed
   through `calculate_hit_damage`, so the node's own +70% does not balloon it — the `the_eye_opens`
   convention). Read in `_step_watcher_tower`. Test: `test_tower_system::test_16`.
2. **`the_fathom_collects` (tentacle) — IMPLEMENTED (re-designed).** *Was* "stacking slow→root"
   (needed per-unit slow-stack state nothing owns). *Now:* every 6 s the deep **drags the most
   path-advanced Ground enemy in range back 1 hex and pins it 2 s** — reuses the existing
   `displace_along_path` + `apply_root` (both DR-limited) from `deep_grasp`. The tentacle's ordinary
   root catches whoever is at hand; the fathom takes the one about to leak. Read in
   `_step_storm_drain_tower`. Test: `test_18`.
3. **`the_grid_forecloses` (substation) — IMPLEMENTED (re-designed).** *Was* "chain-aware rate bonus"
   (fire rate resolves before the chain is built). *Now:* the arc **stops decaying** (`bounce_decay`
   forced to 1.0) and **each further chained target is hit +20% harder** (`chain_damage_growth`),
   applied at attack time where the chain order is known. A dense pack is punished more, not less.
   Read in `_step_chain_arc_tower`. Test: `test_19`.
4. **`the_audit_comes_due` (nail gun) — IMPLEMENTED (re-designed).** *Was* "kills during the burst
   window extend the next burst" — **invalid**: Rite is exclusive with Rigged, and the burst
   (`pneumatic_belt_rig`) is a Rigged mechanic, so a Rite tower never has a window. *Now:* the T3
   ledger (`nail_of_accounting`) is **CASHED IN** — when it fills (12 stacks) the whole account
   settles at once as a Void burst of 60% base damage per stack, then the ledger restarts. The T3
   builds the debt, the T4 collects it. Read in `_step_single_target_tower`. Test: `test_17`.

Net: **4 of the 11** pure-MORE Rite T4s now carry a real mechanic (`the_debt_collector`,
`the_fathom_collects`, `the_grid_forecloses`, `the_audit_comes_due`). The other seven
(`unspoken_receipts`, `communion_of_the_maw`, `the_rust_audits`, `the_vigil_pays_interest`,
`audit_of_the_flock`, `the_till_audits_itself`, `the_ledger_holds_its_breath`) remain the
Corruption-scaled stat payoff by design.

## 5. Method

Nodes dumped from `res://data/upgrades/*.tres` (`UpgradeNode` fields: `tier`, `branch`, `cost`,
`damage_mult`, `fire_rate_mult`, `range_add/mult`, `members_add`, `targets_add`, the `*_override`
fields, `grants_air_targeting`, `corruption_scaled_*`, `behaviors`, `behavior_params`). A node is
**DIFFERENT** when it carries a named behavior whose params introduce a capability beyond stat
scaling; **MORE** otherwise. Hybrid nodes are tagged by dominant character.