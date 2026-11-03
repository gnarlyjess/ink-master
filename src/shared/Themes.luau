--!strict

-- Stable ids. Add rows here when the catalogue grows. Do not rename an id once it is saved.
-- Prompt rule (Draw Something / Dress to Impress):
-- specific enough a kid knows what to start, broad enough for many cool answers.
-- Taglines name 2–3 example directions — never "anything" or pure art-jargon.

export type ThemeDefinition = {
	id: string,
	name: string,
	tagline: string,
}

local catalogue: { ThemeDefinition } = {
	-- Creatures kids know
	{ id = "cats", name = "Cats", tagline = "A cat — sleepy, fierce, or wearing something silly." },
	{ id = "dogs", name = "Dogs", tagline = "A dog — puppy, cool hound, or goofy grin." },
	{ id = "ocean-animals", name = "Ocean Animals", tagline = "A sea creature — shark, jellyfish, octopus, or whale." },
	{ id = "jungle-animals", name = "Jungle Animals", tagline = "A jungle animal — parrot, frog, tiger, or monkey." },
	{ id = "farm-animals", name = "Farm Animals", tagline = "A farm animal — cow, pig, chicken, or horse." },
	{ id = "dinosaurs", name = "Dinosaurs", tagline = "One dinosaur — T-Rex, triceratops, or something tiny." },
	{ id = "cute-animals", name = "Cute Animals", tagline = "Something adorable — bunny, puppy, panda, or chick." },
	{ id = "sharks", name = "Sharks", tagline = "A shark — scary, smiling, or surfing." },
	{ id = "snakes", name = "Snakes", tagline = "A snake — coiled, sneaky, or with a funny face." },
	{ id = "butterflies-and-moths", name = "Butterflies & Moths", tagline = "Wings — butterfly, moth, or a fancy pattern." },
	{ id = "birds-of-prey", name = "Birds", tagline = "A bird — eagle, owl, parrot, or tiny sparrow." },
	{ id = "spiders-and-insects", name = "Bugs", tagline = "A bug — bee, beetle, spider, or ladybug." },
	{ id = "weird-animals", name = "Weird Animals", tagline = "Nature's oddballs — platypus, axolotl, or blobfish." },
	{ id = "animal-hybrids", name = "Animal Mashup", tagline = "Two animals mixed — cat-fish, dog-dragon, etc." },

	-- Fantasy everyone gets
	{ id = "dragons", name = "Dragons", tagline = "A dragon — cute, scary, or tiny on a treasure pile." },
	{ id = "unicorns", name = "Unicorns", tagline = "A unicorn — sparkly, chill, or totally extra." },
	{ id = "mermaids", name = "Mermaids", tagline = "A mermaid or merman — tail, shells, ocean vibes." },
	{ id = "fairies", name = "Fairies", tagline = "A fairy — wings, wand, or flower crown." },
	{ id = "phoenixes", name = "Phoenix", tagline = "A firebird rising — flames and feathers." },
	{ id = "fantasy-pets", name = "Fantasy Pets", tagline = "A magical pet — mini dragon, glow fox, or cloud bunny." },
	{ id = "monsters", name = "Monsters", tagline = "A monster — silly, spooky, or unexpectedly cute." },
	{ id = "aliens", name = "Aliens", tagline = "An alien — big eyes, weird limbs, or a flying saucer." },
	{ id = "robots", name = "Robots", tagline = "A robot — friendly bot, giant mech, or tiny gadget buddy." },
	{ id = "superheroes", name = "Superheroes", tagline = "A hero you invent — cape, mask, or power pose." },
	{ id = "villains", name = "Villains", tagline = "A bad guy you invent — mask, laugh, or evil pet." },
	{ id = "pirates", name = "Pirates", tagline = "Pirate stuff — ship, map, parrot, or treasure chest." },
	{ id = "wizards-and-witches", name = "Wizards & Witches", tagline = "A spellcaster — hat, wand, potion, or familiar." },
	{ id = "magical-artefacts", name = "Magic Items", tagline = "One enchanted object — sword, crystal, book, or ring." },

	-- Food & treats (concrete)
	{ id = "desserts", name = "Desserts", tagline = "Something sweet — cake, ice cream, donut, or cookie." },
	{ id = "fast-food", name = "Fast Food", tagline = "A fast-food fave — burger, fries, pizza slice, or taco." },
	{ id = "food-characters", name = "Food With a Face", tagline = "Food that's alive — happy pizza, grumpy pickle, etc." },
	{ id = "drinks", name = "Drinks", tagline = "A drink — smoothie, soda, milkshake, or fancy cup." },
	{ id = "weird-food-combinations", name = "Weird Food Combo", tagline = "Two foods that shouldn't meet — invent the mashup." },

	-- Everyday & objects (specific)
	{ id = "emoji", name = "Emoji", tagline = "Turn one emoji into a tattoo — smile, fire, skull, etc." },
	{ id = "silly-faces", name = "Silly Faces", tagline = "One ridiculous face — goofy, shocked, or stuck-out tongue." },
	{ id = "toys-and-plushies", name = "Toys & Plushies", tagline = "A toy — teddy, action figure, rubber duck, or doll." },
	{ id = "shoes-and-sneakers", name = "Cool Shoes", tagline = "A pair of shoes — sneakers, boots, or wild kicks." },
	{ id = "jewellery", name = "Jewellery", tagline = "One piece — ring, necklace, charm, or earrings." },
	{ id = "musical-instruments", name = "Instruments", tagline = "One instrument — guitar, drums, piano, or mic." },
	{ id = "vehicles", name = "Vehicles", tagline = "Something that moves — car, bike, skateboard, or scooter." },
	{ id = "things-with-faces", name = "Objects With Faces", tagline = "Give an object a face — toaster, cloud, shoe, etc." },
	{ id = "tiny-things", name = "Tiny Things", tagline = "Something normally big, drawn tiny — or a tiny hero." },
	{ id = "giant-things", name = "Giant Things", tagline = "Something huge — giant snack, monster shoe, big bug." },

	-- Games & internet (specific, kid-safe)
	{ id = "minecraft", name = "Minecraft", tagline = "Minecraft vibes — creeper, pickaxe, blocky pet, or sword." },
	{ id = "retro-gaming", name = "Retro Games", tagline = "Old-school gaming — pixels, arcade, or classic console." },
	{ id = "gaming", name = "Gamer Gear", tagline = "Gamer stuff — controller, headset, or pixel heart." },
	{ id = "kawaii", name = "Kawaii", tagline = "Super cute style — big eyes, pastel, tiny and sweet." },
	{ id = "cartoon-characters", name = "Original Cartoon", tagline = "Invent a cartoon character — not a copy of a real show." },
	{ id = "school-doodles", name = "Notebook Doodles", tagline = "Margin doodles — stars, names, arrows, bored-in-class art." },
	{ id = "fake-brands", name = "Fake Brand", tagline = "Invent a funny brand logo for something silly." },

	-- Nature (concrete)
	{ id = "flowers", name = "Flowers", tagline = "A flower — rose, sunflower, daisy, or wild bloom." },
	{ id = "mushrooms", name = "Mushrooms", tagline = "Mushrooms — cute toadstool, fancy caps, or a little cluster." },
	{ id = "cacti-and-succulents", name = "Cacti", tagline = "A cactus or succulent — spiky, cute, or in a pot." },
	{ id = "sun-moon-and-stars", name = "Sun, Moon & Stars", tagline = "Night-sky marks — sun face, crescent moon, or star cluster." },
	{ id = "planets-and-galaxies", name = "Space", tagline = "Space stuff — planet, rocket, astronaut, or galaxy swirl." },
	{ id = "mountains", name = "Mountains", tagline = "Mountain scene — peaks, cabin, or hiking trail." },
	{ id = "weather", name = "Weather", tagline = "Weather — storm cloud, rainbow, sun, or snowflake." },
	{ id = "volcanoes", name = "Volcanoes", tagline = "A volcano — erupting, chill, or with a tiny house on top." },
	{ id = "crystals-and-gems", name = "Crystals & Gems", tagline = "A gem — crystal cluster, diamond, or glowing stone." },
	{ id = "camping", name = "Camping", tagline = "Camping trip — tent, campfire, marshmallow, or lantern." },

	-- Classic tattoo flash (subject + vibe, not jargon)
	{ id = "traditional-tattoo-flash", name = "Classic Flash", tagline = "Old-school tattoo — rose, dagger, swallow, or banner." },
	{ id = "old-school-sailor", name = "Sailor Tattoo", tagline = "Sailor classic — anchor, ship, swallow, or heart banner." },
	{ id = "hearts", name = "Hearts", tagline = "A heart — simple, broken, winged, or with a banner." },
	{ id = "daggers", name = "Daggers", tagline = "A dagger — with rose, snake, banner, or sparkles." },
	{ id = "flames", name = "Flames", tagline = "Fire — flame shape, burning heart, or hot rod flames." },
	{ id = "eyes", name = "Eyes", tagline = "An eye — all-seeing, crying, cat eye, or triangle eye." },
	{ id = "wings", name = "Wings", tagline = "Wings — angel, bat, butterfly, or mechanical." },
	{ id = "crowns", name = "Crowns", tagline = "A crown — royal, tiny, cracked, or on a skull." },
	{ id = "skulls", name = "Skulls", tagline = "A skull — cute, scary, floral, or with sunglasses." },
	{ id = "lucky-charms", name = "Lucky Charms", tagline = "Lucky charm — clover, horseshoe, dice, or star." },
	{ id = "keys-and-locks", name = "Keys & Locks", tagline = "A key, a lock, or both — fancy or spooky." },
	{ id = "graffiti", name = "Graffiti", tagline = "Street style — bold letters, drips, or a tag design." },
	{ id = "geometric", name = "Geometric", tagline = "Clean shapes — triangles, circles, or a geometric animal." },
	{ id = "sticker-tattoos", name = "Sticker Style", tagline = "Looks like a sticker — bold outline, cute, collectible." },

	-- Spooky (kid-level, not horror essay)
	{ id = "halloween", name = "Halloween", tagline = "Halloween — pumpkin, ghost, candy, or costume." },
	{ id = "ghosts", name = "Ghosts", tagline = "A ghost — classic sheet, cute, or mischievous." },
	{ id = "skeletons", name = "Skeletons", tagline = "A skeleton — dancing, casual, or wearing a hat." },
	{ id = "vampires", name = "Vampires", tagline = "A vampire — fangs, cape, or bat form." },
	{ id = "witches", name = "Witches", tagline = "Witchy — hat, broom, cat, or potion bottle." },
	{ id = "haunted-houses", name = "Haunted House", tagline = "A spooky house — crooked, glowing windows, bats." },
	{ id = "spooky-objects", name = "Spooky Objects", tagline = "Something eerie — candle, mirror, potion, or doll." },

	-- Cyber / neon (visual, not jargon)
	{ id = "cyberpunk", name = "Neon City", tagline = "Neon night — city lights, chrome, or a glowing character." },
	{ id = "synthwave", name = "Synthwave", tagline = "80s sunset vibes — palm, grid, car, or neon sun." },
	{ id = "glitch-art", name = "Glitch", tagline = "Broken digital look — glitchy face, heart, or animal." },
	{ id = "mechs-and-exosuits", name = "Giant Mechs", tagline = "A mech or robot suit — big, chunky, and cool." },

	-- Occasions / Dress-to-Impress style vibes
	{ id = "summer", name = "Summer Vibes", tagline = "Summer — ice cream, sunglasses, beach, or sun." },
	{ id = "winter", name = "Winter Vibes", tagline = "Winter — snowman, cocoa, scarf, or snowflake." },
	{ id = "birthday-party", name = "Birthday Party", tagline = "Birthday — cake, balloons, gift, or party hat." },
	{ id = "valentines-day", name = "Valentine's", tagline = "Love vibes — heart, roses, love letter, or crush note." },
	{ id = "christmas", name = "Christmas", tagline = "Christmas — tree, gift, candy cane, or cozy mug." },
	{ id = "back-to-school", name = "Back to School", tagline = "School stuff — backpack, pencil, apple, or bus." },
	{ id = "beach-day", name = "Beach Day", tagline = "Beach day — wave, palm, surfboard, or sandcastle." },
	{ id = "sleepover", name = "Sleepover", tagline = "Sleepover — pillow fort, snacks, PJs, or fairy lights." },
	{ id = "sports-day", name = "Sports", tagline = "A sport moment — ball, trophy, sneakers, or jersey number." },
	{ id = "concert-night", name = "Concert Night", tagline = "Live show energy — mic, speakers, crowd hearts, or tickets." },

	-- Humour (clear game)
	{ id = "bad-tattoos", name = "Bad Tattoos", tagline = "Intentionally awful ink — funny on purpose." },
	{ id = "puns", name = "Pun Tattoos", tagline = "A visual pun — wordplay you can see." },
	{ id = "unhinged-animals", name = "Chaos Animals", tagline = "Animals behaving badly — chaos gremlin energy." },
	{ id = "opposites", name = "Opposites", tagline = "Two opposites in one piece — hot/cold, big/small, etc." },
	{ id = "unexpected-combinations", name = "Weird Combo", tagline = "Two things mashed — pizza dragon, taco cat, etc." },
}

local Themes = {
	all = catalogue,
}

local random = Random.new()
local lastThemeId: string? = nil

function Themes.validate()
	if #catalogue == 0 then
		error("[InkRivalry] Theme catalogue is empty")
	end

	local seen: { [string]: boolean } = {}
	for _, theme in catalogue do
		if theme.id == "" or theme.name == "" or theme.tagline == "" then
			error("[InkRivalry] Every theme needs an id, name, and tagline")
		end
		if seen[theme.id] then
			error(`[InkRivalry] Duplicate theme id {theme.id}`)
		end
		seen[theme.id] = true
	end
end

function Themes.pickRandom(): ThemeDefinition
	local count = #catalogue
	if count == 0 then
		error("[InkRivalry] Theme catalogue is empty")
	end

	local index = random:NextInteger(1, count)
	local picked = catalogue[index]
	if picked == nil then
		error("[InkRivalry] Theme pick failed")
	end
	if count > 1 and picked.id == lastThemeId then
		index = (index % count) + 1
		picked = catalogue[index]
		if picked == nil then
			error("[InkRivalry] Theme pick failed")
		end
	end

	local theme = picked

	lastThemeId = theme.id
	return theme
end

return Themes
