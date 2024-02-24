-- Tune the worldmap generation for each biome.
--
-- See worldmap.lua for mapgen algorithm.
-- See biomes.lua for biome definitions.

local Enum = require "util.enum"
local kassert = require "util.kassert"
local lume = require "util.lume"
local Equipment = require "defs.equipment"
require "util"
require "util.tableutil"

local Difficulty = Enum{
	'easy',
	'medium',
	'hard',
}

local Reward = Enum{
	'none',
	'coin',        -- konjur
	'plain',       -- player power
	'small_token', -- normal crafting mat
	'skill',       -- player power
	'fabled',      -- weapon power
	'big_token',   -- rare crafting mat
}
local max_reward_per_difficulty = {
	[Difficulty.id.easy] = Reward.id.plain,
	[Difficulty.id.medium] = Reward.id.skill,
}

local EnemyRoom = Enum{
	-- Assumption: These rooms all drop rewards.
	"boss",
	"miniboss",
	"monster", -- basic monster fight
}
local TrivialRoom = Enum{
	"empty",
	"food",
	"hype",
	"potion",
	"powerupgrade",
	"resource",
	"market",

	"mystery", -- a mystery room can be any room, but is typically a Wanderer or Ranger room
	"wanderer", -- these rooms are not typically placed into a dungeon specifically, just appear via a mystery
	"ranger", -- these rooms are not typically placed into a dungeon specifically, just appear via a mystery

	"insert",  -- these rooms are not typically placed into a dungeon specifically, just appear via a quest system
	"quest", -- rooms with quest content (only picked when quest system has something)
	"entrance", -- the first room of the dungeon
}
local RoomType = Enum(table.appendarrays({}, EnemyRoom:Ordered(), TrivialRoom:Ordered()))


-- Here's the format of a mapgen "biome":  {{{1
--   demo = {
--   	forbidden_keys = { "wf_blah" }, <-- If this forbidden_key is unlocked by the world, this mapgen will not be selected.
--   	enforce_difficulty_ramp = true, <-- Optional, defaults to false.
--   	branchdist = {
--			-- [number of exits] = weight, <-- Controls how frequently we choose each number of exits.
--   		[1] = 3,  <-- Most of the time, we have just one exit to avoid too much branching.
--   		[2] = 2,
--   		[3] = 1,
--   	},
--   	intro_rooms = 3, <-- initial rooms that always have 1 exit (incl. entrance)
--   	dimensions = {
--   		short = 7, <-- vertical spread in the dungeon (allows for more branching, but save data is more complex)
--   	},
--   	room_distribution = {
--			Each key is a range of depths where 1 is the first room after the
--			entrance. Advancing through a dungeon is always going deeper (you
--			never move to a new room that's the same depth as the current
--			room).
--
--			Here we specify one setup for the first 11 rooms.
--   		['1-11'] = {
--   			-- Use weights to specify probability for each choice.
--
--   			-- RoomType enum
--   			roomtype = {
--   				monster = 9,  <-- 9 in 10 chance of monster, but repeated choices are less likley
--   				potion = 1,
--   			},
--
--   			-- Reward enum
--   			reward = {
--   				coin = 4,     <-- Like above, 4 in 5 chance of coin.
--   				fabled = 1,
--   			},
--
--   			-- Difficulty enum
--   			difficulty_distribution = {
--   				Difficulty primarily determines which encounter we select
--   				in encounters.lua. It also affects how much loot is
--   				dropped, power selection, limits on reward tier, etc.
--
--   				easy = 1,     <-- Like above 1 in 3 chance. If enforce_difficulty_ramp is enabled,
--   				medium = 1,   <-- then medium can't appear before easy.
--   				hard = 1,
--   			},
--   		},
--
--   		Special behaviour only at depth 11.
--   		['11-11'] = {
--   			force_all_roomtypes = true,  <-- Give player choice of all specified roomtypes.
--   			roomtype = {
--   				monster = 1,
--   				potion = 1,
--   				powerupgrade = 1,
--   			},
--   			reward = {
--   				fabled = 1,
--   			},
--   			difficulty_distribution = {
--   				hard = 1,
--   			},
--				join_all_branches = true, -- All previous depths converge on one room.
--   		},
--
--   		['12-12'] = {
--   			Always include rooms without force between force_all_* rooms to
--   			merge branches back together and avoid excessive sprawl.
--   			...
--   		},
--
--   		Special behaviour only at depth 11.
--   		['13-13'] = {
--   			force_all_rewards = true,  <-- Give player choice of all specified rewards.
--   			roomtype = {
--   				monster = 1,  <-- For force_all_rewards, we must use a roomtype that drops rewards.
--   			},
--   			reward = {
--   				fabled = 1,
--   				small_token = 1,
--   			},
--   			difficulty_distribution = {
--   				hard = 1,
--   			},
--   			forced_encounter = "tutorial1", <-- Always use this encounter from encounters.lua
--   		},
--
--   		This last entry in room_distribution determines the length of the dungeon:
--   		start + room_distribution + hype/boss = 1 + 15 + 1 = 17 rooms
--   		(We count hype and boss as if they were a single room.)
--   		['14-15'] = {
--   			roomtype = {
--   				monster = 10,
--   				mystery = 1,
--   				quest = 1, <-- If questroom available (see AppearInDungeon_QuestRoom), it's *always* picked and the only exit...
--   			},
--   			allow_optional_quest = true, <-- ...except when this flag *allows* other exits alongside questrooms.
--   			reward = {
--   				coin = 1,
--   				small_token = 1,
--   			},
--   			difficulty_distribution = {
--   				hard = 1,
--   			},
--   		},
--   	},
--
--   	Limits on roomtype and reward selection. These values are all counts
--   	(not weights).
--   	roomlimit = {
--			Hard limit how many of this room are offered to the player. These
--			are counts, not weights. force_all_roomtypes/force_all_rewards
--			ignores these limits.
--   		max_seen = {
--   			potion = 3,  <-- We'll stop offering potion after the player had 3 exits for potion.
--   		},
--
--			Hard limit how many times a player can visit this room.
--			force_all_roomtypes/force_all_rewards ignores these limits.
--			max_visited = {
--   			quest = 1,  <-- Maximum one quest room per run.
--   		},
--
--   		Severely reduce likelihood room will be seen again until player
--   		enters/visits this many rooms.
--   		snooze_depth = {
--   			mystery = 2,  <-- Don't see another mystery until player's entered 2 more rooms.
--   		},
--
--   		Severely reduce likelihood room will be seen again until player's seen
--   		this many options (seen, not entered so this snooze ticks down
--   		faster when player gets 3 exits).
--   		snooze_seen = {
--   			potion = 4,  <-- Don't see another potion until we've revealed 4 more rooms.
--   		},
--   	},
--   },
-- }}}1



