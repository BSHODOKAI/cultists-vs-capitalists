"""Builds the Cult Sanctum COMPOUND - the 3-hex (6 reserved hex) version.

Rewritten after a design review found the first version leaning MEDIEVAL. It had a curtain wall of
staggered ashlar courses, two-step coping stones, buttresses, corner piers with carved caps, and a
gatehouse of posts and a lintel. That vocabulary is wrong for this game, and DESIGN_BIBLE.md says so
plainly:

  * Pillar A is *salvaged things made sacred* - storm drains, billboards, propane tanks,
    hardware-store nail guns. It should feel like improvising.
  * Section 7: don't give the cult clean, mass-produced or military-grade hardware; the cult has no
    supply chain.
  * Section 6: a viewer must be able to tell a cultist thing from a corporate thing by silhouette
    alone - jagged/handmade versus sleek/branded.

A castle is none of those things; castle forms read as a *different genre* from the collision of
occult scrappiness and corporate cyberpunk this game is about. The approved concept art had the right
vocabulary all along: concrete, steel pipe, chain-link, tarps, a striped hazard barrier, a junction
box, cables, spray paint, caged lamps.

THE VOCABULARY SWAP
    curtain wall of ashlar      -> low board-formed concrete parapet
    two-step coping stones      -> galvanised steel pipe railing
    buttresses                  -> steel pipe stanchions and diagonal braces
    corner piers with caps      -> bare poured-concrete monoliths, no cap, no detail
    gatehouse posts and lintel  -> a cracked illuminated sign box on a steel frame, plus a turnstile
    flagstone paving            -> concrete deck slabs, wet in patches
    grey masonry, moss          -> concrete, rust, teal tile, red and violet spray paint

The single most important rendering change is not a texture: it is that CONCRETE IS CRISP. Chipped,
jittered blocks read as masonry; cast concrete has straight edges and a flat face. Every concrete
element here is a plain box, and the only irregularity is in the stain and the spray paint.

Layout decisions carried over unchanged:
  * PLATFORM IS THE EXACT 7-HEX UNION - seven hex prisms of radius ~1.005 at the seven hex centres.
    A single hexagon of radius 2.75 under-covers the union by 0.22 at the edge midpoints.
  * The model covers all seven hexes including the path-exit hex; a road running out from under the
    gate reads correctly, and that hex is where units reach the base and leak anyway.
  * LOW AND WIDE. HexMath.TOWER_MAX_HEIGHT = 1.5; the tallest element tops out near 1.36.
  * Blender +Y maps to Godot -Z, so "toward the fixed camera" is the Blender -Y quadrant, which is
    the 300 deg EDGE of a pointy-top hex. The gate sits there and is NOT rotated per-seed: the
    camera never rotates, so a fixed rotation is what guarantees the gate is actually seen.
  * The shaft is a shallow stair whose floor stays ABOVE z=0, since the model sits on the terrain.

Run inside Blender via the Ziva `blender` tool:
    exec(compile(open('.../sources/build_sanctum_compound.py').read(), 'build_compound', 'exec'))
"""

import bpy
import bmesh
import math
import random

from mathutils import Vector

A = 'C:/Users/bshod/Documents/cultists-vs-capitalists/graphics_generation/sanctum/assets/'
OUT = A + 'sanctum_compound.glb'
T = math.radians
# The platform's TOP, in Blender Z.
#
# TOWER_MAX_HEIGHT (1.5) is measured from z=0 UP. z=0 is sea level -- the floor of the hexes -- and
# anything BELOW it is depth, not height, and is not counted against the cap. So a pit may go as deep
# as the model needs without costing a millimetre of the structure above. That is why the plinth is
# back to a modest 0.34: depth does not have to be bought with height, it gets dug. See SHAFT_FLOOR.
PLAT = 0.34
FLOOR = PLAT + .018   # top of the deck
BUILD_SEED = 20261104
# World size covered by one texture tile under cube-projected UVs.
#
# 0.55 was about 3x too small, and it is the reason the surfaces read as untextured at gameplay zoom.
# At 0.55 a surface carries ~930 texels per world unit while gameplay zoom is ~36 screen px per world
# unit, so the texture is minified by ~26x and mip-mapped into a flat wash: only its very broadest
# features survive. The board-form courses in tex_concrete are ~85 px of a 512 map, i.e. 0.09 world
# units at this setting, against the ~0.25-world-unit block scale the concept art shows. Arbitrary
# tiling is not the fix here -- the texture's FEATURES have to land at the concept's feature size.
# Measured, not guessed: at 1.5 one course lands at 0.25 units and one tile-grid cell at ~0.2, both of
# which read at gameplay zoom while the close-up stays crisp. Confirmed by capture.
UV_TILE = 1.50
HEX_R = 1.005         # platform prism radius; 7 of these tile the 7-hex footprint
WALL_APOTHEM = 2.40
WALL_R = WALL_APOTHEM / math.cos(T(30))
GATE_ANG = 300        # the hex EDGE the fixed camera faces
rng = random.Random(BUILD_SEED)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for coll in (bpy.data.curves, bpy.data.meshes, bpy.data.materials):
    for b in list(coll):
        coll.remove(b)


# --- Materials ---------------------------------------------------------------------------------

