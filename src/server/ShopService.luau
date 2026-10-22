--!strict

-- Handles shop, claim, and settings requests, and keeps each player's view up to date.
-- The client asks. The server checks, changes the profile, and sends the result back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NameTags = require(script.Parent.NameTags)
local PlayerEconomy = require(script.Parent.PlayerEconomy)
local Profiles = require(script.Parent.Profiles)
local RoundManager = require(script.Parent.RoundManager)

local PREFIX = "[InkMasters]"
local ACTION_COOLDOWN_SECONDS = 0.2

local revisions: { [Player]: number } = {}
local pending: { [Player]: boolean } = {}
local lastAction: { [Player]: number } = {}
local synced: { [Player]: boolean } = {}

local ShopService = {}

local function buildView(player: Player): { [string]: any }?
	local data = Profiles.get(player)
	if data == nil then
		return nil
	end
	PlayerEconomy.ensureDaily(data)
	local info = Economy.levelInfo(data.xp)
	local day = PlayerEconomy.today()

	local challenges = {}
	for _, challenge in Quests.dailyFor(data.daily.day) do
		local progress: number? = data.daily.progress[challenge.id]
		table.insert(challenges, {
			id = challenge.id,
			text = challenge.text,
			progress = progress or 0,
			target = challenge.target,
			coins = challenge.coins,
			xp = challenge.xp,
			claimed = data.daily.claimed[challenge.id] == true,
		})
	end

	local revision = (revisions[player] or 0) + 1
	revisions[player] = revision
	return {
		revision = revision,
		coins = data.coins,
		xp = data.xp,
		level = info.level,
		levelInto = info.into,
		levelNeed = info.need,
		maxed = info.maxed,
		rewardedLevel = data.rewardedLevel,
		lifetimeEarned = data.lifetimeEarned,
		owned = data.owned,
		equipped = data.equipped,
		stats = data.stats,
		achievements = data.achievements,
		challenges = challenges,
		login = PlayerEconomy.loginView(data),
		featuredId = Catalogue.featuredId(day),
		day = day,
		secondsToReset = Economy.secondsToReset(os.time()),
		settings = data.settings,
		persistent = Profiles.isPersistent(player),
	}
end

local function sendNow(player: Player)
	if player.Parent ~= Players then
		return
	end
	local view = buildView(player)
	if view ~= nil then
		Remotes.ProfileUpdated:FireClient(player, view)
	end
end

-- Several changes in one moment (a round payout) go out as one update.
local function push(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(function()
		pending[player] = nil
		sendNow(player)
	end)
end

local function readText(value: any): string?
	if typeof(value) ~= "string" or value == "" or #value > 48 then
		return nil
	end
	return value
end

local function onAction(player: Player, payload: any)
	local now = os.clock()
	local previous = lastAction[player]
	if previous ~= nil and (now - previous) < ACTION_COOLDOWN_SECONDS then
		return
	end
	lastAction[player] = now

	if typeof(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if typeof(kind) ~= "string" then
		return
	end

	if kind == "sync" then
		synced[player] = true
		sendNow(player)
		PlayerEconomy.welcome(player)
		return
	end

	local ok = true
	local message = ""
	if kind == "buy" then
		local id = readText(payload.id)
		if id == nil then
			return
		end
		ok, message = PlayerEconomy.purchase(player, id)
		if ok then
			print(`{PREFIX} Purchase | {player.Name} | {id}`)
		end
	elseif kind == "equip" then
		local id = readText(payload.id)
		if id == nil then
			return
		end
		ok, message = PlayerEconomy.equip(player, id)
	elseif kind == "unequip" then
		local slot = readText(payload.id)
		if slot == nil then
			return
		end
		ok, message = PlayerEconomy.unequip(player, slot)
	elseif kind == "claimLogin" then
		ok, message = PlayerEconomy.claimLogin(player)
	elseif kind == "claimChallenge" then
		local id = readText(payload.id)
		if id == nil then
			return
		end
		ok, message = PlayerEconomy.claimChallenge(player, id)
	elseif kind == "setting" then
		local key = readText(payload.id)
		if key == nil or typeof(payload.value) ~= "boolean" then
			return
		end
		PlayerEconomy.setSetting(player, key, payload.value)
		return
	elseif kind == "buyThemePick" then
		local text: string? = nil
		if typeof(payload.id) == "string" then
			text = payload.id
		end
		local ThemeQueue = require(script.Parent.ThemeQueue)
		if ThemeQueue.hasClaim(player) then
			ok, message = PlayerEconomy.setThemePickText(player, text)
		elseif not RoundManager.canBuyThemePick() then
			ok, message = false, "Theme picks are only sold while the lobby is waiting."
		else
			ok, message = PlayerEconomy.buyThemePick(player, text)
			if ok then
				print(`{PREFIX} Theme pick | {player.Name}`)
			end
		end
	elseif kind == "setThemePick" then
		local text: string? = nil
		if typeof(payload.id) == "string" then
			text = payload.id
		end
		ok, message = PlayerEconomy.setThemePickText(player, text)
	else
		return
	end

	-- claimLogin already fires a "login" fanfare notice on success.
	if not (kind == "claimLogin" and ok) then
		PlayerEconomy.notify(player, if ok then "ok" else "error", message)
	end
	if not ok then
		-- Re-send so a stale screen corrects itself.
		push(player)
	end
end

-- Milestone and achievement rewards must point at real, earned catalogue items.
local function validateRewards()
	for level = 1, Economy.MAX_LEVEL do
		local itemId = Economy.levelReward(level).itemId
		if itemId ~= nil then
			local item = Catalogue.get(itemId)
			if item == nil or not item.earned then
				error(`[InkMasters] Level {level} reward {itemId} is not an earned catalogue item`)
			end
		end
	end
	for _, achievement in Quests.achievements do
		if achievement.itemId ~= nil and Catalogue.get(achievement.itemId) == nil then
			error(`[InkMasters] Achievement {achievement.id} rewards a missing item`)
		end
	end
end

function ShopService.start()
	validateRewards()
	NameTags.start()
	Profiles.onLoaded(function(player: Player, data)
		PlayerEconomy.onProfileLoaded(player, data)
		if synced[player] == true then
			PlayerEconomy.welcome(player)
		end
	end)
	PlayerEconomy.onChanged(function(player: Player)
		push(player)
		NameTags.refresh(player)
	end)
	Remotes.ProfileAction.OnServerEvent:Connect(onAction)
	Players.PlayerRemoving:Connect(function(player: Player)
		PlayerEconomy.refundThemePickOnLeave(player)
		revisions[player] = nil
		pending[player] = nil
		lastAction[player] = nil
		synced[player] = nil
	end)
end

return ShopService
