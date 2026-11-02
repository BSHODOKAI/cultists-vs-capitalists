# Cultist Tower Defense: Code-Generation Prompt Set

A set of prompts for building the core systems of an isometric, hex-grid, endless-mode tower defense game in Godot 4. Paste **Prompt 0** at the top of each of the others so every prompt stands alone.

**Suggested build order**

1. Prompt 0 + 1: path growth
2. Prompt 0 + 2: towers and tech trees
3. Prompt 0 + 3: enemies and bosses
4. Prompt 0 + 4: director (consumes the tags and damage events from 2 and 3)

## Prompt 0: Shared context

```
PROJECT: Endless-mode, isometric, hex-grid tower defense in Godot 4
(typed GDScript). A scrappy Lovecraftian cult (mysticism + salvaged junk)
defends against sleek, sponsor-branded cyberpunk corporate warlords.

CORE LOOP
- Enemies spawn at the far end of a procedurally generated path and walk
  to the player's base at path index 0. Air units also follow the path
  (they ignore blockers and are only hit by anti-air towers).
- A leaked enemy costs lives (field leak_cost, default 1). Lives start at
  20. A leaked BOSS is an immediate game over. Zero lives is game over.
- Every 10th wave is a boss wave. When the boss dies, the path grows.
- An AI director builds each wave from a budget, adapting to the player's
  defenses to force balanced builds.
- Towers have NO HP in v1. Enemies interact with towers by disabling,
  suppressing, or converting them.

CURRENCIES
- Offerings: build towers, Revealed upgrades, Penance. Earned from kills
  and Tithe Boxes. Start: 150.
- Scrap: Rigged upgrades and maintenance. Dropped by killed enemies
  (scrap_value defaults to round(cost * 0.5), overridable per unit).
  Start: 0.

TAGS
Damage tags: Kinetic, Corrosive, Psychic, Void, Electric.
Unit tags: Ground, Air, Fast, Fragile, Armored, Shielded, Cloaked, Swarm,
Healer, Spawner, Support, Aura, Hacker, Electric, Anti-Magic, Cybernetic,
Tank, Ranged, Boss.
Resistances are damage multipliers per damage tag (0.75 = takes 25% less,
1.25 = takes 25% more).
Bosses: immune to flee, displacement, root and conversion; slows and
damage-over-time effects apply at 50% strength.

SPECIAL EVENT: "Stars Are Right" waves are every 5th wave that is not a
boss wave (5, 15, 25...). Revealed towers deal +20% damage that wave.

ENGINEERING CONVENTIONS
- All game data lives in Resource (.tres) files under res://data/. All
  balance numbers live in named constants or one balance resource per
  system, never scattered through logic.
- Separate pure logic (RefCounted classes) from Nodes so everything can be
  tested headlessly. Use GUT for tests.
- All randomness uses seeded RandomNumberGenerator instances passed in.
  Never call global randf()/randi().
- Cross-system events are signals: wave_started, wave_ended, enemy_died,
  enemy_leaked, boss_killed, boss_leaked, path_extended,
  tower_damaged_enemy(tower_id, tower_type, unit_id, unit_tags, amount,
  damage_tag).
- Rendering is out of scope except for placeholder visuals and explicit UI
  hooks. Do not add features that are not in the spec; when the spec is
  ambiguous, choose the simplest option and list it as an assumption.

WORKFLOW
1) Restate your understanding and list assumptions.
2) Propose the file layout.
3) Implement.
4) Write the tests specified.
5) Finish with a summary: what is done, assumptions made, open items.
```

## Prompt 1: Path growth (consolidated)

