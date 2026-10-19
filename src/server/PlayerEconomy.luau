--!strict

-- The one place coins, XP, levels, items, challenges, and achievements change.
-- Everything here runs without yielding between a check and its change, so a purchase
-- or a claim can only ever happen once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Economy = require(ReplicatedStorage.Shared.Economy)
local ProfileTypes = require(ReplicatedStorage.Shared.ProfileTypes)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Profiles = require(script.Parent.Profiles)

type ProfileData = ProfileTypes.ProfileData

local PlayerEconomy = {}

local changedCallbacks: { (Player) -> () } = {}

local EVENT_STAT: { [string]: string } = {
	rounds = "rounds",
	votesCast = "votesCast",
	votesReceived = "votesReceived",
	podiums = "podiums",
	wins = "wins",
	marks = "maxMarks",
	inks = "maxInks",
}

local function statOf(data: ProfileData, key: string): number
	local value: number? = data.stats[key]
	if value == nil then
		return 0
	end
	return value
end

local function progressOf(data: ProfileData, id: string): number
	local value: number? = data.daily.progress[id]
	if value == nil then
		return 0
	end
	return value
end

function PlayerEconomy.today(): number
	return Economy.dayNumber(os.time())
end

function PlayerEconomy.ensureDaily(data: ProfileData)
	local day = PlayerEconomy.today()
	if data.daily.day ~= day then
		data.daily = { day = day, progress = {}, claimed = {}, firstRoundDone = false }
	end
end

function PlayerEconomy.onChanged(callback: (Player) -> ())
	table.insert(changedCallbacks, callback)
end

local function changed(player: Player)
	Profiles.markDirty(player)
	for _, callback in changedCallbacks do
		task.spawn(callback, player)
	end
end

function PlayerEconomy.notify(player: Player, kind: string, text: string)
	if player.Parent ~= Players then
		return
	end
	Remotes.ProfileNotice:FireClient(player, { kind = kind, text = text })
end

function PlayerEconomy.getLevel(data: ProfileData): number
	return Economy.levelInfo(data.xp).level
end

local function giveCoins(data: ProfileData, amount: number): number
	local whole = math.floor(amount)
	if whole <= 0 then
		return 0
	end
	local granted = math.min(whole, Economy.COIN_CEILING - data.coins)
	if granted <= 0 then
		return 0
	end
	data.coins += granted
	data.lifetimeEarned += granted
	return granted
end

local function slotFor(item: Catalogue.Item): string?
	for _, slot in ProfileTypes.EQUIP_SLOTS do
		if item.category == slot then
			return slot
		end
	end
	return nil
end

local function giveItem(player: Player, data: ProfileData, itemId: string, announce: boolean): boolean
	local item = Catalogue.get(itemId)
	if item == nil or data.owned[itemId] == true then
		return false
	end
	data.owned[itemId] = true
	local slot = slotFor(item)
	if slot ~= nil and data.equipped[slot] == "" then
		data.equipped[slot] = itemId
	end
	if announce then
		PlayerEconomy.notify(player, "item", `New: {item.name}`)
	end
	return true
end

local function checkAchievements(player: Player, data: ProfileData)
	for _, achievement in Quests.achievements do
		if data.achievements[achievement.id] ~= true then
			local value = if achievement.stat == "level"
				then PlayerEconomy.getLevel(data)
				else statOf(data, achievement.stat)
			if value >= achievement.target then
				data.achievements[achievement.id] = true
				giveCoins(data, achievement.coins)
				if achievement.itemId ~= nil then
					giveItem(player, data, achievement.itemId, false)
				end
				PlayerEconomy.notify(
					player,
					"achievement",
					`Achievement: {achievement.name} (+{achievement.coins} coins)`
				)
			end
		end
	end
end

local function settleLevels(player: Player, data: ProfileData)
	local level = PlayerEconomy.getLevel(data)
	while data.rewardedLevel < level do
		local nextLevel = data.rewardedLevel + 1
		data.rewardedLevel = nextLevel
		local reward = Economy.levelReward(nextLevel)
		giveCoins(data, reward.coins)
		local itemId = reward.itemId
		local extra = ""
		if itemId ~= nil and giveItem(player, data, itemId, false) then
			local item = Catalogue.get(itemId)
			if item ~= nil then
				extra = ` and {item.name}`
			end
		end
		PlayerEconomy.notify(player, "level", `Level {nextLevel}! +{reward.coins} coins{extra}`)
	end
