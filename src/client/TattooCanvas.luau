--!strict

-- Prototype only: a flat panel follows the outside of the left forearm.
-- This proves placement, rotation, scale, and colour. It does not wrap the real arm mesh.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DesignDocument = require(game:GetService("ReplicatedStorage").Shared.DesignDocument)
local InkColors = require(game:GetService("ReplicatedStorage").Shared.InkColors)
local StencilDefinitions = require(game:GetService("ReplicatedStorage").Shared.StencilDefinitions)
local StencilView = require(script.Parent.StencilView)

type TattooDesign = DesignDocument.TattooDesign
type DesignElement = DesignDocument.DesignElement

local PANEL_SIZE = Vector3.new(0.95, 1.45, 0.04)
local OUTWARD_STUDS = 0.6
local CAMERA_DISTANCE = 2.55
local CAMERA_LIFT = 0.55

local TattooCanvas = {}

local generation = 0
local panel: BasePart? = nil
local surfacePad: TextButton? = nil
local elementFrames: { [number]: Frame } = {}
local armPart: BasePart? = nil
local rootPart: BasePart? = nil
local cameraLocked = false
local savedFieldOfView: number? = nil
local shownDesign: TattooDesign? = nil
local shownSelection: number? = nil

local onPlace: (number, number) -> () = function(_x: number, _y: number) end
local onGrab: (number) -> () = function(_index: number) end
local queuedPlaceX: number? = nil
local queuedPlaceY: number? = nil
local grabbedThisClick = false
local clickFlushScheduled = false

local function flushClick()
	clickFlushScheduled = false
	local x = queuedPlaceX
	local y = queuedPlaceY
	local grabbed = grabbedThisClick
	queuedPlaceX = nil
	queuedPlaceY = nil
	grabbedThisClick = false
	if grabbed or x == nil or y == nil then
		return
	end
	onPlace(x, y)
end

local function scheduleClickFlush()
	if clickFlushScheduled then
		return
	end
	clickFlushScheduled = true
	task.defer(flushClick)
end

local function elementSize(scale: number): UDim2
	local heightScale = scale * (PANEL_SIZE.X / PANEL_SIZE.Y)
	return UDim2.fromScale(scale, heightScale)
end

local function findArm(character: Model): BasePart?
	local lower = character:FindFirstChild("LeftLowerArm")
	if lower ~= nil and lower:IsA("BasePart") then
		return lower
	end
	local classic = character:FindFirstChild("Left Arm")
	if classic ~= nil and classic:IsA("BasePart") then
		return classic
	end
	return nil
end

local function destroyPanel()
	if panel ~= nil then
		panel:Destroy()
		panel = nil
	end
	surfacePad = nil
	table.clear(elementFrames)
end

local function panelCFrame(): CFrame?
	if armPart == nil or rootPart == nil then
		return nil
	end
	local outward = -rootPart.CFrame.RightVector
	local center = armPart.Position + outward * OUTWARD_STUDS
	return CFrame.lookAt(center, center + outward, Vector3.yAxis)
end

local function updateFollow()
	if panel == nil then
		return
	end
	local nextCFrame = panelCFrame()
	if nextCFrame == nil then
		return
	end
	panel.CFrame = nextCFrame

	local camera = Workspace.CurrentCamera
	if camera == nil or not cameraLocked then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 42
	local cameraPosition = nextCFrame.Position + nextCFrame.LookVector * CAMERA_DISTANCE + Vector3.yAxis * CAMERA_LIFT
	camera.CFrame = CFrame.lookAt(cameraPosition, nextCFrame.Position, Vector3.yAxis)
end

