--!strict

export type RoundState =
	"WaitingForPlayers"
	| "Intermission"
	| "ThemeReveal"
	| "TattooCreation"
	| "Submission"
	| "Showcase"
	| "Voting"
	| "Results"
	| "Cleanup"

export type RoundSnapshot = {
	revision: number,
	roundId: number,
	state: RoundState,
	endsAt: number?,
	duration: number?,
	playerCount: number,
	minPlayers: number,
	maxPlayers: number,
	devMode: boolean,
	showTheme: boolean,
	themeId: string?,
	themeName: string?,
	themeTagline: string?,
}

local TIMED_ORDER: { RoundState } = {
	"Intermission",
	"ThemeReveal",
	"TattooCreation",
	"Submission",
	"Showcase",
	"Voting",
	"Results",
	"Cleanup",
}

local LABELS: { [string]: string } = {
	WaitingForPlayers = "Waiting for players",
	Intermission = "Intermission",
	ThemeReveal = "Theme reveal",
	TattooCreation = "Design phase",
	Submission = "Submission",
	Showcase = "Showcase",
	Voting = "Voting",
	Results = "Results",
	Cleanup = "Clearing up",
}

local RoundTypes = {}

function RoundTypes.getTimedStates(): { RoundState }
	return TIMED_ORDER
end

function RoundTypes.nextInRound(state: RoundState): RoundState?
	local index = table.find(TIMED_ORDER, state)
	if index == nil then
		return nil
	end
	local nextState = TIMED_ORDER[index + 1]
	if typeof(nextState) ~= "string" then
		return nil
	end
	return nextState :: RoundState
end

function RoundTypes.showsTheme(state: RoundState): boolean
	return state ~= "WaitingForPlayers" and state ~= "Intermission"
end

function RoundTypes.isRoundState(value: any): boolean
	if typeof(value) ~= "string" then
		return false
	end
	return LABELS[value] ~= nil
end

function RoundTypes.getLabel(state: RoundState): string
	return LABELS[state] or state
end

local function readFinite(value: any): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function readOptionalString(value: any): (boolean, string?)
	if value == nil then
		return true, nil
	end
	if typeof(value) ~= "string" or value == "" then
		return false, nil
	end
	return true, value
end

function RoundTypes.readSnapshot(payload: any): RoundSnapshot?
	if typeof(payload) ~= "table" then
		return nil
	end

	local state = payload.state
	if not RoundTypes.isRoundState(state) then
		return nil
	end

	local revision = readFinite(payload.revision)
	local roundId = readFinite(payload.roundId)
	local playerCount = readFinite(payload.playerCount)
	local minPlayers = readFinite(payload.minPlayers)
	local maxPlayers = readFinite(payload.maxPlayers)
	if revision == nil or roundId == nil or playerCount == nil or minPlayers == nil or maxPlayers == nil then
		return nil
	end
	if revision < 1 or roundId < 0 or playerCount < 0 or minPlayers < 1 or maxPlayers < 1 then
		return nil
	end
	if typeof(payload.devMode) ~= "boolean" or typeof(payload.showTheme) ~= "boolean" then
		return nil
	end

	local endsAt = readFinite(payload.endsAt)
	if payload.endsAt ~= nil and endsAt == nil then
		return nil
	end
	local duration = readFinite(payload.duration)
	if payload.duration ~= nil and (duration == nil or duration <= 0) then
		return nil
	end
	local hasEnd = payload.endsAt ~= nil
	local hasDuration = payload.duration ~= nil
	if hasEnd ~= hasDuration then
		return nil
	end

	local themeIdOk, themeId = readOptionalString(payload.themeId)
	local themeNameOk, themeName = readOptionalString(payload.themeName)
	local themeTaglineOk, themeTagline = readOptionalString(payload.themeTagline)
	if not themeIdOk or not themeNameOk or not themeTaglineOk then
		return nil
	end
	if payload.showTheme and (themeId == nil or themeName == nil or themeTagline == nil) then
		return nil
	end

	local devMode: boolean = payload.devMode
	local showTheme: boolean = payload.showTheme
	local snapshot: RoundSnapshot = {
		revision = revision,
		roundId = roundId,
		state = state,
		endsAt = endsAt,
		duration = duration,
		playerCount = playerCount,
		minPlayers = minPlayers,
		maxPlayers = maxPlayers,
		devMode = devMode,
		showTheme = showTheme,
		themeId = themeId,
		themeName = themeName,
		themeTagline = themeTagline,
	}
	return snapshot
end

return RoundTypes
