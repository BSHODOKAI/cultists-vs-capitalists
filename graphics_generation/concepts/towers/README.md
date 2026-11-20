# Tower Concept Art — the cult's eleven emplacements

33 concept images: **3 takes per tower × 11 towers** (`concept_tower_<id>_<take>.png`).
These are the *target* for the tower assets, exactly as the parent
[`../README.md`](../README.md) concepts are the target for the Sanctum. **Match the concept at
its own value** — do not darken an asset to sit against the terrain tiles, and do not restyle the
tiles to suit an asset.

> **Prompts ARE recorded below**, verbatim, in the reconstruction-of-last-time sense: the
> **shared style block** and the **per-tower subject** + **per-take framing** blocks are the exact
> strings sent. Every image = *framing + subject + shared style block, concatenated*. This is the
> one thing the original Sanctum concepts failed to do
> (see [`../README.md`](../README.md) and the `create-3d-asset` skill §7).

Generated 2026 · `generate_image` (kind `sprite`, finish `smooth`, 768×768).

---

## How to read the images

- **Take `a`** — centred hero view: the whole emplacement, composed as a standalone hex.
- **Take `b`** — close, lower three-quarter (pitch ~30): the primary object's silhouette dominates.
- **Take `c`** — wide gameplay distance (pitch ~35): the full yard and perimeter, object smaller.

The three takeaways are meant as **directions to iterate on**, not finished frames. Pick a letter
per tower (or mix), then request a variant with the same recorded prompt plus a tweak.

## The shared style block (identical in all 33 prompts)

> Low weathered pale-grey cast-concrete parapets with chamfered tops (knee-high kerbs, not
> walls); galvanised steel pipe and chain-link railings; a rusted corrugated sheet lean-to; a
> frayed olive tarp with sprayed white sigils; narrow red banners; a caged sodium work-lamp
> glowing warm orange with a red-orange halo bloom; clusters of dripping votive candles; rusted
> propane cylinders; an electrical junction box with conduit; red and violet spray sigils on the
> concrete. Wet reflective floor puddles, rubble and leaf litter. Warm golden key light from
> upper-left, deep near-black shadows, faint cool ambient. Hand-built and improvised, **NEVER
> medieval masonry, NEVER clean or mass-produced.** Highly detailed game asset, painterly realism.

The "**NEVER medieval / NEVER clean**" clause is the line the art has actually drifted across —
keep it in every future tower prompt.

## Per-tower subjects (the changing part)