local mapgen = {
	roomtypes = {
		RoomType = RoomType, -- all valid roomtypes

		-- Subsets of RoomType.
		Enemy = EnemyRoom,
		Trivial = TrivialRoom,
	},
	Cardinal = Enum{ "north", "east", "south", "west", },
	Difficulty = Difficulty, -- Difficulty.id maps difficulty name to value. 1 is easiest.
	max_difficulty = #Difficulty:Ordered(),
	Reward = Reward, -- Reward.id maps reward name to value. 1 is least powerful.
	max_reward = #Reward:Ordered(),
	max_reward_per_difficulty = max_reward_per_difficulty,
	biomes = {

		treemon_forest = {
			branchdist = {
				[1] = 3,
				[2] = 2, --JAMBELL: possibly, increase to increase likelihood of 2-branches
				[3] = 1,
			},
			dimensions = {
				short = 7,
			},
			room_distribution = {
				['1-1'] = {
					-- Start with an easy room
					roomtype = {
						monster = 1,
					},
					reward = {
						coin = 1,
						plain = 1,
					},
					difficulty_distribution = {
						easy = 1,
					},
				},
				['2-2'] = {
					-- Add a possibility for a Medium Room, and an early corestone.
					roomtype = {
						monster = 1,
					},
					reward = {
						coin = 1,
						plain = 1,
						small_token = 1
					},
					difficulty_distribution = {
						easy = 3,
						medium = 1,
					},
				},
				['3-3'] = {
					roomtype = {
						monster = 1,
					},
					reward = {
						coin = 1,
						plain = 1,
					},
					difficulty_distribution = {
						medium = 1,
					},
				},
				-- Add a possibility of a special event room. If it doesn't show up here, it will show up either a few before the miniboss or in the second half. Or both!
				['4-5'] = {
					roomtype = {
						monster = 25000,
						mystery = 1,
					},
					reward = {
						coin = 10,
						plain = 10,
						small_token = 1,
					},
					difficulty_distribution = {
						easy = 4,
						medium = 10,
					},
				},
				['6-6'] = {
					roomtype = {
						monster = 1000,
						mystery = 1,
						quest = 1,
						powerupgrade = 5,
					},
					reward = {
						coin = 10,
						plain = 10,
						small_token = 1,
					},
					difficulty_distribution = {
						easy = 4,
						medium = 10,
					},
				},
				['7-7'] = {
					-- High likelihood of potion before miniboss.
					roomtype = {
						monster = 1,
						potion = 10,
						market = 10,
					},
					force_all_roomtypes = true,
					reward = {
						plain = 1,
					},
					difficulty_distribution = {
						easy = 3,
						medium = 2,
					},
				},
				['8-8'] = {
					-- Miniboss at halfway point.
					roomtype = {
						miniboss = 1,
					},
					reward = {
						fabled = 1,
					},
					difficulty_distribution = {
						hard = 1, -- This needs to be set to hard in order for the miniboss to drop a fabled relic.
					},
					join_all_branches = true, -- Only show a single miniboss.
				},
				['9-9'] = {
					--  Give a small token.
					roomtype = {
						monster = 1,
						powerupgrade = 10
					},
					reward = {
						small_token = 1, -- higher chance of soul after miniboss
						plain = 0.001, -- in case we get easy
					},
					difficulty_distribution = {
						easy = 2,
						medium = 10,
						hard = 5,
					},
				},
				['10-11'] = {
					roomtype = {
						monster = 10,
						potion = 5,
						powerupgrade = 5,
						mystery = 1,
					},
					reward = {
						coin = 1,
						plain = 1,
						fabled = 1,
					},
					difficulty_distribution = {
						easy = 1,
						medium = 10,
						hard = 5,
					},
				},
				['12-14'] = {
					roomtype = {
						monster = 10,
						mystery = 1,
						quest = 1,
					},
					reward = {
						coin = 100,
						plain = 200,
						fabled = 200,
						small_token = 10, -- small_token = 100, -- Removing this because snooze don't work with these rewards, so them being this likely means we get flooded.
					},
					difficulty_distribution = {
						medium = 10,
						hard = 10,
					},
				},
				['15-15'] = {
					-- Choice before boss.
					force_all_roomtypes = true,
					roomtype = {
						powerupgrade = 1,
						potion = 1,
						market = 1,
					},
					reward = {
						fabled = 1,
					},
					difficulty_distribution = {
						hard = 1,
					},
				},
			},
			roomlimit = {
				max_seen = {
					-- Plus any from force_all_roomtypes.
					potion = 3,
					resource = 1,
					powerupgrade = 3,
					mystery = 4,
				},
				max_visited = {
					-- Plus any from force_all_roomtypes.
					quest = 1,
				},
				-- Room will not be seen again until we enter this many rooms.
				snooze_depth = {
					potion = 3,
					resource = 2,
					powerupgrade = 3,
					mystery = 2,
					small_token = 3,
				},
				-- Room will not be seen again until we've seen this many
				-- options (seen, not entered).
				snooze_seen = {
					potion = 4,
					resource = 3,
					powerupgrade = 4,
					mystery = 2,
					small_token = 4,
				},
			},
		},

		treemon_forest_tutorial1 = {
			forbidden_keys = { "wf_first_miniboss_seen" },
			enforce_difficulty_ramp = true, -- optional, defaults to false
			branchdist = {
				[1] = 3,
				[2] = 2, --JAMBELL: possibly, increase to increase likelihood of 2-branches
				[3] = 0,
			},
			dimensions = {
				short = 7,
			},
			room_distribution = {
				['1-1'] = {
					-- First time player encounters combat.
					roomtype = {
						monster = 1,
					},
					reward = {
						plain = 1,
					},
					difficulty_distribution = {
						easy = 1, --This difficulty affects how much loot is dropped.
					},
					forced_encounter = "tutorial1",
				},
				['2-2'] = {
					-- First two are always easy monster rooms.
					roomtype = {
						monster = 1,
					},
					reward = {
						plain = 1,
					},
					difficulty_distribution = {
						easy = 1, --This difficulty affects how much loot is dropped.
					},
					forced_encounter = "tutorial2",
				},
				['3-3'] = {
					-- Give them an option to branch out and give some player choice, even if it doesn't amount to much in this. Nothing to spend Konjur on.
					force_all_rewards = true,
					roomtype = {
						monster = 1,
					},
					reward = {
						plain = 1,
						coin = 1,
					},
					difficulty_distribution = {
						easy = 1, --This difficulty affects how much loot is dropped.
					},
					forced_encounter = "tutorial3",
				},
				['4-4'] = {
					roomtype = {
						monster = 1,
					},
					reward = {
						small_token = 1,
					},
					difficulty_distribution = {
						hard = 1, --This difficulty affects how much loot is dropped.
					},
					forced_encounter = "tutorial4",
				},
				['5-5'] = {
					-- Guarantee a potion before the miniboss in the tutorial.
					roomtype = {
						quest = 1,
						potion = 1
					},
					reward = {
						plain = 1, --ignored
					},
					difficulty_distribution = {
						easy = 1, --ignored
					},
				},
				['6-6'] = {
					-- Miniboss is a bit earlier than other mapgens.
					roomtype = {
						miniboss = 1,
					},
					reward = {
						fabled = 1,
					},
					difficulty_distribution = {
						hard = 1, -- This needs to be set to hard in order for the miniboss to drop a fabled relic.
					},
					join_all_branches = true, -- Only show a single miniboss.
				},
				-- Once a player beats this room, once they die they are into TUTORIAL2.
				['7-7'] = {
					-- In the tutorial, guarantee a small token after the miniboss
					roomtype = {
						monster = 1,
					},
					reward = {
						small_token = 1,
					},
					difficulty_distribution = {
						hard = 1, -- Hard room to provide challenge and pressure back towards the town -- this room will only be hard in THIS mapgen... if they die here they go to tutorial2 where this is easier.
								  -- Tuning note: this may be too difficult! If they go "UGH THIS GAME IS HARD! NO WAY I CAN DO THAT" then this should be bumped down to medium.
								  -- Try it out and see.
					},
				},

				-- The above mapgen is what most new players will spend their first few runs in.
				-- From this point on, if a player gets here on their first run, they're doing QUITE well.
				-- So I'm going to crank up the difficulty a little bit to apply some pressure to start the Town Loop.
				-- Apply that pressure to make it more likely that the player gets sent back to town.

				['8-11'] = {
					roomtype = {
						monster = 10,
						mystery = 1,
					},
					reward = {
						plain = 1,
						fabled = 1,
					},
					difficulty_distribution = {
						medium = 2,
						hard = 5,
					},
				},
				['12-14'] = {
					roomtype = {
						monster = 10,
						mystery = 1,
					},
					reward = {
						coin = 1,
						small_token = 1,
					},
					difficulty_distribution = {
						hard = 1,
					},
				},
				['15-15'] = {
					-- Choice before boss.
					force_all_roomtypes = true,
					roomtype = {
						powerupgrade = 1,
						potion = 1,
						market = 1,
					},
					reward = {
						fabled = 1,
					},
					difficulty_distribution = {
						hard = 1,
					},
				},
			},
			roomlimit = {
				max_seen = {
					potion = 3,
					resource = 1,
					powerupgrade = 3,
					mystery = 4,
				},
				max_visited = {
					quest = 1,
				},
				snooze_depth = {
					potion = 3,
					resource = 2,
					powerupgrade = 3,
					mystery = 2,
				},
				snooze_seen = {
					potion = 4,
					resource = 3,
					powerupgrade = 4,
					mystery = 2,
				},
			},
		},

		treemon_forest_tutorial2 = {
			-- DEC2023:
			-- This is after you've seen the miniboss, but before you've defeated it.
			-- It's important to get an early corestone source, as well as a choice of market.
			-- If they're having trouble beating the miniboss, then they should be buying armour and upgrading it with Berna until they clear the boss.

			-- NOTE: they will definitely have an Entrance room Power at this point.

			-- Once we defeat the miniboss, we move onto Tutorial3.

			-- The goal for this tutorial is to get them to:
			-- 		Get a corestone
			--		Have enough konjur to upgrade a power,
			--		While still having enough left to buy stuff from the market.

			-- Breaks out of this once they've seen the market.

			forbidden_keys = { "wf_seen_npc_market_merchant", },
			branchdist = {
				[1] = 3,
				[2] = 2, --JAMBELL: possibly, increase to increase likelihood of 2-branches
				[3] = 1,
			},
			intro_rooms = 1,
			dimensions = {
				short = 7,
			},
			forced_market =
			{
				META_MARKET =
				{
					ARMOUR =
					{
						-- Force an actual helpful choice until they've killed the miniboss.
						[Equipment.Slots.HEAD] = "basic",
						[Equipment.Slots.BODY] = "blarmadillo",
						[Equipment.Slots.WAIST] = "yammo",
					},
				},
			},
			room_distribution = {
				['1-2'] = {
					-- First two are always easy monster rooms, with a possible power.
					roomtype = {
						monster = 1,
					},
					reward = {
						plain = 1,
					},
					difficulty_distribution = {
						easy = 1,
					},
				},
				['3-3'] = {
					-- Bump up to Medium, with a guaranteed choice of power.
					force_all_rewards = true,
					roomtype = {
						monster = 1,
					},
					reward = {
						plain = 1,
						coin = 1,
					},
					difficulty_distribution = {
						medium = 1,
					},
				},
				-- Give them a power upgrade room to try upgrading!
				['4-4'] = {
					roomtype = {
						powerupgrade = 1,
						quest = 1,
					},
					reward = {
						coin = 1,
					},
					difficulty_distribution = {
						easy = 1,
					},
				},
				['5-5'] = {
					-- Give them a corestone so they can use it in the market in the next room.
					roomtype = {
						monster = 1,
					},
					reward = {
						small_token = 1,
					},
					difficulty_distribution = {
						medium = 1,
					},
				},
				['6-6'] = {
					-- Guarantee a market before the miniboss in tutorial2. Let them meet Alphonse and probably get a piece of armour.
					roomtype = {
						market = 1,
					},
					reward = {
						plain = 1,
					},
					difficulty_distribution = {
						easy = 1,
					},
				},
				['7-7'] = {
					-- Miniboss still a bit earlier
					roomtype = {
						miniboss = 1,
					},
					reward = {
						fabled = 1,
					},
					difficulty_distribution = {
						hard = 1, -- This needs to be set to hard in order for the miniboss to drop a fabled relic.
					},
					join_all_branches = true, -- Only show a single miniboss.
				},
				['8-8'] = {
					-- in the tutorial, guarantee a small token after the miniboss (after this is grabbed, this mapgen is turned off)
					roomtype = {
						monster = 1,
					},
					reward = {
						small_token = 1,
					},
					difficulty_distribution = {
						medium = 1,
					},
				},
				-- TUTORIAL MAPGEN ENDS FOR NOW:
				-- From here on out, it is equivalent to a normal mapgen:
				['9-11'] = {
					roomtype = {
						monster = 10,
						potion = 5,
						powerupgrade = 5,
						mystery = 1,
						quest = 1,
						market = 1,
					},
					reward = {
						coin = 1,
						plain = 1,
						fabled = 1,
					},
					difficulty_distribution = {
						easy = 1,
						medium = 10,
						hard = 5,
					},
				},
				['12-14'] = {
					roomtype = {
						monster = 10,
						mystery = 1,
					},
					reward = {
						coin = 1,
						plain = 2,
						fabled = 2,
					},
					difficulty_distribution = {
						medium = 10,
						hard = 10,
					},
				},
				['15-15'] = {
					-- Choice before boss.
					force_all_roomtypes = true,
					roomtype = {
						powerupgrade = 1,
						potion = 1,
						market = 1,
					},
					reward = {
						fabled = 1,
					},
					difficulty_distribution = {
						hard = 1,
					},
				},
			},
			roomlimit = {
				max_seen = {
					potion = 3,
					resource = 1,
					powerupgrade = 3,
					mystery = 4,
					market = 1,
				},
				max_visited = {
					quest = 1,
				},
				snooze_depth = {
					potion = 3,
					resource = 2,
					powerupgrade = 3,
					mystery = 2,
				},
				snooze_seen = {
					potion = 4,
					resource = 3,
					powerupgrade = 4,
					mystery = 2,
				},
			},
		},
		treemon_forest_tutorial3 = {
			-- This tutorial is live after you have seen the market, up until you have beaten the miniboss for the first time
			-- This is to introduce ? Rooms, give more small_tokens, and slowly start to introduce more difficulty.

			-- They are building up gear to beat miniboss at this point.

			forbidden_keys = { "wf_first_miniboss_defeated" },
			branchdist = {
				[1] = 3,
				[2] = 3, --JAMBELL: possibly, increase to increase likelihood of 2-branches
				[3] = 1,
			},
			dimensions = {
				short = 7,
			},
			forced_market =
			{
				META_MARKET =
				{
					ARMOUR =
					{
						-- Force an actual helpful choice until they've killed the miniboss.
						[Equipment.Slots.HEAD] = "basic",
						[Equipment.Slots.BODY] = "blarmadillo",
						[Equipment.Slots.WAIST] = "yammo",
					},
				},
			},
			room_distribution = {
				['1-1'] = {
					roomtype = {
						monster = 1,
					},
					reward = {
						coin = 1,
						plain = 1,
					},
					difficulty_distribution = {
						easy = 1,
					},
				},
				['2-2'] = {
					-- Add a possibility for a Medium Room, and an early corestone.
					force_all_rewards = true,
					roomtype = {
						monster = 1,
					},
					reward = {
						coin = 1,
						plain = 1,
						small_token = 1
					},
					difficulty_distribution = {
						easy = 3,
						medium = 1,
					},
				},
				['3-3'] = {
					-- Bump up to Medium, with a guaranteed choice of power.
					roomtype = {
						monster = 1,
					},
					reward = {
						coin = 1,
						plain = 1,
					},
					difficulty_distribution = {
						medium = 1,
					},
				},
				['4-4'] = {
					-- Give a guaranteed MEDIUM COIN reward to fill them up
					-- with konjur to upgrade the power they got, coming up.
					-- They have one power from Start Room, and at least one
					-- from above. Maybe two.
					roomtype = {
						monster = 1,
					},
					reward = {
						small_token = 5,
						coin = 3,
						plain = 1,
					},
					difficulty_distribution = {
						medium = 1,
					},
				},
				['5-5'] = {
					roomtype = {
						monster = 1,
						mystery = 1,
					},
					reward = {
						coin = 1,
						plain = 1,
						small_token = 2,
					},
					difficulty_distribution = {
						easy = 1,
					},
				},
				['6-6'] = {
					-- Give them a corestone so they can use it in the market in the next room, or let them choose to get more Konjur for the market.
					roomtype = {
						monster = 1,
						quest = 1,
					},
					reward = {
						coin = 1,
						plain = 1,
					},
					difficulty_distribution = {
						easy = 5,
						medium = 1,
					},
				},
				['7-7'] = {
					-- Guarantee a market before the miniboss so they can spend corestones if they got them.
					-- Give them a choice of potion instead, if they want to focus Run Power instead of Meta Power.
					roomtype = {
						potion = 1,
						market = 1,
						powerupgrade = 1,
					},
					force_all_roomtypes = true,
					reward = {
						plain = 1,
					},
					difficulty_distribution = {
						medium = 1,
					},
				},
				['8-8'] = {
					-- Miniboss at halfway point.
					roomtype = {
						miniboss = 1,
					},
					reward = {
						fabled = 1,
					},
					difficulty_distribution = {
						hard = 1, -- This needs to be set to hard in order for the miniboss to drop a fabled relic.
					},
					join_all_branches = true, -- Only show a single miniboss.
				},
				['9-9'] = {
					-- in the tutorial, guarantee a small token after the miniboss (after this is grabbed, this mapgen is turned off)
					roomtype = {
						monster = 1,
					},
					reward = {
						small_token = 1,
					},
					difficulty_distribution = {
						medium = 1,
					},
				},
				-- TUTORIAL MAPGEN ENDS FOR NOW:
				-- From here on out, it is equivalent to a normal mapgen:
				['10-11'] = {
					roomtype = {
						monster = 10,
						potion = 5,
						powerupgrade = 5,
						mystery = 1, -- Add mystery into the mix
					},
					reward = {
						coin = 1,
						plain = 1,
						fabled = 1,
					},
					difficulty_distribution = {
						easy = 1,
						medium = 10,
						hard = 5,
					},
				},
				-- Introduce small tokens to the mix randomly
				['12-14'] = {
					roomtype = {
						monster = 10,
						mystery = 1,
						market = 1,
					},
					reward = {
						coin = 100,
						plain = 200,
						fabled = 200,
						small_token = 50,
					},
					difficulty_distribution = {
						medium = 10,
						hard = 10,
					},
				},
				['15-15'] = {
					-- Choice before boss.
					force_all_roomtypes = true,
					roomtype = {
						powerupgrade = 1,
						potion = 1,
					},
					reward = {
						fabled = 1,
					},
					difficulty_distribution = {
						hard = 1,
					},
				},
			},
			roomlimit = {
				max_seen = {
					potion = 3,
					resource = 1,
					powerupgrade = 3,
					mystery = 4,
					market = 1,
				},
				max_visited = {
					quest = 1,
				},
				snooze_depth = {
					potion = 3,
					resource = 2,
					powerupgrade = 3,
					mystery = 2,
				},
				snooze_seen = {
					potion = 4,
					resource = 3,
					powerupgrade = 4,
					mystery = 2,
				},
			},
		},
	},
}

