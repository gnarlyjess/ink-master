--!strict

-- Everything the shop can sell or hand out. Cosmetics and creative tools only:
-- nothing here changes votes, so skill and ideas decide who wins.
-- Item ids are stable once shipped because they are saved in player data.

local InkColors = require(script.Parent.InkColors)
local StencilDefinitions = require(script.Parent.StencilDefinitions)

export type Category = "ink" | "pack" | "title" | "frame" | "confetti" | "emote"

export type Rgb = {
	r: number,
	g: number,
	b: number,
}

export type Item = {
	id: string,
	name: string,
	description: string,
	category: Category,
	price: number,
	level: number,
	earned: boolean,
	unlockText: string?,
	inkId: string?,
	stencils: { string }?,
	text: string?,
	accent: Rgb?,
	palette: { Rgb }?,
	-- How a frame is drawn, or how a win emote moves.
	style: string?,
}

export type CategoryInfo = {
	id: Category,
	label: string,
}

local Catalogue = {}

Catalogue.FEATURED_DISCOUNT = 0.2

Catalogue.categories = {
	{ id = "ink", label = "Inks" },
	{ id = "pack", label = "Shape packs" },
	{ id = "title", label = "Titles" },
	{ id = "frame", label = "Frames" },
	{ id = "confetti", label = "Party" },
	{ id = "emote", label = "Emotes" },
} :: { CategoryInfo }

local function rgb(r: number, g: number, b: number): Rgb
	return { r = r / 255, g = g / 255, b = b / 255 }
end

local items: { Item } = {}

local function ink(inkId: string, price: number, level: number, description: string)
	local swatch = InkColors.get(inkId)
	if swatch == nil then
		error(`[InkMasters] Catalogue ink {inkId} has no swatch`)
	end
	table.insert(items, {
		id = `ink:{inkId}`,
		name = `{swatch.name} ink`,
		description = description,
		category = "ink",
		price = price,
		level = level,
		earned = false,
		inkId = inkId,
		accent = { r = swatch.r, g = swatch.g, b = swatch.b },
	})
end

ink("ember", 120, 1, "A warm orange for flames and sunsets.")
ink("sky", 120, 1, "A clear blue for waves and wings.")
ink("mint", 120, 1, "Fresh green for leaves and frogs.")
ink("blush", 150, 2, "Soft pink for hearts and flowers.")
ink("plum", 150, 2, "A deep purple for moons and night skies.")
ink("forest", 150, 3, "Dark green for jungles and dragons.")
ink("copper", 200, 4, "Metallic brown for robots and treasure.")
ink("ice", 250, 5, "Pale frost for stars and snow.")
ink("lemon", 150, 1, "Bright yellow for suns, stars, and bees.")
ink("navy", 150, 1, "Deep blue for oceans and night letters.")
ink("coral", 160, 1, "Warm pink-orange for flowers and lips.")
ink("lime", 180, 2, "Sharp green for frogs, slime, and leaves.")
ink("lavender", 180, 2, "Soft purple for clouds and magic.")
ink("bubble", 180, 2, "Hot pink that reads from across the parlour.")
ink("crimson", 220, 3, "A darker red for roses and banners.")
ink("cobalt", 220, 3, "Strong blue for waves and jewels.")
ink("jade", 220, 3, "Rich green for snakes and gardens.")
ink("sand", 280, 4, "Warm tan for stone, skin, and gold dust.")
ink("amber", 280, 4, "Honey gold for treasure and sunlight.")
ink("slate", 280, 4, "Cool grey for metal, stone, and shadows.")
ink("wine", 340, 5, "Burgundy for velvet and dark roses.")
ink("rust", 340, 5, "Weathered orange for anchors and iron.")
ink("cream", 340, 5, "A soft highlight for stars and lace.")
ink("cyan", 420, 6, "Bright turquoise for water and neon signs.")
ink("indigo", 420, 6, "Between navy and violet, for night skies.")
ink("silver", 520, 8, "Cool metal for moons, chains, and robots.")

local function pack(id: string, name: string, description: string, price: number, level: number, stencils: { string })
	table.insert(items, {
		id = `pack:{id}`,
		name = name,
		description = description,
		category = "pack",
		price = price,
		level = level,
		earned = false,
		stencils = stencils,
	})
end

