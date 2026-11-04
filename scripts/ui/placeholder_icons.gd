## PlaceholderIcons
##
## Procedural 2D icon generator that builds and caches crisp [ImageTexture] icons
## for all 9 cultist towers, all 16 regular corporate units, the 5 corporate
## bosses, and the 5 factions.
## Used in BuildPalette, TowerPanel, IntelPanel, and BossBar.
class_name PlaceholderIcons
extends RefCounted

static var _tower_icon_cache: Dictionary = {}
static var _unit_icon_cache: Dictionary = {}
static var _faction_icon_cache: Dictionary = {}
static var _objective_icon_cache: Dictionary = {}


static func _draw_rect(img: Image, x0: int, y0: int, w: int, h: int, col: Color) -> void:
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	var sx: int = clampi(x0, 0, iw)
	var sy: int = clampi(y0, 0, ih)
	var ex: int = clampi(x0 + w, 0, iw)
	var ey: int = clampi(y0 + h, 0, ih)
	for y in range(sy, ey):
		for x in range(sx, ex):
			img.set_pixel(x, y, col)


static func _draw_circle(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	var r2: float = r * r
	var sx: int = clampi(floori(cx - r), 0, iw - 1)
	var ex: int = clampi(ceili(cx + r), 0, iw - 1)
	var sy: int = clampi(floori(cy - r), 0, ih - 1)
	var ey: int = clampi(ceili(cy + r), 0, ih - 1)
	for y in range(sy, ey + 1):
		var dy: float = float(y) - cy
		for x in range(sx, ex + 1):
			var dx: float = float(x) - cx
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, col)


static func _draw_ring(img: Image, cx: float, cy: float, r_in: float, r_out: float, col: Color) -> void:
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	var r_in2: float = r_in * r_in
	var r_out2: float = r_out * r_out
	var sx: int = clampi(floori(cx - r_out), 0, iw - 1)
	var ex: int = clampi(ceili(cx + r_out), 0, iw - 1)
	var sy: int = clampi(floori(cy - r_out), 0, ih - 1)
	var ey: int = clampi(ceili(cy + r_out), 0, ih - 1)
	for y in range(sy, ey + 1):
		var dy: float = float(y) - cy
		for x in range(sx, ex + 1):
			var dx: float = float(x) - cx
			var d2: float = dx * dx + dy * dy
			if d2 >= r_in2 and d2 <= r_out2:
				img.set_pixel(x, y, col)


static func _draw_line(img: Image, x0: float, y0: float, x1: float, y1: float, thickness: float, col: Color) -> void:
	var dist: float = Vector2(x0, y0).distance_to(Vector2(x1, y1))
	var steps: int = maxi(2, ceili(dist * 2.0))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var px: float = lerpf(x0, x1, t)
		var py: float = lerpf(y0, y1, t)
		_draw_circle(img, px, py, thickness * 0.5, col)


## Draws a closed outline through [param pts], joining the last vertex back to the first.
static func _poly_outline(img: Image, pts: PackedVector2Array, thickness: float, col: Color) -> void:
	for i in range(pts.size()):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		_draw_line(img, a.x, a.y, b.x, b.y, thickness, col)


## Vertices of a regular polygon centred on [param cx],[param cy], first vertex placed
## [param start_deg] clockwise from straight up.
static func _regular_polygon(
	cx: float, cy: float, r: float, sides: int, start_deg: float
) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a: float = deg_to_rad(start_deg + 360.0 * float(i) / float(sides))
		pts.append(Vector2(cx + r * cos(a), cy + r * sin(a)))
	return pts


