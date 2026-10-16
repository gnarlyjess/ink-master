--!strict

-- Clean stencil silhouettes. Each shape is filled geometry, drawn once into an image,
-- then tinted by the ink colour. UI boxes cannot make a sharp star or heart.

local AssetService = game:GetService("AssetService")

local StencilView = {}

local SIZE = 160
local SAMPLES = 3

type Vec = { x: number, y: number }
type Mask = (number, number) -> boolean

local function inCircle(x: number, y: number, cx: number, cy: number, radius: number): boolean
	local dx = x - cx
	local dy = y - cy
	return dx * dx + dy * dy <= radius * radius
end

local function inBox(x: number, y: number, x0: number, y0: number, x1: number, y1: number): boolean
	return x >= x0 and x <= x1 and y >= y0 and y <= y1
end

local function inRotBox(
	x: number,
	y: number,
	cx: number,
	cy: number,
	halfW: number,
	halfH: number,
	degrees: number
): boolean
	local angle = math.rad(degrees)
	local dx = x - cx
	local dy = y - cy
	local cosine = math.cos(angle)
	local sine = math.sin(angle)
	local localX = dx * cosine + dy * sine
	local localY = -dx * sine + dy * cosine
	return math.abs(localX) <= halfW and math.abs(localY) <= halfH
end

local function inPoly(x: number, y: number, points: { Vec }): boolean
	local inside = false
	local count = #points
	local previous = count
	for index = 1, count do
		local current = points[index]
		local prior = points[previous]
		if (current.y > y) ~= (prior.y > y) then
			local cross = (prior.x - current.x) * (y - current.y) / (prior.y - current.y) + current.x
			if x < cross then
				inside = not inside
			end
		end
		previous = index
	end
	return inside
end

local function star(points: number, outer: number, inner: number): { Vec }
	local polygon: { Vec } = {}
	for step = 0, points * 2 - 1 do
		local radius = if step % 2 == 0 then outer else inner
		local angle = -math.pi / 2 + step * math.pi / points
		table.insert(polygon, { x = 0.5 + math.cos(angle) * radius, y = 0.5 + math.sin(angle) * radius })
	end
	return polygon
end

