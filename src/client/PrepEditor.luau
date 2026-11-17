--!strict

-- Prep station: pick a limb, soap dirt, wipe, shave. Tool cursor follows the pointer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Prefer InputObject.Position (gui event space); else GetMouseLocation.
-- pointerFix then locks tip AbsolutePosition / stroke UVs onto that pointer.
local function pointerScreen(input: InputObject?): Vector2
	if input ~= nil then
		local pos = input.Position
		if typeof(pos) == "Vector3" then
			return Vector2.new(pos.X, pos.Y)
		end
	end
	return UserInputService:GetMouseLocation()
end

local BodyRegions = require(ReplicatedStorage.Shared.BodyRegions)
local PrepTypes = require(ReplicatedStorage.Shared.PrepTypes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundTypes = require(ReplicatedStorage.Shared.RoundTypes)
local Juice = require(script.Parent.Juice)
local PrepPaint = require(script.Parent.PrepPaint)
local Sfx = require(script.Parent.Sfx)
local TattooCanvas = require(script.Parent.TattooCanvas)
local UiTheme = require(script.Parent.UiTheme)

type PrepView = PrepTypes.PrepView
type PrepTool = PrepTypes.PrepTool

local PREFIX = "[InkRivalry]"
local TOOLS: { { id: PrepTool, label: string, color: Color3 } } = {
	{ id = "soap", label = "Soap", color = Color3.fromRGB(255, 214, 64) },
	{ id = "cloth", label = "Cloth", color = Color3.fromRGB(64, 220, 255) },
	{ id = "razor", label = "Razor", color = Color3.fromRGB(200, 210, 220) },
}

local PrepEditor = {}

local started = false
local open = false
local screenGui: ScreenGui? = nil
local current: PrepView? = nil
local lockedRegion: string? = nil
local lastResidue: PrepView? = nil
local residueHairImage: EditableImage? = nil
local residueDirtImage: EditableImage? = nil

local dirtLayer: Frame? = nil
local hairLayer: Frame? = nil
local strokeCatcher: TextButton? = nil
local cursor: Frame? = nil
local stepsHost: Frame? = nil
local stepLabels: { TextLabel } = {}
local statusLabel: TextLabel? = nil
local toolButtons: { [string]: TextButton } = {}
local limbButtons: { [string]: TextButton } = {}
local stroking = false
local strokeConn: RBXScriptConnection? = nil
local cursorConn: RBXScriptConnection? = nil
local catcherConns: { RBXScriptConnection } = {}
local lastShownRegion: string? = nil
local lastFoamAt = 0
local lastStrokeFire = 0
local lastDirtPaintAt = 0
local dirtPaintPending = false
local STROKE_INTERVAL = 0.08
local DIRT_PAINT_INTERVAL = 0.12
local lastHairPaintKey = ""
local lastDirtPaintKey = ""
local toolOverride: PrepTool? = nil
-- Accumulated screen→board correction so tip AbsolutePosition stays on the pointer.
local pointerFix = Vector2.zero

local function fire(kind: string, extra: { [string]: any }?)
	local payload: { [string]: any } = { kind = kind }
	if extra ~= nil then
		for key, value in extra do
			payload[key] = value
		end
	end
	Remotes.PrepAction:FireServer(payload)
end

function PrepEditor.getLockedRegion(): string?
	return lockedRegion or (if current ~= nil then current.regionId else nil)
end

function PrepEditor.getResidue(): PrepView?
	return lastResidue
end

function PrepEditor.getResidueImages(): (EditableImage?, EditableImage?)
	return residueHairImage, residueDirtImage
end

local function hintFor(view: PrepView): string
	if view.tool == "soap" then
		return "Soap dirt — wipe it after with cloth"
	elseif view.tool == "cloth" then
		return "Wipe soaped dirt (soap first)"
	elseif view.tool == "razor" then
		return "Shave anytime — leftovers stay on the limb"
	end
	return "Ready for ink — leftovers stay"
end

local function rememberResidue(view: PrepView)
	lastResidue = PrepTypes.cloneView(view)
end

local function spawnBubble(parent: GuiObject, x: number, y: number, scale: number?)
	local s = scale or 1
	local bubble = Instance.new("Frame")
	bubble.BackgroundColor3 = Color3.fromRGB(255, 252, 255)
	bubble.BackgroundTransparency = 0.15
	bubble.BorderSizePixel = 0
	bubble.Size = UDim2.fromOffset(math.floor(8 * s), math.floor(8 * s))
	bubble.AnchorPoint = Vector2.new(0.5, 0.5)
	bubble.Position = UDim2.fromScale(x, y)
	bubble.ZIndex = 22
	bubble.Active = false
	bubble.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bubble
	local highlight = Instance.new("Frame")
	highlight.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	highlight.BackgroundTransparency = 0.35
	highlight.Size = UDim2.fromScale(0.4, 0.4)
	highlight.Position = UDim2.fromScale(0.15, 0.12)
	highlight.BorderSizePixel = 0
	highlight.ZIndex = 23
	highlight.Parent = bubble
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(1, 0)
	hc.Parent = highlight
	TweenService:Create(bubble, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.05, y - 0.05 - math.random() * 0.04),
		Size = UDim2.fromOffset(math.floor(3 * s), math.floor(3 * s)),
		BackgroundTransparency = 1,
	}):Play()
	task.delay(0.7, function()
		bubble:Destroy()
	end)
