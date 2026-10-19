--!strict

local UiTheme = {
	color = {
		ink = Color3.fromRGB(16, 12, 18),
		panel = Color3.fromRGB(22, 16, 24),
		panelTop = Color3.fromRGB(36, 26, 34),
		chip = Color3.fromRGB(42, 32, 40),
		track = Color3.fromRGB(54, 40, 48),
		text = Color3.fromRGB(248, 244, 239),
		muted = Color3.fromRGB(176, 160, 168),
		magenta = Color3.fromRGB(214, 54, 98),
		violet = Color3.fromRGB(176, 112, 255),
		gold = Color3.fromRGB(212, 164, 92),
		aqua = Color3.fromRGB(120, 186, 170),
		stroke = Color3.fromRGB(92, 64, 72),
		shadow = Color3.fromRGB(0, 0, 0),
		-- Flash sheet. Dark screens keep the keys above. Paper is for catalogues and the shape book.
		paper = Color3.fromRGB(236, 226, 204),
		paperDeep = Color3.fromRGB(214, 198, 170),
		inkMuted = Color3.fromRGB(104, 82, 72),
		oxblood = Color3.fromRGB(122, 36, 52),
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
}

return UiTheme
