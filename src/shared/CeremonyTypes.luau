--!strict

-- The ceremony payload is separate from the round clock so a bad party update
-- cannot stall the snapshot the HUD already understands.

local DesignDocument = require(script.Parent.DesignDocument)

export type Phase = "Idle" | "TimeUp" | "Showcase" | "Voting" | "Party"

export type Entry = {
	userId: number,
	name: string,
	design: DesignDocument.TattooDesign,
}

export type Place = {
	place: number,
	userId: number,
	name: string,
	votes: number,
	awarded: number,
	total: number,
}

export type CeremonySnapshot = {
	revision: number,
	roundId: number,
	phase: Phase,
	secondsEach: number,
	showcaseStart: number?,
	yourVote: number,
	yourTotal: number,
	entries: { Entry },
	places: { Place },
}

local PHASES: { [string]: boolean } = {
	Idle = true,
	TimeUp = true,
	Showcase = true,
	Voting = true,
	Party = true,
}

local CeremonyTypes = {}

local function readFinite(value: any): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function readName(value: any): string?
	if typeof(value) ~= "string" or value == "" or #value > 30 then
		return nil
	end
	return value
end

local function readUserId(value: any): number?
	local userId = readFinite(value)
	if userId == nil or userId <= 0 or userId ~= math.floor(userId) then
		return nil
	end
	return userId
end

function CeremonyTypes.read(payload: any): CeremonySnapshot?
	if typeof(payload) ~= "table" then
		return nil
	end
	local phase = payload.phase
	if typeof(phase) ~= "string" or PHASES[phase] ~= true then
		return nil
	end
	local revision = readFinite(payload.revision)
	local roundId = readFinite(payload.roundId)
	local secondsEach = readFinite(payload.secondsEach)
	local yourVote = readFinite(payload.yourVote)
	local yourTotal = readFinite(payload.yourTotal)
	if revision == nil or roundId == nil or secondsEach == nil or yourVote == nil or yourTotal == nil then
		return nil
	end
	if revision < 1 or roundId < 0 or secondsEach <= 0 or yourVote < 0 or yourTotal < 0 then
		return nil
	end

	local showcaseStart = readFinite(payload.showcaseStart)
	if payload.showcaseStart ~= nil and showcaseStart == nil then
		return nil
	end

	if typeof(payload.entries) ~= "table" or typeof(payload.places) ~= "table" then
		return nil
	end
	if #payload.entries > 10 or #payload.places > 3 then
		return nil
	end

	local entries: { Entry } = {}
	for index = 1, #payload.entries do
		local item = payload.entries[index]
		if typeof(item) ~= "table" then
			return nil
		end
		local userId = readUserId(item.userId)
		local name = readName(item.name)
		local design = DesignDocument.sanitize(item.design, roundId)
		if userId == nil or name == nil or design == nil then
			return nil
		end
		table.insert(entries, {
			userId = userId,
			name = name,
			design = design,
		})
	end

	local places: { Place } = {}
	for index = 1, #payload.places do
		local item = payload.places[index]
		if typeof(item) ~= "table" then
			return nil
		end
		local place = readFinite(item.place)
		local userId = readUserId(item.userId)
		local name = readName(item.name)
		local votes = readFinite(item.votes)
		local awarded = readFinite(item.awarded)
		local total = readFinite(item.total)
		if place == nil or userId == nil or name == nil or votes == nil or awarded == nil or total == nil then
			return nil
		end
		if place < 1 or place > 3 or votes < 0 or awarded < 0 or total < 0 then
			return nil
		end
		table.insert(places, {
			place = place,
			userId = userId,
			name = name,
			votes = votes,
			awarded = awarded,
			total = total,
		})
	end

	local knownPhase: Phase = phase :: Phase
	return {
		revision = revision,
		roundId = roundId,
		phase = knownPhase,
		secondsEach = secondsEach,
		showcaseStart = showcaseStart,
		yourVote = yourVote,
		yourTotal = yourTotal,
		entries = entries,
		places = places,
	}
end

return CeremonyTypes
