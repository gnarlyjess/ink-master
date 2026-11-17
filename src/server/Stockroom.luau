--!strict

-- Separate tattoo-supply stockroom used for the blueprint scavenger hunt.
-- Industrial warehouse look: pale metal racks, cool fluorescent tubes, packed aisles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BlueprintArt = require(ReplicatedStorage.Shared.BlueprintArt)
local Surfaces = require(script.Parent.Surfaces)

local Stockroom = {}

local PREFIX = "[InkRivalry]"
local ORIGIN = Vector3.new(220, 0, 0)
local FLOOR_Y = 0.4
local CEILING_Y = 16
local HALF_X = 48
local HALF_Z = 42

-- Warehouse palette — warm limewash walls, readable shelves, muted goods.
local BRICK = Color3.fromRGB(132, 72, 56)
local BRICK_DARK = Color3.fromRGB(108, 58, 46)
local WALL_PAINT = Color3.fromRGB(198, 188, 172)
local FLOOR = Color3.fromRGB(118, 114, 108)
local CEILING = Color3.fromRGB(148, 146, 140)
local METAL = Color3.fromRGB(168, 172, 178)
local METAL_DARK = Color3.fromRGB(108, 112, 118)
local BOARD = Color3.fromRGB(198, 182, 156)
local BOARD_EDGE = Color3.fromRGB(156, 140, 116)
local PAPER = Color3.fromRGB(224, 228, 234)
local INK = Color3.fromRGB(42, 52, 72)
local TUBE = Color3.fromRGB(210, 218, 230)
local CARDBOARD = Color3.fromRGB(178, 154, 112)
local PLASTIC = Color3.fromRGB(196, 200, 204)
local RUST = Color3.fromRGB(132, 88, 58)
local WHITE_BOX = Color3.fromRGB(220, 214, 204)
local OLIVE = Color3.fromRGB(96, 110, 88)
local RED_BIN = Color3.fromRGB(168, 58, 52)
local BLUE_BIN = Color3.fromRGB(62, 92, 138)
local SAFETY = Color3.fromRGB(220, 176, 42)
local FORKLIFT = Color3.fromRGB(214, 148, 36)
local TIRE = Color3.fromRGB(42, 42, 44)
local CYLINDER = Color3.fromRGB(72, 118, 92)
local CAUTION = Color3.fromRGB(48, 48, 50)

local built = false
local room: Model? = nil
local pads: { SpawnLocation } = {}
local blueprintParts: { BasePart } = {}
-- Filled during fillRoom: tucked crate / shelf / cart hide positions.
local hideSpots = {} :: { { any } }

local function addHide(world: Vector3, yaw: number, tag: string?)
	table.insert(hideSpots, { world, yaw, tag or "bay" })
end

local function solid(tint: Color3?): Surfaces.Opts
	return { collide = true, tint = tint, shadow = true }
end

local function soft(tint: Color3?): Surfaces.Opts
	return { tint = tint, shadow = false, collide = false }
end

local function clutter(tint: Color3?): Surfaces.Opts
	-- query false so shelf goods don't eat ProximityPrompt line-of-sight rays
	return { tint = tint, shadow = false, collide = true, query = false }
end

local function pivotOnto(character: Model, pad: SpawnLocation)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local hip = 3
	if humanoid ~= nil then
		hip = humanoid.HipHeight + root.Size.Y / 2
	end
	local feet = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
	local stand = feet + Vector3.new(0, hip + 0.15, 0)
	local look = pad.CFrame.LookVector
	local aim = stand + Vector3.new(look.X, 0, look.Z)
	if humanoid ~= nil then
		humanoid.AutoRotate = false
	end
	character:PivotTo(CFrame.lookAt(stand, aim))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	if humanoid ~= nil then
		task.defer(function()
			if humanoid.Parent ~= nil then
				humanoid.AutoRotate = true
			end
		end)
	end
end

local function buildShell(parent: Model)
	local shell = Surfaces.folder(parent, "Shell")
	Surfaces.part(
		shell,
		"Floor",
		Vector3.new(HALF_X * 2, 0.8, HALF_Z * 2),
		CFrame.new(ORIGIN + Vector3.new(0, FLOOR_Y - 0.4, 0)),
		"concrete",
		solid(FLOOR)
	)
	Surfaces.part(
		shell,
		"Ceiling",
		Vector3.new(HALF_X * 2, 0.5, HALF_Z * 2),
		CFrame.new(ORIGIN + Vector3.new(0, CEILING_Y, 0)),
		"concrete",
		solid(CEILING)
	)

	local wallH = CEILING_Y - FLOOR_Y
	local wallY = FLOOR_Y + wallH / 2
	local brickH = wallH * 0.72
	local paintH = wallH - brickH
	local walls = {
		{ "N", Vector3.new(HALF_X * 2, wallH, 0.8), Vector3.new(0, wallY, -HALF_Z), Vector3.new(0, 0, 0.52) },
		{ "S", Vector3.new(HALF_X * 2, wallH, 0.8), Vector3.new(0, wallY, HALF_Z), Vector3.new(0, 0, -0.52) },
		{ "W", Vector3.new(0.8, wallH, HALF_Z * 2), Vector3.new(-HALF_X, wallY, 0), Vector3.new(0.52, 0, 0) },
		{ "E", Vector3.new(0.8, wallH, HALF_Z * 2), Vector3.new(HALF_X, wallY, 0), Vector3.new(-0.52, 0, 0) },
	}
	for _, wall in walls do
		local name = wall[1] :: string
		local size = wall[2] :: Vector3
		local center = wall[3] :: Vector3
		local inset = wall[4] :: Vector3
		Surfaces.part(shell, `Wall{name}`, size, CFrame.new(ORIGIN + center), "concrete", solid(BRICK_DARK))

		local brickSize = if math.abs(inset.X) > 0
			then Vector3.new(0.18, brickH, size.Z - 0.8)
			else Vector3.new(size.X - 0.8, brickH, 0.18)
		local brickCenter = center + inset + Vector3.new(0, -(wallH - brickH) * 0.5, 0)
		Surfaces.part(
			shell,
			`Brick{name}`,
			brickSize,
			CFrame.new(ORIGIN + brickCenter),
			"brick",
			solid(BRICK)
		)

		-- Painted band above the brick (studio parlour vibe).
		local paintSize = if math.abs(inset.X) > 0
			then Vector3.new(0.14, paintH - 0.2, size.Z - 1.0)
			else Vector3.new(size.X - 1.0, paintH - 0.2, 0.14)
		local paintCenter = center + inset + Vector3.new(0, brickH * 0.5 - 0.1, 0)
		Surfaces.part(
			shell,
			`Paint{name}`,
			paintSize,
			CFrame.new(ORIGIN + paintCenter),
			"plaster",
			solid(WALL_PAINT)
		)
	end

	-- Concrete plinth at floor
	for _, side in {
		{ Vector3.new(HALF_X * 2, 1.1, 0.32), Vector3.new(0, FLOOR_Y + 0.55, -HALF_Z + 0.55) },
		{ Vector3.new(HALF_X * 2, 1.1, 0.32), Vector3.new(0, FLOOR_Y + 0.55, HALF_Z - 0.55) },
		{ Vector3.new(0.32, 1.1, HALF_Z * 2), Vector3.new(-HALF_X + 0.55, FLOOR_Y + 0.55, 0) },
		{ Vector3.new(0.32, 1.1, HALF_Z * 2), Vector3.new(HALF_X - 0.55, FLOOR_Y + 0.55, 0) },
	} do
		Surfaces.part(shell, "Plinth", side[1] :: Vector3, CFrame.new(ORIGIN + (side[2] :: Vector3)), "concrete", solid(Color3.fromRGB(128, 124, 118)))
	end
end

