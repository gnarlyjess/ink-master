--!strict

-- Slim payout toast after ceremony ends. Held during showcase / voting / party
-- so the winner moment stays uncluttered.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Juice = require(script.Parent.Juice)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type Line = {
	label: string,
	coins: number,
	xp: number,
}

type Payload = {
	lines: { Line },
	coins: number,
	xp: number,
	balance: number,
	leveled: boolean,
	levelAfter: number?,
}

local VISIBLE_SECONDS = 6

local RoundResults = {}

local gui: ScreenGui? = nil
local held = false
local pending: Payload? = nil
local token = 0

local heading: TextLabel
local total: TextLabel
local dismiss: TextButton
local card: Frame

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

local function hide()
	token += 1
	if gui ~= nil then
		gui.Enabled = false
	end
end

local function showCard(payload: Payload)
	if gui == nil then
		return
	end
	heading.Text = if payload.leveled and payload.levelAfter ~= nil then `LEVEL {payload.levelAfter}!` else "Nice work!"
	total.Text = `+{UiKit.number(payload.coins)} coins  ·  +{UiKit.number(payload.xp)} XP`
	gui.Enabled = true

	local scale = card:FindFirstChildOfClass("UIScale")
	if scale == nil then
		scale = Instance.new("UIScale")
		scale.Parent = card
	end
	scale.Scale = 0.8
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	Juice.punch(heading, 1.12)

	Sfx.play(if payload.leveled then "level" else "good")

	token += 1
	local mine = token
	task.delay(VISIBLE_SECONDS, function()
		if token == mine then
			hide()
		end
	end)
end

local function flush()
	if held or pending == nil then
		return
	end
	local nextPayload = pending
	pending = nil
	showCard(nextPayload)
end

function RoundResults.setHold(blocked: boolean)
	held = blocked
	if blocked then
		hide()
		return
	end
	flush()
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

	local screen = Instance.new("ScreenGui")
	screen.Name = "InkMastersResults"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 48
	screen.Enabled = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
	gui = screen

	card = UiKit.frame(screen, UiTheme.color.panel, 0.02)
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, -UiTheme.safe.bottom)
	card.Size = UDim2.fromOffset(320, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	UiKit.corner(card, 16)
	UiKit.stroke(card, UiTheme.color.gold, 2, 0.2)
	UiKit.padding(card, 14, 16, 14, 16)
	local layout = UiKit.list(card, Enum.FillDirection.Vertical, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	heading = UiKit.label(card, "Nice work!", 22, UiTheme.font.heavy, UiTheme.color.sunshine)
	heading.LayoutOrder = 1
	heading.Size = UDim2.new(1, 0, 0, 28)
	heading.TextStrokeTransparency = 0.75
	heading.TextStrokeColor3 = UiTheme.color.hotPink

	total = UiKit.label(card, "", 16, UiTheme.font.heavy, UiTheme.color.lime)
	total.LayoutOrder = 2
	total.Size = UDim2.new(1, 0, 0, 22)

	dismiss = UiKit.button(card, "NICE!", 14, UiTheme.color.ink, UiTheme.color.gold, 12)
	dismiss.LayoutOrder = 3
	dismiss.Size = UDim2.new(1, 0, 0, 36)
	dismiss.MouseButton1Click:Connect(function()
		Sfx.play("click")
		Juice.punch(dismiss, 1.1)
		hide()
	end)

	Remotes.RoundRewards.OnClientEvent:Connect(function(raw: any)
		if typeof(raw) ~= "table" then
			return
		end
		local lines = readLines(raw.lines)
		local coins = raw.coins
		local xp = raw.xp
		local purse = raw.balance
		if lines == nil or typeof(coins) ~= "number" or typeof(xp) ~= "number" or typeof(purse) ~= "number" then
			return
		end

		local leveled = typeof(raw.levelAfter) == "number"
			and typeof(raw.levelBefore) == "number"
			and raw.levelAfter > raw.levelBefore
		local payload: Payload = {
			lines = lines,
			coins = math.max(0, math.floor(coins)),
			xp = math.max(0, math.floor(xp)),
			balance = math.max(0, math.floor(purse)),
			leveled = leveled,
			levelAfter = if typeof(raw.levelAfter) == "number" then raw.levelAfter else nil,
		}

		if held then
			pending = payload
			return
		end
		showCard(payload)
	end)
end

return RoundResults
