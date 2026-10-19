--!strict

-- The fitted-out parlour inside the shell Lobby builds: finishes, joinery, fixtures,
-- furniture and the curated art. Gameplay pieces (Stations, ThemeBoard, spawns) are
-- built elsewhere; this module only dresses around them and reskins their parts.
-- Seats named WaitingSeat and ReceptionSeat are recreated here on purpose.

local ServerStorage = game:GetService("ServerStorage")

local Surfaces = require(script.Parent.Surfaces)

local P = Surfaces.part
local post = Surfaces.post
local ellipsoid = Surfaces.ellipsoid

local Interior = {}

local CEILING_Y = 16.2
local FLOOR_TOP = 0.4
local HALF_W = 34
local HALF_D = 27
local WALL = 1

local LEFT_FACE = -HALF_W + WALL / 2
local RIGHT_FACE = HALF_W - WALL / 2
local BACK_FACE = HALF_D - WALL / 2 - 0.18
local WORK_Z = -6.5
local WORK_TOP = FLOOR_TOP + 0.04

local ART = {
	tiger = "rbxassetid://78543816327515",
	koi = "rbxassetid://91875065450176",
	sheet = "rbxassetid://110813283705090",
	botanical = "rbxassetid://122988882422710",
	snake = "rbxassetid://126977067222162",
	swallows = "rbxassetid://95314818230148",
	panther = "rbxassetid://76985219251120",
	moth = "rbxassetid://94640584478787",
	rose = "rbxassetid://86726906730272",
	mandala = "rbxassetid://112478329760730",
}
local NEON_ART = "rbxassetid://80329829825351"
local RUG_ART = "rbxassetid://114513066068743"

local NEUTRAL = Color3.fromRGB(255, 246, 236)
local TASK = Color3.fromRGB(255, 249, 242)
local WARM = Color3.fromRGB(255, 204, 156)
local CREAM = Color3.fromRGB(236, 228, 212)
local INK = Color3.fromRGB(24, 24, 26)
local DARK_METAL = Color3.fromRGB(96, 96, 100)
local LEAF_GREEN = Color3.fromRGB(58, 86, 50)

local STATIONS = {
	{ index = 1, origin = Vector3.new(-23, FLOOR_TOP, 3), yaw = 0 },
	{ index = 2, origin = Vector3.new(-23, FLOOR_TOP, 16), yaw = 0 },
	{ index = 3, origin = Vector3.new(23, FLOOR_TOP, 3), yaw = math.pi },
	{ index = 4, origin = Vector3.new(23, FLOOR_TOP, 16), yaw = math.pi },
}

local function noShadow(tint: Color3?): Surfaces.Opts
	return { tint = tint, shadow = false }
end

-- A frame on a wall. cf sits on the wall surface with its front facing the room.
local function wallAt(wall: CFrame, u: number, y: number, out: number): CFrame
	return wall * CFrame.new(u, y, -out)
end

local function makeSeat(parent: Instance, name: string, size: Vector3, cframe: CFrame): Seat
	local seat = Instance.new("Seat")
	seat.Name = name
	seat.Anchored = true
	seat.Size = size
	seat.CFrame = cframe
	seat.Transparency = 1
	seat.CanCollide = true
	seat.CastShadow = false
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = parent
	return seat
end

------------------------------------------------------------------------------------------
-- Reskin of the shell and station parts Lobby already built

type Skin = { key: string, tint: Color3? }

local SKIN: { [string]: Skin } = {
	Floor = { key = "oak" },
	Ceiling = { key = "plaster", tint = Color3.fromRGB(136, 132, 128) },
	WallLeft = { key = "plaster" },
	WallRight = { key = "plaster" },
	WallBack = { key = "plaster" },
	Plaster = { key = "plaster" },
	LoungeWall = { key = "oxblood" },
	WindowSill = { key = "walnut" },
	Mullion = { key = "powder" },
	WindowFrame = { key = "powder" },
	DoorRail = { key = "powder" },
	DoorHead = { key = "powder" },
	Threshold = { key = "brass" },
	ThemeFrame = { key = "walnut" },
	StagePost = { key = "powder" },
	StageLintel = { key = "powder" },
	BoardLight = { key = "powder" },
	DoorLeaf = { key = "walnut" },
	DoorPull = { key = "brass" },
	BedLeg = { key = "steel" },
	SideRail = { key = "steel" },
	ArmPost = { key = "steel" },
	StoolPole = { key = "steel" },
	Tray = { key = "steel" },
	LampPole = { key = "powder" },
	LampArm = { key = "powder" },
	BedFrame = { key = "powder" },
	Mattress = { key = "leather" },
	Headboard = { key = "leather" },
	Footboard = { key = "leather" },
	Armrest = { key = "leather" },
	ArtistStool = { key = "leather" },
	StationMat = { key = "rubber", tint = Color3.fromRGB(34, 34, 36) },
	Sheet = { key = "fabric", tint = Color3.fromRGB(236, 236, 232) },
	Pillow = { key = "fabric", tint = Color3.fromRGB(226, 226, 222) },
}

local function restyle(lobby: Model)
	for _, folderName in { "Shell", "Entrance", "Stations" } do
		local folder = lobby:FindFirstChild(folderName)
		if folder == nil then
			continue
		end
		for _, item in folder:GetDescendants() do
			if not item:IsA("BasePart") then
				local holder = item.Parent
				local holderName = if holder then holder.Name else ""
				if item:IsA("SpotLight") and holderName == "BoardLight" then
					item.Color = NEUTRAL
					item.Brightness = 1.9
					item.Angle = 44
				end
				if item:IsA("Light") and holderName == "LampBulb" then
					item.Color = TASK
				end
				continue
			end
			if item:IsA("Seat") then
				Surfaces.apply(item, "leather")
				continue
			end
			local skin = SKIN[item.Name]
			if skin then
				Surfaces.apply(item, skin.key, skin.tint)
			end
			if item.Name == "BrickFeature" then
				item.Color = Color3.fromRGB(116, 74, 62)
			elseif item.Name == "StationMat" then
				item.CFrame += Vector3.new(0, 0.05, 0)
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Floors, walls and ceiling

local function buildFloorZones(root: Instance)
	local floors = Surfaces.folder(root, "Floors")
	local width = HALF_W * 2 - WALL - 0.2
	local depth = BACK_FACE - WORK_Z
	P(
		floors,
		"WorkFloor",
		Vector3.new(width, 0.04, depth),
		CFrame.new(0, FLOOR_TOP + 0.02, WORK_Z + depth / 2),
		"concrete",
		{ collide = true }
	)
	local joint = Color3.fromRGB(64, 62, 60)
	for _, x in { -11.5, 11.5 } do
		P(
			floors,
			"SawCut",
			Vector3.new(0.05, 0.004, depth - 0.2),
			CFrame.new(x, WORK_TOP + 0.002, WORK_Z + depth / 2),
			"paint",
			noShadow(joint)
		)
	end
	P(
		floors,
		"SawCut",
		Vector3.new(width - 0.2, 0.004, 0.05),
		CFrame.new(0, WORK_TOP + 0.002, 9.5),
		"paint",
		noShadow(joint)
	)
	P(
		floors,
		"ZoneStrip",
		Vector3.new(width, 0.05, 0.14),
		CFrame.new(0, FLOOR_TOP + 0.025, WORK_Z),
		"brass",
		noShadow()
	)

	P(
		floors,
		"EntryMat",
		Vector3.new(8.6, 0.05, 3.8),
		CFrame.new(0, FLOOR_TOP + 0.025, -24.2),
		"rubber",
		noShadow(Color3.fromRGB(34, 32, 30))
	)
	P(
		floors,
		"EntryMatCoir",
		Vector3.new(8.0, 0.056, 3.2),
		CFrame.new(0, FLOOR_TOP + 0.028, -24.2),
		"fabric",
		noShadow(Color3.fromRGB(88, 72, 54))
	)
end

-- Walnut wainscot with powder-coated skirting, the joinery that ties the room together.
local function buildDado(root: Instance)
	local dado = Surfaces.folder(root, "Dado")
	local runs = {
		{ x = LEFT_FACE, normal = 1, z0 = -26.2, z1 = 26.3 },
		{ x = RIGHT_FACE, normal = -1, z0 = -7.6, z1 = 26.3 },
	}
	for _, run in runs do
		local length = run.z1 - run.z0
		local zc = (run.z0 + run.z1) / 2
		local n = run.normal
		local floorY = if run.z0 > WORK_Z then WORK_TOP else FLOOR_TOP
		P(dado, "Skirting", Vector3.new(0.16, 0.55, length), CFrame.new(run.x + n * 0.08, floorY + 0.275, zc), "powder")
		P(
			dado,
			"DadoPanel",
			Vector3.new(0.08, 3.0, length),
			CFrame.new(run.x + n * 0.04, floorY + 0.55 + 1.5, zc),
			"walnut",
			{
				tint = Color3.fromRGB(236, 226, 216),
			}
		)
		P(dado, "DadoCap", Vector3.new(0.24, 0.18, length), CFrame.new(run.x + n * 0.12, floorY + 3.64, zc), "walnut")
		local count = math.floor(length / 2.6)
		for i = 0, count do
			local z = run.z0 + 0.1 + i * (length - 0.2) / count
			P(
				dado,
				"DadoStile",
				Vector3.new(0.14, 3.0, 0.2),
				CFrame.new(run.x + n * 0.1, floorY + 0.55 + 1.5, z),
				"walnut",
				noShadow()
			)
		end
	end
end

local function hang(parent: Instance, from: Vector3, toY: number)
	local length = CEILING_Y - toY
	P(
		parent,
		"Cable",
		Vector3.new(0.04, length, 0.04),
		CFrame.new(from.X, toY + length / 2, from.Z),
		"paint",
		noShadow(INK)
	)
end

