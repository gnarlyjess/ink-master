--!strict

-- Builds the tattoo shop when the server starts.
-- This is a blockout: a readable parlour to spawn in, not finished art.
-- Players land inside, walk the floor, and sit while the round card runs on top.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local InkColors = require(ReplicatedStorage.Shared.InkColors)

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
	wall = Color3.fromRGB(238, 234, 228),
	trim = Color3.fromRGB(248, 246, 242),
	wood = Color3.fromRGB(156, 122, 86),
	woodDark = Color3.fromRGB(128, 98, 70),
	ceiling = Color3.fromRGB(246, 244, 240),
	leather = Color3.fromRGB(24, 24, 26),
	brass = Color3.fromRGB(92, 78, 64),
	paper = Color3.fromRGB(236, 226, 204),
	brick = Color3.fromRGB(150, 74, 58),
	stationRed = Color3.fromRGB(176, 48, 52),
	lot = Color3.fromRGB(78, 76, 74),
	gold = Color3.fromRGB(242, 196, 122),
}

local INK_ROTATION = { "black", "black", "black", "red", "black", "black", "black", "gold" }

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
	spot.Angle = 58
	spot.Brightness = 2.1
	spot.Range = 11
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
	gui.LightInfluence = 1
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

local FLASH_DESIGNS = { "rose", "dagger", "swallow", "snake", "banner", "anchor", "moth", "star", "heart", "bolt" }

