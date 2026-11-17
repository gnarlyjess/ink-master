--!strict

-- Stockroom hunt: pickup toasts, congrats, and hide other artists while hunting.
-- Instruction + timer live in RoundHud's slim top pill.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BlueprintArt = require(ReplicatedStorage.Shared.BlueprintArt)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundTypes = require(ReplicatedStorage.Shared.RoundTypes)
local FirstPerson = require(script.Parent.FirstPerson)
local Juice = require(script.Parent.Juice)
local Sfx = require(script.Parent.Sfx)
local Toasts = require(script.Parent.Toasts)
local UiTheme = require(script.Parent.UiTheme)

local PREFIX = "[InkRivalry]"
local HUNT_ATTR = "BlueprintHunting"
local LOOK_DOT = 0.78
local PROMPT_RANGE = 5.5
local localPlayer = Players.LocalPlayer

local started = false
local hunting = false
local found = 0
local total = 4
local firstPersonLocked = false
local congratsShown = false
local introDismissed = false
local hidden: { [Model]: { [BasePart]: number } } = {}
local pickedLocal: { [number]: boolean } = {}
local exampleGui: ScreenGui? = nil
local introGui: ScreenGui? = nil

local BlueprintHunt = {}

local function restoreCharacter(character: Model)
	local saved = hidden[character]
	if saved == nil then
		return
	end
	for part, value in saved do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = value
		end
	end
	hidden[character] = nil
end

local function hideCharacter(character: Model)
	if hidden[character] ~= nil then
		return
	end
	local saved: { [BasePart]: number } = {}
	for _, desc in character:GetDescendants() do
		if desc:IsA("BasePart") then
			saved[desc] = desc.LocalTransparencyModifier
			desc.LocalTransparencyModifier = 1
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Transparency = 1
		elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
			desc.Enabled = false
		end
	end
	hidden[character] = saved
end

local function shouldHideOther(other: Player): boolean
	if other == localPlayer then
		return false
	end
	-- While I'm hunting, nobody else is visible.
	if hunting or localPlayer:GetAttribute(HUNT_ATTR) == true then
		return true
	end
	-- Waiting in the lobby: hide artists still in the stockroom.
	return other:GetAttribute(HUNT_ATTR) == true
end

local function refreshVisibility()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character == nil then
			continue
		end
		if shouldHideOther(player) then
			hideCharacter(character)
		else
			restoreCharacter(character)
		end
	end
end

local function blueprintFolder(): Folder?
	local room = Workspace:FindFirstChild("Stockroom")
	if room == nil then
		return nil
	end
	local folder = room:FindFirstChild("Blueprints")
	if folder == nil or not folder:IsA("Folder") then
		return nil
	end
	return folder
end

local function hidePickedLocally(index: number)
	pickedLocal[index] = true
	local folder = blueprintFolder()
	if folder == nil then
		return
	end
	local part = folder:FindFirstChild(`Blueprint{index}`)
	if part == nil or not part:IsA("BasePart") then
		return
	end
	part.LocalTransparencyModifier = 1
	for _, desc in part:GetDescendants() do
		if desc:IsA("SurfaceGui") or desc:IsA("BillboardGui") or desc:IsA("ProximityPrompt") then
			desc.Enabled = false
		end
	end
end

local function resetBlueprintVisuals()
	table.clear(pickedLocal)
	local folder = blueprintFolder()
	if folder == nil then
		return
	end
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 0
			for _, desc in part:GetDescendants() do
				if desc:IsA("SurfaceGui") or desc:IsA("BillboardGui") then
					desc.Enabled = true
				elseif desc:IsA("ProximityPrompt") then
					desc.MaxActivationDistance = 0
				end
			end
		end
	end
end