## World-space marker glyph for an objective site KIND, drawn white on a transparent
## background. White on purpose: the marker is tinted per state at draw time, so one texture
## serves unclaimed / claimed / captured, and the SILHOUETTE is left free to tell the three
## site kinds apart at a glance.
static func objective_icon(kind_id: String) -> ImageTexture:
	if _objective_icon_cache.has(kind_id):
		return _objective_icon_cache[kind_id] as ImageTexture

	var size: int = 64
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 0.0))
	var c: float = float(size) * 0.5

	# Two passes: a dark halo, then the white glyph. The halo is what makes the marker readable
	# over BOTH the pale ground that dominates a zoomed-out view and the dark rooftops that
	# dominate a close-up -- a single-colour glyph vanishes against one or the other. The halo
	# survives state tinting, because a tint can only darken an already near-black outline.
	var halo := Color(0.05, 0.04, 0.08, 0.95)
	_draw_site_outline(img, kind_id, c, halo, 4.5)
	_draw_site_outline(img, kind_id, c, Color.WHITE, 0.0)
	_draw_site_detail(img, kind_id, c, Color.WHITE)

	var tex := ImageTexture.create_from_image(img)
	_objective_icon_cache[kind_id] = tex
	return tex


## The outer silhouette of a site glyph -- the shape that tells the three kinds apart. Drawn one
## level thicker when building the halo, so the dark backing tracks the silhouette exactly.
static func _draw_site_outline(
	img: Image, kind_id: String, c: float, col: Color, extra: float
) -> void:
	var t: float = 5.0 + extra
	match kind_id:
		"ley_line":
			_poly_outline(img, _regular_polygon(c, c, 26.0, 6, -90.0), t, col)
		"converted_data_center":
			_poly_outline(img, _regular_polygon(c, c, 25.0, 4, -45.0), t, col)
		"corruption_reservoir":
			_poly_outline(
				img,
				PackedVector2Array([
					Vector2(c, c - 27.0),
					Vector2(c + 24.0, c + 17.0),
					Vector2(c - 24.0, c + 17.0),
				]),
				t,
				col
			)
		_:
			# Unknown kind: still mark the site rather than drawing nothing at all.
			_draw_ring(img, c, c, 15.0 - extra * 0.5, 24.0 + extra * 0.5, col)


## Inner detail, drawn white only. A halo pass over these would smear them into a solid block
## and cost the glyph the very shape that makes it recognisable.
static func _draw_site_detail(img: Image, kind_id: String, c: float, col: Color) -> void:
	match kind_id:
		"ley_line":
			# A node of the ley network: a bright core inside the hexagon.
			_draw_circle(img, c, c, 7.0, col)
		"converted_data_center":
			# A server block: three drive slots inside the frame.
			for i in range(3):
				_draw_rect(img, int(c) - 11, int(c) - 11 + i * 8, 22, 5, col)
		"corruption_reservoir":
			# An alchemical vessel: it stands on a plinth.
			_draw_rect(img, int(c) - 12, int(c) + 20, 24, 5, col)
		_:
			pass


static func _draw_triangle(img: Image, p0: Vector2, p1: Vector2, p2: Vector2, col: Color) -> void:
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	var min_x: int = clampi(floori(minf(p0.x, minf(p1.x, p2.x))), 0, iw - 1)
	var max_x: int = clampi(ceili(maxf(p0.x, maxf(p1.x, p2.x))), 0, iw - 1)
	var min_y: int = clampi(floori(minf(p0.y, minf(p1.y, p2.y))), 0, ih - 1)
	var max_y: int = clampi(ceili(maxf(p0.y, maxf(p1.y, p2.y))), 0, ih - 1)
	var area: float = (p1.x - p0.x) * (p2.y - p0.y) - (p2.x - p0.x) * (p1.y - p0.y)
	if absf(area) < 0.001:
		return
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var pt := Vector2(float(x) + 0.5, float(y) + 0.5)
			var w0: float = ((p1.x - pt.x) * (p2.y - pt.y) - (p2.x - pt.x) * (p1.y - pt.y)) / area
			var w1: float = ((p2.x - pt.x) * (p0.y - pt.y) - (p0.x - pt.x) * (p2.y - pt.y)) / area
			var w2: float = 1.0 - w0 - w1
			if w0 >= -0.01 and w1 >= -0.01 and w2 >= -0.01:
				img.set_pixel(x, y, col)


