return
{
	QUESTS =
	{
		twn_fallback_chat =
		{
			QUIP_CHITCHAT = {
				[[
					agent:
						!disagree
						Hrm. Ye've got naught for me, I see.
				]],
				[[
					agent:
						!point
						Yer wee armourer's been snoopin' round me forge again.
				]],
				[[
					agent:
						!gruffnod
						'Tis a fine forge ye've got here.
				]],
			},
		},

		primary_dgn_meeting_blacksmith =
		{
			TITLE = "Hammer Home",

			invite_to_town =
			{
				-- Use narration (*) to indicate the player's inner monologue.
				TALK = [[
					agent:
						...
					player:
						<i>(That's <#RED>{name.npc_blacksmith}</>, the {name.job_blacksmith}!)</i>
						{name.npc_blacksmith}!
				]],

				OPT1_RESPONSE = [[
					player:
						I'm so glad you weren't hurt in the crash.
					agent:
						!dubious
						...Who are ye?
						!think
						Ah. I remember ye now.
						!point
						Ye were the one that kept screamin' as the ship went down.
				]],

				OPT_2A = "I knew you'd remember me!",
				OPT_2B = "Uh no, you must be thinking of {name.npc_scout}.",

				TALK2 = [[
					agent:
						!point
						Wailin' like a wee bairn, ye were.
				]],

				OPT2A_RESPONSE = [[
					player:
						Haha right, well uh-- {name.npc_scout}'s waiting to take you back to camp.
				]],

				OPT2B_RESPONSE = [[
					player:
						Moving on... {name.npc_scout}'s waiting to take you back to camp.
				]],

				TALK3 = [[
					agent:
						[title:SPEAKER]
						[sound:Event.joinedTheParty] 0.5
						!gruffnod
						Hrm. Aye. I'll be seein' ye at camp then.
						[title:CLEAR]
				]],
			},

			--variations on "See ya back at camp"
			QUIP_RENDEZVOUS_IN_TOWN = {
				[[
					agent:
						!gruffnod
						Hrm. Aye. I'll be seein' ye at camp then.
				]],
				[[
					agent:
						!gruffnod
						Go on, then. I'll make me way to th' camp.
				]],
			},
		},

		--this is a multiplayer alternate start to the quest if the player was present when the blacksmith was recruited in the dungeon but they werent the one to do it
		secondary_dgn_meeting_blacksmith = 
		{
			TITLE = "Hammer Home",

			TALK = [[
				agent:
					!think
					Hrm. I remember ye now. One of them Hunters from th'forest, are ye?
			]],

			OPT_1A = "Sure am!",
			OPT_1B = "It's nice to have a chance to talk.",

			TALK2 = [[
				agent:
					!gruffnod
					Figured ye'd be needin' me services sooner or later.
			]],

			OPT_2 = "What do you make here?",
				
			TALK3 = [[
				agent:
					!point
					Weapons only.
					<#RED>Hammers</>, <#RED>Spears</>, <#RED>Cannons</>, <#RED>Strikers</>.
					!agree
					Aye, yes.
					!point
					Your job's solicitin' the materials.
					!gruffnod
					I'll be handlin' the rest.
			]],

			OPT_3A = "Neato. Anything else I should know?",
			OPT_3B = "Great! See you around, {name.npc_blacksmith}!", --> end convo

			OPT3A_RESPONSE = 
			[[
				agent:
					!think
					It ain't my primary trade, but I can set <#RED>{name_multiple.gem}</> if ye like.
					!point
					Imbue yer weapons with <#RED>Bonuses</> fer some extra <i>oompf</i>.
				player:
					Ooo, weapon inlaying! I'll keep an eye out for <#RED>{name_multiple.gem}</>.
				agent:
					!gesture
					Grand.
			]],		

			OPT3B_RESPONSE = [[
				agent:
					!gruffnod
					Aye.
			]],
		},

		--this is a multiplayer alternate start to the quest if the player wasn't around when the blacksmith was recruited to town (they therefore need to meet him)
		tertiary_twn_meeting_blacksmith = 
		{
			TITLE = "Hammer Home",

			TALK = [[
				agent:
					!think
					...
				player:
					You're {name.npc_blacksmith}, right?
				agent:
					!gruffnod
					Aye.
				player:
					I heard your blacksmithing skills are pretty sharp!
				agent:
					!dubious
					...
			]],
			
			--opt 1B remains available even if you've chosen 1A first
			OPT_1A = "Er... forget I said that. Please.",
			OPT_1B = "So, what do you make here?",

			OPT1A_RESPONSE = [[
				agent:
					!gruffnod
					Aye. I think I will.
			]],

			--NOTE: Hamish doesn't need the corestone to make the forge work, he needs a source of power from each Hunter who wants to use his forge to prevent overburdening the town (sort of like a rite of passage-- kill a yammo to earn your weapon forging)
			OPT1B_RESPONSE = [[
				agent:
					!point
					Weapons only.
					<#RED>Hammers</>, <#RED>Spears</>, <#RED>Cannons</>, <#RED>Strikers</>.
					!think
					'Cept there's a wee problem.
				player:
					What's that?
				agent:
					!gesture
					I need a <#RED>{name.konjur_soul_lesser}</> from ye.
					Ye want weapons?
					!point
					Bring back a stone.
			]],

			--option to hand it in immediately if you already have one
			OPT_2A = "A {name.konjur_soul_lesser}... like this one? <i><#RED><z 0.7>(Give {name.konjur_soul_lesser})</></i></z>",
			--ask why you need a corestone to be able to get weapons
			OPT_2B = "Why do you need a {name.konjur_soul_lesser} to make weapons?",
			OPT_2C = "I'm on it!", -->end convo

			OPT2A_RESPONSE = [[
				agent:
					!takeitem
					...hm...
					!dubious
					Aye, that's a <#RED>{name.konjur_soul_lesser}</>.
					!gruffnod
					Let me fire th'forge.
			]],

			OPT2B_RESPONSE = [[
				agent:
					I don't need it ta make weapons.
					!point
					I need it to make <i>you</i> weapons.
			]],

			-->!! reinsert 2A and its response at the top of this menu
			--lore option
			OPT_3A = "I don't understand.",
			OPT_3B = "{name.konjur_soul_lesser}. I'm on it.", -->end convo

			OPT3A_RESPONSE = [[
				agent:
					<i>({name.npc_blacksmith} makes a grunt that is impossible to interpret.)</i>
					!gesture
					Th'town's low on resources.
					!point
					{name.npc_scout} wants each and every Hunter ta provide th'power for their own forgin'.
					!gruffnod
					I follow {name.npc_scout}'s orders.
			]],

			END = [[
				agent:
					!agree
					Aye.
			]],

			--remind the player what item they need to get
			stone_fetch_reminder = {
				TALK = [[
					agent:
						!gesture
						I canna make you weapons 'til you bring me a <#RED>{name.konjur_soul_lesser}</>.
					player:
						<#RED>{name.konjur_soul_lesser}</>. Right. I'll be back.
				]],
			},

			--player gives berna a corestone to unlock the shop
			hand_in_stone = {
				TALK = [[
					agent:
						!gruffnod
						...
				]],
				
				OPT_1A = "Hey {name.npc_blacksmith}, was this what you wanted? <i><#RED><z 0.7>(Give {name.konjur_soul_lesser})</></i></z>",
				OPT_1B = "Carry on.",

				OPT1A_RESPONSE = [[
					agent:
						!takeitem
						...hm...
						!agree
						Aye, that's a <#RED>{name.konjur_soul_lesser}</>.
						!gruffnod
						Let me fire th'forge.
				]],
			},
		},

		--the player came in during multiplayer and missing the intro flitt dialogue about the crashed damselfly
		--as a result they dont have the quest to recruit the blacksmith but can still meet him in the forest to recruit him anyway
		--ie "Oh, you're with the Foxtails! Can you help me back to camp"
		tertiary_alt_dgn_meeting_blacksmith =
		{
			TALK = [[
				agent:
					...
				player:
					<i>(This guy looks familiar. I think I've seen him at {name.foxtails} meetups back in the Brinks.)</i>
					Hey, are you with the {name_multiple.foxtails}?
				agent:
					!dubious
					...
					!gruffnod
					Aye. I'm {name.npc_blacksmith}, the {name.job_blacksmith}.
					!point
					You appear t'be a Hunter.
			]],

			OPT_1 = "Yep! ...What're you doing out here?",

			TALK2 = [[
				agent:
					!agree
					Waitin' fer a rescue.
			]],

			OPT_2 = "Um... should I tell {name.npc_scout} you're here?",

			TALK3 = [[
				agent:
					!point
					Aye, that'd be ideal.
					[title:SPEAKER]
					[sound:Event.joinedTheParty] 0.5
					!gruffnod
					Thank ye.
					[title:CLEAR]
			]],

		},

		twn_function_unlocked = 
		{
			TITLE = "Hammer Home",

			TALK = [[
				agent:
					...
				player:
					You made it!
				agent:
					!gesture
					O'course I did.
					!dubious
					But enough o'the bletherin'. Th'forge is up and ready.
			]],

			OPT_1A = "What do you make?",
	
			OPT1A_RESPONSE = [[
				agent:
					!dubious
					...
					!point
					Weapons only.
					!think
					<#RED>Hammers</>, <#RED>Spears</>, <#RED>Cannons</>, <#RED>Strikers</>.
					!agree
					Aye, yes.
					!point
					Your job's solicitin' the materials.
					!gruffnod
					I'll be handlin' the rest.
			]],

			OPT_2 = "Neato. Anything else I should know?",
			OPT2_RESPONSE = [[
				agent:
					!think
					It ain't my primary trade, but I can set <#RED>{name_multiple.gem}</> if ye like.
					!point
					Imbue yer weapons with <#RED>Bonuses</> fer some extra <i>oompf</i>.
				player:
					Ooo, weapon inlaying! I'll keep an eye out for <#RED>{name_multiple.gem}</>.
				agent:
					Grand.
			]],

			OPT_3 = "Great! See you around, {name.npc_blacksmith}!",
		},

		twn_gem_intro =
		{
			TITLE = "Shine On",
			gem_tips =
			{
				GEM_INTRO = [[
					agent:
						!dubious
						Hunter.
						!giveitem
						Take these.
						!gruffnod
						Ye'd be wise to learn how ta use them.
				]],

				OPT_GEM = "Woah, Weapon {name_multiple.gem}!",
			}
		},

		twn_weapon_weight_explainer = {
			TALK = [[
				agent:
					!dubious
					...Hunter.
			]],

			OPT_1 = "Yeah?",

			TALK2 = [[
				agent:
					!gesture
					Do ye know about <#RED>Weapon Weight</>?
			]],

			OPT_2A = "I wouldn't mind some tips.",
			OPT_2B = "Yeah. Weight affects speed and damage.",

			OPT2A_RESPONSE = [[
				agent:
					!gruffnod
					Aye, then. Ahem. Heavy weapons?
					!point
					Hefty. They do more <#RED>Damage</>.
					!dubious
					Light weapons? Less <#RED>Damage</>.
					!point
					Fast though. Less risky to commit to an <#RED>Attack</>.
					!shrug
					Normal weapon? Eh. Balanced.
			]],

			OPT2B_RESPONSE = [[
				agent:
					!dubious
					...Aye.
					!gruffnod
					As ye were.
			]],

			OPT_3A = "Is that all?",
			OPT_3B = "Thanks for explaining.",


			TALK3 = [[
				agent:
					!dubious
					...
					!gruffnod
					Aye.
			]],
		},

		twn_shop_weapon =
		{
			resident =
			{
				TALK_RESIDENT = [[
					agent:
						!greet
						Point at whatcha want and I'll forge it-- if ye can provide th'parts, that is.
				]],
		
				OPT_SHOP = "Show me what you got!",
				OPT_GEM = "I want to change my gems.",
		
				OPT_HOME = "About your forge...",
				TALK_HOME = [[
					agent:
						Eh? What of it?
				]],
		
				OPT_UPGRADE = "Let's upgrade it",
				OPT_MOVE_IT = "Let's move it",
		
				DISCUSS_UPGRADE = [[
					agent:
						(grunt)
					player:
						What's that mean? Good? Bad?
					agent:
						!gruffnod
						Good.
						Very good.
						You and I are going to make some serious sharp objects, ma freen.
					player:
						Aaaand he's talking to the forge. Bye {name.npc_blacksmith}!
				]],
		
				TALK_MOVED_HOME = [[
					player:
						There. That work for you?
					agent:
						Mphm.
					player:
						I assume that means yes.
				]],
			}
		}
	}
}
