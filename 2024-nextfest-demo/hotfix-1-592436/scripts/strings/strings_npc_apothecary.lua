return
{
	QUESTS =
	{
		dgn_meeting_apothecary =
		{
			TITLE = "A Funny Brewing Related Quest Name",

			invite_to_town =
			{
				-- HELLOWRITER: Added "Me?" to the end so npc has dialogue that
				-- player choices are displayed against to stop this from
				-- crashing.
				TALK_INTRODUCE_SELF = [[
					agent:
						Sniff... Sniff sniff.
					player:
						Hello? You look injured, are you okay?
					agent:
						Oh, I thought I smelled something unusual. Like <#KONJUR>{name.konjur}</> mixed with wet dog, but there's something else, too...
					player: 
						You look injured. What are you doing out here?
					agent:
						Me?
				]],
		
				OPT_OK = "Okay then!",
			},

			talk_in_town =
			{
				TALK_VISITOR = [[
					agent:
						!greet
						Howdy!
						Heard you been doing some damage to the {name_multiple.rot} out there.
						Maybe you could benefit from an Apothecary?
					player:
						An Apothecary?
					agent:
						Yes. You know, to make potions?
						You've probably met my sister out there already
						I could do the same for you from the comfort of the village
						What do you think?
					player:
						Sounds ideal
					agent:
						Now then. Where should I set up?
				]],
		
				OPT_PLACE_VILLAGER = "(Choose a spot)",
		
				TALK_FIRST_HIRED = [[
					agent:
						!clap
						Oh this spot looks just great!
						Let me know if you get any <#KONJUR>{name.konjur} Shards</>!
						I'm keen to start brewing some mixtures for you.
				]],
				
				TALK_CANCEL_HIRE = "We can pick a spot later.",
		
			},

			build_delayed =
			{
				TALK_VISITOR = [[
					agent:
						Ready to pick a spot now?
				]],
		
				OPT_PLACE_VILLAGER = "(Choose a spot)",
		
				TALK_FIRST_HIRED = [[
					agent:
						!clap
						Oh this spot looks just great!
						Let me know if you get any <#KONJUR>{name.konjur} Shards</>!
						I'm keen to start brewing some mixtures for you.
				]],
		
				TALK_CANCEL_HIRE = "We can pick a spot later.",
			},
		},

		twn_shop_apothecary =
		{
			attract_resident =
			{
				TALK_RESIDENT = [[
					agent:
						!closedeyes
					player:
						*{name.npc_apothecary} is just standing there with her eyes closed.
				]],

				OPT_1A = "What are you doing?",

				TALK2 = [[
					agent:
						...
						Too many people were looking at me. So I decided to go invisible.
				]],

				OPT_2A = "But you're not invisible. You just closed your eyes.",
					
				TALK3 = [[
					agent:
						But I am invisible.
						If you don't believe me, just try it.
				]],

				OPT_3A =  "...Okay...",

				TALK4 = [[
					player:
						Can you see me?
					agent:
						No.
					player:
						Wow, it works!
				]],

				TALK4 = [[
					agent:
						Hehe.
						...
						...Back in the swamp, when I went invisible, I could sense so many things.
						The... wet, earthy smell of mud.
						The squish of distant monster footsteps.
						The thickness of the air. So dense it was almost like a blanket.
						And beneath everything was the reliable hum of mosquitoes.
					player:
						Do you miss it?
					agent:
						Do... I miss it?
						How can you tell if something is bad, or just unfamiliar?
					player:
						I don't know. What do you sense here?
					agent:
						I can hear the crackling of the blacksmith's fire.
						!thought
						The air is light and has a tangy scent. I think that's the grass.
						Beneath everything I hear the small sounds of people existing.
						Breathing, shifting their weight, scratching an itch.
						There is no mosquito buzz.
					player:
						Is it bad?
					agent:
						It is unfamiliar.
					player:
						!thought
						Sniff sniff. All I can smell is wet fox.
					agent:
						The fox is very sweaty.
					player:
						!shrug
						Yeah. They have anxiety.
					agent:
						Hehe.
						.....
						I think... I'm ready to become visible again.
					player:
						Okay. (open eyes)
					agent:
						({name.npc_apothecary} opens her eyes)
					player:
						Better?
					agent:
						!agree
						Yeah.
					player:
						Thanks for teaching me how to go invisible.
					agent:
						You're welcome.
					player:
						Bye, {name.npc_apothecary}.
				]],
			},

			shop_chat_resident =
			{
				TALK_RESIDENT = [[
					agent:
						!aloof
						Sniff sniff.
					player:
						Please don't smell me.
					agent:
						Sorry.
		
				]],
		
				OPT_SHOP = "Got any good potions?",
		
				OPT_HOME = "About your cauldron...",
				TALK_HOME = [[
					agent:
						...?
				]],
		
				OPT_UPGRADE = "Let's upgrade it",
				OPT_MOVE_IT = "Let's move it",
		
				DISCUSS_UPGRADE = [[
					player:
						How's that?
					agent:
						You did this for me?
						Wow.
						I'll be able try some new mixtures with this equipment. Sniff sniff.
				]],
		
				TALK_MOVED_HOME = [[
					player:
						Is this spot okay?
					agent:
						I'd be comfortable anywhere.
				]],
			}
		}
	}
}
