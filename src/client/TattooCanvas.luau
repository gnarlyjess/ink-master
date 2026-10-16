--!strict

-- Flat design canvas. A bare photograph of the chosen limb fills most of the screen.
-- Marks are drawn on a layer above that photo so a drop stays visible.
-- This does not wrap the real arm mesh.

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BodyRegions = require(game:GetService("ReplicatedStorage").Shared.BodyRegions)
local DesignDocument = require(game:GetService("ReplicatedStorage").Shared.DesignDocument)
local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local InkColors = require(game:GetService("ReplicatedStorage").Shared.InkColors)
local StencilDefinitions = require(game:GetService("ReplicatedStorage").Shared.StencilDefinitions)
local StencilView = require(script.Parent.StencilView)
local UiTheme = require(script.Parent.UiTheme)

type TattooDesign = DesignDocument.TattooDesign
type DesignElement = DesignDocument.DesignElement
type BodyRegion = BodyRegions.BodyRegion

local CANVAS_POSITION = UDim2.fromScale(0.015, 0.07)
local CANVAS_SIZE = UDim2.fromScale(0.73, 0.9)
local THUMB_PIXELS = 34
local ROTATE_LIFT = 18
local HANDLE_HIT = 16
local MIN_ZOOM = 1
local MAX_ZOOM = 4
local PAN_SLACK = 0.55

type HandleMode = "scale" | "rotate"

local TattooCanvas = {}

local photoGui: ScreenGui? = nil
local inkGui: ScreenGui? = nil
local viewWindow: GuiObject? = nil
local photoLayer: GuiObject? = nil
local surfacePad: GuiObject? = nil
local captionLabel: TextLabel? = nil
local zoomReadout: TextLabel? = nil
local elementFrames: { [number]: GuiObject } = {}
local shownDesign: TattooDesign? = nil
local shownSelection: number? = nil
local photoCharacter: Model? = nil
local photoRegionId: string? = nil
local skinToneId = "yours"
local acceptsInput = true
local viewZoom = 1
local viewPan = Vector2.zero

type PanDrag = {
	startScreen: Vector2,
	startPan: Vector2,
	moved: boolean,
}

local panDrag: PanDrag? = nil
local hoveredIndex: number? = nil
local applyView: () -> ()
local zoomAt: (number, Vector2) -> ()
local windowCenter: () -> Vector2

type SkinTone = { id: string, name: string, color: Color3? }

local SKIN_TONES: { SkinTone } = {
	{ id = "yours", name = "Yours", color = nil },
	{ id = "fair", name = "Fair", color = Color3.fromRGB(255, 224, 204) },
	{ id = "light", name = "Light", color = Color3.fromRGB(244, 204, 176) },
	{ id = "peach", name = "Peach", color = Color3.fromRGB(232, 184, 150) },
	{ id = "warm", name = "Warm", color = Color3.fromRGB(214, 158, 118) },
	{ id = "tan", name = "Tan", color = Color3.fromRGB(186, 124, 86) },
	{ id = "olive", name = "Olive", color = Color3.fromRGB(154, 110, 78) },
	{ id = "brown", name = "Brown", color = Color3.fromRGB(112, 74, 52) },
	{ id = "deep", name = "Deep", color = Color3.fromRGB(74, 50, 40) },
}

local BARE_PARTS = {
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
	UpperTorso = true,
	LowerTorso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
	Torso = true,
}

local onGrab: (number) -> () = function(_index: number) end
local onBlank: () -> () = function() end
local onMove: (number, number, number) -> () = function(_index: number, _x: number, _y: number) end
local onTransform: (number, number, number) -> () = function(_index: number, _rotation: number, _scale: number) end
local onAdjustStarted: () -> () = function() end

type GestureMode = "move" | HandleMode

type Gesture = {
	mode: GestureMode,
	index: number,
	startCenter: Vector2,
	startUv: Vector2,
	startScale: number,
	startRotation: number,
	startDistance: number,
	startAngle: number,
}

local gesture: Gesture? = nil
local beginGesture: (Vector2) -> () = function(_screen: Vector2) end

local function elementSize(scale: number): UDim2
	if surfacePad == nil then
		return UDim2.fromScale(scale, scale)
	end
	local size = surfacePad.AbsoluteSize
	if size.X <= 1 or size.Y <= 1 then
		return UDim2.fromScale(scale, scale)
	end
	return UDim2.fromScale(scale, scale * (size.X / size.Y))
end

local function corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local function destroyCanvas()
	if photoGui ~= nil then
		photoGui:Destroy()
		photoGui = nil
	end
	if inkGui ~= nil then
		inkGui:Destroy()
		inkGui = nil
	end
	surfacePad = nil
	viewWindow = nil
	photoLayer = nil
	captionLabel = nil
	zoomReadout = nil
	photoCharacter = nil
	photoRegionId = nil
	viewZoom = 1
	viewPan = Vector2.zero
	panDrag = nil
	hoveredIndex = nil
	table.clear(elementFrames)
end

local function findPart(character: Model, region: BodyRegion): BasePart?
	local modern = character:FindFirstChild(region.r15)
	if modern ~= nil and modern:IsA("BasePart") then
		return modern
	end
	local classic = character:FindFirstChild(region.r6)
	if classic ~= nil and classic:IsA("BasePart") then
		return classic
	end
	return nil
