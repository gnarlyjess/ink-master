--!strict

-- Desktop-first editor for the forearm prototype. Drags stay on this client.
-- The server receives the finished design once, then checks it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BodyRegions = require(ReplicatedStorage.Shared.BodyRegions)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local DesignDocument = require(ReplicatedStorage.Shared.DesignDocument)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local InkColors = require(ReplicatedStorage.Shared.InkColors)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundTypes = require(ReplicatedStorage.Shared.RoundTypes)
local StencilDefinitions = require(ReplicatedStorage.Shared.StencilDefinitions)
local Fanfare = require(script.Parent.Fanfare)
local FrameDress = require(script.Parent.FrameDress)
local Juice = require(script.Parent.Juice)
local MarkInspector = require(script.Parent.MarkInspector)
local PlayerData = require(script.Parent.PlayerData)
local Sfx = require(script.Parent.Sfx)
local StencilView = require(script.Parent.StencilView)
local TattooCanvas = require(script.Parent.TattooCanvas)
local Toasts = require(script.Parent.Toasts)
local UiTheme = require(script.Parent.UiTheme)

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
	local selectedSkinId = "peach"
	local editing = false
	local roundId = 0
	local designRound = 0
	local lastRevision = 0
	local clearArmed = false
	local clearToken = 0
	local statusOverride: string? = nil
	local markPanel: {
		show: (MarkInspector.MarkState) -> (),
		hide: () -> (),
	}? = nil

	local stencilStrokes: { [string]: UIStroke } = {}
	local stencilButtons: { [string]: TextButton } = {}
	local stencilOrder: { [string]: number } = {}
	-- Fixed square tiles — must not participate in panel VerticalFlex or they stretch into bars.
	local CHIP = 52
	local CHIP_GAP = 6
	local frameStrokes: { [string]: UIStroke } = {}
	local frameButtons: { [string]: TextButton } = {}
	local frameLocks: { [string]: Frame } = {}
	local frameOrders: { [string]: number } = {}
	local limbButtons: { [string]: TextButton } = {}
	local skinStrokes: { [string]: UIStroke } = {}

	local function freezeFlex(gui: GuiObject)
		local item = Instance.new("UIFlexItem")
		item.FlexMode = Enum.UIFlexMode.None
		item.Parent = gui
	end

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

	local ed = UiTheme.editor
	-- Whole Studio column scrolls so Skin/Frames squares never steal the Shapes section.
	local holder = Instance.new("ScrollingFrame")
	holder.Name = "ShapeList"
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -UiTheme.safe.side, 0, UiTheme.safe.top)
	holder.Size = UDim2.new(0, UiTheme.safe.dock, 1, -(UiTheme.safe.top + UiTheme.safe.bottom))
	holder.BackgroundColor3 = ed.bg
	holder.BackgroundTransparency = 0
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = true
	holder.ScrollingDirection = Enum.ScrollingDirection.Y
	holder.ScrollBarThickness = 5
	holder.ScrollBarImageColor3 = ed.muted
	holder.ElasticBehavior = Enum.ElasticBehavior.Never
	holder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	holder.CanvasSize = UDim2.fromOffset(0, 0)
	holder.ScrollingEnabled = true
	holder.Active = true
	holder.Parent = screenGui
	corner(holder, 8)
	local bookStroke = stroke(holder, ed.hairline)
	bookStroke.Transparency = 0
	bookStroke.Thickness = 1

	local panelPad = Instance.new("UIPadding")
	panelPad.PaddingTop = UDim.new(0, 16)
	panelPad.PaddingBottom = UDim.new(0, 14)
	panelPad.PaddingLeft = UDim.new(0, 14)
	panelPad.PaddingRight = UDim.new(0, 14)
	panelPad.Parent = holder
	local panelList = Instance.new("UIListLayout")
	panelList.FillDirection = Enum.FillDirection.Vertical
	panelList.Padding = UDim.new(0, 14)
	panelList.SortOrder = Enum.SortOrder.LayoutOrder
	panelList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	panelList.VerticalFlex = Enum.UIFlexAlignment.None
	panelList.Parent = holder

	local function sectionLabel(name: string, text: string, order: number): TextLabel
		local heading = Instance.new("TextLabel")
		heading.Name = name
		heading.BackgroundTransparency = 1
		heading.LayoutOrder = order
		heading.FontFace = UiTheme.font.bold
		heading.TextSize = 11
		heading.TextColor3 = ed.muted
		heading.TextStrokeTransparency = 1
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.Text = text
		heading.Size = UDim2.new(1, 0, 0, 16)
		heading.Parent = holder
		freezeFlex(heading)
		return heading
	end

	local bookTitle = Instance.new("TextLabel")
	bookTitle.Name = "BookTitle"
	bookTitle.BackgroundTransparency = 1
	bookTitle.LayoutOrder = 0
	bookTitle.FontFace = UiTheme.font.heavy
	bookTitle.TextSize = 18
	bookTitle.TextColor3 = ed.text
	bookTitle.TextStrokeTransparency = 1
	bookTitle.TextXAlignment = Enum.TextXAlignment.Left
	bookTitle.Text = "Studio"
	bookTitle.Size = UDim2.new(1, 0, 0, 22)
	bookTitle.Parent = holder
	freezeFlex(bookTitle)

	sectionLabel("LimbHeading", "LIMB", 1)

	local limbScroll = Instance.new("ScrollingFrame")
	limbScroll.Name = "Limbs"
	limbScroll.LayoutOrder = 2
	limbScroll.BackgroundTransparency = 1
	limbScroll.BorderSizePixel = 0
	limbScroll.ClipsDescendants = true
	limbScroll.ScrollBarThickness = 3
	limbScroll.ScrollingDirection = Enum.ScrollingDirection.X
	limbScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	limbScroll.CanvasSize = UDim2.fromOffset(0, 0)
	limbScroll.Size = UDim2.new(1, 0, 0, 36)
	limbScroll.Parent = holder
	freezeFlex(limbScroll)
	local limbLayout = Instance.new("UIListLayout")
	limbLayout.FillDirection = Enum.FillDirection.Horizontal
	limbLayout.Padding = UDim.new(0, 10)
	limbLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	limbLayout.SortOrder = Enum.SortOrder.LayoutOrder
	limbLayout.HorizontalFlex = Enum.UIFlexAlignment.None
	limbLayout.VerticalFlex = Enum.UIFlexAlignment.None
	limbLayout.Parent = limbScroll

	sectionLabel("SkinHeading", "SKIN", 3)

	local skinScroll = Instance.new("ScrollingFrame")
	skinScroll.Name = "Skin"
	skinScroll.LayoutOrder = 4
	skinScroll.BackgroundTransparency = 1
	skinScroll.BorderSizePixel = 0
	skinScroll.ClipsDescendants = true
	skinScroll.ScrollBarThickness = 3
	skinScroll.ScrollingDirection = Enum.ScrollingDirection.X
	skinScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	skinScroll.CanvasSize = UDim2.fromOffset(0, 0)
	skinScroll.Size = UDim2.new(1, 0, 0, CHIP)
	skinScroll.ElasticBehavior = Enum.ElasticBehavior.Never
	skinScroll.ScrollingEnabled = true
	skinScroll.Parent = holder
	freezeFlex(skinScroll)
	local skinLayout = Instance.new("UIListLayout")
	skinLayout.FillDirection = Enum.FillDirection.Horizontal
	skinLayout.Padding = UDim.new(0, CHIP_GAP)
	skinLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	skinLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	skinLayout.SortOrder = Enum.SortOrder.LayoutOrder
	skinLayout.HorizontalFlex = Enum.UIFlexAlignment.None
	skinLayout.VerticalFlex = Enum.UIFlexAlignment.None
	skinLayout.Parent = skinScroll

	sectionLabel("FrameHeading", "FRAMES", 5)

	local frameScroll = Instance.new("ScrollingFrame")
	frameScroll.Name = "Frames"
	frameScroll.LayoutOrder = 6
	frameScroll.BackgroundTransparency = 1
	frameScroll.BorderSizePixel = 0
	frameScroll.ClipsDescendants = true
	frameScroll.ScrollBarThickness = 3
	frameScroll.ScrollingDirection = Enum.ScrollingDirection.X
	frameScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	frameScroll.CanvasSize = UDim2.fromOffset(0, 0)
	frameScroll.Size = UDim2.new(1, 0, 0, CHIP)
	frameScroll.ElasticBehavior = Enum.ElasticBehavior.Never
	frameScroll.ScrollingEnabled = true
	frameScroll.Parent = holder
	freezeFlex(frameScroll)
	local frameLayout = Instance.new("UIListLayout")
	frameLayout.FillDirection = Enum.FillDirection.Horizontal
	frameLayout.Padding = UDim.new(0, CHIP_GAP)
	frameLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	frameLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	frameLayout.SortOrder = Enum.SortOrder.LayoutOrder
	frameLayout.HorizontalFlex = Enum.UIFlexAlignment.None
	frameLayout.VerticalFlex = Enum.UIFlexAlignment.None
	frameLayout.Parent = frameScroll

	sectionLabel("ShapeHeading", "SHAPES", 7)

	-- Shape tiles live in a sized frame; the outer Studio panel scrolls to reach them.
	local shapeScroll = Instance.new("Frame")
	shapeScroll.Name = "Shapes"
	shapeScroll.LayoutOrder = 8
	shapeScroll.BackgroundTransparency = 1
	shapeScroll.BorderSizePixel = 0
	shapeScroll.Size = UDim2.fromScale(1, 0)
	shapeScroll.AutomaticSize = Enum.AutomaticSize.Y
	shapeScroll.Parent = holder
	freezeFlex(shapeScroll)
	local shapeGrid = Instance.new("UIGridLayout")
	shapeGrid.CellPadding = UDim2.fromOffset(10, 10)
	shapeGrid.CellSize = UDim2.fromOffset(120, 78)
	shapeGrid.FillDirection = Enum.FillDirection.Horizontal
	shapeGrid.FillDirectionMaxCells = 2
	shapeGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	shapeGrid.SortOrder = Enum.SortOrder.LayoutOrder
	shapeGrid.Parent = shapeScroll
	local shapePad = Instance.new("UIPadding")
	shapePad.PaddingTop = UDim.new(0, 4)
	shapePad.PaddingRight = UDim.new(0, 4)
	shapePad.PaddingBottom = UDim.new(0, 12)
	shapePad.Parent = shapeScroll

	local function layoutShapes()
		local width = math.max(80, shapeScroll.AbsoluteSize.X - 8)
		local cols = if width >= 220 then 2 else 1
		local gap = 10
		local cellW = math.floor((width - gap * (cols - 1)) / cols)
		local cellH = math.clamp(cellW - 32, 76, 92)
		shapeGrid.FillDirectionMaxCells = cols
		shapeGrid.CellPadding = UDim2.fromOffset(gap, gap)
		shapeGrid.CellSize = UDim2.fromOffset(cellW, cellH)
	end
	shapeScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutShapes)
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutShapes)

	local dock = Instance.new("Frame")
	dock.Name = "Dock"
	dock.LayoutOrder = 9
	dock.BackgroundTransparency = 1
	dock.Size = UDim2.fromScale(1, 0)
	dock.AutomaticSize = Enum.AutomaticSize.Y
	dock.Parent = holder
	freezeFlex(dock)
	local dockList = Instance.new("UIListLayout")
	dockList.FillDirection = Enum.FillDirection.Vertical
	dockList.Padding = UDim.new(0, 10)
	dockList.SortOrder = Enum.SortOrder.LayoutOrder
	dockList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockList.Parent = dock

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.LayoutOrder = 10
	status.BackgroundTransparency = 1
	status.FontFace = UiTheme.font.medium
	status.TextSize = 12
	status.TextColor3 = ed.muted
	status.TextWrapped = false
	status.TextTruncate = Enum.TextTruncate.AtEnd
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Center
	status.Text = "Circle, square, triangle, line, heart, and star are free."
	status.Size = UDim2.new(1, 0, 0, 18)
	status.Parent = holder
	freezeFlex(status)

	local function swatchColor(): { r: number, g: number, b: number }
		local swatch = InkColors.get(selectedColorId)
		if swatch == nil then
			return { r = 0.07, g = 0.06, b = 0.08 }
		end
		return { r = swatch.r, g = swatch.g, b = swatch.b }
	end

	local function updateChrome()
		for index, region in BodyRegions.all do
			local button = limbButtons[region.id]
			if button == nil then
				continue
			end
			local selected = region.id == selectedRegion
			button.LayoutOrder = index
			button.BackgroundColor3 = ed.surface
			button.FontFace = if selected then UiTheme.font.heavy else UiTheme.font.medium
			button.TextColor3 = if selected then Color3.new(1, 1, 1) else ed.muted
			button.TextStrokeTransparency = 1
			local limbStroke = button:FindFirstChildOfClass("UIStroke")
			if limbStroke ~= nil then
				limbStroke.Color = ed.hairline
				limbStroke.Transparency = 0
				limbStroke.Thickness = 1
			end
		end
		for id, uiStroke in stencilStrokes do
			local selected = id == selectedStencilId
			uiStroke.Color = if selected then Color3.new(1, 1, 1) else ed.hairline
			uiStroke.Transparency = 0
			uiStroke.Thickness = if selected then 2 else 1
		end
		for id, uiStroke in skinStrokes do
			local selected = id == selectedSkinId
			uiStroke.Color = if selected then Color3.new(1, 1, 1) else ed.hairline
			uiStroke.Thickness = if selected then 2 else 1
			uiStroke.Transparency = 0
		end
		for id, button in stencilButtons do
			local owned = PlayerData.ownsStencil(id)
			local selected = id == selectedStencilId
			local order = stencilOrder[id] or 0
			button.LayoutOrder = if owned then order else 1000 + order
			button.BackgroundTransparency = 0
			button.BackgroundColor3 = ed.surface
			for _, child in button:GetChildren() do
				if child:IsA("TextLabel") and child.Name ~= "Lock" then
					child.FontFace = if selected then UiTheme.font.heavy else UiTheme.font.medium
					child.TextColor3 = if selected then Color3.new(1, 1, 1) else ed.muted
				end
			end
			local lock = button:FindFirstChild("Lock")
			if lock ~= nil and lock:IsA("GuiObject") then
				lock.Visible = not owned
			end
		end
		local wornFrame = PlayerData.equippedItem("frame")
		local wornId = if wornFrame ~= nil then wornFrame.id else ""
		for id, uiStroke in frameStrokes do
			local selected = id == wornId or (id == "none" and wornId == "")
			uiStroke.Color = if selected then Color3.new(1, 1, 1) else ed.hairline
			uiStroke.Transparency = 0
			uiStroke.Thickness = if selected then 2 else 1
			local button = frameButtons[id]
			if button ~= nil then
				if id == "none" then
					button.BackgroundColor3 = ed.surface
					button.FontFace = if selected then UiTheme.font.heavy else UiTheme.font.bold
					button.TextColor3 = if selected then Color3.new(1, 1, 1) else ed.muted
				end
			end
		end
		for id, lock in frameLocks do
			if id == "none" then
				lock.Visible = false
			else
				local owned = PlayerData.owns(id)
				lock.Visible = not owned
				local button = frameButtons[id]
				if button ~= nil then
					button.BackgroundTransparency = 0
					local order = frameOrders[id] or 1
					button.LayoutOrder = if owned then order else 1000 + order
				end
			end
		end
		TattooCanvas.setCaseFrame(if wornId ~= "" then wornId else nil)
	end

	local function syncInspector()
		local panel = markPanel
		if panel == nil then
			return
		end
		if selectedIndex == nil then
			panel.hide()
			TattooCanvas.setMargins(0)
			return
		end
		local element = design.elements[selectedIndex]
		if element == nil then
			panel.hide()
			TattooCanvas.setMargins(0)
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
		TattooCanvas.setMargins(268)
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
		if not PlayerData.ownsStencil(stencilId) then
			local bundle = Catalogue.packFor(stencilId)
			local packName = if bundle ~= nil then bundle.name else "that pack"
			Toasts.show(`Unlock {packName} in the Studio shop.`, "info")
			return
		end
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
		local already = selectedIndex == index
		selectedIndex = index
		statusOverride = nil
		-- Rebuilding marks mid-press destroys the × button and eats the delete click.
		if not already then
			TattooCanvas.render(design, selectedIndex)
			updateStatus()
			syncInspector()
		end
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

	local deleteLock = false
	local function removeAt(index: number)
		if deleteLock or design.elements[index] == nil then
			return
		end
		deleteLock = true
		table.remove(design.elements, index)
		selectedIndex = nil
		statusOverride = nil
		refresh()
		task.defer(function()
			deleteLock = false
		end)
	end

	local function removeSelected()
		if selectedIndex == nil then
			statusOverride = "Select a mark first."
			updateStatus()
			return
		end
		removeAt(selectedIndex)
	end

	TattooCanvas.setDeleteHandler(removeAt)

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
			local inkId = InkColors.matchId(color)
			if inkId == nil or not PlayerData.ownsInk(inkId) then
				Toasts.show("Unlock that ink in the Studio shop.", "info")
				return
			end
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
			local inkId = InkColors.matchId(color)
			if inkId == nil or not PlayerData.ownsInk(inkId) then
				Toasts.show("Unlock that ink in the Studio shop.", "info")
				return
			end
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

	for index, region in BodyRegions.all do
		local limbButton = Instance.new("TextButton")
		limbButton.Name = region.id
		limbButton.LayoutOrder = index
		limbButton.AutoButtonColor = false
		limbButton.Text = region.label
		limbButton.FontFace = UiTheme.font.medium
		limbButton.TextSize = 12
		limbButton.TextColor3 = ed.muted
		limbButton.TextStrokeTransparency = 1
		limbButton.BackgroundColor3 = ed.surface
		limbButton.BorderSizePixel = 0
		limbButton.AutomaticSize = Enum.AutomaticSize.X
		limbButton.Size = UDim2.fromOffset(0, 28)
		limbButton.Selectable = false
		limbButton.Parent = limbScroll
		corner(limbButton, 6)
		stroke(limbButton, ed.hairline).Transparency = 0
		limbButtons[region.id] = limbButton
		local limbPad = Instance.new("UIPadding")
		limbPad.PaddingLeft = UDim.new(0, 10)
		limbPad.PaddingRight = UDim.new(0, 10)
		limbPad.Parent = limbButton
		local regionId = region.id
		limbButton.MouseButton1Click:Connect(function()
			Sfx.play("click")
			Juice.punch(limbButton, 1.1)
			selectRegion(regionId)
		end)
	end

	local function pickFrame(itemId: string)
		if itemId == "none" then
			PlayerData.send("unequip", "frame", nil)
			TattooCanvas.setCaseFrame(nil)
			updateChrome()
			return
		end
		if not PlayerData.owns(itemId) then
			local item = Catalogue.get(itemId)
			local tip = if item ~= nil and item.earned then (item.unlockText or "Keep playing") else "Buy it in the Studio shop."
			Toasts.show(`Frame locked — {tip}`, "info")
			return
		end
		PlayerData.send("equip", itemId, nil)
		TattooCanvas.setCaseFrame(itemId)
		updateChrome()
	end

	local function squareChip(parent: Instance, order: number): TextButton
		local button = Instance.new("TextButton")
		button.Name = "Chip"
		button.LayoutOrder = order
		button.AutomaticSize = Enum.AutomaticSize.None
		button.Size = UDim2.fromOffset(CHIP, CHIP)
		button.BackgroundColor3 = ed.surface
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.Selectable = false
		button.Parent = parent
		freezeFlex(button)
		corner(button, 8)
		return button
	end

	do
		local none = squareChip(frameScroll, 0)
		none.Name = "none"
		none.AutoButtonColor = true
		none.Text = "—"
		none.FontFace = UiTheme.font.bold
		none.TextSize = 18
		none.TextColor3 = ed.muted
		frameStrokes.none = stroke(none, ed.hairline)
		frameStrokes.none.Transparency = 0
		frameButtons.none = none
		none.MouseButton1Click:Connect(function()
			Sfx.play("click")
			Juice.punch(none, 1.1)
			pickFrame("none")
		end)
	end

	local frameOrder = 1
	for _, item in Catalogue.all do
		if item.category ~= "frame" then
			continue
		end
		local button = squareChip(frameScroll, frameOrder)
		button.Name = item.id
		frameOrders[item.id] = frameOrder
		frameOrder += 1
		button.AutoButtonColor = true
		frameStrokes[item.id] = stroke(button, ed.hairline)
		frameStrokes[item.id].Transparency = 0
		frameButtons[item.id] = button

		local preview = Instance.new("Frame")
		preview.Name = "Preview"
		preview.BackgroundTransparency = 1
		preview.AnchorPoint = Vector2.new(0.5, 0.5)
		preview.Position = UDim2.fromScale(0.5, 0.5)
		preview.Size = UDim2.fromOffset(30, 30)
		preview.Parent = button
		local accent = if item.accent ~= nil then Catalogue.toColor3(item.accent) else UiTheme.color.gold
		FrameDress.mount(preview, item.style or "line", accent, 2)

		frameLocks[item.id] = UiTheme.greyLock(button, 22, 3)

		local frameId = item.id
		button.MouseButton1Click:Connect(function()
			Sfx.play("click")
			Juice.punch(button, 1.1)
			pickFrame(frameId)
		end)
	end

	for index, tone in TattooCanvas.skinChoices() do
		local toneButton = squareChip(skinScroll, index)
		toneButton.Name = tone.id
		toneButton.BackgroundColor3 = if tone.color ~= nil then tone.color else Color3.fromRGB(232, 184, 150)
		skinStrokes[tone.id] = stroke(toneButton, ed.hairline)
		skinStrokes[tone.id].Transparency = 0
		local toneId = tone.id
		toneButton.MouseButton1Click:Connect(function()
			Sfx.play("click")
			Juice.punch(toneButton, 1.15)
			selectedSkinId = toneId
			TattooCanvas.setSkin(toneId)
			statusOverride = nil
			updateChrome()
			updateStatus()
		end)
	end

	for index, stencil in StencilDefinitions.all do
		local button = Instance.new("TextButton")
		button.Name = stencil.id
		button.LayoutOrder = index
		button.AutoButtonColor = true
		button.Text = ""
		button.BackgroundColor3 = ed.surface
		button.BorderSizePixel = 0
		button.Selectable = false
		button.Size = UDim2.fromScale(1, 1)
		button.Parent = shapeScroll
		corner(button, 8)
		stencilStrokes[stencil.id] = stroke(button, ed.hairline)
		stencilStrokes[stencil.id].Transparency = 0
		stencilButtons[stencil.id] = button
		stencilOrder[stencil.id] = index

		local lock = UiTheme.greyLock(button, 22, 3)
		lock.Position = UDim2.fromScale(0.5, 0.42)

		local preview = Instance.new("Frame")
		preview.BackgroundTransparency = 1
		preview.AnchorPoint = Vector2.new(0.5, 0)
		preview.Position = UDim2.new(0.5, 0, 0, 4)
		preview.Size = UDim2.new(1, -16, 1, -22)
		preview.Parent = button
		StencilView.draw(preview, stencil.shape, ed.text, stencil.image)

		local name = Instance.new("TextLabel")
		name.Name = "Label"
		name.BackgroundTransparency = 1
		name.FontFace = UiTheme.font.medium
		name.TextSize = 11
		name.TextColor3 = ed.muted
		name.TextStrokeTransparency = 1
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = stencil.name
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -3)
		name.Size = UDim2.new(1, -6, 0, 14)
		name.Parent = button

		local stencilId = stencil.id
		button.MouseButton1Click:Connect(function()
			Sfx.play("click")
			Juice.punch(button, 1.12)
			placeFromMenu(stencilId)
		end)
	end
	layoutShapes()

	local function tool(text: string, parent: Frame, callback: () -> ()): TextButton
		local button = Instance.new("TextButton")
		button.AutoButtonColor = true
		button.BackgroundColor3 = ed.surface
		button.BorderSizePixel = 0
		button.FontFace = UiTheme.font.bold
		button.TextSize = 13
		button.TextColor3 = ed.text
		button.Text = text
		button.TextStrokeTransparency = 1
		button.AutoLocalize = false
		button.Size = UDim2.fromOffset(0, 34)
		button.AutomaticSize = Enum.AutomaticSize.X
		button.Parent = parent
		corner(button, 6)
		stroke(button, ed.hairline).Transparency = 0
		local toolPadding = Instance.new("UIPadding")
		toolPadding.PaddingLeft = UDim.new(0, 14)
		toolPadding.PaddingRight = UDim.new(0, 14)
		toolPadding.Parent = button
		button.MouseButton1Click:Connect(function()
			Sfx.play("click")
			Juice.punch(button, 1.1)
			callback()
		end)
		return button
	end

	local toolRow = row(dock)
	toolRow.LayoutOrder = 2
	local clearTool = tool("Clear", toolRow, requestClear)
	clearTool.BackgroundColor3 = ed.surface
	clearTool.TextColor3 = ed.text

	local function beginEditing(snapshot: RoundSnapshot)
		editing = true
		roundId = snapshot.roundId
		designRound = snapshot.designRound
		design = DesignDocument.createEmpty()
		design.region = selectedRegion
		selectedIndex = nil
		selectedSkinId = "peach"
		TattooCanvas.setSkin("peach")
		clearArmed = false
		statusOverride = nil
		-- Welcome / daily cards sit above the editor; clear them so design can start.
		Fanfare.setHold("design", true)
		screenGui.Enabled = true
		TattooCanvas.setInteractive(true)
		TattooCanvas.setCameraLocked(false)
		Juice.punch(holder, 1.06)
		refresh()
		print(
			`{PREFIX} Editor open | match {snapshot.roundId} | design {snapshot.designRound}/{snapshot.designRounds}`
		)
	end

	local function endEditing()
		if not editing then
			return
		end
		editing = false
		submit()
		screenGui.Enabled = false
		TattooCanvas.setMargins(0)
		TattooCanvas.setInteractive(false)
		TattooCanvas.clear()
		TattooCanvas.setCameraLocked(false)
		Fanfare.setHold("design", false)
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
			if statusOverride ~= "Paused — take your time" then
				statusOverride = "Paused — take your time"
				updateStatus()
			end
		elseif statusOverride == "Paused — take your time" then
			statusOverride = nil
			updateStatus()
		end

		-- Pause used to close the book. During design, keep drawing — only freeze the clock.
		if snapshot.paused then
			local stayInDesign = editing and snapshot.state == "TattooCreation"
			if stayInDesign then
				screenGui.Enabled = true
				TattooCanvas.setVisible(true)
				TattooCanvas.setInteractive(true)
			else
				screenGui.Enabled = false
				TattooCanvas.setVisible(false)
				TattooCanvas.setInteractive(false)
			end
			roundId = snapshot.roundId
			designRound = snapshot.designRound
			return
		end

		local leftCreation = editing and snapshot.state ~= "TattooCreation"
		local sameDesign = snapshot.roundId == roundId and snapshot.designRound == designRound
		local enteredCreation = snapshot.state == "TattooCreation" and (not editing or not sameDesign)
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
			TattooCanvas.setInteractive(true)
		end
		roundId = snapshot.roundId
		designRound = snapshot.designRound
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

	PlayerData.changed:Connect(function()
		updateChrome()
		if editing then
			syncInspector()
		end
	end)
	updateChrome()
end

return TattooEditor
