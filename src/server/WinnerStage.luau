--!strict

-- The podium hall the round moves to for the display case, the vote, and the party.
-- It is a closed room well away from the shop, so the shop lighting never reaches it.
-- The client finds CameraMark here to frame the podiums during the party.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WinnerStageLayout = require(ReplicatedStorage.Shared.WinnerStageLayout)
local LayoutBake = require(script.Parent.LayoutBake)
local Lobby = require(script.Parent.Lobby)

local ORIGIN = Vector3.new(0, 0, 420)
local HALF_W = 34
local HALF_D = 30
local HEIGHT = 28
local DAIS_Z = 16
local DAIS_TOP = 1.2

local PALETTE = {
	floor = Color3.fromRGB(28, 14, 32),
	wall = Color3.fromRGB(38, 16, 44),
	curtain = Color3.fromRGB(186, 36, 92),
	curtainDeep = Color3.fromRGB(110, 18, 54),
	dais = Color3.fromRGB(48, 24, 50),
	gold = Color3.fromRGB(255, 210, 96),
	silver = Color3.fromRGB(230, 236, 255),
	bronze = Color3.fromRGB(232, 148, 78),
	magenta = Color3.fromRGB(255, 64, 140),
	aqua = Color3.fromRGB(72, 240, 230),
	violet = Color3.fromRGB(176, 110, 255),
	warm = Color3.fromRGB(255, 232, 196),
	ink = Color3.fromRGB(22, 12, 26),
	runway = Color3.fromRGB(236, 220, 196),
	bodyGold = Color3.fromRGB(86, 58, 22),
	bodySilver = Color3.fromRGB(52, 56, 72),
	bodyBronze = Color3.fromRGB(78, 42, 24),
}

type Podium = { x: number, height: number, color: Color3, label: string }

local PODIUMS: { Podium } = {
	{ x = 0, height = 5.4, color = PALETTE.gold, label = "1" },
	{ x = -8.2, height = 3.4, color = PALETTE.silver, label = "2" },
	{ x = 8.2, height = 2.2, color = PALETTE.bronze, label = "3" },
}

local anchored: { BasePart } = {}
local sparkles: { ParticleEmitter } = {}
local tags: { BillboardGui } = {}
local savedLight: { ambient: Color3, outdoor: Color3, brightness: number, exposure: number }? = nil

