--!strict

-- Loads and saves each player's profile.
-- A short lock on the saved record stops two servers from writing the same profile at once.
-- If the data store cannot be reached the player still plays, but that session is marked
-- as not saved and never writes, so an outage cannot overwrite real progress.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileTypes = require(ReplicatedStorage.Shared.ProfileTypes)

type ProfileData = ProfileTypes.ProfileData

type Session = {
	data: ProfileData,
	persistent: boolean,
	dirty: boolean,
	changes: number,
	lastSave: number,
	saving: boolean,
	saveQueued: boolean,
}

local PREFIX = "[InkMasters]"
local STORE_NAME = "InkMastersProfiles1"
local LOCK_SECONDS = 120
local AUTOSAVE_SECONDS = 60
local MIN_SAVE_GAP_SECONDS = 8
local LOAD_ATTEMPTS = 3
local SHUTDOWN_WAIT_SECONDS = 25

local isStudio = RunService:IsStudio()
local sessionId = HttpService:GenerateGUID(false)
local sessions: { [Player]: Session } = {}
local closing: { [number]: boolean } = {}
local loadedCallbacks: { (Player, ProfileData) -> () } = {}
local warnedUnsaved = false

local storeOk, storeOrError = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
local store: DataStore? = if storeOk then storeOrError else nil

local Profiles = {}

local function keyFor(userId: number): string
	return `Player_{userId}`
end

local function copyValue(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = copyValue(item)
	end
	return result
end

local function lockedByOther(record: any): boolean
	if isStudio then
		return false
	end
	local lock = record.lock
	if typeof(lock) ~= "table" then
		return false
	end
	return lock.session ~= sessionId and typeof(lock.t) == "number" and (os.time() - lock.t) < LOCK_SECONDS
end

local function warnUnsaved(reason: string)
	if warnedUnsaved then
		return
	end
	warnedUnsaved = true
	warn(
		`{PREFIX} Progress will NOT be saved this session ({reason}). `
			.. "In Studio: publish the place, then turn on Game Settings > Security > Enable Studio Access to API Services."
	)
end

-- Returns "ok", "locked", or "failed" along with the saved record when there is one.
local function loadRecord(userId: number): (string, any)
	local currentStore = store
	if currentStore == nil then
		return "failed", "no data store"
	end
	local reason = "failed"
	for attempt = 1, LOAD_ATTEMPTS do
		local ok, result = pcall(function()
			return currentStore:UpdateAsync(keyFor(userId), function(old: any)
				local record: any = if typeof(old) == "table" then old else {}
				if lockedByOther(record) then
					return nil
				end
				record.lock = { session = sessionId, t = os.time() }
				return record
			end)
		end)
		if ok then
			if typeof(result) == "table" and typeof(result.lock) == "table" and result.lock.session == sessionId then
				return "ok", result
			end
			reason = "locked"
		else
			reason = "failed"
			warn(`{PREFIX} Profile load failed for {userId}: {tostring(result)}`)
		end
		if attempt < LOAD_ATTEMPTS then
			task.wait(2 * attempt)
		end
	end
	return reason, nil
end

local function writeRecord(userId: number, data: any, release: boolean): boolean
	local currentStore = store
	if currentStore == nil then
		return false
	end
	local lost = false
	local ok, err = pcall(function()
		currentStore:UpdateAsync(keyFor(userId), function(old: any)
			local record: any = if typeof(old) == "table" then old else {}
			if lockedByOther(record) then
				lost = true
				return nil
			end
			record.data = data
			if release then
				record.lock = nil
			else
				record.lock = { session = sessionId, t = os.time() }
			end
			return record
		end)
	end)
	if not ok then
		warn(`{PREFIX} Profile save failed for {userId}: {tostring(err)}`)
		return false
	end
	if lost then
		warn(`{PREFIX} Profile for {userId} is owned by another server. This save was skipped.`)
		return false
	end
	return true
end

local function saveSession(userId: number, session: Session, release: boolean)
	if not session.persistent then
		return
	end
	local waited = 0
	while session.saving and waited < 100 do
		task.wait(0.1)
		waited += 1
	end
	if session.saving then
		return
	end
	session.saving = true
	local captured = session.changes
	local ok = writeRecord(userId, copyValue(session.data), release)
	session.saving = false
	if ok then
		session.lastSave = os.clock()
		if session.changes == captured then
			session.dirty = false
		end
	end
end

local function queueSave(player: Player, session: Session)
	if not session.persistent or session.saveQueued then
		return
	end
	session.saveQueued = true
	local wait = math.max(0, MIN_SAVE_GAP_SECONDS - (os.clock() - session.lastSave))
	task.delay(wait, function()
		session.saveQueued = false
		if sessions[player] == session and session.dirty then
			saveSession(player.UserId, session, false)
		end
	end)
end

local function onPlayerAdded(player: Player)
	-- A quick rejoin must not read the record before the last save has landed.
	local waited = 0
	while closing[player.UserId] == true and waited < 100 do
		task.wait(0.1)
		waited += 1
	end
	local state, record = loadRecord(player.UserId)
	if player.Parent ~= Players then
		if state == "ok" and store ~= nil then
			writeRecord(player.UserId, if typeof(record.data) == "table" then record.data else nil, true)
		end
		return
	end

	if state == "locked" then
		player:Kick("Your save is still closing on another server. Please rejoin in a minute.")
		return
	end

	local persistent = state == "ok"
	local data = ProfileTypes.new()
	if persistent then
		data = ProfileTypes.reconcile(record.data)
	else
		warnUnsaved("data store unavailable")
	end

	local session: Session = {
		data = data,
		persistent = persistent,
		dirty = false,
		changes = 0,
		lastSave = os.clock(),
		saving = false,
		saveQueued = false,
	}
	sessions[player] = session
	print(`{PREFIX} Profile ready | {player.Name} | {data.coins} coins | saved: {persistent}`)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	sessions[player] = nil
	closing[player.UserId] = true
	saveSession(player.UserId, session, true)
	closing[player.UserId] = nil
end

function Profiles.get(player: Player): ProfileData?
	local session = sessions[player]
	if session == nil then
		return nil
	end
	return session.data
end

function Profiles.isPersistent(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.persistent
end

function Profiles.markDirty(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	session.changes += 1
	session.dirty = true
	queueSave(player, session)
end

function Profiles.onLoaded(callback: (Player, ProfileData) -> ())
	table.insert(loadedCallbacks, callback)
end

function Profiles.start()
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		task.spawn(onPlayerRemoving, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Every minute, write changes and refresh the lock on live sessions.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, session in sessions do
				if session.persistent and not session.saving then
					task.spawn(saveSession, player.UserId, session, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, session in sessions do
			if session.persistent then
				pending += 1
				local userId = player.UserId
				task.spawn(function()
					saveSession(userId, session, true)
					pending -= 1
				end)
			end
		end
		sessions = {}
		local waited = 0
		while pending > 0 and waited < SHUTDOWN_WAIT_SECONDS do
			task.wait(0.25)
			waited += 0.25
		end
	end)
end

return Profiles
