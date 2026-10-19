--!strict

-- Builds the Ink Masters parlour when the server starts.
-- A converted street-front studio: cream plaster, walnut, charcoal, and brass.
-- Players land inside, walk the floor, and sit while the round card runs on top.
-- Lighting.Technology cannot be set from a runtime script. Use Future in Studio.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local InkColors = require(ReplicatedStorage.Shared.InkColors)
local ParlourProps = require(script.Parent.ParlourProps)
local Interior = require(script.Parent.Interior)

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
	ink = Color3.fromRGB(32, 30, 28),
	panel = Color3.fromRGB(46, 42, 40),
	wall = Color3.fromRGB(232, 226, 216),
	trim = Color3.fromRGB(214, 196, 172),
	wood = Color3.fromRGB(118, 78, 50),
	woodDark = Color3.fromRGB(78, 52, 36),
	plankMid = Color3.fromRGB(104, 70, 46),
	ceiling = Color3.fromRGB(226, 220, 210),
	leather = Color3.fromRGB(42, 38, 36),
	brass = Color3.fromRGB(168, 132, 84),
	paper = Color3.fromRGB(236, 228, 214),
	brick = Color3.fromRGB(116, 96, 88),
	stationRed = Color3.fromRGB(62, 54, 50),
	lot = Color3.fromRGB(64, 62, 58),
	road = Color3.fromRGB(40, 40, 42),
	sidewalk = Color3.fromRGB(164, 158, 150),
	gold = Color3.fromRGB(186, 154, 104),
	magenta = Color3.fromRGB(138, 74, 62),
	glass = Color3.fromRGB(188, 206, 212),
	shade = Color3.fromRGB(54, 46, 40),
	oxblood = Color3.fromRGB(102, 46, 52),
	dusk = Color3.fromRGB(46, 44, 48),
	plaster = Color3.fromRGB(234, 228, 218),
	charcoal = Color3.fromRGB(48, 44, 42),
}

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
	local collides = if spec.collide == nil then true else spec.collide
	part.CanCollide = collides
	part.CanTouch = collides
	part.Transparency = spec.transparency or 0
	local metalSheen = if spec.material == Enum.Material.Metal then 0.08 else 0
	part.Reflectance = spec.reflectance or metalSheen
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
	gui.PixelsPerStud = 48
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

local function clearDefaultPlace()
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") or child.Name == "Baseplate" then
			child:Destroy()
		end
	end
end

local function dressLighting()
	-- Neutral fill keeps skin, paper and plaster true. Warmth comes from the
	-- practical lamps, and the street outside sits in a cool dusk for contrast.
	Lighting.ClockTime = 18.9
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 1.3
	Lighting.Ambient = Color3.fromRGB(60, 59, 58)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 76, 92)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.55
	Lighting.ExposureCompensation = 0.2
	Lighting.FogStart = 0
	Lighting.FogEnd = 100000
	Lighting.FogColor = Color3.fromRGB(120, 126, 138)

	for _, child in Lighting:GetChildren() do
		if
			child:IsA("Atmosphere")
			or child:IsA("BloomEffect")
			or child:IsA("SunRaysEffect")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("BlurEffect")
			or child:IsA("DepthOfFieldEffect")
		then
			child:Destroy()
		end
	end

	local function effect(className: string, name: string): Instance
		local created = Instance.new(className)
		created.Name = name
		created.Parent = Lighting
		return created
	end

	local atmosphere = effect("Atmosphere", "InkMastersAtmosphere")
	if atmosphere:IsA("Atmosphere") then
		atmosphere.Density = 0.06
		atmosphere.Offset = 0.1
		atmosphere.Color = Color3.fromRGB(188, 192, 198)
		atmosphere.Decay = Color3.fromRGB(92, 98, 112)
		atmosphere.Glare = 0
		atmosphere.Haze = 0.4
	end

	local grade = effect("ColorCorrectionEffect", "InkMastersGrade")
	if grade:IsA("ColorCorrectionEffect") then
		grade.Brightness = 0
		grade.Contrast = 0.12
		grade.Saturation = -0.04
		grade.TintColor = Color3.fromRGB(255, 251, 247)
	end

	local bloom = effect("BloomEffect", "InkMastersBloom")
	if bloom:IsA("BloomEffect") then
		bloom.Intensity = 0.3
		bloom.Size = 20
		bloom.Threshold = 1.7
	end
end

