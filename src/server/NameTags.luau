--!strict

-- Equipped title over the head. Flair tier (mist → icon) upgrades the plate so
-- high-level artists read as prestige from across the parlour — not just text.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Prestige = require(ReplicatedStorage.Shared.Prestige)
local Profiles = require(script.Parent.Profiles)

local TAG_NAME = "InkTitle"
local TAG = "InkTitle"

local NameTags = {}

local function titleInfo(player: Player): (string?, Color3?, string?)
	local data = Profiles.get(player)
	if data == nil then
		return nil, nil, nil
	end
	local itemId = data.equipped.title
	if itemId == "" then
		return nil, nil, nil
	end
	local item = Catalogue.get(itemId)
	if item == nil or item.category ~= "title" then
		return nil, nil, nil
	end
	local accent = if item.accent ~= nil then Catalogue.toColor3(item.accent) else Color3.fromRGB(242, 196, 122)
	return item.text, accent, item.flair
end

local function candyGradient(parent: Instance)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 72, 168)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(64, 220, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 214, 64)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 255, 96)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(168, 96, 255)),
	})
	grad.Parent = parent
	return grad
end

local function buildTag(head: BasePart, plate: Prestige.PlateStyle): (BillboardGui, TextLabel, UIStroke)
	local gui = Instance.new("BillboardGui")
	gui.Name = TAG_NAME
	gui.Size = UDim2.fromOffset(plate.width, plate.height)
	gui.StudsOffset = Vector3.new(0, plate.studsY, 0)
	gui.AlwaysOnTop = plate.id == "icon" or plate.id == "gold"
	gui.MaxDistance = if plate.id == "icon" then 110 else 80
	gui.Adornee = head

	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.BackgroundColor3 = Color3.fromRGB(18, 10, 28)
	chip.BackgroundTransparency = plate.chipTransparency
	chip.BorderSizePixel = 0
	chip.Size = UDim2.fromScale(1, 1)
	chip.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = chip

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Glow"
	stroke.Color = plate.accent
	stroke.Thickness = plate.strokeThickness
	stroke.Transparency = plate.strokeTransparency
	stroke.Parent = chip

	if plate.accentB ~= nil then
		local inner = Instance.new("UIStroke")
		inner.Name = "InnerGlow"
		inner.Color = plate.accentB
		inner.Thickness = math.max(1, plate.strokeThickness - 1)
		inner.Transparency = 0.35
		inner.Parent = chip
	end

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	label.TextSize = plate.textSize
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(10, 9, 14)
	label.TextStrokeTransparency = 0.2
	label.Parent = chip

	if plate.rainbow then
		candyGradient(label)
	end

	if plate.shimmer then
		local clip = Instance.new("Frame")
		clip.Name = "ShimmerClip"
		clip.BackgroundTransparency = 1
		clip.Size = UDim2.fromScale(1, 1)
		clip.ClipsDescendants = true
		clip.ZIndex = 2
		clip.Parent = chip
		local band = Instance.new("Frame")
		band.BackgroundColor3 = Color3.new(1, 1, 1)
		band.BackgroundTransparency = 0.75
		band.BorderSizePixel = 0
		band.Size = UDim2.fromScale(0.28, 1.5)
		band.Position = UDim2.fromScale(-0.4, -0.2)
		band.Rotation = 18
		band.ZIndex = 2
		band.Parent = clip
		local bandCorner = Instance.new("UICorner")
		bandCorner.CornerRadius = UDim.new(0, 4)
		bandCorner.Parent = band
		task.spawn(function()
			while band.Parent ~= nil do
				band.Position = UDim2.fromScale(-0.5, -0.2)
				local tween = TweenService:Create(
					band,
					TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
					{ Position = UDim2.fromScale(1.2, -0.2) }
				)
				tween:Play()
				tween.Completed:Wait()
				task.wait(0.9)
			end
		end)
	end

	if plate.sparkles then
		for i, spot in { 0.08, 0.92 } do
			local spark = Instance.new("Frame")
			spark.Name = `Spark{i}`
			spark.AnchorPoint = Vector2.new(0.5, 0.5)
			spark.Position = UDim2.fromScale(spot, 0.5)
			spark.Size = UDim2.fromOffset(7, 7)
			spark.BackgroundColor3 = plate.accent
			spark.BorderSizePixel = 0
			spark.Rotation = 45
			spark.ZIndex = 3
			spark.Parent = chip
			local sparkCorner = Instance.new("UICorner")
			sparkCorner.CornerRadius = UDim.new(0, 2)
			sparkCorner.Parent = spark
			TweenService:Create(
				spark,
				TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Size = UDim2.fromOffset(11, 11), BackgroundTransparency = 0.45 }
			):Play()
		end
	end

	if plate.pulse then
		task.spawn(function()
			local base = stroke.Thickness
			local bright = plate.accent
			local dim = if plate.accentB ~= nil then plate.accentB else bright:Lerp(Color3.new(1, 1, 1), 0.35)
			while stroke.Parent ~= nil do
				local a = TweenService:Create(stroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Color = dim,
					Thickness = base + 1.2,
					Transparency = math.max(0, plate.strokeTransparency - 0.15),
				})
				a:Play()
				a.Completed:Wait()
				if stroke.Parent == nil then
					return
				end
				local b = TweenService:Create(stroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Color = bright,
					Thickness = base,
					Transparency = plate.strokeTransparency,
				})
				b:Play()
				b.Completed:Wait()
			end
		end)
	end

	if plate.rainbow then
		local grad = label:FindFirstChildOfClass("UIGradient")
		if grad ~= nil then
			task.spawn(function()
				local start = os.clock()
				while grad.Parent ~= nil do
					local t = (os.clock() - start) * 0.55
					grad.Offset = Vector2.new((t % 2) - 1, 0)
					RunService.Heartbeat:Wait()
				end
			end)
		end
	end

	CollectionService:AddTag(gui, TAG)
	gui.Parent = head
	return gui, label, stroke
end

function NameTags.refresh(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end

	local text, accent, flair = titleInfo(player)
	local existing = head:FindFirstChild(TAG_NAME)
	if text == nil then
		if existing ~= nil then
			existing:Destroy()
		end
		return
	end

	local plate = Prestige.plate(flair)
	-- Rebuild when flair tier changes so sparkles / size match the title.
	local wantKey = plate.id
	if existing ~= nil and existing:IsA("BillboardGui") then
		if existing:GetAttribute("Flair") ~= wantKey then
			existing:Destroy()
			existing = nil
		end
	end

	local label: TextLabel? = nil
	local stroke: UIStroke? = nil
	if existing ~= nil and existing:IsA("BillboardGui") then
		local chip = existing:FindFirstChild("Chip")
		local found = if chip ~= nil then chip:FindFirstChild("Text") else existing:FindFirstChild("Text")
		if found ~= nil and found:IsA("TextLabel") then
			label = found
		end
		if chip ~= nil then
			local glow = chip:FindFirstChild("Glow")
			if glow ~= nil and glow:IsA("UIStroke") then
				stroke = glow
			end
		end
	end
	if label == nil then
		if existing ~= nil then
			existing:Destroy()
		end
		local gui, created, createdStroke = buildTag(head, plate)
		gui:SetAttribute("Flair", wantKey)
		label = created
		stroke = createdStroke
	end
	if label ~= nil then
		label.Text = text
	end
	if stroke ~= nil and accent ~= nil and not plate.pulse then
		stroke.Color = accent
	end
end

function NameTags.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			task.spawn(function()
				character:WaitForChild("Head", 5)
				NameTags.refresh(player)
			end)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return NameTags
