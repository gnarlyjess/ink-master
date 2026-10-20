--!strict

-- Covers the empty baseplate → dark → lights flash while the parlour builds.
-- Mirrored in ReplicatedFirst for the earliest paint; this PlayerScripts copy is the
-- fallback when Rojo has not yet synced ReplicatedFirst into the place.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Client RunContext under StarterPlayerScripts boots twice; only one veil.
if not script:IsDescendantOf(Players) then
	return
end

local INK = Color3.fromRGB(12, 6, 20)
local PANEL = Color3.fromRGB(28, 14, 42)
local TEXT = Color3.fromRGB(255, 250, 245)
local MUTED = Color3.fromRGB(188, 168, 198)
local GOLD = Color3.fromRGB(255, 196, 64)
local MAGENTA = Color3.fromRGB(255, 64, 140)
local CYAN = Color3.fromRGB(64, 220, 255)
local LIME = Color3.fromRGB(120, 255, 96)
local VIOLET = Color3.fromRGB(168, 96, 255)

local CANDY = { MAGENTA, CYAN, GOLD, LIME, VIOLET, Color3.fromRGB(255, 110, 88) }

local STATUS_LINES = {
	"Laying the floorboards…",
	"Hanging the flash sheets…",
	"Warming the parlour lamps…",
	"Mixing the ink…",
	"Unlocking the door…",
}

local MIN_SECONDS = 1.85
local FADE_SECONDS = 0.55

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("InkMastersLoading") then
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "InkMastersLoading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local veil = Instance.new("Frame")
veil.Name = "Veil"
veil.BackgroundColor3 = INK
veil.BorderSizePixel = 0
veil.Size = UDim2.fromScale(1, 1)
veil.ZIndex = 1
veil.Parent = gui

-- Cover first, then drop Roblox's default card so the world never peeks through.
pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local vignette = Instance.new("Frame")
vignette.Name = "Vignette"
vignette.BackgroundColor3 = Color3.new(0, 0, 0)
vignette.BackgroundTransparency = 0.35
vignette.BorderSizePixel = 0
vignette.Size = UDim2.fromScale(1, 1)
vignette.ZIndex = 2
vignette.Parent = veil

local vigGrad = Instance.new("UIGradient")
vigGrad.Rotation = 90
vigGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.15),
	NumberSequenceKeypoint.new(0.45, 0.55),
	NumberSequenceKeypoint.new(1, 0.05),
})
vigGrad.Parent = vignette

local stage = Instance.new("Frame")
stage.Name = "Stage"
stage.AnchorPoint = Vector2.new(0.5, 0.5)
stage.Position = UDim2.fromScale(0.5, 0.48)
stage.Size = UDim2.fromOffset(420, 320)
stage.BackgroundTransparency = 1
stage.ZIndex = 5
stage.Parent = veil

local rays = Instance.new("Frame")
rays.Name = "Rays"
rays.AnchorPoint = Vector2.new(0.5, 0.5)
rays.Position = UDim2.fromScale(0.5, 0.38)
rays.Size = UDim2.fromOffset(220, 220)
rays.BackgroundTransparency = 1
rays.ZIndex = 5
rays.Parent = stage