static func _draw_frame(img: Image, border_col: Color, bg_col: Color) -> void:
	var s: int = img.get_width()
	_draw_rect(img, 0, 0, s, s, bg_col)
	_draw_rect(img, 0, 0, s, 2, border_col)
	_draw_rect(img, 0, s - 2, s, 2, border_col)
	_draw_rect(img, 0, 0, 2, s, border_col)
	_draw_rect(img, s - 2, 0, 2, s, border_col)


## Returns a cached [ImageTexture] icon for the given [param tower_id] at [param size]x[param size].
static func get_tower_icon(tower_id: String, size: int = 40) -> ImageTexture:
	var key: String = "%s_%d" % [tower_id, size]
	if _tower_icon_cache.has(key):
		return _tower_icon_cache[key] as ImageTexture

	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var f: float = float(size) / 40.0
	var bg := Color(0.10, 0.09, 0.14, 1.0)

	match tower_id:
		"hexed_nail_gun":
			var accent := Color(0.95, 0.72, 0.25)
			var hex_glow := Color(0.92, 0.35, 0.96)
			_draw_frame(img, accent, bg)
			# Tripod legs
			_draw_line(img, 20 * f, 24 * f, 10 * f, 35 * f, 3.0 * f, Color(0.45, 0.48, 0.54))
			_draw_line(img, 20 * f, 24 * f, 30 * f, 35 * f, 3.0 * f, Color(0.45, 0.48, 0.54))
			# Pneumatic gun body + angled barrel + hex coil + giant nail
			_draw_rect(img, roundi(10 * f), roundi(16 * f), roundi(16 * f), roundi(10 * f), accent)
			_draw_line(img, 22 * f, 18 * f, 35 * f, 10 * f, 4.0 * f, Color(0.65, 0.70, 0.76))
			_draw_ring(img, 28 * f, 14 * f, 2.5 * f, 5.5 * f, hex_glow)
			_draw_line(img, 31 * f, 12 * f, 37 * f, 8 * f, 2.5 * f, Color.WHITE)

		"chanting_choir":
			var psych := Color(0.88, 0.38, 0.96)
			_draw_frame(img, psych, bg)
			# 3 hooded cultist figures + floating psychic eye halo above
			for cx_u in [11.0, 20.0, 29.0]:
				var y_off: float = -2.0 if cx_u == 20.0 else 1.0
				_draw_triangle(
					img,
					Vector2(cx_u * f, (15.0 + y_off) * f),
					Vector2((cx_u - 5.5) * f, 35.0 * f),
					Vector2((cx_u + 5.5) * f, 35.0 * f),
					Color(0.46, 0.22, 0.64) if cx_u == 20.0 else Color(0.34, 0.16, 0.48)
				)
				_draw_circle(img, cx_u * f, (21.0 + y_off) * f, 2.2 * f, Color(0.12, 0.08, 0.16))
			_draw_ring(img, 20 * f, 9 * f, 3.5 * f, 6.0 * f, psych)
			_draw_circle(img, 20 * f, 9 * f, 2.0 * f, Color.WHITE)

		"gutter_ritual_circle":
			var acid := Color(0.42, 0.95, 0.28)
			_draw_frame(img, acid, bg)
			# Outer occult circle + corrosive pool + 6 candle flames
			_draw_circle(img, 20 * f, 22 * f, 13 * f, Color(0.16, 0.42, 0.16))
			_draw_ring(img, 20 * f, 22 * f, 11 * f, 14 * f, acid)
			_draw_ring(img, 20 * f, 22 * f, 5 * f, 7 * f, acid)
			for i in range(6):
				var ang: float = float(i) * TAU / 6.0 - PI * 0.5
				var px: float = 20.0 + cos(ang) * 13.0
				var py: float = 22.0 + sin(ang) * 13.0
				_draw_circle(img, px * f, py * f, 2.4 * f, Color(1.0, 0.92, 0.40))

		"tentacle_storm_drain":
			var teal := Color(0.22, 0.85, 0.76)
			_draw_frame(img, teal, bg)
			# Sewer grate bars at bottom + 3 curving tentacles rising up
			_draw_rect(img, roundi(6 * f), roundi(28 * f), roundi(28 * f), roundi(7 * f), Color(0.32, 0.36, 0.40))
			for gx in [11, 17, 23, 29]:
				_draw_rect(img, roundi(gx * f), roundi(28 * f), roundi(2 * f), roundi(7 * f), Color(0.12, 0.16, 0.20))
			_draw_line(img, 12 * f, 28 * f, 8 * f, 11 * f, 4.0 * f, teal)
			_draw_line(img, 8 * f, 11 * f, 13 * f, 7 * f, 3.0 * f, Color(0.65, 1.0, 0.92))
			_draw_line(img, 20 * f, 28 * f, 21 * f, 8 * f, 4.5 * f, teal)
			_draw_line(img, 21 * f, 8 * f, 16 * f, 5 * f, 3.0 * f, Color(0.65, 1.0, 0.92))
			_draw_line(img, 28 * f, 28 * f, 32 * f, 12 * f, 4.0 * f, teal)
			_draw_line(img, 32 * f, 12 * f, 27 * f, 8 * f, 3.0 * f, Color(0.65, 1.0, 0.92))

		"watcher_in_the_billboard":
			var void_col := Color(0.68, 0.28, 0.98)
			_draw_frame(img, void_col, bg)
			# Billboard struts + wide sign frame + giant eldritch vertical-slit eye
			_draw_rect(img, roundi(11 * f), roundi(24 * f), roundi(3 * f), roundi(12 * f), Color(0.45, 0.48, 0.54))
			_draw_rect(img, roundi(26 * f), roundi(24 * f), roundi(3 * f), roundi(12 * f), Color(0.45, 0.48, 0.54))
			_draw_rect(img, roundi(5 * f), roundi(8 * f), roundi(30 * f), roundi(18 * f), Color(0.26, 0.20, 0.36))
			_draw_circle(img, 20 * f, 17 * f, 7.5 * f, Color(0.94, 0.90, 0.98))
			_draw_circle(img, 20 * f, 17 * f, 5.0 * f, void_col)
			_draw_rect(img, roundi(19 * f), roundi(12 * f), roundi(2 * f), roundi(10 * f), Color(0.05, 0.02, 0.08))

		"rust_censer":
			var rust := Color(0.86, 0.52, 0.22)
			var fume := Color(0.48, 0.96, 0.32)
			_draw_frame(img, rust, bg)
			# Gallows chain + swinging spiked censer + green corrosive fume clouds
			_draw_line(img, 20 * f, 4 * f, 20 * f, 16 * f, 2.5 * f, Color(0.55, 0.58, 0.62))
			_draw_circle(img, 20 * f, 23 * f, 8.0 * f, rust)
			_draw_rect(img, roundi(11 * f), roundi(21 * f), roundi(18 * f), roundi(4 * f), Color(0.45, 0.28, 0.16))
			_draw_triangle(img, Vector2(16 * f, 29 * f), Vector2(24 * f, 29 * f), Vector2(20 * f, 36 * f), rust)
			_draw_circle(img, 11 * f, 14 * f, 3.5 * f, fume)
			_draw_circle(img, 29 * f, 13 * f, 4.0 * f, fume)
			_draw_circle(img, 20 * f, 23 * f, 3.2 * f, fume)

		"fever_shrine":
			var crimson := Color(0.98, 0.36, 0.42)
			var flame := Color(1.0, 0.84, 0.28)
			_draw_frame(img, crimson, bg)
			# Altar steps + 3 tall candles with bright fever flames
			_draw_rect(img, roundi(6 * f), roundi(29 * f), roundi(28 * f), roundi(6 * f), Color(0.52, 0.16, 0.24))
			_draw_rect(img, roundi(10 * f), roundi(24 * f), roundi(20 * f), roundi(5 * f), crimson)
			for cx_c in [12, 20, 28]:
				var ch: int = 12 if cx_c == 20 else 9
				var cy_top: int = 24 - ch
				_draw_rect(img, roundi((cx_c - 2) * f), roundi(cy_top * f), roundi(4 * f), roundi(ch * f), Color(0.92, 0.88, 0.80))
				_draw_triangle(
					img,
					Vector2(cx_c * f, (cy_top - 7) * f),
					Vector2((cx_c - 3) * f, cy_top * f),
					Vector2((cx_c + 3) * f, cy_top * f),
					flame
				)

		"the_congregation":
			var lav := Color(0.76, 0.62, 0.96)
			_draw_frame(img, lav, bg)
			# Twin banners + central pulpit + blocker shield emblem
			_draw_rect(img, roundi(7 * f), roundi(8 * f), roundi(6 * f), roundi(24 * f), Color(0.42, 0.24, 0.62))
			_draw_rect(img, roundi(27 * f), roundi(8 * f), roundi(6 * f), roundi(24 * f), Color(0.42, 0.24, 0.62))
			_draw_rect(img, roundi(14 * f), roundi(18 * f), roundi(12 * f), roundi(16 * f), lav)
			_draw_triangle(img, Vector2(14 * f, 34 * f), Vector2(26 * f, 34 * f), Vector2(20 * f, 38 * f), lav)
			_draw_rect(img, roundi(18 * f), roundi(21 * f), roundi(4 * f), roundi(10 * f), Color(0.22, 0.14, 0.32))

		"tithe_box":
			var gold := Color(0.98, 0.84, 0.24)
			_draw_frame(img, gold, bg)
			# Strongbox chest + coin slot + glowing gold coin dropping in
			_draw_rect(img, roundi(8 * f), roundi(19 * f), roundi(24 * f), roundi(15 * f), Color(0.46, 0.30, 0.18))
			_draw_rect(img, roundi(8 * f), roundi(19 * f), roundi(24 * f), roundi(4 * f), gold)
			_draw_rect(img, roundi(17 * f), roundi(22 * f), roundi(6 * f), roundi(7 * f), gold)
			_draw_circle(img, 20 * f, 11 * f, 5.5 * f, gold)
			_draw_circle(img, 20 * f, 11 * f, 3.0 * f, Color(1.0, 0.96, 0.65))

		"substation_effigy":
			var arc := Color(0.28, 0.88, 1.0)
			_draw_frame(img, arc, bg)
			# Transformer base + cross-arm insulators + stepped Tesla coil + jagged lightning forks
			_draw_rect(img, roundi(13 * f), roundi(24 * f), roundi(14 * f), roundi(11 * f), Color(0.38, 0.42, 0.48))
			_draw_rect(img, roundi(8 * f), roundi(20 * f), roundi(24 * f), roundi(3 * f), Color(0.46, 0.32, 0.20))
			_draw_rect(img, roundi(17 * f), roundi(11 * f), roundi(6 * f), roundi(14 * f), Color(0.76, 0.48, 0.24))
			for cy_r in [14, 18]:
				_draw_rect(img, roundi(14 * f), roundi(cy_r * f), roundi(12 * f), roundi(2 * f), arc)
			_draw_circle(img, 20 * f, 9 * f, 4.2 * f, arc)
			_draw_circle(img, 20 * f, 9 * f, 2.2 * f, Color.WHITE)
			# Left & right lightning forks
			_draw_line(img, 17 * f, 9 * f, 9 * f, 13 * f, 2.2 * f, Color.WHITE)
			_draw_line(img, 9 * f, 13 * f, 6 * f, 8 * f, 2.0 * f, arc)
			_draw_line(img, 23 * f, 9 * f, 31 * f, 13 * f, 2.2 * f, Color.WHITE)
			_draw_line(img, 31 * f, 13 * f, 34 * f, 8 * f, 2.0 * f, arc)

		_:
			var fallback_col := Color(0.65, 0.82, 1.0)
			_draw_frame(img, fallback_col, bg)
			_draw_rect(img, roundi(12 * f), roundi(14 * f), roundi(16 * f), roundi(20 * f), fallback_col)
			_draw_circle(img, 20 * f, 12 * f, 5.0 * f, Color.WHITE)

	var tex := ImageTexture.create_from_image(img)
	_tower_icon_cache[key] = tex
	return tex


