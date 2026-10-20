--!strict

-- Flat design canvas. A bare photograph of the chosen limb fills most of the screen.
-- Marks are drawn on a layer above that photo so a drop stays visible.
-- This does not wrap the real arm mesh.

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BodyRegions = require(ReplicatedStorage.Shared.BodyRegions)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local DesignDocument = require(ReplicatedStorage.Shared.DesignDocument)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local InkColors = require(ReplicatedStorage.Shared.InkColors)
local StencilDefinitions = require(ReplicatedStorage.Shared.StencilDefinitions)
local FrameDress = require(script.Parent.FrameDress)
local StencilView = require(script.Parent.StencilView)
local UiTheme = require(script.Parent.UiTheme)

type TattooDesign = DesignDocument.TattooDesign
type DesignElement = DesignDocument.DesignElement
type BodyRegion = BodyRegions.BodyRegion

local leftExtra = 0
local stage: Frame? = nil
local boardStroke: UIStroke? = nil
local caseFrameId: string? = nil
local overridePosition: UDim2? = nil
local overrideSize: UDim2? = nil

local function applyCaseFrame()
	local board = stage
	if board == nil then
		return
	end
	FrameDress.clear(board)
	local stroke = boardStroke
	local worn = if caseFrameId ~= nil and caseFrameId ~= "" then Catalogue.get(caseFrameId) else nil
	local accent = if worn ~= nil then worn.accent else nil
	if worn == nil or accent == nil or worn.category ~= "frame" then
		if stroke ~= nil then
			stroke.Transparency = 0.25
		end
		return
	end
	if stroke ~= nil then
		stroke.Transparency = 1
	end
	FrameDress.mount(board, worn.style or "line", Catalogue.toColor3(accent), 2)
end

local function stageFrame(): (UDim2, UDim2)
	if overridePosition ~= nil and overrideSize ~= nil then
		return overridePosition, overrideSize
	end
	local left = UiTheme.safe.side + leftExtra
	local position = UDim2.fromOffset(left, UiTheme.safe.top)
	local size =
		UDim2.new(1, -(left + UiTheme.safe.side * 2 + UiTheme.safe.dock), 1, -(UiTheme.safe.top + UiTheme.safe.bottom))
	return position, size
end

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

local function applyStage()
	local position, size = stageFrame()
	if stage ~= nil then
		stage.Position = position
		stage.Size = size
	end
	if viewWindow ~= nil then
		viewWindow.Position = position
		viewWindow.Size = size
	end
end

function TattooCanvas.setMargins(extra: number)
	leftExtra = math.max(0, extra)
	applyStage()
end

-- Equipped display-case frame preview around the limb board.
function TattooCanvas.setCaseFrame(itemId: string?)
	caseFrameId = if itemId ~= nil and itemId ~= "" then itemId else nil
	applyCaseFrame()
end

-- Ceremony pins the tattoo to a pane. nil, nil restores the editor layout.
function TattooCanvas.setStageOverride(position: UDim2?, size: UDim2?)
	overridePosition = position
	overrideSize = size
	applyStage()
end

local photoLayer: GuiObject? = nil
local canvasDim: Frame? = nil
local surfacePad: GuiObject? = nil
local captionLabel: TextLabel? = nil
local viewTools: GuiObject? = nil
local presentedCaption: string? = nil
local zoomReadout: TextLabel? = nil
local elementFrames: { [number]: GuiObject } = {}
local shownDesign: TattooDesign? = nil
local shownSelection: number? = nil
local photoCharacter: Model? = nil
local photoRegionId: string? = nil
local photoClone: Model? = nil
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
local onDeleteMark: (number) -> () = function(_index: number) end

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

local function destroyNamedGuis(playerGui: Instance, name: string)
	for _, child in playerGui:GetChildren() do
		if child.Name == name then
			child:Destroy()
		end
	end
end

