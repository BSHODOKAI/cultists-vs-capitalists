# Biome Concept Art — the districts of the city

**The fidelity target for terrain.** Every district the game ships or plans, as a **tile kit** that
mirrors the taxonomy in [`BiomeData`](../../../scripts/world/biome_data.gd). The Sanctum's own
**Urban Center** kit is included because its shipped models are **placeholder** — these images are
what they are aiming at. [`ROADMAP.md` §16](../../../ROADMAP.md) proposes three neighbouring
districts that post-boss path growth can reveal, plus a later candidate.

> **Prompts ARE recorded below, verbatim.** Every image = *subject block + shared tile style block*,
> concatenated exactly as sent (the same rule as the tower, unit and Sanctum concepts; see the
> [`create-3d-asset`](../../../.ziva/skills/create-3d-asset/SKILL.md) skill §7).

Generated 2026 · `generate_image` (kind `sprite`, finish `smooth`, 768×768).

---

## The tile kit

The proposed districts use a **6-tile kit**; **Urban Center** uses its full named variant set from
`BiomeData` (4 district types, 4 skyscraper/block variants, the avenue, one street lot), because
those are the exact models that are placeholder.

| Tile role | `BiomeData` field | Meaning |
|---|---|---|
| `terrain_a` / `terrain_b` | `district_types` | buildable ground — the texture the player mostly reads |
| `obstacle_a` / `obstacle_b` | `unbuildable_variants` | the BLOCKED landmark mass (the district's silhouette) |
| `road` / `avenue` | *(path lane)* | the surface enemies walk |
| `pad` / `street_lot` | `street_lot_variants` | the cleared underlay shown once a tower occupies the hex |

Two variants each of terrain and obstacle is the minimum that lets a chunk read as *a place* rather
than a repeated stamp — which is what those `BiomeData` arrays exist to vary.

### Two honest caveats

- **Hexagons are approximate.** The generator draws *approximately* regular hexagons (Urban Center and
  the Greenbelt/Basin tiles came out cleanest). These are **material and silhouette targets, not
  geometry proofs**; exact hex shape and scale come from the 3D kit and `HexMath`. For a scale-exact
  footprint see the blockout harness (`graphics_generation/court_b_shrine_blockout/`).
- **The Floodplain drifted to medieval on the first pass.** The first two terrain tiles came back as
  *historical stone balustrades and wrought-iron lanterns* — the exact trap the art brief bans. They
  were **regenerated** with an explicit "NEVER medieval / modern poured concrete and glass" clause, and
  the final prompts (recorded below) carry that clause. Keep it on any future Floodplain tile.

---

## The shared tile style block (identical in every prompt)

> Modular game environment tile, isometric 3/4 view at the game camera angle (yaw 45 degrees, pitch
> 35 degrees), orthographic feel, presented as a single regular hexagonal map tile standing alone on
> a pure black background and cropped so the whole hexagon is visible with a small margin. Painterly
> realism, highly detailed and crisp, clean game-asset lighting — a warm golden key light from the
> upper left with a warm ambient fill and soft moderate shadows, **so the tile reads at its own true
> value and is never darkened**. No characters, no creatures, no towers, no UI, no text.

The "**reads at its own value, never darkened**" clause is load-bearing — it is the rule the art
already drifted across once on the Sanctum (see [`../README.md`](../README.md)).

---

## Urban Center — the shipped city (`urban_center/`)

Neon avenues, glass towers, loading courts, cramped street lots. **Iron Board** runs property
security. This is the district the Sanctum sits in.

**District tiles** (`district_types`):

| File | Subject block (verbatim, before the shared style block) |
|---|---|
| `uc_commercial_district.png` | A hexagonal map tile of a COMMERCIAL DISTRICT from a dense cyberpunk Urban Center: a block of glazed storefronts and mid-rise commercial buildings with bright neon signage and holographic advertising, an awning and a paved forecourt, planters with bare street trees, wet reflective pavement mirroring the neon. |
| `uc_industrial_district.png` | A hexagonal map tile of an INDUSTRIAL DISTRICT from a dense cyberpunk Urban Center: a block of low corrugated warehouses and loading bays with roller doors, stacked shipping containers, chain-link security fencing, warm sodium work-lamps, a wet stained concrete yard and a parked flatbed truck. |
| `uc_residential_district.png` | A hexagonal map tile of a RESIDENTIAL DISTRICT from a dense cyberpunk Urban Center: a block of stacked tenement apartments with balconies and fire escapes, laundry lines, satellite dishes and air-conditioning boxes, warm lit windows, a small ground-floor shop with a glowing sign and a cramped courtyard. |
| `uc_plaza_district.png` | A hexagonal map tile of a PLAZA DISTRICT from a dense cyberpunk Urban Center: an open civic plaza of pale paving with benches and planters, a dry stone fountain and a tall advertising totem carrying a glowing holographic billboard, wet reflective paving, low steps and scattered litter. |

**Block variants** (`unbuildable_variants`):

| File | Subject block (verbatim) |
|---|---|
| `uc_skyscraper_monolith.png` | A hexagonal map tile topped by a SKYSCRAPER MONOLITH from a dense cyberpunk Urban Center: a single sheer glass tower rising off the tile with dark curtain-wall glazing and tall vertical fins, glowing cyan window bands, a lit corporate crown and a lobby base with a canopy and a security gate. |
| `uc_skyscraper_stepped.png` | A hexagonal map tile topped by a STEPPED SKYSCRAPER from a dense cyberpunk Urban Center: a tiered tower of stacked setback volumes in glass and steel, glowing window bands, rooftop plant and antennas, a vertical LED light strip running up one corner. |
| `uc_skyscraper_twin_spire.png` | A hexagonal map tile topped by TWIN SPIRES from a dense cyberpunk Urban Center: two slender glass towers rising from one shared podium base, glowing window columns, antenna tips with red aircraft warning lights, a paved plaza with planters at the base. |
| `uc_skyscraper_helipad.png` | A hexagonal map tile topped by a TOWER WITH A ROOFTOP HELIPAD from a dense cyberpunk Urban Center: a glass curtain-wall tower with an outrigger rooftop landing pad marked with a painted circle and landing mark, blue-white perimeter lights, a beacon, a glass shaft and a lit podium below. |

**Road and street lot:**

| File | Subject block (verbatim) |
|---|---|
| `uc_avenue.png` | A hexagonal map tile of a CITY AVENUE from a dense cyberpunk Urban Center: a wide multi-lane avenue running right across the hexagon with glowing lane markings and a crosswalk, manhole covers, wet reflective asphalt mirroring neon, a painted bus lane and a median with a lamp post. |
| `uc_street_lot.png` | A hexagonal map tile of a CLEARED STREET-LEVEL UTILITY LOT from a dense cyberpunk Urban Center where a building has been demolished: a flat paved lot with exposed utility covers, ducting and a transformer box, cable spools, orange safety barriers, swept clean with wet stains and a puddle. |

---

## The Write-Off Belt — wastelander (`write_off_belt/`)

Rust-orange vehicle stacks, salvage markets, patched settlements, buckled freight asphalt. **Swarm
Syndicate** pays per recovered asset; **Iron Board** handles repossessions.

| File | Subject block (verbatim) |
|---|---|
| `wob_terrain_a.png` | A hexagonal map tile of BUCKLED FREIGHT ASPHALT from the Write-Off Belt, a rust-orange wastelander salvage district: dark cracked tarmac heaved and broken into slabs, patched with mismatched grey concrete and orange spray lines, sun-bleached lane markings half worn away, oil stains, scattered grit and broken glass, a few rust flakes. |
| `wob_terrain_b.png` | A hexagonal map tile of SALVAGE-YARD GROUND from the Write-Off Belt, a rust-orange wastelander salvage district: packed ochre dirt and gravel compacted into deep tyre ruts, drifts of rust flakes and small scrap metal, patches of split oil and a stained broken concrete slab, sparse weeds pushing through, a discarded wheel rim. |
| `wob_obstacle_a.png` | A hexagonal map tile featuring a TOWER OF STACKED CRUSHED CARS from the Write-Off Belt, a rust-orange wastelander salvage district: a leaning tower of flattened rust-orange vehicles bound together with cable and chain, one car tipped off the top, a chain-and-hoist rig and a scrap crane hook beside the stack, packed dirt and rust flakes at the base. |
| `wob_obstacle_b.png` | A hexagonal map tile featuring a SETTLED SHANTY CABIN from the Write-Off Belt, a rust-orange wastelander salvage district: a small home built from a shipping container and salvaged freight panels, corrugated sheet and plywood patched walls, a covered porch of stretched tarpaulin, a smoking stove pipe, a stack of crates and a water butt beside it, patched dirt ground and scrap. |
| `wob_road.png` | A hexagonal map tile of a FREIGHT ROAD from the Write-Off Belt, a rust-orange wastelander salvage district: a wide buckled asphalt freight lane running right across the hexagon, faded yellow centre markings, deep tyre ruts and irregular patched repairs, broken edge kerbs and spilled gravel, a rusted road sign on a bent post at the verge. |
| `wob_pad.png` | A hexagonal map tile of a CLEARED WORK PAD from the Write-Off Belt, a rust-orange wastelander salvage district: a flat swept concrete pad with faded painted orange hazard corner markers, cleared of debris for construction, a coil of steel cable and a couple of oil drums at one edge, surrounding packed dirt and scrap just beyond the pad. |

---

## The Unceded Greenbelt — forest (`greenbelt/`)

Dark canopy clusters, open glades, ranger cabins, survey stakes, a readable continuous firebreak.
Survivalists and separatists live here — **not** a new faction. **Hostile Takeover Inc.** buys access
on paper and enforces it. The canopy never grants Cloak and never makes an enemy untargetable.

| File | Subject block (verbatim) |
|---|---|
| `gb_terrain_a.png` | A hexagonal map tile of a FOREST GLADE FLOOR from the Unceded Greenbelt, a dark-canopy forest district: deep green moss and leaf litter over packed dark earth, dappled light, fallen branches and ferns, a few mushrooms and scattered stones. |
| `gb_terrain_b.png` | A hexagonal map tile of a FIREBREAK STRIP from the Unceded Greenbelt, a dark-canopy forest district: a straight band of cleared earth and crushed pale gravel cut through low grass and scrub, trimmed edges, faint tyre tracks, a few cut saplings and a coil of orange survey tape. |
| `gb_obstacle_a.png` | A hexagonal map tile featuring a DENSE CANOPY CLUSTER from the Unceded Greenbelt, a dark-canopy forest district: three tall close-set trees with heavy dark green crowns and thick barked trunks rising off the tile, mossy roots breaking the soil, ferns and leaf litter at the base, one trunk leaning. |
| `gb_obstacle_b.png` | A hexagonal map tile featuring a RANGER SURVEY STATION from the Unceded Greenbelt, a dark-canopy forest district: a small timber cabin with a shingled roof, a window and a stove pipe, beside it a boundary stake with a survey flag and a wire fence post, a crate and hand tools on the ground, cleared earth with leaf litter and ferns around. |
| `gb_road.png` | A hexagonal map tile of a FOREST TRACK from the Unceded Greenbelt, a dark-canopy forest district: a narrow dirt road running across the hexagon with two dark tyre ruts and a strip of grass down the middle, tree roots crossing it, leaf litter, ferns and low branches at the edges. |
| `gb_pad.png` | A hexagonal map tile of a CLEARED FOREST PAD from the Unceded Greenbelt, a dark-canopy forest district: a flattened clearing of bare packed earth ringed by cut stumps and stacked logs, drifts of sawdust and wood chips, a few felled trunks at the edge, cleared flat for construction. |

---

## The Cooling Basin — desolate (`cooling_basin/`)

Chalk-white lakebed, dead intake canals, immaculate cooling works that still hum. Empty where the
Belt is crowded, because extraction is still running. **Skyline Logistics** supplies a water-starved
data campus by air; **Iron Board** guards the intake works.

| File | Subject block (verbatim) |
|---|---|
| `cb_terrain_a.png` | A hexagonal map tile of CRACKED CHALK-WHITE LAKEBED from the Cooling Basin, a desolate drained-reservoir district: pale salt-crusted mud cracked into large plates, almost white with dark grey shadow lines between the cracks, a few dark pebbles, dead bleached reeds and a scatter of small rusted debris. |
| `cb_terrain_b.png` | A hexagonal map tile of DRY BLEACHED GRAVEL FLAT from the Cooling Basin, a desolate drained-reservoir district: pale grey-white gravel and hardpan, dead grey scrub, scattered rusted debris and a discarded pallet, faint tyre tracks and a windblown drift of white dust. |
| `cb_obstacle_a.png` | A hexagonal map tile featuring COOLING WORKS from the Cooling Basin, a desolate drained-reservoir district: a squat immaculate concrete cooling structure with banks of louvred vents, a rusted fan housing, a steel access ladder and pipework, a puddle of dark water and a wisp of faint steam, salt crust staining the concrete base. |
| `cb_obstacle_b.png` | A hexagonal map tile featuring a DEAD INTAKE CANAL from the Cooling Basin, a desolate drained-reservoir district: a deep concrete channel crossing the tile with a sluice gate and a rusted iron trash grid, a dry cracked concrete bottom, hazard-striped edge railings and a faded warning sign, salt dust along the lip. |
| `cb_road.png` | A hexagonal map tile of a CANAL SERVICE ROADBED from the Cooling Basin, a desolate drained-reservoir district: a dry concrete canal running across the hexagon with a flat hard roadbed and a narrow raised service walkway, rusted handrails and a sluice edge, faded painted markings, salt dust and a few dead reeds. |
| `cb_pad.png` | A hexagonal map tile of a CLEARED TOWER PAD from the Cooling Basin, a desolate drained-reservoir district: a flat poured concrete pad on salt-cracked ground with faded orange hazard corner markings, swept clean, a coil of steel cable and a concrete kerb block at the edge, bleached reeds and cracked white lakebed just beyond the pad. |

---

## The Premium Floodplain — flooded (`premium_floodplain/`)

§16's **later candidate**: rooftop roads and breakwater shadows in a district that flooded because
private levees rerouted the water downhill. Every subject block below carries the **"NEVER medieval"**
clause that the first pass lacked.

| File | Subject block (verbatim) |
|---|---|
| `fp_terrain_a.png` | A hexagonal map tile of SHALLOW FLOOD WATER over a drowned MODERN city street from the Premium Floodplain, a flooded cyberpunk district: still green-brown standing water a few centimetres deep reflecting glass towers and neon, a submerged asphalt road with white lane markings and concrete kerbs visible under the clear surface, floating debris and an oil film, dead reeds at the edges. Modern poured concrete and glass, contemporary and high-tech — NEVER historical, NEVER medieval masonry, no stone balustrades, no wrought iron. |
| `fp_terrain_b.png` | A hexagonal map tile of WATERLOGGED SILTED GROUND from the Premium Floodplain, a flooded cyberpunk district: drowned silted mud over cracked poured concrete and asphalt, patches of standing water, a toppled steel street light and a sunken concrete barrier, dead reeds and floating litter, a dark waterline stain. Modern city, contemporary and high-tech — NEVER historical, NEVER medieval masonry, no stone balustrades, no wrought iron. |
| `fp_obstacle_a.png` | A hexagonal map tile featuring a HALF-SUBMERGED MODERN BUILDING from the Premium Floodplain, a flooded cyberpunk district: a luxury glass-and-concrete building drowned to its second floor, dark water lapping a stained waterline, its glazed curtain-wall frontage below the surface, a rooftop terrace with planting and a steel railing above the water, drifting debris. Modern glass and poured concrete, contemporary and high-tech — NEVER historical, NEVER medieval masonry, no stone balustrades, no wrought iron. |
| `fp_obstacle_b.png` | A hexagonal map tile featuring a BREACHED PRIVATE LEVEE from the Premium Floodplain, a flooded cyberpunk district: a collapsed modern poured-concrete flood wall with sandbags and rip-rap spilling through the breach, water rushing past, an intact section of the berm with a steel railing, a corporate warning light and a hazard sign, contemporary engineering — NEVER historical, NEVER medieval masonry. |
| `fp_road.png` | A hexagonal map tile of a ROOFTOP ROADWAY above the flood from the Premium Floodplain, a flooded cyberpunk district: an elevated private roadway carried across building rooftops, poured-concrete parapets and steel expansion joints, still flood water visible far below on both sides, asphalt lane markings and a broken steel barrier, flood stains and drifted litter. Modern concrete and steel — NEVER historical, NEVER medieval. |
| `fp_pad.png` | A hexagonal map tile of an ELEVATED DRY PLATFORM above the floodline from the Premium Floodplain, a flooded cyberpunk district: a poured-concrete pad on a raised plinth standing clear of the water, wet drag marks, orange hazard corner markings, sandbags and a pump hose and a steel barrier at the edge, flood water lapping just below. Modern concrete — NEVER historical, NEVER medieval masonry. |

---

## Wiring these to the game data

Each district's mechanical role and faction affinity are in [`ROADMAP.md` §16](../../../ROADMAP.md);
the tile *kinds* map onto [`BiomeData`](../../../scripts/world/biome_data.gd)'s `district_types`,
`unbuildable_variants` and `street_lot_variants`. A `BiomeData` resource
(`res://data/biomes/<id>.tres`) is the data home for a district's palette and variant lists; a
`BiomeTileModels` builder turns them into meshes. These concepts are the visual target for that kit —
**material and silhouette, not layout**.