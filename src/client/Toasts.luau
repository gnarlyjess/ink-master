--!strict

-- Small messages along the bottom of the screen: purchases, rewards, level-ups, and errors.
-- Big moments (welcome, daily ink, level-up) go through Fanfare instead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fanfare = require(script.Parent.Fanfare)
local PlayerData = require(script.Parent.PlayerData)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

local MAX_VISIBLE = 4
local LIFETIME_SECONDS = 3.6

local KIND_COLOR: { [string]: Color3 } = {
	ok = UiTheme.color.aqua,
	item = UiTheme.color.violet,
	level = UiTheme.color.gold,
	achievement = UiTheme.color.gold,
	error = UiTheme.color.magenta,
	info = UiTheme.color.muted,
}

local function parentOf(instance: Instance): Instance?
	return instance.Parent
end

local stack: Frame? = nil
local started = false
local order = 0

local Toasts = {}

function Toasts.show(text: string, kind: string)
	local holder = stack
	if holder == nil then
		return
	end

	local live = {}
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(live, child)
		end
	end
	if #live >= MAX_VISIBLE then
		table.sort(live, function(a: Frame, b: Frame)
			return a.LayoutOrder < b.LayoutOrder
		end)
		live[1]:Destroy()
	end

	order += 1
	local accent = KIND_COLOR[kind] or UiTheme.color.muted
	local toast = UiKit.frame(holder, UiTheme.color.panel, 0.04)
	toast.Name = "Toast"
	toast.LayoutOrder = order
	toast.AutomaticSize = Enum.AutomaticSize.XY
	toast.Size = UDim2.fromOffset(0, 0)
	toast.BackgroundTransparency = 1
	UiKit.corner(toast, 12)
	local stroke = UiKit.stroke(toast, accent, 1.5, 0.2)
	stroke.Transparency = 1
	UiKit.padding(toast, 10, 16, 10, 16)

	local pip = UiKit.frame(toast, accent, 0)
	pip.Size = UDim2.fromOffset(6, 6)
	pip.LayoutOrder = 0
	pip.Rotation = 45
	UiKit.list(toast, Enum.FillDirection.Horizontal, 10).VerticalAlignment = Enum.VerticalAlignment.Center

	local label = UiKit.label(toast, text, 16, UiTheme.font.bold, UiTheme.color.text)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.LayoutOrder = 1
	label.TextTransparency = 1

	TweenService:Create(toast, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.04,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.22), { Transparency = 0.2 }):Play()
	TweenService:Create(label, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()

	if kind == "error" then
		Sfx.play("error")
	elseif kind == "level" or kind == "achievement" then
		Sfx.play("level")
	elseif kind == "ok" or kind == "item" then
		Sfx.play("good")
	end

	task.delay(LIFETIME_SECONDS, function()
		if parentOf(toast) == nil then
			return
		end
		local fade = TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		fade:Play()
		label.TextTransparency = 0.4
		task.wait(0.3)
		toast:Destroy()
	end)
end

local function routeNotice(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.text) ~= "string" or typeof(payload.kind) ~= "string" then
		return
	end
	if #payload.text > 140 then
		return
	end

	local kind = payload.kind
	if kind == "welcome" then
		Fanfare.show({
			kind = "welcome",
			title = if typeof(payload.text) == "string" and payload.text ~= ""
				then payload.text
				else "Welcome to Ink-Off, here are some coins to start!",
			coins = if typeof(payload.coins) == "number" then payload.coins else nil,
		})
		return
	end
	if kind == "login" then
		-- Skip if the auto daily prompt already claimed; still show a quick celebration.
		Fanfare.show({
			kind = "login",
			title = if typeof(payload.title) == "string" then payload.title else "Daily ink",
			subtitle = if typeof(payload.day) == "number" then `Day {payload.day}` else nil,
			detail = payload.text,
			coins = if typeof(payload.coins) == "number" then payload.coins else nil,
		})
		return
	end
	if kind == "level" then
		Fanfare.show({
			kind = "level",
			title = "Level up",
			detail = payload.text,
			coins = if typeof(payload.coins) == "number" then payload.coins else nil,
		})
		return
	end
	if kind == "achievement" then
		Fanfare.show({
			kind = "achievement",
			title = "Unlocked",
			detail = payload.text,
		})
		return
	end

	local view = PlayerData.get()
	if kind == "info" and view ~= nil and not view.settings.hints then
		return
	end
	Toasts.show(payload.text, kind)
end

function Toasts.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("InkMastersToasts")
	if existing ~= nil then
		existing:Destroy()
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "InkMastersToasts"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 60
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	local holder = Instance.new("Frame")
	holder.Name = "Stack"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -UiTheme.safe.bottom)
	holder.Size = UDim2.fromOffset(520, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = screen
	local layout = UiKit.list(holder, Enum.FillDirection.Vertical, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	stack = holder

	Remotes.ProfileNotice.OnClientEvent:Connect(routeNotice)
end

return Toasts
