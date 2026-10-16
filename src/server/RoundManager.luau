--!strict

-- Server-owned round clock.
-- Only this module changes the round state. Clients receive snapshots and render them.
-- scheduleToken cancels a pending transition when a round is aborted or replaced.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundTypes = require(ReplicatedStorage.Shared.RoundTypes)
local Themes = require(ReplicatedStorage.Shared.Themes)

type RoundState = RoundTypes.RoundState
type RoundSnapshot = RoundTypes.RoundSnapshot
type ThemeDefinition = Themes.ThemeDefinition

local PREFIX = "[InkMasters]"
local REQUEST_COOLDOWN_SECONDS = 0.5

local stateRemote = Remotes.RoundStateUpdated
local requestRemote = Remotes.RequestRoundSnapshot
local pauseRemote = Remotes.DevSetPaused

local scheduleToken = 0
local revision = 0
local roundId = 0
local inRound = false
local announcedWaiting = false
local paused = GameConfig.devHoldsLobby()
local currentState: RoundState = "WaitingForPlayers"
local endsAt: number? = nil
local currentDuration: number? = nil
local activeTheme: ThemeDefinition? = nil
local joinedPlayers: { [Player]: boolean } = {}
local lastRequestAt: { [Player]: number } = {}

local machine = {}

local function countPlayers(): number
	local count = 0
	for _ in joinedPlayers do
		count += 1
	end
	return count
end

function machine.broadcast(target: Player?)
	revision += 1

	local showTheme = RoundTypes.showsTheme(currentState)
	local themeId: string? = nil
	local themeName: string? = nil
	local themeTagline: string? = nil
	if showTheme and activeTheme ~= nil then
		themeId = activeTheme.id
		themeName = activeTheme.name
		themeTagline = activeTheme.tagline
	end

	local snapshot: RoundSnapshot = {
		revision = revision,
		roundId = roundId,
		state = currentState,
		endsAt = endsAt,
		duration = currentDuration,
		playerCount = countPlayers(),
		minPlayers = GameConfig.getMinPlayers(),
		maxPlayers = GameConfig.getMaxPlayers(),
		devMode = GameConfig.DevMode,
		paused = paused,
		showTheme = showTheme,
		themeId = themeId,
		themeName = themeName,
		themeTagline = themeTagline,
	}

	if target ~= nil then
		if target.Parent == Players then
			stateRemote:FireClient(target, snapshot)
		end
		return
	end

	stateRemote:FireAllClients(snapshot)
end

function machine.logState(state: RoundState, stateDuration: number)
	local themeNote = ""
	if activeTheme ~= nil and RoundTypes.showsTheme(state) then
		themeNote = ` | {activeTheme.name}`
	end
	print(
		`{PREFIX} Round {roundId} → {RoundTypes.getLabel(state)} ({state}){themeNote} | players {countPlayers()} | {string.format(
			"%.1f",
			stateDuration
		)}s`
	)
end

function machine.publishWaiting()
	local alreadyWaiting = announcedWaiting and currentState == "WaitingForPlayers" and not inRound
	scheduleToken += 1
	inRound = false
	currentState = "WaitingForPlayers"
	endsAt = nil
	currentDuration = nil
	activeTheme = nil
	announcedWaiting = true
	machine.broadcast(nil)
	if not alreadyWaiting then
		print(`{PREFIX} Waiting for players | {countPlayers()}/{GameConfig.getMinPlayers()} to start`)
	end
end

function machine.transitionTo(state: RoundState)
	local stateDuration = GameConfig.getDuration(state)
	if stateDuration == nil or stateDuration <= 0 then
		warn(`{PREFIX} No positive timer for {state}. Returning to the lobby.`)
		inRound = false
		machine.publishWaiting()
		return
	end

	scheduleToken += 1
	local token = scheduleToken
	currentState = state
	if state == "ThemeReveal" and activeTheme == nil then
		activeTheme = Themes.pickRandom()
	end
	currentDuration = stateDuration
	endsAt = Workspace:GetServerTimeNow() + stateDuration

	task.delay(stateDuration, function()
		if token ~= scheduleToken or currentState ~= state or not inRound or paused then
			return
		end
		machine.advance()
	end)

	machine.broadcast(nil)
	machine.logState(state, stateDuration)
