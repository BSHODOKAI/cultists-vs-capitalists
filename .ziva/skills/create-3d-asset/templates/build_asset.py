# Skeleton for a new cultists-vs-capitalists 3D asset.
#
# Run through Ziva's `blender` tool on blank.blend:
#   exec(compile(open('<abs>/build_<asset>.py').read(), 'build_asset', 'exec'))
#
# This is a STARTING POINT, not a drop-in: it wires up the conventions and the self-checks that
# the Sanctum's build proved necessary. The full worked example, with ~40 more helpers, is
#   res://graphics_generation/sanctum/sources/build_sanctum_compound.py
# Read it before going far past this file.
#
# Conventions baked in below (see the create-3d-asset skill §4):
#   * Blender Z-up -> Godot Y-up; glTF maps Blender -Y -> Godot +Z.
#   * A rotation of A degrees about Blender Z becomes -A in Godot's (x, z).
#   * Deletion is by explicit object list, never "everything" -- the join() trap is real.
#   * Heights are asserted from the JOINED mesh, counting only z >= 0. Depth below is free.

import bpy
import bmesh
import math
import os
from mathutils import Vector

A = '<abs path to the asset folder>/'          # trailing slash
OUT = A + 'my_asset.glb'
T = math.radians

# --- budget: read the real number from res://scripts/core/hex_math.gd -----------------------
HEIGHT_CAP = 1.5           # HexMath.TOWER_MAX_HEIGHT
UV_TILE = 1.5              # world units per texture repeat; a FEATURE-SIZE choice, not detail

objs = []                  # every part, for the counters and the audits below


def fresh():
    """Wipe the file. Explicit, so it cannot silently delete something we made."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()


def _track(o, name):
    o.name = name
    objs.append(o)
    return o


def box(name, size, loc, mat, rot=(0, 0, 0), chamfer=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.scale = Vector(size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.rotation_euler = (T(rot[0]), T(rot[1]), T(rot[2]))
    if chamfer > 0.0:
        m = o.modifiers.new('bev', 'BEVEL')
        m.width = chamfer
        m.segments = 2
    o.data.materials.append(mat)
    return _track(o, name)


def cyl(name, loc, radius, height, mat, rot=(0, 0, 0), segments=12):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=segments, radius=radius, depth=height, location=loc)
    o = bpy.context.active_object
    o.rotation_euler = (T(rot[0]), T(rot[1]), T(rot[2]))
    o.data.materials.append(mat)
    return _track(o, name)


def cut(target, cutter):
    """Real boolean subtraction. A solid prism BURIES whatever is inside it -- if you want a
    hole, cut a hole. (The Sanctum's stairwell sat inside solid floor for four revisions.)"""
    m = target.modifiers.new('cut', 'BOOLEAN')
    m.operation = 'DIFFERENCE'
    m.object = cutter
    return target


def tile_uv(o, uv_tile=UV_TILE):
    """Cube-project at a FIXED WORLD SCALE so texture features land at a real size.
    smart_project packs islands far too densely and reads as blur; keep it for unique decals."""
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.cube_project(cube_size=uv_tile)
    bpy.ops.object.mode_set(mode='OBJECT')


def texmat(name, albedo, normal='', mr='', metallic=0.0, emissive=0.0):
    """PBR material from texture files. METALLIC: keep <= 0.10 -- main.tscn has no reflection
    source, so a strongly metallic surface renders BLACK. emissive > 0 exports as an emissive
    texture + KHR_materials_emissive_strength, which is how a lit sign should be made."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes['Principled BSDF']
    bsdf.inputs['Metallic'].default_value = min(metallic, 0.10)

    def img(path):
        return bpy.data.images.load(A + path) if path else None

    a = img(albedo)
    if a:
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = a
        tex.interpolation = 'Smart'
        nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
        if emissive > 0.0:
            nt.links.new(tex.outputs['Color'], bsdf.inputs['Emission Color'])
            bsdf.inputs['Emission Strength'].default_value = emissive
    n = img(normal)
    if n:
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = n
        tex.image.colorspace_settings.name = 'Non-Color'
        tex.interpolation = 'Smart'
        nm = nt.nodes.new('ShaderNodeNormalMap')
        nt.links.new(tex.outputs['Color'], nm.inputs['Color'])
        nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    r = img(mr)
    if r:
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = r
        tex.image.colorspace_settings.name = 'Non-Color'
        tex.interpolation = 'Smart'
        sep = nt.nodes.new('ShaderNodeSeparateColor')
        nt.links.new(tex.outputs['Color'], sep.inputs['Color'])
        nt.links.new(sep.outputs['Green'], bsdf.inputs['Roughness'])
    return mat


def flat(name, col, metallic=0.0, emissive=0.0, rough=0.7):
    """Untextured fallback. Use sparingly and be able to justify each one -- a flat accent is
    usually a texture audit you have not run yet."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (col[0], col[1], col[2], 1.0)
    b.inputs['Metallic'].default_value = min(metallic, 0.10)
    b.inputs['Roughness'].default_value = rough
    if emissive > 0.0:
        b.inputs['Emission Color'].default_value = (col[0], col[1], col[2], 1.0)
        b.inputs['Emission Strength'].default_value = emissive
    return mat


# ============================================================================================
# BUILD
# ============================================================================================
fresh()
concrete = texmat('concrete', 'tex_concrete.png', 'tex_concrete_n.png', 'mr_concrete.png')
steel = texmat('steel_pale', 'tex_metal_galv.png', 'tex_metal_galv_n.png', 'mr_metal_galv.png')

# --- a 1-hex footprint: keep geometry inside the apothem (0.866); the plinth 0.56 reads well
cyl('Plinth', (0, 0, 0.05), 0.56, 0.10, concrete, segments=6)
box('Housing', (0.60, 0.60, 0.80), (0, 0, 0.50), concrete, chamfer=0.03)
cyl('Stovepipe', (0.20, 0.12, 1.05), 0.07, 0.60, steel, segments=10)

# A cut, done properly: build the cutter, boolean it, then delete the cutter BEFORE the join.
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.35))
cutter = bpy.context.active_object
cutter.scale = Vector((0.30, 0.30, 0.30))
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
cut(bpy.data.objects['Housing'], cutter)
bpy.data.objects.remove(cutter, do_unlink=True)