def texmat(name, image, rough, metal=0.0, mr=None, nrm=None, emissive=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes.get('Principled BSDF')
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = bpy.data.images.load(A + image)
    t.location = (-420, 120)
    nt.links.new(t.outputs['Color'], p.inputs['Base Color'])
    if emissive > 0.0:
        # Emission takes the SAME image, so a backlit panel keeps its texture instead of going flat.
        # This is why the sign face was the last flat surface with real area: `texmat` had no emissive
        # path, so anything that glowed had to be `flat()`. glTF exports this as an emissive texture
        # plus KHR_materials_emissive_strength, and Godot reads both.
        nt.links.new(t.outputs['Color'], p.inputs['Emission Color'])
        p.inputs['Emission Strength'].default_value = emissive
    nimg = bpy.data.images.load(A + (nrm if nrm is not None else image.replace('.png', '_n.png')))
    nimg.colorspace_settings.name = 'Non-Color'
    tn = nt.nodes.new('ShaderNodeTexImage')
    tn.image = nimg
    tn.location = (-420, -260)
    nm = nt.nodes.new('ShaderNodeNormalMap')
    nm.location = (-140, -260)
    nm.inputs['Strength'].default_value = 1.0
    nt.links.new(tn.outputs['Color'], nm.inputs['Color'])
    nt.links.new(nm.outputs['Normal'], p.inputs['Normal'])
    if mr is not None:
        pack = bpy.data.images.load(A + mr)
        pack.colorspace_settings.name = 'Non-Color'
        tp = nt.nodes.new('ShaderNodeTexImage')
        tp.image = pack
        tp.location = (-420, -620)
        nt.links.new(tp.outputs['Color'], p.inputs['Roughness'])
        nt.links.new(tp.outputs['Color'], p.inputs['Metallic'])
    return m


def flat(name, color, rough=.8, metal=0.0, emissive=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    if emissive > 0.0:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = emissive
    return m


def decalmat(name, image):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.blend_method = 'BLEND'
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Roughness'].default_value = .9
    t = m.node_tree.nodes.new('ShaderNodeTexImage')
    t.image = bpy.data.images.load(A + image)
    m.node_tree.links.new(t.outputs['Color'], p.inputs['Base Color'])
    m.node_tree.links.new(t.outputs['Alpha'], p.inputs['Alpha'])
    return m


def tintmat(name, image, color, rough=.88):
    """A decal in a flat colour, keyed off the image's ALPHA only.

    The spray sigils are the same glyph the cult has always used (`decal_sigil_stone.png`, an eye with
    rays over tally strokes) - the cult does not own a second kind of paint. Carrying the colour in
    the material rather than in a second PNG is what lets one glyph be sprayed red on one wall and
    violet on another, which is exactly how it reads in the concept art."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.blend_method = 'BLEND'
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    t = m.node_tree.nodes.new('ShaderNodeTexImage')
    t.image = bpy.data.images.load(A + image)
    m.node_tree.links.new(t.outputs['Alpha'], p.inputs['Alpha'])
    return m


concrete = texmat('Board-formed concrete', 'tex_concrete.png', .90, mr='mr_concrete.png')
tile = texmat('Subway tile', 'tex_tile.png', .30, mr='mr_tile.png')
roof = texmat('Rusted sheet', 'tex_rusted_corrugated.png', .72, .22, mr='mr_corrugated.png')
canvas = texmat('Salvaged canvas', 'tex_torn_canvas.png', .92, mr='mr_canvas.png')
pipe = texmat('Salvaged steel', 'tex_pipe_steel.png', .55, .10, mr='mr_pipe_steel.png')
wood = texmat('Salvaged timber', 'tex_old_wood.png', .80, mr='mr_wood.png')
# The railing fence -- the first of the accent materials to get a real texture. It was `brass`, a FLAT
# colour, and a flat colour on a 42mm pipe is a strip of smooth yellow plastic at close range: no grain
# for the light to break on and no wear to say what it is made of. This is weathered yellow paint over
# galvanised steel, chipped back to the metal in patches with rust bleed and drip streaks, derived
# through the same pipeline as the concrete and tile.
#
# Metallic 0.10, on purpose. main.tscn has a flat colour background and no reflection probe, so a
# strongly metallic surface has nothing to reflect and renders BLACK. Painted steel is a dielectric
# surface anyway; only the exposed chips are real metal.
fence_steel = texmat('Painted fence steel', 'tex_fence_yellow.png', .55, .10, mr='mr_fence_yellow.png')

sig_red = tintmat('Sprayed sigil red', 'decal_sigil_stone.png', (.58, .065, .055))
sig_violet = tintmat('Sprayed sigil violet', 'decal_sigil_stone.png', (.42, .10, .56))
# Wet reads as a translucent DARKENING, so these colours must sit BELOW the concrete they land on.
# The concrete's albedo measures ~0.04-0.10 in linear terms; the first attempt used 0.088-0.115,
# which is LIGHTER than the surface. The "damp" decals were therefore painting pale patches onto dark
# concrete - the exact opposite of damp, and the source of the pale marks in capture. Measured.
wet_m = tintmat('Wet patch', 'decal_grime.png', (.028, .030, .033), .35)

dark = flat('Below', (.012, .008, .016))
wax = texmat('Candle wax', 'tex_wax.png', .62, mr='mr_wax.png')
flame = flat('Flame', (1, .62, .18), .5, 0, 4.0)
glow = flat('Lantern light', (1, .58, .20), .5, 0, 6.0)
sign_glow = texmat('Sign face', 'tex_paint_white.png', .30, 0.0, mr='mr_paint_white.png',
                   emissive=0.22)
sign_steel = texmat('Sign enclosure', 'tex_dark_metal.png', .50, .10, mr='mr_dark_metal.png')
concrete_dark = texmat('Concrete in shadow', 'tex_dark_concrete.png', .80, mr='mr_dark_concrete.png')
red = texmat('Hazard red', 'tex_hazard_red.png', .70, mr='mr_hazard_red.png')
white = texmat('Hazard white', 'tex_paint_white.png', .75, mr='mr_paint_white.png')
propane = texmat('Propane bottle', 'tex_hazard_red.png', .70, mr='mr_hazard_red.png')
steel_pale = texmat('Galvanised', 'tex_metal_galv.png', .55, .10, mr='mr_metal_galv.png')
# The palette the concepts are actually built on: warm brass pipework against oxidised teal iron.
# Metallic stays LOW on purpose - the environment has no sky and no reflection source, so a
# high-metallic brass renders as grey wax rather than metal. The warmth has to come from the albedo.
brass = texmat('Aged brass', 'tex_aged_brass.png', .42, .10, mr='mr_aged_brass.png')
teal_iron = texmat('Oxidised iron', 'tex_teal_iron.png', .55, .10, mr='mr_teal_iron.png')
rust_plate = texmat('Rusted plate', 'tex_rust_plate.png', .85, .10, mr='mr_rust_plate.png')
tin = texmat('Tin can', 'tex_metal_galv.png', .55, .10, mr='mr_metal_galv.png')
bone = texmat('Offering', 'tex_bone.png', .80, mr='mr_bone.png')
tarp = texmat('Tarpaulin', 'tex_tarp_green.png', .85, mr='mr_tarp_green.png')
rust_streak = flat('Rust stain', (.24, .11, .055), .88)
streak_m = tintmat('Grime streak', 'decal_grime.png', (.015, .016, .018), .62)
damp_m = tintmat('Damp', 'decal_grime.png', (.020, .021, .023), .48)
rock = texmat('Rubble', 'tex_dark_concrete.png', .80, mr='mr_dark_concrete.png')
tent = flat('Something under', (.075, .05, .09), .6)

objs = []
decals = []


# --- Geometry helpers --------------------------------------------------------------------------

def chamfer(o, width=.010):
    dims = o.dimensions
    smallest = min(abs(dims.x), abs(dims.y), abs(dims.z))
    w = min(width, smallest * 0.25)
    if w < 0.0012:
        return
    md = o.modifiers.new('Edge chamfer', 'BEVEL')
    md.width = w
    md.segments = 2
    md.limit_method = 'ANGLE'
    md.angle_limit = T(32)


def box(name, pos, dims, mat, rx=0, ry=0, rz=0, keep=True, bev=True):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o = bpy.context.object
    o.name = name
    o.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.rotation_euler = (rx, ry, rz)
    o.data.materials.append(mat)
    if bev:
        chamfer(o)
    (objs if keep else decals).append(o)
    return o


def cyl(name, pos, r, h, mat, rx=0, ry=0, rz=0, v=16, keep=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=v, radius=r, depth=h, location=pos)
    o = bpy.context.object
    o.name = name
    o.rotation_euler = (rx, ry, rz)
    o.data.materials.append(mat)
    chamfer(o, .006)
    (objs if keep else decals).append(o)
    return o


def ball(name, pos, r, mat, squash=1.0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=pos)
    o = bpy.context.object
    o.name = name
    o.scale.z = squash
    o.data.materials.append(mat)
    objs.append(o)
    return o


def ring(name, pos, major, minor, mat, rx=0, ry=0, rz=0):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=pos,
                                     rotation=(rx, ry, rz), major_segments=20, minor_segments=8)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat)
    objs.append(o)
    return o


def tube(name, pts, r, mat):
    c = bpy.data.curves.new(name, 'CURVE')
    c.dimensions = '3D'
    c.bevel_depth = r
    c.bevel_resolution = 3
    s = c.splines.new('BEZIER')
    s.bezier_points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        bp = s.bezier_points[i]
        bp.co = Vector(p)
        bp.handle_left_type = bp.handle_right_type = 'AUTO'
    o = bpy.data.objects.new(name, c)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    objs.append(o)
    return o


def _plane(name, pos, sx, sy, mat):
    """A single quad carrying the DEFAULT unit-square UVs, which is what a decal needs.

    Built from a plane primitive rather than a thin box on purpose: a cube's default UVs are the
    classic cross layout, so a decal mapped onto one face of a cube shows a corner of the texture
    instead of the whole glyph. These are also kept out of the joined mesh so the world-space cube
    projection applied to that mesh cannot stomp their UVs, and they are selected for export
    explicitly - a decal that never reaches the GLB is a decal that does not exist."""
    bpy.ops.mesh.primitive_plane_add(size=1, location=pos)
    o = bpy.context.object
    o.name = name
    o.scale = (sx, sy, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    decals.append(o)
    return o


def decal_flat(name, pos, size, mat, aspect=1.0):
    """A decal lying flat on the deck."""
    return _plane(name, pos, size, size * aspect, mat)


def decal_at(name, pos, size, mat, ang, aspect=1.0):
    """A decal standing up, facing the horizontal direction `ang`."""
    o = _plane(name, pos, size, size * aspect, mat)
    # ang is normalised into 0..360 FIRST. Callers pass things like `sang + 180` and `gcam + 180`,
    # which for a 330-degree edge is 510: an euler of 510 degrees is geometrically identical to 150,
    # but it is not worth betting a decal's orientation on a renderer agreeing about that.
    o.rotation_euler = (T(-90), 0, T((ang % 360.0) - 90))
    return o


def chipped(name, pos, dims, mat, rx=0, ry=0, rz=0, jitter=.12, rounded=False, bevel_w=.010):
    o = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    bpy.context.collection.objects.link(o)
    bm = bmesh.new()
    if rounded:
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.5)
    else:
        bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(dims), verts=bm.verts)
    step = (max(dims) * 0.5 if rounded else min(dims)) * jitter
    for v in bm.verts:
        v.co += Vector((rng.uniform(-step, step), rng.uniform(-step, step), rng.uniform(-step, step)))
    bm.to_mesh(o.data)
    bm.free()
    o.location = pos
    o.rotation_euler = (rx, ry, rz)
    o.data.materials.append(mat)
    if bevel_w > 0.0:
        chamfer(o, bevel_w)
    objs.append(o)
    return o


def hex_prism(name, cx, cy, radius, thickness, mat):
    """Pointy-top hexagon, corners at 30 + 60i, matching HexMath's orientation."""
    o = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    bpy.context.collection.objects.link(o)
    bm = bmesh.new()
    verts = [bm.verts.new((cx + radius * math.cos(T(30 + 60 * i)),
                           cy + radius * math.sin(T(30 + 60 * i)), 0.0)) for i in range(6)]
    face = bm.faces.new(verts)
    res = bmesh.ops.extrude_face_region(bm, geom=[face])
    for e in res['geom']:
        if isinstance(e, bmesh.types.BMVert):
            e.co.z += thickness
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()
    o.data.materials.append(mat)
    objs.append(o)
    return o


# Game (q, r) -> Blender (x, y): glTF maps Blender +Y onto Godot -Z, and HexMath puts a neighbour
# at sqrt(3) in q and 1.5 in r.
def hex_xy(q, r):
    return (math.sqrt(3.0) * (q + r * 0.5), -1.5 * r)


def inside_hex(px, py, apothem):
    for i in range(6):
        a = T(60 * i)
        if px * math.cos(a) + py * math.sin(a) > apothem:
            return False
    return True


def cage_lantern(name, x, y, base_z, scale=1.0):
    """The caged work lamp. Six THIN BARS around the glass, not a solid cylinder over it: a solid
    shell hides its own light, which is what stopped the lantern glowing in an earlier pass."""
    r = .155 * scale
    cyl(name + ' base', (x, y, base_z), r, .04 * scale, pipe)
    cyl(name + ' glass', (x, y, base_z + .15 * scale), r * .82, .26 * scale, glow)
    for i in range(6):
        a = i * math.tau / 6
        cyl('%s bar %d' % (name, i), (x + r * math.cos(a), y + r * math.sin(a), base_z + .15 * scale),
            .016 * scale, .28 * scale, pipe, v=6)
    cyl(name + ' cap', (x, y, base_z + .31 * scale), r, .045 * scale, pipe)
    ball(name + ' flame', (x, y, base_z + .15 * scale), .07 * scale, flame)
    return base_z + .33 * scale


# Spots where a vertical support already stands, so a second one is never stacked on it.
#
# DEFENSIVE, not a fix for a known defect. It was added because the clipping audit flagged
# `Rail 4 post 8  <->  Gate post 270` at 100% box overlap, which looked like one post drawn twice. The
# audit was then extended to measure the real minimum distance between the two parts' vertices, and that
# pair is 0.308 apart -- there was never a duplicate. The box test had reported a long railing's AABB
# containing a small post elsewhere on the wall. The guard stays because a real duplicate post would be
# invisible (buried in the larger) and therefore never caught by looking, but nothing was wrong here.
_SUPPORTS_XZ = []


def railing(name, ox, oy, ang, half_len, base_z, height=.46, gap=.32):
    """A pipe railing: vertical posts with two horizontal rails. This is the single element that
    moved the compound out of the middle ages - a railing says 'somebody roped this off', where
    coping stones said 'somebody built a castle'."""
    ta = T(ang)
    tx, ty = -math.sin(ta), math.cos(ta)
    n = max(2, int(round(2 * half_len / gap)) + 1)
    for i in range(n):
        t = -half_len + i * (2 * half_len / (n - 1))
        px, py = ox + tx * t, oy + ty * t
        if any((px - qx) ** 2 + (py - qy) ** 2 < .006 ** 2 for qx, qy in _SUPPORTS_XZ):
            continue          # a support is already here; a second post is a part with no job
        _SUPPORTS_XZ.append((px, py))
        cyl('%s post %d' % (name, i), (px, py, base_z + height * .5),
            .021, height, fence_steel, v=8)
    for k, hz in enumerate((base_z + height * .98, base_z + height * .52)):
        box('%s rail %d' % (name, k), (ox, oy, hz), (.042, 2 * half_len, .042), fence_steel, 0, 0, ta)


def monolith(name, x, y, h=.60, w=.54):
    _SUPPORTS_XZ.append((x, y))
    """Bare poured concrete. No cap, no cornice, no detail - the absence of detail is the point.
    It does get a footing: a plinth gives the block a bottom edge to read against, and the block's
    own bevel gives it a top one."""
    box(name, (x, y, PLAT + .02 + h * .5), (w, w, h), concrete)
    box(name + ' footing', (x, y, PLAT + .05), (w + .08, w + .08, .10), concrete)


# --- Platform: the exact 7-hex union -----------------------------------------------------------

FOOTPRINT = [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (1, -1), (-1, 1)]
for i, (q, r) in enumerate(FOOTPRINT):
    cx, cy = hex_xy(q, r)
    hex_prism('Platform %d' % i, cx, cy, HEX_R, PLAT, concrete)

# --- Boundary: low concrete parapet, pipe railing, monoliths, pipe braces ----------------------

PARAPET_H = .26
PARAPET_T = .24
WALL_TOP = PLAT + PARAPET_H
RAIL_TOP = WALL_TOP + .50
seg_len = WALL_R
seg_i = 0
BUILT = []
for i in range(6):
    ang = 60 * i
    if ang == GATE_ANG:
        continue
    BUILT.append((ang, seg_i))
    seg_i += 1

for ang, idx in BUILT:
    ta = T(ang)
    nx, ny = math.cos(ta), math.sin(ta)
    tx, ty = -math.sin(ta), math.cos(ta)
    mx, my = WALL_APOTHEM * nx, WALL_APOTHEM * ny
    box('Parapet %d' % idx, (mx, my, PLAT + PARAPET_H * .5),
        (PARAPET_T, seg_len, PARAPET_H), concrete, 0, 0, ta)
    # ARTICULATION. A large concrete face with only a texture on it is one flat value: the detail is
    # there but there is no EDGE for a highlight to sit on, which is why the compound read as mush at
    # gameplay zoom. A cast plinth at the foot, a string band under the coping, vertical formwork
    # joints at panel pitch, and proud form-tie marks give it real edges at every scale. These are
    # geometry, not paint, so they hold up however far out the camera is.
    box('Parapet plinth %d' % idx, (mx + nx * .022, my + ny * .022, PLAT + .05),
        (PARAPET_T + .05, seg_len, .10), concrete, 0, 0, ta)
    box('Parapet band %d' % idx, (mx + nx * .02, my + ny * .02, WALL_TOP - .048),
        (PARAPET_T + .042, seg_len, .045), concrete, 0, 0, ta)
    for j in range(1, 6):
        jt = -seg_len * .5 + j * (seg_len / 6)
        box('Parapet joint %d %d' % (idx, j),
            (mx + nx * (PARAPET_T * .5 + .005) + tx * jt,
             my + ny * (PARAPET_T * .5 + .005) + ty * jt, PLAT + PARAPET_H * .52),
            (.014, .03, PARAPET_H * .80), concrete, 0, 0, ta)
    for j in range(3):
        jt = -seg_len * .3 + j * (seg_len * .3)
        box('Parapet tie %d %d' % (idx, j),
            (mx + nx * (PARAPET_T * .5 + .006) + tx * jt,
             my + ny * (PARAPET_T * .5 + .006) + ty * jt, PLAT + PARAPET_H * .30),
            (.016, .055, .055), concrete, 0, 0, ta)
    # A slightly wider screed along the top: a cast edge, and a place for the railing to land.
    box('Parapet screed %d' % idx, (mx, my, WALL_TOP + .012),
        (PARAPET_T + .06, seg_len, .028), concrete, 0, 0, ta)
    railing('Rail %d' % idx, mx, my, ang, seg_len * .46, WALL_TOP + .02)
    # Steel pipe stanchions outboard, braced back to the parapet: the buttress, replaced.
    for t in (-seg_len * .30, seg_len * .30):
        sx, sy = mx + (-math.sin(ta)) * t + nx * .30, my + math.cos(ta) * t + ny * .30
        cyl('Stanchion %d %.2f' % (idx, t), (sx, sy, PLAT + .34), .042, .68, pipe, v=8)
        cx2, cy2 = mx + (-math.sin(ta)) * t + nx * .13, my + math.cos(ta) * t + ny * .13
        cyl('Brace %d %.2f' % (idx, t), (cx2, cy2, PLAT + .62), .028, .46, pipe, v=6,
            rx=T(34) if abs(math.cos(ta)) > .5 else 0, ry=0 if abs(math.cos(ta)) > .5 else T(-34))

# Corner monoliths where runs meet. The two flanking the gate stay: they are the gateposts now.
GATE_FLANKS = (270, 330) if GATE_ANG == 300 else ()
for cang in (30, 90, 150, 210, 270, 330):
    if cang in GATE_FLANKS:
        continue
    mx, my = WALL_R * math.cos(T(cang)), WALL_R * math.sin(T(cang))
    monolith('Monolith %d' % cang, mx, my)

# One monolith carries the caged lamp on a bracket - the tall accent, and the only deliberately
# asymmetric thing on the ring, so the eye has somewhere to land.
# On a side edge the fixed camera actually sees, not the far one: an accent nobody can see is not an
# accent. The lamp sits ON TOP of the monolith, which is what makes the monolith the tall element -
# with the cage set at railing height it read as a lump on the wall, and the whole ring went flat.
LAMP_ANG = 0
LX, LY = WALL_R * math.cos(T(LAMP_ANG)), WALL_R * math.sin(T(LAMP_ANG))
# The lantern is DERIVED from the monolith height, not placed at a fixed z: hardcoding the height is
# what let the first attempt bury the lamp inside its own block and then, once corrected, float it in
# mid-air. One number, used twice.
LAMP_H = .70
LAMP_BASE = PLAT + .02 + LAMP_H
monolith('Lamp monolith', LX, LY, h=LAMP_H, w=.56)
cyl('Lamp conduit', (LX - .20, LY + .20, LAMP_BASE - .32), .028, LAMP_H * 1.12, pipe, v=8)
CAGE_TOP = cage_lantern('Lamp', LX, LY, LAMP_BASE, scale=1.05)

# --- Gate: a cracked illuminated sign box over a turnstile, no gatehouse ----------------------

gmx, gmy = WALL_APOTHEM * math.cos(T(GATE_ANG)), WALL_APOTHEM * math.sin(T(GATE_ANG))
gta = T(GATE_ANG)
for cang in (270, 330):
    mx, my = WALL_R * math.cos(T(cang)), WALL_R * math.sin(T(cang))
    monolith('Gate post %d' % cang, mx, my, h=.94, w=.50)
# The sign box spans the opening on a steel frame.
SIGN_Z = PLAT + .96
SIGN_TOP = SIGN_Z + .15
# A sign box is a dark enclosure with a pale panel in it. Having it the other way round - pale frame,
# dark face - is what made the first version read as a painted beam rather than a sign. It is also
# SHORT: at 2.05 units it spanned most of the gate and read as a blank white plank across the model,
# which is what the first in-game capture showed. Vertical dividers give it panels to read as.
SIGN_LEN = 1.15
box('Sign frame', (gmx, gmy, SIGN_Z), (.17, SIGN_LEN, .28), sign_steel, 0, 0, gta)
box('Sign face', (gmx + math.cos(gta) * .09, gmy + math.sin(gta) * .09, SIGN_Z),
    (.03, SIGN_LEN - .14, .17), sign_glow, 0, 0, gta)
box('Sign breaker', (gmx + math.cos(gta) * .105, gmy + math.sin(gta) * .105, SIGN_Z + .05),
    (.015, .17, .07), dark, 0, 0, gta)          # one dead panel in the sign, so it looks salvaged
for i, sdiv in enumerate((-.34, 0.0, .34)):
    box('Sign divider %d' % i,
        (gmx + math.cos(gta) * .105 - math.sin(gta) * sdiv,
         gmy + math.sin(gta) * .105 + math.cos(gta) * sdiv, SIGN_Z), (.02, .045, .30),
        sign_steel, 0, 0, gta)
# Legs under the sign box. The sign is carried on a steel frame, but it spans the GATE APOTHEM (2.40)
# while the two gate monoliths sit on the hex CORNERS at radius WALL_R (2.77) -- so a 1.15-long sign
# between posts 2.77 apart touched neither of them and read as a slab hanging in the air over the
# road. Two legs give it something to stand on. They land on the platform, which extends past the
# deck's 2.10 apothem to about 2.6.
for s in (-1, 1):
    box('Sign leg %d' % s,
        (gmx - math.sin(gta) * s * (SIGN_LEN * .5 - .07),
         gmy + math.cos(gta) * s * (SIGN_LEN * .5 - .07), PLAT + .42),
        (.055, .055, .84), sign_steel, 0, 0, gta)
# The sign box is carried by the two gate monoliths; it needs no legs of its own.
# Cables from the sign box to the nearest parapet, strung with slack.
tube('Gate cable 1', [(gmx - math.sin(gta) * .5, gmy + math.cos(gta) * .5, SIGN_Z + .06),
                      (gmx - math.sin(gta) * 1.1, gmy + math.cos(gta) * 1.0, PLAT + .52),
                      (gmx - math.sin(gta) * 1.7, gmy + math.cos(gta) * 1.5, WALL_TOP + .10)], .016, dark)
tube('Gate cable 2', [(gmx + math.sin(gta) * .5, gmy - math.cos(gta) * .5, SIGN_Z + .05),
                      (gmx + math.sin(gta) * 1.0, gmy - math.cos(gta) * 1.0, PLAT + .58),
                      (gmx + math.sin(gta) * 1.5, gmy - math.cos(gta) * 1.5, WALL_TOP + .12)], .014, dark)

# Turnstile, right where the deck meets the opening - but set OFF the centreline. The committed road
# runs straight out through the gate (`PathConstants.BASE_EXIT_DIR` aims it there), so a turnstile
# straddling the middle of the opening would stand in the middle of the road and read as a barricade
# rather than an entrance. Offset to one side with its arms shortened, its inner arm tip clears the
# road's 0.56 half-width: it reads as a turnstile bank beside a clear gate, which is what a station
# has. The offset stays inside the opening (half-width 1.385); there is no wall for it to foul.
TS_OFF = .95
TS_X, TS_Y = gmx * .74 - math.sin(gta) * TS_OFF, gmy * .74 + math.cos(gta) * TS_OFF
cyl('Turnstile post', (TS_X, TS_Y, PLAT + .28), .055, .50, steel_pale, v=10)
cyl('Turnstile head', (TS_X, TS_Y, PLAT + .46), .075, .07, pipe, v=10)
for i in range(3):
    a = i * math.tau / 3 + T(20)
    box('Turnstile arm %d' % i, (TS_X + .16 * math.cos(a), TS_Y + .16 * math.sin(a), PLAT + .45),
        (.32, .045, .035), steel_pale, 0, 0, a)

# --- Central stairwell: tiled walls, pipe handrails, railing round the mouth -------------------

SHAFT_CX, SHAFT_CY = .30, -.34
SHAFT_HW, SHAFT_HL = .62, .95
# How far down the stairwell goes: NEGATIVE, i.e. below sea level, deliberately. The height cap is
# measured from z=0 up and ignores everything under it, so depth here is free and the only thing that
# bounds it is how deep a stairwell the model wants. Nothing else may floor the pit either -- the base
# hexes no longer draw a street lot (see terrain_view.get_hex_tile_archetype) because the compound's
# own platform covers them all, and that lot would otherwise cap the descent at sea level.
SHAFT_FLOOR = -.50
# The flight descends AWAY FROM THE GATE. The gate is built on the 300-degree edge, i.e. the Blender
# -Y side, so the MOUTH - the top step, where you walk in - sits at -Y and the stairs drop toward +Y.
#
# It was the other way round, and that is why the descent could not be read. With the mouth on the far
# side, a player standing at the gate was looking at the BOTTOM of the flight with every riser facing
# away: a pit, not stairs you would walk down. A subway stair is entered at its head, so the mouth has
# to face the entrance. Both ends are named here rather than written as `SHAFT_CY + SHAFT_HL` nine
# times, because these terms are what had to all flip together.
SHAFT_MOUTH_Y = SHAFT_CY - SHAFT_HL
SHAFT_DEEP_Y = SHAFT_CY + SHAFT_HL
# SIX treads on a 0.74 drop: a 0.13 rise each, roughly 10 px at gameplay zoom. What reads as a stair
# is the RISE per step, not the overall slope -- the original six treads on a 0.30 drop gave a 0.04
# rise, about one pixel, so the risers were invisible and all you saw was the tread tops, which is a
# flat surface however steep the flight's ratio looks.
TREADS = 6
# The flight fills the first 0.80 of the shaft; the rest is open void, so the steps visibly continue
# into blackness past the last tread.
STAIR_RUN = .80
STEP_RUN = STAIR_RUN / TREADS
shaft_lining = texmat('Shaft lining', 'tex_dark_concrete.png', .80, mr='mr_dark_concrete.png')
for i in range(TREADS):
    top = (PLAT - .05) - i * ((PLAT - .05) - (SHAFT_FLOOR + .05)) / (TREADS - 1)
    y = SHAFT_MOUTH_Y + (i + .5) * STEP_RUN
    # Treads are TEXTURED concrete, not a flat colour. Flat was part of why the flight read as a smooth
    # ramp: a surface with no albedo variation and no normal map has nothing for a highlight to catch,
    # so under one key light every step was the same sheet of grey. The per-step pale nosing still marks
    # each edge, and there is a real hole underneath now, so the tonal crutch is not needed.
    tread = concrete
    box('Tread %d' % i, (SHAFT_CX, y, top - .04), (SHAFT_HW * 2, STEP_RUN + .02, .08), tread)
    if i < TREADS - 1:
        box('Tread nosing %d' % i, (SHAFT_CX, y + STEP_RUN * .5, top + .006),
            (SHAFT_HW * 2 - .03, .026, .016), pipe)
box('Shaft void', (SHAFT_CX, SHAFT_CY, SHAFT_FLOOR - .28), (SHAFT_HW * 2, SHAFT_HL * 2, .56), dark)
# Tiled cheek walls, the strongest "this was a station" signal in the whole model.
for sx in (-1, 1):
    box('Shaft cheek %d' % sx, (SHAFT_CX + sx * (SHAFT_HW + .04), SHAFT_CY, PLAT - .17),
        (.08, SHAFT_HL * 2 + .08, .40), tile)
# The pit's inner walls, BELOW deck level. The tile cheeks above are the station signal and stay, but
# pale tile lining the inside of the hole made the recess read as a shallow bright box -- the single
# biggest reason the shaft did not look like a hole. Blocking in the below-deck part in a dark tone
# gives the pit sides something to fall away into.
LINING_H = PLAT - SHAFT_FLOOR
LINING_Z = (PLAT + SHAFT_FLOOR) / 2
for sx in (-1, 1):
    box('Shaft lining %d' % sx, (SHAFT_CX + sx * (SHAFT_HW - .005), SHAFT_CY, LINING_Z),
        (.03, SHAFT_HL * 2, LINING_H), shaft_lining)
box('Shaft lining back', (SHAFT_CX, SHAFT_DEEP_Y - .01, LINING_Z),
    (SHAFT_HW * 2, .03, LINING_H), shaft_lining)
box('Shaft back', (SHAFT_CX, SHAFT_DEEP_Y + .03, PLAT - .13),
    (SHAFT_HW * 2 + .12, .06, .32), tile)
box('Shaft lip', (SHAFT_CX, SHAFT_MOUTH_Y - .03, PLAT - .05),
    (SHAFT_HW * 2 + .12, .06, .16), shaft_lining)
# CUT THE PIT THROUGH THE PLATFORM.
#
# The platform is seven SOLID hex prisms, so before this the shaft was a decorative box resting on an
# unbroken concrete floor at deck level: the treads, the nosings and the lamp were all buried inside
# solid geometry, and from above the "hole" was a flat surface. That is the whole reason the flight
# read as flat ground -- there was never a hole to see into, and no amount of tone, proportion or
# lighting could show one.
#
# A boolean DIFFERENCE per platform prism, applied by the convert(target='MESH') before the join,
# removes it for real. The cutter reaches past SHAFT_FLOOR so the pit's own floor is not clipped off,
# and is kept out of `objs` so it is never joined or exported; it is deleted right after the convert.
_pit = box('Shaft cutter', (SHAFT_CX, SHAFT_CY, (PLAT + SHAFT_FLOOR) / 2),
           (SHAFT_HW * 2, SHAFT_HL * 2, PLAT - SHAFT_FLOOR + .40), concrete)
objs.remove(_pit)
for _i in range(len(FOOTPRINT)):
    _mod = bpy.data.objects['Platform %d' % _i].modifiers.new('pit', 'BOOLEAN')
    _mod.operation = 'DIFFERENCE'
    _mod.object = _pit
    _mod.solver = 'EXACT'
# Handrails down both cheeks.
for sx in (-1, 1):
    rx = SHAFT_CX + sx * (SHAFT_HW - .06)
    tube('Handrail %d' % sx,
         [(rx, SHAFT_MOUTH_Y + .08, PLAT + .32), (rx, SHAFT_CY - .10, PLAT - .10),
          (rx, SHAFT_DEEP_Y - .10, SHAFT_FLOOR + .24)], .022, pipe)
    for i in (0, 2, 4):
        yy = SHAFT_MOUTH_Y + (i + .5) * (2 * SHAFT_HL / (TREADS + 1))
        cyl('Handrail post %d %d' % (sx, i), (rx, yy, PLAT - .04 - i * .05), .018, .26, steel_pale, v=6)
# Railing around the mouth so the shaft is not just a hole.
# Side rails run along Y (the shaft's long axis), so their edge angle is 0; the far rail crosses it
# along X, so its edge angle is 270. Getting this wrong lays the railing across the opening.
for sx in (-1, 1):
    railing('Mouth rail %d' % sx, SHAFT_CX + sx * (SHAFT_HW + .12), SHAFT_CY, 0,
            SHAFT_HL * .92, PLAT + .02, height=.44, gap=.30)
# A guard along the FAR (deep) edge of the opening. The mouth end is deliberately left open - that is
# the whole point of turning the flight round: the entrance has to look walkable.
railing('Mouth rail far', SHAFT_CX, SHAFT_DEEP_Y + .12, 270, SHAFT_HW * .92, PLAT + .02,
        height=.44, gap=.30)
# A caged lamp standing on the shaft floor, below deck level. Every one of the shrine concepts does
# this, and it is the cheapest fix for the real problem: without a light in it the shaft reads as a
# black hole, and a black hole is not a centre. With one, the stair is where the eye goes.
# The lamp stands IN the pit. At 0.80 scale on a base at PLAT-.28 its cage topped out around deck
# level, so a lantern poked out of the opening and the hole read as a shelf with a lamp on it. At 0.62
# on the shaft floor it lights the treads from inside the hole, which is what makes the hole deep.
cyl('Shaft lamp rod', (SHAFT_CX + SHAFT_HW - .18, SHAFT_CY + .34, SHAFT_FLOOR + .40), .014, .20, brass, v=6)
cage_lantern('Shaft lamp', SHAFT_CX + SHAFT_HW - .18, SHAFT_CY + .34, SHAFT_FLOOR, .62)
for i, p in enumerate([(-.20, .10, .05), (.06, .20, .04), (.22, .16, .05)]):
    tube('Tentacle %d' % i,
         [(SHAFT_CX + p[0], SHAFT_CY + p[1], p[2]), (SHAFT_CX + p[0] + .06, SHAFT_CY + p[1] - .16, p[2] + .13),
          (SHAFT_CX + p[0] - .04, SHAFT_CY + p[1] - .30, p[2] + .19)], .03, tent)

# --- Deck: concrete slabs, a few wet, clipped to the parapet and cut round the shaft -----------

DECK_APOTHEM = WALL_APOTHEM - .30
GRID = 8
deck_slabs = 0
for row in range(GRID):
    for col in range(GRID):
        cx = -DECK_APOTHEM + (col + .5) * (2 * DECK_APOTHEM / GRID)
        cy = -DECK_APOTHEM + (row + .5) * (2 * DECK_APOTHEM / GRID)
        if not inside_hex(cx, cy, DECK_APOTHEM):
            continue
        if (abs(cx - SHAFT_CX) < SHAFT_HW + .30 and abs(cy - SHAFT_CY) < SHAFT_HL + .30):
            continue
        # Thicker slabs with a wider joint. The joint IS the edge: a 12mm groove between paving is
        # invisible at gameplay zoom, and without visible joints a deck is one flat value with
        # nothing for a highlight to land on.
        box('Deck slab %d %d' % (row, col), (cx, cy, PLAT + .008),
            (2 * DECK_APOTHEM / GRID - .026, 2 * DECK_APOTHEM / GRID - .026, .038), concrete,
            0, 0, rng.uniform(-.006, .006))
        deck_slabs += 1
print('deck paving slabs:', deck_slabs)
for i, (wx, wy, ws) in enumerate([(1.10, -.85, .70), (-.45, 1.15, .68), (1.05, 1.05, .62),
                                  (-1.30, -.80, .60), (.30, -1.10, .72), (-.85, -.20, .56),
                                  (1.45, .10, .55), (-.95, 1.15, .58)]):
    # Guard on the CENTRE MINUS THE PATCH'S OWN HALF-WIDTH, not the centre alone: the old guard
    # passed a 1.05-wide puddle whose centre was inside the parapet and whose corner was not.
    if not inside_hex(wx, wy, DECK_APOTHEM - ws * .72 - .03):
        continue
    decal_flat('Wet patch %d' % i, (wx, wy, PLAT + .034), ws, wet_m, aspect=.8)

# --- Lean-to workshop: corrugated sheet on STEEL PIPE posts ------------------------------------

LH_X, LH_Y = -1.35, .30
LH_W, LH_D = 2.10, 1.70
PITCH = -14
# LH_LOW is 0.52 above the platform, not 0.80. At 0.80 the ridge reached 1.66 in world Z - OVER
# HexMath.TOWER_MAX_HEIGHT (1.5), which exists so tall things do not hide enemies, and enemies arrive
# AT this hex. The height assert never covered the lean-to, which is why it went unnoticed for several
# passes; the AABB measurement of 1.699 that got blamed on the gate cables' curve overshoot was this
# roof all along.
LH_LOW = PLAT + .52
# Derived from LH_LOW, never a second copy of the height: the hardcoded PLAT + .80 here is exactly
# what let the ridge sit 0.16 over the ceiling while LH_LOW looked correct. Same duplicated-magic-
# number mistake as the lantern that floated in mid-air when its monolith changed height.
LH_HIGH = LH_LOW + math.tan(T(-PITCH)) * LH_W
slope = math.tan(T(-PITCH))
# ONE sheet, not two. Two plates split along the slope put a seam straight down the middle of the
# roof, and under isometric light the two halves shaded differently, so it read as two roofs standing
# side by side. A single corrugated sheet is also what the reference has.
box('Lean-to sheet', (LH_X, LH_Y, (LH_LOW + LH_HIGH) * .5), (LH_W, LH_D, .05), roof, 0, T(PITCH), 0)
box('Lean-to ridge', (LH_X + LH_W / 2, LH_Y, LH_HIGH), (.07, LH_D + .06, .07), pipe)
box('Lean-to eave', (LH_X - LH_W / 2, LH_Y, LH_LOW), (.07, LH_D + .06, .08), pipe)
# The sheet's underside is a PLANE, so every support under it has to be placed against that plane
# rather than against a corner height. Two things clipped because they weren't:
#   * the posts took the z of a corner (LH_LOW or LH_HIGH) while being inset 0.10 along X, which put the
#     high-side post's top 0.10 * slope = 0.025 ABOVE the sheet -- a pipe punching through the roof;
#   * the cross beams ran LEVEL along X under a 14-degree slope, so they were guaranteed to cut through
#     the low end of the sheet whatever height they were given.
# Both are now derived from the surface itself.
def lh_surface(x):
    """Underside of the roof sheet at world X, before the sheet's own thickness."""
    return LH_LOW + (x - (LH_X - LH_W / 2)) * slope

for py in (LH_Y - LH_D / 2 + .10, LH_Y + LH_D / 2 - .10):
    for px in (LH_X - LH_W / 2 + .10, LH_X + LH_W / 2 - .10):
        # Stop 0.03 BELOW the sheet, not at a corner height: the sheet is 0.05 thick, and this keeps
        # the joint reading as a joint instead of a pipe through the roof.
        ptop = lh_surface(px) - .03
        cyl('Lean-to post', (px, py, (ptop + PLAT) / 2), .055, max(ptop - PLAT, .1), pipe)
    # Purlins, SLOPED to match the sheet. A level beam under a slope intersects it somewhere by
    # definition; running the purlin parallel to the sheet is also what a real lean-to does.
    box('Lean-to purlin', (LH_X, py, (LH_LOW + LH_HIGH) * .5 - .05), (LH_W, .06, .06), pipe,
        0, T(PITCH), 0)
# A tarp lashed over the outer half, as in the concept.
# A tarp lashed to the low edge and hanging down, which is what the concept art has - a second layer
# of roofing would just read as a second roof. It is a flat dark tarpaulin, NOT the torn-canvas
# texture: canvas carries strong vertical banding, and with a red sigil painted over it the pair read
# as a striped banner rather than a tarpaulin.
box('Lean-to tarp', (LH_X - LH_W / 2 - .02, LH_Y, PLAT + .255), (.014, LH_D * .96, .50), tarp)
decal_at('Tarp sigil', (LH_X - LH_W / 2 - .034, LH_Y, PLAT + .26), .40, sig_red, 180)

# --- Salvage on the deck: propane, junction box, cables, barrier, crates -----------------------

# Two propane bottles and a jerry can, jammed against the lean-to.
for i, (bx, by) in enumerate([(-2.05, -.45), (-1.85, -.72)]):
    cyl('Propane %d' % i, (bx, by, PLAT + .27), .155, .54, propane, v=12)
    cyl('Propane neck %d' % i, (bx, by, PLAT + .55), .055, .08, steel_pale, v=8)
    cyl('Propane valve %d' % i, (bx, by, PLAT + .61), .022, .07, pipe, v=6)
cyl('Jerry can', (-2.05, 1.05, PLAT + .19), .16, .38, red, v=10)
cyl('Jerry cap', (-2.05, 1.05, PLAT + .40), .04, .05, pipe, v=6)

# Junction box with conduit up onto the parapet, and cables strung to the next post.
JX, JY = 1.72, .66
box('Junction box', (JX, JY, PLAT + .52), (.30, .17, .62), steel_pale)
box('Junction door', (JX, JY - .09, PLAT + .52), (.24, .012, .50), pipe)
cyl('Conduit up', (JX + .12, JY, WALL_TOP + .26), .026, .92, pipe, v=8)
cyl('Conduit elbow', (JX + .12, JY, WALL_TOP + .72), .026, .22, pipe, v=8, rx=T(90))
tube('Cable A', [(JX + .12, JY - .04, WALL_TOP + .68), (JX + .70, JY - .30, WALL_TOP + .34),
                 (JX + 1.30, JY + .10, WALL_TOP + .52), (JX + 1.55, JY + .85, WALL_TOP + .70)],
     .014, dark)
tube('Cable B', [(JX + .12, JY + .04, WALL_TOP + .60), (JX + .80, JY + .34, WALL_TOP + .40),
                 (JX + 1.35, JY + .80, WALL_TOP + .56)], .011, dark)

# Hazard barrier leaning on the parapet, and a crate stack.
BX, BY, BANG = -1.10, -2.02, T(14)
box('Barrier plank', (BX, BY, PLAT + .30), (.06, 1.05, .24), white, 0, T(-18), BANG)
for i in range(3):
    box('Barrier stripe %d' % i, (BX - .035, BY - .30 + i * .30, PLAT + .30),
        (.02, .17, .24), red, 0, T(-18), BANG)
cyl('Barrier leg', (BX - .16, BY + .34, PLAT + .10), .028, .30, pipe, v=8, rx=T(-20))
for i, (cx, cy, cz, ca) in enumerate([(-1.50, -1.22, .20, T(9)), (-1.20, -1.45, .20, T(-6)),
                                      (-1.35, -1.33, .58, T(3))]):
    box('Crate %d' % i, (cx, cy, PLAT + cz), (.46, .42, .38), wood, 0, 0, ca)
    box('Crate band %d' % i, (cx, cy, PLAT + cz), (.47, .43, .05), wood, 0, 0, ca)

# --- The shrine: a salvaged standpipe on a cast equipment pad, OFF TO ONE SIDE ---------------
# Off to the side deliberately. The sunken stair is this court's centre, and a shrine dropped over it
# would fight the stair for the same job. The pad is cast concrete with rusted steel angle edging, so
# the cult is visibly building a platform FOR the thing it reveres rather than finding it lying there.
# The standpipe itself is the project's own pump-station object: oxidised teal cast iron, bolted
# flanges, domed top. Salvaged infrastructure made sacred is the whole pillar, so the best idol was
# already in the concept folder.
SHRINE_X, SHRINE_Y = 1.35, 1.30
box('Pad step', (SHRINE_X, SHRINE_Y, PLAT + .03), (1.06, 1.06, .06), concrete)
box('Pad slab', (SHRINE_X, SHRINE_Y, PLAT + .11), (.92, .92, .10), concrete)
for i, (ex, ey, ew, ed) in enumerate([(0, -.46, .92, .05), (0, .46, .92, .05),
                                      (-.46, 0, .05, .92), (.46, 0, .05, .92)]):
    box('Pad angle %d' % i, (SHRINE_X + ex, SHRINE_Y + ey, PLAT + .165), (ew, ed, .022), rust_plate)
PAD_TOP = PLAT + .16
for i, (ex, ey) in enumerate([(-.40, -.40), (.40, -.40), (-.40, .40), (.40, .40)]):
    cyl('Pad cleat %d' % i, (SHRINE_X + ex, SHRINE_Y + ey, PAD_TOP + .012), .026, .05, rust_plate, v=6)

cyl('Standpipe base flange', (SHRINE_X, SHRINE_Y, PAD_TOP + .035), .30, .07, teal_iron, v=16)
cyl('Standpipe foot flange', (SHRINE_X, SHRINE_Y, PAD_TOP + .095), .245, .04, teal_iron, v=16)
for i in range(8):
    a = i * math.tau / 8
    cyl('Standpipe bolt %d' % i, (SHRINE_X + .245 * math.cos(a), SHRINE_Y + .245 * math.sin(a),
                                  PAD_TOP + .078), .023, .026, brass, v=6)
BARREL_Z = PAD_TOP + .115
cyl('Standpipe barrel', (SHRINE_X, SHRINE_Y, BARREL_Z + .25), .135, .50, teal_iron, v=16)
cyl('Standpipe collar', (SHRINE_X, SHRINE_Y, BARREL_Z + .20), .175, .05, teal_iron, v=16)
cyl('Standpipe neck', (SHRINE_X, SHRINE_Y, BARREL_Z + .535), .17, .07, teal_iron, v=16)
ball('Standpipe dome', (SHRINE_X, SHRINE_Y, BARREL_Z + .60), .165, teal_iron, squash=.72)
cyl('Standpipe finial', (SHRINE_X, SHRINE_Y, BARREL_Z + .70), .035, .05, brass, v=8)
ball('Standpipe finial knob', (SHRINE_X, SHRINE_Y, BARREL_Z + .735), .045, brass, squash=.8)
SHRINE_TOP = BARREL_Z + .77
# The elbow off the barrel and down, as the pump-station concept has it.
tube('Standpipe elbow',
     [(SHRINE_X + .09, SHRINE_Y - .05, BARREL_Z + .40),
      (SHRINE_X + .34, SHRINE_Y - .09, BARREL_Z + .34),
      (SHRINE_X + .46, SHRINE_Y - .07, BARREL_Z + .10),
      (SHRINE_X + .46, SHRINE_Y - .05, PAD_TOP + .04)], .085, teal_iron)
box('Standpipe elbow plate', (SHRINE_X + .46, SHRINE_Y - .05, PAD_TOP + .03), (.30, .30, .06),
    teal_iron)
# A tarp lashed over the dome with wire.
ball('Shrine hood', (SHRINE_X, SHRINE_Y, BARREL_Z + .61), .215, canvas, squash=.60)
ring('Shrine wire', (SHRINE_X, SHRINE_Y, BARREL_Z + .50), .20, .012, brass)
# Candles in tins and jars, ringed at the base: the warm pool of light a grey court wants.
for i in range(9):
    a = i * math.tau / 9 + .3
    tx, ty = SHRINE_X + .36 * math.cos(a), SHRINE_Y + .36 * math.sin(a)
    h = .085 + rng.uniform(-.015, .015)
    cyl('Shrine tin %d' % i, (tx, ty, PAD_TOP + h * .5), .052, h, tin, v=10)
    cyl('Shrine wax %d' % i, (tx, ty, PAD_TOP + h + .012), .038, .024, wax, v=10)
    ball('Shrine flame %d' % i, (tx, ty, PAD_TOP + h + .048), .018, flame)
for i in range(3):
    a = .55 + i * .62
    jx, jy = SHRINE_X + .40 * math.cos(a), SHRINE_Y + .40 * math.sin(a)
    cyl('Shrine jar %d' % i, (jx, jy, PAD_TOP + .07), .055, .14, steel_pale, v=10)
    cyl('Shrine jar wax %d' % i, (jx, jy, PAD_TOP + .115), .042, .03, wax, v=10)
    ball('Shrine jar flame %d' % i, (jx, jy, PAD_TOP + .152), .018, flame)
# Offerings heaped at the flange, and a coil of salvaged wire.
for i in range(5):
    ball('Offering %d' % i, (SHRINE_X - .34 + rng.uniform(-.09, .09),
                             SHRINE_Y - .30 + rng.uniform(-.09, .09), PAD_TOP + .032),
         .034 + rng.uniform(0, .015), bone)
ring('Offering wire', (SHRINE_X - .40, SHRINE_Y + .20, PAD_TOP + .035), .07, .022, brass, T(90))
# The caged lamp on a brass bracket bolted to the riser.
cyl('Shrine bracket', (SHRINE_X, SHRINE_Y - .22, BARREL_Z + .34), .026, .30, brass, v=8, rx=T(90))
SHRINE_LAMP_TOP = cage_lantern('Shrine lamp', SHRINE_X, SHRINE_Y - .36, BARREL_Z + .10, .85)

# --- Weathering, and the clutter that makes a place look used ------------------------------------
# Streaks run DOWN the parapet and damp pools at its base. This is the cheap half of the concept look:
# the albedo carries the darkness, but standing water and run-off are what make a surface look
# neglected rather than merely dark. Positions come off the edge maths, like the sigils, so a streak
# cannot end up floating in front of a wall or buried inside it.
STREAKS = [(0, .62, False), (0, -.30, True), (60, -.55, False), (120, .40, True),
           (120, -.25, False), (180, -.62, False), (180, .22, True), (240, .48, True),
           (240, -.15, False)]
for i, sd in enumerate(STREAKS):
    sang, soff, inward = sd
    sa = T(sang)
    snx, sny = math.cos(sa), math.sin(sa)
    stx, sty = -math.sin(sa), math.cos(sa)
    soff_sign = -(PARAPET_T * .5 + .006) if inward else (PARAPET_T * .5 + .006)
    smat = (streak_m, rust_streak, damp_m)[i % 3]
    decal_at('Streak %d' % i,
             (WALL_APOTHEM * snx + snx * soff_sign + stx * soff,
              WALL_APOTHEM * sny + sny * soff_sign + sty * soff, PLAT + .125), .14, smat,
             sang + (180.0 if inward else 0.0), aspect=rng.uniform(1.3, 1.7))
for i, wpair in enumerate([(.75, -.80), (-.30, .85), (1.30, .55), (-1.05, -1.05), (1.55, -.40),
                           (-1.45, -.55), (.10, 1.45)]):
    wx, wy = wpair
    ws = rng.uniform(.50, .78)
    if not inside_hex(wx, wy, DECK_APOTHEM - ws * .72 - .03):
        continue
    decal_flat('Damp %d' % i, (wx, wy, PLAT + .033), ws, damp_m, aspect=.7)


def barrel(bname, x, y, h=.52, r=.19, mat=None):
    cyl(bname, (x, y, PLAT + .02 + h * .5), r, h, pipe if mat is None else mat, v=12)
    for bz in (PLAT + .02 + h * .28, PLAT + .02 + h * .74):
        ring('%s band %.2f' % (bname, bz), (x, y, bz), r + .012, .018, rust_plate)


def bucket(bname, x, y, r=.115):
    cyl(bname, (x, y, PLAT + .14), r, .24, tin, v=10)
    ring(bname + ' rim', (x, y, PLAT + .26), r + .008, .012, rust_plate)
    ball(bname + ' slop', (x, y, PLAT + .23), r * .7, dark, squash=.25)


# The concepts are dense, and density is most of what reads as "somebody works here".
barrel('Barrel A', -1.60, .98)
barrel('Barrel B', -1.28, 1.16, .44, .17, teal_iron)
cyl('Barrel A lid', (-1.60, .98, PLAT + .555), .195, .03, rust_plate, v=12)
bucket('Bucket A', .95, -.70)
bucket('Bucket B', -.74, -1.42, .13)
cyl('Oil drum', (1.90, -.55, PLAT + .30), .24, .58, rust_plate, v=14)
ring('Oil drum band', (1.90, -.55, PLAT + .44), .252, .02, pipe)
ring('Hose coil', (-.34, -.88, PLAT + .045), .15, .045, dark, T(90))
ring('Hose coil 2', (-.34, -.88, PLAT + .105), .135, .042, dark, T(90))
# A pallet: slats on bearers.
for i in range(4):
    box('Pallet slat %d' % i, (.14 + (i - 1.5) * .17, -1.34, PLAT + .055), (.14, .58, .022), wood)
for i, py in enumerate((-.26, .26)):
    box('Pallet bearer %d' % i, (.14, -1.34 + py, PLAT + .028), (.62, .07, .028), wood)
# Debris, and a scatter of small junk the eye reads as a worked surface.
for i in range(14):
    da = rng.uniform(0, math.tau)
    dr = rng.uniform(.3, 1.9)
    dx, dy = math.cos(da) * dr, math.sin(da) * dr
    if not inside_hex(dx, dy, DECK_APOTHEM - .15):
        continue
    chipped('Debris %d' % i, (dx, dy, PLAT + .025), (.075, .065, .04),
            rng.choice((concrete_dark, rock)), 0, 0, rng.uniform(0, 3), jitter=.30, rounded=True)
for i in range(4):
    ba = .4 + i * .8
    cyl('Bottle %d' % i, (1.05 + math.cos(ba) * .30, .62 + math.sin(ba) * .30, PLAT + .085), .035,
        .17, teal_iron, v=8)
# Candles left burning on the stair treads, as the concept has them.
for i in (1, 3, 5):
    cx3 = SHAFT_CX + rng.uniform(-.34, .34)
    cy3 = SHAFT_MOUTH_Y + (i + .5) * (2 * SHAFT_HL / (TREADS + 1))
    top3 = (PLAT - .05) - i * ((PLAT - .05) - (SHAFT_FLOOR + .05)) / (TREADS - 1)
    cyl('Stair candle %d' % i, (cx3, cy3, top3 + .03), .026, .07, wax, v=8)
    ball('Stair flame %d' % i, (cx3, cy3, top3 + .078), .015, flame)

# --- Spray paint: the cult's own marking, red and violet, over concrete and tile ---------------

# Sigils on the parapet, facing outward. Placed off the edge maths rather than by eye so each one
# sits flat ON the concrete instead of floating in front of it or sinking into it.
SIGIL_EDGES = [(0, sig_red, .48), (60, sig_violet, -.42), (120, sig_red, -.46),
               (180, sig_violet, .44), (240, sig_red, -.40)]
for i, (sang, smat, soff) in enumerate(SIGIL_EDGES):
    sa = T(sang)
    snx, sny = math.cos(sa), math.sin(sa)
    stx, sty = -math.sin(sa), math.cos(sa)
    spx = WALL_APOTHEM * snx + snx * (PARAPET_T * .5 + .006) + stx * soff
    spy = WALL_APOTHEM * sny + sny * (PARAPET_T * .5 + .006) + sty * soff
    decal_at('Wall sigil %d' % i, (spx, spy, PLAT + .13), .34, smat, sang, aspect=.58)
decal_flat('Deck sigil', (-1.05, .95, PLAT + .033), .85, sig_violet)
decal_flat('Deck sigil 2', (1.68, -.10, PLAT + .033), .58, sig_red)
decal_at('Shaft tile sigil', (SHAFT_CX, SHAFT_DEEP_Y - .015, PLAT - .09), .22, sig_red, 270)
decal_at('Monolith sigil', (LX, LY - .29, PLAT + .44), .34, sig_violet, 270)
decal_flat('Shrine deck sigil', (SHRINE_X - .75, SHRINE_Y - .55, PLAT + .033), .60, sig_violet)
# On the riser itself, kept small: a flat quad on a curved barrel floats at its edges once the quad is
# wider than the cylinder's radius.
decal_at('Shrine sigil', (SHRINE_X + .138 * math.cos(T(300)),
                          SHRINE_Y + .138 * math.sin(T(300)), BARREL_Z + .28), .16, sig_red, 300)
# Inward-facing sigils, and two on the gate monoliths: the inside of the compound is what the camera
# looks down into, so outward-only paint left the court itself bare.
for i, (sang, smat, soff) in enumerate([(240, sig_violet, .30), (0, sig_red, -.30),
                                        (60, sig_violet, .20)]):
    sa = T(sang)
    snx, sny = math.cos(sa), math.sin(sa)
    stx, sty = -math.sin(sa), math.cos(sa)
    spx = WALL_APOTHEM * snx - snx * (PARAPET_T * .5 + .006) + stx * soff
    spy = WALL_APOTHEM * sny - sny * (PARAPET_T * .5 + .006) + sty * soff
    decal_at('Inner sigil %d' % i, (spx, spy, PLAT + .13), .34, smat, sang + 180, aspect=.58)
for gcam, gmat in ((270, sig_red), (330, sig_violet)):
    gx, gy = WALL_R * math.cos(T(gcam)), WALL_R * math.sin(T(gcam))
    decal_at('Gate sigil %d' % gcam,
             (gx - math.cos(T(gcam)) * .27, gy - math.sin(T(gcam)) * .27, PLAT + .56), .40,
             gmat, gcam + 180)

# --- Join, UV, export -------------------------------------------------------------------------

# --- Decal self-check ---------------------------------------------------------------------------
# A decal is a flat quad, so it cannot wrap or clip: wherever it is put, it hangs in the air. Printing
# each one's actual world extent is the only way to see that, because a decal two millimetres off its
# host surface looks identical to one floating a hand's width away in a rendered view.
#
# view_layer.update() FIRST: reading matrix_world straight after setting rotation_euler gives a STALE
# matrix for some objects, which made the first version of this table report a decal as lying flat when
# it was not. A diagnostic that lies is worse than no diagnostic.
bpy.context.view_layer.update()
print('--- DECAL CHECK: platform top %.3f, wall assembly %.3f..%.3f, monolith tops %.3f ---' % (
    PLAT, PLAT, WALL_TOP + .04, PLAT + .02 + .70))
for d in decals:
    zs = [(d.matrix_world @ Vector(c)).z for c in d.bound_box]
    xs = [(d.matrix_world @ Vector(c)).x for c in d.bound_box]
    ys = [(d.matrix_world @ Vector(c)).y for c in d.bound_box]
    print('  %-22s z %6.3f..%6.3f   x %.2f..%.2f   y %.2f..%.2f' % (
        d.name, min(zs), max(zs), min(xs), max(xs), min(ys), max(ys)))

bpy.ops.object.select_all(action='DESELECT')
# EVERY part must be selected. join() merges the SELECTED objects into the ACTIVE one, so deselecting
# and then setting only the active object joins NOTHING: the parts stay loose in the scene and the
# export below (use_selection=True) ships exactly one of them - a lone hex slab - with all the decals
# left floating in the air where the walls should be. A Blender preview cannot show this, because a
# preview renders the scene and the loose parts are all still in it. Only the exported GLB can.
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
# objs holds curves as well as meshes (the pipe tubes and the cable beziers), and only meshes have
# .vertices, so the accounting has to be taken AFTER the conversion, not before.
bpy.ops.object.convert(target='MESH')
# The boolean cutters have done their work -- convert(target='MESH') applies modifiers -- so they can
# go before the join and the export. They were never in `objs`, so they were never joined.
for _o in list(bpy.data.objects):
    if _o.name.startswith('Shaft cutter'):
        bpy.data.objects.remove(_o, do_unlink=True)
verts_in = sum(len(o.data.vertices) for o in objs)
# Name what is actually tallest. The hand-written HEIGHTS table has under-reported twice (v40 and
# v51), because it lists the parts someone remembered to list -- so when the mesh check reports a top
# above the table, this is what turns "something is too tall" into "this part is too tall".
bpy.context.view_layer.update()
_rank = sorted(((max((o.matrix_world @ v.co).z for v in o.data.vertices), o.name)
                for o in objs if hasattr(o.data, 'vertices')), reverse=True)[:6]
print('tallest parts: ' + ', '.join('%s %.3f' % (n, z) for z, n in _rank))

# --- CLIPPING AUDIT -----------------------------------------------------------------------------
# Parts are supposed to TOUCH, and sometimes to embed shallowly (a bolt inside its flange, a deck slab
# biting into the platform). What reads as a defect is a DEEP interpenetration: two solids sharing a
# large fraction of the smaller one's volume, so the smaller is mostly swallowed and its silhouette is
# cut off where it should read as a separate thing.
#
# Measured on world AABBs. That is an approximation -- two rotated boxes can have overlapping AABBs
# while their solids miss -- but it is the right approximation here, because a part only LOOKS wrong
# when its extent lies inside another part's extent. Report only; the threshold is a judgement call and
# some hits are legitimate by design, which is why this prints names instead of asserting.
_solids = []
for _o in objs:
    if not hasattr(_o.data, 'vertices') or len(_o.data.vertices) == 0:
        continue
    _mw = _o.matrix_world
    _ps = [_mw @ _v.co for _v in _o.data.vertices]
    _solids.append((_o.name,
                    (min(p.x for p in _ps), min(p.y for p in _ps), min(p.z for p in _ps)),
                    (max(p.x for p in _ps), max(p.y for p in _ps), max(p.z for p in _ps)),
                    _o.data.materials[0].name if len(_o.data.materials) else ''))
def _box_vol(_s):
    return (_s[2][0] - _s[1][0]) * (_s[2][1] - _s[1][1]) * (_s[2][2] - _s[1][2])
def _overlap_vol(_a, _b):
    return (max(0.0, min(_a[2][0], _b[2][0]) - max(_a[1][0], _b[1][0])) *
            max(0.0, min(_a[2][1], _b[2][1]) - max(_a[1][1], _b[1][1])) *
            max(0.0, min(_a[2][2], _b[2][2]) - max(_a[1][2], _b[1][2])))
_clip = []
for _i in range(len(_solids)):
    for _j in range(_i + 1, len(_solids)):
        _a, _b = _solids[_i], _solids[_j]
        _ov = _overlap_vol(_a, _b)
        if _ov <= 0.0:
            continue
        _small = min(_box_vol(_a), _box_vol(_b))
        if _small > 0.0 and _ov / _small > 0.30:
            _clip.append((_ov / _small, _a[0], _b[0], _a[3] == _b[3]))
_clip.sort(reverse=True)
# AABB overlap cannot tell "clipping" from "an AABB larger than its part". A long tube's box swallows
# small parts whole, so a candle flame inside a pipe's BOX reports 100% while the pipe passes well clear
# of it. For the pairs the box test flags, measure the actual thing: the shortest distance between the
# two parts' vertices. Touching or interpenetrating geometry gives ~0.000; a clear miss shows a gap.
_TOP = _clip[:16]
_TOPNAMES = set()
for _c in _TOP:
    _TOPNAMES.add(_c[1])
    _TOPNAMES.add(_c[2])
_PTS = {}
for _o in objs:
    if _o.name in _TOPNAMES and hasattr(_o.data, 'vertices'):
        _mw = _o.matrix_world
        _PTS[_o.name] = [(_mw @ _v.co) for _v in _o.data.vertices][::2]
print('clipping: %d pairs share >30%% of the smaller part' % len(_clip))
for _frac, _na, _nb, _same in _TOP:
    _pa, _pb = _PTS.get(_na, []), _PTS.get(_nb, [])
    _best = -1.0
    for _p in _pa:
        for _q in _pb:
            _d2 = (_p - _q).length_squared
            if _best < 0.0 or _d2 < _best:
                _best = _d2
    print('   %.0f%%  gap %s  %s  <->  %s' %
          (_frac * 100.0, ('%.3f' % math.sqrt(_best)) if _best >= 0.0 else '  ?  ', _na, _nb))
names_in = [o.name for o in objs]
bpy.ops.object.join()
base = bpy.context.object
base.name = 'Cult Sanctum Compound'
verts_out = len(base.data.vertices)
survivors = [n for n in names_in if n in bpy.data.objects]
print('join: %d parts / %d verts -> %d verts in one mesh' % (len(objs), verts_in, verts_out))
print('join: unjoined parts left over: %d' % len(survivors))
# names_in holds the PRE-rename names, so a fully consumed join leaves nothing matching: a non-empty
# survivors list means parts are still loose in the scene and will not reach the export.
assert survivors == [], 'join did not consume every part; still loose: %s' % survivors[:6]
assert 'Cult Sanctum Compound' in bpy.data.objects, 'the joined mesh is not in the file'
assert verts_out >= verts_in // 2, 'joined mesh lost most of its vertices'

# World-space tiling UVs. A packed atlas gave ~17px per face; cube-projecting at a fixed world
# scale is what keeps the concrete and the tile crisp.
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.cube_project(cube_size=UV_TILE, correct_aspect=True, clip_to_bounds=False,
                        scale_to_bounds=False)
bpy.ops.object.mode_set(mode='OBJECT')

for loc, power, size in [((7.0, -9.0, 8.0), 1400, 6.0), ((-7.0, 6.0, 7.0), 700, 5.0)]:
    bpy.ops.object.light_add(type='AREA', location=loc)
    o = bpy.context.object
    o.data.energy = power
    o.data.size = size
    o.rotation_euler = (-o.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(location=(7.0, -9.5, 8.0))
c = bpy.context.object
c.rotation_euler = (Vector((0, 0, .6)) - c.location).to_track_quat('-Z', 'Y').to_euler()
c.data.type = 'ORTHO'
c.data.ortho_scale = 7.0
bpy.context.scene.camera = c

# len(objs) is the number of parts that went IN, whether or not the join consumed them. The real
# accounting is the survivor check printed above; this line must not be read as proof of a merge.
print('compound parts offered to the join:', len(objs))
print('platform hexes: %d, parapet top z: %.2f, rail top z: %.2f' % (len(FOOTPRINT), WALL_TOP, RAIL_TOP))
# Assert on the ACTUAL tallest element. Checking only the lamp let the gate sign box grow past the
# limit unnoticed, because the thing being measured was not the thing that was tall.
# Max height is measured from z=0 UP. z=0 is the floor of the hexes -- sea level -- and anything below
# it is depth, not height, and is deliberately not counted: the stairwell descends through z=0 and
# must not be charged for it. So the check runs on the ACTUAL joined mesh, not only on a table of
# constants. A stale constant is exactly how a too-tall element slips past an assert -- it happened at
# v40, where the thing being measured was not the thing that was tall.
HEIGHTS = {'lamp cage': CAGE_TOP, 'gate monolith': PLAT + .96, 'gate sign': SIGN_TOP,
           'railing': RAIL_TOP, 'shrine standpipe': SHRINE_TOP, 'lean-to ridge': LH_HIGH}
bpy.context.view_layer.update()
_wm = base.matrix_world
_zs = [(_wm @ v.co).z for v in base.data.vertices]
mesh_top = max(_zs)
mesh_bottom = min(_zs)
tallest = max(max(HEIGHTS.values()), mesh_top)
print('heights:', {k: round(v, 3) for k, v in HEIGHTS.items()})
print('measured mesh: top %.3f, bottom %.3f (below sea level = depth, not counted)'
      % (mesh_top, mesh_bottom))
print('TALLEST %.3f (limit 1.5, measured from z=0 up)' % tallest)
assert tallest < 1.5, 'tallest element exceeds TOWER_MAX_HEIGHT'
assert mesh_bottom < 0.0, 'the stairwell no longer descends below sea level'

bpy.ops.object.select_all(action='DESELECT')
base.select_set(True)
for d in decals:
    d.select_set(True)
bpy.context.view_layer.objects.active = base
print('decals exported alongside the mesh:', len(decals))
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                          export_image_format='AUTO')
print('exported', OUT)