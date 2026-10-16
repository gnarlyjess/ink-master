--!strict

-- Stable ids. Add rows here when the catalogue grows. Do not rename an id once it is saved.

export type ThemeDefinition = {
	id: string,
	name: string,
	tagline: string,
}

local catalogue: { ThemeDefinition } = {
	{ id = "nature", name = "Nature", tagline = "Leaves, blooms, and wild growth." },
	{ id = "mythical", name = "Mythical creatures", tagline = "Beasts that never quite existed." },
	{ id = "dark", name = "Dark and mysterious", tagline = "Shadows, secrets, and sharp edges." },
	{ id = "heartbreak", name = "Love and heartbreak", tagline = "Devotion, distance, and what remains." },
	{ id = "japanese", name = "Japanese-inspired motifs", tagline = "Waves, blossoms, and bold tradition." },
	{ id = "fire-and-ice", name = "Fire and ice", tagline = "Two forces that refuse to share a room." },
	{ id = "minimalist", name = "Minimalist", tagline = "Say more with almost nothing." },
	{ id = "animals", name = "Animals", tagline = "Claws, feathers, scales, and stare." },
	{ id = "fantasy", name = "Fantasy", tagline = "Myths you invent yourself." },
	{ id = "abstract", name = "Abstract", tagline = "Shape, contrast, and pure feeling." },
	{ id = "strength", name = "Symbols of strength", tagline = "Marks of endurance and will." },
	{ id = "ocean", name = "The ocean", tagline = "Depth, tide, and things that surface." },
	{ id = "cyberpunk", name = "Cyberpunk", tagline = "Neon, chrome, and city nights." },
	{ id = "opposites", name = "Opposites attract", tagline = "Pair two ideas that should not fit." },
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
