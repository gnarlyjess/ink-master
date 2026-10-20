--!strict

-- A restroom opening off the back-right corner of the parlour.
-- The shell leaves a doorway in WallBack (x 26 to 30). Fixtures are modelled in
-- Blender (blender-out/build_bath.py) and baked here the same way as the plants.

local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local Surfaces = require(script.Parent.Surfaces)

local P = Surfaces.part
local post = Surfaces.post

local Bathroom = {}

local FLOOR_Y = 0.4
local CEILING_Y = 16.2
local DROP_Y = 10.25

-- Clear interior, matching the doorway cut in Lobby.buildShell.
-- X values authored for parlour half-width 34; scaled to match Lobby/Interior slim.
local X_SCALE = 28 / 34
local X0 = 22.4 * X_SCALE
local X1 = 33.5 * X_SCALE
local Z0 = 27.5
local Z1 = 40.2
local DOOR_X0 = 26 * X_SCALE
local DOOR_X1 = 30 * X_SCALE
local DOOR_TOP = 8.1

local CREAM = Color3.fromRGB(236, 232, 224)
local TILE = Color3.fromRGB(232, 228, 220)
local WARM = Color3.fromRGB(255, 214, 170)
local BOTANICAL = "rbxassetid://122988882422710"

local FIXTURES = { "BathToilet", "BathVanity", "BathMirror", "BathTowel", "BathPendant" }

local function collide(tint: Color3?): Surfaces.Opts
	return { collide = true, tint = tint }
end

local function quiet(tint: Color3?): Surfaces.Opts
	return { tint = tint, shadow = false }
end

local function bounds(model: Model): (Vector3, Vector3)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local cf = part.CFrame
			local h = part.Size * 0.5
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local p = cf:PointToWorldSpace(Vector3.new(x * h.X, y * h.Y, z * h.Z))
						minV = Vector3.new(math.min(minV.X, p.X), math.min(minV.Y, p.Y), math.min(minV.Z, p.Z))
						maxV = Vector3.new(math.max(maxV.X, p.X), math.max(maxV.Y, p.Y), math.max(maxV.Z, p.Z))
					end
				end
			end
		end
	end
	return minV, maxV
end

local function nudge(model: Model, delta: Vector3)
	model:PivotTo(model:GetPivot() + delta)
end

local function finishMesh(part: BasePart)
	local name = part.Name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Reflectance = 0
	if string.find(name, "Brass") or string.find(name, "TowelBar") then
		Surfaces.apply(part, "brass")
	elseif string.find(name, "Wood") or string.find(name, "Frame") then
		Surfaces.apply(part, "walnut")
	elseif string.find(name, "Stone") then
		Surfaces.apply(part, "stone", Color3.fromRGB(255, 250, 244))
	elseif string.find(name, "Glass") then
		Surfaces.apply(part, "glass", Color3.fromRGB(210, 222, 224))
		part.Transparency = 0.2
		part.Reflectance = 0.35
	elseif string.find(name, "Cloth") then
		Surfaces.apply(part, "fabric", Color3.fromRGB(54, 50, 46))
		part.DoubleSided = true
	elseif string.find(name, "Shade") then
		Surfaces.apply(part, "paint", Color3.fromRGB(255, 236, 214))
		part.Transparency = 0.12
	elseif string.find(name, "Bulb") then
		Surfaces.apply(part, "neon", WARM)
		part.CastShadow = false
	elseif string.find(name, "Seat") then
		Surfaces.apply(part, "paint", Color3.fromRGB(246, 242, 234))
	else
		Surfaces.apply(part, "paint", CREAM)
	end
end

