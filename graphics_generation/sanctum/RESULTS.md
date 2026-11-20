# Initial graphics spike — interim results

Forward+ main scene, 1152×648, default camera zoom, pre-wave. Baseline and after runs used different random maps; these were smoke checks, not a controlled A/B. Both reported the same pre-existing AnalyticsMirror lifecycle error. The scene with all art wiring loaded after converting the three PNGs to mipmapped Godot Texture2D resources.

| Piece | Decision | Evidence and next step |
|---|---|---|
| Cult Sanctum | Revise | The Blender mesh visibly replaces the purple pedestal at the path endpoint. The opening and asymmetry read at default zoom, but the dark finish is easy to miss against the city. Add a selective edge highlight or warmer light before promoting it as a hero landmark. |
| Urban Center road | Keep for comparison | The road remains legible in the main scene and uses its existing MultiMesh material slot. Matched performance and close-up tiling remain unmeasured. |
| Hexed Nail Gun | Pending | Seal wired to base-tier housing. Still needs a close-up fit check, default/far camera review, and a chipped surface material pass. |
| Sponsor Mech | Pending | Steel-blue sponsor board and mark wired to the pooled model. Still needs a moving-model review from both sides and an armor material pass. |

PNG originals and mipmapped game resources are under assets/. Blender source is under sources/; the GLB excludes preview lighting and camera. No matched screenshots were persisted by this run.

Follow-up: a separate zoom-out input run still showed the base opening and route, but the Sanctum relied on its label and the path endpoint for recognition. The runs were not seed-matched. Added scalar roughness and metallic tuning for the Nail Gun and Sponsor Mech; this is not a full PBR texture set.

## Nail Gun decal correction

The original housing-center placement was under the hopper. The seal now sits on a dark backing plate on the exposed rear deck. `captures/nail_gun_seal_off.png` and `captures/nail_gun_seal_on.png` are matched Forward+ close-ups of the same live TowerView, toggling only the decal. Run `capture_nail_gun.tscn` from the editor to regenerate them. This is not a gameplay-zoom or pre-spike comparison. The Sponsor Mech mark is attached to its upper board, but does not have a verified capture yet. The road image is an albedo texture, not a decal.

## Sanctum concept-led redesign

Two gameplay-camera concepts are in sources/. Selected reclaimed subway for its recognizable stairs, dark opening and asymmetric roof. Blender source: sources/sanctum_subway.blend; runtime: assets/sanctum_subway.glb. Existing path anchor and gameplay preserved. Live Forward+ scene booted with the new asset. Captures contain both versions, close and at camera size 18, in an isolated label-free comparison. Decision: keep the subway silhouette for iteration; weathered surfaces and stronger focal lighting still needed to match the concept.

## All-angle subway readability

The subway remains the Sanctum direction. Preserve both concept PNGs; the unselected pump station is a reference for possible future sewer/utility art, not a discarded source. The subway model now has a double-sided transit blade, a rear stair glyph with warm lamp housings, contrasting side cladding, and amber stair accents. The capture scene saves eight isolated azimuths (`captures/sanctum_angle_*.png`). The reviewed rear capture shows two transit markers even with the entrance hidden. This is a readability pass, not proof that the asset matches the concept or reads at every gameplay zoom against the live city.

## Finish pass — weathered, dressed, lit

Built on the subway direction. Added broad tonal weathering (soot cascades, damp growth bands, rust bleeds, efflorescence), improvised dressing (crimson and sackcloth banners across the stair mouth and barricade, rope line, picket planks, sandbags, mismatched barricade, brazier), a double-sided transit blade and two hanging work lanterns, and an amber OmniLight3D at the base anchor so warm light actually falls on the surrounding concrete.

Corrections found by inspection: the flat emissive spill shapes read as yellow paint, and the lamp bulbs bloomed at emission strength 3.0. Both were retuned (spill neutralised, bulbs at 1.0), with the engines own light now doing the spill. Verified by reading the exported glTF material factors and by the regenerated captures.

Captures: captures/sanctum_subway_close.png (finish), captures/sanctum_subway_game_scale.png (camera size 18, label-free), captures/sanctum_angle_000..315.png (eight azimuths), captures/cult_sanctum_*.png (previous version for comparison). Live main-scene runs confirm the Sanctum reads against the city from the default camera.

