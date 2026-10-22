# Build stylized limb stills for Ink-Off design canvas.
# Run inside Blender via MCP / Text Editor.

import bpy
import bmesh
import math
import os
from mathutils import Vector

OUT_DIR = "/Users/jessicaarmitage/Desktop/ink-master/assets/limbs"
os.makedirs(OUT_DIR, exist_ok=True)

TONES = {
	"fair": (255 / 255, 224 / 255, 204 / 255),
	"light": (244 / 255, 204 / 255, 176 / 255),
	"peach": (232 / 255, 184 / 255, 150 / 255),
	"warm": (214 / 255, 158 / 255, 118 / 255),
	"tan": (186 / 255, 124 / 255, 86 / 255),
	"olive": (154 / 255, 110 / 255, 78 / 255),
	"brown": (112 / 255, 74 / 255, 52 / 255),
	"deep": (74 / 255, 50 / 255, 40 / 255),
}

REGIONS = [
	"LeftForearm",
	"LeftUpperArm",
	"LeftThigh",
	"LeftCalf",
	"Chest",
	"Back",
]


def reset_scene():
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete(use_global=False)
	for block in list(bpy.data.meshes):
		if block.users == 0:
			bpy.data.meshes.remove(block)
	for block in list(bpy.data.materials):
		if block.users == 0:
			bpy.data.materials.remove(block)
	for block in list(bpy.data.cameras):
		if block.users == 0:
			bpy.data.cameras.remove(block)
	for block in list(bpy.data.lights):
		if block.users == 0:
			bpy.data.lights.remove(block)

	scene = bpy.context.scene
	try:
		scene.render.engine = "BLENDER_EEVEE"
	except TypeError:
		scene.render.engine = "CYCLES"

	scene.render.resolution_x = 1024
	scene.render.resolution_y = 768
	scene.render.resolution_percentage = 100
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "RGB"
	scene.render.film_transparent = False
	scene.render.filepath = OUT_DIR + "/"

	if scene.world is None:
		scene.world = bpy.data.worlds.new("LimbWorld")
	world = scene.world
	world.use_nodes = True
	nt = world.node_tree
	nt.nodes.clear()
	bg = nt.nodes.new("ShaderNodeBackground")
	bg.inputs["Color"].default_value = (0.028, 0.03, 0.036, 1.0)
	bg.inputs["Strength"].default_value = 1.0
	out = nt.nodes.new("ShaderNodeOutputWorld")
	nt.links.new(bg.outputs["Background"], out.inputs["Surface"])


def skin_material(name, rgb):
	mat = bpy.data.materials.new(name=name)
	mat.use_nodes = True
	nodes = mat.node_tree.nodes
	links = mat.node_tree.links
	nodes.clear()
	out = nodes.new("ShaderNodeOutputMaterial")
	bsdf = nodes.new("ShaderNodeBsdfPrincipled")

	def set_in(key, val):
		if key in bsdf.inputs:
			bsdf.inputs[key].default_value = val

	set_in("Base Color", (*rgb, 1.0))
	set_in("Roughness", 0.52)
	set_in("Specular IOR Level", 0.22)
	if "Subsurface Weight" in bsdf.inputs:
		bsdf.inputs["Subsurface Weight"].default_value = 0.2
	elif "Subsurface" in bsdf.inputs:
		bsdf.inputs["Subsurface"].default_value = 0.14
	if "Subsurface Radius" in bsdf.inputs:
		bsdf.inputs["Subsurface Radius"].default_value = (1.0, 0.35, 0.2)
	if "Subsurface Color" in bsdf.inputs:
		bsdf.inputs["Subsurface Color"].default_value = (
			rgb[0] * 0.95,
			rgb[1] * 0.72,
			rgb[2] * 0.62,
			1.0,
		)
	links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
	return mat


def smooth_shade(obj):
	for poly in obj.data.polygons:
		poly.use_smooth = True
	mod = obj.modifiers.new("Subsurf", "SUBSURF")
	mod.levels = 2
	mod.render_levels = 3