```
TASK
Implement the path generation and growth system. If a prior version
exists, refactor it rather than rewriting, preserve the public interface
where possible, and explain every change.

WORLD
- Sparse Dictionary-based hex grid, axial coordinates (q, r), 6 directions.
  No fixed size or bounds anywhere.
- The path is an ordered Array of hexes. Index 0 is the player's base; the
  last index is the spawn hex.
- Terrain is BUILDABLE or BLOCKED (rubble, dumpsters; target about 12% of
  hexes). Terrain is generated lazily in chunks (CHUNK_RADIUS = 8),
  deterministically from run seed + chunk coordinates, independent of
  generation order.
- Players may build on any non-path, BUILDABLE hex within hex distance 2 of
  a path hex.

GROWTH RULES
1. TRIGGER: Growth happens once after each boss wave, only when the boss is
   dead and no enemies are alive, during the intermission. A leaked boss
   ends the run, so growth never follows a leak.
2. ORIGIN: Extend from the spawn end only. The old spawn hex becomes an
   ordinary interior hex; the new final hex becomes the spawn. Existing path
   hexes never change.
3. SIZE: Each extension adds MIN_EXT to MAX_EXT hexes (12 to 20). No cap on
   total path length.

HARD CONSTRAINTS (reject any candidate that violates one)
H1. Single non-branching chain; no hex visited twice.
H2. CORNER SPACING: at least 2 non-corner hexes between any two consecutive
    corners (a corner is a hex where direction changes). Count straight
    hexes since the last corner of the EXISTING path when validating the
    join. Allowed turns: +/-60 and +/-120 degrees.
H3. SEPARATION: no new path hex may be adjacent to a non-consecutive path
    hex, so at least 1 buildable hex always separates distinct stretches.
H4. NO DEAD ENDS / NO SELF-TRAPPING: after generating a candidate, run a
    lookahead confirming a valid next extension exists from the new spawn
    end. Reject candidates that fail.
H5. Never use BLOCKED hexes, tower-occupied hexes, or hexes reserved by a
    pending preview.

OVERLAP BONUS (deliberate)
- OVERLAP HEX: an unoccupied, buildable, non-path hex within distance 2 of
  path hexes from at least two DISTINCT STRETCHES (path indices differ by
  at least PASS_GAP = 6).
- Each extension must create at least OVERLAP_MIN = 3 new overlap hexes,
  preferably 3 to OVERLAP_SOFT_MAX = 8 (more is allowed but scores lower).

GENERATION METHOD
1. Seeded RNG (run seed + extension index). Generate up to
   MAX_CANDIDATES = 200 random extensions, ensuring terrain chunks exist
   around each candidate and its 2-hex build zone (TERRAIN_MARGIN = 4).
2. Discard hard-constraint violators.
3. Score survivors: reward overlap count in range; penalize turn sequences
   matching either of the previous two extensions; lightly reward loops
   back toward older sections; penalize drift (new spawn end farther than
   MAX_DRIFT_FACTOR = 1.5 times the average extension length from the
   center of the existing path's bounding area). Drift is a score penalty,
   not a hard rule.
4. Pick randomly (seeded) among the top 3.
5. Fallbacks, in order: lower OVERLAP_MIN to 0; reduce MIN_EXT and MAX_EXT;
   if still none, skip growth and log an error. Never relax hard constraints.

PREVIEW
- Generate the next extension PREVIEW_LEAD_WAVES = 2 waves before it
  commits (during wave 8 for the wave-10 boss). The committed extension
  MUST equal the previewed one; never regenerate at commit time.
- Reserve previewed hexes, and any hex that is in the build zone ONLY of the
  previewed extension, immediately. No pre-building. No ALLOW_PREBUILD flag.
- UI hooks: expose ghost_path_hexes, preview_overlap_hexes (new overlap
  hexes in the preview, drawn brightly) and persistent_overlap_hexes (all
  current overlap hexes, drawn subtly). Keep them current as extensions
  commit and as towers are placed or removed. Rendering is out of scope.

CHUNK MANAGEMENT
- Never unload chunks containing path hexes, towers, or reserved hexes.
  Others may unload and regenerate deterministically.

OUTPUT OF A GROWTH OPERATION
new_hexes (ordered), corner_hexes, overlap_hexes, seed, candidates_tried,
relaxations_applied.

TESTS
1. 500 consecutive seeded extensions all pass validate_path (H1-H4).
2. Corner spacing holds across every join.
3. Each extension meets OVERLAP_MIN or logs the relaxation.
4. Same seed + same state gives identical results.
5. Previewed extension equals committed extension.
6. Extensions never use tower-occupied, blocked, or reserved hexes.
7. The lookahead never allows a state with no valid next extension.
8. Chunk generation is deterministic regardless of generation order.
9. No growth runs while the boss is alive or after a boss leak.
10. Reserved hexes reject tower placement.
11. persistent_overlap_hexes stays correct after placements, removals and
    commits.

TUNABLES: all numbers above as named constants in one file.
OUT OF SCOPE: path blocking, rendering, director, enemy behavior.
```

