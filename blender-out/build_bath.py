# Parlour restroom fixtures. 1 unit = 1 stud.
# Each piece is modelled at the origin: floor contact on Z = 0, back toward -Y, front toward +Y.
# Blender Z-up is exported as Roblox Y-up: (x, z, -y).

import json
import math
import os

import bmesh
import bpy
from mathutils import Vector

OUT = "/Users/jessicaarmitage/Desktop/ink-master/blender-out/bath"

old = bpy.data.collections.get("ParlourBath")
if old:
    for child in list(old.children):
        for obj in list(child.objects):
            mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if mesh and mesh.users == 0:
                bpy.data.meshes.remove(mesh)
        bpy.data.collections.remove(child)
    for obj in list(old.objects):
        mesh = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        if mesh and mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    bpy.data.collections.remove(old)

root = bpy.data.collections.new("ParlourBath")
bpy.context.scene.collection.children.link(root)


def material(name, color, rough, metallic=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metallic
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.45 if metallic else 0.3
    return mat


MAT = {
    "ceramic": material("BathCeramic", (0.90, 0.88, 0.84), 0.18),
    "seat": material("BathSeat", (0.93, 0.92, 0.90), 0.42),
    "brass": material("BathBrass", (0.62, 0.46, 0.24), 0.32, 1.0),
    "walnut": material("BathWalnut", (0.28, 0.16, 0.09), 0.48),
    "stone": material("BathStone", (0.78, 0.76, 0.72), 0.22),
    "glass": material("BathGlass", (0.75, 0.82, 0.84), 0.05),
    "linen": material("BathLinen", (0.16, 0.15, 0.14), 0.8),
    "shade": material("BathShade", (0.95, 0.90, 0.80), 0.4),
}


def new_object(collection, name, bm, mat):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, me)
    collection.objects.link(obj)
    me.materials.append(mat)
    return obj


def outward(bm):
    bm.normal_update()
    if not bm.faces:
        return
    center = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
    score = 0.0
    for face in bm.faces:
        score += (face.calc_center_median() - center).dot(face.normal)
    if score < 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))


