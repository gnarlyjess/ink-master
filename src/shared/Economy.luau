--!strict

-- Every number that moves coins or XP lives here, so the economy can be tuned in one place.
-- One currency (coins) and one progression meter (XP, which makes levels).
-- Both are only ever changed on the server.

local GameConfig = require(script.Parent.GameConfig)

export type Reward = {
	coins: number,
	xp: number,
}

export type LevelReward = {
	coins: number,
	-- Primary cosmetic for UI copy; itemIds may grant extras at the same level.
	itemId: string?,
	itemIds: { string }?,
}

local Economy = {}

Economy.MAX_LEVEL = 30
Economy.START_COINS = 500
Economy.COIN_CEILING = 1000000000

-- Lobby buy: claim the next free round's theme (FIFO). Blank text = random theme.
Economy.THEME_PICK_PRICE = 80
Economy.THEME_PICK_MAX_CHARS = 32

-- Design-phase time boost. One purchase per design round for the whole lobby.
export type TimeBoostOption = {
	id: string,
	seconds: number,
	price: number,
	label: string,
}

Economy.TIME_BOOST_OPTIONS = {
	{ id = "30", seconds = 30, price = 40, label = "+30 secs" },
	{ id = "45", seconds = 45, price = 55, label = "+45 secs" },
	{ id = "60", seconds = 60, price = 70, label = "+1 min" },
} :: { TimeBoostOption }

function Economy.getTimeBoost(id: string): TimeBoostOption?
	for _, option in Economy.TIME_BOOST_OPTIONS do
		if option.id == id then
			return option
		end
	end
	return nil
end

-- Round rewards. A round is about five minutes live, so a typical player earns 30 to 60 coins.
Economy.PARTICIPATION = { coins = 20, xp = 30 } :: Reward
Economy.VOTE_CAST = { coins = 5, xp = 10 } :: Reward
Economy.PER_VOTE_RECEIVED = { coins = 5, xp = 5 } :: Reward
Economy.FIRST_ROUND_OF_DAY = { coins = 40, xp = 40 } :: Reward
Economy.PLACEMENT = {
	[1] = { coins = 100, xp = 80 },
	[2] = { coins = 50, xp = 50 },
	[3] = { coins = 25, xp = 30 },
} :: { [number]: Reward }

-- Each podium finish in a row adds this many coins, up to the cap.
Economy.STREAK_STEP_COINS = 10
Economy.STREAK_MAX_STEPS = 5

-- Seven day login cycle. Day seven is the big one.
Economy.LOGIN_REWARDS = { 25, 30, 40, 50, 60, 75, 150 }

-- Placement coins need enough artists that a podium means something.
-- Dev mode allows one so a solo test can still earn.
function Economy.minEntriesForPlacement(): number
	if GameConfig.DevMode then
		return 1
	end
	return 3
end

function Economy.placementReward(place: number): Reward
	local reward = Economy.PLACEMENT[place]
	if reward == nil then
		return { coins = 0, xp = 0 }
	end
	return reward
end

-- XP needed to move from this level to the next.
function Economy.xpToNext(level: number): number
	return 120 + 30 * (level - 1)
end

-- Total XP required to *be* this level (start of the level).
function Economy.xpToReach(level: number): number
	local target = math.clamp(math.floor(level), 1, Economy.MAX_LEVEL)
	local total = 0
	for at = 1, target - 1 do
		total += Economy.xpToNext(at)
	end
	return total
end

export type LevelInfo = {
	level: number,
	into: number,
	need: number,
	maxed: boolean,
}

function Economy.levelInfo(totalXp: number): LevelInfo
	local level = 1
	local remaining = math.max(0, math.floor(totalXp))
	while level < Economy.MAX_LEVEL do
		local need = Economy.xpToNext(level)
		if remaining < need then
			return { level = level, into = remaining, need = need, maxed = false }
		end
		remaining -= need
		level += 1
	end
	return { level = level, into = 0, need = 0, maxed = true }
end

-- Coins for every level, plus milestone cosmetics / inks that cannot be bought.
-- Prestige auras stack with titles at key levels — motion is the flex, text is flavor.
local MILESTONES: { [number]: string | { string } } = {
	[2] = "title:steady",
	[3] = "title:rookie",
	[4] = "pack:geometry",
	[5] = "title:liner",
	[6] = "pack:starter_tools",
	[7] = "title:collector",
	[8] = { "frame:rose", "aura:mist" },
	[9] = "title:needle",
	[10] = { "title:legend", "aura:neon" },
	[11] = "confetti:aqua",
	[12] = "title:parlour",
	[13] = "ink:lemon",
	[14] = "ink:navy",
	[15] = "confetti:stars",
	[16] = "ink:coral",
	[17] = "ink:lime",
	[18] = "ink:lavender",
	[19] = "ink:bubble",
	[20] = { "title:master", "aura:gold" },
	[21] = "ink:cream",
	[22] = "ink:indigo",
	[23] = "ink:ice",
	[24] = "ink:silver",
	[25] = "frame:midnight",
	[30] = { "title:icon", "aura:icon" },
}

local function milestoneList(level: number): { string }
	local raw = MILESTONES[level]
	if raw == nil then
		return {}
	end
	if typeof(raw) == "string" then
		return { raw }
	end
	return raw
end

function Economy.levelReward(level: number): LevelReward
	local ids = milestoneList(level)
	return {
		coins = 20 + level * 5,
		itemId = ids[1],
		itemIds = if #ids > 0 then ids else nil,
	}
end

function Economy.milestoneLevel(itemId: string): number?
	for level, raw in MILESTONES do
		if typeof(raw) == "string" then
			if raw == itemId then
				return level
			end
		else
			for _, id in raw do
				if id == itemId then
					return level
				end
			end
		end
	end
	return nil
end

-- UTC day number. Daily systems reset when this changes.
function Economy.dayNumber(now: number): number
	return math.floor(now / 86400)
end

function Economy.secondsToReset(now: number): number
	return 86400 - (now % 86400)
end

return Economy
