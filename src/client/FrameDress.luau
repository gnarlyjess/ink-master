--!strict

-- Draws the equipped display-case frame. Each style is a different shape,
-- so two frames in the same colour still look unlike each other.

local UiKit = require(script.Parent.UiKit)

local FrameDress = {}

local function piece(parent: Instance, color: Color3): Frame
	local frame = UiKit.frame(parent, color, 0)
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.Interactable = false
	return frame
end

local function lighten(color: Color3): Color3
	return color:Lerp(Color3.new(1, 1, 1), 0.55)
end

function FrameDress.clear(parent: Instance)
	local old = parent:FindFirstChild("Dress")
	if old ~= nil then
		old:Destroy()
	end
end

function FrameDress.mount(parent: GuiObject, style: string, color: Color3, radius: number)
	FrameDress.clear(parent)
	local root = Instance.new("Frame")
	root.Name = "Dress"
	root.Active = false
	root.Interactable = false
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = parent.ZIndex + 1
	root.Parent = parent

	if style == "double" then
		UiKit.stroke(root, color, 4, 0)
		UiKit.corner(root, radius)
		local inner = piece(root, color)
		inner.BackgroundTransparency = 1
		inner.Position = UDim2.fromOffset(8, 8)
		inner.Size = UDim2.new(1, -16, 1, -16)
		UiKit.stroke(inner, color, 2, 0)
		UiKit.corner(inner, math.max(4, radius - 6))
	elseif style == "glow" then
		UiKit.stroke(root, color, 12, 0.4)
		UiKit.corner(root, radius)
		local core = piece(root, color)
		core.BackgroundTransparency = 1
		core.Size = UDim2.fromScale(1, 1)
		UiKit.stroke(core, color, 2, 0)
		UiKit.corner(core, radius)
	elseif style == "neon" then
		UiKit.stroke(root, color, 8, 0.05)
		UiKit.corner(root, radius)
		local core = piece(root, lighten(color))
		core.BackgroundTransparency = 1
		core.Position = UDim2.fromOffset(6, 6)
		core.Size = UDim2.new(1, -12, 1, -12)
		UiKit.stroke(core, lighten(color), 2, 0)
		UiKit.corner(core, math.max(4, radius - 4))
	elseif style == "corners" then
		UiKit.stroke(root, color, 1, 0.55)
		UiKit.corner(root, radius)
		local arm = 22
		local thick = 4
		local function bracket(x: number, y: number, ax: number, ay: number)
			local across = piece(root, color)
			across.AnchorPoint = Vector2.new(ax, ay)
			across.Position = UDim2.fromScale(x, y)
			across.Size = UDim2.fromOffset(arm, thick)
			local down = piece(root, color)
			down.AnchorPoint = Vector2.new(ax, ay)
			down.Position = UDim2.fromScale(x, y)
			down.Size = UDim2.fromOffset(thick, arm)
		end
		bracket(0, 0, 0, 0)
		bracket(1, 0, 1, 0)
		bracket(0, 1, 0, 1)
		bracket(1, 1, 1, 1)
	elseif style == "banner" then
		UiKit.stroke(root, color, 1.5, 0.25)
		UiKit.corner(root, radius)
		local top = piece(root, color)
		top.Size = UDim2.new(1, 0, 0, 8)
		local bottom = piece(root, color)
		bottom.AnchorPoint = Vector2.new(0, 1)
		bottom.Position = UDim2.fromScale(0, 1)
		bottom.Size = UDim2.new(1, 0, 0, 8)
	elseif style == "studs" then
		UiKit.stroke(root, color, 1, 0.65)
		UiKit.corner(root, radius)
		local function stud(x: number, y: number, ax: number, ay: number)
			local dot = piece(root, color)
			dot.AnchorPoint = Vector2.new(ax, ay)
			dot.Position = UDim2.fromScale(x, y)
			dot.Size = UDim2.fromOffset(7, 7)
			UiKit.corner(dot, 2)
		end
		for index = 0, 7 do
			local along = if index == 0 then 0.06 elseif index == 7 then 0.94 else index / 7
			stud(along, 0.015, 0.5, 0)
			stud(along, 0.985, 0.5, 1)
		end
		for index = 1, 6 do
			local along = index / 7
			stud(0.02, along, 0, 0.5)
			stud(0.98, along, 1, 0.5)
		end
	elseif style == "inset" then
		UiKit.stroke(root, color, 1.5, 0.35)
		UiKit.corner(root, radius)
		local inner = piece(root, color)
		inner.BackgroundTransparency = 1
		inner.Position = UDim2.fromOffset(10, 10)
		inner.Size = UDim2.new(1, -20, 1, -20)
		UiKit.stroke(inner, color, 3, 0)
		UiKit.corner(inner, math.max(4, radius - 6))
	else
		UiKit.stroke(root, color, 3, 0)
		UiKit.corner(root, radius)
	end
end

return FrameDress