end

local function stripClothes(clone: Model)
	local remove: { Instance } = {}
	for _, child in clone:GetChildren() do
		if
			child:IsA("Shirt")
			or child:IsA("Pants")
			or child:IsA("ShirtGraphic")
			or child:IsA("Accessory")
			or child:IsA("CharacterMesh")
		then
			table.insert(remove, child)
		end
	end
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("WrapLayer") or descendant:IsA("SurfaceAppearance") then
			table.insert(remove, descendant)
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			local parent = descendant.Parent
			if parent == nil or parent.Name ~= "Head" then
				table.insert(remove, descendant)
			end
		end
	end
	for _, item in remove do
		item:Destroy()
	end
end

local function prepareClone(character: Model): Model
	local wasArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = wasArchivable
	stripClothes(clone)

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("BillboardGui") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end

	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.PlatformStand = true
	end
	return clone
end

local function avatarSkin(character: Model): Color3
	local colors = character:FindFirstChildOfClass("BodyColors")
	if colors ~= nil then
		return colors.LeftLegColor.Color
	end
	local leg = character:FindFirstChild("LeftUpperLeg") or character:FindFirstChild("Left Leg")
	if leg ~= nil and leg:IsA("BasePart") then
		return leg.Color
	end
	return Color3.fromRGB(232, 184, 150)
end

local function toneColor(character: Model): Color3
	for _, tone in SKIN_TONES do
		if tone.id == skinToneId and tone.color ~= nil then
			return tone.color
		end
	end
	return avatarSkin(character)
end

local function paintBare(clone: Model, color: Color3)
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") and BARE_PARTS[descendant.Name] == true then
			descendant.Color = color
			descendant.Material = Enum.Material.SmoothPlastic
			if descendant:IsA("MeshPart") then
				descendant.TextureID = ""
			end
		end
	end
end

local function isLeg(region: BodyRegion): boolean
	return string.find(region.id, "Thigh") ~= nil or string.find(region.id, "Calf") ~= nil
end

