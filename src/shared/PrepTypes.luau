--!strict

-- Prep-station state: dirt patches + hair grid. Leftovers carry into tattoo.

local PrepMasks = require(script.Parent.PrepMasks)

export type PrepTool = "soap" | "cloth" | "razor"

export type DirtPatch = {
	id: number,
	x: number, -- 0..1 canvas
	y: number,
	r: number, -- radius 0..1 relative to min(canvas)
	soaped: boolean,
	cleared: boolean,
}

export type PrepView = {
	regionId: string,
	tool: PrepTool,
	step: PrepTool | "done",
	dirt: { DirtPatch },
	-- Row-major hair cells: 1 = present, 0 = shaved. cols * rows entries.
	hair: { number },
	hairCols: number,
	hairRows: number,
	dirtyLeft: number,
	hairLeft: number,
}

local PrepTypes = {}

PrepTypes.HAIR_COLS = PrepMasks.COLS
PrepTypes.HAIR_ROWS = PrepMasks.ROWS
PrepTypes.DIRT_COUNT = 16
PrepTypes.SOAP_RADIUS = 0.065
PrepTypes.CLOTH_RADIUS = 0.07
PrepTypes.RAZOR_RADIUS = 0.044

local function hashSeed(userId: number, regionId: string): number
	local h = userId % 100000
	for i = 1, #regionId do
		h = (h * 33 + string.byte(regionId, i)) % 1000003
	end
	return h
end

local function nextRand(state: { n: number }): number
	state.n = (state.n * 1103515245 + 12345) % 2147483648
	return state.n / 2147483648
end

local function skinCellList(regionId: string): { number }
	local mask = PrepMasks.get(regionId)
	local list: { number } = {}
	if mask == nil then
		return list
	end
	for i, bit in mask do
		if bit == 1 then
			table.insert(list, i)
		end
	end
	return list
end

