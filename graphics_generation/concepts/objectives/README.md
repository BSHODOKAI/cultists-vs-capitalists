# Objective Site Concept Art — claimable hex tiles

**The target for objective sites.** `ObjectiveSystem` already spawns claimable sites on new ground,
but they render as a ring plus a placeholder glyph. The design intent here is that a site should be a
**visually distinct hex tile** — obvious at a glance, and **biome-matched**, so a site in the Write-Off
Belt looks like it belongs there.

> **Prompts ARE recorded below, verbatim.** Every image = *subject block + shared objective style
> block*, concatenated exactly as sent (the same rule as the tower, unit, Sanctum and biome concepts;
> see the [`create-3d-asset`](../../../.ziva/skills/create-3d-asset/SKILL.md) skill §7).

Generated 2026 · `generate_image` (kind `sprite`, finish `smooth`, 768×768).

---

## The three kinds, and why this is a matrix

`ObjectiveSystem` has exactly **three mechanical kinds**, and each **transcends biomes** — it can
appear in any district, so it needs a local look per district. [`ROADMAP.md` §16](../../../ROADMAP.md)
already names a landmark for each kind in each proposed district, which gives a clean
**4 districts × 3 kinds = 12 tiles**.

| Kind (`ObjectiveData` id) | Effect while held | Local look must say |
|---|---|---|
| `ley_line` | `+8%` local Revealed damage | *a place the cult's power runs through* |
| `converted_data_center` | halves local Rigged jam duration | *corporate infrastructure the cult has tapped* |
| `corruption_reservoir` | `+25` Corruption ceiling **and unlocks Draw Rite** | *something the cult draws rot out of* |

`corruption_reservoir` is the one that most obviously needs a variant per district — it is the site
that changes what the meter can do — but all three are per-district in the design.

> **Now covered:** the **Premium Floodplain** was a gap (§16 assigns it no landmarks); three have
> been **invented for it** below. That completes 3 kinds × 5 districts = **15 landmark tiles**.

---

## The shared objective style block (identical in every prompt)

> An objective-site hex tile: isometric 3/4 view at the game camera angle (yaw 45 degrees, pitch 35
> degrees), orthographic feel, presented as a single regular hexagonal map tile standing alone on a
> pure black background and cropped so the whole hexagon is visible with a small margin. The site's
> landmark stands at the centre of the hex on ground marked as a claimable objective — a faint glowing
> ring of objective aura on the paving. Painterly realism, highly detailed and crisp, clean game-asset
> lighting — a warm golden key light from the upper left with a warm ambient fill and soft moderate
> shadows, so the tile reads at its own true value and is never darkened. No characters, no creatures,
> no towers, no UI, no text.

> **The ring is illustrative, not a colour spec.** The prompt asks only for *a glowing ring*; the
> generator picked colours freely (violet where ley-energy dominates, amber elsewhere). In game the
> ring is the **objective STATE colour** from `VisualThemeData` — green claimed / white unclaimed /
> red captured — and it is rebuilt by `OverlayView` from the state. What these concepts fix is the
> **landmark and the site reading as a distinct, marked hex**, not the ring colour.

---

## Urban Center — the shipped city (`obj_urban_*`)

| Kind | File | Subject block (verbatim) |
|---|---|---|
| Ley Line | `obj_urban_ley_line.png` | An objective-site hex tile of a LEY LINE in a dense cyberpunk Urban Center: a fissured street utility vault splitting open at the centre of the hex, violet ley-energy arcing up out of the crack below, humming cables and rusted conduit, cult sigils spray-painted around the fissure, scattered tools and a barricade. |
| Data Center | `obj_urban_data_center.png` | An objective-site hex tile of a CONVERTED DATA CENTER in a dense cyberpunk Urban Center: a street-level telecom equipment shelter and server cabinets repurposed by the cult, rows of blinking racks with cables spilling out, a hacked junction with a jury-rigged console and a small cooling unit, violet and cyan glows, a hand-painted sigil on the housing. |
| Reservoir | `obj_urban_reservoir.png` | An objective-site hex tile of a CORRUPTION RESERVOIR in a dense cyberpunk Urban Center: a lined underground tank access in a city lot, a manhole and valve assembly leaking black ichor into a bunded pit, a containment drum and a pump, violet and red sigils painted on the concrete. |

