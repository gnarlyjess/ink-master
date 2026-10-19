--!strict

-- Time's up, then each tattoo in the display case, then the vote, then the party.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BodyRegions = require(ReplicatedStorage.Shared.BodyRegions)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local CeremonyTypes = require(ReplicatedStorage.Shared.CeremonyTypes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local FrameDress = require(script.Parent.FrameDress)
local PlayerData = require(script.Parent.PlayerData)
local TattooCanvas = require(script.Parent.TattooCanvas)
local UiTheme = require(script.Parent.UiTheme)

type CeremonySnapshot = CeremonyTypes.CeremonySnapshot
type Entry = CeremonyTypes.Entry

local current: CeremonySnapshot? = nil
local previewUserId = 0
local presentedKey = ""
local caseOpen = false

local screen: ScreenGui
local dim: Frame
local timeUp: TextLabel
local stageTitle: TextLabel
local panel: Frame
local kicker: TextLabel
local artistName: TextLabel
local detail: TextLabel
local list: ScrollingFrame
local footer: TextLabel
local confetti: Frame
local panelStroke: UIStroke
local frameDress: Frame
local emoteRoot: Frame
local emoteHolder: Frame
local emoteLabel: TextLabel
local emoteScale: UIScale
local stamp: Frame
local stampScale: UIScale
local stampStroke: UIStroke
local dots: { Frame } = {}
local sparks: { Frame } = {}
local emoteStyle = ""
local emoteStarted = 0
local emoteShownId = ""

local function corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local function placeWord(place: number): string
	if place == 1 then
		return "1st"
	elseif place == 2 then
		return "2nd"
	elseif place == 3 then
		return "3rd"
	end
	return ""
end

local function localUserId(): number
	local player = Players.LocalPlayer
	if player == nil then
		return 0
	end
	return player.UserId
end

local function modelFor(userId: number): Model?
	local owner = Players:GetPlayerByUserId(userId)
	if owner ~= nil and owner.Character ~= nil then
		return owner.Character
	end
	local player = Players.LocalPlayer
	if player ~= nil then
		return player.Character
	end
	return nil
end

local function entryAt(snapshot: CeremonySnapshot, index: number): Entry?
	if index < 1 or index > #snapshot.entries then
		return nil
	end
	return snapshot.entries[index]
end

local function indexOfUser(snapshot: CeremonySnapshot, userId: number): number
	for index, entry in snapshot.entries do
		if entry.userId == userId then
			return index
		end
	end
	return 1
end

local function showcaseIndex(snapshot: CeremonySnapshot): number
	local count = #snapshot.entries
	if count == 0 then
		return 0
	end
	local start = snapshot.showcaseStart
	if start == nil or snapshot.secondsEach <= 0 then
		return 1
	end
	local elapsed = math.max(0, Workspace:GetServerTimeNow() - start)
	local index = math.floor(elapsed / snapshot.secondsEach) + 1
	return math.clamp(index, 1, count)
end

local function featuredIndex(snapshot: CeremonySnapshot): number
	local count = #snapshot.entries
	if count == 0 then
		return 0
	end
	if snapshot.phase == "Showcase" then
		return showcaseIndex(snapshot)
	end
	if snapshot.phase == "Party" then
		local winner = snapshot.places[1]
		if winner ~= nil then
			return indexOfUser(snapshot, winner.userId)
		end
	end
	if snapshot.phase == "Voting" then
		if previewUserId ~= 0 then
			return indexOfUser(snapshot, previewUserId)
		end
		local mine = localUserId()
		for index, entry in snapshot.entries do
			if entry.userId ~= mine then
				return index
			end
		end
	end
	return 1
end

local function clearList()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function showDesign(entry: Entry)
	local key = `{entry.userId}:{entry.design.region}:{#entry.design.elements}`
	if key == presentedKey then
		TattooCanvas.setVisible(true)
		return
	end
	local character = modelFor(entry.userId)
	if character == nil then
		return
	end
	presentedKey = key
	caseOpen = true
	TattooCanvas.show(character, entry.design, nil)
	TattooCanvas.setInteractive(false)
	TattooCanvas.setVisible(true)
end

