--!strict

-- Stockroom blueprint scavenger hunt. Clears are personal; a full set grants
-- +tattoo seconds for that design round only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundManager = require(script.Parent.RoundManager)
local Lobby = require(script.Parent.Lobby)
local Stockroom = require(script.Parent.Stockroom)

type Progress = {
	found: { [number]: boolean },
	count: number,
	complete: boolean,
	returned: boolean,
}

local PREFIX = "[InkRivalry]"
local HUNT_ATTR = "BlueprintHunting"

local progress: { [Player]: Progress } = {}
local bonusEarned: { [Player]: boolean } = {}
local promptsWired = false

local BlueprintService = {}

local function pieceCount(): number
	return GameConfig.getBlueprintPieceCount()
end

local function pushState(player: Player, picked: number?)
	if player.Parent ~= Players then
		return
	end
	local entry = progress[player]
	local found = if entry ~= nil then entry.count else 0
	local complete = entry ~= nil and entry.complete
	local hasBonus = bonusEarned[player] == true
	Remotes.BlueprintStateUpdated:FireClient(player, {
		found = found,
		total = pieceCount(),
		complete = complete,
		bonusSeconds = if hasBonus then GameConfig.getBlueprintBonusSeconds() else 0,
		hunting = player:GetAttribute(HUNT_ATTR) == true,
		picked = picked,
	})
end

local function ensure(player: Player): Progress
	local entry = progress[player]
	if entry ~= nil then
		return entry
	end
	entry = {
		found = {},
		count = 0,
		complete = false,
		returned = false,
	}
	progress[player] = entry
	return entry
end

local function setHunting(player: Player, hunting: boolean)
	player:SetAttribute(HUNT_ATTR, hunting)
end

local function allReturned(): boolean
	local contestants = RoundManager.getContestants()
	if #contestants == 0 then
		return false
	end
	for _, player in contestants do
		local entry = progress[player]
		if entry == nil or entry.returned ~= true then
			return false
		end
	end
	return true
end

local function returnPlayer(player: Player)
	local entry = progress[player]
	if entry ~= nil then
		entry.returned = true
	end
	setHunting(player, false)
	Lobby.returnPlayer(player)
	pushState(player)
	-- Everyone back in the parlour → theme drop without waiting out the hunt clock.
	if RoundManager.getState() == "BlueprintHunt" and allReturned() then
		print(`{PREFIX} Stockroom clear — all artists returned`)
		RoundManager.advanceNow()
	end
end

local function onCollected(player: Player, index: number)
	if RoundManager.getState() ~= "BlueprintHunt" then
		return
	end
	if player:GetAttribute(HUNT_ATTR) ~= true then
		return
	end
	if index < 1 or index > pieceCount() then
		return
	end

	local entry = ensure(player)
	if entry.complete or entry.found[index] then
		return
	end

	entry.found[index] = true
	entry.count += 1
	print(`{PREFIX} Blueprint {index}/{pieceCount()} | {player.Name}`)

	if entry.count < pieceCount() then
		pushState(player, index)
		return
	end

	-- One payload for the final sheet — client shows the machine-built popup from this.
	entry.complete = true
	bonusEarned[player] = true
	Remotes.BlueprintStateUpdated:FireClient(player, {
		found = entry.count,
		total = pieceCount(),
		complete = true,
		bonusSeconds = GameConfig.getBlueprintBonusSeconds(),
		hunting = true,
		congrats = true,
		picked = index,
	})
	-- Hold in the stockroom so the ~5s congrats card can play, then lobby wait.
	task.delay(5.5, function()
		if player.Parent ~= Players then
			return
		end
		if RoundManager.getState() ~= "BlueprintHunt" then
			return
		end
		returnPlayer(player)
	end)
end

local function wirePrompts()
	if promptsWired then
		return
	end
	promptsWired = true
	for _, part in Stockroom.getBlueprints() do
		local prompt = part:FindFirstChild("Collect", true)
		if prompt == nil or not prompt:IsA("ProximityPrompt") then
			continue
		end
		local index = part:GetAttribute("BlueprintIndex")
		if typeof(index) ~= "number" then
			continue
		end
		prompt.Triggered:Connect(function(player: Player)
			onCollected(player, math.floor(index))
		end)
	end
end

local function clearHuntProgress()
	table.clear(progress)
	for _, player in Players:GetPlayers() do
		setHunting(player, false)
	end
end

local function resetMatch()
	clearHuntProgress()
	table.clear(bonusEarned)
end

local function beginHunt()
	-- One hunt per match — wipe prior bonuses, then reshuffle nests.
	resetMatch()
	Stockroom.reshuffleBlueprints(RoundManager.getRoundId(), RoundManager.getDesignRound())
	wirePrompts()
	local contestants = RoundManager.getContestants()
	for i, player in contestants do
		ensure(player)
		setHunting(player, true)
		Stockroom.seatPlayer(player, i)
		pushState(player)
	end
	print(`{PREFIX} Stockroom hunt | {#contestants} artists | {pieceCount()} blueprints`)
end

local function endHunt()
	-- Hunt over — everyone back in the parlour for the theme beat.
	for _, player in RoundManager.getContestants() do
		local entry = progress[player]
		if entry ~= nil then
			entry.returned = true
		end
		setHunting(player, false)
		pushState(player)
	end
	Lobby.returnToShop()
end

function BlueprintService.hasBonus(player: Player): boolean
	return bonusEarned[player] == true
end

function BlueprintService.anyHasBonus(): boolean
	for _, player in RoundManager.getContestants() do
		if bonusEarned[player] == true then
			return true
		end
	end
	return false
end

function BlueprintService.start()
	Stockroom.build()
	RoundManager.setBlueprintBonusQuery(BlueprintService.hasBonus)

	Players.PlayerRemoving:Connect(function(player: Player)
		progress[player] = nil
		bonusEarned[player] = nil
		player:SetAttribute(HUNT_ATTR, nil)
		task.defer(function()
			if RoundManager.getState() == "BlueprintHunt" and allReturned() then
				print(`{PREFIX} Stockroom clear — remaining artists returned`)
				RoundManager.advanceNow()
			end
		end)
	end)

	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			if RoundManager.getState() ~= "BlueprintHunt" then
				return
			end
			if player:GetAttribute(HUNT_ATTR) ~= true then
				return
			end
			-- Lobby spawn watchers can seat into the shop; put hunters back.
			task.defer(function()
				if RoundManager.getState() == "BlueprintHunt" and player:GetAttribute(HUNT_ATTR) == true then
					Stockroom.seatPlayer(player, math.max(1, player.UserId % 5))
				end
			end)
		end)
	end
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
	Players.PlayerAdded:Connect(watchCharacter)

	RoundManager.setPrepare(function(state)
		if state == "WaitingForPlayers" then
			resetMatch()
			return nil
		end
		if state == "Cleanup" then
			-- Between design rounds: keep match bonuses, just clear hunt flags.
			clearHuntProgress()
			return nil
		end
		if state == "BlueprintHunt" then
			beginHunt()
			return nil
		end
		if state == "ThemeReveal" then
			endHunt()
			return nil
		end
		if state == "TattooCreation" then
			-- Clear-set bonus applies to every tattoo round in this match.
			local base = GameConfig.getCreationSeconds(RoundManager.getDesignRound())
			local extra = if BlueprintService.anyHasBonus() then GameConfig.getBlueprintBonusSeconds() else 0
			if extra > 0 then
				print(`{PREFIX} Tattoo window +{extra}s headroom for blueprint clears`)
			end
			return base + extra
		end
		return nil
	end)
end

return BlueprintService
