--!strict

local Ceremony = require(script.Parent.Ceremony)
local LobbyDressing = require(script.Parent.LobbyDressing)
local PlayerData = require(script.Parent.PlayerData)
local RoundHud = require(script.Parent.RoundHud)
local RoundResults = require(script.Parent.RoundResults)
local StudioMenu = require(script.Parent.StudioMenu)
local TattooEditor = require(script.Parent.TattooEditor)
local Toasts = require(script.Parent.Toasts)

-- The profile mirror has to be listening before anything asks the server for it.
PlayerData.start()
Toasts.start()
LobbyDressing.start()
TattooEditor.start()
Ceremony.start()
RoundHud.start()
StudioMenu.start()
RoundResults.start()
