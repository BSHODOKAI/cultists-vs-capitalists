# Balance & Pacing Test Plan

*Companion to ROADMAP sections 7 to 13. Goals: get the difficulty curve, scaling, and boss timing right; keep the game engaging; and prove out tower unlocks without letting the director punish or starve the player. All numeric thresholds below are proposed starting points to confirm or change, not settled targets.*

---

## 1. Goals and Non-Goals

**Goals**

1. Find what causes the late-run spiral and decide whether it is a designed wall or an accident.
2. Shape the death curve so it rises smoothly and readable by the player.
3. Choose the boss interval (and related cadence) based on data.
4. Measure engagement, not just survival.
5. Prove that tower unlock gating cannot trap the player, in either direction: holes the director exploits, or niches the director starves.

**Non-goals:** new content, new factions, final balance values for meta-progression (that follows once the curve is stable).

---

## 2. Design Targets to Confirm

These are the questions the experiments answer. Fill in the middle column before the first experiment runs, or accept the proposals.

| Player type | Proposed target for typical run end | Proposed shape |
| --- | --- | --- |
| New player (first few runs) | Waves 15 to 20, after one or two bosses | Dies to something understandable, not to a cliff |
| Competent player | Waves 30 to 40 | Reaches the Coalition boss in most runs if the interval is shortened |
| Expert / optimized build | Beyond the Coalition interval, ends at a visible wall | Death rate rises steadily, no single-wave jump |

**Other targets to set:**

- Target real-time run length in minutes at typical play speed.
- Acceptable early-wave loss rate for a new player (proposed: under 5 percent of new-player runs lost before wave 10).
- Whether the first boss should be a milestone or a wall for each player type.

---

## 3. What to Measure

**Difficulty and curve**

| Metric | Definition | Why it matters |
| --- | --- | --- |
| Wave-of-death distribution | Histogram of the wave each run ended on | Shows the median and the tails |
| Hazard rate | Chance of dying at wave W given the run reached W | The key cliff-versus-slope metric: a smooth rise is healthy, a sudden jump is a cliff |
| Kill depth | Average distance along the path where enemies die | A leading indicator: it shifts toward the Sanctum before leaks begin |
| Leak profile | Leaks and lives lost per wave | Shows when pressure becomes real |
| Economy-to-threat ratio | Player income per wave against total enemy effective health per wave | Detects the case where enemy strength compounds while rewards stay flat |
| Scaling term contribution | How much each scaling term (budget ramp, kill-leveling, level floors, bonus levels past the unit cap, Rogue levels) contributes to total pressure growth | Identifies the cause of the spiral |

**Pacing and bosses**

| Metric | Definition |
| --- | --- |
| Bosses seen per run | Count of boss waves reached |
| Path growths and objectives per run | How many of the game's key decisions a run contains |
| Percent of runs reaching the Coalition boss | Whether the finale is reachable |
| Boss kill time and boss-wave leaks | Whether bosses feel like fights |
| Deaths within two waves after a boss | Whether bosses are milestones or walls |
| Run duration in minutes | Real-time length per player type |

**Engagement**

| Metric | Definition |
| --- | --- |
| Decisions per intermission | Count of meaningful actions: builds, upgrades, selling, Penance, Maintenance, Rite draws, claims |
| Empty intermissions | Intermissions where the player spent nothing and did nothing |
| Speed-up usage | Share of time at 2x and 3x, a proxy for waiting |
| Build diversity | Entropy of tower mix across runs |
| "I know why I died" rate | Self-reported in playtests |

**Director fairness**

| Metric | Definition |
| --- | --- |
| Tag exposure share | Share of enemy budget spent on each tag per faction interval |
| Starvation index | Drop in exposure to a tag after the player adds a tower that answers it, compared with the same seed and build without it |
| Unanswerable-roster count | Waves containing a unit that no available tower can damage |
| Fairness swap rate | How often the director's fairness swap triggers |

---

## 4. Test Harnesses

A layered approach, from cheapest and most repeatable to most human.

1. **Headless director simulation.** Extend the existing director simulator so it can run a full run's worth of waves against a synthetic player and emit all metrics above. It should accept parameters for interval length, scaling terms, and unlock state. *Assumption: the simulator may today cover roster generation only. If so, a headless combat resolution step is needed for hazard and kill-depth metrics.*
2. **Bot archetypes.** Scripted players that run the full game headlessly under a fixed seed set:
   - Balanced builder (diverse towers, uses Penance and Maintenance)
   - Monoculture, one version per damage tag
   - Rite gambler (draws Rites aggressively, rides the Reckoning)
   - Turtle (ignores objectives, stacks defenses)
   - Naive new player (spends slowly, mixed or poor choices)
