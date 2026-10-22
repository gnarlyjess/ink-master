--!strict

-- Cinematic unlock / welcome / daily-ink cards.
-- Psychology: anticipation → payoff (confetti + count-up) → itch (pulsing CTA).
-- Bright candy accents on a dark parlour stage — same game, louder dopamine.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Juice = require(script.Parent.Juice)
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

local POP = TweenInfo.new(0.52, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Fanfare = {}

local gui: ScreenGui? = nil
local busy = false
local held = false
local holds: { [string]: boolean } = {}
local queue: { FanfarePayload } = {}
local dailyPrompted = false
local currentPayload: FanfarePayload? = nil

local KIND_KICKER: { [FanfareKind]: string } = {
	welcome = "WELCOME BONUS",
	login = "DAILY TREAT",
	level = "LEVEL UP!",
	item = "NEW UNLOCK",
	achievement = "ACHIEVEMENT",
}

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

local function confettiAllowed(): boolean
	local view = PlayerData.get()
	return view == nil or view.settings.confetti
end

local function coinJewel(parent: Instance, amount: number): Frame
	-- Circle on top, +amount under it — nothing overlapping the coin art.
	local holder = Instance.new("Frame")
	holder.Name = "RewardArt"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(148, 178)
	holder.ZIndex = 5
	holder.Parent = parent

	local jewel = Instance.new("Frame")
	jewel.Name = "Jewel"
	jewel.BackgroundTransparency = 1
	jewel.AnchorPoint = Vector2.new(0.5, 0)
	jewel.Position = UDim2.fromScale(0.5, 0)
	jewel.Size = UDim2.fromOffset(120, 120)
	jewel.ZIndex = 5
	jewel.Parent = holder

	local plate = UiKit.frame(jewel, UiTheme.color.panelTop, 0)
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromOffset(100, 100)
	plate.ZIndex = 5
	UiKit.corner(plate, 999)
	local ring = UiKit.stroke(plate, UiTheme.color.gold, 3.5, 0)
	Juice.rainbowStroke(ring, 1.8)

	local inner = UiKit.frame(plate, UiTheme.color.sunshine, 0)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromOffset(78, 78)
	inner.ZIndex = 6
	UiKit.corner(inner, 999)
	UiKit.stroke(inner, UiTheme.color.hotPink, 2, 0.15)

	local stack = Instance.new("Frame")
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(0.5, 0.5)
	stack.Position = UDim2.fromScale(0.5, 0.5)
	stack.Size = UDim2.fromOffset(48, 34)
	stack.ZIndex = 7
	stack.Parent = inner

	for i = 1, 3 do
		local coin = UiKit.frame(stack, UiTheme.color.gold, 0)
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Position = UDim2.fromScale(0.5, 0.22 + (i - 1) * 0.28)
		coin.Size = UDim2.fromOffset(44 - (i - 1) * 2, 11)
		coin.ZIndex = 7
		UiKit.corner(coin, 999)
		UiKit.stroke(coin, Color3.fromRGB(200, 120, 30), 1, 0.2)
	end

	local amountLabel = UiKit.label(holder, "+0", 24, UiTheme.font.heavy, UiTheme.color.sunshine)
	amountLabel.AnchorPoint = Vector2.new(0.5, 0)
	amountLabel.Position = UDim2.new(0.5, 0, 0, 128)
	amountLabel.Size = UDim2.new(1, 0, 0, 28)
	amountLabel.TextXAlignment = Enum.TextXAlignment.Center
	amountLabel.TextYAlignment = Enum.TextYAlignment.Center
	amountLabel.ZIndex = 8
	amountLabel.TextStrokeTransparency = 1
	Juice.countUp(amountLabel, amount, "+", "", 0.75)
	Juice.punch(plate, 1.12)

	return holder
end

local function starBadge(parent: Instance): Frame
	local badge = UiKit.frame(parent, UiTheme.color.violet, 0)
	badge.Size = UDim2.fromOffset(108, 108)
	UiKit.corner(badge, 999)
	local ring = UiKit.stroke(badge, UiTheme.color.hotPink, 3, 0)
	Juice.glowStroke(ring, UiTheme.color.hotPink, UiTheme.color.electric)
	local glyph = UiKit.label(badge, "✦", 48, UiTheme.font.heavy, UiTheme.color.sunshine)
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	glyph.TextYAlignment = Enum.TextYAlignment.Center
	glyph.TextStrokeTransparency = 0.5
	glyph.TextStrokeColor3 = UiTheme.color.ink
	Juice.pulse(badge, 0.96, 1.08)
	return badge
end

local function present(payload: FanfarePayload)
	local root = gui
	if root == nil then
		return
	end
	busy = true
	currentPayload = payload

	local dim = UiKit.frame(root, Color3.fromRGB(12, 4, 24), 1)
	dim.Name = "FanfareDim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 1
	dim.Active = true

	local cardW = 340
	local cardH = 420
	-- Soft centred shadow — same anchor as the card, no sideways smear.
	local shadow = Juice.shadow(dim, UDim2.fromOffset(cardW + 16, cardH + 16), UDim2.fromScale(0.5, 0.5), 24)
	shadow.BackgroundTransparency = 1

	local card = UiKit.frame(dim, UiTheme.color.ink, 1)
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.54)
	card.Size = UDim2.fromOffset(cardW, cardH)
	card.ZIndex = 2
	card.Active = true
	card.ClipsDescendants = true
	UiKit.corner(card, 22)
	local border = UiKit.stroke(card, UiTheme.color.gold, 3, 0.15)
	Juice.rainbowStroke(border, 1.4)

	local face = UiKit.frame(card, UiTheme.color.panel, 0)
	face.Position = UDim2.fromOffset(12, 12)
	face.Size = UDim2.new(1, -24, 1, -24)
	face.ZIndex = 3
	face.ClipsDescendants = true
	UiKit.corner(face, 16)
	UiKit.stroke(face, UiTheme.color.violet, 1.5, 0.35)

	-- Soft top glow inside the face
	local glow = UiKit.frame(face, UiTheme.color.magenta, 0.85)
	glow.Size = UDim2.new(1, 0, 0, 72)
	glow.ZIndex = 3
	UiKit.corner(glow, 16)

	Juice.sparkles(face, {
		{ 0.1, 0.12 },
		{ 0.9, 0.14 },
		{ 0.12, 0.88 },
		{ 0.88, 0.86 },
	})

	-- One centred column so text, jewel, and CTA share the same axis.
	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.Position = UDim2.fromScale(0.5, 0.5)
	column.Size = UDim2.new(1, -28, 1, -24)
	column.ZIndex = 5
	column.Parent = face
	local list = UiKit.list(column, Enum.FillDirection.Vertical, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)

	local kickerText = KIND_KICKER[payload.kind] or "INK-OFF"
	local kicker = UiKit.label(column, kickerText, 12, UiTheme.font.heavy, UiTheme.color.sunshine)
	kicker.Size = UDim2.new(1, 0, 0, 16)
	kicker.TextXAlignment = Enum.TextXAlignment.Center
	kicker.TextYAlignment = Enum.TextYAlignment.Center
	kicker.TextStrokeTransparency = 1
	kicker.LayoutOrder = 1

	local titleSize = if #payload.title > 28 then 20 else 28
	local titleHeight = if #payload.title > 28 then 44 else 32
	local title = UiKit.label(column, payload.title, titleSize, UiTheme.font.heavy, UiTheme.color.text)
	title.Size = UDim2.new(1, 0, 0, titleHeight)
	title.TextWrapped = true
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextStrokeTransparency = 1
	title.LayoutOrder = 2

	if payload.subtitle ~= nil and payload.subtitle ~= "" then
		local sub = UiKit.label(column, payload.subtitle, 15, UiTheme.font.bold, UiTheme.color.electric)
		sub.Size = UDim2.new(1, 0, 0, 20)
		sub.TextXAlignment = Enum.TextXAlignment.Center
		sub.TextYAlignment = Enum.TextYAlignment.Center
		sub.LayoutOrder = 3
	end

	local coins = payload.coins or 0
	if coins > 0 then
		local art = coinJewel(column, coins)
		art.LayoutOrder = 4
	else
		local badge = starBadge(column)
		badge.LayoutOrder = 4
	end

	if payload.streak ~= nil and payload.streak > 0 then
		local streak =
			UiKit.label(column, `🔥 {payload.streak}-day streak!`, 14, UiTheme.font.heavy, UiTheme.color.coral)
		streak.Size = UDim2.new(1, 0, 0, 20)
		streak.TextXAlignment = Enum.TextXAlignment.Center
		streak.TextYAlignment = Enum.TextYAlignment.Center
		streak.LayoutOrder = 5
		Juice.pulse(streak, 0.98, 1.05)
	end

	if payload.detail ~= nil and payload.detail ~= "" then
		local detail = UiKit.label(column, payload.detail, 13, UiTheme.font.medium, UiTheme.color.muted)
		detail.Size = UDim2.new(1, -8, 0, 40)
		detail.TextWrapped = true
		detail.TextXAlignment = Enum.TextXAlignment.Center
		detail.TextYAlignment = Enum.TextYAlignment.Top
		detail.LayoutOrder = 6
	end

	local primaryLabel = if payload.claimLogin then "CLAIM NOW!" else "AWESOME!"
	local primary = UiKit.button(column, primaryLabel, 16, UiTheme.color.ink, UiTheme.color.gold, 12)
	primary.LayoutOrder = 7
	primary.Size = UDim2.fromOffset(200, 46)
	primary.ZIndex = 10
	primary.TextXAlignment = Enum.TextXAlignment.Center
	primary.TextYAlignment = Enum.TextYAlignment.Center
	primary.TextStrokeTransparency = 1
	local btnStroke = UiKit.stroke(primary, UiTheme.color.hotPink, 2.5, 0)
	Juice.glowStroke(btnStroke, UiTheme.color.hotPink, UiTheme.color.sunshine)
	Juice.shimmer(primary)
	Juice.pulse(primary, 1, 1.05)

	local closing = false
	local function close()
		if closing then
			return
		end
		closing = true
		if confettiAllowed() then
			Juice.confetti(dim, Vector2.new(0.5, 0.45), 36, 1.1)
		end
		local scale = card:FindFirstChildOfClass("UIScale")
		if scale ~= nil then
			TweenService:Create(scale, FADE, { Scale = 0.85 }):Play()
		end
		local out = TweenService:Create(card, FADE, {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.56),
		})
		local dimOut = TweenService:Create(dim, FADE, { BackgroundTransparency = 1 })
		out:Play()
		dimOut:Play()
		task.delay(0.28, function()
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
		Juice.punch(primary, 1.2)
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

	-- Entrance: dim → centred card pop → confetti
	card.Size = UDim2.fromOffset(cardW - 24, cardH - 24)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.55
	scale.Parent = card
	TweenService:Create(dim, FADE, { BackgroundTransparency = 0.4 }):Play()
	TweenService:Create(card, POP, {
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(cardW, cardH),
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
	TweenService:Create(scale, POP, { Scale = 1 }):Play()
	TweenService:Create(shadow, POP, { BackgroundTransparency = 0.62 }):Play()
	TweenService:Create(border, POP, { Transparency = 0 }):Play()

	task.delay(0.12, function()
		if confettiAllowed() and dim.Parent ~= nil then
			Juice.confetti(dim, Vector2.new(0.5, 0.42), 32, 1.2)
		end
	end)

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
				title = "Daily ink!",
				subtitle = `Day {day} of 7`,
				detail = if view.login.streak > 0
					then `Keep the streak alive — claim every day!`
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
