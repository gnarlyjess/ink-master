--!strict

-- The parlour menu: shop, daily rewards, and your profile.
-- It only displays the server's profile and forwards button presses.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PlayerData = require(script.Parent.PlayerData)
local ProfileTab = require(script.Parent.ProfileTab)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardsTab = require(script.Parent.RewardsTab)
local RoundTypes = require(ReplicatedStorage.Shared.RoundTypes)
local Sfx = require(script.Parent.Sfx)
local ShopTab = require(script.Parent.ShopTab)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

local TABS = { "Shop", "Rewards", "You" }

local StudioMenu = {}

function StudioMenu.start()
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("InkMastersStudio")
	if existing ~= nil then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "InkMastersStudio"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 42
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local bar = UiKit.frame(gui, UiTheme.color.ink, 0)
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, UiTheme.safe.side, 1, -UiTheme.safe.side)
	bar.AutomaticSize = Enum.AutomaticSize.X
	bar.Size = UDim2.fromOffset(0, 52)
	UiKit.corner(bar, 12)
	UiKit.stroke(bar, UiTheme.color.gold, 1.5, 0.05)
	UiKit.padding(bar, 8, 12, 8, 12)
	local barRow = UiKit.list(bar, Enum.FillDirection.Horizontal, 10)
	barRow.VerticalAlignment = Enum.VerticalAlignment.Center

	local openButton = UiKit.button(bar, "Shop", 14, UiTheme.color.ink, UiTheme.color.gold, 8)
	openButton.LayoutOrder = 1
	openButton.Size = UDim2.fromOffset(88, 34)
	UiKit.stroke(openButton, Color3.fromRGB(150, 110, 50), 1, 0.35)

	local coinPip = UiKit.frame(bar, UiTheme.color.gold, 0)
	coinPip.LayoutOrder = 2
	coinPip.Size = UDim2.fromOffset(8, 8)
	coinPip.Rotation = 45

	local coinText = UiKit.label(bar, "…", 15, UiTheme.font.heavy, UiTheme.color.gold)
	coinText.LayoutOrder = 3
	coinText.AutomaticSize = Enum.AutomaticSize.X
	coinText.Size = UDim2.fromOffset(0, 34)

	local levelText = UiKit.label(bar, "Lv 1", 15, UiTheme.font.heavy, UiTheme.color.paper)
	levelText.LayoutOrder = 4
	levelText.AutomaticSize = Enum.AutomaticSize.X
	levelText.Size = UDim2.fromOffset(0, 34)

	local dim = UiKit.frame(gui, Color3.new(0, 0, 0), 0.45)
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.Visible = false
	dim.Active = true

	local panel = UiKit.frame(dim, UiTheme.color.ink, 0)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, -8)
	panel.Size = UDim2.new(0.9, 0, 1, -88)
	UiKit.corner(panel, 14)
	UiKit.stroke(panel, UiTheme.color.gold, 2, 0.08)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(1180, 820)
	limit.Parent = panel

	-- Flash-sheet crop marks in the corners.
	local function crop(x: number, y: number, ox: number, oy: number)
		local mark = Instance.new("Frame")
		mark.BackgroundTransparency = 1
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.new(x, ox, y, oy)
		mark.Size = UDim2.fromOffset(16, 16)
		mark.Parent = panel
		local h = UiKit.frame(mark, UiTheme.color.gold, 0.15)
		h.Size = UDim2.fromOffset(16, 2)
		h.Position = UDim2.fromOffset(0, if oy < 0 then 14 else 0)
		local v = UiKit.frame(mark, UiTheme.color.gold, 0.15)
		v.Size = UDim2.fromOffset(2, 16)
		v.Position = UDim2.fromOffset(if ox < 0 then 14 else 0, 0)
	end
	crop(0, 0, 18, 18)
	crop(1, 0, -18, 18)
	crop(0, 1, 18, -18)
	crop(1, 1, -18, -18)

	local kicker = UiKit.label(panel, "INK-OFF", 11, UiTheme.font.bold, UiTheme.color.gold)
	kicker.Position = UDim2.fromOffset(28, 12)
	kicker.Size = UDim2.fromOffset(220, 14)

	local title = UiKit.label(panel, "Shop", 24, UiTheme.font.heavy, UiTheme.color.paper)
	title.Position = UDim2.fromOffset(28, 24)
	title.Size = UDim2.fromOffset(220, 28)

	local close = UiKit.button(panel, "Close", 14, UiTheme.color.paper, UiTheme.color.chip, 8)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -20, 0, 16)
	close.Size = UDim2.fromOffset(88, 32)
	UiKit.stroke(close, UiTheme.color.stroke, 1, 0.35)

	local rule = UiKit.frame(panel, UiTheme.color.gold, 0.2)
	rule.Position = UDim2.fromOffset(28, 56)
	rule.Size = UDim2.new(1, -56, 0, 1)

	local tabRow = Instance.new("Frame")
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromOffset(22, 58)
	tabRow.Size = UDim2.new(1, -44, 0, 28)
	tabRow.Parent = panel
	local tabLayout = UiKit.list(tabRow, Enum.FillDirection.Horizontal, 18)
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(18, 90)
	body.Size = UDim2.new(1, -36, 1, -106)
	body.Parent = panel

	local pages: { [string]: Frame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local tabMarks: { [string]: Frame } = {}
	local selected = "Shop"

	local function page(name: string): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 1)
		frame.Visible = false
		frame.Parent = body
		return frame
	end

	local shopPage = page("Shop")
	local rewardsPage = page("Rewards")
	local profilePage = page("You")
	pages.Shop = shopPage
	pages.Rewards = rewardsPage
	pages.You = profilePage

	local shop = ShopTab.build(shopPage)
	local rewards = RewardsTab.build(rewardsPage)
	local profile = ProfileTab.build(profilePage)

	local loading = UiKit.label(body, "Loading the shop…", 18, UiTheme.font.bold, UiTheme.color.muted)
	loading.Size = UDim2.fromScale(1, 1)
	loading.TextXAlignment = Enum.TextXAlignment.Center

	local function show(name: string)
		selected = name
		local view = PlayerData.get()
		loading.Visible = view == nil
		for id, frame in pages do
			frame.Visible = view ~= nil and id == name
		end
		for id, button in tabButtons do
			local on = id == name
			button.BackgroundTransparency = 1
			button.TextColor3 = if on then UiTheme.color.gold else UiTheme.color.muted
			button.FontFace = if on then UiTheme.font.heavy else UiTheme.font.medium
			local mark = tabMarks[id]
			if mark ~= nil then
				mark.Visible = on
			end
		end
	end

	for index, name in TABS do
		local button = UiKit.button(tabRow, name, 16, UiTheme.color.muted, UiTheme.color.ink, 0)
		button.BackgroundTransparency = 1
		button.AutoButtonColor = false
		button.LayoutOrder = index
		button.AutomaticSize = Enum.AutomaticSize.X
		button.Size = UDim2.fromOffset(0, 28)
		local mark = UiKit.frame(button, UiTheme.color.gold, 0)
		mark.AnchorPoint = Vector2.new(0, 1)
		mark.Position = UDim2.fromScale(0, 1)
		mark.Size = UDim2.new(1, 0, 0, 2)
		mark.Visible = false
		tabButtons[name] = button
		tabMarks[name] = mark
		button.MouseButton1Click:Connect(function()
			Sfx.play("click")
			show(name)
		end)
	end

	local function refresh()
		local view = PlayerData.get()
		if view == nil then
			coinText.Text = "…"
			levelText.Text = "Lv —"
			show(selected)
			return
		end
		coinText.Text = UiKit.number(view.coins)
		levelText.Text = `Lv {view.level}`
		shop.render(view)
		rewards.render(view)
		profile.render(view)
		show(selected)
	end

	local function setOpen(open: boolean)
		dim.Visible = open
		if open then
			dim.BackgroundTransparency = 1
			panel.Position = UDim2.new(0.5, 0, 0.58, -8)
			panel.Size = UDim2.new(0.84, 0, 0.9, -88)
			TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
			TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, 0, 0.5, -8),
				Size = UDim2.new(0.9, 0, 1, -88),
			}):Play()
			refresh()
		end
	end

	openButton.MouseButton1Click:Connect(function()
		Sfx.play("click")
		setOpen(not dim.Visible)
	end)
	close.MouseButton1Click:Connect(function()
		Sfx.play("click")
		setOpen(false)
	end)

	PlayerData.changed:Connect(refresh)
	show("Shop")
	refresh()

	Remotes.RoundStateUpdated.OnClientEvent:Connect(function(payload: any)
		local snapshot = RoundTypes.readSnapshot(payload)
		if snapshot == nil then
			return
		end
		local ceremony = snapshot.state == "Submission"
			or snapshot.state == "Showcase"
			or snapshot.state == "Voting"
			or snapshot.state == "Results"
		bar.Visible = not ceremony
		if ceremony then
			setOpen(false)
		end
	end)
end

return StudioMenu