local function framePart(viewport: ViewportFrame, clone: Model, region: BodyRegion)
	local part = findPart(clone, region)
	local root = clone:FindFirstChild("HumanoidRootPart")
	if part == nil then
		return
	end

	local outward = part.CFrame.LookVector
	if root ~= nil and root:IsA("BasePart") then
		if region.side == "left" then
			outward = -root.CFrame.RightVector
		elseif region.side == "right" then
			outward = root.CFrame.RightVector
		elseif region.side == "back" then
			outward = -root.CFrame.LookVector
		else
			outward = root.CFrame.LookVector
		end
		-- A pure side view turns a thigh into a thin edge. Open it toward the front.
		if isLeg(region) then
			outward = (outward + root.CFrame.LookVector * 0.55).Unit
		end
	end

	local focus = part.Position
	if string.find(region.id, "Thigh") ~= nil then
		focus += part.CFrame.UpVector * part.Size.Y * 0.16
	elseif string.find(region.id, "Calf") ~= nil then
		focus -= part.CFrame.UpVector * part.Size.Y * 0.2
	end

	local distance = if region.torso then 3.1 else 1.65
	local fov = if region.torso then 32 else 28
	if isLeg(region) then
		local span = math.max(part.Size.Y, part.Size.X, part.Size.Z)
		fov = 24
		distance = (span * 1.5 * 0.5) / math.tan(math.rad(fov * 0.5))
		distance = math.clamp(distance, 2.8, 7.5)
	end

	local camera = Instance.new("Camera")
	camera.Name = "LimbCamera"
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(focus + outward * distance, focus, Vector3.yAxis)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function buildCanvas(character: Model, region: BodyRegion)
	destroyCanvas()

	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return
	end

	local photo = Instance.new("ScreenGui")
	photo.Name = "InkMastersCanvas"
	photo.ResetOnSpawn = false
	photo.IgnoreGuiInset = true
	photo.DisplayOrder = 15
	photo.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	photo.Parent = playerGui
	photoGui = photo

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Active = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.55
	dim.BorderSizePixel = 0
	dim.Parent = photo

	local board = Instance.new("Frame")
	board.Name = "Board"
	board.Position = CANVAS_POSITION
	board.Size = CANVAS_SIZE
	board.BackgroundColor3 = Color3.fromRGB(24, 20, 22)
	board.BorderSizePixel = 0
	board.ClipsDescendants = true
	board.Parent = photo
	corner(board, 16)
	local boardStroke = Instance.new("UIStroke")
	boardStroke.Color = UiTheme.color.stroke
	boardStroke.Thickness = 1.5
	boardStroke.Parent = board

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Photo"
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.5, 0.5)
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = Color3.fromRGB(54, 42, 44)
	viewport.BackgroundTransparency = 0
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(120, 104, 96)
	viewport.LightColor = Color3.fromRGB(255, 214, 180)
	viewport.LightDirection = Vector3.new(-0.35, -1, -0.45)
	viewport.Active = false
	viewport.ZIndex = 1
	viewport.Parent = board
	photoLayer = viewport

	local clone = prepareClone(character)
	paintBare(clone, toneColor(character))
	if findPart(clone, region) ~= nil then
		local world = Instance.new("WorldModel")
		world.Name = "PhotoWorld"
		world.Parent = viewport
		clone.Parent = world
		framePart(viewport, clone, region)
	else
		viewport.Visible = false
		clone:Destroy()
		warn(`[InkMasters] This avatar has no {region.label} to photograph.`)
	end

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 0.35
	caption.BackgroundColor3 = UiTheme.color.ink
	caption.FontFace = UiTheme.font.bold
	caption.TextSize = 14
	caption.TextColor3 = UiTheme.color.text
	caption.Text = string.upper(region.label)
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.Size = UDim2.fromOffset(180, 28)
	caption.Position = UDim2.fromOffset(12, 12)
	caption.ZIndex = 5
	caption.Parent = board
	corner(caption, 8)
	local captionPad = Instance.new("UIPadding")
	captionPad.PaddingLeft = UDim.new(0, 10)
	captionPad.Parent = caption
	captionLabel = caption

	-- A second ScreenGui keeps the ink above the viewport photo.
	local ink = Instance.new("ScreenGui")
	ink.Name = "InkMastersInk"
	ink.ResetOnSpawn = false
	ink.IgnoreGuiInset = true
	ink.DisplayOrder = 17
	ink.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ink.Parent = playerGui
	inkGui = ink

	local window = Instance.new("Frame")
	window.Name = "View"
	window.Active = false
	window.BackgroundTransparency = 1
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.Position = CANVAS_POSITION
	window.Size = CANVAS_SIZE
	window.ZIndex = 2
	window.Parent = ink
	viewWindow = window

	local pad = Instance.new("Frame")
	pad.Name = "Marks"
	pad.Active = false
	pad.BackgroundTransparency = 1
	pad.BorderSizePixel = 0
	pad.AnchorPoint = Vector2.new(0.5, 0.5)
	pad.Position = UDim2.fromScale(0.5, 0.5)
	pad.Size = UDim2.fromScale(1, 1)
	pad.ZIndex = 2
	pad.Parent = window
	surfacePad = pad

	local tools = Instance.new("Frame")
	tools.Name = "ViewTools"
	tools.AnchorPoint = Vector2.new(1, 1)
	tools.Position = UDim2.new(0.745, -12, 0.97, -12)
	tools.Size = UDim2.fromOffset(248, 36)
	tools.BackgroundTransparency = 1
	tools.ZIndex = 10
	tools.Parent = ink
	local toolRow = Instance.new("UIListLayout")
	toolRow.FillDirection = Enum.FillDirection.Horizontal
	toolRow.HorizontalAlignment = Enum.HorizontalAlignment.Right
	toolRow.VerticalAlignment = Enum.VerticalAlignment.Center
	toolRow.Padding = UDim.new(0, 6)
	toolRow.SortOrder = Enum.SortOrder.LayoutOrder
	toolRow.Parent = tools

	local function viewButton(text: string, width: number, order: number, callback: () -> ())
		local button = Instance.new("TextButton")
		button.LayoutOrder = order
		button.AutoButtonColor = true
		button.BackgroundColor3 = Color3.fromRGB(250, 246, 240)
		button.BorderSizePixel = 0
		button.FontFace = UiTheme.font.bold
		button.TextSize = 14
		button.TextColor3 = Color3.fromRGB(20, 20, 20)
		button.Text = text
		button.Size = UDim2.fromOffset(width, 32)
		button.ZIndex = 11
		button.Parent = tools
		corner(button, 8)
		button.MouseButton1Click:Connect(callback)
	end

	local readout = Instance.new("TextLabel")
	readout.LayoutOrder = 2
	readout.BackgroundColor3 = Color3.fromRGB(250, 246, 240)
	readout.BorderSizePixel = 0
	readout.FontFace = UiTheme.font.bold
	readout.TextSize = 13
	readout.TextColor3 = Color3.fromRGB(20, 20, 20)
	readout.Text = "100%"
	readout.Size = UDim2.fromOffset(58, 32)
	readout.ZIndex = 11
	readout.Parent = tools
	corner(readout, 8)
	zoomReadout = readout

	photoCharacter = character
	photoRegionId = region.id
	applyView()

	viewButton("−", 32, 1, function()
		zoomAt(1 / 1.2, windowCenter())
	end)
	viewButton("+", 32, 3, function()
		zoomAt(1.2, windowCenter())
	end)
	viewButton("Fit", 52, 4, function()
		viewZoom = 1
		viewPan = Vector2.zero
		applyView()
	end)
end

local function viewMetrics(): (Vector2?, Vector2?)
	if viewWindow == nil then
		return nil, nil
	end
	local window = viewWindow.AbsoluteSize
	if window.X <= 1 or window.Y <= 1 then
		return nil, nil
	end
	local layer = window * viewZoom
	local topLeft = viewWindow.AbsolutePosition + window / 2 + viewPan - layer / 2
	return topLeft, layer
end

local function placeLayer(layer: GuiObject)
	layer.AnchorPoint = Vector2.new(0.5, 0.5)
	layer.Size = UDim2.fromScale(viewZoom, viewZoom)
	layer.Position = UDim2.new(0.5, viewPan.X, 0.5, viewPan.Y)