-- Only show E when close and looking straight at the paper (won't leak from across the aisle).
local function updatePromptLook()
	local folder = blueprintFolder()
	local camera = Workspace.CurrentCamera
	if folder == nil or camera == nil then
		return
	end
	local camPos = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local huntingNow = hunting or localPlayer:GetAttribute(HUNT_ATTR) == true
	for _, part in folder:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		local index = part:GetAttribute("BlueprintIndex")
		local prompt = part:FindFirstChild("Collect", true)
		if typeof(index) ~= "number" or prompt == nil or not prompt:IsA("ProximityPrompt") then
			continue
		end
		if not huntingNow or pickedLocal[math.floor(index)] == true then
			prompt.MaxActivationDistance = 0
			continue
		end
		local target = part:FindFirstChild("PromptSensor")
		local aimAt = if target ~= nil and target:IsA("BasePart") then target.Position else part.Position
		local delta = aimAt - camPos
		local dist = delta.Magnitude
		if dist < 0.05 or dist > PROMPT_RANGE or look:Dot(delta.Unit) < LOOK_DOT then
			prompt.MaxActivationDistance = 0
			continue
		end
		prompt.MaxActivationDistance = PROMPT_RANGE
	end
end

local function setExampleVisible(on: boolean)
	if exampleGui ~= nil then
		exampleGui.Enabled = on
	end
end

local function setIntroVisible(on: boolean)
	if introGui ~= nil then
		introGui.Enabled = on
	end
end

local function syncHuntChrome()
	-- Intro owns the screen until dismissed; then the side ref stays up.
	local showIntro = hunting and not introDismissed
	local showRef = hunting and introDismissed
	setIntroVisible(showIntro)
	setExampleVisible(showRef)
end

local function dismissIntro()
	if introDismissed then
		return
	end
	introDismissed = true
	syncHuntChrome()
	pcall(function()
		Sfx.play("click")
	end)
end

local function showMachineBuiltPopup(bonusSeconds: number)
	if congratsShown then
		return
	end
	congratsShown = true

	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		playerGui = localPlayer:WaitForChild("PlayerGui", 3) :: PlayerGui?
	end
	if playerGui == nil then
		warn(`{PREFIX} Congrats popup skipped — no PlayerGui`)
		congratsShown = false
		return
	end
	local existing = playerGui:FindFirstChild("BlueprintMachineFanfare")
	if existing ~= nil then
		existing:Destroy()
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "BlueprintMachineFanfare"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 120
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.fromRGB(10, 4, 22)
	dim.BackgroundTransparency = 1
	dim.Size = UDim2.fromScale(1, 1)
	dim.BorderSizePixel = 0
	dim.ZIndex = 1
	dim.Parent = screen

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(340, 200)
	card.BackgroundColor3 = UiTheme.color.panel
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.ZIndex = 2
	card.Parent = dim
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = UiTheme.color.gold
	stroke.Thickness = 2.5
	stroke.Transparency = 0.1
	stroke.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = 0.72
	scale.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 20)
	pad.PaddingBottom = UDim.new(0, 20)
	pad.PaddingLeft = UDim.new(0, 22)
	pad.PaddingRight = UDim.new(0, 22)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.Parent = card

	local kicker = Instance.new("TextLabel")
	kicker.BackgroundTransparency = 1
	kicker.Size = UDim2.new(1, 0, 0, 16)
	kicker.FontFace = UiTheme.font.heavy
	kicker.TextSize = 12
	kicker.TextColor3 = UiTheme.color.sunshine
	kicker.Text = "BLUEPRINT SET CLEAR"
	kicker.ZIndex = 3
	kicker.Parent = card

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 60)
	title.FontFace = UiTheme.font.heavy
	title.TextSize = 24
	title.TextColor3 = UiTheme.color.text
	title.TextWrapped = true
	title.Text = "Congrats! You built your tattoo machine!"
	title.ZIndex = 3
	title.Parent = card

	local detail = Instance.new("TextLabel")
	detail.BackgroundTransparency = 1
	detail.Size = UDim2.new(1, 0, 0, 40)
	detail.FontFace = UiTheme.font.bold
	detail.TextSize = 15
	detail.TextColor3 = UiTheme.color.aqua
	detail.TextWrapped = true
	detail.Text = `+{bonusSeconds}s design time on every tattoo round`
	detail.ZIndex = 3
	detail.Parent = card

	local pop = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local fade = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(dim, fade, { BackgroundTransparency = 0.35 }):Play()
	TweenService:Create(scale, pop, { Scale = 1 }):Play()
	pcall(function()
		Sfx.play("good")
	end)
	task.defer(function()
		pcall(function()
			Juice.confetti(dim, Vector2.new(0.5, 0.42), 28, 1.0)
		end)
	end)

	-- ~5s on screen, then fade before / as lobby TP lands.
	task.delay(5.0, function()
		if screen.Parent == nil then
			return
		end
		TweenService:Create(dim, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(card, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(scale, fade, { Scale = 0.9 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		task.delay(0.32, function()
			if screen.Parent ~= nil then
				screen:Destroy()
			end
		end)
	end)
end

local function onBlueprintPayload(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	if typeof(payload.found) == "number" then
		found = math.floor(payload.found)
	end
	if typeof(payload.total) == "number" and payload.total > 0 then
		total = math.floor(payload.total)
	end
	if typeof(payload.hunting) == "boolean" then
		hunting = payload.hunting
	end
	if typeof(payload.picked) == "number" then
		hidePickedLocally(math.floor(payload.picked))
	end
	refreshVisibility()
	-- Intro / side ref follow hunting; hide both once you're waiting in the parlour.
	syncHuntChrome()

	local bonus = if typeof(payload.bonusSeconds) == "number" then payload.bonusSeconds else 10
	local isComplete = payload.congrats == true or payload.complete == true or (total > 0 and found >= total)
	if isComplete and not congratsShown then
		pcall(function()
			Toasts.show(`Blueprint {found}/{total}`, "ok")
		end)
		showMachineBuiltPopup(bonus)
		print(`{PREFIX} Blueprint set complete | +{bonus}s`)
	elseif typeof(payload.picked) == "number" and not isComplete then
		pcall(function()
			Toasts.show(`Blueprint {found}/{total}`, "info")
		end)
	end
end

local function setFirstPersonLocked(on: boolean)
	-- Lobby studio stays first-person too — reinforce free-cursor FP walk.
	firstPersonLocked = on
	FirstPerson.apply(localPlayer)
end

local function buildExampleGui()
	local screen = Instance.new("ScreenGui")
	screen.Name = "BlueprintExample"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 26
	screen.Enabled = false
	screen.Parent = localPlayer:WaitForChild("PlayerGui")

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(1, 0)
	-- Top-right, just under the CoreGui inset — clear of the centre hunt line.
	local top = math.max(UiTheme.safe.top, GuiService:GetGuiInset().Y + 8)
	card.Position = UDim2.new(1, -UiTheme.safe.side, 0, top)
	card.Size = UDim2.fromOffset(132, 158)
	card.BackgroundColor3 = UiTheme.color.panel
	card.BackgroundTransparency = 0.12
	card.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = BlueprintArt.line()
	stroke.Thickness = 1.2
	stroke.Transparency = 0.35
	stroke.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = card

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card

	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.new(1, 0, 0, 14)
	caption.FontFace = UiTheme.font.bold
	caption.Text = "LOOK FOR"
	caption.TextSize = 11
	caption.TextColor3 = UiTheme.color.muted
	caption.LayoutOrder = 1
	caption.Parent = card

	local sheet = Instance.new("Frame")
	sheet.Name = "Sheet"
	sheet.Size = UDim2.fromOffset(108, 86)
	sheet.BorderSizePixel = 0
	sheet.LayoutOrder = 2
	sheet.Parent = card
	BlueprintArt.paint(sheet, 1)

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, 0, 0, 28)
	hint.FontFace = UiTheme.font.medium
	hint.Text = "Blue sheets with\nwhite diagrams"
	hint.TextSize = 11
	hint.TextColor3 = UiTheme.color.text
	hint.TextWrapped = true
	hint.LayoutOrder = 3
	hint.Parent = card

	exampleGui = screen
end

local function buildIntroGui()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "BlueprintHuntIntro"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 55
	screen.Enabled = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.BackgroundColor3 = Color3.fromRGB(8, 4, 18)
	dim.BackgroundTransparency = 0.35
	dim.Size = UDim2.fromScale(1, 1)
	dim.BorderSizePixel = 0
	dim.ZIndex = 1
	dim.Parent = screen

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(380, 410)
	card.BackgroundColor3 = UiTheme.color.panel
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.ZIndex = 2
	card.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 20)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = BlueprintArt.line()
	stroke.Thickness = 2
	stroke.Transparency = 0.25
	stroke.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 22)
	pad.PaddingBottom = UDim.new(0, 28)
	pad.PaddingLeft = UDim.new(0, 24)
	pad.PaddingRight = UDim.new(0, 24)
	pad.Parent = card

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card

	local kicker = Instance.new("TextLabel")
	kicker.BackgroundTransparency = 1
	kicker.Size = UDim2.new(1, 0, 0, 16)
	kicker.FontFace = UiTheme.font.heavy
	kicker.TextSize = 12
	kicker.TextColor3 = UiTheme.color.sunshine
	kicker.Text = "STOCKROOM HUNT"
	kicker.LayoutOrder = 1
	kicker.ZIndex = 3
	kicker.Parent = card

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 52)
	title.FontFace = UiTheme.font.heavy
	title.TextSize = 24
	title.TextColor3 = UiTheme.color.text
	title.TextWrapped = true
	title.Text = "Find all 4 blueprints"
	title.LayoutOrder = 2
	title.ZIndex = 3
	title.Parent = card

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 0, 48)
	body.FontFace = UiTheme.font.medium
	body.TextSize = 15
	body.TextColor3 = UiTheme.color.muted
	body.TextWrapped = true
	body.Text =
		"Search the shelves for blue sheets with white diagrams. Collect every piece to build your tattoo machine and earn extra design time."
	body.LayoutOrder = 3
	body.ZIndex = 3
	body.Parent = card

	local sheetWrap = Instance.new("Frame")
	sheetWrap.Name = "SheetWrap"
	sheetWrap.BackgroundColor3 = UiTheme.color.chip
	sheetWrap.BackgroundTransparency = 0.35
	sheetWrap.Size = UDim2.fromOffset(220, 168)
	sheetWrap.BorderSizePixel = 0
	sheetWrap.LayoutOrder = 4
	sheetWrap.ZIndex = 3
	sheetWrap.Parent = card
	local sheetCorner = Instance.new("UICorner")
	sheetCorner.CornerRadius = UDim.new(0, 12)
	sheetCorner.Parent = sheetWrap
	local sheetPad = Instance.new("UIPadding")
	sheetPad.PaddingTop = UDim.new(0, 10)
	sheetPad.PaddingBottom = UDim.new(0, 10)
	sheetPad.PaddingLeft = UDim.new(0, 10)
	sheetPad.PaddingRight = UDim.new(0, 10)
	sheetPad.Parent = sheetWrap

	local sheet = Instance.new("Frame")
	sheet.Name = "Sheet"
	sheet.AnchorPoint = Vector2.new(0.5, 0.5)
	sheet.Position = UDim2.fromScale(0.5, 0.5)
	sheet.Size = UDim2.fromOffset(200, 148)
	sheet.BorderSizePixel = 0
	sheet.ZIndex = 4
	sheet.Parent = sheetWrap
	BlueprintArt.paint(sheet, 1)

	local go = Instance.new("TextButton")
	go.Name = "Go"
	go.AutoButtonColor = true
	go.Size = UDim2.fromOffset(200, 44)
	go.BackgroundColor3 = UiTheme.color.aqua
	go.BorderSizePixel = 0
	go.FontFace = UiTheme.font.heavy
	go.TextSize = 16
	go.TextColor3 = UiTheme.color.ink
	go.Text = "Got it — let's hunt"
	go.Modal = true
	go.LayoutOrder = 5
	go.ZIndex = 5
	go.Parent = card
	local goCorner = Instance.new("UICorner")
	goCorner.CornerRadius = UDim.new(0, 12)
	goCorner.Parent = go

	go.MouseButton1Click:Connect(dismissIntro)
	dim.MouseButton1Click:Connect(dismissIntro)

	introGui = screen