end

function PlayerEconomy.addCoins(player: Player, amount: number): number
	local data = Profiles.get(player)
	if data == nil then
		return 0
	end
	local granted = giveCoins(data, amount)
	if granted > 0 then
		changed(player)
	end
	return granted
end

function PlayerEconomy.addXp(player: Player, amount: number)
	local data = Profiles.get(player)
	if data == nil then
		return
	end
	local whole = math.floor(amount)
	if whole <= 0 then
		return
	end
	data.xp = math.min(data.xp + whole, Economy.COIN_CEILING)
	settleLevels(player, data)
	checkAchievements(player, data)
	changed(player)
end

function PlayerEconomy.getCoins(player: Player): number
	local data = Profiles.get(player)
	if data == nil then
		return 0
	end
	return data.coins
end

-- Records something that happened in a real round. Events move the lifetime stats,
-- today's challenges, and the achievements.
function PlayerEconomy.recordEvent(player: Player, event: string, amount: number)
	local data = Profiles.get(player)
	local statKey = EVENT_STAT[event]
	if data == nil or statKey == nil or amount <= 0 then
		return
	end
	PlayerEconomy.ensureDaily(data)
	local best = event == "marks" or event == "inks"
	if best then
		data.stats[statKey] = math.max(statOf(data, statKey), amount)
	else
		data.stats[statKey] = statOf(data, statKey) + amount
	end

	for _, challenge in Quests.dailyFor(data.daily.day) do
		if challenge.event == event and data.daily.claimed[challenge.id] ~= true then
			local previous = progressOf(data, challenge.id)
			local nextValue = if challenge.best then math.max(previous, amount) else previous + amount
			data.daily.progress[challenge.id] = math.min(challenge.target, nextValue)
		end
	end
	checkAchievements(player, data)
	changed(player)
end

-- Podium streak: consecutive rounds on the podium. Any other finished round resets it.
function PlayerEconomy.setPodiumStreak(player: Player, onPodium: boolean): number
	local data = Profiles.get(player)
	if data == nil then
		return 0
	end
	if onPodium then
		data.stats.podiumStreak = statOf(data, "podiumStreak") + 1
		data.stats.bestStreak = math.max(statOf(data, "bestStreak"), statOf(data, "podiumStreak"))
	else
		data.stats.podiumStreak = 0
	end
	checkAchievements(player, data)
	changed(player)
	return statOf(data, "podiumStreak")
end

-- True the first time it is called for the player on a given day.
function PlayerEconomy.takeFirstRoundOfDay(player: Player): boolean
	local data = Profiles.get(player)
	if data == nil then
		return false
	end
	PlayerEconomy.ensureDaily(data)
	if data.daily.firstRoundDone then
		return false
	end
	data.daily.firstRoundDone = true
	changed(player)
	return true
end

function PlayerEconomy.claimChallenge(player: Player, id: string): (boolean, string)
	local data = Profiles.get(player)
	if data == nil then
		return false, "Your profile is still loading."
	end
	PlayerEconomy.ensureDaily(data)
	for _, challenge in Quests.dailyFor(data.daily.day) do
		if challenge.id == id then
			if data.daily.claimed[id] == true then
				return false, "You already claimed that one."
			end
			if progressOf(data, id) < challenge.target then
				return false, "That challenge isn't finished yet."
			end
			data.daily.claimed[id] = true
			giveCoins(data, challenge.coins)
			data.xp = math.min(data.xp + challenge.xp, Economy.COIN_CEILING)
			settleLevels(player, data)
			checkAchievements(player, data)
			changed(player)
			return true, `Challenge done: +{challenge.coins} coins, +{challenge.xp} XP`
		end
	end
	return false, "That isn't one of today's challenges."
end

function PlayerEconomy.claimLogin(player: Player): (boolean, string)
	local data = Profiles.get(player)
	if data == nil then
		return false, "Your profile is still loading."
	end
	local day = PlayerEconomy.today()
	if data.login.lastClaimDay == day then
		return false, "Today's reward is already claimed."
	end
	local streak = if data.login.lastClaimDay == day - 1 then data.login.streak + 1 else 1
	local index = (streak - 1) % #Economy.LOGIN_REWARDS + 1
	local coins = Economy.LOGIN_REWARDS[index] or 0
	data.login.lastClaimDay = day
	data.login.streak = streak
	data.stats.loginStreak = math.max(statOf(data, "loginStreak"), streak)
	giveCoins(data, coins)
	checkAchievements(player, data)
	changed(player)
	return true, `Day {streak} reward: +{coins} coins`
