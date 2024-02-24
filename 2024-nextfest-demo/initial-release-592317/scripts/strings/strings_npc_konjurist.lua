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
						The raw <#KONJUR>{name.i_konjur}</> is pretty potent here.
				]],
				[[
					agent:
						!bliss
						Don't you love the sting of <#KONJUR>{name.i_konjur}</> hitting your nostrils?
				]],
				[[
					agent:
						!thinking
						Now what if...? No, no, that won't work.
				]],
				[[
					agent:
						!gesture
						Haha, I knew you were headed this way. My equipment's been going nuts.
				]],
				[[
					agent:
						!gesture
						Watch your step. I've got a bunch of gadgets and crystals strewn about.
				]],
				[[
					agent:
						!notebook
						Well, I didn't expect <i>that</i> result.
				]],
				[[
					agent:
						!notebook
						Hmm... How interesting.
				]],
				[[
					agent:
						!notebook
						Making a note of that...
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
					Hunters manifest pretty cool <#RED>{name_multiple.concept_relic}</>, but you're hopeless at honing them without us <#KONJUR>{name.job_konjurist}s</>.
					!eyeroll
					<#RED>Upgrades</> will make your <#RED>{name_multiple.concept_relic}</> way stronger, so if you want one then let's hurry it up.
					!notebook
					I have research to get back to.
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
					Okay. The first one's free, but I'll need some <#KONJUR>{name.i_konjur}</> from you to <#RED>Upgrade</> any more after that.
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

				OPT_1A = "Has anyone else come by here?\n<i><#RED><z 0.7>(Inquire after missing crew)</z></></i>",
				OPT_1B = "Nevermind.",

				TALK2 = [[
					agent:
						!thinking
						Uhh...
						!point
						Besides you? No one.
						!shrug
						Why, who are you looking for?
				]],

				OPT_NEED_BERNA = "We lost our {name.job_armorsmith} in an aircraft accident.",
				OPT_NEED_HAMISH = "We lost our {name.job_blacksmith} in an aircraft accident.",
				OPT_BERNA_AND_HAMISH = "We lost our {name.job_armorsmith} and {name.job_blacksmith} in an aircraft accident.",
				OPT_1B_ALT = "Eh, forget it.",

				TALK3 = [[
					agent:
						!eyeroll
						Ohh, that forest-shaking <i>crash</i> was you guys, huh?
						!shrug
						Eh, I'll keep an eye out, but their chances aren't great.
						!notebook
						There's an extra-nasty <#RED>{name.yammo}</> roaming about.
				]],

				OPT_ALT_EXPLAIN_YAMMO = "A {name.yammo}?",
				OPT_ALT_SEEN_YAMMO = "Oh. We're acquainted.",
				OPT_ALT_KILLED_YAMMO = "Oh, I already took care of that.",
				OPT_END = "Okay. Thanks for your time.",

				OPT_EXPLAIN_YAMMO_RESPONSE = [[
					agent:
						!think
						Yeah, a <#RED>{name.yammo_elite}</>. It's like a sortaaaa... big... <i>guy?</i>
						!shrug
						They're mean. You won't like them.
						!notebook
						Anyway-- want some <#RED>Upgrades</>? First one's on the house!
				]],

				OPT_SEEN_YAMMO_RESPONSE = [[
					agent:
						!dubious
						Haha, oh. I see. Sorry.
						!notebook
						Anyway-- want some <#RED>Upgrades</>? First one's on the house!
				]],

				OPT_KILLED_YAMMO_RESPONSE = [[
					agent:
						!dubious
						What. The <#RED>{name.yammo}</>?
						!gesture
						Haha, nice.
						!notebook
						Anyway, uh... want some <#RED>Upgrades</>? First one's on the house!
				]],

				OPT_3A = "<#RED>[Upgrade {name.concept_relic}]</> <i>Sigh.</i> Yeah, lemme see the options.",
				OPT_3A_ALT = "<#RED>[Upgrade {name.concept_relic}]</> Yeah, lemme see the options.",
				OPT_3B = "Nah, but thanks anyway.",

				TALK4 = [[
					agent:
						!notebook_stop
						Alrighty.
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

			what_is_konjur = {
				TALK = [[
					agent:
						!dubious
						Hey again.
				]],

				OPT_1A = "What <i>is</i> {name.i_konjur}, exactly?",
				OPT_1B = "Can I get some Upgrades?",
				OPT_1C = "See ya, {name.npc_konjurist}.",

				OPT1A_RESPONSE = [[
					agent:
						!shocked
						Um, only the most versatile chemical compound in the whole entire world!
						!think
						I love talking about <#KONJUR>{name.i_konjur}</>. Ask me whatever you want to know.
				]],

				OPT_2A = "Chemical compound? I thought it was magic.",
				OPT_2B = "Where does it come from?",
				OPT_2C = "Why does {name.i_konjur} give me powers?",

				--KRIS
				OPT2A_RESPONSE = [[
					agent:
						!dejected
						Ugh. I totally forgot you were from the Brinks.
						!gesture
						Less... <i>educated</i> folks might consider <#KONJUR>{name.i_konjur}</> "magic", but I can assure you 
				]],

				OPT1B_RESPONSE = [[
					agent:
						!gesture
						Can-do.
				]],

				OPT1C_RESPONSE = [[
					agent:
						!agree
						See ya.
				]],
			},

			owlitzer_forest = {
				TALK = [[
					agent:
						!greet
						Oh, hey again. Nice to have a little change of scenery, hm?
						!nod
						Y'know, I think <#KONJUR>{name.i_konjur}</> collected from the grove smells the best.
				]],

				OPT_1A = "Uh. If you say so.",
				OPT_1B = "I knock it back too fast to get a whiff.",
				OPT_1C = "{name.i_konjur} all smells the same to me.",

				TALK2 = [[
					agent:
						!shrug
						Eh, opinions are like fleas, huh? We all have them.	
						!think
						Oh, by the way, you mentioned you were looking for some people, right?
						!point
						I heard a weird caterwauling noise earlier. Wasn't a usual forest sound.
						!notebook
						Maybe it was someone you know?
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
						You're welcome to hang out though. The <#KONJUR>{name.i_konjur}</> fumes are wonderfully fragrant this time of day.
				]],

				QUIP_CHAT_ONLY = {
					[[
						agent:
							!shrug
							Kinda hard to work when you're making my equipment go haywire.
					]],
				},

				OPT_LOTTIE_PRESENT = "What's the deal with the blue lady?", --> lottie_desc.TALK_LOTTIE_DESC
		
				OPT_NEXT_TIME = "Okay, thanks. <i><#RED><z 0.7>(No upgradeable {name_multiple.concept_relic})</></i></z>", --> end convo
			},

			done =
			{
				TALK_DONE = {
					[[
						agent:
							!think
							What's it like to be full of <#KONJUR>{name.i_konjur}</>? Bet its nice.
					]],
					[[
						agent:
							!shrug
							Kinda hard to work when you're making my equipment go haywire.
					]],
					[[
						agent:
							!notebook
							If you manifest any more <#RED>{name_multiple.concept_relic}</> that need <#RED>Upgrading</>, I'll be here.
					]],
					[[
						agent:
							!shrug
							Hope those <#RED>Upgrades</> do you some good.
					]],
					[[
						agent:
							!notebook
							You're welcome to hang. The <#KONJUR>{name.i_konjur}</> fumes are wonderfully fragrant this time of day.
					]],
					[[
						agent:
							!dubious
							How do I move from room to room? Very carefully.
					]],
				},
			},

			shop =
			{
				QUIP_UPGRADE = {
					[[
						agent:
							!point
							Whewie, you're <i>ripe</i> with <#KONJUR>{name.i_konjur}</> stink-- need an <#RED>Upgrade</>?
					]],
					[[
						agent:
							!greet
							Oh, hey. Want an <#RED>Upgrade</>? First one's free.
					]],
					[[
						agent:
							!gesture
							First <#RED>Upgrade</>'s on the house. After that I'll need some <#KONJUR>{name.i_konjur}</>.
					]],
					[[
						agent:
							!greet
							First <#RED>Upgrade's</> always free.
					]],
					--[[
						agent:
							!gesture
							Doing an <#RED>Upgrade</> would be a welcome distraction right now.
					]]--,
					[[
						agent:
							!notebook
							Oh. Is it <#RED>Upgrade</> time?
					]],
					[[
						agent:
							!greet
							Want an <#RED>Upgrade</>? First one's on me.
					]],
					[[
						agent:
							!point
							First <#RED>Upgrade's</> on the house.
					]],
				},

				--KRIS
				QUIP_UPGRADE_ADDITIONALPURCHASE = {

				},

				QUIP_NOMONEY = {
					[[
						agent:
							!dubious
							Ooo, sorry. Can't <#RED>Upgrade</> your <#RED>{name_multiple.concept_relic}</> if you've got no <#KONJUR>{name.i_konjur}</>.
					]],
					[[
						agent:
							!shrug
							No <#KONJUR>{name.i_konjur}</>, no <#RED>Upgrades</>. Sorry.
					]],
					[[
						agent:
							!disagree
							You need some <#KONJUR>{name.i_konjur}</> if you want <#RED>Upgrades</>.
					]],
					[[
						agent:
							!dubious
							Haha. Where's all your <#KONJUR>{name.i_konjur}</>?
					]],
				},

				QUIP_NOUPGRADABLE = {
					[[
						agent:
							!dubious
							No <#RED>{name_multiple.concept_relic}</> to <#RED>Upgrade</> today? 'Shame.
					]],
					[[
						agent:
							!notebook
							Eh? Oh. You've got nothing for me to <#RED>Upgrade</> today.
					]],
					[[
						agent:
							!dejected
							Aw, you've got nothing to <#RED>Upgrade</>. I was looking forward to a break.
					]],
					[[
						agent:
							!dubious
							Eh? You've got nothing to <#RED>Upgrade</>.
					]],
					[[
						agent:
							!notebook
							Nothing to <#RED>Upgrade</> today, huh?
					]],
					[[
						agent:
							!notebook
							Nothing to <#RED>Upgrade</>? Just as well, I'm behind on data entry.
					]],
				},

				OPT_UPGRADE = "<#RED>[Upgrade {name.concept_relic}]</> Please do!",
				OPT_LOTTIE_PRESENT = "Who's that blue lady?", --> lottie_desc.TALK_LOTTIE_DESC
				OPT_BACK = "No thanks.",
			}
		}
	}
}
