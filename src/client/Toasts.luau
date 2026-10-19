--!strict

-- Small messages along the bottom of the screen: purchases, rewards, level-ups, and errors.
-- The server sends the real ones. Local code uses Toasts.show for hints like "that ink is locked".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
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

	-- Drop the oldest when the stack is full.
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
	UiKit.corner(toast, 12)
	UiKit.stroke(toast, accent, 1.5, 0.2)
	UiKit.padding(toast, 10, 16, 10, 16)

	local label = UiKit.label(toast, text, 16, UiTheme.font.bold, UiTheme.color.text)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)

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

	local gui = Instance.new("ScreenGui")
	gui.Name = "InkMastersToasts"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local holder = Instance.new("Frame")
	holder.Name = "Stack"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -UiTheme.safe.bottom)
	holder.Size = UDim2.fromOffset(520, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local layout = UiKit.list(holder, Enum.FillDirection.Vertical, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	stack = holder

	Remotes.ProfileNotice.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.text) ~= "string" or typeof(payload.kind) ~= "string" then
			return
		end
		if #payload.text > 140 then
			return
		end
		local view = PlayerData.get()
		if payload.kind == "info" and view ~= nil and not view.settings.hints then
			return
		end
		Toasts.show(payload.text, payload.kind)
	end)
end

return Toasts
