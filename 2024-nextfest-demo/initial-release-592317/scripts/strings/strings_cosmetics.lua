STRINGS.COSMETICS =
{
	--[[ 
		----TITLE WRITING NOTES----
		-Avoid articles at the beginning of a title like "The {name}"/"A {name}, or names that are long/partial sentences
		like "One Who Fights Good"-- these names won't flow well if an NPC calls you by them in casual conversation
		
		--If you're having trouble deciding if a title will grammatically fit well in gameplay, try imagining Flitt saying
		"Hey, {title}, glad you're back!" and see if it feels natural (this is specifically for testing grammar and not tone,
		as there is lots of room to play with tone)

		--Try to imagine how these titles will be used in a social setting amongst players who may or may not be friends,
		and consider if a title could be misused or come across as meanspirited

		--While not always strictly necessary, try to provide a femme, masc and neutral option for titles that are gendered
		(ie, if the title is a general concept like "Queen" then we should have "King" and "Royalty/Monarch" options available,
		but if the title is a specifically gendered colloquialism like "Drama Queen", gender options might be fun but are 
		not required-- use your best judgment per situation)
		--------------------------

		--!Important!
		--These strings are made into titles by creating definitions in data/scripts/defs/cosmetics/batchtitles.lua
		  Writing a title's strings won't automatically put it into the game without the associated batchtitles.lua entry
	]]

	TITLES = 
	{
		TESTSTRING = "CABBAGE MASTER",
		--All players will have the title "Hunter" assigned by default
		DEFAULT_TITLE= "Hunter",

		--MISC/UNASSIGNED (ones with gender variations should unlock together)
			BUCKAROO = "Buckaroo",
			ACE = "Ace",
			PAWBEANS = "Paw Beans",
			HIGHQUEEN = "High Queen",
			HIGHKING = "High King",
			HIGHROYALTY = "High Royalty",
			GOOFYGOOBER = "Goofy Goober",
			SHREDDER = "Shredder",
			CREEPYCRYPTID = "Creepy Cryptid",
			TEAMMASCOT = "Team Mascot", --could be fun for someone who does the lowest damage on their team or something
			POCKETMEDIC = "Pocket Medic",
			GLASSCANNON = "Glass Cannon", --should probably unlock from a cannon mastery lol
			TANK = "Tank",
			FASHIONISTA = "Fashionista", --maybe from crafting a certain number of armour pieces?
			JOKESCLOWN = "Jokes Clown",
			MYSTERIOUSSTRANGER = "Mysterious Stranger",
			CHICKENCHASER = "Chicken Chaser",
			IMPOSTOR = "Impostor",

		--TOOT'S TUTORIALS COMPLETIONS
			TEACHERSPET = "Teacher's Pet",
			HUNTERPHD = "Hunter, PhD",

		--HAMMER
			ALBATROSS = "Albatross", --golf swing (golf related term)
		
		--POLEARM
			DRILLSERGEANT = "Drill Sergeant", --advanced drill

		--CANNON
			BOOMER = "Boomer",

		--STRIKER
			JUGGLER = "Juggler",

		--GENERAL_WEAPON
			BATTLEMASTER = "Battlemaster", --titles for a mastery of all weapons

		--TREEMON_FOREST
			LILBUDDY = "Lil' Buddy", --cabbage roll title
			BEETMASTER = "Beetmaster", --beets mastery
			PIEMASTER = "Piemaster", --kill a zucco, yammo and a gourdo
			TREEHUGGER = "Treehugger", --treemon mastery
			FORESTKEEPER = "Forest Keeper", --megatreemon mastery

		--OWLITZER_FOREST
			STINKY = "Stinky", --gnarlic mastery
			NIGHTSHROUD = "Nightshroud", --owlitzer mastery

		--BANDICOOT_SWAMP
			PRIMABALLERINA = "Prima Ballerina", --floracrane mastery
			WATCHER = "Watcher", --eyev mastery
			MADTRICKSTER = "Mad Trickster", --bandicoot mastery

		--THATCHER_SWAMP
			CHUBBSTER = "Chubbster", --slowpoke mastery
			WOWORM = "Lil' Slime", --woworm mastery
	},
}