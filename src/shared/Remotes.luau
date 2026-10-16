--!strict

-- These events are created by default.project.json when Rojo syncs the place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TIMEOUT_SECONDS = 10
local SYNC_HINT = "Connect this place to Rojo, sync, and press Play again."

local function remoteEvent(parent: Instance, name: string): RemoteEvent
	local instance = parent:WaitForChild(name, TIMEOUT_SECONDS)
	if instance == nil or not instance:IsA("RemoteEvent") then
		error(`[InkMasters] ReplicatedStorage.Remotes.{name} is missing. {SYNC_HINT}`)
	end
	return instance
end

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", TIMEOUT_SECONDS)
if remotesFolder == nil then
	error(`[InkMasters] ReplicatedStorage.Remotes is missing. {SYNC_HINT}`)
end

local Remotes = {
	RoundStateUpdated = remoteEvent(remotesFolder, "RoundStateUpdated"),
	RequestRoundSnapshot = remoteEvent(remotesFolder, "RequestRoundSnapshot"),
}

return Remotes
