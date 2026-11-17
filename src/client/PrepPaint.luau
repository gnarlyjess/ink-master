--!strict

-- Photoreal prep overlays: stamp baked strand/dirt sprites onto EditableImage.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PrepDirtPixels = require(ReplicatedStorage.Shared.PrepDirtPixels)
local PrepMasks = require(ReplicatedStorage.Shared.PrepMasks)
local PrepSoapPixels = require(ReplicatedStorage.Shared.PrepSoapPixels)
local PrepStrandPixels = require(ReplicatedStorage.Shared.PrepStrandPixels)

local PrepPaint = {}

local W = 512
local H = 640
local unavailable = false

local hairImage: EditableImage? = nil
local dirtImage: EditableImage? = nil
local hairBuf: buffer? = nil
local dirtBuf: buffer? = nil
local hairLabel: ImageLabel? = nil
local dirtLabel: ImageLabel? = nil
local lastHairSig = ""
local lastDirtSig = ""

local strandSrc: buffer? = nil
local dirtSrc: buffer? = nil
local soapSrc: buffer? = nil
local STRAND_W = PrepStrandPixels.width
local STRAND_H = PrepStrandPixels.height
local BLOTCH_W = PrepDirtPixels.width
local BLOTCH_H = PrepDirtPixels.height

export type DirtPatch = {
	id: number,
	x: number,
	y: number,
	r: number,
	soaped: boolean,
	cleared: boolean,
}

function PrepPaint.isAvailable(): boolean
	return not unavailable
end

local function ensureSprites()
	if strandSrc == nil then
		strandSrc = PrepStrandPixels.pixels()
	end
	if dirtSrc == nil then
		dirtSrc = PrepDirtPixels.pixels()
	end
	if soapSrc == nil then
		soapSrc = PrepSoapPixels.pixels()
	end
end

local function ensureImages(): boolean
	if unavailable then
		return false
	end
	if hairImage ~= nil and dirtImage ~= nil and hairBuf ~= nil and dirtBuf ~= nil then
		return true
	end
	local ok = pcall(function()
		hairImage = AssetService:CreateEditableImage({ Size = Vector2.new(W, H) })
		dirtImage = AssetService:CreateEditableImage({ Size = Vector2.new(W, H) })
	end)
	if not ok or hairImage == nil or dirtImage == nil then
		unavailable = true
		hairImage = nil
		dirtImage = nil
		warn("[InkRivalry] PrepPaint EditableImage unavailable")
		return false
	end
	hairBuf = buffer.create(W * H * 4)
	dirtBuf = buffer.create(W * H * 4)
	return true
end

local function idx(x: number, y: number): number
	return (y * W + x) * 4
end

local function plot(buf: buffer, x: number, y: number, r: number, g: number, b: number, a: number)
	if a <= 4 or x < 0 or y < 0 or x >= W or y >= H then
		return
	end
	local i = idx(x, y)
	local oa = buffer.readu8(buf, i + 3)
	if oa == 0 then
		buffer.writeu8(buf, i, r)
		buffer.writeu8(buf, i + 1, g)
		buffer.writeu8(buf, i + 2, b)
		buffer.writeu8(buf, i + 3, a)
		return
	end
	local na = a / 255
	local oaN = oa / 255
	local outA = na + oaN * (1 - na)
	if outA <= 0.001 then
		return
	end
	local or_ = buffer.readu8(buf, i)
	local og = buffer.readu8(buf, i + 1)
	local ob = buffer.readu8(buf, i + 2)
	buffer.writeu8(buf, i, math.clamp(math.floor((r * na + or_ * oaN * (1 - na)) / outA + 0.5), 0, 255))
	buffer.writeu8(buf, i + 1, math.clamp(math.floor((g * na + og * oaN * (1 - na)) / outA + 0.5), 0, 255))
	buffer.writeu8(buf, i + 2, math.clamp(math.floor((b * na + ob * oaN * (1 - na)) / outA + 0.5), 0, 255))
	buffer.writeu8(buf, i + 3, math.clamp(math.floor(outA * 255 + 0.5), 0, 255))
end

local function hash(n: number): number
	local x = bit32.bxor(math.floor(n) * 374761393, 668265263)
	x = bit32.bxor(x, bit32.rshift(x, 13))
	return (x % 10000) / 10000
end