local function destroyCanvas()
	local player = Players.LocalPlayer
	local playerGui = if player ~= nil then player:FindFirstChild("PlayerGui") else nil
	if playerGui ~= nil then
		-- Sweep duplicates from Main running twice (Client RunContext under StarterPlayerScripts).
		destroyNamedGuis(playerGui, "InkMastersCanvas")
		destroyNamedGuis(playerGui, "InkMastersInk")
	elseif photoGui ~= nil then
		photoGui:Destroy()
	elseif inkGui ~= nil then
		inkGui:Destroy()
	end
	photoGui = nil
	inkGui = nil
	surfacePad = nil
	viewWindow = nil
	stage = nil
	boardStroke = nil
	photoLayer = nil
	canvasDim = nil
	captionLabel = nil
	viewTools = nil
	zoomReadout = nil
	photoCharacter = nil
	photoRegionId = nil
	photoClone = nil
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
		local ok, value = pcall(function()
			return colors.LeftLegColor3
		end)
		if ok and typeof(value) == "Color3" then
			return value
		end
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
	local bodyColors = clone:FindFirstChildOfClass("BodyColors")
	if bodyColors ~= nil then
		-- Prefer Color3 fields so light tones (e.g. Fair / Yours) don't snap via BrickColor.
		local ok = pcall(function()
			bodyColors.HeadColor3 = color
			bodyColors.LeftArmColor3 = color
			bodyColors.RightArmColor3 = color
			bodyColors.LeftLegColor3 = color
			bodyColors.RightLegColor3 = color
			bodyColors.TorsoColor3 = color
		end)
		if not ok then
			local brick = BrickColor.new(color)
			bodyColors.HeadColor = brick
			bodyColors.LeftArmColor = brick
			bodyColors.RightArmColor = brick
			bodyColors.LeftLegColor = brick
			bodyColors.RightLegColor = brick
			bodyColors.TorsoColor = brick
		end
	end

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("SurfaceAppearance") then
			local parent = descendant.Parent
			if parent ~= nil and parent:IsA("BasePart") and BARE_PARTS[parent.Name] == true then
				descendant:Destroy()
			end
		elseif descendant:IsA("BasePart") and BARE_PARTS[descendant.Name] == true then
			descendant.Color = color
			descendant.Material = Enum.Material.SmoothPlastic
			if descendant:IsA("MeshPart") then
				descendant.TextureID = ""
			end
		end
	end
end

local function findPhotoClone(): Model?
	if photoClone ~= nil and photoClone.Parent ~= nil then
		return photoClone
	end
	if photoLayer ~= nil then
		local world = photoLayer:FindFirstChild("PhotoWorld")
		if world ~= nil then
			for _, child in world:GetChildren() do
				if child:IsA("Model") then
					photoClone = child
					return child
				end
			end
		end
	end
	return nil
end

local function allPhotoClones(): { Model }
	local found: { Model } = {}
	local seen: { [Model]: boolean } = {}
	local primary = findPhotoClone()
	if primary ~= nil then
		seen[primary] = true
		table.insert(found, primary)
	end
	local player = Players.LocalPlayer
	local playerGui = if player ~= nil then player:FindFirstChild("PlayerGui") else nil
	if playerGui ~= nil then
		for _, gui in playerGui:GetChildren() do
			if gui.Name == "InkMastersCanvas" then
				for _, world in gui:GetDescendants() do
					if world.Name == "PhotoWorld" then
						for _, child in world:GetChildren() do
							if child:IsA("Model") and seen[child] ~= true then
								seen[child] = true
								table.insert(found, child)
							end
						end
					end
				end
			end
		end
	end
	return found
end

local function isLeg(region: BodyRegion): boolean
	return string.find(region.id, "Thigh") ~= nil or string.find(region.id, "Calf") ~= nil
end

-- Thigh / calf photos look from the outside of the leg; a hanging arm covers the
-- surface. Swing that side's arm forward ~90° so the limb stays clear.
local function raiseArmForLegShot(clone: Model, region: BodyRegion)
	if not isLeg(region) then
		return
	end
	local root = clone:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local prefix = if region.side == "right" then "Right" else "Left"
	local upper = clone:FindFirstChild(`{prefix}UpperArm`)
	local lower = clone:FindFirstChild(`{prefix}LowerArm`)
	local hand = clone:FindFirstChild(`{prefix}Hand`)
	if upper == nil or not upper:IsA("BasePart") then
		return
	end

	local attachment = upper:FindFirstChild(`{prefix}ShoulderRigAttachment`)
	local torso = clone:FindFirstChild("UpperTorso")
	if torso ~= nil and torso:IsA("BasePart") then
		local torsoAtt = torso:FindFirstChild(`{prefix}ShoulderRigAttachment`)
		if torsoAtt ~= nil and torsoAtt:IsA("Attachment") then
			attachment = torsoAtt
		end
	end
	local pivot = if attachment ~= nil and attachment:IsA("Attachment")
		then attachment.WorldPosition
		else upper.Position

	-- Flex the arm forward around the character's right axis (hanging → horizontal).
	local angle = if prefix == "Left" then -math.rad(90) else math.rad(90)
	local spin = CFrame.fromAxisAngle(root.CFrame.RightVector, angle)
	local transform = CFrame.new(pivot) * spin * CFrame.new(-pivot)
	for _, part in { upper, lower, hand } do
		if part ~= nil and part:IsA("BasePart") then
			part.CFrame = transform * part.CFrame
		end
	end
