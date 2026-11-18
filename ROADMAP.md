# ROADMAP — Ideas to Ponder

> **These are not commitments.** This file is a parking lot for forward-looking ideas so the
> timeless reference in [`DESIGN_BIBLE.md`](DESIGN_BIBLE.md) stays clean. Nothing here is
> scheduled, promised, or scoped. Treat every line as a conversation starter.
>
> When an idea here becomes real design, move its **flavor** into the design bible and its
> **mechanics** into `AGENTS.md`.

---

## 1. Player-Side: More Cults, More Occultisms

The current cult is Lovecraftian. The design's *shape* (see Design Bible §8) is built to host
other traditions without losing the game's identity. Ideas to think about:

- **What traditions fit the "scrappy underdog repurposing junk" mold?** Candidates worth pondering:
  folk-saint / Santa Muerte devotionalism, hoodoo and rootwork, Norse runecraft, Theosophy and
  séance culture, urban shamanism, cargo-cult millenarianism (the game already has a cargo-cult
  windfall event — is that a seed?).
- **What is the shared meter called per cult?** Corruption/Rites/Reckoning is the Lovecraftian
  framing. Another cult might call the same bargain by a different theological name. Question to
  settle before building: **generalize Corruption behind a per-faction abstraction**, or clone it
  with new flavor? (Generalizing is cleaner; cloning is faster but risks drift.)
- **How does the cult choose at run start?** A faction-select screen, a seed-driven assignment, or
  an unlock progression?
- **Do cults share towers or have their own rosters?** Shared roster = less content, less identity.
  Own roster = the full tower pipeline (`data/towers`, upgrades, models, icons, cues) per cult.
- **Do enemy factions react differently to different cults?** The Wave Director already
  counter-picks by tag; a different cult presents a different coverage profile for free.

---

## 2. Corporate-Side Expansion

- **A fifth corpo faction** — the modern-capitalism angles not yet used: surveillance/social media,
  pharma, creditors/debt collectors, regulators, privatized utilities, media/propaganda. Each wants
  a distinct combat identity (Design Bible §8).
- **Sub-brands and subsidiaries** — bosses as *executives* invites named individuals and
  departments under the existing factions. Cheap way to add character without a new faction.
- **Event-deck growth** — the run-events deck is already a shuffled, non-repeating rotation
  (§8 of `AGENTS.md`). More buff/debuff cards, especially ones that reference corpo activity
  ("Hostile Audit", "New Subscription Tier", "Regulatory Capture"). Keep debuffs **soft** — no
  instant life loss.

---

## 3. Systems the Bible Now Implies

These are consequences of writing the bible down, not features anyone requested:

- **A per-faction "bargain" interface** — if more cults arrive, Corruption/Rites/Reckoning likely
  needs to become a pluggable shape so each cult supplies its own names and flavor without
  duplicating logic.
- **A content-lint for theme** — a lightweight check (a test, a skill step, or a checklist app) that
  flags new content failing the Design Bible §9 pre-flight (name pattern, emoji/register in
  strings, missing "bill" on a power-granting node). Optional, but it would stop drift.
- **Faction identity in the data layer** — today factions are mostly strings + colors. If cults
  multiply, a `FactionData` resource (name, voice line, palette, altar/UX flavor) would centralize
  what's currently spread across constants.

---

## 4. Presentation Polish

Long-term, the visual/audio layer is placeholder-driven (procedural meshes, icons, and sounds).
Ideas to ponder — **not** a mandate to replace systems that work:

- Authored 3D meshes for towers/units/bosses that keep the existing silhouette rules
  (towers < 1.5 height, units grounded and facing travel).
- A **title/menu identity pass** — the menu is a plain centered VBox; the theme is strong enough to
  carry a more atmospheric title screen.
- Music/ambience that sits the *corporate* and *occult* registers against each other.
- Localization-ready strings (the two-register voice in Design Bible §4 should survive translation).

---

## 5. Open Questions to Settle Before Big Moves

- **How central is the Corruption bargain?** If it's the game's thesis (the bible argues it is),
  new cults and systems should orbit it. Confirm.
- **Is "the cult" ever the player's *enemy*?** Rogue Entities already imply the player's own rot can
  turn on them. Worth pondering whether a future mode leans into that.
