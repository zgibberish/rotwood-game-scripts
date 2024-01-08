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
						Nothing to report yet, but it's only a matter of time...
				]],
				[[
					agent:
						!bliss
						Don't you love the sting of <#KONJUR>{name.konjur}</> hitting your nostrils?
				]],
				[[
					agent:
						!thinking
						Now what if...? No, no, that won't work.
				]],
			},
		},

		first_meeting =
		{
			TALK = [[
				agent:
					!notebook
					<i>Woah!</i> What the heck is with these readings--
					!shocked
					You! You're making my equipment go nuts!
					!point
					I'm guessing you're a Hunter?
			]],

			OPT_1A = "Yeah, who are you?",
			OPT_1B = "Yeah... What're you doing out here?",

			OPT1A_RESPONSE = [[
				agent:
					!notebook_stop
					I'm a <#KONJUR>{name.job_konjurist}</>. The name's {name.npc_konjurist}.
			]],

			OPT1B_RESPONSE = [[
				agent:
					!notebook_stop
					<i>Um</i>. I'm a <#KONJUR>{name.job_konjurist}</>. We've always been out here.
			]],

			TALK2 = [[
				agent:
					!dubious
					Now do you want <#RED>{name.concept_relic} Upgrades</> or not?
			]],

			OPT_2A = "Upgrades?",
			OPT_2B = "<#RED>[Upgrade {name.concept_relic}]</> Yes, please!",
			OPT_2C = "No, thanks. <i><#RED><z 0.7>(Leave conversation)</></i></z>", --goes to REFUSE_UPGRADE

			OPT2A_RESPONSE = [[
				agent:
					!shrug
					Oh. I just assumed that was why you were here.
					!gesture
					Hunters can manifest some pretty cool <#RED>{name_multiple.concept_relic}</>, but you need us <#KONJUR>{name.job_konjurist}s</> to refine them.
					!eyeroll
					So if you want <#RED>Upgrades</> let's hurry it up. I have research to get back to.
			]],

			OPT_3A = "<#RED>[Upgrade {name.concept_relic}]</> Sounds cool! Refine me!",
			OPT_3B = "Maybe another time.", --goes to REFUSE_UPGRADE

			OPT3A_RESPONSE = [[
				agent:
					!notebook
					Okay, okay. Don't make it weird.
			]],

			REFUSE_UPGRADE = [[
				agent:
					!shrug
					Suit yourself.
			]],

			OPT2B_RESPONSE = [[
				agent:
					!agree
					Okay, let's see what you've got.
			]],

			done =
			{
				TALK_DONE = [[
					agent:
						!clap
						Most appreciated. Any data is crucial to the efforts of the <#KONJUR>{name.job_konjurist}</>!
						Hmm. My instruments are in need of a recharge before they return to function. However, I trust our paths will meet again.
				]],
			},
		},

		seen_missing_friends = {
			starting_forest = {
				TALK = [[
					agent:
						!notebook
						Hm? Oh, you're back?
				]],

				OPT_1A = "Hey, has anyone else come by?",
				OPT_1B = "Nevermind.",

				BLACKSMITH = [[
					player:
						We recently lost our {name.job_blacksmith} in an aircraft accident near here.
				]],

				TALK2 = [[
					agent:
						!eyeroll
						That forest-shaking <i>thunk</i> was you guys, huh?
						!thinking
						Well, no one else has been by in awhile. Sorry, Hunter.
				]],

				TALK2_A =
				[[
						!dubious
						You might wanna find your friend fast though.
						!notebook
						There's an extra-nasty <#RED>{name.yammo}</> roaming about.
				]],

				OPT_2A = "A {name.yammo}?",
				OPT_2B = "Okay. Thanks anyway.",

				TALK3 = [[
					agent:
						!think
						Yeah, an <#RED>{name.yammo_elite}</>. It's like a sortaaaa... big... <i>guy?</i>
						!shrug
						They're mean. You won't like them.
						!notebook
						Anyway. Want some <#RED>Upgrades</>?
				]],

				OPT_3A = "<#RED>[Upgrade {name.concept_relic}]</> <i>Sigh.</i> Yeah, lemme see the options.",
				OPT_3B = "Nah, but thanks anyway.",

				TALK4 = [[
					agent:
						!notebook_stop
						See you around.
				]],

				done =
				{
					TALK_DONE = [[
						agent:
							!clap
							Hope those upgrades do you some good.
							!shrug
							If you manifest any more <#RED>{name_multiple.concept_relic}</>, I'll be around.
					]],
				},
			},

			owlitzer_forest = {
				TALK = [[
					agent:
						!greet
						Oh, hey again. Nice to have a little change of scenery, hm?
						!nod
						Y'know, I think <#KONJUR>{name.konjur}</> collected from the grove smells the best.
				]],

				OPT_1A = "Uh. If you say so.",
				OPT_1B = "I knock it back too fast to get a whiff.",
				OPT_1C = "{name.konjur} all smells the same to me.",

				TALK2 = [[
					agent:
						!shrug
						Eh, opinions are like fleas, huh? We all have them.	
						!think
						Oh, by the way, you mentioned you were looking for some people, right?
						!point
						I heard a weird caterwauling noise earlier. Wasn't a usual forest sound.
						!notebook
						Maybe it someone you know?
				]],

				OPT_2A = "Really?? Where!",
				OPT_2B = "Why didn't you lead with that!",

				OPT2A_RESPONSE = [[
					agent:
						!think
						It sounded really deep into the grove.
						!shrug
						I don't usually go that far. The <#RED>{name_multiple.rot}</> start getting bigger and meaner.
				]],

				OPT2B_RESPONSE = [[
					agent:
						!shrug
						Iunno.
				]],

				TALK3 = [[
					agent:
						!notebook
						Anyway, I'm gonna get back to my research.
						!dubious
						Unless you want some <#RED>Upgrades</>?
				]],

				OPT_3A = "<#RED>[Upgrade {name.concept_relic}]</> Sigh. <i>Yes, please.</i>",
				OPT_3B = "No, thanks. See ya, {name.npc_konjurist}.",

				BYE = [[
					agent:
						!notebook
						'Kay.
				]],
			},
		},

		dgn_shop_powerupgrade =
		{
			lottie_desc = 
			{
				TALK_LOTTIE_DESC = [[
					agent:
						!shrug
						Oh, her? She says she's a doctor, but she's pretty young.
						!notebook_start
						Plus where would you even get a degree nowadays?
				]],
			},

			chat_only =
			{
				TALK = [[
					agent:
						!greet
						Oh, hey. I don't think you have any <#RED>{name_multiple.concept_relic}</> I can upgrade.
						!shrug
						You're welcome to hang out though. The <#KONJUR>{name.konjur}</> fumes are wonderfully fragrant this time of day.
				]],

				OPT_LOTTIE_PRESENT = "What's the deal with the blue lady?", --> lottie_desc.TALK_LOTTIE_DESC
		
				OPT_NEXT_TIME = "Okay, thanks. <i><#RED><z 0.7>(No upgradeable {name_multiple.concept_relic})</></i></z>", --> end convo
			},

			done =
			{
				TALK_DONE = [[
					agent:
						!shrug
						Hope those upgrades do you some good.
						!notebook
						If you manifest any more <#RED>{name_multiple.concept_relic}</> that need upgrading, I'll be here.
				]],
			},

			shop =
			{
				TALK_STORE = [[
					agent:
						!greet
						Curious. My instruments are detecting abnormal tracings of <#KONJUR>{name.konjur}</> around you...
						!point
						Mind if I inspect? I may be able to upgrade a <#RED>{name.concept_relic}</>, provided you've got the materials!
				]],

				OPT_UPGRADE = "<#RED>[Upgrade {name.concept_relic}]</> Please do!",
				OPT_LOTTIE_PRESENT = "Who's that blue lady?", --> lottie_desc.TALK_LOTTIE_DESC
				OPT_BACK = "No thanks.",
			}
		}
	}
}
