--!strict

-- Stable ids. Add rows here when the catalogue grows. Do not rename an id once it is saved.

export type ThemeDefinition = {
	id: string,
	name: string,
	tagline: string,
}

-- Easy prompts a kid, a teen, or an adult can all draw. No studio characters.
local catalogue: { ThemeDefinition } = {
	{ id = "pets", name = "Cats and dogs", tagline = "A pet with a personality." },
	{ id = "ocean-animals", name = "Ocean animals", tagline = "Fish, whales, jellyfish, or a crab." },
	{ id = "jungle-animals", name = "Jungle animals", tagline = "Parrots, frogs, big cats, or snakes." },
	{ id = "farm-animals", name = "Farm animals", tagline = "Horses, pigs, ducks, or a cow." },
	{ id = "birds", name = "Birds", tagline = "Wings, feathers, and a beak." },
	{ id = "bugs", name = "Bugs and butterflies", tagline = "Bees, beetles, or bright wings." },
	{ id = "dinosaurs", name = "Dinosaurs", tagline = "One friendly prehistoric creature." },
	{ id = "dragons", name = "Dragons", tagline = "Scales, wings, and a little fire." },
	{ id = "broken-heart", name = "Broken heart", tagline = "A cracked heart. Keep it kind." },
	{ id = "gothic", name = "Gothic", tagline = "Moons, bats, roses, and candlelight." },
	{ id = "fairy-tale", name = "Fairy tale", tagline = "Castles, crowns, or a magic frog." },
	{ id = "cartoon-pal", name = "A cartoon pal", tagline = "Invent a character of your own." },
	{ id = "friendly-monster", name = "A friendly monster", tagline = "Silly, not scary." },
	{ id = "pirates", name = "Pirates", tagline = "Ships, maps, and treasure." },
	{ id = "space", name = "Space", tagline = "Planets, stars, and a rocket." },
	{ id = "candy", name = "Candy", tagline = "Sweets, lollipops, and sprinkles." },
	{ id = "flowers", name = "Flowers", tagline = "One bloom, or a little bunch." },
	{ id = "music", name = "Music", tagline = "Notes, headphones, or a guitar." },
	{ id = "sports", name = "Sports", tagline = "A ball, a skate, or a trophy." },
	{ id = "robots", name = "Robots", tagline = "A cute machine with a face." },
	{ id = "rainbows", name = "Rainbows", tagline = "Colour, clouds, and sunshine." },
	{ id = "best-friends", name = "Best friends", tagline = "Two pals, side by side." },
	{ id = "birthday", name = "Birthday", tagline = "Cake, candles, and a wish." },
	{ id = "lucky", name = "Lucky charms", tagline = "Horseshoes, clovers, or a star." },
}

local Themes = {
	all = catalogue,
}

local random = Random.new()
local lastThemeId: string? = nil

function Themes.validate()
	if #catalogue == 0 then
		error("[InkMasters] Theme catalogue is empty")
	end

	local seen: { [string]: boolean } = {}
	for _, theme in catalogue do
		if theme.id == "" or theme.name == "" or theme.tagline == "" then
			error("[InkMasters] Every theme needs an id, name, and tagline")
		end
		if seen[theme.id] then
			error(`[InkMasters] Duplicate theme id {theme.id}`)
		end
		seen[theme.id] = true
	end
end

function Themes.pickRandom(): ThemeDefinition
	local count = #catalogue
	if count == 0 then
		error("[InkMasters] Theme catalogue is empty")
	end

	local index = random:NextInteger(1, count)
	local picked = catalogue[index]
	if picked == nil then
		error("[InkMasters] Theme pick failed")
	end
	if count > 1 and picked.id == lastThemeId then
		index = (index % count) + 1
		picked = catalogue[index]
		if picked == nil then
			error("[InkMasters] Theme pick failed")
		end
	end

	local theme = picked

	lastThemeId = theme.id
	return theme
end

return Themes
