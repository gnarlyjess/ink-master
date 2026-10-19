--!strict

-- Time's up, then the display case, then the vote board, then the winner and the podium.
-- Display case: the tattoo on the left, the artist on the right.
-- Vote board: one card per tattoo with a vote button and a countdown.
-- Party: the cards fly together, the winner card pops, then the camera cuts to the podium hall.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local CeremonyTypes = require(ReplicatedStorage.Shared.CeremonyTypes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fanfare = require(script.Parent.Fanfare)
local FrameDress = require(script.Parent.FrameDress)
local PlayerData = require(script.Parent.PlayerData)
local Sfx = require(script.Parent.Sfx)
local TattooCanvas = require(script.Parent.TattooCanvas)
local UiTheme = require(script.Parent.UiTheme)

type CeremonySnapshot = CeremonyTypes.CeremonySnapshot
type Entry = CeremonyTypes.Entry

type Card = {
	userId: number,
	mine: boolean,
	cell: Frame,
	face: Frame,
	scale: UIScale,
	stroke: UIStroke,
	button: TextButton,
}

local CARD_W = 196
local CARD_H = 292
local CARD_GAP = 18
local BOARD_TOP = 188
local COLLAPSE_SECONDS = 0.55
local REVEAL_HOLD = 4.4
local STACK_W = 440
local STACK_H = 520
local RAY_COUNT = 8
local SPLIT = 0.42
local HEADER_H = 64
local PANE_GAP = 18

local current: CeremonySnapshot? = nil
local shownPhase = ""
local presentedKey = ""
local caseOpen = false
local myVote = 0
local voteSeconds = 10
local lastTick = -1

local avatarUserId = 0
local avatarFocus = Vector3.zero
local avatarDistance = 8

local boardKey = ""
local cards: { Card } = {}
local boardColumns = 1
local boardRows = 1

local revealToken = 0
local cameraTaken = false

local screen: ScreenGui
local dim: Frame
local timeUp: TextLabel
local flash: Frame
local confetti: Frame
local dots: { Frame } = {}

local artistGui: ScreenGui
local artistPanel: Frame
local panelStroke: UIStroke
local frameDress: Frame
local showcaseHeader: Frame
local headerKicker: TextLabel
local headerIndex: TextLabel
local artistName: TextLabel
local artistTitle: TextLabel
local avatarView: ViewportFrame
local avatarWorld: WorldModel
local avatarCamera: Camera
local avatarMissing: TextLabel
local progressFill: Frame
local artistFooter: TextLabel
local avatarToken = 0

local voteRoot: Frame
local voteHeader: Frame
local clockLabel: TextLabel
local clockScale: UIScale
local clockStroke: UIStroke
local timerFill: Frame
local voteHint: TextLabel
local board: Frame
local boardScale: UIScale

local revealRoot: Frame
local rays: { Frame } = {}
local stack: Frame
local stackScale: UIScale
local winnerTitle: TextLabel
local winnerTitleScale: UIScale
local winnerCard: Frame
local winnerCardScale: UIScale
local winnerName: TextLabel
local winnerTag: TextLabel
local winnerThumb: Frame
local winnerStats: TextLabel
local runnerRow: Frame
local yourLine: TextLabel

local emoteRoot: Frame
local emoteHolder: Frame
local emoteLabel: TextLabel
local emoteScale: UIScale
local stamp: Frame
local stampScale: UIScale
local stampStroke: UIStroke
local sparks: { Frame } = {}
local emoteStyle = ""
local emoteStarted = 0
local emoteShownId = ""

local function corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local function outline(parent: Instance, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function textStroke(label: TextLabel, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = UiTheme.color.ink
	stroke.Thickness = thickness
	stroke.Parent = label
end

local function text(parent: Instance, value: string, size: number, face: Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.FontFace = face
	label.TextSize = size
	label.TextColor3 = color
	label.Text = value
	label.Parent = parent
	return label
end

local function tween(
	object: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?,
	delay: number?
)
	local info = TweenInfo.new(
		seconds,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out,
		0,
		false,
		delay or 0
	)
	local created = TweenService:Create(object, info, goal)
	created:Play()
	return created
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

local function ownerCharacter(userId: number): Model?
	local owner = Players:GetPlayerByUserId(userId)
	if owner ~= nil then
		return owner.Character
	end
	return nil
end

local function modelFor(userId: number): Model?
	return ownerCharacter(userId)
end

local function entryFor(snapshot: CeremonySnapshot, userId: number): Entry?
	for _, entry in snapshot.entries do
		if entry.userId == userId then
			return entry
		end
	end
	return nil
end

local function titleOf(entry: Entry): string
	local worn = if entry.title ~= "" then Catalogue.get(entry.title) else nil
	if worn ~= nil and worn.text ~= nil then
		return worn.text
	end
	return ""
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
	return math.clamp(math.floor(elapsed / snapshot.secondsEach) + 1, 1, count)
end

local function designKey(entry: Entry): string
	return `{entry.userId}:{entry.design.region}:{#entry.design.elements}`
end

-- Cosmetics -----------------------------------------------------------------

local function colorAt(palette: { Color3 }, index: number): Color3
	return palette[((index - 1) % #palette) + 1]
end

local function paintConfetti(entry: Entry?)
	local view = PlayerData.get()
	if view ~= nil and not view.settings.confetti then
		confetti.Visible = false
		return
	end
	local palette: { Color3 } = { UiTheme.color.gold, UiTheme.color.magenta, UiTheme.color.text }
	if entry ~= nil and entry.confetti ~= "" then
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
	confetti.Visible = true
end

local function hideFrame()
	frameDress.Visible = false
	FrameDress.clear(frameDress)
	panelStroke.Transparency = 0
end

local function applyFrame(entry: Entry)
	local worn = if entry.frame ~= "" then Catalogue.get(entry.frame) else nil
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

local function applyEmote(entry: Entry)
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

-- Camera --------------------------------------------------------------------

local function takeCamera()
	local stage = Workspace:FindFirstChild("WinnerStage")
	local mark = if stage ~= nil then stage:FindFirstChild("CameraMark") else nil
	local camera = Workspace.CurrentCamera
	if mark == nil or not mark:IsA("BasePart") or camera == nil then
		return
	end
	cameraTaken = true
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = mark.CFrame * CFrame.new(0, 4, 16)
	tween(camera, 2.8, { CFrame = mark.CFrame }, Enum.EasingStyle.Quint)
end

local function releaseCamera()
	if not cameraTaken then
		return
	end
	cameraTaken = false
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid ~= nil then
		camera.CameraSubject = humanoid
	end
end

-- Display case ----------------------------------------------------------------

local function layoutShowcase()
	local area = screen.AbsoluteSize
	if area.X < 2 or area.Y < 2 then
		return
	end
	local top = HEADER_H
	local leftWidth = math.floor(area.X * (1 - SPLIT) - PANE_GAP * 1.5)
	local rightWidth = math.floor(area.X * SPLIT - PANE_GAP * 1.5)
	local paneHeight = math.floor(area.Y - top - PANE_GAP)
	showcaseHeader.Position = UDim2.fromOffset(PANE_GAP, 10)
	showcaseHeader.Size = UDim2.fromOffset(area.X - PANE_GAP * 2, HEADER_H - 16)
	artistPanel.Position = UDim2.fromOffset(area.X - PANE_GAP - rightWidth, top)
	artistPanel.Size = UDim2.fromOffset(rightWidth, paneHeight)
	frameDress.Position = artistPanel.Position
	frameDress.Size = artistPanel.Size
	TattooCanvas.setStageOverride(UDim2.fromOffset(PANE_GAP, top), UDim2.fromOffset(leftWidth, paneHeight))
end

local function closeCase()
	TattooCanvas.setPresentation(nil)
	TattooCanvas.setStageOverride(nil, nil)
	if caseOpen then
		TattooCanvas.setInteractive(false)
		TattooCanvas.clear()
		caseOpen = false
	end
	presentedKey = ""
end

local function showDesign(entry: Entry)
	local key = designKey(entry)
	TattooCanvas.setPresentation(entry.name)
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

local function cloneAvatar(character: Model): Model
	local wasArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = wasArchivable
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("BillboardGui") or descendant:IsA("Sound") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return clone
end

local function clearAvatar()
	avatarToken += 1
	avatarWorld:ClearAllChildren()
	avatarUserId = 0
end

local function putAvatar(model: Model)
	local clone = cloneAvatar(model)
	clone:PivotTo(CFrame.identity)
	clone.Parent = avatarWorld
	local box, size = clone:GetBoundingBox()
	avatarFocus = box.Position
	local half = math.max(size.Y, size.X * 1.15) * 0.5
	avatarDistance = half / math.tan(math.rad(avatarCamera.FieldOfView * 0.5)) * 1.18
	avatarMissing.Visible = false
end

local function mountAvatar(userId: number)
	if userId == avatarUserId and avatarWorld:FindFirstChildOfClass("Model") ~= nil then
		return
	end
	avatarToken += 1
	local token = avatarToken
	avatarWorld:ClearAllChildren()
	avatarUserId = userId
	local character = ownerCharacter(userId)
	if character ~= nil then
		putAvatar(character)
		return
	end
	avatarMissing.Visible = true
	task.spawn(function()
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromUserId(userId)
		end)
		if token ~= avatarToken then
			if ok and model ~= nil then
				model:Destroy()
			end
			return
		end
		if ok and model ~= nil then
			putAvatar(model)
			model:Destroy()
		end
	end)
end

local function stepAvatar(now: number)
	local angle = math.sin(now * 0.55) * 0.75
	local offset = Vector3.new(math.sin(angle), 0.06, -math.cos(angle)) * avatarDistance
	avatarCamera.CFrame = CFrame.lookAt(avatarFocus + offset, avatarFocus)
end

local function presentShowcase(snapshot: CeremonySnapshot)
	artistGui.Enabled = true
	artistPanel.Visible = true
	showcaseHeader.Visible = true
	layoutShowcase()
	if screen.AbsoluteSize.X < 2 then
		task.defer(layoutShowcase)
	end
	local count = #snapshot.entries
	local index = showcaseIndex(snapshot)
	local entry = if index > 0 then snapshot.entries[index] else nil
	if entry == nil then
		headerKicker.Text = "ON DISPLAY"
		headerIndex.Text = "Empty case"
		artistName.Text = "No tattoos"
		artistTitle.Visible = false
		artistFooter.Text = "Nobody locked a design this round."
		hideFrame()
		clearAvatar()
		avatarMissing.Visible = true
		closeCase()
		return
	end
	headerKicker.Text = "ON DISPLAY"
	headerIndex.Text = `{index}  /  {count}`
	artistName.Text = entry.name
	local title = titleOf(entry)
	artistTitle.Text = title
	artistTitle.Visible = title ~= ""
	local marks = #entry.design.elements
	local markWord = if marks == 1 then "mark" else "marks"
	artistFooter.Text = if index < count
		then `{marks} {markWord}  ·  next up soon`
		else `{marks} {markWord}  ·  vote next`
	applyFrame(entry)
	mountAvatar(entry.userId)
	showDesign(entry)
end

-- Vote board ------------------------------------------------------------------

local function layoutBoard()
	local width = boardColumns * CARD_W + (boardColumns - 1) * CARD_GAP
	local height = boardRows * CARD_H + (boardRows - 1) * CARD_GAP
	local area = screen.AbsoluteSize
	local roomW = area.X - 64
	local roomH = area.Y - BOARD_TOP - UiTheme.safe.bottom
	local fit = math.min(roomW / math.max(width, 1), roomH / math.max(height, 1))
	board.Size = UDim2.fromOffset(width, height)
	boardScale.Scale = math.clamp(fit, 0.35, 1.15)
	board.Position = UDim2.fromOffset(area.X / 2, BOARD_TOP + roomH / 2)
end

local function refreshCards()
	for _, card in cards do
		local chosen = myVote == card.userId
		card.button.AutoButtonColor = not card.mine
		if card.mine then
			card.button.Text = "YOUR TATTOO"
			card.button.BackgroundColor3 = UiTheme.color.chip
			card.button.TextColor3 = UiTheme.color.muted
		elseif chosen then
			card.button.Text = "VOTED ✓"
			card.button.BackgroundColor3 = UiTheme.color.gold
			card.button.TextColor3 = UiTheme.color.ink
		else
			card.button.Text = "VOTE"
			card.button.BackgroundColor3 = UiTheme.color.magenta
			card.button.TextColor3 = UiTheme.color.text
		end
		card.stroke.Color = if chosen then UiTheme.color.gold else UiTheme.color.stroke
		card.stroke.Thickness = if chosen then 3 else 1.5
	end
end

local function updateHint(snapshot: CeremonySnapshot)
	if #snapshot.entries < 2 then
		voteHint.Text = "You're the only artist, so the party is yours."
	elseif myVote == 0 then
		voteHint.Text = "Pick your favourite. You can't vote for your own."
	else
		voteHint.Text = "Vote in. You can change it before the clock runs out."
	end
end

local function makeCard(entry: Entry, order: number, row: Frame): Card
	local mine = entry.userId == localUserId()

	local cell = Instance.new("Frame")
	cell.Name = `Card_{entry.userId}`
	cell.BackgroundTransparency = 1
	cell.Size = UDim2.fromOffset(CARD_W, CARD_H)
	cell.LayoutOrder = order
	cell.Parent = row

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = UiTheme.color.panel
	face.BackgroundTransparency = 0.04
	face.ZIndex = 12
	face.Parent = cell
	corner(face, 14)
	local stroke = outline(face, UiTheme.color.stroke, 1.5)
	local scale = Instance.new("UIScale")
	scale.Parent = face

	local name = text(face, entry.name, 16, UiTheme.font.heavy, UiTheme.color.text)
	name.Position = UDim2.fromOffset(10, 8)
	name.Size = UDim2.new(1, -20, 0, 22)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.ZIndex = 13
	local title = titleOf(entry)
	local tag = text(face, if title ~= "" then title else " ", 11, UiTheme.font.bold, UiTheme.color.magenta)
	tag.Position = UDim2.fromOffset(10, 28)
	tag.Size = UDim2.new(1, -20, 0, 14)
	tag.TextTruncate = Enum.TextTruncate.AtEnd
	tag.ZIndex = 13

	local thumb = Instance.new("Frame")
	thumb.Name = "Thumb"
	thumb.Position = UDim2.fromOffset(10, 46)
	thumb.Size = UDim2.new(1, -20, 1, -46 - 62)
	thumb.BackgroundColor3 = UiTheme.color.ink
	thumb.ClipsDescendants = true
	thumb.ZIndex = 13
	thumb.Parent = face
	corner(thumb, 10)
	local character = modelFor(entry.userId)
	if character ~= nil then
		TattooCanvas.snapshot(thumb, character, entry.design)
	end

	local button = Instance.new("TextButton")
	button.Name = "Vote"
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new(0, 10, 1, -10)
	button.Size = UDim2.new(1, -20, 0, 42)
	button.BorderSizePixel = 0
	button.FontFace = UiTheme.font.heavy
	button.TextSize = 18
	button.ZIndex = 14
	button.Parent = face
	corner(button, 10)

	local userId = entry.userId
	button.MouseButton1Click:Connect(function()
		local snapshot = current
		if mine or snapshot == nil or snapshot.phase ~= "Voting" then
			return
		end
		myVote = userId
		Remotes.CastVote:FireServer(userId)
		Sfx.play("click")
		refreshCards()
		updateHint(snapshot)
		scale.Scale = 1.06
		tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	scale.Scale = 0.4
	face.BackgroundTransparency = 1
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, order * 0.06)
	tween(face, 0.3, { BackgroundTransparency = 0.04 }, nil, nil, order * 0.06)

	return {
		userId = userId,
		mine = mine,
		cell = cell,
		face = face,
		scale = scale,
		stroke = stroke,
		button = button,
	}
end

local function clearBoard()
	for _, child in board:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(cards)
	boardKey = ""
end

local function buildBoard(snapshot: CeremonySnapshot)
	local ids = {}
	for _, entry in snapshot.entries do
		table.insert(ids, tostring(entry.userId))
	end
	local key = `{snapshot.roundId}:{table.concat(ids, ",")}`
	if key == boardKey then
		return
	end
	clearBoard()
	boardKey = key
	voteHeader.Visible = true

	local count = #snapshot.entries
	boardColumns = if count <= 5 then math.max(count, 1) else math.ceil(count / 2)
	boardRows = math.max(1, math.ceil(count / boardColumns))
	for rowIndex = 1, boardRows do
		local row = Instance.new("Frame")
		row.Name = `Row{rowIndex}`
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, CARD_H)
		row.LayoutOrder = rowIndex
		row.Parent = board
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.Padding = UDim.new(0, CARD_GAP)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = row
		for column = 1, boardColumns do
			local index = (rowIndex - 1) * boardColumns + column
			local entry = snapshot.entries[index]
			if entry ~= nil then
				table.insert(cards, makeCard(entry, index, row))
			end
		end
	end
	layoutBoard()
end

local function presentVoting(snapshot: CeremonySnapshot)
	voteRoot.Visible = true
	dim.Visible = true
	dim.BackgroundTransparency = 0.12
	buildBoard(snapshot)
	refreshCards()
	updateHint(snapshot)
end

local function stepClock(snapshot: CeremonySnapshot)
	local ends = snapshot.phaseEnds
	if ends == nil then
		clockLabel.Text = ""
		return
	end
	local remaining = math.max(0, ends - Workspace:GetServerTimeNow())
	local whole = math.ceil(remaining)
	timerFill.Size = UDim2.fromScale(math.clamp(remaining / voteSeconds, 0, 1), 1)
	if whole == lastTick then
		return
	end
	lastTick = whole
	clockLabel.Text = tostring(whole)
	local urgent = whole <= 3
	clockLabel.TextColor3 = if urgent then UiTheme.color.magenta else UiTheme.color.text
	clockStroke.Color = if urgent then UiTheme.color.magenta else UiTheme.color.gold
	timerFill.BackgroundColor3 = if urgent then UiTheme.color.magenta else UiTheme.color.gold
	clockScale.Scale = if urgent then 1.35 else 1.15
	tween(clockScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	if urgent and whole > 0 then
		Sfx.play("click")
	end
end

-- Party -----------------------------------------------------------------------

local function burstFlash()
	flash.Visible = true
	flash.BackgroundTransparency = 0.25
	local fade = tween(flash, 0.6, { BackgroundTransparency = 1 })
	fade.Completed:Connect(function()
		flash.Visible = false
	end)
end

local function collapseBoard(token: number, done: () -> ())
	voteHeader.Visible = false
	if #cards == 0 or not voteRoot.Visible then
		voteRoot.Visible = false
		done()
		return
	end
	local center = board.AbsolutePosition + board.AbsoluteSize / 2
	local scale = math.max(boardScale.Scale, 0.01)
	for index, card in cards do
		local cellCenter = card.cell.AbsolutePosition + card.cell.AbsoluteSize / 2
		local delta = (center - cellCenter) / scale
		local spin = if index % 2 == 0 then 14 else -14
		tween(card.face, COLLAPSE_SECONDS, {
			Position = UDim2.new(0.5, delta.X, 0.5, delta.Y),
			Rotation = spin,
		}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(card.scale, COLLAPSE_SECONDS, { Scale = 0.1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end
	task.delay(COLLAPSE_SECONDS, function()
		if token ~= revealToken then
			return
		end
		voteRoot.Visible = false
		clearBoard()
		done()
	end)
end

local function fillRunners(snapshot: CeremonySnapshot)
	for _, child in runnerRow:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, place in snapshot.places do
		if place.place > 1 then
			local chip =
				text(runnerRow, `{placeWord(place.place)}  {place.name}`, 14, UiTheme.font.bold, UiTheme.color.text)
			chip.AutomaticSize = Enum.AutomaticSize.X
			chip.Size = UDim2.fromOffset(0, 30)
			chip.BackgroundTransparency = 0
			chip.BackgroundColor3 = UiTheme.color.chip
			chip.LayoutOrder = place.place
			chip.ZIndex = 23
			corner(chip, 999)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 12)
			pad.PaddingRight = UDim.new(0, 12)
			pad.Parent = chip
		end
	end
end

local function fillYourLine(snapshot: CeremonySnapshot)
	local mine = localUserId()
	for _, place in snapshot.places do
		if place.userId == mine then
			yourLine.Text =
				`You placed {placeWord(place.place)}  ·  +{place.awarded} coins  ·  {snapshot.yourTotal} total`
			return
		end
	end
	yourLine.Text = `You have {snapshot.yourTotal} coins.`
end

local function fillWinner(snapshot: CeremonySnapshot)
	winnerThumb:ClearAllChildren()
	corner(winnerThumb, 12)
	local winner = snapshot.places[1]
	local entry = if winner ~= nil then entryFor(snapshot, winner.userId) else nil
	if winner == nil or entry == nil then
		winnerTitle.Text = "NO WINNER"
		winnerName.Text = "Empty case"
		winnerTag.Text = "No tattoos were locked in."
		winnerStats.Text = ""
		hideEmote()
		paintConfetti(nil)
		return
	end
	winnerTitle.Text = "WINNER"
	winnerName.Text = winner.name
	local title = titleOf(entry)
	winnerTag.Text = if title ~= "" then title else "Best tattoo this round"
	local voteWord = if winner.votes == 1 then "vote" else "votes"
	winnerStats.Text = `{winner.votes} {voteWord}  ·  +{winner.awarded} coins`
	local character = modelFor(entry.userId)
	if character ~= nil then
		TattooCanvas.snapshot(winnerThumb, character, entry.design)
	end
	applyEmote(entry)
	paintConfetti(entry)
end

local function settleReveal(token: number)
	if token ~= revealToken then
		return
	end
	local area = screen.AbsoluteSize
	local small = 0.55
	tween(stack, 0.7, {
		Position = UDim2.fromOffset(24 + STACK_W * small / 2, area.Y / 2 + 10),
	}, Enum.EasingStyle.Quint)
	tween(stackScale, 0.7, { Scale = small }, Enum.EasingStyle.Quint)
	tween(dim, 0.7, { BackgroundTransparency = 1 })
	for _, ray in rays do
		tween(ray, 0.5, { BackgroundTransparency = 1 })
	end
	takeCamera()
end

local function startReveal(snapshot: CeremonySnapshot, token: number)
	if token ~= revealToken then
		return
	end
	fillWinner(snapshot)
	fillRunners(snapshot)
	fillYourLine(snapshot)
	revealRoot.Visible = true
	dim.Visible = true
	dim.BackgroundTransparency = 0.3
	stack.Position = UDim2.fromScale(0.5, 0.5)
	stackScale.Scale = 1
	for _, ray in rays do
		ray.BackgroundTransparency = 1
		tween(ray, 0.6, { BackgroundTransparency = 0.82 })
	end
	winnerCardScale.Scale = 0
	tween(winnerCardScale, 0.65, { Scale = 1 }, Enum.EasingStyle.Back)
	winnerTitleScale.Scale = 3
	winnerTitle.TextTransparency = 1
	tween(winnerTitleScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.2)
	tween(winnerTitle, 0.3, { TextTransparency = 0 }, nil, nil, 0.2)
	burstFlash()
	Sfx.play("level")
	task.delay(REVEAL_HOLD, settleReveal, token)
end

local function hideReveal()
	revealToken += 1
	revealRoot.Visible = false
	confetti.Visible = false
	hideEmote()
	releaseCamera()
end

local function presentParty(snapshot: CeremonySnapshot, entering: boolean, fromVoting: boolean)
	if not entering then
		fillYourLine(snapshot)
		return
	end
	revealToken += 1
	local token = revealToken
	if fromVoting then
		collapseBoard(token, function()
			startReveal(snapshot, token)
		end)
	else
		voteRoot.Visible = false
		clearBoard()
		startReveal(snapshot, token)
	end
end

-- Phases ----------------------------------------------------------------------

local function present(snapshot: CeremonySnapshot)
	local phaseKey = `{snapshot.roundId}:{snapshot.phase}`
	local entering = phaseKey ~= shownPhase
	local fromVoting = entering and string.sub(shownPhase, -7) == ":Voting" and voteRoot.Visible
	shownPhase = phaseKey

	screen.Enabled = snapshot.phase ~= "Idle"
	Fanfare.setHold("ceremony", snapshot.phase ~= "Idle")
	timeUp.Visible = snapshot.phase == "TimeUp"

	if snapshot.phase ~= "Showcase" then
		artistGui.Enabled = false
		artistPanel.Visible = false
		showcaseHeader.Visible = false
		hideFrame()
		clearAvatar()
		closeCase()
	end
	if snapshot.phase ~= "Voting" and snapshot.phase ~= "Party" then
		voteRoot.Visible = false
		clearBoard()
	end
	if snapshot.phase ~= "Party" then
		hideReveal()
	end

	if snapshot.phase == "Idle" then
		dim.Visible = false
		return
	end
	if snapshot.phase == "TimeUp" then
		dim.Visible = true
		dim.BackgroundTransparency = 0.45
		TattooCanvas.setVisible(false)
		return
	end
	if snapshot.phase == "Showcase" then
		dim.Visible = true
		dim.BackgroundTransparency = 0
		presentShowcase(snapshot)
		return
	end
	if snapshot.phase == "Voting" then
		if entering then
			lastTick = -1
			local ends = snapshot.phaseEnds
			voteSeconds = if ends ~= nil then math.max(1, ends - Workspace:GetServerTimeNow()) else 10
			Sfx.play("good")
		end
		presentVoting(snapshot)
		return
	end
	presentParty(snapshot, entering, fromVoting)
end

-- Build -----------------------------------------------------------------------

local function buildArtistPanel()
	artistGui = Instance.new("ScreenGui")
	artistGui.Name = "InkMastersArtist"
	artistGui.ResetOnSpawn = false
	artistGui.IgnoreGuiInset = true
	artistGui.DisplayOrder = 40
	artistGui.Enabled = false
	artistGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	artistGui.Parent = screen.Parent

	showcaseHeader = Instance.new("Frame")
	showcaseHeader.Name = "Header"
	showcaseHeader.BackgroundColor3 = UiTheme.color.ink
	showcaseHeader.BackgroundTransparency = 0
	showcaseHeader.Visible = false
	showcaseHeader.ZIndex = 8
	showcaseHeader.Parent = artistGui
	corner(showcaseHeader, 14)
	outline(showcaseHeader, UiTheme.color.stroke, 1)

	headerKicker = text(showcaseHeader, "ON DISPLAY", 13, UiTheme.font.bold, UiTheme.color.gold)
	headerKicker.Position = UDim2.fromOffset(18, 6)
	headerKicker.Size = UDim2.new(0.5, -24, 0, 16)
	headerKicker.TextXAlignment = Enum.TextXAlignment.Left
	headerKicker.ZIndex = 9

	headerIndex = text(showcaseHeader, "", 22, UiTheme.font.heavy, UiTheme.color.text)
	headerIndex.Position = UDim2.fromOffset(18, 20)
	headerIndex.Size = UDim2.new(0.5, -24, 0, 26)
	headerIndex.TextXAlignment = Enum.TextXAlignment.Left
	headerIndex.ZIndex = 9

	local track = Instance.new("Frame")
	track.Name = "Progress"
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, -16, 0.5, 0)
	track.Size = UDim2.new(0.38, 0, 0, 6)
	track.BackgroundColor3 = UiTheme.color.track
	track.BorderSizePixel = 0
	track.ZIndex = 9
	track.Parent = showcaseHeader
	corner(track, 3)
	progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = UiTheme.color.gold
	progressFill.BorderSizePixel = 0
	progressFill.ZIndex = 10
	progressFill.Parent = track
	corner(progressFill, 3)

	artistPanel = Instance.new("Frame")
	artistPanel.Name = "Artist"
	artistPanel.BackgroundColor3 = UiTheme.color.panel
	artistPanel.BackgroundTransparency = 0
	artistPanel.ClipsDescendants = true
	artistPanel.Visible = false
	artistPanel.ZIndex = 5
	artistPanel.Parent = artistGui
	corner(artistPanel, 18)
	panelStroke = outline(artistPanel, UiTheme.color.gold, 1.5)

	avatarView = Instance.new("ViewportFrame")
	avatarView.Name = "Avatar"
	avatarView.Size = UDim2.fromScale(1, 1)
	avatarView.BackgroundColor3 = Color3.fromRGB(18, 12, 20)
	avatarView.BackgroundTransparency = 0
	avatarView.Ambient = Color3.fromRGB(90, 70, 88)
	avatarView.LightColor = Color3.fromRGB(255, 214, 170)
	avatarView.LightDirection = Vector3.new(-0.35, -0.7, 0.55)
	avatarView.ZIndex = 5
	avatarView.Parent = artistPanel
	avatarWorld = Instance.new("WorldModel")
	avatarWorld.Parent = avatarView
	avatarCamera = Instance.new("Camera")
	avatarCamera.FieldOfView = 28
	avatarCamera.Parent = avatarView
	avatarView.CurrentCamera = avatarCamera

	local wash = Instance.new("Frame")
	wash.Name = "Wash"
	wash.AnchorPoint = Vector2.new(0, 1)
	wash.Position = UDim2.fromScale(0, 1)
	wash.Size = UDim2.new(1, 0, 0, 168)
	wash.BackgroundColor3 = UiTheme.color.ink
	wash.BorderSizePixel = 0
	wash.ZIndex = 6
	wash.Parent = artistPanel
	local washFade = Instance.new("UIGradient")
	washFade.Rotation = 90
	washFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.28, 0.35),
		NumberSequenceKeypoint.new(1, 0.08),
	})
	washFade.Parent = wash

	avatarMissing = text(artistPanel, "Artist left the studio", 16, UiTheme.font.medium, UiTheme.color.muted)
	avatarMissing.AnchorPoint = Vector2.new(0.5, 0.5)
	avatarMissing.Position = UDim2.fromScale(0.5, 0.42)
	avatarMissing.Size = UDim2.new(1, -24, 0, 24)
	avatarMissing.Visible = false
	avatarMissing.ZIndex = 7

	artistName = text(artistPanel, "", 32, UiTheme.font.heavy, UiTheme.color.text)
	artistName.AnchorPoint = Vector2.new(0, 1)
	artistName.Position = UDim2.new(0, 18, 1, -52)
	artistName.Size = UDim2.new(1, -36, 0, 38)
	artistName.TextXAlignment = Enum.TextXAlignment.Left
	artistName.TextScaled = true
	artistName.ZIndex = 7
	local nameCap = Instance.new("UITextSizeConstraint")
	nameCap.MaxTextSize = 32
	nameCap.Parent = artistName
	textStroke(artistName, 1.5)

	artistTitle = text(artistPanel, "", 14, UiTheme.font.bold, UiTheme.color.magenta)
	artistTitle.AnchorPoint = Vector2.new(0, 1)
	artistTitle.Position = UDim2.new(0, 18, 1, -32)
	artistTitle.Size = UDim2.new(1, -36, 0, 18)
	artistTitle.TextXAlignment = Enum.TextXAlignment.Left
	artistTitle.ZIndex = 7

	artistFooter = text(artistPanel, "", 13, UiTheme.font.medium, UiTheme.color.muted)
	artistFooter.AnchorPoint = Vector2.new(0, 1)
	artistFooter.Position = UDim2.new(0, 18, 1, -12)
	artistFooter.Size = UDim2.new(1, -36, 0, 16)
	artistFooter.TextXAlignment = Enum.TextXAlignment.Left
	artistFooter.ZIndex = 7

	frameDress = Instance.new("Frame")
	frameDress.Name = "FrameDress"
	frameDress.Active = false
	frameDress.Interactable = false
	frameDress.BackgroundTransparency = 1
	frameDress.Visible = false
	frameDress.ZIndex = 9
	frameDress.Parent = artistGui
end

local function buildVoteBoard()
	voteRoot = Instance.new("Frame")
	voteRoot.Name = "VoteBoard"
	voteRoot.Size = UDim2.fromScale(1, 1)
	voteRoot.BackgroundTransparency = 1
	voteRoot.Visible = false
	voteRoot.ZIndex = 10
	voteRoot.Parent = screen

	voteHeader = Instance.new("Frame")
	voteHeader.Name = "Header"
	voteHeader.AnchorPoint = Vector2.new(0.5, 0)
	voteHeader.Position = UDim2.new(0.5, 0, 0, UiTheme.safe.top + 6)
	voteHeader.Size = UDim2.fromOffset(640, 156)
	voteHeader.BackgroundTransparency = 1
	voteHeader.ZIndex = 10
	voteHeader.Parent = voteRoot

	local title = text(voteHeader, "VOTE", 36, UiTheme.font.heavy, UiTheme.color.gold)
	title.Size = UDim2.new(1, 0, 0, 40)
	title.ZIndex = 11
	textStroke(title, 2)

	local clock = Instance.new("Frame")
	clock.Name = "Clock"
	clock.AnchorPoint = Vector2.new(0.5, 0)
	clock.Position = UDim2.new(0.5, 0, 0, 44)
	clock.Size = UDim2.fromOffset(68, 68)
	clock.BackgroundColor3 = UiTheme.color.ink
	clock.ZIndex = 11
	clock.Parent = voteHeader
	corner(clock, 999)
	clockStroke = outline(clock, UiTheme.color.gold, 3)
	clockScale = Instance.new("UIScale")
	clockScale.Parent = clock
	clockLabel = text(clock, "10", 32, UiTheme.font.heavy, UiTheme.color.text)
	clockLabel.Size = UDim2.fromScale(1, 1)
	clockLabel.ZIndex = 12

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, 122)
	track.Size = UDim2.fromOffset(280, 6)
	track.BackgroundColor3 = UiTheme.color.track
	track.BorderSizePixel = 0
	track.ZIndex = 11
	track.Parent = voteHeader
	corner(track, 3)
	timerFill = Instance.new("Frame")
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = UiTheme.color.gold
	timerFill.BorderSizePixel = 0
	timerFill.ZIndex = 12
	timerFill.Parent = track
	corner(timerFill, 3)

	voteHint = text(voteHeader, "", 15, UiTheme.font.medium, UiTheme.color.text)
	voteHint.Position = UDim2.fromOffset(0, 134)
	voteHint.Size = UDim2.new(1, 0, 0, 20)
	voteHint.ZIndex = 11
	textStroke(voteHint, 1)

	board = Instance.new("Frame")
	board.Name = "Cards"
	board.AnchorPoint = Vector2.new(0.5, 0.5)
	board.BackgroundTransparency = 1
	board.ZIndex = 11
	board.Parent = voteRoot
	boardScale = Instance.new("UIScale")
	boardScale.Parent = board
	local rowsLayout = Instance.new("UIListLayout")
	rowsLayout.FillDirection = Enum.FillDirection.Vertical
	rowsLayout.Padding = UDim.new(0, CARD_GAP)
	rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowsLayout.Parent = board

	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if artistGui.Enabled then
			layoutShowcase()
		end
		if #cards > 0 then
			layoutBoard()
		end
	end)
end

local function buildEmote(parent: Instance)
	emoteRoot = Instance.new("Frame")
	emoteRoot.Name = "WinEmote"
	emoteRoot.Active = false
	emoteRoot.Interactable = false
	emoteRoot.AnchorPoint = Vector2.new(0.5, 1)
	emoteRoot.Position = UDim2.new(0.5, 0, 0, -4)
	emoteRoot.Size = UDim2.fromOffset(460, 100)
	emoteRoot.BackgroundTransparency = 1
	emoteRoot.Visible = false
	emoteRoot.ZIndex = 26
	emoteRoot.Parent = parent

	stamp = Instance.new("Frame")
	stamp.Name = "Stamp"
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Position = UDim2.fromScale(0.5, 0.55)
	stamp.Size = UDim2.fromOffset(280, 64)
	stamp.BackgroundTransparency = 1
	stamp.Visible = false
	stamp.ZIndex = 26
	stamp.Parent = emoteRoot
	corner(stamp, 32)
	stampStroke = outline(stamp, UiTheme.color.gold, 3)
	stampScale = Instance.new("UIScale")
	stampScale.Parent = stamp

	table.clear(sparks)
	for _ = 1, 8 do
		local spark = Instance.new("Frame")
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Size = UDim2.fromOffset(8, 8)
		spark.BackgroundColor3 = UiTheme.color.gold
		spark.BorderSizePixel = 0
		spark.Visible = false
		spark.ZIndex = 26
		spark.Rotation = 45
		spark.Parent = emoteRoot
		corner(spark, 2)
		table.insert(sparks, spark)
	end

	emoteHolder = Instance.new("Frame")
	emoteHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	emoteHolder.Position = UDim2.fromScale(0.5, 0.5)
	emoteHolder.Size = UDim2.new(1, -16, 1, 0)
	emoteHolder.BackgroundTransparency = 1
	emoteHolder.ZIndex = 27
	emoteHolder.Parent = emoteRoot
	emoteScale = Instance.new("UIScale")
	emoteScale.Parent = emoteHolder

	emoteLabel = text(emoteHolder, "", 64, UiTheme.font.heavy, UiTheme.color.gold)
	emoteLabel.Size = UDim2.fromScale(1, 1)
	emoteLabel.TextScaled = true
	emoteLabel.ZIndex = 27
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 64
	cap.MinTextSize = 22
	cap.Parent = emoteLabel
	textStroke(emoteLabel, 2)
end

local function buildReveal()
	revealRoot = Instance.new("Frame")
	revealRoot.Name = "Winner"
	revealRoot.Size = UDim2.fromScale(1, 1)
	revealRoot.BackgroundTransparency = 1
	revealRoot.Visible = false
	revealRoot.ZIndex = 20
	revealRoot.Parent = screen

	table.clear(rays)
	for index = 1, RAY_COUNT do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(70, 2400)
		ray.BackgroundColor3 = UiTheme.color.gold
		ray.BackgroundTransparency = 0.82
		ray.BorderSizePixel = 0
		ray.Rotation = (index - 1) * (180 / RAY_COUNT)
		ray.ZIndex = 20
		ray.Parent = revealRoot
		local taper = Instance.new("UIGradient")
		taper.Rotation = 90
		taper.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		taper.Parent = ray
		table.insert(rays, ray)
	end

	stack = Instance.new("Frame")
	stack.Name = "Stack"
	stack.AnchorPoint = Vector2.new(0.5, 0.5)
	stack.Position = UDim2.fromScale(0.5, 0.5)
	stack.Size = UDim2.fromOffset(STACK_W, STACK_H)
	stack.BackgroundTransparency = 1
	stack.ZIndex = 21
	stack.Parent = revealRoot
	stackScale = Instance.new("UIScale")
	stackScale.Parent = stack

	winnerTitle = text(stack, "WINNER", 64, UiTheme.font.heavy, UiTheme.color.gold)
	winnerTitle.Size = UDim2.new(1, 0, 0, 72)
	winnerTitle.ZIndex = 25
	textStroke(winnerTitle, 3)
	winnerTitleScale = Instance.new("UIScale")
	winnerTitleScale.Parent = winnerTitle

	winnerCard = Instance.new("Frame")
	winnerCard.Name = "Card"
	winnerCard.Position = UDim2.fromOffset(0, 80)
	winnerCard.Size = UDim2.new(1, 0, 1, -80)
	winnerCard.BackgroundColor3 = UiTheme.color.panel
	winnerCard.ZIndex = 22
	winnerCard.Parent = stack
	corner(winnerCard, 18)
	outline(winnerCard, UiTheme.color.gold, 3)
	winnerCardScale = Instance.new("UIScale")
	winnerCardScale.Parent = winnerCard

	winnerName = text(winnerCard, "", 34, UiTheme.font.heavy, UiTheme.color.text)
	winnerName.Position = UDim2.fromOffset(16, 14)
	winnerName.Size = UDim2.new(1, -32, 0, 40)
	winnerName.TextScaled = true
	winnerName.ZIndex = 23
	local nameCap = Instance.new("UITextSizeConstraint")
	nameCap.MaxTextSize = 34
	nameCap.Parent = winnerName

	winnerTag = text(winnerCard, "", 14, UiTheme.font.bold, UiTheme.color.magenta)
	winnerTag.Position = UDim2.fromOffset(16, 56)
	winnerTag.Size = UDim2.new(1, -32, 0, 18)
	winnerTag.ZIndex = 23

	winnerThumb = Instance.new("Frame")
	winnerThumb.Name = "Thumb"
	winnerThumb.Position = UDim2.fromOffset(16, 84)
	winnerThumb.Size = UDim2.new(1, -32, 0, 250)
	winnerThumb.BackgroundColor3 = UiTheme.color.ink
	winnerThumb.ClipsDescendants = true
	winnerThumb.ZIndex = 23
	winnerThumb.Parent = winnerCard

	winnerStats = text(winnerCard, "", 18, UiTheme.font.bold, UiTheme.color.gold)
	winnerStats.Position = UDim2.fromOffset(16, 342)
	winnerStats.Size = UDim2.new(1, -32, 0, 24)
	winnerStats.ZIndex = 23

	runnerRow = Instance.new("Frame")
	runnerRow.Name = "Runners"
	runnerRow.Position = UDim2.fromOffset(16, 372)
	runnerRow.Size = UDim2.new(1, -32, 0, 30)
	runnerRow.BackgroundTransparency = 1
	runnerRow.ZIndex = 23
	runnerRow.Parent = winnerCard
	local runnerLayout = Instance.new("UIListLayout")
	runnerLayout.FillDirection = Enum.FillDirection.Horizontal
	runnerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	runnerLayout.Padding = UDim.new(0, 8)
	runnerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	runnerLayout.Parent = runnerRow

	buildEmote(stack)

	yourLine = text(revealRoot, "", 16, UiTheme.font.bold, UiTheme.color.text)
	yourLine.AnchorPoint = Vector2.new(0.5, 1)
	yourLine.Position = UDim2.new(0.5, 0, 1, -UiTheme.safe.bottom - 8)
	yourLine.Size = UDim2.fromOffset(0, 34)
	yourLine.AutomaticSize = Enum.AutomaticSize.X
	yourLine.BackgroundColor3 = UiTheme.color.ink
	yourLine.BackgroundTransparency = 0.2
	yourLine.ZIndex = 24
	corner(yourLine, 999)
	local linePad = Instance.new("UIPadding")
	linePad.PaddingLeft = UDim.new(0, 16)
	linePad.PaddingRight = UDim.new(0, 16)
	linePad.Parent = yourLine
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
	local existingArtist = playerGui:FindFirstChild("InkMastersArtist")
	if existingArtist ~= nil then
		existingArtist:Destroy()
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

	confetti = Instance.new("Frame")
	confetti.Name = "Confetti"
	confetti.Active = false
	confetti.Size = UDim2.fromScale(1, 1)
	confetti.BackgroundTransparency = 1
	confetti.Visible = false
	confetti.ZIndex = 30
	confetti.Parent = screen
	table.clear(dots)
	for index = 1, 36 do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Size = UDim2.fromOffset(8, 14)
		dot.BackgroundColor3 = UiTheme.color.gold
		dot.BorderSizePixel = 0
		dot.Rotation = index * 18
		dot.ZIndex = 30
		dot.Parent = confetti
		corner(dot, 2)
		table.insert(dots, dot)
	end

	timeUp = text(screen, "Time's up!", 76, UiTheme.font.heavy, UiTheme.color.gold)
	timeUp.Name = "TimeUp"
	timeUp.AnchorPoint = Vector2.new(0.5, 0.5)
	timeUp.Position = UDim2.fromScale(0.5, 0.46)
	timeUp.Size = UDim2.fromOffset(720, 140)
	timeUp.Visible = false
	timeUp.ZIndex = 4
	textStroke(timeUp, 3)

	buildArtistPanel()
	buildVoteBoard()
	buildReveal()

	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Active = false
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Visible = false
	flash.ZIndex = 40
	flash.Parent = screen
end

local function stepConfetti(now: number)
	for index, dot in dots do
		local speed = 18 + (index % 5) * 7
		local travel = (now * speed + index * 37) % 120
		dot.Position = UDim2.new((index * 0.0277 + math.sin(now + index) * 0.01) % 1, 0, 0, -20 + travel * 9)
		dot.Rotation = index * 18 + now * (60 + index * 3)
	end
end

local Ceremony = {}
local started = false

function Ceremony.start()
	if started then
		return
	end
	started = true
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
				myVote = 0
			end
			if snapshot.yourVote ~= 0 then
				myVote = snapshot.yourVote
			end
		else
			myVote = 0
		end
		current = snapshot
		present(snapshot)
	end)

	RunService.Heartbeat:Connect(function()
		local snapshot = current
		if snapshot == nil then
			return
		end
		local now = os.clock()
		if snapshot.phase == "Showcase" then
			local index = showcaseIndex(snapshot)
			local entry = if index > 0 then snapshot.entries[index] else nil
			if entry ~= nil and designKey(entry) ~= presentedKey then
				present(snapshot)
			end
			local start = snapshot.showcaseStart
			if start ~= nil and snapshot.secondsEach > 0 then
				local elapsed = math.max(0, Workspace:GetServerTimeNow() - start)
				progressFill.Size =
					UDim2.fromScale(math.clamp((elapsed % snapshot.secondsEach) / snapshot.secondsEach, 0, 1), 1)
			end
			if avatarUserId ~= 0 then
				stepAvatar(now)
			end
		elseif snapshot.phase == "Voting" then
			stepClock(snapshot)
		end
		if revealRoot.Visible then
			for index, ray in rays do
				ray.Rotation = (index - 1) * (180 / RAY_COUNT) + now * 10
			end
		end
		if confetti.Visible then
			stepConfetti(now)
		end
		if emoteRoot.Visible then
			stepEmote(now)
		end
	end)
end

return Ceremony