local function bakeFixtures()
	local apiOk = pcall(function()
		local probe = AssetService:CreateEditableMesh()
		probe:Destroy()
	end)
	if not apiOk then
		warn("[InkMasters] Restroom meshes need Allow Mesh / Image APIs, in Experience Settings, Security")
		return
	end

	local folder = ServerStorage:FindFirstChild("ParlourImport")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "ParlourImport"
		folder.Parent = ServerStorage
	end

	local meshApi: any = nil
	local dataModule = script.Parent:FindFirstChild("BathMesh")
	if dataModule ~= nil and dataModule:IsA("ModuleScript") then
		local loaded, data = pcall(require, dataModule)
		if loaded then
			meshApi = data
		end
	end

	local function hasSurface(model: Instance): boolean
		if not model:IsA("Model") then
			return false
		end
		local found = false
		for _, part in model:GetDescendants() do
			if part:IsA("MeshPart") then
				found = true
				break
			end
		end
		return found
	end

	for _, species in FIXTURES do
		local existing = folder:FindFirstChild(species)
		if existing ~= nil and hasSurface(existing) then
			continue
		end
		if existing ~= nil then
			existing:Destroy()
		end
		if meshApi == nil or type(meshApi.get) ~= "function" then
			warn(`[InkMasters] Could not load {species}`)
			continue
		end
		local okBody, packed = pcall(meshApi.get, species)
		if not okBody or type(packed) ~= "string" then
			warn(`[InkMasters] Could not load {species}`)
			continue
		end
		local decoded, pieces = pcall(function()
			return HttpService:JSONDecode(packed)
		end)
		if not decoded or type(pieces) ~= "table" then
			warn(`[InkMasters] {species} mesh data was not readable`)
			continue
		end
		local model = Instance.new("Model")
		model.Name = species
		model.WorldPivot = CFrame.identity
		local built = true
		for _, piece in pieces do
			if type(piece) ~= "table" or type(piece.verts) ~= "table" or type(piece.faces) ~= "table" then
				built = false
				break
			end
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
			meshPart.CFrame = CFrame.new(center)
			meshPart.Parent = model
			task.wait(0.05)
		end
		if built and hasSurface(model) then
			model.Parent = folder
		else
			model:Destroy()
		end
		task.wait(0.15)
	end
end

local function cloneFixture(species: string): Model?
	local import = ServerStorage:FindFirstChild("ParlourImport")
	local src = import and import:FindFirstChild(species)
	if src == nil or not src:IsA("Model") then
		return nil
	end
	local copy = src:Clone()
	copy.WorldPivot = CFrame.identity
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			finishMesh(part)
		end
	end
	return copy
end

local function faceNorth(model: Model, centerX: number, floorY: number, wallZ: number)
	local minV, maxV = bounds(model)
	nudge(model, Vector3.new(centerX - (minV.X + maxV.X) * 0.5, floorY - minV.Y, (wallZ - 0.08) - maxV.Z))
end

local function faceEast(model: Model, wallX: number, floorY: number, centerZ: number)
	model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.pi / 2, 0))
	local minV, maxV = bounds(model)
	nudge(model, Vector3.new((wallX - 0.06) - maxV.X, floorY - minV.Y, centerZ - (minV.Z + maxV.Z) * 0.5))
end

local function hangOn(
	model: Model,
	yaw: number,
	wallAlong: number,
	centerAlong: number,
	centerY: number,
	useMaxY: boolean
)
	model:PivotTo(model:GetPivot() * CFrame.Angles(0, yaw, 0))
	local minV, maxV = bounds(model)
	local y = if useMaxY then centerY - maxV.Y else centerY - (minV.Y + maxV.Y) * 0.5
	-- yaw -90 leaves the back on min X (west wall). yaw +90 leaves it on max X (east wall).
	local x = if yaw < 0 then (wallAlong + 0.04) - minV.X else (wallAlong - 0.04) - maxV.X
	nudge(model, Vector3.new(x, y, centerAlong - (minV.Z + maxV.Z) * 0.5))
end

------------------------------------------------------------------------------------------
-- Room