local function sampleSprite(src: buffer, sw: number, sh: number, u: number, v: number): (number, number, number, number)
	if u < 0 or v < 0 or u >= sw - 1 or v >= sh - 1 then
		return 0, 0, 0, 0
	end
	local x0 = math.floor(u)
	local y0 = math.floor(v)
	local fx = u - x0
	local fy = v - y0
	local function px(x: number, y: number): (number, number, number, number)
		local i = (y * sw + x) * 4
		return buffer.readu8(src, i), buffer.readu8(src, i + 1), buffer.readu8(src, i + 2), buffer.readu8(src, i + 3)
	end
	local r00, g00, b00, a00 = px(x0, y0)
	local r10, g10, b10, a10 = px(x0 + 1, y0)
	local r01, g01, b01, a01 = px(x0, y0 + 1)
	local r11, g11, b11, a11 = px(x0 + 1, y0 + 1)
	local a0 = a00 * (1 - fx) + a10 * fx
	local a1 = a01 * (1 - fx) + a11 * fx
	local a = a0 * (1 - fy) + a1 * fy
	if a < 1 then
		return 0, 0, 0, 0
	end
	local r = (r00 * (1 - fx) + r10 * fx) * (1 - fy) + (r01 * (1 - fx) + r11 * fx) * fy
	local g = (g00 * (1 - fx) + g10 * fx) * (1 - fy) + (g01 * (1 - fx) + g11 * fx) * fy
	local b = (b00 * (1 - fx) + b10 * fx) * (1 - fy) + (b01 * (1 - fx) + b11 * fx) * fy
	return math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5), math.floor(a + 0.5)
end

local function stampSprite(
	dest: buffer,
	src: buffer,
	sw: number,
	sh: number,
	cx: number,
	cy: number,
	scale: number,
	angle: number,
	alphaMul: number
)
	local cosA = math.cos(angle)
	local sinA = math.sin(angle)
	local hw = sw * scale * 0.5
	local hh = sh * scale * 0.5
	local extent = math.ceil(math.sqrt(hw * hw + hh * hh)) + 1
	local x0 = math.floor(cx - extent)
	local x1 = math.ceil(cx + extent)
	local y0 = math.floor(cy - extent)
	local y1 = math.ceil(cy + extent)
	for y = y0, y1 do
		for x = x0, x1 do
			local dx = x - cx
			local dy = y - cy
			local lx = (dx * cosA + dy * sinA) / scale + sw * 0.5
			local ly = (-dx * sinA + dy * cosA) / scale + sh * 0.5
			local r, g, b, a = sampleSprite(src, sw, sh, lx, ly)
			if a > 4 then
				plot(dest, x, y, r, g, b, math.floor(a * alphaMul))
			end
		end
	end
end

local function hairSignature(hair: { number }, cols: number, rows: number, hairLeft: number): string
	local sum = 0
	local total = cols * rows
	for i = 1, total, 5 do
		sum += (hair[i] or 0) * (i % 97)
	end
	return `{cols}x{rows}:{hairLeft}:{sum}`
end

