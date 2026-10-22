--!strict

-- Ink swatches. Only black and white start free. Everything else is shop or level unlock
-- under the item id "ink:<swatch id>". Inks never change how votes are counted.
--
-- Core strip = solid, saturated flash colours. Pastels / soft neutrals sit after as add-ons.

export type InkSwatch = {
	id: string,
	name: string,
	r: number,
	g: number,
	b: number,
	starter: boolean,
	-- "core" = solid spectrum; "addon" = pastels / soft neutrals.
	group: "core" | "addon",
}

local swatches: { InkSwatch } = {
	-- Starters
	{ id = "black", name = "Black", r = 0.05, g = 0.05, b = 0.06, starter = true, group = "core" },
	{ id = "white", name = "White", r = 0.98, g = 0.98, b = 0.96, starter = true, group = "core" },

	-- Solid spectrum (red → violet), fully saturated
	{ id = "red", name = "Red", r = 0.92, g = 0.1, b = 0.14, starter = false, group = "core" },
	{ id = "crimson", name = "Crimson", r = 0.72, g = 0.04, b = 0.12, starter = false, group = "core" },
	{ id = "ember", name = "Ember", r = 1, g = 0.42, b = 0.05, starter = false, group = "core" },
	{ id = "amber", name = "Amber", r = 1, g = 0.68, b = 0, starter = false, group = "core" },
	{ id = "gold", name = "Gold", r = 0.95, g = 0.72, b = 0.08, starter = false, group = "core" },
	{ id = "lemon", name = "Lemon", r = 1, g = 0.9, b = 0.05, starter = false, group = "core" },
	{ id = "lime", name = "Lime", r = 0.45, g = 0.92, b = 0.08, starter = false, group = "core" },
	{ id = "jade", name = "Jade", r = 0, g = 0.7, b = 0.38, starter = false, group = "core" },
	{ id = "forest", name = "Forest", r = 0.06, g = 0.45, b = 0.18, starter = false, group = "core" },
	{ id = "teal", name = "Teal", r = 0, g = 0.72, b = 0.68, starter = false, group = "core" },
	{ id = "cyan", name = "Cyan", r = 0, g = 0.86, b = 0.95, starter = false, group = "core" },
	{ id = "sky", name = "Sky", r = 0.2, g = 0.55, b = 1, starter = false, group = "core" },
	{ id = "cobalt", name = "Cobalt", r = 0.05, g = 0.28, b = 0.95, starter = false, group = "core" },
	{ id = "navy", name = "Navy", r = 0.04, g = 0.12, b = 0.42, starter = false, group = "core" },
	{ id = "indigo", name = "Indigo", r = 0.28, g = 0.08, b = 0.72, starter = false, group = "core" },
	{ id = "violet", name = "Violet", r = 0.55, g = 0.18, b = 0.95, starter = false, group = "core" },
	{ id = "magenta", name = "Magenta", r = 0.95, g = 0.08, b = 0.55, starter = false, group = "core" },
	{ id = "bubble", name = "Bubble", r = 1, g = 0.2, b = 0.55, starter = false, group = "core" },
	{ id = "wine", name = "Wine", r = 0.58, g = 0.05, b = 0.22, starter = false, group = "core" },
	{ id = "plum", name = "Plum", r = 0.42, g = 0.08, b = 0.4, starter = false, group = "core" },
	{ id = "rust", name = "Rust", r = 0.72, g = 0.22, b = 0.04, starter = false, group = "core" },
	{ id = "copper", name = "Copper", r = 0.82, g = 0.4, b = 0.12, starter = false, group = "core" },

	-- Add-ons: pastels & soft neutrals
	{ id = "blush", name = "Blush", r = 1, g = 0.78, b = 0.84, starter = false, group = "addon" },
	{ id = "coral", name = "Coral", r = 1, g = 0.62, b = 0.52, starter = false, group = "addon" },
	{ id = "cream", name = "Cream", r = 1, g = 0.94, b = 0.82, starter = false, group = "addon" },
	{ id = "sand", name = "Sand", r = 0.9, g = 0.78, b = 0.58, starter = false, group = "addon" },
	{ id = "mint", name = "Mint", r = 0.62, g = 0.94, b = 0.78, starter = false, group = "addon" },
	{ id = "ice", name = "Ice", r = 0.82, g = 0.94, b = 1, starter = false, group = "addon" },
	{ id = "lavender", name = "Lavender", r = 0.82, g = 0.74, b = 0.98, starter = false, group = "addon" },
	{ id = "silver", name = "Silver", r = 0.78, g = 0.8, b = 0.84, starter = false, group = "addon" },
	{ id = "slate", name = "Slate", r = 0.42, g = 0.46, b = 0.52, starter = false, group = "addon" },
}

local InkColors = {
	all = swatches,
}

local MATCH_TOLERANCE = 0.02

function InkColors.get(id: string): InkSwatch?
	for _, swatch in swatches do
		if swatch.id == id then
			return swatch
		end
	end
	return nil
end

-- The swatch a colour came from, or nil when it matches none of them.
function InkColors.matchId(color: { r: number, g: number, b: number }): string?
	for _, swatch in swatches do
		local same = math.abs(swatch.r - color.r) <= MATCH_TOLERANCE
			and math.abs(swatch.g - color.g) <= MATCH_TOLERANCE
			and math.abs(swatch.b - color.b) <= MATCH_TOLERANCE
		if same then
			return swatch.id
		end
	end
	return nil
end

function InkColors.toColor3(color: { r: number, g: number, b: number }): Color3
	return Color3.new(color.r, color.g, color.b)
end

return InkColors