local function designAt(index: number, width: number): string
	if width >= 6 then
		return "sheet"
	end
	local choice = FLASH_DESIGNS[((index - 1) % #FLASH_DESIGNS) + 1]
	if choice == nil then
		return "rose"
	end
	return choice
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
	-- Fill is high enough to see the room the moment you join.
	-- The lamps add warm pools on top. They must not be the only light,
	-- or the shop stays black until those parts replicate.
	Lighting.ClockTime = 16.4
	Lighting.Brightness = 1.8
	Lighting.Ambient = Color3.fromRGB(150, 132, 118)
	Lighting.OutdoorAmbient = Color3.fromRGB(156, 140, 126)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.85
	Lighting.EnvironmentSpecularScale = 0.08
	Lighting.ExposureCompensation = 0.12
	Lighting.FogStart = 0
	Lighting.FogEnd = 100000
	Lighting.FogColor = Color3.fromRGB(150, 132, 118)

	for _, child in Lighting:GetChildren() do
		if child:IsA("BloomEffect") then
			child:Destroy()
		end
	end

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

	local atmosphere = effect("Atmosphere", "InkMastersAtmosphere")
	if atmosphere:IsA("Atmosphere") then
		atmosphere.Density = 0
		atmosphere.Offset = 0
		atmosphere.Glare = 0
		atmosphere.Haze = 0
	end

	local grade = effect("ColorCorrectionEffect", "InkMastersGrade")
	if grade:IsA("ColorCorrectionEffect") then
		grade.Brightness = 0.04
		grade.Contrast = 0.06
		grade.Saturation = 0.02
		grade.TintColor = Color3.fromRGB(255, 236, 214)
	end
end

local FRAME_COLORS = {
	PALETTE.wood,
	PALETTE.woodDark,
	Color3.fromRGB(62, 44, 36),
	PALETTE.ink,
}

local PRINTS = { "garden", "dusk", "vase", "moon", "coast", "bloom" }

local function buildPicture(
	parent: Instance,
	position: Vector3,
	direction: Vector3,
	width: number,
	height: number,
	index: number,
	kind: "flash" | "print"
)
	local tilt = if width >= 5 then 0 else ((index % 5) - 2) * 0.7
	local cf = faceToward(position, direction) * CFrame.Angles(0, 0, math.rad(tilt))
	local frameColor = FRAME_COLORS[((index - 1) % #FRAME_COLORS) + 1]
	local frameMaterial = if frameColor == PALETTE.ink then Enum.Material.SmoothPlastic else Enum.Material.Wood

	makePart({
		name = "PictureFrame",
		size = Vector3.new(width + 0.72, height + 0.72, 0.12),
		cframe = cf * CFrame.new(0, 0, 0.16),
		color = frameColor,
		material = frameMaterial,
		parent = parent,
		collide = false,
	})
	makePart({
		name = "PictureMat",
		size = Vector3.new(width + 0.28, height + 0.28, 0.06),
		cframe = cf * CFrame.new(0, 0, 0.08),
		color = Color3.fromRGB(246, 240, 230),
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		collide = false,
	})

	local canvas = makePart({
		name = if kind == "flash" then "FlashCard" else "WallCanvas",
		size = Vector3.new(width, height, 0.05),
		cframe = cf,
		color = PALETTE.paper,
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		collide = false,
		castShadow = false,
	})
	if kind == "flash" then
		canvas:SetAttribute("FlashDesign", designAt(index, width))
		canvas:SetAttribute("FlashInk", inkAt(index))
		canvas:SetAttribute("FlashTone", (index - 1) % 3)
	else
		local printId = PRINTS[((index - 1) % #PRINTS) + 1]
		canvas:SetAttribute("WallPrint", printId)
	end
end

local function buildWordmark(
	parent: Instance,
	position: Vector3,
	direction: Vector3,
	width: number,
	height: number,
	text: string,
	bothSides: boolean?
)
	local cf = faceToward(position, direction)
	makePart({
		name = "WordmarkFrame",
		size = Vector3.new(width + 0.28, height + 0.28, 0.12),
		cframe = cf * CFrame.new(0, 0, 0.08),
		color = PALETTE.ink,
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		collide = false,
	})

	local plate = makePart({
		name = "Wordmark",
		size = Vector3.new(width, height, 0.08),
		cframe = cf,
		color = PALETTE.ink,
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		collide = false,
	})
	surfaceText(plate, text, Color3.fromRGB(245, 242, 236), Enum.NormalId.Front)
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
		reflectance = 0.02,
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
		size = Vector3.new(8.5, 0.06, 6.2),
		cframe = CFrame.new(-26, FLOOR_TOP + 0.08, -17.2),
		color = Color3.fromRGB(168, 78, 52),
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
		color = PALETTE.brick,
		material = Enum.Material.Brick,
		parent = shell,
	})
	makePart({
		name = "RedWallLeft",
		size = Vector3.new(0.22, 11, 26),
		cframe = CFrame.new(-HALF_W + WALL / 2 + 0.16, 6.4, 10),
		color = PALETTE.stationRed,
		material = Enum.Material.SmoothPlastic,
		parent = shell,
		collide = false,
	})
	makePart({
		name = "RedWallRight",
		size = Vector3.new(0.22, 11, 26),
		cframe = CFrame.new(HALF_W - WALL / 2 - 0.16, 6.4, 10),
		color = PALETTE.stationRed,
		material = Enum.Material.SmoothPlastic,
		parent = shell,
		collide = false,
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

	for index, lightZ in { -14, 2, 16 } do
		local lamp = makePart({
			name = `ShopLight{index}`,
			size = Vector3.new(14, 0.18, 2.4),
			cframe = CFrame.new(0, CEILING_Y - 0.28, lightZ),
			color = Color3.fromRGB(214, 196, 168),
			material = Enum.Material.SmoothPlastic,
			parent = shell,
			collide = false,
			castShadow = false,
		})
		addLight(lamp, Color3.fromRGB(255, 214, 170), 0.22, 18)
	end
end

local function buildStation(parent: Instance, index: number, origin: Vector3, yaw: number)
	local cf = CFrame.new(origin) * CFrame.Angles(0, yaw, 0)
	local function at(offset: Vector3): CFrame
		return cf * CFrame.new(offset)
	end

	local tile = 1.55
	for column = 0, 4 do
		for row = 0, 5 do
			local dark = (column + row) % 2 == 0
			makePart({
				name = "Checker",
				size = Vector3.new(tile - 0.06, 0.04, tile - 0.06),
				cframe = at(Vector3.new((column - 2) * tile + 0.3, 0.06, (row - 2.5) * tile)),
				color = if dark then Color3.fromRGB(32, 32, 34) else Color3.fromRGB(236, 234, 230),
				material = Enum.Material.SmoothPlastic,
				parent = parent,
				collide = false,
			})
		end
	end

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
		size = Vector3.new(2.35, 0.28, 5.7),
		cframe = at(Vector3.new(0, 3.02, 0.05)),
		color = PALETTE.leather,
		material = Enum.Material.Leather,
		parent = parent,
	})
	makePart({
		name = "Sheet",
		size = Vector3.new(2.15, 0.06, 4.3),
		cframe = at(Vector3.new(0, 3.18, 0.35)),
		color = Color3.fromRGB(244, 242, 236),
		material = Enum.Material.Fabric,
		parent = parent,
		collide = false,
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

	makePart({
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
		color = Color3.fromRGB(255, 236, 210),
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		collide = false,
		castShadow = false,
		shape = Enum.PartType.Ball,
	})
	addSpot(bulb, Color3.fromRGB(255, 196, 140))

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

local function buildGallery(lobby: Model)
	local gallery = makeFolder(lobby, "Gallery")
	local index = 1
	local function hang(position: Vector3, direction: Vector3, width: number, height: number, kind: "flash" | "print")
		-- Sit the frame just off the plaster so the moulding reads.
		local anchor = position + direction * 0.32
		buildPicture(gallery, anchor, direction, width, height, index, kind)
		index += 1
	end

	local back = Vector3.new(0, 0, -1)
	local backZ = HALF_D - WALL / 2
	-- Brick wall: a small flash group, one big framed sheet, then paintings. Brick stays visible.
	hang(Vector3.new(-24, 6.9, backZ), back, 2.5, 3.2, "flash")
	hang(Vector3.new(-20.2, 7.4, backZ), back, 2.5, 3.2, "flash")
	hang(Vector3.new(-24.2, 11.1, backZ), back, 2.4, 3.0, "flash")
	hang(Vector3.new(-20, 11.4, backZ), back, 2.4, 3.0, "flash")
	hang(Vector3.new(-8.6, 9.2, backZ), back, 3.6, 4.6, "print")
	hang(Vector3.new(8.8, 9.1, backZ), back, 3.4, 4.4, "print")
	hang(Vector3.new(14.2, 7.1, backZ), back, 3.2, 4.2, "print")
	hang(Vector3.new(18.6, 6.7, backZ), back, 2.6, 3.4, "print")
	hang(Vector3.new(14.6, 11.8, backZ), back, 3.4, 2.6, "print")
	hang(Vector3.new(19.2, 11.5, backZ), back, 2.4, 3.0, "print")
	hang(Vector3.new(24.6, 8.8, backZ), back, 2.6, 3.4, "flash")

	local left = Vector3.new(1, 0, 0)
	local leftX = -HALF_W + WALL / 2
	hang(Vector3.new(leftX, 9.5, -18.5), left, 3.4, 4.4, "print")
	hang(Vector3.new(leftX, 9.3, -8.5), left, 2.8, 3.6, "print")
	hang(Vector3.new(leftX, 9.6, 1.5), left, 3.2, 4.2, "flash")
	hang(Vector3.new(leftX, 9.2, 11), left, 2.8, 3.6, "print")
	hang(Vector3.new(leftX, 9.5, 20), left, 3.4, 4.4, "print")

	local right = Vector3.new(-1, 0, 0)
	local rightX = HALF_W - WALL / 2
	hang(Vector3.new(rightX, 9.4, -20), right, 3.2, 4.2, "print")
	hang(Vector3.new(rightX, 9.6, -9), right, 2.6, 3.4, "flash")
	hang(Vector3.new(rightX, 9.2, 2.5), right, 3.4, 4.6, "print")
	hang(Vector3.new(rightX, 9.5, 12.5), right, 3.0, 3.8, "print")
	hang(Vector3.new(rightX, 9.3, 21), right, 2.8, 3.6, "print")

	local intoRoom = Vector3.new(0, 0, 1)
	local frontZ = -HALF_D + WALL / 2
	hang(Vector3.new(-24, 9.5, frontZ), intoRoom, 3.2, 4.2, "print")
	hang(Vector3.new(-16, 9.2, frontZ), intoRoom, 2.6, 3.4, "print")
	hang(Vector3.new(16.5, 9.4, frontZ), intoRoom, 2.8, 3.6, "flash")
	hang(Vector3.new(24.5, 9.6, frontZ), intoRoom, 3.2, 4.2, "print")
end

local LEAF_COLORS = {
	Color3.fromRGB(36, 92, 58),
	Color3.fromRGB(58, 122, 74),
	Color3.fromRGB(24, 70, 46),
	Color3.fromRGB(78, 140, 86),
}

local BLOOM_COLORS = {
	Color3.fromRGB(232, 126, 142),
	Color3.fromRGB(244, 198, 132),
	Color3.fromRGB(236, 228, 214),
}

local POT_COLORS = {
	Color3.fromRGB(176, 96, 70),
	Color3.fromRGB(232, 214, 196),
	Color3.fromRGB(214, 186, 150),
	Color3.fromRGB(108, 122, 96),
	Color3.fromRGB(154, 72, 58),
}

local function buildPlant(
	parent: Instance,
	position: Vector3,
	scale: number,
	potColor: Color3,
	bloom: boolean,
	trail: boolean
)
	local potHeight = 1.15 * scale
	local direction = if trail then -1 else 1
	makePart({
		name = "PlantSaucer",
		size = Vector3.new(0.08 * scale, 1.45 * scale, 1.45 * scale),
		cframe = upright(CFrame.new(position + Vector3.new(0, 0.04 * scale, 0))),
		color = potColor,
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		shape = Enum.PartType.Cylinder,
	})
	makePart({
		name = "PlantPot",
		size = Vector3.new(potHeight, 1.12 * scale, 1.12 * scale),
		cframe = upright(CFrame.new(position + Vector3.new(0, potHeight / 2, 0))),
		color = potColor,
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		shape = Enum.PartType.Cylinder,
	})
	makePart({
		name = "Soil",
		size = Vector3.new(0.1 * scale, 0.92 * scale, 0.92 * scale),
		cframe = upright(CFrame.new(position + Vector3.new(0, potHeight - 0.02 * scale, 0))),
		color = Color3.fromRGB(62, 44, 32),
		material = Enum.Material.Ground,
		parent = parent,
		collide = false,
		shape = Enum.PartType.Cylinder,
	})
	makePart({
		name = "Stem",
		size = Vector3.new(1.15 * scale, 0.14 * scale, 0.14 * scale),
		cframe = upright(CFrame.new(position + Vector3.new(0, potHeight + direction * 0.45 * scale, 0))),
		color = Color3.fromRGB(54, 78, 48),
		material = Enum.Material.Grass,
		parent = parent,
		collide = false,
		shape = Enum.PartType.Cylinder,
	})

	local sprouts = {
		Vector3.new(0, 2.25, 0),
		Vector3.new(0.72, 1.95, 0.12),
		Vector3.new(-0.68, 2.05, -0.18),
		Vector3.new(0.18, 2.55, -0.55),
		Vector3.new(-0.12, 2.45, 0.62),
		Vector3.new(0.88, 1.6, -0.38),
		Vector3.new(-0.82, 1.55, 0.32),
		Vector3.new(0.28, 1.5, 0.72),
		Vector3.new(-0.36, 1.7, -0.7),
		Vector3.new(0, 1.42, 0.05),
	}
	for leafIndex, offset in sprouts do
		local leaf = LEAF_COLORS[((leafIndex - 1) % #LEAF_COLORS) + 1]
		local placed = Vector3.new(offset.X, direction * offset.Y * (if trail then 0.72 else 1), offset.Z)
		makePart({
			name = "Leaf",
			size = Vector3.new(1.05, 0.82, 1.05) * scale,
			cframe = CFrame.new(position + placed * scale),
			color = leaf,
			material = Enum.Material.Grass,
			parent = parent,
			collide = false,
			shape = Enum.PartType.Ball,
		})
	end

	if bloom then
		local flowers = {
			Vector3.new(0.35, 2.35, 0.2),
			Vector3.new(-0.42, 2.15, -0.15),
			Vector3.new(0.05, 2.6, -0.28),
		}
		for bloomIndex, offset in flowers do
			local petal = BLOOM_COLORS[((bloomIndex - 1) % #BLOOM_COLORS) + 1]
			local placed = Vector3.new(offset.X, direction * offset.Y * (if trail then 0.72 else 1), offset.Z)
			makePart({
				name = "Bloom",
				size = Vector3.new(0.42, 0.36, 0.42) * scale,
				cframe = CFrame.new(position + placed * scale),
				color = petal,
				material = Enum.Material.SmoothPlastic,
				parent = parent,
				collide = false,
				shape = Enum.PartType.Ball,
			})
		end
	end
end

local function buildEntrance(lobby: Model)
	local entrance = makeFolder(lobby, "Entrance")
	local intoRoom = Vector3.new(0, 0, 1)
	local towardStreet = Vector3.new(0, 0, -1)

	buildWordmark(entrance, Vector3.new(0, 12.4, -HALF_D - 0.75), towardStreet, 13.5, 2.3, "INK MASTERS")
	buildWordmark(entrance, Vector3.new(0, 13.4, -HALF_D + 3.4), intoRoom, 11, 1.8, "INK MASTERS")
	buildWordmark(entrance, Vector3.new(-9.5, 7.4, -HALF_D - 0.7), towardStreet, 3.2, 1.35, "OPEN")

	-- Centered on the back wall, facing the people who walk in.
	local backFace = HALF_D - WALL / 2
	local boardCf = faceToward(Vector3.new(0, 8, backFace - 0.36), Vector3.new(0, 0, -1))
	makePart({
		name = "ThemeFrame",
		size = Vector3.new(10.2, 6, 0.16),
		cframe = boardCf * CFrame.new(0, 0, 0.08),
		color = PALETTE.ink,
		material = Enum.Material.SmoothPlastic,
		parent = entrance,
		collide = false,
	})

	makePart({
		name = "ThemeBoard",
		size = Vector3.new(9.6, 5.4, 0.12),
		cframe = boardCf,
		color = PALETTE.paper,
		material = Enum.Material.SmoothPlastic,
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
		name = "Cushion",
		size = Vector3.new(1.35, 0.38, 1.05),
		cframe = couchAt(Vector3.new(1.7, 1.72, 0.05)),
		color = Color3.fromRGB(232, 176, 176),
		material = Enum.Material.Fabric,
		parent = entrance,
		collide = false,
	})
	makePart({
		name = "Cushion",
		size = Vector3.new(1.15, 0.32, 0.9),
		cframe = couchAt(Vector3.new(-1.5, 1.68, 0.2)) * CFrame.Angles(0, 0.4, 0.15),
		color = Color3.fromRGB(214, 154, 132),
		material = Enum.Material.Fabric,
		parent = entrance,
		collide = false,
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
		name = "Book",
		size = Vector3.new(0.95, 0.08, 0.7),
		cframe = CFrame.new(-25.8, FLOOR_TOP + 1.24, -17.35) * CFrame.Angles(0, 0.35, 0),
		color = Color3.fromRGB(168, 64, 58),
		material = Enum.Material.SmoothPlastic,
		parent = entrance,
		collide = false,
	})
	makePart({
		name = "Book",
		size = Vector3.new(0.8, 0.07, 0.62),
		cframe = CFrame.new(-24.9, FLOOR_TOP + 1.32, -17.7) * CFrame.Angles(0, -0.2, 0),
		color = Color3.fromRGB(232, 220, 196),
		material = Enum.Material.SmoothPlastic,
		parent = entrance,
		collide = false,
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
		color = Color3.fromRGB(36, 40, 44),
		material = Enum.Material.SmoothPlastic,
		parent = entrance,
		collide = false,
		castShadow = false,
	})

	local mirrorCf = faceToward(Vector3.new(16.2, FLOOR_TOP + 3.15, 9.2), Vector3.new(0, 0, -1))
	makePart({
		name = "MirrorFrame",
		size = Vector3.new(2.55, 5.7, 0.16),
		cframe = mirrorCf * CFrame.new(0, 0, 0.1),
		color = PALETTE.ink,
		material = Enum.Material.SmoothPlastic,
		parent = entrance,
	})
	makePart({
		name = "Mirror",
		size = Vector3.new(2.15, 5.2, 0.08),
		cframe = mirrorCf,
		color = Color3.fromRGB(186, 206, 214),
		material = Enum.Material.Glass,
		parent = entrance,
		transparency = 0.25,
		reflectance = 0.12,
		collide = false,
	})

	makePart({
		name = "Pole",
		size = Vector3.new(8.5, 0.35, 0.35),
		cframe = upright(CFrame.new(14, FLOOR_TOP + 4.25, -HALF_D - 8)),
		color = PALETTE.ink,
		material = Enum.Material.Metal,
		parent = entrance,
		shape = Enum.PartType.Cylinder,
	})
	buildWordmark(entrance, Vector3.new(14, 10.2, -HALF_D - 8), towardStreet, 3.4, 2.4, "INK", true)
end

local BOOK_COLORS = {
	Color3.fromRGB(168, 64, 58),
	Color3.fromRGB(62, 78, 64),
	Color3.fromRGB(232, 220, 196),
	Color3.fromRGB(92, 64, 48),
}

local function buildShelf(
	parent: Instance,
	wallFace: Vector3,
	into: Vector3,
	along: Vector3,
	length: number,
	pot: (Vector3, number, boolean, boolean) -> ()
)
	local depth = 1.15
	local center = wallFace + into * (depth / 2 + 0.06)
	local xAxis = along.Unit
	local yAxis = Vector3.yAxis
	local zAxis = xAxis:Cross(yAxis)
	if zAxis:Dot(into) > 0 then
		xAxis = -xAxis
		zAxis = -zAxis
	end
	local cf = CFrame.fromMatrix(center, xAxis, yAxis, zAxis)

	makePart({
		name = "Shelf",
		size = Vector3.new(length, 0.16, depth),
		cframe = cf,
		color = PALETTE.wood,
		material = Enum.Material.Wood,
		parent = parent,
		collide = false,
	})

	local bracketCount = if length > 8 then 3 else 2
	for bracket = 1, bracketCount do
		local x = -length / 2 + 0.45 + (bracket - 1) * ((length - 0.9) / (bracketCount - 1))
		makePart({
			name = "ShelfBracket",
			size = Vector3.new(0.14, 0.5, depth * 0.78),
			cframe = cf * CFrame.new(x, -0.3, 0.08),
			color = PALETTE.woodDark,
			material = Enum.Material.Wood,
			parent = parent,
			collide = false,
		})
	end

	local spots = math.max(2, math.floor(length / 2.15))
	for spot = 1, spots do
		local x = -length / 2 + 0.7 + (spot - 1) * ((length - 1.4) / (spots - 1))
		local point = (cf * CFrame.new(x, 0.12, -0.12)).Position
		local kind = spot % 3
		if kind == 1 then
			pot(point, 0.42, spot % 2 == 0, false)
		elseif kind == 2 then
			local bookColor = BOOK_COLORS[((spot - 1) % #BOOK_COLORS) + 1]
			makePart({
				name = "ShelfBook",
				size = Vector3.new(0.16, 0.62, 0.46),
				cframe = cf * CFrame.new(x - 0.12, 0.42, -0.08) * CFrame.Angles(0, 0.15, 0.12),
				color = bookColor,
				material = Enum.Material.SmoothPlastic,
				parent = parent,
				collide = false,
			})
			makePart({
				name = "ShelfBook",
				size = Vector3.new(0.14, 0.55, 0.42),
				cframe = cf * CFrame.new(x + 0.1, 0.38, -0.05) * CFrame.Angles(0, -0.2, -0.08),
				color = BOOK_COLORS[(spot % #BOOK_COLORS) + 1],
				material = Enum.Material.SmoothPlastic,
				parent = parent,
				collide = false,
			})
		else
			makePart({
				name = "Candle",
				size = Vector3.new(0.55, 0.22, 0.22),
				cframe = upright(CFrame.new(point + Vector3.new(0, 0.2, 0))),
				color = Color3.fromRGB(236, 226, 206),
				material = Enum.Material.SmoothPlastic,
				parent = parent,
				collide = false,
				shape = Enum.PartType.Cylinder,
			})
		end
	end

	local trailAt = (cf * CFrame.new(-length / 2 + 0.55, 0.14, -depth / 2 + 0.16)).Position
	pot(trailAt, 0.48, true, true)
end

local function buildGreenery(lobby: Model)
	local plants = makeFolder(lobby, "Greenery")
	local planted = 0

	local function pot(position: Vector3, scale: number, bloom: boolean, trail: boolean)
		planted += 1
		local color = POT_COLORS[((planted - 1) % #POT_COLORS) + 1]
		buildPlant(plants, position, scale, color, bloom, trail)
	end

	local function hang(x: number, z: number, scale: number)
		local potBottom = 9.4
		local potHeight = 1.15 * scale
		local top = potBottom + potHeight
		local chain = CEILING_Y - 0.35 - top
		makePart({
			name = "PlantChain",
			size = Vector3.new(chain, 0.08, 0.08),
			cframe = upright(CFrame.new(x, top + chain / 2, z)),
			color = PALETTE.brass,
			material = Enum.Material.Metal,
			parent = plants,
			collide = false,
			shape = Enum.PartType.Cylinder,
		})
		pot(Vector3.new(x, potBottom, z), scale, true, true)
	end

	local function shelf(wallFace: Vector3, into: Vector3, along: Vector3, length: number)
		buildShelf(plants, wallFace, into, along, length, pot)
	end

	local leftX = -HALF_W + WALL / 2
	local rightX = HALF_W - WALL / 2
	local frontZ = -HALF_D + WALL / 2
	local alongZ = Vector3.new(0, 0, 1)
	local alongX = Vector3.new(1, 0, 0)
	-- Waist-high shelves with pots, books, and a trailing plant. Pictures hang above them.
	shelf(Vector3.new(leftX, 4.35, -18.8), Vector3.new(1, 0, 0), alongZ, 9.2)
	shelf(Vector3.new(leftX, 4.35, -0.5), Vector3.new(1, 0, 0), alongZ, 10.4)
	shelf(Vector3.new(leftX, 4.35, 18.6), Vector3.new(1, 0, 0), alongZ, 9)
	shelf(Vector3.new(leftX, 13.15, -19), Vector3.new(1, 0, 0), alongZ, 6.2)
	shelf(Vector3.new(leftX, 13.15, 19.2), Vector3.new(1, 0, 0), alongZ, 5.8)
	shelf(Vector3.new(rightX, 4.35, -17), Vector3.new(-1, 0, 0), alongZ, 9.4)
	shelf(Vector3.new(rightX, 4.35, 1.2), Vector3.new(-1, 0, 0), alongZ, 10)
	shelf(Vector3.new(rightX, 4.35, 19.4), Vector3.new(-1, 0, 0), alongZ, 8.6)
	shelf(Vector3.new(rightX, 13.15, -16.5), Vector3.new(-1, 0, 0), alongZ, 6)
	shelf(Vector3.new(rightX, 13.15, 20), Vector3.new(-1, 0, 0), alongZ, 5.6)
	shelf(Vector3.new(-21, 4.35, frontZ), Vector3.new(0, 0, 1), alongX, 10)
	shelf(Vector3.new(21, 4.35, frontZ), Vector3.new(0, 0, 1), alongX, 10)

	-- Waiting nook, desk side, and the aisle edges you see from spawn.
	pot(Vector3.new(-28.4, FLOOR_TOP, -24.4), 1.55, true, false)
	pot(Vector3.new(-21.2, FLOOR_TOP, -22.6), 1.4, true, false)
	pot(Vector3.new(-32.4, FLOOR_TOP, -12.2), 1.45, false, false)
	pot(Vector3.new(-18.5, FLOOR_TOP, -13.4), 1.15, true, false)
	pot(Vector3.new(-15.5, FLOOR_TOP, 1.2), 1.35, true, false)
	pot(Vector3.new(14.2, FLOOR_TOP, -22.4), 1.55, true, false)
	pot(Vector3.new(26.2, FLOOR_TOP, -24.2), 1.5, false, false)
	pot(Vector3.new(19.5, FLOOR_TOP, -13.6), 1.2, true, false)
	pot(Vector3.new(-13.2, FLOOR_TOP, -3.6), 1.5, true, false)
	pot(Vector3.new(13.2, FLOOR_TOP, -3.6), 1.4, true, false)
	pot(Vector3.new(-13.4, FLOOR_TOP, 10.2), 1.6, false, false)
	pot(Vector3.new(13.4, FLOOR_TOP, 10.2), 1.48, true, false)
	pot(Vector3.new(-12.2, FLOOR_TOP, 22.2), 1.72, true, false)
	pot(Vector3.new(12.2, FLOOR_TOP, 22.4), 1.58, false, false)
	pot(Vector3.new(6.5, FLOOR_TOP, 23.2), 1.25, true, false)

	-- Beside each bed, on the aisle side of the foot.
	local stations: { { origin: Vector3, yaw: number } } = {
		{ origin = Vector3.new(-23, FLOOR_TOP, 3), yaw = 0 },
		{ origin = Vector3.new(-23, FLOOR_TOP, 16), yaw = 0 },
		{ origin = Vector3.new(23, FLOOR_TOP, 3), yaw = math.pi },
		{ origin = Vector3.new(23, FLOOR_TOP, 16), yaw = math.pi },
	}
	for step, station in stations do
		local cf = CFrame.new(station.origin) * CFrame.Angles(0, station.yaw, 0)
		pot((cf * CFrame.new(1.9, 0, 4.2)).Position, 0.95, step % 2 == 0, false)
		pot((cf * CFrame.new(-2.3, 0, -3.5)).Position, 0.8, true, false)
	end

	-- Small pots on the table and the desk.
	pot(Vector3.new(-26.5, FLOOR_TOP + 1.24, -17.15), 0.34, true, false)
	pot(Vector3.new(25.2, FLOOR_TOP + 3.32, -19.15), 0.36, true, false)

	hang(-16, -6, 0.85)
	hang(16, -6, 0.8)
	hang(-16, 12, 0.9)
	hang(16, 18, 0.82)
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

local LAMP = Color3.fromRGB(255, 188, 132)
local BULB = Color3.fromRGB(255, 220, 186)
local SHADE = Color3.fromRGB(64, 42, 36)

local function buildFloorLamp(parent: Instance, position: Vector3, height: number)
	makePart({
		name = "LampBase",
		size = Vector3.new(0.12, 1.15, 1.15),
		cframe = upright(CFrame.new(position + Vector3.new(0, 0.06, 0))),
		color = PALETTE.ink,
		material = Enum.Material.Metal,
		parent = parent,
		shape = Enum.PartType.Cylinder,
	})
	makePart({
		name = "LampPole",
		size = Vector3.new(0.1, height - 0.7, 0.1),
		cframe = CFrame.new(position + Vector3.new(0, height / 2, 0)),
		color = PALETTE.ink,
		material = Enum.Material.Metal,
		parent = parent,
	})
	local shadeY = position.Y + height - 0.28
	makePart({
		name = "LampShade",
		size = Vector3.new(0.62, 1.45, 1.45),
		cframe = upright(CFrame.new(position.X, shadeY, position.Z)),
		color = SHADE,
		material = Enum.Material.Fabric,
		parent = parent,
		collide = false,
		shape = Enum.PartType.Cylinder,
	})
	local bulb = makePart({
		name = "LampBulb",
		size = Vector3.new(0.34, 0.34, 0.34),
		cframe = CFrame.new(position.X, shadeY - 0.05, position.Z),
		color = BULB,
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		collide = false,
		castShadow = false,
		shape = Enum.PartType.Ball,
	})
	addLight(bulb, LAMP, if height < 3 then 0.9 else 1.25, if height < 3 then 9 else 15)
end

local function buildSconce(parent: Instance, position: Vector3, into: Vector3)
	local cf = CFrame.lookAt(position, position + into)
	makePart({
		name = "SconcePlate",
		size = Vector3.new(0.55, 0.7, 0.08),
		cframe = cf,
		color = PALETTE.ink,
		material = Enum.Material.Metal,
		parent = parent,
		collide = false,
	})
	makePart({
		name = "SconceShade",
		size = Vector3.new(0.7, 0.22, 0.42),
		cframe = cf * CFrame.new(0, -0.12, -0.28),
		color = SHADE,
		material = Enum.Material.Fabric,
		parent = parent,
		collide = false,
	})
	local bulb = makePart({
		name = "SconceBulb",
		size = Vector3.new(0.16, 0.16, 0.16),
		cframe = cf * CFrame.new(0, -0.18, -0.36),
		color = BULB,
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		collide = false,
		castShadow = false,
		shape = Enum.PartType.Ball,
	})
	addLight(bulb, LAMP, 0.75, 11)
end

local function buildLamps(lobby: Model)
	local lamps = makeFolder(lobby, "Lamps")
	local function floorLamp(x: number, z: number, height: number)
		buildFloorLamp(lamps, Vector3.new(x, FLOOR_TOP, z), height)
	end

	floorLamp(-24.5, -10.5, 5.3)
	floorLamp(23.5, -9, 5.1)
	floorLamp(-9, 16.5, 5.4)
	floorLamp(9.5, 15.5, 5.2)
	floorLamp(-20, 24.2, 4.8)
	floorLamp(20.5, 24, 4.9)
	-- Coffee table and desk.
	buildFloorLamp(lamps, Vector3.new(-24.2, FLOOR_TOP + 1.22, -17.55), 1.35)
	buildFloorLamp(lamps, Vector3.new(20.6, FLOOR_TOP + 3.32, -18.7), 1.15)

	local left = Vector3.new(1, 0, 0)
	local right = Vector3.new(-1, 0, 0)
	local into = Vector3.new(0, 0, 1)
	buildSconce(lamps, Vector3.new(-HALF_W + WALL / 2 + 0.16, 6.7, -11.5), left)
	buildSconce(lamps, Vector3.new(-HALF_W + WALL / 2 + 0.16, 6.7, 8.2), left)
	buildSconce(lamps, Vector3.new(HALF_W - WALL / 2 - 0.16, 6.7, -9.5), right)
	buildSconce(lamps, Vector3.new(HALF_W - WALL / 2 - 0.16, 6.7, 10.5), right)
	buildSconce(lamps, Vector3.new(-12, 6.9, -HALF_D + WALL / 2 + 0.16), into)
	buildSconce(lamps, Vector3.new(12, 6.9, -HALF_D + WALL / 2 + 0.16), into)
end

local Lobby = {}

function Lobby.build()
	if built then
		return
	end
	built = true

	-- Set the fill before the shop exists, so joining is not a black wait for the lamps.
	pcall(dressLighting)

	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	buildShell(lobby)
	buildStations(lobby)
	buildGallery(lobby)
	buildEntrance(lobby)
	buildGreenery(lobby)
	buildLamps(lobby)
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
