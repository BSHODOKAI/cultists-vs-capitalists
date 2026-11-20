## Derives the surface maps a material needs from images that already exist.
##
## Two jobs:
##   1. HEIGHT -> NORMAL, by Sobel. The height source is chosen per material, and the choice matters:
##      * `concrete` derives its height from its OWN ALBEDO too, and no longer from `hgt_concrete.png`.
##        That purpose-made map was legitimate while the albedo and the map came from the same source, but
##        the albedo has since been replaced: a form-seam grid in the height map disagreeing with the
##        form-seam grid in the colour is precisely the moire this file exists to avoid. The replacement
##        albedo carries its own seams, tie holes and exposed aggregate, so deriving from it aligns by
##        construction and there is no second artefact to keep in step. `hgt_concrete.png` is now unused
##        but kept, because it is a source and deleting a source is not recoverable.
##      * `tile` derives its height from its OWN ALBEDO. A tile grid is a strict, learnable pattern,
##        so a height map with a different grid than the albedo produces a moire of two lattices.
##        Off-the-shelf height maps are worse than useless here; the albedo's grout lines are already
##        the height (dark channel = recessed groove), and deriving from it aligns by construction.
##      This is the lesson from the earlier fidelity pass restated: a normal map is wrong if it
##      disagrees with the albedo, no matter how good it looks on its own.
##   2. ALBEDO -> ROUGHNESS/METALLIC PACK (glTF ORM convention: G = roughness, B = metallic).
##
## Run through Ziva's `execute_script` by instantiating this and calling `run()`.
extends RefCounted

const A := "res://graphics_generation/sanctum/assets/"

# albedo, height-source ("" = derive from albedo), normal out, strength, roughness base, rough
# variation, metallic
const JOBS := [
	["tex_concrete.png", "", "tex_concrete_n.png", 2.6, 0.74, 0.20, 0.0],
	["tex_tile.png", "", "tex_tile_n.png", 1.7, 0.30, 0.10, 0.0],
	# Painted fence steel. The normal derives from its OWN albedo rather than a separate height map: the
	# only real relief on it is the chipped paint edge, and that is already in the albedo, so a different
	# source would disagree with it -- the same reasoning the tile follows. Metallic is 0.10, not 0.9:
	# main.tscn has a flat colour background and no reflection probe, so a metallic surface has nothing
	# to reflect and renders black. Painted steel is a dielectric surface anyway.
	["tex_fence_yellow.png", "", "tex_fence_yellow_n.png", 1.6, 0.55, 0.12, 0.10],
	# The accent family. Every one derives its normal from its OWN albedo: on all of these the relief
	# IS the albedo -- chipped paint edges, aggregate grain, form marks, brush tarnish -- so a separate
	# height source would put its detail somewhere the colour does not have any, which is the moire
	# problem the tile documented. Metallic stays at 0.10 or below throughout: main.tscn has no sky and
	# no reflection probe, so a strongly metallic surface has nothing to reflect and renders BLACK.
	["tex_metal_galv.png", "", "tex_metal_galv_n.png", 1.4, 0.55, 0.14, 0.10],
	["tex_dark_metal.png", "", "tex_dark_metal_n.png", 1.3, 0.50, 0.14, 0.10],
	["tex_hazard_red.png", "", "tex_hazard_red_n.png", 2.0, 0.70, 0.12, 0.0],
	["tex_paint_white.png", "", "tex_paint_white_n.png", 1.6, 0.75, 0.12, 0.0],
	["tex_dark_concrete.png", "", "tex_dark_concrete_n.png", 2.2, 0.80, 0.16, 0.0],
	["tex_aged_brass.png", "", "tex_aged_brass_n.png", 1.6, 0.42, 0.16, 0.10],
	["tex_wax.png", "", "tex_wax_n.png", 1.2, 0.62, 0.10, 0.0],
	# The last four. `tex_pipe_steel` is a REPLACEMENT of an older albedo, so it must be re-derived
	# here or its existing `_n` would be a normal map for a surface that no longer exists -- the
	# mismatched-normal problem, and the reason this job list is the single source of truth for what a
	# texture's maps are.
	["tex_tarp_green.png", "", "tex_tarp_green_n.png", 2.0, 0.85, 0.10, 0.0],
	["tex_bone.png", "", "tex_bone_n.png", 1.8, 0.80, 0.10, 0.0],
	["tex_pipe_steel.png", "", "tex_pipe_steel_n.png", 1.8, 0.55, 0.14, 0.10],
	# Oxidised cast iron, the shrine's standpipe. It was `teal_iron`, a flat .12/.48/.44, on every part
	# of the shrine -- flanges, barrel, collar, neck, dome, elbow, plate. This is the weathered verdigris
	# with rust bloom and casting pitting that the teal iron in the concept has.
	["tex_teal_iron.png", "", "tex_teal_iron_n.png", 1.8, 0.55, 0.14, 0.10],
	# Found by the texture audit: `rust_plate` was a flat .47/.21/.08 -- a strong orange-brown -- and it
	# is the material of the OIL DRUM, the barrel bands, the barrel lid and the shrine pad's angles and
	# cleats. The oil drum is the largest of those by far, hence "something orange with no texture".
	["tex_rust_plate.png", "", "tex_rust_plate_n.png", 2.0, 0.85, 0.14, 0.10],
]