end

local function clampPan(pan: Vector2): Vector2
	if viewWindow == nil then
		return Vector2.zero
	end
	local window = viewWindow.AbsoluteSize
	local extraX = window.X * (viewZoom - 1) * 0.5
	local extraY = window.Y * (viewZoom - 1) * 0.5
	local limitX = extraX + window.X * PAN_SLACK
	local limitY = extraY + window.Y * PAN_SLACK
	return Vector2.new(math.clamp(pan.X, -limitX, limitX), math.clamp(pan.Y, -limitY, limitY))
end

function windowCenter(): Vector2
	if viewWindow == nil then
		return Vector2.zero
	end
	return viewWindow.AbsolutePosition + viewWindow.AbsoluteSize / 2
end

function applyView()
	viewPan = clampPan(viewPan)
	if photoLayer ~= nil then
		placeLayer(photoLayer)
	end
	if surfacePad ~= nil then
		placeLayer(surfacePad)
	end
	if zoomReadout ~= nil then
		zoomReadout.Text = `{math.floor(viewZoom * 100 + 0.5)}%`
	end
end

function zoomAt(factor: number, focus: Vector2)
	if viewWindow == nil then
		return
	end
	local beforeX, beforeY = TattooCanvas.screenToUv(focus)
	local nextZoom = math.clamp(viewZoom * factor, MIN_ZOOM, MAX_ZOOM)
	if nextZoom == viewZoom then
		return
	end
	viewZoom = nextZoom
	if beforeX ~= nil and beforeY ~= nil then
		local window = viewWindow.AbsoluteSize
		local localPoint = focus - viewWindow.AbsolutePosition
		local layer = window * viewZoom
		viewPan = localPoint - window / 2 + layer / 2 - Vector2.new(beforeX, beforeY) * layer
	end
	applyView()
end

function TattooCanvas.screenToUv(screen: Vector2): (number?, number?)
	local topLeft, layer = viewMetrics()
	if topLeft == nil or layer == nil or viewWindow == nil then
		return nil, nil
	end
	local windowOrigin = viewWindow.AbsolutePosition
	local window = viewWindow.AbsoluteSize
	if
		screen.X < windowOrigin.X
		or screen.Y < windowOrigin.Y
		or screen.X > windowOrigin.X + window.X
		or screen.Y > windowOrigin.Y + window.Y
	then
		return nil, nil
	end
	local x = (screen.X - topLeft.X) / layer.X
	local y = (screen.Y - topLeft.Y) / layer.Y
	if x < 0 or y < 0 or x > 1 or y > 1 then
		return nil, nil
	end
	return x, y
end

function TattooCanvas.placeScale(): number
	local _, layer = viewMetrics()
	local width = if layer ~= nil then layer.X else 0
	if width <= 1 then
		return GameConfig.getMinElementScale()
	end
	return math.clamp(THUMB_PIXELS / width, GameConfig.getMinElementScale(), GameConfig.getMaxElementScale())
end

function TattooCanvas.setHandlers(grabHandler: (number) -> (), blankHandler: () -> ())
	onGrab = grabHandler
	onBlank = blankHandler
end

function TattooCanvas.setMoveHandler(moveHandler: (number, number, number) -> ())
	onMove = moveHandler
end

function TattooCanvas.setTransformHandlers(transformHandler: (number, number, number) -> ())
	onTransform = transformHandler
end

function TattooCanvas.setAdjustStarted(callback: () -> ())
	onAdjustStarted = callback
end

local function elementCenter(element: DesignElement): Vector2?
	local topLeft, layer = viewMetrics()
	if topLeft == nil or layer == nil then
		return nil
	end
	return topLeft + Vector2.new(element.x * layer.X, element.y * layer.Y)
end

local function halfPixels(element: DesignElement): number
	local _, layer = viewMetrics()
	if layer == nil then
		return 18
	end
	return math.max(18, element.scale * layer.X * 0.5)
end

local function markAt(index: number): GuiObject?
	return elementFrames[index]
end

local function markIndexOf(object: Instance): number?
	local current: Instance? = object
	while current ~= nil do
		if string.sub(current.Name, 1, 5) == "Mark_" then
			local index = tonumber(string.sub(current.Name, 6))
			if index ~= nil then
				return index
			end
		end
		current = current.Parent
	end
	return nil
end

-- Roblox's own hit test, in the same space as the click. A transparent frame
-- is easy for the box test to miss, so the shape button is what decides.
local function pickFromPointer(screen: Vector2): (HandleMode?, number?)
	local player = Players.LocalPlayer
	local playerGui = if player ~= nil then player:FindFirstChildOfClass("PlayerGui") else nil
	if playerGui == nil then
		return nil, nil
	end
	local scaleIndex: number? = nil
	local rotateIndex: number? = nil
	local moveIndex: number? = nil
	for _, object in playerGui:GetGuiObjectsAtPosition(screen.X, screen.Y) do
		local index = markIndexOf(object)
		if index ~= nil then
			local onScale = object.Name == "Scale" or object:FindFirstAncestor("Scale") ~= nil
			local onRotate = object.Name == "Rotate" or object:FindFirstAncestor("Rotate") ~= nil
			if onScale then
				scaleIndex = index
			elseif onRotate then
				rotateIndex = index
			elseif moveIndex == nil then
				moveIndex = index
			end
		end
	end
	if scaleIndex ~= nil then
		return "scale", scaleIndex
	end
	if rotateIndex ~= nil then
		return "rotate", rotateIndex
	end
	return nil, moveIndex