local function dirtSignature(dirt: { DirtPatch }): string
	local parts = table.create(#dirt)
	for i, patch in dirt do
		parts[i] = `{patch.id}:{if patch.cleared then 2 elseif patch.soaped then 1 else 0}`
	end
	return table.concat(parts, ",")
end

local function mountLabel(image: EditableImage, parent: GuiObject, zIndex: number, name: string, existing: ImageLabel?): ImageLabel
	if existing ~= nil and existing.Parent == parent then
		existing.ImageContent = Content.fromObject(image)
		existing.Visible = true
		existing.ImageTransparency = 0
		return existing
	end
	if existing ~= nil then
		existing:Destroy()
	end
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.ScaleType = Enum.ScaleType.Stretch
	label.ZIndex = zIndex
	label.Active = false
	label.ImageTransparency = 0
	label.ImageContent = Content.fromObject(image)
	label.Parent = parent
	return label
end

-- Zero alpha off-limb. Erode ~1 cell so strands never peek onto the backdrop.
local function clipBufToSkin(buf: buffer, regionId: string?)
	if regionId == nil or regionId == "" then
		return
	end
	local mask = PrepMasks.get(regionId)
	if mask == nil then
		return
	end
	local cols = PrepMasks.COLS
	local rows = PrepMasks.ROWS
	local function skinAt(col: number, row: number): boolean
		if col < 1 or row < 1 or col > cols or row > rows then
			return false
		end
		return mask[(row - 1) * cols + col] == 1
	end
	for y = 0, H - 1 do
		local row = math.clamp(math.floor(y / H * rows) + 1, 1, rows)
		local rowBase = y * W * 4
		for x = 0, W - 1 do
			local col = math.clamp(math.floor(x / W * cols) + 1, 1, cols)
			local keep = skinAt(col, row)
				and skinAt(col - 1, row)
				and skinAt(col + 1, row)
				and skinAt(col, row - 1)
				and skinAt(col, row + 1)
			if not keep then
				local i = rowBase + x * 4
				buffer.writeu8(buf, i + 3, 0)
			end
		end
	end
end

local function isInteriorSkin(mask: { number }, col: number, row: number, cols: number, rows: number): boolean
	local function bit(c: number, r: number): boolean
		if c < 1 or r < 1 or c > cols or r > rows then
			return false
		end
		return mask[(r - 1) * cols + c] == 1
	end
	return bit(col, row) and bit(col - 1, row) and bit(col + 1, row) and bit(col, row - 1) and bit(col, row + 1)
end

function PrepPaint.sync(
	hairParent: GuiObject,
	dirtParent: GuiObject,
	hair: { number },
	cols: number,
	rows: number,
	hairLeft: number,
	dirt: { DirtPatch },
	regionId: string?
): boolean
	ensureSprites()
	if not ensureImages() then
		return false
	end
	local hImg = hairImage
	local dImg = dirtImage
	local hBuf = hairBuf
	local dBuf = dirtBuf
	local strand = strandSrc
	local blotch = dirtSrc
	local soap = soapSrc
	if hImg == nil or dImg == nil or hBuf == nil or dBuf == nil or strand == nil or blotch == nil or soap == nil then
		return false
	end

	local hSig = hairSignature(hair, cols, rows, hairLeft) .. ":" .. (regionId or "")
	if hSig ~= lastHairSig then
		lastHairSig = hSig
		buffer.fill(hBuf, 0, 0)
		local cellW = W / cols
		local cellH = H / rows
		local mask = if regionId ~= nil then PrepMasks.get(regionId) else nil
		for row = 1, rows do
			for col = 1, cols do
				local index = (row - 1) * cols + col
				if hair[index] == nil or hair[index] < 0.5 then
					continue
				end
				if mask ~= nil and not isInteriorSkin(mask, col, row, cols, rows) then
					continue
				end
				local seed = col * 97 + row * 13
				-- Tight jitter keeps stamps on-limb; soft angles read as natural hair.
				local n = 2 + math.floor(hash(seed) * 2)
				for s = 1, n do
					local jx = (hash(seed + s * 11) - 0.5) * cellW * 0.22
					local jy = (hash(seed + s * 19) - 0.5) * cellH * 0.18
					local cx = ((col - 0.5) / cols) * W + jx
					local cy = ((row - 0.5) / rows) * H + jy
					local scale = 0.38 + hash(seed + s * 3) * 0.36
					local angle = -0.25 + (hash(seed + s * 7) - 0.5) * 0.95
					stampSprite(hBuf, strand, STRAND_W, STRAND_H, cx, cy, scale, angle, 0.92)
				end
			end
		end
		clipBufToSkin(hBuf, regionId)
		local wrote = pcall(function()
			hImg:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), hBuf)
		end)
		if not wrote then
			unavailable = true
			return false
		end
	end

	local dSig = dirtSignature(dirt) .. ":" .. (regionId or "")
	if dSig ~= lastDirtSig then
		lastDirtSig = dSig
		buffer.fill(dBuf, 0, 0)
		for _, patch in dirt do
			if patch.cleared then
				continue
			end
			local cx = patch.x * W
			local cy = patch.y * H
			local target = patch.r * 2.4 * math.min(W, H)
			local scale = target / BLOTCH_W
			local angle = (patch.id * 0.7) % (math.pi * 2)
			local src = if patch.soaped then soap else blotch
			stampSprite(dBuf, src, BLOTCH_W, BLOTCH_H, cx, cy, scale, angle, if patch.soaped then 0.95 else 1)
			-- secondary smaller blotch for irregularity
			local scale2 = scale * (0.45 + hash(patch.id * 17) * 0.35)
			local ox = (hash(patch.id * 3) - 0.5) * target * 0.35
			local oy = (hash(patch.id * 5) - 0.5) * target * 0.35
			stampSprite(dBuf, src, BLOTCH_W, BLOTCH_H, cx + ox, cy + oy, scale2, angle + 0.8, 0.75)
		end
		clipBufToSkin(dBuf, regionId)
		local wrote = pcall(function()
			dImg:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), dBuf)
		end)
		if not wrote then
			unavailable = true
			return false
		end
	end

	hairLabel = mountLabel(hImg, hairParent, 2, "HairPaint", hairLabel)
	dirtLabel = mountLabel(dImg, dirtParent, 3, "DirtPaint", dirtLabel)
	return true
