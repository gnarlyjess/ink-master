--!strict

export type InkSwatch = {
	id: string,
	name: string,
	r: number,
	g: number,
	b: number,
}

local swatches: { InkSwatch } = {
	{ id = "black", name = "Black", r = 0.07, g = 0.06, b = 0.08 },
	{ id = "white", name = "White", r = 0.96, g = 0.94, b = 0.9 },
	{ id = "red", name = "Red", r = 0.78, g = 0.16, b = 0.22 },
	{ id = "gold", name = "Gold", r = 0.86, g = 0.64, b = 0.28 },
	{ id = "teal", name = "Teal", r = 0.12, g = 0.62, b = 0.58 },
	{ id = "magenta", name = "Magenta", r = 0.86, g = 0.22, b = 0.48 },
	{ id = "violet", name = "Violet", r = 0.46, g = 0.28, b = 0.82 },
}

local InkColors = {
	all = swatches,
}

function InkColors.get(id: string): InkSwatch?
	for _, swatch in swatches do
		if swatch.id == id then
			return swatch
		end
	end
	return nil
end

function InkColors.toColor3(color: { r: number, g: number, b: number }): Color3
	return Color3.new(color.r, color.g, color.b)
end

return InkColors
