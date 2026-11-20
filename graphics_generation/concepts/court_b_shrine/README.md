# Court B (shrine) — re-done as an in-game Sanctum base

Re-interpretations of [`../court_b_shrine.png`](../court_b_shrine.png): the *same idea* — a cult
court with a **shrine at its centre** — but rendered as **what the player actually sees in game**,
at the Sanctum's **true dimensions**.

## Why the original needed changing

`court_b_shrine.png` reads as a **stone castle**: tall coursed/ashlar walls, a walled courtyard.
Two problems against the shipped asset:

1. **Dimensions are wrong.** The Sanctum is **low and wide** — roughly a quarter as tall as it is
   wide. The source concept is nearly as tall as it is wide.
2. **Vocabulary is wrong.** Tall coursed masonry is the single **banned** form (bible §§3, 6–9;
   `feedback-cult-visual-vocabulary-not-medieval`). The cult **does not build walls** — it occupies
   infrastructure and ropes it off with a knee-high kerb and a pipe railing.

## The real dimensions (read from `graphics_generation/sanctum/sources/build_sanctum_compound.py`)

| | value |
|---|---|
| Footprint | the **exact 7-hex union** — seven hex prisms, radius ≈ **1.005**, at the seven hex centres |
| Overall radius | ≈ **2.77** at the corners, ≈ **2.6** across the flats (≈ **5 hex-widths wide**) |
| Height | capped at `HexMath.TOWER_MAX_HEIGHT = 1.5`; the model tops out ≈ **1.4** |
| Proportion | **low & wide** — height ≈ ¼ of width |
| Boundary | **knee-to-waist-high** board-formed concrete kerb + galvanised pipe railing (NOT a wall) |
| Floor | wet reflective concrete at z = 0 |
| Depth | the stairwell descends to **−0.50** (below-floor depth is free and not counted against the cap) |
| Camera | fixed **yaw 45 / pitch 35**, orthographic — only the +X/+Z face is ever seen |

## The four examples

| File | What it varies |
|---|---|
| `a_full_compound.png` | The faithful re-do — whole compound, hero 3/4: low concrete kerb + chain-link, central idol-shrine under a corrugated lean-to, stairwell into blackness, wet sigil floor. |
| `b_gameplay_distance.png` | Pulled back to **gameplay distance** — the compound small in frame; the **7-hex outline** and flat proportions read as they do on the board. |
| `c_scale_with_cultist.png` | Closer, with a **hooded cultist for scale** — the kerb is about chest-high; proves the wall is *low*. |
| `d_alt_shrine_pad.png` | Alternate centre treatment — the cult **seizes a salvaged utility pad** (standpipe, junction box, corrugated awning) with a three-eyed cairn, instead of a carved idol. |

Generated 2026 · `generate_image` (kind `sprite`, finish `smooth`, 768×768). Prompts below.

---

## Prompts (recorded verbatim — skill §7)

**`a_full_compound.png`**
> Orthographic isometric three-quarter view from a fixed game camera (yaw 45, pitch ~35), the whole
> model standing alone on a pure black background. This is the cult's Sanctum base AS IT ACTUALLY
> APPEARS IN GAME: a LOW AND WIDE improvised compound occupying an exact SEVEN-HEX footprint (a
> flower of seven hexes, roughly five hexes across) and only about one-and-a-half hexes tall —
> markedly WIDER than it is tall, a flat sprawling encampment of occupied ground, NEVER a walled
> castle. Its boundary is a knee-to-waist-high board-formed concrete kerb with chamfered top edges,
> topped by a galvanised steel pipe railing with chain-link panels — deliberately low enough to see
> over. Pale weathered mid-value cast concrete, stained and mossy at the base. At the CENTRE OF THE
> COURT stands a SHRINE: a low raised concrete deck carrying a squat many-armed sea-beast idol in
> weathered grey stone, sheltered by a lean-to canopy of rusted corrugated sheet on four salvaged
> steel-pipe posts, hung with two brass censers and a caged lantern, ringed by dense banks of
> dripping votive candles, a narrow red banner hung in front. Before the shrine a staircase descends
> into genuine blackness, flanked by steel handrails. Around the yard: rusted propane cylinders,
> wooden crates, junction boxes with conduit, a frayed olive tarp with a sprayed white sigil, a caged
> sodium work-lamp glowing warm orange with a red-orange halo bloom, red and violet spray sigils and
> tally marks on the wet reflective concrete floor. Warm golden key light from the upper left, deep
> near-black shadows, faint cool ambient. Hand-built and improvised from occupied urban
> infrastructure, NEVER medieval masonry, NEVER clean or mass-produced. Highly detailed game asset,
> painterly realism, matching the shipped Sanctum at its own value.

