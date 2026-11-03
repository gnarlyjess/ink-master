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

local localPlayer = Players.LocalPlayer
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

local Ceremony = require(script.Parent.Ceremony)
local Fanfare = require(script.Parent.Fanfare)
local LobbyDressing = require(script.Parent.LobbyDressing)
local PlayerData = require(script.Parent.PlayerData)
local RoundHud = require(script.Parent.RoundHud)
local RoundResults = require(script.Parent.RoundResults)
local StudioMenu = require(script.Parent.StudioMenu)
local TattooEditor = require(script.Parent.TattooEditor)
local TitleFlair = require(script.Parent.TitleFlair)
local Toasts = require(script.Parent.Toasts)

-- Warm limb stills in the background so skin swaps don't stream blurry on mobile.
task.spawn(function()
	local ok, LimbPhotos = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.LimbPhotos)
	end)
	if not ok or LimbPhotos == nil then
		return
	end
	local ContentProvider = game:GetService("ContentProvider")
	local assets = LimbPhotos.allAssets()
	if #assets > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(assets)
		end)
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
local editorOk, editorErr = pcall(TattooEditor.start)
if not editorOk then
	warn(`[InkRivalry] Tattoo editor did not start: {editorErr}`)
end
