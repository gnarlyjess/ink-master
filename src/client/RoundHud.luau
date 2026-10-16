--!strict

-- Lobby card for the round clock. This script only renders the server snapshot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundTypes = require(ReplicatedStorage.Shared.RoundTypes)
local UiTheme = require(script.Parent.UiTheme)

type RoundSnapshot = RoundTypes.RoundSnapshot

type Presentation = {
	subtitle: string,
	accent: Color3,
}

type HudRefs = {
	badge: TextLabel,
	roundLabel: TextLabel,
	pill: Frame,
	pillLabel: TextLabel,
	pillStroke: UIStroke,
	heroCaption: TextLabel,
	heroValue: TextLabel,
	secondaryTime: TextLabel,
	subtitle: TextLabel,
	track: Frame,
	fill: Frame,
	artistsValue: TextLabel,
	themeChip: Frame,
	themeValue: TextLabel,
}

local PREFIX = "[InkMasters]"
local CARD_WIDTH = 540
local CHIP_WIDTH = 230

local PRESENTATION: { [string]: Presentation } = {
	WaitingForPlayers = {
		subtitle = "The studio stays open until enough artists arrive.",
		accent = UiTheme.color.gold,
	},
	Intermission = {
		subtitle = "Settle in. The next theme is close.",
		accent = UiTheme.color.violet,
	},
	ThemeReveal = {
		subtitle = "A new theme is on the board.",
		accent = UiTheme.color.magenta,
	},
	TattooCreation = {
		subtitle = "Place marks on the forearm panel.",
		accent = UiTheme.color.aqua,
	},
	Submission = {
		subtitle = "Designs will lock in here.",
		accent = UiTheme.color.gold,
	},
	Showcase = {
		subtitle = "Every tattoo will be presented here.",
		accent = UiTheme.color.violet,
	},
	Voting = {
		subtitle = "One vote each, counted on the server.",
		accent = UiTheme.color.magenta,
	},
	Results = {
		subtitle = "The top three will take the podium here.",
		accent = UiTheme.color.gold,
	},
	Cleanup = {
		subtitle = "Clearing the stations for the next round.",
		accent = UiTheme.color.muted,
	},
}