def make_capsule(name, length, r_a, r_b, bend=0.0):
	mesh = bpy.data.meshes.new(name)
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.collection.objects.link(obj)
	bm = bmesh.new()
	segs = 20
	rings = 24
	for i in range(rings + 1):
		t = i / rings
		y = (t - 0.5) * length
		r = r_a * (1 - t) + r_b * t
		bulge = 1.0 + 0.1 * math.sin(t * math.pi)
		r *= bulge
		x_off = bend * math.sin(t * math.pi)
		for j in range(segs):
			a = (j / segs) * math.tau
			bm.verts.new((math.cos(a) * r + x_off, y, math.sin(a) * r * 0.92))
	bm.verts.ensure_lookup_table()
	for i in range(rings):
		for j in range(segs):
			v0 = i * segs + j
			v1 = i * segs + ((j + 1) % segs)
			v2 = (i + 1) * segs + ((j + 1) % segs)
			v3 = (i + 1) * segs + j
			bm.faces.new((bm.verts[v0], bm.verts[v1], bm.verts[v2], bm.verts[v3]))

	ct = bm.verts.new((0.0, -length / 2, 0.0))
	cb = bm.verts.new((bend * 0.0, length / 2, 0.0))
	bm.verts.ensure_lookup_table()
	for j in range(segs):
		a = bm.verts[j]
		b = bm.verts[(j + 1) % segs]
		bm.faces.new((ct, b, a))
		a2 = bm.verts[rings * segs + j]
		b2 = bm.verts[rings * segs + ((j + 1) % segs)]
		bm.faces.new((cb, a2, b2))

	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(mesh)
	bm.free()
	smooth_shade(obj)
	return obj


def make_bent_canvas(name, length, r_a, r_b, bend_deg=26, oval=0.48):
	"""Same path-ring construction as limbs; oval cross-section for torso canvas."""
	mesh = bpy.data.meshes.new(name)
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.collection.objects.link(obj)
	bm = bmesh.new()
	segs = 28
	rings = 40
	bend = math.radians(bend_deg)
	points = []
	for i in range(rings + 1):
		t = i / rings
		r = r_a * (1 - t) + r_b * t
		r *= 1.0 + 0.1 * math.sin(t * math.pi)
		if t <= 0.5:
			p = Vector(((t - 0.5) * length, 0, 0))
			tangent = Vector((1, 0, 0))
		else:
			u = (t - 0.5) / 0.5
			ang = bend * u
			along = (t - 0.5) * length
			p = Vector((along * math.cos(ang), 0, along * math.sin(ang)))
			tangent = Vector((math.cos(ang), 0, math.sin(ang)))
		points.append((p, tangent.normalized(), r))

	prev_n = Vector((0, 1, 0))
	ring_verts = []
	for p, tangent, r in points:
		binorm = tangent.cross(prev_n)
		if binorm.length < 1e-4:
			binorm = tangent.cross(Vector((0, 0, 1)))
		binorm.normalize()
		normal = binorm.cross(tangent).normalized()
		prev_n = normal
		row = []
		for j in range(segs):
			a = (j / segs) * math.tau
			offset = (math.cos(a) * r) * normal + (math.sin(a) * r * oval) * binorm
			row.append(bm.verts.new(p + offset))
		ring_verts.append(row)

	bm.verts.ensure_lookup_table()
	for i in range(len(ring_verts) - 1):
		for j in range(segs):
			v0 = ring_verts[i][j]
			v1 = ring_verts[i][(j + 1) % segs]
			v2 = ring_verts[i + 1][(j + 1) % segs]
			v3 = ring_verts[i + 1][j]
			bm.faces.new((v0, v1, v2, v3))

	for end_i, invert in ((0, True), (-1, False)):
		center = points[end_i][0]
		row = ring_verts[end_i]
		c = bm.verts.new(center)
		for j in range(segs):
			a = row[j]
			b = row[(j + 1) % segs]
			bm.faces.new((c, b, a) if invert else (c, a, b))

	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(mesh)
	bm.free()
	smooth_shade(obj)
	return obj


def add_area(name, loc, energy, size, rot, color=(1.0, 0.97, 0.93)):
	data = bpy.data.lights.new(name=name, type="AREA")
	data.energy = energy
	data.size = size
	data.color = color
	obj = bpy.data.objects.new(name, data)
	bpy.context.collection.objects.link(obj)
	obj.location = loc
	obj.rotation_euler = rot
	return obj