local function at(x: number, y: number, z: number): Vector3
	return ORIGIN + Vector3.new(x, y, z)
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function trim(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = block(parent, name, size, position, color, Enum.Material.Neon)
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function lettering(part: BasePart, text: string, color: Color3, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.14, 0)
	pad.PaddingBottom = UDim.new(0.14, 0)
	pad.Parent = label
end

local function lamp(parent: Instance, position: Vector3, color: Color3, range: number, brightness: number)
	local rig = block(parent, "Lamp", Vector3.new(0.4, 0.4, 0.4), position, color, Enum.Material.SmoothPlastic)
	rig.Transparency = 1
	rig.CanCollide = false
	rig.CastShadow = false
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = color
	light.Shadows = false
	light.Parent = rig
	return rig
end

local function faceLight(part: BasePart, face: Enum.NormalId, color: Color3, brightness: number, range: number)
	local light = Instance.new("SurfaceLight")
	light.Face = face
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
end

local function sparkOn(part: BasePart, color: Color3, rate: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkle"
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(0.18, 0.04)
	emitter.Lifetime = NumberRange.new(0.7, 1.5)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(1.2, 3.2)
	emitter.SpreadAngle = Vector2.new(80, 80)
	emitter.LightEmission = 0.85
	emitter.LightInfluence = 0
	emitter.Enabled = true
	emitter.Parent = part
	table.insert(sparkles, emitter)
	return emitter
end

local function buildShell(model: Model)
	local floor = block(
		model,
		"Floor",
		Vector3.new(HALF_W * 2, 1, HALF_D * 2),
		at(0, -0.5, 0),
		PALETTE.floor,
		Enum.Material.Marble
	)
	floor.Reflectance = 0.18
	block(
		model,
		"Ceiling",
		Vector3.new(HALF_W * 2, 1, HALF_D * 2),
		at(0, HEIGHT + 0.5, 0),
		Color3.fromRGB(48, 18, 54),
		Enum.Material.SmoothPlastic
	)
	block(
		model,
		"WallBack",
		Vector3.new(HALF_W * 2, HEIGHT, 1),
		at(0, HEIGHT / 2, HALF_D + 0.5),
		PALETTE.wall,
		Enum.Material.Fabric
	)
	block(
		model,
		"WallFront",
		Vector3.new(HALF_W * 2, HEIGHT, 1),
		at(0, HEIGHT / 2, -HALF_D - 0.5),
		PALETTE.wall,
		Enum.Material.Fabric
	)
	block(
		model,
		"WallLeft",
		Vector3.new(1, HEIGHT, HALF_D * 2),
		at(-HALF_W - 0.5, HEIGHT / 2, 0),
		PALETTE.wall,
		Enum.Material.Fabric
	)
	block(
		model,
		"WallRight",
		Vector3.new(1, HEIGHT, HALF_D * 2),
		at(HALF_W + 0.5, HEIGHT / 2, 0),
		PALETTE.wall,
		Enum.Material.Fabric
	)

	local pleats = 20
	local span = 44
	for index = 0, pleats - 1 do
		local x = -span / 2 + (index + 0.5) * (span / pleats)
		local deep = index % 2 == 0
		local pleat = block(
			model,
			"Curtain",
			Vector3.new(span / pleats + 0.12, HEIGHT - 1.4, 0.7),
			at(x, (HEIGHT - 1.4) / 2, HALF_D - (if deep then 0.5 else 1.15)),
			if deep then PALETTE.curtainDeep else PALETTE.curtain,
			Enum.Material.Fabric
		)
		pleat.CanCollide = false
	end

	-- Vertical neon bars behind the podiums, Dress-to-Impress LED wall.
	local bars = { PALETTE.magenta, PALETTE.gold, PALETTE.violet, PALETTE.aqua, PALETTE.gold, PALETTE.magenta }
	for index, color in bars do
		local x = -15 + (index - 1) * 6
		local led =
			trim(model, "Led", Vector3.new(0.55, HEIGHT - 5, 0.28), at(x, (HEIGHT - 5) / 2 + 1.2, HALF_D - 1.6), color)
		faceLight(led, Enum.NormalId.Back, color, 2.2, 18)
	end

	local sign = block(
		model,
		"Sign",
		Vector3.new(28, 4.6, 0.4),
		at(0, 18.2, HALF_D - 2.2),
		PALETTE.ink,
		Enum.Material.SmoothPlastic
	)
	sign.CanCollide = false
	lettering(sign, "INK-OFF", PALETTE.gold, Enum.NormalId.Front)
	sign.CFrame = CFrame.lookAt(sign.Position, sign.Position - Vector3.zAxis)
	faceLight(sign, Enum.NormalId.Front, PALETTE.gold, 1.8, 16)
	trim(model, "SignGlow", Vector3.new(28.6, 0.28, 0.28), at(0, 15.75, HALF_D - 2.3), PALETTE.gold)
	trim(model, "SignGlowTop", Vector3.new(28.6, 0.28, 0.28), at(0, 20.65, HALF_D - 2.3), PALETTE.magenta)
	lamp(model, at(0, 16.5, DAIS_Z + 2), PALETTE.gold, 24, 1.8)

	trim(model, "EdgeLeft", Vector3.new(0.4, 0.2, HALF_D * 2 - 2), at(-HALF_W + 1.2, 0.1, 0), PALETTE.magenta)
	trim(model, "EdgeRight", Vector3.new(0.4, 0.2, HALF_D * 2 - 2), at(HALF_W - 1.2, 0.1, 0), PALETTE.aqua)

	-- Ceiling colour wash + a front fill so the camera never looks into a black box.
	lamp(model, at(-14, HEIGHT - 2, 8), PALETTE.magenta, 36, 1.8)
	lamp(model, at(0, HEIGHT - 2, 6), PALETTE.warm, 44, 2.6)
	lamp(model, at(14, HEIGHT - 2, 8), PALETTE.aqua, 36, 1.8)
	lamp(model, at(0, 8, -8), PALETTE.warm, 40, 2.2)

	for _, x in { -18, 0, 18 } do
		trim(
			model,
			"CeilStrip",
			Vector3.new(10, 0.12, 0.28),
			at(x, HEIGHT - 0.7, 4),
			if x < 0 then PALETTE.magenta elseif x > 0 then PALETTE.aqua else PALETTE.gold
		)
	end
end

local function buildDais(model: Model)
	local dais = block(
		model,
		"Dais",
		Vector3.new(36, DAIS_TOP, 16),
		at(0, DAIS_TOP / 2, DAIS_Z),
		PALETTE.dais,
		Enum.Material.Marble
	)
	dais.Reflectance = 0.12
	trim(model, "DaisLip", Vector3.new(36, 0.2, 0.28), at(0, DAIS_TOP - 0.04, DAIS_Z - 8.05), PALETTE.gold)
	faceLight(dais, Enum.NormalId.Top, PALETTE.warm, 1.2, 14)

	local runway = block(
		model,
		"Runway",
		Vector3.new(8.4, 0.32, 22),
		at(0, 0.18, DAIS_Z - 18),
		PALETTE.runway,
		Enum.Material.Marble
	)
	runway.Reflectance = 0.28
	local runLeft = trim(model, "RunwayLeft", Vector3.new(0.28, 0.16, 22), at(-4.2, 0.38, DAIS_Z - 18), PALETTE.gold)
	local runRight =
		trim(model, "RunwayRight", Vector3.new(0.28, 0.16, 22), at(4.2, 0.38, DAIS_Z - 18), PALETTE.magenta)
	faceLight(runLeft, Enum.NormalId.Top, PALETTE.gold, 1.4, 10)
	faceLight(runRight, Enum.NormalId.Top, PALETTE.magenta, 1.4, 10)
	for step = 0, 5 do
		local z = DAIS_Z - 8 - step * 3.4
		trim(
			model,
			"RunwayMark",
			Vector3.new(7.6, 0.06, 0.22),
			at(0, 0.36, z),
			if step % 2 == 0 then PALETTE.magenta else PALETTE.aqua
		)
	end
	lamp(model, at(0, 6, DAIS_Z - 10), PALETTE.warm, 24, 1.6)

	local bodies = { PALETTE.bodyGold, PALETTE.bodySilver, PALETTE.bodyBronze }
	for index, podium in PODIUMS do
		local top = DAIS_TOP + podium.height
		local body = block(
			model,
			`Podium{index}`,
			Vector3.new(6.2, podium.height, 6.2),
			at(podium.x, DAIS_TOP + podium.height / 2, DAIS_Z),
			bodies[index],
			Enum.Material.SmoothPlastic
		)
		lettering(body, podium.label, podium.color, Enum.NormalId.Front)
		body.CFrame = CFrame.lookAt(body.Position, body.Position - Vector3.zAxis)
		faceLight(body, Enum.NormalId.Front, podium.color, 2.2, 14)
		local cap = block(
			model,
			`PodiumCap{index}`,
			Vector3.new(6.7, 0.36, 6.7),
			at(podium.x, top + 0.18, DAIS_Z),
			podium.color,
			Enum.Material.Metal
		)
		cap.Reflectance = 0.28
		trim(model, `PodiumGlow{index}`, Vector3.new(6.9, 0.14, 6.9), at(podium.x, top - 0.04, DAIS_Z), podium.color)
		lamp(
			model,
			at(podium.x, HEIGHT - 3, DAIS_Z - 1),
			podium.color,
			if index == 1 then 28 else 22,
			if index == 1 then 3.2 else 2.2
		)
		sparkOn(cap, podium.color, if index == 1 then 28 else 14)
	end
end

local function buildCamera(model: Model)
	local mark = Instance.new("Part")
	mark.Name = "CameraMark"
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanTouch = false
	mark.CanQuery = false
	mark.Transparency = 1
	mark.Size = Vector3.one
	mark.CFrame = CFrame.lookAt(at(0, 8.2, -18), at(0, DAIS_TOP + 5.6, DAIS_Z))
	mark.Parent = model
end

local function audienceSpot(index: number): Vector3
	local perRow = 6
	local row = math.floor((index - 1) / perRow)
	local column = (index - 1) % perRow
	local x = -12.5 + column * 5 + (if row % 2 == 1 then 2.5 else 0)
	local z = -3 - row * 4.5
	return at(x, 0.3, z)
end

local function standAt(character: Model, feet: Vector3, facing: Vector3)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	local seat = humanoid.SeatPart
	if seat ~= nil then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld ~= nil then
			weld:Destroy()
		end
	end
	humanoid.Sit = false
	local hip = humanoid.HipHeight + root.Size.Y / 2
	local center = feet + Vector3.new(0, hip + 0.15, 0)
	character:PivotTo(CFrame.lookAt(center, center + facing))
end

local function unanchor()
	for _, part in anchored do
		if part.Parent ~= nil then
			part.Anchored = false
		end
	end
	table.clear(anchored)
end

local function clearTags()
	for _, tag in tags do
		tag:Destroy()
	end
	table.clear(tags)
end

local function partyLight(on: boolean)
	if on then
		if savedLight == nil then
			savedLight = {
				ambient = Lighting.Ambient,
				outdoor = Lighting.OutdoorAmbient,
				brightness = Lighting.Brightness,
				exposure = Lighting.ExposureCompensation,
			}
		end
		Lighting.Ambient = Color3.fromRGB(62, 28, 52)
		Lighting.OutdoorAmbient = Color3.fromRGB(48, 24, 56)
		Lighting.Brightness = 1.7
		Lighting.ExposureCompensation = 0.28
		return
	end
	local previous = savedLight
	if previous == nil then
		return
	end
	Lighting.Ambient = previous.ambient
	Lighting.OutdoorAmbient = previous.outdoor
	Lighting.Brightness = previous.brightness
	Lighting.ExposureCompensation = previous.exposure
	savedLight = nil
end

local function tagPlace(character: Model, place: number, color: Color3)
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "InkPlace"
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	label.Text = if place == 1 then "1st" elseif place == 2 then "2nd" else "3rd"
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = PALETTE.ink
	stroke.Thickness = 2
	stroke.Parent = label
	table.insert(tags, gui)
end

local WinnerStage = {}

function WinnerStage.build()
	local existing = Workspace:FindFirstChild("WinnerStage")
	if existing ~= nil then
		existing:Destroy()
	end
	table.clear(sparkles)
	local model = Instance.new("Model")
	model.Name = "WinnerStage"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	buildShell(model)
	buildDais(model)
	buildCamera(model)
	model.Parent = Workspace
	LayoutBake.apply(model, WinnerStageLayout)
end

-- Everyone stands in the audience facing the podiums.
function WinnerStage.gather()
	unanchor()
	clearTags()
	partyLight(true)
	local index = 0
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			index += 1
			standAt(character, audienceSpot(index), Vector3.zAxis)
		end
	end
end

-- The top three step up and face the room. Their roots stay anchored until release.
function WinnerStage.crown(userIds: { number })
	unanchor()
	clearTags()
	for place, userId in userIds do
		local podium = PODIUMS[place]
		local player = Players:GetPlayerByUserId(userId)
		local character = if player ~= nil then player.Character else nil
		if podium ~= nil and character ~= nil then
			standAt(character, at(podium.x, DAIS_TOP + podium.height + 0.3, DAIS_Z), -Vector3.zAxis)
			local root = character:FindFirstChild("HumanoidRootPart")
			if root ~= nil and root:IsA("BasePart") then
				root.Anchored = true
				table.insert(anchored, root)
			end
			tagPlace(character, place, podium.color)
		end
	end
	partyLight(true)
	for _, emitter in sparkles do
		emitter.Enabled = true
	end
end

function WinnerStage.release()
	unanchor()
	clearTags()
	partyLight(false)
	Lobby.returnToShop()
end

return WinnerStage
