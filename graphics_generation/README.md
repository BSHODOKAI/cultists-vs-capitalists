# graphics_generation — authored 3D assets

The project's 3D asset pipeline. This was born as a "visual spike" for one asset and is now the
real pipeline; the Sanctum is its one shipped result.

**Entry point for generating a new asset: the `create-3d-asset` skill**
(`.ziva/skills/create-3d-asset/SKILL.md`). It carries the pipeline, the per-asset scale and
height budgets, the cult's visual vocabulary, and the traps — each of which cost real hours to
learn. Read it before starting.

## What is here

```
graphics_generation/
├── concepts/            # 11 concept images — THE FIDELITY TARGET (README has the brief)
├── sanctum/             # the shipped asset + the pipeline that built it
│   ├── BUILD.md         # how to build, verify and judge it; the traps
│   ├── RESULTS.md       # the revision record: what was wrong, what fixed it
│   ├── PLAN.md          # the original plan
│   ├── assets/          # sanctum_compound.glb (SHIPPED) + texture tiles
│   ├── sources/         # build_sanctum_compound.py, sanctum_compound.blend, derive_maps.gd
│   └── capture_*.gd/.tscn, lighting_ab.*   # verification harnesses
└── (this file)
```

## What ships, and what only looks like it ships

Loaded at runtime — **do not delete, do not move without updating the reader**:

| File | Read by |
|---|---|
| `sanctum/assets/sanctum_compound.glb` | `scripts/world/path_view.gd` (`SANCTUM_GLB_PATH`) and `scripts/world/terrain_view.gd` |
| `sanctum/assets/avenue.gdshader` | `scripts/world/path_view.gd` |
| `sanctum/assets/spike_cult_seal.res` | `scripts/world/tower_view.gd` |
| `sanctum/assets/spike_iron_board.res` | `scripts/world/enemy_mover_view.gd` |

The `spike_*` files date from the original spike and are named like leftovers, but two of them
are **load-bearing runtime textures**. Grep before deleting anything here.

Everything else in `sanctum/assets/` is either an input to the Blender build
(`tex_*`, `mr_*`, `hgt_*`, `decal_*`) or a **generated artifact** — Godot's glTF importer
extracts the GLB's embedded textures into `sanctum_compound_tex_*` / `_mr_*` PNGs and the
imported scene references those. Never hand-edit them; they regenerate on import.

## Rules of the road

1. **`HexMath.TOWER_MAX_HEIGHT = 1.5`, measured from z = 0 upward. Depth below is free.**
2. **Read the budget from code, never from a doc** — this one included.
3. **The camera never orbits.** Fixed yaw 45°, pitch 35°. Only the +X/+Z face is ever visible.
4. **Verify the artifact that ships**, not the scene that produced it.
5. **Bump `BUILD_TAG` on every rebuild** — captures are cached by path.
6. **The first run after clearing the import cache always fails.** Run it again.
7. **Record the generation prompt** next to any image you generate. See `concepts/README.md`
   for why this is now a hard rule.

## History

The folder was `initial_visual_spike/` and held four model iterations (`cult_sanctum`,
`sanctum_subway`, `sanctum_massing`, `sanctum_compound`), ~2250 versioned capture PNGs, and
their `.blend` sources. It was consolidated to `sanctum/` with the three superseded models, all
captures, and the orphaned files removed; the concepts moved up to `concepts/`. What is left is
the pipeline, the harnesses, the record, and the one asset that ships.