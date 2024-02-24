return
{
	QUESTS =
	{
		twn_friendlychat = {
			FLITT = {
				OPT_1 = "You and {name.npc_scout} seem close. How do you know each other?",

				OPT1_RESPONSE = [[
					agent:
						!think
						Ah. Hmm. Well. You know how these things go.
						!point
						'Bout nine years ago now I was spinning up to start the first Hunter school in the Brinks.
						!shrug
						Dangerous work. Even in a town with nothin' left to lose, there weren't many takers.
						!laugh
						Then a dirty, scruffy kit in a blue scarf showed up on my doorstep.
						!shrug
						So I took him in. The rest is history.
				]],

				OPT_2A = "But {name.npc_scout} isn't a Hunter.",
				OPT_2B = "Wait, so you're like... {name.npc_scout}'s dad??",

				OPT2A_RESPONSE = [[
					agent:
						!closedeyes
						Yeah. Took me some time to realize that.
				]],
				OPT2B_RESPONSE = [[
					agent:
						!closedeyes
						I'm... not sure they would use that word.
						!point
						But they're a good kit.
						!agree
						I intend to keep an eye out for'em.
				]],

				OPT_3 = "Thanks for chatting, {name.npc_dojo_master}.",

				OPT3_RESPONSE = [[
					agent:
						!agree
						Hm.
				]],
			},
		},
		twn_meeting_dojo = 
		{
			TITLE = "Fighting Chance",
			DESC = "{name.npc_dojo_master} has returned to camp, but his condition is flaring up. {name.npc_scout} has asked you to refill his inhaler by killing {name_multiple.rot}.",

			talk_in_town =
			{
				TEMP_INTRO = [[
					agent:
						!gesture
						{name.dojo_cough}
						!greet
						'Ey, how d'you do, Hunter? I'm glad this <#RED>Demo</> gave me a chance to meetcha.
						!gesture
						I'm <#BLUE>{name.npc_dojo_master}</>, the <#RED>{name.job_dojo}</>.
						!think
						I came on this expedition to give you some challenges and toughen you up, but, uh--
						!point
						'Looks like those <#RED>Game Systems</> haven't been implemented yet.
						!laugh
						In the meantime, come by and chat if you want some combat tips! {name.dojo_cough}
				]],

				TEMP_OPT = "Cool. Nice to meet you, {name.npc_dojo_master}!",

				TEMP_INTRO2 = [[
					agent:
						[title:SPEAKER]
						[sound:Event.joinedTheParty] 0.5
						!dubious
						Phew. It was quite the fight gettin' home, y'know.
						[title:CLEAR]
				]],

				TALK = [[
					agent:
						!gesture
						{name.dojo_cough} I'm ho-oome!
					flitt:
						!clap
						{name.npc_dojo_master}! Geez, you took long enough.
					agent:
						!angry
						'Ey. I'm <i>old</i>, fox.
						!point
						Who's yer friend?
					flitt:
						!greet
						Hunter! Good timing. I don't think you've formerly met <#BLUE>{name.npc_dojo_master}</>.
						!gesture
						<#BLUE>{name.npc_dojo_master}</>, this is one of our new Hunters.
				]],

				OPT_1A = "Nice to finally meet. I look forward to learning from you.",
				OPT_1B = "How'd you make it back to camp?",
				OPT_1C = "Are you feeling okay?",

				OPT1A_RESPONSE = [[
					agent:
						!agree
						I look forward to putting you through your paces.
				]],
				OPT1B_RESPONSE = [[
					agent:
						!shrug
						{name.dojo_cough} --Fought my way.
				]],
				OPT1C_RESPONSE = [[
					agent:
						!shrug
						Why do you ask?
				]],

				TALK2 = [[
					agent:
						!dejected
						<#KONJUR><i><z 0.8>(cough cough <i>cough</i> HACK)</>
					flitt:
						!point
						<#BLUE>{name.npc_dojo_master}</>? Where's your inhaler?
					agent:
						!angry
						I'm fine, fox! {name.dojo_cough} Quit yer worrying.
					flitt:
						!takeitem
						Huh? There's nothing in here. Did you drop your refill charges during the crash?
						!gesture
						'Ey Hunter, sorry, but <#BLUE>{name.npc_dojo_master}</> won't be up to tutoring you until I can get this refilled.
				]],

				OPT_2A = "Is he okay?",
				OPT_2B = "Can I help?",

				OPT2A_RESPONSE = [[
					agent:
						!angry
						I'm <i>fine</i>! 
				]],
				OPT2B_RESPONSE = [[
					flitt:
						!think
						Hmm...
				]],

				TALK3 = [[
					flitt:
						!agree
						Actually Hunter, there's an errand you could run for me if you're up for it.
						!giveitem
						Could you take this inhaler with you on our next {name.run}?
						!shrug
						If you kill about <#RED>{num_to_kill} {name_multiple.rot}</>, the <#KONJUR>{name.i_konjur}</> should work as a makeshift recharge.
				]],

				OPT_3A = "You got it, {name.npc_scout}.",

				TALK4 = [[
					flitt:
						!clap
						Thanks! You're a huge help.
					agent:
						!eyeroll
						{name.dojo_cough} Bah.
				]],

				OPT_2A = "I'd love to learn more Hunter techniques.",
				OPT_2B = "I never turn down a challenge!",
				OPT_2C = "Nice to meet you, {name.npc_dojo_master}.",

				TALK3 = [[
					agent:
						[title:SPEAKER]
						[sound:Event.joinedTheParty] 0.5
						!agree
						Good.
						[title:CLEAR]
				]],

				OPT2A_RESPONSE = [[
					agent:
						!point
						Just know I'm not the type to go around handing out gold stars.
					flitt:
						!laugh
						Don't worry, he's tough but fair.
				]],

				OPT2B_RESPONSE = [[
					flitt:
						!nervous
						Please try to keep our Hunters' safety in mind during training, {name.npc_dojo_master}.
					agent:
						!laugh
						You worry too much, fox.
				]],

				OPT_3C = [[

				]],

				OPT_3 = "Make yourself at home.",

				TALK_FIRST_HIRED = [[
					agent:
						!laugh
						Ghe-he-he.
						!dubious
						This is gonna be fun.
				]],
			},


		},
		twn_shop_dojo =
		{
			DODGE_CONVERSATION = {
				TALK = [[
					agent:
						!laugh
						Ghe-he-he. 'Ey Hunter! 
						!point
						Don't think you've wriggled out your first {name.pop_quiz} just 'cause I was lost in the woods!
						!gesture
						Tell me. Whatcha know about <#RED>Dodging</>?
				]],

				OPT_1A = "Oh. Um. Nothing?",
				OPT_1B = "It's more important than attacking.",
				OPT_1C = "You do it with <p bind='Controls.Digital.DODGE' color=BTNICON_DARK>.",
				OPT_1D = "It's for wimps.",

				OPT1A_RESPONSE = [[
					agent:
						!shocked
						{name.dojo_cough} Were you sleepin' during Hunter training?
						!point
						Right then, LISTEN UP--
				]],
				OPT1B_RESPONSE = [[
					agent:
						!shocked
						<i><z 2>CORRECT!</></i>
						!gruffnod
						<#RED>A+</>, kid. {name.dojo_cough}
				]],
				OPT1C_RESPONSE = [[
					agent:
						!agree
						An acceptable answer. At least we're not starting from zero.
						!dubious
						{name.dojo_cough} Now, look--
				]],
				OPT1D_RESPONSE = [[
					agent:
						!shocked
						<i><z 2>INCORRECT!</></i>
						!angry
						Someone's lookin' to get detention. {name.dojo_cough} Now LISTEN UP--
				]],

				TALK2 = [[
					agent:
						!point
						If you just charge into a Hunt <#RED>Weapons</> swingin', you'll get knocked on yer tail in no time flat.
						!dubious
						Instead, watch your foes for clues they're about to strike, then <#RED>{name.concept_dodge}</> out of the way with <p bind='Controls.Digital.DODGE' color=BTNICON_DARK> when they do.
						!gruffnod
						Foes leave themselves wide open after they <#RED>{name.concept_attack}</>, but you won't be able to capitalize if you're reelin' from a hit.
				]],

				OPT_2A = "Gotcha... I'll dodge with <p bind='Controls.Digital.DODGE' color=BTNICON_DARK>!",
				OPT_2B = "Prioritize dodging over attacking. Okay!",
				OPT_2C = "Watch foes' movements closely. Can do.",
				OPT_2D = "I still think dodging's for wimps.",

				OPT2A_RESPONSE = [[
					agent:
						!agree
						Remember, it's easy to regret a swing, but you'll never regret a <#RED>{name.concept_dodge}</>.
				]],
				OPT2B_RESPONSE = [[
					agent:
						!agree
						It's easy to regret a swing, but you'll never regret a <#RED>{name.concept_dodge}</>.
				]],
				OPT2C_RESPONSE = [[
					agent:
						!agree
						The more familiar you can get with their patterns, the easier you'll stay alive.
				]],
				--branch--
				OPT2D_RESPONSE = [[
					agent:
						!angry
						Are you a teacher, Hunter? 'Cause you sure are testing me.
						!dubious
						Y'know, I <i>was</i> going to give you a <#KONJUR>Treat</>, but now I'm not sure if you deserve it.
				]],

					--only used if you chose both 1D and 2C
				OPT_3A = "<z 0.92>Treat?? <i>(Ahem)</> I love dodging with <p bind='Controls.Digital.DODGE' color=BTNICON_DARK>!</>",
				OPT_3B = "You can't bribe <i>me!</i>",

				OPT3A_RESPONSE = [[
					agent:
						!dejected
						Sigh. Just take it.
						!giveitem
						But try not to get clobbered out there, okay? Class dismissed.
				]],
				OPT3B_RESPONSE = [[
					agent:
						!gruffnod
						Hmph. {name.dojo_cough} Class dismissed.
				]],
					--END CONVO--
				--branch--

				TALK3 = [[
					agent:
						!give item
						...Here, have a <#KONJUR>Treat</>. Class dismissed.
				]],
			},

			FOCUS_HIT_CONVERSATION = {
				TALK = [[
					agent:
						!greet
						'Ey, Hunter!
						!laugh
						{name.pop_quiz}!
				]],

				OPT_1A = "Yay!",
				OPT_1B = "Oh no.",

				TALK2 = [[
					agent:
						!dubious
						Tell me... Whatcha know about <#BLUE>{name_multiple.concept_focus_hit}</>?
				]],

				OPT_2A = "Err, every weapon does them differently?",
				OPT_2B = "Their damage appears in blue!",
				OPT_2C = "They're the only way to reach full damage potential.",
				OPT_2D = "{name_multiple.concept_focus_hit} are for nerds.",

				OPT2A_RESPONSE = [[
					agent:
						!gruffnod
						True! Don't know your <#RED>Weapon's</> <#BLUE>{name.concept_focus_hit}</> conditions? Swing it here in town and a tip'll pop up to remind you!
						!thinking
						<#BLUE>{name_multiple.concept_focus_hit}</> do waaay more <#RED>{name.concept_damage}</> than regular <#RED>{name_multiple.concept_attack}</>.
						!gruffnod
						You'll know you've done a <#BLUE>{name.concept_focus_hit}</> right if your <#RED>Damage</> appears in <#BLUE>Blue</>.
				]],
				OPT2B_RESPONSE = [[
					agent:
						!gruffnod
						Well, at least you've taken the 101 course.
						!point
						<#BLUE>{name_multiple.concept_focus_hit}</> are <#RED>{name_multiple.concept_attack}</> that deal waaay more <#RED>{name.concept_damage}</> than regular <#RED>{name_multiple.concept_attack}</>.
						!gruffnod
						Don't know your <#RED>Weapon's</> <#BLUE>{name.concept_focus_hit}</> conditions? Swing it here in town and a tip'll pop up to remind you!
						!shrug
						Just don't hit no one.
				]],

				OPT2C_RESPONSE = [[
					agent:
						!shocked
						CORRECT! <#BLUE>{name_multiple.concept_focus_hit}</> appear in <#BLUE>blue</> and do waaay more <#RED>{name.concept_damage}</> than normal <#RED>{name_multiple.concept_attack}</>!
						!gruffnod
						Don't know your <#RED>Weapon's</> <#BLUE>{name.concept_focus_hit}</> conditions? Swing it here in town and a tip'll pop up to remind you!
						!shrug
						Just don't hit no one.
				]],

				OPT2D_RESPONSE = [[
					agent:
						!shrug
						Well, you're gonna get out-<#RED>{name.concept_damage}d</> by nerds, then.
						!gesture
						<#BLUE>{name_multiple.concept_focus_hit}</> appear in <#BLUE>blue</> and do waaay more <#RED>{name.concept_damage}</> than regular <#RED>{name_multiple.concept_attack}</>.
						!shrug
						You can swing your <#RED>Weapon</> anywhere in town to pop up a tip showing its <#BLUE>{name.concept_focus_hit}</> conditions, if you change yer mind.
						!point
						Just don't hit no one.
				]],

				OPT_3A = "Swing my weapon in town to see its conditions. Okay!",
				OPT_3B = "Do {name_multiple.concept_focus_hit} to fulfill my damage potential. Makes sense.",
				OPT_3C = "If my damage appears in blue, I've done it right. Gotcha.",
				--BRANCH--
				OPT_3D = "Wow, that was a long and nerdy lecture.",
				
				OPT3D_RESPONSE = [[
					agent:
						!dejected
						Do you want your <#KONJUR>Treat</> or not?
				]],

				OPT_4A = "<z 0.90><i>Sigh</>. I love doing extra damage with Focus Hits!</>",
				OPT_4B = "My brain can't be bought!",

				OPT4A_RESPONSE = [[
					agent:
						!giveitem
						Just take it.
						!eyeroll
						Class dismissed.
				]],
				OPT4B_RESPONSE = [[
					agent:
						!eyeroll
						You can lead a horse to <#KONJUR>{name.i_konjur}</>...
						!shrug
						Class dismissed.
				]],
				--END BRANCH--

				TALK3 = [[
					agent:
						!gesture
						Yep.
						!gruffnod
						Ah, and feel free to practice your <#BLUE>{name_multiple.concept_focus_hit}</> on the dummies around town.
						!giveitem
						...Great work today, kid. Have a <#KONJUR>Treat</>.
						!gruffnod
						Class dismissed.
				]],
			},

			-- Strings
			TALK_RESIDENT = [[
				agent:
					!gesture
					{name.dojo_cough}
			]],

			--OPT_TEACH_RAND = "Teach me somethin', {name.npc_dojo_master}. <i><#RED><z 0.7>(Random Lesson)</></i></z>",
			OPT_TEACH = "Teach me somethin', {name.npc_dojo_master}.", --> go to LESSONS

			MASTERIES = {
			},

			LESSONS = {
				TALK_SELECT_CATEGORY = [[
					agent:
						!gesture
						What sort of lesson you lookin' for?
				]],

				--player selected a lesson category and now has to pick a specific lesson from within that category
				TALK_SELECT_GENERAL = [[
					agent:
						!dubious
						Sure. {name.dojo_cough} Pick yer lesson.
				]],
				TALK_SELECT_COMBAT = [[
					agent:
						!dubious
						In a fightin' mood, huh?
				]],
				TALK_SELECT_DEFENSE = [[
					agent:
						!gruffnod
						Defense. 'Course.
				]],
				TALK_SELECT_WEAPONS = [[
					agent:
						!agree
						{name.dojo_cough} Which weapon you wanna hear about?
				]],
				TALK_SELECT_EQUIPMENT = [[
					agent:
						!gruffnod
						'Course. The gear makes the Hunter, after all.
				]],

				--go back to the main lessons menu from within a selected category
				BACK_BTN = "Hm, <i>actually--</> <i><#RED><z 0.7>(Back to lesson menu)</></i></z>",
				BACK_BTN_RESPONSE = [[
					agent:
						!gruffnod
						Sure thing.
				]],
				END_BTN_MAINMENU = "Just kidding! I hate learning. <i><#RED><z 0.7>(Class dismissed)</></i></z>",
				END_BTN_MAINMENU_RESPONSE = [[
					agent:
						!shrug
						It's yer life, kid.
				]],
				END_BTN_SUBMENU = "'Kay, that's enough learning. <i><#RED><z 0.7>(Class dismissed)</></i></z>",
				END_BTN_SUBMENU_RESPONSE = [[
					agent:
						!greet
						'Course. {name.dojo_cough} I'll be here.
				]],

				REPEAT_LESSON_FIRST_LINE = [[
					agent:
						LISTEN UP now! {name.dojo_cough}
				]],

				TUTORIALS = {
					GENERAL_BTN = "Iunno. General lessons?",
					GENERAL_BTN_ALT = "A general lessons review?",
					GENERAL = {
						FRENZIED_HUNTS_BTN = "Frenzied Hunts",
						FRENZIED_HUNTS_BTN_ALT = "Frenzied Hunts, again?",
						FRENZIED_HUNTS = [[
							agent:
								!point
								<#RED>Frenzied</> Hunts are tougher than regular Hunts, but you need them for progression-- they're the only way to get those precious <#KONJUR>{name_multiple.i_konjur_heart}</>.
								!dubious
								Be mindful, though. <#RED>Reviving</> allies is free on regular Hunts, but on <#RED>Frenzy Level 1</> and above, it'll cost you some <#RED>Health</> to pick up a friend.
								!gruffnod
								If you're worried, don't be. <#RED>Frenzy Levels</> might be challenging, but you'll never be given access to one that's beyond your ability.
						]],
						POWER_DROPS_BTN = "{name.concept_relic} Crystals",
						POWER_DROPS_BTN_ALT = "{name.concept_relic} Crystals, again?",
						POWER_DROPS = [[
							agent:
								!point
								You can use the <#KONJUR>Power Crystals</> you find during a Hunt to manifest mighty abilities, increasing your power and survivability in the field.
								!gesture
								There are all sorts of different <#RED>{name_multiple.concept_relic}</>, and many of them pair well together to become extra powerful. Get creative and try different combinations.
								!point
								Your <#RED>{name_multiple.concept_relic}</> always wear off by the time you get home, so there's no downside to experimenting.
						]],

						REVIVE_MECHANICS_BTN = "Reviving Friends",
						REVIVE_MECHANICS_BTN_ALT = "Revives, again?",
						REVIVE_MECHANICS = [[
							agent:
								!point
								If one of yer fellow Hunters gets knocked out on a Hunt, you can get them back on their feet by approaching them and holding <p bind='Controls.Digital.ACTION' color=BTNICON_DARK>.
								!disagree
								You're vulnerable while you're reviving, and your friend will only come back with <#RED>33% Health</>... so watch yer backs.
								!gruffnod
								If you're hunting on <#RED>Frenzy Level 1</> or higher, you'll also lose some <#RED>Health</> as it transfers to your revived friend.
						]],
					},

					DEFENSE_BTN = "<i>Defensive tactics</i>.",
					DEFENSE_BTN_ALT = "A defensive tactics review!",
					DEFENSE = {
						DODGE_BTN = "Dodging Basics",
						DODGE_BTN_ALT = "Dodge Basics, again?",
						DODGE = [[
							agent:
								!point
								<#RED>Dodging</> (<p bind='Controls.Digital.DODGE' color=BTNICON_DARK>) is one of the most crucial and fundamental tools in your arsenal, Hunter.
								!gruffnod
								To survive, you'll have to learn to prioritize <#RED>Dodging</> incoming <#RED>Attacks</> over trying to do <#RED>Damage</> yourself.
								!gesture
								Once you <#RED>{name.concept_dodge}</> (<p bind='Controls.Digital.DODGE' color=BTNICON_DARK>) an <#RED>Enemy's Attack</>, they'll usually leave themselves wide open for you to get your hit in safely.
						]],

						DODGE_CANCEL_BTN = "Dodge Cancels",
						DODGE_CANCEL_BTN_ALT = "Dodge Cancels, again?",
						DODGE_CANCEL = [[
							agent:
								!point
								Every <#RED>Attack</> you can perform's got a window of time where <#RED>Dodging</> will cancel its animation, but not its <#RED>Damage</>.
								!gesture
								And although them animations is real pretty, canceling them early allows you to <#RED>Attack</> again sooner than if you'd let it play, making it easier to build combos.
								!gruffnod
								<#RED>Attacks</> all got different cancel windows though, so you'll have to practice to get a feel for <#RED>{name.concept_dodge} Canceling</> your favourite moves.
						]],

						PERFECT_DODGE_BTN = "Perfect {name_multiple.concept_dodge}",
						PERFECT_DODGE_BTN_ALT = "Perfect {name_multiple.concept_dodge}, again?",
						PERFECT_DODGE = [[
							agent:
								!gesture
								When you <#RED>{name.concept_dodge}</>, there's a sliver of a moment where you're immune to <i>all</i> <#RED>{name.concept_damage}</>.
								!point
								If you can line up that sliver with the exact moment an <#RED>{name.concept_attack}</> would hit you, you'll perform a <#RED>Perfect {name.concept_dodge}</>.
								!gruffnod
								You'll know you've done it right if you see a dust cloud where the <#RED>{name.concept_attack}</> would have hit you. Heck, some <#RED>{name_multiple.concept_relic}</> are even triggered when you <#RED>Perfect {name.concept_dodge}</>!
						]],
					},

					COMBAT_BTN = "Combat lessons!",
					COMBAT_BTN_ALT = "A combat review.",
					COMBAT = {
						HIT_STREAKS_BTN = "Hit Streaks",
						HIT_STREAKS_BTN_ALT = "Hit Streaks, again?",
						HIT_STREAKS = [[
							agent:
								!point
								If you can land multiple <#RED>Attacks</> in a row without receiving <#RED>Damage</> or waiting too long between hits, you'll build something called <#RED>Hit Streak</>.
								!think
								Lots of <#RED>{name_multiple.concept_relic}</> interact with <#RED>Hit Streak</>, so it's worth learning how to rack up the hits if you wanna use them.
								!gruffnod
								If y'find it hard to build or maintain <#RED>Hit Streak</>, you can give yourself a leg up by learning to <#RED>Dodge Cancel</>.
						]],

						FOCUS_HITS_BTN = "Focus Hits",
						FOCUS_HITS_BTN_ALT = "Focus Hits, again?",
						FOCUS_HITS = [[
							agent:
								!gesture
								This one's <i>important</i>-- each <#RED>Weapon Type's</> got conditions for extra-effective <#RED>Attacks</> called <#BLUE>Focus Hits</>.
								!dubious
								It can't be overstated how much yer <#RED>Damage'll</> skyrocket if you can learn to do 'em consistently.
								!point
								So check your <#RED>Weapon's</> <#BLUE>Focus Hit</> conditions by hovering it in your inventory.
								!gruffnod
								You'll know you've performed one correctly if your <#RED>Damage</> numbers turn <#BLUE>Blue</>.
						]],

						CRITICAL_HITS_BTN = "Critical Hits",
						CRITICAL_HITS_BTN_ALT = "Critical Hits, again?",
						CRITICAL_HITS = [[
							agent:
								!point
								<#RED>Critical Hits</> deal double <#RED>Damage</> and appear in <#ATK_CRIT>Pink</>. They happen by random chance when you land an <#RED>Attack</>.
								!gesture
								The likelihood of gettin' them is based on your <#RED>Crit Chance</>, which is affected by your Hunter <#RED>{name_multiple.concept_relic}</> and gear.
								!gruffnod
								Keep in mind, a <#RED>Critical Hit</> is different from a <#BLUE>Focus Hit</>. Landin' <#BLUE>Focus Hits</> is under your direct control.
						]],
					},

					WEAPONS_BTN = "I want a weapon lesson.",
					WEAPONS_BTN_REVIEW = "I want a Weapons review.",
					WEAPONS = {
						HAMMER_BTN = "Hammers",
						HAMMER = {

						},

						SPEAR_BTN = "Spears",
						SPEAR = {

						},

						SHOTPUT_BTN = "Strikers",
						SHOTPUT = {

						},

						CANNON_BTN = "Cannons",
						CANNON = {

						},
					},

					EQUIPMENT_BTN = "Equipment lessons, please.",
					EQUIPMENT_BTN_ALT = "An equipment review, please.",
					EQUIPMENT = {
						WEIGHT_SYSTEM_BTN = "Equipment Weight",
						WEIGHT_SYSTEM_BTN_ALT = "Equipment Weight, again?",
						WEIGHT_SYSTEM = [[
								agent:
									Every piece of gear you equip has a <#RED>Weight</> value, which when added together creates your <#RED>Weight Class</>.
									If your gear total puts you in the <#RED>{name.light_weight} Class</>, you'll take more <#RED>Damage</>, be easier to <#RED>Knockback</>, and have a faster <#RED>Dodge</> with a short invulnerability window.
									If your gear puts you in the <#RED>{name.heavy_weight} Class</>, you'll take less <#RED>Damage</>, be harder to <#RED>Knockback</>, and have a slow <#RED>Dodge</> with a longer invulnerability window.
									The <#RED>{name.medium_weight} Class</> will give you a balanced mix of the two.
									None of the <#RED>Weight Classes</> are better or worse than the others-- it's up to you to find which style suits you best.
							]],

						LUCK_STAT_BTN = "The Luck Stat",
						LUCK_STAT_BTN_ALT = "The Luck Stat, again?",
						LUCK_STAT = [[
								agent:
									!gesture
									Ah yeah, <#RED>Luck's</> an unusual stat. 'Affects a little bit of everything.
									!point
									It can boost yer chances of <#RED>Reviving</> when you should get knocked out, getting rarer <#RED>{name_multiple.concept_relic}</>, getting extra loot from <#RED>{name_multiple.rot}</>, or double <#RED>Healing</>.
									!think
									Maybe even more. {name.dojo_cough}
							]],

						POTIONS_BTN = "Potions",
						POTIONS_BTN_ALT = "Potions, again?",
						POTIONS = [[
								agent:
									!point
									You can drink <#RED>Potions</> with <p bind='Controls.Digital.USE_POTION' color=BTNICON_DARK> to restore a good chunk of yer <#RED>Health</>.
									!agree
									<#BLUE>{name.npc_scout}'ll</> make sure you always got <#RED>1 Potion</> with you when you start a Hunt, but use it sparingly.
									!dubious
									It's better to master <#RED>Dodging</> than it is to count on refills. {name.dojo_cough}
							]],
					},

					REWARD_TIER_ONE = {
						TALK = [[
							!dubious
							...
							!thinking
							Y'know, it's nice to see a Hunter take an interest in their education.
							!giveitem
							Here, have a little treat for completing your first lesson. On me, ghe-he-he.
						]],
					},
					REWARD_TIER_TWO = {
						TALK = [[
							!dubious
							...
							!thinking
							That's what, three lessons you've done now? Yer rocketing up my student ranking list, kid.
							!agree
							And yes, I keep a mental ranking of all my students.
						]],
					},
					REWARD_TIER_THREE = {
						TALK = [[
							!dubious
							...
							!giveitem
							'Ey, kid. {name.dojo_cough} Take this.
							!shrug
							Consider it a gold star for yer studies.
						]],
					},
					REWARD_TIER_FOUR = {
						TALK = [[
							!dubious
							...
							!shocked
							Hunter. {name.dojo_cough}
							!gesture
							You've completed all my lessons. Do you know how often a Hunter completes all my lessons?
							!point
							Not often!
							!dejected
							(Despite attempts to conceal it, <#BLUE>{name.npc_dojo_master}</> is emotional over your graduation.)
						]],

						--[[OPT_1A = "...Are you getting misty-eyed?",
						OPT_1B = "Don't worry {name.npc_dojo_master}, I'll come back for refreshers.",
						OPT_1C = "Thanks for all the lessons, {name.npc_dojo_master}.",

						OPT1A_RESPONSE = [[
							agent:
								!dubious.
								{name.dojo_cough} No. Shut up. {name.dojo_cough} Class dismissed.
						]]--,
						--[[OPT1B_RESPONSE = [[
							agent:
								!dubious
								...
								!gruffnod
								Good.
						]]--,
						--[[OPT1C_RESPONSE = [[
							agent:
								!dejected
								(<#BLUE>{name.npc_dojo_master}</> is definitely emotional over this graduation.)
						]]--,]]]]
					},
				},

				--if you ask toot to teach you something, toot chooses one of these as his sign-off when you say goodbye
				GOODBYE_QUIPS = {
					[[
						!point
						It's easy to regret a swing, but you'll never regret a <#RED>{name.concept_dodge}</>.
					]],
					[[
						!gesture
						You can check your <#RED>Weight Class</> by hitting <p bind='Controls.Digital.OPEN_INVENTORY' color=BTNICON_DARK>.
					]],
					[[
						!gesture
						Changing your gear might change your <#RED>Weight Class</>, so keep an eye out.
					]],
					[[
						!gesture
						Try mixing and matching <#RED>Armour</> sets to get your desired <#RED>Weight Class</>.
					]],
					[[
						!eyeroll
						Kids these days can't get enough of them "<#RED>Emote Wheels</>" <p bind='Controls.Digital.SHOW_EMOTE_RING' color=BTNICON_DARK>.
					]],
					[[
						!point
						<#RED>Fabled Powers</> is more powerful than regular ones-- you can tell them apart by the fancier frames around their icons.
					]],
					[[
						!gruffnod
						Try doing <#RED>Dodge Cancels</> to keep up your <#RED>Hit Streak</>.
					]],
					[[	
						!point
						You'll need a <#RED>Blacksmith</> if you want to improve yer <#RED>Weapons</>.
					]],
					[[
						!shrug
						Gettin' new equipment's just as important as upgrading your old stuff. Maybe even more.
					]],
					[[	
						!point
						Visit an <#RED>Armoursmith</> to improve your <#RED>Armour</>.
					]],
					[[
						!gesture
						Healing's scarce on Hunts. Best not to get hit.
					]],
					[[
						!point
						Didja know smacking objects in the environment keeps yer <#RED>Hit Streak</> going?
					]],
					[[
						!dubious
						A <#RED>{name.beets}</> is dazed after a head slam, so bait and <#RED>{name.concept_dodge}</> before going in for the kill.
					]],
					[[
						!point
						You can swap your equipped gear at the <#RED>Inventory Chest</> here in town. {name.dojo_cough}
					]],
					[[
						!gesture
						You can't change your gear once you set out on a Hunt. {name.dojo_cough} Dress wisely.
					]],
					[[
						!gesture
						Failed Hunts is just learning experiences. {name.dojo_cough}
					]],
					[[
						!point
						Don't forget, it's more imporant to stay alive than it is to strike.
					]],
					[[
						!gruffnod
						Remember, all <#RED>Weight</> builds are viable-- you just gotta find what works for you.
					]],
					[[
						!gruffnod
						All great Hunters started off as newbies trying stuff out. {name.dojo_cough}
					]],
					[[
						!agree
						If you ever feel stuck, try changing up your gear.
						!shrug
						If nothing else, you'll feel snazzy.
					]],
					[[
						!agree
						Gettin' stuck's just an opportunity to try new things.
					]],
					[[
						!dubious
						<#RED>{name_multiple.yammo}</> have melons for brains-- they'll hit their own pals if you bait a swing right.
					]],
					[[
						!dubious
						Be wary of the folks in the woods. {name.dojo_cough}
					]],
					[[
						!point
						You can practice <#BLUE>Focus Hits</> on the dummies here in town.
					]],
					[[
						!gesture
						<#RED>{name_multiple.concept_relic}</> only last for one Hunt. Experiment with yer combinations.
					]],
					[[
						!gesture
						You'll know yer <#RED>Luck</> stat swayed a sitchy-ation if you see a <#RED>Lucky Clover Icon</>.
					]],
					[[
						!gesture
						Gusts of <#RED>Wind</> aren't so bad if you're a <#RED>{name.heavy_weight} Class</> build.
					]],
					[[
						!point
						Every <#RED>Enemy</> is predictable, if you learn to read them.
					]],
					[[
						!point
						Study your foes. Watch their moves. Soon you'll see the openings.
					]],
					[[
						!gesture
						Didja know you can get a <#RED>Critical</> <#BLUE>Focus Hit</>? Powerful stuff.
					]],
					[[
						!greet
						Need a lesson?
					]],
					[[
						!greet
						How're yer studies going? {name.dojo_cough}
					]],
					[[
						!gruffnod
						Need anything explained? Ask away.
					]],
					[[
						!gruffnod
						Hmph. I'm in a teachin' mood today.
					]],
					[[
						!gesture
						Don't forget to review the fundamentals. {name.dojo_cough}
					]],
					[[
						!greet
						Need me to explain anythin'?
					]],
				},

				--same as above, but these ones only appear if youre playing multiplayer
				GOODBYE_QUIPS_MP = {
					[[
						!gruffnod
						If you learn something useful out there, share the tip with your fellow Hunters.
					]],
					[[
						!point
						{name.dojo_cough} Remember that you and other Hunters are working together.
					]],
					[[
						!gesture
						By the way, if yer fighting with allies and get knocked out, try hitting the <#RED>Attack</> and <#RED>{name.concept_dodge}</> buttons.
					]],
					[[
						!gruffnod
						By the way, you can communicate with other Hunters by pressing <p bind='Controls.Digital.TOGGLE_SAY' color=BTNICON_DARK> to chat. {name.dojo_cough}
					]],
				},
			},
		},
		WEAPON_UNLOCKS = {
			twn_unlock_cannon =
			{
				TALK = [[
					agent:
						!bliss
						{name.dojo_cough}
				]],

				OPT_1A = "Hm... You seem in a good mood!",
				OPT_1B = "Got something to say to me?",

				TALK2 = [[
					agent:
						!point
						Good Hunter instinct on ya.
						!gesture
						'Ere. Take this.
				]],

				OPT_2 = "UM. Is this a <i>{name.weapon_cannon}?</i>",

				TALK_GIVE_WEAPON = [[
					agent:
						!agree
						Mhm. An old one mind you, but old things can still pack a punch.
						!point
						Dug it out of some pretty messed up cargo crates.
				]],

				OPT_STARTEXPLAINER = "How do I use it?",
				OPT_SKIPEXPLAINER = "No lessons, I'm testing it out <i>right now!</i>",

				--CANNON EXPLAINER BRANCH START--
				STARTEXPLAINER_RESPONSE = [[
					agent:
						!gesture
						What d'ya need to know?
				]],

				OPT_FIRINGMODES = "Firing modes.",
				OPT_FIRINGMODES_ALT = "Firing modes, again?",
				--
				OPT_RELOADING = "How do I reload?",
				OPT_RELOADING_ALT = "Re-explain reloading for me?",
				--
				OPT_MORTAR = "Does it do anything cool?",
				OPT_MORTAR_ALT = "Tell me about the mortar again!",
				--
				OPT_SKIPINFO = "Nevermind, I can figure it out.",
				OPT_SKIPINFO_ALT = "Okay, I think I get the gist.",

				--CANNON EXPLAINER BRANCH 1--
				FIRINGMODES_RESPONSE = [[
					agent:
						!agree
						Hm, yeah. So, <#RED>{name_multiple.weapon_cannon}</> have two firing modes.
						!gesture
						With <p bind='Controls.Digital.ATTACK_HEAVY' color=BTNICON_DARK> you can shoot small <#RED>Projectiles</> in a wide spread.
						!point
						Your <p bind='Controls.Digital.ATTACK_HEAVY' color=BTNICON_DARK> <#RED>Attack</> also doubles as your <#RED>{name.concept_dodge}</> and pushes you backwards.
						!gesture
						With <p bind='Controls.Digital.ATTACK_LIGHT' color=BTNICON_DARK> you can shoot a big ol' <#RED>Projectile</> that'll do more <#RED>Damage</>, but is also more concentrated.
				]],
				FIRINGMODES_RESPONSE_ALT = [[
					agent:
						!angry
						Sure, but LISTEN UP this time.
						!gesture
						<#RED>{name_multiple.weapon_cannon}</> have two firing modes.
						!point
						With <p bind='Controls.Digital.ATTACK_HEAVY' color=BTNICON_DARK> you can launch yourself backwards and shoot a bunch of small <#RED>Projectiles</> in a big spread.
						!gesture
						With <p bind='Controls.Digital.ATTACK_LIGHT' color=BTNICON_DARK> you'll shoot a big ol' <#RED>Projectile</> that does more <#RED>Damage</>, but it'll also have less spread.
				]],
				--CANNON EXPLAINER 1--

				--CANNON EXPLAINER BRANCH 2--
				RELOADING_RESPONSE = [[
					agent:
						!think
						Reloading can be fiddly if you're new to this puppy.
						!gesture
						Hit <p bind='Controls.Digital.DODGE' color=BTNICON_DARK> to start a reload, then hit <p bind='Controls.Digital.ATTACK_LIGHT' color=BTNICON_DARK> just as your <#RED>{name.weapon_cannon}</> touches the ground to finish'r off.
						!point
						You can practice on the <#RED>Training Dummies</> while you're in camp if you need to.
				]],
				RELOADING_RESPONSE_ALT = [[
					agent:
						!angry
						Okay. {name.dojo_cough} But LISTEN UP now.
						!agree
						Just hit <p bind='Controls.Digital.DODGE' color=BTNICON_DARK>, then hit <p bind='Controls.Digital.ATTACK_LIGHT' color=BTNICON_DARK> as your <#RED>{name.weapon_cannon}</> touches the ground to reload.
				]],
				--CANNON EXPLAINER 2--

				--CANNON EXPLAINER BRANCH 3--
				MORTAR_RESPONSE = [[
					agent:
						!think
						{name.dojo_cough} Hm...
						!shocked
						Right, yes. You can initiate a <#RED>Mortar</> volley by hitting <p bind='Controls.Digital.DODGE' color=BTNICON_DARK>.
						!point
						But you gotta time hitting <p bind='Controls.Digital.ATTACK_HEAVY' color=BTNICON_DARK> as your <#RED>{name.weapon_cannon}</> touches the ground to actually fire it.
						!laugh
						But 'ey, then the last half of your <#RED>Mortar Projectiles</> will all be <#BLUE>Focus Hits</>!
						!agree
						That'll really hit'm where it hurts.
				]],
				MORTAR_RESPONSE_ALT = [[
					agent:
						!dubious
						Heh. I like the enthusiasm.
						!point
						Okay. Hitting <p bind='Controls.Digital.DODGE' color=BTNICON_DARK> will initiate a <#RED>Mortar</> volley.
						!gesture
						Hitting <p bind='Controls.Digital.ATTACK_HEAVY' color=BTNICON_DARK> as your <#RED>{name.weapon_cannon}</> touches the ground will fire the volley.
						!agree
						The last half of a <#RED>Mortar</> volley will all be <#BLUE>{name_multiple.concept_focus_hit}</>.
				]],
				--CANNON EXPLAINER 3--

				--CANNON EXPLAINER BRANCH 4--
				SKIPINFO_RESPONSE = [[
					agent:
						!shrug
						Just you don't blow yourself sky high and I'm happy. Anyway--
				]],
				--CANNON EXPLAINER 4--
				--CANNON EXPLAINER BRANCH END--

				TALK_ALLDONE = [[
					agent:
						!gesture
						Play around, get a knack for it.
						!shrug
						You'll know you've learned well if the <#RED>{name_multiple.rot}</> are dying, but you aren't.
				]],

				--OPT_3A = "This is great. Thanks, {name.npc_dojo_master}.",
				--OPT_3B = "WOOOOO. EXPLOSIONS!",
			},

			twn_unlock_polearm =
			{
				TALK_GIVE_WEAPON = [[
						agent:
							!greet
							Hunter! {name.dojo_cough} Come 'ere.
							!agree
							Good old <#BLUE>{name.npc_scout}</> recovered a cargo crate with that flying whats-it of theirs while you were out. 
							!point
							Just cracked 'er open and it looks like the {name_multiple.foxtails} have <#RED>{name_multiple.weapon_polearm}</> again!
							!gesture
							Here. Try this puppy on for size.
					]],

					OPT_1A = "Don't you want it?",
					OPT_1A_ALT = "Don't you want the {name.weapon_polearm}?",
					OPT_1B = "How do I use it?",
					OPT_1C = "Thanks, {name.npc_dojo_master}! I'll try it out!",
			
					--old flitt response 
					--[[
					OPT1A_RESPONSE =
						agent:
							!disagree
							Oh, uh, I'm not much of a fighter.
							!point
							You'll get more use out of it than I will.
					]]

					OPT1A_RESPONSE = [[
						agent:
							!laugh
							HA-HA! {name.dojo_cough} {name.dojo_cough} {name.dojo_cough}
							!dubious
							And forsake my sweetie girlie, bow 'n' arrow?
							!disagree
							Not a chance.
					]],

					OPT1B_RESPONSE = [[
						agent:
							!gesture
							What, never fought with a <#RED>{name.weapon_polearm}</> before?
							!think
							The most crucial lesson is this: To do a <#BLUE>{name.concept_focus_hit}</> with a <#RED>{name.weapon_polearm}</>, strike an <#RED>Enemy</> with the very tip.
							!point
							You can practice the correct distancing on our <#RED>Training Dummies</> if you need.
							!shrug
							And if you and the <#RED>{name.weapon_polearm}</> don't get along, your <#RED>{name.weapon_hammer}</> will be waiting dutifully in your inventory. {name.dojo_cough}
							!gesture
							Find the weapons that make your soul sing. They're all that stand between a Hunter and death.
					]],

					OPT1C_RESPONSE = [[
						agent:
							!gesture
							'Ey, one more thing. You can't swap gear once <#BLUE>{name.npc_scout}</> takes off for a Hunt.
							!agree
							Keep that in mind when you head out.
					]],
			},
			
			twn_unlock_shotput =
			{
				TALK = [[
					agent:
						!greet
						'Ey, Hunter. Come look what the fox dragged in.
						!gesture
						Try this on for size.
				]],
		
				OPT_1A = "Wow! It's... a ball?",
				OPT_1B = "How do I even use this?",
				OPT_1B_ALT = "Can you tell me how to use it again?", --if you've gone through OPT_1B
				OPT_1C = "Thanks, {name.npc_dojo_master}!",
				OPT_1C_ALT = "Seriously though, thanks {name.npc_dojo_master}.",

				--BRANCH--
				OPT1A_RESPONSE = [[
					agent:
						!point
						A <#RED>Striker</>, actually.
				]],

				OPT_2A = "Haha, I can't believe you gave me a ball.",
				OPT_2B = "Gotta say, it's pretty <i>fetching</i>.",

				OPT2A_RESPONSE = [[
					agent:
						!angry
						{name.dojo_cough} {name.dojo_cough} {name.dojo_cough} It's a <#RED>Striker</>!
				]],

				OPT2B_RESPONSE = [[
					agent:
						!think
						...{name.dojo_cough}
						!shrug
						I could end you.
				]],
				--END BRANCH--

				OPT1B_RESPONSE = [[
					agent:
						!think
						Well when you're up close and personal with a <#RED>{name.rot}</>, you can do a nice reliable punch with <p bind='Controls.Digital.ATTACK_LIGHT' color=BTNICON_DARK>.
						!point
						Chuck a <#RED>Striker</> by hitting <p bind='Controls.Digital.ATTACK_HEAVY' color=BTNICON_DARK>. You've got <#RED>2 Strikers</> total.
						!bliss
						You can do some real awesome moves with these. Like punch'em clean out of the air and into a <#RED>{name.rot}</>'s face!
						!point
						Time your throws and punches to keep a <#RED>Striker</> airborne, and you've got a one-way ticket to <#BLUE>{name.concept_focus_hit}</>-city.
						!disagree
						Once the <#RED>Striker</i> touches the ground though, your <#BLUE>{name.concept_focus_hit}</> streak'll end.
				]],

				OPT1B_RESPONSE_ALT = [[
					player:
						I wasn't listening the first time.
					agent:
						!angry
						Well, LISTEN UP this time!
						!gesture
						'Kay now. Hit <p bind='Controls.Digital.ATTACK_LIGHT' color=BTNICON_DARK> and you'll do a good ol' close quarters punch.
						!point
						Hit <p bind='Controls.Digital.ATTACK_HEAVY' color=BTNICON_DARK> to throw one of your <#RED>2 Strikers</>.
						!agree
						Keepin' the <#RED>Strikers</> airborne will rack up the <#BLUE>{name_multiple.concept_focus_hit}</>, but if one hits the ground, your streak's kaput.
				]],

				OPT1C_RESPONSE = [[
					agent:
						!gruffnod
						{name.dojo_cough} Knock'm dead, Hunter.
				]],

				--only plays if the player did options 1A and 2B, toot reluctantly fires back a pun of his own
				OPT1C_RESPONSE_ALT = [[
					agent:
						!eyeroll
						Go, uh... {name.dojo_cough} <i>have a ball</i> out there.
				]],

				BYE_A = "Ayy!",
				BYE_B = "<i>Toot</i>-a-loo! Hehe.",
			},
		},

		ASCENSIONS = {
			explain_frenzy = {
				TALK = [[
					agent:
						!shocked
						'Ey Hunter! I heard you took down a <#RED>{name.rot_boss}</>!
						!laugh
						Congrats. Don't let no one call you a rookie Hunter ever again!
						!thinking
						...By the by, were you ever taught about <#RED>Frenzy Levels</>?
				]],

				--BRANCH START--
				OPT_1A = "\"Frenzy Levels\"? What's that?",
				OPT_1B = "Pfft of course, that's for babies!",

				--BRANCH 1--
				OPT1A_RESPONSE = [[
					agent:
						!think
						Eh, <#BLUE>{name.npc_scout}</> had a good way of explaining it. How'd it go...
						!gesture
						They said it's like when you chop down a big tree in the forest. All the lil ones underneath are gonna grow to fill its place.
						!point
						When you cut down a <#RED>{name.rot_boss}</>, all the lil <#RED>{name_multiple.rot}</> in the area are gonna get meaner and tougher.
						!shrug
						And you just cut down one <i>heck</i> of a tree.
				]],

				OPT_2A = "Interesting. Tell me more!",
				OPT_2B = "Can you give me a short version of this?",

				OPT2A_RESPONSE = [[
					agent:
						!think
						Eh, from what I understand, killing a <#RED>{name.rot_boss}</> releases all its <#KONJUR>{name.i_konjur}</>. Like popping a water balloon.
						!shrug
						Whenever that balloon is popped it makes <i>all</i> the <#RED>{name_multiple.rot}</> in that area more powerful. We call that a <#RED>Frenzy Level</>.
						!point
						But 'ey, stronger <#RED>{name_multiple.rot}</> just mean more chance to show off the skills I've taught you.
						!gesture
						Plus you'll get <#KONJUR>1 {name.konjur_heart}</> for each <#RED>{name.rot_boss}</> you defeat on a new level.
						!dubious
						Be warned though, <#RED>Reviving</> allies costs <#RED>Health</> on <#RED>Frenzy Level 1</> and above.
				]],

				OPT2B_RESPONSE = [[
					agent:
						!laugh
						Sorry. I'll cut to the chase.
						!gesture
						Because you downed that <#RED>{name.megatreemon}</>, you now have access to the next <#RED>Frenzy Level</> in the <#RED>{name.treemon_forest}</>.
						!dubious
						It'll make enemies more powerful, but you'll also get better stuff for beating them. <#RED>Reviving</> allies costs <#RED>Health</>, though.
						!agree
						You can set an area's <#RED>Frenzy Level</> on the map screen before you head out on a {name.run}.
				]],

				OPT_3A = "Wait... hunting {name_multiple.rot} makes them stronger?!",
				OPT_3B = "I see. Thanks for explaining!", --> leads to TALK_END

				OPT3A_RESPONSE = [[
					agent:
						!think
						Yeah. <#BLUE>{name.npc_scout}</> explained that to me once, too, but I didn't really get it.
						!shrug
						I'm just here to teach you how to hit stuff good.
						!gesture
						You should ask them about their plan to cull the <#RED>{name.rot}</> infestation if you're curious.
				]],
				--1--

				--[[
					agent:
						!laugh
						Well, technically.
						!gesture
						Our ultimate goal is to make the <#RED>{name.rotwood}</> habitable again.
						!point
						A major part of that is culling the <#RED>{name.rot}</> infestation.
						!shrug
						Unfortunately it's not possible to fell <#RED>{name_multiple.rot_boss}</> without also releasing ambient <#KONJUR>{name.i_konjur}</>.
						!point
						But luckily there's a limit on how frenzied <#RED>{name_multiple.rot}</> can get.
						!gesture
						And don't forget, if you invest <#KONJUR>{name_multiple.i_konjur_heart}</> into your equipment, it won't just be the <#RED>{name_multiple.rot}</> who get stronger.
						!point
						I'm more than happy for you to spend some <#KONJUR>{name_multiple.i_konjur_heart}</> on yourself if it means you'll be safer out there.
						!shrug
						I'd encourage it, actually.
				]]

				--BRANCH 2--
				OPT1B_RESPONSE = [[
					agent:
					!dubious
					Ah. So you already know upping your <#RED>Frenzy Level</> gets you better stuff on {name_multiple.run}.
				]],

				OPT_4A = "Actually, I wouldn't mind a mini-refresher.",
				OPT_4B = "And that revivng allies costs Health!",
				
				--sub branch--
				OPT4A_RESPONSE = [[
					agent:
						!agree
						{name.dojo_cough} Right.
						!gesture
						To be short, <#RED>Frenzy Levels</> make <#RED>{name_multiple.rot}</> more powerful on your {name_multiple.run}. But it also makes them drop better loot.
						!point
						More importantly, <#RED>{name_multiple.rot_boss}</> give you <#KONJUR><p img='images/ui_ftf_icons/konjur_heart.tex' rpad=1> 1 {name.konjur_heart}</> for each <#RED>Frenzy Level</> you down them on.
						!dubious
						Also, <#RED>Reviving</> allies costs <#RED>Health</> on <#RED>Frenzy Level 1</> and above.
				]],

				OPT_5 = "Good to know. Thanks {name.npc_dojo_master}.", --> leads to "TALK_END"
				--sub branch end--

				OPT4B_RESPONSE = [[
					agent:
						!gruffnod
						Alright then. You've proven you can handle yourself on the battlefield.
						!greet
						Just don't forget your teachings.
				]],
				--2--
				--BRANCH END--

				TALK_END = [[
					agent:
						!agree
						{name.dojo_cough} Mhm.
						!point
						By the by, you can hunt in <#RED>Frenzy Level 1</> at the <#RED>{name.treemon_forest}</> now.
						!greet
						You can set the level next time you're on the map to head out.
				]],
			},
		},
	},
}
