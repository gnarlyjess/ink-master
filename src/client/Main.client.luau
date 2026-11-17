--!strict

-- Client RunContext under StarterPlayerScripts boots twice (starter + player copy).
-- Only the PlayerScripts copy should wire HUD / editor / remotes.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
if not script:IsDescendantOf(Players) then
	return
end

-- No combat — hide Roblox's default health strip (and over-head health).
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local FirstPerson = require(script.Parent.FirstPerson)

local localPlayer = Players.LocalPlayer
-- Parlour + stockroom stay first-person; free PC cursor for shop / pause (hold RMB to look).
FirstPerson.start()
local function muteHealth(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	end
	if humanoid ~= nil then
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
end
if localPlayer.Character ~= nil then
	task.spawn(muteHealth, localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(muteHealth)

local BlueprintHunt = require(script.Parent.BlueprintHunt)
local Ceremony = require(script.Parent.Ceremony)
local Fanfare = require(script.Parent.Fanfare)
local LobbyDressing = require(script.Parent.LobbyDressing)
local PlayerData = require(script.Parent.PlayerData)
local PrepEditor = require(script.Parent.PrepEditor)
local RoundHud = require(script.Parent.RoundHud)
local RoundResults = require(script.Parent.RoundResults)
local StudioMenu = require(script.Parent.StudioMenu)
local TattooEditor = require(script.Parent.TattooEditor)
local TitleFlair = require(script.Parent.TitleFlair)
local Toasts = require(script.Parent.Toasts)

-- Warm every limb × skin still so prep/tattoo swaps stay instant.
task.defer(function()
	local ok, TattooCanvas = pcall(function()
		return require(script.Parent.TattooCanvas)
	end)
	if ok and TattooCanvas ~= nil then
		TattooCanvas.preloadAll()
	end
end)

-- The profile mirror has to be listening before anything asks the server for it.
PlayerData.start()
Fanfare.start()
Toasts.start()
TitleFlair.start()
LobbyDressing.start()
RoundHud.start()
StudioMenu.start()
RoundResults.start()
Ceremony.start()
local huntOk, huntErr = pcall(BlueprintHunt.start)
if not huntOk then
	warn(`[InkRivalry] Blueprint hunt did not start: {huntErr}`)
end
local prepOk, prepErr = pcall(PrepEditor.start)
if not prepOk then
	warn(`[InkRivalry] Prep editor did not start: {prepErr}`)
end
local editorOk, editorErr = pcall(TattooEditor.start)
if not editorOk then
	warn(`[InkRivalry] Tattoo editor did not start: {editorErr}`)
end
