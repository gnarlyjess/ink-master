--!strict

-- Draws one stencil inside a square GuiObject. Used on the arm panel and in the tool tray.

local StencilView = {}

local function corner(parent: Instance, radius: UDim)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = radius
	uiCorner.Parent = parent
end

local function piece(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	height: number,
	color: Color3,
	rotation: number,
	round: boolean
): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(width, height)
	frame.Rotation = rotation
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	if round then
		corner(frame, UDim.new(1, 0))
	end
	return frame
end

local function drawDisc(parent: Instance, color: Color3)
	piece(parent, 0.5, 0.5, 0.92, 0.92, color, 0, true)
end

local function drawRing(parent: Instance, color: Color3)
	local frame = piece(parent, 0.5, 0.5, 0.86, 0.86, color, 0, true)
	frame.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 4
	stroke.Parent = frame
end

local function drawBand(parent: Instance, color: Color3)
	local frame = piece(parent, 0.5, 0.5, 0.92, 0.3, color, 0, false)
	corner(frame, UDim.new(0.5, 0))
end

local function drawDiamond(parent: Instance, color: Color3)
	piece(parent, 0.5, 0.5, 0.68, 0.68, color, 45, false)
end

local function drawCross(parent: Instance, color: Color3)
	local horizontal = piece(parent, 0.5, 0.5, 0.92, 0.24, color, 0, false)
	local vertical = piece(parent, 0.5, 0.5, 0.24, 0.92, color, 0, false)
	corner(horizontal, UDim.new(0.4, 0))
	corner(vertical, UDim.new(0.4, 0))
end

local function drawSpark(parent: Instance, color: Color3)
	piece(parent, 0.5, 0.5, 0.42, 0.42, color, 45, false)
	drawCross(parent, color)
end

local function drawHeart(parent: Instance, color: Color3)
	piece(parent, 0.34, 0.38, 0.46, 0.46, color, 0, true)
	piece(parent, 0.66, 0.38, 0.46, 0.46, color, 0, true)
	piece(parent, 0.5, 0.62, 0.56, 0.56, color, 45, false)
end

function StencilView.draw(parent: GuiObject, shape: string, color: Color3)
	local existing = parent:FindFirstChild("Glyph")
	if existing ~= nil then
		existing:Destroy()
	end

	local glyph = Instance.new("Frame")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.BorderSizePixel = 0
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Parent = parent

	if shape == "ring" then
		drawRing(glyph, color)
	elseif shape == "band" then
		drawBand(glyph, color)
	elseif shape == "diamond" then
		drawDiamond(glyph, color)
	elseif shape == "cross" then
		drawCross(glyph, color)
	elseif shape == "spark" then
		drawSpark(glyph, color)
	elseif shape == "heart" then
		drawHeart(glyph, color)
	else
		drawDisc(glyph, color)
	end
end

return StencilView
