# Detailed parlour plants. 1 unit = 1 stud. Each pot base sits on Z = 0.

import json
import os
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT = "/Users/jessicaarmitage/Desktop/ink-master/blender-out/plants"

for obj in list(bpy.data.objects):
    obj.hide_set(True)
    obj.hide_render = True

old = bpy.data.collections.get("ParlourPlants")
if old:
    for child in list(old.children):
        for obj in list(child.objects):
            mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if mesh.users == 0:
                bpy.data.meshes.remove(mesh)
        bpy.data.collections.remove(child)
    bpy.data.collections.remove(old)

root = bpy.data.collections.new("ParlourPlants")
bpy.context.scene.collection.children.link(root)


def material(name, color, rough):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.28
    return mat


MAT = {
    "leaf": material("PlantLeaf", (0.1, 0.24, 0.09), 0.42),
    "leaf_light": material("PlantLeafLight", (0.22, 0.38, 0.14), 0.4),
    "snake": material("PlantSnakeLeaf", (0.13, 0.24, 0.12), 0.38),
    "blue": material("PlantBlueLeaf", (0.2, 0.34, 0.26), 0.48),
    "stem": material("PlantStem", (0.24, 0.18, 0.1), 0.6),
    "stem_green": material("PlantStemGreen", (0.18, 0.3, 0.12), 0.5),
    "soil": material("PlantSoil", (0.1, 0.065, 0.04), 0.92),
    "pot_char": material("PlantPotChar", (0.16, 0.15, 0.14), 0.5),
    "pot_cream": material("PlantPotCream", (0.75, 0.69, 0.58), 0.5),
    "pot_clay": material("PlantPotClay", (0.45, 0.22, 0.13), 0.58),
    "pot_white": material("PlantPotWhite", (0.88, 0.86, 0.82), 0.28),
}


def new_object(collection, name, bm, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, me)
    collection.objects.link(obj)
    me.materials.append(mat)
    return obj


def pot(collection, name, radius, height, mat, segs=28):
    bm = bmesh.new()
    profile = [
        (0.62, 0.0),
        (0.72, 0.04),
        (0.66, 0.08),
        (0.8, height * 0.5),
        (0.98, height * 0.92),
        (1.08, height),
        (1.16, height + 0.04),
        (1.0, height + 0.015),
        (0.9, height - 0.015),
    ]
    rings = []
    for scale, z in profile:
        ring = []
        for i in range(segs):
            angle = 2 * math.pi * i / segs
            ring.append(bm.verts.new((math.cos(angle) * radius * scale, math.sin(angle) * radius * scale, z)))
        rings.append(ring)
    for r in range(len(rings) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((rings[r][i], rings[r][j], rings[r + 1][j], rings[r + 1][i]))
    soil = bmesh.new()
    cap = []
    for i in range(segs):
        angle = 2 * math.pi * i / segs
        cap.append(soil.verts.new((math.cos(angle) * radius * 0.86, math.sin(angle) * radius * 0.86, height - 0.02)))
    soil.faces.new(cap)
    new_object(collection, name + "Pot", bm, mat)
    new_object(collection, name + "Soil", soil, MAT["soil"])
    return height


def stem(collection, name, start, end, radius, mat, segs=7):
    delta = end - start
    length = delta.length
    if length < 0.02:
        return
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius, radius2=radius * 0.55, depth=length)
    quat = delta.normalized().to_track_quat("Z", "Y")
    bmesh.ops.transform(bm, verts=bm.verts, matrix=Matrix.Translation(start + delta * 0.5) @ quat.to_matrix().to_4x4())
    new_object(collection, name, bm, mat)