**`b_gameplay_distance.png`**
> Orthographic isometric three-quarter view from a fixed game camera (yaw 45, pitch ~35), pulled back
> to gameplay distance so the whole model is small in frame on a pure black background, exactly how
> it reads on the board. This is the cult's Sanctum base AS IT ACTUALLY APPEARS IN GAME: a LOW AND
> WIDE improvised compound occupying an exact SEVEN-HEX footprint (a flower of seven hexes, roughly
> five hexes across) and only about one-and-a-half hexes tall — the flat, sprawling proportions must
> be unmistakable, WIDER than it is tall, NEVER a walled castle. Its boundary is a knee-to-waist-high
> board-formed concrete kerb with chamfered top edges, topped by a galvanised steel pipe railing with
> chain-link panels — you can see straight over it into the yard. Pale weathered mid-value cast
> concrete, stained and mossy at the base. At the CENTRE OF THE COURT, a SHRINE: a low raised
> concrete deck with a squat many-armed sea-beast idol in grey stone under a lean-to canopy of rusted
> corrugated sheet on four salvaged steel-pipe posts, hung with brass censers and a caged lantern,
> ringed by banks of dripping votive candles. Before it a staircase descends into blackness between
> steel handrails. Around the yard: rusted propane cylinders, crates, junction boxes with conduit, a
> frayed olive tarp with a sprayed white sigil, a caged sodium work-lamp glowing warm orange with a
> red-orange halo bloom, red and violet spray sigils on wet reflective concrete. Warm golden key
> light from the upper left, deep near-black shadows, faint cool ambient. Hand-built and improvised
> from occupied urban infrastructure, NEVER medieval masonry, NEVER clean or mass-produced. Highly
> detailed game asset, painterly realism.

**`c_scale_with_cultist.png`**
> Orthographic isometric three-quarter view from a fixed game camera (yaw 45, pitch ~35), a slightly
> closer three-quarter framing on the edge of the cult's Sanctum compound, on a pure black
> background, with a single hooded cultist standing at the kerb for scale. This is the base AS IT
> ACTUALLY APPEARS IN GAME: a LOW AND WIDE improvised compound on an exact SEVEN-HEX footprint, only
> about one-and-a-half hexes tall — its boundary is a KNEE-TO-WAIST-HIGH board-formed concrete kerb
> with chamfered top edges and a galvanised steel pipe railing with chain-link panels, standing
> barely chest-high to the cultist and easy to see over; it is NEVER a tall wall or a castle. Pale
> weathered mid-value cast concrete, stained, mossy at the base, wet and reflective. Beyond the low
> kerb, at the centre of the court, a SHRINE rises: a squat many-armed sea-beast idol in grey stone
> on a low concrete deck, under a lean-to canopy of rusted corrugated sheet on four salvaged
> steel-pipe posts, hung with a brass censer and a caged lantern, ringed by dripping votive candles;
> a staircase descends into blackness between steel handrails. Around the yard: rusted propane
> cylinders, crates, junction boxes with conduit, a frayed olive tarp with a sprayed white sigil, a
> caged sodium work-lamp glowing warm orange with a red-orange halo bloom, red and violet spray
> sigils on wet reflective concrete. Warm golden key light from the upper left, deep near-black
> shadows, faint cool ambient. Hand-built and improvised from occupied urban infrastructure, NEVER
> medieval masonry, NEVER clean or mass-produced. Highly detailed game asset, painterly realism.