end

local function spawnFoamBurst(parent: GuiObject, x: number, y: number, radius: number)
	for i = 1, 6 do
		local ang = (i / 6) * math.pi * 2 + math.random() * 0.35
		local dist = math.random() * radius
		spawnBubble(parent, x + math.cos(ang) * dist, y + math.sin(ang) * dist * 0.85, 0.9 + math.random())
	end
end

local function spawnSpray(parent: GuiObject, x: number, y: number)
	for _ = 1, 6 do
		local drop = Instance.new("Frame")
		drop.BackgroundColor3 = Color3.fromRGB(120, 220, 255)
		drop.BackgroundTransparency = 0.15
		drop.BorderSizePixel = 0
		drop.Size = UDim2.fromOffset(6, 6)
		drop.AnchorPoint = Vector2.new(0.5, 0.5)
		drop.Position = UDim2.fromScale(x, y)
		drop.ZIndex = 22
		drop.Active = false
		drop.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = drop
		local ox = (math.random() - 0.5) * 0.08
		local oy = (math.random() - 0.5) * 0.08
		TweenService:Create(drop, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(x + ox, y + oy),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(2, 2),
		}):Play()
		task.delay(0.4, function()
			drop:Destroy()
		end)
	end
end

local function clearKids(frame: Frame?)
	if frame == nil then
		return
	end
	for _, child in frame:GetChildren() do
		child:Destroy()
	end
end

