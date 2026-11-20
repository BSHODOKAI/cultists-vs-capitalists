---
name: create-3d-asset
description: Use when generating or replacing 3D graphics for cultists-vs-capitalists — a tower, unit, boss, or prop (base, objective site, environment piece). Covers the Blender → GLB pipeline, per-asset scale and height budgets, the cult's salvaged-infrastructure visual vocabulary, texture generation and map derivation, the self-checking build script, the capture/verification harness, and the traps that each cost real hours. The Sanctum is the worked example and the fidelity baseline.
---

# Generating 3D Assets

The project ships **one** real 3D asset: the Cult Sanctum
(`res://graphics_generation/sanctum/assets/sanctum_compound.glb`). Everything else is a
procedural placeholder built by `PlaceholderModels` / `TowerView` / `EnemyMoverView`. This
skill is the pipeline for replacing placeholders with authored assets at concept fidelity,
derived from the Sanctum's build.

**The Sanctum is the reference implementation of everything below.** When in doubt, read
`res://graphics_generation/sanctum/sources/build_sanctum_compound.py` and its
`res://graphics_generation/sanctum/BUILD.md`. The record of what went wrong and what fixed it
is `res://graphics_generation/sanctum/RESULTS.md` — read it before you start, not after.

---

## 1. The one rule that matters most: verify the artifact that ships

Every expensive mistake in the Sanctum's history was a **false verification**, not a bad model:

- A build script counted its **inputs** and reported a healthy part count while the export
  silently dropped 448 of 449 objects. The counter proved nothing.
- A capture harness rendered a build **several revisions old** and its measurements were
  therefore worthless.
- An AABB "clipping report" flagged three overlaps that were all artefacts of long bounding
  boxes — none were real.

**So:** measure the thing that ships (the imported `.glb`, the rendered pixels), never the
scene that produced it. If two builds measure identically, suspect a stale cache before you
conclude anything about the model.

---

## 2. Per-asset parameters

Read these from code every time — do not hardcode from this table, which can drift.

| Asset kind | Footprint | Height budget | Facing | Palette |
|---|---|---|---|---|
| **Tower** | 1 hex; keep geometry inside a **0.866** radius (the hex apothem). Procedural towers use a ~0.56 plinth radius. | **1.5** = `HexMath.TOWER_MAX_HEIGHT`, measured from **z = 0 upward** | Instanced by `TowerView`; a Blender **−Y front** presents correctly at `rotation.y = PI * 0.25` | The tower's own theme from `TOWERS.md` |
| **Unit / boss** | Well inside one hex | Grounded at **Y = 0**; keep small (~0.5–0.6) so 60 units on one path still read | **Must face −Z** (the direction of travel), per `PlaceholderModels` | Faction palette (Syndicate / Iron Board / Hostile Takeover / Skyline) |
| **Prop — base** | 7-hex union | 1.5. The Sanctum's mesh tops at **1.450** (0.05 headroom) | `PathView` mounts it at `rotation.y = 0.0`; its gate is built at **Blender 300°** to agree with `PathConstants.BASE_EXIT_DIR` | Full cult palette |
| **Prop — objective site / environment** | 1 hex | 1.5 | As the instancing code requires | Full cult palette |

**Height is measured from z = 0 UP. Depth below z = 0 is free and is not counted.** The
Sanctum's stairwell floors at **−0.50** for exactly this reason; do not flatten a design to
stay "under" a cap that only applies to the part above the hex floor.

**Scale reference:** `HexMath.HEX_SIZE = 1.0` is the hex **center-to-corner** radius. Apothem
is `sqrt(3)/2 ≈ 0.866`. A 7-hex union spans ≈ **2.598** (corner) / **2.732** (across flats) —
so a 7-hex prop's overall radius is ~**2.7–3.0**, not 2.75 by guesswork.

---

## 3. The visual vocabulary — cult vs. corporate

Authority: `res://DESIGN_BIBLE.md` §§3, 6–9. The cult's pillar is **salvaged things made
sacred**: it does not build, it *occupies* infrastructure and ropes it off.

**Cult materials — use these:** board-formed concrete, steel pipe railing, chain-link and
hazard fencing, scaffold tube, corrugated sheet, rolled shutters, junction boxes, cable runs,
propane cylinders, bus-shelter frames, billboard fragments, tarps, vitreous subway tile
(cream / teal), turnstiles, caged sodium lamps, votive candles, red/violet spray sigils,
oil drums, cheap plywood, pallets.

