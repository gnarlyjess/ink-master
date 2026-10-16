--!strict

-- Starter shapes for the forearm prototype. Ids stay stable.
-- Later rows can point at an uploaded image without changing the editor.

export type StencilShape = "disc" | "ring" | "band" | "diamond" | "cross" | "spark" | "heart"

export type StencilDefinition = {
	id: string,
	name: string,
	category: string,
	shape: StencilShape,
}

local catalogue: { StencilDefinition } = {
	{ id = "disc", name = "Dot", category = "shapes", shape = "disc" },
	{ id = "ring", name = "Ring", category = "shapes", shape = "ring" },
	{ id = "band", name = "Band", category = "lines", shape = "band" },
	{ id = "diamond", name = "Diamond", category = "shapes", shape = "diamond" },
	{ id = "cross", name = "Cross", category = "symbols", shape = "cross" },
	{ id = "spark", name = "Spark", category = "symbols", shape = "spark" },
	{ id = "heart", name = "Heart", category = "symbols", shape = "heart" },
}

local byId: { [string]: StencilDefinition } = {}
for _, stencil in catalogue do
	byId[stencil.id] = stencil
end

local StencilDefinitions = {
	all = catalogue,
}

function StencilDefinitions.get(id: string): StencilDefinition?
	return byId[id]
end

return StencilDefinitions
