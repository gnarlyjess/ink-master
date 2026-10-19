--!strict

-- The saved player profile and the read-only view the server sends to that player.
-- reconcile() turns whatever came out of the data store into a valid profile, so a
-- missing field, an old version, or a damaged value never crashes the game or wipes progress.

local Catalogue = require(script.Parent.Catalogue)
local Economy = require(script.Parent.Economy)

export type DailyState = {
	day: number,
	progress: { [string]: number },
	claimed: { [string]: boolean },
	firstRoundDone: boolean,
}

export type LoginState = {
	lastClaimDay: number,
	streak: number,
}

export type Settings = {
	sound: boolean,
	confetti: boolean,
	hints: boolean,
}

export type ProfileData = {
	version: number,
	coins: number,
	xp: number,
	rewardedLevel: number,
	lifetimeEarned: number,
	lifetimeSpent: number,
	owned: { [string]: boolean },
	equipped: { [string]: string },
	stats: { [string]: number },
	achievements: { [string]: boolean },
	daily: DailyState,
	login: LoginState,
	settings: Settings,
	welcomed: boolean,
}

export type ChallengeView = {
	id: string,
	text: string,
	progress: number,
	target: number,
	coins: number,
	xp: number,
	claimed: boolean,
}

export type LoginView = {
	streak: number,
	canClaim: boolean,
	dayInCycle: number,
	nextCoins: number,
}

export type ProfileView = {
	revision: number,
	coins: number,
	xp: number,
	level: number,
	levelInto: number,
	levelNeed: number,
	maxed: boolean,
	rewardedLevel: number,
	lifetimeEarned: number,
	owned: { [string]: boolean },
	equipped: { [string]: string },
	stats: { [string]: number },
	achievements: { [string]: boolean },
	challenges: { ChallengeView },
	login: LoginView,
	featuredId: string,
	day: number,
	secondsToReset: number,
	settings: Settings,
	persistent: boolean,
}

local ProfileTypes = {}

ProfileTypes.VERSION = 1
ProfileTypes.EQUIP_SLOTS = { "title", "frame", "confetti", "emote" }

local STAT_KEYS = {
	"rounds",
	"wins",
	"podiums",
	"votesCast",
	"votesReceived",
	"maxMarks",
	"maxInks",
	"purchases",
	"podiumStreak",
	"bestStreak",
	"loginStreak",
}

local SLOT_CATEGORY: { [string]: string } = {
	title = "title",
	frame = "frame",
	confetti = "confetti",
	emote = "emote",
}

local MAX_KEYS = 300
local MAX_KEY_LENGTH = 48

function ProfileTypes.new(): ProfileData
	local stats: { [string]: number } = {}
	for _, key in STAT_KEYS do
		stats[key] = 0
	end
	return {
		version = ProfileTypes.VERSION,
		coins = Economy.START_COINS,
		xp = 0,
		rewardedLevel = 1,
		lifetimeEarned = 0,
		lifetimeSpent = 0,
		owned = {},
		equipped = { title = "", frame = "", confetti = "", emote = "" },
		stats = stats,
		achievements = {},
		daily = { day = 0, progress = {}, claimed = {}, firstRoundDone = false },
		login = { lastClaimDay = 0, streak = 0 },
		settings = { sound = true, confetti = true, hints = true },
		welcomed = false,
	}
end

local function readCount(value: any, fallback: number, ceiling: number): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return math.clamp(math.floor(value), 0, ceiling)
end

local function readFlag(value: any, fallback: boolean): boolean
	if typeof(value) == "boolean" then
		return value
	end
	return fallback
end

local function readFlagMap(value: any): { [string]: boolean }
	local result: { [string]: boolean } = {}
	if typeof(value) ~= "table" then
		return result
	end
	local count = 0
	for key, flag in value do
		if typeof(key) == "string" and #key <= MAX_KEY_LENGTH and flag == true and count < MAX_KEYS then
			result[key] = true
			count += 1
		end
	end
	return result
end

local function readCountMap(value: any, ceiling: number): { [string]: number }
	local result: { [string]: number } = {}
	if typeof(value) ~= "table" then
		return result
	end
	local count = 0
	for key, amount in value do
		if typeof(key) == "string" and #key <= MAX_KEY_LENGTH and typeof(amount) == "number" and count < MAX_KEYS then
			result[key] = readCount(amount, 0, ceiling)
			count += 1
		end
	end
	return result
end

