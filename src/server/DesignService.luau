--!strict

-- Stores the accepted tattoo for the current round. The client cannot award anything from this.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DesignDocument = require(ReplicatedStorage.Shared.DesignDocument)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundManager = require(script.Parent.RoundManager)

type TattooDesign = DesignDocument.TattooDesign

type StoredDesign = {
	roundId: number,
	design: TattooDesign,
}

local PREFIX = "[InkMasters]"
local SUBMIT_COOLDOWN_SECONDS = 0.25

local stored: { [Player]: StoredDesign } = {}
local lastSubmitAt: { [Player]: number } = {}

local DesignService = {}

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
		stored[player] = nil
		lastSubmitAt[player] = nil
	end)
end

return DesignService
