--!strict

-- Daily challenges and lifetime achievements. Both read events the server records
-- from real rounds. The client never reports progress.

export type EventName = "rounds" | "votesCast" | "votesReceived" | "podiums" | "wins" | "marks" | "inks"

export type Challenge = {
	id: string,
	text: string,
	event: EventName,
	target: number,
	-- "max" challenges track the best single round instead of a running total.
	best: boolean,
	tier: number,
	coins: number,
	xp: number,
}

export type Achievement = {
	id: string,
	name: string,
	description: string,
	stat: string,
	target: number,
	coins: number,
	itemId: string?,
}

local Quests = {}

local function challenge(
	id: string,
	text: string,
	event: EventName,
	target: number,
	best: boolean,
	tier: number,
	coins: number,
	xp: number
): Challenge
	return {
		id = id,
		text = text,
		event = event,
		target = target,
		best = best,
		tier = tier,
		coins = coins,
		xp = xp,
	}
end

local pool: { Challenge } = {
	challenge("play2", "Finish 2 rounds", "rounds", 2, false, 1, 40, 40),
	challenge("vote3", "Cast 3 votes", "votesCast", 3, false, 1, 30, 30),
	challenge("marks8", "Place 8 marks in one tattoo", "marks", 8, true, 1, 35, 35),
	challenge("inks3", "Use 3 different inks in one tattoo", "inks", 3, true, 2, 45, 45),
	challenge("marks14", "Place 14 marks in one tattoo", "marks", 14, true, 2, 55, 50),
	challenge("play4", "Finish 4 rounds", "rounds", 4, false, 2, 80, 70),
	challenge("recv3", "Receive 3 votes", "votesReceived", 3, false, 2, 50, 50),
	challenge("podium", "Reach the podium", "podiums", 1, false, 3, 70, 80),
	challenge("recv6", "Receive 6 votes", "votesReceived", 6, false, 3, 80, 80),
	challenge("win", "Win a round", "wins", 1, false, 3, 100, 100),
}

local achievements: { Achievement } = {
	{
		id = "first_round",
		name = "First flash",
		description = "Finish a round",
		stat = "rounds",
		target = 1,
		coins = 25,
	},
	{ id = "ten_rounds", name = "Regular", description = "Finish 10 rounds", stat = "rounds", target = 10, coins = 60 },
	{
		id = "fifty_rounds",
		name = "Veteran",
		description = "Finish 50 rounds",
		stat = "rounds",
		target = 50,
		coins = 200,
	},
	{
		id = "ten_votes",
		name = "Fair judge",
		description = "Cast 10 votes",
		stat = "votesCast",
		target = 10,
		coins = 50,
	},
	{
		id = "fifty_votes",
		name = "Critic",
		description = "Cast 50 votes",
		stat = "votesCast",
		target = 50,
		coins = 150,
	},
	{
		id = "first_podium",
		name = "On the podium",
		description = "Finish in the top three",
		stat = "podiums",
		target = 1,
		coins = 50,
	},
	{
		id = "five_podiums",
		name = "Crowd pleaser",
		description = "Reach the podium 5 times",
		stat = "podiums",
		target = 5,
		coins = 120,
	},
	{ id = "first_win", name = "Best in show", description = "Win a round", stat = "wins", target = 1, coins = 75 },
	{
		id = "five_wins",
		name = "Gold needle",
		description = "Win 5 rounds",
		stat = "wins",
		target = 5,
		coins = 200,
		itemId = "title:gold",
	},
	{
		id = "streak3",
		name = "Hot streak",
		description = "Reach the podium 3 rounds in a row",
		stat = "bestStreak",
		target = 3,
		coins = 100,
	},
	{
		id = "detailed",
		name = "Fine detail",
		description = "Place 15 marks in one tattoo",
		stat = "maxMarks",
		target = 15,
		coins = 60,
	},
	{
		id = "colourist",
		name = "Colourist",
		description = "Use 5 different inks in one tattoo",
		stat = "maxInks",
		target = 5,
		coins = 80,
	},
	{
		id = "popular",
		name = "Fan favourite",
		description = "Receive 25 votes in total",
		stat = "votesReceived",
		target = 25,
		coins = 100,
	},
	{
		id = "collector",
		name = "Collector",
		description = "Buy 5 items from the shop",
		stat = "purchases",
		target = 5,
		coins = 100,
	},
	{ id = "level5", name = "Apprentice", description = "Reach level 5", stat = "level", target = 5, coins = 75 },
	{ id = "level10", name = "Journeyman", description = "Reach level 10", stat = "level", target = 10, coins = 150 },
	{
		id = "loyal",
		name = "Regular customer",
		description = "Claim the daily reward 7 days in a row",
		stat = "loginStreak",
		target = 7,
		coins = 100,
	},
}

Quests.achievements = achievements

function Quests.getChallenge(id: string): Challenge?
	for _, item in pool do
		if item.id == id then
			return item
		end
	end
	return nil
end

-- Three challenges per UTC day: one easy, one medium, one hard. Same for every player.
function Quests.dailyFor(day: number): { Challenge }
	local picked: { Challenge } = {}
	for tier = 1, 3 do
		local options: { Challenge } = {}
		for _, item in pool do
			if item.tier == tier then
				table.insert(options, item)
			end
		end
		local choice = options[(day + tier * 5) % #options + 1]
		if choice ~= nil then
			table.insert(picked, choice)
		end
	end
	return picked
end

return Quests