local function buildCeiling(root: Instance)
	local ceiling = Surfaces.folder(root, "Ceiling")
	local beam = Color3.fromRGB(88, 88, 92)
	local span = HALF_W * 2 - WALL
	for _, z in { -13, 3, 19 } do
		P(
			ceiling,
			"BeamFlange",
			Vector3.new(span, 0.1, 0.8),
			CFrame.new(0, CEILING_Y - 0.05, z),
			"powder",
			noShadow(beam)
		)
		P(
			ceiling,
			"BeamWeb",
			Vector3.new(span, 1.0, 0.14),
			CFrame.new(0, CEILING_Y - 0.6, z),
			"powder",
			{ tint = beam }
		)
		P(
			ceiling,
			"BeamFlange",
			Vector3.new(span, 0.1, 0.8),
			CFrame.new(0, CEILING_Y - 1.15, z),
			"powder",
			{ tint = beam }
		)
	end

	-- Galvanised supply duct, off-centre so the ceiling doesn't mirror the floor plan.
	local ductX, ductY, ductZ0, ductZ1 = -10, 14.1, -25.4, 26
	P(
		ceiling,
		"Duct",
		Vector3.new(ductZ1 - ductZ0, 1.5, 1.5),
		CFrame.new(ductX, ductY, (ductZ0 + ductZ1) / 2) * CFrame.Angles(0, math.pi / 2, 0),
		"steel",
		{ shape = Enum.PartType.Cylinder, tint = Color3.fromRGB(196, 198, 200) }
	)
	for _, z in { -22, -8, 8, 23 } do
		P(
			ceiling,
			"DuctBand",
			Vector3.new(0.12, 1.56, 1.56),
			CFrame.new(ductX, ductY, z) * CFrame.Angles(0, math.pi / 2, 0),
			"steel",
			{
				shape = Enum.PartType.Cylinder,
				tint = Color3.fromRGB(150, 152, 154),
				shadow = false,
			}
		)
		P(
			ceiling,
			"DuctHanger",
			Vector3.new(0.06, CEILING_Y - ductY, 0.12),
			CFrame.new(ductX + 0.78, (CEILING_Y + ductY) / 2, z),
			"steel",
			noShadow()
		)
		P(
			ceiling,
			"DuctHanger",
			Vector3.new(0.06, CEILING_Y - ductY, 0.12),
			CFrame.new(ductX - 0.78, (CEILING_Y + ductY) / 2, z),
			"steel",
			noShadow()
		)
	end
	for _, z in { -17, 0, 15 } do
		post(
			ceiling,
			"Diffuser",
			0.35,
			1.0,
			Vector3.new(ductX, ductY - 1.05, z),
			"steel",
			noShadow(Color3.fromRGB(170, 172, 174))
		)
		post(
			ceiling,
			"DiffuserGrille",
			0.02,
			0.92,
			Vector3.new(ductX, ductY - 1.07, z),
			"paint",
			noShadow(Color3.fromRGB(40, 40, 42))
		)
	end

	-- Linear pendants across the aisle, so from the door they read as horizontal bands
	-- instead of stripes pointing at the theme board.
	for _, z in { -13, 3, 11.5 } do
		local y = 13.4
		P(ceiling, "LinearHousing", Vector3.new(10, 0.3, 0.42), CFrame.new(0, y, z), "powder", noShadow())
		local diffuser = P(
			ceiling,
			"LinearDiffuser",
			Vector3.new(9.8, 0.04, 0.3),
			CFrame.new(0, y - 0.17, z),
			"neon",
			noShadow(Color3.fromRGB(214, 210, 204))
		)
		Surfaces.wash(diffuser, Enum.NormalId.Bottom, NEUTRAL, 1.6, 16, 120, false)
		hang(ceiling, Vector3.new(-4.5, 0, z), y + 0.15)
		hang(ceiling, Vector3.new(4.5, 0, z), y + 0.15)
	end

	local smoke = Color3.fromRGB(232, 232, 228)
	for _, spot in { Vector3.new(-14, 0, -6), Vector3.new(14, 0, 9), Vector3.new(-4, 0, 21) } do
		post(
			ceiling,
			"SmokeDetector",
			0.14,
			0.6,
			Vector3.new(spot.X, CEILING_Y - 0.14, spot.Z),
			"paint",
			noShadow(smoke)
		)
	end
end

------------------------------------------------------------------------------------------
-- Art

local function artwork(
	parent: Instance,
	cf: CFrame,
	width: number,
	height: number,
	image: string,
	finish: string,
	lit: boolean
)
	local frame = Surfaces.folder(parent, "Artwork")
	local border = 0.16
	local depth = 0.16
	local matInset = math.min(width, height) * 0.1
	P(frame, "ArtMat", Vector3.new(width, height, 0.05), cf * CFrame.new(0, 0, -0.035), "paint", noShadow(CREAM))
	local art = P(
		frame,
		"Art",
		Vector3.new(width - matInset * 2, height - matInset * 2, 0.02),
		cf * CFrame.new(0, 0, -0.07),
		"paint",
		noShadow(CREAM)
	)
	Surfaces.decal(art, Enum.NormalId.Front, image)
	local outerW, outerH = width + border * 2, height + border * 2
	for _, side in { -1, 1 } do
		P(
			frame,
			"Moulding",
			Vector3.new(outerW, border, depth),
			cf * CFrame.new(0, side * (height / 2 + border / 2), -depth / 2),
			finish
		)
		P(
			frame,
			"Moulding",
			Vector3.new(border, outerH, depth),
			cf * CFrame.new(side * (width / 2 + border / 2), 0, -depth / 2),
			finish
		)
	end
	if lit then
		local barY = outerH / 2 + 0.22
		P(frame, "PictureLightArm", Vector3.new(0.06, 0.06, 0.5), cf * CFrame.new(0, barY, -0.25), "brass", noShadow())
		local bar = P(
			frame,
			"PictureLight",
			Vector3.new(math.min(width * 0.55, 2.4), 0.12, 0.14),
			cf * CFrame.new(0, barY, -0.52) * CFrame.Angles(-0.5, 0, 0),
			"brass",
			noShadow()
		)
		Surfaces.spot(bar, Enum.NormalId.Bottom, Color3.fromRGB(255, 226, 194), 1.6, height + 2.5, 75, false)
	end
end

local function backWall(x: number, y: number): CFrame
	return CFrame.lookAt(Vector3.new(x, y, BACK_FACE), Vector3.new(x, y, BACK_FACE - 1))
end

local function sideWall(side: number, y: number, z: number, out: number?): CFrame
	local x = if side < 0 then LEFT_FACE else RIGHT_FACE
	local origin = Vector3.new(x - side * (out or 0), y, z)
	return CFrame.lookAt(origin, origin + Vector3.new(-side, 0, 0))
end

------------------------------------------------------------------------------------------
-- Plants

local function plant(
	parent: Instance,
	base: Vector3,
	potDiameter: number,
	potHeight: number,
	potKey: string,
	potTint: Color3?,
	crown: number,
	kind: string,
	seed: number
)
	local group = Surfaces.folder(parent, "Plant")
	local rng = Random.new(seed)
	post(group, "Planter", potHeight, potDiameter, base, potKey, { tint = potTint, collide = potDiameter > 1.2 })
	post(
		group,
		"PlanterLip",
		0.1,
		potDiameter + 0.08,
		base + Vector3.new(0, potHeight - 0.1, 0),
		potKey,
		noShadow(potTint)
	)
	post(
		group,
		"Soil",
		0.04,
		potDiameter - 0.12,
		base + Vector3.new(0, potHeight - 0.08, 0),
		"ground",
		noShadow(Color3.fromRGB(46, 36, 28))
	)
	local top = base + Vector3.new(0, potHeight - 0.06, 0)

	if kind == "fig" then
		local trunk = crown * 0.55
		post(group, "Trunk", trunk, 0.14, top, "paint", noShadow(Color3.fromRGB(86, 70, 54)))
		for i = 1, 26 do
			local t = (i - 1) / 25
			local yaw = i * 2.4 + rng:NextNumber(-0.3, 0.3)
			local y = trunk * 0.45 + t * crown * 0.62
			local reach = 0.35 + (1 - math.abs(t - 0.45)) * crown * 0.16
			local stem = top + Vector3.new(math.cos(yaw) * reach, y, math.sin(yaw) * reach)
			local leafCf = CFrame.new(stem)
				* CFrame.Angles(0, -yaw + math.pi / 2, 0)
				* CFrame.Angles(rng:NextNumber(0.5, 1.0), 0, rng:NextNumber(-0.25, 0.25))
			local size = rng:NextNumber(0.85, 1.15)
			local shade = LEAF_GREEN:Lerp(Color3.fromRGB(84, 112, 62), rng:NextNumber(0, 0.6))
			ellipsoid(group, "Leaf", Vector3.new(0.85 * size, 0.06, 1.25 * size), leafCf, "leaf", noShadow(shade))
		end
	elseif kind == "snake" then
		for _ = 1, 11 do
			local yaw = rng:NextNumber(0, math.pi * 2)
			local lean = rng:NextNumber(0.02, 0.22)
			local h = crown * rng:NextNumber(0.55, 1.0)
			local offset = Vector3.new(math.cos(yaw), 0, math.sin(yaw)) * rng:NextNumber(0, potDiameter * 0.25)
			local cf = CFrame.new(top + offset)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(lean, 0, 0)
				* CFrame.new(0, h / 2, 0)
			local shade = Color3.fromRGB(46, 72, 44):Lerp(Color3.fromRGB(96, 116, 64), rng:NextNumber(0, 0.5))
			ellipsoid(group, "Blade", Vector3.new(0.32, h, 0.07), cf, "leaf", noShadow(shade))
		end
	elseif kind == "fern" then
		for i = 1, 14 do
			local yaw = i * 0.48 + rng:NextNumber(-0.1, 0.1)
			local lean = rng:NextNumber(0.35, 1.05)
			local length = crown * rng:NextNumber(0.55, 1)
			local frond = CFrame.new(top)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(lean, 0, 0)
				* CFrame.new(0, length * 0.28, length * 0.22)
			local shade = Color3.fromRGB(48, 92, 46):Lerp(Color3.fromRGB(110, 140, 62), rng:NextNumber(0, 0.7))
			ellipsoid(group, "Frond", Vector3.new(0.28, 0.04, length), frond, "leaf", noShadow(shade))
		end
	elseif kind == "trailing" then
		for _ = 1, 24 do
			local yaw = rng:NextNumber(0, math.pi * 2)
			local drop = rng:NextNumber(0, crown)
			local reach = potDiameter / 2 + 0.05 + drop * 0.1
			local spot = top + Vector3.new(math.cos(yaw) * reach, 0.1 - drop, math.sin(yaw) * reach)
			local shade = Color3.fromRGB(70, 104, 54):Lerp(Color3.fromRGB(122, 140, 70), rng:NextNumber(0, 0.5))
			local size = rng:NextNumber(0.85, 1.25)
			ellipsoid(
				group,
				"Leaf",
				Vector3.new(0.42 * size, 0.05, 0.62 * size),
				CFrame.new(spot) * CFrame.Angles(rng:NextNumber(-1.2, 1.2), yaw, 0.6),
				"leaf",
				noShadow(shade)
			)
		end
	else
		for i = 1, 9 do
			local yaw = i * 2.4
			local r = 0.08 + (i / 9) * potDiameter * 0.3
			local spot = top + Vector3.new(math.cos(yaw) * r, 0.08, math.sin(yaw) * r)
			ellipsoid(
				group,
				"Rosette",
				Vector3.new(0.18, 0.1, 0.34),
				CFrame.new(spot) * CFrame.Angles(0, -yaw, 0) * CFrame.Angles(0.5, 0, 0),
				"leaf",
				noShadow(Color3.fromRGB(104, 132, 102))
			)
		end
	end
end

------------------------------------------------------------------------------------------
-- Station bays

local function bayFin(parent: Instance, side: number, z: number)
	local fin = Surfaces.folder(parent, "BayDivider")
	local wallX = if side < 0 then LEFT_FACE else RIGHT_FACE
	local innerX = side * 27.2
	local length = math.abs(wallX - innerX) - 0.1
	local cx = (wallX + innerX) / 2
	local height = 7.4
	P(fin, "DividerBase", Vector3.new(length, 0.22, 0.38), CFrame.new(cx, WORK_TOP + 0.11, z), "powder")
	P(fin, "DividerRail", Vector3.new(length, 0.2, 0.38), CFrame.new(cx, WORK_TOP + height - 0.1, z), "walnut")
	local slats = 13
	for i = 0, slats - 1 do
		local x = wallX - side * (0.35 + i * (length - 0.7) / (slats - 1))
		P(fin, "DividerSlat", Vector3.new(0.22, height - 0.42, 0.3), CFrame.new(x, WORK_TOP + height / 2, z), "walnut")
	end
	P(
		fin,
		"DividerPost",
		Vector3.new(0.3, height + 0.2, 0.42),
		CFrame.new(innerX, WORK_TOP + height / 2 + 0.1, z),
		"powder",
		{ collide = true }
	)
end

