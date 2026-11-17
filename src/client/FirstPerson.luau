--!strict

-- First-person walk with a free PC cursor (shop / pause / HUD clicks).
-- Roblox's camera scripts re-lock the mouse every frame in FP — same fix most
-- games use: Modal unlocker + force MouseBehavior.Default after Camera.
-- Hold right mouse to look (Classic camera).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local FirstPerson = {}

local ZOOM = 0.5
local BIND_NAME = "InkRivalryFreeCursor"
local started = false

function FirstPerson.apply(player: Player)
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = ZOOM
	player.CameraMaxZoomDistance = ZOOM
end

local function ensureModalUnlocker(player: Player)
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("InkRivalryCursorUnlock")
	if existing ~= nil then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "InkRivalryCursorUnlock"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -100
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Invisible Modal button: engine unlocks the mouse while this stays Visible.
	local unlock = Instance.new("TextButton")
	unlock.Name = "Unlock"
	unlock.Modal = true
	unlock.Text = ""
	unlock.BackgroundTransparency = 1
	unlock.Size = UDim2.fromOffset(1, 1)
	unlock.Position = UDim2.fromOffset(-100, -100)
	unlock.Active = true
	unlock.AutoButtonColor = false
	unlock.Selectable = false
	unlock.Parent = gui
end

function FirstPerson.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	FirstPerson.apply(player)
	ensureModalUnlocker(player)

	player.CharacterAdded:Connect(function()
		FirstPerson.apply(player)
	end)

	-- PlayerModule sets LockCenter after Camera; override one step later.
	pcall(function()
		RunService:UnbindFromRenderStep(BIND_NAME)
	end)
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)
end

return FirstPerson
