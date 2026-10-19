--!strict

-- Shows each artist's equipped title above their head, so everyone in the parlour can see it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Profiles = require(script.Parent.Profiles)

local TAG_NAME = "InkTitle"

local NameTags = {}

local function titleText(player: Player): string?
	local data = Profiles.get(player)
	if data == nil then
		return nil
	end
	local itemId = data.equipped.title
	if itemId == "" then
		return nil
	end
	local item = Catalogue.get(itemId)
	if item == nil then
		return nil
	end
	return item.text
end

local function buildTag(head: BasePart): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = TAG_NAME
	gui.Size = UDim2.fromOffset(240, 26)
	gui.StudsOffset = Vector3.new(0, 2.7, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 70
	gui.Adornee = head

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(242, 196, 122)
	label.TextStrokeColor3 = Color3.fromRGB(10, 9, 14)
	label.TextStrokeTransparency = 0.35
	label.Parent = gui

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

	local text = titleText(player)
	local existing = head:FindFirstChild(TAG_NAME)
	if text == nil then
		if existing ~= nil then
			existing:Destroy()
		end
		return
	end

	local label: TextLabel? = nil
	if existing ~= nil and existing:IsA("BillboardGui") then
		local found = existing:FindFirstChild("Text")
		if found ~= nil and found:IsA("TextLabel") then
			label = found
		end
	end
	if label == nil then
		if existing ~= nil then
			existing:Destroy()
		end
		local _, created = buildTag(head)
		label = created
	end
	if label ~= nil then
		label.Text = text
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