3. **Deterministic replay of real runs.** Record the developer's and friends' command logs. Replay them for regression (same seed, same result), and replay the same build order under changed director parameters to see how a real build fares.
4. **Structured human playtests.** A short script and a short survey (section 6), with the same instrumentation as the bots.

**Seeds:** use a fixed seed set (proposed: 100 to 200 per cell for simulations, 5 to 10 for human playtests) so before-and-after comparisons are fair.

---

## 5. Experiments

### Phase 0: Baseline

Freeze the current build. Run every bot archetype across the seed set and record all metrics. This is the "before" every later phase is compared with.

**Exit:** a saved baseline report (wave-of-death histogram, hazard curve, scaling contributions, kill depth by wave).

### Phase 1: Locate the Spiral

**Hypothesis:** the wave-30-plus spiral comes from several scaling terms compounding while player rewards do not keep pace.

**Method:** an ablation matrix. Run the baseline with exactly one term flattened or removed at a time.

| ID | Variable | What to look for |
| --- | --- | --- |
| 1.1 | Flatten the late-wave budget ramp | Does the hazard curve move right? |
| 1.2 | Cap or flatten kill-leveling | Same |
| 1.3 | Remove the interval level floor | Same |
| 1.4 | Remove bonus levels past the unit cap | Same |
| 1.5 | Remove Rogue Entity compounding | Same |
| 1.6 | Disable rubber-banding | Does it mask or cause the spiral? |
| 1.7 | Disable debuff events | Same |
| 1.8 | Scale kill rewards with enemy level | Does the economy-to-threat ratio stabilize? |

**Decision rule:** rank the terms by how much each one shifts the median wave-of-death and the hazard curve. The top one or two are the tuning priorities. Record whether the spiral looks designed (each term serving a purpose) or accidental (terms compounding unintentionally).

### Phase 2: Shape the Curve

Tune toward the targets in section 2, changing one family of terms at a time.

**Pass criteria (proposed starting thresholds):**

- Hazard rate rises without any single wave-to-wave jump larger than about three times the average of the previous three waves.
- Kill depth drifts toward the Sanctum gradually, giving the player warning before leaks.
- Economy-to-threat ratio declines steadily rather than collapsing.
- Each archetype's median lands in its target band.

### Phase 3: Boss Interval Sweep

**Variable:** interval length of 10, 8, 6, and 5 waves, with event cadence scaled proportionally and wave-number-based guards re-anchored to boss index.

**Method:** run all archetypes across the seed set for each interval length.

**Compare on:**

- Path growths and objectives per run
- Percent of runs reaching the Coalition boss
- Faction exposure per run
- Run duration in minutes
- Deaths within two waves after a boss
- Where the spiral begins in terms of boss index (the spiral should not simply move to the same boss count)
- Whether short intervals make the director's two-wave adaptation lag too large a share of each faction's stay

**Decision rule:** choose the interval that gets competent players to the finale at a comfortable run length, without making early bosses feel like walls. If results are close, favor the one that produces more path growth and objective decisions per run.

**Variant:** also test keeping 10 waves with a mid-interval beat (an elite wave or objective event at wave 5).

### Phase 4: Boss Fights

For each of the five bosses, measure kill time, escort handling, leaks during the fight, and tower disruptions caused by the boss.

- Check that boss health scaling by boss index stays sensible when bosses arrive more often.
- Check that the telegraph and cooldown shortening per cycle does not become too aggressive if cycles complete faster in waves.
- Check that the Coalition boss behaves as a finale and not as another faction boss at higher health.

### Phase 5: Director Behavior and Fairness

| ID | Test | Pass criteria (proposed) |
| --- | --- | --- |
| 5.1 | Monoculture versus balanced | Balanced bots reach a later median wave than monoculture bots, by a clear margin; monoculture stays viable but riskier |
| 5.2 | Unanswerable-roster scan | Zero waves contain a unit that no available tower can damage |
| 5.3 | Fairness swap rate | Triggers rarely in balanced runs, more often in monoculture runs |
| 5.4 | Faction signature check | Each faction wave includes its signature tag at a meaningful share |
| 5.5 | Early-wave safety | New-player bot loses fewer than 5 percent of runs before wave 10 |

### Phase 6: Tower Unlock Safety (the Trap)

The two failure modes to prevent are **hole punishment** (the player lacks an answer to something the director fields) and **niche starvation** (the director stops fielding what the newest tower answers).

