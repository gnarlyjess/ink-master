--!strict

-- The payout card after a round. Numbers come from the server's RoundRewards event.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type Line = {
	label: string,
	coins: number,
	xp: number,
}

local VISIBLE_SECONDS = 14

local RoundResults = {}

local function readLines(value: any): { Line }?
	if typeof(value) ~= "table" or #value > 12 then
		return nil
	end
	local lines: { Line } = {}
	for index = 1, #value do
		local item = value[index]
		if typeof(item) ~= "table" or typeof(item.label) ~= "string" or #item.label > 48 then
			return nil
		end
		if typeof(item.coins) ~= "number" or typeof(item.xp) ~= "number" then
			return nil
		end
		table.insert(lines, {
			label = item.label,
			coins = math.max(0, math.floor(item.coins)),
			xp = math.max(0, math.floor(item.xp)),
		})
	end
	return lines
end

function RoundResults.start()
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("InkMastersResults")
	if existing ~= nil then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "InkMastersResults"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 48
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local card = UiKit.frame(gui, UiTheme.color.ink, 0.04)
	card.AnchorPoint = Vector2.new(0, 1)
	card.Position = UDim2.new(0, UiTheme.safe.side, 1, -UiTheme.safe.bottom)
	card.Size = UDim2.fromOffset(360, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	UiKit.corner(card, 16)
	UiKit.stroke(card, UiTheme.color.gold, 1.5, 0.25)
	UiKit.padding(card, 14, 16, 14, 16)
	local layout = UiKit.list(card, Enum.FillDirection.Vertical, 6)

	local heading = UiKit.label(card, "Round rewards", 20, UiTheme.font.heavy, UiTheme.color.gold)
	heading.LayoutOrder = 1
	heading.Size = UDim2.new(1, 0, 0, 26)

	local linesHolder = Instance.new("Frame")
	linesHolder.Name = "Lines"
	linesHolder.LayoutOrder = 2
	linesHolder.BackgroundTransparency = 1
	linesHolder.AutomaticSize = Enum.AutomaticSize.Y
	linesHolder.Size = UDim2.fromScale(1, 0)
	linesHolder.Parent = card
	UiKit.list(linesHolder, Enum.FillDirection.Vertical, 2)

	local total = UiKit.label(card, "", 16, UiTheme.font.heavy, UiTheme.color.text)
	total.LayoutOrder = 3
	total.Size = UDim2.new(1, 0, 0, 22)

	local balance = UiKit.label(card, "", 13, UiTheme.font.medium, UiTheme.color.muted)
	balance.LayoutOrder = 4
	balance.Size = UDim2.new(1, 0, 0, 18)

	local dismiss = UiKit.button(card, "Nice", 14, UiTheme.color.ink, UiTheme.color.gold)
	dismiss.LayoutOrder = 5
	dismiss.Size = UDim2.new(1, 0, 0, 34)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local token = 0
	local function hide()
		token += 1
		gui.Enabled = false
	end
	dismiss.MouseButton1Click:Connect(function()
		Sfx.play("click")
		hide()
	end)

	Remotes.RoundRewards.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		local lines = readLines(payload.lines)
		local coins = payload.coins
		local xp = payload.xp
		local purse = payload.balance
		if lines == nil or typeof(coins) ~= "number" or typeof(xp) ~= "number" or typeof(purse) ~= "number" then
			return
		end

		for _, child in linesHolder:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if #lines == 0 then
			local empty =
				UiKit.label(linesHolder, "Nothing to pay out this round.", 14, UiTheme.font.medium, UiTheme.color.muted)
			empty.Size = UDim2.new(1, 0, 0, 20)
		else
			for index, line in lines do
				local row = UiKit.label(
					linesHolder,
					`{line.label}   +{line.coins}   +{line.xp} XP`,
					14,
					UiTheme.font.medium,
					UiTheme.color.text
				)
				row.LayoutOrder = index
				row.Size = UDim2.new(1, 0, 0, 20)
				row.TextTruncate = Enum.TextTruncate.AtEnd
			end
		end

		local leveled = typeof(payload.levelAfter) == "number"
			and typeof(payload.levelBefore) == "number"
			and payload.levelAfter > payload.levelBefore
		heading.Text = if leveled then `Level {payload.levelAfter}!` else "Round rewards"
		total.Text = `+{UiKit.number(coins)} coins   +{UiKit.number(xp)} XP`
		balance.Text = `You now have {UiKit.number(purse)} coins.`
		gui.Enabled = true
		Sfx.play(if leveled then "level" else "good")

		token += 1
		local mine = token
		task.delay(VISIBLE_SECONDS, function()
			if token == mine then
				gui.Enabled = false
			end
		end)
	end)
end

return RoundResults
