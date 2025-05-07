return
{

	QUESTS = {
		twn_fallback_chat =
		{
			QUIP_CHITCHAT = {
				[[
					agent:
						!greet
						There's so much we can learn from the world around us.
				]],
				[[
					agent:
						!bliss
						<#KONJUR>{name.konjur}</> is fascinating! And frightening. But mostly fascinating.
				]],
				[[
					agent:
						!bliss
						What a beautiful day for knowledge gathering.
				]],
			},
		},
		dgn_meeting_research =
		{
			TITLE = "An Inquisitive Mind",

			first_chat =
			{
				TALK = [[
					agent:
						...
					player:
						*She seems to be working diligently.
				]],

				OPT_1A = "Whatcha doin'?",

				TALK = [[
					agent:
						Oh, hi there! I didn't expect to see anyone but {name_multiple.job_konjurist} out here.
						I'm a researcher from the Brinks. {name.npc_konjurist}'s been kind enough to share their knowledge with me.
				]],

				OPT_2A = "I'm from the Brinks, too!",

				TALK = [[
					player:
						I'm a Hunter.
					agent:
						That's great-- Listen, sorry to be rude but I'm a little busy here.
						It was nice to meet you, Hunter.
				]],
		
				OPT_OK = "See you around, {name.npc_refiner}.",
			},

			hang_out_in_shop =
			{
				TALK_IN_SHOP = [[
					agent:
						Man, if only I could get some {boss} materials.
				]],
		
				OPT_OK = "Sounds tough!",
			},

			TALK_FIRST_HIRED =
			[[
				player:
					So, how's this set up?
				agent:
					It's meek, but I'm used to working in strained conditions. I appreciate the help.
				player:
					That glass thing sure does weight a lot.
				agent:
					Haha. Hey so listen, now that I'm all set up I can start getting to work for you.
					If you bring me any pieces from the monsters you kill, I can analyze them to further our understanding of the species it came from.
				player:
					Do they have to be special pieces?
				agent:
					Nope! There's so little knowledge in the field of {name.konjur}-corrupted organism that I'll learn something new from pretty much anything you can bring me.
					And part of learning new things is learning how to make the best of what's available to us.
					By examining samples I may learn how your smiths can better work {name.rot} hides and bones to make sturdier gear, or how the chemical properties of {name.rot} spit could be used to craft more potent potions.
				player:
					Better gear and potions? I like you already.
				agent:
					Haha.
					!clap
					I can't wait to get started!
					Oh, and be safe out there, too. Haha.
				player:
					Thanks, {name.npc_refiner}.
			]],

			talk_in_town =
			{
				--TODO(chloe): variations on "See ya back at camp"
				QUIP_RENDEZVOUS_IN_TOWN = {
					[[
						agent:
							!clap
							My neurons are firing up already!
					]],
				},

				TALK_VISITOR = [[
					agent:
						Hello there!
					player:
						Hey again, {name.npc_refiner} was it? What brings you here?
					agent:
						Funny you should ask! I couldn't help but notice the massive {name.treemon} carcass in the forest.
					player:
						Oops. You weren't researching that, were you?
					agent:
						That's exactly why I'm here! I can't believe you managed to cut down a <i>{name.megatreemon}</i>--
						And what's more, I can't believe the pristine samples I was able to take from it thanks to your work!
						Look, I can tell your {name_multiple.foxtails} are onto something here.
						You might actually be able to make a difference in the Rotwood. And I want to be a part of it.
					player:
						Thanks, but I'm not sure what you mean.
					agent:
						I want to join your camp.
					flitt:
						Did I hear that right? A researcher wants to join the {name_multiple.foxtails}?
					agent:
						Oh, you're the leader here?
						Yes. It would be mutually beneficial.
						If your hunters bring me pieces from the monsters they defeat in the wilds, I can research them here and learn more about the different {name.rot} species.
						More knowledge on the {name_multiple.rot} means your hunters will better know how to take them down, and I may even discover properties of the materials that will allow you to improve your weapons and armour.
					flitt:
						Hm. We definitely have room in our company for a new specialist.
						What do you think, hunter?
					player:
						Better weapons and armour sound good to me!
					flitt:
						I agree.
						In that case, welcome aboard, uh--
					agent:
						Dr. {name.npc_refiner} Ashe.
					flitt:
						Dr. {name.npc_refiner} Ashe. Hunter, will you see to setting up her equipment in the camp?
					player:
						Will do!
					agent:
						All I need to kickstart everything is a {primary_ingredient_name}.
				]],
		
				OPT_PLACE_VILLAGER = "(Choose a spot)",
		
				TALK_CANCEL_HIRE = "Next time I guess?",
			},

			talk_in_town_first_chat =
			{
				TALK_VISITOR = [[
					agent:
						Hello there! My name's {name.npc_refiner}!
						I'm a researcher looking into the effects of {name.konjur} on wildlife.
					player:
						Nice to meet you, {name.npc_refiner}. What brings you here?
					agent:
						Funny you should ask! I couldn't help but notice the massive {name.treemon} carcass in the forest.
					player:
						Oops. You weren't researching that, were you?
					agent:
						That's exactly why I'm here! I can't believe you managed to cut down a <i>{name.megatreemon}</i>--
						And what's more, I can't believe the pristine samples I was able to take from it thanks to your work!
						Look, I can tell your little group is onto something here.
						And I want to be a part of it.
					player:
						Thanks, but I'm not sure what you mean.
					agent:
						I want to join your camp.
					flitt:
						Did I hear that right? A researcher wants to join the {name_multiple.foxtails}?
					agent:
						Oh, you're the leader here?
						Yes. It would be mutually beneficial.
						If your people bring me pieces from the monsters they defeat in the wilds, I can research them here and learn more about the different {name.rot} species.
						More knowledge on the {name_multiple.rot} means you'll better know how to take them down, and I may even discover properties of the materials that will allow you to improve your weapons and armour.
					flitt:
						Hm. We definitely have room in our company for a new specialist.
						What do you think, hunter?
					player:
						Better weapons and armour sound good to me!
					flitt:
						I agree.
						In that case, welcome aboard, uh--
					agent:
						Dr. {name.npc_refiner} Ashe.
					flitt:
						Dr. {name.npc_refiner} Ashe. Hunter, will you see to setting up her equipment in the camp?
					player:
						Will do!
					agent:
						All I need to kickstart everything is a {primary_ingredient_name}.
				]],

				OPT_PLACE_VILLAGER = "(Choose a spot)",
				TALK_CANCEL_HIRE = "Next time I guess?",
			},

			build_delayed =
			{
				TALK_VISITOR = [[
					agent:
						Ready to pick a spot now?
				]],

				OPT_PLACE_VILLAGER = "(Choose a spot)",
				TALK_CANCEL_HIRE = "We can pick a spot later.",
			}
		},

		twn_shop_research =
		{
			shop_chat_resident =
			{
				TALK_RESIDENT = [[
					agent:
						!greet
						Got some materials you'd like to analyze?
						I am itchin' to do some fishin'... y'know, for facts and stuff.
				]],
		
				OPT_RESEARCH = "Let's do some research!",
				OPT_REFINE = "Let's crunch some materials!",
		
				OPT_HOME = "About your research equipment...",
				TALK_HOME = [[
					agent:
						Oh?
				]],
		
				OPT_UPGRADE = "Let's upgrade it",
				OPT_MOVE_IT = "Let's move it",
		
				DISCUSS_UPGRADE = [[
					agent:
						WIP text
						WIP text about upgraded station abilities
					player:
						Glad you like it.
				]],
		
				TALK_MOVED_HOME = [[
					player:
						There. Think you can work okay from here?
					agent:
						Sure. Science isn't bound by physical location.
				]],
			},

			attract_resident =
			{
				TALK_RESIDENT = [[
					agent:
						!greet
						Hey, Hunter! Check it out, I found this old pre-erruption research notebook.
						!bliss
						Judging from the scientific illustrations, it's about the insects that inhabit the <#RED>{name.rotwood}</>!
					player:
						Oh. So, a book on bugs.
					agent:
						!clap
						Yes! I've specifically been looking for something like this. 
						!think
						There's very little surviving information on the insects and smaller fauna of the Rotwood.
						!dejected
						And it's been difficult to understand the {name_multiple.rot} without a full picture of the ecosystem that progenerated them.
					player:
						So what does it say?
					agent:
						!think
						Well, that's the problem. It's completely illegible, written in a lost pre-eruption dialect, or maybe some sort of code.
						!shrug
						I can't make out any of it.
					player:
						Cracking ancient codes sounds like work for a Hunter. Hand it here.
					agent:
						!gesture
						Sure, here you go.
					player:
						Hm... The handwriting's a mess, but I think I can make out a few letters at the top.
						Are you sure it's a code?
					agent:
						!shocked
						What, for real? Read it to me, what's it say!
					player:
						I can sort of see an "L"...
						"O"... "TT"... that's an "I"... and "E".
					agent:
						!scared
						...
					player:
						"{NAME.npc_refiner}"? {name.npc_refiner}, is this your jour--
					agent:
						!gesture
						Gimme that!
						!angry
						...
						!dubious
						Let's never speak of this again.
				]],
			}
		},

		twn_recruit_mascot = {
			talk_to_lottie = {
				TALK = [[
					player:
						Hey {name.npc_refiner}, how's it going?
					lottie:
						!notebook
						Eh, just doin' science at the end of the world. Y'know. Ha ha.
				]],

				OPT_1 = "Funny you should mention that.",

				TALK2 = [[
					player:
						Up for a bit of research?
					lottie:
						!point
						<i>Always</i>.
				]],

				OPT_2 = "Flitt says he's seen a bunch of mold turning into {name_multiple.rot}.",

				TALK3 = [[
					lottie:
						!dubious
						Um... can you say that again in science, please?
				]],

				OPT_3A = "{name.kanft_swamp} is witnessing a mycological metamorphosis.",

				TALK4 = [[
					lottie:
						!eyeroll
						Ohhhhhh!
						!thinking
						So fungal spores are undergoing the transformation into <#RED>{name_multiple.rot}</>, are they?
						!gesture
						This isn't the first time non-sentient living matter has been corrupted-- just look at the <#RED>{name.megatreemon}</>, for example.
						!shocked
						But fungal spores becoming <#RED>{name_multiple.rot}</>!
						!dubious
						What's next, <i>microbes</i>?? How far will it go!
						!point
						Hunter. It's of the utmost important that we understand what is going on, before our <#KONJUR>{name.konjur}</>-corrupted gut flora start eating us from the inside out!
				]],

				OPT_4 = "What do you want me to do?",

				TALK5 = [[
					lottie:
						!notebook
						I need samples.
						!thinking
						{name.npc_scout} says <#RED>{name_multiple.mossquito}</> are the result of this mold transformation, so their tissue must hold the answer.
						!point
						<#RED>10 Samples</> ought to do it.
				]],

				OPT_5A = "I'm on it.",
				OPT_5B = "We'll see how it goes.",

				TALK6 = [[
					lottie:
						!notebook_start
						<i>({name.npc_refiner} has already lost interest in you and is muttering to herself about <#KONJUR>{name.konjur}-induced aggression and "fruiting bodies.")</i>
				]],
			},

			return_to_lottie = {
				TALK = [[
					lottie:
						!shocked
						You're back!
				]],

				OPT_1 = "Yup! Here's your samples.",

				TALK2 = [[
					lottie:
						!clap
						Oh, these are juicy!
						!thinking
						It will take me a bit time to analyze these and compile my thoughts.
						!gesture
						Why don't you go do one of your little Hunter romps and come find me after?
				]],

				OPT_2A = "Alright, I'll be back.",
				OPT_2B = "Not sure I'd call risking my life a \"romp\", but--",

				TALK3 = [[
					lottie:
						!notebook_start
						<i>(She's already stopped listening.)</i>
				]],
			},

			give_mats_to_lottie = {

			},
		},
	}
}