end

local function framePart(viewport: ViewportFrame, clone: Model, region: BodyRegion, loose: boolean?)
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

	-- Showcase / winner thumbs pull back so the limb isn't cropped.
	local present = loose == true or presentedCaption ~= nil
	local distance = if region.torso then (if present then 3.6 else 3.1) else (if present then 2.35 else 1.65)
	local fov = if region.torso then (if present then 36 else 32) else (if present then 34 else 28)
	if isLeg(region) then
		local span = math.max(part.Size.Y, part.Size.X, part.Size.Z)
		fov = if present then 28 else 24
		distance = (span * 1.5 * 0.5) / math.tan(math.rad(fov * 0.5))
		distance = math.clamp(distance, if present then 3.2 else 2.8, 7.5)
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
	photo.DisplayOrder = if presentedCaption ~= nil then 37 else 15
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
	dim.Visible = presentedCaption == nil
	dim.Parent = photo
	canvasDim = dim

	local board = Instance.new("Frame")
	board.Name = "Board"
	local boardPosition, boardSize = stageFrame()
	board.Position = boardPosition
	board.Size = boardSize
	board.BackgroundColor3 = UiTheme.color.ink
	board.BorderSizePixel = 0
	board.ClipsDescendants = true
	board.Parent = photo
	stage = board
	corner(board, if presentedCaption ~= nil then 18 else 2)
	local outline = Instance.new("UIStroke")
	outline.Color = UiTheme.color.gold
	outline.Thickness = 1
	outline.Transparency = 0.25
	outline.Parent = board
	boardStroke = outline

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
	raiseArmForLegShot(clone, region)
	if findPart(clone, region) ~= nil then
		local world = Instance.new("WorldModel")
		world.Name = "PhotoWorld"
		world.Parent = viewport
		clone.Parent = world
		framePart(viewport, clone, region)
		photoClone = clone
	else
		viewport.Visible = false
		clone:Destroy()
		photoClone = nil
		warn(`[InkMasters] This avatar has no {region.label} to photograph.`)
	end

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 0.35
	caption.BackgroundColor3 = UiTheme.color.ink
	caption.FontFace = UiTheme.font.bold
	caption.TextSize = 14
	caption.TextColor3 = UiTheme.color.gold
	caption.Text = presentedCaption or string.upper(region.label)
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.AutomaticSize = Enum.AutomaticSize.X
	caption.Size = UDim2.fromOffset(0, 26)
	caption.Position = UDim2.fromOffset(12, 12)
	caption.ZIndex = 5
	caption.Visible = presentedCaption == nil
	caption.Parent = board
	corner(caption, 2)
	local captionPad = Instance.new("UIPadding")
	captionPad.PaddingLeft = UDim.new(0, 10)
	captionPad.PaddingRight = UDim.new(0, 10)
	captionPad.Parent = caption
	captionLabel = caption

	-- A second ScreenGui keeps the ink above the viewport photo.
	local ink = Instance.new("ScreenGui")
	ink.Name = "InkMastersInk"
	ink.ResetOnSpawn = false
	ink.IgnoreGuiInset = true
	ink.DisplayOrder = if presentedCaption ~= nil then 38 else 17
	ink.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ink.Parent = playerGui
	inkGui = ink

	local window = Instance.new("Frame")
	window.Name = "View"
	window.Active = false
	window.BackgroundTransparency = 1
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	local windowPosition, windowSize = stageFrame()
	window.Position = windowPosition
	window.Size = windowSize
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
	tools.AnchorPoint = Vector2.new(0.5, 1)
	tools.Position = UDim2.new(0.5, 0, 1, -10)
	tools.Size = UDim2.fromOffset(140, 36)
	tools.BackgroundTransparency = 1
	tools.ZIndex = 10
	tools.Visible = presentedCaption == nil
	tools.Parent = window
	viewTools = tools
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
		button.BackgroundColor3 = UiTheme.color.ink
		button.BackgroundTransparency = 0.08
		button.BorderSizePixel = 0
		button.FontFace = UiTheme.font.bold
		button.TextSize = 14
		button.TextColor3 = UiTheme.color.text
		button.Text = text
		button.Size = UDim2.fromOffset(width, 32)
		button.ZIndex = 11
		button.Parent = tools
		corner(button, 2)
		local ring = Instance.new("UIStroke")
		ring.Color = UiTheme.color.stroke
		ring.Thickness = 1
		ring.Transparency = 0.35
		ring.Parent = button
		button.MouseButton1Click:Connect(callback)
	end

	local readout = Instance.new("TextLabel")
	readout.LayoutOrder = 2
	readout.BackgroundColor3 = UiTheme.color.ink
	readout.BackgroundTransparency = 0.08
	readout.BorderSizePixel = 0
	readout.FontFace = UiTheme.font.bold
	readout.TextSize = 13
	readout.TextColor3 = UiTheme.color.gold
	readout.Text = "100%"
	readout.Size = UDim2.fromOffset(58, 32)
	readout.ZIndex = 11
	readout.Parent = tools
	corner(readout, 2)
	zoomReadout = readout

	photoCharacter = character
	photoRegionId = region.id
	applyView()
	applyCaseFrame()

	viewButton("−", 32, 1, function()
		zoomAt(1 / 1.2, windowCenter())
	end)
	viewButton("+", 32, 3, function()
		zoomAt(1.2, windowCenter())
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

function TattooCanvas.setDeleteHandler(handler: (number) -> ())
	onDeleteMark = handler
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
	local deleteIndex: number? = nil
	local moveIndex: number? = nil
	for _, object in playerGui:GetGuiObjectsAtPosition(screen.X, screen.Y) do
		local index = markIndexOf(object)
		if index ~= nil then
			local onScale = object.Name == "Scale" or object:FindFirstAncestor("Scale") ~= nil
			local onRotate = object.Name == "Rotate" or object:FindFirstAncestor("Rotate") ~= nil
			local onDelete = object.Name == "Delete" or object:FindFirstAncestor("Delete") ~= nil
			if onScale then
				scaleIndex = index
			elseif onRotate then
				rotateIndex = index
			elseif onDelete then
				deleteIndex = index
			elseif moveIndex == nil then
				moveIndex = index
			end
		end
	end
	if deleteIndex ~= nil then
		-- Handled by the delete button click; do not start a drag.
		return nil, nil
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
	local iconPixels = rasterIcon(kind)
	local created: EditableImage? = nil
	local ok = pcall(function()
		created = AssetService:CreateEditableImage({
			Size = Vector2.new(ICON, ICON),
		})
		if created ~= nil then
			created:WritePixelsBuffer(Vector2.zero, Vector2.new(ICON, ICON), iconPixels)
		end
	end)
	if not ok or created == nil then
		handleIconsUnavailable = true
		return nil
	end
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

local function makeDeleteHandle(parent: GuiObject, index: number)
	local button = Instance.new("TextButton")
	button.Name = "Delete"
	button.Text = "×"
	button.FontFace = UiTheme.font.heavy
	button.TextSize = 18
	button.TextColor3 = Color3.fromRGB(255, 250, 245)
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0, 0)
	button.Size = UDim2.fromOffset(28, 28)
	button.BackgroundColor3 = UiTheme.color.oxblood
	button.BorderSizePixel = 0
	button.Active = true
	button.Selectable = false
	button.ZIndex = 40
	button.Parent = parent
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(1, 0)
	uiCorner.Parent = button
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(255, 250, 245)
	outline.Thickness = 1
	outline.Transparency = 0.25
	outline.Parent = button
	local shapeIndex = index
	button.MouseButton1Click:Connect(function()
		onDeleteMark(shapeIndex)
	end)
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
		local asset = if stencil ~= nil then stencil.image else nil
		StencilView.drawMark(mark, shape, InkColors.toColor3(element.color), InkColors.toColor3(element.line), {
			fill = element.fill,
			outline = element.outline,
			thickness = element.thickness,
			opacity = element.opacity,
			flip = element.flip,
		}, asset)

		if index == selectedIndex then
			makeHandle(mark, "Scale", "scale", UDim2.fromScale(1, 1), index)
			makeHandle(mark, "Rotate", "rotate", UDim2.new(0.5, 0, 0, -ROTATE_LIFT), index)
			makeDeleteHandle(mark, index)
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
		captionLabel.Text = presentedCaption or string.upper(region.label)
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
	skinToneId = id
	local character = photoCharacter
	local regionId = photoRegionId
	-- "Yours" needs a fresh clone from the live avatar so we restore the real
	-- tone after other swatches wiped textures / BodyColors on the photo.
	if id == "yours" and character ~= nil and regionId ~= nil then
		local region = BodyRegions.get(regionId)
		if region ~= nil then
			local design = shownDesign
			local selection = shownSelection
			buildCanvas(character, region)
			if design ~= nil then
				TattooCanvas.render(design, selection)
			end
			return
		end
	end
	-- Recolour every limb photo in place. Paint all canvases in case a duplicate
	-- ScreenGui is still around from a double client start.
	local color = if character ~= nil then toneColor(character) else nil
	local clones = allPhotoClones()
	if color ~= nil and #clones > 0 then
		for _, clone in clones do
			paintBare(clone, color)
		end
		return
	end
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