local function trayStand(parent: Instance, cf: CFrame, accent: Color3)
	local stand = Surfaces.folder(parent, "TrayStand")
	for _, angle in { 0, math.pi / 2 } do
		P(
			stand,
			"CasterBase",
			Vector3.new(1.3, 0.08, 0.12),
			cf * CFrame.new(0, 0.18, 0) * CFrame.Angles(0, angle + 0.4, 0),
			"powder"
		)
	end
	for i = 0, 3 do
		local a = 0.4 + i * math.pi / 2
		ellipsoid(
			stand,
			"Caster",
			Vector3.new(0.16, 0.16, 0.16),
			cf * CFrame.new(math.cos(a) * 0.6, 0.08, math.sin(a) * 0.6),
			"rubber",
			noShadow(INK)
		)
	end
	local pole = cf * CFrame.new(0, 0.2, 0)
	post(stand, "TrayPole", 3.0, 0.1, pole.Position, "steel")
	local tray = cf * CFrame.new(0, 3.25, 0)
	P(stand, "WorkTray", Vector3.new(1.6, 0.05, 1.05), tray, "steel")
	for _, side in { -1, 1 } do
		P(stand, "TrayLip", Vector3.new(1.6, 0.1, 0.04), tray * CFrame.new(0, 0.07, side * 0.51), "steel", noShadow())
		P(stand, "TrayLip", Vector3.new(0.04, 0.1, 1.05), tray * CFrame.new(side * 0.78, 0.07, 0), "steel", noShadow())
	end
	P(
		stand,
		"BarrierFilm",
		Vector3.new(1.5, 0.005, 0.95),
		tray * CFrame.new(0, 0.03, 0),
		"glass",
		{ transparency = 0.6, shadow = false }
	)
	P(
		stand,
		"PenMachine",
		Vector3.new(0.62, 0.13, 0.13),
		tray * CFrame.new(-0.25, 0.1, -0.2) * CFrame.Angles(0, 0.35, 0),
		"powder",
		{
			shape = Enum.PartType.Cylinder,
			tint = accent,
			shadow = false,
		}
	)
	P(
		stand,
		"PenGrip",
		Vector3.new(0.3, 0.1, 0.1),
		tray * CFrame.new(-0.62, 0.1, -0.33) * CFrame.Angles(0, 0.35, 0),
		"steel",
		{
			shape = Enum.PartType.Cylinder,
			shadow = false,
		}
	)
	local caps = { INK, INK, Color3.fromRGB(120, 24, 28), Color3.fromRGB(40, 70, 120), Color3.fromRGB(60, 60, 62) }
	for i, color in caps do
		post(
			stand,
			"InkCap",
			0.08,
			0.1,
			(tray * CFrame.new(0.15 + i * 0.12, 0.025, 0.3)).Position,
			"paint",
			noShadow(color)
		)
	end
	post(stand, "RinseBottle", 0.5, 0.22, (tray * CFrame.new(0.55, 0.025, -0.25)).Position, "glass", {
		tint = Color3.fromRGB(150, 196, 168),
		transparency = 0.25,
		shadow = false,
	})
	post(
		stand,
		"Ointment",
		0.14,
		0.24,
		(tray * CFrame.new(0.2, 0.025, -0.3)).Position,
		"paint",
		noShadow(Color3.fromRGB(240, 238, 232))
	)
	P(
		stand,
		"TowelSquares",
		Vector3.new(0.5, 0.06, 0.5),
		tray * CFrame.new(-0.35, 0.055, 0.25) * CFrame.Angles(0, 0.2, 0),
		"fabric",
		noShadow(Color3.fromRGB(150, 184, 214))
	)
end

local function bayKit(
	parent: Instance,
	station: { index: number, origin: Vector3, yaw: number },
	image: string,
	imageW: number,
	imageH: number,
	finish: string
)
	local bay = Surfaces.folder(parent, `Bay{station.index}`)
	local side = if station.origin.X < 0 then -1 else 1
	local z = station.origin.Z
	local wall = sideWall(side, 0, z)

	-- Overhead task light: the one place a hard, neutral, shadow-casting light belongs.
	local taskY = 11.1
	local panelPos = Vector3.new(station.origin.X - side * 0.4, taskY, z)
	P(bay, "TaskPanel", Vector3.new(2.6, 0.16, 4.6), CFrame.new(panelPos), "powder", noShadow())
	local diffuser = P(
		bay,
		"TaskDiffuser",
		Vector3.new(2.4, 0.03, 4.4),
		CFrame.new(panelPos - Vector3.new(0, 0.09, 0)),
		"neon",
		noShadow(Color3.fromRGB(206, 204, 200))
	)
	Surfaces.spot(diffuser, Enum.NormalId.Bottom, TASK, 2.4, 15, 80, true)
	hang(bay, panelPos + Vector3.new(0, 0, -2), taskY + 0.08)
	hang(bay, panelPos + Vector3.new(0, 0, 2), taskY + 0.08)

	artwork(bay, wallAt(wall, 1.6, 8.4, 0), imageW, imageH, image, finish, true)

	local plate = P(bay, "BayPlate", Vector3.new(1.9, 0.5, 0.05), wallAt(wall, -3.4, 9.6, 0.03), "powder", noShadow())
	Surfaces.label(
		plate,
		Enum.NormalId.Front,
		`STATION 0{station.index}`,
		Color3.fromRGB(220, 196, 150),
		Enum.Font.GothamMedium,
		64
	)

	local shelfCf = wallAt(wall, -3.4, 5.1, 0.5)
	P(bay, "WallShelf", Vector3.new(3.4, 0.08, 1.0), shelfCf, "steel")
	for _, u in { -1.4, 1.4 } do
		P(bay, "ShelfBracket", Vector3.new(0.06, 0.5, 0.9), shelfCf * CFrame.new(u, -0.29, 0.03), "steel", noShadow())
	end
	local inks = {
		INK,
		INK,
		Color3.fromRGB(28, 30, 34),
		Color3.fromRGB(128, 22, 26),
		Color3.fromRGB(36, 64, 118),
		Color3.fromRGB(46, 92, 52),
		Color3.fromRGB(196, 150, 40),
	}
	for i, color in inks do
		local spot = shelfCf * CFrame.new(-1.5 + i * 0.3, 0.04, -0.1)
		post(bay, "InkBottle", 0.42, 0.2, spot.Position, "glass", { tint = color, transparency = 0.1, shadow = false })
		post(bay, "InkLid", 0.1, 0.12, spot.Position + Vector3.new(0, 0.42, 0), "paint", noShadow(INK))
	end
	P(bay, "PowerSupply", Vector3.new(0.7, 0.3, 0.5), shelfCf * CFrame.new(1.05, 0.19, 0.1), "powder", noShadow())
	local readout = P(
		bay,
		"PowerReadout",
		Vector3.new(0.34, 0.12, 0.01),
		shelfCf * CFrame.new(1.0, 0.2, -0.155),
		"paint",
		noShadow(INK)
	)
	Surfaces.label(readout, Enum.NormalId.Front, "8.4V", Color3.fromRGB(255, 92, 72), Enum.Font.Code, 96, 0)

	local gloves = wallAt(wall, -3.4, 7.15, 0.02)
	P(bay, "GloveRack", Vector3.new(1.7, 1.1, 0.04), gloves, "steel", noShadow())
	local boxColors = { Color3.fromRGB(92, 70, 150), Color3.fromRGB(48, 82, 152), INK }
	for i, color in boxColors do
		P(
			bay,
			"GloveBox",
			Vector3.new(0.48, 0.95, 0.4),
			gloves * CFrame.new(-0.56 + (i - 1) * 0.56, 0, -0.22),
			"paint",
			noShadow(color)
		)
		P(
			bay,
			"GloveSlot",
			Vector3.new(0.3, 0.06, 0.01),
			gloves * CFrame.new(-0.56 + (i - 1) * 0.56, -0.3, -0.425),
			"paint",
			noShadow(Color3.fromRGB(240, 240, 240))
		)
	end

	local roll = wallAt(wall, 4.8, 4.3, 0.45)
	P(bay, "RollHolder", Vector3.new(1.6, 0.06, 0.06), roll * CFrame.new(0, 0, 0.3), "steel", noShadow())
	P(bay, "TowelRoll", Vector3.new(1.4, 0.68, 0.68), roll, "fabric", {
		shape = Enum.PartType.Cylinder,
		tint = Color3.fromRGB(150, 184, 214),
		shadow = false,
	})

	local sharps = wallAt(wall, 4.8, 5.85, 0.26)
	P(bay, "SharpsBin", Vector3.new(0.7, 0.8, 0.5), sharps, "paint", noShadow(Color3.fromRGB(176, 30, 30)))
	P(
		bay,
		"SharpsLid",
		Vector3.new(0.72, 0.14, 0.52),
		sharps * CFrame.new(0, 0.45, 0),
		"paint",
		noShadow(Color3.fromRGB(226, 186, 34))
	)

	for _, u in { -1.2, 4.2 } do
		P(
			bay,
			"Outlet",
			Vector3.new(0.38, 0.6, 0.03),
			wallAt(wall, u, 1.8, 0.27),
			"paint",
			noShadow(Color3.fromRGB(234, 232, 226))
		)
	end

	local stationCf = CFrame.new(station.origin) * CFrame.Angles(0, station.yaw, 0)
	trayStand(
		bay,
		stationCf * CFrame.new(2.75, WORK_TOP - FLOOR_TOP, 2.8),
		if station.index % 2 == 0 then Color3.fromRGB(120, 24, 28) else INK
	)
end

local function buildBays(root: Instance)
	local bays = Surfaces.folder(root, "Bays")
	for _, side in { -1, 1 } do
		for _, z in { -3.5, 9.5, 22.5 } do
			bayFin(bays, side, z)
		end
	end
	local art: { { image: string, w: number, h: number, finish: string } } = {
		{ image = ART.panther, w = 3.0, h = 4.0, finish = "powder" },
		{ image = ART.rose, w = 3.0, h = 4.0, finish = "walnut" },
		{ image = ART.swallows, w = 4.0, h = 3.0, finish = "brass" },
		{ image = ART.snake, w = 3.0, h = 4.0, finish = "powder" },
	}
	for i, station in STATIONS do
		local piece = art[i]
		bayKit(bays, station, piece.image, piece.w, piece.h, piece.finish)
	end
end

------------------------------------------------------------------------------------------
-- Reception: the hero joinery piece visitors meet on the way in

-- The Blender desk (blender-out/ReceptionDesk.fbx) arrives at whatever scale and facing
-- the importer chose. Turn it so the long side runs along cf's right vector and the
-- fluted DeskFront faces cf's look vector, then size it to length and stand it on the floor.
local HERO_SKIN: { [string]: string } = {
	DeskFront = "walnut",
	DeskBody = "walnut",
	DeskTop = "stone",
	DeskTrim = "brass",
	DeskPlinth = "powder",
}

local function extents(model: Model, axis: Vector3): (number, number)
	local low, high = math.huge, -math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			local reach = math.abs(part.CFrame.RightVector:Dot(axis)) * half.X
				+ math.abs(part.CFrame.UpVector:Dot(axis)) * half.Y
				+ math.abs(part.CFrame.LookVector:Dot(axis)) * half.Z
			local center = part.Position:Dot(axis)
			low = math.min(low, center - reach)
			high = math.max(high, center + reach)
		end
	end
	return low, high
end