end

-- Soft circular razor brush — natural shave path, no cell rectangles.
function PrepPaint.eraseHairBrush(
	u: number,
	v: number,
	radius: number,
	hairAfter: { number },
	cols: number,
	rows: number,
	regionId: string?
): boolean
	if unavailable or hairImage == nil or hairBuf == nil then
		return false
	end
	local hImg = hairImage
	local hBuf = hairBuf
	local cx = u * W
	local cy = v * H
	-- Slightly larger than gameplay radius so strand tips don't survive at the edge.
	local r = math.max(4, radius * math.min(W, H) * 1.35)
	local r2 = r * r
	local x0 = math.max(0, math.floor(cx - r - 1))
	local x1 = math.min(W - 1, math.ceil(cx + r + 1))
	local y0 = math.max(0, math.floor(cy - r - 1))
	local y1 = math.min(H - 1, math.ceil(cy + r + 1))
	local touched = false
	for y = y0, y1 do
		local dy = y + 0.5 - cy
		local rowBase = y * W * 4
		for x = x0, x1 do
			local dx = x + 0.5 - cx
			local d2 = dx * dx + dy * dy
			if d2 <= r2 then
				-- Hard wipe in the core; only a thin outer ring fades (no leftover tufts).
				local t = math.sqrt(d2) / r
				local cut = if t < 0.75 then 1 else (1 - t) / 0.25
				if cut > 0.02 then
					local i = rowBase + x * 4
					local a = buffer.readu8(hBuf, i + 3)
					if a > 0 then
						touched = true
						if cut >= 0.95 or a < 40 then
							buffer.writeu8(hBuf, i, 0)
							buffer.writeu8(hBuf, i + 1, 0)
							buffer.writeu8(hBuf, i + 2, 0)
							buffer.writeu8(hBuf, i + 3, 0)
						else
							buffer.writeu8(hBuf, i + 3, math.floor(a * (1 - cut)))
						end
					end
				end
			end
		end
	end
	if not touched then
		return false
	end
	local wrote = pcall(function()
		hImg:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), hBuf)
	end)
	if not wrote then
		return false
	end
	local hairLeft = 0
	for _, cell in hairAfter do
		if cell > 0.5 then
			hairLeft += 1
		end
	end
	-- Keep sig in sync with PrepPaint.sync so dirt updates don't restamp rectangles.
	lastHairSig = hairSignature(hairAfter, cols, rows, hairLeft) .. ":" .. (regionId or "")
	return true
end

function PrepPaint.reset()
	lastHairSig = ""
	lastDirtSig = ""
	if hairLabel ~= nil then
		hairLabel:Destroy()
		hairLabel = nil
	end
	if dirtLabel ~= nil then
		dirtLabel:Destroy()
		dirtLabel = nil
	end
end

-- Force the next sync to redraw without tearing down EditableImage labels.
function PrepPaint.invalidate()
	lastHairSig = ""
	lastDirtSig = ""
end

-- Pixel-perfect copy of the live prep overlays (includes soft razor paths).
function PrepPaint.capture(): (EditableImage?, EditableImage?)
	if unavailable or hairBuf == nil or dirtBuf == nil then
		return nil, nil
	end
	local hairCopy: EditableImage? = nil
	local dirtCopy: EditableImage? = nil
	local hBuf = hairBuf
	local dBuf = dirtBuf
	local okHair = pcall(function()
		hairCopy = AssetService:CreateEditableImage({ Size = Vector2.new(W, H) })
		if hairCopy ~= nil then
			local pixels = buffer.create(W * H * 4)
			buffer.copy(pixels, 0, hBuf, 0, W * H * 4)
			hairCopy:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), pixels)
		end
	end)
	local okDirt = pcall(function()
		dirtCopy = AssetService:CreateEditableImage({ Size = Vector2.new(W, H) })
		if dirtCopy ~= nil then
			local pixels = buffer.create(W * H * 4)
			buffer.copy(pixels, 0, dBuf, 0, W * H * 4)
			dirtCopy:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), pixels)
		end
	end)
	if not okHair then
		hairCopy = nil
	end
	if not okDirt then
		dirtCopy = nil
	end
	return hairCopy, dirtCopy