local function buildShell(room: Instance)
	local cx = (X0 + X1) / 2
	local width = X1 - X0
	-- Keep tile clear of the doorway sill so the two floors never share a face (z-fight).
	local floorZ0 = Z0 + 0.55
	local floorDepth = Z1 - floorZ0
	local floorCz = (floorZ0 + Z1) / 2

	P(
		room,
		"BathFloor",
		Vector3.new(width, 0.08, floorDepth),
		CFrame.new(cx, FLOOR_Y + 0.04, floorCz),
		"tile",
		collide(TILE)
	)
	-- Stone sill in the opening only, a hair above both the parlour floor and the tile.
	P(
		room,
		"Threshold",
		Vector3.new(DOOR_X1 - DOOR_X0 - 0.2, 0.07, 0.85),
		CFrame.new((DOOR_X0 + DOOR_X1) / 2, FLOOR_Y + 0.085, Z0),
		"stone",
		collide(Color3.fromRGB(255, 248, 240))
	)

	local wallH = CEILING_Y
	local wallZ1 = Z1 + 0.55
	local function runWall(name: string, thickness: number, x: number, zStart: number)
		local length = wallZ1 - zStart
		P(
			room,
			name,
			Vector3.new(thickness, wallH, length),
			CFrame.new(x, wallH / 2, zStart + length / 2),
			"plaster",
			collide()
		)
	end
	-- West wall keys into the back wall. East wall meets the existing right wall without a doubled face.
	runWall("BathWallWest", 0.5, X0 - 0.25, 27.35)
	runWall("BathWallEast", 1, 34 * X_SCALE, 27.48)

	local northT = 0.55
	local winW = 3.5
	local winSill = 7.15
	local winTop = 9.25
	local winX = 30.1 * X_SCALE
	local northZ = Z1 + northT / 2
	local westOuter = X0 - 0.5
	local eastOuter = 34.5 * X_SCALE
	local leftW = winX - winW / 2 - westOuter
	local rightW = eastOuter - (winX + winW / 2)
	P(
		room,
		"BathWallNorth",
		Vector3.new(leftW, wallH, northT),
		CFrame.new(westOuter + leftW / 2, wallH / 2, northZ),
		"plaster",
		collide()
	)
	P(
		room,
		"BathWallNorth",
		Vector3.new(rightW, wallH, northT),
		CFrame.new(winX + winW / 2 + rightW / 2, wallH / 2, northZ),
		"plaster",
		collide()
	)
	P(
		room,
		"BathWallNorth",
		Vector3.new(winW, winSill, northT),
		CFrame.new(winX, winSill / 2, northZ),
		"plaster",
		collide()
	)
	P(
		room,
		"BathWallNorth",
		Vector3.new(winW, wallH - winTop, northT),
		CFrame.new(winX, (wallH + winTop) / 2, northZ),
		"plaster",
		collide()
	)
	local glassH = winTop - winSill
	P(
		room,
		"BathWindow",
		Vector3.new(winW - 0.16, glassH - 0.12, 0.08),
		CFrame.new(winX, (winSill + winTop) / 2, northZ),
		"glass",
		{ tint = Color3.fromRGB(214, 224, 220), transparency = 0.35, shadow = false }
	)
	P(room, "WindowFrame", Vector3.new(winW + 0.2, 0.1, 0.16), CFrame.new(winX, winSill, Z1 - 0.02), "walnut", quiet())
	P(room, "WindowFrame", Vector3.new(winW + 0.2, 0.1, 0.16), CFrame.new(winX, winTop, Z1 - 0.02), "walnut", quiet())
	P(
		room,
		"WindowMullion",
		Vector3.new(0.08, glassH, 0.12),
		CFrame.new(winX, (winSill + winTop) / 2, Z1 - 0.02),
		"walnut",
		quiet()
	)

	local roofZ0 = 27.52
	local roofZ1 = Z1 + 0.7
	local roofX0 = X0 - 0.7
	local roofX1 = 34.6 * X_SCALE
	P(
		room,
		"BathRoof",
		Vector3.new(roofX1 - roofX0, 0.55, roofZ1 - roofZ0),
		CFrame.new((roofX0 + roofX1) / 2, CEILING_Y + 0.28, (roofZ0 + roofZ1) / 2),
		"plaster",
		{ collide = true, tint = Color3.fromRGB(136, 132, 128) }
	)
	P(
		room,
		"BathCeiling",
		Vector3.new(width - 0.15, 0.16, depth - 0.15),
		CFrame.new(cx, DROP_Y, cz),
		"plaster",
		{ collide = true, tint = Color3.fromRGB(236, 230, 220) }
	)

	local tileH = 3.85
	local tileY = FLOOR_Y + tileH / 2
	local function wainscot(size: Vector3, cf: CFrame)
		P(room, "BathTile", size, cf, "tile", quiet(TILE))
	end
	wainscot(Vector3.new(0.06, tileH, depth - 0.1), CFrame.new(X0 + 0.04, tileY, cz))
	wainscot(Vector3.new(0.06, tileH, depth - 0.1), CFrame.new(X1 - 0.04, tileY, cz))
	wainscot(Vector3.new(width - 0.2, tileH, 0.06), CFrame.new(cx, tileY, Z1 - 0.04))
	local sideW = DOOR_X0 - X0 - 0.15
	wainscot(Vector3.new(sideW, tileH, 0.06), CFrame.new(X0 + 0.1 + sideW / 2, tileY, Z0 + 0.04))
	local sideE = X1 - DOOR_X1 - 0.15
	wainscot(Vector3.new(sideE, tileH, 0.06), CFrame.new(DOOR_X1 + 0.05 + sideE / 2, tileY, Z0 + 0.04))
	P(
		room,
		"TileCap",
		Vector3.new(width - 0.1, 0.1, 0.12),
		CFrame.new(cx, FLOOR_Y + tileH + 0.04, Z1 - 0.08),
		"walnut",
		quiet()
	)
	P(
		room,
		"TileCap",
		Vector3.new(0.12, 0.1, depth - 0.2),
		CFrame.new(X0 + 0.08, FLOOR_Y + tileH + 0.04, cz),
		"walnut",
		quiet()
	)
	P(
		room,
		"TileCap",
		Vector3.new(0.12, 0.1, depth - 0.2),
		CFrame.new(X1 - 0.08, FLOOR_Y + tileH + 0.04, cz),
		"walnut",
		quiet()
	)
