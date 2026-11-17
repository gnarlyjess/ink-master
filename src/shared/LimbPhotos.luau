--!strict

-- Preloaded limb stills for the design canvas. One transparent cutout per
-- region × skin tone — board backdrop stays fixed; only the limb swaps.

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

-- Transparent limb cutouts (alpha outside the skin). Generated from peach masters
-- and recolored per palette tone so the studio backdrop never changes.
local photos: { [string]: { [string]: string } } = {
	LeftForearm = {
		light = "rbxassetid://103213792164498",
		peach = "rbxassetid://90568158139360",
		warm = "rbxassetid://88128823623779",
		tan = "rbxassetid://90445618816168",
		olive = "rbxassetid://86258206987552",
		brown = "rbxassetid://94713640741919",
		deep = "rbxassetid://88526808894781",
	},
	LeftUpperArm = {
		light = "rbxassetid://138471254714201",
		peach = "rbxassetid://103293817669502",
		warm = "rbxassetid://114267186913399",
		tan = "rbxassetid://96435151175462",
		olive = "rbxassetid://128241855800840",
		brown = "rbxassetid://87059426556646",
		deep = "rbxassetid://79901235746362",
	},
	LeftThigh = {
		light = "rbxassetid://101319737825762",
		peach = "rbxassetid://126486009321295",
		warm = "rbxassetid://100332047515925",
		tan = "rbxassetid://80636296778849",
		olive = "rbxassetid://82504176012990",
		brown = "rbxassetid://130523352762438",
		deep = "rbxassetid://77331629043481",
	},
	LeftCalf = {
		light = "rbxassetid://79001137721908",
		peach = "rbxassetid://114458992239123",
		warm = "rbxassetid://78296374296683",
		tan = "rbxassetid://129038757650608",
		olive = "rbxassetid://105124486922413",
		brown = "rbxassetid://136864400298855",
		deep = "rbxassetid://118415518298383",
	},
	Chest = {
		light = "rbxassetid://110780303721379",
		peach = "rbxassetid://111437873159464",
		warm = "rbxassetid://112938526683593",
		tan = "rbxassetid://99469450242183",
		olive = "rbxassetid://84212431406714",
		brown = "rbxassetid://119934512559067",
		deep = "rbxassetid://107825990615993",
	},
	Back = {
		light = "rbxassetid://107007092575786",
		peach = "rbxassetid://82207955851180",
		warm = "rbxassetid://103429817226863",
		tan = "rbxassetid://107708194588138",
		olive = "rbxassetid://131420912601221",
		brown = "rbxassetid://89246450378610",
		deep = "rbxassetid://83972821416277",
	},
}

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
