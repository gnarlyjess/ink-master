--!strict

-- Original framed prints for the parlour walls. These are paintings, not flash sheets.

local WallPrint = {}

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

local function wash(parent: Instance, color: Color3)
	piece(parent, 0.5, 0.5, 1, 1, color, 0, false)
end

local function garden(parent: Instance)
	wash(parent, Color3.fromRGB(214, 196, 168))
	piece(parent, 0.5, 0.82, 1, 0.36, Color3.fromRGB(168, 146, 112), 0, false)
	piece(parent, 0.5, 0.72, 0.22, 0.16, Color3.fromRGB(176, 96, 70), 0, true)
	piece(parent, 0.5, 0.64, 0.16, 0.08, Color3.fromRGB(62, 44, 32), 0, true)
	piece(parent, 0.5, 0.42, 0.28, 0.28, Color3.fromRGB(46, 110, 68), 0, true)
	piece(parent, 0.34, 0.4, 0.2, 0.16, Color3.fromRGB(28, 86, 52), -20, true)
	piece(parent, 0.66, 0.38, 0.2, 0.16, Color3.fromRGB(70, 132, 78), 18, true)
	piece(parent, 0.42, 0.28, 0.1, 0.1, Color3.fromRGB(232, 126, 142), 0, true)
	piece(parent, 0.58, 0.3, 0.08, 0.08, Color3.fromRGB(244, 198, 132), 0, true)
end

local function dusk(parent: Instance)
	piece(parent, 0.5, 0.16, 1, 0.32, Color3.fromRGB(86, 104, 148), 0, false)
	piece(parent, 0.5, 0.4, 1, 0.22, Color3.fromRGB(168, 112, 132), 0, false)
	piece(parent, 0.5, 0.58, 1, 0.18, Color3.fromRGB(214, 132, 96), 0, false)
	piece(parent, 0.5, 0.78, 1, 0.44, Color3.fromRGB(232, 176, 112), 0, false)
	piece(parent, 0.62, 0.42, 0.22, 0.22, Color3.fromRGB(255, 214, 150), 0, true)
	piece(parent, 0.5, 0.86, 1, 0.2, Color3.fromRGB(92, 64, 58), 0, false)
end

local function vase(parent: Instance)
	wash(parent, Color3.fromRGB(232, 210, 196))
	piece(parent, 0.5, 0.84, 0.7, 0.06, Color3.fromRGB(120, 86, 68), 0, true)
	piece(parent, 0.5, 0.7, 0.16, 0.22, Color3.fromRGB(86, 112, 118), 0, true)
	piece(parent, 0.5, 0.6, 0.1, 0.08, Color3.fromRGB(64, 88, 96), 0, true)
	piece(parent, 0.42, 0.4, 0.16, 0.22, Color3.fromRGB(46, 110, 68), -16, true)
	piece(parent, 0.58, 0.36, 0.16, 0.24, Color3.fromRGB(70, 132, 78), 14, true)
	piece(parent, 0.36, 0.28, 0.1, 0.1, Color3.fromRGB(196, 64, 78), 0, true)
	piece(parent, 0.5, 0.24, 0.1, 0.1, Color3.fromRGB(232, 160, 86), 0, true)
	piece(parent, 0.64, 0.3, 0.09, 0.09, Color3.fromRGB(232, 126, 142), 0, true)
end

local function moon(parent: Instance)
	wash(parent, Color3.fromRGB(38, 52, 86))
	piece(parent, 0.58, 0.32, 0.28, 0.28, Color3.fromRGB(236, 226, 196), 0, true)
	piece(parent, 0.64, 0.3, 0.22, 0.22, Color3.fromRGB(38, 52, 86), 0, true)
	piece(parent, 0.22, 0.2, 0.03, 0.03, Color3.fromRGB(236, 226, 196), 0, true)
	piece(parent, 0.3, 0.42, 0.02, 0.02, Color3.fromRGB(236, 226, 196), 0, true)
	piece(parent, 0.18, 0.55, 0.025, 0.025, Color3.fromRGB(236, 226, 196), 0, true)
	piece(parent, 0.5, 0.86, 1.1, 0.28, Color3.fromRGB(24, 32, 48), 0, true)
end

local function coast(parent: Instance)
	piece(parent, 0.5, 0.28, 1, 0.56, Color3.fromRGB(168, 196, 214), 0, false)
	piece(parent, 0.72, 0.22, 0.16, 0.16, Color3.fromRGB(255, 220, 160), 0, true)
	piece(parent, 0.5, 0.58, 1, 0.22, Color3.fromRGB(72, 132, 156), 0, false)
	piece(parent, 0.5, 0.72, 1, 0.16, Color3.fromRGB(96, 156, 170), 0, false)
	piece(parent, 0.5, 0.88, 1, 0.24, Color3.fromRGB(214, 186, 142), 0, false)
end

local function bloom(parent: Instance)
	wash(parent, Color3.fromRGB(236, 214, 196))
	for step = 0, 5 do
		local angle = step * 60
		local rad = math.rad(angle)
		piece(
			parent,
			0.5 + math.cos(rad) * 0.16,
			0.46 + math.sin(rad) * 0.16,
			0.22,
			0.14,
			Color3.fromRGB(196, 64, 78),
			angle,
			true
		)
	end
	piece(parent, 0.5, 0.46, 0.12, 0.12, Color3.fromRGB(120, 36, 48), 0, true)
	piece(parent, 0.5, 0.78, 0.03, 0.28, Color3.fromRGB(46, 92, 58), 0, true)
end

local drawers: { [string]: (Instance) -> () } = {
	garden = garden,
	dusk = dusk,
	vase = vase,
	moon = moon,
	coast = coast,
	bloom = bloom,
}

function WallPrint.draw(parent: Instance, kind: string)
	local draw = drawers[kind]
	if draw == nil then
		garden(parent)
		return
	end
	draw(parent)
end

return WallPrint