**`d_alt_shrine_pad.png`**
> Orthographic isometric three-quarter view from a fixed game camera (yaw 45, pitch ~35), the whole
> model standing alone on a pure black background. This is the cult's Sanctum base AS IT ACTUALLY
> APPEARS IN GAME: a LOW AND WIDE improvised compound occupying an exact SEVEN-HEX footprint (roughly
> five hexes across) and only about one-and-a-half hexes tall — flat and sprawling, WIDER than it is
> tall, NEVER a walled castle. Its boundary is a knee-to-waist-high board-formed concrete kerb with
> chamfered top edges, topped by a galvanised steel pipe railing and chain-link panels, easy to see
> over. Pale weathered mid-value cast concrete, stained, mossy at the base. At the CENTRE OF THE
> COURT, the cult has seized a salvaged utility structure rather than built a temple: a squat
> board-formed concrete equipment pad with an old standpipe and a junction box, wrapped in
> scaffolding tube and hung with a low rusted corrugated awning; on the pad sits a crude piled stone
> cairn idol with three painted eyes, surrounded by dripping votive candles and a coil of cable; a
> length of culvert pipe lies at its foot. Before it a staircase descends into blackness between
> steel handrails. Around the yard: rusted propane cylinders, crates, a frayed olive tarp with a
> sprayed white sigil, a caged sodium work-lamp glowing warm orange with a red-orange halo bloom, red
> and violet spray sigils and tally marks on the wet reflective concrete floor. Warm golden key light
> from the upper left, deep near-black shadows, faint cool ambient. Hand-built and improvised from
> occupied urban infrastructure, NEVER medieval masonry, NEVER clean or mass-produced. Highly
> detailed game asset, painterly realism, matching the shipped Sanctum at its own value.

---

## Refined variant A — sharper shrine idol (3 takes)

Variant A's idol read as **muddy**. These three re-run the same compound and make the idol the
sharp, high-contrast focal point (it is described generically — the image provider rejects named
characters).

| File | Idol treatment |
|---|---|
| `a2_sharp_idol.png` | Pale sculpted stone idol — clean crisp edges, deep hard shadows, warm key + cool rim light so the silhouette reads instantly. |
| `a3_idol_on_plinth.png` | Raised on a plinth, boldly carved, deliberately uncluttered — the cleanest, most readable idol. |
| `a4_basalt_idol.png` | Dark chiselled basalt with gold-inlaid eyes and red sigils — the highest contrast, most striking icon. |

Prompts recorded verbatim below (each = a compound block in the style of variant A + its idol block).

## Dimension-accurate schematic

[`schematic.svg`](schematic.svg) — an **orthographic PLAN** (the 7-hex platform, the compound
boundary, the 300° gate edge, the stairwell shaft and the shrine) and a **true-scale ELEVATION**,
**computed directly from the constants** in
`graphics_generation/sanctum/sources/build_sanctum_compound.py`. This is the strictly-accurate
reference the painted concepts approximate.

| Quantity | Value (source) |
|---|---|
| Platform | 7 hexes, prism **R = 1.005** each (7-hex union) |
| Overall width | ≈**5.49 u** across the bracket edges · ≈**5.32 u** across the corners |
| Boundary | parapet **apothem 2.40** (`WALL_APOTHEM`) · corner **R 2.771** (`WALL_R`) |
| Deck | **z = 0.34** (`PLAT`) |
| Parapet top | **z = 0.60** (`WALL_TOP` = PLAT + 0.26) |
| Railing top | **z = 1.10** (`RAIL_TOP` = WALL_TOP + 0.50) |
| Tallest | ≈**1.45** gate sign (`SIGN_TOP`); lean-to ridge ≈1.36; cap **1.50** |
| Stairwell | **1.24 × 1.90 u** at (0.30, −0.34), floor **z = −0.50** (depth, not counted) |
| Proportion | height ≈ **0.26 × width** — LOW & WIDE |

