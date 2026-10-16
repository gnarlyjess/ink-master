--!strict

-- Builds the tattoo shop when the server starts.
-- This is a blockout: a readable parlour to spawn in, not finished art.
-- Players land inside, walk the floor, and sit while the round card runs on top.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local InkColors = require(ReplicatedStorage.Shared.InkColors)
local StencilDefinitions = require(ReplicatedStorage.Shared.StencilDefinitions)

local PREFIX = "[InkMasters]"

local ROOM_WIDTH = 68
local ROOM_DEPTH = 54
local WALL = 1
local CEILING_Y = 16.2
local FLOOR_TOP = 0.4
local HALF_W = ROOM_WIDTH / 2
local HALF_D = ROOM_DEPTH / 2
local DOOR_HALF = 5
local DOOR_HEIGHT = 8.5

local PALETTE = {
	ink = Color3.fromRGB(10, 9, 14),
	panel = Color3.fromRGB(22, 18, 30),
	wall = Color3.fromRGB(124, 110, 138),
	trim = Color3.fromRGB(96, 80, 112),
	wood = Color3.fromRGB(148, 116, 104),
	woodDark = Color3.fromRGB(124, 96, 88),
	ceiling = Color3.fromRGB(86, 76, 102),
	leather = Color3.fromRGB(42, 24, 32),
	brass = Color3.fromRGB(166, 124, 72),
	paper = Color3.fromRGB(232, 220, 196),
	lot = Color3.fromRGB(58, 56, 64),
	magenta = Color3.fromRGB(255, 78, 146),
	violet = Color3.fromRGB(176, 112, 255),
	gold = Color3.fromRGB(242, 196, 122),
	warm = Color3.fromRGB(255, 214, 170),
}

local INK_ROTATION = { "black", "black", "red", "black", "gold", "teal", "magenta", "black", "violet" }

type PartSpec = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	collide: boolean?,
	transparency: number?,
	reflectance: number?,
	shape: Enum.PartType?,
	castShadow: boolean?,
}

local built = false

local function applyBase(part: BasePart, spec: PartSpec)
	part.Name = spec.name
	part.Anchored = true
	part.Size = spec.size
	part.CFrame = spec.cframe
	part.Color = spec.color
	part.Material = spec.material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = if spec.collide == nil then true else spec.collide
	part.Transparency = spec.transparency or 0
	part.Reflectance = spec.reflectance or 0
	part.CastShadow = if spec.castShadow == nil then true else spec.castShadow
	part.Parent = spec.parent
end

local function makePart(spec: PartSpec): Part
	local part = Instance.new("Part")
	part.Shape = spec.shape or Enum.PartType.Block
	applyBase(part, spec)
	return part
end

local function makeSeat(spec: PartSpec): Seat
	local seat = Instance.new("Seat")
	seat.Disabled = false
	applyBase(seat, spec)
	return seat
end

local function makeFolder(parent: Instance, name: string): Folder
	local child = Instance.new("Folder")
	child.Name = name
	child.Parent = parent
	return child
end