end

function machine.beginRound()
	if paused or inRound then
		return
	end
	if countPlayers() < GameConfig.getMinPlayers() then
		return
	end

	inRound = true
	announcedWaiting = false
	roundId += 1
	activeTheme = nil
	machine.transitionTo("Intermission")
end

function machine.completeRound()
	inRound = false
	if countPlayers() >= GameConfig.getMinPlayers() then
		machine.beginRound()
	else
		machine.publishWaiting()
	end
end

function machine.advance()
	if paused or not inRound then
		return
	end

	local nextState = RoundTypes.nextInRound(currentState)
	if nextState == nil then
		if currentState ~= "Cleanup" then
			warn(`{PREFIX} Stopped at {currentState} because that state has no next step`)
			inRound = false
			machine.publishWaiting()
			return
		end
		machine.completeRound()
		return
	end

	machine.transitionTo(nextState :: RoundState)
end

function machine.refresh()
	local count = countPlayers()
	if count <= 0 then
		machine.publishWaiting()
		return
	end
	if paused then
		if inRound then
			machine.broadcast(nil)
		else
			machine.publishWaiting()
		end
		return
	end
	if inRound then
		machine.broadcast(nil)
		return
	end
	if count >= GameConfig.getMinPlayers() then
		machine.beginRound()
		return
	end
	machine.publishWaiting()
end

function machine.setPaused(want: boolean)
	if not GameConfig.DevMode or paused == want then
		return
	end

	paused = want
	scheduleToken += 1
	if paused then
		endsAt = nil
		currentDuration = nil
		machine.broadcast(nil)
		print(`{PREFIX} Dev pause on | lobby held`)
		return
	end

	print(`{PREFIX} Dev pause off | round running`)
	if not inRound or currentState == "WaitingForPlayers" then
		if countPlayers() >= GameConfig.getMinPlayers() then
			machine.beginRound()
		else
			machine.publishWaiting()
		end
		return
	end

	machine.transitionTo(currentState)
end

function machine.onPlayerAdded(player: Player)
	if joinedPlayers[player] == true then
		return
	end

	joinedPlayers[player] = true
	print(`{PREFIX} {player.Name} joined | players {countPlayers()}`)
	machine.refresh()
	machine.broadcast(player)
end

function machine.onPlayerRemoving(player: Player)
	if joinedPlayers[player] ~= true then
		return
	end

	joinedPlayers[player] = nil
	lastRequestAt[player] = nil
	print(`{PREFIX} {player.Name} left | players {countPlayers()}`)
	machine.refresh()
end

function machine.onRequest(player: Player)
	if joinedPlayers[player] ~= true then
		machine.onPlayerAdded(player)
		return
	end

	local now = os.clock()
	local previous = lastRequestAt[player]
	if previous ~= nil and (now - previous) < REQUEST_COOLDOWN_SECONDS then
		return
	end
	lastRequestAt[player] = now
	machine.broadcast(player)
end

local RoundManager = {}

function RoundManager.getRoundId(): number
	return roundId
end

-- Creation, plus a short grace period so a late submit still counts.
function RoundManager.isDesignWindowOpen(): boolean
	return currentState == "TattooCreation" or currentState == "Submission" or currentState == "Showcase"
end

function RoundManager.start()
	GameConfig.validate()
	Themes.validate()

	local mode = if GameConfig.DevMode then "development" else "live"
	local holdNote = if paused then " | lobby paused until Resume" else ""
	print(`{PREFIX} Server ready | {mode} timings | minimum {GameConfig.getMinPlayers()} players{holdNote}`)

	Players.PlayerAdded:Connect(function(player: Player)
		machine.onPlayerAdded(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		machine.onPlayerRemoving(player)
	end)
	requestRemote.OnServerEvent:Connect(function(player: Player)
		machine.onRequest(player)
	end)
	pauseRemote.OnServerEvent:Connect(function(_player: Player, want: any)
		if typeof(want) ~= "boolean" then
			return
		end
		machine.setPaused(want)
	end)

	for _, player in Players:GetPlayers() do
		machine.onPlayerAdded(player)
	end

	if not inRound then
		machine.publishWaiting()
	end
end

return RoundManager
