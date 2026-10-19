--!strict

-- Ink swatches. Starter inks are free for everyone. The rest are sold in the shop
-- under the item id "ink:<swatch id>". Inks never change how votes are counted.

export type InkSwatch = {
	id: string,
	name: string,
	r: number,
	g: number,
	b: number,
	starter: boolean,
}

local swatches: { InkSwatch } = {
	{ id = "black", name = "Black", r = 0.07, g = 0.06, b = 0.08, starter = true },
	{ id = "white", name = "White", r = 0.96, g = 0.94, b = 0.9, starter = true },
	{ id = "red", name = "Red", r = 0.78, g = 0.16, b = 0.22, starter = true },
	{ id = "gold", name = "Gold", r = 0.86, g = 0.64, b = 0.28, starter = true },
	{ id = "teal", name = "Teal", r = 0.12, g = 0.62, b = 0.58, starter = true },
	{ id = "magenta", name = "Magenta", r = 0.86, g = 0.22, b = 0.48, starter = true },
	{ id = "violet", name = "Violet", r = 0.46, g = 0.28, b = 0.82, starter = true },
	{ id = "ember", name = "Ember", r = 0.93, g = 0.45, b = 0.16, starter = false },
	{ id = "sky", name = "Sky", r = 0.35, g = 0.62, b = 0.95, starter = false },
	{ id = "mint", name = "Mint", r = 0.45, g = 0.85, b = 0.62, starter = false },
	{ id = "blush", name = "Blush", r = 0.97, g = 0.7, b = 0.76, starter = false },
	{ id = "plum", name = "Plum", r = 0.35, g = 0.14, b = 0.34, starter = false },
	{ id = "forest", name = "Forest", r = 0.14, g = 0.4, b = 0.24, starter = false },
	{ id = "copper", name = "Copper", r = 0.72, g = 0.4, b = 0.24, starter = false },
	{ id = "ice", name = "Ice", r = 0.78, g = 0.92, b = 0.98, starter = false },
	{ id = "lemon", name = "Lemon", r = 0.98, g = 0.82, b = 0.12, starter = false },
	{ id = "coral", name = "Coral", r = 0.98, g = 0.48, b = 0.36, starter = false },
	{ id = "lime", name = "Lime", r = 0.52, g = 0.86, b = 0.18, starter = false },
	{ id = "lavender", name = "Lavender", r = 0.72, g = 0.62, b = 0.92, starter = false },
	{ id = "navy", name = "Navy", r = 0.08, g = 0.16, b = 0.4, starter = false },
	{ id = "bubble", name = "Bubble", r = 1, g = 0.32, b = 0.62, starter = false },
	{ id = "crimson", name = "Crimson", r = 0.5, g = 0.05, b = 0.1, starter = false },
	{ id = "cobalt", name = "Cobalt", r = 0.1, g = 0.32, b = 0.86, starter = false },
	{ id = "jade", name = "Jade", r = 0.05, g = 0.55, b = 0.34, starter = false },
	{ id = "sand", name = "Sand", r = 0.86, g = 0.72, b = 0.48, starter = false },
	{ id = "amber", name = "Amber", r = 0.96, g = 0.62, b = 0.06, starter = false },
	{ id = "slate", name = "Slate", r = 0.38, g = 0.42, b = 0.48, starter = false },
	{ id = "wine", name = "Wine", r = 0.62, g = 0.18, b = 0.32, starter = false },
	{ id = "rust", name = "Rust", r = 0.58, g = 0.24, b = 0.08, starter = false },
	{ id = "silver", name = "Silver", r = 0.68, g = 0.72, b = 0.76, starter = false },
	{ id = "cyan", name = "Cyan", r = 0.08, g = 0.78, b = 0.88, starter = false },
	{ id = "cream", name = "Cream", r = 0.96, g = 0.88, b = 0.68, starter = false },
	{ id = "indigo", name = "Indigo", r = 0.22, g = 0.12, b = 0.52, starter = false },
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
