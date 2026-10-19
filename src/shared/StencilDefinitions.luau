--!strict

-- Shapes for the limb canvas. Ids stay stable once shipped.
-- Later rows can point at an uploaded image without changing the editor.

export type StencilShape =
	"disc"
	| "ring"
	| "oval"
	| "square"
	| "diamond"
	| "triangle"
	| "half"
	| "band"
	| "pill"
	| "slash"
	| "line"
	| "cross"
	| "plus"
	| "saltire"
	| "chevron"
	| "arrow"
	| "spark"
	| "burst"
	| "heart"
	| "bolt"
	| "drop"
	| "banner"
	| "steps"
	| "target"
	| "corner"
	| "circle"
	| "frame"
	| "rect"
	| "tri"
	| "bar"
	| "star"
	| "moon"
	| "sun"
	| "flower"
	| "heartline"
	| "ovalline"
	| "gem"
	| "pointer"
	| "crossline"
	| "hex"
	| "dropline"
	| "boltline"
	| "cloud"
	| "leaf"
	| "wave"
	| "zigzag"
	| "eye"
	| "shield"
	| "crown"
	| "burstline"
	| "sparkline"
	| "arc"
	| "blob"
	| "bannerline"
	| "chevronline"
	| "stepline"

export type StencilDefinition = {
	id: string,
	name: string,
	category: string,
	shape: StencilShape,
}

local catalogue: { StencilDefinition } = {
	{ id = "circle", name = "Circle", category = "shapes", shape = "circle" },
	{ id = "frame", name = "Square", category = "shapes", shape = "frame" },
	{ id = "rect", name = "Rectangle", category = "shapes", shape = "rect" },
	{ id = "tri", name = "Triangle", category = "shapes", shape = "tri" },
	{ id = "bar", name = "Line", category = "shapes", shape = "bar" },
	{ id = "star", name = "Star", category = "shapes", shape = "star" },
	{ id = "moon", name = "Moon", category = "shapes", shape = "moon" },
	{ id = "sun", name = "Sun", category = "shapes", shape = "sun" },
	{ id = "flower", name = "Flower", category = "shapes", shape = "flower" },
	{ id = "heartline", name = "Heart", category = "shapes", shape = "heartline" },
	{ id = "ovalline", name = "Oval", category = "shapes", shape = "ovalline" },
	{ id = "gem", name = "Diamond", category = "shapes", shape = "gem" },
	{ id = "pointer", name = "Arrow", category = "shapes", shape = "pointer" },
	{ id = "crossline", name = "Cross", category = "shapes", shape = "crossline" },
	{ id = "hex", name = "Hex", category = "shapes", shape = "hex" },
	{ id = "dropline", name = "Drop", category = "shapes", shape = "dropline" },
	{ id = "boltline", name = "Bolt", category = "shapes", shape = "boltline" },
	{ id = "cloud", name = "Cloud", category = "shapes", shape = "cloud" },
	{ id = "leaf", name = "Leaf", category = "shapes", shape = "leaf" },
	{ id = "eye", name = "Eye", category = "shapes", shape = "eye" },
	{ id = "shield", name = "Shield", category = "shapes", shape = "shield" },
	{ id = "crown", name = "Crown", category = "shapes", shape = "crown" },
	{ id = "burstline", name = "Burst", category = "shapes", shape = "burstline" },
	{ id = "sparkline", name = "Spark", category = "shapes", shape = "sparkline" },
	{ id = "bannerline", name = "Banner", category = "shapes", shape = "bannerline" },
	{ id = "chevronline", name = "Chevron", category = "shapes", shape = "chevronline" },
	{ id = "stepline", name = "Steps", category = "shapes", shape = "stepline" },
	{ id = "arc", name = "Arc", category = "shapes", shape = "arc" },
	{ id = "wave", name = "Wave", category = "shapes", shape = "wave" },
	{ id = "zigzag", name = "Zigzag", category = "shapes", shape = "zigzag" },
	{ id = "blob", name = "Blob", category = "shapes", shape = "blob" },
	-- Extra shop packs (also kept in legacy for old designs).
	{ id = "ring", name = "Ring", category = "shapes", shape = "ring" },
	{ id = "pill", name = "Pill", category = "shapes", shape = "pill" },
	{ id = "slash", name = "Slash", category = "shapes", shape = "slash" },
	{ id = "saltire", name = "X", category = "shapes", shape = "saltire" },
	{ id = "plus", name = "Plus", category = "shapes", shape = "plus" },
	{ id = "arrow", name = "Arrow", category = "shapes", shape = "arrow" },
	{ id = "target", name = "Target", category = "shapes", shape = "target" },
	{ id = "half", name = "Half", category = "shapes", shape = "half" },
	{ id = "spark", name = "Spark", category = "shapes", shape = "spark" },
	{ id = "burst", name = "Burst", category = "shapes", shape = "burst" },
	{ id = "banner", name = "Banner", category = "shapes", shape = "banner" },
	{ id = "heart", name = "Heart solid", category = "shapes", shape = "heart" },
	{ id = "bolt", name = "Bolt solid", category = "shapes", shape = "bolt" },
	{ id = "drop", name = "Drop solid", category = "shapes", shape = "drop" },
	{ id = "chevron", name = "Chevron", category = "shapes", shape = "chevron" },
	{ id = "steps", name = "Steps", category = "shapes", shape = "steps" },
	{ id = "band", name = "Bar", category = "shapes", shape = "band" },
	{ id = "disc", name = "Dot", category = "shapes", shape = "disc" },
	{ id = "corner", name = "Corner", category = "shapes", shape = "corner" },
}