end

-- One-shot draws for tattoo residue — same stamps/clip as the live prep overlays.
function PrepPaint.drawHair(hair: { number }, cols: number, rows: number, regionId: string?): EditableImage?
	if unavailable then
		return nil
	end
	ensureSprites()
	local strand = strandSrc
	if strand == nil then
		return nil
	end
	local pixels = buffer.create(W * H * 4)
	buffer.fill(pixels, 0, 0)
	local cellW = W / cols
	local cellH = H / rows
	local mask = if regionId ~= nil then PrepMasks.get(regionId) else nil
	local any = false
	for row = 1, rows do
		for col = 1, cols do
			local index = (row - 1) * cols + col
			if hair[index] == nil or hair[index] < 0.5 then
				continue
			end
			if mask ~= nil and not isInteriorSkin(mask, col, row, cols, rows) then
				continue
			end
			any = true
			local seed = col * 97 + row * 13
			local n = 2 + math.floor(hash(seed) * 2)
			for s = 1, n do
				local jx = (hash(seed + s * 11) - 0.5) * cellW * 0.22
				local jy = (hash(seed + s * 19) - 0.5) * cellH * 0.18
				local cx = ((col - 0.5) / cols) * W + jx
				local cy = ((row - 0.5) / rows) * H + jy
				local scale = 0.38 + hash(seed + s * 3) * 0.36
				local angle = -0.25 + (hash(seed + s * 7) - 0.5) * 0.95
				stampSprite(pixels, strand, STRAND_W, STRAND_H, cx, cy, scale, angle, 0.92)
			end
		end
	end
	if not any then
		return nil
	end
	clipBufToSkin(pixels, regionId)
	local created: EditableImage? = nil
	local ok = pcall(function()
		created = AssetService:CreateEditableImage({ Size = Vector2.new(W, H) })
		if created ~= nil then
			created:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), pixels)
		end
	end)
	if not ok or created == nil then
		unavailable = true
		return nil
	end
	return created
end

function PrepPaint.drawDirt(dirt: { DirtPatch }, regionId: string?): EditableImage?
	if unavailable then
		return nil
	end
	ensureSprites()
	local blotch = dirtSrc
	local soap = soapSrc
	if blotch == nil or soap == nil then
		return nil
	end
	local pixels = buffer.create(W * H * 4)
	buffer.fill(pixels, 0, 0)
	local any = false
	for _, patch in dirt do
		if patch.cleared then
			continue
		end
		any = true
		local cx = patch.x * W
		local cy = patch.y * H
		local target = patch.r * 2.4 * math.min(W, H)
		local scale = target / BLOTCH_W
		local angle = (patch.id * 0.7) % (math.pi * 2)
		local src = if patch.soaped then soap else blotch
		stampSprite(pixels, src, BLOTCH_W, BLOTCH_H, cx, cy, scale, angle, if patch.soaped then 0.95 else 1)
		local scale2 = scale * (0.45 + hash(patch.id * 17) * 0.35)
		local ox = (hash(patch.id * 3) - 0.5) * target * 0.35
		local oy = (hash(patch.id * 5) - 0.5) * target * 0.35
		stampSprite(pixels, src, BLOTCH_W, BLOTCH_H, cx + ox, cy + oy, scale2, angle + 0.8, 0.75)
	end
	if not any then
		return nil
	end
	clipBufToSkin(pixels, regionId)
	local created: EditableImage? = nil
	local ok = pcall(function()
		created = AssetService:CreateEditableImage({ Size = Vector2.new(W, H) })
		if created ~= nil then
			created:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), pixels)
		end
	end)
	if not ok or created == nil then
		unavailable = true
		return nil
	end
	return created
end

function PrepPaint.mount(image: EditableImage, parent: GuiObject, zIndex: number, name: string): ImageLabel
	return mountLabel(image, parent, zIndex, name, nil)
end

return PrepPaint