## Returns a cached [ImageTexture] icon for a faction ID.
static func get_faction_icon(faction_id: String, size: int = 32) -> ImageTexture:
	var key: String = "%s_%d" % [faction_id, size]
	if _faction_icon_cache.has(key):
		return _faction_icon_cache[key] as ImageTexture

	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var f: float = float(size) / 32.0
	var bg := Color(0.08, 0.09, 0.13, 1.0)

	match faction_id:
		"swarm_syndicate":
			var col := Color(0.98, 0.78, 0.18)
			_draw_frame(img, col, bg)
			# Lightning bolt / gig-hive chevron
			_draw_triangle(img, Vector2(18 * f, 4 * f), Vector2(8 * f, 18 * f), Vector2(17 * f, 18 * f), col)
			_draw_triangle(img, Vector2(15 * f, 14 * f), Vector2(24 * f, 14 * f), Vector2(14 * f, 28 * f), col)

		"iron_board":
			var col := Color(0.56, 0.68, 0.82)
			_draw_frame(img, col, bg)
			# Heavy corporate shield crest
			_draw_rect(img, roundi(8 * f), roundi(6 * f), roundi(16 * f), roundi(12 * f), col)
			_draw_triangle(img, Vector2(8 * f, 18 * f), Vector2(24 * f, 18 * f), Vector2(16 * f, 28 * f), col)
			_draw_rect(img, roundi(14 * f), roundi(9 * f), roundi(4 * f), roundi(12 * f), bg)

		"hostile_takeover":
			var col := Color(0.92, 0.22, 0.48)
			_draw_frame(img, col, bg)
			# Crosshair / hostile acquisition target arrow
			_draw_ring(img, 16 * f, 16 * f, 6 * f, 9 * f, col)
			_draw_circle(img, 16 * f, 16 * f, 2.5 * f, Color(0.25, 0.92, 1.0))
			_draw_rect(img, roundi(15 * f), roundi(4 * f), roundi(2 * f), roundi(24 * f), col)
			_draw_rect(img, roundi(4 * f), roundi(15 * f), roundi(24 * f), roundi(2 * f), col)

		"skyline_logistics":
			var col := Color(0.22, 0.82, 0.96)
			_draw_frame(img, col, bg)
			# Winged air delta chevron
			_draw_triangle(img, Vector2(16 * f, 6 * f), Vector2(4 * f, 24 * f), Vector2(16 * f, 18 * f), col)
			_draw_triangle(img, Vector2(16 * f, 6 * f), Vector2(28 * f, 24 * f), Vector2(16 * f, 18 * f), col.lightened(0.2))

		_:
			# Coalition (4-color diamond)
			var col := Color(0.90, 0.90, 0.96)
			_draw_frame(img, col, bg)
			_draw_rect(img, roundi(7 * f), roundi(7 * f), roundi(8 * f), roundi(8 * f), Color(0.98, 0.78, 0.18))
			_draw_rect(img, roundi(17 * f), roundi(7 * f), roundi(8 * f), roundi(8 * f), Color(0.56, 0.68, 0.82))
			_draw_rect(img, roundi(7 * f), roundi(17 * f), roundi(8 * f), roundi(8 * f), Color(0.92, 0.22, 0.48))
			_draw_rect(img, roundi(17 * f), roundi(17 * f), roundi(8 * f), roundi(8 * f), Color(0.22, 0.82, 0.96))

	var tex := ImageTexture.create_from_image(img)
	_faction_icon_cache[key] = tex
	return tex