local function buildSurface(host: BasePart)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "ForearmInk"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 160
	surface.LightInfluence = 0
	surface.Brightness = 1.15
	surface.AlwaysOnTop = false
	surface.ZOffset = 0.02
	surface.Parent = host

	local pad = Instance.new("TextButton")
	pad.Name = "PlacementPad"
	pad.Text = ""
	pad.AutoButtonColor = false
	pad.BackgroundTransparency = 1
	pad.Size = UDim2.fromScale(1, 1)
	pad.ZIndex = 1
	pad.Parent = surface
	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(42, 28, 32)
	border.Thickness = 2
	border.Transparency = 0.25
	border.Parent = pad
	pad.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local x, y = TattooCanvas.screenToUv(Vector2.new(input.Position.X, input.Position.Y))
		if x == nil or y == nil then
			return
		end
		queuedPlaceX = x
		queuedPlaceY = y
		scheduleClickFlush()
	end)
	surfacePad = pad
end

local function attach(character: Model)
	generation += 1
	local token = generation
	destroyPanel()

	local root = character:WaitForChild("HumanoidRootPart", 5)
	local arm = findArm(character)
	if arm == nil then
		local waited = character:WaitForChild("LeftLowerArm", 5)
		if waited ~= nil and waited:IsA("BasePart") then
			arm = waited
		end
	end
	if token ~= generation or character.Parent == nil then
		return
	end
	if root == nil or not root:IsA("BasePart") or arm == nil then
		warn("[InkMasters] This avatar has no left forearm for the prototype panel.")
		return
	end

	rootPart = root
	armPart = arm

	local host = Instance.new("Part")
	host.Name = "ForearmCanvasPrototype"
	host.Size = PANEL_SIZE
	host.Anchored = true
	host.CanCollide = false
	host.CanTouch = false
	host.CanQuery = true
	host.CastShadow = false
	host.Material = Enum.Material.SmoothPlastic
	host.Color = Color3.fromRGB(214, 170, 148)
	host.Parent = Workspace
	panel = host
	buildSurface(host)
	if shownDesign ~= nil then
		TattooCanvas.render(shownDesign, shownSelection)
	end
	updateFollow()
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

function TattooCanvas.setHandlers(placeHandler: (number, number) -> (), grabHandler: (number) -> ())
	onPlace = placeHandler
	onGrab = grabHandler
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
		mark.ZIndex = 2 + index
		mark.Parent = surfacePad

		local stroke = Instance.new("UIStroke")
		stroke.Name = "Selection"
		stroke.Color = Color3.fromRGB(242, 196, 122)
		stroke.Thickness = 2
		stroke.Enabled = index == selectedIndex
		stroke.Parent = mark

		local shape = if stencil ~= nil then stencil.shape else "disc"
		StencilView.draw(mark, shape, InkColors.toColor3(element.color))

		local hit = Instance.new("TextButton")
		hit.Name = "Hit"
		hit.Text = ""
		hit.AutoButtonColor = false
		hit.BackgroundTransparency = 1
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 10
		hit.Parent = mark
		hit.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			grabbedThisClick = true
			scheduleClickFlush()
			onGrab(index)
		end)

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
	if panel ~= nil and armPart ~= nil and armPart.Parent == character then
		TattooCanvas.render(design, selectedIndex)
		return
	end
	task.spawn(attach, character)
end

function TattooCanvas.clear()
	generation += 1
	shownDesign = nil
	shownSelection = nil
	armPart = nil
	rootPart = nil
	TattooCanvas.setCameraLocked(false)
	destroyPanel()
end

function TattooCanvas.setCameraLocked(locked: boolean)
	local camera = Workspace.CurrentCamera
	if locked then
		cameraLocked = true
		if camera ~= nil and savedFieldOfView == nil then
			savedFieldOfView = camera.FieldOfView
		end
		return
	end

	cameraLocked = false
	if camera == nil then
		savedFieldOfView = nil
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid ~= nil then
		camera.CameraSubject = humanoid
	end
	if savedFieldOfView ~= nil then
		camera.FieldOfView = savedFieldOfView
		savedFieldOfView = nil
	end
end

local player = Players.LocalPlayer
if player ~= nil then
	player.CharacterAdded:Connect(function(character: Model)
		if shownDesign == nil then
			return
		end
		attach(character)
	end)
end

RunService:BindToRenderStep("InkMastersForearmPanel", Enum.RenderPriority.Camera.Value + 1, updateFollow)

return TattooCanvas
