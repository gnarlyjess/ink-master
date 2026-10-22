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

if not script:IsDescendantOf(Players) then
	return
end

local HERO_IMAGE = "rbxassetid://106925356858392"

local INK = Color3.fromRGB(12, 6, 20)
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

local MIN_SECONDS = 3.2
local FADE_SECONDS = 0.6

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

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local hero = Instance.new("ImageLabel")
hero.Name = "Hero"
hero.BackgroundColor3 = Color3.fromRGB(36, 22, 48)
hero.BackgroundTransparency = 0
hero.BorderSizePixel = 0
hero.Size = UDim2.fromScale(1, 1)
hero.ScaleType = Enum.ScaleType.Crop
hero.ImageTransparency = 0
hero.ZIndex = 2
hero.Parent = veil

local shade = Instance.new("Frame")
shade.Name = "Shade"
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BackgroundTransparency = 0.35
shade.BorderSizePixel = 0
shade.Size = UDim2.fromScale(1, 1)
shade.ZIndex = 3
shade.Parent = veil

local bottomWash = Instance.new("Frame")
bottomWash.Name = "BottomWash"
bottomWash.AnchorPoint = Vector2.new(0, 1)
bottomWash.Position = UDim2.fromScale(0, 1)
bottomWash.Size = UDim2.fromScale(1, 0.48)
bottomWash.BackgroundColor3 = INK
bottomWash.BorderSizePixel = 0
bottomWash.ZIndex = 4
bottomWash.Parent = veil

local washGrad = Instance.new("UIGradient")
washGrad.Rotation = 90
washGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.35, 0.45),
	NumberSequenceKeypoint.new(1, 0.05),
})
washGrad.Parent = bottomWash

local stage = Instance.new("Frame")
stage.Name = "Stage"
stage.AnchorPoint = Vector2.new(0.5, 1)
stage.Position = UDim2.new(0.5, 0, 1, -36)
stage.Size = UDim2.new(1, -48, 0, 150)
stage.BackgroundTransparency = 1
stage.ZIndex = 6
stage.Parent = veil

local wordmark = Instance.new("TextLabel")
wordmark.Name = "Wordmark"
wordmark.BackgroundTransparency = 1
wordmark.AnchorPoint = Vector2.new(0.5, 0)
wordmark.Position = UDim2.fromScale(0.5, 0)
wordmark.Size = UDim2.new(1, 0, 0, 56)
wordmark.Font = Enum.Font.GothamBold
wordmark.TextSize = 52
wordmark.TextColor3 = TEXT
wordmark.Text = "INK-OFF"
wordmark.TextStrokeColor3 = Color3.fromRGB(10, 8, 16)
wordmark.TextStrokeTransparency = 0.35
wordmark.ZIndex = 7
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
tagline.Position = UDim2.fromScale(0.5, 0.4)
tagline.Size = UDim2.new(1, 0, 0, 22)
tagline.Font = Enum.Font.GothamMedium
tagline.TextSize = 15
tagline.TextColor3 = MUTED
tagline.Text = "TATTOO STUDIO"
tagline.ZIndex = 7
tagline.Parent = stage

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.fromScale(0.5, 0.58)
status.Size = UDim2.new(1, 0, 0, 22)
status.Font = Enum.Font.Gotham
status.TextSize = 15
status.TextColor3 = MUTED
status.Text = STATUS_LINES[1]
status.ZIndex = 7
status.Parent = stage

local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(0.5, 0)
track.Position = UDim2.fromScale(0.5, 0.82)
track.Size = UDim2.fromOffset(280, 8)
track.BackgroundColor3 = Color3.fromRGB(48, 28, 64)
track.BorderSizePixel = 0
track.ZIndex = 7
track.Parent = stage

local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0.08, 1)
fill.BackgroundColor3 = GOLD
fill.BorderSizePixel = 0
fill.ZIndex = 8
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
stageScale.Scale = 0.92
stageScale.Parent = stage

TweenService:Create(stageScale, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
	Scale = 1,
}):Play()

local started = os.clock()
local running = true
local statusIndex = 1

task.spawn(function()
	while running and gui.Parent ~= nil do
		local now = os.clock() - started
		wordGrad.Offset = Vector2.new((now * 0.35) % 2 - 1, 0)
		fillGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, CANDY[(math.floor(now * 2) % #CANDY) + 1]),
			ColorSequenceKeypoint.new(0.5, GOLD),
			ColorSequenceKeypoint.new(1, CANDY[(math.floor(now * 2 + 2) % #CANDY) + 1]),
		})
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

setProgress(0.1)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

hero.Image = HERO_IMAGE
pcall(function()
	ContentProvider:PreloadAsync({ hero })
end)
local preloadDeadline = os.clock() + 6
while not hero.IsLoaded and os.clock() < preloadDeadline do
	task.wait(0.05)
end
setProgress(0.35)

waitForShop(45)
setProgress(0.78)

if player.Character == nil then
	player.CharacterAdded:Wait()
end
if player.Character ~= nil and player.Character:FindFirstChild("HumanoidRootPart") == nil then
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
TweenService:Create(stageScale, fadeInfo, { Scale = 1.04 }):Play()
TweenService:Create(wordmark, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
TweenService:Create(tagline, fadeInfo, { TextTransparency = 1 }):Play()
TweenService:Create(status, fadeInfo, { TextTransparency = 1 }):Play()
TweenService:Create(track, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(fill, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(hero, fadeInfo, { ImageTransparency = 1 }):Play()
TweenService:Create(shade, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(bottomWash, fadeInfo, { BackgroundTransparency = 1 }):Play()

local veilOut = TweenService:Create(veil, fadeInfo, { BackgroundTransparency = 1 })
veilOut:Play()
veilOut.Completed:Wait()
gui:Destroy()