end

local function buildDoor(room: Instance)
	local midX = (DOOR_X0 + DOOR_X1) / 2
	local jambY = (FLOOR_Y + DOOR_TOP) / 2
	local jambH = DOOR_TOP - FLOOR_Y
	for _, x in { DOOR_X0 - 0.08, DOOR_X1 + 0.08 } do
		P(room, "DoorJamb", Vector3.new(0.18, jambH, 1.05), CFrame.new(x, jambY, Z0), "walnut", collide())
	end
	P(
		room,
		"DoorHead",
		Vector3.new(DOOR_X1 - DOOR_X0 + 0.36, 0.2, 1.05),
		CFrame.new(midX, DOOR_TOP + 0.08, Z0),
		"walnut",
		collide()
	)

	local plaque =
		P(room, "RestroomSign", Vector3.new(3.1, 0.62, 0.08), CFrame.new(midX, 9.05, 26.38), "powder", quiet())
	Surfaces.label(plaque, Enum.NormalId.Front, "RESTROOM", Color3.fromRGB(232, 206, 160), Enum.Font.GothamBold, 52, 0)
	Surfaces.label(plaque, Enum.NormalId.Back, "RESTROOM", Color3.fromRGB(232, 206, 160), Enum.Font.GothamBold, 52, 0)
	Surfaces.glow(plaque, WARM, 0.45, 9)

	local leafW = 3.7
	local leafH = 7.35
	local hinge = CFrame.new(DOOR_X0 + 0.12, FLOOR_Y + leafH / 2, Z0 + 0.18)
	local leafCf = hinge * CFrame.Angles(0, math.rad(-108), 0) * CFrame.new(leafW / 2, 0, 0)
	P(room, "DoorLeaf", Vector3.new(leafW, leafH, 0.16), leafCf, "walnut", collide())
	P(
		room,
		"DoorGlass",
		Vector3.new(leafW - 0.7, 2.6, 0.04),
		leafCf * CFrame.new(0, 1.5, 0),
		"glass",
		{ tint = Color3.fromRGB(220, 228, 224), transparency = 0.4, shadow = false }
	)
	P(
		room,
		"DoorPull",
		Vector3.new(0.08, 0.9, 0.08),
		leafCf * CFrame.new(leafW / 2 - 0.28, -0.4, -0.12),
		"brass",
		quiet()
	)
end