**Banned — this is the failure mode the art has actually drifted into:** curtain walls, ashlar
courses, crenellations, buttresses, coping stones, gatehouse post-and-lintel-arch assemblies,
corner piers with caps. Anything that reads **medieval masonry** is wrong. The cult has no
walls; it has fences, tarps and railings around salvage.

Corporate assets invert this deliberately: sleek, clean, branded, mass-produced, military-grade
hardware. §7 forbids giving the *cult* those.

**Judge an asset against a concept image, not against the tiles around it.** The concepts in
`res://graphics_generation/concepts/` are the target **at their own value** — match them as
closely as possible. Do not darken an asset to fit a terrain tile, and do not restyle tiles to
suit an asset. Warmth is correct where the concept is warm.

---

## 4. The pipeline

### 4.1 Build the model (Blender)

Write a self-checking Python build script, run it with Ziva's `blender` tool on `blank.blend`,
and save the `.blend` beside it. Start from `templates/build_asset.py` in this skill, or copy
the structure of `graphics_generation/sanctum/sources/build_sanctum_compound.py`.

```
exec(compile(open('<abs path>/build_<asset>.py').read(), 'build_asset', 'exec'))
```

Export the `.glb` with every texture embedded.

Coordinate traps, which are absolute:
- **Blender is Z-up, Godot is Y-up.**
- **glTF maps Blender −Y → Godot +Z.**
- **A rotation of A° about Blender Z becomes −A in Godot's (x, z).**
- A flat sheet built with its thickness on Z exports **standing on end**.

### 4.2 Self-checks the build script must perform

These are what make a build trustworthy:

1. **Assert the real mesh height** from the *joined* result, counting only z ≥ 0. (Do this
   after `convert(target='MESH')`, because `join()` discards modifiers.)
2. **Rank the tallest parts by name.** When an assert fails, this names the culprit in one
   line instead of an afternoon. (It was how a 1.490 gate cable was found.)
3. **Clipping audit with a vertex-gap verdict.** Compare every part's world AABB against every
   other and report pairs sharing >30% of the smaller. Then — because AABB overlap cannot tell
   nesting from clipping — measure the actual vertex gap for each flagged pair. Report the gap.
   The box list is a "look here" list, never a defect list.
4. **Part / primitive / decal counts and an unjoined count**, printed after the join.

### 4.3 Textures

Generate seamless tiles (`generate_image`, `kind: "tile"`), then derive the maps. The Sanctum's
`graphics_generation/sanctum/sources/derive_maps.gd` is the working tool: a `JOBS` list
(albedo → normal out, strength, roughness, metallic) and a `RECOLOR` list for idempotent
recolours. Load it and call `run()` via `execute_script`.

Rules:
- **A normal map must derive from its own albedo.** Deriving from a different height source
  produces moiré. The `JOBS` list is the source of truth for what a texture's maps are.
- **Metallic stays ≤ 0.10.** `main.tscn` has no reflection source, so a strongly metallic
  surface renders **black**.
- **Material `texmat` supports an `emissive` parameter** (links the same image to Base Color +
  Emission Color, exports via `KHR_materials_emissive_strength`). Use it for lit signs rather
  than a flat pale colour.
- **Recolour must be idempotent**: write to a `_base.png` source and a derived output, so
  re-running does not compound the shift.
- **Texture features must land at the concept's feature size.** `UV_TILE` (the Sanctum uses
  **1.50**) is not a "more detail" knob — the wrong value reads as noise. Whole surfaces want
  **cube projection at a fixed world scale**; `smart_project` is for unique decals only (it
  packs islands far too densely — the Sanctum once had ~900 islands on a 512 atlas, ~17 px per
  face, which reads as blur).
- Generated images land in `res://assets/generated/`; **move** them next to the build's other
  textures before deriving.

### 4.4 Mount it in the game

- Register the GLB path as **one constant** and have every reader use it — the Sanctum's
  `PathView.SANCTUM_GLB_PATH` is read by `TerrainView` too, so the two cannot disagree.
- Never duplicate that path as a local literal (it was duplicated once, and drifted).
- Gate the visual on the file existing (`ResourceLoader.exists`) and fall back to the
  placeholder **loudly** (`push_error`), so a missing asset degrades instead of vanishing.
- Assets loaded at runtime by `preload` in a view script are **load-bearing** — a file that
  looks like a spike leftover may be a texture the game cannot boot without. Grep before
  deleting.

### 4.5 Verify

```
templates/capture_asset.gd   →   a capture scene, tagged by BUILD_TAG
```