local function fillShowcase(snapshot: CeremonySnapshot, featured: number)
	for index, entry in snapshot.entries do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = if index == featured then 0.15 else 1
		row.BackgroundColor3 = UiTheme.color.chip
		row.BorderSizePixel = 0
		row.FontFace = UiTheme.font.bold
		row.TextSize = 16
		row.TextColor3 = if index == featured then UiTheme.color.gold else UiTheme.color.text
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = entry.name
		row.Size = UDim2.new(1, 0, 0, 32)
		row.LayoutOrder = index
		row.Parent = list
		corner(row, 8)
	end
end

local function colorAt(palette: { Color3 }, index: number): Color3
	return palette[((index - 1) % #palette) + 1]
end

local function paintConfetti(entry: Entry)
	local view = PlayerData.get()
	if view ~= nil and not view.settings.confetti then
		confetti.Visible = false
		return
	end
	local palette: { Color3 } = { UiTheme.color.gold, UiTheme.color.magenta }
	if entry.confetti ~= "" then
		local item = Catalogue.get(entry.confetti)
		local colors = if item ~= nil then item.palette else nil
		if colors ~= nil and #colors > 0 then
			table.clear(palette)
			for _, color in colors do
				table.insert(palette, Catalogue.toColor3(color))
			end
		end
	end
	for index, dot in dots do
		dot.BackgroundColor3 = colorAt(palette, index)
	end
end

local function hideFrame()
	frameDress.Visible = false
	FrameDress.clear(frameDress)
	panelStroke.Transparency = 0
	panelStroke.Color = UiTheme.color.stroke
	panelStroke.Thickness = 1.5
end

local function applyFrame(entry: Entry)
	if entry.frame == "" then
		hideFrame()
		return
	end
	local worn = Catalogue.get(entry.frame)
	local accent = if worn ~= nil then worn.accent else nil
	if worn == nil or accent == nil or worn.category ~= "frame" then
		hideFrame()
		return
	end
	panelStroke.Transparency = 1
	frameDress.Visible = true
	FrameDress.mount(frameDress, worn.style or "line", Catalogue.toColor3(accent), 16)
end

local function hideEmote()
	emoteRoot.Visible = false
	emoteShownId = ""
end

local function applyEmote(entry: Entry, phase: string)
	if phase ~= "Party" then
		hideEmote()
		return
	end
	local worn = if entry.emote ~= "" then Catalogue.get(entry.emote) else nil
	local shout = if worn ~= nil then worn.text else nil
	if worn == nil or worn.category ~= "emote" or shout == nil or shout == "" then
		hideEmote()
		return
	end
	local accent = if worn.accent ~= nil then Catalogue.toColor3(worn.accent) else UiTheme.color.gold
	emoteLabel.Text = shout
	emoteLabel.TextColor3 = accent
	stampStroke.Color = accent
	stamp.Visible = worn.style == "stamp"
	for _, spark in sparks do
		spark.BackgroundColor3 = accent
		spark.Visible = worn.style == "burst"
	end
	emoteStyle = worn.style or "pop"
	if emoteShownId ~= worn.id then
		emoteShownId = worn.id
		emoteStarted = os.clock()
	end
	emoteRoot.Visible = true
end

local function stepEmote(now: number)
	local elapsed = now - emoteStarted
	emoteScale.Scale = 1
	emoteLabel.Rotation = 0
	emoteHolder.Position = UDim2.fromScale(0.5, 0.5)
	if emoteStyle == "pop" then
		emoteScale.Scale = 1 + math.sin(elapsed * 5) * 0.06
	elseif emoteStyle == "bounce" then
		emoteHolder.Position = UDim2.new(0.5, 0, 0.5, -math.abs(math.sin(elapsed * 6)) * 16)
	elseif emoteStyle == "shake" then
		emoteLabel.Rotation = math.sin(elapsed * 22) * 7
	elseif emoteStyle == "float" then
		emoteHolder.Position = UDim2.new(0.5, 0, 0.5, math.sin(elapsed * 2.2) * -12)
		emoteScale.Scale = 1 + math.sin(elapsed * 2.2) * 0.04
	elseif emoteStyle == "stamp" then
		emoteScale.Scale = 1 + math.sin(elapsed * 4) * 0.04
		local cycle = elapsed % 1.2
		stampScale.Scale = 1 + cycle * 0.28
		stampStroke.Transparency = cycle / 1.2
	elseif emoteStyle == "burst" then
		emoteScale.Scale = 1 + math.sin(elapsed * 7) * 0.05
		local cycle = elapsed % 1.1
		local dist = 18 + cycle * 64
		for index, spark in sparks do
			local angle = (index - 1) / #sparks * math.pi * 2
			spark.Position = UDim2.new(0.5, math.cos(angle) * dist, 0.5, math.sin(angle) * dist * 0.62)
			spark.Rotation = cycle * 160
			spark.BackgroundTransparency = cycle / 1.1
		end
	end
end

local present: (CeremonySnapshot) -> ()

local function fillVoting(snapshot: CeremonySnapshot)
	local mine = localUserId()
	for index, entry in snapshot.entries do
		local mineRow = entry.userId == mine
		local chosen = if previewUserId ~= 0 then previewUserId == entry.userId else snapshot.yourVote == entry.userId
		local row = Instance.new("TextButton")
		row.AutoButtonColor = not mineRow
		row.BackgroundColor3 = UiTheme.color.chip
		row.BackgroundTransparency = if chosen then 0 else 0.15
		row.BorderSizePixel = 0
		row.FontFace = UiTheme.font.bold
		row.TextSize = 18
		row.TextColor3 = if chosen then UiTheme.color.gold else UiTheme.color.text
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = if mineRow
			then `{entry.name}  ·  You`
			elseif chosen then `{entry.name}  ·  Your vote`
			else `{entry.name}  ·  Vote`
		row.Size = UDim2.new(1, 0, 0, 48)
		row.LayoutOrder = index
		row.Parent = list
		corner(row, 8)
		local userId = entry.userId
		row.MouseButton1Click:Connect(function()
			previewUserId = userId
			if not mineRow and current ~= nil and current.phase == "Voting" then
				Remotes.CastVote:FireServer(userId)
			end
			local latest = current
			if latest ~= nil then
				present(latest)
			end
		end)
	end
end

local function fillParty(snapshot: CeremonySnapshot)
	if #snapshot.places == 0 then
		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.FontFace = UiTheme.font.medium
		empty.TextSize = 16
		empty.TextColor3 = UiTheme.color.muted
		empty.TextWrapped = true
		empty.Text = "No tattoos were locked in."
		empty.Size = UDim2.new(1, 0, 0, 48)
		empty.Parent = list
		return
	end
	for _, place in snapshot.places do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 0.15
		row.BackgroundColor3 = UiTheme.color.chip
		row.BorderSizePixel = 0
		row.FontFace = UiTheme.font.bold
		row.TextSize = 16
		row.TextColor3 = if place.place == 1 then UiTheme.color.gold else UiTheme.color.text
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextWrapped = true
		local voteWord = if place.votes == 1 then "vote" else "votes"
		row.Text = `{placeWord(place.place)}  {place.name}   +{place.awarded}   {place.votes} {voteWord}`
		row.Size = UDim2.new(1, 0, 0, 40)
		row.LayoutOrder = place.place
		row.Parent = list
		corner(row, 8)
	end
end

present = function(snapshot: CeremonySnapshot)
	local showingCase = snapshot.phase == "Showcase" or snapshot.phase == "Voting" or snapshot.phase == "Party"
	screen.Enabled = snapshot.phase ~= "Idle"
	dim.Visible = snapshot.phase == "TimeUp"
	timeUp.Visible = snapshot.phase == "TimeUp"
	stageTitle.Visible = showingCase
	panel.Visible = showingCase
	confetti.Visible = snapshot.phase == "Party"
	if snapshot.phase == "Idle" then
		hideFrame()
		hideEmote()
		if caseOpen then
			TattooCanvas.setInteractive(false)
			TattooCanvas.clear()
			caseOpen = false
			presentedKey = ""
		end
		return
	end
	if snapshot.phase == "TimeUp" then
		hideFrame()
		hideEmote()
		TattooCanvas.setVisible(false)
		return
	end
	if not showingCase then
		return
	end

	local count = #snapshot.entries
	local index = featuredIndex(snapshot)
	local entry = entryAt(snapshot, index)
	if snapshot.phase == "Showcase" then
		kicker.Text = "DISPLAY CASE"
		stageTitle.Text = "Display case"
	elseif snapshot.phase == "Voting" then
		kicker.Text = "VOTE FOR THE BEST"
		stageTitle.Text = "Vote"
	else
		kicker.Text = "PARTY"
		stageTitle.Text = "Party"
	end

	if entry == nil then
		artistName.Text = "No tattoos"
		detail.Text = "The case is empty."
		footer.Text = `You have {snapshot.yourTotal} coins.`
		hideFrame()
		hideEmote()
		clearList()
		return
	end

	local region = BodyRegions.get(entry.design.region)
	local limb = if region ~= nil then region.label else "Tattoo"
	local marks = #entry.design.elements
	local markWord = if marks == 1 then "mark" else "marks"
	local wornTitle = if entry.title ~= "" then Catalogue.get(entry.title) else nil
	local titleText = if wornTitle ~= nil and wornTitle.text ~= nil then wornTitle.text else ""
	artistName.Text = if titleText ~= "" then `{entry.name}  ·  {titleText}` else entry.name
	applyFrame(entry)
	applyEmote(entry, snapshot.phase)
	paintConfetti(entry)
	if snapshot.phase == "Showcase" then
		detail.Text = `{index} of {count}  ·  {limb}  ·  {marks} {markWord}`
		footer.Text = "Voting opens when the case finishes."
	elseif snapshot.phase == "Voting" then
		detail.Text = `{limb}  ·  {marks} {markWord}`
		if count < 2 then
			footer.Text = "You're the only artist, so the party is yours."
		elseif snapshot.yourVote == 0 then
			footer.Text = "Tap another artist to give them your vote."
		else
			footer.Text = "Vote saved. You can change it until the party."
		end
	else
		detail.Text = `Winning tattoo  ·  {limb}`
		local mineAward = 0
		local minePlace = 0
		for _, place in snapshot.places do
			if place.userId == localUserId() then
				mineAward = place.awarded
				minePlace = place.place
			end
		end
		if minePlace > 0 then
			footer.Text = `+{mineAward} coins for {placeWord(minePlace)}. You have {snapshot.yourTotal} coins.`
		else
			footer.Text = `You have {snapshot.yourTotal} coins.`
		end
	end

	showDesign(entry)
	clearList()
	if snapshot.phase == "Showcase" then
		fillShowcase(snapshot, index)
	elseif snapshot.phase == "Voting" then
		fillVoting(snapshot)
	else
		fillParty(snapshot)
	end
end

local function stepConfetti(now: number)
	for index, dot in dots do
		local travel = (now * (18 + (index % 5) * 7) + index * 37) % 120
		dot.Position = UDim2.new((index * 0.063) % 1, 0, 0, -20 + travel * 8)
	end
end

local function build()
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("InkMastersCeremony")
	if existing ~= nil then
		existing:Destroy()
	end

	screen = Instance.new("ScreenGui")
	screen.Name = "InkMastersCeremony"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 36
	screen.Enabled = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Active = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Visible = false
	dim.Parent = screen

	timeUp = Instance.new("TextLabel")
	timeUp.Name = "TimeUp"
	timeUp.AnchorPoint = Vector2.new(0.5, 0.5)
	timeUp.Position = UDim2.fromScale(0.5, 0.46)
	timeUp.Size = UDim2.fromOffset(720, 140)
	timeUp.BackgroundTransparency = 1
	timeUp.FontFace = UiTheme.font.heavy
	timeUp.TextSize = 76
	timeUp.TextColor3 = UiTheme.color.gold
	timeUp.Text = "Time's up!"
	timeUp.Visible = false
	timeUp.ZIndex = 4
	timeUp.Parent = screen

	stageTitle = Instance.new("TextLabel")
	stageTitle.Name = "Stage"
	stageTitle.AnchorPoint = Vector2.new(0.5, 0)
	stageTitle.Position = UDim2.new(0.5, -(UiTheme.safe.dock + UiTheme.safe.side) / 2, 0, UiTheme.safe.top)
	stageTitle.Size = UDim2.fromOffset(240, 44)
	stageTitle.BackgroundColor3 = UiTheme.color.ink
	stageTitle.BackgroundTransparency = 0.2
	stageTitle.FontFace = UiTheme.font.heavy
	stageTitle.TextSize = 22
	stageTitle.TextColor3 = UiTheme.color.gold
	stageTitle.Text = "Display case"
	stageTitle.Visible = false
	stageTitle.ZIndex = 6
	stageTitle.Parent = screen
	corner(stageTitle, 12)

	panel = Instance.new("Frame")
	panel.Name = "Case"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -UiTheme.safe.side, 0, UiTheme.safe.top)
	panel.Size = UDim2.new(0, UiTheme.safe.dock, 1, -(UiTheme.safe.top + UiTheme.safe.bottom))
	panel.BackgroundColor3 = UiTheme.color.panel
	panel.BackgroundTransparency = 0.06
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 5
	panel.Parent = screen
	corner(panel, 16)
	panelStroke = Instance.new("UIStroke")
	panelStroke.Color = UiTheme.color.stroke
	panelStroke.Thickness = 1.5
	panelStroke.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalFlex = Enum.UIFlexAlignment.Fill
	layout.Parent = panel

	kicker = Instance.new("TextLabel")
	kicker.BackgroundTransparency = 1
	kicker.FontFace = UiTheme.font.bold
	kicker.TextSize = 12
	kicker.TextColor3 = UiTheme.color.magenta
	kicker.TextXAlignment = Enum.TextXAlignment.Left
	kicker.Text = "DISPLAY CASE"
	kicker.Size = UDim2.new(1, 0, 0, 16)
	kicker.LayoutOrder = 1
	kicker.Parent = panel

	artistName = Instance.new("TextLabel")
	artistName.BackgroundTransparency = 1
	artistName.FontFace = UiTheme.font.heavy
	artistName.TextSize = 28
	artistName.TextColor3 = UiTheme.color.text
	artistName.TextXAlignment = Enum.TextXAlignment.Left
	artistName.TextWrapped = true
	artistName.Text = ""
	artistName.Size = UDim2.new(1, 0, 0, 64)
	artistName.LayoutOrder = 2
	artistName.Parent = panel

	detail = Instance.new("TextLabel")
	detail.BackgroundTransparency = 1
	detail.FontFace = UiTheme.font.medium
	detail.TextSize = 14
	detail.TextColor3 = UiTheme.color.muted
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextWrapped = true
	detail.Text = ""
	detail.Size = UDim2.new(1, 0, 0, 36)
	detail.LayoutOrder = 3
	detail.Parent = panel

	list = Instance.new("ScrollingFrame")
	list.Name = "Roster"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.Size = UDim2.fromScale(1, 0)
	list.LayoutOrder = 4
	list.Parent = panel
	local listFlex = Instance.new("UIFlexItem")
	listFlex.FlexMode = Enum.UIFlexMode.Fill
	listFlex.Parent = list
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	footer = Instance.new("TextLabel")
	footer.BackgroundTransparency = 1
	footer.FontFace = UiTheme.font.medium
	footer.TextSize = 14
	footer.TextColor3 = UiTheme.color.text
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.TextWrapped = true
	footer.Text = ""
	footer.Size = UDim2.new(1, 0, 0, 48)
	footer.LayoutOrder = 5
	footer.Parent = panel

	confetti = Instance.new("Frame")
	confetti.Name = "Confetti"
	confetti.Active = false
	confetti.Size = UDim2.fromScale(1, 1)
	confetti.BackgroundTransparency = 1
	confetti.BorderSizePixel = 0
	confetti.Visible = false
	confetti.ZIndex = 2
	confetti.Parent = screen
	for index = 1, 16 do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Size = UDim2.fromOffset(8, 14)
		dot.BackgroundColor3 = if index % 2 == 0 then UiTheme.color.gold else UiTheme.color.magenta
		dot.BorderSizePixel = 0
		dot.Rotation = index * 18
		dot.ZIndex = 2
		dot.Parent = confetti
		corner(dot, 2)
		table.insert(dots, dot)
	end

	frameDress = Instance.new("Frame")
	frameDress.Name = "FrameDress"
	frameDress.Active = false
	frameDress.Interactable = false
	frameDress.AnchorPoint = Vector2.new(1, 0)
	frameDress.Position = panel.Position
	frameDress.Size = panel.Size
	frameDress.BackgroundTransparency = 1
	frameDress.BorderSizePixel = 0
	frameDress.Visible = false
	frameDress.ZIndex = 6
	frameDress.Parent = screen

	emoteRoot = Instance.new("Frame")
	emoteRoot.Name = "WinEmote"
	emoteRoot.Active = false
	emoteRoot.Interactable = false
	emoteRoot.AnchorPoint = Vector2.new(0.5, 0)
	emoteRoot.Position = UDim2.new(0.5, -math.floor(UiTheme.safe.dock / 2), 0, UiTheme.safe.top + 58)
	emoteRoot.Size = UDim2.fromOffset(460, 110)
	emoteRoot.BackgroundTransparency = 1
	emoteRoot.BorderSizePixel = 0
	emoteRoot.Visible = false
	emoteRoot.ZIndex = 7
	emoteRoot.Parent = screen

	stamp = Instance.new("Frame")
	stamp.Name = "Stamp"
	stamp.Active = false
	stamp.Interactable = false
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Position = UDim2.fromScale(0.5, 0.55)
	stamp.Size = UDim2.fromOffset(280, 64)
	stamp.BackgroundTransparency = 1
	stamp.Visible = false
	stamp.ZIndex = 7
	stamp.Parent = emoteRoot
	corner(stamp, 32)
	stampStroke = Instance.new("UIStroke")
	stampStroke.Color = UiTheme.color.gold
	stampStroke.Thickness = 3
	stampStroke.Parent = stamp
	stampScale = Instance.new("UIScale")
	stampScale.Parent = stamp

	table.clear(sparks)
	for _ = 1, 8 do
		local spark = Instance.new("Frame")
		spark.Active = false
		spark.Interactable = false
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Size = UDim2.fromOffset(8, 8)
		spark.BackgroundColor3 = UiTheme.color.gold
		spark.BorderSizePixel = 0
		spark.Visible = false
		spark.ZIndex = 7
		spark.Rotation = 45
		spark.Parent = emoteRoot
		corner(spark, 2)
		table.insert(sparks, spark)
	end

	emoteHolder = Instance.new("Frame")
	emoteHolder.Active = false
	emoteHolder.Interactable = false
	emoteHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	emoteHolder.Position = UDim2.fromScale(0.5, 0.5)
	emoteHolder.Size = UDim2.new(1, -16, 1, 0)
	emoteHolder.BackgroundTransparency = 1
	emoteHolder.ZIndex = 8
	emoteHolder.Parent = emoteRoot
	emoteScale = Instance.new("UIScale")
	emoteScale.Parent = emoteHolder

	emoteLabel = Instance.new("TextLabel")
	emoteLabel.BackgroundTransparency = 1
	emoteLabel.Size = UDim2.fromScale(1, 1)
	emoteLabel.FontFace = UiTheme.font.heavy
	emoteLabel.TextScaled = true
	emoteLabel.TextColor3 = UiTheme.color.gold
	emoteLabel.Text = ""
	emoteLabel.ZIndex = 8
	emoteLabel.Parent = emoteHolder
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 64
	cap.MinTextSize = 22
	cap.Parent = emoteLabel
	local inked = Instance.new("UIStroke")
	inked.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	inked.Color = UiTheme.color.ink
	inked.Thickness = 2
	inked.Parent = emoteLabel
end

local Ceremony = {}

function Ceremony.start()
	build()
	Remotes.CeremonyUpdated.OnClientEvent:Connect(function(payload: any)
		local snapshot = CeremonyTypes.read(payload)
		if snapshot == nil then
			return
		end
		local previous = current
		if previous ~= nil and snapshot.revision < previous.revision and snapshot.roundId == previous.roundId then
			return
		end
		if snapshot.phase == "Voting" then
			if previous == nil or previous.phase ~= "Voting" or previous.roundId ~= snapshot.roundId then
				previewUserId = 0
			end
			if previewUserId == 0 and snapshot.yourVote ~= 0 then
				previewUserId = snapshot.yourVote
			end
		else
			previewUserId = 0
		end
		if previous == nil or previous.phase ~= snapshot.phase or previous.roundId ~= snapshot.roundId then
			presentedKey = ""
		end
		current = snapshot
		present(snapshot)
	end)

	RunService.Heartbeat:Connect(function()
		local snapshot = current
		if snapshot == nil then
			return
		end
		if snapshot.phase == "Showcase" then
			local index = showcaseIndex(snapshot)
			local entry = entryAt(snapshot, index)
			if entry ~= nil then
				local key = `{entry.userId}:{entry.design.region}:{#entry.design.elements}`
				if key ~= presentedKey then
					present(snapshot)
				end
			end
		end
		local now = os.clock()
		if confetti.Visible then
			stepConfetti(now)
		end
		if emoteRoot.Visible then
			stepEmote(now)
		end
	end)
end

return Ceremony