end

local function onRound(payload: any)
	local snapshot = RoundTypes.readSnapshot(payload)
	if snapshot == nil then
		return
	end
	local inHunt = snapshot.state == "BlueprintHunt"
	if not inHunt then
		hunting = false
		found = 0
		congratsShown = false
		introDismissed = false
		setIntroVisible(false)
		setExampleVisible(false)
		setFirstPersonLocked(false)
		resetBlueprintVisuals()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character ~= nil then
				restoreCharacter(character)
			end
		end
		return
	end
	hunting = localPlayer:GetAttribute(HUNT_ATTR) == true
	congratsShown = false
	introDismissed = false
	setFirstPersonLocked(true)
	syncHuntChrome()
	-- Always clear local hide state — server just moved sheets to new nests.
	found = 0
	resetBlueprintVisuals()
	refreshVisibility()
end

function BlueprintHunt.start()
	if started then
		return
	end
	started = true
	buildExampleGui()
	buildIntroGui()

	Remotes.BlueprintStateUpdated.OnClientEvent:Connect(onBlueprintPayload)
	Remotes.RoundStateUpdated.OnClientEvent:Connect(onRound)

	Players.PlayerAdded:Connect(function(player: Player)
		player:GetAttributeChangedSignal(HUNT_ATTR):Connect(refreshVisibility)
		player.CharacterAdded:Connect(function()
			task.defer(refreshVisibility)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player:GetAttributeChangedSignal(HUNT_ATTR):Connect(refreshVisibility)
		player.CharacterAdded:Connect(function()
			task.defer(refreshVisibility)
		end)
	end
	localPlayer:GetAttributeChangedSignal(HUNT_ATTR):Connect(function()
		hunting = localPlayer:GetAttribute(HUNT_ATTR) == true
		if not hunting then
			setIntroVisible(false)
			setFirstPersonLocked(false)
		end
		syncHuntChrome()
		refreshVisibility()
	end)

	local accum = 0
	RunService.Heartbeat:Connect(function(dt: number)
		updatePromptLook()
		accum += dt
		if accum < 0.4 then
			return
		end
		accum = 0
		if hunting or localPlayer:GetAttribute(HUNT_ATTR) == true then
			refreshVisibility()
		end
	end)

	Remotes.RequestRoundSnapshot:FireServer()
end

return BlueprintHunt
