--!strict

-- Prestige cosmetics: what high-level artists wear so the parlour can see them coming.
-- Auras climb from soft ink mist → full flash-sheet flex.

export type FlairId = "plain" | "mist" | "neon" | "gold" | "icon"

export type PlateStyle = {
	id: FlairId,
	height: number,
	width: number,
	studsY: number,
	chipTransparency: number,
	strokeThickness: number,
	strokeTransparency: number,
	textSize: number,
	rainbow: boolean,
	shimmer: boolean,
	sparkles: boolean,
	pulse: boolean,
	accent: Color3,
	accentB: Color3?,
}

export type AuraStyle = {
	id: string,
	inkColor: Color3,
	accent: Color3,
	accentB: Color3?,
	-- Visual budget climbs with tier.
	pool: boolean,
	poolSize: number,
	stencilDots: number,
	dripRate: number,
	vaporRate: number,
	needleRate: number,
	flashSymbols: { string },
	lightBrightness: number,
	lightRange: number,
	highlight: boolean,
	rainbow: boolean,
}

local Prestige = {}

Prestige.plates = {
	plain = {
		id = "plain",
		height = 34,
		width = 280,
		studsY = 2.85,
		chipTransparency = 0.18,
		strokeThickness = 1.6,
		strokeTransparency = 0.25,
		textSize = 17,
		rainbow = false,
		shimmer = false,
		sparkles = false,
		pulse = false,
		accent = Color3.fromRGB(242, 196, 122),
	},
	mist = {
		id = "mist",
		height = 36,
		width = 300,
		studsY = 2.95,
		chipTransparency = 0.12,
		strokeThickness = 2,
		strokeTransparency = 0.15,
		textSize = 17,
		rainbow = false,
		shimmer = false,
		sparkles = false,
		pulse = true,
		accent = Color3.fromRGB(255, 120, 180),
		accentB = Color3.fromRGB(255, 180, 220),
	},
	neon = {
		id = "neon",
		height = 40,
		width = 320,
		studsY = 3.05,
		chipTransparency = 0.08,
		strokeThickness = 2.4,
		strokeTransparency = 0.05,
		textSize = 18,
		rainbow = false,
		shimmer = true,
		sparkles = true,
		pulse = true,
		accent = Color3.fromRGB(255, 70, 190),
		accentB = Color3.fromRGB(64, 220, 255),
	},
	gold = {
		id = "gold",
		height = 44,
		width = 340,
		studsY = 3.15,
		chipTransparency = 0.05,
		strokeThickness = 2.8,
		strokeTransparency = 0,
		textSize = 19,
		rainbow = false,
		shimmer = true,
		sparkles = true,
		pulse = true,
		accent = Color3.fromRGB(255, 196, 64),
		accentB = Color3.fromRGB(255, 230, 140),
	},
	icon = {
		id = "icon",
		height = 48,
		width = 360,
		studsY = 3.3,
		chipTransparency = 0.02,
		strokeThickness = 3.2,
		strokeTransparency = 0,
		textSize = 20,
		rainbow = true,
		shimmer = true,
		sparkles = true,
		pulse = true,
		accent = Color3.fromRGB(255, 214, 64),
		accentB = Color3.fromRGB(255, 72, 168),
	},
} :: { [string]: PlateStyle }

-- Ladder: Fresh Ink → Neon Regular → Gold Needle → Living Icon
-- flashSymbols are traditional motif ids built as part assemblies in Auras.
Prestige.auras = {
	-- Soft ink + first tiny flash charms.
	mist = {
		id = "mist",
		inkColor = Color3.fromRGB(28, 18, 32),
		accent = Color3.fromRGB(255, 140, 190),
		pool = false,
		poolSize = 0,
		stencilDots = 10,
		dripRate = 0,
		vaporRate = 14,
		needleRate = 0,
		flashSymbols = { "star", "heart" },
		lightBrightness = 0.25,
		lightRange = 5,
		highlight = false,
		rainbow = false,
	},
	-- Wet ink pool + classic flash: rose, dagger, swallow.
	neon = {
		id = "neon",
		inkColor = Color3.fromRGB(18, 10, 24),
		accent = Color3.fromRGB(255, 50, 170),
		accentB = Color3.fromRGB(50, 220, 255),
		pool = true,
		poolSize = 3.4,
		stencilDots = 14,
		dripRate = 6,
		vaporRate = 18,
		needleRate = 10,
		flashSymbols = { "rose", "dagger", "swallow", "star" },
		lightBrightness = 0.4,
		lightRange = 6,
		highlight = false,
		rainbow = false,
	},
	-- Gold traditional sheet — denser orbiting flash.
	gold = {
		id = "gold",
		inkColor = Color3.fromRGB(22, 14, 10),
		accent = Color3.fromRGB(255, 190, 50),
		accentB = Color3.fromRGB(255, 230, 140),
		pool = true,
		poolSize = 3.8,
		stencilDots = 18,
		dripRate = 12,
		vaporRate = 22,
		needleRate = 16,
		flashSymbols = { "rose", "dagger", "swallow", "anchor", "skull", "banner" },
		lightBrightness = 0.55,
		lightRange = 7,
		highlight = false,
		rainbow = false,
	},
	-- Full flash wall: every classic motif + rainbow rim.
	icon = {
		id = "icon",
		inkColor = Color3.fromRGB(12, 6, 18),
		accent = Color3.fromRGB(255, 72, 168),
		accentB = Color3.fromRGB(64, 220, 255),
		pool = true,
		poolSize = 4.2,
		stencilDots = 22,
		dripRate = 18,
		vaporRate = 28,
		needleRate = 24,
		flashSymbols = { "rose", "dagger", "swallow", "anchor", "skull", "banner", "heart", "snake", "star" },
		lightBrightness = 0.7,
		lightRange = 8,
		highlight = true,
		rainbow = true,
	},
} :: { [string]: AuraStyle }

function Prestige.plate(flair: string?): PlateStyle
	if flair ~= nil and Prestige.plates[flair] ~= nil then
		return Prestige.plates[flair]
	end
	return Prestige.plates.plain
end

function Prestige.aura(style: string?): AuraStyle?
	if style == nil or style == "" then
		return nil
	end
	return Prestige.auras[style]
end

local AURA_RANK: { [string]: number } = {
	mist = 1,
	neon = 2,
	gold = 3,
	icon = 4,
}

function Prestige.auraRank(style: string?): number
	if style == nil then
		return 0
	end
	return AURA_RANK[style] or 0
end

return Prestige