for i = 1, 12 do
	local ray = Instance.new("Frame")
	ray.Name = `Ray{i}`
	ray.AnchorPoint = Vector2.new(0.5, 1)
	ray.Position = UDim2.fromScale(0.5, 0.5)
	ray.Size = UDim2.fromOffset(12, 96)
	ray.BackgroundColor3 = CANDY[((i - 1) % #CANDY) + 1]
	ray.BackgroundTransparency = 0.72
	ray.BorderSizePixel = 0
	ray.Rotation = (i - 1) * (180 / 12)
	ray.ZIndex = 5
	ray.Parent = rays
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = ray
end

local badge = Instance.new("Frame")
badge.Name = "Badge"
badge.AnchorPoint = Vector2.new(0.5, 0.5)
badge.Position = UDim2.fromScale(0.5, 0.38)
badge.Size = UDim2.fromOffset(112, 112)
badge.BackgroundColor3 = PANEL
badge.BorderSizePixel = 0
badge.ZIndex = 8
badge.Parent = stage

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(1, 0)
badgeCorner.Parent = badge

local badgeStroke = Instance.new("UIStroke")
badgeStroke.Thickness = 3
badgeStroke.Color = MAGENTA
badgeStroke.Parent = badge

local needle = Instance.new("Frame")
needle.Name = "Needle"
needle.AnchorPoint = Vector2.new(0.5, 0.5)
needle.Position = UDim2.fromScale(0.5, 0.46)
needle.Size = UDim2.fromOffset(10, 54)
needle.BackgroundColor3 = TEXT
needle.BorderSizePixel = 0
needle.ZIndex = 9
needle.Parent = badge

local needleTip = Instance.new("Frame")
needleTip.Name = "Tip"
needleTip.AnchorPoint = Vector2.new(0.5, 0)
needleTip.Position = UDim2.new(0.5, 0, 1, -2)
needleTip.Size = UDim2.fromOffset(16, 16)
needleTip.BackgroundColor3 = GOLD
needleTip.BorderSizePixel = 0
needleTip.Rotation = 45
needleTip.ZIndex = 9
needleTip.Parent = needle

local drip = Instance.new("Frame")
drip.Name = "Drip"
drip.AnchorPoint = Vector2.new(0.5, 0)
drip.Position = UDim2.new(0.5, 0, 1, 10)
drip.Size = UDim2.fromOffset(14, 18)
drip.BackgroundColor3 = MAGENTA
drip.BorderSizePixel = 0
drip.ZIndex = 9
drip.Parent = badge

local dripCorner = Instance.new("UICorner")
dripCorner.CornerRadius = UDim.new(1, 0)
dripCorner.Parent = drip

local wordmark = Instance.new("TextLabel")
wordmark.Name = "Wordmark"
wordmark.BackgroundTransparency = 1
wordmark.AnchorPoint = Vector2.new(0.5, 0)
wordmark.Position = UDim2.fromScale(0.5, 0.58)
wordmark.Size = UDim2.new(1, 0, 0, 56)
wordmark.Font = Enum.Font.GothamBold
wordmark.TextSize = 52
wordmark.TextColor3 = TEXT
wordmark.Text = "INK-OFF"
wordmark.TextStrokeColor3 = Color3.fromRGB(10, 8, 16)
wordmark.TextStrokeTransparency = 0.35
wordmark.ZIndex = 10
wordmark.Parent = stage

local wordGrad = Instance.new("UIGradient")
wordGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, MAGENTA),
	ColorSequenceKeypoint.new(0.35, GOLD),
	ColorSequenceKeypoint.new(0.65, CYAN),
	ColorSequenceKeypoint.new(1, VIOLET),
})
wordGrad.Parent = wordmark

local tagline = Instance.new("TextLabel")
tagline.Name = "Tagline"
tagline.BackgroundTransparency = 1
tagline.AnchorPoint = Vector2.new(0.5, 0)
tagline.Position = UDim2.fromScale(0.5, 0.74)
tagline.Size = UDim2.new(1, 0, 0, 24)
tagline.Font = Enum.Font.GothamMedium
tagline.TextSize = 16
tagline.TextColor3 = MUTED
tagline.Text = "TATTOO STUDIO"
tagline.ZIndex = 10
tagline.Parent = stage

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.fromScale(0.5, 0.84)
status.Size = UDim2.new(1, 0, 0, 22)
status.Font = Enum.Font.Gotham
status.TextSize = 15
status.TextColor3 = MUTED
status.Text = STATUS_LINES[1]
status.ZIndex = 10
status.Parent = stage

