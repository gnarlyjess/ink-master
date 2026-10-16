--!strict

-- The saved tattoo is a list of marks. The server rebuilds a clean copy from the client payload.

local GameConfig = require(script.Parent.GameConfig)
local StencilDefinitions = require(script.Parent.StencilDefinitions)

export type RgbColor = {
	r: number,
	g: number,
	b: number,
}

export type DesignElement = {
	stencilId: string,
	x: number,
	y: number,
	rotation: number,
	scale: number,
	color: RgbColor,
}

export type TattooDesign = {
	version: number,
	region: string,
	elements: { DesignElement },
}

local DesignDocument = {}

local function readUnit(value: any): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

function DesignDocument.createEmpty(): TattooDesign
	return {
		version = 1,
		region = GameConfig.getDesignRegion(),
		elements = {},
	}
end

function DesignDocument.sanitize(payload: any, roundId: number): TattooDesign?
	if typeof(payload) ~= "table" then
		return nil
	end
	if payload.roundId ~= roundId or payload.region ~= GameConfig.getDesignRegion() then
		return nil
	end
	if typeof(payload.elements) ~= "table" then
		return nil
	end

	local count = #payload.elements
	if count > GameConfig.getMaxElements() then
		return nil
	end

	local elements: { DesignElement } = {}
	for index = 1, count do
		local item = payload.elements[index]
		if typeof(item) ~= "table" or typeof(item.stencilId) ~= "string" then
			return nil
		end
		if StencilDefinitions.get(item.stencilId) == nil then
			return nil
		end

		local x = readUnit(item.x)
		local y = readUnit(item.y)
		local rotation = readUnit(item.rotation)
		local scale = readUnit(item.scale)
		if x == nil or y == nil or rotation == nil or scale == nil then
			return nil
		end
		if x < 0 or x > 1 or y < 0 or y > 1 then
			return nil
		end
		if scale < GameConfig.getMinElementScale() or scale > GameConfig.getMaxElementScale() then
			return nil
		end
		if math.abs(rotation) > 1080 then
			return nil
		end
		if typeof(item.color) ~= "table" then
			return nil
		end

		local r = readUnit(item.color.r)
		local g = readUnit(item.color.g)
		local b = readUnit(item.color.b)
		if r == nil or g == nil or b == nil then
			return nil
		end
		if r < 0 or r > 1 or g < 0 or g > 1 or b < 0 or b > 1 then
			return nil
		end

		table.insert(elements, {
			stencilId = item.stencilId,
			x = x,
			y = y,
			rotation = rotation,
			scale = scale,
			color = { r = r, g = g, b = b },
		})
	end

	return {
		version = 1,
		region = GameConfig.getDesignRegion(),
		elements = elements,
	}
end

return DesignDocument