- **Multiplayer?** Out of scope here, but if co-op is ever considered, the faction/cult split and
  the deterministic seeded systems are assets — note it and move on.
- **Pacing:** What are the target waves and minutes for new and experienced players? Where should a smooth rise become an intentional endless-mode wall? Verify against the current build (§§7, 14).
- **Progression:** Should any unlock gate content the Director can field? Keep base-tower gating deferred until threat coverage is proven (§13).
- **Competition:** Is sharing a seed with friends enough, or is a leaderboard worth building?

---

## 6. Air Control: Beyond the Dead Air Altar

`dead_air_altar` (see `AGENTS.md` §5) shipped as the first tower to reach **Air** at all — a
continuous slow aura with an Electric "Grounding" synergy. Two further air-control designs were
scoped and deliberately deferred:

- **Skyline Anchor — hard-CC anti-air.** A bolas / harpoon / net emplacement that pins drones:
  periodic `root` / `stun` and, most interestingly, **path displacement against Air** (dragging
  drones *backward* along the skyway). Displacement against air is engine-supported today
  (`CombatUnit.displace_along_path` carries no ground restriction) but no tower uses it —
  `propane_pulse` and `deep_grasp` are both ground-only. Subject to the usual 3× DR budget and
  Boss immunity, so a boss fight is unaffected. Distinct niche: a burst "stop the swarm now"
  answer rather than an attrition slow.
- **Weather Modification Array — full hybrid air-control tower.** A flagship rig pairing a slow
  aura with a periodic AoE hard CC, branching Revealed (mass root, "the sky is commanded") vs
  Rigged (overvolted Electric static-stun), plus a Rite branch. Reuses the `dead_air_altar`
  groundwork (the `AIR_CONTROL` mode and grounding plumbing) and would be the most content-heavy
  option (7 nodes, new models / icons / cues).

Both were set aside so v1 could ship the smallest change that closes the air-control gap without
overlapping `tentacle_storm_drain` (ground-only control) or `jammer_choir` (stun byproduct).
Revisit if air ever needs a harder counter than a slow.



Addendum:

# ROADMAP Additions: Pacing, Run Identity & Meta-Progression

*Draft sections to append to ROADMAP.md, numbered 7 onward to follow the existing sections. Same rules as the rest of that file: these are ideas to ponder, not commitments. Names in quotes are working titles in the game's own voice.*

**Historical context:** This addendum predates the shipped pacing changes. Runs are endless; the intended audience remains the developer and close friends, so large content lifts (new factions, new cults) stay deferred.

---

## 7. Pacing: Difficulty Curve and Boss Interval

**Shipped:** the candidate A scaling changes and five-wave boss cadence, with the first boss still at wave 10 and boss HP anchored to wave number. See the [candidate experiments](tests/baselines/phase2_candidates.md) and [interval experiment](tests/baselines/interval_experiment.md). Those are historical measurements, not current human reach targets. Next is reliability and pacing verification (§14), not another tuning pass by default. The options below are retained as design history or future ideas.

**Ideas to ponder**

- **Shorter intervals (5 to 7 waves between bosses).** Path growth, objectives, and faction rotation all hang off the boss, so more bosses means more of the game's best decisions per run. The Coalition finale becomes reachable inside a normal run.
- **Keep 10 waves, add a mid-interval beat.** An elite wave, objective event, or director "audit" at wave 5 of each interval, so the long stretch stops being monotonous.
- **Variable interval length.** Short early (so new players see variety quickly), longer later.
- **Shape, not height.** The goal is a death curve that rises smoothly, so players can say why they died, rather than a cliff where income stops mattering. A spiral is acceptable as an endpoint; an unreadable one is not.
- **Fiscal framing as the unit of progress.** One interval is a **quarter**, one cycle is a **fiscal year**, and the Coalition interval is the **annual shareholder meeting**. Pacing a year to fit a typical run makes the framing real.

**Things that would need re-anchoring if the interval changes**

- Event cadence (currently every 3 to 7 waves).
- Early-wave guards pinned to fixed wave numbers (Cloaked withheld until after the first boss, first objective, no event on the first boss wave).
- The director's adaptation lag, which becomes a larger share of each faction's stay.
- Boss scaling and telegraph shortening, which should key off boss index rather than wave number.

**Open questions**

- Is the spiral a designed wall or an accident of compounding scaling terms? (The test plan isolates this.)
- What run length in real minutes is the target?

