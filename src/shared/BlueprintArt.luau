--!strict

-- Classic cyanotype look: blue field + white scribbles / machine diagrams.
-- Used on world sheets (SurfaceGui) and the hunt HUD example.

local BLUE = Color3.fromRGB(22, 72, 162)
local LINE = Color3.fromRGB(245, 250, 255)

local BlueprintArt = {}

function BlueprintArt.blue(): Color3
	return BLUE
end

function BlueprintArt.line(): Color3
	return LINE
end

local function mark(parent: GuiObject, size: UDim2, pos: UDim2, rot: number?, transparency: number?)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = LINE
	f.BackgroundTransparency = transparency or 0.08
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = pos
	f.Rotation = rot or 0
	f.Parent = parent
	return f
end

local function label(parent: GuiObject, text: string, pos: UDim2, size: UDim2, textSize: number)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.Font = Enum.Font.Code
	t.Text = text
	t.TextColor3 = LINE
	t.TextTransparency = 0.12
	t.TextSize = textSize
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.TextWrapped = true
	t.Parent = parent
end

-- Dense white-on-blue diagram. `root` is a Frame filling the sheet.
function BlueprintArt.paint(root: Frame, seed: number?)
	local s = seed or 1
	root:ClearAllChildren()
	root.BackgroundColor3 = BLUE
	root.BackgroundTransparency = 0
	root.BorderSizePixel = 0

	-- Outer border
	mark(root, UDim2.new(1, 0, 0, 2), UDim2.fromScale(0, 0), 0, 0.05)
	mark(root, UDim2.new(1, 0, 0, 2), UDim2.new(0, 0, 1, -2), 0, 0.05)
	mark(root, UDim2.new(0, 2, 1, 0), UDim2.fromScale(0, 0), 0, 0.05)
	mark(root, UDim2.new(0, 2, 1, 0), UDim2.new(1, -2, 0, 0), 0, 0.05)

	-- Light grid
	for i = 1, 5 do
		local u = i / 6
		mark(root, UDim2.new(1, -8, 0, 1), UDim2.new(0, 4, u, 0), 0, 0.75)
		mark(root, UDim2.new(0, 1, 1, -8), UDim2.new(u, 0, 0, 4), 0, 0.75)
	end

	-- Coil / motor block
	mark(root, UDim2.fromScale(0.28, 0.22), UDim2.fromScale(0.1, 0.16), 0, 0.84)
	mark(root, UDim2.new(0.28, 0, 0, 2), UDim2.fromScale(0.1, 0.16), 0, 0.08)
	mark(root, UDim2.new(0.28, 0, 0, 2), UDim2.fromScale(0.1, 0.38), 0, 0.08)
	mark(root, UDim2.new(0, 2, 0.22, 0), UDim2.fromScale(0.1, 0.16), 0, 0.08)
	mark(root, UDim2.new(0, 2, 0.22, 0), UDim2.fromScale(0.38, 0.16), 0, 0.08)
	for i = 0, 5 do
		mark(root, UDim2.new(0.2, 0, 0, 1), UDim2.fromScale(0.14, 0.2 + i * 0.03), (s % 3) - 1, 0.18)
	end

	-- Needle arm
	mark(root, UDim2.new(0.34, 0, 0, 2), UDim2.fromScale(0.42, 0.26), -10, 0.06)
	mark(root, UDim2.fromScale(0.07, 0.07), UDim2.fromScale(0.72, 0.22), 45, 0.12)
	mark(root, UDim2.new(0, 2, 0.14, 0), UDim2.fromScale(0.78, 0.18), 14, 0.1)

	-- Frame / grip
	mark(root, UDim2.fromScale(0.18, 0.34), UDim2.fromScale(0.12, 0.48), 0, 0.86)
	mark(root, UDim2.new(0.18, 0, 0, 2), UDim2.fromScale(0.12, 0.48), 0, 0.08)
	mark(root, UDim2.new(0.18, 0, 0, 2), UDim2.fromScale(0.12, 0.82), 0, 0.08)
	mark(root, UDim2.new(0, 2, 0.34, 0), UDim2.fromScale(0.12, 0.48), 0, 0.08)
	mark(root, UDim2.new(0, 2, 0.34, 0), UDim2.fromScale(0.3, 0.48), 0, 0.08)
	for i = 0, 4 do
		mark(root, UDim2.new(0.12, 0, 0, 1), UDim2.fromScale(0.15, 0.54 + i * 0.05), 0, 0.22)
	end

	-- Power pack
	mark(root, UDim2.fromScale(0.22, 0.15), UDim2.fromScale(0.48, 0.56), 0, 0.84)
	mark(root, UDim2.new(0.22, 0, 0, 2), UDim2.fromScale(0.48, 0.56), 0, 0.08)
	mark(root, UDim2.new(0.22, 0, 0, 2), UDim2.fromScale(0.48, 0.71), 0, 0.08)
	mark(root, UDim2.new(0, 2, 0.15, 0), UDim2.fromScale(0.48, 0.56), 0, 0.08)
	mark(root, UDim2.new(0, 2, 0.15, 0), UDim2.fromScale(0.7, 0.56), 0, 0.08)
	mark(root, UDim2.new(0.2, 0, 0, 1), UDim2.fromScale(0.7, 0.62), 20, 0.12)
	mark(root, UDim2.new(0.14, 0, 0, 1), UDim2.fromScale(0.82, 0.68), -24, 0.18)

	-- Random scribble strokes
	local scribbles = {
		{ UDim2.new(0.16, 0, 0, 1), UDim2.fromScale(0.55, 0.2), 32 },
		{ UDim2.new(0.12, 0, 0, 1), UDim2.fromScale(0.62, 0.34), -18 },
		{ UDim2.new(0.1, 0, 0, 1), UDim2.fromScale(0.36, 0.72), 8 },
		{ UDim2.new(0.18, 0, 0, 1), UDim2.fromScale(0.4, 0.4), -6 },
		{ UDim2.new(0.08, 0, 0, 1), UDim2.fromScale(0.22, 0.68), 40 },
	}
	for i, sc in scribbles do
		local rot = (sc[3] :: number) + ((s + i) % 5)
		mark(root, sc[1] :: UDim2, sc[2] :: UDim2, rot, 0.2)
	end

	-- Dimension bar
	mark(root, UDim2.new(0.3, 0, 0, 1), UDim2.fromScale(0.4, 0.88), 0, 0.18)
	mark(root, UDim2.new(0, 1, 0.05, 0), UDim2.fromScale(0.4, 0.86), 0, 0.18)
	mark(root, UDim2.new(0, 1, 0.05, 0), UDim2.fromScale(0.7, 0.86), 0, 0.18)

	label(root, "TATTOO MACHINE  —  ASSY.", UDim2.fromScale(0.08, 0.03), UDim2.fromScale(0.84, 0.1), 11)
	label(root, "FIG.A coil\nFIG.B frame\nREV 03", UDim2.fromScale(0.74, 0.4), UDim2.fromScale(0.22, 0.28), 9)
	label(root, string.format("SH %d/4", ((s - 1) % 4) + 1), UDim2.fromScale(0.08, 0.9), UDim2.fromScale(0.3, 0.08), 10)
end

return BlueprintArt
