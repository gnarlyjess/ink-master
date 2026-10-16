--!strict

-- Flat design canvas. A bare photograph of the chosen limb fills most of the screen.
-- Marks are drawn on a layer above that photo so a drop stays visible.
-- This does not wrap the real arm mesh.

local Players = game:GetService("Players")
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

type HandleMode = "scale" | "rotate"

local TattooCanvas = {}

local photoGui: ScreenGui? = nil
local inkGui: ScreenGui? = nil
local surfacePad: GuiObject? = nil
local captionLabel: TextLabel? = nil
local elementFrames: { [number]: Frame } = {}
local shownDesign: TattooDesign? = nil
local shownSelection: number? = nil
local photoCharacter: Model? = nil
local photoRegionId: string? = nil

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
	captionLabel = nil
	photoCharacter = nil
	photoRegionId = nil
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
	end

	local distance = if region.torso then 3.1 else 1.65
	local camera = Instance.new("Camera")
	camera.Name = "LimbCamera"
	camera.FieldOfView = if region.torso then 32 else 28
	camera.CFrame = CFrame.lookAt(part.Position + outward * distance, part.Position, Vector3.yAxis)
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
	dim.Active = true
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.55
	dim.BorderSizePixel = 0
	dim.Parent = photo

	local board = Instance.new("Frame")
	board.Name = "Board"
	board.Position = CANVAS_POSITION
	board.Size = CANVAS_SIZE
	board.BackgroundColor3 = Color3.fromRGB(214, 170, 148)
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
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(210, 200, 190)
	viewport.LightColor = Color3.fromRGB(255, 248, 240)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.2)
	viewport.Parent = board

	local clone = prepareClone(character)
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

	local pad = Instance.new("TextButton")
	pad.Name = "Marks"
	pad.Text = ""
	pad.AutoButtonColor = false
	pad.Active = true
	pad.BackgroundTransparency = 1
	pad.BorderSizePixel = 0
	pad.Position = CANVAS_POSITION
	pad.Size = CANVAS_SIZE
	pad.ZIndex = 2
	pad.Parent = ink
	surfacePad = pad
	photoCharacter = character
	photoRegionId = region.id
end

function TattooCanvas.screenToUv(screen: Vector2): (number?, number?)
	if surfacePad == nil then
		return nil, nil
	end
	local size = surfacePad.AbsoluteSize
	if size.X <= 1 or size.Y <= 1 then
		return nil, nil
	end
	local origin = surfacePad.AbsolutePosition
	local x = (screen.X - origin.X) / size.X
	local y = (screen.Y - origin.Y) / size.Y
	if x < 0 or y < 0 or x > 1 or y > 1 then
		return nil, nil
	end
	return x, y
end

function TattooCanvas.placeScale(): number
	local width = if surfacePad ~= nil then surfacePad.AbsoluteSize.X else 0
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
	if surfacePad == nil then
		return nil
	end
	local origin = surfacePad.AbsolutePosition
	local size = surfacePad.AbsoluteSize
	return origin + Vector2.new(element.x * size.X, element.y * size.Y)
end

local function halfPixels(element: DesignElement): number
	if surfacePad == nil then
		return 18
	end
	return math.max(18, element.scale * surfacePad.AbsoluteSize.X * 0.5)
end

local function toLocal(element: DesignElement, screen: Vector2): Vector2?
	local center = elementCenter(element)
	if center == nil then
		return nil
	end
	local delta = screen - center
	local angle = -math.rad(element.rotation)
	local cosAngle = math.cos(angle)
	local sinAngle = math.sin(angle)
	return Vector2.new(delta.X * cosAngle - delta.Y * sinAngle, delta.X * sinAngle + delta.Y * cosAngle)
end