mapgen.biomes.treemon_forest_hard = deepcopy(mapgen.biomes.treemon_forest)
mapgen.biomes.treemon_forest_hard.required_ascension = 1

-- Reduce likelihood of easy rooms early on. Give a more interesting start.
mapgen.biomes.treemon_forest_hard.room_distribution['1-1'].difficulty_distribution.medium = 2
mapgen.biomes.treemon_forest_hard.room_distribution['2-2'].difficulty_distribution.easy = 1

-- Add a Fabled power early on, to let builds get Online sooner
mapgen.biomes.treemon_forest_hard.room_distribution['3-3'].reward.fabled = 10
mapgen.biomes.treemon_forest_hard.room_distribution['3-3'].difficulty_distribution.hard = 2
mapgen.biomes.treemon_forest_hard.room_distribution['3-3'].force_all_rewards = true

-- Remove Easy Rooms and add chance of Hard Rooms now that they have a fabled power. Keep challenge consistent.
mapgen.biomes.treemon_forest_hard.room_distribution['4-5'].difficulty_distribution.easy = 0
mapgen.biomes.treemon_forest_hard.room_distribution['4-5'].difficulty_distribution.hard = 2 -- medium is @ 10 as of writing
mapgen.biomes.treemon_forest_hard.room_distribution['6-6'].difficulty_distribution.easy = 0
mapgen.biomes.treemon_forest_hard.room_distribution['6-6'].difficulty_distribution.hard = 2 -- medium is @ 10 as of writing