end

function PlayerEconomy.purchase(player: Player, itemId: string): (boolean, string)
	local data = Profiles.get(player)
	if data == nil then
		return false, "Your profile is still loading."
	end
	local item = Catalogue.get(itemId)
	if item == nil then
		return false, "That item doesn't exist."
	end
	if item.earned then
		return false, `This one is earned: {item.unlockText or "keep playing"}.`
	end
	if data.owned[itemId] == true then
		return false, "You already own that."
	end
	local level = PlayerEconomy.getLevel(data)
	if level < item.level then
		return false, `Reach level {item.level} to unlock {item.name}.`
	end
	local price = Catalogue.priceFor(item, PlayerEconomy.today())
	if data.coins < price then
		return false, `You need {price - data.coins} more coins.`
	end

	data.coins -= price
	data.lifetimeSpent += price
	giveItem(player, data, itemId, false)
	data.stats.purchases = statOf(data, "purchases") + 1
	checkAchievements(player, data)
	changed(player)
	return true, `Bought {item.name} for {price} coins`
end

function PlayerEconomy.equip(player: Player, itemId: string): (boolean, string)
	local data = Profiles.get(player)
	if data == nil then
		return false, "Your profile is still loading."
	end
	local item = Catalogue.get(itemId)
	if item == nil then
		return false, "That item doesn't exist."
	end
	local slot = slotFor(item)
	if slot == nil then
		return false, "That item is used automatically."
	end
	if data.owned[itemId] ~= true then
		return false, "You don't own that yet."
	end
	data.equipped[slot] = itemId
	changed(player)
	return true, `Equipped {item.name}`
end

function PlayerEconomy.unequip(player: Player, slot: string): (boolean, string)
	local data = Profiles.get(player)
	if data == nil then
		return false, "Your profile is still loading."
	end
	local known = false
	for _, name in ProfileTypes.EQUIP_SLOTS do
		if name == slot then
			known = true
		end
	end
	if not known then
		return false, "That slot doesn't exist."
	end
	data.equipped[slot] = ""
	changed(player)
	return true, "Removed"
end

function PlayerEconomy.setSetting(player: Player, key: string, value: boolean)
	local data = Profiles.get(player)
	if data == nil then
		return
	end
	if key == "sound" then
		data.settings.sound = value
	elseif key == "confetti" then
		data.settings.confetti = value
	elseif key == "hints" then
		data.settings.hints = value
	else
		return
	end
	changed(player)
end

-- Settles any level rewards that a crash might have left behind.
function PlayerEconomy.onProfileLoaded(player: Player, data: ProfileData)
	PlayerEconomy.ensureDaily(data)
	settleLevels(player, data)
	checkAchievements(player, data)
	changed(player)
end

-- Sent once, when the client first asks for its profile, so the message is not lost
-- before the client has started listening.
function PlayerEconomy.welcome(player: Player)
	local data = Profiles.get(player)
	if data == nil or data.welcomed then
		return
	end
	data.welcomed = true
	PlayerEconomy.notify(player, "info", `Welcome to Ink Masters! You start with {data.coins} coins.`)
	changed(player)
end

function PlayerEconomy.loginView(data: ProfileData): ProfileTypes.LoginView
	local day = PlayerEconomy.today()
	local canClaim = data.login.lastClaimDay ~= day
	local count = #Economy.LOGIN_REWARDS
	if canClaim then
		local nextStreak = if data.login.lastClaimDay == day - 1 then data.login.streak + 1 else 1
		local index = (nextStreak - 1) % count + 1
		return {
			streak = if nextStreak > 1 then nextStreak - 1 else 0,
			canClaim = true,
			dayInCycle = index,
			nextCoins = Economy.LOGIN_REWARDS[index] or 0,
		}
	end
	local index = (data.login.streak - 1) % count + 1
	local following = index % count + 1
	return {
		streak = data.login.streak,
		canClaim = false,
		dayInCycle = index,
		nextCoins = Economy.LOGIN_REWARDS[following] or 0,
	}
end

return PlayerEconomy
