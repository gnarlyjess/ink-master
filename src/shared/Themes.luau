--!strict

-- Stable ids. Add rows here when the catalogue grows. Do not rename an id once it is saved.

export type ThemeDefinition = {
	id: string,
	name: string,
	tagline: string,
}

-- Theme packs for prompt variety. Keep taglines short and drawable with shapes.
local catalogue: { ThemeDefinition } = {
	-- Kids & Internet Culture
	{ id = "brainrot", name = "Brainrot", tagline = "Something unserious from the internet." },
	{ id = "animals", name = "Animals", tagline = "Any creature with personality." },
	{ id = "ocean-animals", name = "Ocean Animals", tagline = "Fish, whales, jellyfish, or a crab." },
	{ id = "jungle-animals", name = "Jungle Animals", tagline = "Parrots, frogs, big cats, or snakes." },
	{ id = "farm-animals", name = "Farm Animals", tagline = "Horses, pigs, ducks, or a cow." },
	{ id = "dinosaurs", name = "Dinosaurs", tagline = "One prehistoric creature." },
	{ id = "cute-animals", name = "Cute Animals", tagline = "Soft, round, and adorable." },
	{ id = "kawaii", name = "Kawaii", tagline = "Big eyes, tiny body, sweet vibe." },
	{ id = "cartoon-characters", name = "Cartoon Characters", tagline = "Invent a toon of your own." },
	{ id = "internet-memes", name = "Internet Memes", tagline = "A meme everyone might recognise." },
	{ id = "emoji", name = "Emoji", tagline = "Turn an emoji into a tattoo." },
	{ id = "slang-and-gen-z", name = "Slang & Gen Z", tagline = "A phrase or vibe from online slang." },
	{ id = "gaming", name = "Gaming", tagline = "Controllers, pixels, or a boss fight." },
	{ id = "minecraft", name = "Minecraft", tagline = "Blocks, creepers, or a pickaxe." },
	{ id = "fantasy-pets", name = "Fantasy Pets", tagline = "A magical companion animal." },
	{ id = "monsters", name = "Monsters", tagline = "Silly or scary — your call." },
	{ id = "aliens", name = "Aliens", tagline = "From another planet." },
	{ id = "robots", name = "Robots", tagline = "A machine with a face." },
	{ id = "superheroes", name = "Superheroes", tagline = "Cape, mask, or power pose." },
	{ id = "villains", name = "Villains", tagline = "A bad guy worth remembering." },
	{ id = "toys-and-plushies", name = "Toys & Plushies", tagline = "A soft toy or plaything." },
	{ id = "school-doodles", name = "School Doodles", tagline = "Margin scribbles and class boredom art." },
	{ id = "food-characters", name = "Food Characters", tagline = "Food with a face and attitude." },
	{ id = "silly-faces", name = "Silly Faces", tagline = "One ridiculous expression." },
	{ id = "cartoon-chaos", name = "Cartoon Chaos", tagline = "Over-the-top cartoon energy." },
	{ id = "fairy-tales", name = "Fairy Tales", tagline = "Castles, crowns, or a magic frog." },
	{ id = "mythical-creatures", name = "Mythical Creatures", tagline = "Something from myth." },
	{ id = "space-adventures", name = "Space Adventures", tagline = "Rockets, planets, and stars." },
	{ id = "pirates", name = "Pirates", tagline = "Ships, maps, and treasure." },
	{ id = "magical-worlds", name = "Magical Worlds", tagline = "A place that feels enchanted." },

	-- Tattoo Styles & Aesthetics
	{ id = "traditional-tattoo-flash", name = "Traditional Tattoo Flash", tagline = "Bold classic flash design." },
	{ id = "neo-traditional", name = "Neo-Traditional", tagline = "Classic flash with modern flair." },
	{ id = "gothic", name = "Gothic", tagline = "Moons, bats, roses, and candlelight." },
	{ id = "cyber-sigilism", name = "Cyber Sigilism", tagline = "Sharp black sigil marks." },
	{ id = "fine-line", name = "Fine Line", tagline = "Thin elegant linework." },
	{ id = "blackwork", name = "Blackwork", tagline = "Solid black shapes and fills." },
	{ id = "japanese-irezumi", name = "Japanese Irezumi", tagline = "Wave, koi, or chrysanthemum energy." },
	{ id = "tribal", name = "Tribal", tagline = "Bold tribal patterns." },
	{ id = "ornamental", name = "Ornamental", tagline = "Decorative lace-like marks." },
	{ id = "patchwork-tattoos", name = "Patchwork Tattoos", tagline = "A scrapbook of tiny tattoos." },
	{ id = "sticker-tattoos", name = "Sticker Tattoos", tagline = "Cute sticker-style pieces." },
	{ id = "minimalist", name = "Minimalist", tagline = "As few lines as possible." },
	{ id = "geometric", name = "Geometric", tagline = "Shapes, angles, and clean forms." },
	{ id = "watercolour", name = "Watercolour", tagline = "Soft colour-wash energy." },
	{ id = "trash-polka", name = "Trash Polka", tagline = "Red, black, and chaotic collage." },
	{ id = "biomechanical", name = "Biomechanical", tagline = "Flesh meeting machine." },
	{ id = "engraving-and-etching", name = "Engraving & Etching", tagline = "Crosshatch print look." },
	{ id = "old-school-sailor", name = "Old School Sailor", tagline = "Anchors, swallows, and banners." },
	{ id = "dark-art", name = "Dark Art", tagline = "Moody and dramatic." },
	{ id = "surrealism", name = "Surrealism", tagline = "Dream logic and weird mashups." },
	{ id = "chicano", name = "Chicano", tagline = "Lettering, roses, and classic Chicano style." },
	{ id = "dotwork", name = "Dotwork", tagline = "Made of dots and stipple." },
	{ id = "illustrative", name = "Illustrative", tagline = "Like a book illustration." },
	{ id = "abstract", name = "Abstract", tagline = "Shapes and feeling, not a literal thing." },
	{ id = "chrome-and-metallic", name = "Chrome & Metallic", tagline = "Shiny metal surfaces." },
	{ id = "baroque", name = "Baroque", tagline = "Ornate and dramatic." },
	{ id = "medieval", name = "Medieval", tagline = "Knights, crests, and old ink." },
	{ id = "woodcut", name = "Woodcut", tagline = "Rough carved-print look." },
	{ id = "sketch-style", name = "Sketch Style", tagline = "Loose pencil sketch energy." },
	{ id = "graffiti", name = "Graffiti", tagline = "Tags, drips, and street lettering." },

	-- Animals & Wildlife
	{ id = "cats", name = "Cats", tagline = "One cat with attitude." },
	{ id = "dogs", name = "Dogs", tagline = "A dog full of personality." },
	{ id = "sharks", name = "Sharks", tagline = "Fins, teeth, and open water." },
	{ id = "deep-sea-creatures", name = "Deep Sea Creatures", tagline = "Strange life from the deep." },
	{ id = "reptiles", name = "Reptiles", tagline = "Scales, tongues, and cool eyes." },
	{ id = "snakes", name = "Snakes", tagline = "Coils and fangs." },
	{ id = "spiders-and-insects", name = "Spiders & Insects", tagline = "Bugs with style." },
	{ id = "butterflies-and-moths", name = "Butterflies & Moths", tagline = "Wings and patterns." },
	{ id = "birds-of-prey", name = "Birds of Prey", tagline = "Hawks, eagles, or owls." },
	{ id = "jungle-predators", name = "Jungle Predators", tagline = "Big cats and jungle hunters." },
	{ id = "arctic-animals", name = "Arctic Animals", tagline = "Cold-weather creatures." },
	{ id = "australian-wildlife", name = "Australian Wildlife", tagline = "From down under." },
	{ id = "prehistoric-creatures", name = "Prehistoric Creatures", tagline = "Ancient animals and fossils alive." },
	{ id = "endangered-animals", name = "Endangered Animals", tagline = "A rare animal, drawn with care." },
	{ id = "mythical-beasts", name = "Mythical Beasts", tagline = "Legendary animal hybrids." },
	{ id = "weird-animals", name = "Weird Animals", tagline = "Nature's oddballs." },
	{ id = "animal-skeletons", name = "Animal Skeletons", tagline = "Bones of a creature." },
	{ id = "animal-hybrids", name = "Animal Hybrids", tagline = "Two animals mashed together." },
	{ id = "cute-critters", name = "Cute Critters", tagline = "Tiny and lovable." },
	{ id = "legendary-sea-monsters", name = "Legendary Sea Monsters", tagline = "Kraken, leviathan, or worse." },

	-- Nature & Outdoors
	{ id = "flowers", name = "Flowers", tagline = "One bloom, or a little bunch." },
	{ id = "mushrooms", name = "Mushrooms", tagline = "Caps, stems, and forest floor." },
	{ id = "poisonous-plants", name = "Poisonous Plants", tagline = "Pretty but dangerous plants." },
	{ id = "botanical", name = "Botanical", tagline = "Scientific plant study vibes." },
	{ id = "trees-and-leaves", name = "Trees & Leaves", tagline = "Branches, bark, and leaves." },
	{ id = "cacti-and-succulents", name = "Cacti & Succulents", tagline = "Spiky and drought-proof." },
	{ id = "forest-life", name = "Forest Life", tagline = "Creatures and plants of the woods." },
	{ id = "celestial", name = "Celestial", tagline = "Heavenly night-sky marks." },
	{ id = "sun-moon-and-stars", name = "Sun, Moon & Stars", tagline = "The classic celestial trio." },
	{ id = "planets-and-galaxies", name = "Planets & Galaxies", tagline = "Worlds beyond Earth." },
	{ id = "mountains", name = "Mountains", tagline = "Peaks and ridges." },
	{ id = "ocean-life", name = "Ocean Life", tagline = "Under the waves." },
	{ id = "weather", name = "Weather", tagline = "Storms, sun, rain, or wind." },
	{ id = "volcanoes", name = "Volcanoes", tagline = "Lava, ash, and eruption." },
	{ id = "crystals-and-gems", name = "Crystals & Gems", tagline = "Faceted stones and sparkle." },
	{ id = "fossils", name = "Fossils", tagline = "Ancient remains in stone." },
	{ id = "rocks-and-minerals", name = "Rocks & Minerals", tagline = "Geology with character." },
	{ id = "camping", name = "Camping", tagline = "Tents, fire, and the outdoors." },
	{ id = "hiking", name = "Hiking", tagline = "Trails, boots, and backpacks." },
	{ id = "nature-spirits", name = "Nature Spirits", tagline = "Spirits of forest, river, or stone." },
	{ id = "four-seasons", name = "Four Seasons", tagline = "Spring through winter in one piece." },

	-- Gothic & Dark Themes
	{ id = "gothic-architecture", name = "Gothic Architecture", tagline = "Spires, arches, and stained glass." },
	{ id = "haunted-houses", name = "Haunted Houses", tagline = "A house that feels wrong." },
	{ id = "ghosts", name = "Ghosts", tagline = "A spirit with presence." },
	{ id = "skeletons", name = "Skeletons", tagline = "Bones arranged with style." },
	{ id = "skulls", name = "Skulls", tagline = "A skull that reads as ink." },
	{ id = "grim-reapers", name = "Grim Reapers", tagline = "Hood, scythe, and shadows." },
	{ id = "vampires", name = "Vampires", tagline = "Fangs and night glamour." },
	{ id = "witches", name = "Witches", tagline = "Hats, cauldrons, or charms." },
	{ id = "demons", name = "Demons", tagline = "Horns and infernal energy." },
	{ id = "gargoyles", name = "Gargoyles", tagline = "Stone guardians." },
	{ id = "ravens-and-crows", name = "Ravens & Crows", tagline = "Dark birds and omens." },
	{ id = "dark-romance", name = "Dark Romance", tagline = "Love with a gothic edge." },
	{ id = "haunted-dolls", name = "Haunted Dolls", tagline = "Toys that watch you back." },
	{ id = "graveyard", name = "Graveyard", tagline = "Headstones and quiet night." },
	{ id = "occult-symbols", name = "Occult Symbols", tagline = "Mysterious marks and seals." },
	{ id = "spooky-objects", name = "Spooky Objects", tagline = "Everyday things made eerie." },
	{ id = "victorian-gothic", name = "Victorian Gothic", tagline = "Corsets, lace, and fog." },
	{ id = "dark-fairytales", name = "Dark Fairytales", tagline = "Fairy tales gone shadowy." },
	{ id = "horror-monsters", name = "Horror Monsters", tagline = "Classic scare creatures." },
	{ id = "eldritch-creatures", name = "Eldritch Creatures", tagline = "Too many eyes, too many limbs." },

	-- Cyber & Futuristic
	{ id = "cyberpunk", name = "Cyberpunk", tagline = "Neon city and chrome rain." },
	{ id = "glitch-art", name = "Glitch Art", tagline = "Broken pixels and distortion." },
	{ id = "neon-dreams", name = "Neon Dreams", tagline = "Glow-in-the-dark night vibes." },
	{ id = "futuristic-technology", name = "Futuristic Technology", tagline = "Gadgets from tomorrow." },
	{ id = "cybernetic-animals", name = "Cybernetic Animals", tagline = "Animals upgraded with tech." },
	{ id = "robots-and-androids", name = "Robots & Androids", tagline = "Humanoid machines." },
	{ id = "ai-and-artificial-intelligence", name = "AI & Artificial Intelligence", tagline = "Thinking machines." },
	{ id = "holograms", name = "Holograms", tagline = "Projected light forms." },
	{ id = "digital-worlds", name = "Digital Worlds", tagline = "Inside the screen." },
	{ id = "space-exploration", name = "Space Exploration", tagline = "Ships, suits, and distant stars." },
	{ id = "alien-civilisations", name = "Alien Civilisations", tagline = "Otherworldly cultures." },
	{ id = "mechs-and-exosuits", name = "Mechs & Exosuits", tagline = "Giant powered armour." },
	{ id = "biomechanical-horror", name = "Biomechanical Horror", tagline = "Body and machine, unsettling." },
	{ id = "futuristic-fashion", name = "Futuristic Fashion", tagline = "Clothes from the future." },
	{ id = "hacker-culture", name = "Hacker Culture", tagline = "Code, terminals, and access." },
	{ id = "retro-futurism", name = "Retro-Futurism", tagline = "Yesterday's idea of tomorrow." },
	{ id = "synthwave", name = "Synthwave", tagline = "80s neon sunset energy." },
	{ id = "techno-organic", name = "Techno-Organic", tagline = "Tech grown like nature." },
	{ id = "sci-fi-weapons-fictional", name = "Sci-Fi Weapons (fictional)", tagline = "A made-up sci-fi weapon." },

	-- Pop Culture & Entertainment
	{ id = "music", name = "Music", tagline = "Notes, headphones, or a guitar." },
	{ id = "rock-and-metal", name = "Rock & Metal", tagline = "Loud, loud, and louder." },
	{ id = "hip-hop", name = "Hip-Hop", tagline = "Beats, mic, and street style." },
	{ id = "pop-stars", name = "Pop Stars", tagline = "Stage lights and stardom." },
	{ id = "musical-instruments", name = "Musical Instruments", tagline = "One instrument as the star." },
	{ id = "movies", name = "Movies", tagline = "Cinema moments and icons." },
	{ id = "horror-movies", name = "Horror Movies", tagline = "A scare from the big screen." },
	{ id = "fantasy-movies", name = "Fantasy Movies", tagline = "Magic from the movies." },
	{ id = "anime", name = "Anime", tagline = "Anime-style energy." },
	{ id = "manga", name = "Manga", tagline = "Panel and ink vibes." },
	{ id = "cartoons", name = "Cartoons", tagline = "Classic cartoon style." },
	{ id = "comic-books", name = "Comic Books", tagline = "Speech bubbles and panels." },
	{ id = "superhero-comics", name = "Superhero Comics", tagline = "Heroes from the page." },
	{ id = "video-games", name = "Video Games", tagline = "A game moment in ink." },
	{ id = "retro-gaming", name = "Retro Gaming", tagline = "Pixels and old consoles." },
	{ id = "internet-culture", name = "Internet Culture", tagline = "Online life as a tattoo." },
	{ id = "celebrity-icons", name = "Celebrity Icons", tagline = "A famous silhouette vibe — invent your own." },
	{ id = "film-props", name = "Film Props", tagline = "Objects from movie sets." },
	{ id = "tv-shows", name = "TV Shows", tagline = "Something from the small screen." },
	{ id = "memorable-quotes", name = "Memorable Quotes", tagline = "Turn a line into a design." },

	-- Fantasy & Mythology
	{ id = "dragons", name = "Dragons", tagline = "Scales, wings, and a little fire." },
	{ id = "unicorns", name = "Unicorns", tagline = "Horn, mane, and magic." },
	{ id = "fairies", name = "Fairies", tagline = "Wings and sparkle." },
	{ id = "mermaids", name = "Mermaids", tagline = "Tail, waves, and sea song." },
	{ id = "phoenixes", name = "Phoenixes", tagline = "Firebird rising." },
	{ id = "griffins", name = "Griffins", tagline = "Eagle meets lion." },
	{ id = "centaurs", name = "Centaurs", tagline = "Half horse, half hero." },
	{ id = "greek-mythology", name = "Greek Mythology", tagline = "Gods, heroes, and monsters of Greece." },
	{ id = "norse-mythology", name = "Norse Mythology", tagline = "Runes, wolves, and northern gods." },
	{ id = "egyptian-mythology", name = "Egyptian Mythology", tagline = "Ankh, scarab, or desert gods." },
	{ id = "japanese-mythology", name = "Japanese Mythology", tagline = "Yokai, kami, and legends." },
	{ id = "celtic-mythology", name = "Celtic Mythology", tagline = "Knots, spirals, and old myths." },
	{ id = "gods-and-goddesses", name = "Gods & Goddesses", tagline = "A divine figure." },
	{ id = "legendary-heroes", name = "Legendary Heroes", tagline = "A hero from legend." },
	{ id = "magical-artefacts", name = "Magical Artefacts", tagline = "A powerful enchanted object." },
	{ id = "enchanted-forests", name = "Enchanted Forests", tagline = "Trees that hide magic." },
	{ id = "wizards-and-witches", name = "Wizards & Witches", tagline = "Spellcasters and their tools." },
	{ id = "medieval-fantasy", name = "Medieval Fantasy", tagline = "Castles, quests, and armour." },
	{ id = "dungeons-and-dragons", name = "Dungeons & Dragons", tagline = "Tabletop fantasy adventure." },
	{ id = "fantasy-weapons", name = "Fantasy Weapons", tagline = "Swords, staves, and enchanted gear." },

	-- Objects & Everyday Life
	{ id = "food", name = "Food", tagline = "Something delicious." },
	{ id = "desserts", name = "Desserts", tagline = "Sweet treats." },
	{ id = "fast-food", name = "Fast Food", tagline = "Quick bites with flair." },
	{ id = "drinks", name = "Drinks", tagline = "Cups, cans, or cocktails of imagination." },
	{ id = "coffee-culture", name = "Coffee Culture", tagline = "Beans, cups, and cafe life." },
	{ id = "kitchen-objects", name = "Kitchen Objects", tagline = "Tools from the kitchen." },
	{ id = "household-items", name = "Household Items", tagline = "Everyday home objects." },
	{ id = "fashion-accessories", name = "Fashion Accessories", tagline = "Bags, belts, and extras." },
	{ id = "shoes-and-sneakers", name = "Shoes & Sneakers", tagline = "Footwear as art." },
	{ id = "jewellery", name = "Jewellery", tagline = "Rings, chains, and gems." },
	{ id = "watches", name = "Watches", tagline = "Timepieces with style." },
	{ id = "gadgets", name = "Gadgets", tagline = "Handy little tech." },
	{ id = "vehicles", name = "Vehicles", tagline = "Anything that moves you." },
	{ id = "motorcycles", name = "Motorcycles", tagline = "Two wheels and attitude." },
	{ id = "classic-cars", name = "Classic Cars", tagline = "Old-school automobile style." },
	{ id = "trains", name = "Trains", tagline = "Locomotives and tracks." },
	{ id = "aircraft", name = "Aircraft", tagline = "Planes, jets, or sky machines." },
	{ id = "tools", name = "Tools", tagline = "Hammers, wrenches, and craft gear." },
	{ id = "everyday-carry", name = "Everyday Carry", tagline = "Pocket essentials." },
	{ id = "random-objects", name = "Random Objects", tagline = "Anything ordinary made interesting." },

	-- Humour & Party Packs
	{ id = "bad-tattoos", name = "Bad Tattoos", tagline = "Intentionally terrible ink." },
	{ id = "terrible-drawings", name = "Terrible Drawings", tagline = "Proudly awful art." },
	{ id = "cursed-objects", name = "Cursed Objects", tagline = "Things that feel hexed." },
	{ id = "weird-inventions", name = "Weird Inventions", tagline = "Gadgets nobody asked for." },
	{ id = "awkward-situations", name = "Awkward Situations", tagline = "Social disaster as a design." },
	{ id = "dad-jokes", name = "Dad Jokes", tagline = "A visual dad joke." },
	{ id = "puns", name = "Puns", tagline = "Wordplay made visual." },
	{ id = "unexpected-combinations", name = "Unexpected Combinations", tagline = "Two things that should not meet." },
	{ id = "things-that-shouldnt-exist", name = "Things That Shouldn't Exist", tagline = "Impossible objects." },
	{ id = "ridiculous-jobs", name = "Ridiculous Jobs", tagline = "A job title gone wild." },
	{ id = "unhinged-animals", name = "Unhinged Animals", tagline = "Animals behaving badly." },
	{ id = "weird-food-combinations", name = "Weird Food Combinations", tagline = "Food that should not be friends." },
	{ id = "guess-the-sound", name = "Guess the Sound", tagline = "Draw what a sound looks like." },
	{ id = "tiny-things", name = "Tiny Things", tagline = "Make something very small." },
	{ id = "giant-things", name = "Giant Things", tagline = "Make something enormous." },
	{ id = "things-with-faces", name = "Things With Faces", tagline = "Give an object a face." },
	{ id = "fake-brands", name = "Fake Brands", tagline = "Invent a brand logo." },
	{ id = "imaginary-products", name = "Imaginary Products", tagline = "A product that does not exist." },
	{ id = "opposites", name = "Opposites", tagline = "Two opposite ideas in one piece." },
	{ id = "draw-it-wrong", name = "Draw It Wrong", tagline = "Get the idea deliberately wrong." },

	-- Symbols & Iconography
	{ id = "hearts", name = "Hearts", tagline = "A heart with personality." },
	{ id = "daggers", name = "Daggers", tagline = "Sharp blades and ribbons." },
	{ id = "flames", name = "Flames", tagline = "Fire shapes and heat." },
	{ id = "eyes", name = "Eyes", tagline = "Watchful eyes." },
	{ id = "hands", name = "Hands", tagline = "Hands as symbols." },
	{ id = "wings", name = "Wings", tagline = "Feathered or bat-like wings." },
	{ id = "crowns", name = "Crowns", tagline = "Royalty on the skin." },
	{ id = "keys-and-locks", name = "Keys & Locks", tagline = "Access and secrecy." },
	{ id = "chains", name = "Chains", tagline = "Links and weight." },
	{ id = "swords", name = "Swords", tagline = "Blades and hilts." },
	{ id = "shields", name = "Shields", tagline = "Protection and crests." },
	{ id = "masks", name = "Masks", tagline = "Hidden faces." },
	{ id = "sacred-geometry", name = "Sacred Geometry", tagline = "Precise mystical shapes." },
	{ id = "runes-and-glyphs", name = "Runes & Glyphs", tagline = "Mysterious letter-marks." },
	{ id = "lucky-charms", name = "Lucky Charms", tagline = "Horseshoes, clovers, or a star." },
	{ id = "zodiac-signs", name = "Zodiac Signs", tagline = "A star sign symbol." },
	{ id = "tarot", name = "Tarot", tagline = "Cards and arcana." },
	{ id = "alchemy", name = "Alchemy", tagline = "Flasks, symbols, and transformation." },
	{ id = "ancient-symbols", name = "Ancient Symbols", tagline = "Marks from long ago." },

	-- Travel & Culture
	{ id = "countries-and-flags", name = "Countries & Flags", tagline = "A place through its symbols." },
	{ id = "world-landmarks", name = "World Landmarks", tagline = "Famous places worldwide." },
	{ id = "cities", name = "Cities", tagline = "Skyline or city energy." },
	{ id = "street-culture", name = "Street Culture", tagline = "Urban style and pavement life." },
	{ id = "japanese-culture", name = "Japanese Culture", tagline = "Motifs from Japan." },
	{ id = "ancient-egypt", name = "Ancient Egypt", tagline = "Pyramids, gods, and desert gold." },
	{ id = "ancient-rome", name = "Ancient Rome", tagline = "Laurels, columns, and empire." },
	{ id = "medieval-europe", name = "Medieval Europe", tagline = "Castles and old Europe." },
	{ id = "wild-west", name = "Wild West", tagline = "Dust, hats, and frontier." },
	{ id = "pirates-and-sailors", name = "Pirates & Sailors", tagline = "Sea dogs and ship life." },
	{ id = "space-race", name = "Space Race", tagline = "Rockets and moonshot history." },
	{ id = "festivals", name = "Festivals", tagline = "Celebration and colour." },
	{ id = "carnival", name = "Carnival", tagline = "Masks, rides, and spectacle." },
	{ id = "traditional-clothing", name = "Traditional Clothing", tagline = "Garments with cultural roots." },
	{ id = "architecture", name = "Architecture", tagline = "Buildings as ink." },
	{ id = "famous-monuments", name = "Famous Monuments", tagline = "Monuments the world knows." },
	{ id = "cultural-patterns", name = "Cultural Patterns", tagline = "Patterns from around the world." },
	{ id = "mythical-places", name = "Mythical Places", tagline = "Locations that exist in story." },
	{ id = "road-trips", name = "Road Trips", tagline = "Highways and travel kits." },
	{ id = "adventure-travel", name = "Adventure Travel", tagline = "Explore somewhere wild." },

	-- Seasonal & Limited-Time Packs
	{ id = "halloween", name = "Halloween", tagline = "Pumpkins, costumes, and night." },
	{ id = "christmas", name = "Christmas", tagline = "Trees, gifts, and winter cheer." },
	{ id = "valentines-day", name = "Valentine's Day", tagline = "Hearts and romance." },
	{ id = "easter", name = "Easter", tagline = "Eggs, bunnies, and spring." },
	{ id = "summer", name = "Summer", tagline = "Sun, heat, and holidays." },
	{ id = "winter", name = "Winter", tagline = "Snow and cold comfort." },
	{ id = "spring", name = "Spring", tagline = "Bloom and fresh start." },
	{ id = "autumn", name = "Autumn", tagline = "Leaves, harvest, and chill." },
	{ id = "april-fools", name = "April Fools", tagline = "Pranks and silly tricks." },
	{ id = "birthday-party", name = "Birthday Party", tagline = "Cake, candles, and a wish." },
	{ id = "friday-the-13th", name = "Friday the 13th", tagline = "Unlucky and spooky." },
	{ id = "new-year", name = "New Year", tagline = "Countdown and fresh starts." },
	{ id = "spooky-season", name = "Spooky Season", tagline = "Autumn horror vibes." },
	{ id = "summer-holidays", name = "Summer Holidays", tagline = "Beach bags and vacation mode." },
	{ id = "back-to-school", name = "Back to School", tagline = "Bags, pencils, and first day." },
	{ id = "festival-season", name = "Festival Season", tagline = "Lights, music, and crowds." },
	{ id = "lunar-new-year", name = "Lunar New Year", tagline = "Lanterns, red, and celebration." },
	{ id = "pride-inspired-colours-and-symbols", name = "Pride-Inspired Colours & Symbols", tagline = "Colourful pride-inspired marks." },
	{ id = "bonfire-night", name = "Bonfire Night", tagline = "Fireworks and bonfires." },
	{ id = "seasonal-foods", name = "Seasonal Foods", tagline = "Foods tied to the season." },
}

local Themes = {
	all = catalogue,
}

local random = Random.new()
local lastThemeId: string? = nil

function Themes.validate()
	if #catalogue == 0 then
		error("[InkMasters] Theme catalogue is empty")
	end

	local seen: { [string]: boolean } = {}
	for _, theme in catalogue do
		if theme.id == "" or theme.name == "" or theme.tagline == "" then
			error("[InkMasters] Every theme needs an id, name, and tagline")
		end
		if seen[theme.id] then
			error(`[InkMasters] Duplicate theme id {theme.id}`)
		end
		seen[theme.id] = true
	end
end

function Themes.pickRandom(): ThemeDefinition
	local count = #catalogue
	if count == 0 then
		error("[InkMasters] Theme catalogue is empty")
	end

	local index = random:NextInteger(1, count)
	local picked = catalogue[index]
	if picked == nil then
		error("[InkMasters] Theme pick failed")
	end
	if count > 1 and picked.id == lastThemeId then
		index = (index % count) + 1
		picked = catalogue[index]
		if picked == nil then
			error("[InkMasters] Theme pick failed")
		end
	end

	local theme = picked

	lastThemeId = theme.id
	return theme
end

return Themes