def fill_outline(points, length, curl, thickness, cuts=1):
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, 0)) for x, y in points]
    edges = []
    for i in range(len(verts)):
        edges.append(bm.edges.new((verts[i], verts[(i + 1) % len(verts)])))
    bmesh.ops.triangle_fill(bm, edges=edges, normal=Vector((0, 0, 1)), use_beauty=True)
    if cuts > 0:
        bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=cuts, smooth=0.4)
    for vert in bm.verts:
        along = max(0.0, min(1.0, vert.co.x / max(length, 0.001)))
        side = abs(vert.co.y)
        vert.co.z += -curl * (along ** 1.5) * length * 0.22
        vert.co.z += (1 - min(side / (length * 0.2 + 0.05), 1)) * 0.02 * math.sin(math.pi * along)
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=thickness)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def lobed_leaf(length, width, lobes, curl, depth):
    """A blade with deep side notches, the way a monstera or a fern leaflet is cut."""
    steps = 36
    right = []
    left = []
    for i in range(steps + 1):
        t = i / steps
        envelope = math.sin(math.pi * t) ** 0.6
        cut = 1.0
        if 0.14 < t < 0.9:
            cut = 1 - depth * (0.5 + 0.5 * math.cos(t * lobes * math.pi * 2))
            cut = max(0.28, cut)
        y = width * 0.5 * envelope * cut
        x = (t ** 0.92) * length
        right.append((x, y))
        left.append((x, -y))
    outline = right + list(reversed(left))
    return fill_outline(outline, length, curl, 0.012 if length < 1 else 0.016)