| `id` | Subject block (verbatim) |
|---|---|
| `hexed_nail_gun` | a SALVAGED INDUSTRIAL PNEUMATIC NAIL GUN bolted to a scrap-steel tripod frame, its barrel stripped and rewired with bare copper, a coiled air hose running from a rusted propane-tank compressor, bundles of iron nails laid out on a concrete altar like offerings |
| `chanting_choir` | a TIGHT RING OF HOODED CULTISTS chanting, mouths open, around a salvaged public-address horn loudspeaker on a steel pole, hymn sheets clipped to a lectern, an old standpipe rising behind them |
| `gutter_ritual_circle` | a RITUAL CIRCLE of red and violet spray-painted sigils painted onto a stained concrete gutter slab, thick with pooled cracked wax, a rusted iron storm grate at its centre with corrosive green-black ichor bubbling up from the drain, a length of gutter and downpipe above |
| `tentacle_storm_drain` | a CONCRETE STORM-DRAIN CULVERT with a heavy rusted iron grate lifted aside, dark standing water, thick glistening grey-green tentacles writhing up out of the drain and tethered with salvaged chain to a scaffold post, a cracked manhole cover nearby |
| `watcher_in_the_billboard` | a HUGE SALVAGED ROADSIDE BILLBOARD PANEL, its corporate advertisement scraped and overpainted into a single enormous staring EYE surrounded by red and violet sigils, mounted on rusted scaffold-tube legs with a catwalk and ladder beneath, a dead sodium floodlight aimed at the blank side |
| `rust_censer` | a HEAVY RUSTED BRASS CENSER / incense burner swung on chains from a scaffold-tube gantry, thick corrosive yellow-green smoke pouring from its perforated lid, heaps of rust-orange powder and iron filings beneath it, a rusted pipe weep and drain grate at the base |
| `fever_shrine` | a DENSE SHRINE of hundreds of melting votive candles in pooled wax, glowing coals and heat shimmer, built around a salvaged steel equipment cabinet / filing racks repurposed as a feverish altar, red banners on its frame, smouldering and sweating |
| `the_congregation` | a KNEELING RING OF ROBED CULTISTS packed shoulder to shoulder on a concrete kerb, arms raised in summoning, spectral smoke curling up from a painted sigil circle, salvaged bus-shelter frame and turnstiles woven into the ring |
| `tithe_box` | a BATTERED STEEL OFFERING / TITHE BOX on a post, padlocked and overflowing with coins and folded banknotes, wrapped in red cloth with sprayed white sigils, beside a rusted cash register, a coin jar and tally marks scratched on a concrete plinth |
| `substation_effigy` | a SALVAGED HIGH-VOLTAGE ELECTRICAL SUBSTATION TRANSFORMER on a concrete pad, stripped bare to gleaming copper coils and dangling conductive cables, cracked porcelain insulators, a crude effigy figure lashed to it with wire, yellow hazard warning plates, blue-white electric arcs crackling between the terminals |
| `dead_air_altar` | a DEAD BROADCAST ANTENNA MAST rigged into an altar: a salvaged lattice radio tower with a parabolic dish and dead horn antennas, hung with tattered prayer flags, tarp banners and small cold-blue glowing censers, a gutted broadcast-van equipment rack and reel-to-reel tape deck at its foot, a hand-lettered DEAD AIR sign |

## Per-take framing blocks (verbatim)

**Take `a`**
> Isometric 3/4 view (orthographic feel, matching yaw 45 / pitch 35) of a single hexagonal platform
> standing alone on a pure black background. A scrappy occult cult's improvised emplacement, built
> by occupying abandoned modern urban infrastructure — the subject is **[SUBJECT]**.
> *[+ shared style block]* Square composition, centered hero view.

**Take `b`**
> Close three-quarter isometric view, lower camera angle (yaw 45 / pitch ~30), tight and dramatic,
> the subject dominating the frame. Single hexagonal platform, orthographic feel, pure black
> background. A scrappy occult cult's improvised emplacement of occupied abandoned urban
> infrastructure — the subject is **[SUBJECT]**. *[+ shared style block]*

**Take `c`**
> Wide isometric 3/4 view at gameplay distance (yaw 45 / pitch ~35), showing a whole single
> hexagonal yard to its perimeter, orthographic feel, pure black background. A scrappy occult
> cult's improvised emplacement of occupied abandoned urban infrastructure — **[SUBJECT]**, the
> object smaller and centred within the yard. *[+ shared style block]*

---

## Wiring these to the game data

Each tower's mechanical identity (what the emplacement must *say*) is in
[`../../../TOWERS.md`](../../../TOWERS.md) and `res://data/towers/<id>.tres`. The concepts were
generated from the display name + description + role, so they read at a glance as:

- **attackers** carry their weapon/emitter as the hero mass (`hexed_nail_gun`, `watcher_in_the_billboard`,
  `substation_effigy`, `rust_censer`, `gutter_ritual_circle`, `tentacle_storm_drain`, `chanting_choir`);
- **support/no-attack** towers make the *ritual* the hero (`fever_shrine`, `dead_air_altar`,
  `tithe_box`, `the_congregation`).

## Height & footprint reminders (from `code`, not this doc)

`HexMath.TOWER_MAX_HEIGHT = 1.5`, measured from **z = 0 up**; depth below is free. A tower lives on
one hex, keeping geometry inside the **0.866** apothem (procedural towers use a ~0.56 plinth
radius). Read the real numbers from code before modelling. These concepts are *warded* inside those
budgets (single hex, low profile) but the modelling pass must trim to the actual footprint.