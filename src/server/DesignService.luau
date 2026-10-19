--!strict

-- Stores the accepted tattoo for the current round. The client cannot award anything from this.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local DesignDocument = require(ReplicatedStorage.Shared.DesignDocument)
local InkColors = require(ReplicatedStorage.Shared.InkColors)
local Profiles = require(script.Parent.Profiles)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundManager = require(script.Parent.RoundManager)

type TattooDesign = DesignDocument.TattooDesign

type StoredDesign = {
	roundId: number,
	design: TattooDesign,
}

export type LockedDesign = {
	userId: number,
	name: string,
	design: TattooDesign,
}

type Person = {
	userId: number,
	name: string,
}

local PREFIX = "[InkMasters]"
local SUBMIT_COOLDOWN_SECONDS = 0.25

local stored: { [Player]: StoredDesign } = {}
local lastSubmitAt: { [Player]: number } = {}
local people: { Person } = {}
local locked: { LockedDesign } = {}
local capturedRound = 0
local lockedRound = 0

local DesignService = {}

local function shortName(name: string): string
	if #name > 24 then
		return string.sub(name, 1, 24)
	end
	return name
end

local function designFor(userId: number, roundId: number): TattooDesign?
	local found: TattooDesign? = nil
	for player, entry in stored do
		if player.UserId == userId and entry.roundId == roundId then
			found = entry.design
			if player.Parent == Players then
				return entry.design
			end
		end
	end
	return found
end

function DesignService.capture(roundId: number, players: { Player })
	if capturedRound == roundId then
		return
	end
	capturedRound = roundId
	table.clear(people)
	local seen: { [number]: boolean } = {}
	for _, player in players do
		seen[player.UserId] = true
		table.insert(people, {
			userId = player.UserId,
			name = shortName(player.Name),
		})
	end
	for player, entry in stored do
		if entry.roundId == roundId and seen[player.UserId] ~= true then
			seen[player.UserId] = true
			table.insert(people, {
				userId = player.UserId,
				name = shortName(player.Name),
			})
		end
	end
end

function DesignService.lock(roundId: number)
	if lockedRound == roundId then
		return
	end
	lockedRound = roundId
	table.clear(locked)
	for _, person in people do
		local saved = designFor(person.userId, roundId)
		local design = if saved ~= nil then saved else DesignDocument.createEmpty()
		table.insert(locked, {
			userId = person.userId,
			name = person.name,
			design = design,
		})
	end
	print(`{PREFIX} Display case locked | {#locked} tattoos`)
end

function DesignService.getLocked(): { LockedDesign }
	return locked
end

function DesignService.clearRound()
	table.clear(stored)
	table.clear(people)
	table.clear(locked)
	capturedRound = 0
	lockedRound = 0
end

function DesignService.getDesign(player: Player): TattooDesign?
	local entry = stored[player]
	if entry == nil or entry.roundId ~= RoundManager.getRoundId() then
		return nil
	end
	return entry.design
end

local function sendResult(player: Player, ok: boolean, reason: string, elementCount: number)
	if player.Parent ~= Players then
		return
	end
	Remotes.DesignResult:FireClient(player, {
		ok = ok,
		reason = reason,
		elementCount = elementCount,
	})
end

-- Premium shapes and inks only count when the player owns them.
local function usesLockedContent(player: Player, design: TattooDesign): boolean
	local data = Profiles.get(player)
	local owned: { [string]: boolean } = if data ~= nil then data.owned else {}
	for _, element in design.elements do
		if not Catalogue.ownsStencil(owned, element.stencilId) then
			return true
		end
		for _, color in { element.color, element.line } do
			local inkId = InkColors.matchId(color)
			if inkId == nil or not Catalogue.ownsInk(owned, inkId) then
				return true
			end
		end
	end
	return false
end

local function onSubmit(player: Player, payload: any)
	local now = os.clock()
	local previous = lastSubmitAt[player]
	if previous ~= nil and (now - previous) < SUBMIT_COOLDOWN_SECONDS then
		return
	end
	lastSubmitAt[player] = now

	if not RoundManager.isDesignWindowOpen() then
		sendResult(player, false, "The design window is closed.", 0)
		return
	end

	local design = DesignDocument.sanitize(payload, RoundManager.getRoundId())
	if design == nil then
		warn(`{PREFIX} Rejected design from {player.Name}`)
		sendResult(player, false, "That design didn't pass the studio check.", 0)
		return
	end

	if usesLockedContent(player, design) then
		warn(`{PREFIX} Rejected design from {player.Name}: locked content`)
		sendResult(player, false, "That design uses a shape or ink you haven't unlocked.", 0)
		return
	end

	stored[player] = {
		roundId = RoundManager.getRoundId(),
		design = design,
	}
	print(`{PREFIX} Accepted design from {player.Name} | {#design.elements} marks | {design.region}`)
	sendResult(player, true, "Saved", #design.elements)
end

function DesignService.start()
	Remotes.SubmitDesign.OnServerEvent:Connect(onSubmit)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastSubmitAt[player] = nil
	end)
end

return DesignService