end

local function liveCenter(index: number, element: DesignElement): Vector2?
	local mark = markAt(index)
	if mark ~= nil and mark.AbsoluteSize.X > 1 and mark.AbsoluteSize.Y > 1 then
		return mark.AbsolutePosition + mark.AbsoluteSize * 0.5
	end
	return elementCenter(element)
end

local function liveHalf(index: number, element: DesignElement): Vector2
	local mark = markAt(index)
	if mark ~= nil and mark.AbsoluteSize.X > 1 and mark.AbsoluteSize.Y > 1 then
		return mark.AbsoluteSize * 0.5
	end
	local half = halfPixels(element)
	return Vector2.new(half, half)
end

local function localOffset(element: DesignElement, center: Vector2, screen: Vector2): Vector2
	local delta = screen - center
	local angle = -math.rad(element.rotation)
	local cosAngle = math.cos(angle)
	local sinAngle = math.sin(angle)
	return Vector2.new(delta.X * cosAngle - delta.Y * sinAngle, delta.X * sinAngle + delta.Y * cosAngle)
end

local function pointerCandidates(screen: Vector2): { Vector2 }
	local inset = GuiService:GetGuiInset()
	local mouse = UserInputService:GetMouseLocation()
	local shift = Vector2.new(inset.X, inset.Y)
	return { screen, mouse, mouse - shift, screen + shift, screen - shift }
end

local function shapeUnderPointer(screen: Vector2): number?
	local design = shownDesign
	if design == nil then
		return nil
	end
	local bestIndex: number? = nil
	local bestDist = math.huge
	for _, candidate in pointerCandidates(screen) do
		for index = #design.elements, 1, -1 do
			local element = design.elements[index]
			local center = liveCenter(index, element)
			if center ~= nil then
				local half = liveHalf(index, element)
				local reach = math.max(half.X, half.Y) + 12
				local distance = (candidate - center).Magnitude
				if distance <= reach and distance < bestDist then
					bestDist = distance
					bestIndex = index
				end
			end
		end
	end
	return bestIndex
end

local function pickHandle(screen: Vector2): (HandleMode?, number?)
	local design = shownDesign
	local selected = shownSelection
	if design == nil or selected == nil then
		return nil, nil
	end
	local element = design.elements[selected]
	if element == nil then
		return nil, nil
	end
	local center = liveCenter(selected, element)
	if center == nil then
		return nil, nil
	end
	local half = liveHalf(selected, element)
	for _, candidate in pointerCandidates(screen) do
		local localPoint = localOffset(element, center, candidate)
		if (localPoint - Vector2.new(half.X, half.Y)).Magnitude <= HANDLE_HIT then
			return "scale", selected
		end
		if (localPoint - Vector2.new(0, -half.Y - ROTATE_LIFT)).Magnitude <= HANDLE_HIT then
			return "rotate", selected
		end
	end
	return nil, nil
end

local function pickTarget(screen: Vector2): (HandleMode?, number?)
	local handleMode, handleIndex = pickHandle(screen)
	if handleIndex ~= nil and handleMode == "scale" then
		return "scale", handleIndex
	end
	if handleIndex ~= nil and handleMode == "rotate" then
		return "rotate", handleIndex
	end
	local under = shapeUnderPointer(screen)
	if under ~= nil then
		return nil, under
	end
	local pointedMode, pointedIndex = pickFromPointer(screen)
	if pointedIndex ~= nil then
		if pointedMode == "scale" then
			return "scale", pointedIndex
		elseif pointedMode == "rotate" then
			return "rotate", pointedIndex
		end
		return nil, pointedIndex
	end
	return nil, nil
end

local function applyGesture(screen: Vector2)
	local drag = gesture
	if drag == nil or shownDesign == nil then
		return
	end
	local element = shownDesign.elements[drag.index]
	if element == nil then
		gesture = nil
		return
	end
	if drag.mode == "move" then
		local _, layer = viewMetrics()
		if layer == nil or layer.X < 1 or layer.Y < 1 then
			return
		end
		local delta = screen - drag.startCenter
		local x = math.clamp(drag.startUv.X + delta.X / layer.X, 0.06, 0.94)
		local y = math.clamp(drag.startUv.Y + delta.Y / layer.Y, 0.06, 0.94)
		onMove(drag.index, x, y)
		TattooCanvas.nudge(drag.index, x, y)
		return
	end
	local offset = screen - drag.startCenter
	local rotation = drag.startRotation
	local scale = drag.startScale
	if drag.mode == "scale" then
		local distance = math.max(12, offset.Magnitude)
		scale = math.clamp(
			drag.startScale * (distance / drag.startDistance),
			GameConfig.getMinElementScale(),
			GameConfig.getMaxElementScale()
		)
	else
		rotation = drag.startRotation + math.deg(math.atan2(offset.Y, offset.X) - drag.startAngle)
	end
	onTransform(drag.index, rotation, scale)
	local mark = elementFrames[drag.index]
	mark.Rotation = rotation
	mark.Size = elementSize(scale)