function ProfileTypes.reconcile(raw: any): ProfileData
	local profile = ProfileTypes.new()
	if typeof(raw) ~= "table" then
		return profile
	end

	profile.coins = readCount(raw.coins, profile.coins, Economy.COIN_CEILING)
	profile.xp = readCount(raw.xp, 0, Economy.COIN_CEILING)
	profile.rewardedLevel = math.clamp(readCount(raw.rewardedLevel, 1, Economy.MAX_LEVEL), 1, Economy.MAX_LEVEL)
	profile.lifetimeEarned = readCount(raw.lifetimeEarned, 0, Economy.COIN_CEILING * 100)
	profile.lifetimeSpent = readCount(raw.lifetimeSpent, 0, Economy.COIN_CEILING * 100)
	profile.owned = readFlagMap(raw.owned)
	profile.achievements = readFlagMap(raw.achievements)
	profile.welcomed = readFlag(raw.welcomed, false)

	if typeof(raw.stats) == "table" then
		for _, key in STAT_KEYS do
			profile.stats[key] = readCount(raw.stats[key], 0, 1000000000)
		end
	end

	if typeof(raw.equipped) == "table" then
		for _, slot in ProfileTypes.EQUIP_SLOTS do
			local id = raw.equipped[slot]
			if typeof(id) == "string" and profile.owned[id] == true then
				local item = Catalogue.get(id)
				if item ~= nil and item.category == SLOT_CATEGORY[slot] then
					profile.equipped[slot] = id
				end
			end
		end
	end

	if typeof(raw.daily) == "table" then
		profile.daily = {
			day = readCount(raw.daily.day, 0, 1000000),
			progress = readCountMap(raw.daily.progress, 1000000),
			claimed = readFlagMap(raw.daily.claimed),
			firstRoundDone = readFlag(raw.daily.firstRoundDone, false),
		}
	end

	if typeof(raw.login) == "table" then
		profile.login = {
			lastClaimDay = readCount(raw.login.lastClaimDay, 0, 1000000),
			streak = readCount(raw.login.streak, 0, 100000),
		}
	end

	if typeof(raw.settings) == "table" then
		profile.settings = {
			sound = readFlag(raw.settings.sound, true),
			confetti = readFlag(raw.settings.confetti, true),
			hints = readFlag(raw.settings.hints, true),
		}
	end

	return profile
end

local function finite(value: any): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function copyFlags(value: any): { [string]: boolean }
	local result: { [string]: boolean } = {}
	if typeof(value) == "table" then
		for key, flag in value do
			if typeof(key) == "string" and flag == true then
				result[key] = true
			end
		end
	end
	return result
end

local function copyCounts(value: any): { [string]: number }
	local result: { [string]: number } = {}
	if typeof(value) == "table" then
		for key, amount in value do
			if typeof(key) == "string" and typeof(amount) == "number" then
				result[key] = amount
			end
		end
	end
	return result
end

local function copyStrings(value: any): { [string]: string }
	local result: { [string]: string } = {}
	if typeof(value) == "table" then
		for key, text in value do
			if typeof(key) == "string" and typeof(text) == "string" then
				result[key] = text
			end
		end
	end
	return result
end

-- Client side check of the payload the server sends. Returns nil when it is not usable.
function ProfileTypes.readView(payload: any): ProfileView?
	if typeof(payload) ~= "table" then
		return nil
	end
	local revision = finite(payload.revision)
	local coins = finite(payload.coins)
	local xp = finite(payload.xp)
	local level = finite(payload.level)
	local levelInto = finite(payload.levelInto)
	local levelNeed = finite(payload.levelNeed)
	local rewardedLevel = finite(payload.rewardedLevel)
	local lifetimeEarned = finite(payload.lifetimeEarned)
	local day = finite(payload.day)
	local secondsToReset = finite(payload.secondsToReset)
	if
		revision == nil
		or coins == nil
		or xp == nil
		or level == nil
		or levelInto == nil
		or levelNeed == nil
		or rewardedLevel == nil
		or lifetimeEarned == nil
		or day == nil
		or secondsToReset == nil
	then
		return nil
	end
	if typeof(payload.featuredId) ~= "string" or typeof(payload.maxed) ~= "boolean" then
		return nil
	end
	if typeof(payload.persistent) ~= "boolean" or typeof(payload.settings) ~= "table" then
		return nil
	end
	if typeof(payload.login) ~= "table" or typeof(payload.challenges) ~= "table" then
		return nil
	end

	local login = payload.login
	local streak = finite(login.streak)
	local dayInCycle = finite(login.dayInCycle)
	local nextCoins = finite(login.nextCoins)
	if streak == nil or dayInCycle == nil or nextCoins == nil or typeof(login.canClaim) ~= "boolean" then
		return nil
	end

	local challenges: { ChallengeView } = {}
	for index = 1, math.min(#payload.challenges, 6) do
		local item = payload.challenges[index]
		if typeof(item) ~= "table" then
			return nil
		end
		local progress = finite(item.progress)
		local target = finite(item.target)
		local rewardCoins = finite(item.coins)
		local rewardXp = finite(item.xp)
		if
			typeof(item.id) ~= "string"
			or typeof(item.text) ~= "string"
			or progress == nil
			or target == nil
			or rewardCoins == nil
			or rewardXp == nil
			or typeof(item.claimed) ~= "boolean"
		then
			return nil
		end
		table.insert(challenges, {
			id = item.id,
			text = item.text,
			progress = progress,
			target = target,
			coins = rewardCoins,
			xp = rewardXp,
			claimed = item.claimed,
		})
	end

	local settings = payload.settings
	return {
		revision = revision,
		coins = coins,
		xp = xp,
		level = level,
		levelInto = levelInto,
		levelNeed = levelNeed,
		maxed = payload.maxed,
		rewardedLevel = rewardedLevel,
		lifetimeEarned = lifetimeEarned,
		owned = copyFlags(payload.owned),
		equipped = copyStrings(payload.equipped),
		stats = copyCounts(payload.stats),
		achievements = copyFlags(payload.achievements),
		challenges = challenges,
		login = {
			streak = streak,
			canClaim = login.canClaim,
			dayInCycle = dayInCycle,
			nextCoins = nextCoins,
		},
		featuredId = payload.featuredId,
		day = day,
		secondsToReset = secondsToReset,
		settings = {
			sound = settings.sound ~= false,
			confetti = settings.confetti ~= false,
			hints = settings.hints ~= false,
		},
		persistent = payload.persistent,
	}
end

return ProfileTypes