# Tone. Originals are kept as *_base.png so re-running this is idempotent instead of darkening the
# same image a little further on every pass.
#
# The first version darkened the concrete to 0.52 AND tinted it cool (basis B 1.16, R 0.94). Measured
# against the concept art, that was wrong in two independent ways:
#
#   * COLOUR. The result was blue-dominant -- mean RGB (0.233, 0.240, 0.277), B above R -- while the
#     concept's stone is warm, (0.275, 0.205, 0.169), R > G > B. A cool albedo under a cool ambient
#     gave the whole compound a grey-blue cast, which is what "washed out in cool tones" described.
#   * CONTRAST. Multiplying by 0.52 halved the texture's luminance spread, 0.187 -> 0.097. The board
#     seams, tie holes and rust weeps are the concrete's entire character at this scale, and that step
#     threw them away: the walls rendered as untextured flat grey however good the artwork underneath
#     was. No amount of normal-mapping recovers detail that has been multiplied out of the albedo.
#
# The multiplier is now the artwork's own value (1.0) with a WARM basis, so the stone reads as the
# light warm surface the concepts show and keeps its full pattern.
# The 5th column is a CONTRAST expansion applied about 0.5 after the gain and tint. The render's
# p5-p95 spread was still 0.454 against the concept's 0.529 even once the tone and warmth matched, so
# the surfaces were reading flat however correct their average was. Broadening the albedo about its
# own mean widens that spread without changing the value, and it coarsens the board seams and stains
# into readable structure rather than a haze.
# 0.80, down from 1.00: at full value the compound rendered BRIGHTER than the pastel board around
# it and read as pale sand rather than stone. Mid-grey is both the concept's value and the thing that
# makes the recesses and the tile read as darker than the walls.
const RECOLOR := [
	["tex_concrete_base.png", "tex_concrete.png", 0.80, Vector3(1.05, 1.00, 0.94), 1.22],
	["tex_tile_base.png", "tex_tile.png", 0.95, Vector3(1.02, 1.00, 0.98), 1.05],
]


func run() -> void:
	for job: Array in RECOLOR:
		_recolor(ProjectSettings.globalize_path(A + String(job[0])),
			ProjectSettings.globalize_path(A + String(job[1])), float(job[2]), job[3] as Vector3,
			float(job[4]))
	for job: Array in JOBS:
		var albedo: String = job[0]
		var hsrc: String = job[1] if String(job[1]) != "" else albedo
		_normal(ProjectSettings.globalize_path(A + hsrc),
			ProjectSettings.globalize_path(A + String(job[2])), float(job[3]))
		_mr(ProjectSettings.globalize_path(A + albedo),
			ProjectSettings.globalize_path(A + "mr_" + albedo.trim_prefix("tex_")),
			float(job[4]), float(job[5]), float(job[6]))


func _gray(path: String) -> Image:
	var img: Image = Image.load_from_file(path)
	img.convert(Image.FORMAT_RGB8)
	return img


