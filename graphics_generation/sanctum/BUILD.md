# Sanctum — build pipeline and traps

The Cult Sanctum is the project's reference "finished" 3D asset: the fidelity baseline the
other towers should be brought up to. Everything in this folder is either the editable source
of that asset or a harness used to build and judge it.

**One file here is loaded at runtime:** `assets/sanctum_compound.glb`, mounted by
`scripts/world/path_view.gd` (`SANCTUM_GLB_PATH`). `scripts/world/terrain_view.gd` reads the
same constant to decide that the base hexes draw no ground tile — the model's platform is the
ground on those hexes. Also runtime-load-bearing, though they look like spike leftovers:
`assets/spike_cult_seal.res` (`tower_view.gd`) and `assets/spike_iron_board.res`
(`enemy_mover_view.gd`). Nothing else here ships.

## Layout

| Path | What it is |
|---|---|
| `assets/sanctum_compound.glb` | **The shipped asset.** ~27 MB with the textures embedded. Note that Godot's glTF importer *extracts* those embedded images to `sanctum_compound_tex_*` / `sanctum_compound_mr_*` PNGs beside the GLB, and the imported scene references **those**, not the GLB's internal copies. The sidecars are a generated artifact — the importer recreates them — so never delete them expecting the GLB to stand alone, and never treat them as hand-authored. |
| `assets/tex_*.png`, `mr_*.png` | Albedo tiles and their metallic/roughness maps. Inputs to the Blender build. |
| `assets/hgt_*.png` | Height sources, kept for tiles whose normal is *not* derived from the albedo. |
| `assets/decal_*.png` | Grime, moss and sigil decals. |
| `assets/avenue.gdshader` | Road surface shader. **Runtime** — preloaded by `path_view.gd`. |
| `sources/build_sanctum_compound.py` | The Blender build script. The single source of truth for the model. |
| `sources/sanctum_compound.blend` | The saved Blender scene the script produces. |
| `sources/derive_maps.gd` | Godot tool that derives normal / metallic-roughness maps from albedos. |
| `capture_sanctum.gd/.tscn` | Renders the asset in isolation at true gameplay camera scale. |
| `lighting_ab.gd/.tscn`, `capture_nail_gun.gd/.tscn` | Working examples of the same harness: a lighting A/B rig and a second asset capture. |
| `PLAN.md` | The original plan. |
| `RESULTS.md` | **The record.** Every revision, what was wrong, what fixed it. Read this before changing the model. |

## Pipeline

1. **Build the model in Blender.** `sources/build_sanctum_compound.py` builds it and exports
   `assets/sanctum_compound.glb` with every texture embedded. Run it through Ziva's `blender`
   tool on `blank.blend`, saving to `sources/sanctum_compound.blend`:

   ```
   exec(compile(open('<...>/sanctum/sources/build_sanctum_compound.py').read(), 'build_compound', 'exec'))
   ```

   The script is **self-checking**: it asserts the mesh's real height, ranks the tallest parts
   by name, and runs an AABB clipping audit with a vertex-gap verdict. Read its output — it is
   what catches a silent export.

2. **Regenerate derived maps** if any albedo changed. `sources/derive_maps.gd` holds a `JOBS`
   list (albedo → normal out, strength, roughness, metallic) and a `RECOLOR` list. Load it and
   call `run()` via `execute_script`.

3. **Reimport, then capture.** `capture_sanctum.gd` renders close, front, top-down and eight
   azimuths at gameplay scale into `captures/`.

4. **Judge by measurement, not by eye.** See "Judging a render" below.

## Rules the model obeys

These were each learned the hard way; `RESULTS.md` has the story behind each.

- **Height is measured from z = 0 (hex floor) *upward*, and tops out at 1.5**
  (`HexMath.TOWER_MAX_HEIGHT`). Depth *below* z = 0 is free and is not counted. The stairwell
  shaft floors at −0.50 precisely because of this.
- **The camera never orbits.** Fixed yaw 45°, pitch 35°, rotation disabled. Only the world's
  +X/+Z face is ever visible, so anything with a front must be *rotated to face it*.
