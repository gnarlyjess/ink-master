--!strict

-- Lazy Blender mesh chunks. Each chunk stays under Roblox's script source limit.
-- Only the requested species is joined, so play startup does not load every plant at once.

local chunks: { [string]: { string } } = {
	PlantFig = { "Chunk01", "Chunk02" },
	PlantSnake = { "Chunk03", "Chunk04" },
	PlantFern = { "Chunk05", "Chunk06" },
	PlantHang = { "Chunk07", "Chunk08", "Chunk09" },
	PlantSucculent = { "Chunk10", "Chunk11" },
}

local cache: { [string]: string } = {}

local function join(names: { string }): string
	local pieces = table.create(#names)
	for index, name in names do
		local module = script:FindFirstChild(name)
		if module == nil or not module:IsA("ModuleScript") then
			error(`Missing plant mesh chunk {name}`)
		end
		pieces[index] = require(module)
	end
	return table.concat(pieces)
end

local PlantMesh = {}

function PlantMesh.get(species: string): string?
	local cached = cache[species]
	if cached ~= nil then
		return cached
	end
	local names = chunks[species]
	if names == nil then
		return nil
	end
	local body = join(names)
	cache[species] = body
	return body
end

return PlantMesh