Regenerate the schematic with the `execute_script` snippet that writes `schematic.svg` (the
geometry is computed from `HEX_R`, `NB = √3·HEX_R`, `WALL_R`, `REACH = √3·HEX_R + HEX_R`).

### Refined-A prompts (verbatim)

**`a2_sharp_idol.png`** and **`a3_idol_on_plinth.png`** and **`a4_basalt_idol.png`** — see the
recorded text in the build history; the shared frame is:

> Orthographic isometric three-quarter view from a fixed game camera (yaw 45, pitch ~35), on a pure
> black background. The cult's Sanctum base as it appears in game: a LOW AND WIDE improvised
> compound on an exact SEVEN-HEX footprint (roughly five hexes across), only about one-and-a-half
> hexes tall, WIDER than it is tall, never a walled castle; boundary is a knee-to-waist-high
> board-formed concrete kerb with a galvanised steel pipe railing and chain-link panels. Pale
> weathered mid-value cast concrete, wet and reflective. **[IDOL BLOCK]**. Around the yard: rusted
> propane cylinders, crates, junction boxes with conduit, a frayed olive tarp with a sprayed white
> sigil, a caged sodium work-lamp glowing warm orange, red and violet spray sigils on wet reflective
> concrete. Warm golden key light from the upper left, deep near-black shadows, faint cool ambient.
> Hand-built and improvised from occupied urban infrastructure, NEVER medieval masonry, NEVER clean
> or mass-produced. Highly detailed game asset, painterly realism.

**[IDOL BLOCK] a2:**
> At the CENTRE OF THE COURT stands the SHRINE: a low raised concrete deck carrying a
> SHARPLY-SCULPTED idol of a tentacled deep-sea god — a bulbous toothed head, drooping facial
> tentacles, folded leathery wings and hunched humanoid shoulders — carved with clean crisp edges
> and deep hard shadows so its silhouette reads instantly and strikingly. It is lit as the clear
> focal point by a strong warm key and a hard cool rim light that separates it from the dark. It is
> sheltered by a lean-to canopy of rusted corrugated sheet on four salvaged steel-pipe posts, hung
> with two brass censers and a caged lantern, ringed by dense banks of dripping votive candles.
> Before the shrine a staircase descends into genuine blackness between steel handrails.

**[IDOL BLOCK] a3:**
> At the centre, standing proud on a raised concrete plinth, a BOLDLY-CARVED idol of a tentacled
> deep-sea god: a sharp, high-contrast sculpture with a bulbous head, writhing facial tentacles and
> folded wings, its form crisp, clean and unmistakable, uncluttered, picked out by a strong warm key
> and a cold rim light so it pops sharply out of the gloom. A lean-to canopy of rusted corrugated
> sheet on steel-pipe posts rises behind and above it; banks of dripping votive candles ring its
> base; a stair descends into blackness nearby.

**[IDOL BLOCK] a4:**
> At the CENTRE OF THE COURT, a high-contrast idol carved in dark chiselled basalt with sharp
> deep-cut facets: the head of a tentacled deep-sea god with a bulbous crown, emerging facial
> tentacles and folded wings, its eyes inlaid with polished gold and its brow painted with red
> sigils. Hard crisp edges, strong specular highlights and deep black shadow make it read as a
> striking, unmistakable icon; it stands on a low concrete deck under a lean-to canopy of rusted
> corrugated sheet on steel-pipe posts, ringed by dripping votive candles. Before it a stair
> descends into blackness between steel handrails.

## A4 — provably in dimension