*Companion: Balance & Pacing Test Plan.*

---

## 8. Run Identity: "Creeds"

Every run currently starts identically: same resources, same full roster, same options. A **Creed** is a starting rule set chosen before wave 1 that changes the shape of the bargain for that run.

**Examples to ponder**

- A Creed that locks out the Rigged branch in exchange for a higher Corruption ceiling.
- A Creed that starts rich in Scrap and poor in Offerings.
- A Creed that opens with Rites available at a higher starting Corruption.
- A Creed that favors support and blocker towers at the cost of raw damage.

**Why it is attractive**

- Data-driven and cheap compared with new factions or rosters.
- Forces a build identity per run, which directly attacks run sameness.
- A low-cost way to learn which rule changes players enjoy before committing to full new cults (see section 1).
- Slots naturally into meta-progression as an unlock (section 9).

**Guardrail:** a Creed must change the bargain, not just hand out power. Every Creed should name what it costs.

**Open questions**

- How many Creeds before the choice becomes noise (3, 5, 8)?
- Can Creeds be combined, or is it strictly one per run?

---

## 9. Meta-Progression: Unlocks, "The Ledger", and "Fine Print"

**Design principles**

1. **No unbought power.** Permanent flat bonuses (global damage, extra lives) remove the bargain and are off-theme. Prefer breadth over raw power.
2. **Reachable within the real run length.** Unlock conditions must be achievable at the length runs actually last (see section 7).
3. **Leaderboard-fair.** Seeded runs should remain comparable between friends.

**Ideas to ponder**

- **Firsts and codex.** The existing content already forms a checklist: upgrade nodes, event cards, bosses, units, objectives. Completing a first (first Reckoning survived, first capstone on a branch, first Coalition boss) unlocks Creeds, Fine Print clauses, or codex entries. Codex entries double as intel for the player.
- **"The Ledger" (the thesis as meta).** At run start the player may borrow: a stronger opening in exchange for the next run starting with Reckoning pre-charged. Debt carries across runs and must have a reset rule so it cannot become a permanent spiral (mirror the in-run Reckoning debt reset).
- **Corporate memory (opt-in).** The director starts the next run already leaning against the player's most-used tags. Paired with the Dossier (section 10) it reads as an opponent with a file on you.
- **"Fine Print".** Optional difficulty clauses chosen before a run (larger budgets, elite affixes, fewer lives) that multiply score or payout. Unlocked progressively, in the style of ascension levels.
- **Sanctum hub (low priority).** A basement that grows into a cathedral as the flock grows; a presentation home for the other unlocks rather than a source of power.
- **Tower provenance (low priority).** Heavily used towers earn a name or scar as a late mastery layer.

**To avoid:** a permanent "+lives" or "+damage" track, and any payout so steep that deep runs are required to make progress.

**Open questions**

- What is the meta currency, and what is its in-fiction name?
- How many runs should it take a new friend to earn their first unlock?
- Should unlocks gate towers at all? (See section 13; the answer is probably not at first.)

---

## 10. Director Legibility: The "Dossier"

The adaptive director is the game's most distinctive system, and today it is invisible. A death caused by the director learning from the player reads as bad luck.

**Ideas to ponder**

- **Post-run Dossier.** A debrief section listing what the corporation learned about the player and what it did about it, for example: "No coverage against Cloaked; Ghost Contractors prioritized."
- **Live coverage readout.** A small intel view of the player's current coverage by enemy tag, so the player can see the gap before the director exploits it.
- **Events stay hidden.** Legibility applies to the director's reasoning, not to the event deck. Event cards remain unadvertised, in keeping with the design bible.

**Risks**

- Showing the player the director's formula makes it gameable. The Dossier should explain outcomes after the fact, and the live readout should show the player's own coverage, not the director's scoring.

---

## 11. Scoring, the "Quarterly Report", and Tower Stats

**Primary score:** quarters survived (waves reached remains the underlying number). Secondary figures in the debrief: Reckonings survived, peak Corruption, leaks, bosses slain, cause of loss.

**Per-tower stats, shown as two numbers**