def lathe(profile, segs=32, cap_start=True, cap_end=True):
    bm = bmesh.new()
    rings = []
    for radius, z in profile:
        ring = []
        for i in range(segs):
            angle = 2 * math.pi * i / segs
            ring.append(bm.verts.new((math.cos(angle) * radius, math.sin(angle) * radius, z)))
        rings.append(ring)
    for r in range(len(rings) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((rings[r][i], rings[r][j], rings[r + 1][j], rings[r + 1][i]))
    if cap_start and profile[0][0] > 0.001:
        hub = bm.verts.new((0, 0, profile[0][1]))
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((hub, rings[0][j], rings[0][i]))
    if cap_end and profile[-1][0] > 0.001:
        hub = bm.verts.new((0, 0, profile[-1][1]))
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((hub, rings[-1][i], rings[-1][j]))
    outward(bm)
    return bm


def shift(bm, offset):
    for vert in bm.verts:
        vert.co += Vector(offset)
    return bm


def scale_xy(bm, sx, sy):
    for vert in bm.verts:
        vert.co.x *= sx
        vert.co.y *= sy
    return bm


def box(size, bevel=0.0, segs=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for vert in bm.verts:
        vert.co.x *= size[0]
        vert.co.y *= size[1]
        vert.co.z *= size[2]
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segs, affect="EDGES")
    outward(bm)
    return bm


def tube(points, radius, segs=8):
    bm = bmesh.new()
    rings = []
    for index, point in enumerate(points):
        if index == 0:
            tangent = points[1] - points[0]
        elif index == len(points) - 1:
            tangent = points[-1] - points[-2]
        else:
            tangent = points[index + 1] - points[index - 1]
        tangent.normalize()
        up = Vector((0, 0, 1))
        if abs(tangent.dot(up)) > 0.92:
            up = Vector((1, 0, 0))
        side = tangent.cross(up).normalized()
        binormal = side.cross(tangent).normalized()
        ring = []
        for i in range(segs):
            angle = 2 * math.pi * i / segs
            ring.append(bm.verts.new(point + (side * math.cos(angle) + binormal * math.sin(angle)) * radius))
        rings.append(ring)
    for r in range(len(rings) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((rings[r][i], rings[r][j], rings[r + 1][j], rings[r + 1][i]))
    for ring, sign in ((rings[0], -1), (rings[-1], 1)):
        center = sum((v.co for v in ring), Vector()) / len(ring)
        hub = bm.verts.new(center)
        for i in range(segs):
            j = (i + 1) % segs
            if sign < 0:
                bm.faces.new((hub, ring[j], ring[i]))
            else:
                bm.faces.new((hub, ring[i], ring[j]))
    outward(bm)
    return bm


def arc(start, end, bend, steps=8):
    points = []
    for i in range(steps + 1):
        t = i / steps
        point = start.lerp(end, t)
        point += bend * math.sin(t * math.pi)
        points.append(point)
    return points


def join(meshes):
    bm = bmesh.new()
    for piece in meshes:
        bm.from_mesh(piece.data if hasattr(piece, "data") else None) if False else None
    # join bmeshes
    out = bmesh.new()
    for piece in meshes:
        out.from_mesh(_bm_to_mesh(piece))
    return out


def _bm_to_mesh(bm):
    me = bpy.data.meshes.new("_tmp")
    bm.to_mesh(me)
    return me


def merge(bms):
    out = bmesh.new()
    for bm in bms:
        me = _bm_to_mesh(bm)
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
        bm.free()
    outward(out)
    return out


# --------------------------------------------------------------------------------------
# Toilet

def build_toilet(col):
    bowl = lathe(
        [
            (0.16, 0.0),
            (0.30, 0.03),
            (0.34, 0.14),
            (0.22, 0.30),
            (0.42, 0.46),
            (0.56, 0.66),
            (0.60, 0.82),
            (0.54, 0.90),
            (0.46, 0.86),
            (0.30, 0.64),
            (0.16, 0.50),
        ],
        36,
    )
    scale_xy(bowl, 1.0, 1.18)
    shift(bowl, (0, 0.22, 0))

    water = lathe([(0.0, 0.58), (0.24, 0.58)], 20)
    scale_xy(water, 1.0, 1.15)
    shift(water, (0, 0.20, 0))

    seat = lathe(
        [
            (0.40, 0.90),
            (0.52, 0.93),
            (0.56, 0.98),
            (0.52, 1.03),
            (0.40, 1.05),
            (0.36, 1.00),
            (0.40, 0.95),
        ],
        36,
    )
    scale_xy(seat, 1.0, 1.16)
    shift(seat, (0, 0.24, 0))

    lid = lathe(
        [
            (0.08, 1.02),
            (0.46, 1.05),
            (0.54, 1.10),
            (0.46, 1.15),
            (0.08, 1.16),
        ],
        32,
    )
    scale_xy(lid, 1.0, 1.14)
    shift(lid, (0, 0.22, 0))

    tank = box((1.18, 0.46, 1.02), bevel=0.045, segs=2)
    shift(tank, (0, -0.62, 1.48))
    cap = box((1.24, 0.52, 0.08), bevel=0.03, segs=1)
    shift(cap, (0, -0.62, 2.02))

    lever = tube(
        [Vector((-0.60, -0.62, 1.62)), Vector((-0.78, -0.62, 1.62)), Vector((-0.82, -0.70, 1.50))],
        0.035,
        8,
    )

    ceramic = merge([bowl, water, tank, cap])
    new_object(col, "BathToiletCeramic", ceramic, MAT["ceramic"])
    new_object(col, "BathToiletSeat", merge([seat, lid]), MAT["seat"])
    new_object(col, "BathToiletBrass", lever, MAT["brass"])


# --------------------------------------------------------------------------------------
# Vanity: walnut cabinet, stone top, inset basin, brass bridge faucet

def build_vanity(col):
    plinth = box((2.72, 1.48, 0.16), bevel=0.02, segs=1)
    shift(plinth, (0, 0.10, 0.08))
    carcass = box((2.64, 1.42, 2.55), bevel=0.025, segs=1)
    shift(carcass, (0, 0.08, 1.48))

    panels = []
    for side in (-0.64, 0.64):
        panel = box((1.12, 0.06, 2.05), bevel=0.04, segs=2)
        shift(panel, (side, 0.82, 1.42))
        panels.append(panel)
    stile = box((0.08, 0.05, 2.15), 0)
    shift(stile, (0, 0.84, 1.42))
    panels.append(stile)

    wood = merge([plinth, carcass, *panels])
    new_object(col, "BathVanityWood", wood, MAT["walnut"])

    top = box((2.92, 1.62, 0.10), bevel=0.015, segs=1)
    shift(top, (0, 0.02, 2.82))
    new_object(col, "BathVanityStone", top, MAT["stone"])

    # A vessel bowl sitting on the stone, so the interior reads without cutting a hole.
    basin = lathe(
        [
            (0.20, 0.0),
            (0.46, 0.04),
            (0.54, 0.16),
            (0.50, 0.26),
            (0.42, 0.30),
            (0.34, 0.24),
            (0.18, 0.08),
        ],
        32,
    )
    scale_xy(basin, 1.28, 0.92)
    shift(basin, (0, 0.08, 2.90))
    new_object(col, "BathVanityCeramic", basin, MAT["ceramic"])

    spout = tube(
        arc(Vector((0, -0.46, 2.98)), Vector((0, 0.02, 3.08)), Vector((0, -0.05, 0.46)), 10),
        0.042,
        8,
    )
    drop = tube(
        [Vector((0, 0.02, 3.08)), Vector((0, 0.02, 2.86))],
        0.03,
        8,
    )
    handles = []
    for side in (-0.32, 0.32):
        stem = tube(
            [Vector((side, -0.40, 2.96)), Vector((side, -0.40, 3.18))],
            0.038,
            8,
        )
        knob = lathe([(0.0, 0.0), (0.07, 0.02), (0.075, 0.06), (0.04, 0.09)], 12)
        shift(knob, (side, -0.40, 3.18))
        handles.extend([stem, knob])
    pulls = []
    for side in (-0.64, 0.64):
        pull = tube(
            [
                Vector((side - 0.16, 0.90, 1.35)),
                Vector((side - 0.16, 1.02, 1.35)),
                Vector((side + 0.16, 1.02, 1.35)),
                Vector((side + 0.16, 0.90, 1.35)),
            ],
            0.028,
            6,
        )
        pulls.append(pull)
    brass = merge([spout, drop, *handles, *pulls])
    new_object(col, "BathVanityBrass", brass, MAT["brass"])


# --------------------------------------------------------------------------------------
# Mirror. Origin at the centre of the glass; the back of the frame sits on Y = 0.

def build_mirror(col):
    outer_w, outer_h, depth = 2.35, 3.15, 0.12
    lip = 0.16
    frame_parts = []
    top = box((outer_w, depth, lip), bevel=0.012, segs=1)
    shift(top, (0, depth / 2, outer_h / 2 - lip / 2))
    bot = box((outer_w, depth, lip), bevel=0.012, segs=1)
    shift(bot, (0, depth / 2, -outer_h / 2 + lip / 2))
    left = box((lip, depth, outer_h - lip * 2), bevel=0.012, segs=1)
    shift(left, (-outer_w / 2 + lip / 2, depth / 2, 0))
    right = box((lip, depth, outer_h - lip * 2), bevel=0.012, segs=1)
    shift(right, (outer_w / 2 - lip / 2, depth / 2, 0))
    frame_parts.extend([top, bot, left, right])
    new_object(col, "BathMirrorFrame", merge(frame_parts), MAT["walnut"])

    brass_lip = []
    inset_w = outer_w - lip * 2
    inset_h = outer_h - lip * 2
    band = 0.045
    for spec in (
        ((inset_w, 0.02, band), (0, 0.02, inset_h / 2 - band / 2)),
        ((inset_w, 0.02, band), (0, 0.02, -inset_h / 2 + band / 2)),
        ((band, 0.02, inset_h - band * 2), (-inset_w / 2 + band / 2, 0.02, 0)),
        ((band, 0.02, inset_h - band * 2), (inset_w / 2 - band / 2, 0.02, 0)),
    ):
        piece = box(spec[0], 0)
        shift(piece, spec[1])
        brass_lip.append(piece)
    new_object(col, "BathMirrorBrass", merge(brass_lip), MAT["brass"])

    glass = box((inset_w - 0.06, 0.015, inset_h - 0.06), 0)
    shift(glass, (0, 0.012, 0))
    new_object(col, "BathMirrorGlass", glass, MAT["glass"])


# --------------------------------------------------------------------------------------
# Towel bar. Back of the roses on Y = 0, bar running along X, cloth hanging toward -Z.

def build_towel(col):
    span = 1.55
    roses = []
    for side in (-span / 2, span / 2):
        rose = lathe([(0.0, 0.0), (0.09, 0.01), (0.07, 0.04), (0.045, 0.08)], 14)
        # lathe is around Z; rotate so it sticks out along +Y from the wall
        for vert in rose.verts:
            x, y, z = vert.co.x, vert.co.y, vert.co.z
            vert.co = Vector((x, z, y))
        shift(rose, (side, 0, 0))
        roses.append(rose)
    bar = tube([Vector((-span / 2, 0.10, 0)), Vector((span / 2, 0.10, 0))], 0.035, 8)
    new_object(col, "BathTowelBar", merge([*roses, bar]), MAT["brass"])

    cols, rows = 18, 14
    bm = bmesh.new()
    grid = []
    for r in range(rows):
        line = []
        v = r / (rows - 1)
        for c in range(cols):
            u = c / (cols - 1)
            x = (u - 0.5) * (span - 0.12)
            hang = v * 0.95
            fold = math.sin(v * math.pi * 3.0) * 0.035
            sway = math.sin(u * math.pi) * 0.04 * v
            y = 0.10 + fold + sway
            z = -hang - fold * 0.4
            # drape over the bar at the top
            if v < 0.08:
                z = 0.04
                y = 0.14
            line.append(bm.verts.new((x, y, z)))
        grid.append(line)
    for r in range(rows - 1):
        for c in range(cols - 1):
            bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=0.028)
    outward(bm)
    new_object(col, "BathTowelCloth", bm, MAT["linen"])


# --------------------------------------------------------------------------------------
# Pendant. Attachment at Z = 0, shade hangs below.

def build_pendant(col):
    canopy = lathe([(0.0, 0.0), (0.16, -0.01), (0.14, -0.06), (0.05, -0.1)], 16)
    stem = tube([Vector((0, 0, -0.08)), Vector((0, 0, -0.55))], 0.03, 8)
    shade = lathe(
        [
            (0.06, 0.0),
            (0.16, -0.05),
            (0.30, -0.16),
            (0.42, -0.34),
            (0.40, -0.40),
        ],
        24,
        cap_end=False,
    )
    shift(shade, (0, 0, -0.55))
    bulb = lathe([(0.0, 0.0), (0.07, 0.02), (0.07, 0.08), (0.0, 0.1)], 12)
    shift(bulb, (0, 0, -0.72))
    new_object(col, "BathPendantBrass", merge([canopy, stem]), MAT["brass"])
    new_object(col, "BathPendantShade", shade, MAT["shade"])
    new_object(col, "BathPendantBulb", bulb, MAT["shade"])


built = {}
for name, builder in (
    ("BathToilet", build_toilet),
    ("BathVanity", build_vanity),
    ("BathMirror", build_mirror),
    ("BathTowel", build_towel),
    ("BathPendant", build_pendant),
):
    col = bpy.data.collections.new(name)
    root.children.link(col)
    builder(col)
    built[name] = col

os.makedirs(OUT, exist_ok=True)


def export_piece(obj):
    mesh = obj.data
    verts = [[round(v.co.x, 4), round(v.co.z, 4), round(-v.co.y, 4)] for v in mesh.vertices]
    faces = []
    for poly in mesh.polygons:
        idx = list(poly.vertices)
        if len(idx) == 3:
            faces.append(idx)
        elif len(idx) == 4:
            faces.append([idx[0], idx[1], idx[2]])
            faces.append([idx[0], idx[2], idx[3]])
        else:
            for k in range(1, len(idx) - 1):
                faces.append([idx[0], idx[k], idx[k + 1]])
    return {"name": obj.name, "verts": verts, "faces": faces}


for name, col in built.items():
    pieces = [export_piece(obj) for obj in col.objects]
    path = os.path.join(OUT, name + ".json")
    with open(path, "w") as handle:
        json.dump(pieces, handle, separators=(",", ":"))
    tris = sum(len(p["faces"]) for p in pieces)
    print(name, "tris", tris, "bytes", os.path.getsize(path), "parts", [p["name"] for p in pieces])

# Spread them out so they can be looked at without sitting on the user's other work.
slots = {
    "BathToilet": (0, 8, 0),
    "BathVanity": (4.2, 8, 0),
    "BathMirror": (7.4, 8, 1.7),
    "BathTowel": (9.6, 8, 1.2),
    "BathPendant": (11.2, 8, 2.2),
}
for name, col in built.items():
    for obj in col.objects:
        obj.location = Vector(slots[name])

print("bath fixtures ready")