-- Industrial bay: steel uprights + light timber decks + cross braces.
-- clearNests: optional { { localX, deckIndex, tag? }, ... } — empty aisle-facing pads for blueprints.
local function shelfUnit(
	parent: Instance,
	name: string,
	at: Vector3,
	facing: number,
	width: number?,
	clearNests: { { any } }?
)
	local group = Surfaces.folder(parent, name)
	local w = width or 9
	local depth = 1.7
	local height = 9.2
	local decks = 5
	local pivot = CFrame.new(at) * CFrame.Angles(0, facing, 0)
	local nests = clearNests or {}

	local function place(partName: string, size: Vector3, localPos: Vector3, key: string, opts: Surfaces.Opts)
		return Surfaces.part(group, partName, size, pivot * CFrame.new(localPos), key, opts)
	end

	-- Four corner posts (powder-coated steel look).
	for _, corner in {
		Vector3.new(-w / 2, height / 2, -depth / 2),
		Vector3.new(w / 2, height / 2, -depth / 2),
		Vector3.new(-w / 2, height / 2, depth / 2),
		Vector3.new(w / 2, height / 2, depth / 2),
	} do
		place("Post", Vector3.new(0.18, height, 0.18), corner, "steel", solid(METAL))
	end

	-- Foot plates
	for _, foot in {
		Vector3.new(-w / 2, 0.08, -depth / 2),
		Vector3.new(w / 2, 0.08, -depth / 2),
		Vector3.new(-w / 2, 0.08, depth / 2),
		Vector3.new(w / 2, 0.08, depth / 2),
	} do
		place("Foot", Vector3.new(0.42, 0.14, 0.42), foot, "steel", solid(METAL_DARK))
	end

	-- Diagonal side braces
	place("BraceL", Vector3.new(0.08, height * 0.72, 0.08), Vector3.new(-w / 2, height * 0.45, 0), "steel", soft(METAL_DARK))
	place("BraceR", Vector3.new(0.08, height * 0.72, 0.08), Vector3.new(w / 2, height * 0.45, 0), "steel", soft(METAL_DARK))

	-- Thin back mesh panel (reads as wire backing)
	place("Back", Vector3.new(w - 0.2, height - 0.4, 0.06), Vector3.new(0, height / 2, -depth / 2 + 0.04), "steel", soft(Color3.fromRGB(160, 164, 170)))

	-- Shelf decks
	for i = 0, decks - 1 do
		local y = 1.15 + i * ((height - 1.6) / (decks - 1))
		place(`BeamF{i}`, Vector3.new(w, 0.12, 0.12), Vector3.new(0, y - 0.12, depth / 2), "steel", solid(METAL_DARK))
		place(`BeamB{i}`, Vector3.new(w, 0.12, 0.12), Vector3.new(0, y - 0.12, -depth / 2), "steel", solid(METAL_DARK))
		place(`Deck{i}`, Vector3.new(w - 0.1, 0.14, depth - 0.08), Vector3.new(0, y, 0), "paint", solid(BOARD))
		place(`Lip{i}`, Vector3.new(w - 0.1, 0.08, 0.06), Vector3.new(0, y + 0.1, depth / 2 - 0.02), "paint", soft(BOARD_EDGE))
	end

	local function isClearSlot(localX: number, deckIndex: number): boolean
		for _, slot in nests do
			local sx = slot[1] :: number
			local sd = slot[2] :: number
			if sd == deckIndex and math.abs(localX - sx) < 1.35 then
				return true
			end
		end
		return false
	end

	-- Packed goods on every deck (skip clear nest slots so sheets stay visible).
	local goods = {
		{ CARDBOARD, 1.4, 1.0, 1.15 },
		{ WHITE_BOX, 1.2, 0.75, 1.0 },
		{ BLUE_BIN, 1.05, 0.65, 0.95 },
		{ RED_BIN, 0.95, 0.7, 0.9 },
		{ INK, 0.7, 1.05, 0.65 },
		{ OLIVE, 1.3, 0.55, 1.05 },
		{ PLASTIC, 1.55, 0.4, 1.2 },
		{ Color3.fromRGB(92, 72, 56), 1.1, 0.9, 1.0 },
	}
	local n = 0
	for row = 0, decks - 1 do
		local deckY = 1.15 + row * ((height - 1.6) / (decks - 1))
		local y = deckY + 0.55
		local x = -w / 2 + 0.85
		while x < w / 2 - 0.75 do
			n += 1
			local g = goods[((n * 3 + row * 5) % #goods) + 1]
			local bw = g[2] :: number
			local bh = g[3] :: number
			local bd = g[4] :: number
			if not isClearSlot(x + bw * 0.5, row) then
				local key = if (n + row) % 4 == 0 then "steel" else "paint"
				place(
					`Goods{n}`,
					Vector3.new(bw, bh, bd),
					Vector3.new(x + (n % 3) * 0.04, y + bh * 0.15, (n % 2) * 0.08),
					key,
					clutter(g[1] :: Color3)
				)
				if (n + row) % 6 == 0 then
					Surfaces.post(
						group,
						`Bottle{n}`,
						0.55,
						0.28,
						(pivot * CFrame.new(x + 0.7, y - 0.15, 0.25)).Position,
						"paint",
						clutter(Color3.fromRGB(48, 64, 96))
					)
				end
			end
			x += bw + 0.22
		end
	end

	-- Clear aisle-facing nest pads on this unit (tagged "mid" for center racks).
	for _, slot in nests do
		local sx = slot[1] :: number
		local sd = math.clamp(math.floor(slot[2] :: number), 0, decks - 1)
		local deckY = 1.15 + sd * ((height - 1.6) / (decks - 1))
		-- Front lip of the deck — readable while walking the aisle.
		local nestAt = (pivot * CFrame.new(sx, deckY, depth * 0.22)).Position
		local padPivot = CFrame.new(nestAt) * CFrame.Angles(0, facing, 0)
		Surfaces.part(
			group,
			"NestPad",
			Vector3.new(1.6, 0.12, 1.15),
			padPivot * CFrame.new(0, 0.14, 0),
			"paint",
			clutter(WHITE_BOX)
		)
		local tag = if slot[3] ~= nil then tostring(slot[3]) else "shelf"
		addHide((padPivot * CFrame.new(0, 0.28, 0)).Position, facing, tag)
	end
end

local function palletStack(parent: Instance, name: string, at: Vector3, yaw: number, tiers: number)
	local group = Surfaces.folder(parent, name)
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	Surfaces.part(group, "Pallet", Vector3.new(2.6, 0.22, 2.2), pivot * CFrame.new(0, 0.18, 0), "paint", solid(BOARD_EDGE))
	for t = 0, tiers - 1 do
		local y = 0.5 + t * 1.05
		Surfaces.part(
			group,
			`Crate{t}`,
			Vector3.new(2.35, 0.95, 1.95),
			pivot * CFrame.new((t % 2) * 0.1, y, (t % 3) * 0.06),
			"paint",
			clutter(if t % 2 == 0 then CARDBOARD else WHITE_BOX)
		)
	end
end

local function barrel(parent: Instance, name: string, at: Vector3, tint: Color3)
	Surfaces.post(parent, name, 2.3, 1.3, at, "steel", solid(tint))
	Surfaces.part(
		parent,
		`{name}Lid`,
		Vector3.new(1.2, 0.1, 1.2),
		CFrame.new(at + Vector3.new(0, 2.35, 0)),
		"steel",
		soft(tint)
	)
end

local function counter(parent: Instance, name: string, at: Vector3, yaw: number, length: number, nest: boolean?)
	local group = Surfaces.folder(parent, name)
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	Surfaces.part(group, "Body", Vector3.new(length, 2.85, 2.5), pivot * CFrame.new(0, 1.5, 0), "paint", solid(Color3.fromRGB(188, 184, 176)))
	Surfaces.part(group, "Top", Vector3.new(length + 0.15, 0.18, 2.7), pivot * CFrame.new(0, 3.0, 0), "paint", solid(BOARD))
	if nest then
		-- Clear center pad for the sheet; tools shoved to one side only.
		Surfaces.part(
			group,
			"Tools",
			Vector3.new(math.min(2.2, length * 0.28), 0.35, 1.0),
			pivot * CFrame.new(-length * 0.32, 3.28, 0),
			"steel",
			clutter(METAL)
		)
		addHide((pivot * CFrame.new(length * 0.12, 3.2, 0)).Position, yaw)
	else
		Surfaces.part(
			group,
			"Tools",
			Vector3.new(math.min(2.8, length * 0.35), 0.35, 1.2),
			pivot * CFrame.new(-length * 0.22, 3.28, 0),
			"steel",
			clutter(METAL)
		)
		Surfaces.part(
			group,
			"Tray",
			Vector3.new(math.min(2.2, length * 0.28), 0.28, 1.0),
			pivot * CFrame.new(length * 0.2, 3.24, 0.15),
			"paint",
			clutter(INK)
		)
	end
end

local function fluorescentTube(parent: Instance, at: Vector3, yaw: number)
	local group = Surfaces.folder(parent, "Tube")
	local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	-- Cage housing
	Surfaces.part(group, "Housing", Vector3.new(7.2, 0.28, 0.7), cf, "steel", soft(METAL_DARK))
	Surfaces.part(group, "Guard", Vector3.new(6.8, 0.35, 0.9), cf * CFrame.new(0, -0.28, 0), "steel", soft(Color3.fromRGB(90, 94, 100)))
	local tube = Surfaces.part(
		group,
		"Glow",
		Vector3.new(6.4, 0.14, 0.18),
		cf * CFrame.new(0, -0.22, 0),
		"neon",
		{ tint = TUBE, shadow = false, collide = false }
	)
	-- Soft cool wash — sits under lobby practicals, not a stadium blast.
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Color = Color3.fromRGB(220, 224, 232)
	light.Brightness = 1.05
	light.Range = 18
	light.Angle = 120
	light.Shadows = false
	light.Parent = tube
end

-- Hanging warehouse pendant: stem from ceiling → shade → warm pool.
-- `at` is the shade position; stem reaches up toward the ceiling.
local function hangingLight(parent: Instance, at: Vector3)
	local group = Surfaces.folder(parent, "HangingLight")
	local ceilingAttach = math.max(0.4, CEILING_Y - at.Y - 0.2)
	Surfaces.part(
		group,
		"Stem",
		Vector3.new(0.1, ceilingAttach, 0.1),
		CFrame.new(at + Vector3.new(0, ceilingAttach * 0.5 + 0.2, 0)),
		"steel",
		soft(METAL_DARK)
	)
	Surfaces.part(
		group,
		"Canopy",
		Vector3.new(0.55, 0.12, 0.55),
		CFrame.new(at + Vector3.new(0, ceilingAttach + 0.15, 0)),
		"steel",
		soft(METAL)
	)
	local shade = Surfaces.part(
		group,
		"Shade",
		Vector3.new(1.55, 0.5, 1.55),
		CFrame.new(at),
		"paint",
		soft(Color3.fromRGB(68, 66, 62))
	)
	local bulb = Surfaces.part(
		group,
		"Bulb",
		Vector3.new(0.4, 0.4, 0.4),
		CFrame.new(at + Vector3.new(0, -0.32, 0)),
		"neon",
		{ tint = Color3.fromRGB(255, 210, 160), shadow = false, collide = false }
	)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Color = Color3.fromRGB(255, 196, 140)
	spot.Brightness = 2.1
	spot.Range = 16
	spot.Angle = 62
	spot.Shadows = false
	spot.Parent = shade
	local fill = Instance.new("PointLight")
	fill.Color = Color3.fromRGB(255, 196, 140)
	fill.Brightness = 1.05
	fill.Range = 24
	fill.Shadows = false
	fill.Parent = bulb
end

local function aislePendant(parent: Instance, at: Vector3)
	hangingLight(parent, at)
end

-- Decorative open packing crate (no nest — sheets never sit inside walls).
local function packingCrate(parent: Instance, at: Vector3, yaw: number)
	local group = Surfaces.folder(parent, "PackingCrate")
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	Surfaces.part(group, "Floor", Vector3.new(1.9, 0.12, 1.5), pivot * CFrame.new(0, 0.2, 0), "paint", solid(CARDBOARD))
	Surfaces.part(group, "Back", Vector3.new(1.9, 0.85, 0.1), pivot * CFrame.new(0, 0.65, -0.7), "paint", solid(CARDBOARD))
	Surfaces.part(group, "Left", Vector3.new(0.1, 0.7, 1.4), pivot * CFrame.new(-0.9, 0.58, 0), "paint", solid(CARDBOARD))
	Surfaces.part(group, "Right", Vector3.new(0.1, 0.7, 1.4), pivot * CFrame.new(0.9, 0.58, 0), "paint", solid(CARDBOARD))
	Surfaces.part(group, "Front", Vector3.new(1.7, 0.28, 0.1), pivot * CFrame.new(0, 0.36, 0.7), "paint", solid(BOARD_EDGE))
	Surfaces.part(
		group,
		"Lid",
		Vector3.new(1.85, 0.08, 1.2),
		pivot * CFrame.new(0, 1.45, -1.35) * CFrame.Angles(math.rad(-85), 0, 0),
		"paint",
		clutter(CARDBOARD)
	)
end

-- Flat pedestal only — sheet sits fully on the top face, nothing around it.
local function nestPad(parent: Instance, at: Vector3, yaw: number, tint: Color3?, tag: string?)
	local group = Surfaces.folder(parent, "NestPad")
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	Surfaces.part(
		group,
		"Pad",
		Vector3.new(1.75, 0.35, 1.3),
		pivot * CFrame.new(0, 0.18, 0),
		"paint",
		clutter(tint or WHITE_BOX)
	)
	addHide((pivot * CFrame.new(0, 0.42, 0)).Position, yaw, tag)
end

local function sheetGui(part: BasePart): Frame
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sheet"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 110
	gui.Parent = part
	local sketch = Instance.new("Frame")
	sketch.Name = "Sketch"
	sketch.Size = UDim2.fromScale(1, 1)
	sketch.BorderSizePixel = 0
	sketch.Parent = gui
	return sketch
end

-- Cream decoy paperwork — not blue, so cyanotypes stand out when found.
local function decoySheet(parent: Instance, world: Vector3, yaw: number, seed: number)
	local part = Surfaces.part(
		parent,
		"DecoySheet",
		Vector3.new(0.9 + (seed % 3) * 0.08, 0.03, 0.65 + (seed % 2) * 0.08),
		CFrame.new(world) * CFrame.Angles(math.rad(-4 - seed % 5), yaw, math.rad((seed % 7) - 3)),
		"paint",
		{ tint = PAPER, collide = false, query = false, shadow = true }
	)
	local sketch = sheetGui(part)
	sketch.BackgroundColor3 = Color3.fromRGB(232, 228, 218)
	-- Quiet gray notes — not the white-on-blue look.
	for i = 1, 3 do
		local line = Instance.new("Frame")
		line.BackgroundColor3 = Color3.fromRGB(90, 96, 110)
		line.BackgroundTransparency = 0.45
		line.BorderSizePixel = 0
		line.Size = UDim2.new(0.5 + i * 0.1, 0, 0, 2)
		line.Position = UDim2.fromScale(0.12, 0.25 + i * 0.18)
		line.Parent = sketch
	end
end

local function wheel(parent: Instance, name: string, at: CFrame, diameter: number, width: number)
	Surfaces.part(
		parent,
		name,
		Vector3.new(width, diameter, diameter),
		at * CFrame.Angles(0, 0, math.pi / 2),
		"paint",
		{ tint = TIRE, shape = Enum.PartType.Cylinder, collide = true, shadow = true, query = false }
	)
end

local function rollingCart(parent: Instance, name: string, at: Vector3, yaw: number, nest: boolean?)
	local group = Surfaces.folder(parent, name)
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	Surfaces.part(group, "Bed", Vector3.new(3.2, 0.18, 2.0), pivot * CFrame.new(0, 2.2, 0), "steel", solid(METAL))
	Surfaces.part(group, "Shelf", Vector3.new(3.0, 0.12, 1.85), pivot * CFrame.new(0, 1.1, 0), "steel", solid(METAL_DARK))
	for _, corner in {
		Vector3.new(-1.4, 1.1, -0.85),
		Vector3.new(1.4, 1.1, -0.85),
		Vector3.new(-1.4, 1.1, 0.85),
		Vector3.new(1.4, 1.1, 0.85),
	} do
		Surfaces.part(group, "Leg", Vector3.new(0.12, 2.2, 0.12), pivot * CFrame.new(corner), "steel", solid(METAL_DARK))
	end
	for _, corner in {
		Vector3.new(-1.35, 0.28, -0.85),
		Vector3.new(1.35, 0.28, -0.85),
		Vector3.new(-1.35, 0.28, 0.85),
		Vector3.new(1.35, 0.28, 0.85),
	} do
		wheel(group, "Caster", pivot * CFrame.new(corner), 0.42, 0.18)
	end
	if nest then
		-- Flat pedestal box — sheet sits fully on top, nothing overlapping.
		Surfaces.part(group, "NestBox", Vector3.new(2.0, 0.55, 1.35), pivot * CFrame.new(0, 2.55, 0), "paint", clutter(CARDBOARD))
		addHide((pivot * CFrame.new(0, 2.9, 0)).Position, yaw)
	else
		Surfaces.part(group, "Load", Vector3.new(2.4, 0.9, 1.4), pivot * CFrame.new(0, 2.75, 0), "paint", clutter(CARDBOARD))
	end
end

-- Flatbed warehouse trolley with upright handle cage.
local function platformTrolley(parent: Instance, name: string, at: Vector3, yaw: number, nest: boolean?)
	local group = Surfaces.folder(parent, name)
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	Surfaces.part(group, "Deck", Vector3.new(4.2, 0.16, 2.4), pivot * CFrame.new(0, 0.85, 0), "steel", solid(METAL))
	Surfaces.part(group, "Lip", Vector3.new(4.2, 0.35, 0.12), pivot * CFrame.new(0, 1.05, 1.14), "steel", solid(METAL_DARK))
	-- Handle cage at the back.
	Surfaces.part(group, "HandleBar", Vector3.new(0.14, 2.4, 0.14), pivot * CFrame.new(-1.9, 2.0, -1.0), "steel", solid(METAL_DARK))
	Surfaces.part(group, "HandleBar2", Vector3.new(0.14, 2.4, 0.14), pivot * CFrame.new(1.9, 2.0, -1.0), "steel", solid(METAL_DARK))
	Surfaces.part(group, "HandleTop", Vector3.new(3.95, 0.14, 0.14), pivot * CFrame.new(0, 3.15, -1.0), "steel", solid(METAL))
	Surfaces.part(group, "BackMesh", Vector3.new(3.9, 1.6, 0.08), pivot * CFrame.new(0, 1.8, -1.05), "steel", soft(METAL_DARK))
	for _, corner in {
		Vector3.new(-1.7, 0.32, -0.9),
		Vector3.new(1.7, 0.32, -0.9),
		Vector3.new(-1.7, 0.32, 0.9),
		Vector3.new(1.7, 0.32, 0.9),
	} do
		wheel(group, "Wheel", pivot * CFrame.new(corner), 0.55, 0.22)
	end
	if nest then
		-- Side load stays clear of the nest pad; sheet sits fully on NestBox top.
		Surfaces.part(group, "LoadSide", Vector3.new(1.35, 0.95, 1.15), pivot * CFrame.new(-1.25, 1.45, 0.1), "paint", clutter(CARDBOARD))
		Surfaces.part(group, "NestBox", Vector3.new(1.55, 0.65, 1.25), pivot * CFrame.new(0.85, 1.3, 0.1), "paint", clutter(BLUE_BIN))
		addHide((pivot * CFrame.new(0.85, 1.7, 0.1)).Position, yaw)
	else
		Surfaces.part(group, "LoadA", Vector3.new(1.6, 1.0, 1.3), pivot * CFrame.new(-0.9, 1.5, 0.1), "paint", clutter(CARDBOARD))
		Surfaces.part(group, "LoadB", Vector3.new(1.4, 0.8, 1.2), pivot * CFrame.new(1.0, 1.4, 0.15), "paint", clutter(BLUE_BIN))
	end
end

local function palletJack(parent: Instance, name: string, at: Vector3, yaw: number)
	local group = Surfaces.folder(parent, name)
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	Surfaces.part(group, "ForkL", Vector3.new(3.4, 0.16, 0.35), pivot * CFrame.new(0.55, 0.28, -0.55), "steel", solid(METAL))
	Surfaces.part(group, "ForkR", Vector3.new(3.4, 0.16, 0.35), pivot * CFrame.new(0.55, 0.28, 0.55), "steel", solid(METAL))
	Surfaces.part(group, "Bridge", Vector3.new(0.55, 0.35, 1.6), pivot * CFrame.new(-1.35, 0.4, 0), "steel", solid(METAL_DARK))
	Surfaces.part(group, "Pump", Vector3.new(0.7, 1.1, 0.55), pivot * CFrame.new(-1.55, 1.0, 0), "paint", solid(SAFETY))
	Surfaces.part(group, "Handle", Vector3.new(0.14, 2.6, 0.14), pivot * CFrame.new(-1.55, 2.5, 0) * CFrame.Angles(0, 0, math.rad(-18)), "steel", solid(METAL_DARK))
	Surfaces.part(group, "Grip", Vector3.new(0.7, 0.14, 0.14), pivot * CFrame.new(-2.05, 3.55, 0), "paint", soft(TIRE))
	wheel(group, "Steer", pivot * CFrame.new(-1.55, 0.28, 0), 0.5, 0.2)
	wheel(group, "LoadL", pivot * CFrame.new(1.7, 0.2, -0.55), 0.32, 0.14)
	wheel(group, "LoadR", pivot * CFrame.new(1.7, 0.2, 0.55), 0.32, 0.14)
end

local function forklift(parent: Instance, name: string, at: Vector3, yaw: number)
	local group = Surfaces.folder(parent, name)
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	-- Counterweight + body
	Surfaces.part(group, "Body", Vector3.new(3.6, 2.2, 2.6), pivot * CFrame.new(-0.4, 1.5, 0), "paint", solid(FORKLIFT))
	Surfaces.part(group, "Counter", Vector3.new(1.4, 1.8, 2.5), pivot * CFrame.new(-2.2, 1.3, 0), "paint", solid(Color3.fromRGB(176, 118, 28)))
	Surfaces.part(group, "Seat", Vector3.new(1.0, 0.35, 1.0), pivot * CFrame.new(-0.2, 2.75, 0), "paint", soft(TIRE))
	Surfaces.part(group, "Dash", Vector3.new(0.9, 0.55, 1.4), pivot * CFrame.new(0.9, 2.55, 0), "paint", soft(METAL_DARK))
	-- Mast + forks
	Surfaces.part(group, "MastL", Vector3.new(0.28, 5.4, 0.28), pivot * CFrame.new(1.95, 3.1, -0.85), "steel", solid(METAL_DARK))
	Surfaces.part(group, "MastR", Vector3.new(0.28, 5.4, 0.28), pivot * CFrame.new(1.95, 3.1, 0.85), "steel", solid(METAL_DARK))
	Surfaces.part(group, "MastCross", Vector3.new(0.22, 0.22, 1.9), pivot * CFrame.new(1.95, 5.5, 0), "steel", solid(METAL))
	Surfaces.part(group, "Carriage", Vector3.new(0.35, 1.1, 2.0), pivot * CFrame.new(2.15, 1.4, 0), "steel", solid(METAL))
	Surfaces.part(group, "ForkL", Vector3.new(3.2, 0.16, 0.32), pivot * CFrame.new(3.7, 0.95, -0.55), "steel", solid(METAL))
	Surfaces.part(group, "ForkR", Vector3.new(3.2, 0.16, 0.32), pivot * CFrame.new(3.7, 0.95, 0.55), "steel", solid(METAL))
	-- Overhead guard
	Surfaces.part(group, "GuardPostL", Vector3.new(0.16, 2.2, 0.16), pivot * CFrame.new(-1.6, 3.7, -1.05), "steel", soft(METAL_DARK))
	Surfaces.part(group, "GuardPostR", Vector3.new(0.16, 2.2, 0.16), pivot * CFrame.new(-1.6, 3.7, 1.05), "steel", soft(METAL_DARK))
	Surfaces.part(group, "GuardRoof", Vector3.new(3.2, 0.12, 2.4), pivot * CFrame.new(-0.2, 4.8, 0), "steel", soft(METAL))
	-- Wheels
	wheel(group, "FrontL", pivot * CFrame.new(1.1, 0.55, -1.35), 1.0, 0.35)
	wheel(group, "FrontR", pivot * CFrame.new(1.1, 0.55, 1.35), 1.0, 0.35)
	wheel(group, "RearL", pivot * CFrame.new(-1.8, 0.55, -1.2), 0.95, 0.35)
	wheel(group, "RearR", pivot * CFrame.new(-1.8, 0.55, 1.2), 0.95, 0.35)
	-- Loaded pallet on the forks — sheet sits fully on the crate lid.
	Surfaces.part(group, "LoadPallet", Vector3.new(2.4, 0.18, 2.0), pivot * CFrame.new(3.5, 1.15, 0), "paint", clutter(BOARD_EDGE))
	Surfaces.part(group, "LoadCrate", Vector3.new(2.2, 1.3, 1.8), pivot * CFrame.new(3.5, 1.95, 0), "paint", clutter(CARDBOARD))
	addHide((pivot * CFrame.new(3.5, 2.85, 0)).Position, yaw)
end

local function rollingLadder(parent: Instance, name: string, at: Vector3, yaw: number)
	local group = Surfaces.folder(parent, name)
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	Surfaces.part(group, "RailL", Vector3.new(0.12, 5.2, 0.12), pivot * CFrame.new(-0.7, 2.8, 0), "steel", solid(SAFETY))
	Surfaces.part(group, "RailR", Vector3.new(0.12, 5.2, 0.12), pivot * CFrame.new(0.7, 2.8, 0), "steel", solid(SAFETY))
	for i = 0, 7 do
		Surfaces.part(
			group,
			`Step{i}`,
			Vector3.new(1.5, 0.08, 0.35),
			pivot * CFrame.new(0, 0.55 + i * 0.6, 0.1 + i * 0.08),
			"steel",
			solid(METAL)
		)
	end
	Surfaces.part(group, "Platform", Vector3.new(1.7, 0.12, 1.4), pivot * CFrame.new(0, 5.2, 0.7), "steel", solid(METAL_DARK))
	wheel(group, "WheelL", pivot * CFrame.new(-0.7, 0.25, -0.4), 0.4, 0.16)
	wheel(group, "WheelR", pivot * CFrame.new(0.7, 0.25, -0.4), 0.4, 0.16)
end

local function gasCylinder(parent: Instance, name: string, at: Vector3, tint: Color3)
	local group = Surfaces.folder(parent, name)
	Surfaces.post(group, "Tank", 3.4, 0.85, at, "steel", solid(tint))
	Surfaces.part(
		group,
		"Cap",
		Vector3.new(0.55, 0.55, 0.55),
		CFrame.new(at + Vector3.new(0, 3.55, 0)),
		"steel",
		soft(METAL_DARK)
	)
	Surfaces.part(
		group,
		"Valve",
		Vector3.new(0.2, 0.35, 0.2),
		CFrame.new(at + Vector3.new(0, 3.85, 0)),
		"steel",
		soft(METAL)
	)
end

local function hazardCone(parent: Instance, name: string, at: Vector3)
	local group = Surfaces.folder(parent, name)
	Surfaces.part(group, "Base", Vector3.new(0.9, 0.1, 0.9), CFrame.new(at + Vector3.new(0, 0.1, 0)), "paint", solid(CAUTION))
	Surfaces.part(
		group,
		"Cone",
		Vector3.new(0.55, 1.5, 0.55),
		CFrame.new(at + Vector3.new(0, 0.9, 0)),
		"paint",
		solid(SAFETY)
	)
	Surfaces.part(
		group,
		"Stripe",
		Vector3.new(0.58, 0.2, 0.58),
		CFrame.new(at + Vector3.new(0, 1.05, 0)),
		"paint",
		soft(Color3.fromRGB(245, 245, 240))
	)
end

local function wrapRoll(parent: Instance, name: string, at: Vector3, yaw: number)
	local group = Surfaces.folder(parent, name)
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	Surfaces.part(
		group,
		"Roll",
		Vector3.new(1.6, 1.6, 1.6),
		pivot * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2),
		"paint",
		{ tint = PLASTIC, shape = Enum.PartType.Cylinder, collide = true, shadow = true, query = false }
	)
	Surfaces.part(group, "Core", Vector3.new(1.7, 0.35, 0.35), pivot * CFrame.new(0, 0.9, 0), "paint", soft(BOARD))
end

local function wallFan(parent: Instance, name: string, at: Vector3, yaw: number)
	local group = Surfaces.folder(parent, name)
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	Surfaces.part(group, "Housing", Vector3.new(0.55, 2.4, 2.4), pivot, "steel", soft(METAL_DARK))
	Surfaces.part(group, "Blade", Vector3.new(0.2, 1.8, 1.8), pivot * CFrame.new(0.35, 0, 0), "steel", soft(METAL))
	Surfaces.part(group, "Hub", Vector3.new(0.35, 0.45, 0.45), pivot * CFrame.new(0.45, 0, 0), "steel", soft(CAUTION))
end

local function toteStack(parent: Instance, name: string, at: Vector3, yaw: number, count: number)
	local group = Surfaces.folder(parent, name)
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	for i = 0, count - 1 do
		local tint = if i % 2 == 0 then BLUE_BIN else RED_BIN
		Surfaces.part(
			group,
			`Tote{i}`,
			Vector3.new(2.2, 0.85, 1.6),
			pivot * CFrame.new((i % 2) * 0.08, 0.55 + i * 0.9, (i % 3) * 0.05),
			"paint",
			clutter(tint)
		)
	end
end

local function dockPlate(parent: Instance, name: string, at: Vector3, yaw: number)
	local group = Surfaces.folder(parent, name)
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	Surfaces.part(group, "Plate", Vector3.new(6.5, 0.18, 4.2), pivot * CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-6), 0, 0), "steel", solid(METAL_DARK))
	Surfaces.part(group, "Lip", Vector3.new(6.5, 0.35, 0.35), pivot * CFrame.new(0, 0.45, 2.0), "steel", solid(SAFETY))