-- Showcase mode: only the tattoo, no limb label, zoom tools, or world dim.
-- nil goes back to the editor look.
function TattooCanvas.setPresentation(caption: string?)
	presentedCaption = caption
	local presenting = caption ~= nil
	if photoGui ~= nil then
		photoGui.DisplayOrder = if presenting then 37 else 15
	end
	if inkGui ~= nil then
		inkGui.DisplayOrder = if presenting then 38 else 17
	end
	if canvasDim ~= nil then
		canvasDim.Visible = not presenting
	end
	if captionLabel ~= nil then
		captionLabel.Visible = not presenting
		local region = if shownDesign ~= nil then BodyRegions.get(shownDesign.region) else nil
		captionLabel.Text = caption or (if region ~= nil then string.upper(region.label) else captionLabel.Text)
	end
	if viewTools ~= nil then
		viewTools.Visible = not presenting
	end
end

-- Width over height of the stage. Marks are stored against this shape, so snapshots copy it.
function TattooCanvas.stageAspect(): number
	local camera = Workspace.CurrentCamera
	local view = if camera ~= nil then camera.ViewportSize else Vector2.new(1280, 720)
	local _, size = stageFrame()
	local width = size.X.Scale * view.X + size.X.Offset
	local height = size.Y.Scale * view.Y + size.Y.Offset
	if width <= 1 or height <= 1 then
		return 4 / 3
	end
	return width / height