end

local function beginMove(index: number, screen: Vector2)
	if gesture ~= nil and gesture.mode == "move" and gesture.index == index then
		return
	end
	local design = shownDesign
	local element = if design ~= nil then design.elements[index] else nil
	if element == nil then
		return
	end
	-- Claim the press before any redraw. A redraw can yield, and a yield used
	-- to let the photo pan start while the shape was still the thing under the cursor.
	panDrag = nil
	gesture = {
		mode = "move",
		index = index,
		startCenter = screen,
		startUv = Vector2.new(element.x, element.y),
		startScale = element.scale,
		startRotation = element.rotation,
		startDistance = 1,
		startAngle = 0,
	}
	onGrab(index)
end

local function beginAdjust(mode: HandleMode, index: number, screen: Vector2)
	local element = if shownDesign ~= nil then shownDesign.elements[index] else nil
	local center = if element ~= nil then elementCenter(element) else nil
	if element == nil or center == nil then
		return
	end
	panDrag = nil
	local offset = screen - center
	gesture = {
		mode = mode,
		index = index,
		startCenter = center,
		startUv = Vector2.new(element.x, element.y),
		startScale = element.scale,
		startRotation = element.rotation,
		startDistance = math.max(12, offset.Magnitude),
		startAngle = math.atan2(offset.Y, offset.X),
	}
	onAdjustStarted()
end

beginGesture = function(screen: Vector2)
	local mode, index = pickTarget(screen)
	if index ~= nil and (mode == "scale" or mode == "rotate") then
		local handleMode: HandleMode = if mode == "scale" then "scale" else "rotate"
		beginAdjust(handleMode, index, screen)
		return
	end
	if index ~= nil then
		beginMove(index, screen)
		return
	end
	if gesture ~= nil then
		return
	end
	gesture = nil
	panDrag = {
		startScreen = screen,
		startPan = viewPan,
		moved = false,
	}
end

-- Thin line icons, the same pair photo editors put on a selection:
-- a two-way diagonal arrow for size, and an open circular arrow for angle.
local ICON = 64
local ICON_SAMPLES = 3

type IconPoint = { x: number, y: number }

local handleIcons: { [string]: EditableImage } = {}
local handleIconsUnavailable = false

local function inPoly(x: number, y: number, points: { IconPoint }): boolean
	local inside = false
	local count = #points
	local previous = count
	for index = 1, count do
		local current = points[index]
		local prior = points[previous]
		if (current.y > y) ~= (prior.y > y) then
			local cross = (prior.x - current.x) * (y - current.y) / (prior.y - current.y) + current.x
			if x < cross then
				inside = not inside
			end
		end
		previous = index
	end
	return inside
end

local function onSegment(x: number, y: number, ax: number, ay: number, bx: number, by: number, width: number): boolean
	local abx = bx - ax
	local aby = by - ay
	local length = abx * abx + aby * aby
	local t = 0
	if length > 0 then
		t = math.clamp(((x - ax) * abx + (y - ay) * aby) / length, 0, 1)
	end
	local dx = x - (ax + abx * t)
	local dy = y - (ay + aby * t)
	return dx * dx + dy * dy <= width * width
end

local function arrowHead(x: number, y: number, tipX: number, tipY: number, dirX: number, dirY: number): boolean
	local baseX = tipX - dirX * 0.16
	local baseY = tipY - dirY * 0.16
	return inPoly(x, y, {
		{ x = tipX, y = tipY },
		{ x = baseX - dirY * 0.085, y = baseY + dirX * 0.085 },
		{ x = baseX + dirY * 0.085, y = baseY - dirX * 0.085 },
	})
end

local function scaleGlyph(x: number, y: number): boolean
	local x0, y0 = 0.2, 0.8
	local x1, y1 = 0.8, 0.2
	local dx = x1 - x0
	local dy = y1 - y0
	local length = math.sqrt(dx * dx + dy * dy)
	dx /= length
	dy /= length
	local shaft = onSegment(x, y, x0 + dx * 0.08, y0 + dy * 0.08, x1 - dx * 0.08, y1 - dy * 0.08, 0.032)
	return shaft or arrowHead(x, y, x1, y1, dx, dy) or arrowHead(x, y, x0, y0, -dx, -dy)
end

local function rotateGlyph(x: number, y: number): boolean
	local center = 0.5
	local radius = 0.3
	local dx = x - center
	local dy = y - center
	local angle = math.atan2(dy, dx)
	local gapStart = -1.35
	local gapEnd = -0.15
	local ring = (dx * dx + dy * dy) > 0 and math.abs(math.sqrt(dx * dx + dy * dy) - radius) <= 0.034
	if ring and not (angle >= gapStart and angle <= gapEnd) then
		return true
	end
	local tipX = center + math.cos(gapStart) * radius
	local tipY = center + math.sin(gapStart) * radius
	return arrowHead(x, y, tipX, tipY, -math.sin(gapStart), math.cos(gapStart))
end