end

local function lockerBank(parent: Instance, name: string, at: Vector3, yaw: number, count: number)
	local group = Surfaces.folder(parent, name)
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	for i = 0, count - 1 do
		local x = -count * 0.7 + i * 1.4
		Surfaces.part(group, `Door{i}`, Vector3.new(1.25, 5.2, 1.1), pivot * CFrame.new(x, 2.7, 0), "steel", solid(METAL_DARK))
		Surfaces.part(group, `Handle{i}`, Vector3.new(0.08, 0.45, 0.08), pivot * CFrame.new(x + 0.4, 2.7, 0.58), "steel", soft(METAL))
	end
end

local function toolChest(parent: Instance, name: string, at: Vector3, yaw: number)
	local group = Surfaces.folder(parent, name)
	local pivot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	Surfaces.part(group, "Body", Vector3.new(2.6, 2.4, 1.5), pivot * CFrame.new(0, 1.3, 0), "paint", solid(RED_BIN))
	for i = 0, 3 do
		Surfaces.part(
			group,
			`Drawer{i}`,
			Vector3.new(2.45, 0.08, 0.04),
			pivot * CFrame.new(0, 0.55 + i * 0.5, 0.76),
			"steel",
			soft(METAL)
		)
	end
end

local function cableReel(parent: Instance, name: string, at: Vector3)
	local group = Surfaces.folder(parent, name)
	Surfaces.post(group, "Drum", 0.85, 2.1, at, "paint", solid(BOARD_EDGE))
	Surfaces.part(
		group,
		"Axle",
		Vector3.new(2.4, 0.25, 0.25),
		CFrame.new(at + Vector3.new(0, 1.05, 0)),
		"steel",
		soft(METAL_DARK)
	)