-- Older marks still resolve. They are not shown in the shape panel.
local legacy: { StencilDefinition } = {
	{ id = "disc", name = "Dot", category = "shapes", shape = "disc" },
	{ id = "ring", name = "Ring", category = "shapes", shape = "ring" },
	{ id = "oval", name = "Oval", category = "shapes", shape = "oval" },
	{ id = "square", name = "Square", category = "shapes", shape = "square" },
	{ id = "diamond", name = "Diamond", category = "shapes", shape = "diamond" },
	{ id = "triangle", name = "Triangle", category = "shapes", shape = "triangle" },
	{ id = "half", name = "Half", category = "shapes", shape = "half" },
	{ id = "band", name = "Bar", category = "lines", shape = "band" },
	{ id = "pill", name = "Pill", category = "lines", shape = "pill" },
	{ id = "slash", name = "Slash", category = "lines", shape = "slash" },
	{ id = "line", name = "Line", category = "lines", shape = "line" },
	{ id = "cross", name = "Cross", category = "symbols", shape = "cross" },
	{ id = "plus", name = "Plus", category = "symbols", shape = "plus" },
	{ id = "saltire", name = "X", category = "symbols", shape = "saltire" },
	{ id = "chevron", name = "Chevron", category = "symbols", shape = "chevron" },
	{ id = "arrow", name = "Arrow", category = "symbols", shape = "arrow" },
	{ id = "spark", name = "Star", category = "symbols", shape = "spark" },
	{ id = "burst", name = "Burst", category = "symbols", shape = "burst" },
	{ id = "heart", name = "Heart", category = "symbols", shape = "heart" },
	{ id = "bolt", name = "Bolt", category = "symbols", shape = "bolt" },
	{ id = "drop", name = "Drop", category = "shapes", shape = "drop" },
	{ id = "banner", name = "Banner", category = "symbols", shape = "banner" },
	{ id = "steps", name = "Steps", category = "lines", shape = "steps" },
	{ id = "target", name = "Target", category = "symbols", shape = "target" },
	{ id = "corner", name = "Corner", category = "lines", shape = "corner" },
}

local byId: { [string]: StencilDefinition } = {}

local function stored(id: string): StencilDefinition?
	return byId[id]
end

for _, stencil in catalogue do
	byId[stencil.id] = stencil
end
for _, stencil in legacy do
	if stored(stencil.id) == nil then
		byId[stencil.id] = stencil
	end
end

local StencilDefinitions = {
	all = catalogue,
}

function StencilDefinitions.get(id: string): StencilDefinition?
	return byId[id]
end

return StencilDefinitions
