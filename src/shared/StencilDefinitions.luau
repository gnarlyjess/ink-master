--!strict

-- Shapes for the limb canvas. Ids stay stable once shipped.
-- The Figma outline pack is the live catalogue; older procedural shapes stay for old saves.

local StencilPack = require(script.Parent.StencilPack)

export type StencilShape = string

export type StencilDefinition = {
	id: string,
	name: string,
	category: string,
	shape: StencilShape,
	-- Optional Roblox image (white-on-transparent). When set, StencilView prefers it.
	image: string?,
}

-- Starter kit first in the picker: circle, triangle, square, line, rectangle.
local FREE_ORDER = { "circle", "tri", "frame", "bar", "rect" }

local catalogue: { StencilDefinition } = {}
local packed: { [string]: boolean } = {}
for _, id in FREE_ORDER do
	local entry = StencilPack.byId[id]
	if entry ~= nil then
		table.insert(catalogue, {
			id = entry.id,
			name = entry.name,
			category = "shapes",
			shape = entry.id,
		})
		packed[id] = true
	end
end
for _, entry in StencilPack.entries do
	if packed[entry.id] ~= true then
		table.insert(catalogue, {
			id = entry.id,
			name = entry.name,
			category = "shapes",
			shape = entry.id,
		})
	end
end

-- Older marks still resolve. They are not shown in the shape panel.
local legacy: { StencilDefinition } = {
	{ id = "disc", name = "Dot", category = "shapes", shape = "disc" },
	{ id = "ring", name = "Ring", category = "shapes", shape = "ring" },
	{ id = "oval", name = "Oval", category = "shapes", shape = "oval" },
	{ id = "square", name = "Square", category = "shapes", shape = "square" },
	{ id = "diamond", name = "Diamond", category = "shapes", shape = "diamond" },
	{ id = "triangle", name = "Triangle", category = "shapes", shape = "triangle" },
	{ id = "band", name = "Bar", category = "lines", shape = "band" },
	{ id = "line", name = "Line", category = "lines", shape = "line" },
	{ id = "cross", name = "Cross", category = "symbols", shape = "cross" },
	{ id = "chevron", name = "Chevron", category = "symbols", shape = "chevron" },
	{ id = "spark", name = "Star", category = "symbols", shape = "spark" },
	{ id = "burst", name = "Burst", category = "symbols", shape = "burst" },
	{ id = "heart", name = "Heart", category = "symbols", shape = "heart" },
	{ id = "bolt", name = "Bolt", category = "symbols", shape = "bolt" },
	{ id = "drop", name = "Drop", category = "shapes", shape = "drop" },
	{ id = "banner", name = "Banner", category = "symbols", shape = "banner" },
	{ id = "steps", name = "Steps", category = "lines", shape = "steps" },
	{ id = "corner", name = "Corner", category = "lines", shape = "corner" },
	{ id = "bar", name = "Line", category = "shapes", shape = "bar" },
	{ id = "flower", name = "Flower", category = "shapes", shape = "flower" },
	{ id = "bannerline", name = "Banner", category = "shapes", shape = "bannerline" },
	{ id = "stepline", name = "Steps", category = "shapes", shape = "stepline" },
	{ id = "arc", name = "Arc", category = "shapes", shape = "arc" },
	{ id = "blob", name = "Blob", category = "shapes", shape = "blob" },
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