Decision: keep. Remaining gap to the concept is fine surface detail and the sense of a crowded, lived-in shrine; the silhouette, palette and improvisation now read in game. test_integration.gd (12) and test_build_menu_ui.gd (9) pass.

	## Concept-led rebuild (chasing the concept render)
	
	The user confirmed the subway concept IS the target art direction, so the Sanctum was rebuilt from the ground up rather than polished. Rebuildable via sources/build_sanctum.py (run in Blender; textures embedded in the GLB).
	
	What changed: raised octagonal stone platform with the stairwell cut INTO it (previously the stair hung below the platform); warm sandstone masonry; rusty corrugated lean-to roof on pipe posts; plumbed riser, wall run, elbow, flanges and a brass valve wheel; painted sigil decals (eye-and-tally on the pillar, daubed mark on the banner and rear wall); canvas banner hung from the roof's front edge facing the approach; hanging lantern; five candles with wax drips; gloves, rubble, sandbags, a hazard-striped board; sloped pipe railing down the stair; tentacles in the dark opening.
	
	New assets: textures tex_warm_sandstone / tex_rusted_corrugated / tex_torn_canvas / tex_pipe_steel, decals decal_sigil_stone / decal_sigil_banner.
	
	Costs honesty: this is still flat-shaded low-poly geometry with tiled image textures, NOT a sculpt with hand-painted maps. It reads as the concept's PLACE and props, but it does not match the concept's surface fidelity. Closing that gap is a much denser asset, not another material tweak.
	
	Two capture traps worth keeping: view_image returns a cached image for a repeated path, so capture filenames are versioned by BUILD_TAG (currently v6) in capture_sanctum.gd; and Blender is Z-up while Godot is Y-up, so a flat sheet built with Z as its thickness exports standing on end (that is what made the first roof a vertical fin).
	
	Concepts are preserved under concepts/ (subway = the chosen direction; pump station = reference for future sewer/utility art).
	
	## Fidelity pass 1 — materials, relief and light
	
	Goal set by the user: the concept render is the target for "completed" graphics, and the Sanctum is the baseline that towers will be held to. This pass attacked surfaces and lighting rather than composition.
	
	**Materials.** Every textured material now carries an albedo plus a derived normal map (albedo luminance -> central-difference Sobel -> tangent-space RGB). Verified by reading the exported material factors back out of the GLB, not by eye alone. Surface weathering is scattered as separate alpha-blend decal quads (sooty grime, moss), never joined into the opaque mesh.
	
	**Geometry.** Every solid gets a BEVEL modifier (applied via convert() before the join, because join() discards modifiers on non-active objects), so edges now catch light instead of reading as flat cardboard. Added a curb course, tread nosings, coiled rope, bucket, crate, spare planks, more candles.
	
	**Lighting (the largest single improvement to feel).** main.tscn's Environment had no glow, no ambient occlusion and no tonemapping, which is much of why the game read flat next to the render. Now: ACES tonemap, SSAO, glow, mild contrast/saturation. The whole board gains contact shadow and the emissive path/lanterns bloom. This is a global change and affects every scene that uses this environment.
	
	**Three real defects found by measuring rather than assuming:**
	1. `tonemap_white` acts as exposure in Godot. Setting it to 6.0 washed the entire game out; corrected to 1.0.
	2. Godot had not reimported the GLB since the v7 build, so captures v8 and v9 rendered stale geometry. Fixed by deleting the generated `.import` + `.godot/imported/sanctum_subway.glb-*.scn` cache; the recipe is in sources/README.md. Confirm imports by printing the instantiated scene's MeshInstance3D names before trusting a capture.
	3. A performance test failed at 16.51 ms vs a 16.0 ms budget — because it was launched in the SAME batch as a scene run and the two competed for CPU. Run alone, test_12 passes. Do not run run_tests and run_scene concurrently.
	
	**Where the asset stands.** Materials, relief, weathering and lighting are now in the same language as the concept, and the Sanctum is unmistakable at gameplay zoom. But the FORMS are still crude: the concept is a dense, organic pile of individually irregular stones and props, and this is still a small set of boxes with good textures on them. The distance that remains is geometric density and hand-authored surface art, not more material tweaking.
	
	**Definition of done for the baseline (proposed).** An asset is "completed" when: it has authored albedo + normal + roughness maps (not tiled stand-ins), its silhouette reads its function from every azimuth at gameplay zoom, edges are chamfered and never read as untextured primitives, a warm/cool light pair gives it form, and it is captured from all eight angles with the decision recorded.
	
	## Fidelity pass 2 — geometric density (user-directed)
	
	The user confirmed the "completed" bar and chose density over authored textures for this pass.
	
	**What changed.** The platform is no longer an extruded band: three courses of individually sized, rotated, height-jittered stones (14/12/10) with the lower courses deliberately dirtier and darker. The stair walls are three courses of six stones each instead of a single box. Added a rubble field (52 loose stones on the floor avoiding the stair mouth, 7 pieces of debris on the treads, 18 stones spilling past the platform edge), plus barrels with hoops, a crate stack, three clay jars, a ladder, two hanging tools, a ledger stack and a beam lantern.
	
	**Tone variation was the other half of the win.** A single pale sandstone tone made 150 stones read as one soft mass. Two tinted derivatives of the albedo (`tex_stone_mid`, `tex_stone_dark`, sharing the one normal map) now vary every course and every scattered stone. This is the cheapest realism lever found so far.
	
	**Every scatter is seeded** (`BUILD_SEED = 20261104`), so rebuilds are byte-identical.
	
	**Harness improvement.** The capture scene now lights the asset the way the game does: a warm directional key, a cool fill, modest ambient, ACES tonemap. Captures before this were flat scans and under-sold the asset's form; the approved bar asks for a warm/cool light pair, so the review now includes one.
	
	**Budget.** The main mesh is ~39,000 triangles across 20 material surfaces, plus 12 alpha-blend decal quads. One of these per run is a reasonable landmark cost; this is not a budget for every tower.
	
	**Honest status against the bar.** Silhouette now reads from every azimuth; edges are chamfered; there are no untextured primitives; a warm/cool pair gives it form. Still short of the concept: the stones are chamfered boxes, not chipped irregular rock, so the surfaces read as cut slab rather than weathered masonry. Authored albedo (pass 3) plus genuinely irregular rock forms are what remain.
	
	test_integration.gd passes 12/12 after the world-lighting change. Run tests and scene runs SEPARATELY — launching both in one batch competes for CPU and produced a false perf failure earlier.
	
	## Fidelity pass 3 — irregular stone forms (user-directed)
	
	The user chose irregular forms before authored textures, on the reasoning that a better texture on a rectangular slab still reads as a rectangular slab. That was right.
	
	**What changed.** `box()` no longer builds any stone. A new `chipped()` helper builds each stone from bmesh: a plain cube whose eight corners are nudged by the seeded rng, so it still stacks but has no parallel faces and no square corners; loose rock instead starts from an icosphere. The tinted albedos were also lightened (mid 0.87/0.84/0.78, dark 0.70/0.66/0.58) — the first values were too aggressive and turned the palette muddy. Applied to the plinth courses, wall stones, coping, floor slabs, stair treads, rear wall, pillar, left block, and all loose/stair/spill rock.
	
	**Capture harness fix.** The key light was aimed from behind the model, so every face the camera could see was in shadow and the whole asset read as a dark mass. The key now comes from the camera's quadrant (`rotation_degrees = (-45, 45, 0)`) with a cool fill from behind-left, ambient up to 0.65. This alone changed the asset from "dark pile" to "readable object" — a reminder that a capture harness is part of the art pipeline and needs the same scrutiny as the asset.
	
	**Budget.** 32,968 triangles across 20 surfaces (down from 39k: chipped forms with a small bevel cost less than heavily subdivided beveled boxes).
	
	**Honest status against the bar.** The platform rim now reads as genuine chipped masonry; the silhouettes vary stone to stone and the tone variation holds up under a raking key. What is still weak: the stairwell does not read as a descending flight from the gameplay angles — the treads fill the opening so there is no visible void to read depth from. That is a composition problem, not a materials one, and it is the next thing to fix.
	
	Remaining toward "done": the stairwell read, then authored albedo (hand-painted, not tiled) with a real baked normal.
	
	## Fidelity pass 4 — the stairwell read (user-directed)
	
	The stairwell was the known weak point: the flight filled the opening completely, so from gameplay angles it read as flat paving with no depth.
	
	**What changed.** The flight is now only three steps occupying the back of the opening (tops at PLAT-.06 / -.135 / -.21), with the remainder of the opening and everything beneath the steps left as an unlit shaft: dark stone lining on both sides, a dark back wall, a dark front lip and a near-black shaft floor at PLAT-.30. A solid `Platform core` cylinder used to fill the entire interior volume and would have swallowed the shaft, so it is gone — the four floor slabs now tile the interior around the opening (front/back slabs pulled in to match). Tread nosings and the stair railing follow the new, deeper descent.
	
	Read result: the steps are clearly legible descending into darkness from the front and three-quarter views, which was the whole objective.
	
	**Flagged, not resolved: the live board looks brighter than before.** A live main-scene run after the world-lighting change reads noticeably paler and more pastel than earlier in the session. I have not isolated whether that is the environment change (ACES + ambient + glow) or just a different generated map on that seed, so I am not claiming it as a regression — but it needs a controlled before/after before the lighting change is called good. The concept's feel is dark with warm accents, not pastel, so if the brightening is real the ambient and glow want pulling back.
	
	Also worth a look next: the rusted roof reads as saturated dark red rather than brown-grey rust; the warm key in the capture harness is strong enough to make the whole asset golden.
	
	## World lighting resolved — controlled A/B
	
	The brightening flagged in pass 4 is real and was caused by the environment change, not by map variance. Proven with a controlled harness (`lighting_ab.gd` + `lighting_ab.tscn`): it instantiates main.tscn ONCE, so every preset is captured on the same seed, same map, same camera, and prints each frame's mean screen luminance. Two separate runs could never be compared this way, because launching main.tscn directly rolls a fresh random seed each time — which is exactly what made the earlier comparison unreliable.
	
	Measured mean luminance, one run:
	
	| preset | mean luminance |
	|---|---|
	| original (pre-change) | 0.4048 |
	| + SSAO only | 0.4024 |
	| + glow only (bloom 0.15, threshold 0.85) | 0.4360 |
	| + SSAO and glow | 0.4336 |
	| what shipped after pass 1 (ACES + glow + ambient 0.6) | 0.5244 |
	| tuned (linear, ambient 0.62, SSAO, glow 0.8 / bloom 0.05 / threshold 1.05) | 0.4063 |
	| **shipped now** | **0.4063** |
	
	Findings:
	1. **ACES tonemapping plus the wide glow was the wash**, +30% over the original. Glow alone accounts for +7.7%; SSAO actually lowers it slightly, which is what you want — occlusion adding contact shadow rather than light.
	2. Raising `glow_hdr_threshold` from 0.85 to 1.05 and dropping `glow_bloom` to 0.05 keeps a bloom on genuinely bright emissives (the path, the spawn gate, the Sanctum's lantern) without hazing the whole board.
	3. The shipped scene now sits within 0.4% of the original's brightness while retaining SSAO depth and emissive bloom — the depth the concept has, without the pastel wash.
	
	The `shipped` row is measured from the loaded scene with no overrides applied, so it verifies the values actually in main.tscn rather than a copy of them. test_integration.gd passes 12/12.
	
	Lesson worth keeping: a post-processing change can only be judged against an unmodified baseline captured in the SAME run. Guessing from two separate runs cost several passes here.
	
	## Authored surface maps — and the harness lighting bug that hid them
	
	### The harness was lying about colour
	Every capture up to v16 was lit by a hand-tuned approximation in `capture_sanctum.gd`: a warm
	amber key (`Color(1.0, 0.74, 0.45)` at energy 1.7) over a cool fill, with ACES tonemapping. The
	shipping game's actual light is a **white** `DirectionalLight3D` at energy **1.15** over a cool
	lavender ambient (`Color(0.55, 0.5, 0.68)` at **0.62**), tonemap **linear**.
	
	So every capture read amber, and the asset was being judged through a colour cast the game never
	applies. Worse, the obvious-looking fix — repainting the stone albedo away from warm sandstone —
	would have been compensating for a bug that existed only in the harness.
	
	`capture_sanctum.gd` now reads the Environment and the DirectionalLight3D straight out of
	`main.tscn` (instantiated but never added to the tree, so no gameplay `_ready` fires) and copies
	their real values. It prints them each run, so a capture can prove which light produced it:
	
	```
	key light: color=(1.0, 1.0, 1.0, 1.0) energy=1.15 | ambient=(0.55, 0.5, 0.68, 1.0) energy=0.62 | tonemap=0
	```
	
	### Two hardcoded materials were most of the mud
	Under honest light the model read uniformly olive-tan, and the reason was plain: `timber` was a
	flat colour `(.28, .19, .11)` covering every deck plank, crate, barrel and the ladder — the single
	largest surface area in the model — and the stone was a warm sandstone tile under a cool light,
	which multiplies to olive. Almost every other material was textured; these two were not.
	
	### What was authored
	| Material | Before | Now |
	|---|---|---|
	| Plinth / deck stone | `tex_warm_sandstone` (warm), derived-from-albedo normal | `tex_grey_stone` cool salvage masonry + `tex_grey_stone_{lit,dark}` tone variants, normal from a purpose-made height map |
	| Timber (deck, crates, barrels, ladder) | flat colour, no UV detail | `tex_old_wood` weathered planks, normal from a height map |
	| — | roughness/metallic were flat material constants | packed `mr_*.png` (roughness in G, metallic in B) driven by the height map, so recesses read dirtier and raised crests worn smoother |
	
	Normal maps are now derived from **dedicated height maps**, not from albedo luminance. That
	matters: luminance-derived normals only invent relief where the *colour* happens to change, so
	mortar joints and plank splits carried no depth. The height maps put the joints and splits where
	they actually belong. Verified in the GLB that all six textured materials carry all three maps
	(albedo + metallicRoughness + normal).
	
	Tone variants come off **one** masonry tile with a per-pixel tint (lighter sun-bleached, darker
	damp), so the courses read as different stone without tripling the texture count. `texmat()` grew
	an explicit `nrm=` argument for exactly this — variants share a single height source.
	
	### Two Blender traps hit here
	1. `texmat` derived its normal-map path from the albedo filename (`x.png` -> `x_n.png`), so a tone
		variant with no normal of its own failed the build with `Cannot read ..._lit_n.png`. Fixed with
		the explicit `nrm=` argument rather than by duplicating identical normal maps.
	2. Renaming a material variable (`stone_mid` -> `stone_lit`) left a stale reference 160 lines down;
		the build dies on a `NameError`, so grep the whole file, not the block you edited.
	
	### Result
	`captures/sanctum_subway_v18_close.png` vs `captures/sanctum_subway_v16g_close.png` is a clean
	comparison — v16g is the old warm materials already under the *corrected* harness lighting, so the
	only difference between the two captures is the materials. The model now reads as cool grey salvage
	masonry with warm accents (candle, warning board, rusted roof) instead of uniform olive mud.
	
	Remaining gap to the concept (unchanged by this pass, and the next real work): the plinth still
	reads as a splayed heap of slabs rather than a coherent masonry pit, the stairwell is not legible
	from most azimuths, and detail density is below the concept's.
	
	## Composition pass — plinth courses, the stairwell, and the model's facing
	
	### The model was showing the player its back
	`CameraRig` is fixed at yaw 45 / pitch 35 and `CAMERA_ROTATION_ENABLED = false`, so the camera
	**never orbits** — the face at world (+X, +Z) is the only face a player ever sees. `path_view.gd`
	was mounting the Sanctum at `rotation.y = -PI * 0.5`. glTF maps the model's Blender -Y (its front:
	where the flight descends and the lean-to opens) onto Godot +Z; rotating +45 deg instead of -90
	puts that front toward the camera.
	
	So the stairwell — the defining feature of a reclaimed subway entrance — was pointing squarely
	away from the player, and every close-up I had been judging had been taken from a harness angle
	the game never uses. Fixed in `path_view.gd` (`rotation.y = PI * 0.25`), and the harness now has a
	`sanctum_ingame_*` capture that applies the same rotation at CameraRig's exact yaw/pitch, so
	composition is judged from where the player stands.
	
	### The plinth was geometrically wrong, not aesthetically wrong
	`stone_ring` took a `depth` argument and callers passed **.30, .26, .22** against a course height
	of only **.13**. Every "stone" was therefore a wide flat slab whose radial depth exceeded its
	height by more than 2x, and they overlapped one another all the way around the ring — from above
	and from the game camera it read as a deck of cards splayed on the ground, which is exactly what
	the top-down capture showed.
	
	Rebuilt: blocks are now laid as courses, thin radially and wide tangentially (~2:1 width:depth),
	~.36 x .17 x .11 — plausible masonry proportions — and each course is offset by a fraction of a
	block so **joints stagger** against the course below. Staggered joints are what actually make
	masonry read as masonry rather than as aligned boxes. Size/rotation jitter was cut hard (±5% size,
	±0.7 deg) so faces stay flush and the coursing lines stay horizontal.
	
	### The stairwell
	- Three shallow treads over a .30-deep shaft read as "a wall with ledges", not a descent. Now
		**five** treads dropping .335, with the tone darkening step by step (`stone` -> `stone_dark` ->
		`dark`) so the eye is led down into the black rather than stopping at the top step.
	- The mouth was widened from .65 to .84 across so it reads as an opening, and the railing was
		moved inboard to the new edge and made to follow the descent.
	
	### A real bug this exposed: geometry below the ground plane
	Deepening the shaft, I set `SHAFT_FLOOR = PLAT - .40`, which is **z = -0.06 — below zero**. The
	model is a platform sitting on the ground, so anything below z=0 pokes through the terrain. It
	showed up as a thin stick hanging under the platform (an overlong railing upright). The shaft
	floor is now clamped above ground (`PLAT - .32`) and the tread spacing is computed from the shaft
	floor rather than assumed, so the last tread's underside lands exactly on the ground plane. Any
	railing upright is clamped with `max(z - .16, 0.0)`.
	
	### Also fixed
	- `timber` was flat colour with no texture (the largest surface area in the model) — now authored
		weathered planks; stone was warm sandstone under a cool light — now cool grey salvage masonry.
		(Details in the previous section.)
	- The canvas banner and tarp rendered as a blank white card; the canvas albedo was dulled to a
		dirty olive-grey (mean luminance .34 -> .191).
	- Loose scatter was sitting on top of the plinth at up to r=.86 and obscuring its silhouette;
		pulled in to r=.14-.62, with the spill stones pushed further out to r=.98-1.16 to read as debris
		at the foot of the wall rather than splaying off the rim.
	
	### A trap worth remembering
	`Image.load_from_file("res://...")` logs a hard `ERROR: ... load_from_file (core/io/image.cpp:2780)`
	for every call **yet still returns a correct image**. It cost time chasing a load failure that was
	not happening. The images are fine — check `get_size()` / mean luminance before believing the
	error, or pass a globalized absolute path to keep the log clean.
	
	### Remaining gap to the concept
	The platform's top surface is still a jumble of overlapping slabs (four floor slabs plus ledgers,
	planks and loose stones) that reads as clutter where the concept reads as a clean deck with one
	purposeful opening; the lantern pillar is still a plain box; and at the in-game zoom of 18 the
	whole assembly is a small blob, so detail density still lags. Next real work is the deck.
	
	## Deck pass — paving instead of plates
	
	### The deck was four slabs spanning the whole interior
	`Floor left/right/back/front` were four large plates laid edge to edge with jitter, which is
	what read as "a jumble of overlapping slabs" from the game camera. The deck is now **16 paving
	slabs** on a 6x6 grid, clipped to an octagon and cut around the stair opening.
	
	Two details make it read as paving rather than as another plate:
	- **The cut around the opening lands exactly on the shaft walls.** The opening constants
		(`MOUTH_HALF_X`, `STAIR_FRONT_Y`, `STAIR_BACK_Y`) were chosen so the deck grid's cell edges
		coincide with them, so the stair hole is bounded by straight paving joints rather than a
		ragged grid-sized gap. The mouth was reduced from .84 to .78 across to suit the grid.
	- **Slab centres sit at `PLAT`,** so their tops land exactly on `FLOOR` (the documented deck
		level) and every prop and decal that references `PLAT` keeps its original relationship. The
		shafts to the plinth's top course are deliberately left **open at the octagon corners** — the
		plinth rim reads there instead of a grid-sized notch.
	
	### The plinth courses are now exactly level
	`stone_ring` was jittering each course height by +-5%, so the three courses did not stack to a
	level `PLAT` — the plinth's top wandered by a few centimetres and any deck resting on it would
	have clashed. Course heights are now exact; the width still varies for interest. This is also
	just correct: a course is a level thing.
	
	### Three colour faults the capture made obvious
	- **White painted sigils.** `decal_sigil_stone` was white (opaque-region mean RGB 0.86, 0.84,
		0.85), so a .24 painted mark rendered as a pale card. Both sigils were multiplied down into a
		dark red-brown (0.50, 0.18, 0.15) and (0.36, 0.13, 0.12), leaving alpha untouched. Confirmed
		the material still exports `alphaMode = BLEND` — the alpha was never the problem, the colour
		was.
	- **Purple tentacles.** The `tent` material was (.17, .10, .19), which under a white key read as
		bright lavender worms lying on the deck. Now (.075, .05, .09).
	- **The deck read as white plastic.** Its slabs were drawing from `ROCK_TONES`, a third of which
		is the bleached variant — and the deck is the brightest surface in the model (horizontal, under
		a near-overhead key). Deck slabs now draw from the two non-bleached tones only.
	
	### Method note
	Twice in this pass I formed a confident theory about which object was at fault from a rendered
	image — "that white rectangle must be the grime decal" — and both times measuring the texture
	proved it wrong (the grime is dark brown; the sigil was white). Reading the texture's actual
	pixels took one call and settled it. Guess from the model, measure from the pixels.
	
	## Composition pass — deciding what the eye lands on, then clearing the way
	
	### The rule
	The Sanctum had ~150 objects on a platform 1.2 units across, all at roughly the same visual weight.
	Nothing was wrong with any individual prop; there was simply no hierarchy. The fix is a stated
	rule, then enforcement:
	
	**The approach and the stair opening are the focal lane. Nothing decorative sits there.** The lane
	spans the corridor between the two parapets (x +-0.36) from the front edge up to just past the
	stair's back edge (y 0.42) — which deliberately leaves the back strip free for the ladder, where it
	reads as *depth behind* the opening instead of clutter in front of it. Everything else lives at the
	rim.
	
	### Enforcement, not discipline
	Hand-checking a layout this dense does not survive the next edit, so the build now **checks itself**
	and prints the result:
	
	```
	objects at deck level: 223
	focal-lane offenders: none
	```
	
	Anything at deck level (`z <= 0.62` — the overhead roof beams are legitimately above the lane) whose
	centre falls in the lane, and which is not part of the deck/stair/shaft itself, is reported by name.
	
	**It immediately caught a real composition bug I had already talked myself out of.** In an earlier
	pass I reasoned that the banner hung on the far side of the stair and so "doesn't occlude anything".
	The check disagreed:
	
	```
	focal-lane offenders: ['Plinth course 3 6 at (-0.32, -0.63)', 'Banner panel 1 tail at (-0.13, -0.22)']
	```
	
	The banner sat at y = -0.22 — *directly over the opening* — with its tails reaching to within 0.08
	of the deck, squarely in the camera's line of sight to the focal point. It never looked like
	"clutter" in a still, because a hanging prop reads as scenery, not as an obstruction. Moved to the
	roof's left edge and shortened; it now frames the stair from the side. (The plinth entry was a false
	positive — structure, so `Plinth course` was added to the allowed list.)
	
	### What moved
	Clutter was relocated to deliberate peripheral clusters rather than scattered: gloves, bucket, one
	candle and two rubble stones to the right-front work cluster; coiled rope and the stair plank to the
	left; loose debris cut from 34 stones to 14 and confined to the outer band (`r` 0.40-0.60, lane
	excluded) so it reads as debris at the sides of the paved approach; stair debris cut 7 -> 2; candle
	wax drips 3 -> 2 per candle.
	
	### The stair read as a grey well, not a descent
	Four treads spanning the opening filled it almost completely. Now **three** treads, toned
	`stone_lit` -> `stone` -> `stone_dark` so each separates from the next and from the deck, with
	everything past the third left as unlit shaft. The shaft lining was also darkened to near-black so
	the opening reads as a void with lit steps rather than as a lined recess.
	
	### Result
	The eye now travels up the paving, over the hazard board, and down into the opening; the roof frames
	it from the upper left, the caged lantern and pillar from the right, the banner from the left.
	
	### Remaining gap
	The lantern pillar and the two parapets are still plain stone boxes at close range, and the model
	still reads as a small blob at the in-game zoom of 18. Detail density and the pillar's silhouette are
	the next real work.
	
	### Method note
	Stating a composition rule and then **asserting it in the build** found a defect that three passes of
	looking at renders had missed. Eyes normalise to a layout; a counter does not.
	
	## Fidelity pass — pillar silhouette, density, and the real cause of the blur
	
	### The blur was a UV problem, not a resolution problem
	The textures looked "splotchy and blurry". Measured rather than guessed, in two steps:
	
	1. **Not JPEG.** Blender's glTF exporter uses PNG for images with alpha and JPEG for opaque ones
	   under `export_image_format='AUTO'`, so compression artifacts were a real candidate. Reading the
	   GLB's `images[].mimeType` showed all 21 images already PNG. Ruled out.
	2. **`smart_project` was packing ~900 islands into one 512 atlas.** 228 objects, several faces
	   each, all unwrapped into a single 0-1 space — so every face got roughly a **17-pixel thumbnail**
	   of the texture. That is the blur, and raising the texture resolution would only have helped
	   linearly.
	
	**Fix: cube-project the joined mesh at a fixed world scale** (`UV_TILE = 0.55`, the world size one
	tile covers) instead of packing a unique atlas. Texel density becomes uniform with no island
	lottery, the pattern flows continuously across block boundaries instead of restarting on every
	stone, and it is the correct mapping for tiling materials anyway. The alpha decals keep
	`smart_project` — they genuinely need unique maps.
	
	### And a texture-design error that compounded it
	`tex_grey_stone` was a **masonry-wall** texture — blocks plus mortar joints — applied to *individual
	stones*. Every block showed five or six mini-blocks of its own, which also reads as splotchy. Replaced
	with `tex_stoneface`: one continuous rough grey stone surface, no mortar grid, no coursing, at
	**1024** (4x the texels), with its normal from a purpose-made height map and two tone variants.
	
	### The pillar: a box became a pier
	`Lantern pillar` was a single `.32 x .32 x .60` box with a lid — and it is one of the two largest
	objects in the model. Nothing about it read as built stone. Rebuilt as **coursed masonry**: a wider
	footing, five courses of stones, **quoins stepping in and out on alternating corners**, a corbelled
	two-step capital, and a niche in the face the camera actually sees (the camera sees the -Y and +X
	faces after the mount rotation), with a stub candle in it. The caged lantern now sits on a capital
	that reads as a capital.
	
	### Density
	- **Parapet end piers** at both ends of both side walls, taller than the wall and capped, so each
	  long parapet run breaks into bays and the wall has a silhouette instead of being one low band.
	- Objects at deck level: **223 -> 237**.
	
	### Metals were glossy because they had nothing to reflect
	The game environment uses a solid background with a colour ambient and **no reflection source**, so
	metallic surfaces have nothing to reflect and read flat or waxy. Weathered rust and old painted steel
	are mostly non-metallic anyway, so the packed metallic channel was dropped: pipe `.60 -> .25`,
	corrugated roof `.35 -> .10`, roughness left alone.
	
	### Result
	`captures/sanctum_subway_v28_front.png` against `v23_front.png` is the before/after. Note the stone
	is not merely sharper — the blocks now share one continuous stone surface at uniform density instead
	of each carrying its own compressed copy.
	
	### Remaining gap
	Detail density is now reasonable, but the model still reads as a small blob at the in-game zoom of
	18, and the two long parapets remain fairly plain between their end piers. The next real work is
	either silhouette at gameplay zoom or the parapets.
	
	## Parapets and the lantern
	
	### The lantern was enclosing its own light
	The caged lantern is the warm focal accent of the whole model — and it was invisible. `Cage rib` was
	a **solid 6-sided cylinder at r = .104 wrapped around a glass at r = .088**, so the cage covered the
	light completely and the whole lantern read as a stack of brown barrels from every angle. Replaced
	with **six thin bars** (r = .012) at r = .098 around the glass. The lantern now reads as a lantern
	and blooms properly, which is the single strongest improvement to the model's read this pass.
	
	### Parapets: a kerb became a wall
	- **Three courses -> four**, so the wall tops at `PLAT + .324` instead of `PLAT + .252`. It was only
		~.17 proud of the deck -- too low to enclose anything.
	- **Buttresses** on every second bay (`.20 x .18 x .34`, proud of the outer face, with a cap), which
		give the run a rhythm and break the crest. The cheapest way to make a low wall read as structure.
	- **Two-step coping** (a wider lower slab plus a narrower upper) so the wall has a profile instead
		of a lid.
	- **Alternating top-course stones** shortened to 58%, so the crest is not a ruler line.
	- **Taller end piers** (`.38` tall, `PLAT + .40` cap) so the wall terminates rather than just stops.
	- The rear wall got its own top constant (`REAR_TOP`); it previously shared `WALL`, so raising the
		side parapets would have floated the rear coping off the rear wall.
	
	Objects at deck level: 237 -> 241. `focal-lane offenders: none`. test_integration 12/12.
	
	## On a 3-hex Cult Sanctum — findings to decide against
	
	The question: should the Sanctum grow to a 3-hex footprint to become a landmark at gameplay zoom?
	
	**The hex math (measured from `HexMath`).** `HEX_SIZE = 1.0`, pointy-top. `hex_to_world` gives a
	q-neighbour at `sqrt(3) = 1.732` and an r-neighbour at `1.5`. A radius-1 disc — the base plus its
	six neighbours, i.e. "3 hexes wide" — spans roughly **5.2 x 5.0 world units**. The current Sanctum's
	plinth is 1.61 across, so the main mass would need to be **~3.2x** larger, and its footprint area
	grows by about **10x**.
	
	**Constraint 1: wide, not tall.** `HexMath.TOWER_MAX_HEIGHT = 1.5` exists so that tall objects do
	not hide enemies. The Sanctum currently tops out at ~1.16 (the lantern), just under that. A uniform
	3.2x scale would put it at ~3.7 — and enemies arrive *at the base*, since `path_hexes[0]` is the leak
	point. So the base must spend its new size on footprint, not height. That is also the better read: a
	low sprawling reclaimed entrance reads as a place, where a giant tower reads as a statue.
	
	**Constraint 2: restructure, do not scale.** 10x the area with the same 241 objects gives a sparse
	giant. A 3-hex base wants to be a *compound* — a walled ritual court at the core, plus a gateway, a
	scrap yard, and a second shaft, connected by the paved deck — so the eye has a route through it.
	
	**Constraint 3: the layout work is real, and it is gameplay code** (previously out of scope for the
	asset work). Concretely:
	- `path_hexes[0]` is the base and the leak point, and the path steps from it into a neighbour — so
		the reserved footprint must be `disk(base, 1)` **minus the hex `path_hexes[1]` occupies**, which
		yields exactly **6 reserved hexes**. That matches "3 hex wide, 6 total" precisely.
	- `PathGenerator` calls `grid.clear_reserved_hexes()` on every preview update (lines 1921 and 2005),
		so a base footprint needs its own persistent set (e.g. `set_base_hexes` / `is_base_hex`), not the
		preview reservation mechanism.
	- `validate_placement` must reject the footprint with a clear reason.
	- `TerrainView` / `BiomeTileModels` must not raise districts or skyscrapers on those hexes, or they
		will poke through the model.
	- `test_08` asserts the leak lands on `path_hexes[0]`, so the origin hex must stay the origin.
	
	**Recommendation.** Yes, do it — at zoom 18 a 1.6-unit base is a pebble, and the thing the player
	defends should be the thing they can see. But decide the **massing first**, then derive the footprint
	hexes from the shape the model actually covers, then wire the layout. Sequence: massing prototype ->
	footprint reservation + terrain clearing + placement rejection + tests -> detail pass at the new
	scale.
	
	## Massing blockout for a 3-hex Cult Sanctum
	
	`build_massing.py` -> `assets/sanctum_massing.glb`, captured by the existing harness (which now
	takes a third variant, `sanctum_massing`, at a 3.2x frame scale). Flat-coloured volumes only: the
	question under test is whether a 3-hex footprint reads as a landmark at gameplay zoom and whether a
	low wide compound works -- not whether the stone is nice. Detail at the wrong scale is wasted work.
	
	### Verdict: yes
	At `capture_sanctum` zoom 18 (the gameplay zoom) the compound is an unmistakable landmark covering
	the centre 7 hexes, with legible massing: the walled enclosure, the gate with its lintel and lantern,
	the dark shaft, the lean-to, and the lantern pier. Against the current 1.61-wide Sanctum -- a pebble
	at that zoom -- it is not close. The low wide profile also holds the height budget: the tallest
	element tops out at ~1.42, under `HexMath.TOWER_MAX_HEIGHT = 1.5`.
	
	### Three bugs in my own blockout, all worth remembering
	1. **The wall ring came out as a star.** A box whose long axis is local Y, rotated by `ang + 90`,
	   ends up pointing *radially* instead of tangentially. Rotating by `ang` alone puts it along the
	   tangent. The first render was a sunburst, which is not a subtle failure -- but it is exactly the
	   kind of thing that is obvious in a shape and invisible in a number.
	2. **`-Y` is a hex CORNER, not an edge.** A pointy-top hex's edges face the six neighbour
	   directions (`0, 60, ... 300`); its corners face `30, 90, ... 330`. So `-Y` (270 deg) has no edge
	   to gate, and my `if ang == 270: continue` never matched: all six walls were built and there was
	   no opening at all. The camera sees the model's Blender `(+X, -Y)` quadrant, which is the **300
	   deg edge**, so that is where the gate belongs.
	3. **A dark box inside a solid plinth is invisible.** The shaft was a dark box buried in a solid hex
	   prism, so the blockout had no pit. The shaft has to be actually cut out -- a boolean difference --
	   before anything shows through it.
	
	### Footprint finding: a 2.75-radius hexagon does not exactly cover the 7-hex union
	Measured from the captures: the reserved footprint is `disk(base, 1)` = 7 hexes. The union's boundary
	reaches **2.598** at the edge midpoints (neighbour centre 1.732 + apothem 0.866) and **2.732** at the
	corners. A hexagon of radius 2.75 has an apothem of 2.38, so it **under-covers the edge midpoints by
	0.22** -- a sliver of each outer hex would be left uncovered, and that sliver is exactly where
	terrain (road, district) would poke out from under the base.
	
	For the real model use the **union outline itself**, or a hexagon of radius **3.0** (apothem 2.598,
	exact on the edges, over-covering the corners by 0.27). Over-covering is the safe direction: the base
	should fully cover the hexes it reserves, never leave a sliver of road showing.
	
	### What the massing says about the real build
	- The **shaft at 1.9 x 2.3 is too large** -- it reads as a quarry, and it dominates the court. The
	  subway-entrance identity wants a *stair*, not a void this big.
	- The **lean-to reads as a floating slab**; it needs a real lean-to structure (plates, purlins, a
	  ridge) rather than one tilted box.
	- The **wall ring is a good silhouette** and should stay, at full detail (coursed stone, buttresses,
	  two-step coping, end piers -- all already built for the single-hex version).
	- Two glow points (gate lantern + pier lantern) work well as focal accents at gameplay zoom.
	
	### Next
	Layout plumbing: reserve the 6 hexes (`disk(base, 1)` **minus the hex `path_hexes[1]` occupies**)
	with its own persistent set, since `PathGenerator` calls `grid.clear_reserved_hexes()` on every
	preview update; clear terrain on those hexes; reject placement with a reason; add a test that the
	path never enters the footprint.
	
	## Layout plumbing — the Sanctum footprint (first simulation-side change)
	
	Everything before this was asset-only. This pass touches the sim, because a 3-hex base has to be a
	real footprint the path and the player both respect.
	
	### The footprint
	`disk(base, 1)` (7 hexes, "3 hexes wide") **minus the hex `path_hexes[1]` occupies** = **6 hexes**.
	The base hex is `path_hexes[0]` and is also the leak point, and the path must be able to step out of
	it, so the exit hex cannot be reserved. The hard path constraints already forbid the path from
	wandering back in: H3 rejects any path hex adjacent to a non-consecutive one, so a later path hex
	can never touch the base.
	
	### One design decision did most of the work
	`HexGrid` gained `_base_hexes` / `set_base_hexes` / `is_base_hex` / `get_base_hexes` as a set that is
	**persistent** (unlike `_reserved_hexes`, which `PathGenerator` wipes on every preview update), and
	`is_reserved()` now reports base hexes too.
	
	That folding is the whole trick: every guard in the project already consults `is_reserved()` --
	initial path stepping, the H1-H5 extension checks, preview validation, `PathGenerator.can_place_tower`
	(which drives the build-zone overlay), objective site placement -- so the Sanctum footprint became
	off-limits in all of them at once, and a guard written later cannot forget about it. The only place
	that needed a distinct check is `validate_placement`, which reports `"base_hex"` as its own reason
	rather than a misleading `"reserved_hex"`.
	
	Base hexes also pin their chunks (both in `is_chunk_pinned` and `unload_unused_chunks`), like path
	hexes and towers do.
	
	### Terrain
	`TerrainView.get_hex_tile_archetype` returns the **street-lot** variant for base hexes -- the same
	treatment a placed tower gets: buildings removed, street furniture left behind. So the model never
	stands on a live district or a skyscraper.
	
	### Verified
	- `test_integration.gd` **13/13**, including a new `test_13` that asserts the footprint is exactly 6
		hexes, excludes the path exit, that every footprint hex reads as reserved, that **no path hex
		other than the base lies inside it**, and that placement on it is rejected with `"base_hex"`.
	- `test_build_menu_ui.gd` 9/9 and `test_tower_system.gd` 15/15 -- the two suites that touch terrain
		archetypes and placement.
	- **Live board**: a run of `main.tscn` shows a cleared, flat footprint around the Sanctum with the
		yellow avenue exiting through the single un-reserved hex. The footprint is visible on screen.
	
	### Note on the full test suite
	`run_tests` on the whole `res://tests` directory **times out at 300 s** -- it includes the perf and
	long-simulation suites. Run the specific suites that touch the change instead of the directory.
	
	### Next
	Rebuild the Sanctum itself at the new footprint as a compound (massing already validated), using the
	union outline or a radius-3.0 hexagon so the model fully covers the 6 reserved hexes.
	
	## The compound — the Sanctum rebuilt at the 3-hex footprint
	
	`sources/build_sanctum_compound.py` -> `assets/sanctum_compound.glb`. The single-hex asset
	(`build_sanctum.py` -> `sanctum_subway.glb`) is left in place; this is the landmark-scale rebuild
	the massing blockout validated. Helpers and material setup are copied verbatim so the fidelity work
	already done -- authored albedo/normal/roughness, world-space tiling UVs, chipped stones, the caged
	lantern pattern -- carries over unchanged.
	
	### The platform is the exact 7-hex union
	Seven hexagonal prisms of radius 1.005 at the seven hex centres, joined. A single hexagon of radius
	2.75 (the first guess) under-covers the union by 0.22 at the edge midpoints, which would leave a
	sliver of each outer hex bare for terrain to poke out of. Prisms at the hex positions match the
	footprint exactly, with no sliver and no overhang.
	
	The model **does** cover the path-exit hex. That is deliberate: the reserved footprint excludes it
	(the path must leave), but a fortress road running out from under the gate wall reads correctly, and
	that hex is where units reach the base and leak anyway.
	
	### What is in it
	- **Wall**: five of the six hex edges (gate on the camera-facing 300 deg edge), four staggered
	  courses of chipped stones, buttresses on every second bay, two-step coping, corner piers. The two
	  bays flanking the gate are **two courses proud** -- the gatehouse.
	- **Gate**: posts on the flanking hex corners, a lintel and arch, and a caged lantern (six bars
	  around an emissive glass, the fix that stopped the single-hex lantern enclosing its own light).
	- **Stair shaft**: a real six-tread flight descending into a dark shaft, toned
	  `stone_lit -> stone -> stone_dark`, with a dark lining. **Its floor stays above z=0** -- the model
	  sits on the terrain, and anything below the ground plane pokes through it (that bug cost a pass on
	  the earlier build).
	- **Paving**: 41 slabs clipped to the wall hexagon and cut around the stair mouth.
	- **Lantern pier**: coursed masonry with quoins on alternating corners, a corbelled two-step capital,
	  a niche with a candle, and the caged lantern. This is the tallest element.
	- **Lean-to workshop**, **a coursed stone well** with a windlass, **two annex outbuildings** with dark
	  doorways.
	
	### Design finding worth keeping
	**A 3-hex base under a 1.5 height ceiling is inherently flat**: 1.42 tall against 5.2 wide is a 0.29
	height-to-width ratio. No amount of detail changes that. Being striking has to come from *internal
	contrast and silhouette variation* -- recesses, accent colour, and varying the ring's height -- rather
	than from making anything taller. That is why the gatehouse bays and corner piers were raised: they
	are the only vertical contrast available.
	
	### Two fixes the captures forced
	1. **The paving read as a checkerboard**, not as paving. Colours were cycling `stone / stone_dark /
	   stone` at 1/3 each, which next to each other reads as a chessboard. Now `stone` three times in four
	   with an occasional damp slab.
	2. **The lean-to was four narrow plates** and read as four boards floating in the air. Now two wide
	   plates with a hairline seam, which reads as one sheet of corrugated roofing.
	
	### State
	361 objects joined, tallest ~1.42 (limit 1.5). Captured by the harness, which now takes four variants
	(`cult_sanctum`, `sanctum_subway`, `sanctum_massing`, `sanctum_compound`) at a 3.2x frame scale.
	**Not yet mounted in the game** -- `path_view.gd` still mounts `sanctum_subway.glb`.
	
	### Remaining work
	1. Mount the compound. **Decided: the gate is to be seen.** The camera never rotates, so the model gets
	   a fixed rotation presenting the gate to the camera, rather than a per-seed rotation to face the path. The
   gate being legible every run beats it pointing down a path the player cannot see the end of.
	2. **Value contrast**: the model is dominated by mid-grey horizontal surfaces. It needs deeper
	   recesses (dark under the lean-to, a deeper shaft, dark doorways) and more accent colour.
	3. **The court is a large empty paved area**. It wants a focal structure over the shaft -- a dais,
	   a shrine, a sigil inlay -- rather than a hole in a plaza.
	4. The gate has posts and a lintel but no clear threshold or opening; it does not yet read as an
	   entrance you could walk through.
	
	## The vocabulary swap: the compound stops being a castle
	
	The first compound was flagged in review as leaning **medieval**. It was: a curtain wall of staggered
	ashlar courses, two-step coping stones, buttresses, corner piers with carved caps, and a gatehouse of
	posts and a lintel. `DESIGN_BIBLE.md` rules that out on three counts - Pillar A is *salvaged things
	made sacred*, section 7 forbids the cult clean or military-grade hardware, and section 6 wants a
	cultist thing to read jagged/handmade against a corporate thing's sleek/branded. A castle reads as a
	different genre from the collision of occult scrappiness and corporate cyberpunk this game is.
	
	The approved concept art had the right vocabulary from the start, which is the annoying part:
	concrete, steel pipe, chain-link, tarps, a striped hazard barrier, a junction box, cables, spray
	paint, caged lamps. Nobody had to invent the answer.
	
	### The swap
	
	| removed (castle) | replaced with (occupied infrastructure) |
	|---|---|
	| curtain wall of staggered ashlar courses | low board-formed concrete parapet |
	| two-step coping stones | galvanised steel pipe railing: posts and two rails |
	| buttresses | steel pipe stanchions with diagonal braces |
	| corner piers with carved caps | bare poured-concrete monoliths, no cap, no detail |
	| gatehouse posts, lintel and arch | cracked illuminated sign box on a steel enclosure |
	| flagstone paving, moss in the joints | concrete deck slabs, wet in patches |
	| grey masonry, muted, all mid-tone | concrete, rust, teal tile, red and violet spray paint |
	
	Also removed: the stone well with its coping ring. A well is a medieval object; propane bottles, a
	junction box and a hazard barrier are the same function in the right vocabulary.
	
	**The load-bearing rendering decision is that CONCRETE IS CRISP.** Chipped, jittered blocks read as
	masonry however you texture them. Every concrete element here is a plain box with a small bevel, and
	all the irregularity lives in the stain and the spray paint. That single change does more than any
	texture.
	
	### The spray paint, and the decal bug it exposed
	
	The cult does not own a second kind of paint: the sigils use the same glyph it always has
	(`decal_sigil_stone.png`, an eye with rays over tally strokes), and the red/violet split is carried in
	the material, keying the alpha and setting a flat base colour. `tintmat()` does that, and the same
	helper produces the wet patches off `decal_grime.png`.
	
	**The previous build's decals never reached the GLB at all.** The script collected them into a
	`decals` list that was never joined and never selected, and the export ran with `use_selection=True`
	on the joined mesh alone - so the grime, moss and sigil quads were created, placed, and then silently
	dropped. The old GLB had one node, which is the tell. Decals are now separate **plane** objects (a
	cube's default UVs are the classic cross layout, so a decal mapped onto one cube face shows a corner
	of the texture rather than the glyph) and they are selected for export explicitly.
	
	### Textures
	
	Two new materials, each with authored albedo, normal and ORM roughness/metallic:
	`tex_concrete` (board-formed, form seams and tie holes) and `tex_tile` (aged cream with a teal band).
	`sources/derive_maps.gd` derives the normals by Sobel and packs the ORM maps.
	
	**The height source is chosen per material, and that choice matters.** Concrete derives its normal
	from a purpose-made height map (`hgt_concrete.png`): board-formed concrete is a *stochastic* surface,
	so a slightly different arrangement of the same features than the albedo's is invisible. The tile
	derives its normal **from its own albedo**, because a tile grid is a strict pattern and a height map
	with a different lattice than the albedo produces a moire of two grids. This restates the earlier
	fidelity lesson: a normal map that disagrees with its albedo is wrong no matter how good it looks
	alone. `hgt_tile.png` was generated, found to be misaligned with the tile albedo, and is unused.
	
	The concrete albedo is also **darkened to 0.58 with a cool bias** (`tex_concrete_base.png` keeps the
	original so the step is idempotent). The generated concrete read as pale plaster, and damp concrete is
	both darker and cooler than dry. This is the fix for the "too pale, all mid-grey" note from the
	previous pass.
	
	### Two bugs the build's own checks caught
	
	Both were caught by asserts and counters rather than by looking, which is the point of having them:
	
	1. **The height assertion was measuring the wrong element.** It checked only the lamp cage, so the
		gate sign box grew to 1.45 unnoticed - fine, but the lamp itself went to 1.567, over
		`TOWER_MAX_HEIGHT`, and the check that existed to catch exactly that was looking elsewhere. It now
		asserts on a dict of every tall element.
	2. **The lamp lantern was at a hardcoded height.** Correcting the monolith's height moved the block
		but not the lamp, which then floated in mid-air above nothing. The lantern base is now *derived*
		from the monolith height, one number used twice, so the two cannot drift apart again.
	
	The lamp was also moved from the 90-degree edge to the 0-degree edge: it had been placed on the far
	side of the compound, hidden from a camera that never rotates. An accent nobody can see is not an
	accent.
	
	### State
	249 parts joined plus 19 decals. 18 materials. Tallest 1.45 (the gate sign), lamp cage 1.407,
	railing 1.10 - all under the 1.5 ceiling. Concrete, tile, rusted sheet, canvas, steel and timber all
	carry albedo + normal + ORM in the GLB; the three decal materials export as `alphaMode: BLEND`.
	
	### Still open
	1. **Not mounted in the game.** `path_view.gd` still mounts `sanctum_subway.glb`.
	2. **The court's middle is still an empty grey slab with a hole in it.** The railings around the stair
		help, but the composition wants a stronger centre than "hole in a plaza".
	3. The lean-to's hanging tarp reads as a striped banner rather than a tarpaulin; the torn-canvas
		texture is fighting the red sigil painted on it.
	
	## The side shrine, and three upgrades the concepts exposed
	
	Chosen from three concept options (`concepts/shrine_a_standpipe.png`, `_b_equipment_pad.png`,
	`_c_pallet_dais.png`): **A's object on B's pad**. The standpipe is the project's own pump-station
	object - oxidised teal cast iron, bolted flanges, domed top, elbow - so the idol is already canon. The
	cast equipment pad under it with rusted steel angle edging means the cult is visibly building a
	platform FOR the thing it reveres rather than finding it lying there, and it separates the riser from
	the propane bottles it would otherwise echo.
	
	**It is placed off to one side (1.35, 1.30) on purpose.** The sunken stair is this court's centre, and
	a shrine dropped over it would fight the stair for the same job. Dressed with a tarp hood lashed on
	with wire, nine votive tins and three jars ringed at the base, offerings heaped at the flange, a
	coiled wire, and a caged lamp on a brass bracket.
	
	### The three upgrades
	
	1. **A lantern standing on the shaft floor**, below deck level. Every one of the three concepts does
	   this, and it is the cheapest fix for the real problem: without a light in it the shaft read as a
	   black hole, and a black hole is not a centre. With one, the stair is where the eye goes.
	2. **Brass pipe railings and oxidised teal iron.** The concepts run warm brass pipework against teal
	   machinery; the build had flat grey steel rails and a very grey palette. Metallic is deliberately
	   LOW (0.15-0.25) because this scene has no sky and no reflection source, so a high-metallic brass
	   renders as grey wax rather than metal. The warmth comes from the albedo instead.
	3. **A wet floor - ATTEMPTED AND BACKED OUT, and the reason is worth keeping.** The concepts owe most
	   of their richness to a damp, half-reflective deck, so the concrete roughness was dropped from 0.90
	   to 0.55. The capture came back with the entire courtyard nearly black and the brass turned into a
	   hot gold cutout. Smooth surfaces mirror the environment, and this environment has no sky: it
	   reflects black. **A genuinely mirror-like wet floor needs a reflection source in `main.tscn`, not a
	   material change.** Roughness sits at 0.74 with the wet-patch decals carrying the damp read.
	
	### A bug in the roughness derivation
	
	The roughness-from-luminance formula had its sign backwards (`base + (0.5 - lum) * var`), so the
	darkest, wettest concrete came out the ROUGHEST - exactly inverted. Now `base + (lum - 0.5) * var`.
	
	### Measuring beat looking
	
	The v37 and v38 captures looked identical to the eye, which suggested the change had not landed. It
	had: the md5s differed (`89bb015f5aa5` vs `63e7d145ea56`) and the mean brightness moved 32.49 -> 32.95.
	The shift was real and simply small. Worth remembering before concluding a rebuild silently failed.
	
	### Two harness notes
	
	- **After clearing the `.import` cache, the first capture renders the STALE model.** The editor imports
	  during the capture call, not before it. Two runs are required, and the console says so: *"Ziva made
	  sure the editor imported ..., which it had not imported when this call ran."*
	- The harness frames on the model's AABB, which is inflated by the gate cables' bezier AUTO-handle
	  overshoot (AABB max Y 1.699 against a real tallest element of 1.45), so it frames slightly wider than
	  the model warrants. Not a model defect, but it makes the `game_scale` shot look smaller than it is.
	
	### State
	343 parts joined plus 25 decals. Tallest 1.45 (gate sign); shrine standpipe 1.385; lamp cage 1.407;
	railing 1.10 - all under the 1.5 ceiling. Model AABB 6.02 x 2.22 x 6.06 across 26 mesh nodes.
	
	## Mounted: the compound is now the base
	
	`scripts/world/path_view.gd` loads `sanctum_compound.glb` in place of `sanctum_subway.glb`, at
	`rotation.y = PI * 0.25`. **The rotation is fixed, not per-seed.** The path's exit direction varies by
	seed, so the model could have been turned at mount time to face its gate down the path - but the camera
	never rotates, so a fixed rotation is what guarantees the gate is actually seen. A gate pointing at a
	path end the player cannot look at is worth less than a gate every run.
	
	Three omnis hang off the base marker, positioned by putting the model's own coordinates through the
	same +45 deg rotation, because the lights are siblings of the model rather than children of it. Every
	lantern in the model is an emissive MESH, and an emissive mesh glows without lighting anything: the
	candle ring and the stairwell were bright paint casting no light. The lights are what make them read as
	sources.
	
	### Three defects the first in-game captures exposed
	
	1. **The "CULT SANCTUM [BASE]" label burned straight across the middle of the model.** It sat at
	   Y 1.15, which is *inside* a compound whose tallest element is 1.45 - fine for the 1.5-unit single-hex
	   asset it was written for, wrong for this one. Now at 2.75, clear of the roof.
	2. **The gate sign box was 2.05 units long** and read as a blank white plank laid across the model
	   rather than as a sign. Now 1.15 units with three vertical dividers, so it has panels to read as.
	3. **The vigil light at energy 2.4 over a 3.3 range bathed the whole compound warm brown** and the
	   concrete went muddy - three warm omnis plus a warm key is one warm wash too many. The vigil light is
	   now 0.9 / 2.4 and the two accents (shrine 1.6 / 2.0, shaft 1.4 / 1.7) stay tight, so the court reads
	   as cool concrete with two pools of warm light rather than one brown mass.
	
	### The observation that should shape the fidelity pass
	
	The concept art is a **dark, moody, damp** scene photographed against a neutral or dark background. The
	game's board is the opposite: **bright, pastel, highly saturated** city tiles, and the compound already
	reads *darker* than everything around it. Those pull in opposite directions. "Closer to the concept
	art" therefore means one of two different things, and they need deciding before more work goes in:
	
	- **Match the concept's VALUE** (dark, damp, dramatic). Maximum fidelity to the reference, but the
	  sanctum becomes a dark hole in a bright board, and loses its warm-accent contrast against the terrain.
	- **Match the concept's DETAIL and richness** - density, layering, staining, teal/brass/rust/violet,
	  surface variation - while holding the game's existing value range. Closer to the reference's craft
	  without fighting the board it sits on.
	
	The second is the safer read of "closer to concept art" for a piece of a game rather than a standalone
	render. **Recommend confirming before the pass.**
	
	## Fidelity pass: matching the concept's dark value
	
	Decided in-game rather than in the harness: the concept art is dark and damp, the game board is bright
	and pastel, and the owner's call was to **match the concept's VALUE** and let the sanctum sit darker
	than the terrain around it. That is the opposite of what the harness had been arguing for, which is why
	it was worth asking - the harness renders on black and flatters dark assets.
	
	### What the pass did
	
	1. **Concrete albedo darkened to 0.52** (from 0.74), keeping the cool bias. This is the single change
		that delivers the value match. It is an ALBEDO change, not a roughness change - roughness is what
		caused the mirror-black failure earlier, and albedo darkness carries no such risk.
	2. **Weathering.** Nine run-off streaks down the parapet faces, alternating grime, rust weeps and damp,
		plus seven damp pools at the wall bases. All placed off the edge maths like the sigils, so a streak
		cannot float in front of a wall or sink inside it.
	3. **Density.** Two barrels, two buckets, an oil drum, a hose coil, a pallet, fourteen rounded debris
		stones, four bottles, and candles left burning on the stair treads. Density is most of what reads as
		"somebody works here", and the concepts are far denser than the build was.
	4. **The lean-to tarp.** It is now a flat dark tarpaulin rather than the torn-canvas texture. Canvas
		carries strong vertical banding, and with a red sigil painted over it the pair read as a striped
		banner - which is what the earlier captures showed and what the note on file had flagged.
	
	### Verdict from the game
	
	The value match works, and better than the mid-grey version did. A dark compound with warm light pools
	in it - the shaft lantern, the shrine candles, the lamp - reads as *mysterious* rather than merely dark,
	because the lights have something dark to contrast against. Against the bright board the sanctum now
	reads as a distinct place rather than as another grey object.
	
	### Still open
	1. **The cleared footprint reads as a pale halo** around the base. `terrain_view.gd` renders street lot
		for the base hexes, and against a now-dark compound that pale ring is the brightest thing on screen.
		Worth darkening to match.
	2. **Whether the damp decals read as darker or lighter is unresolved.** Pale marks are visible on the
		deck, but the concrete's own albedo carries pale form-board lines and tie holes, so the marks may be
		the texture working rather than the decals failing. It needs a capture with the decals disabled to
		settle.
	3. **Interior detail is hard to read at gameplay zoom.** The shrine, the stair railings and the clutter
		only resolve when the camera comes in; at default zoom the compound is a dark mass with warm points.
		That may be correct for a 3-hex landmark, but it is worth naming.
	
	### State
	393 parts joined plus 41 decals. Tallest 1.45 (gate sign) - under the 1.5 ceiling. Mounted in
	`path_view.gd` with a fixed rotation and three omni lights.
	
	## Three fixes: the pale halo, the light damp decals, and edge articulation
	
	### 1. The halo was the build-zone tile variant
	
	`terrain_view.gd` decided `in_zone` as `pgen.is_in_build_zone(h) and not is_path and not is_blk`. The
	base footprint sits on the path, so five or six of its seven hexes qualified, and `_add_street_foundation`
	renders build-zone tiles with lighter asphalt, a lighter curb and a lighter inner pad. The Sanctum was
	standing on a lit platform. **A reserved hex is not a build zone**, so the flag now also excludes
	`grid.is_base_hex(h)`, and the compound stands on the same dark street lot as any other cleared ground.
	
	Consequence worth noting: the footprint now reads DARK rather than pale. That is the honest tile, and a
	dark patch of taken ground suits the fiction, but it is a value choice to keep an eye on.
	
	### 2. The damp decals were painting LIGHT patches - settled by measurement
	
	This had been left open as "the pale marks may be the concrete's own albedo". It was not; measuring
	settled it in one step rather than two renders:
	
			tex_concrete.png       mean G byte 0.238  -> approx linear 0.044
			tex_concrete_base.png  mean G byte 0.472  -> approx linear 0.192
			decal tints:  damp_m 0.088   streak_m 0.070   wet_m 0.115
	
	The concrete's albedo is around 0.04 linear; the "damp" decals were 0.088 and the wet patches 0.115 -
	**lighter than the surface they land on**. An alpha-blended decal can only darken if its colour is below
	the surface, so these were brightening the concrete and had been since they were added. Now damp 0.020,
	streak 0.015, wet 0.028, all safely under the albedo.
	
	### 3. Edge articulation - the owner's actual diagnosis
	
	> *"theres not real contrast between bricks to bring edge highlights and such into play"*
	
	Correct, and it was my own doing. Dropping chipped masonry for "crisp concrete" removed every joint, and
	a large concrete face with only a texture on it is **one flat value**: the detail is present but there is
	no EDGE for a highlight to land on, so it reads as mush however good the normal map is. Texture cannot
	fix a missing edge. Added as geometry, so it holds at any zoom:
	
	- **Plinth** at the wall foot and a **string band** under the coping: two horizontal edges per wall.
	- **Vertical formwork joints** at panel pitch (five per edge) and **proud form-tie marks**: the cast
		panel structure of a board-formed wall, which is what that surface actually has.
	- **Footings** under every concrete monolith, giving each block a bottom edge to read against.
	- **Deck slabs thickened to 0.038 with the joint widened to 0.026** - roughly double. The joint IS the
		edge; a 12mm groove between paving was invisible at gameplay zoom.
	
	Also fixed: a `NameError` where the wall loop computed its tangent inline as `(-sin, cos)` and never
	bound `tx`/`ty`, while the new joint code used them. Bound once now.
	
	### State
	450 parts joined plus 41 decals. Tallest 1.45 (gate sign), under the 1.5 ceiling.
	
	## The close-up found a bug the assert had been blind to
	
	The v40 in-game close-up confirmed the articulation works - panel joints, plinths, string bands and deck
	joints all read at close range - and then showed the lean-to roof dominating the compound. Checking it
	numerically: **the ridge sat at 1.664, over `HexMath.TOWER_MAX_HEIGHT` (1.5).**
	
	That cap exists so tall objects do not hide enemies, and enemies arrive AT this hex, so it is not a
	cosmetic rule. It had been violated for several passes because the height assert only ever checked the
	lamp, the gate, the railing and the shrine - **the lean-to was never in the list.** The AABB
	measurement of max Y 1.699 that I had earlier blamed on the gate cables' curve overshoot was this roof
	all along; the cables were innocent and I had a real defect in hand while I was reasoning about a
	phantom one.
	
	Then fixing it failed once more, for an instructive reason: lowering `LH_LOW` did not move the ridge,
	because `LH_HIGH` carried its own hardcoded `PLAT + .80` instead of being derived from `LH_LOW`. **It is
	the same duplicated-magic-number mistake as the lantern that floated in mid-air when its monolith
	changed height.** Derived now: `LH_HIGH = LH_LOW + tan(-PITCH) * LH_W` -> 1.384, and the ridge is in the
	assert list so this cannot recur silently.
	
	Lesson, twice learned the same way: **when a quantity is derived, derive it - a second copy of the
	number is a bug waiting for the first copy to change.**
	
	### Final state
	450 parts joined plus 41 decals. Height assert now covers six elements - lamp cage 1.407, gate monolith
	1.30, gate sign 1.45, railing 1.10, shrine standpipe 1.385, lean-to ridge 1.384 - tallest 1.450, all
	under the 1.5 ceiling. Mounted in `path_view.gd` with a fixed gate rotation and three omnis.
	
	## Decals on the Z axis, and the two-roof lean-to
	
	Two defects reported from play, both with numeric causes rather than mystery ones.
	
	### Decals hanging above their surfaces
	
	**The decals did not fit the surfaces they were painted on.** The wall sigils were 0.44 units tall on a
	parapet only **0.26** tall, centred at PLAT + 0.13 - so they spanned PLAT - 0.09 to PLAT + 0.35 and
	stood a full 0.09 proud of the wall top, floating over it. The run-off streaks were worse: 0.15 wide at
	an aspect of up to 4.2 meant **0.63 tall on a 0.26 wall**, nearly two and a half times its height.
	
	An alpha decal is a flat quad, so it does not wrap or clip: it hangs in the air wherever it is put. The
	sizes are now derived from the surface instead of chosen by eye:
	
	- wall and inner sigils: 0.34 wide at aspect 0.58 = **0.197 tall**, inside the 0.26 wall
	- streaks: 0.14 wide at aspect 1.3-1.7 = **0.21 tall max**, inside the 0.26 wall
	- monolith sigil: moved down and shrunk to fit the 0.70 block it is on
	- the cheek sigil was deleted and replaced by one on the shaft's **tiled back wall** - the cheek is
		almost entirely below deck, so there was no surface up there to paint
	- deck puddles: capped at 0.80, and the `inside_hex` guard now tests **the centre minus the patch's own
		half-width**. The old guard passed a 1.05-wide puddle whose centre was inside the parapet and whose
		corner was not, so puddles hung over the wall.
	
	### The lean-to reading as two roofs
	
	Two plates split **along the slope** put a seam straight down the middle of the roof, and under
	isometric light the two halves shaded differently, so they read as two roofs standing side by side
	rather than one sheet with a seam. It is now a **single** corrugated sheet at the mid-height of the
	run. (This is the third revision of this roof: four narrow plates read as floating boards, two wide
	plates read as two roofs, one sheet reads as a roof.)
	
	### On the contrast with the board
	
	Owner's note, recorded because it settles the value question: the dark compound against the pastel board
	is **fine for now**, because this is the first piece of graphics moving toward the true art direction and
	the pastel board is still placeholder. The value was not a mistake to be corrected back toward the
	board; the board is what will move.
	
	## The exported GLB was shipping one part out of 449
	
	Worth recording because the asset had already passed two instrumented passes, and the only thing that
	caught this was measuring the file that actually ships.
	
	The reported symptom was the decals "sitting oddly on the Z axis, above the various posts". Measuring
	the exported GLB in Godot - not the scene, not the source - showed why:
	
			Cult Sanctum Compound   size (1.741, 0.340, 2.010)   y 0.000..0.340
			41 decals               y 0.371..1.100
	
	The compound had exported as **one hex platform slab, 0.34 tall**, with all 41 decals left hanging in
	the air where the walls, gate, lean-to, shrine and lamp should have been. After the fix:
	
			Cult Sanctum Compound   size (6.024, 2.010, 6.143)   y -0.520..1.490
	
	### The cause was one missing loop
	
			bpy.ops.object.select_all(action='DESELECT')
			for o in objs:
				o.select_set(True)      # <-- this
			bpy.context.view_layer.objects.active = objs[0]
			bpy.ops.object.convert(target='MESH')
			bpy.ops.object.join()
	
	`join()` merges the **selected** objects into the **active** one. With the selection loop gone nothing
	was selected, so the join consumed nothing: the 449 parts stayed loose in the scene and the export
	(`use_selection=True`) shipped `objs[0]` plus the decals. That loop was deleted by an edit made in this
	same session - a diagnostic print added above the join replaced a block that included it. The asset was
	broken by the act of inspecting it.
	
	### Why every existing check missed it
	
	- **Blender's preview looked perfect**, because a preview renders the SCENE, and the unjoined parts are
	  all still in that scene. A preview is not a test of the export.
	- **The capture harness looked perfect too**, for a different reason: the import cache. `capture_sanctum`
	  loads the GLB, and after the GLB is rewritten the editor can still serve the previously imported copy
	  for one run.
	- **The build's own counter was a lie.** It printed `compound objects joined: 449` - the number of parts
	  that went *in*, whether or not the join consumed them. A counter that reports its input is not a check.
	- Blender printed `Warning: Active object is not a selected mesh` the whole time. It was in the log, and
	  I read past it twice.
	
	### What now guards it
	
	The build asserts the join consumed everything and accounts vertices rather than counting inputs:
	
			join: 449 parts / 37776 verts -> 37776 verts in one mesh
			join: unjoined parts left over: 0
	
	and `tests/test_sanctum_glb.gd` reads the **exported GLB** and fails if the compound is not whole
	(footprint >= 5.5, height >= 1.2) or if any decal lies outside the model's own bounds - which is the
	reported symptom, tested directly. All three checks would have failed on the broken build: it measured
	1.741 wide and 0.340 tall, and all 41 decals sat above its 0.340 top.
	
	### The two lessons
	
	1. **Verify the artifact that ships, not the scene that produced it.** A scene render cannot fail the
	   way an export can.
	2. **When a build prints a count, make sure it counts the OUTCOME.** `len(objs)` was never evidence that
	   anything had been joined.
	
	### A smaller trap from the same pass
	
	The first version of the decal table read `matrix_world` immediately after assigning `rotation_euler` and
	reported one gate sigil as lying flat in mid-air when it was standing correctly - a stale matrix, fixed
	by calling `bpy.context.view_layer.update()` before reading. A diagnostic that lies is worse than none,
	because it sends you off to edit working code. `decal_at` also now normalises its angle into 0..360,
	since a caller passing `gcam + 180` hands it 510 degrees.
	
	### The decals themselves were not moved
	
	Their placement was measured and is correct: wall and inner sigils sit at z 0.371-0.569 inside a wall
	assembly spanning 0.340-0.640, streaks at 0.346-0.584, the flat deck decals at 0.373 on slabs topping
	at 0.367, and every decal lies inside its host's bounds. Nothing needed repositioning; what the player
	saw was decals with no compound around them.
	
	BUILD_TAG is now `v42`, and the compound was re-verified whole in the running game at the Sanctum base.
	
	## The road leaves through the gate, and the descent faces the entrance
	
	Two complaints from play, and they turned out to be one problem each with a numeric cause.
	
	> *"the sanctum doesnt connect at all to the path, so it seems cluttered, can't really see the
	> descent into the subway at all. The player should be able to see the descent, and the path should
	> logically enter the sanctum"*
	
	### The path left through a wall
	
	The compound was mounted at `rotation.y = PI * 0.25`. The gate is built on Blender 300 deg, which
	glTF maps to a Godot direction of +60 deg, so a +45 deg mount put the gate at **+15 deg** -- while
	`HEX_DIRECTIONS[5] = (0, 1)`, the +60 deg neighbour, is the hex a path leaves by. The road came out
	of the solid wall 45 deg away from the opening, so the compound read as a walled lump the path had
	nothing to do with.
	
	The fix is `rotation.y = 0`, which leaves the gate at exactly +60 deg. Everything then agrees:
	
	| what | value |
	|---|---|
	| gate in the model (Blender 300 deg) | Godot +60 deg |
	| mount rotation | 0 |
	| gate in the world | +60 deg |
	| `PathConstants.BASE_EXIT_DIR` = `HEX_DIRECTIONS[5]` = `(0, 1)` | +60 deg |
	| fixed camera azimuth | 45 deg, i.e. the gate is 15 deg off axis |
	
	The +45 deg mount had been chosen **deliberately** not to follow the path, on the reasoning that the
	camera never orbits so a fixed rotation was what guaranteed the gate was seen. The measurement kills
	that trade: at zero the gate is **15 deg off the camera axis, against 30 deg before**. The gate
	faces the camera *better* when it is aligned with the path. There was never anything to trade.
	
	`PathGenerator` now forces the initial chain's first step to `BASE_EXIT_DIR` instead of drawing it
	from the RNG, and the guaranteed-fallback straight run uses it too, so even the dense-blocked case
	exits through the gate. Every later step is still random, so the path's variety is unchanged. The
	exit hex is forced BUILDABLE, and `_reset_state` clears the base footprint, because a stale
	footprint from the previous run would be reserved and would reject the forced first step.
	
	**The angle comments in `HEX_DIRECTIONS` were wrong** -- `(0, 1)` was labelled -60 deg when
	`hex_to_world` puts it at +60 deg. Mislabelled directions are how a gate ends up facing a wall, so
	they are corrected, verified against the printed values.
	
	### The descent was pointing the wrong way
	
	The stair descended **toward** the gate. `y = SHAFT_CY + SHAFT_HL - (i + .5) * ...` put tread 0 (the
	highest) at Blender y = +0.61 and dropped toward -Y, which is the gate side -- so a player standing
	at the gate was looking at the BOTTOM of the flight with every riser facing away. That is a pit, not
	stairs you would walk down. A subway stair is entered at its head.
	
	The mouth is now at `SHAFT_MOUTH_Y = SHAFT_CY - SHAFT_HL` (the gate side) and the flight drops toward
	`SHAFT_DEEP_Y`. The two ends are named once rather than written as `SHAFT_CY + SHAFT_HL` nine times,
	because those nine terms are what had to flip together. The tall tiled back wall stays at the deep
	end and the low concrete lip at the mouth, so the entrance is open and you look down the flight.
	
	### Also in this pass
	
	- **The turnstile stood in the middle of the road.** With the road now aimed at the gate, a turnstile
	  on the centreline reads as a barricade. Offset 0.95 to one side with its arms shortened to 0.32,
	  its inner arm tip clears the road's 0.56 half-width: a turnstile bank beside a clear gate.
	- **The three omni lights were hand-rotated.** They hung off the base marker with the mount rotation
	  applied to each position by hand, so the mount change silently detached every light from its
	  lantern. They are now children of the **model** and inherit its rotation.
	- The capture harness had the old `PI * 0.25` hardcoded for its `ingame` shots, so it would have
	  gone on flattering a mount the game no longer uses. Now 0, with a note that it has to track the
	  game.
	
	### Guarded
	
	`tests/test_base_gate_alignment.gd` reads `GATE_ANG` **out of the build script** (so moving the gate
	cannot leave the test asserting the old angle), reads the mount rotation off a **live `PathView`**,
	and asserts: the gate's world angle equals the path's exit angle; the gate is within 25 deg of the
	fixed camera; and the exit is an adjacent hex direction. No single file was wrong in the shipped
	bug, which is why no per-file check could have caught it. 3/3.
	
	`test_integration` 12/13 (the one failure was a frame-time threshold under load, and passes on a
	quiet rerun), `test_build_menu_ui` 9/9, `test_tower_system` 15/15, `test_sanctum_glb` 3/3.
	
	### State
	449 parts, 25 primitives, tallest 1.450, BUILD_TAG `v43`. Verified in the running game: the road
	runs in under the gate sign, and the railed stair opening sits directly behind it on the same axis.
	
	## Fidelity to the concept, measured: colour, contrast, and the texel-density bug
	
	> *"the texture fidelity is no where near where i want it, i want it to more closely match the
	> concepts, the dark moodiness may be causing things to be washed out in cool tones, maybe we just
	> refocus on making it as close to the concept art as possible in game"*
	
	The owner's hypothesis was correct, and it was measurable. Comparing the render against
	`concepts/reskin_a_occupied_concrete.png`:
	
	| | mean RGB | R/B | p50 | p95 | spread |
	|---|---|---|---|---|---|
	| concept | (0.275, 0.205, 0.169) | **1.63** | 0.200 | 0.530 | 0.529 |
	| build, before | (0.121, 0.107, **0.140**) | **0.87** | 0.067 | 0.289 | 0.222 |
	| build, after | (0.160, 0.137, 0.150) | 1.12 | 0.067 | **0.521** | **0.454** |
	
	The render was **blue-dominant** where the concept is strongly warm, with **half the dynamic range**
	and a highlight end 40% of the concept's. (Caveat kept on the record: the harness renders on black,
	so the mean is dragged down and the p50 is not the model's; p95 and the spread are the meaningful
	columns, and the R/B direction is unaffected by the background.)
	
	### Three separate causes, one of them mine
	
	1. **`derive_maps.gd`'s RECOLOR darkened the concrete to 0.52 AND tinted it cool** (basis B 1.16,
	   R 0.94). Measured, that left `tex_concrete.png` blue-dominant -- (0.233, 0.240, **0.277**), B
	   above R -- with its luminance spread cut from 0.187 to **0.097**, i.e. halved. Board seams and tie
	   holes are the entire character of that surface at this scale, and the tone step multiplied them
	   out of existence: the walls rendered as untextured flat grey no matter how good the artwork
	   underneath was. **No amount of normal-mapping recovers detail that has been multiplied out of the
	   albedo.** Now gain 1.0 with a neutral-warm basis, spread restored to 0.193.
	2. **`main.tscn` carried a lavender ambient**, `Color(0.55, 0.5, 0.68)` at 0.62, over the whole
	   scene. Now warm neutral `Color(0.62, 0.57, 0.50)` at 0.72, with the key warmed to
	   `Color(1, 0.95, 0.86)` at 1.30. That is a scene-wide change, made deliberately: the concepts are
	   warm-lit and the whole board is still placeholder.
	3. **`UV_TILE` was set 3x too small, and this was the actual texture-fidelity bug.** At 0.55 a
	   surface carries about 930 texels per world unit while gameplay zoom is about 36 screen px per
	   world unit -- so the texture is minified roughly 26x and mip-mapped into a featureless wash, with
	   only its very broadest structure surviving. The board-form courses (~85 px of a 512 map) landed at
	   0.09 world units against the ~0.25-world-unit block scale the concepts show.
	
	   **The lesson worth keeping: tiling is not the knob. The texture's FEATURES have to land at the
	   concept's feature size.** At `UV_TILE = 1.50` one course lands at 0.25 units and one tile-grid
	   cell at ~0.2, so both read at gameplay zoom while the close-up stays crisp. The build's own
	   comment now says so, because the previous value looked reasonable and was wrong by 3x.
	
	### Accents
	Brass `(.30,.21,.11)` -> `(.52,.40,.19)`, rust plate `(.28,.15,.09)` -> `(.40,.20,.10)`, oxidised
	iron `(.15,.40,.37)` -> `(.17,.44,.40)`, galvanised and sign steel de-blued. The concepts run warm
	brass and saturated rust against grey concrete; those accents are most of what makes the concept
	read as rich.
	
	### Method note, and a trap that cost a full cycle
	The v45 capture came back **byte-identical** to v44 -- same mean RGB to three decimals, same p95 --
	while the Blender preview plainly showed the new UV detail. That is the import-cache trap again:
	after a GLB is rewritten, the editor can serve the previously imported copy, and a capture that
	loads the GLB will happily render the old one. **When a change is invisible in capture, measure
	before believing it failed** -- identical statistics mean a stale asset, not a change that did not
	work. Clearing the import cache and re-running fixed it, and the neighbour-pixel delta then moved
	0.03105 -> 0.03292.
	
	### Still short of the concept
	The concepts carry deeper darks and more saturated accents than the build yet does; the value
	structure is now right, but the contrast WITHIN the model is still flatter than the reference. That
	is the next pass.
	
	### State
	449 parts, 25 primitives, tallest 1.450. Concrete albedo warm and full-contrast, `UV_TILE = 1.50`,
	warm ambient and key. BUILD_TAG `v45`. `test_sanctum_glb` 3/3.
	
	## In-model contrast and accents, and a measurement that was lying
	
	Second half of the fidelity pass: the value structure had been fixed but the model's own contrast
	was still flatter than the reference, and the accents were undersold. Three levers, one rebuild:
	an albedo contrast expansion (x1.22 about the mean, applied after the gain and tint in
	`_recolor`), `ssao_intensity` 2.0 -> 3.2 to deepen the contact shadows in the recesses, and
	sharper accents -- brass `(.52,.40,.19)` -> `(.62,.46,.15)`, rust plate -> `(.47,.21,.08)`,
	oxidised iron -> `(.12,.48,.44)`.
	
	### The measurement was wrong, not the change
	
	After the rebuild the whole-image statistics were **unchanged from the previous build** (spread
	0.449 -> 0.444), which reads as "the change did nothing". It had not: the capture renders on
	BLACK, so the 5th percentile is pinned to background pixels and the whole-image spread is really
	measuring "background to brightest highlight". It is structurally blind to contrast WITHIN the
	model, which is the only thing this pass was about.
	
	Re-measured over model pixels only (luminance above 0.10, i.e. everything that is not background):
	
	| capture | mean RGB | R/B | spread | neighbour delta |
	|---|---|---|---|---|
	| concept (whole image) | (0.275, 0.205, 0.169) | **1.63** | 0.529 | -- |
	| v43 | (0.332, 0.291, 0.296) | 1.12 | 0.369 | 0.1084 |
	| v44 | (0.518, 0.425, 0.316) | 1.64 | 0.533 | 0.1344 |
	| v45 | (0.502, 0.423, 0.335) | 1.50 | 0.533 | 0.1423 |
	| v46 | (0.502, 0.419, 0.321) | **1.56** | **0.563** | **0.1504** |
	
	The model's own warmth now matches the concept (1.56 against 1.63), its internal range meets the
	reference (0.563 against 0.529), its highlight end is actually richer (p95 0.686 against 0.530),
	and the detail metric -- mean absolute difference between neighbouring pixels, which is what
	"does it read as texture" actually means -- is up **39%** from v43.
	
	Note the correction this forced: the earlier pass reported the render as R/B 1.12 against the
	concept's 1.63 and called that "not warm enough". Over model pixels the R/B was already 1.64 and
	matched exactly. The blue figure was the background dragging the average, and acting on it would
	have over-warmed the asset to compensate for a measurement artefact.
	
	### Rule for judging an asset from here
	Judge a capture by: **model-pixel mean RGB** (warm if R > G > B), **model-pixel spread**, and
	**neighbour-pixel delta**. Never the whole-image numbers on a black background; the p5 there is
	the background and the mean is a mix of two populations.
	
	### State
	449 parts, 25 primitives, tallest 1.450. Concrete albedo warm, full-contrast and x1.22 expanded,
	`UV_TILE = 1.50`, warm ambient and key at SSAO 3.2, accents saturated. BUILD_TAG `v46`.
	`test_sanctum_glb` 3/3.
	
	## Three things play found that the harness had been flattering
	
	From an in-game screenshot: the stairs did not read as stairs, everything felt washed out, and the
	sign looked like it floated above the road into the gate.
	
	### The over-correction
	
	The previous pass pushed the value up and the compound came out **brighter than the board**, reading
	as pale sand rather than stone. Concrete gain 1.00 -> 0.80, ambient 0.72 -> 0.62, key 1.30 -> 1.20.
	Mid-grey is both the concept's value and what lets the recesses and the tile read as darker than the
	walls.
	
	### The stairs never had tone
	
	Every tread used the one `concrete` material. A flight of identical steps under a flat key is a
	single flat slab however correctly it is stepped -- which is exactly how it rendered. The single-hex
	build toned its treads lighter-to-darker with depth and that is the only reason its stairs read; the
	compound dropped that when it was rebuilt. Treads are now toned by index (`.44 -> .15` luminance)
	with the pale nosing per step kept as a bright line against the darkening tread, and the shaft lip
	is a new dark `shaft_lining` so the mouth reads as an opening rather than a pale kerb.
	
	### The sign genuinely was floating
	
	The sign box spans the GATE APOTHEM (2.40) but the two gate monoliths that are supposed to carry it
	sit on the hex **corners** at radius `WALL_R` (2.77). A 1.15-long sign between posts 2.77 apart
	touched neither. Two legs now stand under its ends, landing on the platform (which extends past the
	deck's 2.10 apothem to about 2.6). 449 -> 451 parts.
	
	### Not a defect: the hole beside the base
	
	The dark pit at the base's top-right is a neighbouring **BLOCKED terrain hex**, not a gap in the
	compound. Evidence: identical dark pits appear all over the board (a rubble hex is built with a rim
	and a sunken interior), and this one is outside the compound's wall. Worth stating because "there is
	a hole" is exactly what a correct rubble tile looks like when it lands next to the thing you are
	staring at.
	
	### Honest limit
	The treads read as steps in the close view and the shaft now reads as a lit opening at gameplay
	zoom, but at the default zoom it is still a small feature: a descending stair a third of a hex wide
	is not going to be a landmark. If it needs to be unmistakable at zoom 18, that is a scale change to
	the shaft, not a material one.
	
	### State
	451 parts, 32 primitives, tallest 1.450. BUILD_TAG `v47`.
	
	## The stair still read as flat ground — thicken the plinth
	
	Three passes. The first two each fixed a real defect and neither was the problem.
	
	### v48 — darken the pit (necessary, not sufficient)
	Pale vitreous tile lined the *inside* of the shaft, so the recess read as a shallow bright box: the
	single biggest reason a hole looked like a shelf. The below-deck walls are now lined in a dark
	`shaft_lining` tone, and the shaft lamp moved off the deck to the pit floor (0.62 scale), so it
	lights the treads from *inside* the hole instead of poking out of the opening.
	
	### v49 — fewer, taller steps (still not sufficient)
	Six treads spread over the shaft gave a 0.271 run against a **0.040 rise** — a 1:6.8 ratio, i.e. a
	6-degree ramp. Compressing the flight into the first 42% of the shaft made the *slope* steep, and it
	still read as flat ground. Slope is not what the eye uses: it uses the **RISE per step**, and 0.040
	is about **one screen pixel** at gameplay zoom, so the risers were invisible and only the tread
	tops were visible — a flat surface, however steep the flight's overall ratio looks. Three treads on
	the same 0.30 drop gave a 0.10 rise (~8 px) and still only partly read, because 0.30 was the whole
	budget.
	
	### v50 — the actual fix: a thicker plinth
	The drop is bounded by the platform's thickness, and the platform was 0.34, so the descent could
	never exceed ~0.30. **That bound was self-imposed, not structural.** The plinth is now **0.560**,
	which buys a **0.42 drop**: four treads at a **0.14 rise** (~11 px) with a 0.195 run — a 36-degree
	stair.
	
	The one real constraint is the height cap, and it is not cosmetic: `HexMath.TOWER_MAX_HEIGHT` (1.5)
	exists because enemies *arrive* at this hex, so anything taller hides the build hexes behind the
	base. Every height measured up from the deck is therefore multiplied by
	`ABOVE_SCALE = (1.45 - PLAT) / (1.45 - 0.34)` = **0.8018**.
	
	Two things made that safe:
	
	1. It is applied as **one Z-scale about the deck**, over every part whose base sits at or above it,
	   immediately before the join — not by editing a dozen height constants. Those constants are what
	   the `HEIGHTS` assert reads, so editing them would have changed what the assert *meant*.
	2. **The 41 decals are separate plane objects** with their own Z literals, so they are inside that
	   same loop: a sigil rides down with the wall it was glued to and stays glued. A constant edit
	   would have left every sigil floating above a wall that had shrunk away from it — the v41
	   failure, reintroduced by a different route.
	
	`HEIGHTS` now passes through the same `_above()` scale as the geometry, so the assert measures what
	was built rather than the pre-scale intent. Build reports `scaled 394 parts above the deck by
	0.8018`.
	
	| | v47 | v50 |
	|---|---|---|
	| platform top | 0.340 | **0.560** |
	| shaft drop | 0.30 | **0.42** |
	| treads | 6 | 4 |
	| rise per step | 0.040 (~1 px) | **0.140 (~11 px)** |
	| run per step | 0.271 | 0.195 |
	| stair angle | 6 deg (a ramp) | **36 deg** |
	| tallest | 1.450 | 1.450 (cap 1.5) |
	
	### Two consequences of the thicker plinth
	- **The gate sill is now 0.56 above the road.** A station entrance has to meet the pavement it
	  serves, so this wants a short flight of entry steps outside the gate. Not built yet.
	- **`path_view.gd` silently falls back to the base's purple pedestal when the GLB cannot load**,
	  with no warning. Hit by accident mid-pass (an un-imported GLB showed a bare pedestal and no
	  error), which makes a failed load look identical to a design choice. Should at least log.
	
	### Verified / not verified
	Verified: the build assert (`TALLEST 1.450`, limit 1.5), 450 parts joined with 0 left over, 41
	decals shipped, and the Blender preview, which now shows a deep dark shaft where v47 showed a
	shallow recess. **Also verified in the running game** at BUILD_TAG `v50`: the plinth reads as a
	thick raised terrace and the shaft as a dark, lamp-lit recess descending out of the court. The
	individual treads are still small at gameplay zoom — legible, not a landmark.
	
	### State
	450 parts, 30 primitives, tallest 1.450. BUILD_TAG `v50`.
	
	## v51 — the pit was never actually cut open
	
	**The root cause of "it just looks like flat ground", found after three passes that all missed it.**
	
	The platform is seven **solid** hex prisms (`hex_prism(..., PLAT, ...)`), and nothing ever removed a
	hole from them. So the "shaft" was a decorative box resting on an unbroken concrete floor **at deck
	level**: the treads, the nosings and the lamp were all buried inside solid geometry. From above, the
	opening was a flat surface at `PLAT`. No amount of tread tone, tread proportion, pit lining or lamp
	placement could ever show a descent, because *there was no hole to see into*. Every pass in v48-v50
	was tuning the contents of a room with no door.
	
	Also wrong, and load-bearing: **`SHAFT_FLOOR` was kept above z=0** on the belief that below the
	ground plane "pokes through the terrain". `TOWER_MAX_HEIGHT` is measured from **z=0 up** — z=0 is
	the floor of the hexes, sea level — and anything below it is **depth, not height**, and is not
	counted. Depth is free. The plinth therefore goes back to **0.34** and `ABOVE_SCALE` is **deleted**
	along with its whole Z-scale transform: there was never anything to pay for. That also removes the
	0.56 gate sill the v50 plinth created.
	
	### What changed
	- **A real cut.** One `Shaft cutter` box plus a boolean `DIFFERENCE` per platform prism, applied by
	   the existing `convert(target='MESH')` before the join. The cutter reaches past `SHAFT_FLOOR` so
	   the pit's own floor is not clipped, is kept out of `objs` so it is never joined or exported, and
	   is deleted immediately after the convert.
	- **`SHAFT_FLOOR = -0.50`** — below sea level, on purpose.
	- **Six treads** on a 0.74 drop: a **0.13 rise** each (~10 px at gameplay zoom).
	- Lining depth, handrail drop and lamp rod are now derived from `PLAT - SHAFT_FLOOR` instead of
	   hardcoded, so changing the depth cannot leave them behind.
	- **`terrain_view.get_hex_tile_archetype` returns `""` for base hexes** and the chunk builder skips
	   empty ids. The Sanctum's platform covers all seven base hexes exactly (radius 1.005 hexes against
	   a hex of 1.0), so the lot was invisible from every angle *except through the stairwell* — where it
	   would have floored the pit at sea level and hidden the descent all over again.
	
	### The assert now measures the building, not the plan
	Per the height rule, the check runs on the **actual joined mesh**: max vertex z from z=0 up, with
	below-zero explicitly excluded (plus `assert mesh_bottom < 0.0` to lock the descent in). It caught
	something immediately: `measured mesh: top 1.490` against a hand-listed tallest of **1.45**. The
	`HEIGHTS` table was still under-reporting by 0.04 — the exact v40 failure mode, where the thing
	being measured was not the thing that was tall. Still under the 1.5 cap, but with 0.01 of headroom,
	and the offending part should be identified and trimmed.
	
	### State
	454 parts, 32 primitives, mesh top **1.490**, mesh bottom **-1.060**. BUILD_TAG `v51`.
	Preview shows a staircase descending into a dark pit; `test_sanctum_glb` 3/3.
	
	## v52 — the road across the compound, a loud missing model, and the part that was too tall
	
	### The road drew across the sanctum -- TWO renderers, and only one was fixed at first
	The path runs INTO the base hexes. Fixing `terrain_view.get_hex_tile_archetype` (testing `is_base_hex`
	**before** `is_path_hex`, so base hexes draw nothing) stopped the ground tile -- and the chevrons
	still drew inside the compound, because **`path_view.gd` draws road too, from a completely separate
	source**: its own `PathHexesMultiMesh` (the directional chevron lane, `_build_directional_lane_mesh`)
	and `PathConnectorsMultiMesh` (the road surface), both built in `refresh_lanes` from the lane array
	and with no knowledge of the base footprint at all. Three things draw road on this board; the ground
	tile was only one of them. `PathView` now skips base hexes in BOTH loops -- the lane tiles and any
	connector segment with a base-hex endpoint -- via a small `_is_base_hex()` that reads the grid off
	`GameState`, the same way `TerrainView` does. Verified in-game: the chevron road stops at the
	compound's edge.
	
	**Lesson: "the road" was not one thing.** A renderer fix must be traced to every surface that draws
	it, or half the symptom survives and looks like the fix did nothing.
	
	### A missing Sanctum is now loud
	Removing the base-hex ground tile moved the base's floor INTO the model, so a failed load no longer
	leaves a pedestal on a lot -- it leaves a HOLE IN THE WORLD. `path_view.gd` now `push_error`s on
	both failure paths (`ResourceLoader.exists` false, and `load()` returning null) rather than silently
	keeping the pedestal, which is exactly what made an unimported GLB look like a design choice.
	
	### The tallest part, named
	The mesh check reported top 1.490 against a hand-listed 1.45, so the build now prints the six tallest
	parts by name. It was **`Gate cable 1` (1.490)**, then `Gate cable 2` (1.469): the two decorative
	cables strung from the sign box began at `SIGN_Z + .18`, i.e. 0.03 ABOVE the sign's own top, so they
	sprouted off the top of the box and floated above it. Both now attach at `SIGN_Z + .06/.05` -- the
	side of the box, as intended -- which puts the gate sign back as the tallest element at 1.450 and
	restores the headroom under the cap to 0.05.
	
	### State
	454 parts, 32 primitives, mesh top **1.450**, mesh bottom **-1.060**. BUILD_TAG `v53`.
	
	## v54-v55 — flat accent materials, and the lean-to's clipping
	
	### The treads and handrails were FLAT, and that is what "smooth" meant
	`flat()` materials carry no albedo map and no normal map, so under one key light a surface has no
	variation for a highlight to catch and reads as a sheet of plastic. The stair treads were
	`flat('Tread tone %d', ...)` -- the per-tread tonal ramp was compensation for having no hole to see
	into (v51), and once the pit was real it was just a smooth ramp again. Treads are now the board-formed
	**concrete** texture; the tread nosings and both handrails moved from `steel_pale` (flat
	"Galvanised") to the **`pipe`** ("Salvaged steel") texture that was already in the file, unused by
	the stairs.
	
	### The fence: the first accent material with a real texture
	`railing()` used `brass` -- a flat colour -- for both posts and rails, so the yellow perimeter fence
	was smooth yellow plastic at close range. A new seamless tile (`tex_fence_yellow.png`, weathered
	yellow paint over galvanised steel with chipped patches, rust bleed and drip streaks) now goes
	through the same derive pipeline as concrete and tile, producing `tex_fence_yellow_n.png` and
	`mr_fence_yellow.png`. The railing uses it via a new `fence_steel` texmat.
	
	**Metallic is 0.10, deliberately.** `main.tscn` has a flat colour background and no reflection probe,
	so a strongly metallic surface has nothing to reflect and renders BLACK. Painted steel is a
	dielectric surface anyway; only the exposed chips are real metal. The normal derives from the
	texture's OWN albedo, for the same reason the tile does -- the only real relief on it is the chipped
	paint edge, which is already in the albedo, and a separate height source would disagree with it.
	
	**The rest of the flat family (v56)** -- `brass`, `red`/`white` hazard, `propane`, `sign_steel`,
	`concrete_dark`, `steel_pale`, `wax`, `tin`, `shaft_lining` -- went through the same recipe:
	generate a seamless tile, add a `JOBS` entry, add a `texmat`, swap it in. Seven new tiles produced
	ten materials, because two share (`red`/`propane` use the hazard red, `steel_pale`/`tin` the
	galvanised sheet, `concrete_dark`/`shaft_lining` the dark concrete). Every one derives its normal
	from its OWN albedo: on all of these the relief IS the albedo -- chipped paint edges, aggregate
	grain, form marks, brush tarnish -- so a separate height source would put detail where the colour
	has none, which is the moire problem the tile documented. Metallic stays at 0.10 or below
	throughout, for the no-reflection-source reason above.
	
	**Deliberately left alone:** `tarp` is a dark green tarpaulin (.13,.17,.14), NOT the pale
	`canvas` -- swapping it would have turned it into a different object, so it stayed flat until it
	gets its own tile. `bone` ("Offering") is warm off-white and would read waxy under the wax texture.
	`dark` is the stairwell void and has nothing to texture. `flame`/`glow`/`sign_glow` are emissive, and
	`texmat` has no emissive path.
	
	### The lean-to clipped its own supports
	Two separate geometric faults, both from placing supports against a CORNER height instead of the
	roof's actual surface:
	- the posts took the z of a corner (`LH_LOW` / `LH_HIGH`) while being inset 0.10 along X, putting the
	  high-side post's top `0.10 * slope` = 0.025 ABOVE the sheet -- a pipe punching through the roof;
	- the two cross beams ran LEVEL along X under a sloping sheet, so they cut through the low end by
	  definition, at any height.
	
	Now derived: a `lh_surface(x)` helper gives the sheet's underside at any X, posts stop 0.03 below it,
	and the two level beams became **purlins** rotated to the sheet's own pitch -- parallel to the
	roof, which is also what a real lean-to does. Build is geometrically unchanged (454 parts, 0
	unjoined), so the counts and the 1.450 ceiling held.
	
	### State
	454 parts, 32 primitives, mesh top **1.450**, mesh bottom **-1.060**. BUILD_TAG `v55`.
	
	## v56-v57 — the rest of the accent family, and the shrine's pipe
	
	### Seven tiles covered ten materials (v56)
	`brass`, `red`/`white` hazard, `propane`, `sign_steel`, `concrete_dark`, `steel_pale`, `wax`, `tin`,
	`shaft_lining` all became `texmat`s. Sharing is why seven tiles did ten materials: `red`/`propane`
	use the hazard red, `steel_pale`/`tin` the galvanised sheet, `concrete_dark`/`shaft_lining` the dark
	concrete. Two rules applied throughout, both from earlier findings: every normal derives from its OWN
	albedo (on all of these the relief IS the albedo -- chipped edges, aggregate grain, form marks, brush
	tarnish -- so a separate source would put detail where the colour has none), and metallic stays at
	0.10 or below because there is no reflection source to reflect.
	
	### The last three, and the pipe shrine (v57)
	`tarp` and `bone` got their own tiles -- `tarp` a dark green woven tarpaulin, `bone` pitted ivory.
	Both had been held back in v56 rather than pointed at an existing texture that would have made them
	something else.
	
	**The shrine's pipe was not `pipe`.** Every part of the standpipe -- base flange, foot flange,
	barrel, collar, neck, dome, elbow, elbow plate -- uses **`teal_iron`**, a flat `.12/.48/.44`, and had
	never been textured at all. The standpipe is now weathered oxidised teal cast iron: verdigris with
	casting pitting, rust bloom breaking through, chalky mineral deposits.
	
	`pipe` itself ("Salvaged steel" -- handrails, lean-to purlins, lamp cages, barrier legs) got a new
	albedo too, and its job entry was added so its `_n` map is **re-derived from the new albedo**. That
	matters: replacing an albedo while leaving its old normal in place is the mismatched-normal problem,
	and it is why the job list, not the asset folder, is the source of truth for what maps a texture has.
	
	### State
	454 parts, 32 primitives, mesh top **1.450**, mesh bottom **-1.060**. BUILD_TAG `v57`.
	
	## v58 — the concrete, which was the last flat-looking thing
	
	Everything else had a purpose-generated tile by now, so the concrete -- the LARGEST surface in the
	compound, and the one the eye spends the most time on -- stood out as flat precisely because it was
	still the original pre-spike albedo, run through the tone step. A low-resource source is still a
	low-resource source however carefully it is recoloured: the recolour can normalise value and warmth,
	but it cannot invent board seams, tie-rod holes or exposed aggregate that were never in the file.
	
	Replaced with a purpose-generated board-formed concrete: horizontal board seams with the timber grain
	pressed in, tie-rod holes in regular rows, patches of exposed aggregate, hairline shrinkage cracks,
	damp staining running down from the seams. Feature scale lands right -- six seams across 512 px at
	`UV_TILE` 1.50 is roughly a 0.21-unit board against the concept's ~0.25.
	
	**Its normal is now derived from its own albedo too**, and the job entry no longer reads
	`hgt_concrete.png`. That purpose-made height map was legitimate while the albedo and the map came
	from the same source, but the albedo has been replaced: a form-seam grid in the height map that
	disagrees with the form-seam grid in the colour is exactly the moire this pipeline exists to avoid.
	The new albedo carries its own seams and holes, so deriving from it aligns by construction. Strength
	3.0 -> 2.6, since the new albedo has far more high-frequency structure to convert.
	
	`hgt_concrete.png` is now unused but KEPT: it is a source, and deleting a source is not recoverable.
	The old albedo is kept as `tex_concrete_base_v1.png` for the same reason -- the tone step reads
	`tex_concrete_base.png`, so replacing it in place would have destroyed the thing that step depends on.
	
	Measured after the pass: base 0.476, recoloured albedo 0.356 (matching the concept's mid-grey),
	normal 0.535 (a normal map should average ~0.5), roughness 0.720 against a 0.74 base.
	
	### State
	454 parts, 32 primitives, mesh top **1.450**, mesh bottom **-1.060**. BUILD_TAG `v58`.
	
	## v59 — texture audit, and a measured clipping audit
	
	### The orange thing with no texture: `rust_plate`
	Grepping the remaining `flat()` definitions found `rust_plate = flat('Rusted plate', (.47, .21, .08),
	.85, .10)` -- a strong orange-brown -- and grepping its USES found the culprit: `cyl('Oil drum',
	(1.90, -.55, PLAT + .30), .24, .58, rust_plate)`, a 0.58-tall drum, plus the barrel bands, the barrel
	lid and the shrine pad's angles and cleats. It now has a purpose-generated heavily-rusted steel tile.
	`rock` ("Rubble") was folded onto the existing dark concrete texture rather than getting its own.
	
	### Texture audit result: nothing with a visible area is left flat
	Remaining `flat()` materials, and why each is correct:
	- `dark` (.012/.008/.016) -- the stairwell void. Nothing to texture.
	- `flame`, `glow`, `sign_glow` -- emissive, and `texmat` has no emissive path.
	- `tent` (.075/.05/.09) -- the tentacles under the shaft; near-black, so texture would not read.
	- `rust_streak` (.24/.11/.055) -- thin stain streaks; a texture on a 0.14-wide streak has no pixels.
	
	### Clipping audit: a real check, and an honest statement of its limits
	The build now measures every part's world AABB against every other and reports pairs sharing more
	than 30% of the smaller part's volume. Result: **377 pairs, and no gross clipping** -- the top hits
	are all *designed* nesting (a sign face inside its frame, wax inside a jar, a flame inside its glass,
	the tarp hood over the standpipe dome).
	
	**The method cannot tell nesting from clipping**, and that is worth stating rather than papering
	over: both are "one solid inside another", and what separates them is whether the inner thing is
	MEANT to be visible. That is a semantic judgement an AABB test cannot make. Its real value is as a
	"look here" list, and a same-material filter was added to help -- though it only cut 377 to 219,
	because most legitimate nesting is also cross-material.
	
	Genuine candidates it surfaced, all small: the standpipe **elbow clips a candle flame** (real
	intersection, ~0.1-unit radii), a **flange bolt sits under the elbow's first leg**, and
	**`Rail 4 post 8` coincides with `Gate post 270`** (two posts in one place -- a redundant part, hidden
	inside the other). None is a gross artefact. The lean-to from v55 appears nowhere in the list, which
	is the confirmation that fix held.
	
	### State
	454 parts, 32 primitives, mesh top **1.450**, mesh bottom **-1.060**. BUILD_TAG `v59`.
	
	Left for a follow-up, in priority order: the three small clips above; `tent` and `rust_streak` if a
	texture is ever wanted on near-black or hairline geometry.
	
	## v60 — measuring the three "clips": there were none
	
	The v59 audit listed three candidates. Before changing any geometry, the audit was extended to answer
	the question the box test cannot: for each flagged pair, the actual **minimum distance between the
	two parts' vertices**, subsampled. Touching geometry reads ~0.000; a clear miss reads a real gap.
	
	| pair | box test | actual gap |
	|---|---|---|
	| `Standpipe elbow` <-> `Shrine flame 8` | 100% | **0.057** |
	| `Standpipe bolt 0` <-> `Standpipe elbow` | 100% | **0.135** |
	| `Rail 4 post 8` <-> `Gate post 270` | 100% | **0.308** |
	
	**All three were bounding-box artefacts**, which is exactly the failure mode flagged when the box
	test was written: a long tube's AABB is enormously larger than the tube, so it contains small parts
	whole and reports 100% for a clear miss. The pipe passes 57 mm from the flame (the flame is 36 mm
	wide, so it is clear); the bolt is 135 mm from the elbow; and the two posts are 308 mm apart -- they
	were never coincident, so the duplicate-post reading in v59 was simply wrong.
	
	The only pair that measures ~0.000 is `Standpipe dome <-> Shrine hood`, which is the tarp sitting on
	the dome. Correct by design. `Shrine jar <-> wax` measures 0.015, also correct.
	
	So: **no clips to fix.** Two things follow. First, the box test is only a "look here" list and the
	gap measurement is what decides -- they are now printed together so a candidate is never reported
	without its verdict. Second, the `_SUPPORTS_XZ` post guard added on the strength of the false
	duplicate is kept but re-commented as DEFENSIVE rather than a fix: a genuinely duplicated post would
	be invisible, buried inside the larger one, and so could never be caught by looking. Part count is
	unchanged at 454, confirming it removed nothing.
	
	### State
	454 parts, 32 primitives, mesh top **1.450**, mesh bottom **-1.060**. BUILD_TAG `v60`.
	
	Both audits now run on every build: the texture audit from the `flat()` definitions in use, and the
	clipping audit as box overlap PLUS a vertex-gap verdict.
	
	## v61 — the sign face, and why it was the last flat piece
	
	The off-white panel in the sign banner was `sign_glow = flat('Sign face', (.50, .54, .48), .30, 0, 0.22)`
	-- and it had stayed flat for a structural reason, not an oversight: **`texmat` had no emissive
	path**. Anything that glowed had to be `flat()`, so a textured backlit panel was not expressible.
	
	`texmat` now takes an `emissive` parameter and links the SAME image node to both Base Color and
	Emission Color, with Emission Strength set from it. glTF exports that as an emissive texture plus
	`KHR_materials_emissive_strength`, both of which Godot reads, so a textured emissive surface is now
	possible anywhere in the model -- the v59 texture audit could not see this class of gap, because it
	was looking for `flat()` calls and the reason was a missing capability rather than a missed swap.
	
	The panel reuses `tex_paint_white` (grimy off-white, already derived) rather than a new tile: it is
	the right surface for a weathered backlit sign, and the white paint's dirt and rust creep read
	correctly lit from behind. A dedicated backlit-panel tile with faint signage would be the next step
	if the face ever needs to look like it says something.
	
	### State
	454 parts, 32 primitives, mesh top **1.450**, mesh bottom **-1.060**. BUILD_TAG `v61`.
	
	## Reorg — the spike becomes the pipeline (no model change; still v61)
	
	The folder stopped being a spike and became the project's graphics pipeline, so it was renamed and
	cleaned: `graphics_generation/initial_visual_spike/` -> `graphics_generation/sanctum/`, with
	`concepts/` lifted to `graphics_generation/concepts/`. **No geometry changed** -- this is the same
	v61 asset, and the build/verify path below still produces it.
	
	**Removed** (all recoverable or regenerable): the three superseded models (`cult_sanctum`,
	`sanctum_subway`, `sanctum_massing`) with their `.blend`/`.blend1` sources and
	`build_sanctum.py`/`build_massing.py`; ~2250 versioned capture PNGs; the superseded models'
	extracted texture families; orphaned `.import` files. **Kept**: the compound build pipeline, the
	three harnesses (`capture_sanctum`, `capture_nail_gun`, `lighting_ab`), `PLAN.md`, this file, all
	eleven concepts, and the shipped GLB with its tiles.
	
	**Two traps the move exposed, both worth more than the cleanup itself.**
	
	First: a full-project grep for the old path found **fourteen** references, not the handful expected,
	and **two of them were runtime-load-bearing textures that looked exactly like spike leftovers** --
	`spike_cult_seal.res` (preloaded by `tower_view.gd`) and `spike_iron_board.res` (preloaded by
	`enemy_mover_view.gd`). Deleting by filename pattern would have broken the game and the failure
	would not have appeared until a tower or a mech was drawn. Grep for a path before moving a folder,
	and treat `preload()` in a view script as a runtime contract regardless of the folder's name.
	
	Second: the assumption that a `.glb` with embedded textures needs no sidecar PNGs is **wrong in
	Godot**. The glTF importer extracts the embedded images to `sanctum_compound_tex_*` /
	`sanctum_compound_mr_*` PNGs beside the GLB and the imported scene references *those*. Deleting them
	and the `.import` does not break the asset, but it does force a reimport -- and the first run after
	a cache clear always fails with `No loader found` / `Can't load dependency`. The sidecars came back
	by themselves (112 regenerated). They are a generated artifact and must never be hand-edited.
	
	**Verified**: zero references to the old path anywhere in the project; `test_sanctum_glb.gd` 3/3 and
	`test_base_gate_alignment.gd` 3/3 (both read the asset by path, so they *are* the validation of the
	move); `test_integration.gd` 13/13 including the 300-enemy performance stress; and a live `main.tscn`
	run showing the compound mounted, textured and gated with the road leaving through the gate.
	
	Also written: the reusable `create-3d-asset` skill (`.ziva/skills/create-3d-asset/`, with a
	self-checking build template and a capture template) and
	`graphics_generation/concepts/README.md` -- the style brief reconstructed from this record, since
	**the original concept prompts were never written down anywhere**. That omission is why the skill
	now makes recording a prompt a required step.
	
	Still flat, for the record: `rust_plate` (shrine pad angles/cleats), `dark` (the stairwell void, which
	has nothing to texture), and `flame`/`glow`, which are emissive. (`sign_glow` is no longer flat --
	v61 gave `texmat` an emissive path and the sign face now uses it.)
	