local function placeHeroDesk(hero: Model, cf: CFrame, length: number, parent: Instance): boolean
	local copy = hero:Clone()
	local front: BasePart? = nil
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanTouch = false
			local key = HERO_SKIN[part.Name]
			if key then
				Surfaces.apply(part, key)
				part.CanCollide = key ~= "brass"
			end
			if part.Name == "DeskFront" then
				front = part
			end
		elseif part:IsA("Script") or part:IsA("LocalScript") then
			part:Destroy()
		end
	end
	if front == nil then
		copy:Destroy()
		warn("[InkMasters] ParlourImport.ReceptionDesk has no DeskFront mesh; using the built desk")
		return false
	end

	copy:PivotTo(cf)
	local r0, r1 = extents(copy, cf.RightVector)
	local l0, l1 = extents(copy, cf.LookVector)
	if l1 - l0 > r1 - r0 then
		copy:PivotTo(copy:GetPivot() * CFrame.Angles(0, math.pi / 2, 0))
		r0, r1 = extents(copy, cf.RightVector)
	end
	if r1 - r0 > 0 then
		copy:ScaleTo(copy:GetScale() * length / (r1 - r0))
	end
	local f0, f1 = extents(copy, cf.LookVector)
	if front.Position:Dot(cf.LookVector) < (f0 + f1) / 2 then
		copy:PivotTo(copy:GetPivot() * CFrame.Angles(0, math.pi, 0))
	end

	local x0, x1 = extents(copy, cf.RightVector)
	local z0, z1 = extents(copy, cf.LookVector)
	local y0 = select(1, extents(copy, Vector3.yAxis))
	local want = cf.Position
	local shift = cf.RightVector * (want:Dot(cf.RightVector) - (x0 + x1) / 2)
		+ cf.LookVector * (want:Dot(cf.LookVector) + 0.05 - (z0 + z1) / 2)
		+ Vector3.yAxis * (want.Y - y0)
	copy:PivotTo(copy:GetPivot() + shift)
	copy.Name = "ReceptionDesk"
	copy.Parent = parent
	return true
end

local function buildReception(root: Instance)
	local desk = Surfaces.folder(root, "Reception")
	local origin = Vector3.new(24.6, FLOOR_TOP, -16.4)
	-- Customer side faces the aisle (-X). Local +X runs toward the street, +Z toward the staff.
	local cf = CFrame.lookAt(origin, origin + Vector3.new(-1, 0, 0))
	local L = 11

	local import = ServerStorage:FindFirstChild("ParlourImport")
	local hero = import and import:FindFirstChild("ReceptionDesk")
	-- The Blender desk is 11.4 studs end to end including the ledge overhang.
	if hero and hero:IsA("Model") and placeHeroDesk(hero, cf, 11.4, desk) then
		local glow = P(desk, "LedgeGlow", Vector3.new(L - 0.6, 0.05, 1.0), cf * CFrame.new(0, 3.3, -0.85), "paint", {
			transparency = 1,
			shadow = false,
		})
		Surfaces.wash(glow, Enum.NormalId.Bottom, Color3.fromRGB(255, 208, 164), 0.9, 4, 150, false)
	else
		P(
			desk,
			"DeskPlinth",
			Vector3.new(L - 0.4, 0.32, 2.5),
			cf * CFrame.new(0, 0.16, 0.25),
			"powder",
			{ collide = true }
		)
		P(
			desk,
			"DeskCarcass",
			Vector3.new(L, 3.1, 1.2),
			cf * CFrame.new(0, 0.32 + 1.55, -0.65),
			"walnut",
			{ collide = true }
		)
		local flutes = 33
		for i = 0, flutes - 1 do
			local x = -L / 2 + 0.45 + i * (L - 0.9) / (flutes - 1)
			P(
				desk,
				"Flute",
				Vector3.new(2.9, 0.26, 0.26),
				cf * CFrame.new(x, 0.42 + 1.45, -1.27) * CFrame.Angles(0, 0, math.pi / 2),
				"walnut",
				{
					shape = Enum.PartType.Cylinder,
					shadow = false,
				}
			)
		end
		for _, side in { -1, 1 } do
			P(
				desk,
				"DeskEnd",
				Vector3.new(0.3, 3.2, 1.5),
				cf * CFrame.new(side * (L / 2 - 0.15), 0.32 + 1.6, -0.62),
				"walnut"
			)
			P(
				desk,
				"DeskPedestal",
				Vector3.new(2.2, 2.36, 1.4),
				cf * CFrame.new(side * (L / 2 - 1.4), 1.5, 0.75),
				"walnut",
				{ collide = true }
			)
		end
		P(desk, "KickStrip", Vector3.new(L - 0.4, 0.06, 0.03), cf * CFrame.new(0, 0.3, -1.01), "brass", noShadow())
		local ledge =
			P(desk, "TransactionLedge", Vector3.new(L + 0.4, 0.18, 1.3), cf * CFrame.new(0, 3.51, -0.85), "stone")
		P(desk, "LedgeEdge", Vector3.new(L + 0.4, 0.05, 0.03), cf * CFrame.new(0, 3.4, -1.5), "brass", noShadow())
		Surfaces.wash(ledge, Enum.NormalId.Bottom, Color3.fromRGB(255, 208, 164), 0.9, 4, 150, false)
		P(desk, "Worktop", Vector3.new(L, 0.14, 1.5), cf * CFrame.new(0, 2.75, 0.7), "stone")
	end

	local ledgeTop = 3.6
	local monitorCf = cf * CFrame.new(-1.6, 2.82, 0.75)
	P(desk, "MonitorFoot", Vector3.new(0.6, 0.04, 0.4), monitorCf, "powder", noShadow())
	P(desk, "MonitorNeck", Vector3.new(0.08, 0.75, 0.08), monitorCf * CFrame.new(0, 0.38, 0.1), "powder", noShadow())
	local screen = P(
		desk,
		"Monitor",
		Vector3.new(1.9, 1.12, 0.07),
		monitorCf * CFrame.new(0, 1.1, 0.06) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(-0.08, 0, 0),
		"powder",
		noShadow()
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 120
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	gui.Parent = screen
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(26, 28, 32)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 10)
	pad.Parent = panel
	for i, line in
		{
			"TODAY  ·  BOOKINGS",
			"12:00   Consult — fine line",
			"14:30   Sleeve session 3/5",
			"17:00   Walk-in flash",
		}
	do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -12, 0, if i == 1 then 22 else 18)
		row.Font = if i == 1 then Enum.Font.GothamBold else Enum.Font.Gotham
		row.TextSize = if i == 1 then 18 else 15
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i == 1 then Color3.fromRGB(226, 196, 150) else Color3.fromRGB(214, 214, 210)
		row.Text = line
		row.Parent = panel
	end

	P(
		desk,
		"CardTerminal",
		Vector3.new(0.36, 0.1, 0.6),
		cf * CFrame.new(2.4, ledgeTop + 0.05, -0.95) * CFrame.Angles(0.15, 0.4, 0),
		"powder",
		noShadow()
	)
	post(desk, "BellBase", 0.05, 0.5, (cf * CFrame.new(3.6, ledgeTop, -0.9)).Position, "powder", noShadow())
	ellipsoid(
		desk,
		"Bell",
		Vector3.new(0.42, 0.3, 0.42),
		cf * CFrame.new(3.6, ledgeTop + 0.12, -0.9),
		"brass",
		noShadow()
	)
	P(
		desk,
		"BookCover",
		Vector3.new(1.3, 0.05, 0.9),
		cf * CFrame.new(-3.4, ledgeTop + 0.025, -0.9) * CFrame.Angles(0, 0.12, 0),
		"leather",
		noShadow(Color3.fromRGB(150, 120, 100))
	)
	P(
		desk,
		"BookPages",
		Vector3.new(1.2, 0.04, 0.82),
		cf * CFrame.new(-3.4, ledgeTop + 0.07, -0.9) * CFrame.Angles(0, 0.12, 0),
		"paint",
		noShadow(Color3.fromRGB(240, 234, 220))
	)
	P(
		desk,
		"CardHolder",
		Vector3.new(0.42, 0.12, 0.18),
		cf * CFrame.new(0.7, ledgeTop + 0.06, -1.15),
		"brass",
		noShadow()
	)
	P(
		desk,
		"Cards",
		Vector3.new(0.36, 0.1, 0.03),
		cf * CFrame.new(0.7, ledgeTop + 0.15, -1.12) * CFrame.Angles(-0.25, 0, 0),
		"paint",
		noShadow(Color3.fromRGB(22, 22, 24))
	)
	plant(
		desk,
		(cf * CFrame.new(-4.85, ledgeTop, -0.9)).Position,
		0.6,
		0.5,
		"paint",
		Color3.fromRGB(226, 222, 212),
		0.4,
		"succulent",
		7
	)

	local stool = cf * CFrame.new(0.9, 0, 2.3)
	post(desk, "StoolBase", 0.08, 1.2, stool.Position, "steel")
	post(desk, "StoolPole", 1.95, 0.14, stool.Position, "steel")
	post(desk, "StoolSeat", 0.3, 1.5, stool.Position + Vector3.new(0, 1.95, 0), "leather")
	makeSeat(desk, "ReceptionSeat", Vector3.new(1.3, 0.3, 1.3), stool * CFrame.new(0, 2.15, 0))

	-- Back bar: credenza with retail aftercare and a slatted brand wall above.
	local backCf = sideWall(1, 0, -16.6)
	local credenza = wallAt(backCf, 0, WORK_TOP, 0.85)
	P(desk, "BackBar", Vector3.new(15.4, 2.9, 1.5), credenza * CFrame.new(0, 1.45, 0.05), "walnut", { collide = true })
	P(desk, "BackBarTop", Vector3.new(15.6, 0.14, 1.65), credenza * CFrame.new(0, 2.97, 0), "stone")
	for i = 1, 4 do
		P(
			desk,
			"DoorReveal",
			Vector3.new(0.04, 2.5, 0.02),
			credenza * CFrame.new(-7.7 + i * 3.08, 1.5, -0.71),
			"paint",
			noShadow(Color3.fromRGB(28, 22, 18))
		)
	end
	local products = {
		Color3.fromRGB(22, 22, 24),
		Color3.fromRGB(232, 226, 214),
		Color3.fromRGB(22, 22, 24),
		Color3.fromRGB(122, 40, 40),
	}
	for i = 0, 11 do
		local spot = credenza * CFrame.new(-4.6 + i * 0.36, 3.04, -0.2)
		post(desk, "Aftercare", 0.55 + (i % 3) * 0.1, 0.26, spot.Position, "paint", noShadow(products[i % 4 + 1]))
	end
	P(desk, "Speaker", Vector3.new(0.8, 1.2, 0.7), credenza * CFrame.new(5.6, 3.64, 0), "powder", noShadow())
	post(
		desk,
		"Vase",
		1.1,
		0.5,
		(credenza * CFrame.new(-6.4, 3.04, 0)).Position,
		"paint",
		noShadow(Color3.fromRGB(196, 186, 168))
	)
	for i = 1, 7 do
		local lean = CFrame.Angles((i - 4) * 0.08, 0, (i % 3 - 1) * 0.12)
		local stem = credenza * CFrame.new(-6.4, 4.1, 0) * lean * CFrame.new(0, 0.9, 0)
		P(desk, "Stem", Vector3.new(0.03, 2.0, 0.03), stem, "paint", noShadow(Color3.fromRGB(110, 96, 70)))
		ellipsoid(
			desk,
			"Eucalyptus",
			Vector3.new(0.18, 0.04, 0.22),
			stem * CFrame.new(0, 0.6, 0),
			"leaf",
			noShadow(Color3.fromRGB(116, 138, 120))
		)
		ellipsoid(
			desk,
			"Eucalyptus",
			Vector3.new(0.16, 0.04, 0.2),
			stem * CFrame.new(0.05, 0.2, 0) * CFrame.Angles(0, 1, 0),
			"leaf",
			noShadow(Color3.fromRGB(116, 138, 120))
		)
	end

	local wallLen = 16.8
	P(
		desk,
		"SlatBacking",
		Vector3.new(wallLen, 12.6, 0.06),
		wallAt(backCf, 0, WORK_TOP + 6.3, 0.03),
		"powder",
		noShadow()
	)
	local slats = 32
	for i = 0, slats - 1 do
		local u = -wallLen / 2 + 0.25 + i * (wallLen - 0.5) / (slats - 1)
		P(
			desk,
			"BrandSlat",
			Vector3.new(0.28, 12.6, 0.22),
			wallAt(backCf, u, WORK_TOP + 6.3, 0.17),
			"walnut",
			noShadow()
		)
	end
	local sign = P(
		desk,
		"BrandSign",
		Vector3.new(11, 2.2, 0.04),
		wallAt(backCf, 0, 9.4, 0.32),
		"paint",
		{ transparency = 1, shadow = false }
	)
	local wordmark =
		Surfaces.label(sign, Enum.NormalId.Front, "Ink-Off", Color3.fromRGB(196, 160, 102), Enum.Font.Bodoni, 48, 0)
	wordmark.TextStrokeTransparency = 0.6
	wordmark.TextStrokeColor3 = Color3.fromRGB(60, 40, 20)
	local tagline = P(
		desk,
		"BrandTagline",
		Vector3.new(7.2, 0.75, 0.04),
		wallAt(backCf, 0, 7.75, 0.32),
		"paint",
		{ transparency = 1, shadow = false }
	)
	Surfaces.label(
		tagline,
		Enum.NormalId.Front,
		"TATTOO STUDIO  ·  EST. 2026",
		Color3.fromRGB(190, 182, 168),
		Enum.Font.GothamMedium,
		64,
		0
	)
	for _, u in { -3.6, 3.6 } do
		local can = wallAt(backCf, u, CEILING_Y - 0.4, 3.2)
		local fixture = P(
			desk,
			"WallWasher",
			Vector3.new(0.5, 0.5, 0.6),
			CFrame.lookAt(can.Position, (wallAt(backCf, u, 8.4, 0)).Position),
			"powder",
			noShadow()
		)
		Surfaces.spot(fixture, Enum.NormalId.Front, Color3.fromRGB(255, 224, 188), 2.4, 15, 50, false)
	end

	for _, u in { -3.6, 0, 3.6 } do
		local spot = cf * CFrame.new(u, 0, -0.3)
		local y = 10.4
		P(
			desk,
			"Canopy",
			Vector3.new(0.08, 0.6, 0.6),
			CFrame.new(spot.X, CEILING_Y - 0.04, spot.Z) * CFrame.Angles(0, 0, math.pi / 2),
			"powder",
			{
				shape = Enum.PartType.Cylinder,
				shadow = false,
			}
		)
		hang(desk, spot.Position, y + 0.7)
		post(desk, "ShadeNeck", 0.4, 0.4, Vector3.new(spot.X, y + 0.3, spot.Z), "brass", noShadow())
		post(desk, "Shade", 0.7, 1.4, Vector3.new(spot.X, y - 0.4, spot.Z), "brass", noShadow())
		local bulb = ellipsoid(
			desk,
			"Bulb",
			Vector3.new(0.42, 0.42, 0.42),
			CFrame.new(spot.X, y - 0.5, spot.Z),
			"neon",
			noShadow(Color3.fromRGB(255, 222, 186))
		)
		Surfaces.glow(bulb, WARM, 0.9, 12)
	end

	plant(desk, Vector3.new(21.4, FLOOR_TOP, -23.6), 1.2, 1.5, "powder", nil, 4.2, "snake", 11)