end

local function pipeRun(parent: Instance, at: Vector3, length: number, yaw: number)
	local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	Surfaces.part(parent, "Pipe", Vector3.new(length, 0.35, 0.35), cf, "steel", soft(METAL))
	Surfaces.part(parent, "Hang", Vector3.new(0.2, 0.8, 0.2), cf * CFrame.new(-length * 0.35, 0.5, 0), "steel", soft(METAL_DARK))
	Surfaces.part(parent, "Hang2", Vector3.new(0.2, 0.8, 0.2), cf * CFrame.new(length * 0.35, 0.5, 0), "steel", soft(METAL_DARK))
end

local function wallSign(parent: Instance, at: Vector3, yaw: number, text: string, tint: Color3)
	local part = Surfaces.part(
		parent,
		"Sign",
		Vector3.new(3.2, 1.1, 0.12),
		CFrame.new(at) * CFrame.Angles(0, yaw, 0),
		"paint",
		soft(tint)
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 250, 240)
	label.TextScaled = true
	label.Parent = gui
end

local function fillRoom(parent: Instance)
	table.clear(hideSpots)
	local props = Surfaces.folder(parent, "Props")

	-- Perimeter racks (short runs so side corridors stay open at cross-aisles).
	shelfUnit(props, "WallWest1", ORIGIN + Vector3.new(-HALF_X + 2.6, 0, -24), math.rad(90), 12)
	shelfUnit(props, "WallWest2", ORIGIN + Vector3.new(-HALF_X + 2.6, 0, -6), math.rad(90), 12)
	shelfUnit(props, "WallWest3", ORIGIN + Vector3.new(-HALF_X + 2.6, 0, 12), math.rad(90), 12)
	shelfUnit(props, "WallWest4", ORIGIN + Vector3.new(-HALF_X + 2.6, 0, 28), math.rad(90), 10)

	shelfUnit(props, "WallEast1", ORIGIN + Vector3.new(HALF_X - 2.6, 0, -24), math.rad(-90), 12)
	shelfUnit(props, "WallEast2", ORIGIN + Vector3.new(HALF_X - 2.6, 0, -6), math.rad(-90), 12)
	shelfUnit(props, "WallEast3", ORIGIN + Vector3.new(HALF_X - 2.6, 0, 12), math.rad(-90), 12)
	shelfUnit(props, "WallEast4", ORIGIN + Vector3.new(HALF_X - 2.6, 0, 28), math.rad(-90), 10)

	shelfUnit(props, "WallNorth1", ORIGIN + Vector3.new(-28, 0, -HALF_Z + 2.6), 0, 12)
	shelfUnit(props, "WallNorth2", ORIGIN + Vector3.new(-6, 0, -HALF_Z + 2.6), 0, 12)
	shelfUnit(props, "WallNorth3", ORIGIN + Vector3.new(20, 0, -HALF_Z + 2.6), 0, 12)
	shelfUnit(props, "WallSouth1", ORIGIN + Vector3.new(-22, 0, HALF_Z - 2.6), math.pi, 12)
	shelfUnit(props, "WallSouth2", ORIGIN + Vector3.new(4, 0, HALF_Z - 2.6), math.pi, 12)
	shelfUnit(props, "WallSouth3", ORIGIN + Vector3.new(28, 0, HALF_Z - 2.6), math.pi, 10)

	-- Center racks: two lanes + clear center corridor; rows ~12 studs apart for walk aisles.
	-- Each mid rack leaves a clear eye-level nest pad facing the cross-aisle ("mid" tag).
	local westX = -20
	local eastX = 14
	local rowZs = { -24, -12, 0, 12, 24 }
	for i, z in rowZs do
		-- Alternate which way the shelf front faces so every cross-aisle sees pads.
		local faceW = if i % 2 == 0 then math.pi else 0
		local faceE = if i % 2 == 0 then 0 else math.pi
		local deck = (i - 1) % 3 -- decks 0–2 stay reachable
		shelfUnit(props, `RowW{i}`, ORIGIN + Vector3.new(westX, 0, z), faceW, 11, {
			{ -2.5, deck, "mid" },
			{ 2.8, (deck + 1) % 3, "mid" },
		})
		shelfUnit(props, `RowE{i}`, ORIGIN + Vector3.new(eastX, 0, z), faceE, 11, {
			{ -2.8, (deck + 2) % 3, "mid" },
			{ 2.5, deck, "mid" },
		})
	end

	-- Inner wall faces (shell wall thickness 0.8 → face is ~0.4 in from HALF_*).
	local wallW = -HALF_X + 0.95
	local wallE = HALF_X - 0.95
	local wallN = -HALF_Z + 0.95
	local wallS = HALF_Z - 0.95

	-- Pack desks flush to the south / north packing bays (not mid-floor).
	counter(props, "PackBench", ORIGIN + Vector3.new(34, 0, wallS - 2.0), math.pi, 8, true)
	counter(props, "BuildBench", ORIGIN + Vector3.new(-8, 0, wallS - 2.0), math.pi, 10, true)
	counter(props, "ShipDesk", ORIGIN + Vector3.new(16, 0, wallS - 2.0), math.pi, 9, true)
	counter(props, "PartsDesk", ORIGIN + Vector3.new(30, 0, wallN + 2.0), 0, 8, true)
	counter(props, "ClipDesk", ORIGIN + Vector3.new(-30, 0, wallN + 2.0), 0, 8, true)

	-- Pallet stacks in true corners / wall bays only.
	palletStack(props, "StackNW", ORIGIN + Vector3.new(wallW + 2.2, 0, wallN + 2.2), 0.05, 4)
	palletStack(props, "StackNE", ORIGIN + Vector3.new(wallE - 2.2, 0, wallN + 2.2), -0.05, 4)
	palletStack(props, "StackSW", ORIGIN + Vector3.new(wallW + 2.2, 0, wallS - 2.2), 0.08, 4)
	palletStack(props, "StackSE", ORIGIN + Vector3.new(wallE - 2.2, 0, wallS - 2.2), -0.08, 4)
	palletStack(props, "StackWestBay", ORIGIN + Vector3.new(wallW + 2.0, 0, 3), 0, 3)
	palletStack(props, "StackEastBay", ORIGIN + Vector3.new(wallE - 2.0, 0, -3), 0, 3)

	-- Drum rows against the long walls, between shelf runs.
	barrel(props, "Drum1", ORIGIN + Vector3.new(wallW + 0.7, FLOOR_Y, -15.2), RUST)
	barrel(props, "Drum2", ORIGIN + Vector3.new(wallW + 0.7, FLOOR_Y, -13.6), METAL_DARK)
	barrel(props, "Drum3", ORIGIN + Vector3.new(wallE - 0.7, FLOOR_Y, 14.2), RUST)
	barrel(props, "Drum4", ORIGIN + Vector3.new(wallE - 0.7, FLOOR_Y, 15.8), OLIVE)
	barrel(props, "Drum5", ORIGIN + Vector3.new(wallE - 0.7, FLOOR_Y, -16), RUST)
	barrel(props, "Drum6", ORIGIN + Vector3.new(wallW + 0.7, FLOOR_Y, 16), OLIVE)

	-- Loose crates tucked at shelf ends / wall feet (messy, but grounded).
	local loose = Surfaces.folder(props, "Loose")
	local looseSpots = {
		{ Vector3.new(wallW + 1.6, 0.55, -31), Vector3.new(1.6, 0.85, 1.3), CARDBOARD },
		{ Vector3.new(wallE - 1.6, 0.4, 31), Vector3.new(2.0, 0.5, 1.4), BOARD_EDGE },
		{ Vector3.new(wallW + 1.8, 0.65, 20), Vector3.new(1.4, 1.1, 1.2), INK },
		{ Vector3.new(wallE - 1.8, 0.4, -20), Vector3.new(2.2, 0.45, 1.2), PLASTIC },
		{ Vector3.new(-32, 0.55, wallN + 1.5), Vector3.new(1.5, 0.9, 1.4), CARDBOARD },
		{ Vector3.new(30, 0.35, wallS - 1.5), Vector3.new(2.4, 0.35, 1.1), RED_BIN },
		{ Vector3.new(wallE - 1.4, 0.75, -10), Vector3.new(1.1, 1.3, 0.9), BLUE_BIN },
		{ Vector3.new(wallW + 1.4, 0.5, 10), Vector3.new(1.8, 0.65, 1.3), WHITE_BOX },
		{ Vector3.new(10, 0.5, wallS - 1.4), Vector3.new(1.7, 0.75, 1.2), CARDBOARD },
		{ Vector3.new(-10, 0.45, wallN + 1.4), Vector3.new(1.9, 0.6, 1.3), WHITE_BOX },
	}
	for i, spot in looseSpots do
		Surfaces.part(
			loose,
			`Loose{i}`,
			spot[2] :: Vector3,
			CFrame.new(ORIGIN + (spot[1] :: Vector3)) * CFrame.Angles(0, (i % 5) * 0.12, 0),
			"paint",
			clutter(spot[3] :: Color3)
		)
	end

	-- Cream decoys on clear desk / shelf lips only.
	local decoys = Surfaces.folder(props, "Decoys")
	local decoySpots = {
		{ Vector3.new(-8, 3.2, wallS - 1.7), 0.05 },
		{ Vector3.new(-4, 3.2, wallS - 1.7), -0.08 },
		{ Vector3.new(34, 3.2, wallS - 1.7), -0.1 },
		{ Vector3.new(30, 3.2, wallN + 1.7), 0.08 },
		{ Vector3.new(-30, 3.2, wallN + 1.7), -0.06 },
		{ Vector3.new(16, 3.2, wallS - 1.7), 0.1 },
		{ Vector3.new(-20, 2.7, -23.4), 0.05 },
		{ Vector3.new(14, 2.7, 24.2), 0.08 },
		{ Vector3.new(wallW + 2.2, 4.4, wallS - 2.0), 0.1 },
		{ Vector3.new(wallE - 2.2, 3.6, wallN + 2.0), -0.1 },
	}
	for i, spot in decoySpots do
		decoySheet(decoys, ORIGIN + (spot[1] :: Vector3), spot[2] :: number, i)
	end

	local extras = Surfaces.folder(props, "Extras")

	-- Lockers flush on west / east walls in the gaps between shelf runs.
	-- Doors face the room; backs sit on the wall face.
	lockerBank(extras, "LockersW", ORIGIN + Vector3.new(wallW + 0.15, 0, -34), math.rad(90), 5)
	lockerBank(extras, "LockersE", ORIGIN + Vector3.new(wallE - 0.15, 0, 34), math.rad(-90), 5)

	-- Tool chests against wall, under fire kit / beside drums.
	toolChest(extras, "Chest1", ORIGIN + Vector3.new(wallW + 1.1, 0, -20), math.rad(90))
	toolChest(extras, "Chest2", ORIGIN + Vector3.new(wallE - 1.1, 0, 20), math.rad(-90))
	toolChest(extras, "Chest3", ORIGIN + Vector3.new(wallW + 1.1, 0, 22), math.rad(90))

	-- Carts / trolleys parked at aisle ends (handles toward wall or bay).
	rollingCart(extras, "Cart1", ORIGIN + Vector3.new(wallW + 3.5, 0, 26), math.rad(90), true)
	rollingCart(extras, "Cart2", ORIGIN + Vector3.new(wallE - 3.5, 0, -24), math.rad(-90), true)
	rollingCart(extras, "Cart3", ORIGIN + Vector3.new(-12, 0, wallS - 3.2), math.pi, true)
	rollingCart(extras, "Cart4", ORIGIN + Vector3.new(12, 0, wallN + 3.2), 0, true)

	platformTrolley(extras, "Trolley1", ORIGIN + Vector3.new(-26, 0, wallN + 3.4), 0, true)
	platformTrolley(extras, "Trolley2", ORIGIN + Vector3.new(28, 0, wallS - 3.4), math.pi, true)
	platformTrolley(extras, "Trolley3", ORIGIN + Vector3.new(wallE - 3.6, 0, -28), math.rad(-90), true)

	-- Pallet jacks resting by the loading bays.
	palletJack(extras, "Jack1", ORIGIN + Vector3.new(wallW + 4.0, 0, 8), math.rad(90))
	palletJack(extras, "Jack2", ORIGIN + Vector3.new(wallE - 4.0, 0, -8), math.rad(-90))
	palletJack(extras, "Jack3", ORIGIN + Vector3.new(24, 0, wallS - 4.0), math.pi)

	-- Forklifts parked in the marked loading bays, facing the dock.
	forklift(extras, "Forklift1", ORIGIN + Vector3.new(-34, 0, wallS - 6.5), math.pi)
	forklift(extras, "Forklift2", ORIGIN + Vector3.new(34, 0, wallN + 6.5), 0)

	-- Rolling ladders at the end of the center rack lanes.
	rollingLadder(extras, "Ladder1", ORIGIN + Vector3.new(-20, 0, -30), 0)
	rollingLadder(extras, "Ladder2", ORIGIN + Vector3.new(14, 0, 30), math.pi)

	-- Gas bottles chained in a corner bay against the wall.
	gasCylinder(extras, "Gas1", ORIGIN + Vector3.new(wallW + 0.6, FLOOR_Y, -5.2), CYLINDER)
	gasCylinder(extras, "Gas2", ORIGIN + Vector3.new(wallW + 0.6, FLOOR_Y, -3.8), Color3.fromRGB(168, 72, 62))
	gasCylinder(extras, "Gas3", ORIGIN + Vector3.new(wallE - 0.6, FLOOR_Y, 5.2), CYLINDER)
	gasCylinder(extras, "Gas4", ORIGIN + Vector3.new(wallE - 0.6, FLOOR_Y, 6.6), Color3.fromRGB(62, 88, 138))

	-- Cones marking the forklift / dock lanes.
	hazardCone(extras, "Cone1", ORIGIN + Vector3.new(-30, FLOOR_Y, wallS - 10))
	hazardCone(extras, "Cone2", ORIGIN + Vector3.new(-27.5, FLOOR_Y, wallS - 10))
	hazardCone(extras, "Cone3", ORIGIN + Vector3.new(30, FLOOR_Y, wallN + 10))
	hazardCone(extras, "Cone4", ORIGIN + Vector3.new(32.5, FLOOR_Y, wallN + 10))

	-- Stretch wrap parked next to pallet stacks.
	wrapRoll(extras, "Wrap1", ORIGIN + Vector3.new(wallW + 3.5, FLOOR_Y, wallS - 4.5), 0.2)
	wrapRoll(extras, "Wrap2", ORIGIN + Vector3.new(wallE - 3.5, FLOOR_Y, wallN + 4.5), -0.2)

	wallFan(extras, "FanN", ORIGIN + Vector3.new(-16, 10, -HALF_Z + 1.0), 0)
	wallFan(extras, "FanS", ORIGIN + Vector3.new(16, 10, HALF_Z - 1.0), math.pi)
	wallFan(extras, "FanW", ORIGIN + Vector3.new(-HALF_X + 1.0, 10, 8), math.rad(90))

	toteStack(extras, "Totes1", ORIGIN + Vector3.new(wallW + 2.0, 0, -8), math.rad(90), 4)
	toteStack(extras, "Totes2", ORIGIN + Vector3.new(wallE - 2.0, 0, 10), math.rad(-90), 3)
	toteStack(extras, "Totes3", ORIGIN + Vector3.new(6, 0, wallS - 2.0), math.pi, 3)

	-- Dock plates at the loading doors (north-east / south-west bays).
	dockPlate(extras, "DockN", ORIGIN + Vector3.new(34, FLOOR_Y, wallN + 1.2), 0)
	dockPlate(extras, "DockS", ORIGIN + Vector3.new(-34, FLOOR_Y, wallS - 1.2), math.pi)

	cableReel(extras, "Reel1", ORIGIN + Vector3.new(wallW + 1.2, FLOOR_Y, 12))
	cableReel(extras, "Reel2", ORIGIN + Vector3.new(wallE - 1.2, FLOOR_Y, -14))
	cableReel(extras, "Reel3", ORIGIN + Vector3.new(8, FLOOR_Y, wallS - 1.5))
	cableReel(extras, "Reel4", ORIGIN + Vector3.new(-8, FLOOR_Y, wallN + 1.5))

	-- Work table against the south packing bay, beside ShipDesk.
	local tablePivot = CFrame.new(ORIGIN + Vector3.new(8, 0, wallS - 2.2))
	Surfaces.part(extras, "WorkTop", Vector3.new(5.5, 0.2, 2.4), tablePivot * CFrame.new(0, 2.9, 0), "paint", solid(BOARD))
	Surfaces.part(extras, "WorkLegA", Vector3.new(0.25, 2.8, 0.25), tablePivot * CFrame.new(-2.2, 1.4, 0.9), "steel", solid(METAL_DARK))
	Surfaces.part(extras, "WorkLegB", Vector3.new(0.25, 2.8, 0.25), tablePivot * CFrame.new(2.2, 1.4, -0.9), "steel", solid(METAL_DARK))
	Surfaces.part(extras, "WorkBox", Vector3.new(1.4, 0.7, 1.0), tablePivot * CFrame.new(-1.2, 3.35, 0), "paint", clutter(CARDBOARD))
	Surfaces.part(extras, "WorkBin", Vector3.new(1.1, 0.55, 0.9), tablePivot * CFrame.new(1.4, 3.25, 0.2), "paint", clutter(BLUE_BIN))

	pipeRun(extras, ORIGIN + Vector3.new(0, CEILING_Y - 1.6, -16), 56, 0)
	pipeRun(extras, ORIGIN + Vector3.new(0, CEILING_Y - 1.6, 16), 56, 0)
	pipeRun(extras, ORIGIN + Vector3.new(-14, CEILING_Y - 2.0, 0), 50, math.rad(90))
	pipeRun(extras, ORIGIN + Vector3.new(18, CEILING_Y - 2.2, 0), 44, math.rad(90))

	wallSign(extras, ORIGIN + Vector3.new(0, 9.2, -HALF_Z + 0.9), 0, "SUPPLY  ·  AUTHORIZED ONLY", Color3.fromRGB(140, 48, 42))
	wallSign(extras, ORIGIN + Vector3.new(-HALF_X + 0.9, 9.0, 0), math.rad(90), "AISLE B  ·  INK & PARTS", Color3.fromRGB(48, 72, 110))
	wallSign(extras, ORIGIN + Vector3.new(HALF_X - 0.9, 9.0, 0), math.rad(-90), "AISLE A  ·  MACHINES", Color3.fromRGB(48, 72, 110))
	wallSign(extras, ORIGIN + Vector3.new(0, 9.0, HALF_Z - 0.9), math.pi, "LOADING  ·  KEEP CLEAR", Color3.fromRGB(140, 100, 36))

	-- Dumpsters flush against the long walls.
	Surfaces.part(
		extras,
		"Dumpster",
		Vector3.new(2.4, 3.2, 3.8),
		CFrame.new(ORIGIN + Vector3.new(wallE - 1.3, 1.7, 12)),
		"steel",
		solid(OLIVE)
	)
	Surfaces.part(
		extras,
		"DumpLid",
		Vector3.new(2.5, 0.2, 3.9),
		CFrame.new(ORIGIN + Vector3.new(wallE - 1.3, 3.4, 12)),
		"steel",
		soft(METAL_DARK)
	)
	Surfaces.part(
		extras,
		"Dumpster2",
		Vector3.new(2.2, 2.8, 3.4),
		CFrame.new(ORIGIN + Vector3.new(wallW + 1.2, 1.5, -12)),
		"steel",
		solid(METAL_DARK)
	)

	-- Hand trucks leaning with crates by the north packing desks.
	Surfaces.part(
		extras,
		"HandTruck",
		Vector3.new(0.9, 3.0, 0.2),
		CFrame.new(ORIGIN + Vector3.new(-26, 1.6, wallN + 2.2)) * CFrame.Angles(0.15, 0, 0),
		"steel",
		solid(METAL)
	)
	Surfaces.part(
		extras,
		"HandTruck2",
		Vector3.new(0.9, 3.0, 0.2),
		CFrame.new(ORIGIN + Vector3.new(26, 1.6, wallS - 2.2)) * CFrame.Angles(-0.15, math.pi, 0),
		"steel",
		solid(METAL_DARK)
	)
	Surfaces.part(
		extras,
		"SpareCrate",
		Vector3.new(2.0, 1.2, 1.6),
		CFrame.new(ORIGIN + Vector3.new(-24, 0.7, wallN + 2.0)),
		"paint",
		clutter(CARDBOARD)
	)
	Surfaces.part(
		extras,
		"SpareCrate2",
		Vector3.new(1.8, 1.1, 1.5),
		CFrame.new(ORIGIN + Vector3.new(24, 0.65, wallS - 2.0)),
		"paint",
		clutter(WHITE_BOX)
	)

	-- Fire cabinet flush on west wall between shelf runs.
	Surfaces.part(
		extras,
		"FireCab",
		Vector3.new(0.35, 2.2, 1.4),
		CFrame.new(ORIGIN + Vector3.new(-HALF_X + 0.75, 3.2, -20)),
		"paint",
		soft(RED_BIN)
	)
	Surfaces.part(
		extras,
		"Extinguish",
		Vector3.new(0.35, 1.4, 0.35),
		CFrame.new(ORIGIN + Vector3.new(-HALF_X + 1.1, 3.0, -20)),
		"paint",
		soft(RED_BIN)
	)

	-- Hazard stripes across the forklift / dock lanes.
	for i = 0, 5 do
		Surfaces.part(
			extras,
			`StripeN{i}`,
			Vector3.new(1.2, 0.04, 0.35),
			CFrame.new(ORIGIN + Vector3.new(28 + i * 1.4, FLOOR_Y + 0.02, wallN + 9)),
			"paint",
			soft(if i % 2 == 0 then SAFETY else CAUTION)
		)
		Surfaces.part(
			extras,
			`StripeS{i}`,
			Vector3.new(1.2, 0.04, 0.35),
			CFrame.new(ORIGIN + Vector3.new(-36 + i * 1.4, FLOOR_Y + 0.02, wallS - 9)),
			"paint",
			soft(if i % 2 == 0 then SAFETY else CAUTION)
		)
	end

	-- Decorative packing crates (no blueprints inside).
	local crates = Surfaces.folder(props, "PackingCrates")
	packingCrate(crates, ORIGIN + Vector3.new(wallW + 3.2, FLOOR_Y, -18), math.rad(90))
	packingCrate(crates, ORIGIN + Vector3.new(wallE - 3.2, FLOOR_Y, 18), math.rad(-90))
	packingCrate(crates, ORIGIN + Vector3.new(-16, FLOOR_Y, wallN + 3.0), 0)
	packingCrate(crates, ORIGIN + Vector3.new(18, FLOOR_Y, wallS - 3.0), math.pi)

	-- Blueprint nests outside mid racks: desks/pallets/floor pads ("bay").
	-- Mid-shelf nests are registered by the center shelfUnit clear slots above.
	local nests = Surfaces.folder(props, "HideNests")
	-- A few clear pads on perimeter wall shelves too.
	nestPad(nests, ORIGIN + Vector3.new(-HALF_X + 2.6, 3.2, -24), math.rad(90), WHITE_BOX, "bay")
	nestPad(nests, ORIGIN + Vector3.new(HALF_X - 2.6, 3.2, 12), math.rad(-90), CARDBOARD, "bay")
	nestPad(nests, ORIGIN + Vector3.new(-6, 3.2, -HALF_Z + 2.6), 0, WHITE_BOX, "bay")
	nestPad(nests, ORIGIN + Vector3.new(4, 3.2, HALF_Z - 2.6), math.pi, CARDBOARD, "bay")
	-- Flat pads on pallet tops / open floor bay boxes.
	nestPad(nests, ORIGIN + Vector3.new(wallW + 2.2, 4.4, wallN + 2.2), 0.05, CARDBOARD, "bay")
	nestPad(nests, ORIGIN + Vector3.new(wallE - 2.2, 4.4, wallS - 2.2), -0.05, WHITE_BOX, "bay")
	nestPad(nests, ORIGIN + Vector3.new(wallW + 2.0, 3.4, 3), 0, BLUE_BIN, "bay")
	nestPad(nests, ORIGIN + Vector3.new(wallE - 2.0, 3.4, -3), 0, CARDBOARD, "bay")
	-- Aisle-side floor pads (open boxes, no walls).
	nestPad(nests, ORIGIN + Vector3.new(-26, FLOOR_Y, -16), math.rad(90), WHITE_BOX, "bay")
	nestPad(nests, ORIGIN + Vector3.new(26, FLOOR_Y, 16), math.rad(-90), CARDBOARD, "bay")
	nestPad(nests, ORIGIN + Vector3.new(-10, FLOOR_Y, wallS - 4.0), math.pi, BLUE_BIN, "bay")
	nestPad(nests, ORIGIN + Vector3.new(10, FLOOR_Y, wallN + 4.0), 0, WHITE_BOX, "bay")
	-- Cart / trolley / bench / forklift nests come from those builders.

	local lights = Surfaces.folder(parent, "Lights")
	-- Cool cage tubes over the rack lanes.
	local tubeY = CEILING_Y - 1.1
	for _, z in { -24, -6, 12, 28 } do
		for _, x in { -20, 14 } do
			fluorescentTube(lights, ORIGIN + Vector3.new(x, tubeY, z), 0)
		end
	end
	-- Hanging ceiling pendants down the corridor + corners / wall ends.
	local hangY = CEILING_Y - 2.4
	for _, z in { -18, 0, 18 } do
		hangingLight(lights, ORIGIN + Vector3.new(-3, hangY, z))
		hangingLight(lights, ORIGIN + Vector3.new(3, hangY, z))
	end
	hangingLight(lights, ORIGIN + Vector3.new(-28, hangY, 0))
	hangingLight(lights, ORIGIN + Vector3.new(28, hangY, 0))
	hangingLight(lights, ORIGIN + Vector3.new(0, hangY, -32))
	hangingLight(lights, ORIGIN + Vector3.new(0, hangY, 32))
	-- Corner / bay hanging lights (same fixtures — no floating glow cubes).
	for _, xz in {
		Vector3.new(-38, hangY, -34),
		Vector3.new(38, hangY, -34),
		Vector3.new(-38, hangY, 34),
		Vector3.new(38, hangY, 34),
		Vector3.new(-38, hangY, -12),
		Vector3.new(-38, hangY, 12),
		Vector3.new(38, hangY, -12),
		Vector3.new(38, hangY, 12),
		Vector3.new(-16, hangY, -36),
		Vector3.new(16, hangY, -36),
		Vector3.new(-16, hangY, 36),
		Vector3.new(16, hangY, 36),
	} do
		hangingLight(lights, ORIGIN + xz)
	end
