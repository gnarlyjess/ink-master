--!strict

-- Parlour ink base + candy-bright accents. Kids read colour before copy —
-- hot pink / cyan / lime / sunshine pull the eye; gold stays the "money" signal.

local UiTheme = {
	color = {
		ink = Color3.fromRGB(18, 10, 28),
		panel = Color3.fromRGB(32, 18, 48),
		panelTop = Color3.fromRGB(52, 28, 72),
		chip = Color3.fromRGB(58, 36, 78),
		track = Color3.fromRGB(72, 44, 96),
		text = Color3.fromRGB(255, 250, 245),
		muted = Color3.fromRGB(188, 168, 198),
		magenta = Color3.fromRGB(255, 64, 140),
		hotPink = Color3.fromRGB(255, 72, 168),
		violet = Color3.fromRGB(168, 96, 255),
		electric = Color3.fromRGB(64, 220, 255),
		lime = Color3.fromRGB(120, 255, 96),
		sunshine = Color3.fromRGB(255, 214, 64),
		coral = Color3.fromRGB(255, 110, 88),
		gold = Color3.fromRGB(255, 196, 64),
		aqua = Color3.fromRGB(72, 236, 210),
		stroke = Color3.fromRGB(120, 72, 140),
		shadow = Color3.fromRGB(0, 0, 0),
		-- Flash sheet. Dark screens keep the keys above. Paper is for catalogues and the shape book.
		paper = Color3.fromRGB(255, 246, 232),
		paperDeep = Color3.fromRGB(255, 220, 180),
		inkMuted = Color3.fromRGB(120, 88, 110),
		oxblood = Color3.fromRGB(200, 40, 90),
	},
	-- Party burst palette — confetti, rays, button shimmer.
	candy = {
		Color3.fromRGB(255, 72, 168),
		Color3.fromRGB(64, 220, 255),
		Color3.fromRGB(255, 214, 64),
		Color3.fromRGB(120, 255, 96),
		Color3.fromRGB(168, 96, 255),
		Color3.fromRGB(255, 110, 88),
		Color3.fromRGB(72, 236, 210),
		Color3.fromRGB(255, 140, 220),
	},
	font = {
		heavy = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		bold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
		medium = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
	},
	-- One set of margins so the banner, the side panels, and the bottom bar never share a pixel.
	-- Desktop reference sizes; use editorLayout() on phones so the canvas keeps the same share.
	safe = {
		top = 68,
		bottom = 84,
		side = 16,
		dock = 300,
	},
	-- Canvas editor chrome — quiet dark tools around the stage (not the lobby candy look).
	editor = {
		bg = Color3.fromRGB(22, 24, 28),
		surface = Color3.fromRGB(32, 35, 40),
		raised = Color3.fromRGB(42, 46, 52),
		hairline = Color3.fromRGB(58, 62, 70),
		text = Color3.fromRGB(236, 238, 242),
		muted = Color3.fromRGB(148, 154, 164),
		accent = Color3.fromRGB(64, 168, 255),
		danger = Color3.fromRGB(255, 96, 112),
	},
}

export type EditorLayout = {
	side: number,
	top: number,
	bottom: number,
	leftWidth: number,
	rightWidth: number,
	leftExtra: number,
	dock: number,
}

-- Scale the Studio panels with the viewport so phones keep a desktop-like canvas ratio.
function UiTheme.editorLayout(view: Vector2): EditorLayout
	local scaleX = math.clamp(view.X / 1280, 0.42, 1)
	local scaleY = math.clamp(view.Y / 720, 0.5, 1)
	local side = math.max(8, math.floor(UiTheme.safe.side * scaleX + 0.5))
	local top = math.max(36, math.floor(UiTheme.safe.top * scaleY + 0.5))
	local bottom = math.max(40, math.floor(UiTheme.safe.bottom * scaleY + 0.5))
	local gap = math.max(6, math.floor(12 * scaleX + 0.5))
	local leftWidth = math.clamp(math.floor(256 * scaleX + 0.5), 128, 256)
	local rightWidth = math.clamp(math.floor(UiTheme.safe.dock * scaleX + 0.5), 148, UiTheme.safe.dock)

	-- Panels + gutters may use at most ~46% of width; canvas keeps the rest.
	local chrome = leftWidth + rightWidth + side * 2 + gap * 2
	local maxChrome = view.X * 0.46
	if view.X > 1 and chrome > maxChrome then
		local shrink = maxChrome / chrome
		leftWidth = math.max(112, math.floor(leftWidth * shrink))
		rightWidth = math.max(128, math.floor(rightWidth * shrink))
		side = math.max(6, math.floor(side * shrink))
		gap = math.max(4, math.floor(gap * shrink))
	end

	return {
		side = side,
		top = top,
		bottom = bottom,
		leftWidth = leftWidth,
		rightWidth = rightWidth,
		leftExtra = leftWidth + gap,
		dock = rightWidth,
	}
end

-- White padlock silhouette (assets/ui/padlock.png) — tinted grey via ImageColor3.
-- Emoji locks stay yellow on Roblox and can't be recolored.
local PADLOCK_IMAGE = "rbxassetid://82367063203571"

function UiTheme.greyLock(parent: Instance, pixel: number?, zIndex: number?): Frame
	local size = pixel or 22
	local root = Instance.new("Frame")
	root.Name = "Lock"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(size, size)
	root.ZIndex = zIndex or 3
	root.Visible = false
	root.Parent = parent

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(1, 1)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = PADLOCK_IMAGE
	icon.ImageColor3 = UiTheme.editor.muted
	icon.ImageTransparency = 0.05
	icon.ZIndex = root.ZIndex
	icon.Parent = root

	return root
end

return UiTheme