local function dirtPaintKey(view: PrepView): string
	local parts = table.create(#view.dirt)
	for i, patch in view.dirt do
		parts[i] = `{patch.id}:{if patch.cleared then 2 elseif patch.soaped then 1 else 0}`
	end
	return table.concat(parts, ",")
end

local function hairPaintKey(view: PrepView): string
	return `{view.regionId}:{view.hairCols}x{view.hairRows}:{view.hairLeft}`
end

local function renderFrameHair(view: PrepView, hair: Frame)
	clearKids(hair)
	local cols = view.hairCols
	local rows = view.hairRows
	for row = 1, rows do
		for col = 1, cols do
			local index = (row - 1) * cols + col
			if view.hair[index] == nil or view.hair[index] < 0.5 then
				continue
			end
			local cx = (col - 0.5) / cols
			local cy = (row - 0.5) / rows
			local strand = Instance.new("Frame")
			strand.BackgroundColor3 = Color3.fromRGB(28, 16, 12)
			strand.BackgroundTransparency = 0.2
			strand.BorderSizePixel = 0
			strand.AnchorPoint = Vector2.new(0.5, 0)
			strand.Position = UDim2.fromScale(cx, cy)
			strand.Size = UDim2.fromScale(0.14 / cols, 1.15 / rows)
			strand.Rotation = ((col * 17 + row * 13) % 40) - 20
			strand.ZIndex = 2
			strand.Active = false
			strand.Parent = hair
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = strand
		end
	end
end

local function renderFrameDirt(view: PrepView, dirt: Frame)
	clearKids(dirt)
	for _, patch in view.dirt do
		if patch.cleared then
			continue
		end
		local blot = Instance.new("Frame")
		blot.AnchorPoint = Vector2.new(0.5, 0.5)
		blot.Position = UDim2.fromScale(patch.x, patch.y)
		blot.Size = UDim2.fromScale(patch.r * 2.4, patch.r * 2.4)
		blot.BackgroundColor3 = if patch.soaped then Color3.fromRGB(210, 195, 150) else Color3.fromRGB(58, 36, 24)
		blot.BackgroundTransparency = if patch.soaped then 0.32 else 0.22
		blot.BorderSizePixel = 0
		blot.ZIndex = 3
		blot.Active = false
		blot.Parent = dirt
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = blot
	end
end

local function renderOverlays(view: PrepView, forceHair: boolean, forceDirt: boolean)
	local dirt = dirtLayer
	local hair = hairLayer
	if dirt == nil or hair == nil then
		return
	end
	local hKey = hairPaintKey(view)
	local dKey = dirtPaintKey(view)
	local needHair = forceHair or hKey ~= lastHairPaintKey
	local needDirt = forceDirt or dKey ~= lastDirtPaintKey
	if not needHair and not needDirt then
		return
	end

	local patches: { PrepPaint.DirtPatch } = {}
	for _, patch in view.dirt do
		table.insert(patches, patch)
	end
	local ok = PrepPaint.sync(hair, dirt, view.hair, view.hairCols, view.hairRows, view.hairLeft, patches, view.regionId)
	if ok then
		if needHair then
			lastHairPaintKey = hKey
		end
		if needDirt then
			lastDirtPaintKey = dKey
		end
		return
	end

	-- Fallback if EditableImage APIs are off.
	if needHair then
		lastHairPaintKey = hKey
		renderFrameHair(view, hair)
	end
	if needDirt then
		lastDirtPaintKey = dKey
		renderFrameDirt(view, dirt)
	end
end

local function updateSteps(view: PrepView)
	-- Progress chips only — tools are free; dirt wipe still needs soap first.
	local needsSoap = false
	local needsWipe = false
	for _, patch in view.dirt do
		if not patch.cleared and not patch.soaped then
			needsSoap = true
		end
		if not patch.cleared and patch.soaped then
			needsWipe = true
		end
	end
	local needsShave = view.hairLeft > 0
	local states = {
		{ remaining = needsSoap, selected = view.tool == "soap" },
		{ remaining = needsWipe, selected = view.tool == "cloth" },
		{ remaining = needsShave, selected = view.tool == "razor" },
	}
	for i, label in stepLabels do
		local state = states[i]
		local on = state ~= nil and state.selected
		local remaining = state ~= nil and state.remaining
		label.TextColor3 = if on then UiTheme.color.ink elseif remaining then UiTheme.color.text else UiTheme.color.gold
		label.BackgroundColor3 = if on then UiTheme.color.gold elseif remaining then UiTheme.color.chip else Color3.fromRGB(60, 50, 40)
		label.BackgroundTransparency = if on then 0 else 0.15
		label.FontFace = if on then UiTheme.font.heavy else UiTheme.font.medium
	end
end

local function updateChrome(view: PrepView)
	if statusLabel ~= nil then
		statusLabel.Text = hintFor(view)
	end
	updateSteps(view)
	for _, tool in TOOLS do
		local button = toolButtons[tool.id]
		if button == nil then
			continue
		end
		local selected = view.tool == tool.id
		button.Active = true
		button.AutoButtonColor = true
		button.BackgroundColor3 = if selected then tool.color else UiTheme.color.chip
		button.TextColor3 = if selected then UiTheme.color.ink else UiTheme.color.text
		button.BackgroundTransparency = if selected then 0 else 0.12
	end
	for _, region in BodyRegions.all do
		local button = limbButtons[region.id]
		if button == nil then
			continue
		end
		local selected = view.regionId == region.id
		button.BackgroundColor3 = if selected then UiTheme.color.aqua else UiTheme.color.chip
		button.TextColor3 = if selected then UiTheme.color.ink else UiTheme.color.text
		button.FontFace = if selected then UiTheme.font.heavy else UiTheme.font.medium
	end
	if cursor ~= nil then
		local color = UiTheme.color.gold
		for _, tool in TOOLS do
			if tool.id == view.tool then
				color = tool.color
				break
			end
		end
		cursor.BackgroundColor3 = color
		local label = cursor:FindFirstChild("Label")
		if label ~= nil and label:IsA("TextLabel") then
			label.Text = if view.tool == "soap" then "🧼" elseif view.tool == "cloth" then "🧴" else "🪒"
		end
	end
end

local function boardLocalFromScreen(screenPos: Vector2): (number?, number?, number?, number?)
	local board = dirtLayer and dirtLayer.Parent
	if board == nil or not board:IsA("GuiObject") then
		return nil, nil, nil, nil
	end
	local abs = board.AbsolutePosition
	local size = board.AbsoluteSize
	if size.X < 2 or size.Y < 2 then
		return nil, nil, nil, nil
	end
	local lx = screenPos.X - abs.X + pointerFix.X
	local ly = screenPos.Y - abs.Y + pointerFix.Y
	if lx < 0 or ly < 0 or lx > size.X or ly > size.Y then
		return nil, nil, nil, nil
	end
	return lx, ly, lx / size.X, ly / size.Y
end

local function canvasPoint(screenPos: Vector2): (number?, number?)
	local _, _, x, y = boardLocalFromScreen(screenPos)
	return x, y
end

local function moveCursor(screenPos: Vector2, pressed: boolean)
	local tip = cursor
	local board = dirtLayer and dirtLayer.Parent
	if tip == nil or board == nil or not board:IsA("GuiObject") then
		return
	end
	local lx, ly = boardLocalFromScreen(screenPos)
	local over = lx ~= nil and ly ~= nil
	tip.Visible = over and open
	-- Tool tip only on the limb — restore the normal cursor over soap/cloth/razor UI.
	if open then
		UserInputService.MouseIconEnabled = not over
	end
	if over and lx ~= nil and ly ~= nil then
		tip.Position = UDim2.fromOffset(lx, ly)
		local scale = tip:FindFirstChildOfClass("UIScale")
		if scale ~= nil then
			scale.Scale = if pressed then 0.92 else 1
		end
		-- Lock tip AbsolutePosition to the pointer; feed the same fix into stroke UVs.
		local center = tip.AbsolutePosition + tip.AbsoluteSize * 0.5
		local err = screenPos - center
		if err.Magnitude >= 1 then
			pointerFix += err
			tip.Position = UDim2.fromOffset(lx + err.X, ly + err.Y)
		end
	end
end

local function ensureCursorLoop()
	if cursorConn ~= nil then
		return
	end
	cursorConn = RunService.RenderStepped:Connect(function()
		if not open then
			return
		end
		moveCursor(pointerScreen(nil), stroking)
	end)
end

local function stopCursorLoop()
	if cursorConn ~= nil then
		cursorConn:Disconnect()
		cursorConn = nil
	end
end

local function flushDirtPaint()
	if not dirtPaintPending or current == nil then
		return
	end
	dirtPaintPending = false
	lastDirtPaintAt = os.clock()
	renderOverlays(current, false, true)
	updateChrome(current)
	rememberResidue(current)
end

local function strokeAt(screenPos: Vector2)
	local x, y = canvasPoint(screenPos)
	if x == nil or y == nil or current == nil then
		return
	end
	moveCursor(screenPos, true)

	local now = os.clock()
	local board = dirtLayer
	-- Juice can tick a bit more often than the networked stroke.
	if board ~= nil and now - lastFoamAt > 0.05 then
		lastFoamAt = now
		if current.tool == "soap" then
			spawnBubble(board, x, y, 1)
			local hits = PrepTypes.hitDirt(current.dirt, x, y, PrepTypes.SOAP_RADIUS)
			for _, patch in hits do
				spawnFoamBurst(board, patch.x, patch.y, patch.r * 1.2)
			end
		elseif current.tool == "cloth" then
			spawnSpray(board, x, y)
		end
	end

	local dirtChanged = false
	if current.tool == "soap" then
		local hits = PrepTypes.hitDirt(current.dirt, x, y, PrepTypes.SOAP_RADIUS)
		for _, patch in hits do
			if not patch.soaped then
				patch.soaped = true
				dirtChanged = true
			end
		end
	elseif current.tool == "cloth" then
		local hits = PrepTypes.hitDirt(current.dirt, x, y, PrepTypes.CLOTH_RADIUS)
		for _, patch in hits do
			if patch.soaped and not patch.cleared then
				patch.cleared = true
				dirtChanged = true
			end
		end
	end
	if dirtChanged then
		current.dirtyLeft = PrepTypes.countDirtLeft(current.dirt)
		current.step = PrepTypes.currentStep(current.dirt, current.hair)
		dirtPaintPending = true
		rememberResidue(current)
		-- Full dirt re-stamp is expensive — debounce so tool clicks stay responsive.
		if now - lastDirtPaintAt >= DIRT_PAINT_INTERVAL then
			flushDirtPaint()
		end
	end

	-- Optimistic local razor: always erase pixels under the brush (strands can sit
	-- off cell centers — gating on shaveAt left unerasureable tufts).
	if current.tool == "razor" then
		local shaved = PrepTypes.shaveAt(current.hair, x, y, PrepTypes.RAZOR_RADIUS)
		local erased = PrepPaint.eraseHairBrush(
			x,
			y,
			PrepTypes.RAZOR_RADIUS,
			current.hair,
			current.hairCols,
			current.hairRows,
			current.regionId
		)
		if shaved > 0 or erased then
			current.hairLeft = PrepTypes.countHairLeft(current.hair)
			current.step = PrepTypes.currentStep(current.dirt, current.hair)
			lastHairPaintKey = hairPaintKey(current)
			updateChrome(current)
			rememberResidue(current)
		end
	end

	if now - lastStrokeFire < STROKE_INTERVAL then
		return
	end
	lastStrokeFire = now
	fire("stroke", { x = x, y = y })
end

local function clearCatcherConns()
	for _, conn in catcherConns do
		conn:Disconnect()
	end
	table.clear(catcherConns)
end

local function bindStrokeCatcher(catcher: TextButton)
	clearCatcherConns()
	table.insert(
		catcherConns,
		catcher.InputBegan:Connect(function(input: InputObject)
			if not open then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			stroking = true
			strokeAt(pointerScreen(input))
			if strokeConn ~= nil then
				strokeConn:Disconnect()
			end
			strokeConn = RunService.RenderStepped:Connect(function()
				if not stroking then
					return
				end
				strokeAt(pointerScreen(nil))
			end)
		end)
	)
	table.insert(
		catcherConns,
		catcher.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			stroking = false
			if strokeConn ~= nil then
				strokeConn:Disconnect()
				strokeConn = nil
			end
			flushDirtPaint()
			moveCursor(pointerScreen(input), false)
		end)
	)
	table.insert(
		catcherConns,
		catcher.InputChanged:Connect(function(input: InputObject)
			if not open then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				moveCursor(pointerScreen(input), stroking)
			end
		end)
	)