local function addLight(parent: Instance, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
end

local function addSpot(parent: Instance, color: Color3)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 78
	spot.Brightness = 4
	spot.Range = 22
	spot.Color = color
	spot.Shadows = false
	spot.Parent = parent
end

local function surfaceText(part: BasePart, text: string, color: Color3, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Lettering"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.08, 0)
	padding.PaddingRight = UDim.new(0.08, 0)
	padding.Parent = label
end

local function faceToward(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction)
end

local function upright(cf: CFrame): CFrame
	return cf * CFrame.Angles(0, 0, math.rad(90))
end

local function shapeAt(index: number): string
	local catalogue = StencilDefinitions.all
	local stencil = catalogue[((index - 1) % #catalogue) + 1]
	if stencil == nil then
		return "disc"
	end
	return stencil.shape
end

local function inkAt(index: number): string
	local choice = INK_ROTATION[((index - 1) % #INK_ROTATION) + 1]
	if choice == nil then
		return "black"
	end
	return choice
end

local function clearDefaultPlace()
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") or child.Name == "Baseplate" then
			child:Destroy()
		end
	end
end

local function dressLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(190, 186, 200)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 168, 176)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.85
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ExposureCompensation = 0.25
	Lighting.FogStart = 180
	Lighting.FogEnd = 500
	Lighting.FogColor = Color3.fromRGB(186, 184, 196)

	local function effect(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing ~= nil then
			existing:Destroy()
		end
		local created = Instance.new(className)
		created.Name = name
		created.Parent = Lighting
		return created
	end

	local bloom = effect("BloomEffect", "InkMastersBloom")
	if bloom:IsA("BloomEffect") then
		bloom.Intensity = 0.35
		bloom.Size = 28
		bloom.Threshold = 1.05
	end

	local atmosphere = effect("Atmosphere", "InkMastersAtmosphere")
	if atmosphere:IsA("Atmosphere") then
		atmosphere.Density = 0.08
		atmosphere.Offset = 0.05
		atmosphere.Color = Color3.fromRGB(196, 190, 204)
		atmosphere.Decay = Color3.fromRGB(170, 166, 180)
		atmosphere.Glare = 0.05
		atmosphere.Haze = 0.4
	end

	local grade = effect("ColorCorrectionEffect", "InkMastersGrade")
	if grade:IsA("ColorCorrectionEffect") then
		grade.Brightness = 0.05
		grade.Contrast = 0.06
		grade.Saturation = 0.08
		grade.TintColor = Color3.fromRGB(255, 236, 244)
	end
end

local function buildCard(
	parent: Instance,
	position: Vector3,
	direction: Vector3,
	width: number,
	height: number,
	index: number
)
	local tilt = ((index % 5) - 2) * 1.5
	local cf = faceToward(position, direction) * CFrame.Angles(0, 0, math.rad(tilt))

	makePart({
		name = "FlashFrame",
		size = Vector3.new(width + 0.28, height + 0.28, 0.08),
		cframe = cf * CFrame.new(0, 0, 0.08),
		color = PALETTE.ink,
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		collide = false,
	})

	local paper = makePart({
		name = "FlashCard",
		size = Vector3.new(width, height, 0.06),
		cframe = cf,
		color = PALETTE.paper,
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		collide = false,
		castShadow = false,
	})
	paper:SetAttribute("FlashShape", shapeAt(index))
	paper:SetAttribute("FlashInk", inkAt(index))
end

local function buildWordmark(
	parent: Instance,
	position: Vector3,
	direction: Vector3,
	width: number,
	height: number,
	text: string,
	glow: Color3,
	bothSides: boolean?
)
	local cf = faceToward(position, direction)
	local backing = makePart({
		name = "WordmarkGlow",
		size = Vector3.new(width + 0.45, height + 0.36, 0.16),
		cframe = cf * CFrame.new(0, 0, 0.12),
		color = glow,
		material = Enum.Material.Neon,
		parent = parent,
		collide = false,
		castShadow = false,
	})
	addLight(backing, glow, 1.3, 14)

	local plate = makePart({
		name = "Wordmark",
		size = Vector3.new(width, height, 0.1),
		cframe = cf,
		color = PALETTE.ink,
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		collide = false,
	})
	surfaceText(plate, text, PALETTE.gold, Enum.NormalId.Front)
	if bothSides then
		surfaceText(plate, text, PALETTE.gold, Enum.NormalId.Back)
	end
end

local function buildShell(lobby: Model)
	local shell = makeFolder(lobby, "Shell")

	makePart({
		name = "Lot",
		size = Vector3.new(160, 1, 150),
		cframe = CFrame.new(0, -0.5, 4),
		color = PALETTE.lot,
		material = Enum.Material.Asphalt,
		parent = shell,
	})

	local floor = makePart({
		name = "Floor",
		size = Vector3.new(ROOM_WIDTH - WALL - 0.2, FLOOR_TOP, ROOM_DEPTH + WALL),
		cframe = CFrame.new(0, FLOOR_TOP / 2, 0),
		color = PALETTE.woodDark,
		material = Enum.Material.Wood,
		parent = shell,
		reflectance = 0.06,
	})
	lobby.PrimaryPart = floor

	local porchDepth = 12
	makePart({
		name = "Porch",
		size = Vector3.new(18, FLOOR_TOP, porchDepth),
		cframe = CFrame.new(0, FLOOR_TOP / 2, -HALF_D - WALL / 2 - porchDepth / 2 + 0.3),
		color = Color3.fromRGB(42, 40, 46),
		material = Enum.Material.Concrete,
		parent = shell,
	})

	local plankCount = 8
	local plankSpan = ROOM_WIDTH - WALL * 2 - 1
	local plankWidth = plankSpan / plankCount
	for index = 1, plankCount do
		local shade = if index % 2 == 0 then PALETTE.wood else PALETTE.woodDark
		local x = -plankSpan / 2 + plankWidth * (index - 0.5)
		makePart({
			name = "Plank",
			size = Vector3.new(plankWidth - 0.12, 0.05, ROOM_DEPTH - 3),
			cframe = CFrame.new(x, FLOOR_TOP + 0.03, 1),
			color = shade,
			material = Enum.Material.Wood,
			parent = shell,
			collide = false,
		})
	end

	makePart({
		name = "Rug",
		size = Vector3.new(7.5, 0.06, 30),
		cframe = CFrame.new(0, FLOOR_TOP + 0.08, 4),
		color = Color3.fromRGB(58, 22, 40),
		material = Enum.Material.Fabric,
		parent = shell,
		collide = false,
	})

	makePart({
		name = "Ceiling",
		size = Vector3.new(ROOM_WIDTH + WALL, 0.6, ROOM_DEPTH + WALL),
		cframe = CFrame.new(0, CEILING_Y + 0.3, 0),
		color = PALETTE.ceiling,
		material = Enum.Material.SmoothPlastic,
		parent = shell,
	})

	local wallSizeZ = ROOM_DEPTH + WALL
	makePart({
		name = "WallLeft",
		size = Vector3.new(WALL, CEILING_Y, wallSizeZ),
		cframe = CFrame.new(-HALF_W, CEILING_Y / 2, 0),
		color = PALETTE.wall,
		material = Enum.Material.SmoothPlastic,
		parent = shell,
	})
	makePart({
		name = "WallRight",
		size = Vector3.new(WALL, CEILING_Y, wallSizeZ),
		cframe = CFrame.new(HALF_W, CEILING_Y / 2, 0),
		color = PALETTE.wall,
		material = Enum.Material.SmoothPlastic,
		parent = shell,
	})
	makePart({
		name = "WallBack",
		size = Vector3.new(ROOM_WIDTH + WALL, CEILING_Y, WALL),
		cframe = CFrame.new(0, CEILING_Y / 2, HALF_D),
		color = PALETTE.wall,
		material = Enum.Material.SmoothPlastic,
		parent = shell,
	})

	local sideWidth = HALF_W + WALL / 2 - DOOR_HALF
	local sideCenter = DOOR_HALF + sideWidth / 2
	makePart({
		name = "WallFrontLeft",
		size = Vector3.new(sideWidth, CEILING_Y, WALL),
		cframe = CFrame.new(-sideCenter, CEILING_Y / 2, -HALF_D),
		color = PALETTE.wall,
		material = Enum.Material.SmoothPlastic,
		parent = shell,
	})
	makePart({
		name = "WallFrontRight",
		size = Vector3.new(sideWidth, CEILING_Y, WALL),
		cframe = CFrame.new(sideCenter, CEILING_Y / 2, -HALF_D),
		color = PALETTE.wall,
		material = Enum.Material.SmoothPlastic,
		parent = shell,
	})

	local headerHeight = CEILING_Y - DOOR_HEIGHT
	makePart({
		name = "DoorHeader",
		size = Vector3.new(DOOR_HALF * 2, headerHeight, WALL),
		cframe = CFrame.new(0, DOOR_HEIGHT + headerHeight / 2, -HALF_D),
		color = PALETTE.wall,
		material = Enum.Material.SmoothPlastic,
		parent = shell,
	})

	makePart({
		name = "Threshold",
		size = Vector3.new(DOOR_HALF * 2 - 0.4, 0.08, 0.35),
		cframe = CFrame.new(0, FLOOR_TOP + 0.05, -HALF_D),
		color = PALETTE.brass,
		material = Enum.Material.Metal,
		parent = shell,
		collide = false,
	})

	local function baseboard(size: Vector3, cframe: CFrame)
		makePart({
			name = "Baseboard",
			size = size,
			cframe = cframe,
			color = PALETTE.trim,
			material = Enum.Material.SmoothPlastic,
			parent = shell,
			collide = false,
		})
	end

	local boardY = FLOOR_TOP + 0.55
	baseboard(Vector3.new(ROOM_WIDTH - 2, 1.1, 0.18), CFrame.new(0, boardY, HALF_D - WALL / 2 - 0.2))
	baseboard(Vector3.new(0.18, 1.1, ROOM_DEPTH - 2), CFrame.new(-HALF_W + WALL / 2 + 0.2, boardY, 0))
	baseboard(Vector3.new(0.18, 1.1, ROOM_DEPTH - 2), CFrame.new(HALF_W - WALL / 2 - 0.2, boardY, 0))
	baseboard(Vector3.new(sideWidth - 1, 1.1, 0.18), CFrame.new(-sideCenter, boardY, -HALF_D + WALL / 2 + 0.2))
	baseboard(Vector3.new(sideWidth - 1, 1.1, 0.18), CFrame.new(sideCenter, boardY, -HALF_D + WALL / 2 + 0.2))

	for _, beamZ in { -10, 8 } do
		makePart({
			name = "Beam",
			size = Vector3.new(ROOM_WIDTH - 4, 0.35, 0.45),
			cframe = CFrame.new(0, CEILING_Y - 0.4, beamZ),
			color = PALETTE.ink,
			material = Enum.Material.Metal,
			parent = shell,
			collide = false,
		})
	end

	local function cove(name: string, x: number, color: Color3)
		local tube = makePart({
			name = name,
			size = Vector3.new(0.28, 0.28, ROOM_DEPTH - 8),
			cframe = CFrame.new(x, CEILING_Y - 1.1, 2),
			color = color,
			material = Enum.Material.Neon,
			parent = shell,
			collide = false,
			castShadow = false,
		})
		addLight(tube, color, 2, 28)
	end

	cove("CoveLeft", -HALF_W + 2.2, PALETTE.magenta)
	cove("CoveRight", HALF_W - 2.2, PALETTE.violet)

	local fill = makePart({
		name = "FillLight",
		size = Vector3.new(0.4, 0.4, 0.4),
		cframe = CFrame.new(0, CEILING_Y - 1.4, 0),
		color = PALETTE.warm,
		material = Enum.Material.Neon,
		parent = shell,
		collide = false,
		castShadow = false,
		shape = Enum.PartType.Ball,
	})
	addLight(fill, Color3.fromRGB(255, 244, 230), 2.4, 60)

	for index, lightZ in { -12, 6, 18 } do
		local lamp = makePart({
			name = `ShopLight{index}`,
			size = Vector3.new(7, 0.22, 1.4),
			cframe = CFrame.new(0, CEILING_Y - 0.4, lightZ),
			color = Color3.fromRGB(255, 236, 214),
			material = Enum.Material.Neon,
			parent = shell,
			collide = false,
			castShadow = false,
		})
		addLight(lamp, Color3.fromRGB(255, 244, 230), 2.2, 34)
	end
end

local function buildStation(parent: Instance, index: number, origin: Vector3, yaw: number)
	local cf = CFrame.new(origin) * CFrame.Angles(0, yaw, 0)
	local function at(offset: Vector3): CFrame
		return cf * CFrame.new(offset)
	end

	makePart({
		name = `StationMat{index}`,
		size = Vector3.new(8.5, 0.05, 9.5),
		cframe = at(Vector3.new(0.4, 0.08, 0)),
		color = Color3.fromRGB(18, 14, 20),
		material = Enum.Material.Fabric,
		parent = parent,
		collide = false,
	})

	local legOffsets = {
		Vector3.new(-1.15, 1.35, -2.7),
		Vector3.new(1.15, 1.35, -2.7),
		Vector3.new(-1.15, 1.35, 2.7),
		Vector3.new(1.15, 1.35, 2.7),
	}
	for _, offset in legOffsets do
		makePart({
			name = "BedLeg",
			size = Vector3.new(0.22, 2.7, 0.22),
			cframe = at(offset),
			color = PALETTE.brass,
			material = Enum.Material.Metal,
			parent = parent,
		})
	end

	makePart({
		name = "BedFrame",
		size = Vector3.new(2.7, 0.22, 6.3),
		cframe = at(Vector3.new(0, 2.8, 0)),
		color = PALETTE.ink,
		material = Enum.Material.Metal,
		parent = parent,
	})
	makePart({
		name = "Mattress",
		size = Vector3.new(2.35, 0.32, 5.7),
		cframe = at(Vector3.new(0, 3.05, 0.05)),
		color = PALETTE.leather,
		material = Enum.Material.Leather,
		parent = parent,
	})
	makePart({
		name = "Pillow",
		size = Vector3.new(1.55, 0.28, 1.15),
		cframe = at(Vector3.new(0, 3.28, -2.15)),
		color = Color3.fromRGB(228, 216, 206),
		material = Enum.Material.Fabric,
		parent = parent,
		collide = false,
	})

	makePart({
		name = "StoolPole",
		size = Vector3.new(2.05, 0.22, 0.22),
		cframe = upright(at(Vector3.new(2.35, 1.02, 0.2))),
		color = PALETTE.brass,
		material = Enum.Material.Metal,
		parent = parent,
		shape = Enum.PartType.Cylinder,
	})
	-- Seat faces the bed (local -X).
	makeSeat({
		name = "ArtistStool",
		size = Vector3.new(1.5, 0.22, 1.5),
		cframe = at(Vector3.new(2.35, 2.15, 0.2)) * CFrame.Angles(0, math.rad(90), 0),
		color = PALETTE.leather,
		material = Enum.Material.Leather,
		parent = parent,
	})

	local pole = makePart({
		name = "LampPole",
		size = Vector3.new(0.16, 5.4, 0.16),
		cframe = at(Vector3.new(1.55, 2.7, -3.35)),
		color = PALETTE.ink,
		material = Enum.Material.Metal,
		parent = parent,
	})
	makePart({
		name = "LampArm",
		size = Vector3.new(0.14, 0.14, 2.4),
		cframe = at(Vector3.new(0.7, 5.35, -2.3)),
		color = PALETTE.ink,
		material = Enum.Material.Metal,
		parent = parent,
		collide = false,
	})
	local bulb = makePart({
		name = "LampBulb",
		size = Vector3.new(0.46, 0.46, 0.46),
		cframe = CFrame.new(at(Vector3.new(0.15, 5.15, -1.2)).Position),
		color = PALETTE.warm,
		material = Enum.Material.Neon,
		parent = parent,
		collide = false,
		castShadow = false,
		shape = Enum.PartType.Ball,
	})
	addSpot(bulb, PALETTE.warm)
	addLight(pole, PALETTE.warm, 0.6, 10)

	makePart({
		name = "Tray",
		size = Vector3.new(1.15, 0.1, 1.7),
		cframe = at(Vector3.new(2.15, 2.55, 1.85)),
		color = PALETTE.ink,
		material = Enum.Material.Metal,
		parent = parent,
	})

	for bottleIndex = 1, 3 do
		local swatch = InkColors.all[((index * 3 + bottleIndex - 1) % #InkColors.all) + 1]
		local color = if swatch ~= nil then InkColors.toColor3(swatch) else PALETTE.ink
		makePart({
			name = "InkBottle",
			size = Vector3.new(0.55, 0.22, 0.22),
			cframe = upright(at(Vector3.new(2.15, 2.9, 1.35 + bottleIndex * 0.38))),
			color = color,
			material = Enum.Material.Glass,
			parent = parent,
			transparency = 0.15,
			shape = Enum.PartType.Cylinder,
		})
	end

	makePart({
		name = "CurtainRod",
		size = Vector3.new(0.12, 0.12, 5.4),
		cframe = at(Vector3.new(-1.85, 6.3, 0)),
		color = PALETTE.brass,
		material = Enum.Material.Metal,
		parent = parent,
		collide = false,
	})
	makePart({
		name = "Curtain",
		size = Vector3.new(0.12, 3.2, 2.3),
		cframe = at(Vector3.new(-1.85, 4.55, -1.3)),
		color = Color3.fromRGB(86, 18, 46),
		material = Enum.Material.Fabric,
		parent = parent,
		collide = false,
	})
	makePart({
		name = "Curtain",
		size = Vector3.new(0.12, 3.2, 2.3),
		cframe = at(Vector3.new(-1.85, 4.55, 1.3)),
		color = Color3.fromRGB(64, 16, 48),
		material = Enum.Material.Fabric,
		parent = parent,
		collide = false,
	})
end

local function buildStations(lobby: Model)
	local stations = makeFolder(lobby, "Stations")
	-- Local +X points at the aisle, so the stool sits toward the middle.
	buildStation(stations, 1, Vector3.new(-23, FLOOR_TOP, 3), 0)
	buildStation(stations, 2, Vector3.new(-23, FLOOR_TOP, 16), 0)
	buildStation(stations, 3, Vector3.new(23, FLOOR_TOP, 3), math.pi)
	buildStation(stations, 4, Vector3.new(23, FLOOR_TOP, 16), math.pi)
end

local function buildFlash(lobby: Model)
	local flash = makeFolder(lobby, "Flash")
	local wallZ = HALF_D - WALL / 2 - 0.32
	local intoRoom = Vector3.new(0, 0, -1)

	buildWordmark(flash, Vector3.new(0, 14.7, wallZ), intoRoom, 8.5, 1.25, "FLASH", PALETTE.magenta)

	local columns = 6
	local rows = 3
	local cardW = 3.45
	local cardH = 3.55
	local gapX = 0.5
	local gapY = 0.42
	local gridW = columns * cardW + (columns - 1) * gapX
	local gridH = rows * cardH + (rows - 1) * gapY
	local originX = -gridW / 2 + cardW / 2
	local originY = 7.15 - gridH / 2 + cardH / 2
	local index = 1
	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			buildCard(
				flash,
				Vector3.new(originX + column * (cardW + gapX), originY + row * (cardH + gapY), wallZ),
				intoRoom,
				cardW,
				cardH,
				index
			)
			index += 1
		end
	end

	local sideYs = { 5.2, 9.1 }
	local sideZs = { -21, -16.6 }
	for _, z in sideZs do
		for _, y in sideYs do
			buildCard(flash, Vector3.new(-HALF_W + WALL / 2 + 0.28, y, z), Vector3.new(1, 0, 0), 3.1, 3.3, index)
			index += 1
			buildCard(flash, Vector3.new(HALF_W - WALL / 2 - 0.28, y, z), Vector3.new(-1, 0, 0), 3.1, 3.3, index)
			index += 1
		end
	end
end

local function buildEntrance(lobby: Model)
	local entrance = makeFolder(lobby, "Entrance")
	local intoRoom = Vector3.new(0, 0, 1)
	local towardStreet = Vector3.new(0, 0, -1)

	buildWordmark(
		entrance,
		Vector3.new(0, 12.4, -HALF_D - 0.75),
		towardStreet,
		13.5,
		2.3,
		"INK MASTERS",
		PALETTE.magenta
	)
	buildWordmark(entrance, Vector3.new(0, 13.4, -HALF_D + 3.4), intoRoom, 11, 1.8, "INK MASTERS", PALETTE.violet)
	buildWordmark(entrance, Vector3.new(-9.5, 7.4, -HALF_D - 0.7), towardStreet, 3.2, 1.35, "OPEN", PALETTE.magenta)

	-- Foreground board. Spawn faces +Z, so the readable face points back at them.
	local boardCf = faceToward(Vector3.new(-9, 6.4, -1.5), Vector3.new(0, 0, -1))
	local glow = makePart({
		name = "ThemeGlow",
		size = Vector3.new(10.4, 6.1, 0.2),
		cframe = boardCf * CFrame.new(0, 0, 0.16),
		color = PALETTE.magenta,
		material = Enum.Material.Neon,
		parent = entrance,
		collide = false,
		castShadow = false,
	})
	addLight(glow, PALETTE.magenta, 1.1, 12)

	makePart({
		name = "ThemeBoard",
		size = Vector3.new(9.6, 5.4, 0.16),
		cframe = boardCf,
		color = PALETTE.panel,
		material = Enum.Material.SmoothPlastic,
		parent = entrance,
	})
	makePart({
		name = "ThemePost",
		size = Vector3.new(0.28, 6.2, 0.28),
		cframe = CFrame.new(-9, FLOOR_TOP + 3.1, -1.5),
		color = PALETTE.brass,
		material = Enum.Material.Metal,
		parent = entrance,
	})

	local couchCf = faceToward(Vector3.new(-29.2, FLOOR_TOP, -17.5), Vector3.new(1, 0, 0))
	local function couchAt(offset: Vector3): CFrame
		return couchCf * CFrame.new(offset)
	end
	makePart({
		name = "CouchSeat",
		size = Vector3.new(6.2, 0.45, 2.15),
		cframe = couchAt(Vector3.new(0, 1.25, 0.15)),
		color = PALETTE.leather,
		material = Enum.Material.Leather,
		parent = entrance,
	})
	makePart({
		name = "CouchBack",
		size = Vector3.new(6.2, 2.1, 0.35),
		cframe = couchAt(Vector3.new(0, 2.15, 1.05)),
		color = Color3.fromRGB(32, 18, 28),
		material = Enum.Material.Leather,
		parent = entrance,
	})
	makeSeat({
		name = "WaitingSeat",
		size = Vector3.new(2.4, 0.2, 1.7),
		cframe = couchAt(Vector3.new(-1.5, 1.55, -0.15)),
		color = PALETTE.leather,
		material = Enum.Material.Leather,
		parent = entrance,
	})
	makeSeat({
		name = "WaitingSeat",
		size = Vector3.new(2.4, 0.2, 1.7),
		cframe = couchAt(Vector3.new(1.5, 1.55, -0.15)),
		color = PALETTE.leather,
		material = Enum.Material.Leather,
		parent = entrance,
	})

	makePart({
		name = "CoffeeTable",
		size = Vector3.new(3.4, 0.28, 1.5),
		cframe = CFrame.new(-25.4, FLOOR_TOP + 1.05, -17.5),
		color = PALETTE.ink,
		material = Enum.Material.Wood,
		parent = entrance,
	})

	makePart({
		name = "PlantPot",
		size = Vector3.new(0.7, 0.85, 0.85),
		cframe = upright(CFrame.new(-31.2, FLOOR_TOP + 0.35, -23.2)),
		color = PALETTE.brass,
		material = Enum.Material.Metal,
		parent = entrance,
		shape = Enum.PartType.Cylinder,
	})
	makePart({
		name = "Plant",
		size = Vector3.new(1.7, 1.7, 1.7),
		cframe = CFrame.new(-31.2, FLOOR_TOP + 1.7, -23.2),
		color = Color3.fromRGB(38, 92, 64),
		material = Enum.Material.Grass,
		parent = entrance,
		collide = false,
		shape = Enum.PartType.Ball,
	})

	local deskCf = faceToward(Vector3.new(22, FLOOR_TOP, -19), intoRoom)
	makePart({
		name = "Desk",
		size = Vector3.new(8.4, 3.15, 2.5),
		cframe = deskCf * CFrame.new(0, 1.58, 0),
		color = PALETTE.woodDark,
		material = Enum.Material.Wood,
		parent = entrance,
	})
	makePart({
		name = "DeskTop",
		size = Vector3.new(8.8, 0.18, 2.9),
		cframe = deskCf * CFrame.new(0, 3.2, 0),
		color = PALETTE.ink,
		material = Enum.Material.SmoothPlastic,
		parent = entrance,
	})
	makePart({
		name = "Register",
		size = Vector3.new(1.1, 0.7, 0.85),
		cframe = deskCf * CFrame.new(-2.4, 3.65, 0.2),
		color = PALETTE.panel,
		material = Enum.Material.SmoothPlastic,
		parent = entrance,
	})
	makePart({
		name = "RegisterScreen",
		size = Vector3.new(0.9, 0.55, 0.08),
		cframe = deskCf * CFrame.new(-2.4, 4.15, -0.15),
		color = PALETTE.violet,
		material = Enum.Material.Neon,
		parent = entrance,
		collide = false,
		castShadow = false,
	})

	makePart({
		name = "Mirror",
		size = Vector3.new(0.12, 4.6, 2.6),
		cframe = CFrame.new(HALF_W - WALL / 2 - 0.2, 5.4, 10),
		color = Color3.fromRGB(186, 206, 214),
		material = Enum.Material.Glass,
		parent = entrance,
		transparency = 0.25,
		reflectance = 0.45,
		collide = false,
	})

	local post = makePart({
		name = "Pole",
		size = Vector3.new(8.5, 0.35, 0.35),
		cframe = upright(CFrame.new(14, FLOOR_TOP + 4.25, -HALF_D - 8)),
		color = PALETTE.ink,
		material = Enum.Material.Metal,
		parent = entrance,
		shape = Enum.PartType.Cylinder,
	})
	buildWordmark(entrance, Vector3.new(14, 10.2, -HALF_D - 8), towardStreet, 3.4, 2.4, "INK", PALETTE.gold, true)
	addLight(post, PALETTE.gold, 0.8, 10)
end

local function buildSpawns(lobby: Model): { SpawnLocation }
	local folder = makeFolder(lobby, "Spawns")
	local pads: { SpawnLocation } = {}
	local spots = {
		Vector3.new(-7.5, FLOOR_TOP + 0.22, -12),
		Vector3.new(-2.5, FLOOR_TOP + 0.22, -12),
		Vector3.new(2.5, FLOOR_TOP + 0.22, -12),
		Vector3.new(7.5, FLOOR_TOP + 0.22, -12),
		Vector3.new(-6, FLOOR_TOP + 0.22, -8),
		Vector3.new(-2, FLOOR_TOP + 0.22, -8),
		Vector3.new(2, FLOOR_TOP + 0.22, -8),
		Vector3.new(6, FLOOR_TOP + 0.22, -8),
		Vector3.new(-4, FLOOR_TOP + 0.22, -15.5),
		Vector3.new(4, FLOOR_TOP + 0.22, -15.5),
	}

	for index, spot in spots do
		local pad = Instance.new("SpawnLocation")
		pad.Name = `ShopSpawn{index}`
		pad.Anchored = true
		pad.Size = Vector3.new(3.6, 0.2, 3.6)
		pad.CFrame = CFrame.lookAt(spot, spot + Vector3.new(0, 0, 8))
		pad.Color = PALETTE.woodDark
		pad.Material = Enum.Material.Wood
		pad.TopSurface = Enum.SurfaceType.Smooth
		pad.BottomSurface = Enum.SurfaceType.Smooth
		pad.Neutral = true
		pad.Duration = 0
		pad.Enabled = true
		pad.AllowTeamChangeOnTouch = false
		pad.Parent = folder
		for _, child in pad:GetChildren() do
			if child:IsA("Decal") then
				child:Destroy()
			end
		end
		table.insert(pads, pad)
	end

	return pads
end

local function pivotOnto(character: Model, pad: SpawnLocation)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local hip = 3
	if humanoid ~= nil then
		local rootHeight = 2
		if root ~= nil and root:IsA("BasePart") then
			rootHeight = root.Size.Y
		end
		hip = humanoid.HipHeight + rootHeight / 2
	end
	local _, yaw, _ = pad.CFrame:ToOrientation()
	local feet = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
	character:PivotTo(CFrame.new(feet + Vector3.new(0, hip + 0.15, 0)) * CFrame.Angles(0, yaw, 0))
end

local function placeExistingCharacters(pads: { SpawnLocation })
	if #pads == 0 then
		return
	end

	-- Only move people who already spawned. Asking for a new character here
	-- deadlocks Studio on the Connecting card, because the round never starts.
	local index = 0
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			index += 1
			local pad = pads[((index - 1) % #pads) + 1]
			pivotOnto(character, pad)
		end
	end
end

local Lobby = {}

function Lobby.build()
	if built then
		return
	end
	built = true

	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	buildShell(lobby)
	buildStations(lobby)
	buildFlash(lobby)
	buildEntrance(lobby)
	local pads = buildSpawns(lobby)

	lobby.Parent = Workspace
	clearDefaultPlace()
	placeExistingCharacters(pads)

	-- Lighting must not stop the round. A normal script cannot set Technology,
	-- and that error was leaving the join card on screen.
	local lit = pcall(dressLighting)
	if not lit then
		warn(`{PREFIX} Shop lights skipped`)
	end

	print(`{PREFIX} Shop open | spawn inside the parlour`)
end

return Lobby
