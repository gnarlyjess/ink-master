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

-- regionId -> toneId -> rbxassetid
local photos: { [string]: { [string]: string } } = {
	LeftForearm = {
		light = "rbxassetid://105725694418928",
		peach = "rbxassetid://92716745950431",
		warm = "rbxassetid://95785016954319",
		tan = "rbxassetid://108561031673527",
		olive = "rbxassetid://95817517069695",
		brown = "rbxassetid://79840075103290",
		deep = "rbxassetid://130189225993849",
	},
	LeftUpperArm = {
		light = "rbxassetid://96793958612236",
		peach = "rbxassetid://75494655827654",
		warm = "rbxassetid://130312158953640",
		tan = "rbxassetid://101564387758923",
		olive = "rbxassetid://107766824050687",
		brown = "rbxassetid://99013278385274",
		deep = "rbxassetid://119286107625110",
	},
	LeftThigh = {
		light = "rbxassetid://105265634640190",
		peach = "rbxassetid://120588074998974",
		warm = "rbxassetid://124581724614975",
		tan = "rbxassetid://105964165114477",
		olive = "rbxassetid://78930782472497",
		brown = "rbxassetid://101797459907397",
		deep = "rbxassetid://127177180415992",
	},
	LeftCalf = {
		light = "rbxassetid://88876246216890",
		peach = "rbxassetid://91808551297723",
		warm = "rbxassetid://76467639694051",
		tan = "rbxassetid://110952942797277",
		olive = "rbxassetid://133316170445208",
		brown = "rbxassetid://121113181940526",
		deep = "rbxassetid://101196815113273",
	},
	Chest = {
		light = "rbxassetid://114167788353512",
		peach = "rbxassetid://107600178745379",
		warm = "rbxassetid://78580889693300",
		tan = "rbxassetid://109374209169427",
		olive = "rbxassetid://129766109275907",
		brown = "rbxassetid://86926855561307",
		deep = "rbxassetid://100919392882441",
	},
	Back = {
		light = "rbxassetid://122191314032622",
		peach = "rbxassetid://136698860612467",
		warm = "rbxassetid://87617491164025",
		tan = "rbxassetid://88594401880491",
		olive = "rbxassetid://125189876785891",
		brown = "rbxassetid://90475372546670",
		deep = "rbxassetid://138083612528671",
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