local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(0.5, 0)
track.Position = UDim2.fromScale(0.5, 0.94)
track.Size = UDim2.fromOffset(260, 8)
track.BackgroundColor3 = Color3.fromRGB(48, 28, 64)
track.BorderSizePixel = 0
track.ZIndex = 10
track.Parent = stage

local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0.08, 1)
fill.BackgroundColor3 = GOLD
fill.BorderSizePixel = 0
fill.ZIndex = 11
fill.Parent = track

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

local fillGrad = Instance.new("UIGradient")
fillGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, MAGENTA),
	ColorSequenceKeypoint.new(0.5, GOLD),
	ColorSequenceKeypoint.new(1, CYAN),
})
fillGrad.Parent = fill

local stageScale = Instance.new("UIScale")
stageScale.Scale = 0.86
stageScale.Parent = stage

TweenService:Create(stageScale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
	Scale = 1,
}):Play()

local started = os.clock()
local running = true
local statusIndex = 1

task.spawn(function()
	while running and gui.Parent ~= nil do
		local now = os.clock() - started
		rays.Rotation = now * 32
		wordGrad.Offset = Vector2.new((now * 0.35) % 2 - 1, 0)
		badgeStroke.Color = CANDY[(math.floor(now * 2.4) % #CANDY) + 1]
		local bob = math.sin(now * 4.2) * 5
		drip.Position = UDim2.new(0.5, 0, 1, 10 + bob)
		drip.Size = UDim2.fromOffset(14, 16 + math.abs(bob) * 0.35)
		RunService.Heartbeat:Wait()
	end
end)

task.spawn(function()
	while running and status.Parent ~= nil do
		status.Text = STATUS_LINES[statusIndex]
		statusIndex = (statusIndex % #STATUS_LINES) + 1
		task.wait(0.7)
	end
end)

local function setProgress(alpha: number)
	local t = math.clamp(alpha, 0, 1)
	fill.Size = UDim2.fromScale(0.08 + t * 0.92, 1)
end

local function shopIsReady(): boolean
	local lobby = Workspace:FindFirstChild("Lobby")
	if lobby == nil then
		return false
	end
	return lobby:GetAttribute("ShopReady") == true
end

local function waitForShop(timeout: number): boolean
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if shopIsReady() then
			return true
		end
		task.wait(0.05)
	end
	return shopIsReady()
end

setProgress(0.12)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
setProgress(0.35)

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({ wordmark, badge, fill })
	end)
end)

waitForShop(45)
setProgress(0.78)

if player.Character == nil then
	player.CharacterAdded:Wait()
end
local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if root == nil and player.Character ~= nil then
	player.Character:WaitForChild("HumanoidRootPart", 8)
end
setProgress(1)

local elapsed = os.clock() - started
if elapsed < MIN_SECONDS then
	task.wait(MIN_SECONDS - elapsed)
end

running = false
status.Text = "Welcome in."

local fadeInfo = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
TweenService:Create(stageScale, fadeInfo, { Scale = 1.08 }):Play()
TweenService:Create(wordmark, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
TweenService:Create(tagline, fadeInfo, { TextTransparency = 1 }):Play()
TweenService:Create(status, fadeInfo, { TextTransparency = 1 }):Play()
TweenService:Create(badge, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(badgeStroke, fadeInfo, { Transparency = 1 }):Play()
TweenService:Create(needle, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(needleTip, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(drip, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(track, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(fill, fadeInfo, { BackgroundTransparency = 1 }):Play()
for _, child in rays:GetChildren() do
	if child:IsA("Frame") then
		TweenService:Create(child, fadeInfo, { BackgroundTransparency = 1 }):Play()
	end
end

local veilOut = TweenService:Create(veil, fadeInfo, { BackgroundTransparency = 1 })
TweenService:Create(vignette, fadeInfo, { BackgroundTransparency = 1 }):Play()
veilOut:Play()
veilOut.Completed:Wait()
gui:Destroy()
