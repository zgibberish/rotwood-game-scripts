return
{
	QUESTS =
	{
		twn_meeting_dojo = 
		{
			TITLE = "Fighting Chance",
			DESC = "{name.npc_dojo_master} has returned to town! He could use some help getting set up.",

			talk_in_town =
			{
				TEMP_INTRO = [[
					agent:
						!gesture
						{name.dojo_cough}
						!greet
						Hey, how d'you do, Hunter? I'm glad this <#RED>Playtest</> gave me a chance to meetcha.
						!gesture
						I'm <#BLUE>{name.npc_dojo_master}</>, the <#RED>{name.job_dojo}</>.
						!think
						I came on this expedition to give you some challenges and toughen you up, but, uh--
						!point
						'Looks like those <#RED>Game Systems</> haven't been implemented yet.
						!laugh
						In the meantime, maybe I'll teach you how to use whatever weapons we find! {name.dojo_cough}
				]],

				TEMP_OPT = "Cool. Nice to meet you, {name.npc_dojo_master}!",

				TEMP_INTRO2 = [[
					agent:
						[title:SPEAKER]
						[sound:Event.joinedTheParty] 0.5
						!dubious
						Phew. It was quite the fight gettin' home, y'know!
						!agree
						Time for this old dog to take a nap.
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
						!point
						Hey. I'm <i>old</i>, fox.
					flitt:
						!gesture
						Hunter! Good timing. I don't think you've formerly met {name.npc_dojo_master}.
				]],

				OPT_1A = "So, you're our {name.job_dojo}?",
				OPT_1B = "How'd you make it back to camp?",

				OPT1A_RESPONSE = [[
					agent:
						!agree
						{name.dojo_cough} --In the flesh.
				]],
				OPT1B_RESPONSE = [[
					agent:
						!shrug
						{name.dojo_cough} --Fought my way.
				]],

				TALK2 = [[
					flitt:
						!point
						{name.npc_dojo_master}'s a former Hunter like yourself.
						!gesture
						He's come along on our expedition to provide supplementary training for our Hunter recruits.
					agent:
						!gesture
						{name.npc_scout} probably steered you well in my absence.
						!agree
						But if you want heftier lessons, come and see me.
						!laugh
						If you're worth your salt, I might even give you a challenge or two.
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
			resident =
			{
				-- Strings
				TALK_RESIDENT = [[
					agent:
						!gesture
						{name.dojo_cough}
				]],

				OPT_SHOP = "Teach me somethin', {name.npc_dojo_master}.",
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
						Your <p bind='Controls.Digital.ATTACK_HEAVY' color=BTNICON_DARK> <#RED>Attack</> also doubles as your <#RED>Dodge</> and pushes you backwards.
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
						But hey, then the last half of your <#RED>Mortar Projectiles</> will all be <#BLUE>Focus Hits</>!
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
							Good old {name.npc_scout} recovered a cargo crate with that flying ma-jigger of theirs while you were out. 
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
							Hey, one more thing. You can't swap gear once {name.npc_scout} takes off.
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
						By the by, were you ever taught about <#RED>Frenzy Levels</>?
				]],

				--BRANCH START--
				OPT_1A = "\"Frenzy Levels\"? What's that?",
				OPT_1B = "Pfft of course, that's for babies!",

				--BRANCH 1--
				OPT1A_RESPONSE = [[
					agent:
						!think
						Eh, {name.npc_scout} had a good way of explaining it. How'd it go...
						!gesture
						They said it's like when you chop down a big ol' tree in the forest. All the lil ones underneath are gonna grow to fill its place.
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
						Eh, from what I understand, killing a <#RED>{name.rot_boss}</> releases all its <#KONJUR>{name.konjur}</>. Like popping a water balloon.
						!shrug
						Whenever that balloon is popped it makes <i>all</i> the <#RED>{name_multiple.rot}</> in that area more powerful. We call that a <#RED>Frenzy Level</>.
						!point
						But hey, stronger <#RED>{name_multiple.rot}</> just mean more chance to show off the skills I've taught you.
						!gesture
						Plus you'll get <#KONJUR>1 {name.konjur_heart}</> for each <#RED>{name.rot_boss}</> you defeat on a new level.
				]],

				OPT2B_RESPONSE = [[
					agent:
						!laugh
						Sorry. I'll cut to the chase.
						!gesture
						Because you downed that <#RED>{name.megatreemon}</>, you now have access to the next <#RED>Frenzy Level</> in the <#RED>{name.treemon_forest}</>.
						!dubious
						It'll make enemies more powerful, but you'll also get better stuff for beating them.
						!agree
						You can set an area's <#RED>Frenzy Level</> on the map screen before you head out on a {name.run}.
				]],

				OPT_3A = "Wait... hunting {name_multiple.rot} makes them stronger?!",
				OPT_3B = "I see. Thanks for explaining!", --> leads to TALK_END

				OPT3A_RESPONSE = [[
					agent:
						!think
						Yeah. {name.npc_scout} explained it to me once but I didn't really get it.
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
						Unfortunately it's not possible to fell <#RED>{name_multiple.rot_boss}</> without also releasing ambient <#KONJUR>{name.konjur}</>.
						!point
						But luckily there's a limit on how frenzied <#RED>{name_multiple.rot}</> can get.
						!gesture
						And don't forget, if you invest <#KONJUR>{name_multiple.konjur_heart}</> into your equipment, it won't just be the <#RED>{name_multiple.rot}</> who get stronger.
						!point
						I'm more than happy for you to spend some <#KONJUR>{name_multiple.konjur_heart}</> on yourself if it means you'll be safer out there.
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
				OPT_4B = "Yep! Bye, {name.npc_dojo_master}!",
				
				--sub branch--
				OPT4A_RESPONSE = [[
					agent:
						!agree
						{name.dojo_cough} Right.
						!gesture
						To be short, <#RED>Frenzy Levels</> make <#RED>{name_multiple.rot}</> more powerful on your {name_multiple.run}. But it also makes them drop better loot.
						!point
						More importantly, <#RED>{name_multiple.rot_boss}</> give you <#KONJUR>1 {name.konjur_heart}</> for each <#RED>Frenzy Level</> you down them on.
				]],

				OPT_5 = "Good to know. Thanks {name.npc_dojo_master}.", --> leads to "TALK_END"
				--sub branch end--

				OPT4B_RESPONSE = [[
					agent:
						!greet
						Don't forget what I've taught you.
				]],
				--2--
				--BRANCH END--

				TALK_END = [[
					agent:
						!agree
						{name.dojo_cough} Mhm.
						!point
						By the by, you can now hunt in <#RED>Frenzy Level 1</> at the <#RED>{name.treemon_forest}</>.
						!greet
						You can set the level next time you're on the map to head out.
				]],
			},
		},
	},
}