function PrepTypes.makeDirt(userId: number, regionId: string): { DirtPatch }
	local rng = { n = hashSeed(userId, regionId) }
	local cols = PrepTypes.HAIR_COLS
	local rows = PrepTypes.HAIR_ROWS
	local skin = skinCellList(regionId)
	local patches: { DirtPatch } = {}
	if #skin == 0 then
		return patches
	end
	local used: { [number]: boolean } = {}
	local guard = 0
	while #patches < PrepTypes.DIRT_COUNT and guard < 240 do
		guard += 1
		local cell = skin[1 + math.floor(nextRand(rng) * #skin)]
		if used[cell] then
			continue
		end
		used[cell] = true
		local col = ((cell - 1) % cols) + 1
		local row = math.floor((cell - 1) / cols) + 1
		local x = (col - 0.5) / cols + (nextRand(rng) - 0.5) * 0.55 / cols
		local y = (row - 0.5) / rows + (nextRand(rng) - 0.5) * 0.55 / rows
		table.insert(patches, {
			id = #patches + 1,
			x = math.clamp(x, 0.08, 0.92),
			y = math.clamp(y, 0.1, 0.9),
			r = 0.016 + nextRand(rng) * 0.018,
			soaped = false,
			cleared = false,
		})
	end
	return patches
end

function PrepTypes.makeHair(userId: number?, regionId: string?): { number }
	local seed = if userId ~= nil and regionId ~= nil then hashSeed(userId, regionId .. ":hair") else 424242
	local rng = { n = seed }
	local cols = PrepTypes.HAIR_COLS
	local rows = PrepTypes.HAIR_ROWS
	local total = cols * rows
	local cells: { number } = table.create(total, 0)
	local region = regionId or ""
	local mask = if region ~= "" then PrepMasks.get(region) else nil

	local function interior(col: number, row: number): boolean
		if mask == nil then
			return true
		end
		local function bit(c: number, r: number): boolean
			if c < 1 or r < 1 or c > cols or r > rows then
				return false
			end
			return mask[(r - 1) * cols + c] == 1
		end
		return bit(col, row) and bit(col - 1, row) and bit(col + 1, row) and bit(col, row - 1) and bit(col, row + 1)
	end
	for row = 1, rows do
		for col = 1, cols do
			local index = PrepTypes.cellIndex(col, row)
			if not interior(col, row) then
				continue
			end
			local nx = (col - 0.5) / cols
			local ny = (row - 0.5) / rows
			-- Dense body hair on the limb only — denser mid/lower mass.
			local dens = 0.55 + 0.42 * (1 - math.abs(nx - 0.5) * 1.4) * (0.3 + 0.7 * ny)
			if dens > 0 and nextRand(rng) < dens then
				cells[index] = 1
			end
		end
	end
	return cells
end

function PrepTypes.countDirtLeft(dirt: { DirtPatch }): number
	local n = 0
	for _, patch in dirt do
		if not patch.cleared then
			n += 1
		end
	end
	return n
end

function PrepTypes.countHairLeft(hair: { number }): number
	local n = 0
	for _, cell in hair do
		if cell > 0.5 then
			n += 1
		end
	end
	return n
end

function PrepTypes.currentStep(dirt: { DirtPatch }, hair: { number }): PrepTool | "done"
	local dirty = PrepTypes.countDirtLeft(dirt)
	if dirty > 0 then
		local needsSoap = false
		for _, patch in dirt do
			if not patch.cleared and not patch.soaped then
				needsSoap = true
				break
			end
		end
		if needsSoap then
			return "soap"
		end
		return "cloth"
	end
	if PrepTypes.countHairLeft(hair) > 0 then
		return "razor"
	end
	return "done"
end

function PrepTypes.cellIndex(col: number, row: number): number
	return (row - 1) * PrepTypes.HAIR_COLS + col
end

function PrepTypes.hitDirt(dirt: { DirtPatch }, x: number, y: number, radius: number): { DirtPatch }
	local hits: { DirtPatch } = {}
	for _, patch in dirt do
		if patch.cleared then
			continue
		end
		local dx = patch.x - x
		local dy = patch.y - y
		if dx * dx + dy * dy <= (patch.r + radius) * (patch.r + radius) then
			table.insert(hits, patch)
		end
	end
	return hits
end

function PrepTypes.shaveAt(hair: { number }, x: number, y: number, radius: number): number
	local shaved = 0
	local cols = PrepTypes.HAIR_COLS
	local rows = PrepTypes.HAIR_ROWS
	-- Clear any cell whose box overlaps the brush (pad matches the paint wipe radius).
	local halfW = 0.5 / cols
	local halfH = 0.5 / rows
	local reach = radius * 1.35
	local reach2 = reach * reach
	for row = 1, rows do
		for col = 1, cols do
			local index = PrepTypes.cellIndex(col, row)
			if hair[index] == nil or hair[index] < 0.5 then
				continue
			end
			local cx = (col - 0.5) / cols
			local cy = (row - 0.5) / rows
			local nearestX = math.clamp(x, cx - halfW, cx + halfW)
			local nearestY = math.clamp(y, cy - halfH, cy + halfH)
			local dx = nearestX - x
			local dy = nearestY - y
			if dx * dx + dy * dy <= reach2 then
				hair[index] = 0
				shaved += 1
			end
		end
	end
	return shaved
end

function PrepTypes.cloneView(view: PrepView): PrepView
	local dirt: { DirtPatch } = table.create(#view.dirt)
	for i, patch in view.dirt do
		dirt[i] = {
			id = patch.id,
			x = patch.x,
			y = patch.y,
			r = patch.r,
			soaped = patch.soaped,
			cleared = patch.cleared,
		}
	end
	local hair: { number } = table.create(#view.hair)
	for i, cell in view.hair do
		hair[i] = cell
	end
	return {
		regionId = view.regionId,
		tool = view.tool,
		step = view.step,
		dirt = dirt,
		hair = hair,
		hairCols = view.hairCols,
		hairRows = view.hairRows,
		dirtyLeft = view.dirtyLeft,
		hairLeft = view.hairLeft,
	}
end

-- Keep any local progress the server hasn't echoed yet (shaved / soaped / wiped).
function PrepTypes.mergeProgress(base: PrepView, localView: PrepView): PrepView
	if base.regionId ~= localView.regionId then
		return PrepTypes.cloneView(base)
	end
	local merged = PrepTypes.cloneView(base)
	for i, cell in localView.hair do
		if cell < 0.5 then
			merged.hair[i] = 0
		end
	end
	for i, localPatch in localView.dirt do
		local patch = merged.dirt[i]
		if patch == nil then
			continue
		end
		if localPatch.soaped then
			patch.soaped = true
		end
		if localPatch.cleared then
			patch.cleared = true
		end
	end
	merged.dirtyLeft = PrepTypes.countDirtLeft(merged.dirt)
	merged.hairLeft = PrepTypes.countHairLeft(merged.hair)
	merged.step = PrepTypes.currentStep(merged.dirt, merged.hair)
	-- Server wins for the selected tool — never block cloth/razor switches.
	merged.tool = base.tool
	return merged
end

function PrepTypes.readView(payload: any): PrepView?
	if typeof(payload) ~= "table" then
		return nil
	end
	if typeof(payload.regionId) ~= "string" or typeof(payload.tool) ~= "string" then
		return nil
	end
	if typeof(payload.step) ~= "string" or typeof(payload.dirt) ~= "table" or typeof(payload.hair) ~= "table" then
		return nil
	end
	local hairCols = payload.hairCols
	local hairRows = payload.hairRows
	if typeof(hairCols) ~= "number" or typeof(hairRows) ~= "number" then
		return nil
	end
	local dirt: { DirtPatch } = {}
	for _, raw in payload.dirt do
		if typeof(raw) ~= "table" then
			continue
		end
		if typeof(raw.id) ~= "number" or typeof(raw.x) ~= "number" or typeof(raw.y) ~= "number" or typeof(raw.r) ~= "number" then
			continue
		end
		if typeof(raw.soaped) ~= "boolean" or typeof(raw.cleared) ~= "boolean" then
			continue
		end
		table.insert(dirt, {
			id = raw.id,
			x = raw.x,
			y = raw.y,
			r = raw.r,
			soaped = raw.soaped,
			cleared = raw.cleared,
		})
	end
	local hair: { number } = {}
	for i, value in payload.hair do
		if typeof(value) == "number" then
			hair[i] = if value > 0.5 then 1 else 0
		end
	end
	local dirtyLeft = if typeof(payload.dirtyLeft) == "number" then payload.dirtyLeft else PrepTypes.countDirtLeft(dirt)
	local hairLeft = if typeof(payload.hairLeft) == "number" then payload.hairLeft else PrepTypes.countHairLeft(hair)
	return {
		regionId = payload.regionId,
		tool = payload.tool :: PrepTool,
		step = payload.step :: PrepTool | "done",
		dirt = dirt,
		hair = hair,
		hairCols = hairCols,
		hairRows = hairRows,
		dirtyLeft = dirtyLeft,
		hairLeft = hairLeft,
	}
end

return PrepTypes