end

local function makeBlueprint(parent: Instance, index: number, world: Vector3, yaw: number): BasePart
	local part = Surfaces.part(
		parent,
		`Blueprint{index}`,
		Vector3.new(1.35, 0.035, 1.0),
		CFrame.new(world) * CFrame.Angles(math.rad(-4), yaw, 0),
		"paint",
		{ tint = BlueprintArt.blue(), collide = false, query = true, shadow = false }
	)
	part.CanTouch = false
	part:SetAttribute("BlueprintIndex", index)
	BlueprintArt.paint(sheetGui(part), index)

	-- Soft cyan hint so mid-aisle shelves still read from a few studs away.
	local glow = Instance.new("PointLight")
	glow.Name = "BlueprintGlow"
	glow.Color = Color3.fromRGB(120, 170, 230)
	glow.Brightness = 0.85
	glow.Range = 8
	glow.Shadows = false
	glow.Parent = part

	local sensor = Instance.new("Part")
	sensor.Name = "PromptSensor"
	sensor.Size = Vector3.new(1.0, 1.0, 1.0)
	sensor.Transparency = 1
	sensor.Anchored = true
	sensor.CanCollide = false
	sensor.CanTouch = false
	sensor.CanQuery = true
	sensor.CastShadow = false
	sensor.Massless = true
	sensor.CFrame = part.CFrame * CFrame.new(0, 0.55, 0)
	sensor.Parent = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Collect"
	prompt.ActionText = "Take blueprint"
	prompt.ObjectText = "Machine plan"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = sensor

	return part
