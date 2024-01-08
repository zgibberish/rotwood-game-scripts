return
{
	--NOTE TO WRITERS:
	--This lil weirdo is under Jambell's care. Please run changes by him first before implementing -Kris

	QUESTS =
	{
		dgn_mystery =
		{
			TITLE = "Mysterious Wanderer Encounters",

			chat_only =
			{
				TALK_CHAT_ONLY = [[
					agent:
						!greet
						He! He! He!
						Let me know if you come across anything interesting!
				]],

				OPT_NEXT_TIME = "Will do!",

			},

			--a present from Kris that may be used or discarded :)
			--[[
				A name is a pin in a butterfly.
				Did you choose your shape, or nestle into it?
			]]

			done =
			{
				TALK_DONE = [[
					agent:
						!clap
						He! He! He!
						'til we meet again!
				]],

				OPT_EXIT = "...",
			},

			free_power_epic =
			{
				TALK_FREE_POWER_EPIC = [[
					agent:
						!think
						Hm!
						We live inside a dream.
						!shrug
						But who is dreaming?
						!gesture
						*He holds out a hand, offering a gift.
				]],

				OPT_ACCEPT = "Thanks...",
				OPT_BACK = "No thanks.",
			},

			free_power_legendary =
			{
				TALK_FREE_POWER_LEGENDARY = [[
					agent:
						!think
						I'll really need this.
						!shrug
						You should have it.
						!gesture
						*He holds out a hand, offering a gift.
				]],

				OPT_ACCEPT = "Thanks...",
				OPT_BACK = "No thanks.",
			},

			potion_refill =
			{
				TALK = [[
					agent:
						!point
						Temperance!
						I knew a thirsty ghost who carried an infinite potion.
						Her throat was swollen, and she could never drink enough.
						!think
						Do you thirst?
				]],

				OPT_ACCEPT = "Yes...",
				OPT_BACK = "No.",
			},

			lose_power_gain_health =
			{
				TALK_LOSE_POWER_GAIN_HEALTH = [[
					agent:
						!clap
						He! He! He! I've got an idea!
						Give me a <#RED>{name.concept_relic}</> of yours...
						!think
						And I'll give you some <#RED>Health</> of mine! He! He! He!
						Accept:
							Select and lose a <#RED>{name.concept_relic}</>
							Gain <#RED>Health</> depending on <#RED>Rarity</>
				]],

				OPT_ACCEPT = "<#RED>[Select a {name.concept_relic}...]</> Sure...",
				OPT_BACK = "No thanks.",
			},

			transmute_power =
			{
				TALK_TRANSMUTE_POWER = [[
					agent:
						!point
						He! He! He! Transmutation!
						!clap
						Transmutation! Transmutation! Transmutation!
						Lead into gold! What do you say?
						Accept:
							Select and lose a <#RED>{name.concept_relic}</>
							Gain a random <#RED>{name.concept_relic}</> one <#RED>Rarity</> higher
				]],

				OPT_ACCEPT = "<#RED>[Select a {name.concept_relic}...]</> Sure...",
				OPT_BACK = "No thanks.",
			},

			upgrade_random_power =
			{
				-- TODO(dbriscoe): Should use something like PlayRecipeMenu to better visualize the cost and rewards. Discuss w/ jambell.
				TALK_UPGRADE_RANDOM_POWER = [[
					agent:
						!clap
						He! He! He! I'm feeling generous!
						I'll <#RED>Upgrade A Random {name.concept_relic}</> for free.
						!think
						All it will cost is a slice of your finger! He! He! He!
						Accept: Random <#RED>{name.concept_relic}</> upgrade. <#RED>Take 250 Damage</>.
				]],

				OPT_ACCEPT = "Okay...",
				OPT_BACK = "No way!",
			},

			coin_flip_max_health_or_damage =
			-- TODO(jambell): write an actual string set for this -- determinism, synchronicity, tendrel, karma
			{
				TALK_COIN_FLIP_MAX_HEALTH_OR_DAMAGE = [[
					agent:
						He! He! He! Care to flip a coin?
						Call it right, I'll help you out.
						If not, I'll have to help your enemies! He! He! He!
				]],

				OPT_HEADS = "Heads.",
				OPT_TAILS = "Tails.",
				OPT_BACK = "No way!",
			},

			event_prototype =
			{
				TALK_EVENT_PROTOTYPE = [[
					agent:
						!point
						Let's prototype an event!
						!clap
						Start?
				]],

				OPT_ACCEPT = "<#RED>[Start Minigame]</> Let's go!",
				OPT_BACK = "No thanks.",
			},

			bomb_game =
			{
				TALK_BOMB_GAME = [[
					agent:
						!point
						[BOMB_GAME]
						!clap
						Dodge a series of flying explosives.

						TIP: When getting knocked down, tap <#RED>Dodge</> just as you hit the ground to <#RED>Quick Rise</>!
				]],

				OPT_ACCEPT = "<#RED>[Start Minigame]</> Let's go!",
				OPT_BACK = "No thanks.",
			},

			dodge_game =
			{
				TALK_DODGE_GAME = [[
					agent:
						!point
						[DODGE_GAME]
						!clap
						Run through a field of <#RED>Spike Traps</> without getting hit.

						TIP: You can't be hit at the start of a <#RED>Dodge</>. Keep moving!
				]],

				OPT_ACCEPT = "<#RED>[Start Minigame]</> Let's go!",
				OPT_BACK = "No thanks.",
			},

			dps_check =
			{
				TALK_DPS_CHECK = [[
					agent:
						!point
						[DPS_CHECK]
						!clap
						Deal a lot of <#RED>Damage</> to one target within a time limit.

						TIP: Find an attack pattern that deals the most <#RED>Damage</> possible!
				]],

				OPT_ACCEPT = "<#RED>[Start Minigame]</> Let's go!",
				OPT_BACK = "No thanks.",
			},

			hit_streak =
			{
				TALK_HIT_STREAK = [[
					agent:
						!point
						[HIT_STREAK]
						!clap
						Get a high <#RED>Hit Streak</> by attacking a pair of alternating dummies.

						TIP: Focus on the timing and choose the right time to switch sides!
				]],

				OPT_ACCEPT = "<#RED>[Start Minigame]</> Let's go!",
				OPT_BACK = "No thanks.",
			},

			mini_cabbage_swarm =
			{
				TALK_MINI_CABBAGE_SWARM = [[
					agent:
						!point
						[MINI_CABBAGE_SWARM]
						!clap
						Kill as many tiny <#RED>Bonions</> as possible. Lose points when you get hit.

						TIP: You can't be hit at the start of a <#RED>Dodge</>. Keep moving!
				]],

				OPT_ACCEPT = "<",
				OPT_BACK = "No thanks.",
			},
		}
	}
}

--[[
I grow weary of suffering.
Seven, seven, seven, and two.
]]

--[[
Do you fail?
Are you sorry?
Is fear in your heart?
Where I am, these are not.
]]

--[[
Ah! Ah! Death! Death! You will long for death. Death is forbidden.
]]

--[[
I really need this.
You should have it.
]]

--[[
Is this memory, or is this dream?
Have you already made a habit of the distinction?
]]

--[[
If you come across a starving {name.rot}, feed to it your body.
Birth!
]]

--[[
I sought my Potion by holding my flask.
I held the flask.
And I will miss the Potion within.
]]