end

local function ensureCanvas(regionId: string)
	local board = TattooCanvas.getBoard()
	local boardReady = lastShownRegion == regionId
		and board ~= nil
		and strokeCatcher ~= nil
		and strokeCatcher.Parent ~= nil
	if boardReady then
		return
	end

	-- Fast path: board already up — only swap the limb still + overlays.
	if board ~= nil and strokeCatcher ~= nil and strokeCatcher.Parent ~= nil and hairLayer ~= nil and dirtLayer ~= nil then
		lastShownRegion = regionId
		TattooCanvas.setLimbRegion(regionId)
		PrepPaint.invalidate()
		lastHairPaintKey = ""
		lastDirtPaintKey = ""
		return
	end

	lastShownRegion = regionId
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	if character == nil then
		return
	end
	TattooCanvas.show(character, {
		roundId = 0,
		region = regionId,
		elements = {},
	} :: any, nil)
	TattooCanvas.setInteractive(false)
	TattooCanvas.setLayersVisible(false)
	TattooCanvas.setCameraLocked(true)

	board = TattooCanvas.getBoard()
	if board == nil then
		return
	end
	if board:IsA("GuiObject") then
		board.Active = true
	end
	PrepPaint.reset()
	lastHairPaintKey = ""
	lastDirtPaintKey = ""
	if dirtLayer ~= nil then
		dirtLayer:Destroy()
	end
	if hairLayer ~= nil then
		hairLayer:Destroy()
	end
	if stepsHost ~= nil then
		stepsHost:Destroy()
		stepsHost = nil
	end
	table.clear(stepLabels)
	if strokeCatcher ~= nil then
		strokeCatcher:Destroy()
	end
	if cursor ~= nil then
		cursor:Destroy()
	end
	clearCatcherConns()

	local hair = Instance.new("Frame")
	hair.Name = "PrepHair"
	hair.BackgroundTransparency = 1
	hair.Size = UDim2.fromScale(1, 1)
	hair.ZIndex = 2
	hair.Active = false
	hair.Parent = board
	hairLayer = hair

	local dirt = Instance.new("Frame")
	dirt.Name = "PrepDirt"
	dirt.BackgroundTransparency = 1
	dirt.Size = UDim2.fromScale(1, 1)
	dirt.ZIndex = 3
	dirt.Active = false
	dirt.Parent = board
	dirtLayer = dirt

	local steps = Instance.new("Frame")
	steps.Name = "PrepSteps"
	steps.AnchorPoint = Vector2.new(0.5, 0)
	steps.Position = UDim2.new(0.5, 0, 0, 10)
	steps.Size = UDim2.fromOffset(420, 34)
	steps.BackgroundColor3 = UiTheme.color.panel
	steps.BackgroundTransparency = 0.12
	steps.BorderSizePixel = 0
	steps.ZIndex = 25
	steps.Active = false
	steps.Parent = board
	local stepsCorner = Instance.new("UICorner")
	stepsCorner.CornerRadius = UDim.new(0, 10)
	stepsCorner.Parent = steps
	local stepsPad = Instance.new("UIPadding")
	stepsPad.PaddingLeft = UDim.new(0, 8)
	stepsPad.PaddingRight = UDim.new(0, 8)
	stepsPad.Parent = steps
	local stepsRow = Instance.new("UIListLayout")
	stepsRow.FillDirection = Enum.FillDirection.Horizontal
	stepsRow.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stepsRow.VerticalAlignment = Enum.VerticalAlignment.Center
	stepsRow.Padding = UDim.new(0, 6)
	stepsRow.SortOrder = Enum.SortOrder.LayoutOrder
	stepsRow.Parent = steps
	stepsHost = steps
	local stepCopy = { "Soap", "Cloth", "Razor" }
	for i, text in stepCopy do
		local chip = Instance.new("TextLabel")
		chip.Name = `Step{i}`
		chip.LayoutOrder = i
		chip.Size = UDim2.fromOffset(128, 26)
		chip.BackgroundColor3 = UiTheme.color.chip
		chip.BackgroundTransparency = 0.15
		chip.BorderSizePixel = 0
		chip.FontFace = UiTheme.font.medium
		chip.TextSize = 13
		chip.TextColor3 = UiTheme.color.muted
		chip.Text = text
		chip.ZIndex = 26
		chip.Active = false
		chip.Parent = steps
		local chipCorner = Instance.new("UICorner")
		chipCorner.CornerRadius = UDim.new(0, 8)
		chipCorner.Parent = chip
		stepLabels[i] = chip
	end

	local catcher = Instance.new("TextButton")
	catcher.Name = "PrepStrokeCatcher"
	catcher.Text = ""
	catcher.AutoButtonColor = false
	catcher.BackgroundTransparency = 1
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.ZIndex = 20
	catcher.Active = true
	catcher.Selectable = false
	catcher.Parent = board
	strokeCatcher = catcher
	bindStrokeCatcher(catcher)

	-- Cursor on the board in board-local pixels (matches AbsolutePosition ↔ mouse).
	if cursor ~= nil then
		cursor:Destroy()
		cursor = nil
	end
	local tip = Instance.new("Frame")
	tip.Name = "ToolCursor"
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Size = UDim2.fromOffset(28, 28)
	tip.BackgroundColor3 = UiTheme.color.gold
	tip.BorderSizePixel = 0
	tip.Visible = false
	tip.ZIndex = 40
	tip.Active = false
	tip.Parent = board
	local tipScale = Instance.new("UIScale")
	tipScale.Scale = 1
	tipScale.Parent = tip
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = tip
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "🧼"
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Active = false
	label.Parent = tip
	cursor = tip
	ensureCursorLoop()