local function newFrame(name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(0, 0)
	return frame
end

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addStroke(parent: Instance, color: Color3, thickness: number, transparency: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function addPadding(parent: Instance, top: number, right: number, bottom: number, left: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, top)
	padding.PaddingRight = UDim.new(0, right)
	padding.PaddingBottom = UDim.new(0, bottom)
	padding.PaddingLeft = UDim.new(0, left)
	padding.Parent = parent
end

local function addList(parent: Instance, direction: Enum.FillDirection, padding: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, padding)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

local function createLabel(name: string, textSize: number, face: Font, color: Color3, fit: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.FontFace = face
	label.TextSize = textSize
	label.TextColor3 = color
	label.Text = ""
	label.TextWrapped = not fit
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.RichText = false
	label.AutoLocalize = false
	label.TextStrokeTransparency = 1
	label.TextScaled = false
	if fit then
		label.AutomaticSize = Enum.AutomaticSize.XY
		label.Size = UDim2.fromOffset(0, 0)
	else
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.fromScale(1, 0)
	end
	return label
end

local function formatCount(value: number): string
	return tostring(math.floor(value + 0.5))
end

local function formatClock(totalSeconds: number): string
	local seconds = math.max(0, math.ceil(totalSeconds))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return string.format("%d:%02d", minutes, remainder)
end

local function renderClock(refs: HudRefs, snapshot: RoundSnapshot)
	local stateEndsAt = snapshot.endsAt
	local stateDuration = snapshot.duration
	if stateEndsAt == nil or stateDuration == nil or stateDuration <= 0 then
		return
	end

	local remaining = math.max(0, stateEndsAt - Workspace:GetServerTimeNow())
	local clock = formatClock(remaining)
	if snapshot.state == "ThemeReveal" then
		refs.secondaryTime.Text = `{clock} left`
	else
		refs.heroValue.Text = clock
	end
	refs.fill.Size = UDim2.fromScale(math.clamp(remaining / stateDuration, 0, 1), 1)
end

local function apply(refs: HudRefs, snapshot: RoundSnapshot)
	local presentation = PRESENTATION[snapshot.state]
	local accent = if presentation ~= nil then presentation.accent else UiTheme.color.muted
	local fallbackSubtitle = if presentation ~= nil then presentation.subtitle else ""

	refs.badge.Visible = snapshot.devMode
	refs.subtitle.TextColor3 = if snapshot.state == "ThemeReveal" then UiTheme.color.text else UiTheme.color.muted
	refs.roundLabel.Text = if snapshot.state == "WaitingForPlayers"
		then "Lobby"
		else `Round {formatCount(snapshot.roundId)}`
	refs.pillLabel.Text = RoundTypes.getLabel(snapshot.state)
	refs.pill.BackgroundColor3 = accent
	refs.pillLabel.TextColor3 = accent
	refs.pillStroke.Color = accent
	refs.heroValue.TextColor3 = accent
	refs.secondaryTime.TextColor3 = accent
	refs.fill.BackgroundColor3 = accent

	local needed = math.max(0, math.ceil(snapshot.minPlayers - snapshot.playerCount))
	if snapshot.state == "WaitingForPlayers" and needed > 0 then
		refs.subtitle.Text = if needed == 1 then "Waiting for 1 more artist." else `Waiting for {needed} more artists.`
	elseif snapshot.state == "ThemeReveal" and snapshot.themeTagline ~= nil then
		refs.subtitle.Text = snapshot.themeTagline
	else
		refs.subtitle.Text = fallbackSubtitle
	end

	if snapshot.state == "WaitingForPlayers" then
		refs.heroCaption.Text = "TO START"
		refs.heroValue.TextSize = 60
		refs.heroValue.Text = `{formatCount(snapshot.playerCount)} / {formatCount(snapshot.minPlayers)}`
		refs.secondaryTime.Visible = false
	elseif snapshot.state == "ThemeReveal" then
		refs.heroCaption.Text = "THIS ROUND"
		refs.heroValue.TextSize = 36
		refs.heroValue.Text = snapshot.themeName or "Theme"
		refs.secondaryTime.Visible = true
	else
		refs.heroCaption.Text = "TIME LEFT"
		refs.heroValue.TextSize = 60
		refs.secondaryTime.Visible = false
	end

	local hasTimer = snapshot.endsAt ~= nil and snapshot.duration ~= nil
	refs.track.Visible = hasTimer
	refs.artistsValue.Text = `{formatCount(snapshot.playerCount)} / {formatCount(snapshot.maxPlayers)}`
	refs.themeValue.Text = snapshot.themeName or "Incoming"
	refs.themeChip.Visible = snapshot.state ~= "ThemeReveal"
	renderClock(refs, snapshot)
end

local function buildHud(parent: Instance): HudRefs
	local existing = parent:FindFirstChild("InkMastersHud")
	if existing ~= nil then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "InkMastersHud"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 10
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = parent

	local holder = newFrame("CardHolder")
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 68)
	holder.Size = UDim2.fromOffset(CARD_WIDTH, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Parent = screenGui

	local shadow = newFrame("Shadow")
	shadow.BackgroundColor3 = UiTheme.color.shadow
	shadow.BackgroundTransparency = 0.45
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromOffset(0, 8)
	shadow.ZIndex = 1
	shadow.Parent = holder
	addCorner(shadow, 22)

	local card = newFrame("Card")
	card.BackgroundColor3 = UiTheme.color.panel
	card.BackgroundTransparency = 0.08
	card.Size = UDim2.fromScale(1, 1)
	card.ZIndex = 2
	card.ClipsDescendants = true
	card.Parent = holder
	addCorner(card, 22)
	addStroke(card, UiTheme.color.stroke, 1, 0.25)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UiTheme.color.panelTop),
		ColorSequenceKeypoint.new(1, UiTheme.color.panel),
	})
	gradient.Rotation = 100
	gradient.Parent = card

	local accent = newFrame("Accent")
	accent.BackgroundColor3 = UiTheme.color.magenta
	accent.Size = UDim2.new(0, 6, 1, 0)
	accent.ZIndex = 3
	accent.Parent = card
	local accentGradient = Instance.new("UIGradient")
	accentGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UiTheme.color.magenta),
		ColorSequenceKeypoint.new(1, UiTheme.color.gold),
	})
	accentGradient.Rotation = 90
	accentGradient.Parent = accent

	local badge = createLabel("DevBadge", 12, UiTheme.font.bold, UiTheme.color.ink, false)
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -14, 0, 14)
	badge.Size = UDim2.fromOffset(52, 22)
	badge.AutomaticSize = Enum.AutomaticSize.None
	badge.BackgroundColor3 = UiTheme.color.gold
	badge.BackgroundTransparency = 0
	badge.Text = "DEV"
	badge.ZIndex = 5
	badge.Visible = false
	badge.Parent = holder
	addCorner(badge, 8)

	local content = newFrame("Content")
	content.Size = UDim2.fromScale(1, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.ZIndex = 4
	content.Parent = holder
	addPadding(content, 22, 28, 20, 28)
	addList(content, Enum.FillDirection.Vertical, 8)

	local eyebrow = createLabel("Eyebrow", 12, UiTheme.font.bold, UiTheme.color.magenta, false)
	eyebrow.Text = "TATTOO COMPETITION"
	eyebrow.Parent = content

	local titleRow = newFrame("Wordmark")
	titleRow.AutomaticSize = Enum.AutomaticSize.XY
	titleRow.Parent = content
	addList(titleRow, Enum.FillDirection.Horizontal, 8)

	local ink = createLabel("Ink", 32, UiTheme.font.heavy, UiTheme.color.text, true)
	ink.Text = "INK"
	ink.Parent = titleRow
	local masters = createLabel("Masters", 32, UiTheme.font.heavy, UiTheme.color.magenta, true)
	masters.Text = "MASTERS"
	masters.Parent = titleRow

	local roundLabel = createLabel("Round", 14, UiTheme.font.medium, UiTheme.color.muted, false)
	roundLabel.Text = "Lobby"
	roundLabel.Parent = content

	local pill = newFrame("StatePill")
	pill.BackgroundColor3 = UiTheme.color.chip
	pill.BackgroundTransparency = 0.82
	pill.AutomaticSize = Enum.AutomaticSize.XY
	pill.Parent = content
	addCorner(pill, 999)
	addPadding(pill, 6, 14, 6, 14)
	local pillStroke = addStroke(pill, UiTheme.color.muted, 1, 0.35)
	local pillLabel = createLabel("State", 14, UiTheme.font.bold, UiTheme.color.muted, true)
	pillLabel.Text = "Connecting"
	pillLabel.Parent = pill

	local heroCaption = createLabel("HeroCaption", 12, UiTheme.font.bold, UiTheme.color.muted, false)
	heroCaption.Text = "STUDIO"
	heroCaption.Parent = content

	local heroValue = createLabel("HeroValue", 60, UiTheme.font.heavy, UiTheme.color.text, false)
	heroValue.Text = "—"
	heroValue.Parent = content

	local secondaryTime = createLabel("SecondaryTime", 18, UiTheme.font.bold, UiTheme.color.gold, false)
	secondaryTime.Visible = false
	secondaryTime.Parent = content

	local subtitle = createLabel("Subtitle", 16, UiTheme.font.medium, UiTheme.color.text, false)
	subtitle.Text = "Joining the studio..."
	subtitle.Parent = content

	local track = newFrame("CountdownTrack")
	track.BackgroundColor3 = UiTheme.color.track
	track.BackgroundTransparency = 0
	track.Size = UDim2.new(1, 0, 0, 4)
	track.Visible = false
	track.ClipsDescendants = true
	track.Parent = content
	addCorner(track, 2)
	local fill = newFrame("Fill")
	fill.BackgroundColor3 = UiTheme.color.magenta
	fill.BackgroundTransparency = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track

	local divider = newFrame("Divider")
	divider.BackgroundColor3 = UiTheme.color.stroke
	divider.BackgroundTransparency = 0.35
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Parent = content

	local chipRow = newFrame("Meta")
	chipRow.Size = UDim2.fromScale(1, 0)
	chipRow.AutomaticSize = Enum.AutomaticSize.Y
	chipRow.Parent = content
	addList(chipRow, Enum.FillDirection.Horizontal, 12)

	local function createChip(name: string, caption: string): (Frame, TextLabel)
		local chip = newFrame(name)
		chip.BackgroundColor3 = UiTheme.color.chip
		chip.BackgroundTransparency = 0
		chip.Size = UDim2.fromOffset(CHIP_WIDTH, 0)
		chip.AutomaticSize = Enum.AutomaticSize.Y
		chip.Parent = chipRow
		addCorner(chip, 12)
		addPadding(chip, 10, 8, 10, 8)
		addList(chip, Enum.FillDirection.Vertical, 2)

		local captionLabel = createLabel(name .. "Caption", 11, UiTheme.font.bold, UiTheme.color.muted, false)
		captionLabel.Text = caption
		captionLabel.Parent = chip
		local valueLabel = createLabel(name .. "Value", 18, UiTheme.font.heavy, UiTheme.color.text, false)
		valueLabel.Text = "—"
		valueLabel.Parent = chip
		return chip, valueLabel
	end

	local _, artistsValue = createChip("Artists", "ARTISTS")
	local themeChip, themeValue = createChip("Theme", "THEME")

	return {
		badge = badge,
		roundLabel = roundLabel,
		pill = pill,
		pillLabel = pillLabel,
		pillStroke = pillStroke,
		heroCaption = heroCaption,
		heroValue = heroValue,
		secondaryTime = secondaryTime,
		subtitle = subtitle,
		track = track,
		fill = fill,
		artistsValue = artistsValue,
		themeChip = themeChip,
		themeValue = themeValue,
	}
end

local RoundHud = {}
local started = false

function RoundHud.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	if player == nil then
		error("[InkMasters] The lobby HUD must run on the client")
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local refs = buildHud(playerGui)
	local currentSnapshot: RoundSnapshot? = nil
	local lastLogKey = ""

	local function onSnapshot(payload: any)
		local snapshot = RoundTypes.readSnapshot(payload)
		if snapshot == nil then
			warn(`{PREFIX} Ignored a round update that did not match the expected shape`)
			return
		end
		if currentSnapshot ~= nil and snapshot.revision <= currentSnapshot.revision then
			return
		end

		currentSnapshot = snapshot
		apply(refs, snapshot)

		local logKey = `{snapshot.roundId}:{snapshot.state}`
		if logKey ~= lastLogKey then
			lastLogKey = logKey
			print(
				`{PREFIX} HUD applied | round {snapshot.roundId} | {RoundTypes.getLabel(snapshot.state)} | rev {snapshot.revision}`
			)
		end
	end

	Remotes.RoundStateUpdated.OnClientEvent:Connect(onSnapshot)
	RunService.Heartbeat:Connect(function()
		if currentSnapshot ~= nil then
			renderClock(refs, currentSnapshot)
		end
	end)

	print(`{PREFIX} HUD ready | waiting for the server snapshot`)
	-- Keep asking until the first snapshot arrives. A single request can be lost
	-- if the client starts before the server is listening.
	task.spawn(function()
		while currentSnapshot == nil do
			Remotes.RequestRoundSnapshot:FireServer()
			task.wait(1)
		end
	end)
end

return RoundHud