local function rasterIcon(kind: HandleMode): buffer
	local pixels = buffer.create(ICON * ICON * 4)
	local step = 1 / ICON_SAMPLES
	for py = 0, ICON - 1 do
		for px = 0, ICON - 1 do
			local cover = 0
			for sampleY = 0, ICON_SAMPLES - 1 do
				for sampleX = 0, ICON_SAMPLES - 1 do
					local x = (px + (sampleX + 0.5) * step) / ICON
					local y = (py + (sampleY + 0.5) * step) / ICON
					local hit = if kind == "scale" then scaleGlyph(x, y) else rotateGlyph(x, y)
					if hit then
						cover += 1
					end
				end
			end
			if cover > 0 then
				local index = (py * ICON + px) * 4
				buffer.writeu8(pixels, index, 255)
				buffer.writeu8(pixels, index + 1, 255)
				buffer.writeu8(pixels, index + 2, 255)
				buffer.writeu8(pixels, index + 3, math.floor(cover * 255 / (ICON_SAMPLES * ICON_SAMPLES)))
			end
		end
	end
	return pixels
end

local function cachedHandleIcon(kind: HandleMode): EditableImage?
	return handleIcons[kind]
end

local function handleIcon(kind: HandleMode): EditableImage?
	if handleIconsUnavailable then
		return nil
	end
	local cached = cachedHandleIcon(kind)
	if cached ~= nil then
		return cached
	end
	local created: EditableImage? = nil
	local ok = pcall(function()
		created = AssetService:CreateEditableImage({
			Size = Vector2.new(ICON, ICON),
		})
	end)
	if not ok or created == nil then
		handleIconsUnavailable = true
		return nil
	end
	created:WritePixelsBuffer(Vector2.zero, Vector2.new(ICON, ICON), rasterIcon(kind))
	handleIcons[kind] = created
	return created
end

local function makeHandle(parent: GuiObject, name: string, kind: HandleMode, position: UDim2, index: number)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = position
	button.Size = UDim2.fromOffset(28, 28)
	button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	button.BorderSizePixel = 0
	button.Active = true
	button.Selectable = false
	button.ZIndex = 40
	button.Parent = parent
	button.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		beginAdjust(kind, index, Vector2.new(input.Position.X, input.Position.Y))
	end)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(1, 0)
	uiCorner.Parent = button
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(20, 20, 20)
	outline.Thickness = 1
	outline.Transparency = 0.35
	outline.Parent = button

	local image = handleIcon(kind)
	if image == nil then
		return
	end
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(13, 13)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ImageColor3 = Color3.fromRGB(20, 20, 20)
	icon.ImageContent = Content.fromObject(image)
	icon.ZIndex = 41
	icon.Parent = button
end

function TattooCanvas.render(design: TattooDesign, selectedIndex: number?)
	shownDesign = design
	shownSelection = selectedIndex
	if surfacePad == nil then
		return
	end

	for _, frame in elementFrames do
		frame:Destroy()
	end
	table.clear(elementFrames)

	for index, element: DesignElement in design.elements do
		local stencil = StencilDefinitions.get(element.stencilId)
		local mark = Instance.new("TextButton")
		mark.Name = `Mark_{index}`
		mark.Text = ""
		mark.AutoButtonColor = false
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(element.x, element.y)
		mark.Size = elementSize(element.scale)
		mark.Rotation = element.rotation
		mark.BackgroundTransparency = 1
		mark.BorderSizePixel = 0
		mark.Active = true
		mark.Selectable = false
		mark.ZIndex = 3 + index
		mark.Parent = surfacePad
		local shapeIndex = index
		mark.MouseEnter:Connect(function()
			hoveredIndex = shapeIndex
		end)
		mark.MouseLeave:Connect(function()
			if hoveredIndex == shapeIndex then
				hoveredIndex = nil
			end
		end)
		mark.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local screen = Vector2.new(input.Position.X, input.Position.Y)
			hoveredIndex = shapeIndex
			beginMove(shapeIndex, screen)
		end)

		local stroke = Instance.new("UIStroke")
		stroke.Name = "Selection"
		stroke.Color = Color3.fromRGB(250, 246, 240)
		stroke.Thickness = 1.5
		stroke.Enabled = index == selectedIndex
		stroke.Parent = mark

		local shape = if stencil ~= nil then stencil.shape else "disc"
		StencilView.drawMark(mark, shape, InkColors.toColor3(element.color), InkColors.toColor3(element.line), {
			fill = element.fill,
			outline = element.outline,
			thickness = element.thickness,
			opacity = element.opacity,
			flip = element.flip,
		})

		if index == selectedIndex then
			makeHandle(mark, "Scale", "scale", UDim2.fromScale(1, 1), index)
			makeHandle(mark, "Rotate", "rotate", UDim2.new(0.5, 0, 0, -ROTATE_LIFT), index)
		end

		elementFrames[index] = mark
	end
end

function TattooCanvas.nudge(index: number, x: number, y: number)
	local mark: GuiObject? = elementFrames[index]
	if mark == nil then
		return
	end
	mark.Position = UDim2.fromScale(x, y)
end

