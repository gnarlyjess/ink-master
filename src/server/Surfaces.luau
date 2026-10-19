--!strict

-- The parlour's material library and the small builders every interior module shares.
-- Variants live in MaterialService (src/materials, synced by Rojo or saved in the place).
-- A runtime script cannot create a MaterialVariant, so if one is missing the part
-- falls back to the base material and a colour close to the texture's average.

local MaterialService = game:GetService("MaterialService")

local Surfaces = {}

type Surface = {
	base: Enum.Material,
	variant: string?,
	fallback: Color3,
}

local SURFACES: { [string]: Surface } = {
	oak = { base = Enum.Material.WoodPlanks, variant = "InkOakFloor", fallback = Color3.fromRGB(104, 80, 60) },
	walnut = { base = Enum.Material.Wood, variant = "InkWalnut", fallback = Color3.fromRGB(80, 54, 38) },
	plaster = { base = Enum.Material.Plaster, variant = "InkPlaster", fallback = Color3.fromRGB(226, 220, 208) },
	oxblood = { base = Enum.Material.Plaster, variant = "InkOxblood", fallback = Color3.fromRGB(88, 30, 36) },
	concrete = { base = Enum.Material.Concrete, variant = "InkConcrete", fallback = Color3.fromRGB(122, 120, 116) },
	tile = { base = Enum.Material.CeramicTiles, variant = "InkTile", fallback = Color3.fromRGB(232, 230, 224) },
	powder = { base = Enum.Material.SmoothPlastic, variant = "InkPowder", fallback = Color3.fromRGB(40, 40, 42) },
	steel = { base = Enum.Material.Metal, variant = "InkSteel", fallback = Color3.fromRGB(168, 170, 172) },
	brass = { base = Enum.Material.Foil, variant = "InkBrass", fallback = Color3.fromRGB(150, 118, 72) },
	leather = { base = Enum.Material.Leather, variant = "InkLeather", fallback = Color3.fromRGB(36, 32, 30) },
	leatherOx = { base = Enum.Material.Fabric, variant = "InkLeatherOx", fallback = Color3.fromRGB(86, 30, 34) },
	stone = { base = Enum.Material.Slate, variant = "InkStone", fallback = Color3.fromRGB(44, 43, 44) },
	-- Untextured finishes: the tint is the colour.
	fabric = { base = Enum.Material.Fabric, fallback = Color3.new(1, 1, 1) },
	paint = { base = Enum.Material.SmoothPlastic, fallback = Color3.new(1, 1, 1) },
	rubber = { base = Enum.Material.Rubber, fallback = Color3.new(1, 1, 1) },
	glass = { base = Enum.Material.Glass, fallback = Color3.new(1, 1, 1) },
	neon = { base = Enum.Material.Neon, fallback = Color3.new(1, 1, 1) },
	brick = { base = Enum.Material.Brick, fallback = Color3.new(1, 1, 1) },
	ground = { base = Enum.Material.Ground, fallback = Color3.new(1, 1, 1) },
	leaf = { base = Enum.Material.SmoothPlastic, fallback = Color3.new(1, 1, 1) },
}

-- Brass reads olive without a warm lift; every other variant shows its own colour.
local DEFAULT_TINT: { [string]: Color3 } = {
	brass = Color3.fromRGB(255, 222, 176),
}

local WHITE = Color3.new(1, 1, 1)
local present: { [string]: boolean } = {}

local function hasVariant(name: string): boolean
	local cached = present[name]
	if cached ~= nil then
		return cached
	end
	local found = false
	for _, child in MaterialService:GetDescendants() do
		if child:IsA("MaterialVariant") and child.Name == name then
			found = true
			break
		end
	end
	present[name] = found
	return found
end

local function multiply(a: Color3, b: Color3): Color3
	return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B)
end

function Surfaces.apply(part: BasePart, key: string, tint: Color3?)
	local surface = SURFACES[key]
	if surface == nil then
		warn(`[InkMasters] Unknown surface {key}`)
		return
	end
	local shade = tint or DEFAULT_TINT[key] or WHITE
	part.Material = surface.base
	local variant = surface.variant
	if variant ~= nil and hasVariant(variant) then
		part.MaterialVariant = variant
		part.Color = shade
	else
		part.MaterialVariant = ""
		part.Color = multiply(surface.fallback, shade)
	end
	part.Reflectance = 0
end

export type Opts = {
	tint: Color3?,
	collide: boolean?,
	shape: Enum.PartType?,
	transparency: number?,
	shadow: boolean?,
	query: boolean?,
}

function Surfaces.part(parent: Instance, name: string, size: Vector3, cframe: CFrame, key: string, opts: Opts?): Part
	local o: Opts = opts or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = o.shape or Enum.PartType.Block
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local collide = o.collide == true
	part.CanCollide = collide
	part.CanTouch = false
	part.CanQuery = if o.query ~= nil then o.query else collide
	part.CastShadow = if o.shadow == nil then true else o.shadow
	part.Transparency = o.transparency or 0
	Surfaces.apply(part, key, o.tint)
	part.Parent = parent
	return part
end

-- A cylinder standing on its end. Roblox cylinders run along local X.
function Surfaces.post(
	parent: Instance,
	name: string,
	height: number,
	diameter: number,
	base: Vector3,
	key: string,
	opts: Opts?
): Part
	local o: Opts = table.clone(opts or {})
	o.shape = Enum.PartType.Cylinder
	return Surfaces.part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		key,
		o
	)
end

-- An ellipsoid, for leaves, cushions and lamp globes.
function Surfaces.ellipsoid(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	key: string,
	opts: Opts?
): Part
	local part = Surfaces.part(parent, name, size, cframe, key, opts)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

function Surfaces.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Surfaces.spot(
	parent: BasePart,
	face: Enum.NormalId,
	color: Color3,
	brightness: number,
	range: number,
	angle: number,
	shadows: boolean
): SpotLight
	local light = Instance.new("SpotLight")
	light.Face = face
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Angle = angle
	light.Shadows = shadows
	light.Parent = parent
	return light
end

function Surfaces.wash(
	parent: BasePart,
	face: Enum.NormalId,
	color: Color3,
	brightness: number,
	range: number,
	angle: number,
	shadows: boolean
): SurfaceLight
	local light = Instance.new("SurfaceLight")
	light.Face = face
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Angle = angle
	light.Shadows = shadows
	light.Parent = parent
	return light
end

function Surfaces.glow(
	parent: BasePart,
	color: Color3,
	brightness: number,
	range: number,
	shadows: boolean?
): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = shadows == true
	light.Parent = parent
	return light
end

-- Real text, lit like paint unless glow is asked for.
function Surfaces.label(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	font: Enum.Font,
	pixelsPerStud: number?,
	lightInfluence: number?
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 64
	gui.LightInfluence = lightInfluence or 1
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = gui
	return label
end

function Surfaces.decal(part: BasePart, face: Enum.NormalId, texture: string): Decal
	local decal = Instance.new("Decal")
	decal.Face = face
	decal.Texture = texture
	decal.Parent = part
	return decal
end

return Surfaces
