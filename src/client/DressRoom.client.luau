--!strict

-- Editable meshes saved in the place do not replicate into a play client, so the
-- server copies render as the blank checker. This rebuilds them locally from the
-- mesh buffers stored in ReplicatedStorage.DressBins.

-- Skip the StarterPlayerScripts pass when RunContext is Client (boots twice).
local Players = game:GetService("Players")
if not script:IsDescendantOf(Players) then
	return
end

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ALIASES = {
	PalmB = "Palm",
	IvyB = "Ivy",
}
local SKIP = {
	WoodSlab = true,
	Plank = true,
}
local ORDER = {
	Shelf = 1,
	NeonAmber = 2,
	Cabinet = 3,
	Palm = 4,
	PalmB = 5,
	Ivy = 6,
	IvyB = 7,
	Pots = 8,
	Skull = 9,
	Clock = 10,
	NeonViolet = 11,
	Frog = 12,
}

local function buildMesh(data: string, textureId: string): MeshPart
	local nvert, nface, _mode, pos = string.unpack("<I4I4I4", data, 5)
	local verts = table.create(nvert)
	for index = 1, nvert do
		local x, y, z
		x, y, z, pos = string.unpack("<fff", data, pos)
		verts[index] = Vector3.new(x, y, z)
	end
	local uvs = table.create(nface * 3)
	for index = 1, nface * 3 do
		local u, v
		u, v, pos = string.unpack("<ff", data, pos)
		uvs[index] = Vector2.new(u, v)
	end
	local indices = table.create(nface * 3)
	for index = 1, nface * 3 do
		local vertexIndex
		vertexIndex, pos = string.unpack("<I4", data, pos)
		indices[index] = vertexIndex + 1
	end

	local editable = AssetService:CreateEditableMesh()
	for faceIndex = 1, nface do
		local base = (faceIndex - 1) * 3
		local faceId = editable:AddTriangle(
			editable:AddVertex(verts[indices[base + 1]]),
			editable:AddVertex(verts[indices[base + 2]]),
			editable:AddVertex(verts[indices[base + 3]])
		)
		local uvIds = editable:GetFaceUVs(faceId)
		editable:SetUV(uvIds[1], uvs[base + 1])
		editable:SetUV(uvIds[2], uvs[base + 2])
		editable:SetUV(uvIds[3], uvs[base + 3])
		if faceIndex % 2000 == 0 then
			task.wait()
		end
	end

	local mesh = AssetService:CreateMeshPartAsync(Content.fromObject(editable))
	mesh.TextureID = textureId
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.DoubleSided = true
	mesh.Material = Enum.Material.Fabric
	mesh.Color = Color3.new(1, 1, 1)
	mesh.CastShadow = true
	return mesh
end

local function dress()
	local bins = ReplicatedStorage:WaitForChild("DressBins", 20)
	local sourceFolder = Workspace:WaitForChild("MeshyDress", 20)
	if bins == nil or sourceFolder == nil or Workspace:FindFirstChild("DressLocal") then
		return
	end

	local shown = Instance.new("Folder")
	shown.Name = "DressLocal"
	shown.Parent = Workspace

	local parts = {}
	for _, child in sourceFolder:GetChildren() do
		if child:IsA("MeshPart") then
			child.LocalTransparencyModifier = 1
			table.insert(parts, child)
		end
	end
	table.sort(parts, function(a, b)
		return (ORDER[a.Name] or 50) < (ORDER[b.Name] or 50)
	end)

	for _, part in parts do
		if SKIP[part.Name] then
			continue
		end
		local key = ALIASES[part.Name] or part.Name
		local chunks = {}
		local chunkIndex = 1
		while true do
			local piece = bins:FindFirstChild(key .. "_" .. chunkIndex)
			if piece == nil or not piece:IsA("StringValue") then
				break
			end
			table.insert(chunks, piece.Value)
			chunkIndex += 1
		end
		local data = table.concat(chunks)
		if string.sub(data, 1, 4) ~= "MSH1" then
			continue
		end
		local mesh = buildMesh(data, part.TextureID)
		mesh.Name = part.Name
		mesh.Size = part.Size
		mesh.CFrame = part.CFrame
		for _, child in part:GetChildren() do
			if child:IsA("Light") then
				local light = child:Clone()
				light.Parent = mesh
				child:Destroy()
			end
		end
		mesh.Parent = shown
		task.wait()
	end
end

task.spawn(dress)
