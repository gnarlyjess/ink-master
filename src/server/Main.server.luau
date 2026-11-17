--!strict

local BlueprintService = require(script.Parent.BlueprintService)
local CeremonyService = require(script.Parent.CeremonyService)
local DesignService = require(script.Parent.DesignService)
local Lobby = require(script.Parent.Lobby)
local PrepService = require(script.Parent.PrepService)
local Profiles = require(script.Parent.Profiles)
local RoundManager = require(script.Parent.RoundManager)
local RoundRewards = require(script.Parent.RoundRewards)
local ShopService = require(script.Parent.ShopService)
local WinnerStage = require(script.Parent.WinnerStage)

Lobby.build()
WinnerStage.build()
-- Profiles load first so every system below can read a player's saved data.
Profiles.start()
ShopService.start()
RoundRewards.start()
DesignService.start()
PrepService.start()
BlueprintService.start()
CeremonyService.start()
RoundManager.start()
