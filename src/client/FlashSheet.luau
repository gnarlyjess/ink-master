--!strict

-- Original flash for the shop walls. These are not the editor shapes.
-- Bold line and a little colour, the way a traditional sheet reads across a room.

local LINE = Color3.fromRGB(22, 16, 14)

local FlashSheet = {}

local function piece(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	height: number,
	color: Color3,
	rotation: number,
	round: boolean
)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(width, height)
	frame.Rotation = rotation
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame
	end
end

local function marked(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	height: number,
	fill: Color3,
	rotation: number,
	round: boolean
)
	piece(parent, x, y, width + 0.035, height + 0.035, LINE, rotation, round)
	piece(parent, x, y, width, height, fill, rotation, round)
end

local function caption(parent: Instance, text: string, y: number)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, y)
	label.Size = UDim2.fromScale(0.72, 0.12)
	label.Font = Enum.Font.Antique
	label.Text = text
	label.TextColor3 = LINE
	label.TextScaled = true
	label.Parent = parent
end

local function rose(parent: Instance, fill: Color3)
	piece(parent, 0.5, 0.78, 0.045, 0.28, LINE, 0, true)
	marked(parent, 0.32, 0.7, 0.2, 0.08, fill, -38, true)
	marked(parent, 0.68, 0.66, 0.2, 0.08, fill, 32, true)
	for step = 0, 5 do
		local angle = step * 60
		local rad = math.rad(angle)
		marked(parent, 0.5 + math.cos(rad) * 0.15, 0.36 + math.sin(rad) * 0.13, 0.2, 0.12, fill, angle, true)
	end
	piece(parent, 0.5, 0.36, 0.1, 0.1, LINE, 0, true)
end

local function dagger(parent: Instance, fill: Color3)
	marked(parent, 0.5, 0.28, 0.16, 0.42, fill, 0, false)
	piece(parent, 0.5, 0.28, 0.04, 0.36, LINE, 0, false)
	marked(parent, 0.5, 0.5, 0.46, 0.07, fill, 0, true)
	marked(parent, 0.5, 0.68, 0.1, 0.28, fill, 0, true)
	piece(parent, 0.5, 0.84, 0.12, 0.08, LINE, 0, true)
end

local function swallow(parent: Instance, fill: Color3)
	marked(parent, 0.28, 0.42, 0.34, 0.16, fill, -28, true)
	marked(parent, 0.72, 0.42, 0.34, 0.16, fill, 28, true)
	marked(parent, 0.5, 0.48, 0.16, 0.34, fill, 0, true)
	piece(parent, 0.5, 0.34, 0.08, 0.08, LINE, 0, true)
	piece(parent, 0.4, 0.74, 0.05, 0.28, LINE, 24, true)
	piece(parent, 0.6, 0.74, 0.05, 0.28, LINE, -24, true)
end

local function snake(parent: Instance, fill: Color3)
	local bends = {
		{ 0.38, 0.24, 28 },
		{ 0.58, 0.36, -24 },
		{ 0.4, 0.5, 26 },
		{ 0.6, 0.64, -22 },
		{ 0.44, 0.78, 18 },
	}
	for _, bend in bends do
		marked(parent, bend[1], bend[2], 0.28, 0.09, fill, bend[3], true)
	end
	marked(parent, 0.34, 0.16, 0.14, 0.12, fill, 0, true)
	piece(parent, 0.3, 0.14, 0.03, 0.03, LINE, 0, true)
	piece(parent, 0.22, 0.1, 0.08, 0.02, LINE, -30, true)
	piece(parent, 0.24, 0.18, 0.08, 0.02, LINE, 24, true)
end

local function banner(parent: Instance, fill: Color3)
	marked(parent, 0.5, 0.46, 0.72, 0.22, fill, 0, false)
	piece(parent, 0.16, 0.56, 0.16, 0.14, fill, 18, false)
	piece(parent, 0.84, 0.56, 0.16, 0.14, fill, -18, false)
	caption(parent, "LUCK", 0.46)
	piece(parent, 0.5, 0.72, 0.04, 0.16, LINE, 0, true)