end

------------------------------------------------------------------------------------------
-- Lounge

local function sofa(parent: Instance, cf: CFrame, length: number, waiting: number, finish: string)
	local depth = 3.1
	for _, x in { -length / 2 + 0.35, length / 2 - 0.35 } do
		for _, z in { -depth / 2 + 0.35, depth / 2 - 0.35 } do
			post(parent, "SofaLeg", 0.4, 0.2, (cf * CFrame.new(x, 0, z)).Position, "walnut", noShadow())
		end
	end
	P(
		parent,
		"SofaBase",
		Vector3.new(length, 0.75, depth),
		cf * CFrame.new(0, 0.4 + 0.375, 0),
		finish,
		{ collide = true }
	)
	local armW = 0.8
	local seatW = (length - armW * 2) / waiting
	for i = 1, waiting do
		local x = -length / 2 + armW + seatW * (i - 0.5)
		P(parent, "SeatCushion", Vector3.new(seatW - 0.05, 0.5, depth - 0.75), cf * CFrame.new(x, 1.4, -0.3), finish)
		makeSeat(parent, "WaitingSeat", Vector3.new(seatW - 0.4, 0.2, 1.8), cf * CFrame.new(x, 1.66, -0.35))
	end
	P(
		parent,
		"SofaBack",
		Vector3.new(length - armW * 2, 1.9, 0.75),
		cf * CFrame.new(0, 2.1, depth / 2 - 0.375),
		finish,
		{ collide = true }
	)
	for row = 0, 1 do
		for col = 0, math.floor(length) - 2 do
			local x = -length / 2 + armW + 0.5 + col * (length - armW * 2 - 1) / (math.floor(length) - 2)
			ellipsoid(
				parent,
				"Button",
				Vector3.new(0.1, 0.1, 0.06),
				cf * CFrame.new(x, 1.95 + row * 0.6, depth / 2 - 0.76),
				finish,
				noShadow()
			)
		end
	end
	for _, side in { -1, 1 } do
		local x = side * (length / 2 - armW / 2)
		P(
			parent,
			"SofaArm",
			Vector3.new(armW, 1.25, depth),
			cf * CFrame.new(x, 1.15 + 0.6, 0),
			finish,
			{ collide = true }
		)
		P(
			parent,
			"ArmRoll",
			Vector3.new(depth, 0.9, 0.9),
			cf * CFrame.new(x, 2.4, 0) * CFrame.Angles(0, math.pi / 2, 0),
			finish,
			{
				shape = Enum.PartType.Cylinder,
			}
		)
	end
end

local function buildLounge(root: Instance)
	local lounge = Surfaces.folder(root, "Lounge")

	local rug = P(
		lounge,
		"Rug",
		Vector3.new(9.45, 0.04, 12.6),
		CFrame.new(-27.4, FLOOR_TOP + 0.02, -16.4),
		"fabric",
		noShadow(Color3.fromRGB(92, 40, 36))
	)
	Surfaces.decal(rug, Enum.NormalId.Top, RUG_ART)

	local sofaOrigin = Vector3.new(-31.0, FLOOR_TOP, -16.4)
	sofa(lounge, CFrame.lookAt(sofaOrigin, sofaOrigin + Vector3.new(1, 0, 0)), 8.4, 3, "leather")
	for i, z in { -19.2, -13.7 } do
		ellipsoid(
			lounge,
			"Cushion",
			Vector3.new(0.5, 1.2, 1.35),
			CFrame.new(-31.7, 2.2, z) * CFrame.Angles(0, 0, -0.25) * CFrame.Angles(i * 0.1, 0, 0),
			"leatherOx"
		)
	end

	local chairOrigin = Vector3.new(-22.6, FLOOR_TOP, -22.4)
	sofa(lounge, CFrame.lookAt(chairOrigin, Vector3.new(-27.5, FLOOR_TOP, -15.8)), 3.4, 1, "leatherOx")

	local tableCf = CFrame.new(-26.0, FLOOR_TOP, -16.4)
	for _, x in { -0.95, 0.95 } do
		for _, z in { -2.3, 2.3 } do
			P(lounge, "TableLeg", Vector3.new(0.1, 1.36, 0.1), tableCf * CFrame.new(x, 0.68, z), "powder")
		end
		P(lounge, "TableStretcher", Vector3.new(0.1, 0.1, 4.6), tableCf * CFrame.new(x, 0.3, 0), "powder", noShadow())
	end
	P(lounge, "TableTop", Vector3.new(2.3, 0.14, 5.0), tableCf * CFrame.new(0, 1.43, 0), "walnut", { collide = true })
	local tableTop = 1.5
	local books = { Color3.fromRGB(26, 26, 28), Color3.fromRGB(110, 34, 36), Color3.fromRGB(196, 186, 166) }
	for i, color in books do
		P(
			lounge,
			"Book",
			Vector3.new(1.0 - i * 0.08, 0.14, 1.35 - i * 0.06),
			tableCf * CFrame.new(0.1, tableTop + 0.07 + (i - 1) * 0.14, -1.2) * CFrame.Angles(0, i * 0.12, 0),
			"paint",
			noShadow(color)
		)
	end
	P(
		lounge,
		"Portfolio",
		Vector3.new(1.3, 0.06, 1.7),
		tableCf * CFrame.new(-0.1, tableTop + 0.03, 1.0) * CFrame.Angles(0, -0.15, 0),
		"leather",
		noShadow()
	)
	post(
		lounge,
		"Mug",
		0.3,
		0.26,
		(tableCf * CFrame.new(0.5, tableTop, 0.2)).Position,
		"paint",
		noShadow(Color3.fromRGB(226, 220, 208))
	)

	local side = Vector3.new(-31.5, FLOOR_TOP, -10.9)
	post(lounge, "SideTableFoot", 0.08, 1.1, side, "walnut")
	post(lounge, "SideTableStem", 1.9, 0.16, side, "walnut")
	post(lounge, "SideTableTop", 0.1, 1.5, side + Vector3.new(0, 1.9, 0), "walnut", { collide = true })
	ellipsoid(
		lounge,
		"LampBase",
		Vector3.new(0.6, 0.85, 0.6),
		CFrame.new(side + Vector3.new(0, 2.42, 0)),
		"paint",
		noShadow(Color3.fromRGB(204, 196, 182))
	)
	local shade = post(lounge, "LampShade", 0.8, 1.15, side + Vector3.new(0, 2.85, 0), "fabric", {
		tint = Color3.fromRGB(230, 218, 196),
		transparency = 0.12,
		shadow = false,
	})
	Surfaces.glow(shade, WARM, 1.1, 12)

	local floorLamp = Vector3.new(-32.3, FLOOR_TOP, -21.9)
	post(lounge, "LampFoot", 0.08, 1.0, floorLamp, "powder")
	post(lounge, "LampStem", 5.6, 0.1, floorLamp, "powder")
	local drum = post(lounge, "DrumShade", 1.1, 1.7, floorLamp + Vector3.new(0, 5.3, 0), "fabric", {
		tint = Color3.fromRGB(226, 214, 192),
		transparency = 0.12,
		shadow = false,
	})
	Surfaces.glow(drum, WARM, 1.2, 14)

	plant(
		lounge,
		Vector3.new(-31.7, FLOOR_TOP, -24.9),
		2.0,
		1.9,
		"powder",
		Color3.fromRGB(200, 200, 200),
		6.0,
		"fig",
		3
	)

	local wallZ = -16.4
	artwork(lounge, sideWall(-1, 8.4, wallZ, 0.18), 6.0, 4.5, ART.sheet, "powder", true)
	artwork(lounge, sideWall(-1, 7.2, -11.0, 0.18), 3.2, 2.4, ART.swallows, "brass", false)
	artwork(lounge, sideWall(-1, 8.8, -21.8, 0.18), 2.25, 3.0, ART.botanical, "brass", false)
