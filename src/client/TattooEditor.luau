--!strict

-- Desktop-first editor for the forearm prototype. Drags stay on this client.
-- The server receives the finished design once, then checks it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BodyRegions = require(ReplicatedStorage.Shared.BodyRegions)
local DesignDocument = require(ReplicatedStorage.Shared.DesignDocument)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local InkColors = require(ReplicatedStorage.Shared.InkColors)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundTypes = require(ReplicatedStorage.Shared.RoundTypes)
local StencilDefinitions = require(ReplicatedStorage.Shared.StencilDefinitions)
local StencilView = require(script.Parent.StencilView)
local TattooCanvas = require(script.Parent.TattooCanvas)
local UiTheme = require(script.Parent.UiTheme)
local MarkInspector = require(script.Parent.MarkInspector)

type TattooDesign = DesignDocument.TattooDesign
type RoundSnapshot = RoundTypes.RoundSnapshot

local PREFIX = "[InkMasters]"

local TattooEditor = {}
local started = false

local function corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local function stroke(parent: Instance, color: Color3): UIStroke
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = color
	uiStroke.Thickness = 1.5
	uiStroke.Transparency = 0.35
	uiStroke.Parent = parent
	return uiStroke
end

function TattooEditor.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	if player == nil then
		error("[InkMasters] The tattoo editor must run on the client")
	end

	local design = DesignDocument.createEmpty()
	local selectedIndex: number? = nil
	local selectedStencilId = "circle"
	local selectedColorId = "black"
	local selectedRegion = "LeftForearm"
	local selectedSkinId = "yours"
	local editing = false
	local roundId = 0
	local lastRevision = 0
	local clearArmed = false
	local clearToken = 0
	local statusOverride: string? = nil
	local markPanel: {
		show: (MarkInspector.MarkState) -> (),
		hide: () -> (),
	}? = nil

	local stencilStrokes: { [string]: UIStroke } = {}
	local regionStrokes: { [string]: UIStroke } = {}
	local skinStrokes: { [string]: UIStroke } = {}

	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("InkMastersEditor")
	if existing ~= nil then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "InkMastersEditor"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 20
	screenGui.Enabled = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	local holder = Instance.new("Frame")
	holder.Name = "ShapeList"
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.fromScale(0.985, 0.07)
	holder.Size = UDim2.fromScale(0.24, 0.9)
	holder.BackgroundColor3 = UiTheme.color.panel
	holder.BackgroundTransparency = 0.08
	holder.BorderSizePixel = 0
	holder.Parent = screenGui
	corner(holder, 16)
	stroke(holder, UiTheme.color.stroke)

	holder.ClipsDescendants = true
	local panelPad = Instance.new("UIPadding")
	panelPad.PaddingTop = UDim.new(0, 12)
	panelPad.PaddingBottom = UDim.new(0, 12)
	panelPad.PaddingLeft = UDim.new(0, 12)
	panelPad.PaddingRight = UDim.new(0, 12)
	panelPad.Parent = holder
	local panelList = Instance.new("UIListLayout")
	panelList.FillDirection = Enum.FillDirection.Vertical
	panelList.Padding = UDim.new(0, 8)
	panelList.SortOrder = Enum.SortOrder.LayoutOrder
	panelList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	panelList.Parent = holder

	local function sectionLabel(name: string, text: string, order: number): TextLabel
		local heading = Instance.new("TextLabel")
		heading.Name = name
		heading.BackgroundTransparency = 1
		heading.LayoutOrder = order
		heading.FontFace = UiTheme.font.bold
		heading.TextSize = 12
		heading.TextColor3 = UiTheme.color.magenta
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.Text = text
		heading.Size = UDim2.new(1, 0, 0, 16)
		heading.Parent = holder
		return heading
	end

	sectionLabel("LimbHeading", "LIMB", 1)

	local limbScroll = Instance.new("ScrollingFrame")
	limbScroll.Name = "Limbs"
	limbScroll.LayoutOrder = 2
	limbScroll.BackgroundTransparency = 1
	limbScroll.BorderSizePixel = 0
	limbScroll.ClipsDescendants = true
	limbScroll.ScrollBarThickness = 4
	limbScroll.ScrollingDirection = Enum.ScrollingDirection.X
	limbScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	limbScroll.CanvasSize = UDim2.fromOffset(0, 0)
	limbScroll.Size = UDim2.new(1, 0, 0, 40)
	limbScroll.Parent = holder
	local limbLayout = Instance.new("UIListLayout")
	limbLayout.FillDirection = Enum.FillDirection.Horizontal
	limbLayout.Padding = UDim.new(0, 6)
	limbLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	limbLayout.SortOrder = Enum.SortOrder.LayoutOrder
	limbLayout.Parent = limbScroll

	sectionLabel("SkinHeading", "SKIN", 3)

	local skinScroll = Instance.new("ScrollingFrame")
	skinScroll.Name = "Skin"
	skinScroll.LayoutOrder = 4
	skinScroll.BackgroundTransparency = 1
	skinScroll.BorderSizePixel = 0
	skinScroll.ClipsDescendants = true
	skinScroll.ScrollBarThickness = 4
	skinScroll.ScrollingDirection = Enum.ScrollingDirection.X
	skinScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	skinScroll.CanvasSize = UDim2.fromOffset(0, 0)
	skinScroll.Size = UDim2.new(1, 0, 0, 36)
	skinScroll.Parent = holder
	local skinLayout = Instance.new("UIListLayout")
	skinLayout.FillDirection = Enum.FillDirection.Horizontal
	skinLayout.Padding = UDim.new(0, 6)
	skinLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	skinLayout.SortOrder = Enum.SortOrder.LayoutOrder
	skinLayout.Parent = skinScroll

	sectionLabel("ShapeHeading", "SHAPES", 5)

	local shapeScroll = Instance.new("ScrollingFrame")
	shapeScroll.Name = "Shapes"
	shapeScroll.LayoutOrder = 6
	shapeScroll.BackgroundTransparency = 1
	shapeScroll.BorderSizePixel = 0
	shapeScroll.ClipsDescendants = true
	shapeScroll.ScrollBarThickness = 6
	shapeScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	shapeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	shapeScroll.CanvasSize = UDim2.fromOffset(0, 0)
	shapeScroll.Size = UDim2.fromScale(1, 0)
	shapeScroll.Parent = holder
	local shapeFlex = Instance.new("UIFlexItem")
	shapeFlex.FlexMode = Enum.UIFlexMode.Fill
	shapeFlex.Parent = shapeScroll
	local shapeGrid = Instance.new("UIGridLayout")
	shapeGrid.CellPadding = UDim2.fromOffset(6, 6)
	shapeGrid.CellSize = UDim2.new(0.333, -6, 0, 78)
	shapeGrid.FillDirection = Enum.FillDirection.Horizontal
	shapeGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	shapeGrid.SortOrder = Enum.SortOrder.LayoutOrder
	shapeGrid.Parent = shapeScroll
	local shapePad = Instance.new("UIPadding")
	shapePad.PaddingRight = UDim.new(0, 4)
	shapePad.Parent = shapeScroll

	local dock = Instance.new("Frame")
	dock.Name = "Dock"
	dock.LayoutOrder = 7
	dock.BackgroundTransparency = 1
	dock.Size = UDim2.fromScale(1, 0)
	dock.AutomaticSize = Enum.AutomaticSize.Y
	dock.Parent = holder
	local dockList = Instance.new("UIListLayout")
	dockList.FillDirection = Enum.FillDirection.Vertical
	dockList.Padding = UDim.new(0, 10)
	dockList.SortOrder = Enum.SortOrder.LayoutOrder
	dockList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockList.Parent = dock

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.LayoutOrder = 8
	status.BackgroundTransparency = 1
	status.FontFace = UiTheme.font.medium
	status.TextSize = 13
	status.TextColor3 = UiTheme.color.muted
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.Text = "Press a shape to add it."
	status.Size = UDim2.new(1, 0, 0, 32)
	status.Parent = holder

	local function swatchColor(): { r: number, g: number, b: number }
		local swatch = InkColors.get(selectedColorId)
		if swatch == nil then
			return { r = 0.07, g = 0.06, b = 0.08 }
		end
		return { r = swatch.r, g = swatch.g, b = swatch.b }
	end

	local function updateChrome()
		for id, uiStroke in stencilStrokes do
			local selected = id == selectedStencilId
			uiStroke.Color = if selected then UiTheme.color.gold else UiTheme.color.stroke
			uiStroke.Transparency = if selected then 0 else 0.45
		end
		for id, uiStroke in regionStrokes do
			local selected = id == selectedRegion
			uiStroke.Color = if selected then UiTheme.color.gold else UiTheme.color.stroke
			uiStroke.Transparency = if selected then 0 else 0.45
		end
		for id, uiStroke in skinStrokes do
			local selected = id == selectedSkinId
			uiStroke.Color = if selected then UiTheme.color.gold else Color3.fromRGB(28, 24, 22)
			uiStroke.Thickness = if selected then 2.5 else 1
		end
	end

	local function syncInspector()
		local panel = markPanel
		if panel == nil then
			return
		end
		if selectedIndex == nil then
			panel.hide()
			return
		end
		local element = design.elements[selectedIndex]
		if element == nil then
			panel.hide()
			return
		end
		local stencil = StencilDefinitions.get(element.stencilId)
		panel.show({
			name = if stencil ~= nil then stencil.name else "Shape",
			fill = element.fill,
			outline = element.outline,
			thickness = element.thickness,
			opacity = element.opacity,
			flip = element.flip,
			color = element.color,
			line = element.line,
		})
	end

	local function updateStatus()
		if statusOverride ~= nil then
			status.Text = statusOverride
			return
		end
		local stencil = StencilDefinitions.get(selectedStencilId)
		local ink = InkColors.get(selectedColorId)
		local markName = if stencil ~= nil then stencil.name else "Mark"
		local inkName = if ink ~= nil then ink.name else "Ink"
		local count = #design.elements
		local maxCount = GameConfig.getMaxElements()
		status.Text = `{markName} · {inkName} · {count}/{maxCount}`
	end

	local function refresh()
		local character = player.Character
		if character ~= nil then
			TattooCanvas.show(character, design, selectedIndex)
		end
		TattooCanvas.render(design, selectedIndex)
		updateStatus()
		updateChrome()
		syncInspector()
	end

	local function clampScale(scale: number): number
		return math.clamp(scale, GameConfig.getMinElementScale(), GameConfig.getMaxElementScale())
	end

	local function placeAt(x: number, y: number)
		if not editing then
			return
		end
		if #design.elements >= GameConfig.getMaxElements() then
			statusOverride = "This design is full."
			updateStatus()
			return
		end
		local color = swatchColor()
		table.insert(design.elements, {
			stencilId = selectedStencilId,
			x = math.clamp(x, 0.06, 0.94),
			y = math.clamp(y, 0.06, 0.94),
			rotation = 0,
			scale = TattooCanvas.placeScale(),
			color = { r = color.r, g = color.g, b = color.b },
			line = { r = color.r, g = color.g, b = color.b },
			fill = false,
			outline = true,
			thickness = 1,
			opacity = 1,
			flip = false,
		})
		selectedIndex = #design.elements
		statusOverride = nil
		clearArmed = false
		refresh()
	end

	local function placeFromMenu(stencilId: string)
		selectedStencilId = stencilId
		local slot = #design.elements
		local column = slot % 5
		local line = math.floor(slot / 5) % 4
		placeAt(0.38 + column * 0.06, 0.4 + line * 0.07)
	end

	local function grab(index: number)
		if design.elements[index] == nil then
			return
		end
		selectedIndex = index
		statusOverride = nil
		TattooCanvas.render(design, selectedIndex)
		updateStatus()
		syncInspector()
	end

	local function deselect()
		if selectedIndex == nil then
			return
		end
		selectedIndex = nil
		refresh()
	end

	TattooCanvas.setHandlers(grab, deselect)
	TattooCanvas.setMoveHandler(function(index: number, x: number, y: number)
		local element = design.elements[index]
		if element == nil then
			return
		end
		element.x = x
		element.y = y
	end)
	TattooCanvas.setTransformHandlers(function(index: number, rotation: number, scale: number)
		local element = design.elements[index]
		if element == nil then
			return
		end
		element.rotation = rotation
		element.scale = scale
	end)
	TattooCanvas.setAdjustStarted(function() end)

	local function selectedElement(): DesignDocument.DesignElement?
		if selectedIndex == nil then
			return nil
		end
		return design.elements[selectedIndex]
	end

	local function rotateBy(degrees: number)
		local element = selectedElement()
		if element == nil then
			statusOverride = "Select a mark first."
			updateStatus()
			return
		end
		element.rotation = (element.rotation + degrees) % 360
		statusOverride = nil
		refresh()
	end

	local function scaleBy(factor: number)
		local element = selectedElement()
		if element == nil then
			statusOverride = "Select a mark first."
			updateStatus()
			return
		end
		element.scale = clampScale(element.scale * factor)
		statusOverride = nil
		refresh()
	end

	local function removeSelected()
		if selectedIndex == nil then
			statusOverride = "Select a mark first."
			updateStatus()
			return
		end
		table.remove(design.elements, selectedIndex)
		selectedIndex = nil
		statusOverride = nil
		refresh()
	end

	local function editSelected(mutate: (DesignDocument.DesignElement) -> ())
		local element = selectedElement()
		if element == nil then
			return
		end
		mutate(element)
		statusOverride = nil
		refresh()
	end

	local function copyElement(element: DesignDocument.DesignElement): DesignDocument.DesignElement
		return {
			stencilId = element.stencilId,
			x = math.clamp(element.x + 0.05, 0.06, 0.94),
			y = math.clamp(element.y + 0.05, 0.06, 0.94),
			rotation = element.rotation,
			scale = element.scale,
			color = { r = element.color.r, g = element.color.g, b = element.color.b },
			line = { r = element.line.r, g = element.line.g, b = element.line.b },
			fill = element.fill,
			outline = element.outline,
			thickness = element.thickness,
			opacity = element.opacity,
			flip = element.flip,
		}
	end

	markPanel = MarkInspector.mount(screenGui, {
		onClose = function()
			deselect()
		end,
		onDelete = function()
			removeSelected()
		end,
		onFill = function(enabled: boolean)
			editSelected(function(element)
				element.fill = enabled
				if not enabled and not element.outline then
					element.outline = true
				end
			end)
		end,
		onOutline = function(enabled: boolean)
			editSelected(function(element)
				element.outline = enabled
				if not enabled and not element.fill then
					element.fill = true
				end
			end)
		end,
		onThickness = function(delta: number)
			editSelected(function(element)
				element.thickness = DesignDocument.clampThickness(element.thickness + delta)
			end)
		end,
		onOpacity = function(delta: number)
			editSelected(function(element)
				local stepped = math.floor((element.opacity + delta) * 10 + 0.5) / 10
				element.opacity = DesignDocument.clampOpacity(stepped)
			end)
		end,
		onScale = function(direction: number)
			scaleBy(if direction < 0 then 0.85 else 1.18)
		end,
		onRotate = function(degrees: number)
			rotateBy(degrees)
		end,
		onFlip = function(enabled: boolean)
			editSelected(function(element)
				element.flip = enabled
			end)
		end,
		onColor = function(color: MarkInspector.Rgb)
			for _, ink in InkColors.all do
				local same = math.abs(ink.r - color.r) < 0.03
					and math.abs(ink.g - color.g) < 0.03
					and math.abs(ink.b - color.b) < 0.03
				if same then
					selectedColorId = ink.id
				end
			end
			editSelected(function(element)
				element.color = { r = color.r, g = color.g, b = color.b }
				element.line = { r = color.r, g = color.g, b = color.b }
			end)
		end,
		onLine = function(color: MarkInspector.Rgb)
			editSelected(function(element)
				element.line = { r = color.r, g = color.g, b = color.b }
				element.outline = true
			end)
		end,
		onDuplicate = function()
			local element = selectedElement()
			if element == nil then
				return
			end
			if #design.elements >= GameConfig.getMaxElements() then
				statusOverride = "This design is full."
				updateStatus()
				return
			end
			table.insert(design.elements, copyElement(element))
			selectedIndex = #design.elements
			statusOverride = nil
			refresh()
		end,
		onOrder = function(direction: number)
			if selectedIndex == nil then
				return
			end
			local nextIndex = selectedIndex + direction
			local current = design.elements[selectedIndex]
			local neighbor = design.elements[nextIndex]
			if current == nil or neighbor == nil then
				return
			end
			design.elements[selectedIndex] = neighbor
			design.elements[nextIndex] = current
			selectedIndex = nextIndex
			refresh()
		end,
	})

	local function requestClear()
		if not clearArmed then
			clearArmed = true
			clearToken += 1
			local token = clearToken
			statusOverride = "Click Clear again to wipe the panel."
			updateStatus()
			task.delay(3, function()
				if token ~= clearToken then
					return
				end
				clearArmed = false
				if statusOverride == "Click Clear again to wipe the panel." then
					statusOverride = nil
					updateStatus()
				end
			end)
			return
		end
		clearArmed = false
		design.elements = {}
		selectedIndex = nil
		statusOverride = nil
		refresh()
	end

	local function submit()
		if roundId <= 0 then
			return
		end
		Remotes.SubmitDesign:FireServer({
			roundId = roundId,
			region = design.region,
			elements = design.elements,
		})
	end

	local function row(parent: Instance): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Parent = parent
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 6)
		layout.Wraps = true
		layout.Parent = frame
		return frame
	end

	local function selectRegion(regionId: string)
		selectedRegion = regionId
		design.region = regionId
		statusOverride = nil
		updateChrome()
		refresh()
	end

	for _, region in BodyRegions.all do
		local limbButton = Instance.new("TextButton")
		limbButton.Name = region.id
		limbButton.AutoButtonColor = true
		limbButton.Text = region.label
		limbButton.FontFace = UiTheme.font.bold
		limbButton.TextSize = 13
		limbButton.TextColor3 = UiTheme.color.text
		limbButton.BackgroundColor3 = UiTheme.color.chip
		limbButton.BorderSizePixel = 0
		limbButton.AutomaticSize = Enum.AutomaticSize.X
		limbButton.Size = UDim2.fromOffset(0, 34)
		limbButton.Parent = limbScroll
		corner(limbButton, 10)
		regionStrokes[region.id] = stroke(limbButton, UiTheme.color.stroke)
		local limbPad = Instance.new("UIPadding")
		limbPad.PaddingLeft = UDim.new(0, 10)
		limbPad.PaddingRight = UDim.new(0, 10)
		limbPad.Parent = limbButton
		local regionId = region.id
		limbButton.MouseButton1Click:Connect(function()
			selectRegion(regionId)
		end)
	end

	local function yoursTone(): Color3
		local character = player.Character
		if character == nil then
			return Color3.fromRGB(232, 184, 150)
		end
		return TattooCanvas.avatarTone(character)
	end

	for index, tone in TattooCanvas.skinChoices() do
		local toneButton = Instance.new("TextButton")
		toneButton.Name = tone.id
		toneButton.LayoutOrder = index
		toneButton.AutoButtonColor = false
		toneButton.Text = ""
		toneButton.BackgroundColor3 = if tone.color ~= nil then tone.color else yoursTone()
		toneButton.BorderSizePixel = 0
		toneButton.Size = UDim2.fromOffset(28, 28)
		toneButton.Parent = skinScroll
		corner(toneButton, 14)
		skinStrokes[tone.id] = stroke(toneButton, Color3.fromRGB(28, 24, 22))
		local toneId = tone.id
		toneButton.MouseButton1Click:Connect(function()
			selectedSkinId = toneId
			TattooCanvas.setSkin(toneId)
			statusOverride = nil
			refresh()
		end)
	end

	for index, stencil in StencilDefinitions.all do
		local button = Instance.new("TextButton")
		button.Name = stencil.id
		button.LayoutOrder = index
		button.AutoButtonColor = true
		button.Text = ""
		button.BackgroundColor3 = UiTheme.color.chip
		button.BorderSizePixel = 0
		button.Size = UDim2.fromScale(1, 1)
		button.Parent = shapeScroll
		corner(button, 12)
		stencilStrokes[stencil.id] = stroke(button, UiTheme.color.stroke)

		local preview = Instance.new("Frame")
		preview.BackgroundTransparency = 1
		preview.AnchorPoint = Vector2.new(0.5, 0)
		preview.Position = UDim2.new(0.5, 0, 0, 6)
		preview.Size = UDim2.fromOffset(40, 40)
		preview.Parent = button
		StencilView.draw(preview, stencil.shape, UiTheme.color.text)

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.FontFace = UiTheme.font.bold
		name.TextSize = 12
		name.TextColor3 = UiTheme.color.text
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = stencil.name
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -4)
		name.Size = UDim2.new(1, -8, 0, 16)
		name.Parent = button

		local stencilId = stencil.id
		button.MouseButton1Click:Connect(function()
			placeFromMenu(stencilId)
		end)
	end

	local function tool(text: string, parent: Frame, callback: () -> ())
		local button = Instance.new("TextButton")
		button.AutoButtonColor = true
		button.BackgroundColor3 = UiTheme.color.chip
		button.BorderSizePixel = 0
		button.FontFace = UiTheme.font.bold
		button.TextSize = 13
		button.TextColor3 = UiTheme.color.text
		button.Text = text
		button.AutoLocalize = false
		button.Size = UDim2.fromOffset(0, 32)
		button.AutomaticSize = Enum.AutomaticSize.X
		button.Parent = parent
		corner(button, 10)
		local toolPadding = Instance.new("UIPadding")
		toolPadding.PaddingLeft = UDim.new(0, 14)
		toolPadding.PaddingRight = UDim.new(0, 14)
		toolPadding.Parent = button
		button.MouseButton1Click:Connect(callback)
	end

	local toolRow = row(dock)
	toolRow.LayoutOrder = 2
	tool("Delete", toolRow, function()
		removeSelected()
	end)
	tool("Clear", toolRow, requestClear)
	tool("Save", toolRow, function()
		submit()
		statusOverride = "Saving..."
		updateStatus()
	end)

	local function beginEditing(snapshot: RoundSnapshot)
		editing = true
		roundId = snapshot.roundId
		design = DesignDocument.createEmpty()
		design.region = selectedRegion
		selectedIndex = nil
		clearArmed = false
		statusOverride = nil
		screenGui.Enabled = true
		TattooCanvas.setInteractive(true)
		TattooCanvas.setCameraLocked(false)
		refresh()
		print(`{PREFIX} Editor open | round {snapshot.roundId}`)
	end

	local function endEditing()
		if not editing then
			return
		end
		editing = false
		submit()
		screenGui.Enabled = false
		TattooCanvas.setInteractive(false)
		TattooCanvas.clear()
		TattooCanvas.setCameraLocked(false)
	end

	Remotes.DesignResult.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.ok) ~= "boolean" then
			return
		end
		if payload.ok == true then
			local count = if typeof(payload.elementCount) == "number" then payload.elementCount else 0
			print(`{PREFIX} Design saved | {count} marks on the forearm`)
			if editing then
				statusOverride = `Saved {count} marks.`
				updateStatus()
			end
			return
		end
		local reason = if typeof(payload.reason) == "string" then payload.reason else "The studio rejected that design."
		warn(`{PREFIX} Design rejected | {reason}`)
		if editing then
			statusOverride = reason
			updateStatus()
		end
	end)

	Remotes.RoundStateUpdated.OnClientEvent:Connect(function(payload: any)
		local snapshot = RoundTypes.readSnapshot(payload)
		if snapshot == nil or snapshot.revision <= lastRevision then
			return
		end
		lastRevision = snapshot.revision

		if snapshot.paused then
			screenGui.Enabled = false
			TattooCanvas.setVisible(false)
			TattooCanvas.setInteractive(false)
			return
		end

		local leftCreation = editing and snapshot.state ~= "TattooCreation"
		local enteredCreation = snapshot.state == "TattooCreation" and (not editing or snapshot.roundId ~= roundId)
		if leftCreation then
			endEditing()
		end
		if
			snapshot.state == "WaitingForPlayers"
			or snapshot.state == "Intermission"
			or snapshot.state == "ThemeReveal"
		then
			TattooCanvas.clear()
		end
		if enteredCreation then
			beginEditing(snapshot)
		elseif editing and snapshot.state == "TattooCreation" then
			screenGui.Enabled = true
			TattooCanvas.setVisible(true)
		end
		roundId = snapshot.roundId
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not editing or processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			rotateBy(-15)
		elseif input.KeyCode == Enum.KeyCode.E then
			rotateBy(15)
		elseif input.KeyCode == Enum.KeyCode.Minus then
			scaleBy(1 / 1.12)
		elseif input.KeyCode == Enum.KeyCode.Equals then
			scaleBy(1.12)
		elseif input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Backspace then
			removeSelected()
		end
	end)

	updateChrome()
end

return TattooEditor
