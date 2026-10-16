--!strict

local LobbyDressing = require(script.Parent.LobbyDressing)
local RoundHud = require(script.Parent.RoundHud)
local TattooEditor = require(script.Parent.TattooEditor)

-- Dress the shop and connect the editor before the HUD asks for the round.
LobbyDressing.start()
TattooEditor.start()
RoundHud.start()
