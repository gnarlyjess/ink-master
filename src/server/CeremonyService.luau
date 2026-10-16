--!strict

-- Time's up, the display case, the vote, and the podium party.
-- Points are awarded here. The client only renders the result.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DesignService = require(script.Parent.DesignService)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundManager = require(script.Parent.RoundManager)
local RoundTypes = require(ReplicatedStorage.Shared.RoundTypes)

type RoundState = RoundTypes.RoundState
type LockedDesign = DesignService.LockedDesign

type PlaceRow = {
	place: number,
	userId: number,
	name: string,
	votes: number,
	awarded: number,
	total: number,
}

local PREFIX = "[InkMasters]"
local VOTE_COOLDOWN_SECONDS = 0.3

local phase = "Idle"
local revision = 0
local showcaseStart: number? = nil
local points: { [number]: number } = {}
local votes: { [number]: number } = {}
local places: { PlaceRow } = {}
local talliedRound = 0
local lastVoteAt: { [number]: number } = {}

local function voterTotal(userId: number): number
	return points[userId] or 0
end

local function designWire(design: LockedDesign, roundId: number)
	return {
		roundId = roundId,
		version = design.design.version,
		region = design.design.region,
		elements = design.design.elements,
	}
end

local function broadcast()
	revision += 1
	local roundId = RoundManager.getRoundId()
	local entries = {}
	for _, design in DesignService.getLocked() do
		table.insert(entries, {
			userId = design.userId,
			name = design.name,
			design = designWire(design, roundId),
		})
	end
	local placeWire = {}
	for _, place in places do
		table.insert(placeWire, {
			place = place.place,
			userId = place.userId,
			name = place.name,
			votes = place.votes,
			awarded = place.awarded,
			total = place.total,
		})
	end

	for _, player in Players:GetPlayers() do
		local choice = votes[player.UserId] or 0
		Remotes.CeremonyUpdated:FireClient(player, {
			revision = revision,
			roundId = roundId,
			phase = phase,
			secondsEach = GameConfig.getShowcaseSlice(),
			showcaseStart = showcaseStart,
			yourVote = choice,
			yourTotal = voterTotal(player.UserId),
			entries = entries,
			places = placeWire,
		})
	end
end

local function entryExists(userId: number): boolean
	for _, design in DesignService.getLocked() do
		if design.userId == userId then
			return true
		end
	end
	return false
end

local function tally()
	local roundId = RoundManager.getRoundId()
	if talliedRound == roundId then
		return
	end
	talliedRound = roundId
	table.clear(places)

	local scored: { { userId: number, name: string, votes: number, order: number } } = {}
	for index, design in DesignService.getLocked() do
		local count = 0
		for _, target in votes do
			if target == design.userId then
				count += 1
			end
		end
		table.insert(scored, {
			userId = design.userId,
			name = design.name,
			votes = count,
			order = index,
		})
	end
	table.sort(scored, function(a, b)
		if a.votes ~= b.votes then
			return a.votes > b.votes
		end
		return a.order < b.order
	end)

	local summary = ""
	for index, row in scored do
		if index > 3 then
			break
		end
		local awarded = GameConfig.getPlacePoints(index)
		local total = voterTotal(row.userId) + awarded
		points[row.userId] = total
		table.insert(places, {
			place = index,
			userId = row.userId,
			name = row.name,
			votes = row.votes,
			awarded = awarded,
			total = total,
		})
		local label = if index == 1 then "1st" elseif index == 2 then "2nd" else "3rd"
		summary ..= `{label} {row.name} +{awarded} ({row.votes} votes) `
	end
	if summary == "" then
		print(`{PREFIX} Party | no tattoos to place`)
	else
		print(`{PREFIX} Party | {summary}`)
	end
end

local function onVote(player: Player, target: any)
	if phase ~= "Voting" then
		return
	end
	if typeof(target) ~= "number" or target ~= math.floor(target) or target <= 0 then
		return
	end
	if target == player.UserId or not entryExists(target) then
		return
	end
	local now = os.clock()
	local previous = lastVoteAt[player.UserId]
	if previous ~= nil and (now - previous) < VOTE_COOLDOWN_SECONDS then
		return
	end
	lastVoteAt[player.UserId] = now
	votes[player.UserId] = target
	print(`{PREFIX} {player.Name} voted`)
	broadcast()
end

local function prepare(state: RoundState): number?
	local roundId = RoundManager.getRoundId()
	if state == "Intermission" or state == "WaitingForPlayers" or state == "Cleanup" then
		if state == "Intermission" then
			DesignService.clearRound()
			table.clear(votes)
			table.clear(places)
			talliedRound = 0
			showcaseStart = nil
		end
		phase = "Idle"
		broadcast()
		return nil
	end
	if state == "Submission" then
		DesignService.capture(roundId, RoundManager.getContestants())
		phase = "TimeUp"
		broadcast()
		return nil
	end
	if state == "Showcase" then
		DesignService.lock(roundId)
		showcaseStart = Workspace:GetServerTimeNow()
		phase = "Showcase"
		broadcast()
		local count = math.max(1, #DesignService.getLocked())
		return count * GameConfig.getShowcaseSlice()
	end
	if state == "Voting" then
		phase = "Voting"
		broadcast()
		return nil
	end
	if state == "Results" then
		tally()
		phase = "Party"
		broadcast()
		return nil
	end
	phase = "Idle"
	broadcast()
	return nil
end

local CeremonyService = {}

function CeremonyService.start()
	RoundManager.setPrepare(prepare)
	Remotes.CastVote.OnServerEvent:Connect(onVote)
end

return CeremonyService
