--!strict

-- Equipped title over the head — text only (no pill / chip behind it).
-- Flair still drives size, studs offset, and text color motion.

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

local function buildTag(head: BasePart, plate: Prestige.PlateStyle): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = TAG_NAME
	gui.Size = UDim2.fromOffset(plate.width, plate.height)
	gui.StudsOffset = Vector3.new(0, plate.studsY, 0)
	gui.AlwaysOnTop = plate.id == "icon" or plate.id == "gold"
	gui.MaxDistance = if plate.id == "icon" then 110 else 80
	gui.Adornee = head

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	label.TextSize = plate.textSize
	label.TextColor3 = if plate.accent ~= nil then plate.accent else Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(10, 9, 14)
	label.TextStrokeTransparency = 0.15
	label.Parent = gui

	if plate.rainbow then
		candyGradient(label)
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
	elseif plate.pulse then
		task.spawn(function()
			local bright = plate.accent
			local dim = if plate.accentB ~= nil then plate.accentB else bright:Lerp(Color3.new(1, 1, 1), 0.35)
			while label.Parent ~= nil do
				local a = TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					TextColor3 = dim,
				})
				a:Play()
				a.Completed:Wait()
				if label.Parent == nil then
					return
				end
				local b = TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					TextColor3 = bright,
				})
				b:Play()
				b.Completed:Wait()
			end
		end)
	end

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
	if existing ~= nil and existing:IsA("BillboardGui") then
		-- Drop legacy pill chips from older builds.
		local chip = existing:FindFirstChild("Chip")
		if chip ~= nil then
			existing:Destroy()
			existing = nil
		else
			local found = existing:FindFirstChild("Text")
			if found ~= nil and found:IsA("TextLabel") then
				label = found
			end
		end
	end
	if label == nil then
		if existing ~= nil then
			existing:Destroy()
		end
		local gui, created = buildTag(head, plate)
		gui:SetAttribute("Flair", wantKey)
		label = created
	end
	if label ~= nil then
		label.Text = text
		if accent ~= nil and not plate.rainbow and not plate.pulse then
			label.TextColor3 = accent
		end
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
