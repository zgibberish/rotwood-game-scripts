return
{
	--[[
	NOTES FOR WRITERS:
		Your primary speaking character (in this case, Glorabelle), will be named "agent" in dialogue (this is for a codeside purpose). The player character will be named "player"
		Any additional cast you add to a conversation can just be called by their in-game name ("Flitt", "Hamish"), as I'll need to custom add them to the quest file anyway

		Anything that happens in a "dgn" string category is dialogue the character will deliver while in a dungeon-- for example, in the case below, "dgn_meeting_cook" is
		the scene that will play when you meet Glorabelle in the dungeons for the first time. Likewise, anything in the "twn" prefix category is dialogue that
		will play when that character is present in the town

		When referring to the name of a monster, character or material, check the strings_names.lua file to see if the name you want is already in there. If it is,
		make sure to use the loc function {name.codesidename} for singular use, or {name_multiple.codesidename} for plural use rather than hardcoding the name. This will both prevent
		accidental typos in names, inconsistent plural forms, and allow anything that's renamed to be instantly updated throughout the whole project if it's altered in strings_names

		Finally, you can have the character emote if you write !emotename under their dialogue header (ie agent:). Different emotes can be used multiple times in a single conversation, but 
		will only play at the start of the next dialogue line. The full list of emotes can be found in emotes.lua (but depending on the time you're reading this, be aware that some holdovers
		from Griftlands may still exist in the list that are not hooked up-- sorry!)
	]]
	QUESTS =
	{
		twn_fallback_chat =
		{
			QUIP_CHITCHAT = {
				[[
					agent:
						!bliss
						Dont'cha just love the smell of freshly burnt grits?
				]],
				[[
					agent:
						!laugh
						You look like you could use a good hearty feedin'!
				]],
				[[
					agent:
						!clap
						Folks've been calling my cooking "memorable"!
				]],
			},
		},

		primary_dgn_meeting_cook = --<-- Here is dgn_meeting_cook
		{
			--This is how you'll name a quest title. Conversations that don't lead into quests don't need this, and quests with multiple parts will use the same title for the quest's whole duration
			TITLE = "A Culinary Quest",

			--This is the beginning of a single conversation. Each step in the "A Culinary Quest" quest will be written inside the "dgn_meeting_cook" brackets
			invite_to_town =
			{
				--For dialogue that is *not* a clickable player option, write in [[]] brackets like below, and be sure to use the name header of the character who is speaking (agent:/player:)
				TALK_INTRODUCE_SELF = [[
					agent: 
						!greet
						Well howdy there, stranger!
						!dubious
						Are you the one who felled that big ol' nasty <#RED>{name.megatreemon}</>?
				]],

				--[[For clickable player options, separate each option onto their own line like this. OPT_1A = "Me? Huh... I guess I am.",
					I like to name them by the number of the round of options first (1, because this is the first option in the conversation), and a letter
					for each option in the choice (A and B in this case because we have two options)

					Using this naming system will be helpful for me both keeping track of the flow of conversation as I move these into the quest files and
					also for making sure I present the options you write in the correct order

					If there's only one option, only use the number (ie, OPT_1) so I know there aren't missing option strings for me to look for]]
				OPT_1A = "Me? Huh... I guess I am.",
				OPT_1B = "You betcha!",

				--If the next line is just a continuation of the conversation I like to name it the same thing and just add a number on the end
				TALK_INTRODUCE_SELF2 = [[
					agent:
						!laugh
						I knew it!
						!point
						You've just got that air of authority about ya!
				]],

				OPT_2A = "Thanks for noticing!",
				OPT_2B = "R-really?",

				TALK_INTRODUCE_SELF3 = [[
					agent:
						!agree
						Sure as sugar!
						!think
						Say, I reckon a big ol' camp like yours has plenty of mouths what need feedin',
						!bliss
						And I love nothin' more than whipping up big tasty batches of grub!
						!shocked
						Oh, where are my manners?
						!bliss
						The name's {name.npc_cook}, cook for hire.
				]],

				--BRANCH START-- <-Including this comment will let me know the conversation is about to diverge
				OPT_3A = "It'd be great to have a cook!",
				OPT_3B = "Do you have any qualifications?",

				--BRANCH 1--
				--[[If clickable options have different responses rather than bottlenecking into the same response, make sure you include the full
				name of the option that leads into this response in the title (OPT3A_RESPONSE is, of course, the response following OPT_3A)]]
				OPT3A_RESPONSE = [[
					player:
						I <i>have</i> been getting tired of rock soup for dinner.
						You're hired!
					agent:
						[title:SPEAKER]
						[sound:Event.joinedTheParty] 0.5
						!clap
						Great! Just point to wherever you keep the food and leave the rest to me!
						[title:CLEAR]
				]],
				--1--

				--BRANCH 2--
				OPT3B_RESPONSE = [[
					agent:
						!disagree
						Qualifications? Well gosh, I ain't got much in the way of school-learnin'.
						!gesture
						My family are just simple farm folk, but dear old ma taught me everything she knew about cookin' back on the homestead.
				]],
				
				OPT_4 = "What a delightfully rustic answer!", --If branch 2 wasn't encapsulated by the --BRANCH 2-- and --2-- comments, I may not realize that OPT3A_RESPONSE from the branch above doesn't lead into this OPT_4 line (opt_4 is only shown if you doubt Glorabelle's qualifications)
				OPT4_RESPONSE = [[
					player:
						Welcome aboard.
					agent:
						[title:SPEAKER]
						[sound:Event.joinedTheParty] 0.5
						!clap
						Great! Just point to wherever you keep the food and leave the rest to me!
						[title:CLEAR]
				]],
				--2-- 

				--BRANCH END--
				--If there were more dialogue after this point, BRANCH END would signal to me that the dialogue has now bottlenecked again
			},

			--variations on "See ya back at camp"
				QUIP_RENDEZVOUS_IN_TOWN = {
					[[
						agent:
							!clap
							See you back at that big ol' camp of yours!
					]],
				},

			--This is the end of the first conversation in the "A Culinary Quest" quest. twn_function_unlocked will be the next conversation/quest step 
		},

		--this is a multiplayer alternate start to the quest if the player was present when the cook was recruited in the dungeon but they werent the one to do it
		secondary_dgn_meeting_cook = 
		{
			TITLE = "A Culinary Quest",

			TALK = [[
				agent:
					!greet
					Well howdy!
					!think
					Your face looks awful familiar, have we... met before?
			]],

			OPT_1A = "I was there when the other Hunter invited you to be the camp's new cook!", --OPT_1A and OPT1B_RESPONSE both bottleneck into TALK2
			OPT_1B = "Have we?",

			OPT1B_RESPONSE = [[
				agent:
					!scared
					Have... we...?
				player:
					Just kidding. I was there when the other Hunter invited you to join the camp.
			]], --OPT_1A and OPT1B_RESPONSE both bottleneck into TALK2

			TALK2 = [[
				agent:
					!closedeyes
					Oh, good.
					!shocked
					Er, that is, where are my manners? I reckon I ain't never introduced myself!
					!greet
					Name's Glorabelle.
					!bliss
					And there's nothin' I love more in this world than whipping up big tasty batches of grub.
					Just like my dear ol' ma taught me back on the family farm!
				player:
					How delightfully rustic!
				agent:
					!point
					You betcha!
					
			]],

			OPT_2A = "Can you cook something for me?",
			OPT_2B = "Bye, {name.npc_cook}!", --> end convo
			OPT_2B_ALT = "Sounds good! Bye, {name.npc_cook}.",

			OPT2A_RESPONSE = [[
				agent:
					!laugh
					Sure as shootin'!
					!gesture
					My food doesn't just fill your belly, it invigorates your whooole body. As such, my services is open to all you Hunters.
					!shrug
					What with the dangerous nature of your work and all.
					!gesture
					I do ask that you bring your own ingredients back from the hunt.
					!laugh
					There isn't exactly a farmer's market around here!
			]],

			TALK3 = [[
				agent:
					!bliss
					Come on back now!
			]],

		},

		--this is a multiplayer alternate start to the quest if the player wasn't around when the cook was recruited to town (they therefore need to meet her)
		tertiary_twn_meeting_cook = 
		{
			TITLE = "A Culinary Quest",

			TALK = [[
				agent:
					!greet
					Well howdy, stranger! 
					!think
					You're another Hunter, aren't ya?
			]],

			OPT_1A = "I am.",
			OPT_1B = "Wow! How did you know?", --OPT1A and OPT1B both bottleneck into TALK2

			TALK2 = [[
				agent:
					!bliss
					Oh, I can tell. 
					That confident stride? That steely gaze? 
					Shoot, I'd trust you with my safety any old day!
			]],

			OPT_2A = "Thanks for noticing!",
			OPT_2B = "R-really?", --OPT2A and OPT2B both bottleneck into TALK3

			TALK3 = [[
				agent:
					!clap
					Sure as sugar!
					!shocked
					Oh, where are my manners?
					!greet
					Name's Glorabelle, I'm the cook in this here camp.
					!bliss
					There's nothin' I love more in this world than whipping up big tasty batches of grub.
					!agree
					Just like my dear ol' ma taught me back on the family farm!
				player:
					How delightfully rustic!
				agent:
					!point
					You betcha!
					!dejected
					Only trouble is it looks like I can't get this old stove runnin' proper without a <#RED>{name.konjur_soul_lesser}</>.
					!think
					If you get your hands on one while you're out explorin', would ya mind givin' it to me?
			]],

			--player already has a corestone in their inventory and can offer it straight away
			OPT_3A = "A {name.konjur_soul_lesser}... like this one? <i><#RED><z 0.7>(Give {name.konjur_soul_lesser})</></i></z>",

			--player asks for details about what the cook does mechanically
			OPT_3B = "What do I get if I do?",

			--player ends the convo
			OPT_3C = "I'll keep an eye out.", --> go to TALK4

			OPT3A_RESPONSE = [[
				agent:
					!clap
					Why yes, just like that in fact!
					!takeitem
					Great! Now, you just think for a second about what you wanna order.
					!bliss
					I'll get this ol' stove fired up, lickety-split!
			]],

			OPT3B_RESPONSE = [[
				agent:
					!angry
					Did I not just tell--
					!laugh
					Oh golly gosh! Excuse me, I get a little grumpy when I haven't eaten.
					!gesture
					If you bring me a <#RED>{name.konjur_soul_lesser}</> I can whip you up some homemade grub, special.
					!agree
					Not only is it tasty, but it'll keep your body strong when you're out on the hunt.
					!gesture
					So... would you mind?
			]],

			OPT3C_RESPONSE = [[
				agent:
					!bliss
					Thankya kindly!
			]],

			--remind the player what item they need to get
			stone_fetch_reminder = {
				TALK = [[
					agent:
						!dejected
						I'm mighty sorry Hunter, every bone in my body wants to give you a big ol' bowl of somethin'.
						!dejected
						But I ain't allowed to cook for you til I get one of them <#RED>{name_multiple.konjur_soul_lesser}</>.
					player:
						It's okay, {name.npc_cook}. I'll get a <#RED>{name.konjur_soul_lesser}</> soon.
				]],
			},

			--player gives berna a corestone to unlock the shop
			hand_in_stone = {
				TALK = [[
					agent:
						!greet
						Well howdy there, Hunter!
				]],

				OPT_1A = "Hey! Was this what you were looking for? <i><#RED><z 0.7>(Give {name.konjur_soul_lesser})</></i></z>",
				OPT_1B = "Sorry, {name.npc_cook}, gotta jet!",

				OPT1A_RESPONSE = [[
					agent:
						!takeitem
						You found it!
						!gesture
						Great! Now, you just think for a second about what you wanna order.
						!clap
						I'll get this ol' stove fired up, lickety-split!
				]],
			},
		},

		twn_function_unlocked = 
		{
			TITLE = "A Culinary Quest",

			TALK = [[
				agent:
					!bliss
					You've sure got a nice little setup here, real homey!
			]],

			OPT_1 = "How are you settling in?",

			TALK2 = [[
				agent:
					!gesture
					Why, I'm snug as a bug, don't worry your little head about me!
					!point
					Been meanin' to ask though... where do you usually stash your supplies and whatnot?
					!laugh
					Haha, in case I need to go lookin' for ingredients for my tasty recipes, of course!
			]],

			OPT_2 = "I usually keep everything on my person.",

			TALK3 = [[
				agent:
					!dubious
					Do you... sleep with all your supplies? Don't that get heavy?
			]],

			OPT_3A = "Not really.",
			OPT_3B = "<i>I don't sleep.</i>",

			OPT3A_RESPONSE =[[
				player:
					But feel free to help yourself if you need anything.
				agent:
					!agree
					Swell, just swell!
			]],

			OPT3B_RESPONSE = [[
				agent:
					!dubious
					Oh. Okay.
					!laugh
					Uh, I-I mean-- well shucks, don't you worry about it then, sugar! I'll just ask that nice lil fox friend of yours.
			]],

			OPT_4 = "Okey dokey. Bye {name.npc_cook}!",
		},

		unique_convos = 
		{
			UNIQUE_CONVO1 = {
					TALK = [[
						agent:
							Heeyyyy-- er, howdy! What brings you here?
					]],

					OPT = "I'd like to get to know you better!",

					TALK2 = [[
						agent:
							Oh. Uh. Wow, how nice...
					]],

					--BRANCH START--
					OPT_FARMING = "What kind of farming does your family do?",
					OPT_RECIPE = "What was your favorite recipe to make growing up?",

					--BRANCH 1--
					BRANCH1 = {
						RESPONSE = [[
							agent:
							Farming?
						]],

						OPT_1 = "Yeah... didn't you say you and your family were \"farm folk\"?",

						OPT1_RESPONSE = [[
							agent:
								Oh right, yeah, of course! Er... you know, the usual stuff. Corn, radishes... um... kumquats... porcupines...
						]],

						OPT_2 = "Wow. That's an interesting mix.",

						OPT2_RESPONSE = [[
							agent:
								No it's not! It's completely normal stuff for a farm!
						]],

						OPT_3A = "My mistake, you're the expert here!",
						OPT_3B = "If you say so...",
					},
					--1--

					--BRANCH 2--
					BRANCH2 = {
						RESPONSE = [[
							agent:
								Oh, well, uh...
								Y'see, good ol' pops and I cooked up so many tasty things I don't reckon I can pick a favourite!
						]],

						OPT_1 = "Wait, didn't you say it was your mom who taught you everything about cooking?",

						OPT1_RESPONSE = [[
							agent:
								Did I? Right, well... \"pops\" was just, er... a fun nickname I used to call her.
						]],

						OPT_2A = "Oh, that makes perfect sense!",
						OPT_2B = "If you say so...",
					},
					--2--

					--BRANCH END--
					TALK3 = [[
						agent:
							Well, you've probably got way more important things to do than sit and chat with little old me.
							Why don't you mosey on?
					]],

					OPT_END = "Oh, okay?",

					TALK4 = [[
						agent:
							Toodle-oo!
					]],
				},

				UNIQUE_CONVO2 =
				{
					TALK = [[
						agent: 
							The other day {name.npc_armorsmith} complimented my hair... and {name.dojo} patched up a hole in my cart when I never even asked him to!
							What's their angle, huh?!
					]],

					OPT_1A = "It sounds like they were just being nice!",
					OPT_1B = "Maybe it was a try-angle, as in trying to be your friend?",

					TALK2 = [[
						agent:
							Really? Huh... weird.
					]],

					OPT_2 = "Is it just me, or do you sound kind of different today?",

					TALK3 = [[
						agent:
							What? Uh, no! Nope! No-siree! I sound just as charmin'ly folksy as ever, by gum!
					]],

					OPT_3 = "Okay...?",

					TALK4 = [[
						agent:
							Darn tootin'!
					]],
				},
		},

		friendship_quest = 
		{
			TITLE = "Cook Friendship",
			
			PROBLEM_INTRODUCTION =
			{
				TALK = [[
					agent:
						SUNNUVAGUN, THAT'S HOT!!
				]],

				OPT_1A = "Are you okay?",
				OPT_1B = "Whoa, language!",

				TALK2 = [[
					agent:
						Yipes! Where did you come from? C-can't you see I'm busy cookin'?!
				]],

				OPT_2 = "It looks like you're having some trouble.",

				TALK3 = [[
					agent:
						Well it's not my fault the plates get so dang hot when you take them outta the oven!
				]],

				OPT_3 = "Have you tried an oven mitt?",

				TALK4 = [[
					agent:
						A what-now?
				]],

				OPT_5 = "You don't really know a lot about cooking, do you?",

				TALK6 = [[
					agent:
						I... well... the thing is...
				]],

				--BRANCH START--
				OPT_KIND = "Don't worry, I won't tell anyone.",
				OPT_JERK = "Wait until everyone hears about this!",

				--BRANCH 1--
				KIND = {
					RESPONSE = [[
						agent:
							What? Wait... really?
					]],

					OPT_1A = "Really.",
					OPT_1B = "Just kidding! Wait until everyone hears about this! ", --redirects to other branch

					OPT1A_RESPONSE = [[
						agent =
							But... I lied to you!
						player:
							Yeah, you really shouldn't have lied. But I forgive you.
						agent:
							...Why?
						player:
							Real cook or not, you're part of the {name_multiple.foxtails}, and we stick together!
						agent:
							Wow. You really mean it, don't you?
					]],

					OPT_2 = "You bet!",

					OPT2_RESPONSE = [[
						agent:
							Excuse me, Hunter. I have a lot to think about...
					]],
				},
				--1--

				--BRANCH 2--
				JERK = {
					RESPONSE = [[
						agent:
							H-hang on a second! Okay, fine, you're right, just please don't tell anyone!
					]],

					OPT_1A = "Fine, I won't tell anyone.",
					OPT_1B = "No promises!",
				},
				--2--

				--BRANCH END--
			},

			--this character has an extra conversation that can occur if the player didn't agree to keep Glorabelle's secret in the last convo
			PROBLEM_INTRODUCTION2 = 
			{
				TALK = [[
					agent:
						Can we talk? Er... away from any prying ears?
				]],

				BERNA_NEARBY = [[
					BERNA:
						Hey, I was only listening a little bit!
				]],

				OPT_1A = "Sure thing!",
				OPT_1B = "I guess so.",

				TALK2 = [[
					agent:
						Nobody's been talking about \"the cook who can't cook,\" so I'm guessing you didn't tell anyone about my little secret.
				]],

				OPT_2A = "It wasn't my secret to tell.",
				OPT_2B = "I honestly kind of forgot about it.",

				OPT2_RESPONSE = [[
					agent:
						Right... so out with it. What do you want?
				]],

				OPT_3 = "Huh?",

				OPT3_RESPONSE = [[
					agent:
						Nobody keeps a secret without wanting something in return.

					player:
						I think you're confusing \"keeping a secret\" with \"blackmail\".

					agent:
						Not much of a difference, in my experience.

					player:
						That's kind of sad. Don't worry, I'm not going to blackmail you.

					agent: ...Why?
				]],

				--BRANCH START--
				OPT_4A = "It's not my secret to tell. Simple as that.",
				OPT_4B = "We stick together!",

				--BRANCH 1--
				OPT4A_RESPONSE = [[
					agent:
						Wow. You really mean it, don't you?
					player:
						You bet!
				]],
				--1--

				--BRANCH 2--
				OPT4B_RESPONSE = [[
					player:
						Real cook or not, you're part of the {name_multiple.foxtails}.
					agent:
						Wow. You really mean it, don't you?
					player:
						You bet!
				]],
				--2--

				--BRANCH END--
				TALK3 = [[
					agent: 
						...
					player:
						See you later!
				]],
			},

			QUEST_OFFER = {
				TALK1 = [[
					agent:
						Hunter! I messed up, I really messed up!
				]],

				OPT_1 = "Huh? What happened?",

				--NOTE: Berna is a placeholder, this should be replaced with whoever is nearby
				TALK2 = [[
					berna:
						Hey, has anybody seen my {Item}? I could've sworn we were all stocked up on {Items}...
					agent:
						Look, you were right when you said I don't really know anything about cooking, but... um--
						--there might have been some other things I wasn't completely honest about too.
				]],

				OPT_2 = "Like what exactly?",

				TALK3 = [[
					agent:
						It's kind of a long list, but let's start with what I actually came here for.
				]],

				OPT_3 = "Oh I already figured that out - you came here to make friends!",

				TALK4 = [[
					agent:
						To steal stuff. I came here to steal stuff.
				]],

				OPT_4A = "Wait, WHAT?",
				OPT_4B = "Ah... that actually makes a lot of sense.",

				TALK5 = [[
					agent:
						When I heard a group of adventurers were going out to the Rotwood, I figured they'd probably haul in lots of rare, valuable stuff.
						And I thought... why not see if I could get my hands on a piece of it?
						I had it all planned out--
						--I'd join your camp, bide my time until I figured out where you kept everything stashed, then make a clean getaway.
				]],

				OPT_5 = "But you're still here--",

				TALK6 = [[
					player:
						That means you didn't go through with it, right?
					agent:
						Er...
					player:
						Right?
					agent:
						I might've... <i>liberated</i> some things and headed out last night...
				]],

				OPT_6A = "What?! But... you're a {name.foxtails}!",
				OPT_6B = "I thought we were friends!",

				TALK7 = [[
					agent:
						But I couldn't go through with it, okay? All your stupid niceness and trustworthiness infected me!
						I was already on my way back when I ran into some {name_multiple.rot}, and, well... I couldn't exactly run with all that stuff weighing me down, so...
				]],

				OPT_7 = "You left it all in the woods? Surrounded by monsters??",

				TALK8 = [[
					agent:
						Basically. I know you have no reason to believe me, but I thought you at least deserve to know what happened before I go.
				]],

				OPT_8 = "Wait, where are you going?",

				TALK9 = [[
					agent:
						I have to leave camp! There's no way I can get all that stuff back, and it's only a matter of time before everyone figures out I'm the thief!
						I lied to everyone... I don't deserve to stay with the {name_multiple.foxtails}.
				]],

				--BRANCH START--
				OPT_9A = "What if I helped you return everything you took?",
				OPT_9B = "I think I need a minute to take this in. Don't go anywhere yet, okay?",

				--BRANCH 1--
				OPT9A_RESPONSE = [[
					agent:
						But there's no way you'll be able to find it all!
					player:
						Wanna bet? Just give me a list of what to look for!
					agent:
						...Fine. But I'm keeping my bags packed for when you come to your senses and give up.
				]],
				--1--

				--BRANCH 2--
				OPT9B_RESPONSE = [[
					agent:
						No promises.
				]],
				--2--
				--BRANCH END--
			},

			QUEST_RESOLUTION = {
				TALK = [[
					agent:
						You did it? You really did it! You found everything, I can't believe it!
				]],

				OPT_1A = "I can hardly believe it myself.",
				OPT_1B = "Hey, you don't have to sound that surprised!",

				TALK2 = [[
					agent:
						Now I can put everything back where it belongs, and nobody has to know about what happened!
						But wait, why does that still feel bad?
				]],

				OPT_2 = "You could always try telling them the truth?",

				TALK3 = [[
					agent:
						HA! Good one!
					player:
						Worth a shot.
					agent:
						Seriously though, thank you for giving me another chance. I'm gonna do things differently from now on.
						Starting with this... I actually worked really hard on it!
						Seeya 'round!
				]],
			},
		},

		twn_shop_cook =
		{
			resident =
			{
				TALK_RESIDENT = [[
					agent:
						!greet
						Your raids leaving you hungry for a win?
						!agree
						I've got just the thing for you!
				]],
		
				OPT_SHOP = "Show me what you got!",
		
				OPT_HOME = "About your kitchen...",
				TALK_HOME = [[
					agent:
						What about it, hon?
				]],
		
				OPT_UPGRADE = "Let's upgrade it",
				OPT_MOVE_IT = "Let's move it",
		
				DISCUSS_UPGRADE = [[
					agent:
						Wowee!
						I appreciate you going out on a limb for me like this.
						This little camp's gonna be eating good tonight, I can tell you that much!
				]],
		
				TALK_MOVED_HOME = [[
					player:
						There, that should do it.
					agent:
						They say the restaurant business is all about location, location, location.
				]],
			},

			minigame =
			{
				TALK_MINIGAME  = [[
					agent:
						<#RED>Potion</> runnin' low?
						Lemme stir this up and we'll get that bottle filled. Just takes a little {primary_ingredient_name}.
				]],
		
				OPT_CONFIRM  = "<#RED>[Refill Potion]</> Let's do it!",
			},

			done =
			{
				TALK_DONE_GAME  = [[
					agent:
						Safe wanderin'!
						Seems I'm runnin' dry on supplies. Gonna have to rustle up some 'fore we can get cookin' again.
				]],
		
				OPT_CONFIRM  = "See ya!",
			},
		},
	},
}