end

------------------------------------------------------------------------------------------
-- Back wall: theme board stays the focal point; art clusters frame it off-axis.

local function buildBackWall(root: Instance)
	local back = Surfaces.folder(root, "BackWall")

	artwork(back, backWall(-9.0, 8.3), 4.2, 5.6, ART.tiger, "walnut", true)
	artwork(back, backWall(-13.7, 9.4), 2.4, 3.2, ART.snake, "powder", false)
	artwork(back, backWall(-13.7, 6.2), 2.4, 2.4, ART.mandala, "brass", false)
	artwork(back, backWall(9.2, 8.0), 4.2, 5.6, ART.koi, "powder", true)
	artwork(back, backWall(13.9, 9.9), 2.4, 3.2, ART.moth, "walnut", false)

	local credenza = backWall(0, WORK_TOP)
	P(back, "Credenza", Vector3.new(9.0, 2.5, 1.4), credenza * CFrame.new(0, 1.25, -0.7), "walnut", { collide = true })
	P(back, "CredenzaTop", Vector3.new(9.2, 0.12, 1.5), credenza * CFrame.new(0, 2.56, -0.72), "stone")
	for _, u in { -1.5, 1.5 } do
		P(
			back,
			"DoorReveal",
			Vector3.new(0.04, 2.2, 0.02),
			credenza * CFrame.new(u, 1.3, -1.41),
			"paint",
			noShadow(Color3.fromRGB(28, 22, 18))
		)
	end
	local top = 2.62
	for i, color in { Color3.fromRGB(28, 28, 30), Color3.fromRGB(196, 186, 166), Color3.fromRGB(110, 34, 36) } do
		P(
			back,
			"Book",
			Vector3.new(1.2, 0.16, 0.9),
			credenza * CFrame.new(-2.6, top + 0.08 + (i - 1) * 0.16, -0.7) * CFrame.Angles(0, i * 0.1, 0),
			"paint",
			noShadow(color)
		)
	end
	ellipsoid(
		back,
		"Bowl",
		Vector3.new(1.0, 0.36, 1.0),
		credenza * CFrame.new(2.7, top + 0.1, -0.7),
		"brass",
		noShadow()
	)
	plant(
		back,
		(credenza * CFrame.new(-3.8, top, -0.7)).Position,
		0.7,
		0.8,
		"paint",
		Color3.fromRGB(64, 60, 56),
		1.4,
		"snake",
		21
	)

	local neon =
		P(back, "NeonSign", Vector3.new(9.0, 9.0 / 2.891, 0.05), backWall(0, 13.3) * CFrame.new(0, 0, -0.1), "paint", {
			transparency = 1,
			shadow = false,
		})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 48
	gui.LightInfluence = 0
	gui.Brightness = 2.6
	gui.Parent = neon
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = NEON_ART
	image.Parent = gui
	Surfaces.glow(neon, Color3.fromRGB(255, 146, 70), 0.55, 12)
end

------------------------------------------------------------------------------------------
-- Back-of-house: supply storage (left) and wash-up (right)