local function pickTarget(screen: Vector2): (HandleMode?, number?)
	local design = shownDesign
	if design == nil then
		return nil, nil
	end
	local selected = shownSelection
	if selected ~= nil then
		local element = design.elements[selected]
		if element ~= nil then
			local localPoint = toLocal(element, screen)
			if localPoint ~= nil then
				local half = halfPixels(element)
				if (localPoint - Vector2.new(half + 10, -half - 10)).Magnitude <= 22 then
					return "scale", selected
				end
				if (localPoint - Vector2.new(half + 10, -half - 42)).Magnitude <= 22 then
					return "rotate", selected
				end
			end
		end
	end
	for index = #design.elements, 1, -1 do
		local element = design.elements[index]
		local localPoint = toLocal(element, screen)
		if localPoint ~= nil then
			local half = halfPixels(element)
			if math.abs(localPoint.X) <= half and math.abs(localPoint.Y) <= half then
				return nil, index
			end
		end
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
		local x, y = TattooCanvas.screenToUv(screen)
		if x == nil or y == nil then
			return
		end
		x = math.clamp(x, 0.06, 0.94)
		y = math.clamp(y, 0.06, 0.94)
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

beginGesture = function(screen: Vector2)
	local mode, index = pickTarget(screen)
	if index ~= nil and (mode == "scale" or mode == "rotate") then
		local element = if shownDesign ~= nil then shownDesign.elements[index] else nil
		local center = if element ~= nil then elementCenter(element) else nil
		if element == nil or center == nil then
			return
		end
		onAdjustStarted()
		local offset = screen - center
		local handleMode: HandleMode = if mode == "scale" then "scale" else "rotate"
		gesture = {
			mode = handleMode,
			index = index,
			startCenter = center,
			startScale = element.scale,
			startRotation = element.rotation,
			startDistance = math.max(12, offset.Magnitude),
			startAngle = math.atan2(offset.Y, offset.X),
		}
		return
	end
	if index ~= nil then
		onGrab(index)
		gesture = {
			mode = "move",
			index = index,
			startCenter = screen,
			startScale = 0,
			startRotation = 0,
			startDistance = 1,
			startAngle = 0,
		}
		return
	end
	gesture = nil
	onBlank()
end

local function makeHandle(parent: Frame, name: string, symbol: string, position: UDim2)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = UDim2.fromOffset(28, 28)
	label.Text = symbol
	label.FontFace = UiTheme.font.bold
	label.TextSize = 14
	label.TextColor3 = UiTheme.color.ink
	label.BackgroundColor3 = UiTheme.color.gold
	label.Active = false
	label.AutoLocalize = false
	label.ZIndex = 40
	label.Parent = parent
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(1, 0)
	uiCorner.Parent = label
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
		local mark = Instance.new("Frame")
		mark.Name = `Mark_{index}`
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(element.x, element.y)
		mark.Size = elementSize(element.scale)
		mark.Rotation = element.rotation
		mark.BackgroundTransparency = 1
		mark.BorderSizePixel = 0
		mark.ZIndex = 3 + index
		mark.Parent = surfacePad

		local stroke = Instance.new("UIStroke")
		stroke.Name = "Selection"
		stroke.Color = UiTheme.color.gold
		stroke.Thickness = 2
		stroke.Enabled = index == selectedIndex
		stroke.Parent = mark

		local shape = if stencil ~= nil then stencil.shape else "disc"
		StencilView.draw(mark, shape, InkColors.toColor3(element.color))

		if index == selectedIndex then
			makeHandle(mark, "Scale", "<->", UDim2.new(1, 10, 0, -10))
			makeHandle(mark, "Rotate", "↻", UDim2.new(1, 10, 0, -42))
		end

		elementFrames[index] = mark
	end
end

function TattooCanvas.nudge(index: number, x: number, y: number)
	local mark: Frame? = elementFrames[index]
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
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if surfacePad == nil then
		return
	end
	local screen = Vector2.new(input.Position.X, input.Position.Y)
	local x, _y = TattooCanvas.screenToUv(screen)
	if x == nil then
		return
	end
	beginGesture(screen)
end)

UserInputService.InputChanged:Connect(function(input: InputObject)
	if gesture == nil then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	applyGesture(Vector2.new(input.Position.X, input.Position.Y))
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