- **Contribution:** damage, kills, and damage per resource invested. For support and control towers, **attributed** contribution: damage taken by slowed or buffed enemies, bonus damage added by auras. Without attribution the four non-attacking towers always look worthless.
- **Bill:** what the tower cost the run in Corruption fed, Scrap spent on Jank, Rites drawn. This is the thesis as a statistic: a Rite tower may top the damage chart and also top the bill chart.
- Efficiency is compared within a role, not across the whole roster.
- Flavor: "Most Valuable Asset" and "Underperforming Asset, flagged for restructuring."

**Also useful for balance:** aggregated across runs these stats are pick rate, contribution, and bill data for tuning.

**Open questions**

- Should the debrief show seeds so friends can replay the same run?
- How is role defined for towers that straddle roles?

---

## 12. Mid-Run Bargains: "Pacts", "Subcontracts", and Enemy Affixes

- **Pacts.** After each boss (the same beat as path growth), offer one of three powers, each with a bill. A draft that shapes the build mid-run and counters the solved-meta problem.
- **Subcontracts.** At intermission the player may accept a larger wave budget in exchange for a payout. An optional bargain between waves with no new system.
- **Enemy affixes.** Elite modifiers ("Insured", "Outsourced", "Compliant") that give existing units new behavior without adding units.

**Guardrail:** debuffs and contracts stay soft; none should be an instant loss.

---

## 13. Tower Unlock Gating: Deferred, With Guardrails

Starting with a smaller roster would help onboarding and give early runs an arc. It also interacts dangerously with the adaptive director, in two ways:

1. **Hole punishment.** A gated roster leaves coverage gaps, and the director's job is to exploit gaps. A player without an answer to a threat the director can already field is simply losing.
2. **Niche starvation.** The director avoids what the player can handle. A player who unlocks an air-capable tower may find the director quietly stops fielding air, so the unlock appears to have been wasted.

**Principles to adopt before any gating**

- **No threat before its answer.** Maintain one table linking the first appearance of each enemy tag or ability to the towers that can answer it. The unlock schedule and the director's introduction schedule must both obey it.
- **Punish monoculture, not adoption.** Counter-pressure should scale with how concentrated the player's coverage is, not with whether it exists. A single new tower should not be able to make a whole enemy tag disappear.
- **Gate depth before breadth.** Prefer gating upgrade nodes, Creeds, Pacts, and codex entries over base towers; those cannot create coverage holes.

**Candidate mitigations to test**

- **Faction signature floors:** each faction's waves guarantee a minimum share of its signature tag.
- **Counter-bias saturation:** counter-pressure on a tag stops growing past a point.
- **"Honeymoon" window:** coverage from towers built in the last few waves is hidden from the director, so a new tower's niche appears at least once.
- **Showcase wave:** after a new tower is built, the director deliberately includes the tag it answers once.
- **Role-complete unlock pairs:** unlock towers so that no single unlock is the only answer to a threat.

**Status:** hold gating until the test plan's unlock-safety experiments pass.

---

## 14. Now / Next / Later (recommended order, not a commitment)

### Now — Run reliability and pacing verification

- Recheck the recorded Raider/Bid Drone stall (balanced bot, seed 4242, historically wave 20). If it reproduces, fix the helper lifecycle and add a wave-clear regression before taking a fresh seeded baseline. Track stalls separately from losses.
- Pair that baseline with a small human playtest: record time to first boss, first meaningful growth decision, and Coalition reach. Preserve the fast early economy. Only reopen tuning if completed runs show a repeatable problem.

### Next — Explain the run, then test whether geography changes it

1. **Quarterly Report + Dossier (§§10–11):** One post-run debrief using existing run logs and Director rationale. Start with wave reached, cause of loss, boss and Reckoning outcomes, and one or two evidence-backed explanations of enemy picks. Include direct tower damage and kills where reliably attributable. Defer indirect support attribution (auras, slows, blockers) and live coverage Intel: they answer different questions and need different accounting or presentation.
2. **Cooling Basin vertical slice (§16):** Keep the boss-growth preview, terrain seam, local objectives, operator signage, main-lane Skyline affinity, and confirmed attacker Intel in one playtestable package. Use the debrief to distinguish district-influenced faction assignment from adaptive unit counter-picks. Validate deterministic preview and commit across routes from day one, but defer secondary-lane affinity, the Greenbelt, and the Write-Off Belt until the main-lane slice proves the hook. Include the art and UI polish needed to read the slice; keep unrelated menu, music, and asset work separate.

### Later — Run identity, then something worth unlocking