## Returns a cached [ImageTexture] icon for a unit or boss ID.
static func get_unit_icon(unit_id: String, faction_id: String = "swarm_syndicate", size: int = 36) -> ImageTexture:
	var key: String = "%s_%s_%d" % [unit_id, faction_id, size]
	if _unit_icon_cache.has(key):
		return _unit_icon_cache[key] as ImageTexture

	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var f: float = float(size) / 36.0
	var bg := Color(0.08, 0.09, 0.13, 1.0)
	var fac_col := Color(0.98, 0.78, 0.18)
	match faction_id:
		"iron_board":
			fac_col = Color(0.56, 0.68, 0.82)
		"hostile_takeover":
			fac_col = Color(0.92, 0.22, 0.48)
		"skyline_logistics":
			fac_col = Color(0.22, 0.82, 0.96)
		"coalition":
			fac_col = Color(0.90, 0.90, 0.96)

	_draw_frame(img, fac_col, bg)
	var cyan := Color(0.25, 0.95, 1.0)

	match unit_id:
		"gig_runner":
			_draw_circle(img, 14 * f, 12 * f, 4 * f, fac_col)
			_draw_rect(img, roundi(11 * f), roundi(17 * f), roundi(7 * f), roundi(12 * f), fac_col)
			_draw_rect(img, roundi(19 * f), roundi(14 * f), roundi(10 * f), roundi(12 * f), fac_col.lightened(0.25))
		"scooter_courier":
			_draw_circle(img, 10 * f, 27 * f, 4 * f, Color(0.6, 0.65, 0.7))
			_draw_circle(img, 26 * f, 27 * f, 4 * f, Color(0.6, 0.65, 0.7))
			_draw_rect(img, roundi(10 * f), roundi(24 * f), roundi(16 * f), roundi(3 * f), fac_col)
			_draw_line(img, 11 * f, 24 * f, 13 * f, 10 * f, 2.5 * f, cyan)
		"hype_influencer":
			_draw_ring(img, 18 * f, 16 * f, 8 * f, 11 * f, Color(1.0, 0.3, 0.7))
			_draw_circle(img, 18 * f, 16 * f, 4.5 * f, fac_col)
			_draw_rect(img, roundi(13 * f), roundi(22 * f), roundi(10 * f), roundi(9 * f), fac_col)
		"gig_van":
			_draw_rect(img, roundi(6 * f), roundi(12 * f), roundi(18 * f), roundi(13 * f), fac_col)
			_draw_rect(img, roundi(24 * f), roundi(16 * f), roundi(6 * f), roundi(9 * f), cyan)
			_draw_circle(img, 11 * f, 27 * f, 3.5 * f, Color.WHITE)
			_draw_circle(img, 24 * f, 27 * f, 3.5 * f, Color.WHITE)
		"security_contractor":
			_draw_circle(img, 18 * f, 11 * f, 4.5 * f, fac_col)
			_draw_rect(img, roundi(14 * f), roundi(10 * f), roundi(8 * f), roundi(3 * f), cyan)
			_draw_rect(img, roundi(10 * f), roundi(17 * f), roundi(16 * f), roundi(13 * f), fac_col)
		"riot_shield_unit":
			_draw_rect(img, roundi(8 * f), roundi(7 * f), roundi(12 * f), roundi(22 * f), cyan)
			_draw_rect(img, roundi(10 * f), roundi(10 * f), roundi(8 * f), roundi(4 * f), bg)
			_draw_circle(img, 24 * f, 14 * f, 4.5 * f, fac_col)
		"siege_walker":
			_draw_circle(img, 18 * f, 16 * f, 6 * f, fac_col)
			_draw_line(img, 14 * f, 18 * f, 7 * f, 29 * f, 2.5 * f, fac_col)
			_draw_line(img, 22 * f, 18 * f, 29 * f, 29 * f, 2.5 * f, fac_col)
			_draw_rect(img, roundi(6 * f), roundi(14 * f), roundi(10 * f), roundi(3 * f), cyan)
		"sponsor_mech":
			_draw_rect(img, roundi(10 * f), roundi(6 * f), roundi(16 * f), roundi(6 * f), Color(1.0, 0.82, 0.22))
			_draw_rect(img, roundi(9 * f), roundi(13 * f), roundi(18 * f), roundi(12 * f), fac_col)
			_draw_rect(img, roundi(11 * f), roundi(25 * f), roundi(5 * f), roundi(6 * f), fac_col)
			_draw_rect(img, roundi(20 * f), roundi(25 * f), roundi(5 * f), roundi(6 * f), fac_col)
		"taser_skirmisher":
			_draw_circle(img, 18 * f, 18 * f, 6 * f, fac_col)
			_draw_line(img, 8 * f, 10 * f, 28 * f, 26 * f, 2.5 * f, cyan)
			_draw_line(img, 28 * f, 10 * f, 8 * f, 26 * f, 2.5 * f, cyan)
		"ghost_contractor":
			_draw_triangle(img, Vector2(18 * f, 6 * f), Vector2(8 * f, 29 * f), Vector2(28 * f, 29 * f), fac_col)
			_draw_circle(img, 15 * f, 15 * f, 2.0 * f, Color(0.25, 0.98, 0.48))
			_draw_circle(img, 21 * f, 15 * f, 2.0 * f, Color(0.25, 0.98, 0.48))
		"compliance_officer":
			_draw_ring(img, 18 * f, 14 * f, 5 * f, 8 * f, cyan)
			_draw_rect(img, roundi(16 * f), roundi(20 * f), roundi(4 * f), roundi(11 * f), fac_col)
		"acquisitions_rep":
			_draw_rect(img, roundi(8 * f), roundi(14 * f), roundi(20 * f), roundi(14 * f), fac_col)
			_draw_rect(img, roundi(11 * f), roundi(17 * f), roundi(14 * f), roundi(8 * f), cyan)
		"courier_drone":
			_draw_line(img, 8 * f, 8 * f, 28 * f, 28 * f, 2.5 * f, fac_col)
			_draw_line(img, 28 * f, 8 * f, 8 * f, 28 * f, 2.5 * f, fac_col)
			_draw_rect(img, roundi(14 * f), roundi(14 * f), roundi(8 * f), roundi(8 * f), Color(0.98, 0.82, 0.22))
		"cargo_hauler":
			_draw_circle(img, 9 * f, 16 * f, 4.5 * f, cyan)
			_draw_circle(img, 27 * f, 16 * f, 4.5 * f, cyan)
			_draw_rect(img, roundi(11 * f), roundi(13 * f), roundi(14 * f), roundi(12 * f), fac_col)
		"medic_drone":
			_draw_circle(img, 18 * f, 18 * f, 10 * f, Color(0.92, 0.96, 1.0))
			_draw_rect(img, roundi(16 * f), roundi(11 * f), roundi(4 * f), roundi(14 * f), Color(0.20, 0.92, 0.45))
			_draw_rect(img, roundi(11 * f), roundi(16 * f), roundi(14 * f), roundi(4 * f), Color(0.20, 0.92, 0.45))
		"drone_carrier":
			_draw_triangle(img, Vector2(18 * f, 6 * f), Vector2(5 * f, 28 * f), Vector2(31 * f, 28 * f), fac_col)
			_draw_rect(img, roundi(16 * f), roundi(10 * f), roundi(4 * f), roundi(16 * f), cyan)
		_:
			# Bosses (crowned icon)
			_draw_triangle(img, Vector2(7 * f, 26 * f), Vector2(11 * f, 10 * f), Vector2(18 * f, 26 * f), fac_col)
			_draw_triangle(img, Vector2(12 * f, 26 * f), Vector2(18 * f, 7 * f), Vector2(24 * f, 26 * f), Color(1.0, 0.85, 0.25))
			_draw_triangle(img, Vector2(18 * f, 26 * f), Vector2(25 * f, 10 * f), Vector2(29 * f, 26 * f), fac_col)
			_draw_rect(img, roundi(7 * f), roundi(25 * f), roundi(22 * f), roundi(5 * f), fac_col)

	var tex := ImageTexture.create_from_image(img)
	_unit_icon_cache[key] = tex
	return tex