def heart_leaf(length, curl):
    pts = []
    for i in range(48):
        t = 2 * math.pi * i / 48
        x = math.sin(t) ** 3
        y = (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 16
        # Tip points along +X, stem notch at the origin.
        pts.append(((y + 1) * 0.5 * length, x * length * 0.42))
    return fill_outline(pts, length, curl, 0.008)


def lance(length, width, curl, thick, steps=18, cuts=1):
    right = []
    left = []
    for i in range(steps + 1):
        t = i / steps
        envelope = math.sin(math.pi * t) ** 0.55 * (1 - 0.15 * t)
        y = width * 0.5 * envelope
        right.append((t * length, y))
        left.append((t * length, -y))
    return fill_outline(right + list(reversed(left)), length, curl, thick, cuts)


def place(bm, origin, direction):
    rot = direction.normalized().to_track_quat("X", "Z").to_matrix().to_4x4()
    bmesh.ops.transform(bm, verts=bm.verts, matrix=Matrix.Translation(origin) @ rot)
    return bm


def build_fig(collection):
    rim = pot(collection, "Fig", 0.78, 1.45, MAT["pot_char"])
    rng = random.Random(3)
    fork = Vector((0.05, 0, rim + 1.15))
    stem(collection, "FigTrunk", Vector((0, 0, rim - 0.04)), fork, 0.075, MAT["stem"], 8)
    stem(collection, "FigBranchA", fork, fork + Vector((0.25, 0.15, 0.7)), 0.04, MAT["stem"], 6)
    stem(collection, "FigBranchB", fork, fork + Vector((-0.2, -0.1, 0.55)), 0.035, MAT["stem"], 6)
    poses = [
        (0.3, 0.55, 1.9, 1.35, 0.7),
        (1.2, 0.9, 1.7, 1.2, 1.15),
        (2.1, 0.35, 1.85, 1.3, 1.4),
        (3.0, 1.1, 1.6, 1.15, 0.9),
        (4.0, 0.5, 1.55, 1.05, 1.6),
        (4.8, 1.4, 1.4, 1.0, 1.25),
        (5.6, 0.2, 1.45, 0.95, 1.85),
        (2.6, 2.2, 1.35, 0.9, 0.55),
        (0.9, 2.5, 1.25, 0.85, 1.35),
        (3.7, 2.7, 1.2, 0.8, 1.7),
    ]
    for i, (yaw, pitch, length, width, height) in enumerate(poses):
        origin = Vector((math.cos(yaw) * 0.16, math.sin(yaw) * 0.16, rim + height))
        direction = Vector((math.cos(yaw) * math.cos(pitch * 0.35), math.sin(yaw) * math.cos(pitch * 0.35), 0.55 - pitch * 0.15))
        stem(collection, f"FigPetiole{i}", origin - Vector((0, 0, 0.05)), origin + direction.normalized() * 0.22, 0.016, MAT["stem_green"])
        bm = lobed_leaf(length, width, lobes=5, curl=0.45 + rng.random() * 0.35, depth=0.55)
        place(bm, origin + direction.normalized() * 0.18, direction)
        new_object(collection, f"FigLeaf{i}", bm, MAT["leaf"] if i % 2 == 0 else MAT["leaf_light"])


def build_snake(collection):
    rim = pot(collection, "Snake", 0.5, 0.9, MAT["pot_cream"])
    rng = random.Random(11)
    for i in range(13):
        yaw = rng.random() * math.pi * 2
        lean = rng.uniform(0.05, 0.22)
        length = rng.uniform(1.5, 2.8)
        base = Vector((math.cos(yaw) * rng.uniform(0, 0.1), math.sin(yaw) * rng.uniform(0, 0.1), rim - 0.02))
        direction = Vector((math.cos(yaw) * lean, math.sin(yaw) * lean, 1))
        bm = lance(length, rng.uniform(0.16, 0.26), curl=lean * 0.8, thick=0.02)
        place(bm, base, direction)
        new_object(collection, f"SnakeBlade{i}", bm, MAT["snake"])


def build_fern(collection):
    """Boston fern: arching rachis with broad paired pinnae, cheap enough to keep whole."""
    rim = pot(collection, "Fern", 0.58, 0.95, MAT["pot_clay"])
    rng = random.Random(21)
    fronds = 9
    pairs = 8
    for i in range(fronds):
        yaw = i * (math.pi * 2 / fronds) + rng.uniform(-0.06, 0.06)
        droop = rng.uniform(0.55, 0.95)
        length = rng.uniform(0.85, 1.15)
        flat = Vector((math.cos(yaw), math.sin(yaw), 0))
        origin = Vector((math.cos(yaw) * 0.05, math.sin(yaw) * 0.05, rim - 0.01))
        mid = origin + flat * (length * 0.42) + Vector((0, 0, 0.42))
        tip = origin + flat * (length * 0.95) + Vector((0, 0, 0.08 * droop))
        stem(collection, f"FernRachis{i}a", origin, mid, 0.016, MAT["stem_green"], 5)
        stem(collection, f"FernRachis{i}b", mid, tip, 0.01, MAT["stem_green"], 5)
        side = Vector((-math.sin(yaw), math.cos(yaw), 0))
        for k in range(pairs):
            t = (k + 1) / (pairs + 1)
            centre = origin.lerp(mid, t / 0.5) if t < 0.5 else mid.lerp(tip, (t - 0.5) / 0.5)
            pin = 0.12 + 0.22 * math.sin(math.pi * t)
            for sign in (-1, 1):
                bm = lance(pin, pin * 0.48, curl=0.25, thick=0.012, steps=8, cuts=0)
                direction = side * sign * 0.85 + Vector((0, 0, 0.42)) + flat * 0.12
                place(bm, centre, direction)
                shade = MAT["leaf_light"] if (k + sign) % 2 == 0 else MAT["leaf"]
                new_object(collection, f"FernPin{i}_{k}_{sign}", bm, shade)


def build_hang(collection):
    rim = pot(collection, "Hang", 0.36, 0.5, MAT["pot_white"], segs=20)
    rng = random.Random(7)
    for vine in range(4):
        yaw = vine * 1.57 + 0.3
        drop = rng.uniform(2.6, 4.2)
        points = [Vector((math.cos(yaw) * 0.05, math.sin(yaw) * 0.05, rim - 0.02))]
        for s in range(1, 8):
            t = s / 7
            spread = 0.08 + t * rng.uniform(0.25, 0.55)
            twist = yaw + math.sin(t * 3) * 0.6
            sag = rim - (t ** 1.15) * drop
            points.append(Vector((math.cos(twist) * spread, math.sin(twist) * spread, sag)))
        for s in range(len(points) - 1):
            stem(collection, f"HangStem{vine}_{s}", points[s], points[s + 1], 0.014 * (1 - s * 0.07), MAT["stem_green"], 5)
            if s < 1:
                continue
            length = rng.uniform(0.34, 0.55) * (1.2 - s / 8)
            bm = heart_leaf(length, curl=0.85)
            side = Vector((-math.sin(yaw + s * 0.4), math.cos(yaw + s * 0.4), -0.35))
            place(bm, points[s], side)
            new_object(collection, f"HangLeaf{vine}_{s}", bm, MAT["leaf_light"] if s % 2 == 0 else MAT["leaf"])


def build_succulent(collection):
    rim = pot(collection, "Succ", 0.24, 0.34, MAT["pot_white"], segs=20)
    for ring, count, radius, lift, length in ((0, 10, 0.15, 0.0, 0.2), (1, 7, 0.09, 0.05, 0.15), (2, 5, 0.04, 0.09, 0.09)):
        for i in range(count):
            yaw = i / count * math.pi * 2 + ring * 0.35
            bm = lance(length, length * 0.62, curl=0.05, thick=0.035)
            direction = Vector((math.cos(yaw) * 0.55, math.sin(yaw) * 0.55, 0.85))
            origin = Vector((math.cos(yaw) * radius, math.sin(yaw) * radius, rim + lift))
            place(bm, origin, direction)
            new_object(collection, f"SuccLeaf{ring}_{i}", bm, MAT["blue"])


PLANTS = {
    "PlantFig": build_fig,
    "PlantSnake": build_snake,
    "PlantFern": build_fern,
    "PlantHang": build_hang,
    "PlantSucculent": build_succulent,
}

built = {}
for plant_name, builder in PLANTS.items():
    col = bpy.data.collections.new(plant_name)
    root.children.link(col)
    builder(col)
    built[plant_name] = col


def consolidate(collection, name, objects):
    if len(objects) <= 1:
        if objects:
            objects[0].name = name
            objects[0].data.name = name
        return
    bm = bmesh.new()
    for obj in objects:
        bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
    mat = objects[0].data.materials[0]
    created = new_object(collection, name, bm, mat)
    for obj in objects:
        mesh = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    created.name = name


for plant_name, col in built.items():
    groups = {"Pot": [], "Soil": [], "Foliage": [], "Stems": []}
    for obj in list(col.objects):
        lower = obj.name.lower()
        if lower.endswith("pot"):
            groups["Pot"].append(obj)
        elif "soil" in lower:
            groups["Soil"].append(obj)
        elif any(word in lower for word in ("stem", "trunk", "branch", "rachis", "petiole")):
            groups["Stems"].append(obj)
        else:
            groups["Foliage"].append(obj)
    prefix = plant_name.replace("Plant", "")
    consolidate(col, prefix + "Pot", groups["Pot"])
    consolidate(col, prefix + "Soil", groups["Soil"])
    consolidate(col, prefix + "Stems", groups["Stems"])
    consolidate(col, prefix + "Foliage", groups["Foliage"])

os.makedirs(OUT, exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
for plant_name, col in built.items():
    for obj in col.objects:
        obj.hide_set(False)
        obj.hide_render = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = col.objects[0]
    path = os.path.join(OUT, plant_name + ".fbx")
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_NONE",
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
        bake_space_transform=True,
        path_mode="STRIP",
        embed_textures=False,
        axis_forward="-Z",
        axis_up="Y",
    )
    for obj in col.objects:
        obj.select_set(False)
    tris = sum(sum(len(p.vertices) - 2 for p in obj.data.polygons) for obj in col.objects)
    print(plant_name, "tris", tris, "objects", [obj.name for obj in col.objects], "bytes", os.path.getsize(path))
    if plant_name == "PlantFern":
        pieces = []
        for obj in col.objects:
            mesh = obj.data
            verts = [[round(v.co.x, 5), round(v.co.z, 5), round(-v.co.y, 5)] for v in mesh.vertices]
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
            pieces.append({"name": obj.name, "verts": verts, "faces": faces})
        json_path = os.path.join(OUT, "PlantFern.json")
        with open(json_path, "w") as handle:
            json.dump(pieces, handle, separators=(",", ":"))
        print("PlantFern json", os.path.getsize(json_path), "faces", {p["name"]: len(p["faces"]) for p in pieces})

gaps = {"PlantFig": 0, "PlantSnake": 7, "PlantFern": 11.5, "PlantHang": 16, "PlantSucculent": 20}
for plant_name, col in built.items():
    for obj in col.objects:
        obj.location.x += gaps[plant_name]