- Try a small **Creeds** pack (§8). If players want more decisions between waves, try **Subcontracts** (§12) as the first mid-run bargain. Keep their implementations separate: one affects setup and the other affects wave locking. Don't build a shared framework before the ideas prove themselves.
- Group **Firsts, codex, and unlocks** (§9) as one progression package once there is meaningful content to unlock. Fine Print can follow. Defer base-tower gating, cross-run debt, and corporate memory.
- Keep new factions, bosses, events, affixes, and playable cults out of the Basin experiment. Revisit additional air-control towers only if playtests identify a roster gap rather than an Intel or balance problem.

---

## 15. Open Questions

Consolidated in §5.

---

## 16. Biomes: Follow the Corporate Roads Out of the City

**Design draft, not a production commitment.** The Sanctum stays in Urban Center. Post-boss path growth reveals the same metropolis's outskirts: where the city discards its equipment, whose land it takes, and what it drains to stay online. These are neighboring districts in one run, not map skins or mandatory stages. A run need not visit all of them.

### Districts and corporate operators

| District | Terrain kit and silhouette | Usual operator and pressure |
|---|---|---|
| **Urban Center** (existing) | Neon avenues, glass towers, loading courts, and cramped street lots. | **Iron Board** runs property security. Branded checkpoints and armor fit the district, but the opening faction roll stays unchanged. |
| **The Write-Off Belt** (Wastelander) | Rust-orange vehicle stacks, open salvage markets, patched settlements, buckled freight asphalt, and cleared work pads. Inhabited and improvised; people make a living from assets the companies wrote off but still claim. | **Swarm Syndicate** pays per recovered asset; **Iron Board** handles high-value repossessions. Dispatch boards, gig vans, and fast couriers make the freight road feel active. |
| **The Unceded Greenbelt** (Forest) | Dark canopy clusters, open glades, ranger cabins, survey stakes, and a readable, continuous firebreak. Survivalists and separatists live here; they aren't a new enemy faction. | **Hostile Takeover Inc.** buys access on paper and sends contractors to enforce it. Easement notices foreshadow cloak and tower disruption; the canopy itself never makes an enemy untargetable or grants Cloak. |
| **The Cooling Basin** (Desolate Landscape) | Chalk-white lakebed, dead intake canals, and immaculate cooling works that still hum. Where the Belt is crowded with reused equipment, the Basin is empty because extraction is still running. | **Skyline Logistics** supplies a water-starved data campus by air; **Iron Board** guards the intake works. Drone pads marked `SURFACE DELIVERY SUSPENDED` foreshadow the air threat without creating a terrain rule. |

**Coalition:** a joint enforcement order, not a biome. Companies own different pieces of the same corridor. Preserve the existing mixed interval and Holding Company boss even when the ground has a clear operator.

### Objectives: local landmarks, familiar rules

Use the existing three mechanical kinds in the first pass. Give each district a distinct physical landmark, name, description, and seizure message for each kind; keep the kind glyph and ownership colors consistent. Put a plain effect line in site intel (e.g. `Reservoir · Enables Draw Rite while held`). Seizure text says `corporate` or describes what the site does; it never names a company that may not be attacking.

| District | Ley Line: local Revealed damage | Data Center: shorter local Rigged jams | Reservoir: Corruption headroom and Draw Rite access |
|---|---|---|---|
| Urban Center | **Ley Line** | **Converted Data Center** | **Corruption Reservoir** |
| Write-Off Belt | **Axle-Bone Cairn** — stacked wrecks over a fault that hums when engines idle. | **Salvage Relay** — a dispatch mast built from repossessed truck radios. | **The Black Sump** — a lined salvage pit collecting something absent from the manifests. |
| Unceded Greenbelt | **Witness Grove** — a stand of trees older than the deeds that claim it. | **Firewatch Exchange** — a lookout tapped into the local radio network. | **The Root Cistern** — an old water collector whose roots draw up more than water. |
| Cooling Basin | **The Subsidence Fault** — a fracture opened when the aquifer collapsed. | **Emergency Failover Yard** — a switchyard that keeps patched rigs running or reroutes corporate traffic. | **Spent Coolant Well** — a sealed disposal shaft the cult can draw from and the corporation can pump. |

