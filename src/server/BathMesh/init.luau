--!strict

-- Blender restroom fixtures, one chunk per piece so each stays under the script source limit.

local chunks: { [string]: string } = {
	BathToilet = "Toilet",
	BathVanity = "Vanity",
	BathMirror = "Mirror",
	BathTowel = "Towel",
	BathPendant = "Pendant",
}

local cache: { [string]: string } = {}

local BathMesh = {}

function BathMesh.get(name: string): string?
	local cached = cache[name]
	if cached ~= nil then
		return cached
	end
	local chunk = chunks[name]
	if chunk == nil then
		return nil
	end
	local module = script:FindFirstChild(chunk)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local body = require(module)
	if type(body) ~= "string" then
		return nil
	end
	cache[name] = body
	return body
end

return BathMesh