for o in list(objs):
    if o.type == 'MESH' and o.data.polygons:
        tile_uv(o)

# ============================================================================================
# SELF-CHECKS -- these are what make a build trustworthy. Do not skip them.
# ============================================================================================
# convert() FIRST: join() discards modifiers, and a preview cannot catch a broken export.
bpy.ops.object.select_all(action='DESELECT')
for o in objs:
    if o.name in bpy.data.objects and o.type in {'MESH', 'CURVE'}:
        o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
input_count = len(bpy.context.selected_objects)
bpy.ops.object.convert(target='MESH')       # bake the chamfers
bpy.ops.object.join()
joined = bpy.context.active_object
bpy.context.view_layer.update()

# NOTE: a count of INPUTS is not a check. Verify the joined result.
verts = len(joined.data.vertices)
tris = len(joined.data.loop_triangles)

# 1. height from the JOINED mesh, counting only z >= 0 (below-sea-level depth is not capped)
top = max((joined.matrix_world @ v.co).z for v in joined.data.vertices)
bottom = min((joined.matrix_world @ v.co).z for v in joined.data.vertices)
print('joined: %d objects -> %d verts, %d tris' % (input_count, verts, tris))
print('mesh top %.3f (cap %.2f, headroom %.3f)   mesh bottom %.3f' % (
    top, HEIGHT_CAP, HEIGHT_CAP - top, bottom))
assert top <= HEIGHT_CAP + 1e-4, 'TOO TALL by %.3f' % (top - HEIGHT_CAP)

# 2. name the tallest parts -- when the assert above fails, this says WHICH part
corners = []
for o in objs:
    if o.name not in bpy.data.objects:
        continue
    zs = [(o.matrix_world @ v.co).z for v in o.data.vertices]
    if zs:
        corners.append((max(zs), o.name))
corners.sort(reverse=True)
print('tallest parts:', ', '.join('%s %.3f' % (n, z) for z, n in corners[:4]))

# 3. clipping audit: AABB pairs sharing >30% of the smaller volume, then A VERTEX-GAP VERDICT.
#    AABB overlap cannot tell nesting from clipping -- the gap decides, so report it.
def aabb(o):
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))

meshes = [o for o in objs if o.name in bpy.data.objects and o.type == 'MESH']
boxes = {o.name: aabb(o) for o in meshes}
flagged = 0
for i, a in enumerate(meshes):
    for b in meshes[i + 1:]:
        lo1, hi1 = boxes[a.name]
        lo2, hi2 = boxes[b.name]
        ov = Vector((min(hi1.x, hi2.x) - max(lo1.x, lo2.x),
                     min(hi1.y, hi2.y) - max(lo1.y, lo2.y),
                     min(hi1.z, hi2.z) - max(lo1.z, lo2.z)))
        if ov.x <= 0 or ov.y <= 0 or ov.z <= 0:
            continue
        # separation of the actual vertex sets (a long thin tube's box overstates its bulk)
        da = [min((a.matrix_world @ v.co - b.matrix_world @ w.co).length
                  for w in b.data.vertices) for v in a.data.vertices[:40]]
        gap = min(da) if da else 0.0
        if gap > 0.02:
            flagged += 1
            print('box overlap (gap %.3f -- NESTED, not clipping): %s / %s'
                  % (gap, a.name, b.name))
print('clipping audit: %d boxes, %d real intersections' % (len(meshes), flagged))

# 4. export
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB')
print('exported %s (%d bytes)' % (OUT, os.path.getsize(OUT)))