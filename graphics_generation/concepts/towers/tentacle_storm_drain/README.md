# Tentacle Storm Drain — upgrade-path concept art

Concept art for the tower's **upgrade paths**, each built on the base emplacement from
[`../concept_tower_tentacle_storm_drain_b.png`](../concept_tower_tentacle_storm_drain_b.png) (take B).

**The rule (same as `../hexed_nail_gun/`):** the emplacement is the *same tower* — every image shows
**one subtle but noticeable addition** that reads the node's effect and flavour. Seven nodes: the
shared T2, then the three two-tier branches (**Revealed / Rigged / Rite**). Effects and flavour from
[`TOWERS.md`](../../../../TOWERS.md) §4 (Tentacle Storm Drain) and `res://data/upgrades/*.tres`.

| Branch | Tier | Node | In-game effect | Visual tell (subtle, on-theme) |
|---|---|---|---|---|
| Shared | T2 | `more_grates` | +1 target; slow aura 35% → 45% | Two extra rusted grates set into the surrounding concrete, shallow black-water channels running between them, an extra length of chain. |
| Revealed | T3 | `deep_grasp` | Root 2.5s and drag 1 hex backward (not Bosses) | One long barbed tentacle reaches out across the ground to coil and drag, its tip a faint abyssal teal; fresh drag-gouges scored in the concrete behind it. |
| Revealed | T4 | `leviathan_awakens` | Every 25s a sweep hits all enemies in range +2 for 120 Void, roots 1s | The drain boils: a massed crown of larger tentacles rises, a single huge pale eye opens among them, a violet-black void haze hangs over the yard, new cracks radiate from the culvert. |
| Rigged | T3 | `flood_pump` | 40% slow puddle on nearby path hexes; wet hexes conduct Electric | A salvaged sump pump and tangled hoses clamped to the drain rim; shallow puddles deliberately flooding out across the concrete. |
| Rigged | T4 | `live_wire_flood` | Flooded hexes deal 12 Electric/s | The puddles crackle: bare cables from a rusted battery bank into the water, thin blue-white arcs across the surface, a hazard warning plate by the hoses. |
| Rite | T3 | `drowned_ledger` | +30% damage, slow aura 45%; +0.5%/Corruption | A waterlogged ledger sprawled open on the wet concrete, pages swollen, tally marks running in the damp, tarnished coins sunk in a puddle. |
| Rite | T4 | `the_fathom_collects` | +50% dmg, slow aura 55%, +1 target; +2 Corruption and +1 Scrap/kill | The culvert is a bottomless black well; chained ledgers, coins and salvage drawn down into the dark, thin violet threads pulled under. A creditor of the deep. |

**Why these read the theme.** Revealed = Corruption made visible (the occult glow, the thing in the
drain growing); Rigged = the cult's cheap scrapyard improvisation (jank, flood, live wires);
**Rite** = the game's debt/ledger thesis — the deep keeps a ledger, and *The Fathom Collects* is the
Reckoning's logic in miniature (what the cult owes is taken from the water).

Generated 2026 · `generate_image` (kind `sprite`, finish `smooth`, 768×768). Prompts below.

---

## Prompts (recorded verbatim — skill §7)

Every image = **BASE block + the node's ADDITION**. Nothing else varied.

### BASE block (identical in all seven)