[`a4_in_dimension.html`](a4_in_dimension.html) overlays the **exact** Sanctum geometry on
[`a4_basalt_idol.png`](a4_basalt_idol.png): the 7-hex platform, the boundary hexagon, the 300°
gate edge, the stairwell shaft and the shrine position, plus a scale bar.

- **Art scale, measured not guessed:** the compound's fence fills the 768 px frame and the fence is
  **4.80 u** corner-to-corner (2 × 2.400), so **1 u ≈ 160 px** — and the 5.49 u platform is,
  correctly, **cropped** slightly at the sides.
- **Overlay geometry is from code** (`build_sanctum_compound.py`), not traced from the picture.
- **Caveat (honest):** the *alignment* to the painted ground plane is **fitted** — the generator's
  camera is not the game's orthographic camera, and the art is cropped at the sides — so this is a
  scale-locked overlay, not a photographic match.

**Finding.** The overlay exposes a real discrepancy: the art puts the **idol at the compound
centre**, while the model's shrine sits **offset to (1.35, 1.30)** — the green marker in the plate.
A concept meant to represent the asset should move the shrine off-centre (or the model should move
it to the centre).

## A4b — shrine off-centre, re-shot for a 1:1 fit

Three re-shoots ([`a4b_shrine_rear_1/2/3.png`](a4b_shrine_rear_1.png)) with the **shrine moved
off-centre to the right-rear** and the **whole compound framed with margin** (nothing cropped), so
the exact overlay could be fitted. Plate: [`a4b_in_dimension.html`](a4b_in_dimension.html).

**Outcome, stated honestly:**
- The re-shoots are a **better concept** — the shrine is now off-centre (matching the model's
  (1.35, 1.30) offset) and the full hexagonal footprint is visible.
- The overlay's **boundary now traces the kerb** (that is the pinned fit), and it carries a scale bar.
- But a **true 1:1 overlay is not achievable**: the generator's render is **not** the game's
  orthographic camera **and is internally projection-inconsistent** — the stairwell pit and the idol
  do not agree with any single ground-plane affine, so no parameter set lands every feature at once.
  The overlay is therefore **fitted to the kerb**, not photographic.
- The **exact** reference remains [`schematic.svg`](schematic.svg) (plan + elevation from the code).

## Blockout — the **provable** plate ([`blockout_provable.png`](blockout_provable.png))

A Godot scene (`graphics_generation/court_b_shrine_blockout/blockout.tscn` + `blockout.gd`) builds the
compound's **exact** footprint / height geometry straight from the constants in
`graphics_generation/sanctum/sources/build_sanctum_compound.py`, renders it from the **true game
camera** (`CameraRig`: orthographic, yaw 45 / pitch 35 — verified in `scripts/world/camera_rig.gd`),
and annotates every level with `Camera3D.unproject_position()`, so each label sits **exactly** where
the geometry is. Nothing is fitted.

- **It is the answer to "provably in dimension."** The cyan 7-hex grid lands on the platform, the
  gold hexagon lands on the kerb, the green outline lands on the shrine deck, the red segment is the
  gate edge — all by construction, from the same numbers, through the same camera.
- **Why the generator art can only be *fitted*:** the AI render is neither the game's camera nor
  internally projection-consistent, so [`a4b_in_dimension.html`](a4b_in_dimension.html) can only be
  pinned to the kerb. This blockout is exact instead of fitted.
- **Reproduce:** run `blockout.tscn`; it writes `blockout_capture.png` and prints the world→pixel
  scale (≈83 px per world unit at ortho size 6.4, viewport 1152×648).

---

## Reference

- Source concept: [`../court_b_shrine.png`](../court_b_shrine.png) (and the sibling
  `court_a_dais.png` / `court_c_sigil.png`)
- The shipped asset this matches: `res://graphics_generation/sanctum/` (`BUILD.md`, `RESULTS.md`)
- Dimension source of truth: `res://graphics_generation/sanctum/sources/build_sanctum_compound.py`
- Style brief: [`../README.md`](../README.md) · Tone: `res://DESIGN_BIBLE.md`