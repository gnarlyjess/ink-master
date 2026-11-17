--!strict

-- Prep station: pick a limb, soap dirt, wipe, shave. Leftovers carry into tattoo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BodyRegions = require(ReplicatedStorage.Shared.BodyRegions)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PrepTypes = require(ReplicatedStorage.Shared.PrepTypes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundManager = require(script.Parent.RoundManager)

type DirtPatch = PrepTypes.DirtPatch
type PrepTool = PrepTypes.PrepTool
type PrepView = PrepTypes.PrepView

type Session = {
	regionId: string,
	tool: PrepTool,
	dirt: { DirtPatch },
	hair: { number },
	locked: boolean, -- region locked once they start stroking
}

local PREFIX = "[InkRivalry]"
local COOLDOWN = 0.07

local sessions: { [Player]: Session } = {}
local lastStrokeAt: { [Player]: number } = {}

local PrepService = {}

local function push(player: Player)
	local session = sessions[player]
	if session == nil or player.Parent ~= Players then
		return
	end
	local step = PrepTypes.currentStep(session.dirt, session.hair)
	local view: PrepView = {
		regionId = session.regionId,
		tool = session.tool,
		step = step,
		dirt = session.dirt,
		hair = session.hair,
		hairCols = PrepTypes.HAIR_COLS,
		hairRows = PrepTypes.HAIR_ROWS,
		dirtyLeft = PrepTypes.countDirtLeft(session.dirt),
		hairLeft = PrepTypes.countHairLeft(session.hair),
	}
	Remotes.PrepStateUpdated:FireClient(player, view)
end

local function ensure(player: Player): Session
	local existing = sessions[player]
	if existing ~= nil then
		return existing
	end
	local regionId = GameConfig.getDesignRegion()
	local session: Session = {
		regionId = regionId,
		tool = "soap",
		dirt = PrepTypes.makeDirt(player.UserId, regionId),
		hair = PrepTypes.makeHair(player.UserId, regionId),
		locked = false,
	}
	sessions[player] = session
	return session
end

local function resetRegion(session: Session, player: Player, regionId: string)
	session.regionId = regionId
	session.dirt = PrepTypes.makeDirt(player.UserId, regionId)
	session.hair = PrepTypes.makeHair(player.UserId, regionId)
	session.tool = "soap"
	session.locked = false
end

function PrepService.getLockedRegion(player: Player): string?
	local session = sessions[player]
	if session == nil then
		return nil
	end
	return session.regionId
end

function PrepService.getResidue(player: Player): PrepView?
	local session = sessions[player]
	if session == nil then
		return nil
	end
	return {
		regionId = session.regionId,
		tool = session.tool,
		step = PrepTypes.currentStep(session.dirt, session.hair),
		dirt = session.dirt,
		hair = session.hair,
		hairCols = PrepTypes.HAIR_COLS,
		hairRows = PrepTypes.HAIR_ROWS,
		dirtyLeft = PrepTypes.countDirtLeft(session.dirt),
		hairLeft = PrepTypes.countHairLeft(session.hair),
	}
end

function PrepService.clearPlayer(player: Player)
	sessions[player] = nil
	lastStrokeAt[player] = nil
end

function PrepService.clearAll()
	table.clear(sessions)
	table.clear(lastStrokeAt)
end

local function onAction(player: Player, payload: any)
	if typeof(payload) ~= "table" or typeof(payload.kind) ~= "string" then
		return
	end
	if not RoundManager.isLimbPrepOpen() then
		return
	end

	local session = ensure(player)
	local kind = payload.kind

	if kind == "sync" then
		push(player)
		return
	end

	if kind == "pickRegion" then
		local regionId = payload.regionId
		if typeof(regionId) ~= "string" or BodyRegions.get(regionId) == nil then
			return
		end
		if session.locked and regionId ~= session.regionId then
			return
		end
		if regionId ~= session.regionId then
			resetRegion(session, player, regionId)
		end
		push(player)
		return
	end

	if kind == "selectTool" then
		local tool = payload.tool
		if tool ~= "soap" and tool ~= "cloth" and tool ~= "razor" then
			return
		end
		-- Always allow picking any tool; stroke handlers still gate what each tool does.
		session.tool = tool
		push(player)
		return
	end

	if kind == "stroke" then
		local now = os.clock()
		local previous = lastStrokeAt[player]
		if previous ~= nil and (now - previous) < COOLDOWN then
			return
		end
		lastStrokeAt[player] = now

		local x = payload.x
		local y = payload.y
		if typeof(x) ~= "number" or typeof(y) ~= "number" then
			return
		end
		x = math.clamp(x, 0, 1)
		y = math.clamp(y, 0, 1)
		session.locked = true

		local tool = session.tool
		local changed = false
		if tool == "soap" then
			local hits = PrepTypes.hitDirt(session.dirt, x, y, PrepTypes.SOAP_RADIUS)
			for _, patch in hits do
				if not patch.soaped then
					patch.soaped = true
					changed = true
				end
			end
		elseif tool == "cloth" then
			local hits = PrepTypes.hitDirt(session.dirt, x, y, PrepTypes.CLOTH_RADIUS)
			for _, patch in hits do
				if patch.soaped and not patch.cleared then
					patch.cleared = true
					changed = true
				end
			end
		elseif tool == "razor" then
			-- Razor is free anytime — dirt soap→wipe is the only ordered rule.
			local shaved = PrepTypes.shaveAt(session.hair, x, y, PrepTypes.RAZOR_RADIUS)
			if shaved > 0 then
				changed = true
			end
		end

		if changed then
			push(player)
		end
		return
	end
end

function PrepService.start()
	Remotes.PrepAction.OnServerEvent:Connect(onAction)
	Players.PlayerRemoving:Connect(function(player: Player)
		PrepService.clearPlayer(player)
	end)

	RoundManager.setPrepare(function(state)
		if state == "WaitingForPlayers" then
			PrepService.clearAll()
		elseif state == "LimbPrep" then
			-- Fresh dirt/hair each prep phase (limb masks + sparse stubble).
			PrepService.clearAll()
			for _, player in RoundManager.getContestants() do
				ensure(player)
				push(player)
			end
			print(`{PREFIX} Prep station open`)
		end
		return nil
	end)
end

return PrepService
