# Hexed Nail Gun — upgrade-path concept art

Concept art for the tower's **upgrade paths**, each built on the base emplacement from
[`../concept_tower_hexed_nail_gun_b.png`](../concept_tower_hexed_nail_gun_b.png) (take B).

**The rule for these:** the emplacement is the *same tower* — every image shows **one subtle but
noticeable addition** that reads the node's effect and flavour. Seven nodes: the shared T2, then the
three two-tier branches (**Revealed / Rigged / Rite**). Node effects and flavour are from
[`TOWERS.md`](../../../../TOWERS.md) §1 (Hexed Nail Gun) and `res://data/upgrades/*.tres`.

| Branch | Tier | Node | In-game effect | Visual tell (subtle, on-theme) |
|---|---|---|---|---|
| Shared | T2 | `rapid_cycling` | +30% fire rate | A salvaged ratchet-and-flywheel cycling gear bolted to the receiver, an extra air line, a short strip of queued nails at the breech. |
| Revealed | T3 | `whispering_nails` | Nails home; 25% pierce resistances | A faint violet psychic sheen on the nails and coils; a few nails float; ghostly open-mouthed whisper shapes trail toward the barrel. |
| Revealed | T4 | `nails_that_remember` | Each nail returns for a second hit | The violet deepens; a closed loop of translucent spectral nails arcs from the muzzle back down to the altar, trailing an after-image. |
| Rigged | T3 | `drone_feeder` | +40% fire rate; never reloads | A salvaged electric drum-feeder clamped on with exposed wiring, duct tape and a spinning feed drum, fed from an oil drum of nails. Clattering, cobbled-together grey/rust. |
| Rigged | T4 | `pneumatic_belt_rig` | 5-round bursts; +50% vs Armored | A linked disintegrating nail belt snaking from an oversized hopper through a belt-drive gearbox into the receiver, pressure gauge, heavier compressor. |
| Rite | T3 | `nail_of_accounting` | **The Ledger:** +8% per consecutive hit on one target (to +96%); +0.5%/Corruption | An open ledger chained flat on the altar, pages dense with tally marks, a brass pen, nail heads stood up in tally rows, red tally sigils up the barrel. Mundane and sinister. |
| Rite | T4 | `the_audit_comes_due` | +45% dmg, +30% rate; +2 Offerings per kill | A vast unblinking dark-red eye of dim light under the canopy; an abacus of beads and chained ledgers; coins and receipts spilling from a split sack; golden threads drawn up from the nail pile as if being counted. |

**Why these read the theme.** The cult's voice is *deadpan sinister — corpo-speak for the occult*.
The Revealed branch is the occult glow (Corruption made visible); the Rigged branch is the cult's
cheap scrapyard improvisation (Scrap, jank); the **Rite** branch is the game's debt/ledger thesis —
bookkeeping as black magic — so its tells are ledgers, tally marks, an audit, a creditor's eye.

Generated 2026 · `generate_image` (kind `sprite`, finish `smooth`, 768×768). Prompts below.

---

## Prompts (recorded verbatim — skill §7)

Every image = **BASE block + the node's ADDITION**. Nothing else varied.

### BASE block (identical in all seven)