> Isometric close three-quarter view from a slightly lower camera angle (yaw 45 / pitch ~30),
> orthographic feel, tight and dramatic, the subject dominating the frame. A single hexagonal
> platform standing alone on a pure black background. A scrappy occult cult's improvised emplacement
> built by occupying abandoned modern urban infrastructure: a CONCRETE STORM-DRAIN CULVERT with a
> dark arched drain mouth, thick grey-green tentacles writhing up out of the drain, a heavy rusted
> iron grate lifted aside and leaning against the parapet, and a cracked round concrete manhole cover
> sealed with a red sigil on the ground nearby. Low weathered pale-grey cast-concrete parapets with
> chamfered tops; galvanised steel pipe railings; a rusted corrugated sheet lean-to; frayed olive
> tarps hanging with sprayed white sigils; narrow red banners with white cult marks; a caged sodium
> work-lamp glowing warm orange with a red-orange halo bloom; clustered dripping votive candles in
> red wax on a concrete block; rusted butane canisters; scattered stone rubble. Wet reflective
> concrete floor with dark puddles and red runoff stains; red and violet spray sigils and tally marks
> on the concrete. Warm golden key light from the upper left, deep near-black shadows, faint cool
> ambient. Hand-built and improvised, NEVER medieval masonry, NEVER clean or mass-produced. Highly
> detailed game asset, painterly realism.
>
> *(The two **Rite** images: the BASE read "…red and violet spray sigils on the concrete" — no "and
> tally marks" — so the ledger's tally is the added element.)*

### ADDITION blocks (one per node)

**`t2_more_grates.png`**
> THIS IS THE T2 UPGRADE "More Grates" (a second target; a deeper slow). Add only a subtle but
> noticeable change: two more rusted iron grates set into the surrounding concrete, shallow channels
> of black water running between them into the main culvert, and an extra length of salvaged chain;
> the drain now draws from more of the yard. The emplacement is otherwise completely unchanged.

**`revealed_t3_deep_grasp.png`**
> THIS IS THE REVEALED T3 UPGRADE "Deep Grasp" (it roots and drags its prey backward). Add only a
> subtle but noticeable occult change: one long barbed tentacle now reaches out across the ground to
> coil and drag, its tip carrying a faint abyssal teal glow; fresh drag-gouges are scored into the
> wet concrete behind it. The emplacement is otherwise completely unchanged.

**`revealed_t4_leviathan_awakens.png`**
> THIS IS THE REVEALED T4 UPGRADE "Leviathan Awakens" (a periodic sweep of void across the whole
> yard). Add only a subtle but noticeable occult change: the drain boils — a massed crown of larger
> tentacles rises, a single huge pale abyssal eye opens among them, a faint violet-black void haze
> hangs over the yard, and new cracks radiate outward through the concrete from the culvert.
> Ominous, but still the same place. The emplacement is otherwise completely unchanged.

**`rigged_t3_flood_pump.png`**
> THIS IS THE RIGGED T3 UPGRADE "Flood Pump" (a slow puddle spreads over the path; wet hexes
> conduct). Add only a subtle but noticeable scrapyard change: a salvaged sump pump and tangled hoses
> clamped to the drain rim, and shallow standing puddles deliberately flooding out across the
> concrete from the culvert; a jury-rigged flood. The emplacement is otherwise completely unchanged.

**`rigged_t4_live_wire_flood.png`**
> THIS IS THE RIGGED T4 UPGRADE "Live Wire Flood" (the floodwater becomes lethal). Add only a subtle
> but noticeable scrapyard change: the standing puddles now crackle — bare salvaged cables trail
> from a rusted battery bank into the water, thin blue-white electric arcs skip across the wet
> surface, and a red-and-white hazard warning plate stands by the hoses. The emplacement is
> otherwise completely unchanged.

**`rite_t3_drowned_ledger.png`**
> THIS IS THE RITE T3 UPGRADE "Drowned Ledger" (the cult tallies what the deep is owed). Add only a
> subtle but noticeable bureaucratic-occult change: a waterlogged ledger book sprawled open on the
> wet concrete beside the culvert, its pages swollen and its tally marks running and bleeding in the
> damp, with a handful of tarnished coins sunk in a puddle. Quiet and sinister. The emplacement is
> otherwise completely unchanged.

**`rite_t4_the_fathom_collects.png`**
> THIS IS THE RITE T4 UPGRADE "The Fathom Collects" (the depth is being paid). Add only a subtle but
> noticeable bureaucratic-occult change: the culvert has become a bottomless black well; chained
> ledgers, coins and scraps of salvage hang and are drawn down into the dark, thin violet threads
> pulled beneath the surface, and something immense and patient stirs below. Ominous and quiet, a
> creditor of the deep. The emplacement is otherwise completely unchanged.

---

## Reference

- Base tower concepts (a/b/c): [`../README.md`](../README.md)
- Full roster & per-node effects: [`../../../../TOWERS.md`](../../../../TOWERS.md)
- Tone/voice: `res://DESIGN_BIBLE.md`