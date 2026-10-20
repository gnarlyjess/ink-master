--!strict

-- Shows each artist's equipped title above their head, so everyone in the parlour can see it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Profiles = require(script.Parent.Profiles)

local TAG_NAME = "InkTitle"
local TAG = "InkTitle"

local NameTags = {}

local function titleInfo(player: Player): (string?, Color3?)
	local data = Profiles.get(player)
	if data == nil then
		return nil, nil
	end
	local itemId = data.equipped.title
	if itemId == "" then
		return nil, nil
	end
	local item = Catalogue.get(itemId)
	if item == nil or item.category ~= "title" then
		return nil, nil
	end
	local accent = if item.accent ~= nil then Catalogue.toColor3(item.accent) else Color3.fromRGB(242, 196, 122)
	return item.text, accent
end

local function buildTag(head: BasePart): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = TAG_NAME
	gui.Size = UDim2.fromOffset(280, 34)
	gui.StudsOffset = Vector3.new(0, 2.85, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 80
	gui.Adornee = head

	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.BackgroundColor3 = Color3.fromRGB(18, 10, 28)
	chip.BackgroundTransparency = 0.18
	chip.BorderSizePixel = 0
	chip.Size = UDim2.fromScale(1, 1)
	chip.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = chip

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Glow"
	stroke.Color = Color3.fromRGB(255, 196, 64)
	stroke.Thickness = 1.6
	stroke.Transparency = 0.25
	stroke.Parent = chip

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	label.TextSize = 17
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(10, 9, 14)
	label.TextStrokeTransparency = 0.2
	label.Parent = chip

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 72, 168)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(64, 220, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 214, 64)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 255, 96)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(168, 96, 255)),
	})
	grad.Parent = label

	CollectionService:AddTag(gui, TAG)
	gui.Parent = head
	return gui, label
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

	local text, accent = titleInfo(player)
	local existing = head:FindFirstChild(TAG_NAME)
	if text == nil then
		if existing ~= nil then
			existing:Destroy()
		end
		return
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
		local gui, created = buildTag(head)
		label = created
		local chip = gui:FindFirstChild("Chip")
		if chip ~= nil then
			local glow = chip:FindFirstChild("Glow")
			if glow ~= nil and glow:IsA("UIStroke") then
				stroke = glow
			end
		end
	end
	if label ~= nil then
		label.Text = text
	end
	if stroke ~= nil and accent ~= nil then
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
