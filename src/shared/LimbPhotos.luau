--!strict

-- Preloaded limb stills for the design canvas. One image per region × skin tone.
-- Generated / uploaded assets — replace any id when you swap art.

export type SkinToneId = "light" | "peach" | "warm" | "tan" | "olive" | "brown" | "deep"

local DEFAULT_TONE: SkinToneId = "peach"

local TONES: { SkinToneId } = {
	"light",
	"peach",
	"warm",
	"tan",
	"olive",
	"brown",
	"deep",
}

-- Transparent peach masters (alpha outside the limb). Carousel tones tint these via ImageColor3
-- so the studio backdrop stays fixed. Older per-tone uploads were nearly identical and useless.
local PEACH_MASTER: { [string]: string } = {
	LeftForearm = "rbxassetid://122046948218715",
	LeftUpperArm = "rbxassetid://110674980538687",
	LeftThigh = "rbxassetid://107362931437457",
	LeftCalf = "rbxassetid://130478219774881",
	Chest = "rbxassetid://112508645495534",
	Back = "rbxassetid://111156088026511",
}

-- regionId -> toneId -> rbxassetid (every tone points at the peach master for that region)
local photos: { [string]: { [string]: string } } = {}
for regionId, asset in PEACH_MASTER do
	local byTone: { [string]: string } = {}
	for _, tone in TONES do
		byTone[tone] = asset
	end
	photos[regionId] = byTone
end

local LimbPhotos = {}

LimbPhotos.defaultTone = DEFAULT_TONE
LimbPhotos.tones = TONES

function LimbPhotos.get(regionId: string, toneId: string?): string?
	local byTone = photos[regionId]
	if byTone == nil then
		return nil
	end
	-- "fair" used to sit next to light and looked identical — map old saves over.
	local tone = if toneId ~= nil and toneId ~= "" then toneId else DEFAULT_TONE
	if tone == "fair" then
		tone = "light"
	end
	return byTone[tone] or byTone[DEFAULT_TONE]
end

function LimbPhotos.has(regionId: string): boolean
	return photos[regionId] ~= nil
end

function LimbPhotos.allAssets(): { string }
	local assets: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, byTone in photos do
		for _, asset in byTone do
			if asset ~= "" and not seen[asset] then
				seen[asset] = true
				table.insert(assets, asset)
			end
		end
	end
	return assets
end

return LimbPhotos
