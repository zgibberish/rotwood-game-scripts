STRINGS.ITEMS =
{
	RARITY =
	{
		COMMON = "Scuffed",
		UNCOMMON = "Ordinary",
		RARE = "DEV_UNUSED",
		EPIC = "Great",
		LEGENDARY = "Pristine",
		TITAN = "Masterwork",
		SET = "Set"
	},

	RARITY_CAPS =
	{
		COMMON = "SCUFFED",
		UNCOMMON = "ORDINARY",
		RARE = "DEV_UNUSED",
		EPIC = "GREAT",
		LEGENDARY = "PRISTINE",
		TITAN = "MASTERWORK",
		SET = "SET",
	},

	WEAPON = {
		hammer_basic =
		{
			name = "Crumbling Bammer",
			desc = "A heavy hitter for the unpretentious.",
		},

		hammer_sledge =
		{
			name = "Sludgebammer",
			desc = "Bash up a {name.rot} real hard-like.",
		},

		hammer_startingforest =
		{
			name = "The Tenderizer",
			desc = "Kills with severe tenderness.",
		},

		hammer_startingforest2 =
		{
			name = "The Smashing Pumpkin",
			desc = "Winning feels so gourd.",
		},

		hammer_megatreemon =
		{
			name = "The Ocular Gavel",
			desc = "Kill with one eye open.",
		},

		hammer_swamp = --slowpoke tail and bulbug jaw
		{
			name = "Grove Bammer",
			desc = "Exudes the putrid stench of success.",
		},
		hammer_swamp2 = --groak tentacle and eye-v vine
		{
			name = "Wetwhacker",
			desc = "Well that's gonna leave a mark.",
		},
		hammer_bandicoot =
		{
			name = "Troublemaker",
			desc = "It's time to crack some skulls.",
		},

		polearm_startingforest =
		{
			name = "The Cold High Five",
			desc = "For the Hunter who'd only touch a {name.rot} with a ten foot pole.",
		},

		polearm_startingforest2 =
		{
			name = "The Pumpkin Carver",
			desc = "Poke a pumpkin, gouge a gourd.",
		},

		polearm_megatreemon =
		{
			name = "The All-Seeing Fork",
			desc = "It sees you when you're bleeding, it knows when you've been staked.",
		},

		polearm_swamp =
		{
			name = "Barbed Pike",
			desc = "For when you don't wanna run 'em <i>clean</i> through.",
		},
		polearm_swamp2 =
		{
			name = "The Claw",
			desc = "It's also a great backscratcher.",
		},
		polearm_bandicoot =
		{
			name = "Cutting Remark",
			desc = "A well-timed barb in passing can cut a foe to the quick.",
		},

		polearm_basic =
		{
			name = "Rusty Skewer",
			desc = "A dull blade is sometimes more dangerous than a sharp one.",
		},

		cleaver_basic = --not used
		{
			name = "Extra Dull Cleaver",
			desc = "Chop yourself a nice slice of {name.rot}.",
		},

		cannon_basic =
		{
			name = "Splintered {name.weapon_cannon}",
			desc = "When this {name.weapon_cannon} fires in the forest, it definitely makes a sound.",
		},
		cannon_swamp1 =
		{
			name = "Big Batty Boom",
			desc = "Things are about to get batty.",
		},
		cannon_swamp2 =
		{
			name = "The Bog Blaster",
			desc = "Your enemies are gonna <i>croak</i>.",
		},
		cannon_bandicoot =
		{
			name = "Loose {name.weapon_cannon}",
			desc = "Let chaos reign.",
		},
		cannon_megatreemon =
		{
			name = "One Big Mother",
			desc = "Walk softly and carry a boomstick.",
		},

		shotput_basic =
		{
			name = "Old Leather {name.weapon_shotput}",
			desc = "Strike fear into the hearts of {name_multiple.rot}!",
		},

		shotput_startingforest1 =
		{
			name = "Zesty {name.weapon_shotput}",
			desc = "Beat your enemies to a pulp.",
		},
		shotput_startingforest2 =
		{
			name = "The Doodlebug Special",
			desc = "Flies through the air with the greatest of ease.",
		},
		shotput_swamp1 =
		{
			name = "Pokey Ball",
			desc = "Watch {name_multiple.rot} catch 'em... <i>right in the face</i>.",
		},
		shotput_swamp2 =
		{
			name = "Groakshot",
			desc = "As deadly as it is hideously sticky.",
		},

		shotput_megatreemon =
		{
			name = "Mother Treek's Conker",
			desc = "Ah, that old chestnut.",
		},

		shotput_bandicoot =
		{
			name = "Juggler's Charade",
			desc = "How long can you keep the ruse afloat?",
		},

		weaponprototype =
		{
			name = "Weapon Prototype",
			desc = "Hi Mike! Have a great day!",
		},
	},
	BODY = {

		--[[BEAUTIFUL WRITER FRIENDS LOOK HERE:

		Here's a list of armour/clothing-related words, feel free to grab from it or use them as a jumping off point :)
		It's okay to mix modern and medieval terms in our game.

		*Note* Our gear doesn't actually have armour values (they just bequeath stat boosts and effects when equipped),
		so whether an armour piece is considered heavy/medium/light is just based off appearance and how you want to 
		flavour it
		-Kris

		HEAVY
			--Armour 			--Plate
			--Mail				--Chainmail/Scalemail
			--Breastplate 		--Chestplate
			--Bone 				--Pauldrons
			--Regalia			--Hauberk (shirt of mail)
		MEDIUM
			--Vest 				--Tunic
			--Leathers 			--Jacket
			--Coat 				--Cuirass
			--Corselet 			--Duster
			--Hide 				--Skins
			--Trenchcoat 		--Overalls/Coveralls
			--Cladding 			--Epaulets
			--Brigandine (sleeveless, riveted, can be cloth or leather and lined with steel plates)
			--Flak Jacket (sleeveless, more modern body armour. Military but not bulletproof)
			--Buff Coat (longsleeve leather coat worn by cavalry)
			--Gambeson (quilted, padded jacket, longsleeve)
			--Doublet (longsleeve, medieval, can be quite fancy)
		LIGHT
			--Robe 				--Tabard
			--Wrap 				--Linens
			--Dress 			--Sweater
			--Longcoat 			--Cover
			--Drape 			--Frock
			--Bodice 			--Corset
			--Blazer 			--Cape/Capelet
			--Surcoat (cloth worn by a knight, usually has an insignia)
		MISC
			--Outfit			--Adornment
			--Garb 				--Gear
			--Uniform 			--Garments
			--Clothes 			--Raiment
			--Suit 				--Vestiary
			--Apparel 			--Finery
			--Costume			--Bustier
		]]

		--basic
		basic = {
			name = "Basic Tunic",
			desc = "Better than running around in the buck."
		},

		--bosses
		bandicoot = {
			name = "{name.bandicoot}'s Biting Cuirass",
			desc = "A comfortable yet stylish tunic. Tends to shed."
		},
		bonejaw = {
			name = "{name.bonejaw} Breastplate",
			desc = "A breastplate of scale and bone does well to intimidate."
		},
		megatreemon = {
			name = "{name.megatreemon}'s Sylvan Weave",
			desc = "A piece to wear with pride.",
		},
		owlitzer =
		{
			name = "{name.owlitzer}'s Plumed Doublet",
			desc = "Become a bird of prey.",
		},
		thatcher = {
			name = "{name.thatcher}'s Super Brigandine",
			desc = "A lightweight thorax of armour."
		},

		--minibosses
		gourdo = {
			name = "{name.gourdo} Vest",
			desc = "Athletic gear for the team player.",
		},
		yammo = {
			name = "{name.yammo} Singlet",
			desc = "A gourd-geous piece of attire.",
		},
		floracrane = {
			name = "{name.floracrane} Raiments",
			desc = "In fighting and in dancing, one benefits from a full range of motion.",
		},
		seeker = {
			name = "{name.seeker} Coat",
			desc = "",
		},
		groak = {
			name = "{name.groak} Body Casing",
			desc = "Harder to slip on than a pair of wet jeans.",
		},

		--regular
		rotwood = {
			name = "{name.rotwood} Breastplate",
			desc = "If you can get over the splinters, it's a very effective breastplate."
		},
		blarmadillo = {
			name = "{name.blarmadillo} Chestplate",
			desc = "Properly protects from punches, but pretty prone to pilling."
		},
		cabbageroll = {
			name = "{name.cabbageroll} Longcoat",
			desc = "Just don't touch your eyes after buttoning it up."
		},
		zucco = {
			name = "{name.zucco} Singlet",
			desc = "Sometimes you need to get into a pickle to get out of one.",
		},
		battoad = {
			name = "{name.battoad} Surcoat",
			desc = "Ready for {name.battoad}tle!",
		},
		mothball = {
			name = "{name.mothball} Fur Coat",
			desc = "It's nearly impossible to be in a bad mood while wearing one of these.",
		},
		bulbug = {
			name = "{name.bulbug} Exoskeleton",
			desc = "Two skeletons are better than one.",
		},
		treemon =
		{
			name = "{name.treemon} Trunk",
			desc = "All bark, and some bite.",
		},
		-- WRITER!
		windmon =
		{
			name = "{name.windmon} Breastplate",
			desc = "For a suit of armour, it's surprisingly breezy.",
		},
		gnarlic =
		{
			name = "{name.gnarlic} Chest Wrap",
			desc = "A pungent garment that eliminates the need for personal deodorant.",
		},
		eyev =
		{
			name = "{name.eyev} Wrap",
			desc = "Just because you're fighting {name_multiple.rot} doesn't mean you can't look cute.",
		},
	},
	HEAD = {
		--[[
		BEAUTIFUL WRITER FRIENDS LOOK HERE:
			Here's a list of headgear words, feel free to grab from it or use them as a jumping off point :)
			It's okay to mix modern and medieval terms in our game.

			*Note* Our gear doesn't actually have armour values (they just bequeath stat boosts and effects when equipped),
			so whether an armour piece is considered heavy/medium/light is just based off appearance and how you want to 
			flavour it
			-Kris

		HEAVY
			--Helm/Great Helm 			--Helmet
			--Hardhat 					--Bascinet (funny lil helmet with a beak)
			--Armet (quintessential suit of armour helmet)
			--Barbute (metal helmet with T-shaped eye/nose space)
			--Sallet (metal helmet that covers the top half of the face and the back of the neck)
			--Kettlehat (helmet that looks like a regular hat, but metal)
			--Bevor (metal piece that protects your neck, doesn't cover the face on its own but can be paired with helmets)
		MEDIUM
			--Coif (mail) 			--Cap/Skullcap
			--Hood 					--Visor
			--Toque					--Headdress (keep cultural sensitivity in mind with this one :) )
			--Pith Helmet (safari hat)
		LIGHT
			--Cowl 					--Bonnet
			--Veil 					--Shroud
			--Beret 				--Tricorne
		DECORATIVE
			--Crown 				--Diadem
			--Tiara 				--Circlet
			--Mask 					--Hatpin
			--Coronet 				--Garland
			--Clip/Barrette			--Ribbon/Bow
		MISC
			--Headgear 				--Hat
			--Headpiece				--Headwrap
		]]

		--basic
		basic = {
			name = "Basic Headband",
			desc = "Keep the sweat from your eyes while bashing {name_multiple.rot}.",
		},

		--bosses
		bandicoot = {
			name = "{name.bandicoot}'s Toothed Armet",
			desc = "This helmet once housed many devious thoughts. Now, it houses yours.",
		},
		bonejaw = {
			name = "{name.bonejaw} Head Cage",
			desc = "Intimidating and protective. Good qualities in a helm.",
		},
		megatreemon = {
			name = "{name.megatreemon}'s Avid Circlet",
			desc = "Only for those who have tread within the forest's inner circle.",
		},
		thatcher = {
			name = "{name.thatcher}'s Vigilant Visor",
			desc = "Why so bug-eyed?",
		},
		owlitzer =
		{
			name = "The Cowlitzer",
			desc = "The only cowl made from an owl.",
		},

		--minibosses
		floracrane = {
			name = "{name.floracrane} Garland",
			desc = "Combat is an elegant dance.",
		},
		gourdo = {
			name = "{name.gourdo}'s Noggin-Padder",
			desc = "Proper padding to guard your gourd.",
		},
		yammo = {
			name = "{name.yammo}'s Noggin-Padder",
			desc = "Orange you glad you didn't crack your melon?",
		},
		seeker = {
			name = "{name.seeker} Helm",
			desc = "",
		},
		groak = {
			name = "{name.groak} Bow",
			desc = "What makes you pretty on the inside also makes you pretty on the outside.",
		},

		--regular enemies
		rotwood = {
			name = "{name.rotwood} Helm",
			desc = "Takes a solid knock on wood.",
		},
		blarmadillo = {
			name = "{name.blarmadillo} Kettlehat",
			desc = "It's a dome for the dome.",
		},
		cabbageroll = {
			name = "{name.cabbageroll} Buddy",
			desc = "Never fight alone again.",
		},
		zucco = {
			name = "{name.zucco}'s Noggin-Padder",
			desc = "A full helmet might've been too cucumbersome.",
		},
		battoad = {
			name = "{name.battoad} Wings",
			desc = "Rain terror from the skies.",
		},
		mothball = {
			name = "{name.mothball} Ushanka",
			desc = "So comfortingly floofy, you can't help but feel a bit friendlier wearing it.",
		},
		bulbug = {
			name = "{name.bulbug} Eyes",
			desc = "See your enemies from a {name.bulbug}'s perspective.",
		},
		treemon =
		{
			name = "Treeara",
			desc = "Pretty in {name.treemon}.",
		},
		windmon =
		{
			name = "{name.windmon} Helm",
			desc = "Charge into hunts with confidence and gusto.",
		},
		gnarlic =
		{
			name = "{name.gnarlic} Head Stalk",
			desc = "Stalk your prey.",
		},
		eyev =
		{
			name = "{name.eyev} Shroud",
			desc = "Woe be upon {name_multiple.rot} who won't leaf you alone.",
		},
	},
	WAIST = {

		--[[BEAUTIFUL WRITER FRIENDS LOOK HERE:

		Hi Kris I emptied this out to leave a blank template for WAIST which is the lower body -- Shoes + Pants!
		-jambell

		HEAVY
		-Chausses (chainmail, covers the whole leg)
		-Sabaton (foot portion of a suit of armour)
		-Faulds (the "skirt" part of a suit of armour)

		MEDIUM
		-Cuisses (quilted, padded armour for the thigh specifically)
		-Chaps

		LIGHT
		-Pants
		-Tights
		-Trousers
		-Skirt
		-Kilt
		-Slacks
		-Knickers (underwear)
		-Breeches
		-Shorts
		-Pantaloons
		-Loincloth
		-Sash
		-Belt
		-Petticoat (undergarment, like a skirt)
		-Culottes
		-Capris

		-Cinch
		Shoes
		-Galoshes (shoes)

		MISC
		-Greaves (leg armour, can be metal, leather or cloth)
		]]

		--basic
		basic = {
			name = "Basic Leggings",
			desc = "The sandal blisters are only <i>mildly</i> intolerable!",
		},

		--bosses
		bandicoot = {
			name = "{name.bandicoot}'s Blue Suede Boots",
			desc = "Do not step on them.",
		},
		bonejaw = {
			name = "Rigid {name.bonejaw} Jawbelt",
			desc = "",
		},
		megatreemon = {
			name = "{name.megatreemon}'s Bark-Kilt",
			desc = "Let your sovereignty take root.",
		},
		owlitzer =
		{
			name = "{name.owlitzer}'s' Shearling Britches",
			desc = "How can something so dangerous be so soft?",
		},
		thatcher = {
			name = "{name.thatcher}'s Super Elasti-Pants",
			desc = "They're not underpants! Stop calling them underpants!",
		},

		--minibosses
		gourdo = {
			name = "{name.gourdo} Elasti-Shorts",
			desc = "May you cling to life as tightly as these shorts cling to you.",
		},
		yammo = {
			name = "{name.yammo} Elasti-Shorts",
			desc = "Comfy shorts with an astonishingly wide range of movement.",
		},
		zucco = {
			name = "{name.zucco} Elasti-Shorts",
			desc = "In battle you should leave nothing up to chance, or the imagination.",
		},
		floracrane = {
			name = "{name.floracrane} Skirt",
			desc = "Twirls gracefully on the battlefield.",
		},
		seeker = {
			name = "{name.seeker} WAIST",
			desc = "",
		},
		groak = {
			name = "{name.groak} Drippings",
			desc = "Take a bath after wearing.",
		},

		--regular
		rotwood = {
			name = "{name.rotwood} Faulds",
			desc = "No, it's not mahogany.",
		},
		blarmadillo = {
			name = "{name.blarmadillo} Trunks",
			desc = "For someone who nose their way around a trap or two.",
		},
		cabbageroll = {
			name = "{name.cabbageroll} Sash",
			desc = "Don't go out on a hunt without a friend to watch your behind.",
		},
		battoad = {
			name = "{name.battoad} Legs",
			desc = "Always be ready to leap into the fray.",
		},
		mothball = {
			name = "{name.mothball} Fur Leggings",
			desc = "Double-layered for extra comfort.",
		},
		bulbug = {
			name = "{name.bulbug} Tarsi",
			desc = "Makes a scritching noise when you walk.",
		},
		treemon =
		{
			name = "{name.treemon} Fig Leaf",
			desc = "A very modest piece of armour.",
		},
		-- WRITER!
		windmon =
		{
			name = "{name.windmon} Greaves",
			desc = "Perfect for weathering the elements.",
		},
		gnarlic =
		{
			name = "{name.gnarlic} Bulb Shorts",
			desc = "These shorts really grow on you.",
		},
		eyev =
		{
			name = "{name.eyev} Twine Cinch",
			desc = "Soft, flowy leaves, secured by an only <i>slightly</i> sticky pink belt.",
		},
	},
	POTIONS = {
		heal1 = {
			name = "Soothing Spirits",
			desc = "A sturdy bottle, able to hold a good amount of liquid.\n\nEffects trigger after drinking.",
		},

		quick_heal1 = {
			name = "Bubbling Brew",
			desc = "A collection of smaller flasks, each of them holds a perfect swallow of liquid.\n\nEffects trigger after drinking.",
		},

		duration_heal1 = {
			name = "Misting Mixture",
			desc = "The mixture seems to be endlessly misting.\n\nEffects trigger after drinking."
		},
	},

	TONICS =
	{
		yammo_rage = {
			name = "Spicy Pumpkin Seeds",
			desc = "Flavoured with pure, distilled <#RED>{name.yammo}</> rage.\n\n<#RED>{name_multiple.tonic}</> are automatically added to your <#RED>{name.potion}</> when equipped.\n\nEffects trigger after drinking.",
		},

		full_shield = {
			name = "{name.bulbug} Boba",
			desc = "Daily treats are scientifically proven to fortify body and soul.\n\n<#RED>{name_multiple.tonic}</> are automatically added to your <#RED>{name.potion}</> when equipped.\n\nEffects trigger after drinking.",
		},

		explotion = {
			name = "Popping Candy",
			desc = "These crushed <#RED>{name.trap_bomb_pinecone}</> bits will add some <i>oompf</> to any <#RED>{name.potion}</>.\n\n<#RED>{name_multiple.tonic}</> are automatically added to your <#RED>{name.potion}</> when equipped.\n\nEffects trigger after drinking.",
		},

		zucco_dash = {
			name = "Coffee Jelly",
			desc = "Gotta go fast.\n\n<#RED>{name_multiple.tonic}</> are automatically added to your <#RED>{name.potion}</> when equipped.\n\nEffects trigger after drinking.",
		},

		juggernaut = {
			name = "Juggernaut Jelly",
			desc = "It's mostly made of <#RED>{name.battoad}</> slime.\n\n<#RED>{name_multiple.tonic}</> are automatically added to your <#RED>{name.potion}</> when equipped.\n\nEffects trigger after drinking.",
		},

		shrink = {
			name = "Small Beans",
			desc = "Some <#RED>Pearls</> make you larger... these <#RED>Pearls</> make you small.\n\n<#RED>{name_multiple.tonic}</> are automatically added to your <#RED>{name.potion}</> when equipped.\n\nEffects trigger after drinking.",
		},

		mudslinger = {
			name = "Chocolate Foam",
			desc = "Contains your yearly recommended intake of mud.\n\n<#RED>{name_multiple.tonic}</> are automatically added to your <#RED>{name.potion}</> when equipped.\n\nEffects trigger after drinking.",
		},

		projectile_repeat = {
			name = "{name.battoad} Eggs",
			desc = "They're great for spitting!\n\n<#RED>{name_multiple.tonic}</> are automatically added to your <#RED>{name.potion}</> when equipped.\n\nEffects trigger after drinking.",
		},

		resolve1 = {
			name = "Tincture of Stone Resolve",
			desc = "Cannot be interrupted by hits for {duration} second(s).\n\n<#RED>{name_multiple.tonic}</> are automatically added to your <#RED>{name.potion}</> when equipped.\n\nEffects trigger after drinking.",
		},

		freeze = {
			name = "Ice Cold Slushie",
			desc = "Make your brain freeze into everyone else's problem.\n\n<#RED>{name_multiple.tonic}</> are automatically added to your <#RED>{name.potion}</> when equipped.\n\nEffects trigger after drinking.",
		},
	},

	FOOD =
	{
		spoiled_food = {
			name = "Spoiled Food",
			desc = "Are you sure you wanna eat that?\n\n<#RED>Lunch Boxes</> are automatically eaten at the start of a run.\n\n<#RED>Buffs</> remain active for the run's duration.",
		},

		stuffed_blarma = {
			name = "Stuffed {name.blarmadillo}",
			desc = "Soon you will be, too.\n\n<#RED>Lunch Boxes</> are automatically eaten at the start of a run.\n\n<#RED>Buffs</> remain active for the run's duration.",
		},

		spiced_gourd = {
			name = "Spiced Gourd",
			desc = "It tastes kind of how autumn leaves smell.\n\n<#RED>Lunch Boxes</> are automatically eaten at the start of a run.\n\n<#RED>Buffs</> remain active for the run's duration.",
		},

		salad = {
			name = "Leaf Salad",
			desc = "Supposedly \"healthy\".\n\n<#RED>Lunch Boxes</> are automatically eaten at the start of a run.\n\n<#RED>Buffs</> remain active for the run's duration.",
		},

		roast_tail = {
			name = "Roast Tail",
			desc = "Tastes hearty, but leaves one feeling fit and spry.\n\n<#RED>Lunch Boxes</> are automatically eaten at the start of a run.\n\n<#RED>Buffs</> remain active for the run's duration.",
		},

		noodle_legs = {
			name = "Noodle Legs",
			desc = "Wriggles all the way down!\n\n<#RED>Lunch Boxes</> are automatically eaten at the start of a run.\n\n<#RED>Buffs</> remain active for the run's duration.",
		},

		meatwich = {
			name = "Meatwich",
			desc = "Take some meat. Put it between some other meat.\nEnjoy.\n\n<#RED>Lunch Boxes</> are automatically eaten at the start of a run.\n\n<#RED>Buffs</> remain active for the run's duration.",
		},

		haggis = {
			name = "Haggis",
			desc = "Looks offal, tastes great.\n\n<#RED>Lunch Boxes</> are automatically eaten at the start of a run.\n\n<#RED>Buffs</> remain active for the run's duration.",
		},

		gourd_stew = {
			name = "Gourd Stew",
			desc = "You can even eat the bowl!\n\n<#RED>Lunch Boxes</> are automatically eaten at the start of a run.\n\n<#RED>Buffs</> remain active for the run's duration.",
		},

		cased_sausage = {
			name = "Cased Sausage",
			desc = "Pack yourself a snack for the road, just in case.\n\n<#RED>Lunch Boxes</> are automatically eaten at the start of a run.\n\n<#RED>Buffs</> remain active for the run's duration.",
		},

		dimsum = {
			name = "Dim Sum",
			desc = "You know you want sum.\n\n<#RED>Lunch Boxes</> are automatically eaten at the start of a run.\n\n<#RED>Buffs</> remain active for the run's duration.",
		},

		cabbage_wrap = {
			name = "Cabbage Wrap",
			desc = "Some <#RED>{name_multiple.cabbageroll}</> were harmed in the making of this snack.\n\n<#RED>Lunch Boxes</> are automatically eaten at the start of a run.\n\n<#RED>Buffs</> remain active for the run's duration.",
		},
	},

	--KRIS: jambell here, just filling in what it is asking me to fill in
	HEART =
	{
		heart_megatreemon =
		{
			name = "Heart of Mother Treek",
			desc = "Increase your <#RED>Maximum Health</> by <#RED>{health}</>.",
		},
		heart_owlitzer =
		{
			name = "Power of Owlitzer",
			desc = "When you enter a new clearing, <#RED>Heal</> for <#RED>{heal} Health</>."
		},
		heart_bandicoot =
		{
			name = "Heart of Engimox",
			desc = "Increase your <#RED>Dodge Speed</> by <#RED>{dodge_speed}%</>.",
		},
		heart_thatcher =
		{
			name = "Power of Thatcher",
			desc = "[TEMP] Increase your <#RED>Dodge Speed</> by <#RED>{dodge_speed}%</>.",
		},
	},


	KEY_ITEMS = {
		recipe_generic =
		{
			name = "%s Recipe: %s",
			desc = "Unlocks the recipe for [%s]."
		},
		basic =
		{
			name = "Basic Armour Recipe Book",
			desc = "Barely worth the paper it's printed on."
		},


		bandicoot =
		{
			name = "{name.bandicoot} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.bandicoot}</> bits."
		},
		bonejaw =
		{
			name = "{name.bonejaw} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.bonejaw}</> bits."
		},
		rotwood =
		{
			name = "{name.rotwood} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.rotwood}</> bits."
		},
		thatcher =
		{
			name = "{thatcher} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{thatcher}</> bits."
		},
		blarmadillo =
		{
			name = "{blarmadillo} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{blarmadillo}</> bits."
		},
		cabbageroll =
		{
			name = "{name.cabbageroll} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.cabbageroll}</> bits."
		},
		yammo =
		{
			name = "{name.yammo} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.yammo}</> bits."
		},
		megatreemon =
		{
			name = "{name.megatreemon} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.megatreemon}</> bits."
		},
		zucco =
		{
			name = "{name.zucco} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.zucco}</> bits."
		},
		gourdo =
		{
			name = "{name.gourdo} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.gourdo}</> bits."
		},
		battoad =
		{
			name = "{name.battoad} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.battoad}</> bits."
		},
		floracrane =
		{
			name = "{name.floracrane} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.floracrane}</> bits."
		},
		mothball =
		{
			name = "{name.mothball} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.mothball}</> bits."
		},
		seeker =
		{
			name = "{name.seeker} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.seeker}</> bits."
		},
		groak =
		{
			name = "{name.groak} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.groak}</> bits."
		},
		bulbug =
		{
			name = "{name.bulbug} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.bulbug}</> bits."
		},
		slowpoke =
		{
			name = "{name.slowpoke} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>name.slowpoke}</> bits."
		},
		owlitzer =
		{
			name = "{name.owlitzer} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.owlitzer}</> bits."
		},
		treemon =
		{
			name = "{name.treemon} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.treemon}</> bits."
		},
		-- windmon =
		-- {
		-- 	name = "{name.windmon} Armour Recipe Book",
		-- 	desc = "Teaches a crafter how to make armour from <#RED>{name.windmon}</> bits."
		-- },
		eyev =
		{
			name = "{name.eyev} Armour Recipe Book",
			desc = "Teaches a crafter how to make armour from <#RED>{name.eyev}</> bits."
		},
	},

	KONJUR = {
		name = "{name.konjur}",
		desc = "The enigmatic and magical substance that seems to fuel all of the Rotwood's misgivings.",
	},

	--When writing material names/descriptions, try to always include the name of the monster it drops from in the item title (if any) and include what area the monster is found in in the description (if any)
	MATERIALS = {
		TAKE_SOUL_BUTTON = "<p bind='Controls.Digital.ACTION' color=0> Take",
		TAKE_SOUL_BUTTON_NAME = "<p bind='Controls.Digital.ACTION' color=0> Take %s",
		konjur =
		{
			name = "{name.konjur}",
			desc = "Raw {name.konjur}",
		},

		glitz =
		{
			name = "Glitz",
			desc = "The crystallized byproduct of <#KONJUR>{name.konjur}</>, used as currency.",
		},

		konjur_soul_lesser =
		{
			name = "{name.konjur_soul_lesser}",
			desc = "A hunk of pure, solidified <#KONJUR>{name.konjur}</>.\n\nFound in: <#RED>Special Rooms</>"
		},

		konjur_soul_greater =
		{
			name = "{name.konjur_soul_greater}",  
			desc = "Heavily condensed, solid <#KONJUR>{name.konjur}</>.\n\nIt was harvested from an especially fearsome <#RED>{name.rot}</>.\n\nFound in: <#RED>{name.rot_miniboss} Rooms</>"
		},

		konjur_heart =
		{
			name = "{name.konjur_heart}", 
			desc = "Magnificently powerful, solid <#KONJUR>{name.konjur}</>, recovered from a <#RED>{name.rot_boss}</>.\n\nIt is prized by the {name_multiple.foxtails}.\n\nFound in: <#RED>{name.rot_boss} Rooms</>"
		},

		-- Writer!
		konjur_heart_megatreemon =
		{
			name = "{name.megatreemon} {name.konjur_heart}", 
			desc = "Magnificently powerful, solid <#KONJUR>{name.konjur}</>, recovered from a <#RED>{name.megatreemon}</>.\n\nIt is prized by the {name_multiple.foxtails}."
		},

		-- Writer!
		konjur_heart_owlitzer =
		{
			name = "{name.owlitzer} {name.konjur_heart}", 
			desc = "Magnificently powerful, solid <#KONJUR>{name.konjur}</>, recovered from a <#RED>{name.owlitzer}</>.\n\nIt is prized by the {name_multiple.foxtails}."
		},

		-- Writer!
		konjur_heart_bandicoot =
		{
			name = "{name.bandicoot} {name.konjur_heart}", 
			desc = "Magnificently powerful, solid <#KONJUR>{name.konjur}</>, recovered from a <#RED>{name.bandicoot}</>.\n\nIt is prized by the {name_multiple.foxtails}."
		},

		-- Writer!
		konjur_heart_thatcher =
		{
			name = "{name.thatcher} {name.konjur_heart}", 
			desc = "Magnificently powerful, solid <#KONJUR>{name.konjur}</>, recovered from a <#RED>{name.thatcher}</>.\n\nIt is prized by the {name_multiple.foxtails}."
		},

		rotwood_bark =
		{
			name = "{name.rotwood} Bark",
			desc = "Its bite is admittedly much worse.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},

		rotwood_twig =
		{
			name = "{name.rotwood} Twig",
			desc = "A gnarled, knot-pocked twig.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},

		rotwood_root =
		{
			name = "{name.rotwood} Root",
			desc = "A section from the subterranean labyrinth of roots from a <#RED>{name.rotwood}</>.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},

		rotwood_face =
		{
			name = "{name.rotwood} Grimace",
			desc = "Wood in the gnarly features of a <#RED>{name.rotwood}'s</> face.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},

		thatcher_antennae =
		{
			name = "{name.thatcher} Feeler",
			desc = "Wiry and durable antennae.\n\nFound in: <#RED>{name.thatcher_swamp}</>",
		},

		thatcher_fur =
		{
			name = "{name.thatcher} Down",
			desc = "Makes for decent stuffing.\n\nFound in: <#RED>{name.thatcher_swamp}</>",
		},

		thatcher_limb =
		{
			name = "{name.thatcher} Tarsus",
			desc = "A long limb belonging to a <#RED>{name.thatcher}</>.\n\nFound in: <#RED>{name.thatcher_swamp}</>",
		},

		thatcher_wing =
		{
			name = "{name.thatcher} Fin",
			desc = "A transparent wing of a <#RED>{name.thatcher}</>.\n\nFound in: <#RED>{name.thatcher_swamp}</>",
		},

		thatcher_shell =
		{
			name = "{name.thatcher} Husk",
			desc = "A solid shell.\n\nFound in: <#RED>{name.thatcher_swamp}</>",
		},

		thatcher_skull =
		{
			name = "{name.thatcher} Skull",
			desc = "A skull that resembling a <#RED>{name.thatcher}</> when it was alive.\n\nFound in: <#RED>{name.thatcher_swamp}</>",
		},

		bonejaw_claw =
		{
			name = "{name.bonejaw} Claw",
			desc = "A sharp claw. The worst kind\n\nFound in: <#RED></>",
		},

		bonejaw_hide =
		{
			name = "{name.bonejaw} Rind",
			desc = "A coriaceous yet mealy hide.\n\nFound in: <#RED></>",
		},

		bonejaw_skull =
		{
			name = "{name.bonejaw} Skull",
			desc = "A skull of an <#RED>{name.bonejaw}</>. A good chunk exposed when breathing\n\nFound in: <#RED></>",
		},

		bonejaw_spike =
		{
			name = "{name.bonejaw} Tusk",
			desc = "One of many spikes from an <#RED>{name.bonejaw}</>.\n\nFound in: <#RED></>",
		},

		bonejaw_tail =
		{
			name = "{name.bonejaw} Tail",
			desc = "An <#RED>{name.bonejaw}'s</> serpentine tail.\n\nFound in: <#RED></>",
		},

		bonejaw_tooth =
		{
			name = "{name.bonejaw} Fang",
			desc = "A well-kept, well pointed tooth.\n\nFound in: <#RED></>",
		},

		bandicoot_tail =
		{
			name = "{name.bandicoot} Tail",
			desc = "Rarely wags.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},

		--[[
		bandicoot_hide =
		{
			name = "{name.bandicoot} Hide",
			desc = "Good at keeping in heat.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},

		bandicoot_skull =
		{
			name = "{name.bandicoot} Skull",
			desc = "A {name.bandicoot}'s former skull post removal.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		]]

		bandicoot_wing =
		{
			name = "{name.bandicoot} Wings",
			desc = "Leathery wings with incredible tensile strength.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},

		bandicoot_hand =
		{
			name = "{name.bandicoot} Hand",
			desc = "Once-nimble fingers taken from an <#RED>{name.bandicoot}</>.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},

		arak_eye =
		{
			name = "{name.arak} Eye",
			desc = "A big eye with an intense gaze.\n\nFound in: <#RED></>",
		},

		arak_leg =
		{
			name = "{name.arak} Leg",
			desc = "A hairy leg.\n\nFound in: <#RED></>",
		},

		arak_shell =
		{
			name = "{name.arak} Shell",
			desc = "A silky shell.\n\nFound in: <#RED></>",
		},

		arak_skull =
		{
			name = "{name.arak} Skull",
			desc = "Even for a skull, it's a fright.\n\nFound in: <#RED></>",
		},

		arak_web =
		{
			name = "{name.arak} Web",
			desc = "Silky and tensile.\n\nFound in: <#RED></>",
		},

		owlitzer_fur = -- HELLOWRITER
		{
			name = "{name.owlitzer} Fur",
			desc = "[TEMP] Fluffy fur, harvested from an <#RED>{name.owlitzer}</>.\n\nFound in: <#RED>{name.owlitzer_forest}</>",
		},

		owlitzer_claw =
		{
			name = "{name.owlitzer} Claw",
			desc = "The razor sharp claws of an <#RED>{name.owlitzer}</>.\n\nFound in: <#RED>{name.owlitzer_forest}</>",
		},

		owlitzer_pelt =
		{
			name = "{name.owlitzer} Pelt",
			desc = "Majestic and beautiful. It's almost a shame the creature was felled.\n\nFound in: <#RED>{name.owlitzer_forest}</>",
		},

		--[[
		owlitzer_feather =
		{
			name = "{name.owlitzer} Feather",
			desc = "Inlficts a mean tickle.\n\nFound in: <#RED>{name.owlitzer_forest}</>",
		},

		owlitzer_fur =
		{
			name = "{name.owlitzer} Fur",
			desc = "Warm, fuzzy fur... and feathers\n\nFound in: <#RED>{name.owlitzer_forest}</>",
		},

		owlitzer_foot =
		{
			name = "{name.owlitzer} Foot",
			desc = "A lucky foot?\n\nFound in: <#RED>{name.owlitzer_forest}</>",
		},

		owlitzer_skull =
		{
			name = "{name.owlitzer} Skull",
			desc = "A skull with big eye sockets.\n\nFound in: <#RED>{name.owlitzer_forest}</>",
		},
		]]
		--[[
		flower_bush =
		{
			name = "Bush Flower",
			desc = "Suits a garden well.",
		},

		flower_violet =
		{
			name = "Violet",
			desc = "Plant it in your garden.",
		},
		]]

		------------- GLOBAL DROPS not in game
		--[[
		generic_bone =
		{
			name = "Rot Bone",
			desc = "The skeleton bits of a Rot.",
		},
		generic_meat =
		{
			name = "Rot Meat",
			desc = "A prime cut of Rot meat.",
		},
		generic_hide =
		{
			name = "Rot Hide",
			desc = "A section of hide from a Rot.",
		},
		generic_leaf =
		{
			name = "Leaf",
			desc = "It's a leaf. Wonder where it came from?",
		},
		]]

		------------- STARTING FOREST DROPS not in game 
		--[[
		forest_fern =
		{
			name = "Hollow Root Fern",
			desc = "Only found in Hollow Root Forest",
		},
		forest_sap =
		{
			name = "Hollow Root Sap",
			desc = "Only found in Hollow Root Forest",
		},
		forest_twigs =
		{
			name = "Hollow Root Twigs",
			desc = "Only found in Hollow Root Forest",
		},
		forest_seed =
		{
			name = "Hollow Root Seeds",
			desc = "Only found in Hollow Root Forest",
		},
		]]

		------ STARTING FOREST CREATURE DROPS
		--[[
		cabbageroll_leg =
		{
			name = "{name.cabbageroll} Stalk",
			desc = "Wee legs let them twits crawl about\n\nFound in: <#RED>{name.treemon_forest}</>",
		},
		]]
		cabbageroll_skin =
		{
			name = "{name.cabbageroll} Skin",
			desc = "<#RED>{name_multiple.cabbageroll}</> have <i>layers</i>.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},

		cabbageroll_baby =
		{
			name = "{name.cabbageroll} Bulb",
			desc = "The larval form of a <#RED>{name.cabbageroll}</>. It may look cute, but don't be fooled.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},

		blarmadillo_hide =
		{
			name = "{name.blarmadillo} Hide",
			desc = "A section of rough, thick skin. The last owner should've moisturized.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},

		blarmadillo_trunk =
		{
			name = "{name.blarmadillo} Trunk",
			desc = "The elongated snoot of a felled <#RED>{name.blarmadillo}</>. It squishes in a displeasing manner.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},

		--[[blarmadillo_scale =
		{
			name = "{name.blarmadillo} Slate",
			desc = "A callus scale\n\nFound in: <#RED>{name.treemon_forest}</>",
		},]]

		treemon_arm =
		{
			name = "{name.treemon} Branch",
			desc = "A twisted branch, sawn off a felled <#RED>{name.treemon}</>.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},

		treemon_cone =
		{
			name = "{name.treemon} Cone",
			desc = "It's basically a baby <#RED>{name.treemon}</>.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},
		--[[
		treemon_stick =
		{
			name = "{name.treemon} Stick",
			desc = "Found in: <#RED>{name.treemon_forest}</>",
		},
		]]

		megatreemon_bark =
		{
			name = "{name.megatreemon} Bark",
			desc = "Found in: <#RED>{name.treemon_forest}</>",
		},
		megatreemon_hand =
		{
			name = "{name.megatreemon} Claw",
			desc = "There's just no reason for trees to have thumbs.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},
		megatreemon_cone =
		{
			name = "{name.megatreemon} Paincone",
			desc = "The volatile seed of a nasty <#RED>{name.megatreemon}</>.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},
		--[[
		megatreemon_wood =
		{
			name = "{name.megatreemon} Wood",
			desc = "Found in: <#RED>{name.treemon_forest}</>",
		},
		]]

		--[[
		yammo_tail =
		{
			name = "{name.yammo} Tail",
			desc = "Pockmarked and vegetated\n\nFound in: <#RED>{name.treemon_forest}</>",
		},
		]]
		yammo_skin =
		{
			name = "{name.yammo} Dermis",
			desc = "It smells faintly citrusy.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},
		yammo_stem =
		{
			name = "{name.yammo} Stem",
			desc = "A rough, fibrous stem that once served as a <#RED>{name.yammo}'s</> horn.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},

		zucco_claw =
		{
			name = "{name.zucco} Claw",
			desc = "They're a lot safer now they're not attached to a <#RED>{name.zucco}</>.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},
		zucco_skin =
		{
			name = "{name.zucco} Skin",
			desc = "It looks like it'd be crunchy and refreshing if you bit into it.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},
		--[[
		zucco_stem =
		{
			name = "{name.zucco} Stem",
			desc = "Found in: <#RED>{name.treemon_forest}</>",
		},
		]]
		--[[
		gourdo_finger =
		{
			name = '{name.gourdo} Finger',
			desc = "Found in: <#RED>{name.treemon_forest}</>",
		},
		]]
		gourdo_hat =
		{
			name = '{name.gourdo} Hat',
			desc = "A leafy stem, carved off the top of a <#RED>{name.gourdo}</>.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},
		gourdo_skin =
		{
			name = '{name.gourdo} Skin',
			desc = "Dark red rind from a <#RED>{name.gourdo}'s</> behind.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},
		beets_body =
		{
			name = "{name.beets} Body",
			desc = "Whoops, I guess someone dropped the <#RED>{name.beets}</>.\n\nFound in: <#RED>{name.treemon_forest}</>",
		},
		beets_leaf =
		{
			name = "{name.beets} Leaf",
			desc = "How can the top of a <#RED>{name.beets}</> be so soft, yet hurt so bad?\n\nFound in: <#RED>{name.treemon_forest}</>",
		},

		gnarlic_cloves =
		{
			name = "{name.gnarlic} Cloves",
			desc = "They emanate a pungent stench.\n\nFound in: <#RED>{name.owlitzer_forest}</>",
		},
		gnarlic_sprouts =
		{
			name = "{name.gnarlic} Sprouts",
			desc = "A grassy tuft. It was taken from atop the head of a <#RED>{name.gnarlic}</>.\n\nFound in: <#RED>{name.owlitzer_forest}</>",
		},

		--Writer!
		windmon_trunk =
		{
			name = "{name.windmon} Trunk",
			desc = "DESC\n\nFound in: <#RED>{name.owlitzer_forest}</>",
		},

		--Writer!
		windmon_horn =
		{
			name = "{name.windmon} Horn",
			desc = "DESC\n\nFound in: <#RED>{name.owlitzer_forest}</>",
		},

		------------- SWAMP BIOME DROPS
		--[[ --not in game
		swamp_slime =
		{
			name = "Kanft Slime",
			desc = "Only found in Kanft Swamp.",
		},
		swamp_moss =
		{
			name = "Kanft Moss",
			desc = "Only found in Kanft Swamp.",
		},
		swamp_spore =
		{
			name = "Kanft Spore",
			desc = "Only found in Kanft Swamp.",
		},
		swamp_vines =
		{
			name = "Kanft Vines",
			desc = "Only found in Kanft Swamp.",
		},
		]]

		------ SWAMP CREATURE DROPS

		battoad_leg =
		{
			name = '{name.battoad} Leg',
			desc = "A generous hock of <#RED>{name.battoad}</> meat.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		battoad_wing =
		{
			name = '{name.battoad} Wing',
			desc = "A stretchy wing with an only mildly offputting odour.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},

		--[[
		battoad_scale =
		{
			name = '{name.battoad} Scale',
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},

		battoad_tongue =
		{
			name = '{name.battoad} Tongue',
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},
		battoad_eyeball =
		{
			name = '{name.battoad} Eyeball',
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},
		]]

		mothball_fluff =
		{
			name = "{name.mothball} Fluff",
			desc = "Cloud-soft down, harvested from a <#RED>{name.mothball}</>.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		mothball_teen_ear =
		{
			name = "{name.mothball} Ears",
			desc = "They tickle.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},

		--[[
		mothball_eyeballs =
		{
			name = "{name.mothball} Eyeballs",
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},

		mothball_teen_claw =
		{
			name = "{name.mothball} Claw",
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},
		mothball_teen_tail =
		{
			name = "{name.mothball} Tail",
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},
		]]

		eyev_vine =
		{
			name = "{name.eyev} Vine",
			desc = "A rubbery vine, shorn from an <#RED>{name.eyev}</>.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		eyev_eyelashes =
		{
			name = "{name.eyev} Eyelashes",
			desc = "Frozen forever in a sultry stare.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		--[[
		eyev_eyeball =
		{
			name = "{name.eyev} Eyeball",
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},
		]]

		seeker_wood_stick =
		{
			name = "{name.seeker} Wood Stick",
			desc = "What's the point of a nature walk if you don't come back with a good stick?\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		seeker_wood_plank =
		{
			name = "{name.seeker} Wood Plank",
			desc = "Sturdy bark pulled from a felled <#RED>{name.seeker}</>.\n\nFound in: <#RED>{name.thatcher_swamp}</>",
		},
		seeker_leaf =
		{
			name = "{name.seeker} Leaf",
			desc = "Crunchy leaves taken from a felled <#RED>{name.seeker}</>.\n\nFound in: <#RED>{name.thatcher_swamp}</>",
		},
		seeker_beard =
		{
			name = "{name.seeker} Beard",
			desc = "It feels scratchy and full of wisdom.\n\nFound in: <#RED>{name.thatcher_swamp}</>",
		},
		seeker_boquet =
		{
			name = "{name.seeker} Bouquet",
			desc = "A <#RED>{name.seeker}</> by any other name would smell like feet.\n\nFound in: <#RED>{name.thatcher_swamp}</>",
		},

		floracrane_feather =
		{
			name = "{name.floracrane} Down",
			desc = "Soft, elegant feathers harvested from a <#RED>{name.floracrane}</>.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		floracrane_beak =
		{
			name = "{name.floracrane} Beak",
			desc = "Are <#RED>{name_multiple.floracrane}</> shy? They're all tongue-tied.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		--[[
		floracrane_tail =
		{
			name = "{name.floracrane} Plume",
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},
		floracrane_leg =
		{
			name = "{name.floracrane} Drumstick",
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},
		floracrane_neck =
		{
			name = "{name.floracrane} Vines",
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},
		floracrane_feet =
		{
			name = "{name.floracrane} Foot",
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},
		]]

		mossquito_cap =
		{
			name = "{name.mossquito} Cap",
			desc = "The <#RED>{name.mossquito}</> fashion world is abuzz over this hat style.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},

		mossquito_tooth =
		{
			name = "{name.mossquito} Tooth",
			desc = "No wonder their bites hurt so much.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		--[[
		mossquito_nose =
		{
			name = "{name.mossquito} Nose",
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},
		]]

		slowpoke_eye =
		{
			name = "{name.slowpoke} Eye",
			desc = "A piercing eye, harvested from a <#RED>{name.slowpoke}</>.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},

		slowpoke_tail =
		{
			name = "{name.slowpoke} Tail",
			desc = "A pleasingly plump tail.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		--[[
		slowpoke_jaw =
		{
			name = "{name.slowpoke} Jaw",
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},
		]]

		bulbug_jaw =
		{
			name = "{name.bulbug} Pincers",
			desc = "Huge insect jaws with impressive piercing power.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		bulbug_bulb =
		{
			name = "{name.bulbug} Bulb",
			desc = "A classic <#RED>{name.bulbug}</> bulb. The air around it feels fuzzy with energy.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		--[[
		bulbug_claw =
		{
			name = "{name.bulbug} Claw",
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},
		]]

		groak_tentacle =
		{
			name = "{name.groak} Tentacle",
			desc = "A <#RED>{name.groak}'s</> squishy mustache.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		groak_elite =
		{
			name = "{name.groak} Wigglers",
			desc = "Wiggly ears taken from a felled <#RED>{name.groak}</>.\n\nFound in: <#RED>{name.kanft_swamp}</>",
		},
		--[[
		groak_chin =
		{
			name = "{name.groak} Chin",
			desc = "Found in: <#RED>{name.kanft_swamp}</>",
		},
		]]
	},

	AMULET = {
		STATS = {
			ATTACK = "Attack",
			HAMMER_ATK = "Bammer attack",
			POLEARM_ATK = "Skewer attack",
			CLEAVER_ATK = "Cleaver attack",
			REFLECT = "Reflect {name.concept_damage}",
			DEFEND = "Defense",
			SPEED = "Speed",
			HEAL_RANDOM = "Random party member heal per hit",
		},

		shield_bone =
		{
			name = "Creaking Bone",
			desc = "Silence is painful, but when it groans you feel at ease.\n\nReduced <#RED>{name.concept_damage}</> every third hit received.",
		},
		rage_guts =
		{
			name = "Entrails of Anger",
			desc = "Increased <#RED>{name.concept_damage}</> every third hit dealt.",
		},
		healing_meat =
		{
			name = "Healing Flesh",
			desc = "Enemy attacks refill a bit of potion.",
		},
		broken_bone =
		{
			name = "Broken Bone",
			desc = "Brokenness is weakness. Brokenness is pointy.\n\nIncrease <#RED>{name.concept_damage}</> dealt and received.",
		},
		spike_bone =
		{
			name = "Bone Shards",
			desc = "Brokenness is pointy.\n\nAttackers receive a portion of <#RED>{name.concept_damage}</> dealt.",
		},
		ancient_strike =
		{
			name = "Ancient Strike",
			desc = "Some old battle techniques still have their merits.",
		},
		awm_hunger =
		{
			name = "Awm's Hunger",
			desc = "Ingesting of <#KONJUR>{name.konjur}</> is a risky habit.",
		},
		bludj_anger =
		{
			name = "Bludj's Anger",
			desc = "Draw inspiration from Bludj to strengthen Bammer attacks.",
		},
		destruction_frenzy =
		{
			name = "Destruction Frenzy",
			desc = "Unleash a rampage with no regard for consequences.",
		},
		healing_roulette =
		{
			name = "Healing Roulette",
			desc = "Each strike will heal a lucky party member.",
		},
	},

	--------------------------------------------------------------------------------------------------------------
	--ABILITY DESC FORMATTING NOTES FOR WRITERS--
	
	---Use red highlight on numbers, percentages and key combat concepts, ie, Attack, Dodge, Damage, Heal, Shield Segment, Runspeed, etc

	---"Runspeed"is one word

	---Anything within <#RED></> brackets should be capitalized as if a proper noun, ie <#RED>Damage</> :--VS--: <#RED>damage</>

	---Try to keep numbers next to their associated nouns whenever possible, ie
	-----"A <#RED>{percent}% Runspeed</> increase":--VS--: "A <#RED>{percent}%</> increase of <#RED>Runspeed</>"

	---If a description has too many elements to highlight, use best judgement to choose the most important 3. Try to view the description in-game to help prioritize

	---End description sentences with a period
	--------------------------------------------------------------------------------------------------------------

	SHIELD =
	{
		-- shield_light_attack =
		-- {
		-- 	name = "Even the Odds",
		-- 	desc = "Gain <#RED>{shield} Shield Segment</> every {attack_count} <#RED>Light</> attacks that connect.", -- {shield} for # of shield added if we make them add >1 shield segment
		-- },

		shield_heavy_attack =
		{
			name = "Heavy Defense",
			desc = "When your <#RED>Heavy Attacks</> hit <#RED>{targets_required} or More</> enemies at once, gain <#RED>{shield} Shield Segment</>."-- {shield} for # of shield added if we make them add >1 shield segment
		},

		shield_focus_kill =
		{
			name = "Resolute",
			desc = "When you <#RED>Kill</> an enemy with a <#BLUE>{name.concept_focus_hit}</>, gain <#RED>{shield} Shield Segment</>.", -- {shield} for # of shield added if we make them add >1 shield segment
		},

		shield_dodge =
		{
			name = "Tuck and Roll",
			desc = "When you <#RED>Perfect Dodge</>, gain <#RED>{shield} Shield Segments</>."
		},

		shield_hit_streak =
		{
			name = "The Best Defense",
			desc = "Every <#RED>{hitstreak} Hit Streak</>, gain <#RED>{shield} Shield Segment</>."
		},

		shield_when_hurt =
		{
			name = "Automated Defenses",
			desc = "When you take <#RED>{name.concept_damage}</>, gain <#RED>{shield} Shield Segment</>."
		},

		shield =
		{
			name = "Shield Segment",
			desc = "When you have <#RED>4 Shield Segments</>, any <#RED>{name.concept_damage}</> taken is reduced to <#RED>{damage}</>, then removes all <#RED>Segments</>."
		},

		shield_to_health =
		{
			name = "Inequivalent Exchange",
			desc = "When your <#RED>Shield</> breaks, <#RED>Heal</> for {text} of the <#RED>{name.concept_damage}</> it prevented.",
			epic_string = "half",
			legendary_string = "all",
		},

		shield_dodge_knockback =
		{
			name = "Inertia",
			desc = "When you have <#RED>Shield</>, your <#RED>Dodge</> becomes an <#RED>Attack</> that deals <#RED>{damage_mod}% Weapon {name.concept_damage}</> and inflicts <#RED>Knockback</>.",
		},

		shield_move_speed_bonus =
		{
			name = "Resistance Training",
			desc = "Gain <#RED>+{speed}% {name.concept_runspeed}</> for every <#RED>Shield Segment</> you have.",
		},

		shield_heavy_attack_bonus_damage =
		{
			name = "Heavy Hitter",
			desc = "When you have <#RED>Shield</>, your <#RED>Heavy Attacks</> deal a bonus <#RED>+{percent}% {name.concept_damage}</>.",
		},

		shield_reduced_damage_on_break =
		{
			name = "Plan B",
			desc = "When your <#RED>Shield</> breaks, take <#RED>{percent}%</> reduced <#RED>{name.concept_damage}</> for <#RED>{time}</> seconds.",
		},

		shield_bonus_damage_on_break =
		{
			name = "Plan C",
			desc = "When your <#RED>Shield</> breaks, deal an extra <#RED>+{percent}% {name.concept_damage}</> for <#RED>{time}</> seconds.",
		},

		shield_move_speed_on_break =
		{
			name = "Plan Flee",
			desc = "When your <#RED>Shield</> breaks, gain <#RED>+{percent}% {name.concept_runspeed}</> for <#RED>{time}</> seconds.",
		},

		shield_steadfast =
		{
			name = "Adamantine",
			desc = "{string}",
			epic_string = "When you have <#RED>Shield</>, your <#RED>Attacks</> can no longer be interrupted.",
			legendary_string = "Your <#RED>Attacks</> can no longer be interrupted.",
		},

		shield_explosion_on_break =
		{
			name = "Shield Detonation",
			desc = "When your <#RED>Shield</> breaks, deal <#RED>{damage} {name.concept_damage}</> to all enemies in a <#RED>{radius}</> unit radius."
		},

		shield_knockback_on_break =
		{
			name = "Aftershock",
			desc = "When your <#RED>Shield</> breaks, all enemies in a <#RED>{radius}</> unit radius get <#RED>Knocked Down</>."
		},
	},

	ELECTRIC =
	{
		charged =
		{
			name = "Charge",
			desc = "When you <#RED>Die</>, trigger a <#RED>Chain Reaction</> which causes an additional <#RED>{damage_mod}% Weapon {name.concept_damage}</> to all other enemies that have <#RED>Charge</>, consuming one stack of <#RED>Charge</>."
		},

		charge_apply_on_light_attack =
		{
			name = "Static Charge",
			desc = "Apply <#RED>{stacks} Charge</> with your <#RED>Light Attacks</>.",
		},

		charge_apply_on_heavy_attack =
		{
			name = "Static Shock",
			desc = "Apply <#RED>{stacks} Charge</> in a large radius with your <#RED>Heavy Attacks</>."
		},

		charge_orb_on_dodge =
		{
			name = "Orb of ZAP!",
			desc = "When you <#RED>Dodge</>, drop an orb that applies <#RED>{stacks} Charge</> in a small radius <#RED>{pulses}</> times.", -- jambell: not displaying cooldown here, because the cooldown is == how long the orb lasts. Effectively, you just can't summon two. Trying to avoid time-based cooldowns, personally!
		},

		charge_consume_on_crit =
		{
			name = "Catalyst",
			desc = "Trigger a <#RED>Chain Reaction</> when you land a <#RED>Critical</> hit.",
		},

		charge_consume_on_focus =
		{
			name = "Lightning Rod",
			desc = "Trigger a <#RED>Chain Reaction</> when you land a <#BLUE>{name.concept_focus_hit}</>.",
		},

		charge_consume_all_stacks =
		{
			name = "Conductor",
			desc = "When you trigger a <#RED>Chain Reaction</>, consume all stacks of <#RED>Charge</>.",
		},

		charge_consume_extra_damage =
		{
			name = "Strike Twice",
			desc = "<#RED>Chain Reaction</> impulses cause an additional <#RED>+{damage_bonus_percent}% Weapon {name.concept_damage}</>.",
		},
	},

	SUMMON =
	{
		summon_slots =
		{
			name = "Summon Slots", --JAMBELL TODO
			desc = "Summon up to <#RED>{summons} Minions</>."--JAMBELL TODO
		},

		summon_on_kill =
		{
			name = "With A Little Help", --JAMBELL TODO
			desc = "When you <#RED>Kill</> an enemy, summon a <#RED>Minion</> to fight for you."--JAMBELL TODO
		},

		charm_on_kill =
		{
			name = "Enchantée", --JAMBELL TODO
			desc = "Once per clearing, when you <#RED>Kill</> an enemy it will return to life as a <#RED>Charmed</> {name.concept_ally}."--JAMBELL TODO
		},

		summon_wormhole_on_dodge =
		{
			name = "Thinking With Portals", --JAMBELL TODO
			desc = "When you double tap <#RED>Dodge</>, summon up to two portals to teleport between."--JAMBELL TODO
		},
	},

	SEED =
	{
		seeded =
		{
			name = "[TEMP] Seeded",
			desc = "[TEMP] It... does some stuff!"
		},

		seeded_on_light_attack =
		{
			name = "[TEMP] Seed: Light Attack",
			desc = "[TEMP]Your <#RED>Light Attack</> applies <#RED>Seed</>."--does <#RED>Half {name.concept_damage}</>, but applies <#RED>Seed</>."
		},

		seeded_on_heavy_attack =
		{
			name = "[TEMP] Seed: Heavy Attack",
			desc = "[TEMP]Your <#RED>Heavy Attack</> applies <#RED>Seed</> in a large radius."-- does <#RED>0 {name.concept_damage}</>, but applies <#RED>Seed</> in a large radius."
		},

		acid_on_dodge =
		{
			name = "[TEMP] Seed: Acid On Dodge",
			desc = "[TEMP]When you <#RED>Dodge</>, leave behind a trail of <#RED>Acid</>."-- does <#RED>0 {name.concept_damage}</>, but applies <#RED>Seed</> in a large radius."
		},
	},

	CHEAT = {
		-- They're all hidden, so nothing goes in here.
	},


	FOOD_POWER =
	{
		thick_skin =
		{
			name = "Silver Lining",
			desc = "When you take <#RED>{name.concept_damage}</>, reduce it by <#RED>{reduction}</>.",
		},

		heal_on_enter =
		{
			name = "Breath of Fresh Air",
			desc = "When you enter a new clearing, <#RED>Heal</> for <#RED>{heal} Health</>.",
		},

		max_health =
		{
			name = "Vitality",
			desc = "Increase <#RED>Maximum Health</> by <#RED>{health}</>."
		},

		max_health_on_enter =
		{
			name = "Trailblazer",
			desc = "When you enter a new clearing, gain <#RED>+{max_health} Maximum Health</> and <#RED>Heal</> for <#RED>{heal} Health</>."
		},

		retail_therapy =
		{
			name = "Retail Therapy",
			desc = "When you enter a <#RED>Shop</>, <#RED>Heal</> for <#RED>{heal} Health</>."
		},

		perfect_pairing =
		{
			name = "Perfect Pairing",
			desc = "Your <#RED>Potion</> will <#RED>Heal</> an additional <#RED>+{bonus_heal}% Health</>."
		},

		pocket_money =
		{
			name = "Pocket Change",
			desc = "Gain <#KONJUR>{konjur} {name.konjur}</>."
		},

		private_healthcare =
		{
			name = "Abundance Mindset",
			desc = "Whenever you pick up <#KONJUR>{name.konjur}</>, <#RED>Heal {percent}%</> of the amount picked up."
		},
	},

	POTION_POWER =
	{
		soothing_potion =
		{
			name = "Soothing Spirits",
			desc = "Immediately <#RED>Heal</> for <#RED>{heal} Health</>.",
		},
		bubbling_potion =
		{
			name = "Bubbling Brew",
			desc = "Immediately <#RED>Heal</> for <#RED>{heal} Health</>.",
		},
		misting_potion =
		{
			name = "Misting Mixture",
			desc = "<#RED>Heal</> for <#RED>{heal} Health</> every {tick_time} seconds until you've been healed <#RED>{num_heals}</> times.",
		},
	},

	STATUSEFFECT =
	{
		juggernaut =
		{
			name = "Juggernaut",
			desc = "Increases your <#RED>Size</> and <#RED>{name.concept_damage}</> by <#RED>+{damage}%</> per stack.\n\nEach stack also causes you to take <#RED>{damagereceivedmult}%</> less <#RED>{name.concept_damage}</>, but reduces your <#RED>{name.concept_runspeed}</> by <#RED>{speed}%</>.\n\nRemoved when combat ends.",
		},

		smallify =
		{
			name = "Tiny",
			desc = "Shrink in <#RED>Size</> by <#RED>{scale}%</>. Gain <#RED>+{speed}% {name.concept_runspeed}</>, but take <#RED>{damage}% Increased {name.concept_damage}</>.", --this kong's got STYLE, so listen up dudes, she can shrink in size, to suit. her. mood! she's quick and nimble when she needs to be, SHEee can float through the air, and climb. up. trees!
		},
		stuffed =
		{
			name = "Stuffed",
			desc = "Reduced <#RED>{name.concept_runspeed}</>.",
		},
		freeze =
		{
			name = "DEV_FREEZE",
			desc = "You should never see this in the UI.",
		},
		poison =
		{
			name = "DEV_POISON",
			desc = "You should never see this in the UI.",
		},
		hammer_totem_buff =
		{
			name = "DEV_HAMMER_TOTEM_BUFF",
			desc = "You should never see this in the UI.",
		},
		confused =
		{
			name = "DEV_CONFUSED",
			desc = "You should never see this in the UI.",
		},
		acid =
		{
			name = "DEV_ACID",
			desc = "You should never see this in the UI.",
		},
		bodydamage =
		{
			name = "DEV_BODYDAMAGE",
			desc = "You should never see this in the UI.",
		},
	},

	TONIC =
	{
		tonic_rage =
		{
			name = "Yammo Rage",
			desc = "Increase your <#RED>{name.concept_damage}</> by <#RED>+{damage}%</> for <#RED>{time}</> seconds.",
		},
		tonic_speed =
		{
			name = "Zucco Speed",
			desc = "Increase your <#RED>{name.concept_runspeed}</> by <#RED>+{speed}%</> for the rest of the encounter.",
		},
		tonic_explode =
		{
			name = "Explosive",
			desc = "Explode, dealing <#RED>{damage} {name.concept_damage}</> to all enemies within {radius} unit radius every <#RED>{tick_time}</> second for <#RED>{duration}</> seconds.",
		},
		tonic_freeze =
		{
			name = "Freeze",
			desc = "Freeze all enemies in the encounter.",
		},
		tonic_projectile =
		{
			name = "Mud Spray",
			desc = "Shoot <#RED>{projectiles} Projectiles</> that deal <#RED>{damage} {name.concept_damage}</> each.",
		},
		tonic_projectile_repeat =
		{
			name = "Sustained Spray",
			desc = "Shoot <#RED>{projectiles} Projectiles</> that deal <#RED>{damage} {name.concept_damage}</> every <#RED>{tick_time}</> second for <#RED>{duration}</> seconds.",
		},
	},

	PLAYER =
	{

		snowball_effect =
		{
			name = "Snowball Effect",
			-- TODO(dbriscoe): Can we interpolate On a Roll to ensure
			-- consistent translation and insert nbsp to prevent bad wrapping?
			-- For now, I added nbsp inside the string but that seems
			-- unreliable.
			desc = "When you <#RED>Kill</> an enemy, gain <#RED>{stacks} Stacks</> of <#RED>On a Roll</>.",
		},

		damage_until_hit =
		{
			name = "On a Roll",
			desc = "Gain <#RED>+1% {name.concept_damage}</> for each stack.\n\nRemove all stacks whenever you take <#RED>{name.concept_damage}</>.",
		},

		undamaged_target =
		{
			name = "Strong Start",
			desc = "Your <#RED>Attacks</> against enemies with full <#RED>Health</> deal <#RED>+{bonus}% {name.concept_damage}</>.",
		},

		thorns =
		{
			name = "Retaliation",
			desc = "When you get attacked, deal <#RED>{reflect} {name.concept_damage}</> back to the attacker.",
		},

		heal_on_focus_kill =
		{
			name = "Concentrated Cure",
			desc = "When you use a <#BLUE>{name.concept_focus_hit}</> to <#RED>Kill</> an enemy or break something in the environment, <#RED>Heal</> for <#RED>{heal} Health</>.",
		},

		heal_on_quick_rise =
		{
			name = "Stage Fall",
			desc = "When you <#RED>Quick Rise</>, <#RED>Heal</> for <#RED>{heal} Health</>.",
		},

		-- extra_damage_after_iframe_dodge =
		-- {
		-- 	name = "Sting Like A Bee",
		-- 	desc = "After a <#RED>Perfect Dodge</>, your next attack deals {damage_mult}x damage.\n\n<z 0.8><i><#GOLD>Perfect Dodge</>: Narrowly dodge an attack at the last second.</i></z>",
		-- },

		berserk =
		{
			name = "Cornered Coyote",
			desc = "When you have less than <#RED>{health} Health</>, deal <#RED>+{bonus}% {name.concept_damage}</>.",
		},


		max_health_and_heal =
		{
			name = "Waffle",
			desc = "Gain <#RED>+{health} Maximum Health</> and <#RED>Heal</> to full."
		},

		bomb_on_dodge =
		{
			name = "Parting Gifts",
			desc = "When you <#RED>Dodge</>, launch {text} in a random direction.\n\n<z 0.8><i>Cooldown: {cd} seconds</i></z>",
			text_single = "a <#RED>Bomb</>",
			text_multiple = "<#RED>2 Bombs</>", -- TODO: make a more elegant way of handling this, especially one that can read {num_bombs}
		},

		attack_dice =
		{
			name = "Attack Dice",
			desc = "When you deal <#RED>{name.concept_damage}</>, do an extra <#RED>{min}-{max} {name.concept_damage}</>, <#RED>{count}</> times."
		},

		running_shoes =
		{
			name = "Running Shoes",
			desc = "Gain <#RED>+{speed}% {name.concept_runspeed}</>."
		},

		coin_purse =
		{
			name = "Petty Cash",
			desc = "Inflict an extra <#RED>+{bonus}% {name.concept_damage}</> for every <#KONJUR>{currency} {name.konjur}</> you have."
		},

		extended_range =
		{
			name = "Pew Pew!",
			desc = "Every <#RED>{swings} Attacks</>, shoot <#RED>{projectiles}</> {description} <#RED>+{damage}% Weapon {name.concept_damage}</>.",
			epic_desc = "<#RED>Projectile</> that deals",
			legendary_desc = "<#RED>Projectiles</> that each deal",
		},

		bloodthirsty =
		{
			name = "Bloodthirsty",
			desc = "<#RED>Heal {heal}%</> of <#RED>{name.concept_damage}</> you deal. Lose <#RED>{health_penalty}% Maximum Health</>.\n\nTake <#RED>{damage} {name.concept_damage}</> every <#RED>{time}</> seconds. <#RED>Bloodthirsty</> will never deal fatal <#RED>{name.concept_damage}</>.",
		},

		mulligan =
		{
			name = "Mulligan",
			desc = "When you <#RED>Die</>, remove this Power and <#RED>Heal</> to <#RED>{heal}% Max Health</>.",
		},

		iron_brew =
		{
			name = "Iron Brew",
			desc = "Refill your <#RED>Potion</>.\n\nEach time you <#RED>Drink</>, <#RED>Heal</> an additional <#RED>+{bonus_heal}%</> and gain <#RED>Shield</>.",
		},

		risk_reward =
		{
			name = "Thrill Seeker",
			desc = "Deal <#RED>+{outgoing}% Damage</>. Take <#RED>+{incoming}% {name.concept_damage}</>.",
		},

		retribution =
		{
			name = "Righteous Fury", --renamed from Retribution to help differentiate it from Retaliation
			desc = "When you take <#RED>{name.concept_damage}</>, your next <#RED>Attack</> deals <#RED>+{percent}% {name.concept_damage}</>.",
		},

		pump_and_dump =
		{
			name = "Wind Up",
			desc = "Every <#RED>{attacks}th Attack</> deals <#RED>+{percent}% {name.concept_damage}</>."
		},

		volatile_weaponry =
		{
			name = "Volatile Weaponry",
			desc = "Every <#RED>{count} Hit Streak</>, cause an explosion in an area around the target."
		},

		precision_weaponry =
		{
			name = "Precision Weaponry",
			desc = "Every <#RED>{count} Hit Streak</> is guaranteed to <#RED>Critical Hit</>. "
		},

		fractured_weaponry =
		{
			name = "Fractured Weaponry",
			desc = "Every <#RED>{count} Hit Streak</>, launch a <#RED>Bomb</> in a random direction."
		},

		weighted_weaponry =
		{
			name = "Weighted Weaponry",
			desc = "When you have at least <#RED>{count} Hit Streak</>, <#RED>Critical Hits</> deal <#RED>+{percent}% {name.concept_damage}</>."
		},

		momentum =
		{
			name = "Momentum",
			desc = "When you <#RED>Dodge</>, gain <#RED>+{speed}% {name.concept_runspeed}</> for <#RED>{time}</> seconds."
		},

		down_to_business =
		{
			name = "Straight to Business",
			desc = "When you enter a new clearing, gain <#RED>+{speed}% {name.concept_runspeed}</> for <#RED>{time}</> seconds."
		},

		grand_entrance =
		{
			name = "Big Stick",
			desc = "Your first <#RED>Heavy Attack</> per clearing deals <#RED>{damage} {name.concept_damage}</> to all enemies."
		},

		extroverted =
		{
			name = "Extroverted",
			desc = "When you enter a new clearing, gain <#RED>+{damage}% {name.concept_damage}</> for <#RED>{time}</> seconds."
		},

		introverted =
		{
			name = "Introverted",
			desc = "When you enter a new clearing, gain <#RED>Shield</>."
		},

		wrecking_ball =
		{
			name = "Wrecking Ball",
			desc = "Multiply your <#RED>{name.concept_damage}</> by your <#RED>{name.concept_runspeed}</> modifier."
		},

		steadfast =
		{
			name = "Relentless",
			desc = "Your <#RED>Attacks</> can no longer be interrupted."
		},

		getaway =
		{
			name = "Post-Kill Zoomies",
			desc = "When you <#RED>Kill</> an enemy, gain <#RED>+{speed}% {name.concept_runspeed}</> for <#RED>{time}</> seconds."
		},

		-- stronger_light_attack =
		-- {
		-- 	name = "Light Might",
		-- 	desc = "Your Light attacks deal {bonus}% more damage."
		-- },

		-- stronger_heavy_attack =
		-- {
		-- 	name = "Heavy Hitter",
		-- 	desc = "Your Heavy attacks deal {bonus}% more damage."
		-- },

		-- stronger_crits =
		-- {
		-- 	name = "Concentration",
		-- 	desc = "Your Focus attacks deal {bonus}% more damage."
		-- },

		-- increased_pushback =
		-- {
		-- 	name = "Keepaway",
		-- 	desc = "Your attacks push enemies further away."
		-- },

		no_pushback =
		{
			name = "Constructive Criticism",
			desc = "Your <#RED>Attacks</> no longer push enemies away."
		},

		increased_hitstun =
		{
			name = "Simply Stunning",
			desc = "Your <#RED>Attacks</> deal {desc} <#RED>Hitstun</> to enemies.",
			common_desc = "more",
			epic_desc = "even more",
			legendary_desc = "significantly more",
		},

		combo_wombo =
		{
			name = "Confidence Building",
			desc = "Your <#RED>{name.concept_damage}</> is increased by an amount equal to {upgrade_text}your current <#RED>Hit Streak</> until it ends.",
			upgrade_text = "<#RED>double</> ", -- space is intentional
		},


		battle_fame =
		{
			name = "Surgical",
			desc = "When combat ends, gain <#KONJUR>{name.konjur}</> equal to {upgrade_text}your highest <#RED>Hit Streak</> in that clearing.",
			upgrade_text_epic = "<#RED>double</> ", -- space is intentional
			upgrade_text_legendary = "<#RED>triple</> ", -- space is intentional
			new_highest_popup = "New high: %s",
		},

		streaking =
		{
			name = "Excitable",
			desc = "Increase your <#RED>{name.concept_runspeed}</> by a percentage equal to {upgrade_text}your current <#RED>Hit Streak</>.",
			upgrade_text = "<#RED>double</> ", -- space is intentional
			upgrade_text_legendary = "<#RED>triple</> ", -- space is intentional
		},

		crit_streak =
		{
			name = "Piñata",
			desc = "Increase your <#RED>Critical Chance</> by a percentage equal to {upgrade_text}your current <#RED>Hit Streak</>.",
			upgrade_text = "<#RED>double</> ", -- space is intentional
		},

		crit_movespeed =
		{
			name = "Ambush Predator",
			desc = "Increase your <#RED>Critical Chance</> by a percentage equal to {upgrade_text}your current <#RED>{name.concept_runspeed}</>.",
			-- upgrade_text = "<#RED>double</> ", -- space is intentional
		},

		lasting_power =
		{
			name = "Encore",
			desc = "When a <#RED>Hit Streak</> ends, gain <#RED>Critical Chance</> equal to that <#RED>Hit Streak</> for <#RED>{time}</> seconds.",
		},

		sting_like_a_bee =
		{
			name = "Sting Like a Bee",
			desc = "When you <#RED>Perfect Dodge</>, the next time you deal <#RED>{name.concept_damage}</> is guaranteed to <#RED>Critical Hit</>."
		},

		advantage =
		{
			name = "Good First Impression",
			desc = "Your <#RED>Attacks</> against enemies with <#RED>{desc} Health</> are guaranteed to <#RED>Critical Hit</>."
		},

		salted_wounds =
		{
			name = "Salted Wounds",
			desc = "Your <#BLUE>{name_multiple.concept_focus_hit}</> have <#RED>+{bonus}% Critical Chance</>.",
		},

		crit_knockdown =
		{
			name = "High Ground",
			desc = "Your <#RED>Attacks</> against enemies that are <#RED>Knocked Down</> have <#RED>+{chance}% Critical Chance</>."
		},

		heal_on_crit =
		{
			name = "Morale Booster",
			desc = "When you <#RED>Critical Hit</>, <#RED>Heal</> for <#RED>{heal}</>.",
		},


		konjur_on_crit =
		{
			name = "Jackpot",
			desc = "<#RED>Critical Hits</> drop <#KONJUR>{konjur} {name.konjur}</>."
		},

		-- reprieve =
		-- {
		-- 	name = "Reprieve",
		-- 	desc = "<#RED>Hit Streaks</> decay {percent}% slower.",
		-- },

		sanguine_power =
		{
			name = "Sanguine Power",
			desc = "Each time you <#RED>Kill</> an enemy, gain <#RED>+{bonus}% Critical Chance</> for <#RED>{time}</> seconds.",
		},

		feedback_loop =
		{
			name = "Feedback Loop",
			desc = "Each time you <#RED>Critical Hit</>, gain <#RED>+{bonus}% Critical Chance</> for <#RED>{time}</> seconds."
		},

		-- crit_to_crit_damage =
		-- {
		-- 	name = "Crit to Crit Damage",
		-- 	desc = "Increase the <#RED>Critical Damage</> of attacks by the <#RED>Critical Chance</> of the attack."
		-- },

		bad_luck_protection =
		{
			name = "Get'em Next Time",
			desc = "Each time you do not <#RED>Critical Hit</>, gain <#RED>+{bonus}% Critical Chance</>.\n\nResets after your next <#RED>Critical Hit</>."
		},

		-- critical_roll =
		-- {
		-- 	name = "Counter Argument",
		-- 	desc = "Each time you <#RED>Perfect Dodge</>, gain <#RED>+{bonus}% Critical Chance</> for <#RED>{time}</> seconds."
		-- },

		optimism =
		{
			name = "Healthy Optimism",
			desc = "Each time you <#RED>Heal</>, gain <#RED>+{bonus}% Critical Chance</> for <#RED>{time}</> seconds."
		},

		pick_of_the_litter =
		{
			name = "Pick of the Litter",
			desc = "When you activate a <#RED>{name.concept_relic}</>, choose from <#RED>{count}</> more {options}.",
			single_string = "option",
			plural_string = "options",
		},

		-- stronger_counter_hits =
		-- {
		-- 	name = "Counter Puncher",
		-- 	desc = "Your attacks that land during an enemy's attack startup deal <#RED>+{bonus}% Damage</>."
		-- },

		free_upgrade =
		{
			name = "First One's Free",
			desc = "Whenever you get a new <#RED>Power</>, upgrade it once."
		},

		shrapnel =
		{
			name = "Shrapnel",
			desc = "Anything you break in the environment shatters into <#RED>{projectiles} Projectiles</> that deal <#RED>{damage} {name.concept_damage}</> each.",
		},

		analytical =
		{
			name = "Lil' Schemer",
			desc = "If you do not <#RED>Attack</> for <#RED>{seconds}</> seconds, your next <#RED>Attack</> gains <#RED>+{percent}% {name.concept_damage}</>.",
		},

		dont_whiff =
		{
			name = "Strength of Conviction",
			desc = "Your <#RED>Light Attack</> deals an extra <#RED>{otherdamage} {name.concept_damage}</>, but inflicts <#RED>{selfdamage} {name.concept_damage}</> to you when you miss.",
		},

		dizzyingly_evasive =
		{
			name = "Acrobat",
			desc = "Your <#RED>Dodge</> can be chained into itself infinitely.",
		},

		carefully_critical =
		{
			name = "Light Precision",
			desc = "When you land a <#RED>Light Attack</>, gain <#RED>+{bonus}% Critical Chance</>.\n\nWhen you miss with a <#RED>Light Attack</>, reset the bonus.",
		},

		reflective_dodge =
		{
			name = "I'm Rubber, You're Glue",
			desc = "When you <#RED>Dodge</>, reflect <#RED>{percent}% {name.concept_damage}</> taken for the next <#RED>{time}</> seconds.",
		},

		ping =
		{
			name = "Ping!",
			desc = "When you <#RED>Light Attack</>, your next <#RED>Attack</> deals double <#RED>{name.concept_damage}</> if it's a <#RED>Heavy Attack</>."--but <#RED>Half Damage</> if it's another <#RED>Light Attack</>.",
		},

		pong =
		{
			name = "Pong!",
			desc = "When you <#RED>Heavy Attack</>, your next <#RED>Attack</> deals double <#RED>{name.concept_damage}</> if it's a <#RED>Light Attack</>."--but <#RED>Half Damage</> if it's another <#RED>Heavy Attack</>.",
		},

		-- Skill-specific Powers
		moment37 =
		{
			-- Parry
			name = "Thirty-Seven", -- from EVO Moment #37, famous fighting game parry
			desc = "When you <#RED>Parry</>, gain <#RED>100% Critical Chance</> for an extra <#RED>{time}</> seconds.",
		},

		jury_and_executioner =
		{
			-- Hammer Thump - "Order in the Court"
			name = "Jury and Executioner",
			desc = "<#RED>Order in the Court</> deals <#RED>{damage_per_consecutive_hit} {name.concept_damage}</> for each consecutive hit.",
		},

		-- Loot powers:
		loot_increase_upgrade_epic = "<i>much</i> ", --space is intentional. it slots into {desc} in descs below
		loot_increase_upgrade_legendary = "<i>significantly</i> ", --space is intentional. it slots into {desc} in descs below
		-- We can't really show any meaningful numbers to the players because of the way our loot system works, unfortunately.
		-- If we want to show numbers instead of "more likely / much more likely / etc", we'll need to find a way to make it grokable.

		loot_increase_cabbageroll =
		{
			name = "Bloomin' {name_multiple.cabbageroll}",
			desc = "<#RED>{name_multiple.cabbageroll}</> are {upgrade_text}more likely to drop <#RED>Materials</> when felled.",
		},
		loot_increase_blarmadillo =
		{
			name = "Bloated {name_multiple.blarmadillo}",
			desc = "<#RED>{name_multiple.blarmadillo}</> are {upgrade_text}more likely to drop <#RED>Materials</> when felled.",

		},

		max_health_wanderer =
		{
			name = "Tendrel", -- jambell name, please ask before changing
			desc = "Increase <#RED>Maximum Health</> by <#RED>{health}</>."
		},

		-- REVIVE POWERS:
		-- Multiplayer-only powers which get triggered when you revive someone.
		-- do we have macros for revive, 'ally', etc?
		-- JAMBELL we do now: {name.concept_ally} {name.concept_revive}
		revive_gain_konjur =
		{
			name = "Grave Robber",
			desc = "When you <#RED>{name.concept_revive}</> an {name.concept_ally}, gain <#KONJUR>{konjur} {name.konjur}</>."
		},

		revive_explosion =
		{
			name = "Phoenix Burst",
			desc = "When you <#RED>{name.concept_revive}</> an {name.concept_ally}, deal <#RED>{damage} {name.concept_damage}</> to all enemies.",
		},

		revive_damage_bonus =
		{
			name = "Lich King",
			desc = "When you <#RED>{name.concept_revive}</> an {name.concept_ally}, gain <#RED>+{percent_per_revive}% {name.concept_damage}</> for the rest of the {name.run}." --what doesnt kill you makes me stronger :)
		},

		revive_borrow_power =
		{
			name = "Departing Gift", --Dearly Departing Gift too wordy?
			desc = "When you <#RED>{name.concept_revive}</> an {name.concept_ally}, copy <#RED>{powers_borrowed} {name.concept_relic}</> from their loadout for the rest of the {name.dungeon_room}.",
			--JAMBELL i imagine this one'll upgrade to copy more powers --kris
			--common_desc = "<#RED>{powers_borrowed} {name.concept_relic}</>",
			--epic_desc = "<#RED>{powers_borrowed} {name_multiple.concept_relic}</>",
		},
	},

	SKILL = {
		parry =
		{
			name = "Parry",
			desc = "Nullify an incoming <#RED>Attack</> to gain a brief window of <#RED>100% Critical Chance</>."
		},

		buffnextattack =
		{
			name = "Fist Pound", -- This buffs the entire attack, not just until the critical hit. An entire swing will have the buff. Should maybe change to simplify.
			desc = "Pound your fists together to gain <#RED>+{stackspertrigger}% Critical Chance</> until your next <#RED>Critical Hit</>.",
		},

		bananapeel =
		{
			name = "Banana Peel",
			desc = "<#RED>Heals</> for <#RED>{heal} Health</> when eaten.\n\nLeaves behind a <#RED>Banana Peel</> that inflicts <#RED>Knock Down</> on any target that steps on it.\n\nRegain <#RED>1 Banana</> for every <#RED>{damage_til_new_banana} {name.concept_damage}</> dealt.",
		},

		throwstone =
		{
			name = "Throw Stone",
			desc = "Throw a stone <#RED>Projectile</> which deals your <#RED>Weapon {name.concept_damage}</>.",
		},

		-- POLEARM
		polearm_shove =
		{
			name = "Crosscheck",
			desc = "Push an enemy away from you, creating space.",
		},

		polearm_vault =
		{
			name = "Pole Vault",
			desc = "Launch yourself over an obstacle or enemy to help with positioning.",
		},

		-- SHOTPUT
		shotput_summon =
		{
			name = "Direct Recall", -- Use skill to summon the ball to your hands, which travels quickly horizontally towards you hitting anything in its way
			desc = "Your <#RED>{name.weapon_shotput}</> surges toward you in a straight line, causing <#RED>{name.concept_damage}</> to all targets in its path.",
		},

		shotput_recall =
		{
			name = "Arcing Recall", -- Use skill to summon the ball to your hands, which travels in an arc and can land on any enemies if you don't catch it.
			desc = "Your <#RED>{name.weapon_shotput}</> returns to you in a high arc, causing <#RED>{name.concept_damage}</> to all targets it lands on if not caught.",
		},

		shotput_seek =
		{
			name = "Reverse Recall", -- Use skill to throw yourself towards your ball, tackling anything along the way.
			desc = "Launch yourself toward your <#RED>{name.weapon_shotput}</>, causing <#RED>{name.concept_damage}</> to all targets in your path.",
		},

		-- HAMMER
		hammer_thump =
		{
			name = "Order in the Court",
			desc = "Pound the head of your <#RED>{name.weapon_hammer}</> into the ground, causing <#RED>Knockback</> to any nearby enemies.\n\nHold <#RED>Skill</> to charge.",
		},

		hammer_totem =
		{
			name = "Hazard Idol",
			desc = "Sacrifice <#RED>{healthtocreate} Health</> to summon a Hazard Idol.\n\n<#RED>Everything</> in a large radius of the Idol deals <#RED>+{bonusdamagepercent}% {name.concept_damage}</>.\n\nThe Idol <#RED>Heals</> its destroyer for <#RED>{healthtocreate} Health</>.",
		},

		-- CANNON
		cannon_butt =
		{
			name = "Battering Ram",
			desc = "Hit an enemy with the butt of your <#RED>{name.weapon_cannon}</>.\n\nOn hit, <#RED>Gain 1 {name.cannon_ammo}</>.",
		},


		--BOSSES
		-- MOTHER TREEK
		megatreemon_weaponskill =
		{
			name = "Mother of Methuselah",
			desc = "Summon a line of <#RED>{name.megatreemon}</> roots.",
		},
	},

	EQUIPMENT = {
		-- basic
		equipment_basic_head =
		{
			name = "equipment_basic_head",
			desc = "Increase your <#RED>Maximum Health</>.",
			variables =
			{
				health = "Maximum Health",
			},
		},
		equipment_basic_body =
		{
			name = "equipment_basic_body",
			desc = "Increase your <#RED>Maximum Health</>.",
			variables =
			{
				health = "Maximum Health",
			},
		},
		equipment_basic_waist =
		{
			name = "equipment_basic_waist",
			desc = "Increase your <#RED>Maximum Health</>.",
			variables =
			{
				health = "Maximum Health",
			},
		},

		-- cabbageroll
		equipment_cabbageroll_head =
		{
			name = "equipment_cabbageroll_head",
			desc = "Your <#RED>Dodge</> deals a <#RED>Knockback</> hit to enemies.", --\nYour <#RED>Dodge</> temporarily increases your <#RED>{name.concept_runspeed}</>.",
			variables =
			{
				damage_mod = "Weapon {name.concept_damage} Dealt",
			},
		},
		equipment_cabbageroll_body =
		{
			name = "equipment_cabbageroll_body",
			desc = "Your <#RED>Dodge</> is <#RED>Invincible</> for longer.",
			variables =
			{
				percent_extra_iframes = "Bonus <#RED>Invincibility</#>",
			},
			--Your <#BLUE>Focus Attacks</> deal extra <#RED>{name.concept_damage}</>.
		},
		equipment_cabbageroll_waist =
		{
			name = "equipment_cabbageroll_waist",
			desc = "Your <#RED>Dodge</> is faster.",
			variables =
			{
				percent_speed_bonus = "Bonus Speed",
			},
		},

		-- blarma
		equipment_blarmadillo_head =
		{
			name = "equipment_blarmadillo_head",
			desc = "Take less <#RED>{name.concept_damage}</> from <#RED>Projectiles</>.",
			variables =
			{
				projectile_damage_reduction = "{name.concept_damage} Reduction",
			},
		},
		equipment_blarmadillo_body =
		{
			name = "equipment_blarmadillo_body",
			desc = "Take less <#RED>{name.concept_damage}</> from <#RED>{name_multiple.rot_miniboss}</>.",
			variables =
			{
				miniboss_damage_reduction = "{name.concept_damage} Reduction",
			},
		},
		equipment_blarmadillo_waist =
		{
			name = "equipment_blarmadillo_waist",
			desc = "Take less <#RED>{name.concept_damage}</> from <#RED>Traps</>.",
			variables =
			{
				trap_damage_reduction = "{name.concept_damage} Reduction",
			},
		},

		-- battoad
		equipment_battoad_head =
		{
			name = "equipment_battoad_head",
			desc = "When you gain <#KONJUR>{name.konjur}</>, gain more.",
			variables =
			{
				bonus_percent = "Bonus {name.konjur}",
			}
		},
		equipment_battoad_body =
		{
			name = "equipment_battoad_body",
			desc = "When you take <#RED>Damage</>, lose <#KONJUR>{name.konjur}</> and <#RED>Heal</> back some of the <#RED>{name.concept_damage}</> taken.",
			variables =
			{
				heal_percent = "Percentage Healed",
				cost = "{name.konjur} Lost",
			}
		},
		equipment_battoad_waist =
		{
			name = "equipment_battoad_waist",
			desc = "Gain <#KONJUR>{name.konjur}</> when breaking anything in the environment.", --TODO: come up with strong keyword for "destructible props but NOT traps/windmon projectiles"
			variables =
			{
				konjur = "{name.konjur}",
			}
		},

		-- battoad
		equipment_windmon_head =
		{
			name = "equipment_windmon_head",
			desc = "When you <#RED>Dodge</>, create a gust of <#RED>Wind</> behind you.",
			variables =
			{
				wind_strength = "Wind Strength"
			}
		},
		equipment_windmon_body =
		{
			name = "equipment_windmon_body",
			desc = "When you <#RED>Perfect Dodge</>, drop a <#RED>{name.windmon} Spikeball</> behind you.",
			variables =
			{
				number_of_balls = "Number of Spikeballs"
			}
		},
		equipment_windmon_waist =
		{
			name = "equipment_windmon_waist",
			desc = "Gain <#RED>Wind Resistance</> while standing still.",
			variables =
			{
				wind_resistance = "Wind Resistance",
			}
		},

		-- gnarlic
		equipment_gnarlic_head =
		{
			name = "equipment_gnarlic_head",
			desc = "Your run becomes an <#RED>Attack</> that deals <#RED>{name.concept_damage}</> based on how fast you are moving.",
			variables =
			{
				damage_bonus = "<#RED>{name.concept_damage}</> Bonus"
			}
		},
		equipment_gnarlic_body =
		{
			name = "equipment_gnarlic_body",
			desc = "When you run in one direction, gain bonus <#RED>{name.concept_runspeed}</> every second.",
			variables =
			{
				speed_bonus_per_second = "{name.concept_runspeed} Bonus"
			}
		},
		equipment_gnarlic_waist =
		{
			name = "equipment_gnarlic_waist",
			desc = "Your <#RED>Dodge</> travels farther.",
			variables =
			{
				percent_distance_bonus = "Bonus Distance",
			}
		},


		-- groak
		equipment_groak_head =
		{
			name = "equipment_groak_head",
			desc = "Your <#RED>Heavy Attacks</> stun enemies for longer.",
			variables =
			{
				bonus_percent = "Hitstun Bonus",
			}
		},
		equipment_groak_body =
		{
			name = "equipment_groak_body",
			desc = "Your <#RED>Heavy Attacks</> pull enemies towards you.",
			variables =
			{
				pull_factor = "Pull Strength"
			},
		},
		equipment_groak_waist =
		{
			name = "equipment_groak_waist",
			desc = "You have a chance of negating the effect of any <#RED>Spore</>.",
			variables =
			{
				chance = "Chance",
			}
		},

		-- yammo
		equipment_yammo_head =
		{
			name = "equipment_yammo_head",
			desc = "Your <#BLUE>Focus</> <#RED>Heavy Attacks</> deal bonus <#RED>{name.concept_damage}</>.",
			variables =
			{
				damage_bonus = "{name.concept_damage} Bonus",
			}
		},
		equipment_yammo_body =
		{
			name = "equipment_yammo_body",
			desc = "Take less <#RED>{name.concept_damage}</> from <#RED>{name_multiple.rot_boss}</>.",
			variables =
			{
				boss_damage_reduction = "{name.concept_damage} Reduction",
			},
		},
		equipment_yammo_waist =
		{
			name = "equipment_yammo_waist",
			desc = "Take less <#RED>{name.concept_damage}</> while you aren't <#RED>Attacking</>.",
			variables =
			{
				damage_reduction = "Damage Reduction",
			}
		},
		-- gourdo
		equipment_gourdo_head =
		{
			name = "equipment_gourdo_head",
			desc = "When you <#RED>Heal</>, heal again.",
			variables =
			{
				bonus_heal = "Bonus Heal",
			},
		},
		equipment_gourdo_body =
		{
			name = "equipment_gourdo_body",
			desc = "When you <#RED>Heal</>, heal all <#RED>{name_multiple.concept_ally}</> for a portion.",
			variables =
			{
				shared_heal = "Shared Heal",
			},
		},
		equipment_gourdo_waist =
		{
			name = "equipment_gourdo_waist",
			desc = "<#RED>Heal</> when you enter a new clearing.",
			variables =
			{
				heal_on_enter = "Heal on Enter",
			},
		},
		-- zucco
		equipment_zucco_head =
		{
			name = "equipment_zucco_head",
			desc = "Increase your <#RED>{name.concept_runspeed}</>.",
			variables =
			{
				speed = "{name.concept_runspeed}",
			},
		},
		equipment_zucco_body =
		{
			name = "equipment_zucco_body",
			desc = "Your <#BLUE>Focus Attacks</> deal extra <#RED>{name.concept_damage}</>.",
			variables =
			{
				focus_damage_bonus = "{name.concept_damage} Bonus",
			},
		},
		equipment_zucco_waist =
		{
			name = "equipment_zucco_waist",
			desc = "NO POWER",
			variables =
			{
				focus_damage_bonus = "Modifier",
			},
		},
		-- megatreemon
		equipment_megatreemon_head =
		{
			name = "equipment_megatreemon_head",
			desc = "Deal increased <#RED>{name.concept_damage}</> to all <#RED>Regular {name_multiple.rot}</>.",
			variables =
			{
				damage_bonus = "{name.concept_damage} Bonus",
			},
		},
		equipment_megatreemon_body =
		{
			name = "equipment_megatreemon_body",
			desc = "Chance to summon a <#RED>Defensive Root</> when hit.",
			variables =
			{
				chance_to_summon = "Summon Chance",
				root_lifetime = "Root Lifetime",
			},
		},
		equipment_megatreemon_waist =
		{
			name = "equipment_megatreemon_waist",
			desc = "NO POWER",
			variables =
			{
				chance_to_summon = "Modifier",
				root_lifetime = "Modifier",
			},
		},

		-- owlitzer
		equipment_owlitzer_head =
		{
			name = "equipment_owlitzer_head",
			desc = "{damage_per_stack} {name.concept_damage} to Regular {name_multiple.rot}",
		},
		equipment_owlitzer_body =
		{
			name = "equipment_owlitzer_body",
			desc = "{damage_per_stack} {name.concept_damage} to Regular {name_multiple.rot}",
		},
		equipment_owlitzer_waist =
		{
			name = "equipment_owlitzer_waist",
			desc = "NO POWER",
		},

		--mothball
		equipment_mothball_head =
		{
			name = "equipment_mothball_head",
			desc = "Deal more <#RED>{name.concept_damage}</> when fighting near an {name.concept_ally}.",
			variables =
			{
				damage_bonus = "{name.concept_damage} Bonus",
			},
		},
		equipment_mothball_body =
		{
			name = "equipment_mothball_body",
			desc = "Take less <#RED>{name.concept_damage}</> when fighting near an {name.concept_ally}.",
			variables =
			{
				damage_reduction = "{name.concept_damage} Reduction",
			},
		},
		equipment_mothball_waist =
		{
			name = "equipment_mothball_waist",
			desc = "Gain more <#RED>Health</> when healing near an {name.concept_ally}.",
			variables =
			{
				heal_bonus = "Health Bonus",
			},
		},

		--eyev
		equipment_eyev_head =
		{
			name = "equipment_eyev_head",
			desc = "When you <#RED>Perfect Dodge</>, your attacker takes increased <#RED>{name.concept_damage}</> for a few seconds.",
			variables =
			{
				time = "Seconds",
				debuff_stacks = "{name.concept_damage} Bonus",
			},
		},
		equipment_eyev_body =
		{
			name = "equipment_eyev_body",
			desc = "When you <#RED>Perfect Dodge</>, gain increased <#RED>Critical Chance</> for a few seconds.",
			variables =
			{
				time = "Seconds",
				critchance_bonus = "Critical Chance Bonus",
			},
		},
		equipment_eyev_waist =
		{
			name = "equipment_eyev_waist",
			desc = "Your <#RED>Dodge</> is faster and moves through objects.",
			variables =
			{
				percent_speed_bonus = "Bonus Speed",
			},
		},

		--bulbug
		equipment_bulbug_head =
		{
			name = "equipment_bulbug_head",
			desc = "When you break an enemy's <#RED>Shield</>, deal <#RED>{name.concept_damage}</> to the target anyway.",
			variables =
			{
				damage_mult_of_blocked_attack = "{name.concept_damage} Bonus",
			},
		},

		equipment_bulbug_body =
		{
			name = "equipment_bulbug_body",
			desc = "When you break an enemy's <#RED>Shield</>, gain <#RED>Shield Segments</>.",
			variables =
			{
				shield_segments = "Shield Segments",
			},
		},

		equipment_bulbug_waist =
		{
			name = "equipment_bulbug_waist",
			desc = "When you gain <#RED>Shield</>, break it and deal <#RED>{name.concept_damage}</> in an area around you.",
			variables =
			{
				weapon_damage_percent = "{name.concept_damage} Dealt",
			},

		},
		-- floracrane
		equipment_floracrane_head =
		{
			name = "equipment_floracrane_body",
			desc = "<#RED>Critical Hits</> deal additional <#RED>{name.concept_damage}</>.",
			variables =
			{
				bonus = "Critical {name.concept_damage} Bonus",
			},
		},
		equipment_floracrane_body =
		{
			name = "equipment_floracrane_body",
			desc = "<#BLUE>{name_multiple.concept_focus_hit}</> have an increased <#RED>Critical Chance</>.",
			variables =
			{
				bonus = "Critical Chance",
			},
		},
		equipment_floracrane_waist =
		{
			name = "equipment_floracrane_waist",
			desc = "NO POWER",
		},
		equipment_bandicoot_head =
		{
			name = "equipment_bandicoot_head",
			desc = "Your attacks have a chance to <#RED>Multistrike</>.",
			variables =
			{
				chance = "Multistrike Chance",
			},
		},

		equipment_bandicoot_body =
		{
			name = "equipment_bandicoot_body",
			desc = "Your attacks have a chance to <#RED>Multistrike</>.",
			variables =
			{
				chance = "Multistrike Chance",
			},
		},
		equipment_bandicoot_waist =
		{
			name = "equipment_bandicoot_waist",
			desc = "NO POWER",
		},
	},

	BUILDINGS = {
		scout_tent =
		{
			name = "{name.station_scout}",
			desc = "Scouts congregate in this here tent. Ask round to track yourself a {name.rot}.",
		},
		scout_tent_1 =
		{
			name = "{name.station_scout}",
			desc = "A hangout spot for scouts. Wrangle up information about any nearby {name_multiple.rot}.",
		},
		armorer =
		{
			name = "{name.station_armorsmith}",
			desc = "This shop will craft you up some armour.",
		},
		armorer_1 =
		{
			name = "{name.station_armorsmith}",
			desc = "A shop that crafts and sells armour.",
		},
		apothecary =
		{
			name = "{name.station_apothecary}",
			desc = "Potions, tinctures, and elixirs await stirring, stewing, and brewing.",
		},
		forge =
		{
			name = "{name.station_blacksmith}",
			desc = "Objects blunt and sharp alike get crafted up in here.",
		},
		forge_1 =
		{
			name = "{name.station_blacksmith}",
			desc = "A shop where you can get weapons crafted.",
		},
		chemist =
		{
			name = "{name.station_apothecary}",
			desc = "A potion smith is at the ready to concoct in their cauldrons.",
		},
		chemist_1 =
		{
			name = "{name.station_apothecary}",
			desc = "Enjoy yourself a potion? This alchemancer combines elixirs into desirable concoctions to you specs.",
		},
		kitchen =
		{
			name = "{name.station_cook}",
			desc = "Make delicious meals to prepare you for the journey ahead."
		},
		kitchen_1 =
		{
			name = "{name.station_cook}",
			desc = "Make delicious meals to prepare you for the journey ahead."
		},
		refinery_1 =
		{
			name = "{name.station_refiner}",
			desc = "Refine and Research Monster Materials"
		},
		refinery =
		{
			name = "{name.station_refiner}",
			desc = "Refine and Research Monster Materials"
		},

		dojo_1 =  -- WRITER
		{
			name = "{name.station_dojo}",
			desc = "Learn how to fight stuff!"
		},

		marketroom_shop = -- WRITER
		{
			name = "{name.station_marketroom_shop}",
			desc = "Buy stuff!",
		},
	},

	PLACEABLE_PROP =
	{

	},

	FURNISHINGS = {
		dummy_bandicoot =
		{
			name = "{name.bandicoot} Dummy",
			desc = "Relive that victory against the {name.bandicoot} while doing without the pesky wounds endured.",
		},
		dummy_cabbageroll =
		{
			name = "{name.cabbageroll} Dummy",
			desc = "Those <#RED>{name_multiple.cabbageroll}</> were a relentless bother. Vent your annoyance on a dummy of 'em!",
		},
		chair1 =
		{
			name = "Wooden Chair",
			desc = "Its mossy scent is temporary. Probably.",
		},
		chair2 =
		{
			name = "Hard Chair",
			desc = "Builds your tailbone's character",
		},
		bench_megatreemon =
		{
			name = "Mega Bench",
			desc = "Like a regular bench, but mega",
		},
		bench_rotwood =
		{
			name = "Bench",
			desc = "Like a chair, but double it",
		},
		hammock =
		{
			name = "Hammock",
			desc = "Get the best sleep of your life and the worst back pain",
		},
		kitchen_barrel =
		{
			name = "Barrel",
			desc = "It helps keep food fresh I think",
		},
		kitchen_chair =
		{
			name = "Kitchen chair",
			desc = "Sit down when you're hungry",
		},
		outdoor_seating_stool =
		{
			name = "Outdoor Stool",
			desc = "Like an indoor stool, but with extra steps",
		},
		outdoor_seating =
		{
			name = "Outdoor seating",
			desc = "A chill place to chill",
		},
		character_customizer_vshack =
		{
			name = "Vanity",
			desc = "Allows you to customize your character"
		}
	},

	DECOR = {
		flower_bush =
		{
			name = "Bush Flower",
			desc = "Something right pretty in vile land.",
		},
		flower_violet =
		{
			name = "Violet",
			desc = "A violet amongst all the violence.",
		},
		tree =
		{
			name = "Tree",
			desc = "It's a tree.",
		},
		shrub =
		{
			name = "Shrub",
			desc = "It's a shrub.",
		},
		flower_bluebell =
		{
			name = "Bluebell",
			desc = "A blue flower shaped like a bell.",
		},

		plushies_lrg =
		{
			name = "Thatcher Plushie",
			desc = "Cute? Yes. Evil? Maybe.",
		},
		plushies_mid =
		{
			name = "Yammo Plushie",
			desc = "Doesn't look as threatening now",
		},
		plushies_sm =
		{
			name = "Zucco Plushie",
			desc = "SO CUTE",
		},
		plushies_stack =
		{
			name = "Rotrioshka",
			desc = "It goes on forever",
		},
		basket =
		{
			name = "Fruit Basket",
			desc = "Are those real?",
		},
		bulletin_board =
		{
			name = "Bulleting Board",
			desc = "A place to put down notices",
		},
		bread_oven =
		{
			name = "Bread Oven",
			desc = "If only we had a baker",
		},
		dye1 =
		{
			name = "Barrel of Dye",
			desc = "Colorful",
		},
		dye2 =
		{
			name = "Barrel of Dye",
			desc = "Colorful",
		},
		dye3 =
		{
			name = "Barrel of Dye",
			desc = "Colorful",
		},
		kitchen_sign =
		{
			name = "Kitchen Sign",
			desc = "In case you don't know where the kitchen is",
		},
		leather_rack =
		{
			name = "Leather Rack",
			desc = "Kinda dry",
		},
		tanning_rack =
		{
			name = "Tanning Rack",
			desc = "Kinda Tan",
		},
		pergola =
		{
			name = "Pergola",
			desc = "Rest in the shade and smell the flowers",
		},
		stone_lamp =
		{
			name = "Stone Lamp",
			desc = "Let there be light",
		},
		street_lamp =
		{
			name = "Street Lamp",
			desc = "Lux Aeterna",
		},
		travel_pack =
		{
			name = "Travel Pack",
			desc = "Everything you need in one place",
		},
		weapon_rack =
		{
			name = "Weapon Rack",
			desc = "Do I need a permit for those?",
		},
		well =
		{
			name = "Well",
			desc = "Well, well, well, what do we have here?",
		},
		wooden_cart =
		{
			name = "Wooden Cart",
			desc = "Pretty self-explanatory I think",
		},
	},

	BIOME_EXPLORATION =
	{
		forest =
		{
			name = "{name.forest} Exploration",
			desc = "Advance through expeditions to the <#RED>{name.treemon_forest}</> and <#RED>{name.owlitzer_forest}",
		},

		swamp =
		{
			name = "{name.swamp} Exploration",
			desc = "Advance through expeditions to <#RED>{name.kanft_swamp}</> and <#RED>{name.thatcher_swamp}</>",
		},

		tundra =
		{
			name = "{name.swamp} Exploration",
			desc = "Advance through expeditions to <#RED>{name.sedament_tundra}</>",
		}
	},

	MONSTER_RESEARCH =
	{
		--Can we make this happen codeside? So just {idname} + "Research" instead? --Kris

		-- forest
		beets =
		{
			name = "{name.beets} {name.research}",
			desc = "Advanced <#BLUE>{name.beets} {name.research}</> for more efficient use of <#RED>{name.beets}</> materials.",
		},
		gnarlic =
		{
			name = "{name.gnarlic} {name.research}",
			desc = "Advanced <#BLUE>{name.gnarlic} {name.research}</> for more efficient use of <#RED>{name.gnarlic}</> materials.",
		},
		cabbageroll =
		{
			name = "{name.cabbageroll} {name.research}",
			desc = "Advanced <#BLUE>{name.cabbageroll} {name.research}</> for more efficient use of <#RED>{name.cabbageroll}</> materials.",
		},

		blarmadillo =
		{
			name = "{name.blarmadillo} {name.research}",
			desc = "Advanced <#BLUE>{name.blarmadillo} {name.research}</> for more efficient use of <#RED>{name.blarmadillo}</> materials.",
		},
		zucco =
		{
			name = "{name.zucco} {name.research}",
			desc = "Advanced <#BLUE>{name.zucco} {name.research}</> for more efficient use of <#RED>{name.zucco}</> materials.",
		},
		yammo =
		{
			name = "{name.yammo} {name.research}",
			desc = "Advanced <#BLUE>{name.yammo} {name.research}</> for more efficient use of <#RED>{name.yammo}</> materials.",
		},
		gourdo =
		{
			name = "{name.gourdo} {name.research}",
			desc = "Advanced <#BLUE>{name.gourdo} {name.research}</> for more efficient use of <#RED>{name.gourdo}</> materials.",
		},
		eyev =
		{
			name = "{name.eyev} {name.research}",
			desc = "Advanced <#BLUE>{name.eyev} {name.research}</> for more efficient use of <#RED>{name.eyev}</> materials.",
		},
		treemon =
		{
			name = "{name.treemon} {name.research}",
			desc = "Advanced <#BLUE>{name.treemon} {name.research}</> for more efficient use of <#RED>{name.treemon}</> materials.",
		},
		megatreemon =
		{
			name = "{name.megatreemon} {name.research}",
			desc = "Advanced <#BLUE>{name.megatreemon} {name.research}</> for more efficient use of <#RED>{name.megatreemon}</> materials.",
		},
		owlitzer =
		{
			name = "{name.owlitzer} {name.research}",
			desc = "Advanced <#BLUE>{name.owlitzer} {name.research}</> for more efficient use of <#RED>{name.owlitzer}</> materials.",
		},

		-- swamp

		mothball =
		{
			name = "{name.mothball} {name.research}",
			desc = "Advanced <#BLUE>{name.mothball} {name.research}</> for more efficient use of <#RED>{name.mothball}</> materials.",
		},
		battoad =
		{
			name = "{name.battoad} {name.research}",
			desc = "Advanced <#BLUE>{name.battoad} {name.research}</> for more efficient use of <#RED>{name.battoad}</> materials.",
		},
		floracrane =
		{
			name = "{name.floracrane} {name.research}",
			desc = "Advanced <#BLUE>{name.floracrane} {name.research}</> for more efficient use of <#RED>{name.floracrane}</> materials.",
		},
		bulbug =
		{
			name = "{name.bulbug} {name.research}",
			desc = "Advanced <#BLUE>{name.bulbug} {name.research}</> for more efficient use of <#RED>{name.bulbug}</> materials.",
		},
		mossquito =
		{
			name = "{name.mossquito} {name.research}",
			desc = "Advanced <#BLUE>{name.mossquito} {name.research}</> for more efficient use of <#RED>{name.mossquito}</> materials.",
		},
		groak =
		{
			name = "{name.groak} {name.research}",
			desc = "Advanced <#BLUE>{name.groak} {name.research}</> for more efficient use of <#RED>{name.groak}</> materials.",
		},
		slowpoke =
		{
			name = "{name.slowpoke} {name.research}",
			desc = "Advanced <#BLUE>{name.slowpoke} {name.research}</> for more efficient use of <#RED>{name.slowpoke}</> materials.",
		},
		bandicoot =
		{
			name = "{name.bandicoot} {name.research}",
			desc = "Advanced <#BLUE>{name.bandicoot} {name.research}</> for more efficient use of <#RED>{name.bandicoot}</> materials.",
		},
	},

	DEFAULT_UNLOCK =
	{
		default =
		{
			name = "default data",
			desc = "no one should ever read this string in the game",
		}
	},

	RELATIONSHIP_CORE =
	{

	},

	WEAPON_MASTERY =
	{

		-- ALL TEMP
		-- KRIS, JAMBELL

		----- HAMMER -----
		HAMMER =
		{
			hammer_focus_hits =
			{
				name = "Focus Hits",
				desc = "Kill an enemy using a <#BLUE>{name.concept_focus_hit}</>",
			},

			hammer_focus_hits_destructibles =
			{
				name = "Collateral Damage",
				desc = "Get a <#BLUE>{name.concept_focus_hit}</> by hitting a Prop and an enemy at the same time", --kris
			},

			-- BASIC MOVES
			hammer_fading_light =
			{
				name = "Fading Lights",
				desc = "Kill an enemy with a Fading Light", --TODO controls
			},

			hammer_golf_swing =
			{
				name = "Golf Swings",
				desc = "Kill an enemy with a Golf Swing", --TODO controls
			},

			hammer_air_spin =
			{
				name = "Jumping Heavy Somersault",
				desc = "Kill an enemy with a Jumping Heavy Somersault", --TODO controls
			},

			hammer_lariat =
			{
				name = "Spinning Heavy Lariat",
				desc = "Kill an enemy with a Spinning Heavy Lariat", --TODO controls
			},

			hammer_heavy_slam =
			{
				name = "Standing Heavy Slam",
				desc = "Kill an enemy with a Standing Heavy Slam", --TODO controls
			},

			hammer_counterattack =
			{
				name = "Counter Attacks",
				desc = "Kill an enemy while it is in the middle of an attack",
			},

			-- ADVANCED MOVES
			hammer_hitstreak_dodge_L =
			{
				name = "Hitstreak with Rolling Light",
				desc = "Get a Hitstreak of 10 starting with a Rolling Light",
			},

			hammer_hitstreak_fading_L =
			{
				name = "Hitstreak with Fading Light",
				desc = "Get a Hitstreak of 10 featuring at least three Fading Lights",
			},
		},

		----- POLEARM -----
		POLEARM =
		{
			polearm_focus_hits_tip =
			{
				name = "Tipped {name_multiple.concept_focus_hit}",
				desc = "Kill an enemy using a <#BLUE>{name.concept_focus_hit}</>", --TODO
			},

			polearm_fading_light =
			{
				name = "Fading Lights",
				desc = "Kill an enemy with a Fading Light", --TODO controls
			},

			polearm_drill =
			{
				name = "Spinning Drill",
				desc = "Kill an enemy with a Spinning Drill", --TODO controls
			},

			polearm_multithrust =
			{
				name = "Multi-Thrust",
				desc = "Kill an enemy with a Multi-Thrust", --TODO controls
			},

			polearm_heavy_attack =
			{
				name = "Jumping Heavy",
				desc = "Kill an enemy with a Jumping Heavy", --TODO controls
			},

			polearm_single_hit =
			{
				name = "One and Done",
				desc = "Kill an enemy in a single attack", --TODO controls
			},

			polearm_drill_multiple_enemies_basic =
			{
				name = "Spinning Drill x3",
				desc = "Hit three enemies with a single Spinning Drill", --TODO controls
			},

			polearm_drill_multiple_enemies_advanced =
			{
				name = "Spinning Drill x5",
				desc = "Hit 5 enemies with a single Spinning Drill", --TODO controls
			},

			polearm_hitstreak_basic =
			{
				name = "Drill Hitstreak Basic",
				desc = "Get a Hitstreak of 15 featuring at least three Spinning Drills", --TODO controls
			},

			polearm_hitstreak_advanced =
			{
				name = "Drill Hitstreak Advanced",
				desc = "Get a Hitstreak of 30 featuring at least three Spinning Drills", --TODO controls
			},

			polearm_hitstreak_expert =
			{
				name = "Drill Hitstreak Expert",
				desc = "Get a Hitstreak of 100", --TODO
			},
		},
	},

	MONSTER_MASTERY =
	{
		CABBAGEROLL =
		{
			cabbageroll_kill =
			{
				name = "{name.cabbageroll} Kill",
				desc = "Kill a {name.cabbageroll}",
			},
			cabbageroll_kill_focus =
			{
				name = "{name.cabbageroll} Focus Kill",
				desc = "Kill a {name.cabbageroll} with a {name.concept_focus_hit}",
			},
			cabbageroll_kill_quickly =
			{
				name = "{name.cabbageroll} Quick Kill",
				desc = "Kill a {name.cabbageroll} shortly after it enters the battle",
			},
			cabbageroll_kill_flawless =
			{
				name = "{name.cabbageroll} Flawless Kill",
				desc = "Kill a {name.cabbageroll} without taking any <#RED>{name.concept_damage}</> from it",
			},
			cabbageroll_kill_onehit =
			{
				name = "{name.cabbageroll} One Hit",
				desc = "Kill a {name.cabbageroll} in a single attack",
			},
			cabbageroll_kill_lightattack =
			{
				name = "{name.cabbageroll} Light Attack",
				desc = "Kill a {name.cabbageroll} using a Light Attack",
			},
			cabbageroll_kill_heavyattack =
			{
				name = "{name.cabbageroll} Heavy Attack",
				desc = "Kill a {name.cabbageroll} using a Heavy Attack",
			},
			cabbageroll_kill_skill =
			{
				name = "{name.cabbageroll} Skill",
				desc = "Kill a {name.cabbageroll} using a Skill",
			},
		},
	},

	GEMS =
	{

		LEVEL_UP_NOTIFICATION = "%s Level Up!!!", -- %s is the new name of the gem

		ILVL_TO_NAME =
		-- usage to find suffix = ILVL_TO_NAME[gem.ilvl] returns the correct suffix
		{
			"α", --1
			"β", --2
			"γ", --3
			"Σ", --4
			"Ω", --5
		},

		PROTOTYPE_DESC_TUTORIAL = "\nSlot into a <#RED>Weapon</> at the <#RED>{name.station_gems}</>, located by {name.npc_blacksmith}.",

		damage_mod = 
		{
			-- Adds a flat damage boost
			name = "Damage Bonus {name.gem}",
			desc = "Its razor sharp edges could cause injury if not handled with care.\n\nIncreases <#RED>Weapon {name.concept_damage}</>.\n\n<#RED>{name_multiple.gem}</> can be set into <#RED>Weapons</> by {name.npc_blacksmith}.",
			--at the <#RED>{name.station_gems}</>, located near {name.npc_blacksmith}.",
			slotted_desc = "Increases <#RED>Weapon {name.concept_damage}</>.",
			stat_name = "Bonus <#RED>{name.concept_damage}</>",
		},

		-- damage_mult = 
		-- {
		-- 	-- Adds a % damage boost
		-- 	name = "Damage Percentage",
		-- 	desc = "Increase <#RED>Damage</> by a percentage.",
		-- },

		damage_crit = 
		{
			name = "Critical Damage {name.gem}",
			desc = "Fire appears trapped inside when held up to the sun.\n\nIncreases <#RED>Critical Hit {name.concept_damage}</>.\n\n<#RED>{name_multiple.gem}</> can be set into <#RED>Weapons</> by {name.npc_blacksmith}.",
			--at the <#RED>{name.station_gems}</>, located near {name.npc_blacksmith}.",
			slotted_desc = "Increases <#RED>Critical Hit {name.concept_damage}</>.",
		},

		damage_focus = 
		{
			name = "Focus Damage {name.gem}",
			desc = "Smooth to the touch. You feel calmer with it in your palm.\n\nIncreases <#BLUE>{name.concept_focus_hit}</> <#RED>{name.concept_damage}</>.\n\n<#RED>{name_multiple.gem}</> can be set into <#RED>Weapons</> by {name.npc_blacksmith}.",
			--at the <#RED>{name.station_gems}</>, located near {name.npc_blacksmith}.",
			slotted_desc = "Increases <#BLUE>{name.concept_focus_hit}</> <#RED>{name.concept_damage}</>.",
		},

		crit_chance = 
		{
			name = "Critical Chance {name.gem}",
			desc = "You can sense this {name.gem} judging you.\n\nIncreases <#RED>Critical Hit Chance</>.\n\n<#RED>{name_multiple.gem}</> can be set into <#RED>Weapons</> by {name.npc_blacksmith}.",
			--at the <#RED>{name.station_gems}</>, located near {name.npc_blacksmith}.",
			slotted_desc = "Increases <#RED>Critical Hit Chance</>.",
		},


		speed = 
		{
			name = "Runspeed {name.gem}",
			desc = "You swear lightning crackles through it out the corner of your eye.\n\nIncreases <#RED>{name.concept_runspeed}</>.\n\n<#RED>{name_multiple.gem}</> can be set into <#RED>Weapons</> by {name.npc_blacksmith}.",
			--at the <#RED>{name.station_gems}</>, located near {name.npc_blacksmith}.",
			slotted_desc = "Increases <#RED>{name.concept_runspeed}</>.",
		},

		-- sprint = 
		-- {
		-- 	name = "Sprint",
		-- 	desc = "NO POWER",
		-- },

		luck = 
		{
			name = "Luck {name.gem}",
			desc = "You're not sure how, but you get the impression this {name.gem} is smiling.\n\nIncreases <#RED>Luck</>.\n\n<#RED>{name_multiple.gem}</> can be set into <#RED>Weapons</> by {name.npc_blacksmith}.",
			--at the <#RED>{name.station_gems}</>, located near {name.npc_blacksmith}.",
			slotted_desc = "Increases <#RED>Luck</>.",
		},

		max_health = 
		{
			name = "Max Health {name.gem}",
			desc = "This thick-cut {name.gem} feels weighty in your hand.\n\nIncreases <#RED>Max Health</>.\n\n<#RED>{name_multiple.gem}</> can be set into <#RED>Weapons</> by {name.npc_blacksmith}.",
			--at the <#RED>{name.station_gems}</>, located near {name.npc_blacksmith}.",
			slotted_desc = "Increases <#RED>Max Health</>.",
		},

		bonus_damage_cabbageroll =
		{
			name = "{name.cabbageroll} Damage {name.gem}",
			desc = "it's a gem and it'll make you punch those bulbinses bettering heh dude",
			--at the <#RED>{name.station_gems}</>, located near {name.npc_blacksmith}.",
			slotted_desc = "Increases <#RED>{name.concept_damage}</> done to <#RED>{name_multiple.cabbageroll}</>.",
			stat_name = "Bonus <#RED>{name.concept_damage}</>",
		},
	},
}