local function buildWordmark(
	parent: Instance,
	position: Vector3,
	direction: Vector3,
	width: number,
	height: number,
	text: string,
	bothSides: boolean?,
	accent: Color3?
)
	local cf = faceToward(position, direction)
	local letterColor = accent or Color3.fromRGB(236, 214, 168)
	makePart({
		name = "WordmarkFrame",
		size = Vector3.new(width + 0.36, height + 0.36, 0.16),
		cframe = cf * CFrame.new(0, 0, 0.12),
		color = PALETTE.charcoal,
		material = Enum.Material.SmoothPlastic,
		parent = parent,
		collide = false,
	})
	makePart({
		name = "WordmarkLip",
		size = Vector3.new(width + 0.5, 0.08, 0.08),
		cframe = cf * CFrame.new(0, -(height / 2) - 0.16, 0.16),
		color = PALETTE.brass,
		material = Enum.Material.Metal,
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
	surfaceText(plate, text, letterColor, Enum.NormalId.Front)
	if bothSides then
		surfaceText(plate, text, letterColor, Enum.NormalId.Back)
	end
end

local function buildShell(lobby: Model)
	local shell = makeFolder(lobby, "Shell")

	makePart({
		name = "Lot",
		size = Vector3.new(210, 1, 240),
		cframe = CFrame.new(0, -0.5, -28),
		color = PALETTE.lot,
		material = Enum.Material.Asphalt,
		parent = shell,
	})

	local floor = makePart({
		name = "Floor",
		size = Vector3.new(ROOM_WIDTH - WALL - 0.2, FLOOR_TOP, ROOM_DEPTH + WALL),
		cframe = CFrame.new(0, FLOOR_TOP / 2, 0),
		color = Color3.fromRGB(124, 82, 48),
		material = Enum.Material.WoodPlanks,
		parent = shell,
		reflectance = 0.03,
	})
	lobby.PrimaryPart = floor

	local porchDepth = 12
	makePart({
		name = "Porch",
		size = Vector3.new(18, FLOOR_TOP, porchDepth),
		cframe = CFrame.new(0, FLOOR_TOP / 2, -HALF_D - WALL / 2 - porchDepth / 2 + 0.3),
		color = Color3.fromRGB(132, 124, 114),
		material = Enum.Material.Concrete,
		parent = shell,
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
		color = PALETTE.plaster,
		material = Enum.Material.Plaster,
		parent = shell,
	})
	makePart({
		name = "WallRight",
		size = Vector3.new(WALL, CEILING_Y, wallSizeZ),
		cframe = CFrame.new(HALF_W, CEILING_Y / 2, 0),
		color = PALETTE.plaster,
		material = Enum.Material.Plaster,
		parent = shell,
	})
	makePart({
		name = "BrickFeature",
		size = Vector3.new(ROOM_WIDTH - 2.4, 11.4, 0.16),
		cframe = CFrame.new(0, 9.15, HALF_D - WALL / 2 - 0.1),
		color = Color3.fromRGB(132, 72, 56),
		material = Enum.Material.Brick,
		parent = shell,
		collide = false,
	})
	makePart({
		name = "LoungeWall",
		size = Vector3.new(0.16, 11.2, 16.5),
		cframe = CFrame.new(-HALF_W + WALL / 2 + 0.1, 9.05, -16.4),
		color = Color3.fromRGB(176, 118, 42),
		material = Enum.Material.Plaster,
		parent = shell,
		collide = false,
	})

	makePart({
		name = "WallBack",
		size = Vector3.new(ROOM_WIDTH + WALL, CEILING_Y, WALL),
		cframe = CFrame.new(0, CEILING_Y / 2, HALF_D),
		color = PALETTE.plaster,
		material = Enum.Material.Plaster,
		parent = shell,
	})

	local sideWidth = HALF_W + WALL / 2 - DOOR_HALF
	local sideCenter = DOOR_HALF + sideWidth / 2
	local SILL_Y = 3.85
	local WINDOW_TOP = 11.15
	local WINDOW_WIDTH = 14

	local function buildWindowBay(centerX: number)
		local jamb = (sideWidth - WINDOW_WIDTH) / 2
		local leftX = centerX - WINDOW_WIDTH / 2 - jamb / 2
		local rightX = centerX + WINDOW_WIDTH / 2 + jamb / 2
		local windowMidY = (SILL_Y + WINDOW_TOP) / 2
		local windowHeight = WINDOW_TOP - SILL_Y

		makePart({
			name = "WindowJamb",
			size = Vector3.new(jamb, CEILING_Y, WALL),
			cframe = CFrame.new(leftX, CEILING_Y / 2, -HALF_D),
			color = PALETTE.brick,
			material = Enum.Material.Brick,
			parent = shell,
		})
		makePart({
			name = "WindowJamb",
			size = Vector3.new(jamb, CEILING_Y, WALL),
			cframe = CFrame.new(rightX, CEILING_Y / 2, -HALF_D),
			color = PALETTE.brick,
			material = Enum.Material.Brick,
			parent = shell,
		})
		makePart({
			name = "WindowSillWall",
			size = Vector3.new(WINDOW_WIDTH, SILL_Y, WALL),
			cframe = CFrame.new(centerX, SILL_Y / 2, -HALF_D),
			color = PALETTE.brick,
			material = Enum.Material.Brick,
			parent = shell,
		})
		local bayHeader = CEILING_Y - WINDOW_TOP
		makePart({
			name = "WindowHeader",
			size = Vector3.new(WINDOW_WIDTH, bayHeader, WALL),
			cframe = CFrame.new(centerX, WINDOW_TOP + bayHeader / 2, -HALF_D),
			color = PALETTE.brick,
			material = Enum.Material.Brick,
			parent = shell,
		})
		makePart({
			name = "WindowGlass",
			size = Vector3.new(WINDOW_WIDTH - 0.3, windowHeight + 0.06, 0.1),
			cframe = CFrame.new(centerX, windowMidY, -HALF_D),
			color = PALETTE.glass,
			material = Enum.Material.Glass,
			parent = shell,
			collide = false,
			transparency = 0.42,
			reflectance = 0.16,
			castShadow = false,
		})

		local mullionZ = -HALF_D + 0.28
		makePart({
			name = "Mullion",
			size = Vector3.new(0.14, windowHeight - 0.16, 0.14),
			cframe = CFrame.new(centerX, windowMidY, mullionZ),
			color = PALETTE.ink,
			material = Enum.Material.SmoothPlastic,
			parent = shell,
			collide = false,
		})
		makePart({
			name = "Mullion",
			size = Vector3.new(WINDOW_WIDTH - 0.24, 0.14, 0.14),
			cframe = CFrame.new(centerX, windowMidY, mullionZ),
			color = PALETTE.ink,
			material = Enum.Material.SmoothPlastic,
			parent = shell,
			collide = false,
		})
		makePart({
			name = "WindowSill",
			size = Vector3.new(WINDOW_WIDTH + 0.35, 0.16, 0.62),
			cframe = CFrame.new(centerX, SILL_Y + 0.04, -HALF_D + 0.38),
			color = PALETTE.woodDark,
			material = Enum.Material.Wood,
			parent = shell,
			collide = false,
		})
		local linerZ = -HALF_D + 0.48
		local function plasterFace(size: Vector3, cframe: CFrame)
			makePart({
				name = "Plaster",
				size = size,
				cframe = cframe,
				color = PALETTE.plaster,
				material = Enum.Material.Plaster,
				parent = shell,
				collide = false,
			})
		end
		plasterFace(
			Vector3.new(math.max(jamb - 0.08, 0.4), CEILING_Y - 0.5, 0.1),
			CFrame.new(leftX, CEILING_Y / 2, linerZ)
		)
		plasterFace(
			Vector3.new(math.max(jamb - 0.08, 0.4), CEILING_Y - 0.5, 0.1),
			CFrame.new(rightX, CEILING_Y / 2, linerZ)
		)
		plasterFace(
			Vector3.new(WINDOW_WIDTH, math.max(SILL_Y - 0.2, 0.4), 0.1),
			CFrame.new(centerX, SILL_Y / 2, linerZ)
		)
		plasterFace(
			Vector3.new(WINDOW_WIDTH, math.max(bayHeader - 0.15, 0.4), 0.1),
			CFrame.new(centerX, WINDOW_TOP + bayHeader / 2, linerZ)
		)
	end

	buildWindowBay(-sideCenter)
	buildWindowBay(sideCenter)

	local transomBottom = 10.35
	local transomTop = 14.15
	local doorWidth = DOOR_HALF * 2
	makePart({
		name = "DoorRail",
		size = Vector3.new(doorWidth, transomBottom - DOOR_HEIGHT, WALL),
		cframe = CFrame.new(0, DOOR_HEIGHT + (transomBottom - DOOR_HEIGHT) / 2, -HALF_D),
		color = PALETTE.brick,
		material = Enum.Material.Brick,
		parent = shell,
	})
	makePart({
		name = "DoorHead",
		size = Vector3.new(doorWidth, CEILING_Y - transomTop, WALL),
		cframe = CFrame.new(0, transomTop + (CEILING_Y - transomTop) / 2, -HALF_D),
		color = PALETTE.brick,
		material = Enum.Material.Brick,
		parent = shell,
	})
	local doorLinerZ = -HALF_D + 0.48
	makePart({
		name = "Plaster",
		size = Vector3.new(doorWidth - 0.2, transomBottom - DOOR_HEIGHT - 0.08, 0.1),
		cframe = CFrame.new(0, DOOR_HEIGHT + (transomBottom - DOOR_HEIGHT) / 2, doorLinerZ),
		color = PALETTE.plaster,
		material = Enum.Material.Plaster,
		parent = shell,
		collide = false,
	})
	makePart({
		name = "Plaster",
		size = Vector3.new(doorWidth - 0.2, math.max(CEILING_Y - transomTop - 0.1, 0.4), 0.1),
		cframe = CFrame.new(0, transomTop + (CEILING_Y - transomTop) / 2, doorLinerZ),
		color = PALETTE.plaster,
		material = Enum.Material.Plaster,
		parent = shell,
		collide = false,
	})
	makePart({
		name = "Transom",
		size = Vector3.new(doorWidth - 0.35, transomTop - transomBottom + 0.06, 0.1),
		cframe = CFrame.new(0, (transomBottom + transomTop) / 2, -HALF_D),
		color = PALETTE.glass,
		material = Enum.Material.Glass,
		parent = shell,
		collide = false,
		transparency = 0.38,
		reflectance = 0.14,
		castShadow = false,
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

	local faceZ = -HALF_D - 0.78
	local function masonry(name: string, size: Vector3, cframe: CFrame, collide: boolean?)
		makePart({
			name = name,
			size = size,
			cframe = cframe,
			color = PALETTE.brick,
			material = Enum.Material.Brick,
			parent = shell,
			collide = collide,
		})
	end

	masonry(
		"ExteriorSide",
		Vector3.new(0.42, CEILING_Y + 0.35, ROOM_DEPTH + 1.4),
		CFrame.new(-HALF_W - 0.55, CEILING_Y / 2, 0),
		true
	)
	masonry(
		"ExteriorSide",
		Vector3.new(0.42, CEILING_Y + 0.35, ROOM_DEPTH + 1.4),
		CFrame.new(HALF_W + 0.55, CEILING_Y / 2, 0),
		true
	)
	masonry(
		"ExteriorBack",
		Vector3.new(ROOM_WIDTH + 1.6, CEILING_Y + 0.35, 0.42),
		CFrame.new(0, CEILING_Y / 2, HALF_D + 0.55),
		true
	)
	masonry("Pier", Vector3.new(1.35, CEILING_Y + 0.5, 1.05), CFrame.new(-HALF_W + 0.35, CEILING_Y / 2, faceZ), true)
	masonry("Pier", Vector3.new(1.35, CEILING_Y + 0.5, 1.05), CFrame.new(HALF_W - 0.35, CEILING_Y / 2, faceZ), true)
	masonry("Fascia", Vector3.new(ROOM_WIDTH + 0.4, 2.35, 0.72), CFrame.new(0, CEILING_Y - 0.85, faceZ), false)
	masonry("StallRiser", Vector3.new(WINDOW_WIDTH + 0.5, 1.05, 0.48), CFrame.new(-sideCenter, 0.62, faceZ), true)
	masonry("StallRiser", Vector3.new(WINDOW_WIDTH + 0.5, 1.05, 0.48), CFrame.new(sideCenter, 0.62, faceZ), true)
	masonry(
		"MullionPier",
		Vector3.new(0.72, CEILING_Y - 1.2, 0.55),
		CFrame.new(-DOOR_HALF - 0.7, CEILING_Y / 2, faceZ),
		true
	)
	masonry(
		"MullionPier",
		Vector3.new(0.72, CEILING_Y - 1.2, 0.55),
		CFrame.new(DOOR_HALF + 0.7, CEILING_Y / 2, faceZ),
		true
	)

	local function windowBars(centerX: number)
		local windowMidY = (SILL_Y + WINDOW_TOP) / 2
		local windowHeight = WINDOW_TOP - SILL_Y
		local barZ = -HALF_D - 0.42
		local function bar(size: Vector3, cframe: CFrame)
			makePart({
				name = "WindowFrame",
				size = size,
				cframe = cframe,
				color = PALETTE.ink,
				material = Enum.Material.Metal,
				parent = shell,
				collide = false,
			})
		end
		bar(Vector3.new(WINDOW_WIDTH + 0.35, 0.16, 0.16), CFrame.new(centerX, WINDOW_TOP, barZ))
		bar(Vector3.new(WINDOW_WIDTH + 0.35, 0.16, 0.16), CFrame.new(centerX, SILL_Y, barZ))
		bar(Vector3.new(0.16, windowHeight, 0.16), CFrame.new(centerX - WINDOW_WIDTH / 2, windowMidY, barZ))
		bar(Vector3.new(0.16, windowHeight, 0.16), CFrame.new(centerX + WINDOW_WIDTH / 2, windowMidY, barZ))
	end
	windowBars(-sideCenter)
	windowBars(sideCenter)
end

local function buildStation(parent: Instance, index: number, origin: Vector3, yaw: number)
	local cf = CFrame.new(origin) * CFrame.Angles(0, yaw, 0)
	local station = Instance.new("Model")
	station.Name = "Station"
	station:SetAttribute("Index", index)
	station.Parent = parent
	parent = station
	local function at(offset: Vector3): CFrame
		return cf * CFrame.new(offset)
	end

	makePart({
		name = "StationMat",
		size = Vector3.new(6.2, 0.035, 8.4),
		cframe = at(Vector3.new(0.35, 0.03, 0.15)),
		color = PALETTE.charcoal,
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
		name = "Headboard",
		size = Vector3.new(2.45, 1.15, 0.28),
		cframe = at(Vector3.new(0, 3.55, -2.95)),
		color = PALETTE.leather,
		material = Enum.Material.Leather,
		parent = parent,
	})
	makePart({
		name = "Footboard",
		size = Vector3.new(2.45, 0.7, 0.22),
		cframe = at(Vector3.new(0, 3.25, 2.95)),
		color = PALETTE.leather,
		material = Enum.Material.Leather,
		parent = parent,
	})
	makePart({
		name = "SideRail",
		size = Vector3.new(0.1, 0.22, 5.6),
		cframe = at(Vector3.new(-1.28, 2.95, 0)),
		color = PALETTE.brass,
		material = Enum.Material.Metal,
		parent = parent,
		collide = false,
	})
	makePart({
		name = "SideRail",
		size = Vector3.new(0.1, 0.22, 5.6),
		cframe = at(Vector3.new(1.28, 2.95, 0)),
		color = PALETTE.brass,
		material = Enum.Material.Metal,
		parent = parent,
		collide = false,
	})
	makePart({
		name = "ArmPost",
		size = Vector3.new(0.14, 0.72, 0.14),
		cframe = at(Vector3.new(1.42, 3.15, 0.35)),
		color = PALETTE.brass,
		material = Enum.Material.Metal,
		parent = parent,
	})
	makePart({
		name = "Armrest",
		size = Vector3.new(1.15, 0.14, 0.48),
		cframe = at(Vector3.new(1.85, 3.48, 0.35)),
		color = PALETTE.leather,
		material = Enum.Material.Leather,
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
		material = Enum.Material.Neon,
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
	makePart({
		name = "Machine",
		size = Vector3.new(0.26, 0.2, 0.72),
		cframe = at(Vector3.new(2.15, 2.74, 1.15)) * CFrame.Angles(0.35, 0.7, 0),
		color = PALETTE.ink,
		material = Enum.Material.Metal,
		parent = parent,
		collide = false,
	})
	makePart({
		name = "MachineCoil",
		size = Vector3.new(0.16, 0.16, 0.16),
		cframe = at(Vector3.new(2.05, 2.9, 1.02)),
		color = PALETTE.brass,
		material = Enum.Material.Metal,
		parent = parent,
		collide = false,
		shape = Enum.PartType.Ball,
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

	local function tuck(rigName: string, names: { string })
		local rig = Instance.new("Folder")
		rig.Name = rigName
		rig.Parent = station
		local children = station:GetChildren()
		for _, child in children do
			if child ~= rig and table.find(names, child.Name) ~= nil then
				child.Parent = rig
			end
		end
	end

	tuck("RigBed", {
		"BedLeg",
		"BedFrame",
		"Mattress",
		"Sheet",
		"Pillow",
		"Headboard",
		"Footboard",
		"SideRail",
		"ArmPost",
		"Armrest",
	})
	tuck("RigStool", { "StoolPole", "ArtistStool" })
	tuck("RigLamp", { "LampPole", "LampArm", "LampBulb" })
	tuck("RigTray", { "Tray", "Machine", "MachineCoil" })
	station.WorldPivot = cf
end

local function buildStations(lobby: Model)
	local stations = makeFolder(lobby, "Stations")
	-- Local +X points at the aisle, so the stool sits toward the middle.
	buildStation(stations, 1, Vector3.new(-23, FLOOR_TOP, 3), 0)
	buildStation(stations, 2, Vector3.new(-23, FLOOR_TOP, 16), 0)
	buildStation(stations, 3, Vector3.new(23, FLOOR_TOP, 3), math.pi)
	buildStation(stations, 4, Vector3.new(23, FLOOR_TOP, 16), math.pi)
end

local function buildEntrance(lobby: Model)
	local entrance = makeFolder(lobby, "Entrance")
	local intoRoom = Vector3.new(0, 0, 1)
	local towardStreet = Vector3.new(0, 0, -1)

	buildWordmark(entrance, Vector3.new(0, 15.05, -HALF_D - 1.25), towardStreet, 18.5, 1.7, "INK MASTERS")
	buildWordmark(entrance, Vector3.new(0, 12.15, -HALF_D + 0.95), intoRoom, 10.5, 1.15, "INK MASTERS")
	buildWordmark(
		entrance,
		Vector3.new(-8.6, 5.6, -HALF_D - 0.72),
		towardStreet,
		3.1,
		0.85,
		"OPEN",
		false,
		PALETTE.brass
	)

	makePart({
		name = "Awning",
		size = Vector3.new(12.6, 0.12, 4.2),
		cframe = CFrame.new(0, 9.4, -HALF_D - 2.1) * CFrame.Angles(math.rad(-14), 0, 0),
		color = PALETTE.oxblood,
		material = Enum.Material.Fabric,
		parent = entrance,
		collide = false,
	})
	makePart({
		name = "AwningValance",
		size = Vector3.new(12.6, 0.5, 0.08),
		cframe = CFrame.new(0, 8.78, -HALF_D - 4.05),
		color = PALETTE.oxblood,
		material = Enum.Material.Fabric,
		parent = entrance,
		collide = false,
	})
	makePart({
		name = "AwningStripe",
		size = Vector3.new(12.6, 0.08, 0.04),
		cframe = CFrame.new(0, 8.98, -HALF_D - 4.1),
		color = PALETTE.gold,
		material = Enum.Material.SmoothPlastic,
		parent = entrance,
		collide = false,
		castShadow = false,
	})
	for _, armX in { -5.5, 5.5 } do
		makePart({
			name = "AwningArm",
			size = Vector3.new(0.1, 0.1, 3.4),
			cframe = CFrame.new(armX, 9.2, -HALF_D - 1.7) * CFrame.Angles(math.rad(-14), 0, 0),
			color = PALETTE.brass,
			material = Enum.Material.Metal,
			parent = entrance,
			collide = false,
		})
	end

	local function pilaster(x: number)
		makePart({
			name = "Pilaster",
			size = Vector3.new(0.62, CEILING_Y - 0.3, 0.4),
			cframe = CFrame.new(x, (CEILING_Y - 0.3) / 2 + 0.15, -HALF_D - 0.72),
			color = PALETTE.ink,
			material = Enum.Material.SmoothPlastic,
			parent = entrance,
			collide = false,
		})
	end
	pilaster(-DOOR_HALF - 0.15)
	pilaster(DOOR_HALF + 0.15)
	pilaster(-HALF_W + 0.55)
	pilaster(HALF_W - 0.55)

	makePart({
		name = "Cornice",
		size = Vector3.new(ROOM_WIDTH + 2.2, 0.65, 1.45),
		cframe = CFrame.new(0, CEILING_Y + 0.2, -HALF_D - 0.85),
		color = PALETTE.ink,
		material = Enum.Material.SmoothPlastic,
		parent = entrance,
		collide = false,
	})

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

	local stageZ = backFace - 0.55
	makePart({
		name = "StagePost",
		size = Vector3.new(0.42, 8.2, 0.36),
		cframe = CFrame.new(-5.7, 7.5, stageZ),
		color = PALETTE.woodDark,
		material = Enum.Material.Wood,
		parent = entrance,
		collide = false,
	})
	makePart({
		name = "StagePost",
		size = Vector3.new(0.42, 8.2, 0.36),
		cframe = CFrame.new(5.7, 7.5, stageZ),
		color = PALETTE.woodDark,
		material = Enum.Material.Wood,
		parent = entrance,
		collide = false,
	})
	makePart({
		name = "StageLintel",
		size = Vector3.new(11.8, 0.42, 0.36),
		cframe = CFrame.new(0, 11.45, stageZ),
		color = PALETTE.woodDark,
		material = Enum.Material.Wood,
		parent = entrance,
		collide = false,
	})
	local boardLight = makePart({
		name = "BoardLight",
		size = Vector3.new(1.4, 0.28, 0.4),
		cframe = CFrame.lookAt(Vector3.new(0, 13.2, backFace - 5.5), Vector3.new(0, 8.2, backFace)),
		color = PALETTE.ink,
		material = Enum.Material.Metal,
		parent = entrance,
		collide = false,
		castShadow = false,
	})
	local boardSpot = Instance.new("SpotLight")
	boardSpot.Face = Enum.NormalId.Front
	boardSpot.Angle = 48
	boardSpot.Brightness = 1.5
	boardSpot.Range = 16
	boardSpot.Color = Color3.fromRGB(255, 216, 180)
	boardSpot.Shadows = false
	boardSpot.Parent = boardLight
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

	local function doorLeaf(sign: number)
		local hingeX = sign * 4.55
		local leafWidth = 4.15
		local leafX = hingeX + sign * (leafWidth / 2 - 0.15)
		makePart({
			name = "DoorLeaf",
			size = Vector3.new(leafWidth, 7.6, 0.12),
			cframe = CFrame.new(leafX, FLOOR_TOP + 3.85, -HALF_D + 0.72),
			color = PALETTE.woodDark,
			material = Enum.Material.Wood,
			parent = entrance,
		})
		makePart({
			name = "DoorGlass",
			size = Vector3.new(leafWidth - 0.85, 3.1, 0.05),
			cframe = CFrame.new(leafX, FLOOR_TOP + 5.15, -HALF_D + 0.8),
			color = PALETTE.glass,
			material = Enum.Material.Glass,
			parent = entrance,
			transparency = 0.4,
			collide = false,
			castShadow = false,
		})
		makePart({
			name = "DoorPull",
			size = Vector3.new(0.08, 1.15, 0.08),
			cframe = CFrame.new(hingeX + sign * 0.35, FLOOR_TOP + 4.1, -HALF_D + 0.88),
			color = PALETTE.brass,
			material = Enum.Material.Metal,
			parent = entrance,
			collide = false,
		})
	end
	doorLeaf(-1)
	doorLeaf(1)
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
		pad.Size = Vector3.new(3.2, 0.05, 3.2)
		pad.CFrame = CFrame.lookAt(
			Vector3.new(spot.X, FLOOR_TOP + 0.1, spot.Z),
			Vector3.new(spot.X, FLOOR_TOP + 0.1, spot.Z + 8)
		)
		pad.Color = PALETTE.woodDark
		pad.Material = Enum.Material.Wood
		pad.Transparency = 1
		pad.CanCollide = false
		pad.CastShadow = false
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

local function buildStreet(lobby: Model)
	local street = makeFolder(lobby, "Street")

	makePart({
		name = "Sidewalk",
		size = Vector3.new(128, 0.22, 18.9),
		cframe = CFrame.new(0, 0.11, -48.05),
		color = PALETTE.sidewalk,
		material = Enum.Material.Concrete,
		parent = street,
	})
	makePart({
		name = "Road",
		size = Vector3.new(156, 0.16, 20.8),
		cframe = CFrame.new(0, 0.08, -67.6),
		color = PALETTE.road,
		material = Enum.Material.Asphalt,
		parent = street,
	})
	for index = 0, 3 do
		makePart({
			name = "LaneDash",
			size = Vector3.new(0.85, 0.04, 2.6),
			cframe = CFrame.new(0, 0.18, -60.5 - index * 4.4),
			color = Color3.fromRGB(214, 190, 128),
			material = Enum.Material.SmoothPlastic,
			parent = street,
			collide = false,
			castShadow = false,
		})
	end

	local function neighbor(x: number, label: string)
		local width = 18
		local depth = 30
		local height = 13.2
		local z = -23.8
		makePart({
			name = "Neighbor",
			size = Vector3.new(width, height, depth),
			cframe = CFrame.new(x, height / 2, z),
			color = Color3.fromRGB(52, 44, 50),
			material = Enum.Material.Concrete,
			parent = street,
		})
		makePart({
			name = "NeighborCap",
			size = Vector3.new(width + 0.8, 0.5, depth + 0.4),
			cframe = CFrame.new(x, height + 0.18, z),
			color = PALETTE.ink,
			material = Enum.Material.SmoothPlastic,
			parent = street,
			collide = false,
		})
		makePart({
			name = "NeighborWindow",
			size = Vector3.new(5.4, 3.4, 0.14),
			cframe = CFrame.new(x, 6.2, z - depth / 2 - 0.04),
			color = PALETTE.glass,
			material = Enum.Material.Glass,
			parent = street,
			transparency = 0.35,
			reflectance = 0.1,
			collide = false,
			castShadow = false,
		})
		local sign = makePart({
			name = "NeighborSign",
			size = Vector3.new(6.4, 1.25, 0.12),
			cframe = CFrame.new(x, 11.15, z - depth / 2 - 0.16),
			color = PALETTE.ink,
			material = Enum.Material.SmoothPlastic,
			parent = street,
			collide = false,
		})
		surfaceText(sign, label, PALETTE.gold, Enum.NormalId.Front)
	end
	neighbor(-43.3, "SUPPLY")
	neighbor(43.3, "FLASH")

	local skyline = {
		{ x = -56, z = -94, w = 20, h = 30, d = 14, color = Color3.fromRGB(44, 38, 52) },
		{ x = -26, z = -106, w = 16, h = 46, d = 12, color = Color3.fromRGB(30, 28, 38) },
		{ x = 24, z = -100, w = 18, h = 36, d = 14, color = Color3.fromRGB(50, 38, 44) },
		{ x = 58, z = -90, w = 22, h = 26, d = 16, color = Color3.fromRGB(28, 32, 42) },
	}
	for _, block in skyline do
		makePart({
			name = "Skyline",
			size = Vector3.new(block.w, block.h, block.d),
			cframe = CFrame.new(block.x, block.h / 2, block.z),
			color = block.color,
			material = Enum.Material.Concrete,
			parent = street,
			collide = false,
		})
		makePart({
			name = "SkylineCap",
			size = Vector3.new(block.w + 0.6, 0.4, block.d + 0.4),
			cframe = CFrame.new(block.x, block.h + 0.12, block.z),
			color = PALETTE.dusk,
			material = Enum.Material.SmoothPlastic,
			parent = street,
			collide = false,
		})
		local faceZ = block.z + block.d / 2 + 0.08
		for windowIndex = 1, 2 do
			local windowX = block.x + (if windowIndex == 1 then -2.3 else 2.3)
			local windowY = block.h * (0.32 + windowIndex * 0.2)
			makePart({
				name = "SkylineWindow",
				size = Vector3.new(1.6, 2.2, 0.08),
				cframe = CFrame.new(windowX, windowY, faceZ),
				color = Color3.fromRGB(255, 206, 156),
				material = Enum.Material.SmoothPlastic,
				parent = street,
				collide = false,
				castShadow = false,
			})
		end
	end

	local function streetLamp(x: number, z: number)
		makePart({
			name = "StreetPole",
			size = Vector3.new(0.22, 10.6, 0.22),
			cframe = CFrame.new(x, 5.3, z),
			color = PALETTE.ink,
			material = Enum.Material.Metal,
			parent = street,
		})
		makePart({
			name = "StreetArm",
			size = Vector3.new(0.14, 0.14, 1.5),
			cframe = CFrame.new(x, 10.4, z - 0.55),
			color = PALETTE.ink,
			material = Enum.Material.Metal,
			parent = street,
			collide = false,
		})
		local bulb = makePart({
			name = "StreetBulb",
			size = Vector3.new(0.55, 0.28, 0.7),
			cframe = CFrame.new(x, 10.15, z - 1.15),
			color = Color3.fromRGB(255, 214, 170),
			material = Enum.Material.Neon,
			parent = street,
			collide = false,
			castShadow = false,
		})
		addLight(bulb, Color3.fromRGB(255, 196, 140), 1.05, 28)
	end
	streetLamp(-16, -44)
	streetLamp(18, -44)
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
	buildEntrance(lobby)
	buildStreet(lobby)
	Interior.build(lobby)
	local pads = buildSpawns(lobby)

	lobby.Parent = Workspace
	ParlourProps.dress(lobby)
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
