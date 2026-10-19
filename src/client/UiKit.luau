--!strict

-- Small builders shared by the menu screens so they all look like the same game.

local UiTheme = require(script.Parent.UiTheme)

local UiKit = {}

function UiKit.corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

function UiKit.stroke(parent: Instance, color: Color3, thickness: number, transparency: number): UIStroke
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = color
	uiStroke.Thickness = thickness
	uiStroke.Transparency = transparency
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Parent = parent
	return uiStroke
end

function UiKit.padding(parent: Instance, top: number, right: number, bottom: number, left: number)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, top)
	pad.PaddingRight = UDim.new(0, right)
	pad.PaddingBottom = UDim.new(0, bottom)
	pad.PaddingLeft = UDim.new(0, left)
	pad.Parent = parent
end

function UiKit.list(parent: Instance, direction: Enum.FillDirection, gap: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function UiKit.frame(parent: Instance, color: Color3, transparency: number): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

function UiKit.label(parent: Instance, text: string, size: number, face: Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.FontFace = face
	label.TextSize = size
	label.TextColor3 = color
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.AutoLocalize = false
	label.Parent = parent
	return label
end

function UiKit.button(
	parent: Instance,
	text: string,
	size: number,
	color: Color3,
	background: Color3,
	radius: number?
): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = background
	button.BorderSizePixel = 0
	button.FontFace = UiTheme.font.bold
	button.TextSize = size
	button.TextColor3 = color
	button.Text = text
	button.AutoLocalize = false
	button.Parent = parent
	UiKit.corner(button, if radius == nil then 10 else radius)
	return button
end

function UiKit.bar(parent: Instance, fillColor: Color3): (Frame, Frame)
	local track = UiKit.frame(parent, UiTheme.color.track, 0)
	UiKit.corner(track, 6)
	local fill = UiKit.frame(track, fillColor, 0)
	fill.Size = UDim2.fromScale(0, 1)
	UiKit.corner(fill, 6)
	return track, fill
end

function UiKit.setBar(fill: Frame, ratio: number)
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
end

-- 1234567 becomes "1,234,567".
function UiKit.number(value: number): string
	local text = tostring(math.floor(value + 0.5))
	local result = text
	while true do
		local replaced, count = string.gsub(result, "^(-?%d+)(%d%d%d)", "%1,%2")
		result = replaced
		if count == 0 then
			break
		end
	end
	return result
end

function UiKit.duration(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	if hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m`
end

return UiKit
