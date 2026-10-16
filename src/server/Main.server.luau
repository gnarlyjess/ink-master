--!strict

local DesignService = require(script.Parent.DesignService)
local Lobby = require(script.Parent.Lobby)
local RoundManager = require(script.Parent.RoundManager)

Lobby.build()
RoundManager.start()
DesignService.start()
