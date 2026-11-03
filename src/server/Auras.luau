--!strict

-- Tattoo-parlour foot auras. Traditional flash motifs (rose, dagger, swallow…)
-- built from parts so the flex reads without waiting on uploaded textures.
-- Optional floor-sheet textures in UiAssets swap in when ids are filled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Prestige = require(ReplicatedStorage.Shared.Prestige)
local UiAssets = require(ReplicatedStorage.Shared.UiAssets)
local Profiles = require(script.Parent.Profiles)

local FOLDER = "InkAura"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FLOOR_Y = -3.05

local Auras = {}

local animConnections: { [Player]: RBXScriptConnection } = {}

local TEXTURE_BY_STYLE: { [string]: string } = {
	mist = UiAssets.auraMist,
	neon = UiAssets.auraNeon,
	gold = UiAssets.auraGold,
	icon = UiAssets.auraIcon,
}

local function clearAura(character: Model)
	local existing = character:FindFirstChild(FOLDER)
	if existing ~= nil then
		existing:Destroy()
	end
	local highlight = character:FindFirstChild("InkAuraHighlight")
	if highlight ~= nil then
		highlight:Destroy()
	end
end

local function styleOf(player: Player): Prestige.AuraStyle?
	local data = Profiles.get(player)
	if data == nil then
		return nil
	end
	local itemId = data.equipped.aura
	if itemId == nil or itemId == "" then
		return nil
	end
	local item = Catalogue.get(itemId)
	if item == nil or item.category ~= "aura" then
		return nil
	end
	return Prestige.aura(item.style)
end

