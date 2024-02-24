return
{
	QUESTS =
	{
		twn_fallback_chat =
		{
			QUIP_CHITCHAT = {
				[[
					agent:
						!dubious
						It'sss not easy to brew this stuff up, you know.
				]],
			},
		},

		first_meeting = {

			TALK = [[
				agent:
					!dubious
					Welllll now, what hath we here?
					!eyeroll
					{name.shop_magpie}, wake up!
					!dubious
					Our new armour patron hath <i>deigned</i> to arrive.
			]],
			--[[nimble:
					Squawk!]]

			OPT_1A = "It's nice to see a friendly face out here.",
			OPT_1B = "Patron? What makes you think I'm in the market for gear?",

			OPT1B_RESPONSE = [[
				agent:
					!dubious
					Um... I hath eyes.
			]],

			OPT_2A = "What's wrong with what I'm wearing?",
			OPT_2B = "Hey! We don't have a lot to work with in the Brinks.",
			OPT_2C = "How are you making all this armour?",

			OPT2A_RESPONSE = [[
				agent:
					!laugh
					Bwe-heu-heu.
					!shrug
					Should I start with the presentation, or the function?

			]],
			OPT2B_RESPONSE = [[
				agent:
					!eyeroll
					You mean people art struggling to rebuild without Mulligan tech?
					!shocked
					Shocker!
					!laugh
					Bwe-heu-heu.
			]],

			SUDDEN_END = [[
				agent:
					!eyeroll
					Anyway, enjoy the <#RED>Demo</>, culver.
					!point
					Look forward to getting better acquainted. Bwe-heu-heu.
			]],

			--[[OPT_2A = "I happen to like my armour just fine!",
			OPT_2B = "I could maybe use some new gear...",

			OPT2A_RESPONSE = [[
				agent:
					!laugh
					Is that so?
					!point
					Well, should you find yourself in the market for new pieces, I'm happy to provide.
			]]

			--[[OPT2B_RESPONSE = [[
				agent:
					!laugh
					That was a rhetorical question.
			]]

			--[[OPT_3A = "What sort of armour do you sell?",
			OPT_3B = "Can I put in orders?",
			OPT_3C = "Anything in particular I should know?",

			OPT3A_RESPONSE = [[
				agent:
					!gesture
					I offer artisanal, handcrafted, locally sourced pieces.
					!laugh
					By which I mean I make gear out of the region's local monsters.
			]]

			--[[OPT3B_RESPONSE = [[
				agent:
					!shocked
					I don't take <i>commissions</i>.
					!agree
					I am an artist, and you have the opportunity to purchase my original work.
			]]

			--[[OPT3C_RESPONSE = [[
				agent:
					!thinking
					Oh, we do deliveries.
			]]

			--OPT_4A = "I already have an {name.job_armorsmith}.",
			--OPT_4B = "Okay. I'll take a look.",
			
			--[[OPT4A_RESPONSE = [[
				agent:
					!laugh
					And?
			]]

			--[[OPT4B_RESPONSE = [[
				agent:
					!gesture
					Enjoyyy.
			]]
		},

		seen_missing_friends = 
		{
			
		},

		dgn_shop_armorsmith =
		{
			twn_fallback_chat =
			{
				--used if in a forest dungeon
				QUIP_FORESTCHAT = {
					[[
						agent:
							!gesture
							This here tonic is made from the finest, freshest ingredientsss east of the <#RED>{name.treemon}</>.
					]],
				},

				--used if in a swamp dungeon
				QUIP_FORESTCHAT = {
					[[
						agent:
							!gesture
							Don't muck about with inferior products, my friend.
					]],
				},

				--used only if the salesman sold a tonic to the player in that room
				QUIP_SOLDTONICCHAT = {
					[[
						agent:
							!agree
							Pleasssure doing business with you, my friend!
					]],
				},

				--used whenever
				QUIP_CHITCHAT = {
					[[
						agent:
							!bliss
							I ain't perfect. But I sure am closer than most.
					]],
					[[
						agent:
							!point
							You're my favourite cussstomer.
					]],
					[[
						agent:
							!agree
							Trussst me, I'm a doctor.
					]],
				},
			},

			shop = {
				TALK = [[
					agent:
						!shrug
						Hey.
				]],
			},
		}
	}
}
