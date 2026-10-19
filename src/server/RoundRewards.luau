--!strict

-- Pays out one finished round. Called once per round by the ceremony, after the vote is counted.
-- Each player is paid at most once per round, and everything comes from what the server saw.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Economy)
local InkColors = require(ReplicatedStorage.Shared.InkColors)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DesignService = require(script.Parent.DesignService)
local PlayerEconomy = require(script.Parent.PlayerEconomy)
local Profiles = require(script.Parent.Profiles)

type LockedDesign = DesignService.LockedDesign

export type RankedRow = {
	userId: number,
	votes: number,
}

export type AwardInput = {
	roundId: number,
	entries: { LockedDesign },
	-- Artists who actually drew, best first.
	ranked: { RankedRow },
	-- Voter user id to the artist they picked.
	votes: { [number]: number },
}

type Line = {
	label: string,
	coins: number,
	xp: number,
}

local PREFIX = "[InkMasters]"

local paid: { [Player]: { [number]: boolean } } = {}

local RoundRewards = {}

local function paidFor(player: Player): { [number]: boolean }
	local existing: { [number]: boolean }? = paid[player]
	if existing ~= nil then
		return existing
	end
	local created: { [number]: boolean } = {}
	paid[player] = created
	return created
end

local function pickOf(votes: { [number]: number }, userId: number): number?
	local picked: number? = votes[userId]
	return picked
end

local function ordinal(place: number): string
	if place == 1 then
		return "1st place"
	elseif place == 2 then
		return "2nd place"
	end
	return "3rd place"
end

local function distinctInks(design: DesignService.LockedDesign): number
	local seen: { [string]: boolean } = {}
	local count = 0
	for _, element in design.design.elements do
		local used: { string } = {}
		if element.fill then
			local id = InkColors.matchId(element.color)
			if id ~= nil then
				table.insert(used, id)
			end
		end
		if element.outline then
			local id = InkColors.matchId(element.line)
			if id ~= nil then
				table.insert(used, id)
			end
		end
		for _, id in used do
			if seen[id] ~= true then
				seen[id] = true
				count += 1
			end
		end
	end
	return count
end

local function entryFor(entries: { LockedDesign }, userId: number): LockedDesign?
	for _, entry in entries do
		if entry.userId == userId then
			return entry
		end
	end
	return nil
end

local function payPlayer(player: Player, input: AwardInput, placementOn: boolean)
	local userId = player.UserId
	local entry = entryFor(input.entries, userId)
	local marks = if entry ~= nil then #entry.design.elements else 0
	local drew = marks > 0

	local place = 0
	local received = 0
	for index, row in input.ranked do
		if row.userId == userId then
			place = index
			received = row.votes
		end
	end

	local lines: { Line } = {}
	local function add(label: string, coins: number, xp: number)
		if coins > 0 or xp > 0 then
			table.insert(lines, { label = label, coins = coins, xp = xp })
		end
	end

	if drew and entry ~= nil then
		add("Finished the round", Economy.PARTICIPATION.coins, Economy.PARTICIPATION.xp)
		PlayerEconomy.recordEvent(player, "rounds", 1)
		PlayerEconomy.recordEvent(player, "marks", marks)
		PlayerEconomy.recordEvent(player, "inks", distinctInks(entry))
		if PlayerEconomy.takeFirstRoundOfDay(player) then
			add("First round of the day", Economy.FIRST_ROUND_OF_DAY.coins, Economy.FIRST_ROUND_OF_DAY.xp)
		end
	end

	local picked = pickOf(input.votes, userId)
	if picked ~= nil and entryFor(input.entries, picked) ~= nil then
		add("Voted", Economy.VOTE_CAST.coins, Economy.VOTE_CAST.xp)
		PlayerEconomy.recordEvent(player, "votesCast", 1)
	end

	if drew and received > 0 then
		local word = if received == 1 then "vote" else "votes"
		add(
			`{received} {word} received`,
			received * Economy.PER_VOTE_RECEIVED.coins,
			received * Economy.PER_VOTE_RECEIVED.xp
		)
		PlayerEconomy.recordEvent(player, "votesReceived", received)
	end

	if drew and placementOn then
		if place >= 1 and place <= 3 then
			local reward = Economy.placementReward(place)
			add(ordinal(place), reward.coins, reward.xp)
			PlayerEconomy.recordEvent(player, "podiums", 1)
			if place == 1 then
				PlayerEconomy.recordEvent(player, "wins", 1)
			end
			local streak = PlayerEconomy.setPodiumStreak(player, true)
			if streak >= 2 then
				local steps = math.min(streak - 1, Economy.STREAK_MAX_STEPS)
				add(`{streak} podiums in a row`, steps * Economy.STREAK_STEP_COINS, 0)
			end
		else
			PlayerEconomy.setPodiumStreak(player, false)
		end
	end

	local totalCoins = 0
	local totalXp = 0
	for _, line in lines do
		totalCoins += line.coins
		totalXp += line.xp
	end

	local data = Profiles.get(player)
	local levelBefore = if data ~= nil then PlayerEconomy.getLevel(data) else 1
	local grantedCoins = PlayerEconomy.addCoins(player, totalCoins)
	PlayerEconomy.addXp(player, totalXp)
	local levelAfter = if data ~= nil then PlayerEconomy.getLevel(data) else levelBefore

	Remotes.RoundRewards:FireClient(player, {
		roundId = input.roundId,
		lines = lines,
		coins = grantedCoins,
		xp = totalXp,
		balance = PlayerEconomy.getCoins(player),
		levelBefore = levelBefore,
		levelAfter = levelAfter,
		place = if drew and placementOn and place >= 1 and place <= 3 then place else 0,
	})
	print(`{PREFIX} Paid {player.Name} | +{grantedCoins} coins, +{totalXp} XP | {#lines} lines`)
end

function RoundRewards.award(input: AwardInput)
	local placementOn = #input.ranked >= Economy.minEntriesForPlacement()

	local people: { [number]: boolean } = {}
	for _, entry in input.entries do
		people[entry.userId] = true
	end
	for voter in input.votes do
		people[voter] = true
	end

	for userId in people do
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil and Profiles.get(player) ~= nil then
			local done = paidFor(player)
			if done[input.roundId] ~= true then
				done[input.roundId] = true
				payPlayer(player, input, placementOn)
			end
		end
	end
end

function RoundRewards.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		paid[player] = nil
	end)
end

return RoundRewards
