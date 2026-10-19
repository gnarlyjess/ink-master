--!strict

-- Cinematic unlock / welcome / daily-ink cards. Parlour palette: ink, brass, oxblood, cream.
-- Same energy as a boutique unlock popup — without the pink sparkles.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local PlayerData = require(script.Parent.PlayerData)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

export type FanfareKind = "welcome" | "login" | "level" | "item" | "achievement"

export type FanfarePayload = {
	kind: FanfareKind,
	title: string,
	subtitle: string?,
	detail: string?,
	coins: number?,
	day: number?,
	streak: number?,
	-- When set, the primary button claims the daily login instead of just closing.
	claimLogin: boolean?,
}

local POP = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GLINT = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local Fanfare = {}

local gui: ScreenGui? = nil
local busy = false
local held = false
local holds: { [string]: boolean } = {}
local queue: { FanfarePayload } = {}
local dailyPrompted = false
local currentPayload: FanfarePayload? = nil

local function clearActiveCard()
	local root = gui
	if root ~= nil then
		for _, child in root:GetChildren() do
			if child.Name == "FanfareDim" then
				child:Destroy()
			end
		end
	end
	busy = false
	currentPayload = nil
end

local function claimIfNeeded(payload: FanfarePayload?)
	if payload ~= nil and payload.claimLogin then
		PlayerData.send("claimLogin", nil, nil)
	end
end

local function anyHold(): boolean
	for _, on in holds do
		if on then
			return true
		end
	end
	return false
end

local function softShadow(parent: Instance, size: UDim2, position: UDim2): Frame
	local shadow = UiKit.frame(parent, UiTheme.color.shadow, 0.55)
	shadow.Size = size
	shadow.Position = position
	shadow.ZIndex = 1
	UiKit.corner(shadow, 18)
	return shadow
end

local function cropMark(parent: Instance, x: number, y: number, flipX: number, flipY: number)
	local mark = UiKit.frame(parent, UiTheme.color.gold, 0)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.new(x, flipX * 10, y, flipY * 10)
	mark.Size = UDim2.fromOffset(18, 18)
	mark.BackgroundTransparency = 1
	mark.ZIndex = 6
	local h = UiKit.frame(mark, UiTheme.color.gold, 0)
	h.Size = UDim2.fromOffset(18, 2)
	h.Position = UDim2.fromOffset(0, if flipY < 0 then 16 else 0)
	local v = UiKit.frame(mark, UiTheme.color.gold, 0)
	v.Size = UDim2.fromOffset(2, 18)
	v.Position = UDim2.fromOffset(if flipX < 0 then 16 else 0, 0)
end

local function glint(parent: Instance, x: number, y: number, delaySec: number)
	local spark = UiKit.frame(parent, UiTheme.color.gold, 0.15)
	spark.AnchorPoint = Vector2.new(0.5, 0.5)
	spark.Position = UDim2.fromScale(x, y)
	spark.Size = UDim2.fromOffset(7, 7)
	spark.Rotation = 45
	spark.ZIndex = 8
	task.delay(delaySec, function()
		if spark.Parent == nil then
			return
		end
		TweenService:Create(spark, GLINT, {
			Size = UDim2.fromOffset(11, 11),
			BackgroundTransparency = 0.55,
		}):Play()
	end)
end

