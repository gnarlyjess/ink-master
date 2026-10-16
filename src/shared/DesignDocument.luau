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
	line: RgbColor,
	fill: boolean,
	outline: boolean,
	thickness: number,
	opacity: number,
	flip: boolean,
}

export type TattooDesign = {
	version: number,
	region: string,
	elements: { DesignElement },
}

local DesignDocument = {}

local MIN_THICKNESS = 1
local MAX_THICKNESS = 10
local MIN_OPACITY = 0.2

local function readUnit(value: any): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function readColor(value: any, fallback: RgbColor): RgbColor
	if typeof(value) ~= "table" then
		return fallback
	end
	local r = readUnit(value.r)
	local g = readUnit(value.g)
	local b = readUnit(value.b)
	if r == nil or g == nil or b == nil then
		return fallback
	end
	if r < 0 or r > 1 or g < 0 or g > 1 or b < 0 or b > 1 then
		return fallback
	end
	return { r = r, g = g, b = b }
end

local function readThickness(value: any): number
	local thickness = readUnit(value)
	if thickness == nil then
		return 1
	end
	return math.clamp(math.floor(thickness + 0.5), MIN_THICKNESS, MAX_THICKNESS)
end

local function readOpacity(value: any): number
	local opacity = readUnit(value)
	if opacity == nil then
		return 1
	end
	return math.clamp(opacity, MIN_OPACITY, 1)
end

function DesignDocument.clampThickness(value: number): number
	return math.clamp(math.floor(value + 0.5), MIN_THICKNESS, MAX_THICKNESS)
end

function DesignDocument.clampOpacity(value: number): number
	return math.clamp(value, MIN_OPACITY, 1)
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
	local region = payload.region
	if payload.roundId ~= roundId then
		return nil
	end
	if typeof(region) ~= "string" or not GameConfig.isDesignRegion(region) then
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
		local color = readColor(item.color, { r = -1, g = 0, b = 0 })
		if color.r < 0 then
			return nil
		end
		local fill = if typeof(item.fill) == "boolean" then item.fill else true
		local outline = if typeof(item.outline) == "boolean" then item.outline else false
		if not fill and not outline then
			fill = true
		end

		table.insert(elements, {
			stencilId = item.stencilId,
			x = x,
			y = y,
			rotation = rotation,
			scale = scale,
			color = color,
			line = readColor(item.line, color),
			fill = fill,
			outline = outline,
			thickness = readThickness(item.thickness),
			opacity = readOpacity(item.opacity),
			flip = item.flip == true,
		})
	end

	return {
		version = 1,
		region = region,
		elements = elements,
	}
end

return DesignDocument