def setup_studio():
	add_area("Key", (2.4, -3.8, 2.2), 280, 3.8, (math.radians(55), 0, math.radians(-20)))
	add_area(
		"Fill",
		(-3.0, -2.8, 1.0),
		90,
		4.2,
		(math.radians(65), 0, math.radians(40)),
		(0.82, 0.88, 1.0),
	)
	add_area(
		"Rim",
		(0.2, 3.2, 1.8),
		140,
		2.8,
		(math.radians(115), 0, math.radians(180)),
		(1.0, 0.94, 0.88),
	)

	cam_data = bpy.data.cameras.new("LimbCam")
	cam_data.lens = 55
	cam = bpy.data.objects.new("LimbCam", cam_data)
	bpy.context.collection.objects.link(cam)
	cam.location = (0.0, -4.4, 0.1)
	cam.rotation_euler = (math.radians(90), 0, 0)
	bpy.context.scene.camera = cam
	return cam


def frame_object(obj, cam, margin=1.25):
	# Position camera so object fills ~4:3 frame along length
	bbox = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
	center = sum(bbox, Vector()) / 8.0
	dims = Vector(
		(
			max(v.x for v in bbox) - min(v.x for v in bbox),
			max(v.y for v in bbox) - min(v.y for v in bbox),
			max(v.z for v in bbox) - min(v.z for v in bbox),
		)
	)
	# Prefer fitting the longer on-screen axis
	span = max(dims.x, dims.z) * margin
	# lens 55mm ~ fov; approximate distance for orthographic-ish framing
	dist = max(3.2, span * 1.55)
	cam.location = (center.x, center.y - dist, center.z)
	cam.rotation_euler = (math.radians(90), 0, 0)


def assign_skin(obj, mat):
	obj.data.materials.clear()
	obj.data.materials.append(mat)


def build_limbs():
	limbs = {}
	limbs["LeftForearm"] = make_capsule("LeftForearm", 2.45, 0.27, 0.37, bend=0.14)
	limbs["LeftUpperArm"] = make_capsule("LeftUpperArm", 2.05, 0.44, 0.36, bend=0.08)
	limbs["LeftThigh"] = make_capsule("LeftThigh", 2.85, 0.56, 0.43, bend=0.05)
	limbs["LeftCalf"] = make_capsule("LeftCalf", 2.35, 0.31, 0.40, bend=0.11)
	limbs["Chest"] = make_bent_canvas("Chest", length=3.6, r_a=0.55, r_b=0.62, bend_deg=26, oval=0.48)
	limbs["Back"] = make_bent_canvas("Back", length=3.6, r_a=0.55, r_b=0.62, bend_deg=26, oval=0.48)

	for name, obj in limbs.items():
		# Orient so length is mostly vertical on screen (Z up in cam view after 90° X rot)
		obj.rotation_euler = (math.radians(90), 0, math.radians(-8 if "Left" in name else 0))
		obj.location = (0, 0, 0)
		obj.hide_render = True
		obj.hide_viewport = True
	return limbs


def set_visible(limbs, region):
	for name, obj in limbs.items():
		show = name == region
		obj.hide_render = not show
		obj.hide_viewport = not show


def render_all(limbs, mats, cam):
	scene = bpy.context.scene
	# Faster EEVEE
	if hasattr(scene.eevee, "taa_render_samples"):
		scene.eevee.taa_render_samples = 32

	written = []
	for region in REGIONS:
		set_visible(limbs, region)
		obj = limbs[region]
		frame_object(obj, cam)
		for tone, rgb in TONES.items():
			assign_skin(obj, mats[tone])
			# Force mesh update for material
			path = os.path.join(OUT_DIR, f"{region}_{tone}.png")
			scene.render.filepath = path
			bpy.ops.render.render(write_still=True)
			written.append(path)
			print("wrote", path)
	return written


def main():
	reset_scene()
	mats = {tone: skin_material(f"Skin_{tone}", rgb) for tone, rgb in TONES.items()}
	cam = setup_studio()
	limbs = build_limbs()
	# Preview peach forearm
	set_visible(limbs, "LeftForearm")
	assign_skin(limbs["LeftForearm"], mats["peach"])
	frame_object(limbs["LeftForearm"], cam)
	print("built limbs", list(limbs.keys()))
	print("tones", list(mats.keys()))
	return limbs, mats, cam


if __name__ == "__main__":
	main()
