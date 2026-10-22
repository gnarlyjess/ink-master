--!strict

-- Lobby card for the round clock. This script only renders the server snapshot.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage.Shared.Economy)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundTypes = require(ReplicatedStorage.Shared.RoundTypes)
local PlayerData = require(script.Parent.PlayerData)
local UiTheme = require(script.Parent.UiTheme)

type RoundSnapshot = RoundTypes.RoundSnapshot

type Presentation = {
	subtitle: string,
	accent: Color3,
}

type HudRefs = {
	badge: TextLabel,
	eyebrow: TextLabel,
	wordmark: Frame,
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
	artistsChip: Frame,
	artistsValue: TextLabel,
	themeChip: Frame,
	themeValue: TextLabel,
	card: Frame,
	banner: Frame,
	bannerState: TextLabel,
	bannerTime: TextLabel,
	bannerTheme: TextLabel,
	pauseButton: TextButton,
	themePick: Frame,
	themeExpand: Frame,
	themeInput: TextBox,
	themeBuy: TextButton,
	themeSet: TextButton,
}

local PREFIX = "[InkMasters]"
local CARD_WIDTH = 420
local CHIP_WIDTH = 160

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
		subtitle = "Get ready to ink.",
		accent = UiTheme.color.magenta,
	},
	TattooCreation = {
		subtitle = "Place marks on the forearm panel.",
		accent = UiTheme.color.aqua,
	},
	Submission = {
		subtitle = "Designs lock in after this.",
		accent = UiTheme.color.gold,
	},
	Showcase = {
		subtitle = "Every tattoo gets a turn in the display case.",
		accent = UiTheme.color.violet,
	},
	Voting = {
		subtitle = "Vote for the best tattoo. You can't vote for yourself.",
		accent = UiTheme.color.magenta,
	},
	Results = {
		subtitle = "Votes add up. Most across the match wins.",
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
	if snapshot.state == "ThemeReveal" or snapshot.state == "Submission" then
		refs.secondaryTime.Text = `{clock} left`
	else
		refs.heroValue.Text = clock
	end
	refs.bannerTime.Text = clock
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
		else `Match {formatCount(snapshot.roundId)} · Design {formatCount(snapshot.designRound)}/{formatCount(snapshot.designRounds)}`
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
	else
		refs.subtitle.Text = fallbackSubtitle
	end

	if snapshot.state == "WaitingForPlayers" then
		refs.heroCaption.Text = "TO START"
		refs.heroValue.TextSize = 44
		refs.heroValue.Text = `{formatCount(snapshot.playerCount)} / {formatCount(snapshot.minPlayers)}`
		refs.secondaryTime.Visible = false
	elseif snapshot.state == "ThemeReveal" then
		refs.heroCaption.Text = "NEXT THEME COMING UP:"
		refs.heroValue.TextSize = 40
		refs.heroValue.Text = snapshot.themeName or "Theme"
		refs.secondaryTime.Visible = false
	elseif snapshot.state == "Submission" then
		refs.heroCaption.Text = "PENCILS DOWN"
		refs.heroValue.TextSize = 36
		refs.heroValue.Text = "Time's up!"
		refs.secondaryTime.Visible = true
	else
		refs.heroCaption.Text = "TIME LEFT"
		refs.heroValue.TextSize = 44
		refs.secondaryTime.Visible = false
	end

	local hasTimer = snapshot.endsAt ~= nil and snapshot.duration ~= nil
	local designing = snapshot.state == "TattooCreation"
	local inLobby = snapshot.state == "WaitingForPlayers" or snapshot.state == "Intermission"
	local revealing = snapshot.state == "ThemeReveal"
	refs.track.Visible = hasTimer and not designing and not inLobby and not revealing and not snapshot.paused
	refs.artistsValue.Text = `{formatCount(snapshot.playerCount)} / {formatCount(snapshot.maxPlayers)}`
	refs.themeValue.Text = snapshot.themeName or "Incoming"
	refs.themeChip.Visible = not revealing and not designing and not inLobby and not snapshot.paused
	refs.artistsChip.Visible = not revealing
	refs.roundLabel.Visible = not revealing
	refs.pill.Visible = not revealing
	refs.heroCaption.Visible = true
	refs.subtitle.Visible = not revealing
	refs.eyebrow.Visible = not revealing
	refs.wordmark.Visible = not revealing
	local ceremony = snapshot.state == "Submission"
		or snapshot.state == "Showcase"
		or snapshot.state == "Voting"
		or snapshot.state == "Results"
	-- Theme reveal sits top-centre: caption + theme name only.
	refs.card.Visible = revealing or (not designing and not inLobby and not snapshot.paused and not ceremony)
	local top = math.max(UiTheme.safe.top, GuiService:GetGuiInset().Y + 12)
	refs.card.Position = if revealing
		then UDim2.new(0.5, 0, 0, top + 8)
		else UDim2.new(0.5, 0, 0, top + 56)
	-- The ceremony owns the screen. Keep the pause chip only while the lobby is paused.
	refs.banner.Visible = (designing or inLobby or snapshot.paused or snapshot.devMode) and not ceremony and not revealing
	refs.pauseButton.Visible = snapshot.devMode
	refs.pauseButton.Text = if snapshot.paused then "Resume" else "Pause"
	refs.bannerTime.TextColor3 = accent

	local showPick = snapshot.themePickOpen and refs.banner.Visible
	refs.themePick.Visible = showPick
	if showPick then
		local queued = snapshot.myThemePickSpot ~= nil
		refs.themeBuy.Visible = not queued
		refs.themeExpand.Visible = queued
		refs.themeBuy.Text = `Choose theme for a round · {formatCount(snapshot.themePickPrice)}`
	end

	if snapshot.paused then
		refs.bannerState.Text = "Paused"
		refs.bannerTime.Text = "Lobby"
		refs.bannerTheme.Text = "Walk around"
		return
	end
	if snapshot.state == "WaitingForPlayers" then
		refs.bannerState.Text = "Lobby"
		refs.bannerTime.Text = `{formatCount(snapshot.playerCount)}/{formatCount(snapshot.minPlayers)}`
		refs.bannerTheme.Text = "Shop open"
	elseif inLobby then
		refs.bannerState.Text = "Lobby"
		refs.bannerTheme.Text =
			`Design {formatCount(snapshot.designRound)}/{formatCount(snapshot.designRounds)} soon`
	else
		refs.bannerState.Text =
			`{RoundTypes.getLabel(snapshot.state)} · {formatCount(snapshot.designRound)}/{formatCount(snapshot.designRounds)}`
		refs.bannerTheme.Text = snapshot.themeName or "Theme"
	end
	if not revealing then
		renderClock(refs, snapshot)
	end
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
	screenGui.DisplayOrder = 30
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = parent

	local holder = newFrame("CardHolder")
	holder.AnchorPoint = Vector2.new(0.5, 0)
	local top = math.max(UiTheme.safe.top, GuiService:GetGuiInset().Y + 12)
	holder.Position = UDim2.new(0.5, 0, 0, top + 56)
	holder.Size = UDim2.fromOffset(CARD_WIDTH, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Visible = false
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

	-- Top rule only — a left strip makes centred copy look off-centre.
	local accent = newFrame("Accent")
	accent.BackgroundColor3 = UiTheme.color.magenta
	accent.Size = UDim2.new(1, 0, 0, 3)
	accent.ZIndex = 3
	accent.Parent = card
	local accentGradient = Instance.new("UIGradient")
	accentGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, UiTheme.color.magenta),
		ColorSequenceKeypoint.new(1, UiTheme.color.gold),
	})
	accentGradient.Parent = accent

	local badge = createLabel("DevBadge", 11, UiTheme.font.bold, UiTheme.color.ink, false)
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -12, 0, 10)
	badge.Size = UDim2.fromOffset(44, 18)
	badge.AutomaticSize = Enum.AutomaticSize.None
	badge.BackgroundColor3 = UiTheme.color.gold
	badge.BackgroundTransparency = 0
	badge.Text = "DEV"
	badge.ZIndex = 5
	badge.Visible = false
	badge.Parent = holder
	addCorner(badge, 6)

	local content = newFrame("Content")
	content.Size = UDim2.fromScale(1, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.ZIndex = 4
	content.Parent = holder
	addPadding(content, 16, 22, 14, 22)
	addList(content, Enum.FillDirection.Vertical, 4)

	local eyebrow = createLabel("Eyebrow", 11, UiTheme.font.bold, UiTheme.color.magenta, false)
	eyebrow.Text = "TATTOO COMPETITION"
	eyebrow.Parent = content

	local titleRow = newFrame("Wordmark")
	titleRow.Size = UDim2.fromScale(1, 0)
	titleRow.AutomaticSize = Enum.AutomaticSize.Y
	titleRow.Parent = content
	addList(titleRow, Enum.FillDirection.Horizontal, 0).HorizontalAlignment = Enum.HorizontalAlignment.Center

	local wordmarkLabel = createLabel("Title", 28, UiTheme.font.heavy, UiTheme.color.magenta, true)
	wordmarkLabel.Text = "INK-OFF"
	wordmarkLabel.Parent = titleRow

	local roundLabel = createLabel("Round", 13, UiTheme.font.medium, UiTheme.color.muted, false)
	roundLabel.Text = "Lobby"
	roundLabel.Parent = content

	local pill = newFrame("StatePill")
	pill.BackgroundColor3 = UiTheme.color.chip
	pill.BackgroundTransparency = 0.82
	pill.AutomaticSize = Enum.AutomaticSize.XY
	pill.Parent = content
	addCorner(pill, 999)
	addPadding(pill, 4, 12, 4, 12)
	local pillStroke = addStroke(pill, UiTheme.color.muted, 1, 0.35)
	local pillLabel = createLabel("State", 13, UiTheme.font.bold, UiTheme.color.muted, true)
	pillLabel.Text = "Connecting"
	pillLabel.Parent = pill

	local heroCaption = createLabel("HeroCaption", 11, UiTheme.font.bold, UiTheme.color.muted, false)
	heroCaption.Text = "STUDIO"
	heroCaption.Parent = content

	local heroValue = createLabel("HeroValue", 44, UiTheme.font.heavy, UiTheme.color.text, false)
	heroValue.Text = "—"
	heroValue.Parent = content

	local secondaryTime = createLabel("SecondaryTime", 15, UiTheme.font.bold, UiTheme.color.gold, false)
	secondaryTime.Visible = false
	secondaryTime.Parent = content

	local subtitle = createLabel("Subtitle", 14, UiTheme.font.medium, UiTheme.color.text, false)
	subtitle.Text = "Joining the studio..."
	subtitle.Parent = content

	local track = newFrame("CountdownTrack")
	track.BackgroundColor3 = UiTheme.color.track
	track.BackgroundTransparency = 0
	track.Size = UDim2.new(1, 0, 0, 3)
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
	divider.Size = UDim2.new(0.55, 0, 0, 1)
	divider.Parent = content

	local chipRow = newFrame("Meta")
	chipRow.Size = UDim2.fromScale(1, 0)
	chipRow.AutomaticSize = Enum.AutomaticSize.Y
	chipRow.Parent = content
	addList(chipRow, Enum.FillDirection.Horizontal, 10).HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function createChip(name: string, caption: string): (Frame, TextLabel)
		local chip = newFrame(name)
		chip.BackgroundColor3 = UiTheme.color.chip
		chip.BackgroundTransparency = 0
		chip.Size = UDim2.fromOffset(CHIP_WIDTH, 0)
		chip.AutomaticSize = Enum.AutomaticSize.Y
		chip.Parent = chipRow
		addCorner(chip, 10)
		addPadding(chip, 8, 10, 8, 10)
		addList(chip, Enum.FillDirection.Vertical, 1)

		local captionLabel = createLabel(name .. "Caption", 10, UiTheme.font.bold, UiTheme.color.muted, false)
		captionLabel.Text = caption
		captionLabel.Parent = chip
		local valueLabel = createLabel(name .. "Value", 16, UiTheme.font.heavy, UiTheme.color.text, false)
		valueLabel.Text = "—"
		valueLabel.Parent = chip
		return chip, valueLabel
	end

	local artistsChip, artistsValue = createChip("Artists", "ARTISTS")
	local themeChip, themeValue = createChip("Theme", "THEME")

	-- Banner text stays centred; Pause sits outside so it never shifts the copy.
	local banner = newFrame("Banner")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, top)
	banner.AutomaticSize = Enum.AutomaticSize.XY
	banner.BackgroundColor3 = UiTheme.color.panel
	banner.BackgroundTransparency = 0.12
	banner.Visible = true
	banner.ZIndex = 6
	banner.Parent = screenGui
	addCorner(banner, 999)
	addStroke(banner, UiTheme.color.stroke, 1, 0.35)
	addPadding(banner, 7, 18, 7, 18)
	addList(banner, Enum.FillDirection.Horizontal, 12).HorizontalAlignment = Enum.HorizontalAlignment.Center

	local bannerState = createLabel("BannerState", 14, UiTheme.font.bold, UiTheme.color.aqua, true)
	bannerState.Text = "Lobby"
	bannerState.Parent = banner
	local bannerTime = createLabel("BannerTime", 16, UiTheme.font.heavy, UiTheme.color.text, true)
	bannerTime.Text = "…"
	bannerTime.Parent = banner
	local bannerTheme = createLabel("BannerTheme", 14, UiTheme.font.medium, UiTheme.color.text, true)
	bannerTheme.Text = "Joining"
	bannerTheme.Parent = banner

	local pauseButton = Instance.new("TextButton")
	pauseButton.Name = "Pause"
	pauseButton.BackgroundColor3 = UiTheme.color.gold
	pauseButton.BackgroundTransparency = 0.1
	pauseButton.BorderSizePixel = 0
	pauseButton.FontFace = UiTheme.font.bold
	pauseButton.TextSize = 14
	pauseButton.TextColor3 = UiTheme.color.ink
	pauseButton.Text = "Pause"
	pauseButton.AutomaticSize = Enum.AutomaticSize.XY
	pauseButton.Size = UDim2.fromOffset(0, 0)
	pauseButton.AnchorPoint = Vector2.new(0, 0.5)
	pauseButton.Position = UDim2.new(0.5, 0, 0, top + 16)
	pauseButton.Visible = false
	pauseButton.ZIndex = 7
	pauseButton.Parent = screenGui
	addCorner(pauseButton, 999)
	addPadding(pauseButton, 4, 12, 4, 12)

	-- Keep Pause tucked just to the right of the centred banner.
	banner:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		pauseButton.Position = UDim2.new(0.5, math.floor(banner.AbsoluteSize.X * 0.5) + 10, 0, top + 16)
	end)
	pauseButton.Position = UDim2.new(0.5, math.floor(banner.AbsoluteSize.X * 0.5) + 10, 0, top + 16)

	local themePick = newFrame("ThemePick")
	themePick.AnchorPoint = Vector2.new(0.5, 0)
	themePick.Position = UDim2.new(0.5, 0, 0, top + 44)
	themePick.AutomaticSize = Enum.AutomaticSize.XY
	themePick.BackgroundTransparency = 1
	themePick.Visible = false
	themePick.ZIndex = 6
	themePick.Parent = screenGui
	addList(themePick, Enum.FillDirection.Vertical, 4)

	local themeBuy = Instance.new("TextButton")
	themeBuy.Name = "ThemeBuy"
	themeBuy.BackgroundColor3 = UiTheme.color.gold
	themeBuy.BackgroundTransparency = 0.05
	themeBuy.BorderSizePixel = 0
	themeBuy.FontFace = UiTheme.font.bold
	themeBuy.TextSize = 13
	themeBuy.TextColor3 = UiTheme.color.ink
	themeBuy.Text = `Choose theme for a round · {Economy.THEME_PICK_PRICE}`
	themeBuy.AutomaticSize = Enum.AutomaticSize.XY
	themeBuy.Size = UDim2.fromOffset(0, 0)
	themeBuy.Parent = themePick
	addCorner(themeBuy, 999)
	addStroke(themeBuy, UiTheme.color.stroke, 1, 0.45)
	addPadding(themeBuy, 6, 14, 6, 14)

	local themeExpand = newFrame("ThemeExpand")
	themeExpand.AutomaticSize = Enum.AutomaticSize.XY
	themeExpand.BackgroundColor3 = UiTheme.color.panel
	themeExpand.BackgroundTransparency = 0.08
	themeExpand.Visible = false
	themeExpand.Parent = themePick
	addCorner(themeExpand, 12)
	addStroke(themeExpand, UiTheme.color.stroke, 1, 0.35)
	addPadding(themeExpand, 6, 8, 6, 8)
	addList(themeExpand, Enum.FillDirection.Horizontal, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center

	local themeInput = Instance.new("TextBox")
	themeInput.Name = "ThemeInput"
	themeInput.BackgroundColor3 = UiTheme.color.chip
	themeInput.BackgroundTransparency = 0
	themeInput.BorderSizePixel = 0
	themeInput.FontFace = UiTheme.font.medium
	themeInput.TextSize = 14
	themeInput.TextColor3 = UiTheme.color.text
	themeInput.PlaceholderColor3 = UiTheme.color.muted
	themeInput.PlaceholderText = "Your theme"
	themeInput.Text = ""
	themeInput.ClearTextOnFocus = false
	themeInput.TextXAlignment = Enum.TextXAlignment.Left
	themeInput.Size = UDim2.fromOffset(200, 30)
	themeInput.Parent = themeExpand
	addCorner(themeInput, 8)
	addPadding(themeInput, 0, 8, 0, 8)
	local inputStroke = addStroke(themeInput, UiTheme.color.stroke, 1, 0.4)
	inputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local themeSet = Instance.new("TextButton")
	themeSet.Name = "ThemeSet"
	themeSet.BackgroundColor3 = UiTheme.color.aqua
	themeSet.BackgroundTransparency = 0
	themeSet.BorderSizePixel = 0
	themeSet.FontFace = UiTheme.font.bold
	themeSet.TextSize = 13
	themeSet.TextColor3 = UiTheme.color.ink
	themeSet.Text = "Set"
	themeSet.AutomaticSize = Enum.AutomaticSize.XY
	themeSet.Size = UDim2.fromOffset(0, 30)
	themeSet.Parent = themeExpand
	addCorner(themeSet, 8)
	addPadding(themeSet, 0, 12, 0, 12)

	return {
		badge = badge,
		eyebrow = eyebrow,
		wordmark = titleRow,
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
		artistsChip = artistsChip,
		artistsValue = artistsValue,
		themeChip = themeChip,
		themeValue = themeValue,
		card = holder,
		banner = banner,
		bannerState = bannerState,
		bannerTime = bannerTime,
		bannerTheme = bannerTheme,
		pauseButton = pauseButton,
		themePick = themePick,
		themeExpand = themeExpand,
		themeInput = themeInput,
		themeBuy = themeBuy,
		themeSet = themeSet,
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
	local wasQueued = false

	local function onSnapshot(payload: any)
		local snapshot = RoundTypes.readSnapshot(payload)
		if snapshot == nil then
			warn(`{PREFIX} Ignored a round update that did not match the expected shape`)
			return
		end
		if currentSnapshot ~= nil and snapshot.revision <= currentSnapshot.revision then
			return
		end

		local nowQueued = snapshot.myThemePickSpot ~= nil
		currentSnapshot = snapshot
		apply(refs, snapshot)
		if nowQueued and not wasQueued and snapshot.themePickOpen then
			refs.themeInput:CaptureFocus()
		end
		wasQueued = nowQueued

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

	local function sendPause(wantPause: boolean)
		if currentSnapshot == nil or not currentSnapshot.devMode then
			return
		end
		Remotes.DevSetPaused:FireServer(wantPause)
	end

	refs.pauseButton.MouseButton1Click:Connect(function()
		local wantPause = if currentSnapshot ~= nil then not currentSnapshot.paused else true
		sendPause(wantPause)
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or input.KeyCode ~= Enum.KeyCode.P then
			return
		end
		-- Don't toggle pause while typing a theme.
		if UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		local wantPause = if currentSnapshot ~= nil then not currentSnapshot.paused else true
		sendPause(wantPause)
	end)

	local function readThemeText(): string?
		local raw = refs.themeInput.Text
		local trimmed = string.match(raw, "^%s*(.-)%s*$") or ""
		if #trimmed > Economy.THEME_PICK_MAX_CHARS then
			trimmed = string.sub(trimmed, 1, Economy.THEME_PICK_MAX_CHARS)
			refs.themeInput.Text = trimmed
		end
		if trimmed == "" then
			return nil
		end
		return trimmed
	end

	-- Collapsed buy: claim the next free round (theme stays random until they type one).
	refs.themeBuy.MouseButton1Click:Connect(function()
		local snapshot = currentSnapshot
		if snapshot == nil or not snapshot.themePickOpen or snapshot.myThemePickSpot ~= nil then
			return
		end
		PlayerData.buyThemePick(nil)
	end)

	local function submitThemeText()
		local snapshot = currentSnapshot
		if snapshot == nil or not snapshot.themePickOpen or snapshot.myThemePickSpot == nil then
			return
		end
		PlayerData.setThemePick(readThemeText())
	end

	refs.themeSet.MouseButton1Click:Connect(submitThemeText)
	refs.themeInput.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			submitThemeText()
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