## The Write-Off Belt — wastelander (`obj_belt_*`)

| Kind | File | Subject block (verbatim) |
|---|---|---|
| Ley Line | `obj_belt_ley_line.png` | An objective-site hex tile of an AXLE-BONE CAIRN in the Write-Off Belt, a rust-orange wastelander salvage district: a stacked cairn of crushed vehicle axles, drive shafts and bleached bones heaped over a humming crack in the ground that glows violet, rust flakes and scrap, cult sigils painted on a hubcap. |
| Data Center | `obj_belt_data_center.png` | An objective-site hex tile of a SALVAGE RELAY in the Write-Off Belt, a rust-orange wastelander salvage district: a tall improvised radio mast built from repossessed truck CB radios, whip antennas and scrap, cabling running down to a battered console and a car battery, a weak spark at a loose connector. |
| Reservoir | `obj_belt_reservoir.png` | An objective-site hex tile of THE BLACK SUMP in the Write-Off Belt, a rust-orange wastelander salvage district: a tar-lined salvage pit brimming with thick black sludge, a battered pump and oil drums at the rim, hazard-striped boards and a length of chain, cult sigils scratched into the drums. |

## The Unceded Greenbelt — forest (`obj_greenbelt_*`)

| Kind | File | Subject block (verbatim) |
|---|---|---|
| Ley Line | `obj_greenbelt_ley_line.png` | An objective-site hex tile of a WITNESS GROVE in the Unceded Greenbelt, a dark-canopy forest district: an ancient ring of tall trees whose roots glow with violet ley-light, deep moss, carved and painted cult sigils on the trunks, a weathered standing stone at the centre. |
| Data Center | `obj_greenbelt_data_center.png` | An objective-site hex tile of a FIREWATCH EXCHANGE in the Unceded Greenbelt, a dark-canopy forest district: a timber firewatch lookout tower with a radio dish and antenna array, cabling running down a tree, a hand-cranked radio set and a map board at its foot. |
| Reservoir | `obj_greenbelt_reservoir.png` | An objective-site hex tile of THE ROOT CISTERN in the Unceded Greenbelt, a dark-canopy forest district: an old overgrown concrete water cistern whose tree roots reach down into it and draw up black liquid, moss and ferns, cult sigils painted on the rim, a bucket and rope. |

## The Cooling Basin — desolate (`obj_basin_*`)

| Kind | File | Subject block (verbatim) |
|---|---|---|
| Ley Line | `obj_basin_ley_line.png` | An objective-site hex tile of THE SUBSIDENCE FAULT in the Cooling Basin, a desolate drained-reservoir district: a deep fracture opened in the chalk-white lakebed, violet ley-energy glowing up out of the crack, broken salt plates and a survey marker, cult sigils sprayed on the ground. |
| Data Center | `obj_basin_data_center.png` | An objective-site hex tile of an EMERGENCY FAILOVER YARD in the Cooling Basin, a desolate drained-reservoir district: a small electrical switchyard with transformers, porcelain insulators, breaker cabinets and cable runs on concrete pads, a warning sign and the corner of a chain-link fence. |
| Reservoir | `obj_basin_reservoir.png` | An objective-site hex tile of a SPENT COOLANT WELL in the Cooling Basin, a desolate drained-reservoir district: a sealed concrete disposal wellhead with a heavy bolted hatch, black liquid seeping around the seal into a stained pit, a rusted pipe and valve, hazard signs, salt crust. |

---

## The Premium Floodplain — flooded (`obj_floodplain_*`)

§16's later candidate: rooftop roads and breakwater shadows in a district that flooded because private
levees rerouted the water downhill. §16 assigned it **no** landmarks, so these three are **invented**
here. Like the terrain tiles, every prompt carries the **"NEVER medieval"** clause (the floodplain
drifted to stone balustrades on the first terrain pass).