1. **Delete the import cache** (`<asset>.glb.import` + `.godot/imported/<asset>.glb-*`) after
   every Blender export, then reopen a scene.
2. **The first run after clearing ALWAYS fails** (`No loader found for resource`). That *is*
   the reimport. **Run it a second time.**
3. **Bump `BUILD_TAG`** on every rebuild — `view_image` caches by path, so a reused filename
   shows you the previous picture.
4. **Measure the model pixels only.** The harness renders on black, so whole-image stats are
   meaningless: measure the non-black pixels (mean RGB, spread, neighbour-pixel delta) and
   compare against a concept.
5. Confirm the **live import** by printing instantiated node names — the cheapest tell that you
   are looking at the current build.

Lighting contract to capture under (read it from `scenes/main.tscn`, do not invent it): a
directional key at ~1.15–1.2 energy, a warm-to-lavender ambient at ~0.62, SSAO on, linear
tone mapping.

---

## 5. Camera reality

**The camera never orbits.** Fixed yaw 45°, pitch 35°, rotation disabled. Only the world's
**+X/+Z face** is ever visible. An asset with a front must be rotated to face it, and an asset
whose detail lives on its back is invisible. Design for the one angle the player has.

---

## 6. Trap checklist

- **`join()` merges the SELECTED objects**, not the one you think, and discards modifiers —
  call `convert(target='MESH')` first, and keep a count of what you are joining.
- **The `objs` list holds curves as well as meshes**, so a vertex account only means anything
  after the convert.
- **A solid prism buries whatever is inside it.** The Sanctum's stairwell sat inside unbroken
  floor for four revisions; it needed a real boolean `DIFFERENCE` cut against the platform
  prisms. If you want a hole, cut a hole.
- **Texture cannot fix a missing edge.** Articulation is geometry. If two forms must read as
  separate, model them separately.
- **`bpy.ops.uv.smart_project` needs edit mode** — it raises `poll() failed` in object mode.
- **A scene preview cannot catch a broken export.** Open the `.glb`'s import result.
- **A node that is not in the tree returns an identity `global_transform`** — measure after
  adding it, not before.
- **Godot's glTF importer extracts embedded textures to sidecar PNGs** beside the GLB
  (`<asset>_tex_*.png`, `<asset>_mr_*.png`) and the imported scene references those. They are
  a generated artifact: deleting them and the `.import` forces a reimport that regenerates
  them. Never hand-edit them, and never assume a `.glb` with embedded textures needs no
  sidecars in Godot.
- **`Image.load_from_file("res://...")` logs a hard ERROR and still returns a correct image.**
- **Do not run `run_tests` and `run_scene` in one batch**, and do not run the full
  `res://tests` directory (it exceeds the timeout) — run targeted suites.

---

## 7. Documentation duty — record the prompt

**When you generate a texture, a concept, or any reference image, write the prompt and its
parameters down next to the output, in the same change.**

This is a hard rule, and it exists because the concept art for this project was generated
without it: eleven images that the whole art direction now points at, and not one prompt
recorded in the repo. `graphics_generation/concepts/README.md` had to be **reconstructed**
from design notes and memory, and the original wording is gone.

Prompt records go with the asset. For a texture, a line in the build tool's job list or a
sibling `.md`. For a concept, an entry in the concepts README.

---

## 8. Decision log — the choices already made, and why

Do not relitigate these without new evidence:

| Decision | Because |
|---|---|
| Concepts are the target **at their own value** | An earlier pass darkened the asset to match terrain tiles; it was reversed. Match the concept. |
| Height cap measured **from z = 0 up**; below is free | Drove the stairwell pit design. |
| Metallic **≤ 0.10** | No reflection source exists, so metal renders black. |
| Normals derive **from their own albedo** | Avoids moiré; mismatched-normal avoidance. |
| Verify the **artifact**, not the scene | Export counters and stale caches had both lied. |
| Cult = **occupied infrastructure**, never medieval | The stated failure mode of the art so far. |
| One constant for the GLB path | It was duplicated once and drifted. |
| Concrete is **crisp**; articulation is geometry | Texture cannot manufacture an edge. |

---

## 9. Templates

- `templates/build_asset.py` — a self-checking Blender build skeleton: the primitive helpers,
  the UV/naming conventions, and the assert / tallest-parts / clipping-audit blocks wired up.
- `templates/capture_asset.gd` — a minimal capture harness: fixed camera, black background,
  `BUILD_TAG`-versioned output, and a model-pixel measurement print.

Copy them, rename, and put the numbers from §2 in.