--[[

	-- ALL MYSTERIES:
		treemon_forest_tutorial1 = {
			forbidden_keys = { "wf_town_has_armorsmith" },
			enforce_difficulty_ramp = true, -- optional, defaults to false
			branchdist = {
				[1] = 3,
				[2] = 2, --JAMBELL: possibly, increase to increase likelihood of 2-branches
				[3] = 1,
			},
			intro_rooms = 3,
			dimensions = {
				short = 7,
			},
			room_distribution = {
				['1-15'] = {
					-- First time player encounters combat.
					roomtype = {
						mystery = 1,
					},
					reward = {
						coin = 1,
					},
					difficulty_distribution = {
						easy = 1, --This difficulty affects how much loot is dropped.
					},
				},
			},
			roomlimit = {
				max_seen = {
					potion = 3,
					resource = 1,
					powerupgrade = 3,
				},
				max_visited = {
					quest = 1,
				},
				snooze_depth = {
					potion = 3,
					resource = 2,
					powerupgrade = 3,
					mystery = 0,
				},
				snooze_seen = {
					potion = 4,
					resource = 3,
					powerupgrade = 4,
					mystery = 0,
				},
			},
		},
]]


mapgen.cheat = {}

function mapgen.cheat.no_monster()
	print("[WorldGen] Cheat: Replaced monster with trivial rooms for an easy dungeon testing. May cause errors.")
	-- TODO: Why does this barf?
	local no_combat = lume(TrivialRoom:Ordered())
		:removeswap(function(v, i, j)
			return v == RoomType.s.hype
				or v == RoomType.s.insert
				or v == RoomType.s.entrance
				or v == RoomType.s.quest
		end)
		:result()
	for biome_id,def in pairs(mapgen.biomes) do
		for _,roomtype in ipairs(TrivialRoom:Ordered()) do
			def.roomlimit.max_seen[roomtype] = nil
			def.roomlimit.max_visited[roomtype] = nil
		end
		def.roomlimit.snooze_depth.mystery = 1
		def.roomlimit.snooze_seen.mystery = 2
		for i,dist in ipairs(def.roomdist) do
			if dist.roomtype.boss > 0
				or dist.roomtype.miniboss > 0
			then
				break
			end
			if dist.roomtype.monster > 0 then
				dist.roomtype.monster = 0
				dist.reward.coin = 1
				for _,val in ipairs(no_combat) do
					dist.roomtype[val] = 1
				end
			end
		end
	end