end

local function placeBlueprint(part: BasePart, world: Vector3, yaw: number)
	-- Sit clearly on the pad top — flat, never clipped into neighbouring boxes.
	part.CFrame = CFrame.new(world + Vector3.new(0, 0.08, 0)) * CFrame.Angles(math.rad(-3), yaw, 0)
	local sensor = part:FindFirstChild("PromptSensor")
	if sensor ~= nil and sensor:IsA("BasePart") then
		sensor.CFrame = part.CFrame * CFrame.new(0, 0.55, 0)
	end
	local prompt = part:FindFirstChild("Collect", true)
	if prompt ~= nil and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = true
		prompt.MaxActivationDistance = 8
	end
end

local function buildBlueprints(parent: Model): { BasePart }
	local folder = Surfaces.folder(parent, "Blueprints")
	local list: { BasePart } = {}
	-- Spawn at temp origin; reshuffleBlueprints assigns real hide spots each hunt.
	for i = 1, 4 do
		table.insert(list, makeBlueprint(folder, i, ORIGIN + Vector3.new(0, 3, 0), 0))
	end
	return list
end

local function shuffleIndices(count: number, rng: Random): { number }
	local order: { number } = {}
	for i = 1, count do
		order[i] = i
	end
	for i = count, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	return order
end