local function buildFallbackToilet(room: Instance, x: number)
	local z = Z1 - 1.05
	post(room, "ToiletBase", 0.45, 0.7, Vector3.new(x, FLOOR_Y, z), "paint", quiet(CREAM))
	P(room, "ToiletBowl", Vector3.new(1.15, 0.7, 1.45), CFrame.new(x, FLOOR_Y + 0.85, z - 0.15), "paint", quiet(CREAM))
	P(room, "ToiletTank", Vector3.new(1.15, 1.0, 0.5), CFrame.new(x, FLOOR_Y + 1.55, z + 0.45), "paint", quiet(CREAM))
	P(room, "Flush", Vector3.new(0.28, 0.06, 0.06), CFrame.new(x - 0.7, FLOOR_Y + 1.7, z + 0.45), "brass", quiet())
end

local function buildFallbackVanity(room: Instance, z: number)
	local x = X1 - 0.85
	P(room, "VanityCab", Vector3.new(1.5, 2.7, 2.7), CFrame.new(x, FLOOR_Y + 1.4, z), "walnut", collide())
	P(
		room,
		"VanityTop",
		Vector3.new(1.65, 0.1, 2.95),
		CFrame.new(x - 0.05, FLOOR_Y + 2.8, z),
		"stone",
		quiet(Color3.fromRGB(255, 250, 244))
	)
	P(room, "Basin", Vector3.new(1.15, 0.28, 0.85), CFrame.new(x - 0.15, FLOOR_Y + 3.0, z), "paint", quiet(CREAM))
	post(room, "Faucet", 0.45, 0.1, Vector3.new(x + 0.15, FLOOR_Y + 2.85, z), "brass", quiet())
end

local function buildFallbackMirror(room: Instance, z: number)
	P(room, "MirrorFrame", Vector3.new(0.1, 3.05, 2.25), CFrame.new(X1 - 0.08, 5.7, z), "walnut", quiet())
	local glass = P(
		room,
		"MirrorGlass",
		Vector3.new(0.04, 2.7, 1.95),
		CFrame.new(X1 - 0.14, 5.7, z),
		"glass",
		{ tint = Color3.fromRGB(210, 222, 224), transparency = 0.2, shadow = false }
	)
	glass.Reflectance = 0.35
end