local function heartOutline(): { Vec }
	local polygon: { Vec } = {}
	for step = 0, 47 do
		local t = step / 48 * math.pi * 2
		local x = math.sin(t) ^ 3
		local y = (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 16
		table.insert(polygon, { x = 0.5 + x * 0.4, y = 0.5 - y * 0.4 })
	end
	return polygon
end

local FOUR_STAR = star(4, 0.44, 0.17)
local EIGHT_STAR = star(8, 0.44, 0.24)
local HEART = heartOutline()
local BOLT = {
	{ x = 0.56, y = 0.08 },
	{ x = 0.22, y = 0.5 },
	{ x = 0.46, y = 0.5 },
	{ x = 0.34, y = 0.92 },
	{ x = 0.78, y = 0.4 },
	{ x = 0.52, y = 0.4 },
}
local BANNER = {
	{ x = 0.08, y = 0.4 },
	{ x = 0.24, y = 0.26 },
	{ x = 0.76, y = 0.26 },
	{ x = 0.92, y = 0.4 },
	{ x = 0.76, y = 0.54 },
	{ x = 0.68, y = 0.54 },
	{ x = 0.68, y = 0.78 },
	{ x = 0.5, y = 0.58 },
	{ x = 0.32, y = 0.78 },
	{ x = 0.32, y = 0.54 },
	{ x = 0.24, y = 0.54 },
}
local ARROW_HEAD = {
	{ x = 0.5, y = 0.08 },
	{ x = 0.86, y = 0.46 },
	{ x = 0.14, y = 0.46 },
}
local DIAMOND = {
	{ x = 0.5, y = 0.08 },
	{ x = 0.92, y = 0.5 },
	{ x = 0.5, y = 0.92 },
	{ x = 0.08, y = 0.5 },
}
local TRIANGLE = {
	{ x = 0.5, y = 0.1 },
	{ x = 0.9, y = 0.88 },
	{ x = 0.1, y = 0.88 },
}
local function scalePoly(points: { Vec }, scale: number, cx: number, cy: number): { Vec }
	local scaled: { Vec } = {}
	for _, point in points do
		table.insert(scaled, {
			x = cx + (point.x - cx) * scale,
			y = cy + (point.y - cy) * scale,
		})
	end
	return scaled
end

local function polyRing(x: number, y: number, outer: { Vec }, inner: { Vec }): boolean
	return inPoly(x, y, outer) and not inPoly(x, y, inner)
end

local function circleRing(x: number, y: number, cx: number, cy: number, radius: number, width: number): boolean
	local dx = x - cx
	local dy = y - cy
	local distance = dx * dx + dy * dy
	local inner = radius - width
	return distance <= radius * radius and distance >= inner * inner
end

local FIVE_STAR = star(5, 0.42, 0.17)
local STAR_RING = scalePoly(FIVE_STAR, 0.78, 0.5, 0.5)
local TRI_RING = scalePoly(TRIANGLE, 0.78, 0.5, 0.62)
local HEART_RING = scalePoly(HEART, 0.78, 0.5, 0.52)
local GEM_RING = scalePoly(DIAMOND, 0.78, 0.5, 0.5)
local ARROW_RING = scalePoly(ARROW_HEAD, 0.62, 0.5, 0.33)

local function regularPolygon(sides: number, radius: number): { Vec }
	local polygon: { Vec } = {}
	for step = 0, sides - 1 do
		local angle = -math.pi / 2 + step * math.pi * 2 / sides
		table.insert(polygon, { x = 0.5 + math.cos(angle) * radius, y = 0.5 + math.sin(angle) * radius })
	end
	return polygon
end

local HEX = regularPolygon(6, 0.4)
local HEX_RING = scalePoly(HEX, 0.8, 0.5, 0.5)
local EIGHT_RING = scalePoly(EIGHT_STAR, 0.8, 0.5, 0.5)
local SPARK_RING = scalePoly(FOUR_STAR, 0.72, 0.5, 0.5)
local BOLT_RING = scalePoly(BOLT, 0.72, 0.5, 0.48)
local BANNER_RING = scalePoly(BANNER, 0.78, 0.5, 0.5)
local LEAF = {
	{ x = 0.5, y = 0.08 },
	{ x = 0.78, y = 0.42 },
	{ x = 0.62, y = 0.78 },
	{ x = 0.5, y = 0.92 },
	{ x = 0.38, y = 0.78 },
	{ x = 0.22, y = 0.42 },
}
local LEAF_RING = scalePoly(LEAF, 0.78, 0.5, 0.5)
local EYE = {
	{ x = 0.08, y = 0.5 },
	{ x = 0.5, y = 0.3 },
	{ x = 0.92, y = 0.5 },
	{ x = 0.5, y = 0.7 },
}
local EYE_RING = scalePoly(EYE, 0.72, 0.5, 0.5)
local SHIELD = {
	{ x = 0.5, y = 0.08 },
	{ x = 0.86, y = 0.26 },
	{ x = 0.74, y = 0.72 },
	{ x = 0.5, y = 0.92 },
	{ x = 0.26, y = 0.72 },
	{ x = 0.14, y = 0.26 },
}
local SHIELD_RING = scalePoly(SHIELD, 0.78, 0.5, 0.5)
local CROWN = {
	{ x = 0.12, y = 0.74 },
	{ x = 0.12, y = 0.38 },
	{ x = 0.3, y = 0.56 },
	{ x = 0.4, y = 0.22 },
	{ x = 0.5, y = 0.5 },
	{ x = 0.62, y = 0.18 },
	{ x = 0.74, y = 0.56 },
	{ x = 0.88, y = 0.34 },
	{ x = 0.88, y = 0.74 },
}
local CROWN_RING = scalePoly(CROWN, 0.78, 0.5, 0.5)
local DROP_POINT = {
	{ x = 0.5, y = 0.08 },
	{ x = 0.76, y = 0.58 },
	{ x = 0.24, y = 0.58 },
}
local DROP_RING = scalePoly(DROP_POINT, 0.72, 0.5, 0.4)

local masks: { [string]: Mask } = {
	disc = function(x, y)
		return inCircle(x, y, 0.5, 0.5, 0.38)
	end,
	ring = function(x, y)
		return inCircle(x, y, 0.5, 0.5, 0.4) and not inCircle(x, y, 0.5, 0.5, 0.33)
	end,
	oval = function(x, y)
		local dx = (x - 0.5) / 0.4
		local dy = (y - 0.5) / 0.24
		return dx * dx + dy * dy <= 1
	end,
	square = function(x, y)
		return inBox(x, y, 0.16, 0.16, 0.84, 0.84)
	end,
	diamond = function(x, y)
		return inPoly(x, y, DIAMOND)
	end,
	triangle = function(x, y)
		return inPoly(x, y, TRIANGLE)
	end,
	half = function(x, y)
		return y <= 0.56 and inCircle(x, y, 0.5, 0.56, 0.36)
	end,
	band = function(x, y)
		return inBox(x, y, 0.1, 0.47, 0.9, 0.53)
	end,
	pill = function(x, y)
		return inBox(x, y, 0.28, 0.34, 0.72, 0.66) or inCircle(x, y, 0.28, 0.5, 0.16) or inCircle(x, y, 0.72, 0.5, 0.16)
	end,
	slash = function(x, y)
		return inRotBox(x, y, 0.5, 0.5, 0.42, 0.025, -42)
	end,
	line = function(x, y)
		return inBox(x, y, 0.08, 0.485, 0.92, 0.515)
	end,
	cross = function(x, y)
		return inBox(x, y, 0.08, 0.47, 0.92, 0.53) or inBox(x, y, 0.47, 0.08, 0.53, 0.92)
	end,
	plus = function(x, y)
		return inBox(x, y, 0.08, 0.475, 0.92, 0.525) or inBox(x, y, 0.475, 0.08, 0.525, 0.92)
	end,
	saltire = function(x, y)
		return inRotBox(x, y, 0.5, 0.5, 0.42, 0.025, 45) or inRotBox(x, y, 0.5, 0.5, 0.42, 0.025, -45)
	end,
	chevron = function(x, y)
		return inRotBox(x, y, 0.38, 0.5, 0.03, 0.28, 36) or inRotBox(x, y, 0.62, 0.5, 0.03, 0.28, -36)
	end,
	arrow = function(x, y)
		return inPoly(x, y, ARROW_HEAD) or inBox(x, y, 0.47, 0.42, 0.53, 0.9)
	end,
	spark = function(x, y)
		return inPoly(x, y, FOUR_STAR)
	end,
	burst = function(x, y)
		return inPoly(x, y, EIGHT_STAR)
	end,
	heart = function(x, y)
		return inPoly(x, y, HEART)
	end,
	bolt = function(x, y)
		return inPoly(x, y, BOLT)
	end,
	drop = function(x, y)
		return inPoly(x, y, DROP_POINT) or inCircle(x, y, 0.5, 0.62, 0.26)
	end,
	banner = function(x, y)
		return inPoly(x, y, BANNER)
	end,
	steps = function(x, y)
		return inBox(x, y, 0.12, 0.68, 0.4, 0.76)
			or inBox(x, y, 0.36, 0.46, 0.64, 0.54)
			or inBox(x, y, 0.6, 0.24, 0.88, 0.32)
	end,
	target = function(x, y)
		local outer = inCircle(x, y, 0.5, 0.5, 0.4) and not inCircle(x, y, 0.5, 0.5, 0.34)
		local middle = inCircle(x, y, 0.5, 0.5, 0.24) and not inCircle(x, y, 0.5, 0.5, 0.18)
		return outer or middle or inCircle(x, y, 0.5, 0.5, 0.035)
	end,
	corner = function(x, y)
		return inBox(x, y, 0.22, 0.18, 0.3, 0.82) or inBox(x, y, 0.22, 0.74, 0.82, 0.82)
	end,
	circle = function(x, y)
		return circleRing(x, y, 0.5, 0.5, 0.38, 0.045)
	end,
	frame = function(x, y)
		return inBox(x, y, 0.16, 0.16, 0.84, 0.84) and not inBox(x, y, 0.22, 0.22, 0.78, 0.78)
	end,
	rect = function(x, y)
		return inBox(x, y, 0.08, 0.3, 0.92, 0.7) and not inBox(x, y, 0.14, 0.36, 0.86, 0.64)
	end,
	tri = function(x, y)
		return polyRing(x, y, TRIANGLE, TRI_RING)
	end,
	bar = function(x, y)
		return inBox(x, y, 0.08, 0.475, 0.92, 0.525)
	end,
	star = function(x, y)
		return polyRing(x, y, FIVE_STAR, STAR_RING)
	end,
	moon = function(x, y)
		local outer = inCircle(x, y, 0.42, 0.5, 0.34) and not inCircle(x, y, 0.58, 0.46, 0.28)
		local inner = inCircle(x, y, 0.42, 0.5, 0.28) and not inCircle(x, y, 0.56, 0.46, 0.24)
		return outer and not inner
	end,
	sun = function(x, y)
		if circleRing(x, y, 0.5, 0.5, 0.2, 0.04) then
			return true
		end
		for ray = 0, 7 do
			local angle = ray * math.pi / 4
			local cx = 0.5 + math.cos(angle) * 0.36
			local cy = 0.5 + math.sin(angle) * 0.36
			if inRotBox(x, y, cx, cy, 0.07, 0.028, math.deg(angle)) then
				return true
			end
		end
		return false
	end,
	flower = function(x, y)
		for petal = 0, 5 do
			local angle = -math.pi / 2 + petal * math.pi / 3
			local cx = 0.5 + math.cos(angle) * 0.2
			local cy = 0.5 + math.sin(angle) * 0.2
			if circleRing(x, y, cx, cy, 0.13, 0.035) then
				return true
			end
		end
		return circleRing(x, y, 0.5, 0.5, 0.07, 0.03)
	end,
	heartline = function(x, y)
		return polyRing(x, y, HEART, HEART_RING)
	end,
	ovalline = function(x, y)
		local function oval(rx: number, ry: number): boolean
			local dx = (x - 0.5) / rx
			local dy = (y - 0.5) / ry
			return dx * dx + dy * dy <= 1
		end
		return oval(0.4, 0.26) and not oval(0.33, 0.19)
	end,
	gem = function(x, y)
		return polyRing(x, y, DIAMOND, GEM_RING)
	end,
	pointer = function(x, y)
		local head = polyRing(x, y, ARROW_HEAD, ARROW_RING)
		local shaft = inBox(x, y, 0.44, 0.4, 0.56, 0.9) and not inBox(x, y, 0.475, 0.48, 0.525, 0.9)
		return head or shaft
	end,
	crossline = function(x, y)
		local upright = inBox(x, y, 0.08, 0.46, 0.92, 0.54) or inBox(x, y, 0.46, 0.08, 0.54, 0.92)
		local core = inBox(x, y, 0.14, 0.48, 0.86, 0.52) or inBox(x, y, 0.48, 0.14, 0.52, 0.86)
		return upright and not core
	end,
	hex = function(x, y)
		return polyRing(x, y, HEX, HEX_RING)
	end,
	dropline = function(x, y)
		local outer = inPoly(x, y, DROP_POINT) or inCircle(x, y, 0.5, 0.62, 0.26)
		local inner = inPoly(x, y, DROP_RING) or inCircle(x, y, 0.5, 0.62, 0.18)
		return outer and not inner
	end,
	boltline = function(x, y)
		return polyRing(x, y, BOLT, BOLT_RING)
	end,
	cloud = function(x, y)
		local function puff(scale: number): boolean
			return inCircle(x, y, 0.36, 0.56, 0.16 * scale)
				or inCircle(x, y, 0.5, 0.42, 0.18 * scale)
				or inCircle(x, y, 0.66, 0.56, 0.15 * scale)
				or inBox(x, y, 0.28, 0.52, 0.74, 0.7 * scale + 0.2)
		end
		return puff(1) and not puff(0.72)
	end,
	leaf = function(x, y)
		return polyRing(x, y, LEAF, LEAF_RING)
	end,
	wave = function(x, y)
		if x < 0.08 or x > 0.92 then
			return false
		end
		local curve = 0.5 + math.sin((x - 0.08) / 0.84 * math.pi * 2) * 0.16
		return math.abs(y - curve) <= 0.028
	end,
	zigzag = function(x, y)
		if x < 0.1 or x > 0.9 then
			return false
		end
		local along = (x - 0.1) / 0.8 * 3
		local phase = along % 2
		local tooth = if phase < 1 then phase else 2 - phase
		local curve = 0.3 + tooth * 0.4
		return math.abs(y - curve) <= 0.03
	end,
	eye = function(x, y)
		return polyRing(x, y, EYE, EYE_RING) or circleRing(x, y, 0.5, 0.5, 0.07, 0.028)
	end,
	shield = function(x, y)
		return polyRing(x, y, SHIELD, SHIELD_RING)
	end,
	crown = function(x, y)
		return polyRing(x, y, CROWN, CROWN_RING)
	end,
	burstline = function(x, y)
		return polyRing(x, y, EIGHT_STAR, EIGHT_RING)
	end,
	sparkline = function(x, y)
		return polyRing(x, y, FOUR_STAR, SPARK_RING)
	end,
	arc = function(x, y)
		return circleRing(x, y, 0.5, 0.58, 0.34, 0.045) and y <= 0.58
	end,
	blob = function(x, y)
		local dx = x - 0.5
		local dy = y - 0.5
		local angle = math.atan2(dy, dx)
		local radius = 0.34 + math.sin(angle * 3) * 0.05
		local distance = math.sqrt(dx * dx + dy * dy)
		return distance <= radius and distance >= radius - 0.045
	end,
	bannerline = function(x, y)
		return polyRing(x, y, BANNER, BANNER_RING)
	end,
	chevronline = function(x, y)
		local function arm(cx: number, tilt: number, width: number): boolean
			return inRotBox(x, y, cx, 0.5, width, 0.28, tilt)
		end
		return (arm(0.38, 36, 0.045) or arm(0.62, -36, 0.045)) and not (arm(0.4, 36, 0.012) or arm(0.6, -36, 0.012))
	end,
	stepline = function(x, y)
		local function stair(x0: number, y0: number, x1: number, y1: number): boolean
			return inBox(x, y, x0, y0, x1, y1) and not inBox(x, y, x0 + 0.035, y0 + 0.035, x1 - 0.035, y1 - 0.035)
		end
		return stair(0.12, 0.66, 0.4, 0.82) or stair(0.36, 0.44, 0.64, 0.6) or stair(0.6, 0.22, 0.88, 0.38)
	end,
}

local solids: { [string]: Mask } = {
	circle = function(x, y)
		return inCircle(x, y, 0.5, 0.5, 0.38)
	end,
	frame = function(x, y)
		return inBox(x, y, 0.16, 0.16, 0.84, 0.84)
	end,
	rect = function(x, y)
		return inBox(x, y, 0.08, 0.3, 0.92, 0.7)
	end,
	tri = function(x, y)
		return inPoly(x, y, TRIANGLE)
	end,
	bar = function(x, y)
		return inBox(x, y, 0.08, 0.4, 0.92, 0.6)
	end,
	star = function(x, y)
		return inPoly(x, y, FIVE_STAR)
	end,
	moon = function(x, y)
		return inCircle(x, y, 0.42, 0.5, 0.34) and not inCircle(x, y, 0.58, 0.46, 0.28)
	end,
	sun = function(x, y)
		if inCircle(x, y, 0.5, 0.5, 0.2) then
			return true
		end
		for ray = 0, 7 do
			local angle = ray * math.pi / 4
			local cx = 0.5 + math.cos(angle) * 0.36
			local cy = 0.5 + math.sin(angle) * 0.36
			if inRotBox(x, y, cx, cy, 0.07, 0.028, math.deg(angle)) then
				return true
			end
		end
		return false
	end,
	flower = function(x, y)
		for petal = 0, 5 do
			local angle = -math.pi / 2 + petal * math.pi / 3
			local cx = 0.5 + math.cos(angle) * 0.2
			local cy = 0.5 + math.sin(angle) * 0.2
			if inCircle(x, y, cx, cy, 0.13) then
				return true
			end
		end
		return inCircle(x, y, 0.5, 0.5, 0.07)
	end,
	heartline = function(x, y)
		return inPoly(x, y, HEART)
	end,
	ovalline = function(x, y)
		local dx = (x - 0.5) / 0.4
		local dy = (y - 0.5) / 0.26
		return dx * dx + dy * dy <= 1
	end,
	gem = function(x, y)
		return inPoly(x, y, DIAMOND)
	end,
	pointer = function(x, y)
		return inPoly(x, y, ARROW_HEAD) or inBox(x, y, 0.44, 0.4, 0.56, 0.9)
	end,
	crossline = function(x, y)
		return inBox(x, y, 0.08, 0.42, 0.92, 0.58) or inBox(x, y, 0.42, 0.08, 0.58, 0.92)
	end,
	hex = function(x, y)
		return inPoly(x, y, HEX)
	end,
	dropline = function(x, y)
		return inPoly(x, y, DROP_POINT) or inCircle(x, y, 0.5, 0.62, 0.26)
	end,
	boltline = function(x, y)
		return inPoly(x, y, BOLT)
	end,
	cloud = function(x, y)
		return inCircle(x, y, 0.36, 0.56, 0.16)
			or inCircle(x, y, 0.5, 0.42, 0.18)
			or inCircle(x, y, 0.66, 0.56, 0.15)
			or inBox(x, y, 0.28, 0.5, 0.74, 0.7)
	end,
	leaf = function(x, y)
		return inPoly(x, y, LEAF)
	end,
	wave = function(x, y)
		if x < 0.08 or x > 0.92 then
			return false
		end
		local curve = 0.5 + math.sin((x - 0.08) / 0.84 * math.pi * 2) * 0.16
		return math.abs(y - curve) <= 0.07
	end,
	zigzag = function(x, y)
		if x < 0.1 or x > 0.9 then
			return false
		end
		local along = (x - 0.1) / 0.8 * 3
		local phase = along % 2
		local tooth = if phase < 1 then phase else 2 - phase
		local curve = 0.3 + tooth * 0.4
		return math.abs(y - curve) <= 0.07
	end,
	eye = function(x, y)
		return inPoly(x, y, EYE)
	end,
	shield = function(x, y)
		return inPoly(x, y, SHIELD)
	end,
	crown = function(x, y)
		return inPoly(x, y, CROWN)
	end,
	burstline = function(x, y)
		return inPoly(x, y, EIGHT_STAR)
	end,
	sparkline = function(x, y)
		return inPoly(x, y, FOUR_STAR)
	end,
	arc = function(x, y)
		return inCircle(x, y, 0.5, 0.58, 0.34) and y <= 0.58
	end,
	blob = function(x, y)
		local dx = x - 0.5
		local dy = y - 0.5
		local angle = math.atan2(dy, dx)
		local radius = 0.34 + math.sin(angle * 3) * 0.05
		return dx * dx + dy * dy <= radius * radius
	end,
	bannerline = function(x, y)
		return inPoly(x, y, BANNER)
	end,
	chevronline = function(x, y)
		return inRotBox(x, y, 0.38, 0.5, 0.09, 0.28, 36) or inRotBox(x, y, 0.62, 0.5, 0.09, 0.28, -36)
	end,
	stepline = function(x, y)
		return inBox(x, y, 0.12, 0.66, 0.4, 0.82)
			or inBox(x, y, 0.36, 0.44, 0.64, 0.6)
			or inBox(x, y, 0.6, 0.22, 0.88, 0.38)
	end,
}

local function raster(inside: Mask): buffer
	local pixels = buffer.create(SIZE * SIZE * 4)
	local step = 1 / SAMPLES
	for y = 0, SIZE - 1 do
		for x = 0, SIZE - 1 do
			local cover = 0
			for sampleY = 0, SAMPLES - 1 do
				for sampleX = 0, SAMPLES - 1 do
					local px = (x + (sampleX + 0.5) * step) / SIZE
					local py = (y + (sampleY + 0.5) * step) / SIZE
					if inside(px, py) then
						cover += 1
					end
				end
			end
			if cover > 0 then
				local index = (y * SIZE + x) * 4
				buffer.writeu8(pixels, index, 255)
				buffer.writeu8(pixels, index + 1, 255)
				buffer.writeu8(pixels, index + 2, 255)
				buffer.writeu8(pixels, index + 3, math.floor(cover * 255 / (SAMPLES * SAMPLES)))
			end
		end
	end
	return pixels
end

local images: { [string]: EditableImage } = {}
local unavailable = false

local function cachedImage(shape: string): EditableImage?
	return images[shape]
end

local function maskFor(shape: string): Mask?
	return masks[shape]
end

local function solidFor(shape: string): Mask?
	return solids[shape]
end

local function silhouette(shape: string): EditableImage?
	if unavailable then
		return nil
	end
	local cached = cachedImage(shape)
	if cached ~= nil then
		return cached
	end
	local inside = maskFor(shape)
	if inside == nil then
		inside = maskFor("disc")
	end
	if inside == nil then
		return nil
	end
	local created: EditableImage? = nil
	local ok = pcall(function()
		created = AssetService:CreateEditableImage({
			Size = Vector2.new(SIZE, SIZE),
		})
	end)
	if not ok or created == nil then
		unavailable = true
		warn("[InkMasters] Clean stencils need Allow Mesh / Image APIs, in Experience Settings, Security")
		return nil
	end
	created:WritePixelsBuffer(Vector2.zero, Vector2.new(SIZE, SIZE), raster(inside))
	images[shape] = created
	return created
end

local function solidSilhouette(shape: string): EditableImage?
	if unavailable then
		return nil
	end
	local key = `solid:{shape}`
	local cached = cachedImage(key)
	if cached ~= nil then
		return cached
	end
	local inside = solidFor(shape)
	if inside == nil then
		inside = maskFor(shape)
	end
	if inside == nil then
		return nil
	end
	local created: EditableImage? = nil
	local ok = pcall(function()
		created = AssetService:CreateEditableImage({
			Size = Vector2.new(SIZE, SIZE),
		})
	end)
	if not ok or created == nil then
		unavailable = true
		warn("[InkMasters] Clean stencils need Allow Mesh / Image APIs, in Experience Settings, Security")
		return nil
	end
	created:WritePixelsBuffer(Vector2.zero, Vector2.new(SIZE, SIZE), raster(inside))
	images[key] = created
	return created
end

local function fallback(parent: Instance, color: Color3)
	local blob = Instance.new("Frame")
	blob.Name = "Glyph"
	blob.AnchorPoint = Vector2.new(0.5, 0.5)
	blob.Position = UDim2.fromScale(0.5, 0.5)
	blob.Size = UDim2.fromScale(0.7, 0.7)
	blob.BackgroundColor3 = color
	blob.BorderSizePixel = 0
	blob.Parent = parent
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(1, 0)
	uiCorner.Parent = blob
end

function StencilView.draw(parent: GuiObject, shape: string, color: Color3)
	local existing = parent:FindFirstChild("Glyph")
	if existing ~= nil then
		existing:Destroy()
	end

	local image = silhouette(shape)
	if image == nil then
		fallback(parent, color)
		return
	end

	local glyph = Instance.new("ImageLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.BorderSizePixel = 0
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.ScaleType = Enum.ScaleType.Fit
	glyph.ImageColor3 = color
	glyph.ImageContent = Content.fromObject(image)
	glyph.Parent = parent
end

export type MarkStyle = {
	fill: boolean,
	outline: boolean,
	thickness: number,
	opacity: number,
	flip: boolean,
}

local styled: { [string]: EditableImage } = {}

local function cachedStyled(key: string): EditableImage?
	return styled[key]
end

local function probe(mask: Mask, x: number, y: number): boolean
	if x < 0 or y < 0 or x > 1 or y > 1 then
		return false
	end
	return mask(x, y)
end

local shapeGrids: { [string]: { boolean } } = {}

local function cachedGrid(shape: string): { boolean }?
	return shapeGrids[shape]
end

local function gridFor(shape: string, mask: Mask): { boolean }
	local cached = cachedGrid(shape)
	if cached ~= nil then
		return cached
	end
	local grid = table.create(SIZE * SIZE, false)
	for y = 0, SIZE - 1 do
		local row = y * SIZE
		for x = 0, SIZE - 1 do
			grid[row + x + 1] = probe(mask, (x + 0.5) / SIZE, (y + 0.5) / SIZE)
		end
	end
	shapeGrids[shape] = grid
	return grid
end

local function dilate(source: { boolean }, radius: number): { boolean }
	if radius <= 0 then
		return source
	end
	local horizontal = table.create(SIZE * SIZE, false)
	for y = 0, SIZE - 1 do
		local row = y * SIZE
		for x = 0, SIZE - 1 do
			local x0 = math.max(0, x - radius)
			local x1 = math.min(SIZE - 1, x + radius)
			local on = false
			for nx = x0, x1 do
				if source[row + nx + 1] == true then
					on = true
					break
				end
			end
			horizontal[row + x + 1] = on
		end
	end
	local result = table.create(SIZE * SIZE, false)
	for x = 0, SIZE - 1 do
		for y = 0, SIZE - 1 do
			local y0 = math.max(0, y - radius)
			local y1 = math.min(SIZE - 1, y + radius)
			local on = false
			for ny = y0, y1 do
				if horizontal[ny * SIZE + x + 1] == true then
					on = true
					break
				end
			end
			result[y * SIZE + x + 1] = on
		end
	end
	return result
end

local function rasterGrid(source: { boolean }, kind: "fill" | "line", radius: number): buffer
	local grown = if radius <= 0 then source else dilate(source, radius)
	local pixels = buffer.create(SIZE * SIZE * 4)
	for index = 1, SIZE * SIZE do
		local on = if kind == "fill" then grown[index] == true else grown[index] == true and source[index] ~= true
		if on then
			local offset = (index - 1) * 4
			buffer.writeu8(pixels, offset, 255)
			buffer.writeu8(pixels, offset + 1, 255)
			buffer.writeu8(pixels, offset + 2, 255)
			buffer.writeu8(pixels, offset + 3, 255)
		end
	end
	return pixels
end

local function styledImage(shape: string, kind: "fill" | "line", pixels: number, filled: boolean): EditableImage?
	if unavailable then
		return nil
	end
	local key = `{kind}:{shape}:{pixels}:{if filled then "s" else "o"}`
	local cached = cachedStyled(key)
	if cached ~= nil then
		return cached
	end
	local mask = if filled then solidFor(shape) else maskFor(shape)
	if mask == nil then
		mask = maskFor(shape)
	end
	if mask == nil then
		mask = maskFor("disc")
	end
	if mask == nil then
		return nil
	end
	local created: EditableImage? = nil
	local ok = pcall(function()
		created = AssetService:CreateEditableImage({
			Size = Vector2.new(SIZE, SIZE),
		})
	end)
	if not ok or created == nil then
		unavailable = true
		warn("[InkMasters] Clean stencils need Allow Mesh / Image APIs, in Experience Settings, Security")
		return nil
	end
	local gridKey = if filled then `{shape}:solid` else shape
	created:WritePixelsBuffer(Vector2.zero, Vector2.new(SIZE, SIZE), rasterGrid(gridFor(gridKey, mask), kind, pixels))
	styled[key] = created
	return created
end

local function glyphLayer(
	parent: Instance,
	name: string,
	image: EditableImage,
	color: Color3,
	transparency: number,
	zIndex: number,
	flip: boolean
)
	local glyph = Instance.new("ImageLabel")
	glyph.Name = name
	glyph.BackgroundTransparency = 1
	glyph.BorderSizePixel = 0
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromScale(if flip then -1 else 1, 1)
	glyph.ScaleType = Enum.ScaleType.Fit
	glyph.ImageColor3 = color
	glyph.ImageTransparency = transparency
	glyph.ImageContent = Content.fromObject(image)
	glyph.ZIndex = zIndex
	glyph.Parent = parent
end

function StencilView.drawMark(parent: GuiObject, shape: string, fillColor: Color3, lineColor: Color3, style: MarkStyle)
	for _, name in { "Glyph", "FillGlyph", "LineGlyph" } do
		local existing = parent:FindFirstChild(name)
		if existing ~= nil then
			existing:Destroy()
		end
	end

	local transparency = 1 - math.clamp(style.opacity, 0, 1)
	local thickness = math.clamp(math.floor(style.thickness + 0.5), 1, 10)
	if style.fill then
		local spread = if style.outline then 0 else (thickness - 1) * 2
		local image = if spread == 0 then solidSilhouette(shape) else styledImage(shape, "fill", spread, true)
		if image ~= nil then
			glyphLayer(parent, "FillGlyph", image, fillColor, transparency, 2, style.flip)
		end
	end
	if style.outline then
		local spread = (thickness - 1) * 2
		local image = if spread == 0 then silhouette(shape) else styledImage(shape, "fill", spread, false)
		if image ~= nil then
			glyphLayer(parent, "LineGlyph", image, lineColor, transparency, 3, style.flip)
		end
	end
end

return StencilView