local function earnedPack(id: string, name: string, description: string, unlockText: string, stencils: { string })
	table.insert(items, {
		id = `pack:{id}`,
		name = name,
		description = description,
		category = "pack",
		price = 0,
		level = 1,
		earned = true,
		unlockText = unlockText,
		stencils = stencils,
	})
end

-- Free shapes stay out of every pack: circle, square, triangle, line, heart, star.
earnedPack("geometry", "Geometry", "Rectangle, oval, diamond, hex, drop, and arc.", "Reach level 4", {
	"rect",
	"ovalline",
	"gem",
	"hex",
	"dropline",
	"arc",
})
pack("motion", "Motion", "Arrow, cross, wave, zigzag, and blob.", 280, 2, {
	"pointer",
	"crossline",
	"wave",
	"zigzag",
	"blob",
})
pack("garden", "Sky and garden", "Moon, sun, flower, cloud, and leaf shapes.", 350, 2, {
	"moon",
	"sun",
	"flower",
	"cloud",
	"leaf",
})
pack("flash", "Bold flash", "Bolts, bursts, sparks, banners, and steps.", 400, 3, {
	"boltline",
	"burstline",
	"sparkline",
	"bannerline",
	"chevronline",
	"stepline",
})
pack("crest", "Royal crest", "A crown, a shield, and a watching eye.", 500, 5, {
	"crown",
	"shield",
	"eye",
})

local function title(id: string, name: string, text: string, description: string, price: number, level: number)
	table.insert(items, {
		id = `title:{id}`,
		name = name,
		description = description,
		category = "title",
		price = price,
		level = level,
		earned = false,
		text = text,
		accent = rgb(242, 196, 122),
	})
end

local function earnedTitle(id: string, name: string, text: string, description: string, unlockText: string)
	table.insert(items, {
		id = `title:{id}`,
		name = name,
		description = description,
		category = "title",
		price = 0,
		level = 1,
		earned = true,
		unlockText = unlockText,
		text = text,
		accent = rgb(242, 196, 122),
	})
end

title("steady", "Steady Hand", "Steady Hand", "Shown over your head and in the display case.", 200, 1)
title("liner", "Line Wizard", "Line Wizard", "For artists who love a clean line.", 250, 2)
title("collector", "Flash Collector", "Flash Collector", "A shelf full of shapes.", 400, 4)
title("needle", "Needle Hand", "Needle Hand", "Quick, bold, and confident.", 600, 6)
title("parlour", "Parlour Regular", "Parlour Regular", "You practically live here.", 1200, 12)
earnedTitle("rookie", "Ink Rookie", "Ink Rookie", "Your first milestone title.", "Reach level 3")
earnedTitle("legend", "Parlour Legend", "Parlour Legend", "Known by every artist in the shop.", "Reach level 10")
earnedTitle("master", "Ink Master", "Ink Master", "The shop's own title.", "Reach level 20")
earnedTitle("icon", "Living Icon", "Living Icon", "The top of the level track.", "Reach level 30")
earnedTitle("gold", "Gold Needle", "Gold Needle", "Awarded for winning five rounds.", "Win 5 rounds")

local FRAME_STYLES: { [string]: boolean } = {
	line = true,
	double = true,
	glow = true,
	neon = true,
	corners = true,
	banner = true,
	studs = true,
	inset = true,
}

local function frame(
	id: string,
	name: string,
	description: string,
	price: number,
	level: number,
	accent: Rgb,
	style: string
)
	if FRAME_STYLES[style] ~= true then
		error(`[InkMasters] Frame {id} has unknown style {style}`)
	end
	table.insert(items, {
		id = `frame:{id}`,
		name = name,
		description = description,
		category = "frame",
		price = price,
		level = level,
		earned = false,
		accent = accent,
		style = style,
	})
end

local function earnedFrame(id: string, name: string, description: string, unlockText: string, accent: Rgb, style: string)
	if FRAME_STYLES[style] ~= true then
		error(`[InkMasters] Frame {id} has unknown style {style}`)
	end
	table.insert(items, {
		id = `frame:{id}`,
		name = name,
		description = description,
		category = "frame",
		price = 0,
		level = 1,
		earned = true,
		unlockText = unlockText,
		accent = accent,
		style = style,
	})
end