local function coinStack(parent: Instance, amount: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "RewardArt"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(120, 120)
	holder.ZIndex = 4
	holder.Parent = parent

	local plate = UiKit.frame(holder, UiTheme.color.paper, 0)
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromScale(1, 1)
	UiKit.corner(plate, 14)
	UiKit.stroke(plate, UiTheme.color.gold, 2, 0.15)

	local stack = Instance.new("Frame")
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(0.5, 0.5)
	stack.Position = UDim2.fromScale(0.5, 0.42)
	stack.Size = UDim2.fromOffset(58, 44)
	stack.Parent = plate

	for i = 1, 3 do
		local coin = UiKit.frame(stack, UiTheme.color.gold, 0)
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Position = UDim2.fromScale(0.5, 0.72 - (i - 1) * 0.28)
		coin.Size = UDim2.fromOffset(52 - i * 2, 12)
		UiKit.corner(coin, 999)
		UiKit.stroke(coin, Color3.fromRGB(150, 110, 50), 1, 0.25)
	end

	local amountLabel = UiKit.label(plate, `+{UiKit.number(amount)}`, 20, UiTheme.font.heavy, UiTheme.color.ink)
	amountLabel.AnchorPoint = Vector2.new(0.5, 1)
	amountLabel.Position = UDim2.new(0.5, 0, 1, -8)
	amountLabel.Size = UDim2.new(1, -8, 0, 22)
	amountLabel.TextXAlignment = Enum.TextXAlignment.Center
	amountLabel.ZIndex = 5
	return holder
end

local function present(payload: FanfarePayload)
	local root = gui
	if root == nil then
		return
	end
	busy = true
	currentPayload = payload

	local dim = UiKit.frame(root, Color3.new(0, 0, 0), 1)
	dim.Name = "FanfareDim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 1
	dim.Active = true

	local cardH = 340
	local shadow = softShadow(dim, UDim2.fromOffset(360, cardH + 16), UDim2.new(0.5, 6, 0.5, 10))
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)

	local card = UiKit.frame(dim, UiTheme.color.ink, 1)
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.54)
	card.Size = UDim2.fromOffset(340, cardH)
	card.ZIndex = 2
	card.Active = true
	UiKit.corner(card, 16)
	local border = UiKit.stroke(card, UiTheme.color.gold, 2, 0.1)

	local face = UiKit.frame(card, UiTheme.color.paper, 0)
	face.Position = UDim2.fromOffset(12, 12)
	face.Size = UDim2.new(1, -24, 1, -24)
	face.ZIndex = 3
	UiKit.corner(face, 10)
	UiKit.stroke(face, UiTheme.color.ink, 1.5, 0.55)

	cropMark(face, 0, 0, 1, 1)
	cropMark(face, 1, 0, -1, 1)
	cropMark(face, 0, 1, 1, -1)
	cropMark(face, 1, 1, -1, -1)

	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.Position = UDim2.fromOffset(18, 16)
	column.Size = UDim2.new(1, -36, 1, -72)
	column.ZIndex = 4
	column.Parent = face
	local list = UiKit.list(column, Enum.FillDirection.Vertical, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top

	local kicker = UiKit.label(column, "INK-OFF", 11, UiTheme.font.bold, UiTheme.color.oxblood)
	kicker.Size = UDim2.new(1, 0, 0, 14)
	kicker.TextXAlignment = Enum.TextXAlignment.Center
	kicker.LayoutOrder = 1

	local titleSize = if #payload.title > 28 then 18 else 26
	local titleHeight = if #payload.title > 28 then 44 else 30
	local title = UiKit.label(column, payload.title, titleSize, UiTheme.font.heavy, UiTheme.color.ink)
	title.Size = UDim2.new(1, 0, 0, titleHeight)
	title.TextWrapped = true
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.LayoutOrder = 2

	if payload.subtitle ~= nil and payload.subtitle ~= "" then
		local sub = UiKit.label(column, payload.subtitle, 14, UiTheme.font.medium, UiTheme.color.inkMuted)
		sub.Size = UDim2.new(1, 0, 0, 18)
		sub.TextXAlignment = Enum.TextXAlignment.Center
		sub.LayoutOrder = 3
	end

	local coins = payload.coins or 0
	if coins > 0 then
		local art = coinStack(column, coins)
		art.LayoutOrder = 4
	else
		local badge = UiKit.frame(column, UiTheme.color.ink, 0)
		badge.Size = UDim2.fromOffset(100, 100)
		badge.LayoutOrder = 4
		UiKit.corner(badge, 14)
		UiKit.stroke(badge, UiTheme.color.gold, 2, 0.2)
		local glyph = UiKit.label(badge, "✦", 36, UiTheme.font.heavy, UiTheme.color.gold)
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.TextXAlignment = Enum.TextXAlignment.Center
	end

	glint(face, 0.16, 0.22, 0.05)
	glint(face, 0.84, 0.28, 0.2)
	glint(face, 0.2, 0.78, 0.35)
	glint(face, 0.8, 0.74, 0.5)

	if payload.detail ~= nil and payload.detail ~= "" then
		local detail = UiKit.label(column, payload.detail, 13, UiTheme.font.medium, UiTheme.color.inkMuted)
		detail.Size = UDim2.new(1, 0, 0, 36)
		detail.TextWrapped = true
		detail.TextXAlignment = Enum.TextXAlignment.Center
		detail.LayoutOrder = 5
	end

	local primaryLabel = if payload.claimLogin then "Claim reward" else "Continue"
	local primary = UiKit.button(face, primaryLabel, 15, UiTheme.color.ink, UiTheme.color.gold, 8)
	primary.AnchorPoint = Vector2.new(0.5, 1)
	primary.Position = UDim2.new(0.5, 0, 1, -14)
	primary.Size = UDim2.fromOffset(180, 40)
	primary.ZIndex = 7
	UiKit.stroke(primary, Color3.fromRGB(150, 110, 50), 1, 0.35)

	local closing = false
	local function close()
		if closing then
			return
		end
		closing = true
		local out = TweenService:Create(card, FADE, {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.58),
		})
		local dimOut = TweenService:Create(dim, FADE, { BackgroundTransparency = 1 })
		out:Play()
		dimOut:Play()
		task.delay(0.24, function()
			if dim.Parent ~= nil then
				dim:Destroy()
			end
			busy = false
			currentPayload = nil
			local nextPayload = table.remove(queue, 1)
			if nextPayload ~= nil and not held then
				present(nextPayload)
			end
		end)
	end

	primary.MouseButton1Click:Connect(function()
		Sfx.play("good")
		claimIfNeeded(payload)
		close()
	end)
	dim.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if not payload.claimLogin then
				Sfx.play("click")
				close()
			end
		end
	end)

	card.Size = UDim2.fromOffset(300, cardH - 24)
	TweenService:Create(dim, FADE, { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(card, POP, {
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(340, cardH),
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
	TweenService:Create(border, POP, { Transparency = 0.05 }):Play()
	Sfx.play(if payload.kind == "welcome" or payload.kind == "login" then "level" else "good")
end

-- Design / ceremony take the screen. Dismiss open cards (auto-claim daily if needed)
-- and park the rest until every hold is released. Keys let both systems hold without fighting.
function Fanfare.setHold(key: string, blocked: boolean)
	holds[key] = blocked
	local wantHeld = anyHold()
	if wantHeld then
		if busy then
			claimIfNeeded(currentPayload)
			clearActiveCard()
		end
		held = true
		if gui ~= nil then
			gui.Enabled = false
		end
		return
	end
	local wasHeld = held
	held = false
	if gui ~= nil then
		gui.Enabled = true
	end
	if wasHeld and not busy then
		local nextPayload = table.remove(queue, 1)
		if nextPayload ~= nil then
			present(nextPayload)
		end
	end
end

function Fanfare.setHeld(blocked: boolean)
	Fanfare.setHold("legacy", blocked)
end

function Fanfare.show(payload: FanfarePayload)
	if gui == nil then
		return
	end
	if busy or held then
		table.insert(queue, payload)
		return
	end
	present(payload)
end

function Fanfare.start()
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("InkMastersFanfare")
	if existing ~= nil then
		existing:Destroy()
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "InkMastersFanfare"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 80
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
	gui = screen

	-- Offer daily ink after a short beat so the welcome card can land first for new players.
	PlayerData.changed:Connect(function()
		if dailyPrompted then
			return
		end
		task.delay(0.9, function()
			if dailyPrompted then
				return
			end
			local view = PlayerData.get()
			if view == nil or not view.login.canClaim then
				return
			end
			dailyPrompted = true
			local day = view.login.dayInCycle
			Fanfare.show({
				kind = "login",
				title = "Daily ink",
				subtitle = `Day {day} of 7`,
				detail = if view.login.streak > 0
					then `Streak alive — {view.login.streak} {if view.login.streak == 1 then "day" else "days"} so far.`
					else "Claim every day. Miss one and the streak resets.",
				coins = view.login.nextCoins,
				day = day,
				streak = view.login.streak,
				claimLogin = true,
			})
		end)
	end)
end

return Fanfare
