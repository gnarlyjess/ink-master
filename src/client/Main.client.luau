--!strict

-- Client RunContext under StarterPlayerScripts boots twice (starter + player copy).
-- Only the PlayerScripts copy should wire HUD / editor / remotes.
local Players = game:GetService("Players")
if not script:IsDescendantOf(Players) then
	return
end

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
	warn(`[InkMasters] Tattoo editor did not start: {editorErr}`)
end
