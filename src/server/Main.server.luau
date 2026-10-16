--!strict

local CeremonyService = require(script.Parent.CeremonyService)
local DesignService = require(script.Parent.DesignService)
local Lobby = require(script.Parent.Lobby)
local RoundManager = require(script.Parent.RoundManager)

Lobby.build()
DesignService.start()
CeremonyService.start()
RoundManager.start()