## Prompt 2: Towers and tech trees

```
TASK
Build the tower library as data-driven Resources plus the systems that
run them: tower definitions, upgrade trees, Corruption, Jank, and the
balance mechanics below. Implement in two stages and stop after Stage A
for review: Stage A is schema + all T1 and T2 nodes; Stage B is all
T3/T4 nodes.

PLACEMENT: one hex per tower, on a buildable non-path hex within distance 2
of the path and not reserved. Sell refund: 70% of total spent (tunable).

TREE RULES
- Every tower has T1 (base), T2 (shared), then a fork: REVEALED T3 -> T4
  capstone, or RIGGED T3 -> T4 capstone. Choosing one branch permanently
  locks the other for that tower.
- Costs: T2 = 0.6x base, T3 = 1.0x, T4 = 1.8x.
- REVEALED upgrades are paid in Offerings and add global Corruption
  (T3 +4, T4 +8).
- RIGGED upgrades are paid in Scrap and set that tower's Jank (T3 10, T4 25).
- Stat tiers add roughly 40-60% power each; capstones add a unique
  mechanic, not just numbers.

CORRUPTION (global, 0-100)
- Revealed towers deal +0.25% damage per point.
- 50 or more: at each wave start, 10% chance one random Revealed tower
  misfires (disabled that wave). 75 or more: 20%.
- At 100: each wave a hostile Rogue Entity spawns on the path and walks to
  the base (leaking it costs 2 lives; killing it yields 10 Offerings).
- Penance: pay 40 Offerings to remove 5 Corruption.
- Compliance Officer aura (see enemies) negates the damage bonus nearby.

JANK (per Rigged tower, percent)
- At each wave start, each Rigged tower jams with probability Jank% (cap
  60) at a random moment, disabled for 10 s.
- Maintenance: pay 15 Scrap to lower one tower's Jank by 10.

ANTI-ALL-IN MECHANICS
- Cost escalation: each tower of a type you already own raises the cost of
  the next of that type by 10%.
- Variety bonus: each tower gets +3% damage per distinct tower type within
  3 hexes (max +12%).
- Entangled: enemies slowed or rooted by the Tentacle Storm Drain take
  +25% damage from Gutter Ritual Circle pulses.
- Armor Shred: each stack adds +5% damage taken from all sources (max 5
  unless a node says otherwise).

DETECTION: Cloaked enemies can't be targeted until revealed. Detectors:
Chanting Choir and Watcher (within range), Gutter Ritual Circle (pulse
reveals those hit for 3 s).

TOWERS (cost, range in hexes, damage, rate, targets)
1 hexed_nail_gun: 50, 3, 8 Kinetic, 2.0/s, Ground+Air, single target.
  T2 rapid_cycling: +30% fire rate.
  REVEALED whispering_nails: homing; 25% of each hit ignores resistances.
    -> nails_that_remember: each nail returns for a second hit at 50%.
  RIGGED drone_feeder: +40% fire rate, never reloads.
    -> pneumatic_belt_rig: 5-shot bursts; +50% damage vs Armored.
2 chanting_choir: 70, 2, 3 Psychic per member per s (starts with 3
  members), Ground only; damage scales linearly with members; detects.
  T2 deeper_harmony: +2 members.
  REVEALED dissonant_hymn: stacking Fear (max 5; -6% speed and +3% damage
    taken per stack).
    -> the_unspoken_verse: enemies at 5 stacks flee backward 2 s (once per
    enemy per 10 s).
  RIGGED bullhorn_array: +1 range; can hit Air.
    -> jammer_choir: stuns Air and Cybernetic enemies 1.5 s every 8 s;
    interrupts Hacker channels in range.
3 gutter_ritual_circle: 80, 3, pulse 25 Corrosive every 2.5 s on target +
  ring 1, Ground only; detects (see above).
  T2 wider_circle: also hits ring 2 at 50%.
  REVEALED ichor_bloom: each pulse leaves a 4 s puddle, 8 Void/s.
    -> maw_beneath: every 12 s a maw kills non-Tank, non-Boss Ground units
    under 30% max HP in the pulse area.
  RIGGED propane_pulse: +40% pulse damage, knocks back 1 hex along the
    path (not Bosses).
    -> chain_detonator: pulse kills explode for 40% of the victim's max HP
    in radius 1; chains.
4 tentacle_storm_drain: 60, 2, 4 Kinetic/s, Ground only; 35% slow aura;
  roots target 1.5 s every 8 s; applies Entangled.
  T2 more_grates: +1 target, slow 45%.
  REVEALED deep_grasp: root 2.5 s and drag 1 hex backward (not Bosses).
    -> leviathan_awakens: every 25 s a sweep hits all enemies in range +2
    for 120 Void and roots 1 s.
  RIGGED flood_pump: 40% slow puddle on path hexes within radius 1; wet
    hexes conduct Electric.
    -> live_wire_flood: flooded hexes deal 12 Electric/s.
5 watcher_in_the_billboard: 120, 6, 90 Void, 1 shot per 4 s,
  Ground+Air, targets highest-HP enemy; detects.
  T2 dilated_pupil: +2 range, +20% damage.
  REVEALED gaze_of_unmaking: ignores shields and 50% of armor; marks target
    (+15% damage from all sources for 6 s).
    -> the_eye_opens: every 4th shot adds 12% of target max HP as Void
    (Bosses 4%).
  RIGGED rooftop_scope_array: +25% crit chance (2x damage).
    -> ad_hijack: each shot also confuses enemies within 1 hex (walk in
    reverse 1.5 s, not Bosses) and cancels Hacker channels.
6 rust_censer: 65, 2, DoT 6 Corrosive/s for 4 s, stacks to 3, each
  application adds 1 Armor Shred; Ground only.
  T2 heavier_incense: DoT +30%, duration 6 s.
  REVEALED plague_incense: on death, remaining DoT spreads to enemies
    within 1 hex.
    -> rust_communion: shred cap 8; shred counts double vs Cybernetic.
  RIGGED acid_sprayer: +1 range, +50% application rate.
    -> solvent_tank: shred cap 10; +100% DoT vs Armored; consumes 4 Scrap
    per wave and is disabled at 0 Scrap.
7 fever_shrine: 90, no attack; aura radius 2: +15% fire rate to towers in
  range (auras from multiple shrines do not stack).
  T2 more_candles: radius 3.
  REVEALED frenzy_rites: aura +30% fire rate; upkeep 4 Offerings per
    buffed tower per wave.
    -> ecstatic_vigil: every 20 s buffed towers fire at double rate 3 s.
  RIGGED server_rack_altar: +10% range; buffed towers can't be disabled or
    converted by enemies.
    -> mesh_network: replaces the flat buff with +6% fire rate per distinct
    tower type in the aura (max +30%).
8 the_congregation: 75, 2, summons up to 2 cultist blockers (60 HP, 2
  Kinetic/s) on path hexes in range; resummon 10 s after death. Ground
  enemies stop and fight blockers; Air ignores them.
  T2 bigger_flock: up to 3 blockers, +30 HP.
  REVEALED devoted: blockers explode on death for 40 Void in radius 1.
    -> martyrs_chorus: fallen blockers rise as ghosts for 8 s (10 Psychic/s).
  RIGGED picket_line: blockers get riot shields (+100% HP, -30% damage
    taken).
    -> union_strike: blockers taunt enemies in melee and slow them 30%.
9 tithe_box: 60, no attack; +4 Offerings per 5 s.
  T2 bigger_plate: +50% income.
  REVEALED blood_tithe: +50% income; +1 Corruption per wave per box.
    -> dark_patron: +10% of each wave's kill Offerings (max 3 boxes count).
  RIGGED scrap_collector: +25% Scrap from kills (max 3 boxes count).
    -> chop_shop: once per wave, free maintenance: -10 Jank on every Rigged
    tower within 3 hexes.

DATA REQUIREMENTS
- TowerData and UpgradeNode Resources; effects are named behaviors from a
  registry plus stat modifiers, so new nodes need no engine changes.
- All 9 towers x (1 T2 + 2 T3 + 2 T4) = 45 upgrade nodes, with ids as
  written above.
- Emit tower_damaged_enemy for every hit (the director needs it).

TESTS
1. Data validation: 9 towers, 45 nodes, all references valid, costs correct.
2. Branch lock: choosing a T3 locks the other branch.
3. Corruption/Jank accounting and thresholds.
4. Targeting: ground-only towers can't target Air; Cloaked can't be
   targeted until revealed.
5. Cost escalation, variety bonus, Entangled and Armor Shred math.
6. Deterministic headless combat sim for each tower vs a dummy enemy.
7. Stars Are Right and Corruption bonuses stack additively, not
   multiplicatively.
```