end

local function anchor(parent: Instance, fill: Color3)
	piece(parent, 0.5, 0.16, 0.14, 0.14, LINE, 0, true)
	piece(parent, 0.5, 0.16, 0.06, 0.06, fill, 0, true)
	marked(parent, 0.5, 0.46, 0.08, 0.5, fill, 0, true)
	marked(parent, 0.5, 0.34, 0.42, 0.07, fill, 0, true)
	piece(parent, 0.32, 0.72, 0.08, 0.22, LINE, 28, true)
	piece(parent, 0.68, 0.72, 0.08, 0.22, LINE, -28, true)
end

local function moth(parent: Instance, fill: Color3)
	marked(parent, 0.3, 0.4, 0.28, 0.34, fill, -18, true)
	marked(parent, 0.7, 0.4, 0.28, 0.34, fill, 18, true)
	marked(parent, 0.34, 0.62, 0.2, 0.22, fill, 16, true)
	marked(parent, 0.66, 0.62, 0.2, 0.22, fill, -16, true)
	piece(parent, 0.5, 0.5, 0.06, 0.42, LINE, 0, true)
	piece(parent, 0.42, 0.2, 0.02, 0.16, LINE, 16, true)
	piece(parent, 0.58, 0.2, 0.02, 0.16, LINE, -16, true)
end

local function star(parent: Instance, fill: Color3)
	marked(parent, 0.5, 0.46, 0.18, 0.62, fill, 0, false)
	marked(parent, 0.5, 0.46, 0.18, 0.62, fill, 70, false)
	marked(parent, 0.5, 0.46, 0.18, 0.62, fill, -70, false)
	piece(parent, 0.5, 0.46, 0.12, 0.12, LINE, 0, true)
end

local function heart(parent: Instance, fill: Color3)
	marked(parent, 0.36, 0.36, 0.28, 0.28, fill, 0, true)
	marked(parent, 0.64, 0.36, 0.28, 0.28, fill, 0, true)
	marked(parent, 0.5, 0.56, 0.34, 0.34, fill, 45, false)
	caption(parent, "TRUE", 0.82)
end

local function bolt(parent: Instance, fill: Color3)
	marked(parent, 0.56, 0.28, 0.16, 0.34, fill, 18, false)
	marked(parent, 0.44, 0.5, 0.16, 0.28, fill, 18, false)
	marked(parent, 0.58, 0.72, 0.16, 0.32, fill, 18, false)
end

local function sheet(parent: Instance, fill: Color3)
	caption(parent, "TRADITIONAL", 0.1)
	local left = Instance.new("Frame")
	left.BackgroundTransparency = 1
	left.Position = UDim2.fromScale(0.02, 0.18)
	left.Size = UDim2.fromScale(0.46, 0.74)
	left.Parent = parent
	local right = Instance.new("Frame")
	right.BackgroundTransparency = 1
	right.Position = UDim2.fromScale(0.52, 0.18)
	right.Size = UDim2.fromScale(0.46, 0.74)
	right.Parent = parent
	rose(left, fill)
	dagger(right, fill)
end

local drawers: { [string]: (Instance, Color3) -> () } = {
	rose = rose,
	dagger = dagger,
	swallow = swallow,
	snake = snake,
	banner = banner,
	anchor = anchor,
	moth = moth,
	star = star,
	heart = heart,
	bolt = bolt,
	sheet = sheet,
}

function FlashSheet.draw(parent: Instance, design: string, accent: Color3)
	local fill = if accent.R + accent.G + accent.B < 0.45 then LINE else accent
	local draw = drawers[design]
	if draw == nil then
		rose(parent, fill)
		return
	end
	draw(parent, fill)
end

return FlashSheet