end

local function applyView(view: PrepView)
	local prev = current
	-- Keep optimistic shaves/soaps/wipes the server hasn't caught up on yet.
	local merged = if prev ~= nil then PrepTypes.mergeProgress(view, prev) else view
	if toolOverride ~= nil then
		if view.tool == toolOverride then
			toolOverride = nil
		else
			merged.tool = toolOverride
		end
	end
	current = merged
	lockedRegion = merged.regionId
	rememberResidue(merged)
	ensureCanvas(merged.regionId)
	-- Hair: only full-rebuild on region change. Razor uses eraseHairBrush locally;
	-- server echoes just refresh the key without restamping every strand.
	local forceHair = prev == nil or prev.regionId ~= merged.regionId
	local forceDirt = prev == nil or prev.regionId ~= merged.regionId or prev.dirtyLeft ~= merged.dirtyLeft
	if not forceDirt and prev ~= nil then
		for i, patch in merged.dirt do
			local before = prev.dirt[i]
			if before == nil or before.soaped ~= patch.soaped or before.cleared ~= patch.cleared then
				forceDirt = true
				break
			end
		end
	end
	if prev ~= nil and prev.hairLeft ~= merged.hairLeft then
		lastHairPaintKey = hairPaintKey(merged)
	end
	renderOverlays(merged, forceHair, forceDirt)
	updateChrome(merged)