frame("gold", "Gold frame", "A clean gold line around your display case.", 300, 2, rgb(242, 196, 122), "line")
frame("aqua", "Aqua frame", "A cool teal line around your showcase.", 300, 3, rgb(120, 230, 214), "line")
frame("violet", "Violet frame", "A rich purple line around your showcase.", 350, 4, rgb(176, 112, 255), "line")
frame("brass", "Brass double", "Two brass lines, like a classic frame.", 400, 3, rgb(196, 148, 72), "double")
frame("canopy", "Canopy", "Green ribbons across the top and bottom.", 420, 3, rgb(72, 168, 112), "banner")
frame("crop", "Flash crop", "Corner crop marks, like a flash sheet.", 450, 4, rgb(248, 244, 239), "corners")
frame("ribbon", "Ribbon", "Red bands, as if the case were wrapped.", 450, 4, rgb(214, 54, 72), "banner")
frame("studded", "Studded", "Magenta studs marching around the edge.", 500, 4, rgb(255, 78, 146), "studs")
frame("plaque", "Plaque", "An inset violet plate inside the border.", 520, 5, rgb(176, 112, 255), "inset")
frame("marquee", "Marquee", "A ring of gold studs, like a shop sign.", 560, 5, rgb(242, 196, 122), "studs")
frame("emberglow", "Ember glow", "A warm halo around your display case.", 580, 5, rgb(255, 120, 48), "glow")
frame("halo", "Halo", "A soft teal glow around the case.", 640, 6, rgb(120, 230, 214), "glow")
frame("lining", "Silver lining", "A double border in cool silver.", 680, 7, rgb(190, 198, 210), "double")
frame("neon", "Neon sign", "A hot pink tube, lit from the inside.", 720, 7, rgb(255, 70, 190), "neon")
frame("frost", "Frost pane", "A pale inner pane, like glass.", 740, 8, rgb(180, 220, 240), "inset")
frame("electric", "Electric", "A bright blue neon outline.", 860, 9, rgb(80, 150, 255), "neon")
earnedFrame("rose", "Rose frame", "A soft pink border.", "Reach level 8", rgb(255, 150, 186), "line")
earnedFrame("midnight", "Midnight frame", "A deep blue border.", "Reach level 25", rgb(90, 110, 220), "line")

local function confetti(id: string, name: string, description: string, price: number, level: number, palette: { Rgb })
	table.insert(items, {
		id = `confetti:{id}`,
		name = name,
		description = description,
		category = "confetti",
		price = price,
		level = level,
		earned = false,
		palette = palette,
	})
end

confetti("candy", "Cotton candy", "Pink and blue confetti when you take the podium.", 350, 2, {
	rgb(255, 150, 200),
	rgb(150, 200, 255),
	rgb(255, 255, 255),
})
confetti("rainbow", "Rainbow burst", "Every colour at once.", 450, 5, {
	rgb(255, 90, 90),
	rgb(255, 210, 90),
	rgb(90, 220, 140),
	rgb(90, 160, 255),
	rgb(190, 110, 255),
})
table.insert(items, {
	id = "confetti:aqua",
	name = "Aqua splash",
	description = "Teal and white confetti.",
	category = "confetti",
	price = 0,
	level = 1,
	earned = true,
	unlockText = "Reach level 5",
	palette = { rgb(120, 230, 214), rgb(255, 255, 255), rgb(60, 170, 190) },
})
table.insert(items, {
	id = "confetti:stars",
	name = "Midnight stars",
	description = "Gold and violet sparkle.",
	category = "confetti",
	price = 0,
	level = 1,
	earned = true,
	unlockText = "Reach level 15",
	palette = { rgb(242, 196, 122), rgb(176, 112, 255), rgb(255, 255, 255) },
})

local EMOTE_STYLES: { [string]: boolean } = {
	pop = true,
	bounce = true,
	shake = true,
	float = true,
	burst = true,
	stamp = true,
}

local function emote(
	id: string,
	name: string,
	text: string,
	description: string,
	price: number,
	level: number,
	style: string,
	accent: Rgb
)
	if EMOTE_STYLES[style] ~= true then
		error(`[InkMasters] Emote {id} has unknown style {style}`)
	end
	table.insert(items, {
		id = `emote:{id}`,
		name = name,
		description = description,
		category = "emote",
		price = price,
		level = level,
		earned = false,
		text = text,
		style = style,
		accent = accent,
	})
end