## Prompt 3: Enemies and bosses

```
TASK
Build the enemy library: 16 regular units (4 per faction), 5 bosses, the
ability components that power them, and leveling hooks. Stage A: schema +
ability components + all regular units. Stage B: bosses. Stop after Stage A
for review.

SCHEMA (UnitData Resource)
id, display_name, faction, cost, base_hp, speed (hexes/s), tags[],
resistances{damage_tag: multiplier}, abilities[], leak_cost (default 1),
scrap_value (default round(cost*0.5)), tier (always 1 for now).
Stats are scaled at spawn time by per-unit-type kill level (see below) and
then fixed for the unit's lifetime.

LEVELING
level = floor(sqrt(kills_of_this_unit_type / 10))
health_mult = 1 + 0.12 * level; speed_mult = min(1 + 0.02 * level, 1.25).
Kills are counted per unit id, across all factions. Bosses are not subject
to kill leveling.

ABILITY COMPONENTS (reusable, data-parameterized)
LeakSteal(offerings), SlowResist(pct), SpeedAura(radius, pct),
DeathBurst(effect), SpawnOnTimer(unit_id, interval, cap, release_on_death),
ShieldRegen(shield_hp, regen_delay, bypass_tags), RangedSuppress(range,
fire_rate_penalty), TowerDisable(interval, duration), Cloak,
AntiMagicAura(radius), TowerConvert(interval, channel, duration,
cleanse_rules), Heal(radius, hps, max_targets), Breakthrough (not held by
blockers; instantly kills blockers it touches).

FACTIONS AND REGULAR UNITS (cost / HP / speed / tags)
SWARM SYNDICATE (gig economy; cheap, fast, numerous)
 gig_runner      2 /  30 / 1.6 / Ground, Fast, Swarm. LeakSteal(5).
 scooter_courier 4 /  55 / 2.0 / Ground, Fast. SlowResist(50%). +25% speed
                 within 2 hexes of another courier.
 hype_influencer 6 /  70 / 1.0 / Ground, Support, Aura, Fragile.
                 SpeedAura(2, +20%). DeathBurst: allies in the aura get
                 +40% speed for 3 s.
 gig_van         9 / 220 / 0.9 / Ground, Spawner. SpawnOnTimer(gig_runner,
                 3 s, cap 4, release remaining on death).
IRON BOARD (few, elite, armored)
 security_contractor 4 / 100 / 0.8 / Ground, Armored. Kinetic 0.75.
 riot_shield_unit    6 / 140 / 0.7 / Ground, Shielded. ShieldRegen(120,
                     4 s, bypass Void and Corrosive).
 siege_walker       10 / 260 / 0.6 / Ground, Ranged, Armored. Kinetic 0.8.
                    RangedSuppress(3 hexes, -30% fire rate). Breakthrough.
 sponsor_mech       15 / 600 / 0.5 / Ground, Tank, Cybernetic, Armored.
                    Kinetic 0.7, Corrosive 1.3, Void 1.2, Electric 1.25.
                    Breakthrough. scrap_value 12.
HOSTILE TAKEOVER INC. (sabotage and anti-magic)
 taser_skirmisher   5 /  80 / 1.0 / Ground, Electric. Electric 0.5.
                    TowerDisable(every 6 s, 2 s, nearest tower).
 ghost_contractor   7 /  90 / 1.1 / Ground, Cloaked. Cloak.
 compliance_officer 9 / 160 / 0.8 / Ground, Anti-Magic, Support. Psychic
                    0.6. AntiMagicAura(2): negates Corruption damage bonus
                    for Revealed towers in radius.
 acquisitions_rep  12 / 140 / 0.7 / Ground, Hacker, Support. Electric 0.7.
                    TowerConvert(every 15 s, 3 s channel, 8 s duration,
                    target: highest-cost tower within 3 hexes). Converted
                    tower is disabled and enemies in its range gain +20%
                    speed. Cleanse: kill the Rep (instant), interrupt the
                    channel (Jammer Choir, Ad Hijack), or pay 50% of the
                    tower's base cost to cleanse early.
SKYLINE LOGISTICS (air supremacy, healing, spawners)
 courier_drone  2 /  25 / 1.8 / Air, Fast, Fragile. Electric 1.3.
 cargo_hauler   7 / 200 / 0.7 / Air, Armored. Kinetic 0.8.
 medic_drone    8 /  90 / 1.0 / Air, Healer. Heal(2 hexes, 15 hp/s, 3
                targets; not self or other medics).
 drone_carrier 18 / 450 / 0.6 / Air, Tank, Spawner. Kinetic 0.75, Electric
                1.3. SpawnOnTimer(courier_drone, 4 s, cap 6; spawns 2).

BOSSES (Boss tag; base HP scaled by boss_index n: HP = base * (1 + 0.3 *
(n-1)); every full cycle also shortens telegraphs and cooldowns by 15%)
 the_disruptor (Swarm Syndicate): HP 2000, speed 0.9, Ground.
   Network Effect: takes 8% less damage per living Swarm Syndicate unit
   within 3 hexes (max 50%), shown as icon stacks above its health bar.
   Surge Pricing: every 15 s, all Syndicate units get +30% speed for 4 s,
   telegraphed 1.5 s earlier by a siren. Counters: AoE, Choir, killing the
   swarm first.
 the_chairman (Iron Board): HP 4000, speed 0.4, Ground, Armored, Tank.
   Restructuring: phases at 100/66/33% HP. Each phase he resists one damage
   type at 0.4 (different from the previous), shown as a colored plating
   and icon over his health bar. At each transition he halts and is immune
   for 3 s while 2 riot_shield_unit escorts arrive. Forces damage-type
   diversity.
 the_raider (Hostile Takeover): HP 2500, speed 0.6, Ground, Hacker.
   Leveraged Buyout: every 20 s he starts a visible 4 s beam on the
   highest-cost tower within 4 hexes (countdown ring on the tower). If
   uninterrupted, the tower is converted for 10 s. Break it by killing the
   Bid Drone that spawns with the beam (150 HP), interrupting with Jammer
   Choir or Ad Hijack, or paying 50% of the tower's base cost.
 the_prime_dispatcher (Skyline): HP 3000, speed 0.5, Air, Tank, Spawner.
   Same-Day Delivery: every 15 s two supply pods (150 HP) land on path
   hexes near the boss, with a 2 s landing reticle, then open after 3 s to
   release 3 courier_drones each. Destroying a pod while it is opening
   cancels it. Stresses anti-air.
 the_holding_company (Coalition, mixed intervals): HP 5000, speed 0.45,
   Ground, Tank, Cybernetic. Switches between the four boss mechanics above
   at every 25% HP loss (random order, none repeated until all have been
   used), each at 70% effect. The active mechanic's faction logo is shown
   over the boss.

LEGIBILITY AND LOSS REPORT
Every ability needs a distinct telegraph hook (event + timing) so the UI
can show it. On game over, emit a LossReport: leaked unit id, path hex where
it leaked, wave number, damage by tower type in the last 10 s, and the
player's coverage per unit tag at that moment.

TESTS
1. Data validation: 16 regular units (4 per faction), 5 bosses, unique ids,
   all tags valid, all ability references valid.
2. Ability unit tests: Heal targeting, SpawnOnTimer caps, ShieldRegen
   bypass tags, TowerConvert channel/interrupt/cleanse paths, Breakthrough.
3. Boss tests: HP scaling formula, telegraph timing, immunities (flee,
   root, conversion), phase transitions, Holding Company mechanic order.
4. boss_leaked triggers game over; enemy_leaked reduces lives by leak_cost.
5. Leveling math and spawn-time snapshotting.
6. LossReport contains all fields.
```

