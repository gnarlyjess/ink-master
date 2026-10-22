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
