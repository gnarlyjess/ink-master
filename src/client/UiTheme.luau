--!strict

local UiTheme = {
	color = {
		ink = Color3.fromRGB(10, 9, 14),
		panel = Color3.fromRGB(22, 18, 30),
		panelTop = Color3.fromRGB(42, 30, 58),
		chip = Color3.fromRGB(38, 31, 52),
		track = Color3.fromRGB(54, 44, 70),
		text = Color3.fromRGB(248, 244, 239),
		muted = Color3.fromRGB(176, 166, 190),
		magenta = Color3.fromRGB(255, 78, 146),
		violet = Color3.fromRGB(176, 112, 255),
		gold = Color3.fromRGB(242, 196, 122),
		aqua = Color3.fromRGB(120, 230, 214),
		stroke = Color3.fromRGB(118, 90, 138),
		shadow = Color3.fromRGB(0, 0, 0),
	},
	font = {
		heavy = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		bold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
		medium = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
	},
}

return UiTheme