local function basePart(name: string, size: Vector3, color: Color3, material: Enum.Material, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Material = material
	part.Color = color
	part.Transparency = transparency
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	return part
end

local function ball(name: string, diameter: number, color: Color3, material: Enum.Material, transparency: number): Part
	local part = basePart(name, Vector3.new(diameter, diameter, diameter), color, material, transparency)
	part.Shape = Enum.PartType.Ball
	return part
end

local function weldTo(root: BasePart, part: BasePart, offset: CFrame)
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function weldMotif(root: BasePart, host: BasePart, part: BasePart, localCf: CFrame)
	part.CFrame = host.CFrame * localCf
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = host
	weld.Part1 = part
	weld.Parent = part
	part.Parent = host
end

local function flatDisc(name: string, diameter: number, height: number, color: Color3, material: Enum.Material, transparency: number): Part
	local disc = basePart(name, Vector3.new(height, diameter, diameter), color, material, transparency)
	disc.Shape = Enum.PartType.Cylinder
	return disc
end

-- ---- Traditional flash motif builders (tiny part assemblies) ----

local function motifRose(host: BasePart, accent: Color3, ink: Color3, scale: number)
	local leaf = Color3.fromRGB(40, 110, 55)
	for _, side in { -1, 1 } do
		local blade = basePart("Leaf", Vector3.new(0.22, 0.06, 0.38) * scale, leaf, Enum.Material.SmoothPlastic, 0.05)
		weldMotif(host, host, blade, CFrame.new(side * 0.28 * scale, 0, 0.05 * scale) * CFrame.Angles(0, 0, math.rad(side * 35)))
	end
	for i = 1, 6 do
		local ang = (i / 6) * math.pi * 2
		local petal = ball("Petal", 0.28 * scale, accent, Enum.Material.SmoothPlastic, 0.05)
		weldMotif(host, host, petal, CFrame.new(math.cos(ang) * 0.2 * scale, 0.02, math.sin(ang) * 0.2 * scale))
	end
	local core = ball("Core", 0.18 * scale, ink, Enum.Material.SmoothPlastic, 0)
	weldMotif(host, host, core, CFrame.new(0, 0.04, 0))
	local bud = ball("Bud", 0.1 * scale, accent:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.Neon, 0.15)
	weldMotif(host, host, bud, CFrame.new(0, 0.08, 0))
end

local function motifDagger(host: BasePart, accent: Color3, ink: Color3, scale: number)
	local blade = basePart("Blade", Vector3.new(0.12, 0.72, 0.06) * scale, accent, Enum.Material.Metal, 0.05)
	weldMotif(host, host, blade, CFrame.new(0, 0.15 * scale, 0))
	local tip = basePart("Tip", Vector3.new(0.1, 0.18, 0.05) * scale, accent:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.Metal, 0.05)
	tip.Shape = Enum.PartType.Ball -- soft tip
	weldMotif(host, host, tip, CFrame.new(0, 0.52 * scale, 0))
	local guard = basePart("Guard", Vector3.new(0.42, 0.08, 0.1) * scale, ink, Enum.Material.SmoothPlastic, 0)
	weldMotif(host, host, guard, CFrame.new(0, -0.12 * scale, 0))
	local hilt = basePart("Hilt", Vector3.new(0.1, 0.28, 0.1) * scale, Color3.fromRGB(90, 55, 35), Enum.Material.Wood, 0)
	weldMotif(host, host, hilt, CFrame.new(0, -0.32 * scale, 0))
	local pom = ball("Pommel", 0.14 * scale, accent, Enum.Material.Neon, 0.1)
	weldMotif(host, host, pom, CFrame.new(0, -0.5 * scale, 0))
end

local function motifSwallow(host: BasePart, accent: Color3, ink: Color3, scale: number)
	local body = basePart("Body", Vector3.new(0.16, 0.14, 0.42) * scale, accent, Enum.Material.SmoothPlastic, 0.05)
	weldMotif(host, host, body, CFrame.new())
	for _, side in { -1, 1 } do
		local wing = basePart("Wing", Vector3.new(0.55, 0.05, 0.28) * scale, accent:Lerp(ink, 0.15), Enum.Material.SmoothPlastic, 0.05)
		weldMotif(
			host,
			host,
			wing,
			CFrame.new(side * 0.32 * scale, 0.04 * scale, -0.05 * scale) * CFrame.Angles(math.rad(-18), 0, math.rad(side * 28))
		)
	end
	local head = ball("Head", 0.14 * scale, accent, Enum.Material.SmoothPlastic, 0.05)
	weldMotif(host, host, head, CFrame.new(0, 0.02, -0.24 * scale))
	local beak = basePart("Beak", Vector3.new(0.06, 0.05, 0.12) * scale, Color3.fromRGB(255, 180, 60), Enum.Material.SmoothPlastic, 0)
	weldMotif(host, host, beak, CFrame.new(0, 0, -0.34 * scale))
end

local function motifHeart(host: BasePart, accent: Color3, _ink: Color3, scale: number)
	local left = ball("L", 0.28 * scale, accent, Enum.Material.SmoothPlastic, 0.05)
	weldMotif(host, host, left, CFrame.new(-0.1 * scale, 0.08 * scale, 0))
	local right = ball("R", 0.28 * scale, accent, Enum.Material.SmoothPlastic, 0.05)
	weldMotif(host, host, right, CFrame.new(0.1 * scale, 0.08 * scale, 0))
	local tip = basePart("Tip", Vector3.new(0.32, 0.28, 0.2) * scale, accent, Enum.Material.SmoothPlastic, 0.05)
	weldMotif(host, host, tip, CFrame.new(0, -0.1 * scale, 0) * CFrame.Angles(0, 0, math.rad(45)))
end

local function motifStar(host: BasePart, accent: Color3, _ink: Color3, scale: number)
	local core = ball("Core", 0.16 * scale, accent, Enum.Material.Neon, 0.1)
	weldMotif(host, host, core, CFrame.new())
	for i = 1, 5 do
		local ang = -math.pi / 2 + (i / 5) * math.pi * 2
		local point = basePart("Point", Vector3.new(0.1, 0.32, 0.08) * scale, accent, Enum.Material.Neon, 0.08)
		weldMotif(
			host,
			host,
			point,
			CFrame.new(math.cos(ang) * 0.18 * scale, math.sin(ang) * 0.18 * scale, 0)
				* CFrame.Angles(0, 0, ang + math.pi / 2)
		)
	end
end

local function motifSkull(host: BasePart, accent: Color3, ink: Color3, scale: number)
	local cranium = ball("Cranium", 0.42 * scale, accent, Enum.Material.SmoothPlastic, 0.05)
	weldMotif(host, host, cranium, CFrame.new(0, 0.06 * scale, 0))
	local jaw = basePart("Jaw", Vector3.new(0.32, 0.16, 0.22) * scale, accent:Lerp(ink, 0.1), Enum.Material.SmoothPlastic, 0.05)
	weldMotif(host, host, jaw, CFrame.new(0, -0.14 * scale, 0.02 * scale))
	for _, side in { -1, 1 } do
		local eye = ball("Eye", 0.12 * scale, ink, Enum.Material.SmoothPlastic, 0)
		weldMotif(host, host, eye, CFrame.new(side * 0.1 * scale, 0.08 * scale, -0.14 * scale))
	end
end

local function motifAnchor(host: BasePart, accent: Color3, ink: Color3, scale: number)
	local shaft = basePart("Shaft", Vector3.new(0.1, 0.55, 0.1) * scale, accent, Enum.Material.Metal, 0.05)
	weldMotif(host, host, shaft, CFrame.new(0, -0.05 * scale, 0))
	local ring = basePart("Ring", Vector3.new(0.28, 0.28, 0.08) * scale, accent, Enum.Material.Metal, 0.15)
	ring.Shape = Enum.PartType.Cylinder
	weldMotif(host, host, ring, CFrame.new(0, 0.32 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local arms = basePart("Arms", Vector3.new(0.55, 0.1, 0.12) * scale, accent, Enum.Material.Metal, 0.05)
	weldMotif(host, host, arms, CFrame.new(0, -0.28 * scale, 0))
	local stock = basePart("Stock", Vector3.new(0.28, 0.08, 0.08) * scale, ink, Enum.Material.Metal, 0)
	weldMotif(host, host, stock, CFrame.new(0, 0.12 * scale, 0))
end

local function motifBanner(host: BasePart, accent: Color3, ink: Color3, scale: number)
	local ribbon = basePart("Ribbon", Vector3.new(0.7, 0.18, 0.06) * scale, accent, Enum.Material.SmoothPlastic, 0.05)
	weldMotif(host, host, ribbon, CFrame.new())
	local notch = basePart("Notch", Vector3.new(0.16, 0.18, 0.05) * scale, accent:Lerp(ink, 0.2), Enum.Material.SmoothPlastic, 0.05)
	weldMotif(host, host, notch, CFrame.new(0.38 * scale, 0, 0) * CFrame.Angles(0, 0, math.rad(45)))
	local seal = ball("Seal", 0.12 * scale, ink, Enum.Material.Neon, 0.2)
	weldMotif(host, host, seal, CFrame.new(-0.05 * scale, 0, 0.04 * scale))
end

local function motifSnake(host: BasePart, accent: Color3, ink: Color3, scale: number)
	for i = 0, 5 do
		local t = i / 5
		local seg = ball("Seg", (0.14 - t * 0.03) * scale, if i % 2 == 0 then accent else accent:Lerp(ink, 0.25), Enum.Material.SmoothPlastic, 0.05)
		local x = math.sin(t * math.pi * 2) * 0.22 * scale
		local y = (t - 0.5) * 0.55 * scale
		weldMotif(host, host, seg, CFrame.new(x, y, 0))
	end
	local head = ball("Head", 0.16 * scale, accent, Enum.Material.SmoothPlastic, 0.05)
	weldMotif(host, host, head, CFrame.new(0, 0.32 * scale, 0))
end

local MOTIF_BUILDERS: { [string]: (BasePart, Color3, Color3, number) -> () } = {
	rose = motifRose,
	dagger = motifDagger,
	swallow = motifSwallow,
	heart = motifHeart,
	star = motifStar,
	skull = motifSkull,
	anchor = motifAnchor,
	banner = motifBanner,
	snake = motifSnake,
}

local function makeFlashHost(folder: Folder, root: BasePart, index: number): (BasePart, Weld)
	local host = basePart(`Flash{index}`, Vector3.new(0.15, 0.15, 0.15), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	host.Parent = folder
	local weld = Instance.new("Weld")
	weld.Name = "FlashWeld"
	weld.Part0 = root
	weld.Part1 = host
	weld.C0 = CFrame.new(0, FLOOR_Y + 0.55, 0)
	weld.Parent = host
	return host, weld
end

local function textureFor(style: Prestige.AuraStyle): string?
	local id = TEXTURE_BY_STYLE[style.id]
	if id == nil or id == "" then
		return nil
	end
	return id
end

local function attachFloorSheet(folder: Folder, root: BasePart, style: Prestige.AuraStyle, texture: string)
	local size = if style.pool then style.poolSize * 1.15 else 3.2
	local plate = basePart("FlashSheet", Vector3.new(size, 0.04, size), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	plate.Parent = folder
	weldTo(root, plate, CFrame.new(0, FLOOR_Y + 0.02, 0))

	local gui = Instance.new("SurfaceGui")
	gui.Name = "FlashArt"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 64
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = plate

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = texture
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = gui
end

local function attach(player: Player, character: Model, style: Prestige.AuraStyle)
	clearAura(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = character

	local flat = CFrame.new(0, FLOOR_Y, 0) * CFrame.Angles(0, 0, math.rad(90))
	local accentB = style.accentB or style.accent:Lerp(Color3.new(1, 1, 1), 0.35)
	local sheet = textureFor(style)

	local rim: Part? = nil
	if style.pool then
		local pool = flatDisc("InkPool", style.poolSize, 0.07, style.inkColor, Enum.Material.SmoothPlastic, 0.18)
		pool.Reflectance = 0.18
		pool.Parent = folder
		weldTo(root, pool, flat)

		rim = flatDisc("InkRim", style.poolSize * 1.08, 0.05, style.accent, Enum.Material.Neon, 0.32)
		rim.Parent = folder
		weldTo(root, rim, CFrame.new(0, FLOOR_Y + 0.03, 0) * CFrame.Angles(0, 0, math.rad(90)))

		if style.accentB ~= nil then
			local rimB = flatDisc("InkRimB", style.poolSize * 0.7, 0.04, accentB, Enum.Material.Neon, 0.5)
			rimB.Parent = folder
			weldTo(root, rimB, CFrame.new(0, FLOOR_Y + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)))
		end
	end

	-- Transfer-paper stencil dots (always — denser with tier).
	if style.stencilDots > 0 then
		local radius = if style.pool then style.poolSize * 0.52 else 1.55
		for i = 1, style.stencilDots do
			local angle = (i / style.stencilDots) * math.pi * 2
			local dot = ball(`Stencil{i}`, 0.11, style.accent, Enum.Material.SmoothPlastic, 0.2)
			dot.Parent = folder
			weldTo(root, dot, CFrame.new(math.cos(angle) * radius, FLOOR_Y + 0.06, math.sin(angle) * radius))
		end
	end

	if sheet ~= nil then
		attachFloorSheet(folder, root, style, sheet)
	end

	local emit = Instance.new("Attachment")
	emit.Name = "AuraEmit"
	emit.Position = Vector3.new(0, FLOOR_Y + 0.12, 0)
	emit.Parent = root

	if style.vaporRate > 0 then
		local vapor = Instance.new("ParticleEmitter")
		vapor.Name = "InkVapor"
		vapor.Texture = SMOKE
		vapor.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, style.accent),
			ColorSequenceKeypoint.new(1, style.inkColor),
		})
		vapor.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.5, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		})
		vapor.LightEmission = 0.25
		vapor.LightInfluence = 0.2
		vapor.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(0.5, 0.85),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		vapor.Lifetime = NumberRange.new(0.7, 1.2)
		vapor.Speed = NumberRange.new(0.15, 0.45)
		vapor.SpreadAngle = Vector2.new(180, 180)
		vapor.Rate = style.vaporRate
		vapor.RotSpeed = NumberRange.new(-25, 25)
		vapor.LockedToPart = true
		vapor.Parent = emit
		vapor:Emit(4)
	end

	if style.dripRate > 0 then
		local drips = Instance.new("ParticleEmitter")
		drips.Name = "InkDrips"
		drips.Texture = SPARK
		drips.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, style.accent),
			ColorSequenceKeypoint.new(0.6, style.inkColor),
			ColorSequenceKeypoint.new(1, style.inkColor),
		})
		drips.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		drips.LightEmission = 0.15
		drips.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.4, 0.14),
			NumberSequenceKeypoint.new(1, 0.04),
		})
		drips.Lifetime = NumberRange.new(0.45, 0.8)
		drips.Speed = NumberRange.new(0.4, 1.0)
		drips.SpreadAngle = Vector2.new(18, 18)
		drips.Acceleration = Vector3.new(0, -6, 0)
		drips.EmissionDirection = Enum.NormalId.Bottom
		drips.Rate = style.dripRate
		drips.LockedToPart = false
		drips.Parent = emit
	end

	if style.needleRate > 0 then
		local needle = Instance.new("ParticleEmitter")
		needle.Name = "NeedleSparks"
		needle.Texture = SPARK
		needle.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 245)),
			ColorSequenceKeypoint.new(0.4, style.accent),
			ColorSequenceKeypoint.new(1, accentB),
		})
		needle.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.35, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		needle.LightEmission = 0.85
		needle.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.06),
			NumberSequenceKeypoint.new(0.3, 0.18),
			NumberSequenceKeypoint.new(1, 0),
		})
		needle.Lifetime = NumberRange.new(0.12, 0.28)
		needle.Speed = NumberRange.new(0.8, 2.0)
		needle.SpreadAngle = Vector2.new(40, 40)
		needle.Acceleration = Vector3.new(0, 1.5, 0)
		needle.Rate = style.needleRate
		needle.LockedToPart = false
		needle.Parent = emit
		needle:Emit(3)
	end

	-- Orbiting traditional flash charms (not emoji).
	local flashWelds: { Weld } = {}
	local motifScale = if style.id == "icon" then 0.95 elseif style.id == "gold" then 0.85 elseif style.id == "neon" then 0.75 else 0.62
	for i, symbol in style.flashSymbols do
		local builder = MOTIF_BUILDERS[symbol]
		if builder == nil then
			continue
		end
		local color = if i % 2 == 0 then accentB else style.accent
		local host, weld = makeFlashHost(folder, root, i)
		builder(host, color, style.inkColor, motifScale)
		table.insert(flashWelds, weld)
	end

	local glow = Instance.new("PointLight")
	glow.Name = "AuraGlow"
	glow.Color = style.accent
	glow.Brightness = style.lightBrightness
	glow.Range = style.lightRange
	glow.Parent = root

	if style.highlight then
		local hl = Instance.new("Highlight")
		hl.Name = "InkAuraHighlight"
		hl.FillColor = style.accent
		hl.OutlineColor = accentB
		hl.FillTransparency = 0.93
		hl.OutlineTransparency = 0.5
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = character
	end

	local prev = animConnections[player]
	if prev ~= nil then
		prev:Disconnect()
		animConnections[player] = nil
	end

	if rim ~= nil then
		TweenService:Create(
			rim,
			TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.55 }
		):Play()
	end

	if #flashWelds == 0 and not style.rainbow and style.accentB == nil then
		return
	end

	local t0 = os.clock()
	local orbitRadius = if style.pool then style.poolSize * 0.42 else 1.4
	animConnections[player] = RunService.Heartbeat:Connect(function()
		if folder.Parent == nil then
			local conn = animConnections[player]
			if conn ~= nil then
				conn:Disconnect()
			end
			animConnections[player] = nil
			return
		end
		local t = os.clock() - t0
		local count = #flashWelds
		for i, weld in flashWelds do
			if weld.Parent ~= nil then
				local angle = t * 1.05 + (i / math.max(1, count)) * math.pi * 2
				local y = FLOOR_Y + 0.62 + math.sin(t * 2.1 + i) * 0.12
				-- Face outward a bit so motifs read while orbiting.
				weld.C0 = CFrame.new(math.cos(angle) * orbitRadius, y, math.sin(angle) * orbitRadius)
					* CFrame.Angles(0, -angle + math.pi / 2, 0)
			end
		end
		if glow.Parent ~= nil then
			if style.rainbow then
				local hue = (t * 0.28) % 1
				glow.Color = Color3.fromHSV(hue, 0.75, 1)
				if rim ~= nil and rim.Parent ~= nil then
					rim.Color = Color3.fromHSV(hue, 0.85, 1)
				end
			elseif style.accentB ~= nil then
				local blend = (math.sin(t * 2.0) + 1) * 0.5
				glow.Color = style.accent:Lerp(style.accentB, blend)
			end
		end
	end)
end

function Auras.refresh(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local style = styleOf(player)
	if style == nil then
		clearAura(character)
		local prev = animConnections[player]
		if prev ~= nil then
			prev:Disconnect()
			animConnections[player] = nil
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root ~= nil then
			local glow = root:FindFirstChild("AuraGlow")
			if glow ~= nil then
				glow:Destroy()
			end
		end
		return
	end
	attach(player, character, style)
end

function Auras.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			task.spawn(function()
				character:WaitForChild("HumanoidRootPart", 5)
				task.wait(0.15)
				Auras.refresh(player)
			end)
		end)
		player.CharacterRemoving:Connect(function()
			local prev = animConnections[player]
			if prev ~= nil then
				prev:Disconnect()
				animConnections[player] = nil
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
		if player.Character ~= nil then
			Auras.refresh(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local prev = animConnections[player]
		if prev ~= nil then
			prev:Disconnect()
			animConnections[player] = nil
		end
	end)
end

return Auras