**6a. Threat and answer completeness (static check).** Build a table of every enemy tag and special ability, the first wave at which each can appear, and the towers that can answer it. Assert that, for any proposed starting roster and unlock order, every threat has at least one available answer before it can appear. Items to check explicitly: Cloaked units and detection, Air units and air-capable towers, Healers, Spawners, Shielded units, Anti-Magic auras against Revealed damage, and Hackers that convert towers.

**6b. Starvation A/B.** Same seed, same build order, with and without the newest tower. Compare the roster's share of the tag that tower answers over the next several waves.

- Pass (proposed): the tag's share drops by no more than about a quarter relative to the baseline, and never below the faction's signature floor.

**6c. Director variants.** Run 6b and Phase 5 against each of these variants of counter-pressure:

| Variant | Description |
| --- | --- |
| A | Current behavior |
| B | Counter-pressure scales with how concentrated the player's coverage is, not with presence |
| C | "Honeymoon" window: coverage from towers built in the last few waves is hidden from the director |
| D | Faction signature floors: each faction guarantees a minimum share of its signature tag |
| E | "Showcase wave": after a new tower is built, the director includes the tag it answers once |
| F | Combinations of B with C, D, or E |

Compare on starvation index, the monoculture-versus-balanced ordering from 5.1 (it must be preserved), and new-player survival.

**6d. Worst-case faction order.** For each candidate starting roster, run the first three intervals under every legal faction order. Find the worst order for that roster.

- Pass (proposed): the new-player bot survives to the end of the first three intervals in a high share of orders, and no single order is dramatically worse than the rest.

**6e. Unlock order sweep.** Run candidate unlock orders against each bot archetype and count "regret events":

- A death within a few waves of an unlock.
- A new tower sitting idle for several waves after being built.
- A wave in which the player holds no answer to something the director fields.

Choose the order with the fewest regret events.

**6f. Human validation.** Friends play runs with unlock gating on. Instrument the same regret events and ask: "Did the game ever punish you for a choice you thought was good?"

**Gate:** do not ship tower gating until 6a, 6b, and 6d pass. If they do not pass, prefer gating Creeds, upgrade nodes, or codex entries instead of base towers (see ROADMAP section 13).

### Phase 7: Meta-Layer Pacing (later)

Only after Phases 1 to 6 are stable.

- **Payout curve:** time to first unlock should be short for a new player (proposed: within the first two runs), and later unlocks should not require deep runs.
- **Creed balance:** run every Creed across the bot archetypes and check that none dominates or is a trap.
- **Fine Print calibration:** check that payout multipliers match the actual extra difficulty.
- **The Ledger:** confirm debt cannot become an unrecoverable spiral across runs, mirroring the in-run Reckoning debt reset.

---

## 6. Engagement Playtest Protocol

**Session:** two or three runs per player, same seed set for everyone, with the instrumentation from section 3 enabled.

**Questions after each run**

1. Did you know why you died?
2. Was there a point where you felt you had nothing to decide?
3. Was there a point where the game felt unfair?
4. Which tower did you rely on, and which did you ignore?
5. Did any boss feel too easy or too hard?

**Flags for review:** any run where a player dies within a few waves of a new unlock, any run with several empty intermissions in a row, and any run where speed-up usage is nearly constant.

---

## 7. Regression Guardrails

- **Determinism check:** the same seed and command log must produce the same result after every change.
- **Curve smoke test:** a small seed set run automatically on each change, alerting when the median wave-of-death or the hazard curve shifts by more than a set amount (proposed: about 10 percent).
- **Balance snapshot:** keep the baseline report and each accepted change's report in the repository so changes can be compared over time.

---

## 8. Experiment Log Template

| ID | Change | Seeds and archetypes | Result | Decision | Date |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |

Record every experiment, including ones that failed. Several of the decisions here (interval length, which terms to flatten, which director variant to use) depend on seeing the failures.

---

## 9. Suggested Order

1. Phase 0 baseline and Phase 1 ablation. Everything else depends on knowing what drives the spiral.
2. Phase 2 curve shaping and Phase 3 interval sweep, which interact and are best run together.
3. Phase 4 and Phase 5 once the curve and interval are stable.
4. Phase 6a (the static check) can run at any time, since it needs no simulation, and is worth doing early.
5. Phase 6b to 6f only if tower gating is still wanted.
6. Phase 7 when meta-progression work begins.

---

## 10. Risks and Caveats

- Bots are not humans. Use them to find large effects and regressions, and use human playtests to judge feel.
- Rubber-banding interacts with nearly every curve metric and can hide a problem. Run important experiments with it on and off.
- A metric can be tuned at the expense of fun. A smooth hazard curve is necessary, not sufficient; the engagement measures guard against it.
- Small friend groups produce small samples. Treat human results as directional.
