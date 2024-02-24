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
				[[
					agent:
						!bliss
						Thanks for stopping by the finest little caravan this ssside of the volcano!
				]],
				[[
					agent:
						!laugh
						If ma could sssee me now.
				]],
				[[
					agent:
						!greet
						{name.npc_doc_lastname}-brand <#RED>Health {name.potion}s</>! Restore your mojo on the go-go!
				]],
			},
		},

		first_meeting = {
			TALK = [[
				agent:
					!shocked
					Goodness <i>graciousss!</i> Is that a cussstomer I see?
					!greet
					Greetings and sssalutations, my fine <#BLUE>{species}</> friend! Welcome to the <#RED>{name.rotwood}</>!
					!point
					<i>Boy howdy</i>, have I ever got a business proposition for YOU!
			]],

			OPT_1 = "Woah, hold on a sec. Who are--",

			--NO RESOURCES BRANCH--
			NO_RESOURCES_ALT = [[
				agent:
					!dubious
					--Now, you seem like a savvy <#BLUE>{species}</> who could use a bit of a pick-me-up. A refreshing <i>punch</i> of vim and vigour... a bit of, err...
					!shocked
					Now wait just a moment!
					!angry
					<i>I barely sssmell any <#KONJUR>{name.i_konjur}</> on you</i>.
			]],

			NO_RESOURCES_OPT1A = "Oh, yeah. I'm a bit broke right now.",
			NO_RESOURCES_OPT1B = "Yeah? So?",

			NO_RESOURCES_ALT2 = [[
					!think
					My, what an awkward predicament we find ourselvesss in!
					!dejected
					I can't show you the wonder of my {name.npc_doc_lastname}-brand <#RED>Health {name.potion}s</> without appropriate compensssation!
					!shrug
					Sssuch is the fickle nature of the market, I suppose.
					!point
					Do come back for a <#RED>{name.potion}</> when you have <#KONJUR><p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}</>, won't you?
			]],

			NO_RESOURCES_OPT2A = "Okay, sorry about that. See ya!",
			NO_RESOURCES_OPT2B = "Well that was a waste of time.",

			RESPONSE_NO_RESOURCES_OPT2A = [[
				agent:
					!greet
					Ta-ta!
			]],
			RESPONSE_NO_RESOURCES_OPT2B = [[
				agent:
					!greet
					Agreed!
			]],
			--END NO RESOURCES BRANCH

			--POTION FULL BRANCH--
			POTION_FULL_ALT = [[
				agent:
					!dubious
					--Now, you seem like a savvy <#BLUE>{species}</> who could use a bit of a pick-me-up. A refreshing <i>punch</i> of vim and vigour... a bit of, err...
					!angry
					Why, dear friend, I was going to offer you a most <i>marvelous</i> <#RED>{name.potion}</>, but it looks like your flask is already full!
					!dejected
					I can't sell you my <#RED>{name_multiple.potion}</> if you have nothing to carry them in.
			]],
				--mid branch--
					OPT_FULL_HEALTH = "Oh, sorry. Maybe next time?\n<i><#RED><z 0.7>(Potion already full)</></i></z>",

					OPT_FULL_HEALTH_RESPONSE = [[
						agent:
							!point
							I'll consider that a legally binding verbal agreement!
					]],
				--mid branch end--

				--mid branch--
					POT_FULL_LOST_HEALTH = [[
						agent:
							!think
							I'll tell you what. Why don't you take a moment to empty that vinegar out with <p bind='Controls.Digital.USE_POTION' color=BTNICON_DARK>, then I'll top you up with some bonafide {name.npc_doc_lastname}-brand <#RED>Health Potion</> instead?
					]],

					POTION_FULL_OPT_A = "Wow, you'd do that? Thanks!\n<i><#RED><z 0.7>(Potion already full)</></i></z>",
					POTION_FULL_OPT_B = "I'll, uh, think about it.\n<i><#RED><z 0.7>(Potion already full)</></i></z>",

					POTFULL_OPTA_RESPONSE = "Certainly!",
					POTFULL_OPTB_RESPONSE = "Don't think <i>too</i> long now!",
				-- mid branch end--
			--END POTION FULL BRANCH--

			--NORMAL BRANCH--
			RESPONSE_1 = [[
				agent:
					!dubious
					--Now, you seem like someone who could use a bit of a pick-me-up. A refreshing <i>punch</i> of vim and vigour! A bit of insurance, you might say, in an unsssure w--
			]],

			OPT_2_WHO = "--SORRY! To interrupt. Who <i>are</i> you?",
			OPT_2_POTION = "--Skip the pitch. Are those {name_multiple.potion}?",

			--BRANCH--
			RESPONSE_2_WHO = [[
				agent:
					!shocked
					Why, forgive my manners!
					!clap
					The name's <#BLUE>{name.npc_potionmaker_dungeon}</>, illussstrious post-apocalypse entrepreneur, ssscholar of medicine and beloved young heir to the {name.npc_doc_lastname} family fortune!
					!gesture
					At your mid-hunt convenience.
			]],

			--if this option becomes available, hide OPT1C
			OPT_3_SELLWHAT = "A salesman, huh? What are you selling?", 
			RESPONSE_3_SELLWHAT = [[
				agent:
					!shocked
					Why, my patented {name.npc_doc_lastname}-brand <#RED>Health {name.potion}s</>, of course!
			]], -->go to TALK2

			--BRANCH END--


			--BRANCH--
			RESPONSE_2_POTION = [[
				agent:
					!shocked
					My, what a dissscerning eye you have! Why yes, my good chum!
					!clap
					Allow me to introduce you to my patented {name.npc_doc_lastname}-brand <#RED>Health Potion</>!
			]], --> go to TALK2
			--BRANCH END--

			TALK2 = [[
				agent:
					!agree
					One sip with <p bind='Controls.Digital.USE_POTION' color=BTNICON_DARK>'s guaranteed to <#RED>Heal</> your woundsss, clear your skin, and leave your breath minty fresh for that <i>ssspecial someone</i> back home.
					!shocked
					[recipe:admission_recipe] And all for only a modessst sum of <#KONJUR>{name.i_konjur}</>!
			]],

			OPT_4_WHYBUY = "Why should I buy a {name.potion}?",
			OPT_4_BUY = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}]</> Wow! I'll take it. <i><#RED><z 0.7>(Refill Potion)</></i></z>",
			OPT_4_NOTHANKS = "I don't think I need a {name.potion}, thanks.",

			--BRANCH--
			RESPONSE_4_WHYBUY = [[
				agent:
					!shocked
					Why, my friend! Isn't it obvious?
					!disagree
					These woods are just itching to take a bite out of whatever poor soul wanders through.
					!agree
					But with a spare <#RED>{name.potion}</> in your backpocket, you're sure to blaze ahead where a lesser soul might have fallen!
					!gesture
					All you need do is take a sip with <p bind='Controls.Digital.USE_POTION' color=BTNICON_DARK>!
			]],
			OPT4A_RESPONSE = [[
				agent:
					!clap
					I knew you were a smart <#BLUE>{species}</>.
					!greet
					Pleassure doing business with you, and may we meet again soon!
			]],
			--BRANCH END--

			--BRANCH--
			RESPONSE_4_NOTHANKS = [[
				agent:
					!angry
					Now hold on just a sssecond there!
					!dubious
					I'll let you in on a little secret. These woods are <i>danger</i>-ous. 
					!think
					I'd hate to see fine folks like yourself in a pinch... so what sssay you buy one of these <#RED>Potions</> for the road, hm?
			]],

			OPT_6_ACCEPT = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}]</> Fine, you talked me into it. <i><#RED><z 0.7>(Refill Potion)</></i></z>",
			OPT_6_DECLINE = "No, I'm really okay.",

			RESPONSE_6_ACCEPT = [[
				agent:
					!laugh
					Ha-ha! You had me on the ropes, but I knew from the start you were a smart <#BLUE>{species}</>!
					!agree
					Enjoy your {name.npc_doc_lastname}-brand <#RED>Health {name.potion}</>, and may we deal again soon!
			]],
			RESPONSE_6_DECLINE = [[
				agent:
					!point
					A tough customer. I <i>do</i> love a challenge.
					!greet
					Well, fair play, my friend. I'll get you next time!
			]],
			--BRANCH END--

			done =
			{
				TALK_DONE_GAME = [[
					agent:
						!greet
						Pleasssure doing business with you.
				]],
			},
			--END NORMAL BRANCH--

			--kris
			--[[
				player:
					Sorry, can you tell me what this does?
				agent:
					!dubious
					Hueh? It's a <#RED>{name.potion}</>, kid.
					!gesture
					When you get hurt, drink it with <p bind='Controls.Digital.USE_POTION' color=BTNICON_DARK> to restore your <#RED>Health</>.
					!point
					But you only get one serving! And no refunds.
			]]

			player_emptied_flask = {
				-- WRITER: TEMP TEXT FOR FUNCTIONALITY!
				WAIT_FOR_EMPTY = [[
					agent:
						!point
						Now just empty that flasssk of yours out with <p bind='Controls.Digital.USE_POTION' color=BTNICON_DARK>.
						!clap
						I'll top you back up in a jiff!
				]],

				TALK = [[
					agent:
						!clap
						Ah, you've emptied your flasssk! Sssplendid!
						!gesture
						Now, allow me to properly introduce you to the {name.npc_doc_lastname}-brand <#RED>Health {name.potion}</>!
						!agree
						One sip with <p bind='Controls.Digital.USE_POTION' color=BTNICON_DARK>'s guaranteed to restore your mojo on the go-go! And by that I mean it <#RED>Heals</i> you.
						!shocked
						[recipe:admission_recipe] This veritable panacea of a <#RED>{name.potion}</> can be <i>yours</i> for only a modessst sum of <#KONJUR>{name.i_konjur}</>!
				]],

				OPT_1A = "I have to pay?? You said you'd top me up!",
				OPT_1B = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}]</> I'll take it! <i><#RED><z 0.7>(Refill {name.potion})</></i></z>",
				OPT_1C = "I don't think I need a {name.potion}, thanks.",

				--BRANCH 1--
				RESPONSE_OPT1A = [[
					agent:
						!shocked
						Why, my friend! You aren't trying to take advantage of a small business, are you?
						!dejected
						I put love into each and every one of these <#RED>{name_multiple.potion}ss</>... Sssurely you wouldn't bully me into asking less than my worth?
				]],

				OPT_1B_ALT = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}]</> Fine... Give me a {name.potion}.<i><#RED><z 0.7> (Refill {name.potion})</></i></z>",
				OPT_1C_ALT = "I think I'll pass, thanks.",
				--END BRANCH 1--

				RESPONSE_OPT1B = [[
					agent:
						!clap
						I knew you were a smart <#BLUE>{species}</>.
						!greet
						Pleassure doing business with you, and may we meet again soon!
				]],

				--BRANCH 3--
				RESPONSE_OPT1C = [[
					agent:
						!angry
						Now hold on just a sssecond there!
						!dubious
						I'll let you in on a little secret, my good <#BLUE>{species}</>. These woods are <i>daaanger</i>-ous. 
						!think
						I'd hate to see fine folks like yourself get into a pickle... so what sssay you buy one of these <#RED>Potions</> for the road, hm?
				]],

				OPT_2A = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}]</> Alright, you talked me into it. <i><#RED><z 0.7>(Refill {name.potion})</></i></z>",
				OPT_2B = "No, I'm really okay.",

				RESPONSE_OPT2A = [[
					agent:
						!laugh
						Ha-ha! You had me on the ropes, but I knew from the start you were a smart <#BLUE>{species}</>!
						!agree
						Enjoy your {name.npc_doc_lastname}-brand <#RED>Health {name.potion}</>, and may we deal again soon!
				]],

				RESPONSE_OPT2B = [[
					agent:
						!point
						A tough customer. I <i>do</i> love a challenge.
						!greet
						Well, fair play, my friend. I'll get you next time!
				]],
				--END BRANCH 3--
			},

			second_meeting = {
				TALK = [[
				agent:
					!shocked
					Ah, my friend! You've returned!
				]],

				OPT_1 = "Yeah! And I have funds this time.",
				OPT1_NOROOM = "Err, yeah, but I have a {name.potion} already.",
				OPT1_NOFUNDS = "Err, yeah, but I'm still a bit low on {name.i_konjur}.",

				--REGULAR BRANCH--
				OPT1_RESPONSE = [[
					agent:
						!clap
						Sssplendid, sssplendid!
						!gesture
						Then without further ado, allow me to introduce you to my patented {name.npc_doc_lastname}-brand <#RED>Health {name.potion}</>!
						!agree
						One sip with <p bind='Controls.Digital.USE_POTION' color=BTNICON_DARK>'s guaranteed to <#RED>Heal</> your woundsss, clear your skin, and leave your breath minty fresh for that <i>ssspecial someone</i> back home.
						!shocked
						[recipe:admission_recipe] This veritable panacea <#RED>Health {name.potion}</> can be <i>yours</i> for only a modessst sum of <#KONJUR>{name.i_konjur}</>!
				]],

				OPT_2A = "Why should I buy your {name_multiple.potion}? I don't even know you.",
				OPT_2B = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}]</> Wow! I'll take it. <i><#RED><z 0.7>(Refill {name.potion})</></i></z>",
				OPT_2C = "I think I'll pass, thanks.",

					--2A branch--
						OPT2A_RESPONSE = [[
							agent:
								!shocked
								Why, forgive my manners!
								!clap
								The name's <#BLUE>{name.npc_potionmaker_dungeon}</>, illussstrious post-apocalypse entrepreneur, ssscholar of medicine and beloved young heir to the {name.npc_doc_lastname} family fortune!
								!gesture
								[recipe:admission_recipe] At your mid-hunt convenience.
						]],

						--OPT_2B_ALT should only become available if OPT2A_RESPONSE is played, and should be presented with a decline button using OPT_2C
						OPT_2B_ALT = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}]</> Hm... Okay {name.npc_doc_firstname}, I'll try your {name.potion}.\n<i><#RED><z 0.7>(Refill {name.potion})</></i></z>",
						OPT2BALT_RESPONSE = [[
							agent:
								!dubious
								Hey, now that's what I call networking!
								!clap
								Enjoy your {name.npc_doc_lastname}-brand <#RED>Health {name.potion}</>, and may we deal again sssoon!
						]],
					--2A branch end--

					--2B branch--
						OPT2B_RESPONSE = [[
							agent:
								!clap
								I knew you were a smart <#BLUE>{species}</>.
								!greet
								Pleassure doing business with you, and may we meet again soon!
						]],
					--2B branch end--

					--2C branch--
						OPT2C_RESPONSE = [[
							agent:
								!angry
								Now hold on just a sssecond there!
								!dubious
								I'll let you in on a little secret. These woods are <i>danger</i>-ous. 
								!think
								I'd hate to see fine folks like yourself in a pinch... so what sssay you buy one of these <#RED>Potions</> for the road, hm?
						]],

						OPT_3A = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}]</> Fine, you talked me into it. <i><#RED><z 0.7>(Refill {name.potion})</></i></z>",
						OPT_3B = "No, I'm really okay.",

						OPT3A_RESPONSE = [[
							agent:
								!laugh
								Ha-ha! You had me on the ropes, but I knew from the start you were a smart <#BLUE>{species}</>!
								!agree
								Enjoy your {name.npc_doc_lastname}-brand <#RED>Health {name.potion}</>, and may we deal again soon!
						]],
						OPT3B_RESPONSE = [[
							agent:
								!point
								A tough customer. I <i>do</i> love a challenge.
								!greet
								Well, fair play, my friend. I'll get you next time!
						]],
					--2C branch end--
				--END REGULAR BRANCH--

				--POTION FULL BRANCH--
				OPT1_RESPONSE_NOROOM = [[
					agent:
					!dubious
					--Now, as I was sssaying last time, you seem like a savvy <#BLUE>{species}</> who could--
					!shocked
					WAIT! You already have a <#RED>{name.potion}</>?
					!disagree
					Bouncing <#RED>{name_multiple.cabbageroll}</> on a pogo stick, this just won't do!
					!dejected
					I can't sell you my <#RED>{name_multiple.potion}</> if you have nothing to carry them in.
				]],
					--mid branch--
					OPT_FULL_HEALTH = "Err, sorry. Catch ya next time?\n<i><#RED><z 0.7>(Potion already full)</></i></z>",

					OPT_FULL_HEALTH_RESPONSE = [[
						agent:
							!greet
							I'm counting on it!
					]],
					--end mid branch--

					--mid branch--
					OPT1_RESPONSE_NOROOM2 = [[
						!dubious
						Tell you what, why don't you take a moment to empty that flask of yours out with <p bind='Controls.Digital.USE_POTION' color=BTNICON_DARK>?
						!clap
						Then I can top you up with some bonafide {name.npc_doc_lastname}-brand <#RED>Health Potion</> instead!
					]],

					POTION_FULL_OPT_A = "Wowee! Thanks!\n<i><#RED><z 0.7>(Potion already full)</></i></z>",
					POTION_FULL_OPT_B = "Lemme think it over.\n<i><#RED><z 0.7>(Potion already full)</></i></z>",

					POTFULL_OPTA_RESPONSE = "Most certainly!",
					POTFULL_OPTB_RESPONSE = "Don't think <i>too</i> long now!",
					--end mid branch--
				--END POTION FULL BRANCH--

				--NO FUNDS BRANCH--
				OPT1_RESPONSE_NOFUNDS = [[
					agent:
						!dubious
						<i>--Now,</i> as I was sssaying last time, you seem like one savvy <#BLUE>{species}</> who could--
						!shocked
						<i>Hold your horses!</i> Did you just say you're ssstill broke? 
						!angry
						How'sss that even possible?
						!dubious
						Err, I mean, no hard feelings. Why don't you go give some monsters the what-for, then come back in a flash with some cold hard cash!
						!agree
						My gen-u-ine <#RED>{name_multiple.potion}</> will be waiting!
				]],

				OPT_5A = "Okay! I'll go bash some {name_multiple.rot}!",
				OPT_5B = "Eh, we'll see how I do.",

				OPT5_RESPONSE = [[
					agent:
						!greet
						Ta-ta!
						!angry
						<z 0.7>(Good grief.)</z>
				]],

					--USE QUIP_BROKECUSTOMER! 
				--END NO FUNDS BRANCH--
			},

			buffer = {

				TALK = [[
					agent:
						!dubious
						It's been a pleasssure to meet a smart and savvy <#BLUE>{species}</> such as yourself!
						!greet
						Best of luck to you.
				]],
			},

			third_meeting = {
				TALK = [[
					agent:
						!dubious
						(sniff sniff)...
						!dejected
						Kid. We gotta stop meeting like this.
				]],
			},
		},

		seen_missing_friends = 
		{
			TALK = [[
				agent:
					!shocked
					You're back!
			]],

			TALK2_CAN_BUY = [[
				agent:
					!dubious
					[recipe:admission_recipe] Can't resist the call of these fine <#RED>Potions</>, can you? Only a handful of <#KONJUR>{name.i_konjur}</> a pop!
			]],

			TALK2_NO_RESOURCES = [[
				agent:
					!dubious
					But you still don't have enough <#KONJUR>{name.i_konjur}</>.
			]],

			TALK2_NO_SPACE = [[
				agent:
					!dubious
					But your flask's still full. I'm afraid this is a bring-your-own container sort of operation.
					!agree
					I care deeply about the environment, you know.
			]],
			OPT_1A_ONEFRIEND = "Actually, have you seen my friend?",
			OPT_1A_TWOFRIENDS = "Actually, have you seen my friends?",
			OPT_1A_ALT = "By the way, have you seen my friend?",
			OPT_1B = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}]</> I'll take one! <i><#RED><z 0.7>(Refill Potion)</></i></z>",
			OPT_1C = "Hm. Well, see you around, {name.npc_doc_firstname}.",

			--BRANCH--
			OPT1A_BOTH = [[
				player:
					There was a gyroplane accident, and now our {name.job_blacksmith} and {name.job_armorsmith} are lost in the woods.
			]],
			OPT1A_BLACKSMITHONLY = [[
				player:
					There was a gyroplane accident, and now our {name.job_blacksmith} is lost in the woods.
			]],

			TALK3 = [[
				agent:
					!shocked
					How terrible! Truly awful!
					!agree
					[recipe:hoggins_tip_recipe] For a small fee, I'd be happy to tell you everything I know.
			]],

			OPT_2A = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 1 {name.konjur}]</> Uh, okay... Here you go.",
			OPT_2B = "Sigh. Nevermind.",
			OPT_2B_ALT = "Sigh. Nevermind. <i><#RED><z 0.7>(Need more {name.konjur})</></i></z>",

			OPT2A_RESPONSE = [[
				agent:
					!clap
					Thank you!
					!think
					I'm afraid I haven't seen anything.
					!wave
					Anyway, good luck on your search! Bye now!
			]],

			OPT2B_RESPONSE = [[
				agent:
					!shrug
					No hard feelings!
			]],
			--END BRANCH--

			OPT1B_RESPONSE = [[
				agent:
					!point
					You're a shrewd customer, I'll give you that.
					!greet
					Pleassure doing business!
			]],

			done =
			{
				TALK_DONE_GAME = [[
					agent:
						!greet
						Pleasssure doing business with you.
				]],
			},
		},

		--Hoggins' various... "business ventures" (scams)
		dgn_business_ventures_potion = 
		{
			bandicoot_swamp =
			{	--TODO kris remove agent ...
				TALK = [[
					agent:
						...
					player:
						{name.npc_doc_lastname}? How'd you end up in <#BLUE>{name.kanft_swamp}</>?
					agent:
						!angry
						You know what they say, my good <#BLUE>{species}</>-- location, location, location!!
						!dubious
						But nevermind that-- I do believe that shoe of yours is untied!
				]],

				OPT_2 = "Oh? Why, so it is!",

				--MAIN BRANCH--
				OPT2_RESPONSE = [[
					agent:
						!point
						Here, let me hold your bag while you fix it.
				]],

				--You wouldn't want to fall over in thisss toxic mud, now.

				OPT_3A = "Sure, thanks!",
				OPT_3B = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}]</> I'm just here for a Potion.\n<i><#RED><z 0.7>(Refill Potion)</></i></z>",
				OPT_3C = "Eh, why bother.",
					
					--BRANCH TWO--
						OPT3A_RESPONSE = [[
							agent:
								!takeitem
							player:
								<i>(shuffle shuffle)</i>
								There!
							agent:
								!gesture
								Here'sss your bag back, my good <#BLUE>{species}</>.
						]],

						OPT_7 = "Thanks, {name.npc_doc_lastname}!",

						OPT7_RESPONSE = [[
							agent:
								!greet
								Until next time, my friend!
						]],

						--tacks on to OPT3A_RESPONSE and overrides 7A & 7B options with 4A and 4B if the player hasnt bought a potion yet
						OPT3A_RESPONSE_ALT = [[
							agent:
								!gesture
								Now, were you also looking to buy a <#RED>Potion</> today?
						]],

						OPT_4A = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}]</> Oh, yes please. <i><#RED><z 0.7>(Refill Potion)</></i></z>",
						OPT_4B = "No thanks, I'm good for now.", --> player OPT7_RESPONSE

						OPT4A_RESPONSE = [[
							agent:
								!gesture
								Thank-you for your patronage!
						]],
					--END BRANCH TWO--

					--BRANCH THREE--
						OPT3B_RESPONSE = [[
							agent:
								!shocked
								Of course, of course!
								!gesture
								Here you are, my friend.
								!dubious
								Now, are you sure about leaving that shoe untied?
						]],

						OPT_5A = "Fine, okay. Hold my bag.", --> go to OPT3A_RESPONSE
						OPT_5B = "Eh, I'm not too worried about it.", --> go to OPT3C_RESPONSE
					--END BRANCH THREE--

					--BRANCH FOUR--
						OPT3C_RESPONSE = [[
							agent:
								!shocked
								What! But what if you trip fighting a <#RED>{name.rot}</>?
						]],

						OPT_6A = "Hmm, maybe you're right.",
						OPT_6B = "Sounds like an exciting fight!",

						OPT6B_RESPONSE = [[
							player:
								But thanks anyway, {name.npc_doc_lastname}!
						]],
					--END BRANCH FOUR--
				--END MAIN BRANCH--
			},

			sedament_tundra = {
				TALK = [[
					agent:
						!greet
						Oh Hunter, good to sssee you!
						!clap
						You're just in time to try my new <#RED><i>Limited Edition</i> {name.npc_doc_lastname}-brand Health Potion</>!
						!gesture
						Only <#KONJUR>10 {name.i_konjur}</> more than a regular <#RED>Potion</>!
						[recipe:limited_potion_refill] Get one while sssupplies last!
				]],

				OPT_1A = "It looks the same as the old potion.",
				OPT_1B = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 85 {name.konjur}]</> I'll take one! <i><#RED><z 0.7>(Refill with <i>Limited Edition</i> Potion)</></i></z>",
				OPT_1C = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}]</> Can I get a regular Potion? <i><#RED><z 0.7>(Refill Potion)</></i></z>",
				OPT_1D = "Actually, I don't need a Potion today.",

				OPT1A_RESPONSE = [[ 
					agent:
						!shocked
						Tassstes the same, too!
						!bliss
						Isn't it incredible?
				]], --> completing this option puts you back into a menu with the other three options

				OPT1B_RESPONSE = [[
					agent:
						!clap
						Yes! Oh, you're getting a real sssteal on this--
						!gesture
						--But I'm happy to bend the rules for a valued cussstomer.
					player:
						Thanks, {name.npc_doc_firstname}!
				]],

				OPT1B_RESPONSE_ALT_NOFUNDS = [[
					!shocked
						Why, my dear <#BLUE>{species}</>, it appears you haven't the <#KONJUR>{name.i_konjur}</> for this ssspecialty item!
						!dejected
						What a ssshame.
						!greet
						Well, I'll be here if you find some ssspare change!
				]],
				
				--TODO: Add an option to exit the conversation, drink your pot and then retry the exchange -kris
				OPT1B_RESPONSE_ALT_NOSPACE = [[
					agent:
						!shocked
						Why, my dear <#BLUE>{species}</>, you have no room for this specialty <#RED>Potion</>!
						!shrug
						Oh well. I'll be here if you'd like a regular <#RED>Potion</>.
				]],

				OPT1C_RESPONSE = [[ 
					agent:
						!think
						I expected a Hunter to be more adventurous, but I can't knock the ol'tried and true.
						!greet
						Thanksss for your continued patronage, my friend!
				]],

				--mini branch--
				OPT1D_RESPONSE = [[
					agent:
						!shocked
						Whoa, whoa now!
						!think
						What say I give you this special, limited edition <#RED>Potion</> for the price of your usual one?
						!agree
						Consider it a loyalty reward for a most valued customer.
				]],

				OPT_2A = "Now that's more like it.",
				OPT_2B = "Nah, I'm okay.",
				OPT_2B_NOFUNDS = "Nah, I'm okay. <i><#RED><z 0.7>(Need more {name.konjur})</></i></z>",
				OPT_2B_NOSPACE = "Nah, I'm okay. <i><#RED><z 0.7>(Potion already full)</></i></z>",

				OPT2A_RESPONSE = [[
					agent:
						!gesture
						Pleasssure doing business!
				]],
				OPT2B_RESPONSE = [[
					agent:
						!dubious
						You stick to your guns. I respect that.
						!shrug
						Well, I'll be here if you change your mind.
				]],
				--end mini branch--
			},
		},

		dgn_shop_potion =
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
				QUIP_BROKECUSTOMER = {
					[[
						Good gravy, maybe Ma wasss right about this venture.
					]],
				},
			},
			
			no_resources =
			{
				TALK_NO_RESOURCES = [[
					agent:
						!shocked
						Oh my, your pocketsss seem lighter than usual today.
						!dejected
						As the single father of four plucky eruption orphansss, I'm afraid I simply can't give my <#RED>Potions</> away for free.
						[recipe:admission_recipe] A little <#KONJUR>{name.i_konjur}</> is all I ask. It's for their college fundsss. I'm sure you understand.
				]],
		
				OPT_NEXT_TIME = "My apologies! Say hi to the kids!\n<i><#RED><z 0.7>(Need more {name.konjur})</></i></z>",
			},

			no_space =
			{
				TALK_NO_SPACE = [[
					agent:
						!shocked
						Why, my friend! Are you aware your flask is full of <i>inferior product</i>?!
						!think
						Golly, I just hate to see a salt of the earth <#BLUE>{species}</> like yourself get ssswindled.
						!dubious
						[recipe:admission_recipe] Tell you what, why don't you empty that swill out with <p bind='Controls.Digital.USE_POTION' color=BTNICON_DARK> and I'll top you up with some bonafide {name.npc_doc_lastname}-brand <#RED>Potion</> instead?
				]],
		
				OPT_NEXT_TIME = "Wow! You'd do that for me? <i><#RED><z 0.7>(Potion already full)</></i></z>",

				BYE = "Undoubtedly!",
			},

			shop =
			{
				TALK_MINIGAME = [[
					agent:
						!dubious
						Why, my good <#BLUE>{species}</>! Your flask's run bone dry!
						!gesture
						[recipe:admission_recipe] Ssspare a little <#KONJUR>{name.i_konjur}</> for your pal {name.npc_doc_firstname} and we'll set you up with some gen-u-ine <#RED>{name_multiple.potion}</>!
				]],
		
				OPT_CONFIRM = "<#RED>[<p img='images/ui_ftf_icons/konjur.tex'> 75 {name.konjur}]</> Take my {name.konjur}! <i><#RED><z 0.7>(Refill Potion)</></i></z>",
			},

			done =
			{
				TALK_DONE_GAME = [[
					agent:
						!greet
						Pleasssure doing business with you.
				]],
			},
		}
	}
}
