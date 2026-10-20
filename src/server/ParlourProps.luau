--!strict

-- Clones the free Creator Store props that were actually inserted and measured.
-- Scripts, sounds, and interface objects are removed before a prop can enter the room.
-- If a prop is missing, the procedural stand-in stays where it is.

local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local Surfaces = require(script.Parent.Surfaces)

local PREFIX = "[InkMasters]"

-- Texture values read from the Decal instances after insert, not guessed.
local ParlourProps = {
	FLASH_SHEET = "rbxthumb://type=Asset&id=18225257498&w=420&h=420",
	ROSE = "rbxthumb://type=Asset&id=72209360850042&w=420&h=420",
	JAPANESE = "rbxthumb://type=Asset&id=131062865342765&w=420&h=420",
}

local IDS: { [string]: number } = {
	BarberChair = 2545463897,
	CasterSeat = 13376928707,
	ToolCabinet = 110380403791099,
	TableLamp = 5680874848,
}

local MARKERS: { [string]: string } = {
	BarberChair = "chair_kleiner03a",
	CasterSeat = "Seat",
}

local NAMES = { "BarberChair", "CasterSeat", "ToolCabinet", "TableLamp" }

local templates: { [string]: Model } = {}
local loading = false
local loaded = false

local function warnProp(name: string, detail: string)
	warn(`{PREFIX} {name} stayed procedural ({detail})`)
end

local function sanitize(root: Instance)
	local doomed: { Instance } = {}
	for _, descendant in root:GetDescendants() do
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("LayerCollector")
			or descendant:IsA("GuiBase2d")
			or descendant:IsA("Sound")
			or descendant:IsA("Dialog")
			or descendant:IsA("RemoteEvent")
			or descendant:IsA("RemoteFunction")
			or descendant:IsA("UnreliableRemoteEvent")
			or descendant:IsA("Camera")
			or descendant:IsA("Tool")
			or descendant:IsA("ProximityPrompt")
			or descendant:IsA("ClickDetector")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Fire")
			or descendant:IsA("Smoke")
			or descendant:IsA("Sparkles")
			or descendant:IsA("InputContext")
			or descendant:IsA("InputAction")
			or descendant:IsA("InputBinding")
		then
			table.insert(doomed, descendant)
		end
	end
	for _, descendant in doomed do
		descendant:Destroy()
	end

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.Massless = true
			if descendant:IsA("Seat") then
				descendant.CanCollide = true
				descendant.CanTouch = true
				descendant.CanQuery = true
				descendant.Disabled = false
			else
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
	end
end

local function unwrap(container: Instance): Model?
	local model = Instance.new("Model")
	for _, child in container:GetChildren() do
		child.Parent = model
	end
	if container ~= model then
		container:Destroy()
	end
	if #model:GetChildren() == 0 then
		model:Destroy()
		return nil
	end
	return model
end

local function fromImport(name: string): Model?
	local folder = ServerStorage:FindFirstChild("ParlourImport")
	if folder == nil then
		return nil
	end
	local source = folder:FindFirstChild(name)
	if source == nil or not source:IsA("Model") then
		return nil
	end
	return source:Clone()
end

local function fromAsset(name: string): Model?
	local assetId = IDS[name]
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or asset == nil then
		warnProp(name, `LoadAsset {assetId} failed`)
		return nil
	end
	if typeof(asset) ~= "Instance" then
		warnProp(name, "LoadAsset returned no instance")
		return nil
	end
	return unwrap(asset)
end

local function cacheOf(): Folder
	local existing = ServerStorage:FindFirstChild("ParlourProps")
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "ParlourProps"
	folder.Parent = ServerStorage
	return folder
end

local function ensureLoaded()
	if loaded or loading then
		while loading do
			task.wait(0.05)
		end
		return
	end
	loading = true
	local cache = cacheOf()
	for _, name in NAMES do
		local model = fromImport(name) or fromAsset(name)
		if model == nil then
			warnProp(name, "not in ServerStorage.ParlourImport and not loaded")
		else
			sanitize(model)
			model.Name = name
			model.Parent = cache
			templates[name] = model
		end
	end
	loaded = true
	loading = false
end

local function alignMarker(clone: Model, markerName: string, face: Vector3)
	local marker = clone:FindFirstChild(markerName, true)
	if marker == nil or not marker:IsA("BasePart") then
		return
	end
	local look = marker.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local flatFace = Vector3.new(face.X, 0, face.Z)
	if flatLook.Magnitude < 0.05 or flatFace.Magnitude < 0.05 then
		return
	end
	local current = math.atan2(flatLook.X, flatLook.Z)
	local desired = math.atan2(flatFace.X, flatFace.Z)
	local delta = desired - current
	local pivot = clone:GetPivot()
	clone:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, delta, 0) * CFrame.new(-pivot.Position) * pivot)
