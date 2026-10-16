--!strict

local RoundHud = require(script.Parent.RoundHud)
local TattooEditor = require(script.Parent.TattooEditor)

-- Connect the editor before the HUD asks for the current round.
TattooEditor.start()
RoundHud.start()