The same upkeep applies: keep a tower in claim range to hold the site. Under corporate capture, the Ley Line variants make local enemies tougher, the Data Center variants make them faster, and Reservoir variants do both. Neither owning nor attacking factions get a special site multiplier. Resolve the variant from the **actual site hex** after choosing a legal placement, not from the lane name or spawn district: a site on the urban side of a seam still looks urban. Separate the seeded effect-kind draw from presentation so adding another landmark doesn't change effect odds or turn two consecutive rolls of the same kind into false variety. Preserve reservoir recognition and access wherever the site looks different.

### How a district enters play

1. **Survey at the existing growth preview.** For the first transition, target the wave-10 clear or the next successful eligible growth if the route stays in settled city ground. Annotate the ghost route with its destination and local operator, e.g. `COOLING BASIN · SKYLINE FREIGHT CORRIDOR`. The operator is a fact about the land, not a roster promise. Don't move a legal route to force a reveal or promise an exact site before placement.
2. **Commit the selected route, then settle the district.** Reveal a coherent patch around newly opened ground, not just the road. Use a short seam of shared props (loading yards into salvage, street edges into firebreaks, storm drains into intake canals). Once revealed, ground keeps its identity across growths, fork selection, and chunk streaming. Preserve building and path legality. No successful growth means no new district or site.
3. **Keep fork choices honest.** If viable candidates reach different districts, report that alongside condemnation and bounty in Intel. Keep route buttons short and put district/operator details in wrapping copy. Two valid routes can lead to the same district. Switching the preview must not repaint ground, consume a faction roll, or create a site.
4. **Confirm the attacker after commit.** Use the actual locked assignment in post-boss intel, e.g. `SKYLINE LOGISTICS ASSIGNED — REVIEW AIR COVERAGE`. If the next interval is Coalition, say so even if the route crosses Skyline property. A Greenbelt route can likewise stay under a different faction's current contract.

### Faction affinity: test as a preference, not a lock

- For the next eligible **regular** interval, bias the roll using the committed biome at the **main-lane spawn**, not whichever fork opened most recently. Trial weights: **3** for the local operator, **2** for a listed secondary contractor, **1** for other eligible factions. Exclude the previous regular faction first. Keep early urban scheduling unchanged; leave unassigned affinities neutral. The Coalition slot always wins.
- When the existing secondary lane assignments activate, apply the preference using each fork's own spawn district. Keep the current distinct-faction exclusions and readiness/budget rules. Don't bring this behavior forward into early forks.
- Lock assignments once per interval, using a seeded draw that preview and UI queries cannot perturb. The Director currently caches future schedule entries; a prototype must resolve the affected assignment from committed ground before the post-boss announcement or first roster of that interval. A speculative schedule lookup must never bind the choice, and a committed route must never rewrite a locked wave.
- Keep budgets, boss cadence, tower rules, events, terrain blockage, and roster constraints unchanged. The effect should be a planning signal (e.g. consider anti-air in the Basin), not a guarantee or an additional enemy stat bonus.

### Prototype and acceptance checks

1. **Prove the seam: Urban Center → Cooling Basin.** Use seeded district lookup per hex rather than the current run-wide biome. Keep the existing chunk renderer and batch by biome plus archetype where they meet. Build a minimal kit: dry canal roadbed and matching connectors, open salt flats, blocked intake works, cleared tower pad, an urban-edge transition, three site landmarks, and Skyline freight signage. Keep path arrows, construction overlays, and objective state glyphs legible at normal zoom; don't spawn a node per tile.
2. **Prove the director hook in the same slice.** Compare identical seeds with affinity on and off. Skyline should appear more often at eligible Basin spawns, never bypass a faction exclusion or replace Coalition, and the Intel assignment must match the locked roster. Check roster constraints, early-wave parity, and seeded replay across preview, commit, and fork selections. In a live playtest, check whether players recognize the Basin's landmarks and consider anti-air because of the confirmed assignment rather than assuming every Basin wave is Skyline.
3. **Expand after the slice reads well.** Greenbelt next for canopy/firebreak contrast; Write-Off Belt after its inhabited salvage look is unmistakable next to the Basin. Defer biome-wide hazards and unique faction-site rules. If districts still need more tactical identity, prototype one bespoke site before modifying a whole biome.

**Later candidate:** **The Premium Floodplain** — rooftop roads and breakwater shadows in a district that flooded because private levees rerouted the water downhill.