> Isometric three-quarter view from a slightly lower camera angle (yaw 45 / pitch ~30),
> orthographic feel, tight and dramatic, the subject dominating the frame. A single hexagonal
> platform standing alone on a pure black background. A scrappy occult cult's improvised
> emplacement built by occupying abandoned modern urban infrastructure: a salvaged industrial
> PNEUMATIC NAIL GUN bolted to a scrap-steel tripod frame, its barrel stripped and rewired with
> bare copper, a coiled air hose running from a rusted propane-tank compressor, bundles of iron
> nails heaped on a low concrete altar like offerings. Low weathered pale-grey cast-concrete kerbs
> with chamfered tops; galvanised steel pipe and chain-link railings; a rusted corrugated sheet
> lean-to; a frayed olive tarp with a sprayed white sigil; thin red banners; a caged sodium
> work-lamp glowing warm orange with a red-orange halo bloom; clusters of dripping votive candles;
> rusted propane cylinders; an electrical junction box with conduit; red and violet spray sigils
> and tally marks on the concrete. Wet reflective concrete floor, rubble and leaf litter. Warm
> golden key light from the upper left, deep near-black shadows, faint cool ambient. Hand-built and
> improvised, NEVER medieval masonry, NEVER clean or mass-produced. Highly detailed game asset,
> painterly realism.
>
> *(Rite T3 only: the BASE read "…red and violet spray sigils on the concrete" — no "and tally
> marks" — to avoid pre-empting its ledger tally.)*

### ADDITION blocks (one per node)

**`t2_rapid_cycling.png`**
> THIS IS THE T2 UPGRADE "Rapid Cycling" (a modest +30% fire rate). Add only a subtle but
> noticeable mechanical change: a salvaged ratchet-and-flywheel cycling gear bolted to the gun's
> receiver, an extra coiled air line, and a short strip of queued nails feeding into the breech.
> Chipped yellow and greasy steel, hand-crimped with wire. The emplacement is otherwise completely
> unchanged — the same tower, just faster-cycling.

**`revealed_t3_whispering_nails.png`**
> THIS IS THE REVEALED T3 UPGRADE "Whispering Nails" (nails home in; some pierce all resistances).
> Add only a subtle but noticeable occult change: the nail heads and the gun's coils now carry a
> faint violet psychic sheen, a few nails float slightly off the altar, and ghostly open-mouthed
> whisper shapes trail thinly toward the barrel. The violet is a quiet underglow, not a blaze. The
> emplacement is otherwise completely unchanged.

**`revealed_t4_nails_that_remember.png`**
> THIS IS THE REVEALED T4 UPGRADE "Nails That Remember" (each fired nail returns for a second hit).
> Add only a subtle but noticeable occult change: the violet sheen is a little deeper, and a thin
> closed loop of translucent spectral nails arcs from the muzzle back down to the altar, leaving a
> faint trailing after-image; the nail pile seems to writhe with a memory of past shots. Still
> restrained, a single glowing thread of repetition. The emplacement is otherwise completely
> unchanged.

**`rigged_t3_drone_feeder.png`**
> THIS IS THE RIGGED T3 UPGRADE "Drone Feeder" (a crude motorised auto-feeder; never reloads). Add
> only a subtle but noticeable scrapyard change: a salvaged electric drum-feeder clamped onto the
> receiver with exposed wiring, duct tape and a spinning feed drum, fed from an oil drum of nails;
> a reclaimed fan motor and a small whirring belt. Industrial grey and rust, cobbled together and
> clattering — the cult's cheap fix for rate of fire. The emplacement is otherwise completely
> unchanged.

**`rigged_t4_pneumatic_belt_rig.png`**
> THIS IS THE RIGGED T4 UPGRADE "Pneumatic Belt Rig" (five-round bursts, punched through armour).
> Add only a subtle but noticeable scrapyard change: a linked disintegrating belt of iron nails
> snakes from an oversized salvaged hopper through a belt-drive gearbox into the receiver, with a
> pressure gauge and a heavier greasy compressor. Chipped yellow paint, oil-stained steel, patched
> with scrap. A heavier, angrier version of the same gun. The emplacement is otherwise completely
> unchanged.

**`rite_t3_nail_of_accounting.png`**
> THIS IS THE RITE T3 UPGRADE "Nail of Accounting" (the Ledger: every hit on the same target is
> tallied). Add only a subtle but noticeable bureaucratic-occult change: an open ledger book
> chained flat on the altar, its pages crowded with dense tally marks, a brass pen resting on it, a
> few nail heads stood up in rows like tally strokes, and thin red tally-mark sigils spiralling
> faintly up the barrel. Mostly mundane and sinister — a bookkeeping shrine. The emplacement is
> otherwise completely unchanged.

**`rite_t4_the_audit_comes_due.png`**
> THIS IS THE RITE T4 UPGRADE "The Audit Comes Due" (the cult's debt is being collected). Add only
> a subtle but noticeable bureaucratic-occult change: a single vast unblinking dark-red eye of dim
> light beneath the canopy above the gun, an abacus of hanging beads and chained ledgers crowds the
> altar, coins and paper receipts spill from a split canvas sack, and thin golden threads are drawn
> upward from the nail pile as if being counted. Ominous and quiet, a creditor watching. The
> emplacement is otherwise completely unchanged.

---

## Reference

- Base tower concepts (a/b/c): [`../README.md`](../README.md)
- Full roster & per-node effects: [`../../../../TOWERS.md`](../../../../TOWERS.md)
- Tone/voice: `res://DESIGN_BIBLE.md`