end

local function matchYaw(clone: Model, yaw: number)
	local pivot = clone:GetPivot()
	local _, current = pivot:ToOrientation()
	local delta = yaw - current
	clone:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, delta, 0) * CFrame.new(-pivot.Position) * pivot)
end

local function dropToFloor(clone: Model, floorPosition: Vector3)
	local boundsCF, boundsSize = clone:GetBoundingBox()
	local bottom = boundsCF.Position - Vector3.new(0, boundsSize.Y / 2, 0)
	local shift = Vector3.new(floorPosition.X - bottom.X, floorPosition.Y - bottom.Y, floorPosition.Z - bottom.Z)
	clone:PivotTo(clone:GetPivot() + shift)
end

local function addBlock(clone: Model, size: Vector3)
	local boundsCF, boundsSize = clone:GetBoundingBox()
	local block = Instance.new("Part")
	block.Name = "PropBlock"
	block.Anchored = true
	block.CanTouch = false
	block.CanQuery = false
	block.CanCollide = true
	block.Transparency = 1
	block.CastShadow = false
	block.Size = size
	block.CFrame =
		CFrame.new(boundsCF.Position.X, boundsCF.Position.Y - boundsSize.Y / 2 + size.Y / 2, boundsCF.Position.Z)
	block.Parent = clone
end

local function scaleToHeight(clone: Model, height: number)
	local _, boundsSize = clone:GetBoundingBox()
	if boundsSize.Y < 0.05 then
		return
	end
	local ok = pcall(function()
		clone:ScaleTo(height / boundsSize.Y)
	end)
	if not ok then
		warnProp(clone.Name, "could not scale")
	end
end

function ParlourProps.place(
	name: string,
	parent: Instance,
	floor: CFrame,
	face: Vector3?,
	height: number?,
	solid: boolean?,
	yawBias: number?
): Model?
	ensureLoaded()
	local template = templates[name]
	if template == nil then
		return nil
	end
	local clone = template:Clone()
	clone.Name = name
	clone.Parent = parent
	if height ~= nil then
		scaleToHeight(clone, height)
	end
	local markerName = MARKERS[name]
	if markerName ~= nil and face ~= nil then
		alignMarker(clone, markerName, face)
	else
		local _, stationYaw = floor:ToOrientation()
		matchYaw(clone, stationYaw + math.rad(yawBias or 0))
	end
	dropToFloor(clone, floor.Position)
	if solid == true then
		local _, boundsSize = clone:GetBoundingBox()
		addBlock(clone, Vector3.new(boundsSize.X * 0.72, boundsSize.Y * 0.92, boundsSize.Z * 0.72))
	end
	return clone
end

local function dressLamp(clone: Model)
	-- Creator Store lamps arrive with a near-black pebble inner dome that reads as a
	-- solid black blob once SurfaceAppearance is gone. Reskin every piece here.
	local cream = Color3.fromRGB(255, 236, 214)
	local warm = Color3.fromRGB(255, 214, 170)
	local metal = Color3.fromRGB(168, 170, 172)
	for _, part in clone:GetDescendants() do
		if not part:IsA("BasePart") or part.Name == "LampAim" or part.Name == "PropBlock" then
			continue
		end
		local name = string.lower(part.Name)
		if string.find(name, "innerlampdome", 1, true) then
			Surfaces.apply(part, "glass", cream)
			part.Transparency = 0.35
			part.Reflectance = 0.2
			part.CastShadow = false
		elseif string.find(name, "outerlampdome", 1, true) or string.find(name, "coloredlampdome", 1, true) then
			Surfaces.apply(part, "glass", cream)
			part.Transparency = 0.15
			part.Reflectance = 0.12
		elseif string.find(name, "lightbulb", 1, true) or string.find(name, "coloredneon", 1, true) then
			Surfaces.apply(part, "neon", warm)
			part.CastShadow = false
		elseif
			string.find(name, "pole", 1, true)
			or string.find(name, "joint", 1, true)
			or string.find(name, "socket", 1, true)
			or string.find(name, "cage", 1, true)
			or string.find(name, "nut", 1, true)
			or string.find(name, "hold", 1, true)
			or string.find(name, "base", 1, true)
			or string.find(name, "transformer", 1, true)
			or string.find(name, "switch", 1, true)
			or string.find(name, "rotating", 1, true)
		then
			Surfaces.apply(part, "powder", metal)
		end
	end
end