end

local function buildUi(playerGui: Instance)
	local gui = Instance.new("ScreenGui")
	gui.Name = "InkRivalryPrep"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ClipToDeviceSafeArea = false
	gui.DisplayOrder = 28
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	-- Prefer ScreenInsets.None when available so GetMouseLocation matches child offsets.
	pcall(function()
		(gui :: any).ScreenInsets = Enum.ScreenInsets.None
	end)
	gui.Parent = playerGui
	screenGui = gui

	local left = Instance.new("Frame")
	left.Name = "Tools"
	left.AnchorPoint = Vector2.new(0, 0.5)
	left.Position = UDim2.new(0, UiTheme.safe.side, 0.5, 0)
	left.Size = UDim2.fromOffset(120, 220)
	left.BackgroundColor3 = UiTheme.color.panel
	left.BackgroundTransparency = 0.08
	left.BorderSizePixel = 0
	left.Parent = gui
	local lc = Instance.new("UICorner")
	lc.CornerRadius = UDim.new(0, 14)
	lc.Parent = left
	local lp = Instance.new("UIPadding")
	lp.PaddingTop = UDim.new(0, 12)
	lp.PaddingBottom = UDim.new(0, 12)
	lp.PaddingLeft = UDim.new(0, 10)
	lp.PaddingRight = UDim.new(0, 10)
	lp.Parent = left
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 8)
	ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = left

	local toolsTitle = Instance.new("TextLabel")
	toolsTitle.BackgroundTransparency = 1
	toolsTitle.Size = UDim2.new(1, 0, 0, 18)
	toolsTitle.FontFace = UiTheme.font.heavy
	toolsTitle.TextSize = 12
	toolsTitle.TextColor3 = UiTheme.color.muted
	toolsTitle.Text = "TOOLS"
	toolsTitle.LayoutOrder = 0
	toolsTitle.Parent = left

	for index, tool in TOOLS do
		local button = Instance.new("TextButton")
		button.Name = tool.id
		button.LayoutOrder = index
		button.Size = UDim2.new(1, 0, 0, 44)
		button.BackgroundColor3 = UiTheme.color.chip
		button.BorderSizePixel = 0
		button.FontFace = UiTheme.font.bold
		button.TextSize = 15
		button.TextColor3 = UiTheme.color.text
		button.Text = tool.label
		button.Active = true
		button.Parent = left
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button
		toolButtons[tool.id] = button
		local id = tool.id
		button.MouseButton1Click:Connect(function()
			if current == nil then
				return
			end
			-- Switch instantly locally — don't wait on the server round-trip.
			toolOverride = id
			current.tool = id
			updateChrome(current)
			Sfx.play("click")
			Juice.punch(button, 1.08)
			fire("selectTool", { tool = id })
		end)
	end

	local right = Instance.new("Frame")
	right.Name = "Limbs"
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.new(1, -UiTheme.safe.side, 0.5, 0)
	right.Size = UDim2.fromOffset(140, 260)
	right.BackgroundColor3 = UiTheme.color.panel
	right.BackgroundTransparency = 0.08
	right.BorderSizePixel = 0
	right.Parent = gui
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 14)
	rc.Parent = right
	local rp = Instance.new("UIPadding")
	rp.PaddingTop = UDim.new(0, 12)
	rp.PaddingBottom = UDim.new(0, 12)
	rp.PaddingLeft = UDim.new(0, 10)
	rp.PaddingRight = UDim.new(0, 10)
	rp.Parent = right
	local rl = Instance.new("UIListLayout")
	rl.Padding = UDim.new(0, 6)
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Parent = right

	local limbTitle = Instance.new("TextLabel")
	limbTitle.BackgroundTransparency = 1
	limbTitle.Size = UDim2.new(1, 0, 0, 18)
	limbTitle.FontFace = UiTheme.font.heavy
	limbTitle.TextSize = 12
	limbTitle.TextColor3 = UiTheme.color.muted
	limbTitle.Text = "LIMB"
	limbTitle.LayoutOrder = 0
	limbTitle.Parent = right

	for index, region in BodyRegions.all do
		local button = Instance.new("TextButton")
		button.Name = region.id
		button.LayoutOrder = index
		button.Size = UDim2.new(1, 0, 0, 32)
		button.BackgroundColor3 = UiTheme.color.chip
		button.BorderSizePixel = 0
		button.FontFace = UiTheme.font.medium
		button.TextSize = 13
		button.TextColor3 = UiTheme.color.text
		button.Text = region.label
		button.Parent = right
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button
		limbButtons[region.id] = button
		local regionId = region.id
		button.MouseButton1Click:Connect(function()
			Sfx.play("click")
			Juice.punch(button, 1.08)
			-- Optimistic swap — don't wait on the server to show the new limb.
			if lockedRegion == nil or lockedRegion == regionId then
				local player = Players.LocalPlayer
				local uid = if player ~= nil then player.UserId else 0
				local dirt = PrepTypes.makeDirt(uid, regionId)
				local hair = PrepTypes.makeHair(uid, regionId)
				local tool: PrepTool = if current ~= nil then current.tool else "soap"
				applyView({
					regionId = regionId,
					tool = tool,
					step = PrepTypes.currentStep(dirt, hair),
					dirt = dirt,
					hair = hair,
					hairCols = PrepTypes.HAIR_COLS,
					hairRows = PrepTypes.HAIR_ROWS,
					dirtyLeft = PrepTypes.countDirtLeft(dirt),
					hairLeft = PrepTypes.countHairLeft(hair),
				})
			end
			fire("pickRegion", { regionId = regionId })
		end)
	end

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, 0, 0, 36)
	status.FontFace = UiTheme.font.medium
	status.TextSize = 11
	status.TextColor3 = UiTheme.color.muted
	status.TextWrapped = true
	status.Text = "Soap the dirt"
	status.LayoutOrder = 20
	status.Parent = left
	statusLabel = status
