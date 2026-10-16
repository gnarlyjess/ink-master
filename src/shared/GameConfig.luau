--!strict

-- DevMode is the testing switch.
-- true: one player can start a round, and the short Dev timers are used.
-- false: the live lobby needs 5 players and uses the Live timers.
-- Both timer tables stay in this file. Durations are seconds.

local BodyRegions = require(script.Parent.BodyRegions)
local RoundTypes = require(script.Parent.RoundTypes)

local LIVE_MIN_PLAYERS = 5
local DEV_MIN_PLAYERS = 1
local MAX_PLAYERS = 10

-- Showcase is one fixed beat in this phase. Per-design showcase timing
-- arrives when submissions exist.
local LIVE_TIMERS: { [string]: number } = {
	Intermission = 15,
	ThemeReveal = 10,
	TattooCreation = 180,
	Submission = 5,
	Showcase = 10,
	Voting = 25,
	Results = 15,
	Cleanup = 4,
}

local DEV_TIMERS: { [string]: number } = {
	Intermission = 5,
	ThemeReveal = 5,
	-- Long enough to place a few marks. The other dev timers stay short.
	TattooCreation = 90,
	Submission = 2,
	Showcase = 4,
	Voting = 5,
	Results = 5,
	Cleanup = 2,
}

-- The forearm panel is a placement prototype. These limits are what the server enforces.
local MAX_ELEMENTS = 20
local MIN_ELEMENT_SCALE = 0.015
local MAX_ELEMENT_SCALE = 0.7
local DESIGN_REGION = "LeftForearm"

local GameConfig = {
	DevMode = true,
}

function GameConfig.getMinPlayers(): number
	if GameConfig.DevMode then
		return DEV_MIN_PLAYERS
	end
	return LIVE_MIN_PLAYERS
end

function GameConfig.getMaxPlayers(): number
	return MAX_PLAYERS
end

function GameConfig.getMaxElements(): number
	return MAX_ELEMENTS
end

function GameConfig.getMinElementScale(): number
	return MIN_ELEMENT_SCALE
end

function GameConfig.getMaxElementScale(): number
	return MAX_ELEMENT_SCALE
end

function GameConfig.getDesignRegion(): string
	return DESIGN_REGION
end

function GameConfig.isDesignRegion(region: string): boolean
	return BodyRegions.get(region) ~= nil
end

function GameConfig.getDuration(state: string): number?
	local timers = if GameConfig.DevMode then DEV_TIMERS else LIVE_TIMERS
	return timers[state]
end

function GameConfig.validate()
	if DEV_MIN_PLAYERS < 1 or LIVE_MIN_PLAYERS < 1 then
		error("[InkMasters] Minimum player counts must be at least 1")
	end
	if MAX_PLAYERS < LIVE_MIN_PLAYERS or MAX_PLAYERS < DEV_MIN_PLAYERS then
		error("[InkMasters] MaxPlayers must be at least the live and dev minimums")
	end
	if MAX_ELEMENTS < 1 or MIN_ELEMENT_SCALE <= 0 or MAX_ELEMENT_SCALE <= MIN_ELEMENT_SCALE then
		error("[InkMasters] Design limits are invalid")
	end
	if not GameConfig.isDesignRegion(DESIGN_REGION) then
		error("[InkMasters] Default design region is not a known body part")
	end

	local profiles: { [string]: { [string]: number } } = {
		Live = LIVE_TIMERS,
		Dev = DEV_TIMERS,
	}

	for _, state in RoundTypes.getTimedStates() do
		for profileName, timers in profiles do
			local duration = timers[state]
			if typeof(duration) ~= "number" or duration <= 0 then
				error(`[InkMasters] {profileName} timer for {state} must be a positive number of seconds`)
			end
		end
	end
end

return GameConfig