end

local function many_trivial(roomtype)
	assert(TrivialRoom:Contains(roomtype))
	TheLog.ch.WorldMap:printf("Cheat: Added %s to all room distribution. May cause errors.", roomtype)
	-- Add lots of potion rooms for easier potion testing.
	for biome_id,def in pairs(mapgen.biomes) do
		def.roomlimit.max_seen[roomtype] = nil
		-- Snooze so we're alternating.
		def.roomlimit.snooze_depth[roomtype] = 2
		-- Need this or get nil rewards during worldgen!?
		def.roomlimit.snooze_seen[roomtype] = 2
		for i,dist in ipairs(def.roomdist) do
			if dist.roomtype.monster > 0 then
				dist.roomtype[roomtype] = 10000
			end
		end
	end
end


function mapgen.cheat.many_mystery()
	return many_trivial(TrivialRoom.s.mystery)
end

function mapgen.cheat.many_potion()
	return many_trivial(TrivialRoom.s.potion)
end


mapgen.validate = {}

function mapgen.validate.has_all_difficulty_keys(t, msg, ...)
	msg = msg or "Missing difficulty '%s'."
	for key in pairs(mapgen.Difficulty.s) do
		kassert.assert_fmt(t[key], msg, key, ...)
	end
end

function mapgen.validate.all_keys_are_difficulty(t, msg, ...)
	msg = msg or "Invalid difficulty '%s'."
	for key in pairs(t) do
		kassert.assert_fmt(mapgen.Difficulty:Contains(key), msg, key, ...)
	end
