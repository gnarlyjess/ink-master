--!strict

-- Short feedback sounds for menu actions. They use sounds that ship with Roblox, so swap the
-- ids below for uploaded audio whenever the game has its own. The player can turn them off.

local SoundService = game:GetService("SoundService")

local PlayerData = require(script.Parent.PlayerData)

export type Cue = "click" | "good" | "level" | "error"

local CUES: { [string]: { id: string, volume: number } } = {
	click = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.35 },
	good = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.35 },
	level = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.5 },
	error = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.25 },
}

local sounds: { [string]: Sound } = {}

local Sfx = {}

local function soundFor(cue: string): Sound?
	local existing: Sound? = sounds[cue]
	if existing ~= nil then
		return existing
	end
	local info = CUES[cue]
	if info == nil then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = `InkMasters_{cue}`
	sound.SoundId = info.id
	sound.Volume = info.volume
	sound.Parent = SoundService
	sounds[cue] = sound
	return sound
end

function Sfx.play(cue: Cue)
	local view = PlayerData.get()
	if view ~= nil and not view.settings.sound then
		return
	end
	local sound = soundFor(cue)
	if sound ~= nil then
		sound:Play()
	end
end

return Sfx