local function buildFixtures(room: Instance)
	local toiletX = 25.55 * X_SCALE
	local vanityZ = 33.6

	local toilet = cloneFixture("BathToilet")
	if toilet ~= nil then
		faceNorth(toilet, toiletX, FLOOR_Y, Z1)
		toilet.Name = "Toilet"
		toilet.Parent = room
	else
		buildFallbackToilet(room, toiletX)
	end
	P(
		room,
		"ToiletBlock",
		Vector3.new(1.2, 1.15, 1.65),
		CFrame.new(toiletX, FLOOR_Y + 0.6, Z1 - 0.95),
		"paint",
		{ collide = true, transparency = 1, shadow = false }
	)
	local seat = Instance.new("Seat")
	seat.Name = "ToiletSeat"
	seat.Size = Vector3.new(1.25, 0.16, 1.15)
	seat.CFrame =
		CFrame.lookAt(Vector3.new(toiletX, FLOOR_Y + 1.18, Z1 - 1.25), Vector3.new(toiletX, FLOOR_Y + 1.18, Z0))
	seat.Anchored = true
	seat.Transparency = 1
	seat.CanCollide = true
	seat.CastShadow = false
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = room

	local vanity = cloneFixture("BathVanity")
	if vanity ~= nil then
		faceEast(vanity, X1, FLOOR_Y, vanityZ)
		vanity.Name = "Vanity"
		vanity.Parent = room
	else
		buildFallbackVanity(room, vanityZ)
	end
	P(
		room,
		"VanityBlock",
		Vector3.new(1.85, 2.75, 2.9),
		CFrame.new(X1 - 0.98, FLOOR_Y + 1.4, vanityZ),
		"paint",
		{ collide = true, transparency = 1, shadow = false }
	)

	local mirror = cloneFixture("BathMirror")
	if mirror ~= nil then
		hangOn(mirror, math.pi / 2, X1, vanityZ, 5.85, false)
		mirror.Name = "Mirror"
		mirror.Parent = room
	else
		buildFallbackMirror(room, vanityZ)
	end
	for _, side in { -1.45, 1.45 } do
		local sconce = P(
			room,
			"Sconce",
			Vector3.new(0.16, 0.55, 0.16),
			CFrame.new(X1 - 0.22, 6.15, vanityZ + side),
			"brass",
			quiet()
		)
		P(
			room,
			"SconceShade",
			Vector3.new(0.22, 0.28, 0.22),
			sconce.CFrame * CFrame.new(-0.12, -0.15, 0),
			"paint",
			quiet(Color3.fromRGB(255, 232, 206))
		)
		Surfaces.glow(sconce, WARM, 0.7, 7)
	end

	local towel = cloneFixture("BathTowel")
	if towel ~= nil then
		hangOn(towel, -math.pi / 2, X0, 36.4, 4.55, true)
		towel.Name = "Towel"
		towel.Parent = room
	else
		P(room, "TowelBar", Vector3.new(0.08, 0.08, 1.5), CFrame.new(X0 + 0.18, 4.5, 36.4), "brass", quiet())
		P(
			room,
			"Towel",
			Vector3.new(0.08, 0.85, 1.2),
			CFrame.new(X0 + 0.22, 4.0, 36.4),
			"fabric",
			quiet(Color3.fromRGB(54, 50, 46))
		)
	end

	post(room, "PaperHolder", 0.08, 0.42, Vector3.new(24.15 * X_SCALE, FLOOR_Y + 1.55, Z1 - 0.35), "brass", quiet())
	P(
		room,
		"Paper",
		Vector3.new(0.28, 0.28, 0.28),
		CFrame.new(24.15 * X_SCALE, FLOOR_Y + 1.7, Z1 - 0.55),
		"paint",
		quiet(Color3.fromRGB(244, 240, 232))
	)

	post(
		room,
		"WasteBin",
		1.15,
		0.72,
		Vector3.new(X0 + 0.7, FLOOR_Y, Z1 - 0.7),
		"powder",
		{ collide = true, tint = Color3.fromRGB(72, 72, 76) }
	)

	local printCf = CFrame.lookAt(Vector3.new(X0 + 0.1, 6.7, 31.4), Vector3.new(X0 + 1, 6.7, 31.4))
	P(room, "PrintFrame", Vector3.new(1.7, 2.15, 0.08), printCf, "walnut", quiet())
	local art = P(room, "Print", Vector3.new(1.4, 1.85, 0.04), printCf * CFrame.new(0, 0, -0.06), "paint", quiet(CREAM))
	Surfaces.decal(art, Enum.NormalId.Front, BOTANICAL)

	local pendant = cloneFixture("BathPendant")
	local lightHost: BasePart? = nil
	if pendant ~= nil then
		local minV, maxV = bounds(pendant)
		nudge(
			pendant,
			Vector3.new(
				(X0 + X1) / 2 - (minV.X + maxV.X) * 0.5,
				DROP_Y - maxV.Y,
				(Z0 + Z1) / 2 - (minV.Z + maxV.Z) * 0.5
			)
		)
		pendant.Name = "Pendant"
		pendant.Parent = room
		local bulb = pendant:FindFirstChild("BathPendantBulb", true)
		if bulb ~= nil and bulb:IsA("BasePart") then
			lightHost = bulb
		else
			local anyPart = pendant:FindFirstChildWhichIsA("BasePart", true)
			if anyPart ~= nil then
				lightHost = anyPart
			end
		end
	else
		lightHost = P(
			room,
			"Pendant",
			Vector3.new(0.9, 0.45, 0.9),
			CFrame.new((X0 + X1) / 2, DROP_Y - 0.7, (Z0 + Z1) / 2),
			"paint",
			quiet(Color3.fromRGB(255, 236, 214))
		)
	end
	if lightHost ~= nil then
		Surfaces.glow(lightHost, WARM, 1.35, 16)
	end
end

function Bathroom.build(parent: Instance)
	local room = Surfaces.folder(parent, "Bathroom")
	buildShell(room)
	buildDoor(room)
	local baked, bakeErr = pcall(bakeFixtures)
	if not baked then
		warn(`[InkMasters] Restroom meshes could not be prepared: {bakeErr}`)
	end
	buildFixtures(room)
end

return Bathroom