local function buildStorage(root: Instance)
	local store = Surfaces.folder(root, "Storage")
	local cf = backWall(-24.6, WORK_TOP)
	local L = 15.8
	P(store, "Plinth", Vector3.new(L - 0.2, 0.3, 1.6), cf * CFrame.new(0, 0.15, -0.9), "powder")
	P(store, "Cabinets", Vector3.new(L, 2.9, 1.9), cf * CFrame.new(0, 0.3 + 1.45, -0.95), "walnut", { collide = true })
	for i = 1, 5 do
		local u = -L / 2 + i * L / 6
		P(
			store,
			"DoorReveal",
			Vector3.new(0.04, 2.8, 0.02),
			cf * CFrame.new(u, 1.75, -1.91),
			"paint",
			noShadow(Color3.fromRGB(28, 22, 18))
		)
	end
	for i = 0, 5 do
		local u = -L / 2 + (i + 0.5) * L / 6 + (if i % 2 == 0 then 1 else -1) * 0.95
		P(store, "Pull", Vector3.new(0.06, 0.8, 0.06), cf * CFrame.new(u, 2.5, -1.95), "brass", noShadow())
	end
	P(store, "Counter", Vector3.new(L + 0.2, 0.14, 2.05), cf * CFrame.new(0, 3.27, -1.0), "stone")
	local counterTop = 3.34

	for _, u in { -L / 2 + 0.08, 0, L / 2 - 0.08 } do
		P(store, "Upright", Vector3.new(0.16, 4.8, 1.25), cf * CFrame.new(u, 6.8, -0.63), "walnut")
	end
	local shelfYs = { 5.9, 8.1 }
	for i, y in shelfYs do
		local shelf = P(store, "Shelf", Vector3.new(L, 0.16, 1.25), cf * CFrame.new(0, y, -0.63), "walnut")
		if i == 1 then
			Surfaces.wash(shelf, Enum.NormalId.Bottom, Color3.fromRGB(255, 230, 198), 0.7, 5, 120, false)
		end
	end
	local inkColors = {
		INK,
		Color3.fromRGB(128, 22, 26),
		INK,
		Color3.fromRGB(36, 64, 118),
		Color3.fromRGB(46, 92, 52),
		INK,
		Color3.fromRGB(196, 150, 40),
		Color3.fromRGB(96, 40, 110),
		INK,
	}
	for i = 0, 17 do
		local spot = cf * CFrame.new(-7.2 + i * 0.4, 5.98, -0.6)
		post(
			store,
			"InkBottle",
			0.48,
			0.24,
			spot.Position,
			"glass",
			{ tint = inkColors[i % #inkColors + 1], transparency = 0.1, shadow = false }
		)
		post(store, "InkLid", 0.1, 0.14, spot.Position + Vector3.new(0, 0.48, 0), "paint", noShadow(INK))
	end
	P(
		store,
		"SupplyBox",
		Vector3.new(2.0, 1.1, 1.0),
		cf * CFrame.new(3.6, 6.53, -0.6),
		"paint",
		noShadow(Color3.fromRGB(200, 186, 160))
	)
	P(
		store,
		"SupplyBox",
		Vector3.new(1.6, 0.8, 1.0),
		cf * CFrame.new(5.6, 6.38, -0.6),
		"paint",
		noShadow(Color3.fromRGB(236, 236, 232))
	)
	local binders =
		{ INK, Color3.fromRGB(110, 34, 36), INK, Color3.fromRGB(70, 76, 60), INK, Color3.fromRGB(196, 186, 166), INK }
	for i, color in binders do
		local h = 1.1 + (i % 3) * 0.15
		P(
			store,
			"Binder",
			Vector3.new(0.3, h, 1.0),
			cf
				* CFrame.new(-7.0 + i * 0.34, 8.18 + h / 2, -0.62)
				* CFrame.Angles(0, 0, if i == #binders then 0.2 else 0),
			"paint",
			noShadow(color)
		)
	end
	plant(
		store,
		(cf * CFrame.new(1.2, 8.18, -0.6)).Position,
		0.8,
		0.7,
		"paint",
		Color3.fromRGB(226, 220, 208),
		1.8,
		"trailing",
		5
	)
	post(
		store,
		"Jar",
		0.9,
		0.7,
		(cf * CFrame.new(5.2, 8.18, -0.6)).Position,
		"glass",
		{ tint = Color3.fromRGB(196, 186, 160), transparency = 0.3, shadow = false }
	)

	P(
		store,
		"StencilPrinter",
		Vector3.new(1.6, 0.6, 1.1),
		cf * CFrame.new(-5.2, counterTop + 0.3, -1.0),
		"paint",
		noShadow(Color3.fromRGB(46, 48, 52))
	)
	P(
		store,
		"PrinterSlot",
		Vector3.new(1.2, 0.04, 0.02),
		cf * CFrame.new(-5.2, counterTop + 0.45, -1.56),
		"paint",
		noShadow(Color3.fromRGB(240, 240, 236))
	)
	for i = 0, 2 do
		P(
			store,
			"FilmRoll",
			Vector3.new(0.9, 0.36, 0.36),
			cf * CFrame.new(-2.4, counterTop + 0.18, -0.6 - i * 0.4),
			"glass",
			{
				shape = Enum.PartType.Cylinder,
				tint = Color3.fromRGB(220, 226, 230),
				transparency = 0.35,
				shadow = false,
			}
		)
	end
	for i = 0, 3 do
		P(
			store,
			"Towel",
			Vector3.new(1.4, 0.18, 1.0),
			cf * CFrame.new(2.6, counterTop + 0.09 + i * 0.18, -1.0),
			"fabric",
			noShadow(Color3.fromRGB(32, 32, 34))
		)
	end
end

local function buildWashUp(root: Instance)
	local wash = Surfaces.folder(root, "WashUp")
	local cf = backWall(24.6, WORK_TOP)
	local L = 15.8
	P(
		wash,
		"Plinth",
		Vector3.new(L - 0.2, 0.3, 1.6),
		cf * CFrame.new(0, 0.15, -0.9),
		"powder",
		{ tint = Color3.fromRGB(70, 70, 72) }
	)
	P(
		wash,
		"Cabinets",
		Vector3.new(L, 2.9, 1.9),
		cf * CFrame.new(0, 0.3 + 1.45, -0.95),
		"powder",
		{ collide = true, tint = Color3.fromRGB(170, 170, 170) }
	)
	for i = 1, 5 do
		local u = -L / 2 + i * L / 6
		P(wash, "DoorReveal", Vector3.new(0.04, 2.8, 0.02), cf * CFrame.new(u, 1.75, -1.91), "paint", noShadow(INK))
	end
	for i = 0, 5 do
		P(
			wash,
			"Pull",
			Vector3.new(1.0, 0.06, 0.06),
			cf * CFrame.new(-L / 2 + (i + 0.5) * L / 6, 2.9, -1.95),
			"steel",
			noShadow()
		)
	end
	P(wash, "Counter", Vector3.new(L + 0.2, 0.12, 2.05), cf * CFrame.new(0, 3.26, -1.0), "steel")
	local top = 3.32
	P(wash, "Splashback", Vector3.new(L + 0.2, 4.4, 0.08), cf * CFrame.new(0, top + 2.2, -0.04), "tile")

	local sinkU = -3.6
	P(
		wash,
		"Basin",
		Vector3.new(2.6, 0.01, 1.4),
		cf * CFrame.new(sinkU, top + 0.005, -1.0),
		"steel",
		noShadow(DARK_METAL)
	)
	post(
		wash,
		"Drain",
		0.012,
		0.22,
		(cf * CFrame.new(sinkU, top, -1.0)).Position,
		"steel",
		noShadow(Color3.fromRGB(60, 60, 62))
	)
	post(wash, "Tap", 1.1, 0.14, (cf * CFrame.new(sinkU, top, -0.25)).Position, "steel", noShadow())
	P(wash, "Spout", Vector3.new(0.1, 0.1, 0.75), cf * CFrame.new(sinkU, top + 1.08, -0.6), "steel", noShadow())
	P(wash, "SpoutTip", Vector3.new(0.1, 0.25, 0.1), cf * CFrame.new(sinkU, top + 0.95, -0.95), "steel", noShadow())
	P(
		wash,
		"WristLever",
		Vector3.new(0.7, 0.06, 0.06),
		cf * CFrame.new(sinkU + 0.3, top + 0.7, -0.25),
		"steel",
		noShadow()
	)

	local soap = cf * CFrame.new(sinkU + 1.9, top + 2.2, -0.28)
	P(wash, "SoapDispenser", Vector3.new(0.55, 0.9, 0.4), soap, "paint", noShadow(Color3.fromRGB(238, 238, 234)))
	P(wash, "SoapNozzle", Vector3.new(0.12, 0.12, 0.14), soap * CFrame.new(0, -0.5, -0.1), "steel", noShadow())
	local towels = cf * CFrame.new(sinkU - 2.2, top + 2.6, -0.3)
	P(wash, "TowelDispenser", Vector3.new(1.3, 1.5, 0.45), towels, "steel")
	P(
		wash,
		"TowelTab",
		Vector3.new(0.7, 0.2, 0.02),
		towels * CFrame.new(0, -0.82, -0.2),
		"paint",
		noShadow(Color3.fromRGB(236, 236, 232))
	)

	local clave = cf * CFrame.new(3.1, top + 0.55, -1.0)
	P(wash, "Autoclave", Vector3.new(1.9, 1.1, 1.5), clave, "steel")
	P(wash, "AutoclaveDoor", Vector3.new(1.2, 0.8, 0.02), clave * CFrame.new(-0.2, 0, -0.76), "powder", noShadow())
	local display = P(
		wash,
		"AutoclaveDisplay",
		Vector3.new(0.4, 0.2, 0.02),
		clave * CFrame.new(0.65, 0.2, -0.76),
		"paint",
		noShadow(INK)
	)
	Surfaces.label(display, Enum.NormalId.Front, "134°C", Color3.fromRGB(90, 230, 140), Enum.Font.Code, 96, 0)
	P(wash, "Ultrasonic", Vector3.new(1.0, 0.5, 0.7), cf * CFrame.new(0.9, top + 0.25, -1.1), "steel")
	for i = 0, 1 do
		local bottle = (cf * CFrame.new(5.0 + i * 0.4, top, -1.2)).Position
		post(
			wash,
			"SprayBottle",
			0.75,
			0.26,
			bottle,
			"paint",
			noShadow(if i == 0 then Color3.fromRGB(236, 236, 232) else Color3.fromRGB(150, 196, 168))
		)
		P(
			wash,
			"Trigger",
			Vector3.new(0.14, 0.24, 0.3),
			CFrame.new(bottle + Vector3.new(0, 0.86, 0)),
			"paint",
			noShadow(INK)
		)
	end
	for i = 0, 3 do
		P(
			wash,
			"Towel",
			Vector3.new(1.3, 0.16, 0.9),
			cf * CFrame.new(6.6, top + 0.08 + i * 0.16, -1.0),
			"fabric",
			noShadow(Color3.fromRGB(240, 238, 232))
		)
	end

	local shelfCf = cf * CFrame.new(0, 9.1, -0.6)
	local shelf = P(wash, "OpenShelf", Vector3.new(L, 0.08, 1.2), shelfCf, "steel")
	Surfaces.wash(shelf, Enum.NormalId.Bottom, NEUTRAL, 1.0, 8, 130, false)
	for _, u in { -6, 0, 6 } do
		P(wash, "ShelfBracket", Vector3.new(0.06, 0.5, 1.1), shelfCf * CFrame.new(u, -0.29, 0), "steel", noShadow())
	end
	local boxes: { { w: number, h: number, color: Color3 } } = {
		{ w = 1.0, h = 0.6, color = Color3.fromRGB(92, 70, 150) },
		{ w = 1.0, h = 0.6, color = Color3.fromRGB(48, 82, 152) },
		{ w = 1.0, h = 0.6, color = INK },
		{ w = 1.6, h = 0.9, color = Color3.fromRGB(236, 236, 232) },
		{ w = 1.2, h = 0.7, color = Color3.fromRGB(200, 186, 160) },
		{ w = 1.0, h = 0.5, color = Color3.fromRGB(120, 168, 150) },
	}
	local u = -6.6
	for _, box in boxes do
		P(
			wash,
			"Supplies",
			Vector3.new(box.w, box.h, 0.9),
			shelfCf * CFrame.new(u + box.w / 2, 0.04 + box.h / 2, 0),
			"paint",
			noShadow(box.color)
		)
		u += box.w + 0.25
	end

	local bin = (cf * CFrame.new(7.0, 0, -2.5)).Position
	post(wash, "PedalBin", 1.6, 1.0, bin, "steel", { collide = true })
	post(wash, "BinLid", 0.08, 1.04, bin + Vector3.new(0, 1.6, 0), "powder", noShadow())
end

------------------------------------------------------------------------------------------
-- Code-required and lived-in details

local function buildDetails(root: Instance)
	local details = Surfaces.folder(root, "Details")

	local exit = P(
		details,
		"ExitSign",
		Vector3.new(2.0, 0.7, 0.2),
		CFrame.new(0, 10.2, -24.6),
		"paint",
		noShadow(Color3.fromRGB(236, 236, 232))
	)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Surfaces.label(exit, face, "EXIT", Color3.fromRGB(40, 190, 90), Enum.Font.GothamBold, 64, 0)
	end
	for _, x in { -0.7, 0.7 } do
		P(
			details,
			"ExitRod",
			Vector3.new(0.04, CEILING_Y - 10.55, 0.04),
			CFrame.new(x, (CEILING_Y + 10.55) / 2, -24.6),
			"steel",
			noShadow()
		)
	end

	local extinguisher = sideWall(-1, 4.6, -6.0, 0.1)
	P(
		details,
		"ExtinguisherBracket",
		Vector3.new(0.5, 0.18, 0.4),
		extinguisher * CFrame.new(0, -0.1, -0.1),
		"powder",
		noShadow()
	)
	post(
		details,
		"Extinguisher",
		1.7,
		0.52,
		(extinguisher * CFrame.new(0, 0, -0.32)).Position,
		"paint",
		noShadow(Color3.fromRGB(176, 24, 24))
	)
	post(
		details,
		"ExtinguisherHead",
		0.25,
		0.2,
		(extinguisher * CFrame.new(0, 1.7, -0.32)).Position,
		"powder",
		noShadow()
	)
	local sign = P(
		details,
		"ExtinguisherSign",
		Vector3.new(0.9, 0.6, 0.03),
		extinguisher * CFrame.new(0, 2.6, 0),
		"paint",
		noShadow(Color3.fromRGB(176, 24, 24))
	)
	Surfaces.label(sign, Enum.NormalId.Front, "FIRE", Color3.fromRGB(250, 250, 250), Enum.Font.GothamBold, 64)

	local sanitiser = Vector3.new(15.2, FLOOR_TOP, -7.6)
	post(details, "SanitiserBase", 0.06, 1.0, sanitiser, "powder")
	post(details, "SanitiserPole", 3.4, 0.14, sanitiser, "powder")
	P(
		details,
		"SanitiserUnit",
		Vector3.new(0.5, 0.8, 0.4),
		CFrame.new(sanitiser + Vector3.new(0, 3.7, 0)),
		"paint",
		noShadow(Color3.fromRGB(238, 238, 234))
	)

	ellipsoid(details, "SecurityDome", Vector3.new(0.6, 0.4, 0.6), CFrame.new(31.5, CEILING_Y - 0.1, -24.5), "glass", {
		tint = Color3.fromRGB(30, 30, 34),
		transparency = 0.2,
		shadow = false,
	})
end

-- Blender plants live in ServerStorage.ParlourImport (MeshParts authored in Blender).
-- Floor and sill plants sit on their pot base. Hanging vines are seated by the pot rim,
-- because the foliage is modelled below the pot. Procedural pots remain the fallback.
local POT_FINISH: { [string]: { key: string, tint: Color3 } } = {
	PlantFig = { key = "stone", tint = Color3.fromRGB(196, 188, 178) },
	PlantSnake = { key = "plaster", tint = Color3.fromRGB(255, 250, 242) },
	PlantFern = { key = "rubber", tint = Color3.fromRGB(176, 104, 68) },
	PlantHang = { key = "plaster", tint = Color3.fromRGB(255, 252, 246) },
	PlantSucculent = { key = "plaster", tint = Color3.fromRGB(255, 252, 246) },
}

local PLANT_SPECIES = { "PlantFig", "PlantSnake", "PlantFern", "PlantHang", "PlantSucculent" }

local PIECE_COLOR: { [string]: Color3 } = {
	FigPot = Color3.fromRGB(62, 58, 54),
	FigStems = Color3.fromRGB(112, 84, 54),
	FigFoliage = Color3.fromRGB(46, 90, 38),
	SnakePot = Color3.fromRGB(214, 206, 192),
	SnakeFoliage = Color3.fromRGB(52, 92, 48),
	FernPot = Color3.fromRGB(176, 104, 68),
	FernStems = Color3.fromRGB(78, 108, 52),
	FernFoliage = Color3.fromRGB(64, 118, 52),
	HangPot = Color3.fromRGB(236, 232, 224),
	HangStems = Color3.fromRGB(86, 118, 58),
	HangFoliage = Color3.fromRGB(58, 110, 48),
	SucculentPot = Color3.fromRGB(236, 232, 224),
	SucculentFoliage = Color3.fromRGB(92, 128, 102),
}

-- Reject MeshParts that lost their geometry (SourceType.None draws as a solid box).
local function meshHasSurface(part: MeshPart): boolean
	local ok, sourceType = pcall(function()
		return (part.MeshContent :: any).SourceType
	end)
	if not ok or sourceType == nil then
		-- Some Studio builds expose MeshContent late; a MeshPart with real Size is enough.
		return part.Size.Magnitude > 0.01
	end
	return sourceType ~= Enum.ContentSourceType.None
end

local function modelHasSurface(model: Instance): boolean
	if not model:IsA("Model") then
		return false
	end
	local found = false
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			found = true
			if not meshHasSurface(part) then
				return false
			end
		end
	end
	return found
end

-- Bake the Blender meshes into this session so clients actually receive them.
-- Roblox only allows this when Allow Mesh / Image APIs is on.
local function ensureBlenderPlants()
	local AssetService = game:GetService("AssetService")
	local apiOk = pcall(function()
		local probe = AssetService:CreateEditableMesh()
		probe:Destroy()
	end)
	if not apiOk then
		warn("[InkMasters] Blender plants need Allow Mesh / Image APIs, in Experience Settings, Security")
		return
	end

	local folder = ServerStorage:FindFirstChild("ParlourImport")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "ParlourImport"
		folder.Parent = ServerStorage
	end

	local meshApi: any = nil
	local dataModule = script.Parent:FindFirstChild("PlantMesh")
	if dataModule ~= nil and dataModule:IsA("ModuleScript") then
		local loaded, data = pcall(require, dataModule)
		if loaded then
			meshApi = data
		end
	end
	local HttpService = game:GetService("HttpService")
	for _, species in PLANT_SPECIES do
		local existing = folder:FindFirstChild(species)
		if existing ~= nil and modelHasSurface(existing) then
			continue
		end
		if existing ~= nil then
			existing:Destroy()
		end
		local body: string? = nil
		if meshApi ~= nil and type(meshApi.get) == "function" then
			local okBody, packed = pcall(meshApi.get, species)
			if okBody and type(packed) == "string" then
				body = packed
			end
		end
		if body == nil and HttpService.HttpEnabled then
			local fetched, remote = pcall(function()
				return HttpService:GetAsync(`http://127.0.0.1:8766/blender-out/plants/{species}.json`, true)
			end)
			if fetched and type(remote) == "string" then
				body = remote
			end
		end
		if body == nil then
			warn(`[InkMasters] Could not load {species}`)
			continue
		end
		local decoded, pieces = pcall(function()
			return HttpService:JSONDecode(body)
		end)
		if not decoded or type(pieces) ~= "table" then
			warn(`[InkMasters] {species} mesh data was not readable`)
			continue
		end
		local model = Instance.new("Model")
		model.Name = species
		local built = true
		for _, piece in pieces do
			local minv = Vector3.new(math.huge, math.huge, math.huge)
			local maxv = Vector3.new(-math.huge, -math.huge, -math.huge)
			for _, vertex in piece.verts do
				minv =
					Vector3.new(math.min(minv.X, vertex[1]), math.min(minv.Y, vertex[2]), math.min(minv.Z, vertex[3]))
				maxv =
					Vector3.new(math.max(maxv.X, vertex[1]), math.max(maxv.Y, vertex[2]), math.max(maxv.Z, vertex[3]))
			end
			local center = (minv + maxv) * 0.5
			local editable = AssetService:CreateEditableMesh()
			local ids = table.create(#piece.verts)
			for index, vertex in piece.verts do
				ids[index] =
					editable:AddVertex(Vector3.new(vertex[1] - center.X, vertex[2] - center.Y, vertex[3] - center.Z))
			end
			for _, face in piece.faces do
				editable:AddTriangle(ids[face[1] + 1], ids[face[2] + 1], ids[face[3] + 1])
			end
			local bakedOk, result, content = pcall(function()
				return AssetService:CreateDataModelContentAsync(Content.fromObject(editable))
			end)
			editable:Destroy()
			if not bakedOk or result ~= Enum.CreateContentResult.Success then
				warn(`[InkMasters] {piece.name} could not be baked: {result}`)
				built = false
				break
			end
			local created, meshPart = pcall(function()
				return AssetService:CreateMeshPartAsync(content, {
					CollisionFidelity = Enum.CollisionFidelity.Box,
					RenderFidelity = Enum.RenderFidelity.Precise,
				})
			end)
			if not created or meshPart == nil then
				warn(`[InkMasters] {piece.name} mesh failed: {meshPart}`)
				built = false
				break
			end
			meshPart.Name = piece.name
			meshPart.Anchored = true
			meshPart.CanCollide = false
			meshPart.CanTouch = false
			meshPart.CanQuery = false
			meshPart.CastShadow = true
			meshPart.Reflectance = 0
			meshPart.Material = Enum.Material.Plastic
			meshPart.Color = PIECE_COLOR[piece.name] or Color3.fromRGB(54, 38, 26)
			meshPart.DoubleSided = string.find(piece.name, "Foliage") ~= nil
			meshPart.CFrame = CFrame.new(center)
			meshPart.Parent = model
			task.wait(0.05)
		end
		if built and modelHasSurface(model) then
			model.Parent = folder
		else
			model:Destroy()
		end
		task.wait(0.2)
	end
end

local function placeMeshPlant(
	parent: Instance,
	species: string,
	anchor: Vector3,
	targetHeight: number,
	yaw: number,
	seatTop: boolean
): boolean
	local import = ServerStorage:FindFirstChild("ParlourImport")
	local src = import and import:FindFirstChild(species)
	if src == nil or not modelHasSurface(src) then
		return false
	end
	local copy = src:Clone()
	local pot = POT_FINISH[species]
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = true
			if string.find(part.Name, "Foliage") then
				part.DoubleSided = true
				Surfaces.apply(part, "rubber", part.Color)
			elseif string.find(part.Name, "Stem") then
				Surfaces.apply(part, "walnut", Color3.fromRGB(255, 232, 206))
			elseif string.find(part.Name, "Soil") then
				Surfaces.apply(part, "ground", Color3.fromRGB(72, 50, 34))
			elseif pot ~= nil and string.find(part.Name, "Pot") then
				Surfaces.apply(part, pot.key, pot.tint)
			end
		end
	end
	local y0, y1 = extents(copy, Vector3.yAxis)
	local height = y1 - y0
	if height > 0.05 and targetHeight > 0 then
		copy:ScaleTo(copy:GetScale() * (targetHeight / height))
	end
	copy:PivotTo(copy:GetPivot() * CFrame.Angles(0, yaw, 0))
	y0, y1 = extents(copy, Vector3.yAxis)
	local x0, x1 = extents(copy, Vector3.xAxis)
	local z0, z1 = extents(copy, Vector3.zAxis)
	local deltaY = if seatTop then anchor.Y - y1 else anchor.Y - y0
	copy:PivotTo(copy:GetPivot() + Vector3.new(anchor.X - (x0 + x1) / 2, deltaY, anchor.Z - (z0 + z1) / 2))
	copy.Name = "Plant"
	copy:SetAttribute("Species", species)
	copy.Parent = parent
	return true
end

-- Pots on the floor, the window sills, the walls, and hanging from the ceiling.
-- The door, the spawn pads, and the four stations stay clear.
local function needsPlantBake(): boolean
	local folder = ServerStorage:FindFirstChild("ParlourImport")
	if folder == nil then
		return true
	end
	for _, species in PLANT_SPECIES do
		local model = folder:FindFirstChild(species)
		if model == nil or not modelHasSurface(model) then
			return true
		end
	end
	return false
end

local function buildGreenery(root: Instance)
	-- Prefer meshes already baked into ServerStorage.ParlourImport.
	-- Only rebuild missing species; baking every plant at lobby load can crash Studio.
	if needsPlantBake() then
		local baked, bakeErr = pcall(ensureBlenderPlants)
		if not baked then
			warn(`[InkMasters] Blender plants could not be prepared: {bakeErr}`)
		end
	end
	local green = Surfaces.folder(root, "Greenery")
	local cream = Color3.fromRGB(226, 220, 208)
	local clay = Color3.fromRGB(138, 74, 52)

	local function suspend(x: number, z: number, seed: number)
		-- Rim sits high enough that the trailing leaves clear a standing player.
		local rimY = 12.05
		P(
			green,
			"Hanger",
			Vector3.new(0.045, CEILING_Y - rimY, 0.045),
			CFrame.new(x, (CEILING_Y + rimY) / 2, z),
			"paint",
			noShadow(INK)
		)
		local yaw = math.rad((seed * 47) % 360)
		if not placeMeshPlant(green, "PlantHang", Vector3.new(x, rimY, z), 4.05, yaw, true) then
			plant(green, Vector3.new(x, 10.4, z), 0.72, 0.5, "paint", cream, 4.2, "trailing", seed)
		end
	end

	local function wallPot(side: number, z: number, y: number, seed: number)
		local shelf = wallAt(sideWall(side, 0, z), 0, y, 0.55)
		P(green, "WallBracket", Vector3.new(1.15, 0.1, 0.7), shelf, "powder", noShadow())
		local sit = shelf.Position + shelf.LookVector * 0.35 + Vector3.new(0, 0.06, 0)
		local species = if z > 10 then "PlantSucculent" else "PlantFern"
		local height = if species == "PlantSucculent" then 0.72 else 1.25
		local yaw = math.rad((seed * 29) % 360)
		if not placeMeshPlant(green, species, sit, height, yaw, false) then
			plant(green, shelf.Position + Vector3.new(0, 0.05, 0), 0.7, 0.45, "paint", clay, 1.5, "trailing", seed)
		end
	end

	for _, spot in { { -8, -20 }, { 8, -20 }, { -9, 7 }, { 9, 7 }, { -7, 22 }, { 7, 22 }, { -18, -8 }, { 18, 14 } } do
		suspend(spot[1], spot[2], 40 + math.abs(spot[1]) + math.abs(spot[2]))
	end

	for _, side in { -1, 1 } do
		for _, z in { -6, 6, 19 } do
			wallPot(side, z, 8.6, 80 + side * 10 + z)
		end
	end

	-- Species and whole-plant height. Corners get the tall fiddle-leaf; the aisle stays open.
	local floorPots = {
		{ Vector3.new(-29.5, FLOOR_TOP, -23.4), "PlantFig", 5.3, 31 },
		{ Vector3.new(30.2, FLOOR_TOP, -22.8), "PlantFern", 3.1, 32 },
		{ Vector3.new(-18.5, FLOOR_TOP, -23.8), "PlantSnake", 3.3, 33 },
		{ Vector3.new(16.5, FLOOR_TOP, -23.2), "PlantFern", 2.4, 34 },
		{ Vector3.new(-14.5, FLOOR_TOP, -5.2), "PlantSnake", 2.9, 35 },
		{ Vector3.new(14.5, FLOOR_TOP, -5.2), "PlantFern", 2.2, 36 },
		{ Vector3.new(-15.5, FLOOR_TOP, 23.4), "PlantFig", 4.1, 37 },
		{ Vector3.new(15.5, FLOOR_TOP, 23.4), "PlantSnake", 3.2, 38 },
		{ Vector3.new(-30.5, FLOOR_TOP, 8), "PlantSnake", 3.0, 39 },
		{ Vector3.new(30.5, FLOOR_TOP, 10), "PlantFern", 2.7, 41 },
		{ Vector3.new(-31.2, FLOOR_TOP, 22.6), "PlantFern", 2.5, 42 },
		{ Vector3.new(31.2, FLOOR_TOP, 22.8), "PlantFig", 4.4, 43 },
	}
	for _, spot in floorPots do
		local at = spot[1] :: Vector3
		local species = spot[2] :: string
		local height = spot[3] :: number
		local seed = spot[4] :: number
		local yaw = math.rad((seed * 53) % 360)
		if not placeMeshPlant(green, species, at, height, yaw, false) then
			local kind = if species == "PlantFig" then "fig" elseif species == "PlantSnake" then "snake" else "fern"
			plant(green, at, 1.1, 1.0, "paint", cream, height * 0.7, kind, seed)
		end
	end

	for _, x in { -15.2, -19.6, -24.2, 15.2, 19.6, 24.2 } do
		local at = Vector3.new(x, 3.97, -26.28)
		local seed = 100 + math.floor(x)
		if not placeMeshPlant(green, "PlantSucculent", at, 0.68, math.rad((seed * 41) % 360), false) then
			plant(green, at, 0.55, 0.4, "paint", cream, 0.45, "succulent", seed)
		end
	end
end

function Interior.build(lobby: Model)
	local root = Surfaces.folder(lobby, "Interior")
	restyle(lobby)
	local steps: { [string]: () -> () } = {
		floors = function()
			buildFloorZones(root)
		end,
		dado = function()
			buildDado(root)
		end,
		ceiling = function()
			buildCeiling(root)
		end,
		bays = function()
			buildBays(root)
		end,
		reception = function()
			buildReception(root)
		end,
		lounge = function()
			buildLounge(root)
		end,
		backWall = function()
			buildBackWall(root)
		end,
		storage = function()
			buildStorage(root)
		end,
		washUp = function()
			buildWashUp(root)
		end,
		details = function()
			buildDetails(root)
		end,
		greenery = function()
			buildGreenery(root)
		end,
	}
	-- A failure in one dressing step must never stop the lobby (and the game) from loading.
	for name, step in steps do
		local ok, err = pcall(step)
		if not ok then
			warn(`[InkMasters] Interior step {name} failed: {err}`)
		end
	end
end

return Interior