## Sobel height -> tangent-space normal, OpenGL convention (green is up), wrapping at the edges so
## the result stays seamless.
func _normal(hpath: String, outpath: String, strength: float) -> void:
	var h: Image = _gray(hpath)
	var w: int = h.get_width()
	var hh: int = h.get_height()
	var d: PackedByteArray = h.get_data()
	var o: PackedByteArray = PackedByteArray()
	o.resize(w * hh * 3)
	for y in hh:
		var yu: int = (y - 1 + hh) % hh
		var yd: int = (y + 1) % hh
		for x in w:
			var xl: int = (x - 1 + w) % w
			var xr: int = (x + 1) % w
			var dx: float = (_at(d, xr, y, w) - _at(d, xl, y, w)) / 255.0
			# rows run top-down, so "up" is the smaller index; flip so green points up.
			var dy: float = (_at(d, x, yu, w) - _at(d, x, yd, w)) / 255.0
			var n: Vector3 = Vector3(-dx * strength, -dy * strength, 1.0).normalized()
			var i: int = (y * w + x) * 3
			o[i] = int(clampf(n.x * 0.5 + 0.5, 0.0, 1.0) * 255.0)
			o[i + 1] = int(clampf(n.y * 0.5 + 0.5, 0.0, 1.0) * 255.0)
			o[i + 2] = int(clampf(n.z * 0.5 + 0.5, 0.0, 1.0) * 255.0)
	_write(outpath, w, hh, o)


## Roughness from albedo luminance: darker means wetter, dirtier or more worn, and wet is SMOOTHER.
## The first version had this sign the wrong way round, so the darkest, wettest concrete came out the
## roughest - exactly backwards.
##
## The concrete base is 0.74, NOT the 0.55 that "wet" first suggests. This scene's Environment has no
## sky and no reflection source, so a smooth surface mirrors it and returns BLACK: at 0.55 the whole
## courtyard went nearly black in capture while the brass turned into a hot gold cutout. The damp read
## has to come from the wet-patch decals and a moderate sheen instead; a genuinely mirror-like wet
## floor needs a reflection source in the scene, which is a main.tscn change, not a material one.
func _mr(apath: String, outpath: String, base: float, var_amt: float, metal: float) -> void:
	var s: Image = _gray(apath)
	var w: int = s.get_width()
	var hh: int = s.get_height()
	var d: PackedByteArray = s.get_data()
	var o: PackedByteArray = PackedByteArray()
	o.resize(w * hh * 3)
	for i in range(w * hh):
		var lum: float = (d[i * 3] * 0.2126 + d[i * 3 + 1] * 0.7152 + d[i * 3 + 2] * 0.0722) / 255.0
		var r: float = clampf(base + (lum - 0.5) * var_amt, 0.05, 1.0)
		o[i * 3] = 255
		o[i * 3 + 1] = int(r * 255.0)
		o[i * 3 + 2] = int(metal * 255.0)
	_write(outpath, w, hh, o)


func _at(d: PackedByteArray, x: int, y: int, w: int) -> float:
	return float(d[(y * w + x) * 3])


## Scales an albedo's tone, per channel, so a wetter and cooler surface can be had without
## regenerating the artwork, then expands the contrast about 0.5 so the surface has range.
func _recolor(src: String, dst: String, gain: float, basis: Vector3, contrast: float) -> void:
	var s: Image = _gray(src)
	var w: int = s.get_width()
	var hh: int = s.get_height()
	var d: PackedByteArray = s.get_data()
	var o: PackedByteArray = PackedByteArray()
	o.resize(w * hh * 3)
	for i in range(w * hh):
		o[i * 3] = int(clampf(0.5 + (d[i * 3] / 255.0 * gain * basis.x - 0.5) * contrast,
			0.0, 1.0) * 255.0)
		o[i * 3 + 1] = int(clampf(0.5 + (d[i * 3 + 1] / 255.0 * gain * basis.y - 0.5) * contrast,
			0.0, 1.0) * 255.0)
		o[i * 3 + 2] = int(clampf(0.5 + (d[i * 3 + 2] / 255.0 * gain * basis.z - 0.5) * contrast,
			0.0, 1.0) * 255.0)
	_write(dst, w, hh, o)


func _write(path: String, w: int, h: int, rgb: PackedByteArray) -> void:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	img.set_data(w, h, false, Image.FORMAT_RGB8, rgb)
	img.save_png(path)
	print("wrote ", path)