end

function mapgen.validate.all_keys_are_roomtype(t, msg, ...)
	msg = msg or "Invalid roomtype '%s'."
	for key in pairs(t) do
		kassert.assert_fmt(RoomType:Contains(key), msg, key, ...)
	end
end

for biome_id,def in pairs(mapgen.biomes) do
	def.roomdist = {}
	def.intro_rooms = def.intro_rooms or 0
	-- Vars for validation
	local dist_count = 0
	local edges = { first = {}, last = {}, }
	--
	for depth_range,dist in pairs(def.room_distribution) do
		local first,last = depth_range:match("^(%d+)-(%d+)$")
		local first_num <const> = tonumber(first)
		local last_num <const> = tonumber(last)
		kassert.assert_fmt(not edges.first[first] and not edges.last[first], "Invalid room_distribution: %d in '%s' overlaps with another range.", first, depth_range)
		kassert.assert_fmt(not edges.first[last] and not edges.last[last], "Invalid room_distribution: %d in '%s' overlaps with another range.", last, depth_range)
		edges.first[first] = true
		edges.first[last] = true
		for i=first_num,last_num do
			dist_count = dist_count + 1
			def.roomdist[i] = dist
		end

		for r in pairs(dist.roomtype) do
			kassert.assert_fmt(RoomType:Contains(r), "Invalid roomtype '%s' in biome '%s'.", r, biome_id)
		end
		if dist.force_all_roomtypes then
			kassert.assert_fmt(last_num > def.intro_rooms, "intro_rooms forces a single exit on the first %i rooms, so those rooms can't use force_all_roomtypes. See depth '%s' in biome '%s'.", def.intro_rooms, depth_range, biome_id)
			dist.roomtype_count = lume.count(dist.roomtype)
			if dist.roomtype.quest then
				-- Quests negate force_all, so don't count them.
				dist.roomtype_count = dist.roomtype_count - 1
			end
			kassert.assert_fmt(dist.roomtype_count <= 3, "Too many roomtypes for force_all_roomtypes in room_distribution for depth '%s' in biome '%s'. Can only have one per exit.", depth_range, biome_id)
		end
		if dist.force_all_rewards then
			kassert.assert_fmt(last_num > def.intro_rooms, "intro_rooms forces a single exit on the first %i rooms, so those rooms can't use force_all_rewards. See depth '%s' in biome '%s'.", def.intro_rooms, depth_range, biome_id)
			assert(not dist.force_all_roomtypes, "Cannot combine force_all_rewards and force_all_roomtypes in the same depth.")
			dist.reward_count = lume.count(dist.reward)
			kassert.assert_fmt(dist.reward_count <= 3, "Too many rewards for force_all_rewards in room_distribution for depth '%s' in biome '%s'. Can only have one per exit.", depth_range, biome_id)
			for r in pairs(dist.roomtype) do
				kassert.assert_fmt(EnemyRoom:Contains(r)
					-- Mandatory quests ignore force_all_rewards when picked.
					or (r == RoomType.s.quest and not dist.allow_optional_quest),
					"All rooms must drop rewards to use force_all_rewards for depth '%s' in biome '%s'. Can only have one per exit.",
					depth_range, biome_id)
			end
		end

		if dist.roomtype.miniboss then
			-- We don't iterate in order, so use min.
			def.first_miniboss_depth = math.min(first_num, def.first_miniboss_depth or math.huge)
		end

		if dist.roomtype.quest then
			kassert.assert_fmt(lume.count(dist.roomtype) > 1, "Rooms %s in biome '%s' using quest require other roomtype options. Quest rooms are only chosen when there's a quest is available, so we need a fallback roomtype.", depth_range, biome_id)
			kassert.assert_fmt(dist.roomtype.quest == 1, "Quest rooms are always selected when available so probability is ignored. Always set to 1. See rooms %s in biome '%s'.", depth_range, biome_id)
			kassert.assert_fmt(not dist.force_all_roomtypes or not dist.allow_optional_quest, "Don't use force_all_roomtypes with optional quest rooms because we might not have a quest (you'll get an empty room). See rooms %s in biome '%s'.", depth_range, biome_id)
		else
			kassert.assert_fmt(not dist.allow_optional_quest, "No quest room for allow_optional_quest. See rooms %s in biome '%s'.", depth_range, biome_id)
		end

		-- Ensure all known roomtypes have a probability to allow stronger
		-- checking during worldgen.
		for _,r in ipairs(RoomType:Ordered()) do
			dist.roomtype[r] = dist.roomtype[r] or 0
		end

		for r in pairs(dist.reward) do
			kassert.assert_fmt(Reward:Contains(r), "Invalid reward '%s' in biome '%s'.", r, biome_id)
		end

		-- Validation for worldmap's FilterRewardForDifficulty.
		local max_reward = mapgen.max_reward
		local lowest_cap = lume(dist.difficulty_distribution)
			:keys()
			:reduce(function(lowest, diff_name)
				local diff_id = Difficulty.id[diff_name]
				local capped_reward = mapgen.max_reward_per_difficulty[diff_id] or max_reward
				return math.min(capped_reward, lowest)
			end, max_reward)
			:result()
		local all_rewards = lume(dist.reward)
			:reject(function(v)
				-- Require nonzero chance.
				return v == 0
			end, true)
			:keys()
			:map(function(v)
				return mapgen.Reward.id[v]
			end)
			:result()
		local lowest_allowed = math.min(table.unpack(all_rewards))
		kassert.assert_fmt(lowest_cap >= lowest_allowed, "Rooms %s require '%s' (%d) or lower reward tier to satisfy difficulty in biome '%s'.", depth_range, Reward:FromId(lowest_cap), lowest_cap, biome_id)

		-- Remap difficulty distribution into number indexes so we can use
		-- constants as keys.
		mapgen.validate.all_keys_are_difficulty(dist.difficulty_distribution, "Invalid difficulty '%s' in biome '%s'.", biome_id)
		dist.difficulty = {}
		for d,val in pairs(Difficulty.id) do
			dist.difficulty[val] = dist.difficulty_distribution[d] or 0
		end
		dist.difficulty_distribution = nil
	end
	-- room_distribution is only for ease of tuning. Use roomdist for all logic.
	def.room_distribution = nil
	kassert.assert_fmt(dist_count >= #def.roomdist, "Holes in %s.room_distribution. Ranges must be consecutive.", biome_id)
	kassert.assert_fmt(dist_count <= #def.roomdist, "Overlaps in %s.room_distribution. Ranges must be consecutive.", biome_id)
	kassert.assert_fmt(def.roomdist[1], "Must define room_distribution for at least one room in biome '%s'.", biome_id)

	for depth,dist in pairs(def.roomdist) do
		if dist.force_all_roomtypes or dist.force_all_rewards then
			-- Join at previous room to ensure we have enough space to branch.
			local prev = deepcopy(def.roomdist[depth-1])
			prev.join_all_branches = true
			def.roomdist[depth-1] = prev
		end
	end

	-- Last rooms are always hype and then boss.
	local final = deepcopy(def.roomdist[dist_count])
	final.force_all_roomtypes = nil
	final.force_all_rewards = nil
	for key in pairs(final.roomtype) do
		-- Zero instead of clobbering so all rooms are defined.
		final.roomtype[key] = 0
	end
	local hype = deepcopy(final)
	final.roomtype.boss = 1
	hype.roomtype.hype = 1
	table.insert(def.roomdist, hype)
	table.insert(def.roomdist, final)

	assert(def.dimensions.long == nil, "Don't specify dimensions.long. It's determined by the last value in room_distribution.")
	def.dimensions.long = #def.roomdist

	for lim_name,limit in pairs(def.roomlimit) do
		for r in pairs(limit) do
			assert(RoomType:Contains(r) or Reward:Contains(r), ("Invalid roomtype/reward '%s' in roomlimit.%s in biome '%s'."):format(r, lim_name, biome_id))
		end
	end
end

-- TODO(mapgen): Once worldgen is figured out and we want to use these
-- worlds, we can make custom tuning for them.
assert(not mapgen.biomes.kanft_swamp, "Remove this block when we setup mapgen for this location.")
mapgen.biomes.kanft_swamp = mapgen.biomes.treemon_forest
mapgen.biomes.kanft_swamp_hard = mapgen.biomes.treemon_forest_hard
assert(not mapgen.biomes.thatcher_swamp, "Remove this block when we setup mapgen for this location.")
mapgen.biomes.thatcher_swamp = mapgen.biomes.treemon_forest
mapgen.biomes.thatcher_swamp_hard = mapgen.biomes.treemon_forest_hard

assert(not mapgen.biomes.owlitzer_forest, "Remove this block when we setup mapgen for this location.")
mapgen.biomes.owlitzer_forest = mapgen.biomes.treemon_forest
mapgen.biomes.owlitzer_forest_hard = mapgen.biomes.treemon_forest_hard

assert(not mapgen.biomes.sedament_tundra, "Remove this block when we setup mapgen for this location.")
mapgen.biomes.sedament_tundra = mapgen.biomes.treemon_forest
mapgen.biomes.sedament_tundra_hard = mapgen.biomes.treemon_forest_hard

kassert.equal(mapgen.Difficulty.id.easy, 1, "Ensure a sensible starting point.")
assert(mapgen.Difficulty:FromId(mapgen.max_difficulty), "Max should be a valid difficulty.")

return mapgen
