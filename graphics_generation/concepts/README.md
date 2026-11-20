# Concept Art — the fidelity target

Eleven concept images for the Cult Sanctum and its surrounding vocabulary. **These are the
target.** The implementations so far (including the shipped Sanctum) are approximations of
them, and where the two disagree, the concept wins.

> ### ⚠️ These prompts are RECONSTRUCTED
> The original generation prompts were **not recorded anywhere in this repository** — not in
> `RESULTS.md`, not in the build tool, not in any note. The images were generated, judged, and
> kept; the words that produced them were not.
>
> The brief below was **reconstructed** from the shipped model, `DESIGN_BIBLE.md`, `AGENTS.md`,
> and the design discussion. It describes what the images *demonstrate* and gives a reusable
> prompt template that reproduces the look — but it is **not** the verbatim original wording,
> and that wording is gone.
>
> **This is why the `create-3d-asset` skill has a hard rule requiring prompts be written down
> when an image is generated (§7).** Read the brief as a specification, not as provenance.

---

## The images

| File | What it explores |
|---|---|
| `sanctum_subway_concept.png` | The core idea at one hex: a stairwell headhouse over a subway shaft. |
| `sanctum_pump_station_concept.png` | The same idea as a flooded pump station. |
| `reskin_a_occupied_concrete.png` | **The fidelity reference.** The full compound: perimeter, yard, shelter, shaft. |
| `reskin_b_salvage_stockade.png` | The same footprint built mostly from salvage rather than concrete. |
| `reskin_c_station_headhouse.png` | A station-entrance reading: the cult has moved into a transit headhouse. |
| `court_a_dais.png` | Variant: a raised dais / platform as the centre of the cult court. |
| `court_b_shrine.png` | Variant: a shrine structure as the centre. |
| `court_c_sigil.png` | Variant: a painted sigil circle as the centre, no built structure. |
| `shrine_a_standpipe.png` | The small-shrine treatment on a standpipe. |
| `shrine_b_equipment_pad.png` | The small-shrine treatment on a salvaged equipment pad. |
| `shrine_c_pallet_dais.png` | The small-shrine treatment on a pallet dais. |

> **Tower concepts live in [`towers/`](towers/README.md)** — 33 images (3 takes × the 11 cult
> towers), each generated from the same style brief on this page. Their prompts ARE recorded there.

---

## The style brief

### The one-sentence premise

**A scrappy occult cult that occupies abandoned urban infrastructure and ropes it off, making
salvage sacred.** It does not build. It moves in, fences what it found, sprays sigils on it, and
puts candles on it.

### Composition and camera

- **3/4 isometric** view, orthographic feel — the same angle the game camera uses (fixed yaw
  45°, pitch ~35°). Subjects are shown as a **hexagonal footprint** standing alone on black.
- **Read the silhouette first.** Each concept is legible as a shape at a glance.

### What is physically there (observed vocabulary)

Every one of these appears in the concepts; they are the palette to draw from:

- **Low pale grey concrete** — weathered, stained, mossy at the base, **chamfered / rounded top
  edges**. It reads as *cast and poured*, with seams and patchiness, **never as coursed
  masonry**. These are **parapets and plinths**, not enclosing walls: they stand about knee- to
  waist-height and are not tall enough to hide what is behind them.
- **Steel pipe railing** — scaffold-tube handrails and posts, with **chain-link panels** infilled
  between them, and diamond mesh in places. Fence gates and frames.
- **Corrugated sheet roofing**, heavily rusted, seen as a lean-to over part of the yard.
- **Olive/camo tarpaulins**, hanging as canopies and wall-hangings, **frayed and torn**, each
  carrying a **sprayed white sigil**.
- **Red banners**, narrow and hanging, with white cult marks.
- **Caged sodium lamps** on posts and pinning the corners — **warm orange/yellow** glow with a
  red-orange halo bloom. These are a primary light source.
- **Votive candles**, clustered and thick with dripped wax, at floor level and on ledges.
- **Propane cylinders** — rusted red/orange, in pairs.
- **A red-and-white striped hazard barrier** — the road-works board, laid against the perimeter.
- **An electrical junction box** on a post, with conduit and cable runs.
- **Painted sigils** in **red and violet** sprayed on the concrete floor and on the walls:
  spiky radial spider/eye forms, and tally marks.
- **A stairwell descending into blackness** — handrails, concrete treads, and *something*
  suggested in the dark. The void is genuinely dark, not a lit box.
- **Wet, reflective floor** — puddles and damp staining, not a uniform gloss.
- **Rubble, leaf litter, and scattered debris** — the ground is never clean.

### Materials and value

- Concrete is **pale and mid-value**, weathered by streaks and moss — it is **not a dark
  material**. An earlier pass darkened the model to sit against the terrain tiles and that was
  reversed: **match the concept at its own value.**
- Metals are **galvanised grey, rust orange, or aged brass**. Verdigris teal appears on pipework.
- Warm accents (lamps, candles, rust, hazard red) carry the colour. The cool end is the concrete
  and the black void.

### Lighting

- **A warm golden key** from above-left, reading as late afternoon or sodium lamplight.
- **Emissive warmth** from the lamps and candles with a visible **red-orange bloom halo**.
- **Deep, near-black shadows** — strong contrast, and large areas of true black.
- A faint **cool ambient** so shadowed concrete still reads grey rather than black.

### Banned

Anything that reads as **medieval masonry or fortification**: curtain walls, ashlar courses,
crenellations, buttresses, coping stones, gatehouse assemblies (post + lintel + arch), corner
piers with caps. Also banned: clean, mass-produced, or military-grade hardware, and any
branding on cult structures (branding belongs to the corporations, who are the enemy).

---

## Reusable prompt template

For a new concept in this style, the shape that reproduces it:

> Isometric 3/4 view of a single hexagonal platform, orthographic, on a pure black background.
> A small occult cult's encampment built by occupying abandoned modern urban infrastructure —
> **[THE SPECIFIC SUBJECT]**. Low weathered pale-grey cast-concrete parapets with chamfered
> tops; steel pipe and chain-link railings; rusted corrugated sheet lean-to; frayed olive tarp
> canopies with sprayed white sigils; narrow red banners; caged sodium lamps glowing warm
> orange with a red halo; clusters of dripping votive candles; rusted propane cylinders; a
> red-and-white striped hazard barrier; electrical junction boxes with conduit. Red and violet
> spray sigils on the concrete. Wet reflective floor, rubble and leaf litter. Warm golden key
> light, deep black shadows, faint cool ambient. **Hand-built and improvised, never medieval
> masonry, never clean or mass-produced.** Highly detailed game asset, painterly realism.

Keep the "never medieval / never clean" clause in every prompt — it is the line the art has
actually drifted across.

---

## Using these images

- **Judge a render against these, not against the terrain tiles.** Compare at gameplay zoom and
  compare *model pixels* (see the `create-3d-asset` skill §4.5).
- **When you generate a new concept or texture, record its prompt here** (or beside the asset).
  That is now a required step.