| Kind | File | Invented landmark | Subject block (verbatim) |
|---|---|---|---|
| Ley Line | `obj_floodplain_ley_line.png` | **The Drowned Causeway** | An objective-site hex tile of THE DROWNED CAUSEWAY in the Premium Floodplain, a flooded cyberpunk district: the crest of an old private levee road submerged under clear shallow flood water, a ley fault running along it glowing violet up through the water, rusted steel marker posts and a handrail breaking the surface, drowned glass towers reflected in the water. Modern poured concrete and steel — NEVER historical, NEVER medieval masonry. |
| Data Center | `obj_floodplain_data_center.png` | **The Waterlogged Exchange** | An objective-site hex tile of THE WATERLOGGED EXCHANGE in the Premium Floodplain, a flooded cyberpunk district: a private street-level comms exchange flooded to its racks, half-submerged grey cabinets and cable trays still glowing cyan and violet beneath the clear water, a floating access hatch, warning boards on a steel post, an oil sheen on the surface. Modern poured concrete and steel — NEVER historical, NEVER medieval masonry. |
| Reservoir | `obj_floodplain_reservoir.png` | **The Breach Basin** | An objective-site hex tile of THE BREACH BASIN in the Premium Floodplain, a flooded cyberpunk district: the scour pool behind a breached private levee, deep black water pooled against broken modern concrete, a pump and a floating containment boom, orange hazard markers and bent steel rebar, cult sigils painted on the levee wall. Modern concrete and steel — NEVER historical, NEVER medieval masonry. |

---

## Wiring spec — presentation is separate from the effect draw

**The cardinal rule (from §16):** adding a landmark must **not** change effect odds. Today the effect
is chosen by [`ObjectiveSystem`](../../../scripts/objectives/objective_system.gd)
`_pick_data(catalog)` — a seeded draw over `res://data/objectives/*.tres` (3 files, one per kind,
avoiding an immediate repeat). **Do not add per-biome `ObjectiveData` files** — that would change the
catalog and therefore the odds. Keep exactly three effect resources.

**1. Per-hex biome resolution (prerequisite).** The biome is run-wide today; a landmark needs the
district *at the site hex*. Add a resolver — `BiomeResolver.get_biome_id_at(hex)` — using a seeded
per-hex district lookup (the §16 prototype), so `place_for_growth` knows the site's biome when it
picks `hex`.

**2. Presentation layer, keyed by (kind, biome).** Add an `ObjectiveLandmarkData` Resource
(`kind`, `biome_id`, `landmark_id`, `display_name`, `description`, `seizure_message`) plus an
`ObjectiveLandmarkLibrary` that loads `res://data/objective_landmarks/*.tres`. Resolve at placement:
`ObjectiveLandmarkLibrary.find(data.kind, biome_id)`, and store the resolved record on the
`ObjectiveInstance` (`landmark_id`, `presentation_name`, `presentation_description`,
`seizure_message`). The effect numbers stay on the `ObjectiveData`; the landmark overrides only
*presentation*.

**3. Rendering — the landmark is the tile, the ring stays the state.** `OverlayView` keeps its
state-coloured ring/aura layers unchanged, and keeps one **kind** layer so the three kinds stay
distinguishable (`PlaceholderIcons.objective_icon()` / `_icon_layer_for`). Add one **landmark** layer
per `landmark_id`, minted on demand like the icon layers, drawn from the site hex's `landmark_id` —
this is the "obvious different hex tile". Fall back to the kind glyph when a landmark mesh is
missing, so a new district never renders an invisible site.

**4. Data to author.** 3 kinds × 5 districts = **15** landmark records (the 12 rolled above plus the
Floodplain's 3).

**5. UI / intel.** Use `presentation_name` in the site's intel line and `seizure_message` in the
capture banner. Per §16, seizure text says *corporate* or describes the effect — never names a
company that may not be attacking.

**6. Test.** The existing data tests validate `ObjectiveData`. Add one asserting every
`(kind, biome_id)` pair the resolver can produce has exactly one landmark record, so adding a biome
cannot silently leave a site with no presentation.