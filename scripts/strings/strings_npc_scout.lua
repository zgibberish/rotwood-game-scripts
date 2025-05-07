return
{
	QUIPS =
	{
		quip_scout_generic =
		{
			[[
				!gesture
				Just hop in the <#RED>{name.damselfly}</> when you're ready to head out.
			]],
			[[
				!gesture
				The <#RED>{name.damselfly}</> is waiting when you're ready.
			]],
		},

		--HELLOWRITER-- hook up friendlychat quips
		--friendly chats are low priority conversations that have no bearing on progression and arent relationship-related cutscenes. they just serve to get to know the character better
		twn_friendlychat = {
			SETUP = {
				QUIP_END_RESPONSE = {
					[[
						agent:
							!agree
							Yeah, me too.
					]],
					[[
						agent:
							!agree
							Sounds good.
					]],
					[[
						agent:
							!greet
							See ya.
					]],
					[[
						agent:
							!agree
							Be safe.
					]],
					[[
						agent:
							!agree
							Careful out there.
					]],
					[[
						agent:
							!greet
							Nice chatting.
					]],
				},
			},	
		},

		twn_tips_scout =
		{
			tutorial_glitz =
			{
				TALK_GO_CUSTOMIZE = [[
					agent:
						!greet
						Oh, hey Hunter-- have you had a chance to check out the little <#BLUE>Vanity Mirror</> to the right of <#BLUE>{name.npc_dojo_master}</>?
						!gesture
						You can use it to customize your hair, your colours... even your species!
						!shrug
						One of the many perks of existing inside a <#RED>Game</>, huh?
						!gesture
						Why don't you try it out? I'll give you a little somethin' for your time if you do.			
				]],

				OPT_1A = "Ooo, sounds fun!",
				OPT_1B = "Pfft, I look great already.",

				OPT1A_RESPONSE = [[
					agent:
						!greet
						Enjoy!
				]],

				OPT1B_RESPONSE = [[
					agent:
						!point
						Haha. No argument here.
						!shrug
						Anyway, the mirror's there if you want it.
				]],

				TALK_DONE_CUSTOMIZE = [[
					agent:
						!shocked
						Hey, I can tell you used the mirror! You sure look...
						!clap
						Like a Hunter!
						!closedeyes
						I know things like customization aren't strictly necessary to the {name_multiple.foxtails}' mission, but I hope to make living here as homey as possible.
						!gesture
						Thanks for humouring me.
						!point
						As promised, here's a bit of <#KONJUR>{name.glitz}</>. You can use it to buy new <#RED>Cosmetics</>!
				]],

				OPT_END = "Thanks, {name.npc_scout}!",
				END_RESPONSE = [[
					agent:
						!laugh
						Don't spend it in one place!
				]],
			},

		},

		dgn_tips_scout =
		{
			DODGE_NO_CANNON =
			{
				[[
					agent:
						!greet
						Be cautious against the <#RED>{name_multiple.rot}</> in there.
						!scared
						If one looks like it's about to <#RED>Attack</>, press <p bind='Controls.Digital.DODGE' color=BTNICON_DARK> to <#RED>Dodge</> out of the way.
						!bliss
						You'll roll a short distance and even be <#RED>Invincible</> for a little bit.
						!agree
						Heck, if you're stylish you can even wait until the very last moment before getting hit to roll away.
						!point
						That's called a <#RED>Perfect Dodge</>.
					player:
						So press <p bind='Controls.Digital.DODGE' color=BTNICON_DARK> to <#RED>Dodge</> when things try to bite me. Got it.
				]],
				[[
					agent:
						!greet
						You've heard of <#RED>Dodge Cancels</>, right?
						!gesture
						Once you start an <#RED>Attack</> you've gotta see it through... which means you won't be able to move while you're performing it.
						!point
						But if you <#RED>Dodge Cancel</>, you can start moving again early <i>and</i> still get your <#RED>Attack</> off!
					player:
						How do I do that?
					agent:
						!agree
						Easy! Just <#RED>Dodge</> (<p bind='Controls.Digital.DODGE' color=BTNICON_DARK>) during an <#RED>Attack</>!
						!dubious
						Keep in mind, <#RED>Attacks</> that are heavier or take longer to perform usually have smaller <#RED>Cancel Windows</>.
						!shrug
						That means you'll need more precise timing.
						!clap
						But a <#RED>Dodge</> (<p bind='Controls.Digital.DODGE' color=BTNICON_DARK>) will always get you out of danger quicker than running.
					player:
						So just <#RED>Dodge</> (<p bind='Controls.Digital.DODGE' color=BTNICON_DARK>) after I <#RED>Attack</> to <#RED>Dodge Cancel</>? Pfft, easy!
				]],
			},

			HAMMER =
			{
				[[
					agent:
						!think
						Hey, do you know about <#BLUE>{name_multiple.concept_focus_hit}</>?
						!gesture
						Each weapon has special conditions for a <#RED>High-Damage Attack</> called a <#BLUE>{name.concept_focus_hit}</>.
						!point
						For <#RED>{name_multiple.weapon_hammer}</> like yours, you'll have to hit <#RED>2+ Targets</> at once, or fully charge either your <#RED>Skill</> (<p bind='Controls.Digital.SKILL' color=BTNICON_DARK>) or your <#RED>Heavy Attack</> (<p bind='Controls.Digital.ATTACK_HEAVY' color=BTNICON_DARK>).
						!bliss
						You'll know you've pulled off a <#BLUE>{name.concept_focus_hit}</> if your <#RED>Damage</> appears in <#BLUE>Blue</>.
					player:
						<#BLUE>{name_multiple.concept_focus_hit}</>, huh? I'll try that out!
				]],
			},

			POLEARM =
			{
				[[
					agent:
						!clap
						Ah, you're using the <#RED>{name.weapon_polearm}</>!
						!bliss
						I'm so glad.
						!point
						Just remember, it's a little different from your <#RED>{name.weapon_hammer}</>.
						!gesture
						Try to jab <#RED>Enemies</> with the tip of the <#RED>{name.weapon_polearm}</> if you want to perform a <#BLUE>{name.concept_focus_hit}</>.
						!dubious
						Hitting them when they're too close just won't do.
						!point
						Oh, and you can also hit multiple <#RED>Targets</> at once with your <#RED>Rolling Drill</>!
					player:
						The <#RED>Rolling Drill</> is <#RED>Dodge</> (<p bind='Controls.Digital.DODGE' color=BTNICON_DARK>), then <#RED>Light Attack</> (<p bind='Controls.Digital.ATTACK_LIGHT' color=BTNICON_DARK>), right?
					agent:
						!clap
						Yep!
					player:
						Thanks, {name.npc_scout}. I'll try it out.
				]],
			},

			FALLBACK =
			{
				[[
					agent:
						!greet
						Don't forget to keep <#BLUE>{name_multiple.concept_focus_hit}</> in mind out there!
						!gesture
						They do an increased amount of <#RED>Damage</>, which'll appear in <#BLUE>Blue</>!
					player:
						<#BLUE>{name_multiple.concept_focus_hit}</>, got it!
				]],
			},
		},
	},

	QUESTS =
	{
		main_defeat_bandicoot =
		{
			TITLE = "Defeat {name.bandicoot}",
			DESC = [[
				{giver} spotted a {boss} in {target_dungeon}! Eliminate it and make these woods a bit safer.
			]],

			quest_intro =
			{
				--{last_boss} to reference treek
				TALK = [[
					agent:
						!shocked
						Whew! It's been awhile since I touched down in <#RED>{name.kanft_swamp}</>.
						!angry
						I forgot how much it stinks!
						!dubious
						Have you ever been here before?
				]],

				OPT_1A = "This is my first visit.",
				OPT_1B = "A couple times, pre-eruption.",

				--BRANCH 1--
				OPT1A_RESPONSE = [[
					agent:
						!agree
						So this will be your first experience with <#RED>Spores</> and <#RED>Acid</> then, huh.
				]],

				--convo can't progress without hitting 2C, others are optional
				OPT_2A = "Acid?",
				OPT_2A_ALT = "You said something about Acid?",
				OPT_2B = "Spores?",
				OPT_2B_ALT = "You said something about Spores?",
				OPT_2C = "I'm more worried about the {name.rot_boss}.",
				OPT_2C_ALT = "What about the {name.rot_boss}?",

				OPT2A_RESPONSE = [[
					agent:
						!think
						Yeah. There were always a ton of toxic creatures in the bog, even before the volcano erupted.
						!dubious
						And the introduction of <#KONJUR>{name.konjur}</> certainly didn't help matters.
						!gesture
						But <#RED>Acid's</> easy enough to understand. There's only one rule, after all--
						!shrug
						Don't touch it.
						!point
						If something spits at you or leaves an <#RED>Acid</> trail in its wake, get moving and don't stand around in it.
						!shrug
						Unless you're looking to do some industrial-strength exfoliation.
				]],

				OPT2B_RESPONSE = [[
					agent:
						!nervous
						Yeah, this whole place is caked top to bottom with fungus.
						!gesture
						Most <#RED>Spores</> are benign, but they <i>can</i> cause some weird and inconvenient effects.
						!think
						To be honest, there's too many <#RED>Spore</> types to explain individually.
						!point
						I'd suggest learning to identify them by sight.
						!shrug
						You'll be fine. You're a fast learner, right?
				]],

				OPT2C_RESPONSE = [[
					agent:
						!bliss
						Got your eye on the <#KONJUR>{name.konjur_heart}</>, do you? I'm glad.
						!gesture
						The <#RED>{name.rot_boss}</> in this area is something called an <#RED>{name.bandicoot}</>.
						!scared
						It's huge, and seems to delight in tormenting people with its tricks.
						!dubious
						This'll be a very different fight from the <#RED>{last_boss}</>. Make sure to steel yourself.
				]],

				-->go to opt_3B
				--1--

				--BRANCH 2--
				OPT1B_RESPONSE = [[
					agent:
						!agree
						Ah. It's probably changed a bit since you last saw it.
						!gesture
						Ten years of <#KONJUR>{name.konjur}</> contamination's made the <#RED>Acid</> and <#RED>Spores</> waaay more potent.
				]],

				OPT_3A = "Can you tell me about the {name.rot_boss}?", --> go to OPT2C_RESPONSE
				OPT_3B = "Let's go take down a {name.rot_boss}!", -->go to TALK2
				--2--

				TALK2 = [[
					agent:
						!clap
						And get that <#KONJUR>{name.konjur_heart}</>!
				]],
			},

			pre_miniboss_death_convo =
			{
				TALK_FIRST_PLAYER_DEATH = [[
					agent:
						!clap
						Oh good, you're okay!
						!point
						I found you out there in the <#RED>Rotwood</> and brought you back.
						!think
						I'm so glad you're okay or I might have to deal with the <#RED>{boss}</> myself!
				]],
			},

			die_to_miniboss_convo =
			{
				TALK_DEATH_TO_MINIBOSS = [[
					agent:
						!nervous
						That <#RED>{miniboss}</> was terrifying!
						!clap
						I'm glad you're the one fighting those <#RED>{name_multiple.rot}</> and not me!
				]],
			},

			die_to_boss_convo =
			{
				TALK_DEATH_TO_BOSS = [[
					agent:
						!gesture
						I barely got you out of there!
						!think
						Not sure how that <#RED>{boss}</> didn't notice me.
				]],

				OPT_1A = "Gee, thanks.",
			},

			celebrate_defeat_miniboss =
			{
				TALK_FIRST_MINIBOSS_KILL = [[
					agent:
						!clap
						Wow, killing that <#RED>{miniboss}</> sure was something!
						!dejected
						But that <#RED>{boss}</> is still out there!
				]],
			},

			celebrate_defeat_boss =
			{
				TALK_FIRST_BOSS_KILL = [[
					agent:
						!shocked
						I can't believe it! You downed <i>another</> <#RED>{name.rot_boss}</>!
						!point
						You're practically unstoppable, Hunter.
						!clap
						Quickly, go pop it in the <#RED>{name.town_grid_cryst}</>.
						!bliss
						I can't wait another second!
				]],
			},

			talk_after_konjur_heart =
			{
				TALK_GAVE_KONJUR_HEART = [[
					agent:
						!clap
						It's working! We're one step closer to powering the <#RED>{name.town_grid_cryst}</>!
						!think
						Unfortunately, that's the end of the story content for this <#RED>Focus Test</>.
						!bliss
						But you're welcome to keep playing. It might be fun to try some runs on higher <#RED>Frenzy Levels</>.
						!point
						I have to say, Hunter, you've been a <i>very</i> welcome addition to the {name_multiple.foxtails}.
						!bliss
						I hope you'll come back again for the <#RED>Full Game</>!
				]],
			},
		},

		main_defeat_megatreemon =
		{
			TITLE = "Rough Landing",
			DESC = [[
				{giver} spotted a {boss} in {target_dungeon}! Eliminate it and make these woods a bit safer.
			]],

			logstrings = {
				find_target_miniboss = "The {miniboss} was last sighted in {target_dungeon}.",
				defeat_target_miniboss = "Defeat {miniboss}.",
				celebrate_defeat_miniboss = "{giver} won't believe what you encountered in the woods.",
				find_target_boss = "The {boss} was last sighted in {target_dungeon}.",
				defeat_target_boss = "Defeat the {boss} in {target_dungeon}.",
				celebrate_defeat_boss = "Tell {giver} of your triumph.",
				add_konjur_heart = "Add the {boss}'s {item.konjur_heart} to {pillar}",
				find_berna = "Locate {name.npc_armorsmith} in the {name.treemon_forest}.",
				find_hamish = "Locate {name.npc_blacksmith} in the {name.owlitzer_forest}.",
			},

			quest_intro =
			{
				TALK_INTRO = [[
					agent:
						!greet
						Hunter! Thank goodness, you're on your feet.
				]],
		
				OPT_1 = "<i>Oof</i>, what hit us?",
		
				TALK_INTRO2 = [[
					agent:
						!shocked
						That was a real life <#RED>{name.rot_boss}</> that smacked us down-- a <#RED>{name.megatreemon}</>, to be exact!
						!nervous
						Ohh, Hunter! What a terrible start to our expedition!
						!dejected
						Now half our crew are lost in the forest, and it's all my fault!
				]],
		
				--BRANCH START--
				OPT_2D = "What's a \"{name.rot}\"?",
				OPT_2A = "Just don't send <i>me</i> after them.",
				OPT_2B = "How'd you not see a {name.rot} that big anyway?",
				OPT_2C = "It's gonna be okay, {name.npc_scout}. Who's missing?",

				--not implemented kris
				OPT2D_RESPONSE = [[
					agent:
						!shocked
						<i>Uhh,</i> the giant monsters you're here to fight??
						!nervous
						Did you smack your head?
						!greet
						How many paws am I holding up?
				]],

				--BRANCH 1--
				OPT2A_RESPONSE = [[
					agent:
						!point
						Hey, don't back out on me now! I need you if we're gonna rescue <#RED>{name.npc_blacksmith}</> the {name.job_blacksmith} and <#RED>{name.npc_armorsmith}</> the {name.job_armorsmith}!
						!think
						Let's focus up, okay? We can fix this.
						!point
						You spearhead the search. I'll handle the rescue.
						!agree
						Finding <#RED>{name.npc_armorsmith}</> and <#RED>{name.npc_blacksmith}</> is our top priority. There are hostile <#RED>{name_multiple.rot}</> about, and those two aren't fighters.
				]],
				--1--

				--BRANCH 2--
				OPT2B_RESPONSE = [[
					agent:
						agent:
						!shocked
						I-It was a <#RED>{name.treemon}</>! In a forest full of trees!
						!nervous
						Being a scout doesn't make me omniscient, you know...
						!angry
						But we can't dwell on it!
						!point
						Our top priority is rescuing our {name.job_armorsmith}, <#RED>{name.npc_armorsmith}</>, and <#RED>{name.npc_blacksmith}</> the {name.job_blacksmith}. There are dangerous <#RED>{name_multiple.rot}</> in these woods, and those two aren't fighters like you are.
				]],
				--3--

				--BRANCH 3--
				OPT2C_RESPONSE = [[
					agent:
						!nervous
						...<#RED>{name.npc_armorsmith}</> the {name.job_armorsmith}, and <#RED>{name.npc_blacksmith}</> the {name.job_blacksmith}.
						!think
						<#BLUE>{name.npc_dojo_master}'s</> out there too, but I trust him to hold his own.
						!shocked
						The other two wouldn't stand a chance against the <#RED>{name_multiple.rot}</> in these woods!
						!point
						I need you to comb the forest and search for them. Just make it as far in as you can.
				]],
				--3--

				--plays after branches 1 and 2
				TALK_INTRO3 = 
				[[
					agent:
						!shrug
						<#BLUE>{name.npc_dojo_master}'s</> out there too, but he can hold his own.
						!point
						Let's comb the woods as far as we can. And if you see that nasty <#RED>{name.megatreemon}</>, pop her one for me won't you?
				]],
				--BRANCH END--

				OPT_3A = "What are you gonna do?",
				OPT_3B = "But I've never been in a real fight before!\n<i><#RED><z 0.7>(Explain controls)</></i></z>",
				OPT_3C = "Welp, no sense wasting time.\n<i><#RED><z 0.7>(Skip controls explainer)</></i></z>",

				OPT3A_RESPONSE = [[
					agent:
						!think
						The <#RED>{name.damselfly}</> is still operational, so I'm headed back up.
						!agree
						I'll watch from the air to make sure you stay safe, and scoop up anyone you find along the way.
				]],

				--BRANCH 4--
				OPT3B_RESPONSE = [[
					agent:
						!think
						Oh, um. I know the basics of fighting, I could give you refresher if you'd like?
				]],

				OPT_4A = "Yes, please!",
				OPT_4B = "Actually, I've had a burst of bravery.",

				OPT4A_RESPONSE = [[
						agent:
							!agree
							Sure, if it'll help.
							!think
							Okay, so to start-- you can perform <#RED>Light Attacks</> with <p bind='Controls.Digital.ATTACK_LIGHT' color=BTNICON_DARK>, and <#RED>Heavy Attacks</> with <p bind='Controls.Digital.ATTACK_HEAVY' color=BTNICON_DARK>.
							!gesture
							<p bind='Controls.Digital.DODGE' color=BTNICON_DARK> lets you <#RED>Dodge</>.
							!point
							Always keep your eyes peeled for when a <#RED>{name.rot}'s</> about to <#RED>Attack</> so you can <#RED>Dodge</> out of the way.
							!gesture
							I know that sounds obvious, but it's crucial to survival.
							!agree
							A good Hunter always prioritizes <#RED>Dodging Attacks</> over getting their own swing in.
							!point
							Oh, and if your <#RED>Health</> gets low, drink your <#RED>Potion</> with <p bind='Controls.Digital.USE_POTION' color=BTNICON_DARK>. You only have one, though, so use it wisely.
				]],

				OPT_5 = "Thanks. I'm feeling a bit better now.",

				OPT5_RESPONSE = [[
					agent:
						!agree
						Glad to hear it. You're never too smart to review the fundamentals.
						!shocked
						Now hold on, everyone, we're coming!
				]],

				--opt 4B ends the conversation, doesnt go on to opt 5
				OPT4B_RESPONSE = [[
					agent:
						!gesture
						Don't worry Hunter, I'll be right behind you the whole way.
						!point
						Now let's go.
				]],				
				--4--

				OPT3C_RESPONSE = [[
					agent:
						!clap
						Hold on everyone, we're coming!
				]],
			},

			pre_miniboss_death_convo =
			{
				TALK_FIRST_DEATH = [[
					agent:
						!clap
						Whew! I grabbed you in the nick of time.
				]],

				OPT_1A = "Did... did I die?",
				OPT_1B = "I just had the nicest nap.",
				OPT_1C = "Stand back {name.npc_scout}, there's {name_multiple.rot} about!",

				OPT1A_RESPONSE = [[
					agent:
						!angry
						Of course not! I'm a little better at rescues than that.
						!shrug
						...You did get a teensy bit knocked out though.
				]],

				OPT1B_RESPONSE = [[
					agent:
						!point
						See? I knew I liked you. Always looking for silver linings.
						!dubious
						What <i>is</i> being unconscious in a deadly forest if not a little "nap"?
				]],

				OPT1C_RESPONSE = [[
					agent:
						!dubious
						Easy now, we're out of the woods. Literally and figuratively.
						!point
						Keep that fighting spirit though, that's good stuff.
				]],



				TALK_FIRST_DEATH2 = [[
					agent:
						!agree
						By the way, I'm going to tail overhead in the {name.damselfly} each time you venture out. That way I can pull you up if things get dicey.
						!point
						It's never gonna be "safe" out there, but I can at least make sure it's not deadly.
				]],

				OPT_2A = "I'm glad to know you have my back.",
				OPT_2B = "Could you grab me earlier next time?",

				OPT2A_RESPONSE = [[
					player:
						Thanks, {name.npc_scout}.
					agent:
						!agree
						That's my job.
				]],

				OPT2B_RESPONSE = [[
					player:
						Like maybe before I get knocked out?
					agent:
						!shrug
						Hey, pobody's nerfect.
				]],
			},

			die_to_miniboss_convo =
			{
				TALK = [[
					agent:
						!clap
						You did great out there!
				]],

				OPT_1 = "Huh? But I got my butt kicked!",
				TALK2 = [[
					agent:
						!point
						Yeah, you got your butt kicked... <i>by an <#RED>{miniboss}</>!</i>
						!think
						In my experience, bigger <#RED>{name_multiple.rot}</> tend to hang out around <#RED>{name_multiple.rot_boss}</>.
						!point
						If you've seen an <#RED>{miniboss}</>, you must be closing in on the <#RED>{name.megatreemon}</>!
				]],

				OPT_2 = "That's... reassuring?",

				TALK3 = [[
					agent:
						!clap
						I'm sure <#RED>{name.megatreemon}'s</> just around the corner!
				]],
			},

			multiple_die_to_miniboss_convo = 
			{
				TALK = [[
					agent:
						!angry
						Yeesh, that <#RED>{miniboss}</>'s being a real jerk, huh?
				]],

				OPT_1A = "Yeah! Got any tips?",
				OPT_1B = "I'm not giving up!",

				OPT1A_RESPONSE = [[
					agent:
						!think
						Hmm, well... it hits pretty hard, but it's also slow winding up.
						!point
						If you keep an eye out for that wind up, it'll be easier to <#RED>Dodge</> (<p bind='Controls.Digital.DODGE' color=BTNICON_DARK>) the blow when it comes.
						!gesture
						<#RED>Dodging</> is better than running away, because you'll stay in range to land a few <#RED>Attacks</> before the <#RED>{miniboss}</> comes at you again.
						!point
						Plus, you're <#RED>Invincible</> for a split second during a <#RED>Dodge</> (<p bind='Controls.Digital.DODGE' color=BTNICON_DARK>), so you won't take any <#RED>Damage</> even if you're up close and personal.
						!shrug
						So long as you time your roll right, anyway.
				]],

				OPT1B_RESPONSE = [[
					agent:
						!clap
						I believe in you!
				]],
			},

			die_to_boss_convo =
			{
				TALK = [[
					agent:
						!greet
						I can't believe you've made it so deep into the forest so fast.
						!shocked
						Imagine that! A rookie {name_multiple.foxtails} Hunter, taking on a <#RED>{name.rot_boss}</> head to head!
						!point
						That <#RED>{name.megatreemon}'s</> lumber waiting to happen.
				]],
			},

			celebrate_defeat_miniboss =
			{
				TALK_FIRST_MINIBOSS_KILL = [[
					agent:
						!greet
						Hunter, you downed a <#RED>{miniboss}</>!
						!gesture
						You've really been finding your footing since we got here.
				]],

				OPT_1A = "A lot of that is owing to you.",
				OPT_1B = "Thanks, I'm feeling pretty confident.",

				OPT1A_RESPONSE = [[
					agent:
						!agree
						We make a good team, huh?
				]],

				OPT1B_RESPONSE = [[
					agent:
						!agree
						You're an asset to the {name_multiple.foxtails}!
				]],

				TALK2 = [[
					agent:
						!angry
						That <#RED>{name.megatreemon}</> better watch her bark!
				]],
			},

			dojo_master_returned = {
				TALK = [[
					agent:
						!clap
						Great news, Hunter!
						!bliss
						<#BLUE>{name.npc_dojo_master}</> made it back to camp while we were out!
						!gesture
						You should go introduce yourself if you haven't had a chance yet.
					]],
			},

			celebrate_defeat_boss =
			{
				defeated_first_run = {
					TALK = [[
						agent:
							!shocked
							Holy moly, that was incredible to watch!
							!point
							I can't believe you downed a <#RED>{name.megatreemon}</> on your very first {name.run}!
					]],

					OPT_1A = "Thanks! I'm feeling good about it.",
					OPT_1B = "I was screaming inside the entire time!",
					OPT_1C = "It was literally so easy.",

					OPT1A_RESPONSE = [[
						agent:
							!bliss
							As you should!
					]],

					OPT1B_RESPONSE = [[
						agent:
							!shocked
							I would never have guessed!
					]],

					OPT1C_RESPONSE = [[
						agent:
							!shocked
							You're so confident!
					]],

					TALK2 =[[
						agent:
							!thinking
							I think you might become a Hunter to rival <#BLUE>{name.npc_dojo_master}</> in his heyday.
							!clap
							Oh! Speaking of which, <#BLUE>{name.npc_dojo_master}</> made it back to camp while we were out!
							!gesture
							You should go introduce yourself if you haven't had a chance yet.
					]],

					OPT_2A = "We still haven't found {name.npc_armorsmith} or {name.npc_blacksmith}.",
					OPT_2B = "D'you think our {name.job_armorsmith} and {name.job_blacksmith} are goners yet?",

					OPT2A_RESPONSE = [[
						agent:
							!nervous
							Yes, I know. I'm very worried.
					]],

					OPT2B_RESPONSE = [[
						agent:
							!shocked
							Hunter!
							!angry
							Don't speak like that.
					]],

					TALK3 = [[
						agent:
							!gesture
							While you were hunting I spotted a section of the forest where the treeline had been disturbed, though.
							!agree
							It's possible one of our people landed there.
							!dubious
							I think we should keep searching the <#RED>{name.treemon_forest}</>, too.
							!gesture
							Both locations available on your map. I'll leave it up to you where we go next.
					]],

					OPT_3 = "Do you know anything about this rock the {name.megatreemon} dropped?",

					OPT3_RESPONSE = [[
						agent:
							!shocked
							Woah! In all the commotion I totally forgot!
							!point
							That right there is a <#KONJUR>{name.konjur_heart}</>, my friend.
							!agree
							It's <i>very</i> important.
					]],

					OPT_4A = "Can I eat it?",
					OPT_4B = "What's it do?",

					OPT4A_RESPONSE = [[
						agent:
							!angry
							No!
							!think
							Well, sort of.
							!angry
							But no!
							!shrug
							I'll just show you.
					]],

					OPT4B_RESPONSE = [[
						agent:
							!agree
							That's precisely what I want to show you.
					]],

					TALK4 = [[
						agent:
							!gesture
							I'd prefer not to touch it. Do me a favour, won't you?
							!point
							Place <#RED>{name.megatreemon}'s</> <#KONJUR>{name.konjur_heart}</> in the <#RED>{name.town_grid_cryst}</>.
					]],

					OPT_5A = "{name.town_grid_cryst}? What's that?",
					OPT_5B = "Sure thing, {name.npc_scout}.",
					OPT_5B_ALT = "Ohhh, the {name.town_grid_cryst}. Sure thing, {name.npc_scout}.",

					OPT5A_RESPONSE = [[
						agent:
							!think
							Oh, sorry.
							!point
							The <#KONJUR>{name.town_grid_cryst}</> is that big purple rock here in town.
							!shrug
							Y'know, near where I dropped you off.
					]],
				},

				defeated_regular = {
					TALK = [[
						agent:
							!shocked
							Holy moly, you really did it!
							!point
							You took down the <#RED>{name.megatreemon}</> that attacked us!
					]],

					--changes based on how many of the lost foxtails youve recruited
					TALK2_ALT1 = [[
						agent:
							!clap
							<i>And</i> you found Berna!
					]],

					TALK2_ALT2 = [[
						agent:
							!nervous
							Now all that's left is to save the rest of our crew!
					]],

					TALK3 = [[
						agent:
							!think
							But first...
							!dubious
							You didn't happen to find a <#KONJUR>purple</> glowy rock when you felled the <#RED>{name.treemon}</>, did you?
					]],
					
					OPT_1A = "Why, is it edible?",
					OPT_1B = "Why, is it valuable?",
					OPT_1C = "You mean this? <i><#RED><z 0.7>(Show {name.npc_scout} the {name.konjur_heart})</z></></i>", --progresses conversation
					OPT_1C_ALT = "Oh, this thing! <i><#RED><z 0.7>(Show {name.npc_scout} the {name.konjur_heart})</z></></i>", --progresses conversation

					OPT1A_RESPONSE = [[
						agent:
							!angry
							No! It's much too important to eat.
							!think
							Although I guess you do kind of consume it in a way?
					]],

					OPT1B_RESPONSE = [[
						agent:
							!gesture
							Not monetarily, but they're <i>extremely</i> important to our expedition.
					]],

					OPT1C_RESPONSE = [[
						agent:
							!clap
							Yes!
							!gesture
							Hunter... Have you noticed how powerful <#RED>{name_multiple.rot}</> tend to drop a bit more <#KONJUR>{name.konjur}</> than weaker ones?
							!point
							Well, <#RED>{name_multiple.rot_boss}</> have an absurd amount of <#KONJUR>{name.konjur}</> in their system.
							!gesture
							So much, in fact, that it crystallizes into what we call a <#KONJUR>{name.konjur_heart}</>.
							!shocked
							What you're holding there is <#RED>{name.megatreemon}'s</> <#KONJUR>{name.konjur_heart}</>!
							!gesture
							Can you do me a favour? I want to show you something, but I'd rather not touch the crystal if I can avoid it.
							!point
							Go place <#RED>{name.megatreemon}'s</> <#KONJUR>{name.konjur_heart}</> in the <#KONJUR>{name.town_grid_cryst}</>.
					]],

					OPT_2A = "{name.town_grid_cryst}? What's that?",
					OPT_2B = "Sure thing, {name.npc_scout}.",
					OPT_2B_ALT = "Ohhh, the {name.town_grid_cryst}. Sure thing, {name.npc_scout}.",

					OPT2A_RESPONSE = [[
						agent:
							!think
							Oh, sorry.
							!point
							The <#KONJUR>{name.town_grid_cryst}</> is that big purple rock here in town.
							!shrug
							Y'know, near where I dropped you off.
					]],

					END = "Thanks.",
				},
			},

			directions = -- WRITER! Temp for tutorial flow
			{
				LOST = [[
					agent:
						!dubious
						Looking for the <#KONJUR>{name.town_grid_cryst}</>?
						!gesture
						It's the big glowy rock I dropped you off next to.
				]],

				OPT_1A = "OH! The purple well."
			},

			talk_after_konjur_heart =
			{
				-- WRITER! Temp for tutorial flow
				REMINDER_GIVE_KONJUR_HEART = [[
					agent:
						!gesture
						Don't forget to put that <#KONJUR>{name.konjur_heart}</> in the <#KONJUR>{name.town_grid_cryst}</>!
						!point
						It's right where I always drop you off.
				]],

				TALK = [[
					agent:
						!clap
						Now that's a thing of beauty!
				]],

				OPT_1A = "I feel kinda tingly.",
				OPT_1B = "What did we just do?",

				OPT1A_RESPONSE = [[
					agent:
						!think
						Haha, I always wondered what it'd feel like.
				]],

				TALK2 = [[
					agent:
						!point
						When you put a <#KONJUR>{name.konjur_heart}</> in the <#KONJUR>{name.town_grid_cryst}</> it works kinda like prism, amplifying one aspect of your Hunter abilities.
						!gesture
						It looks like <#RED>{name.megatreemon}'s</> <#KONJUR>{name.konjur_heart}</> gave you some extra <#RED>Health</>. Pretty neat!
				]],

				OPT_2A = "Will all <#KONJUR>{name_multiple.konjur_heart}</> give me Health?",
				OPT_2B = "How long does the effect last?",
				OPT_2C = "Where can I get more <#KONJUR>{name_multiple.konjur_heart}</>?",

				OPT2A_RESPONSE = [[
					agent:
						!think
						Well, to be honest, I'm sort of learning as we go. No one's really done this before.
						!disagree
						But no, I think each one will probably do something completely different.
						!dubious
						I mean, you can feel it, can't you? That heart wasn't <i>just</i> concentrated <#KONJUR>{name.konjur}</>.
						!nervous
						There's like... <#RED>{name.megatreemon}</i> <i>essence</i> in there. 
				]],

				OPT2B_RESPONSE = [[
					agent:
						!shrug
						Indefinitely.
						!point
						The <#KONJUR>{name.town_grid_cryst}</> also has a pretty gigantic radius. You should get its benefits no matter where on the map we go to hunt.
						!shocked
						Oh! But you can only have one <#KONJUR>{name.konjur_heart}</> effect active per slot.
				]],

				OPT2C_RESPONSE_HAVEBERNA = [[
					agent:
						!gesture
						I'm glad you asked!
						!point
						During our flight I spotted part of the forest where the treeline had been disturbed.
						!gesture
						It's possible <#BLUE>{name.npc_blacksmith}</> landed there in the crash.
						!point
						Finding him is priority number one... but there's also a huge <#RED>{name.rot_boss}</> called an <#RED>{name.owlitzer}</> prowling the area.
						!dubious
						We could find {name.npc_blacksmith}, then secure another heart and kill two birds with one stone...
						!nervous
						Err, poor choice of words.
						!point
						Anyway, I've marked the area on your map as <#RED>{name.owlitzer_forest}</>.
				]],

				OPT2C_RESPONSE_NOBERNA = [[
					agent:
						!point
						I'm glad you asked!
						!gesture
						During our flight I spotted part of the forest where the treeline had been disturbed.
						!nervous
						I think one of our missing people might have landed there-- and they probably woke up the <#RED>{name.owlitzer}</> that prowls the area!
						!point
						We should clear the <#RED>{name_multiple.rot}</> in those woods and see if we can find anyone. I've marked the area on your map as <#RED>{name.owlitzer_forest}</>.
				]],

				OPT_3_NOBERNA = "Anything else?", --only if you dont have berna

				OPT3_NOBERNA_RESPONSE = [[
					agent:
						!think
						Hmm... Well, I also think we should keep searching the <#RED>{name.treemon_forest}</>.
						!point
						I just have a feeling we missed someone out there.
						!gesture
						Anyway, both locations are available on your map. I'll leave it up to you where we go next.
				]],

				OPT_AGREE = "On it, {name.npc_scout}!",
			}
		},

		main_defeat_owlitzer =
		{
			TITLE = "Defeat {name.owlitzer}",
			DESC = [[
				{giver} spotted a {boss} in {target_dungeon}! Eliminate it and make these woods a bit safer.
			]],

			quest_intro =
			{
				TALK_INTRO = [[
					agent:
						!nervous
						Um...
						!dubious
						No one's given me a script for this part of the game yet.
						!point
						But I know this quest is to go defeat the <#RED>{boss}</>. It's like, a <i>HUGE</i> bird!
						!gesture
						Don't worry, even though I don't know my lines I'll still watch over you from the air.
						!clap
						Go get'em Hunter!
				]],

				OPT_TEMP_COMPLETE = "You got it."
			},

			pre_miniboss_death_convo =
			{
				TALK_FIRST_PLAYER_DEATH = [[
					agent:
						!dejected
						Oh good, you're okay!
						!point
						I found you out there in the <#RED>Rotwood</> and brought you back.
						!think
						I'm so glad you're okay or I might have to deal with the <#RED>{boss}</> myself!
				]],
			},

			die_to_miniboss_convo =
			{
				TALK_DEATH_TO_MINIBOSS = [[
					agent:
						!point
						That <#RED>{miniboss}</> is terrifying!
						!clap
						I'm glad you're the one fighting those <#RED>{name_multiple.rot}</>!
				]],
			},

			die_to_boss_convo =
			{
				TALK_DEATH_TO_BOSS = [[
					agent:
						!gesture
						I barely got you out of there!
						!think
						Not sure how that <#RED>{boss}</> didn't notice me.
				]],
			},

			celebrate_defeat_miniboss =
			{
				TALK_FIRST_MINIBOSS_KILL = [[
					agent:
						!clap
						Wow, killing that <#RED>{miniboss}</> sure was something!
						!dejected
						But that <#RED>{boss}</> is still out there!
				]],
			},

			celebrate_defeat_boss =
			{
				-- HELLOWRITER: TEMP WRITING FOR CLARITY
				TALK_FIRST_BOSS_KILL = [[
					agent:
						!clap
						You did it! You killed the <#RED>{boss}</>!
						!dubious
						Err... this is a bit embarrassing, but I don't know my lines here either.
						!point
						But you can still go hunt in the next location! It's called <#RED>{name.kanft_swamp}</>.
						!gesture
						The boss there is called an <#RED>{name.bandicoot}</>. It's pretty mean, but I hear it's also kinda fun to fight.
				]],

				OPT_1 = "Hey, where's {name.npc_blacksmith}?",

				TALK2 = [[
					agent:
						!shocked
						Oh, yeah!
						!laugh
						Don't worry, he's visiting family back in the Brinks. It's almost the holidays, y'know?
						!shrug
						He'll prooobably be back for the next <#RED>Playtest</>.
						!nervous
						Sorry if you were looking hard and couldn't find him.
						!clap
						Anyway, go bust up that <#RED>{name.bandicoot}</>! Good luck, Hunter!
				]],

				defeated_regular = 
				{
					OPT1_RESPONSE = [[
						agent:
							!gesture
							You know the <#KONJUR>{name.konjur}</> grid that ran through the city, back before the disaster?
							!point
							This is one of the last working <#RED>{name_multiple.town_grid_cryst}</> that fed that system. 
							!gesture
							I want to bring it back online.
					]],

					OPT_2A = "Why?",
					OPT_2B = "How do we do that?",
					OPT_2B_ALT = "How would we restore the grid?",

					OPT2B_RESPONSE = [[
						!dubious
						The <#RED>{name_multiple.town_grid_cryst}</> need an absurdly concentrated form of <#KONJUR>{name.konjur}</> to use as fuel.
						!point
						For example, the watered-down liquid stuff you manifest abilities with wouldn't cut it.
						!gesture
						I've noticed a <#RED>{name.rot}'s</> strength is a good indicator of how potent the <#KONJUR>{name.konjur}</> in their system is.
						!point
						<#RED>{name_multiple.rot_boss}</> are practically guaranteed to have a <#KONJUR>{name.konjur_heart}</>, which is just what the <#RED>{name_multiple.town_grid_cryst}</> ordered.
					]],

					OPT_3A = "Why would restoring the grid help us?",
					OPT_3B = "How many {name_multiple.konjur_heart} do we need?",
					OPT_3C = "So I need to kill {name_multiple.rot_boss}.",

					--BRANCH 1-- 
					--ALSO USED AS OPT_2A RESPONSE!
					OPT3A_RESPONSE = [[
						agent:
							!point
							The grid powered multiple utilities, but the one I'm after is the <#RED>Bubble Shield</>.
							!gesture
							If we could raise a <#RED>Bubble Shield</>, even just around the campsite--
							!closedeyes
							We could make things safe enough for normal people to return to the <#RED>{name.rotwood}</>.
							!agree
							After that, who knows. Maybe there'd be a chance to restore normal life.
					]],

					OPT_4A = "You're a good person, {name.npc_scout}.",
					OPT_4B = "Sounds like a lofty goal.",

					OPT4A_RESPONSE = [[
						agent:
							!gesture
							Thanks, Hunter... though none of this would be possible without every person here who was crazy enough to come with me.
					]],

					OPT4B_RESPONSE = [[
						agent:
							!angry
							I know the odds are against us, but we'll never take back our home if no one's brave enough to try.
					]],

					--1--

					--BRANCH 2--
					OPT3B_RESPONSE = [[
						agent:
							!think
							We don't know enough to calculate exactly how many <#KONJUR>{name_multiple.konjur_heart}</> it'd take to bring this node back online.
							!point
							But <#KONJUR>{name_multiple.konjur_heart}</> could also be useful for improving your powers.
							!gesture
							There's no shortage of big nasty <#RED>{name_multiple.rot_boss}</> out there, so keep feeding those <#KONJUR>{name_multiple.konjur_heart}</> into the {name.town_grid_cryst}!
							!laugh
							The stronger you are, the more <#KONJUR>{name_multiple.konjur_heart}</> you'll be able to procure for the {name_multiple.foxtails} in the future.
							!tic
							Plus I'd be less worried about you.
					]],
					--2--

					--BRANCH 3--
					OPT3C_RESPONSE = [[
						agent:
							!point
							Exactly. New <#RED>{name_multiple.rot_boss}</> always possess a <#KONJUR>{name.konjur_heart}</>.
							!shrug
							It's what turned them into <#RED>{name_multiple.rot_boss}</> in the first place.
					]],
					--3--

					--OPT_5A = "How d'you know so much about this stuff?",
					OPT_5B = "Do you have any leads on {name_multiple.rot_boss}?",				

					--BRANCH 5--

					-- HELLOWRITER: TELL THE PLAYER TO KILL OWLITZER NOT BANDICOOT Slight programmer edits to update functionality of what hearts do
					OPT5B_RESPONSE = [[
						agent:
							!think
							Well, this is temp writing but you should go kill {name.owlitzer}.
							!point
							If you're ready to start looking for more <#KONJUR>{name_multiple.konjur_heart}</>, that's where I'd start.
					]],
					--5--

					OPT_7 = "Alright, alright! Let's go kill an {name.owlitzer}!",

					OPT7_RESPONSE = [[
						agent:
							!clap
							To <#RED>{name.owlitzer_forest}</>!
					]],
				},
			},
		},

		dgn_power_crystal = {
			TALK = [[
				agent:
					!point
					Hey look, a <#RED>{name.concept_relic} Crystal</>!
					!clap
					Have you ever seen one before?
			]],

			OPT_1A = "Nope! What's a {name.concept_relic} Crystal?",
			OPT_1B = "Yeah, I've seen {name.concept_relic} Crystals before.",

			--BRANCH 1--
			OPT1A_RESPONSE = [[
				agent:
					!think
					It's technically <#KONJUR>{name.konjur}</>, but in the special form Hunters can realize <#RED>{name_multiple.concept_relic}</> with.
					!point
					Make sure to pick them up whenever you see them.
					!gesture
					<#RED>{name_multiple.concept_relic}</> are <i>very</i> important for surviving against <#RED>{name_multiple.rot}</>.
			]],

			OPT_2A = "How do I use a {name.concept_relic} Crystal?",
			OPT_2B = "How long do \"{name_multiple.concept_relic}\" last?", -->only appears when OPT_2A is exhausted
			OPT_2C = "Where did this Crystal come from?",
			OPT_2D = "Do you want it?",-->only appears when OPT_2C is exhausted
			OPT_2E = "Alright, I'm gonna get going.", --> go to TALK2

			OPT2A_RESPONSE = [[
				agent:
					!gesture
					Just go up and absorb it with <p bind='Controls.Digital.ATTACK_LIGHT' color=BTNICON_DARK>.
			]],
			OPT2B_RESPONSE = [[
				agent:
					!dubious
					You can use <#RED>{name_multiple.concept_relic}</> as much as you want while you're here, but they aren't <i>forever</i>-forever.
					!gesture
					They'll all wear off when we fly back to camp.
			]],
			OPT2C_RESPONSE = [[
				agent:
					!think
					I think <#RED>{name.concept_relic} Crystals</> come from ambient <#KONJUR>{name.konjur}</>, which is often released from defeated <#RED>{name_multiple.rot}</>.
					!shrug
					Maybe it formed during your last excursion.
					!point
					At any rate, you're sure to see more of them as you clear the rooms ahead.
			]],
			OPT2D_RESPONSE = [[
				agent:
					!shocked
					The <#RED>{name.concept_relic} Crystal</>?
					!disagree
					Nah, I don't touch the stuff.
				player:
					Why not?
				agent:
					!laugh
					I'm not a Hunter, silly.
			]],
			--1--

			--BRANCH 2--
			OPT1B_RESPONSE = [[
				agent:
					!agree
					Ah, so you know what to do with them then.
			]],
			OPT_3A = "I wouldn't mind hearing some tips.", --> go to OPT2's menu
			OPT_3B = "Yup! See ya.", --> go to TALK2

			OPT3A_RESPONSE = [[
				agent:
					!shrug
						Sure. Anything in particular you want to know?
			]], 
			--2--

			TALK2 = [[
				agent:
					!greet
					Good luck!
			]],
		},

		--regular town chat like shop dialogue/tutorials/etc
		twn_chat_scout =
		{

			multiplayer_start = {
				TALK = [[
					agent:
						!greet
						Hi, Hunter! Welcome to the <#RED>Playtest</>!
						!think
						In this version a peculiar shop seems to have appeared in the dungeons.
						!clap
						You might also get to meet a good friend of mine!
						!nervous
						The game is pretty new and a liiittle unstable though, so you'll have to help me put it through the wringer.
						!think
						All you need to do is play with some friends, kill some <#RED>{name_multiple.rot}</>, and most importantly, report any nasty bugs or crashes you encounter with <#RED>F8</>.
						!bliss
						Thanks for participating in this test and I hope you have fun-- the {name_multiple.foxtails} really appreciate your efforts!
						!greet
						Be safe now!
				]],
			},

			abandoned_run = {
				TALK = [[
					agent:
						!gesture
						Got cold feet out there, huh?
				]],
				OPT_1A = "Yeah, {name.npc_scout}, things try to bite me out there!",
				OPT_1B = "Nah, I just had to pee.",

				OPT1A_RESPONSE = [[
					agent:
						!agree
						Haha, yeah.
						!laugh
						That's why I prefer the air.
				]],
				OPT1B_RESPONSE = [[
					agent:
						!think
						Ah, yeah.
						!agree
						That <i>is</i> worth an emergency airlift.
				]],
			},

			tutorial_feedback =
			{
				TALK_FEEDBACK_REMINDER = [[
					agent:
						!clap
						Remember to press F8 to give feedback!
				]],
			},

			upgrade_home =
			{
				TALK_HINT_UPGRADE = [[
					agent:
						Heading out?
						While you're out there, maybe you could get something for me?
						With some {primary_ingredient_name}, I can scout a bit further.
						Keep an eye out.
				]],
		
				TALK_CAN_UPGRADE = [[
					agent:
						What do you have there?
						Did you get some {primary_ingredient_name} so I can upgrade this dismal little tent?
				]],
		
				OPT_UPGRADE = "Let's build it.",
			},

			resident =
			{
				TALK_INTRO = [[
					agent:
						!greet
						%scout instruction startrun
					player:
						Hop in the flying machine. Got it.
				]],
			},
		},

		--friendly chats are inconsequential conversations you can unlock with flitt about world lore/his backstory etc
		twn_friendlychat = 
		{
			INITIATE_CHITCHAT = [[
				agent:
					...
				player:
					<i>(It looks like {name.npc_scout} has some time to chat.)</i>
					Hey {name.npc_scout}--
				agent:
					!dubious
					What's up, Hunter?

			]],

			EMPTY_LIST = [[
				player:
					...Uh, I totally forgot what I was gonna say.
				agent:
					!agree
					Haha. Well no worries, I'm around if you need me.
			]],

			END_CHITCHAT = "That's all.",

			END_CHITCHAT_RESPONSE = [[
				agent:
					!laugh
					Bye!
			]],

			--VILLAGER UNLOCKS--
			--Blacksmith
			BLACKSMITH_QUESTION = "So it seems we have a {name.job_blacksmith} now.",
			BLACKSMITH_TALK = [[
				agent:
					!clap
					Yeah! I'm so relieved you brought him back!
					!gesture
					Thanks, Hunter. It gives me real peace of mind to know {name.npc_blacksmith}'s safe.
					!laugh
					Plus he seems to really be warming up to you.
					!think
					When you get the chance you should speak to him about honing your weapons.
			]],

			--Armorsmith
			ARMORSMITH_QUESTION = "Any thoughts on the {name.job_armorsmith}?",
			ARMORSMITH_TALK = [[
				agent:
					!clap
					You found {name.npc_armorsmith}!
				berna:
					!angry
					A-hem!
				agent:
					!scared
					Oh!
					!agree
					A-and {name.npc_lunn}.
				berna:
					!bliss
					And {name.npc_lunn}.
				agent:
					!gesture
					Thank-you for bringing them back in one piece.
					!point
					When you get a moment, you should speak with {name.npc_armorsmith} about reinforcing your armour.
					!clap
					She might even make you something new if you have the materials.
				berna:
					!greet
					Come by any time!
			]],

			--Dojo
			DOJO_QUESTION = "Seems you were right about the {name.job_dojo}.",
			DOJO_TALK = [[
				player:
					He didn't need any help getting back from the forest.
				agent:
					!laugh
					You know he was one of the original Hunters, right?
					!gesture
					I hope you get to know him. He could teach you a lot about fighting <#RED>{name_multiple.rot}</>.
					!shrug
					Heck, most of our knowledge on the <#RED>{name_multiple.rot}</> comes from his original expeditions.
			]],

			--Cook
			COOK_QUESTION = "What do you think of the {name.job_cook}?",
			COOK_TALK = [[
				agent:
					!think
					You know...
					!shrug
					It was a bit of an oversight on my part, not hiring a cook.
					!nervous
					I was so worried about procuring weapons and armour, I totally forgot we need to eat!
					!agree
					Good thing you're here to pick up my slack. {name.npc_cook}'ll be a welcome addition to the team.
					!bliss
					I can't wait to eat some good food!
			]],

			--Apothecary
			APOTHECARY_QUESTION = "About the {name.job_apothecary}.",
			APOTHECARY_TALK = [[
				agent:
					!think
					Stuff to think about.
			]],

			--Researcher
			RESEARCHER_QUESTION = "What do you think of the {name.job_refiner}.",
			RESEARCHER_TALK = [[
				agent:
					!shocked
					I can't believe it!
					!bliss
					Word of our progress has spread so far, we're actually attracting new recruits!
					!gesture
					Can I trust you to ensure our researcher friend settles in okay?!
					!clap
					I want to leave a good impression.
			]],

			ALPHONSE1_QUESTION = "About the strange {name.shop_armorsmith} I met...",
			ALPHONSE1 = {
				TALK = [[
					agent:
						!shocked
						Oh! That reminds me!
						!point
						You should chat with {name.npc_armorsmith} about your new "friend".
						!shrug
						As part of the {name.job_armorsmith}'s Guild, she might know who they are.
				]],
				OPT1 = "Thanks for the tip.",
			},

			KONJUR_ALLERGY_QUESTION = "How come you know so much about fighting?",

			KONJUR_ALLERGY = {
				Q_RESPONSE = [[
					player:
						For someone who isn't a Hunter, you sure can explain a lot about combat techniques.
					agent:
						!dubious
						Oh!
						!nervous
						It's a little embarrassing.
				]],

				OPT_1A = "Don't worry, I won't make fun.",
				OPT_1B = "Spill the beans!",

				TALK = [[
					agent:
						!thinking
						I was still pretty young when the eruption happened, y'know?
						!gesture
						I met <#BLUE>{name.npc_dojo_master}</> not long after the Brinks was settled.
						!agree
						He gave me a place to stay and I started training as his pupil.
				]],

				OPT_2 = "{name.npc_dojo_master}?",

				OPT2_RESPONSE = [[
					player:
						That's the guy you said is lost in the forest, right?
					agent:
						!agree
						Yeah. Don't worry, you'll get to meet him soon.
				]],

				OPT2_RESPONSE_ALT = [[
					player:
						As in, our {name.job_dojo} <#BLUE>{name.npc_dojo_master}</>?
					agent:
						!clap
						Yep!
						!point
						You should really ask him for some pointers if you haven't yet already.
				]],

				TALK2 = [[
					agent:
						!gesture
						Anyway. I made it through all the combat basics, but when it came time to practice Hunter abilities...
						!nervous
						Well, let's just say we learned I was allergic to <#KONJUR>{name.konjur}</> <i>pre-</i>tty fast.
				]],

				OPT_3 = "Allergic?",

				OPT3_RESPONSE = [[
					agent:
						!shrug
						Can't even touch the stuff! I swell up like a balloon...
						!shocked
						Pop!
				]],

				OPT_4A = "That's awful!",
				OPT_4B = "That's hilarious!",

				OPT4A_RESPONSE = [[
					agent:
						!shrug
						Ah, it's just as well.
						!laugh
						I hated every second I was learning to fight!
				]],

				--opt4B plays this response and then plays opt4A's response directly after
				OPT4B_RESPONSE = [[
					agent:
						!angry
						Hey! You said you wouldn't make fun!
				]],
			},

			DAMSELFLY = {
				QUESTION = ""
			},

			KONJUR_TECH_KNOWLEDGE_QUESTION = "How do you know so much about the {name.konjur} tech around here?",
			KONJUR_TECH_KNOWLEDGE = {
				

				Q_RESPONSE = [[
					agent:
						!shrug
						Oh, I practically grew up in my grandfather's <#KONJUR>{name.konjur}</> workshop.
				]],

				OPT_1A = "Wait... you're {name.npc_grandad} {name.flitt_lastname}'s grandson?",
				
				OPT1A_RESPONSE = [[
					agent:
						!clap
						Yep yep!
						!shrug
						To grandpa's chagrin I never really clicked with all that science stuff--
						!point
						But I picked up enough that I can still operate his <#KONJUR>{name.konjur}</> machines.
						!bliss
						Grandpa's legacy might just save us all in the end.
				]],
			},
		},

		twn_heartstone_intro =
		{
			heartstone_tips =
			{
				INTRO = [[
					agent:
						!greet
						Hunter!
						It looks like you harvested a {name.konjur_heart} from that {name.megatreemon}!
						Those things are absolutely brimming with power. 
						You should head over to the town's {name.town_grid_cryst} and see if it reacts.
						!thinking
				]],

				OPT_1A = "{name.town_grid_cryst}. Got it."
			},

			directions =
			{
				LOST = [[
					agendt:
						What's wrong? You look a bit confused.
						The {name.town_grid_cryst} is the big glowing pillar I always drop you beside.
				]],

				OPT_1A = "Big glowing pillar. Got it."
			},

			after_heart =
			{
				AFTER_HEART = [[
					agent:
						Woah! The {name.town_grid_cryst} definitely did react to that.
						And you seem like you're more powerful too.
						I wonder what other powers you'll discover.
				]],

				OPT_1A = "Thanks, {name.npc_scout}."
			},

		},

		twn_recruit_mascot = 
		{
			TITLE = "Mascot Quest",

			explain_problem = {
				TALK = [[
					agent:
						!greet
						Hey Hunter, you got a second?
				]],

				OPT_1A = "Sure, what's up?",
				OPT_2A = "Not right now, sorry!",

				OPT1A_RESPONSE = [[
					agent:
						!dubious
						Well, I was scouting over <#BLUE>{name.thatcher_swamp}</> recently and I saw something...
						!nervous
						Strange.
				]],

				OPT1B_RESPONSE = [[
					agent:
						!nervous
						Oh, no problem.
						!nod
						Come catch me when you've got a moment.
				]], -->exit convo

				OPT_2A = "Bones?",
				OPT_2B = "Like what?",

				OPT2A_RESPONSE = [[
					player:
						There's tons of bones there.
					agent:
						!agree
						So many bones!
						!disagree
						But that's not what I'm talking about.
				]],

				TALK2 = [[
					agent:
						!nervous
						It was the mold.
						!scared
						It was... <i>moving</i>.
				]],

				OPT_3A = "Ew.",
				OPT_3B = "Are you sure it wasn't the wind?",

				OPT3A_RESPONSE = [[
					agent:
						!point 
						Yeah, it was super gross.
				]],

				OPT3B_RESPONSE = [[
					agent:
						!angry
						I didn't imagine it!
				]],

				TALK3 = [[
					agent:
						!gesture
						I think the mold spores are gaining sentience.
						In the past year I've noticed the emergence of a new creature in the Bog...
						You'd recognize them as <#RED>{name_multiple.mossquito}</>.
				]],

				OPT_4A = "I hate those guys!",
				OPT_4B = "I assumed they'd always been there.",

				OPT4A_RESPONSE = [[
					agent:
						!agree 
						Yeah, me too. That's why I've been trying to figure out where they're coming from.
				]],
				OPT4B_RESPONSE = [[
					agent:
						!agree
						Haha yeah, it's hard to imagine a world before <#RED>{name_multiple.mossquito}</> bites, huh?
				]],

				TALK4 = [[
					agent:
						!gesture
						But that's why I mention it.
						!point
						I <i>finally</i> saw where they're coming from. It's the <i>mold</i>.
						I saw it wriggling and then suddenly a <#RED>{name.mossquito}</> schlorped out!
						It's coming alive or something.
						If you have the chance, I'd really appreciate it if you could talk to Dr. {name.npc_refiner} and see if she has any insight.
				]],

				OPT_5A = "This is too interesting to stay away!",
				OPT_5B = "I'll see.",

				OPT5A_RESPONSE = [[
					agent:
						!nervous
						I hope you two can sort it out soon.
						!shocked
						I can't stand those lil suckers!
				]],
				OPT5B_RESPONSE = [[
					agent:
						!nervous
						Thanks, Hunter.
				]],
			},

			recruit_mascot = {

			},

			use_potion_on_monster = {

			},
		},

		twn_magpie_delivery = {
			TALK = [[
				agent:
					!scared
					Hey Hunter??
					!nervous
					Can you help me with this bird?? It won't go away!
				magpie:
					<i>SQUAAAWK</i>
			]],

			OPT_1A = "Oh neat, my package is here!",
			OPT_1B = "Relax, {name.npc_scout}. He's cool.",

			OPT1A_RESPONSE = [[
				agent:
					!shocked
					Package? Where did you get a--
				magpie:
					<i>KA-CAW</i>
				agent:
					!scared
					--Ah! It moved!
			]],
			OPT1B_RESPONSE = [[
				agent:
					!shocked
					You <i>know</i> him?
			]],

			--OPT_2 = "",
			OPT_2_ALT = "I met an {name.job_armorsmith} in the field.",

			TALK2 = [[
				player:
					This is the stuff I bought from him on our last outing.
				agent:
					!thinking
					Huh? I don't remember ever seeing you talk to another {name.job_armorsmith}.
			]],

			OPT_3A = "He seemed cool.",
			OPT_3B = "He seemed a little sketchy.",
			OPT_3C = "He had some good pieces.",

			OPT3A_RESPONSE = [[

			]],

			OPT3B_RESPONSE = [[

			]],

			OPT3C_RESPONSE = [[
				agent:
					!thinking
					Hmm...
					!dubious
					I don't know if I approve of you buying gear from an unvetted vendor.
					!gesture
					But quality gear is quality gear.
					!shrug
					And we don't really have the luxury of being picky, do we?
			]],

			TALK3 = [[
				agent:
					!angry
					I'm okay with you getting more deliveries, as long as I don't have to sign for them.
					!nervous
					Birds freak me out.
				nimble:
					SQUAWKK
				agent:
					!scared
					Ah!
			]],
		},
	}
}