emote("woo", "Woo!", "WOO!", "Pops in gold when you take first.", 280, 2, "pop", rgb(242, 196, 122))
emote("yes", "Yes!", "YES!", "Bounces when the votes land your way.", 280, 2, "bounce", rgb(120, 230, 214))
emote("wow", "Wow", "WOW", "A bright bounce over the winning tattoo.", 320, 2, "bounce", rgb(255, 78, 146))
emote("bravo", "Bravo", "BRAVO", "A steady pop for a clean win.", 360, 3, "pop", rgb(248, 244, 239))
emote("hype", "Hype", "HYPE", "Shakes across the case.", 400, 3, "shake", rgb(255, 140, 90))
emote("fire", "Fire", "FIRE", "Shakes in ember orange.", 440, 4, "shake", rgb(255, 110, 40))
emote("boom", "Boom", "BOOM", "Bursts outward when you win.", 480, 4, "burst", rgb(255, 78, 146))
emote("spark", "Spark", "SPARK", "Gold sparks fly off the word.", 520, 5, "burst", rgb(242, 196, 122))
emote("clean", "So clean", "SO CLEAN", "Floats over a tidy winning piece.", 540, 5, "float", rgb(190, 230, 255))
emote("glow", "Glow", "GLOW", "Drifts up in teal.", 600, 6, "float", rgb(120, 230, 214))
emote("inked", "Ink'd", "INK'D", "Pops in parlour pink.", 640, 6, "pop", rgb(255, 78, 146))
emote("nailed", "Nailed it", "NAILED IT", "Stamps itself on the win.", 700, 7, "stamp", rgb(248, 244, 239))
emote("star", "Star", "STAR", "A burst of gold for a standout piece.", 760, 8, "burst", rgb(255, 214, 120))
emote("legend", "Legend", "LEGEND", "Bounces in violet. You earned the shout.", 880, 9, "bounce", rgb(176, 112, 255))
emote("crown", "Crown", "CROWN", "Stamps a gold seal on first place.", 980, 10, "stamp", rgb(242, 196, 122))

local byId: { [string]: Item } = {}
local packByStencil: { [string]: Item } = {}

local function lookup(id: string): Item?
	return byId[id]
end

local function packOf(stencilId: string): Item?
	return packByStencil[stencilId]
end

for _, item in items do
	if lookup(item.id) ~= nil then
		error(`[InkMasters] Duplicate catalogue id {item.id}`)
	end
	byId[item.id] = item
	local stencils = item.stencils
	if stencils ~= nil then
		for _, stencilId in stencils do
			if StencilDefinitions.get(stencilId) == nil then
				error(`[InkMasters] Pack {item.id} lists unknown shape {stencilId}`)
			end
			packByStencil[stencilId] = item
		end
	end
end

Catalogue.all = items

function Catalogue.get(id: string): Item?
	return byId[id]
end

function Catalogue.packFor(stencilId: string): Item?
	return packOf(stencilId)
end

function Catalogue.ownsInk(owned: { [string]: boolean }, swatchId: string): boolean
	local swatch = InkColors.get(swatchId)
	if swatch == nil then
		return false
	end
	if swatch.starter then
		return true
	end
	return owned[`ink:{swatchId}`] == true
end

function Catalogue.ownsStencil(owned: { [string]: boolean }, stencilId: string): boolean
	local bundle = packOf(stencilId)
	if bundle == nil then
		return true
	end
	return owned[bundle.id] == true
end

-- Items a player can buy with coins. Earned items are handed out by milestones.
local function buyable(): { Item }
	local list: { Item } = {}
	for _, item in items do
		if not item.earned and item.price >= 150 then
			table.insert(list, item)
		end
	end
	return list
end

-- One item is discounted for the whole UTC day, the same for every player.
function Catalogue.featuredId(day: number): string
	local list = buyable()
	local index = (day * 7 + 3) % #list + 1
	local chosen = list[index]
	if chosen == nil then
		error("[InkMasters] Catalogue has nothing to feature")
	end
	return chosen.id
end

function Catalogue.priceFor(item: Item, day: number): number
	if item.earned then
		return 0
	end
	if Catalogue.featuredId(day) == item.id then
		return math.floor(item.price * (1 - Catalogue.FEATURED_DISCOUNT))
	end
	return item.price
end

function Catalogue.toColor3(color: Rgb): Color3
	return Color3.new(color.r, color.g, color.b)
end

return Catalogue