function TattooCanvas.show(character: Model, design: TattooDesign, selectedIndex: number?)
	shownDesign = design
	shownSelection = selectedIndex
	local region = BodyRegions.get(design.region) or BodyRegions.get("LeftForearm")
	if region == nil then
		return
	end
	if captionLabel ~= nil then
		captionLabel.Text = string.upper(region.label)
	end
	if photoGui ~= nil and photoCharacter == character and photoRegionId == region.id and surfacePad ~= nil then
		TattooCanvas.render(design, selectedIndex)
		return
	end
	buildCanvas(character, region)
	if shownDesign ~= nil then
		TattooCanvas.render(shownDesign, shownSelection)
	end
end

function TattooCanvas.skinChoices(): { SkinTone }
	return SKIN_TONES
end

function TattooCanvas.avatarTone(character: Model): Color3
	return avatarSkin(character)
end

function TattooCanvas.setSkin(id: string)
	if skinToneId == id then
		return
	end
	skinToneId = id
	photoRegionId = nil
end

function TattooCanvas.setInteractive(enabled: boolean)
	acceptsInput = enabled
	if not enabled then
		panDrag = nil
		gesture = nil
	end
end

function TattooCanvas.setVisible(visible: boolean)
	if photoGui ~= nil then
		photoGui.Enabled = visible
	end
	if inkGui ~= nil then
		inkGui.Enabled = visible
	end
end

function TattooCanvas.clear()
	shownDesign = nil
	shownSelection = nil
	destroyCanvas()
end

function TattooCanvas.setCameraLocked(_locked: boolean)
	local camera = Workspace.CurrentCamera
	if camera == nil or camera.CameraType ~= Enum.CameraType.Scriptable then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	local localPlayer = Players.LocalPlayer
	local character = if localPlayer ~= nil then localPlayer.Character else nil
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid ~= nil then
		camera.CameraSubject = humanoid
	end
end

UserInputService.InputBegan:Connect(function(input: InputObject)
	if not acceptsInput then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if surfacePad == nil then
		return
	end
	local screen = Vector2.new(input.Position.X, input.Position.Y)
	local mode, index = pickTarget(screen)
	if index == nil and hoveredIndex ~= nil then
		mode = nil
		index = hoveredIndex
	end
	if index ~= nil then
		if mode == "scale" then
			beginAdjust("scale", index, screen)
		elseif mode == "rotate" then
			beginAdjust("rotate", index, screen)
		else
			beginMove(index, screen)
		end
		return
	end
	local player = Players.LocalPlayer
	local playerGui = if player ~= nil then player:FindFirstChildOfClass("PlayerGui") else nil
	if playerGui ~= nil then
		for _, object in playerGui:GetGuiObjectsAtPosition(screen.X, screen.Y) do
			if object:FindFirstAncestor("InkMastersEditor") ~= nil or object.Name == "InkMastersEditor" then
				return
			end
			if object:FindFirstAncestor("ViewTools") ~= nil or object.Name == "ViewTools" then
				return
			end
		end
	end
	local x, _y = TattooCanvas.screenToUv(screen)
	if x == nil then
		return
	end
	beginGesture(screen)
end)

local function pointerHitsEditor(screen: Vector2): boolean
	local player = Players.LocalPlayer
	local playerGui = if player ~= nil then player:FindFirstChildOfClass("PlayerGui") else nil
	if playerGui == nil then
		return false
	end
	local editor = playerGui:FindFirstChild("InkMastersEditor")
	if editor ~= nil and editor:IsA("ScreenGui") and editor.Enabled then
		for _, child in editor:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				local origin = child.AbsolutePosition
				local size = child.AbsoluteSize
				if
					screen.X >= origin.X
					and screen.Y >= origin.Y
					and screen.X <= origin.X + size.X
					and screen.Y <= origin.Y + size.Y
				then
					return true
				end
			end
		end
	end
	return false
end

UserInputService.InputChanged:Connect(function(input: InputObject)
	if not acceptsInput then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if viewWindow == nil then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		local inset = GuiService:GetGuiInset()
		local adjusted = mouse - Vector2.new(inset.X, inset.Y)
		if pointerHitsEditor(mouse) or pointerHitsEditor(adjusted) then
			return
		end
		local screen = Vector2.new(input.Position.X, input.Position.Y)
		if
			pointerHitsEditor(screen)
			or TattooCanvas.screenToUv(mouse) == nil and TattooCanvas.screenToUv(adjusted) == nil
		then
			return
		end
		local factor = if input.Position.Z > 0 then 1.15 else 1 / 1.15
		local focus = if TattooCanvas.screenToUv(mouse) ~= nil then mouse else adjusted
		zoomAt(factor, focus)
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local screen = Vector2.new(input.Position.X, input.Position.Y)
	if gesture ~= nil then
		applyGesture(screen)
		return
	end
	local drag = panDrag
	if drag ~= nil then
		local delta = screen - drag.startScreen
		if delta.Magnitude > 4 then
			drag.moved = true
		end
		viewPan = drag.startPan + delta
		applyView()
		return
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local drag = panDrag
		if drag ~= nil and not drag.moved then
			onBlank()
		end
		panDrag = nil
		gesture = nil
	end
end)

local player = Players.LocalPlayer
if player ~= nil then
	player.CharacterAdded:Connect(function(character: Model)
		if shownDesign == nil then
			return
		end
		photoCharacter = nil
		TattooCanvas.show(character, shownDesign, shownSelection)
	end)
end

return TattooCanvas