## Prompt 4: Director (consolidated)

```
TASK
Implement the adaptive wave director. Pure logic (RefCounted), no
rendering. Include the headless simulator described at the end.

ROLE
Each wave, build an enemy roster by spending a budget on units, exploiting
gaps in the player's current defenses while staying fair, readable and
varied. The goal is a challenging wave, never an unbeatable one.

INPUTS
budget inputs (wave number, rubber_factor, cycle index), catalog (UnitData
with tags and resistances), coverage_profile (tag -> player damage per
second, MEASURED from tower_damaged_enemy events over the previous 2
waves), tower_branch_mix (Revealed vs Rigged counts), history (unit ids
used in last 5 waves), faction state, per-unit kill levels, player_state
(lives, leaks last wave), path layout summary.

SCHEDULE AND FACTIONS
- Waves 1-10 form interval 1 and so on; each interval ends with a boss.
- Intervals are numbered 1, 2, 3... Intervals 1-4 of each 5-interval
  cycle are FACTION intervals; interval 5 is a MIXED interval; then the
  pattern repeats. completed_cycles = floor((interval_index - 1) / 5).
- At the start of each FACTION interval, pick a faction by seeded RNG from
  the four factions, excluding the last faction used. Interval 1 of a run
  picks any faction. The unit pool is that faction's 4 units; the boss is
  that faction's boss.
- MIXED interval: the pool is all 16 units; faction weights are 1.0 for
  all; the boss is the_holding_company.

BUDGET
B(w) = (10 + 5w + 0.12 w^2) * (1 + 0.15 * completed_cycles) * rubber_factor
- rubber_factor starts at 1.0. If the player lost 2+ lives last wave,
  subtract 0.1; after 3 consecutive waves with 0 lives lost, add 0.1.
  Otherwise it moves 0.05 toward 1.0 per wave. Clamp to [0.8, 1.25].
- Stars Are Right waves: B * 1.10.
- Cap total units per wave at MAX_UNITS_PER_WAVE = 60; spend the excess
  budget as +1 level on chosen unit types (applied at spawn).

HARD CONSTRAINTS
1. Total cost never exceeds budget.
2. No unit type exceeds 50% of the budget.
3. From wave 6 onward, at least 3 distinct unit types.
4. Air units at most 40% of budget unless the active faction is Skyline.
5. Spawners and Healers: max 2 of each category per wave.
6. Don't exceed what the path can deliver in the wave's time window.

UNIT COST WITH LEVELS: effective_cost = cost * (1 + 0.03 * level).

SCORING (per pick)
score = (weakness_exploit / effective_cost) * diversity * faction_weight *
        noise
- weakness_exploit = sum over the unit's tags of 1 / (1 + coverage[tag]).
- diversity = 1 / (1 + uses in the last 5 waves), never 0.
- faction_weight: Swarm Syndicate favors Swarm/Fast (1.3-1.5); Iron Board
  Armored/Tank/Shielded (1.3-1.4); Hostile Takeover Hacker/Electric/
  Anti-Magic/Cloaked (1.2-1.5); Skyline Air/Spawner/Healer (1.3-1.4).
- noise: uniform [0.8, 1.2]. Choose by weighted random, never always the top.

COUNTER-BIASES (each multiplier at most 1.5x, never absolute)
- Revealed-heavy builds: raise Anti-Magic units. Rigged-heavy builds:
  raise Hacker and Electric units.
- Heavy Congregation use: raise Breakthrough units.
- Path awareness: favor Fast/Ranged on long exposed stretches; armored or
  spawner units for dense overlap zones; bias slightly toward units that
  exploit a newly previewed, still-undefended stretch.

ADAPTATION LAG: decide from coverage measured 1-2 waves ago. Idle towers
that haven't dealt damage contribute nothing (they stay "unscouted").

BOSS WAVES
- The boss is NOT bought from the budget; its stats come from boss_index.
  Escorts get 60% of B(w); the rest is withheld.
- Ignore the rubber-banding reduction on boss waves.
- Escorts must never make the boss fight unreadable or block its approach.
- The Intel preview names the boss and its signature mechanic.

TELEGRAPHING
Before each wave, provide an Intel payload: unit categories (for example
"armored ground, air") without exact counts, the active faction logo, boss
presence, and whether the wave is Stars Are Right. Show the next faction's
logo after each boss dies.

SPAWN ORDER
Tanks and Spawners first, Swarms spread through the middle, Support and
Healers inside the pack, escorts before the boss. Never release all Fast
units in the first second.

FAIRNESS CHECKS (after roster generation)
If every unit in the roster targets a tag where the player's coverage is
below MIN_COVERAGE, swap the lowest-value unit for one the player can
handle. Log the final roster, per-tag exposure, and per-pick rationale
(unit id, score, dominant reason).

TESTS
1. Budget, 50%, distinct-type, air-cap and spawner/healer caps hold across
   1,000 seeded rosters.
2. Faction schedule: no consecutive repeats, mixed interval every 5th
   interval, deterministic for a seed.
3. Counter behavior: low Air coverage raises Air picks; Revealed-heavy
   builds raise Anti-Magic units, within the 1.5x cap.
4. Leveled units cost more and appear less often.
5. Rubber-banding clamps and recovery.
6. Boss waves: escorts get exactly 60% of budget; boss HP scales by n.
7. Same seed + same inputs give identical rosters.

SIMULATOR
Headless harness that runs 100 waves against scripted player profiles
(all Nail Gun, balanced, all Revealed, all Rigged) with synthetic coverage
and prints per-wave rosters and exposure to CSV. Use it to check that no
profile is trivially safe or trivially punished.

TUNABLES: every number above as a named constant in one place.
```

## Assumptions to check

1. **Corner spacing** means at least 2 non-corner hexes between corners.
2. **The boss is no longer bought from the budget.** This replaces the earlier 40% rule: escorts get 60% of the wave budget, because boss stats scale by boss index and a budget cost would be ill-defined.
3. **Towers have no HP.** Enemies disable, suppress, or convert them instead.
4. **Currency split:** Revealed upgrades cost Offerings (competing with new builds); Rigged upgrades cost Scrap (earned from kills). Worth checking in the simulator.
5. **Anti-all-in additions:** 10% cost escalation per same-type tower and a variety bonus. These are new; cut them if you'd rather rely on the director alone.
6. **Faction picks** are random with no consecutive repeats, including across the mixed interval.
7. **Leak cost** defaults to 1 life per enemy, with a per-unit field if heavy units should cost more.
8. **All numbers are placeholders**, meant to be tuned with the simulator.
