--!strict

-- FIFO queue of paid theme picks for upcoming rounds.
-- One pending claim per player. Leaving before your turn refunds the coins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Economy = require(ReplicatedStorage.Shared.Economy)
local Themes = require(ReplicatedStorage.Shared.Themes)

export type ThemeClaim = {
	userId: number,
	displayName: string,
	customName: string?,
	pricePaid: number,
}

local PREFIX = "[InkMasters]"

local queue: { ThemeClaim } = {}
local changedCallbacks: { () -> () } = {}

local ThemeQueue = {}

local function findIndex(userId: number): number?
	for index, claim in queue do
		if claim.userId == userId then
			return index
		end
	end
	return nil
end

local function notifyChanged()
	for _, callback in changedCallbacks do
		task.spawn(callback)
	end
end

local function sanitizeName(raw: string): string?
	local trimmed = string.match(raw, "^%s*(.-)%s*$")
	if trimmed == nil or trimmed == "" then
		return nil
	end
	if #trimmed > Economy.THEME_PICK_MAX_CHARS then
		trimmed = string.sub(trimmed, 1, Economy.THEME_PICK_MAX_CHARS)
	end
	-- Keep printable characters only.
	local cleaned = string.gsub(trimmed, "[%c%z]", "")
	cleaned = string.match(cleaned, "^%s*(.-)%s*$") or ""
	if cleaned == "" then
		return nil
	end
	return cleaned
end

local function filterForBroadcast(player: Player, text: string): string?
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId)
	end)
	if not ok or filtered == nil then
		return nil
	end
	local okBroadcast, result = pcall(function()
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not okBroadcast or typeof(result) ~= "string" then
		return nil
	end
	return sanitizeName(result)
end

function ThemeQueue.onChanged(callback: () -> ())
	table.insert(changedCallbacks, callback)
end

function ThemeQueue.getCount(): number
	return #queue
end

function ThemeQueue.getPosition(player: Player): number?
	return findIndex(player.UserId)
end

function ThemeQueue.hasClaim(player: Player): boolean
	return findIndex(player.UserId) ~= nil
end

function ThemeQueue.getClaim(player: Player): ThemeClaim?
	local index = findIndex(player.UserId)
	if index == nil then
		return nil
	end
	return queue[index]
end

-- Resolve the next claim into a theme. Empty custom text → random catalogue pick.
function ThemeQueue.consumeNext(): Themes.ThemeDefinition
	local claim = table.remove(queue, 1)
	notifyChanged()
	if claim == nil then
		return Themes.pickRandom()
	end

	local custom = claim.customName
	if custom ~= nil and custom ~= "" then
		print(`{PREFIX} Theme pick | {claim.displayName} set "{custom}"`)
		return {
			id = "custom",
			name = custom,
			tagline = `Chosen by {claim.displayName}.`,
		}
	end

	print(`{PREFIX} Theme pick | {claim.displayName} left it random`)
	return Themes.pickRandom()
end

-- Update text on an existing claim without spending again.
function ThemeQueue.setText(player: Player, rawText: string?): (boolean, string)
	local index = findIndex(player.UserId)
	if index == nil then
		return false, "Buy a theme pick first."
	end

	local claim = queue[index]
	if claim == nil then
		return false, "Buy a theme pick first."
	end

	local sanitized = if rawText ~= nil then sanitizeName(rawText) else nil
	if sanitized ~= nil then
		local filtered = filterForBroadcast(player, sanitized)
		if filtered == nil then
			return false, "That theme couldn't be used. Try different words."
		end
		claim.customName = filtered
		claim.displayName = player.DisplayName
		notifyChanged()
		return true, `Theme set to "{filtered}". You're #{index} in line.`
	end

	claim.customName = nil
	claim.displayName = player.DisplayName
	notifyChanged()
	return true, `Theme will be random. You're #{index} in line.`
end

-- Enqueue after coins were already deducted by PlayerEconomy.
function ThemeQueue.enqueue(player: Player, rawText: string?, pricePaid: number): (boolean, string)
	if findIndex(player.UserId) ~= nil then
		return false, "You already have a theme pick queued."
	end

	local sanitized = if rawText ~= nil then sanitizeName(rawText) else nil
	local customName: string? = nil
	if sanitized ~= nil then
		customName = filterForBroadcast(player, sanitized)
		if customName == nil then
			return false, "That theme couldn't be used. Try different words."
		end
	end

	-- Re-check after the filter yield.
	if findIndex(player.UserId) ~= nil then
		return false, "You already have a theme pick queued."
	end
	if player.Parent ~= Players then
		return false, "You left before the pick was saved."
	end

	table.insert(queue, {
		userId = player.UserId,
		displayName = player.DisplayName,
		customName = customName,
		pricePaid = pricePaid,
	})
	local spot = #queue
	notifyChanged()

	if customName ~= nil then
		return true, `Theme pick bought. "{customName}" is queued at #{spot}.`
	end
	return true, `Theme pick bought. You're #{spot} — leave it blank for a random theme.`
end

function ThemeQueue.refundLeaving(player: Player): number
	local index = findIndex(player.UserId)
	if index == nil then
		return 0
	end
	local claim = table.remove(queue, index)
	notifyChanged()
	if claim == nil then
		return 0
	end
	return claim.pricePaid
end

function ThemeQueue.start()
	-- Queue is session-only. Refunds on leave are handled by PlayerEconomy.
end

return ThemeQueue
