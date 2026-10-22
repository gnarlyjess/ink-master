--!strict

-- Time's up, the display case, the vote, and the podium party.
-- Votes from each design round add up. The final party crowns the match winner.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DesignService = require(script.Parent.DesignService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerEconomy = require(script.Parent.PlayerEconomy)
local Profiles = require(script.Parent.Profiles)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundManager = require(script.Parent.RoundManager)
local RoundRewards = require(script.Parent.RoundRewards)
local RoundTypes = require(ReplicatedStorage.Shared.RoundTypes)
local WinnerStage = require(script.Parent.WinnerStage)

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

type ScoredRow = {
	userId: number,
	name: string,
	votes: number,
	order: number,
}

local PREFIX = "[InkMasters]"
local VOTE_COOLDOWN_SECONDS = 0.3

local phase = "Idle"
local revision = 0
local showcaseStart: number? = nil
local phaseEnds: number? = nil
local staged = false
local votes: { [number]: number } = {}
local places: { PlaceRow } = {}
local matchTotals: { [number]: number } = {}
local talliedKey = 0
local lastVoteAt: { [number]: number } = {}

local function balanceOf(userId: number): number
	local player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return 0
	end
	return PlayerEconomy.getCoins(player)
end

local function equippedFor(userId: number, slot: string): string
	local player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return ""
	end
	local data = Profiles.get(player)
	if data == nil then
		return ""
	end
	local id: string? = data.equipped[slot]
	return id or ""
end

local function designWire(design: LockedDesign, roundId: number)
	return {
		roundId = roundId,
		version = design.design.version,
		region = design.design.region,
		elements = design.design.elements,
	}
end

local function payoutKey(): number
	return RoundManager.getRoundId() * 100 + RoundManager.getDesignRound()
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
			title = equippedFor(design.userId, "title"),
			frame = equippedFor(design.userId, "frame"),
			confetti = equippedFor(design.userId, "confetti"),
			emote = equippedFor(design.userId, "emote"),
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

	local matchFinal = RoundManager.isMatchFinal()
	for _, player in Players:GetPlayers() do
		local choice = votes[player.UserId] or 0
		Remotes.CeremonyUpdated:FireClient(player, {
			revision = revision,
			roundId = roundId,
			designRound = RoundManager.getDesignRound(),
			designRounds = RoundManager.getDesignRounds(),
			matchFinal = matchFinal,
			phase = phase,
			secondsEach = GameConfig.getShowcaseSlice(),
			showcaseStart = showcaseStart,
			phaseEnds = phaseEnds,
			yourVote = choice,
			yourTotal = PlayerEconomy.getCoins(player),
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

local function scoreThisRound(): { ScoredRow }
	local scored: { ScoredRow } = {}
	for index, design in DesignService.getLocked() do
		if #design.design.elements > 0 then
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
	end
	table.sort(scored, function(a, b)
		if a.votes ~= b.votes then
			return a.votes > b.votes
		end
		return a.order < b.order
	end)
	return scored
end

local function nameFor(userId: number): string
	for _, design in DesignService.getLocked() do
		if design.userId == userId then
			return design.name
		end
	end
	local player = Players:GetPlayerByUserId(userId)
	if player ~= nil then
		return player.DisplayName
	end
	return "Artist"
end

local function scoreMatch(): { ScoredRow }
	local scored: { ScoredRow } = {}
	local seen: { [number]: boolean } = {}
	-- Prefer names/order from this round's locked designs when present.
	for index, design in DesignService.getLocked() do
		if #design.design.elements > 0 then
			seen[design.userId] = true
			table.insert(scored, {
				userId = design.userId,
				name = design.name,
				votes = matchTotals[design.userId] or 0,
				order = index,
			})
		end
	end
	-- Keep artists who scored earlier in the match even if they skipped this design.
	for userId, total in matchTotals do
		if seen[userId] ~= true then
			table.insert(scored, {
				userId = userId,
				name = nameFor(userId),
				votes = total,
				order = 1000 + userId,
			})
		end
	end
	table.sort(scored, function(a, b)
		if a.votes ~= b.votes then
			return a.votes > b.votes
		end
		return a.order < b.order
	end)
	return scored
end

local function clearDesignRound()
	DesignService.clearRound()
	table.clear(votes)
	table.clear(places)
	showcaseStart = nil
	lastVoteAt = {}
end

local function resetMatch()
	clearDesignRound()
	table.clear(matchTotals)
	talliedKey = 0
end

local function tally()
	local key = payoutKey()
	if talliedKey == key then
		return
	end
	talliedKey = key
	table.clear(places)

	local roundScored = scoreThisRound()
	for _, row in roundScored do
		matchTotals[row.userId] = (matchTotals[row.userId] or 0) + row.votes
	end

	local matchFinal = RoundManager.isMatchFinal()
	local displayScored = if matchFinal then scoreMatch() else roundScored

	local ranked: { RoundRewards.RankedRow } = {}
	for _, row in roundScored do
		table.insert(ranked, { userId = row.userId, votes = row.votes })
	end

	local placementRanked: { RoundRewards.RankedRow }? = nil
	if matchFinal then
		placementRanked = {}
		for _, row in displayScored do
			table.insert(placementRanked, { userId = row.userId, votes = row.votes })
		end
	end

	local voteCopy = table.clone(votes)
	RoundRewards.award({
		roundId = RoundManager.getRoundId(),
		designRound = RoundManager.getDesignRound(),
		entries = DesignService.getLocked(),
		ranked = ranked,
		placementRanked = placementRanked,
		awardPlacement = matchFinal,
		votes = voteCopy,
	})

	local placementOn = matchFinal and #displayScored >= Economy.minEntriesForPlacement()
	local summary = ""
	for index, row in displayScored do
		if index > 3 then
			break
		end
		local awarded = if placementOn then Economy.placementReward(index).coins else 0
		table.insert(places, {
			place = index,
			userId = row.userId,
			name = row.name,
			votes = row.votes,
			awarded = awarded,
			total = balanceOf(row.userId),
		})
		local label = if index == 1 then "1st" elseif index == 2 then "2nd" else "3rd"
		summary ..= `{label} {row.name} +{awarded} ({row.votes} votes) `
	end
	local kind = if matchFinal then "Match party" else "Round party"
	if summary == "" then
		print(`{PREFIX} {kind} | no tattoos to place`)
	else
		print(`{PREFIX} {kind} | {summary}`)
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

local function endsIn(seconds: number?): number?
	if seconds == nil or seconds <= 0 then
		return nil
	end
	return Workspace:GetServerTimeNow() + seconds
end

local function leaveStage()
	if staged then
		staged = false
		WinnerStage.release()
	end
end

local function prepare(state: RoundState): number?
	local roundId = RoundManager.getRoundId()
	if state == "WaitingForPlayers" or state == "Intermission" then
		resetMatch()
		leaveStage()
		phase = "Idle"
		phaseEnds = nil
		broadcast()
		return nil
	end
	if state == "Cleanup" then
		-- Between design rounds we keep matchTotals; wipe the finished design only.
		leaveStage()
		clearDesignRound()
		phase = "Idle"
		phaseEnds = nil
		broadcast()
		return nil
	end
	if state == "ThemeReveal" then
		-- Fresh canvas for this design round (also covers round 2+ after Cleanup).
		clearDesignRound()
		leaveStage()
		phase = "Idle"
		phaseEnds = nil
		broadcast()
		return nil
	end
	if state == "Submission" then
		DesignService.capture(roundId, RoundManager.getContestants())
		phase = "TimeUp"
		phaseEnds = endsIn(GameConfig.getDuration(state))
		broadcast()
		return nil
	end
	if state == "Showcase" then
		DesignService.lock(roundId)
		showcaseStart = Workspace:GetServerTimeNow()
		local count = math.max(1, #DesignService.getLocked())
		local duration = count * GameConfig.getShowcaseSlice()
		staged = true
		WinnerStage.gather()
		phase = "Showcase"
		phaseEnds = endsIn(duration)
		broadcast()
		return duration
	end
	if state == "Voting" then
		phase = "Voting"
		phaseEnds = endsIn(GameConfig.getDuration(state))
		broadcast()
		return nil
	end
	if state == "Results" then
		tally()
		if staged then
			local podium = {}
			for _, place in places do
				table.insert(podium, place.userId)
			end
			WinnerStage.crown(podium)
		end
		phase = "Party"
		phaseEnds = endsIn(GameConfig.getDuration(state))
		broadcast()
		return nil
	end
	leaveStage()
	phase = "Idle"
	phaseEnds = nil
	broadcast()
	return nil
end

local CeremonyService = {}

function CeremonyService.start()
	RoundManager.setPrepare(prepare)
	Remotes.CastVote.OnServerEvent:Connect(onVote)
end

return CeremonyService