end

-- A still photo of a finished tattoo, sized to fit inside parent.
function TattooCanvas.snapshot(parent: GuiObject, character: Model, design: TattooDesign): Frame?
	local region = BodyRegions.get(design.region) or BodyRegions.get("LeftForearm")
	if region == nil then
		return nil
	end
	local aspect = TattooCanvas.stageAspect()

	local holder = Instance.new("Frame")
	holder.Name = "Snapshot"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ClipsDescendants = true
	holder.ZIndex = parent.ZIndex + 1
	holder.Parent = parent
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = aspect
	ratio.Parent = holder

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Photo"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = Color3.fromRGB(54, 42, 44)
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(120, 104, 96)
	viewport.LightColor = Color3.fromRGB(255, 214, 180)
	viewport.LightDirection = Vector3.new(-0.35, -1, -0.45)
	viewport.ZIndex = holder.ZIndex
	viewport.Parent = holder

	local clone = prepareClone(character)
	paintBare(clone, avatarSkin(character))
	raiseArmForLegShot(clone, region)
	if findPart(clone, region) ~= nil then
		local world = Instance.new("WorldModel")
		world.Parent = viewport
		clone.Parent = world
		framePart(viewport, clone, region, true)
	else
		clone:Destroy()
	end

	local marks = Instance.new("Frame")
	marks.Name = "Marks"
	marks.Size = UDim2.fromScale(1, 1)
	marks.BackgroundTransparency = 1
	marks.ZIndex = holder.ZIndex + 1
	marks.Parent = holder
	for index, element: DesignElement in design.elements do
		local stencil = StencilDefinitions.get(element.stencilId)
		local mark = Instance.new("Frame")
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(element.x, element.y)
		mark.Size = UDim2.fromScale(element.scale, element.scale * aspect)
		mark.Rotation = element.rotation
		mark.BackgroundTransparency = 1
		mark.ZIndex = marks.ZIndex + index
		mark.Parent = marks
		local shape = if stencil ~= nil then stencil.shape else "disc"
		local asset = if stencil ~= nil then stencil.image else nil
		StencilView.drawMark(mark, shape, InkColors.toColor3(element.color), InkColors.toColor3(element.line), {
			fill = element.fill,
			outline = element.outline,
			thickness = element.thickness,
			opacity = element.opacity,
			flip = element.flip,
		}, asset)
	end
	return holder
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