- **Cult vocabulary is salvaged urban infrastructure, never medieval.** Board-formed concrete,
  steel pipe railing, chain-link, corrugated sheet, junction boxes, cable runs, vitreous subway
  tile, caged lamps, votive candles, spray sigils. Banned forms: ashlar courses, crenellations,
  buttresses, post-and-lintel gatehouses, corner piers with caps. The cult does not build
  walls — it occupies infrastructure and ropes it off. See `DESIGN_BIBLE.md` §§3, 6–9.
- **Texture features must land at the concept's feature size.** `UV_TILE` (now 1.50) is not a
  "more detail" knob; the wrong value makes texture read as noise.
- **A normal map must derive from its own albedo.** Mismatched normals moiré. Do not derive a
  normal from a different height source than the albedo it accompanies.
- **Metallic stays ≤ 0.10.** `main.tscn` has no reflection source, so a strongly metallic
  surface renders black.
- **Texture cannot fix a missing edge.** Articulation has to be geometry.

## Judging a render

`view_image` caches by path, so every capture is tagged by `BUILD_TAG` in `capture_sanctum.gd`.
**Bump the tag on every rebuild** or you will judge the previous picture.

The harness renders on a black background, so whole-image statistics are meaningless. Measure
the **model pixels only** (the non-black ones): mean RGB, spread, and neighbour-pixel delta.
Then compare against a concept. Identical stats on two builds means a **stale asset** — check
the import cache, do not re-judge.

## Traps that cost real time here

- **The import cache.** Godot caches imported `.glb` resources and does not reliably rescan when
  an external process (Blender) rewrites the file. A capture immediately after an export can
  render a build several revisions old. Delete the generated cache, then reopen a scene:

  ```gdscript
  var base := ProjectSettings.globalize_path("res://graphics_generation/sanctum/assets/")
  var imported := ProjectSettings.globalize_path("res://.godot/imported/")
  DirAccess.remove_absolute(base + "sanctum_compound.glb.import")
  for f in DirAccess.get_files_at(imported):
      if f.begins_with("sanctum_compound.glb-"):
          DirAccess.remove_absolute(imported + f)
  ```

  **The first run after clearing always fails** with `No loader found for resource: ...
  sanctum_compound.glb`. That is expected — it is the reimport. **Run the second time.**

  Confirm the live import before trusting anything; node names are the cheapest tell:

  ```gdscript
  var s := load("res://graphics_generation/sanctum/assets/sanctum_compound.glb") as PackedScene
  print(s.instantiate().find_children("*", "MeshInstance3D", true, false).map(func(n): return n.name))
  ```
- **`view_image` caches by path.** Re-rendering to the same filename shows the old picture.
- **Blender is Z-up, Godot is Y-up.** glTF maps Blender −Y → Godot +Z, and a rotation of A°
  about Z becomes **−A** in Godot's (x, z). A flat sheet built with its thickness on Z exports
  standing on end.
- **`join()` merges the SELECTED objects and discards modifiers.** The script calls
  `convert(target='MESH')` first to bake the chamfer modifiers. A scene preview cannot catch a
  broken export, and a build count that reports *inputs* is not a check — verify the artifact.
- **`objs` holds curves as well as meshes**, so any vertex account must run *after* the convert.
- **A solid prism buries whatever is inside it.** The stairwell was a decorative box sitting in
  solid floor for several revisions; it needed a real boolean `DIFFERENCE` cut.
- **`bpy.ops.uv.smart_project` needs edit mode** (it raises `poll() failed` in object mode), and
  it packs islands far too tightly for a whole surface — it is right for unique decals, not for
  tiling. Whole-surface tiling wants cube projection at a fixed world scale.
- **Scattered decals must stay separate objects.** They are alpha-blend surfaces; joining them
  into the opaque mesh removes them from Godot's transparency sorting.
- **AABB overlap cannot tell nesting from clipping.** The box list is a "look here" list; the
  vertex-gap measurement decides. Three flagged overlaps measured 0.057–0.308 gaps and were
  all artefacts of a long tube's bounding box.

## Derived vs. real maps

A derived normal map carries the albedo's painted detail as relief, but it does not describe
shelves, cracks or bevels the flat albedo does not show. It is a good stand-in and a poor final
asset; a real one would bake normals from a high-poly sculpt.