function Stockroom.reshuffleBlueprints(roundId: number?, designRound: number?)
	if #blueprintParts == 0 or #hideSpots < #blueprintParts then
		warn(`{PREFIX} Not enough hide spots for blueprints ({#hideSpots})`)
		return
	end
	-- Fresh seed every hunt so Studio/live don't repeat the same 4 nests.
	local seed = math.floor(Workspace:GetServerTimeNow() * 1000)
		+ (roundId or 0) * 7919
		+ (designRound or 0) * 104729
		+ os.clock() * 1e6
	local rng = Random.new(math.floor(seed) % 2147483646 + 1)

	local midIdx: { number } = {}
	local bayIdx: { number } = {}
	for i, spot in hideSpots do
		if spot[3] == "mid" then
			table.insert(midIdx, i)
		else
			table.insert(bayIdx, i)
		end
	end
	-- Shuffle each pool, then take up to 2 mid-shelf nests so the centre aisles always matter.
	local function shuffleList(list: { number })
		for i = #list, 2, -1 do
			local j = rng:NextInteger(1, i)
			list[i], list[j] = list[j], list[i]
		end
	end
	shuffleList(midIdx)
	shuffleList(bayIdx)

	local chosen: { number } = {}
	local wantMid = math.min(2, #midIdx, #blueprintParts)
	for i = 1, wantMid do
		table.insert(chosen, midIdx[i])
	end
	local need = #blueprintParts - #chosen
	for i = 1, #bayIdx do
		if need <= 0 then
			break
		end
		table.insert(chosen, bayIdx[i])
		need -= 1
	end
	-- If bays ran short, fill from leftover mid shelves.
	if need > 0 then
		for i = wantMid + 1, #midIdx do
			if need <= 0 then
				break
			end
			table.insert(chosen, midIdx[i])
			need -= 1
		end
	end
	shuffleList(chosen)

	local picked = {}
	for i, part in blueprintParts do
		local spotIndex = chosen[i]
		local spot = hideSpots[spotIndex]
		local base = spot[1] :: Vector3
		local yaw = spot[2] :: number
		part.Transparency = 0
		part.LocalTransparencyModifier = 0
		placeBlueprint(part, base, yaw)
		table.insert(picked, `{spotIndex}:{spot[3] or "?"}`)
	end
	print(
		`{PREFIX} Blueprints reshuffled | nests {table.concat(picked, ",")} | mid {#midIdx} bay {#bayIdx} | seed {math.floor(seed)}`
	)
end

local function buildSpawns(parent: Model): { SpawnLocation }
	local folder = Surfaces.folder(parent, "Spawns")
	local list: { SpawnLocation } = {}
	-- Spawn in the clear center corridor.
	local spots = {
		ORIGIN + Vector3.new(-2, FLOOR_Y + 0.12, 0),
		ORIGIN + Vector3.new(2, FLOOR_Y + 0.12, 2),
		ORIGIN + Vector3.new(0, FLOOR_Y + 0.12, -4),
		ORIGIN + Vector3.new(-3, FLOOR_Y + 0.12, 4),
		ORIGIN + Vector3.new(3, FLOOR_Y + 0.12, -2),
	}
	for i, spot in spots do
		local pad = Instance.new("SpawnLocation")
		pad.Name = `StockSpawn{i}`
		pad.Anchored = true
		pad.Size = Vector3.new(3, 0.05, 3)
		pad.CFrame = CFrame.lookAt(spot, spot + Vector3.new(0, 0, 1))
		pad.Transparency = 1
		pad.CanCollide = false
		pad.CastShadow = false
		pad.Neutral = true
		pad.Duration = 0
		pad.Enabled = false
		pad.Parent = folder
		for _, child in pad:GetChildren() do
			if child:IsA("Decal") then
				child:Destroy()
			end
		end
		table.insert(list, pad)
	end
	return list
end

function Stockroom.build()
	if built then
		return
	end
	built = true

	local model = Instance.new("Model")
	model.Name = "Stockroom"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	buildShell(model)
	fillRoom(model)

	pads = buildSpawns(model)
	blueprintParts = buildBlueprints(model)
	-- Initial scatter; each hunt calls reshuffle again with a new seed.
	Stockroom.reshuffleBlueprints(0, 0)
	model.Parent = Workspace
	room = model
	print(`{PREFIX} Stockroom ready | {#blueprintParts} blueprints | {#hideSpots} hide nests`)
end

function Stockroom.getBlueprints(): { BasePart }
	return blueprintParts
end

function Stockroom.seatPlayer(player: Player, index: number)
	if #pads == 0 then
		return
	end
	local pad = pads[((index - 1) % #pads) + 1]
	local character = player.Character
	if character == nil then
		return
	end
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 8)
		if root == nil or character.Parent == nil then
			return
		end
		pivotOnto(character, pad)
	end)
end

function Stockroom.seatAll(players: { Player })
	for i, player in players do
		Stockroom.seatPlayer(player, i)
	end
end

function Stockroom.getModel(): Model?
	return room
end

return Stockroom
