--!strict

-- The one client copy of the player's profile. It is a read-only mirror of what the server sent.
-- Every change the player asks for goes to the server first and comes back as a new view.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local ProfileTypes = require(ReplicatedStorage.Shared.ProfileTypes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

type ProfileView = ProfileTypes.ProfileView

local current: ProfileView? = nil
local lastRevision = 0
local started = false
local receivedAt = 0

local changedEvent = Instance.new("BindableEvent")

local PlayerData = {}

PlayerData.changed = changedEvent.Event

function PlayerData.get(): ProfileView?
	return current
end

-- Seconds until the daily reset, counted down from when the view arrived.
function PlayerData.secondsToReset(): number
	local view = current
	if view == nil then
		return 0
	end
	return math.max(0, view.secondsToReset - (os.clock() - receivedAt))
end

function PlayerData.ownsInk(inkId: string): boolean
	local view = current
	if view == nil then
		return Catalogue.ownsInk({}, inkId)
	end
	return Catalogue.ownsInk(view.owned, inkId)
end

function PlayerData.ownsStencil(stencilId: string): boolean
	local view = current
	if view == nil then
		return Catalogue.ownsStencil({}, stencilId)
	end
	return Catalogue.ownsStencil(view.owned, stencilId)
end

function PlayerData.owns(itemId: string): boolean
	local view = current
	return view ~= nil and view.owned[itemId] == true
end

-- The cosmetic equipped in a slot, if any.
function PlayerData.equippedItem(slot: string): Catalogue.Item?
	local view = current
	if view == nil then
		return nil
	end
	local id: string? = view.equipped[slot]
	if id == nil or id == "" then
		return nil
	end
	return Catalogue.get(id)
end

function PlayerData.send(kind: string, id: string?, value: boolean?)
	Remotes.ProfileAction:FireServer({ kind = kind, id = id, value = value })
end

function PlayerData.start()
	if started then
		return
	end
	started = true
	Remotes.ProfileUpdated.OnClientEvent:Connect(function(payload: any)
		local view = ProfileTypes.readView(payload)
		if view == nil or view.revision <= lastRevision then
			return
		end
		lastRevision = view.revision
		current = view
		receivedAt = os.clock()
		changedEvent:Fire()
	end)
	-- The server pushes when the profile loads. Asking once covers a client that connected late.
	PlayerData.send("sync", nil, nil)
end

return PlayerData