local function aimLamp(clone: Model, target: Vector3)
	dressLamp(clone)
	local bulb = clone:FindFirstChild("LightBulb", true)
	local origin = if bulb ~= nil and bulb:IsA("BasePart") then bulb.Position else clone:GetPivot().Position
	local aim = Instance.new("Part")
	aim.Name = "LampAim"
	aim.Anchored = true
	aim.CanCollide = false
	aim.CanTouch = false
	aim.CanQuery = false
	aim.Transparency = 1
	aim.CastShadow = false
	aim.Size = Vector3.new(0.2, 0.2, 0.2)
	aim.CFrame = CFrame.lookAt(origin, target)
	aim.Parent = clone

	local spot = Instance.new("SpotLight")
	spot.Name = "TaskSpot"
	spot.Face = Enum.NormalId.Front
	spot.Brightness = 1.8
	spot.Range = 14
	spot.Angle = 52
	-- The overhead task panel in each bay casts the shadows; this lamp only adds fill.
	spot.Color = Color3.fromRGB(255, 246, 236)
	spot.Shadows = false
	spot.Parent = aim

	if bulb ~= nil then
		local glow = bulb:FindFirstChildOfClass("PointLight")
		if glow ~= nil then
			glow.Brightness = 0.6
			glow.Range = 8
			glow.Shadows = false
			glow.Color = Color3.fromRGB(255, 240, 224)
		end
	end
end

local function dressCabinet(root: Instance)
	-- Keep Creator Store SurfaceAppearance when present; only force parlour finishes on
	-- plain MeshParts so closing the SA does not leave a black silhouette.
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "PropBlock" then
			local hasLook = descendant:FindFirstChildOfClass("SurfaceAppearance") ~= nil
			if hasLook and descendant:IsA("MeshPart") then
				-- Soften the stock look without wiping the texture maps.
				descendant.Color = Color3.fromRGB(255, 250, 244)
				continue
			end
			local name = string.lower(descendant.Name)
			if string.find(name, "handle", 1, true) or string.find(name, "lock", 1, true) then
				Surfaces.apply(descendant, "steel")
			elseif string.find(name, "wheel", 1, true) then
				Surfaces.apply(descendant, "rubber", Color3.fromRGB(36, 36, 40))
			else
				Surfaces.apply(descendant, "powder", Color3.fromRGB(236, 236, 232))
			end
		end
	end
end

local function dropRig(station: Model, rigName: string)
	local rig = station:FindFirstChild(rigName)
	if rig ~= nil then
		rig:Destroy()
	end
end

-- Yields until Creator Store props are placed so layout baking can include them.
function ParlourProps.dress(lobby: Model)
	local ok, err = pcall(function()
		ensureLoaded()
		local stations = lobby:FindFirstChild("Stations")
		if stations == nil then
			return
		end
		for _, station in stations:GetChildren() do
			if not station:IsA("Model") then
				continue
			end
			local pivot = station:GetPivot()
			local floorAt = function(offset: Vector3): CFrame
				return pivot * CFrame.new(offset)
			end

			local chair = ParlourProps.place(
				"BarberChair",
				station,
				floorAt(Vector3.new(0.15, 0, 0.15)),
				pivot.LookVector,
				nil,
				true,
				nil
			)
			if chair ~= nil then
				dropRig(station, "RigBed")
			end

			local stool = ParlourProps.place(
				"CasterSeat",
				station,
				floorAt(Vector3.new(2.85, 0, 0.45)),
				-pivot.RightVector,
				2.05,
				false,
				nil
			)
			if stool ~= nil then
				local seat = stool:FindFirstChild("Seat", true)
				if seat ~= nil and seat:IsA("Seat") then
					seat.Name = "ArtistStool"
				end
				dropRig(station, "RigStool")
			end

			local cabinet =
				ParlourProps.place("ToolCabinet", station, floorAt(Vector3.new(-4.55, 0, 2.55)), nil, nil, true, 135)
			if cabinet ~= nil then
				dressCabinet(cabinet)
				dropRig(station, "RigTray")
				local boundsCF, boundsSize = cabinet:GetBoundingBox()
				local top = boundsCF.Position.Y + boundsSize.Y / 2
				local slot = 0
				for _, child in station:GetChildren() do
					if child.Name == "InkBottle" and child:IsA("BasePart") then
						slot += 1
						local spin = child.CFrame.Rotation
						child.CFrame = CFrame.new(
							boundsCF.Position.X + (slot - 2) * 0.42,
							top + 0.16,
							boundsCF.Position.Z + 0.2
						) * spin
					end
				end
			end

			local lamp =
				ParlourProps.place("TableLamp", station, floorAt(Vector3.new(2.15, 0, -2.35)), nil, 3.3, false, 180)
			if lamp ~= nil then
				aimLamp(lamp, floorAt(Vector3.new(0.1, 2.4, 0.2)).Position)
				dropRig(station, "RigLamp")
			end
		end
	end)
	if not ok then
		warn(`{PREFIX} Prop dressing failed: {err}`)
	end
end

return ParlourProps