end

local function setOpen(want: boolean)
	if open == want then
		return
	end
	open = want
	if screenGui ~= nil then
		screenGui.Enabled = want
	end
	if want then
		lastShownRegion = nil
		pointerFix = Vector2.zero
		TattooCanvas.setCameraLocked(true)
		-- Mouse icon toggles in moveCursor: off over the limb, on over tool panels.
		UserInputService.MouseIconEnabled = true
		ensureCursorLoop()
		fire("sync")
	else
		stroking = false
		flushDirtPaint()
		if current ~= nil then
			rememberResidue(current)
		end
		-- Snapshot live pixels BEFORE reset so soft shaves match the next round.
		local hairImg, dirtImg = PrepPaint.capture()
		residueHairImage = hairImg
		residueDirtImage = dirtImg
		stopCursorLoop()
		UserInputService.MouseIconEnabled = true
		pointerFix = Vector2.zero
		if strokeConn ~= nil then
			strokeConn:Disconnect()
			strokeConn = nil
		end
		clearCatcherConns()
		PrepPaint.reset()
		lastHairPaintKey = ""
		lastDirtPaintKey = ""
		dirtPaintPending = false
		if dirtLayer ~= nil then
			dirtLayer:Destroy()
			dirtLayer = nil
		end
		if hairLayer ~= nil then
			hairLayer:Destroy()
			hairLayer = nil
		end
		if stepsHost ~= nil then
			stepsHost:Destroy()
			stepsHost = nil
		end
		table.clear(stepLabels)
		if strokeCatcher ~= nil then
			strokeCatcher:Destroy()
			strokeCatcher = nil
		end
		if cursor ~= nil then
			cursor:Destroy()
			cursor = nil
		end
		lastShownRegion = nil
		if lastResidue ~= nil then
			TattooCanvas.setPrepResidue(lastResidue, residueHairImage, residueDirtImage)
		end
	end
end

function PrepEditor.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	buildUi(playerGui)
	TattooCanvas.preloadAll()

	Remotes.PrepStateUpdated.OnClientEvent:Connect(function(payload: any)
		local view = PrepTypes.readView(payload)
		if view == nil then
			return
		end
		if open then
			applyView(view)
		else
			local merged = if current ~= nil then PrepTypes.mergeProgress(view, current) else view
			current = merged
			lockedRegion = merged.regionId
			rememberResidue(merged)
		end
	end)

	Remotes.RoundStateUpdated.OnClientEvent:Connect(function(payload: any)
		local snapshot = RoundTypes.readSnapshot(payload)
		if snapshot == nil then
			return
		end
		setOpen(snapshot.state == "LimbPrep")
		if snapshot.state == "WaitingForPlayers" then
			lockedRegion = nil
			lastResidue = nil
			residueHairImage = nil
			residueDirtImage = nil
			TattooCanvas.setPrepResidue(nil)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not open or stroking then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local pos = pointerScreen(input)
		if canvasPoint(pos) == nil then
			return
		end
		stroking = true
		strokeAt(pos)
		if strokeConn ~= nil then
			strokeConn:Disconnect()
		end
		strokeConn = RunService.RenderStepped:Connect(function()
			if not stroking then
				return
			end
			strokeAt(pointerScreen(nil))
		end)
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, _processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stroking = false
			if strokeConn ~= nil then
				strokeConn:Disconnect()
				strokeConn = nil
			end
			flushDirtPaint()
			moveCursor(pointerScreen(input), false)
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject, _processed: boolean)
		if not open then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			moveCursor(pointerScreen(input), stroking)
		end
	end)

	print(`{PREFIX} Prep editor ready`)
end

return PrepEditor
