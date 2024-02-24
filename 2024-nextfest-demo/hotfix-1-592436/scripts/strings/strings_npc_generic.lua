return
{
	QUESTS =
	{
		twn_fallback_chat =
		{
			-- We should never actually hit this line! If you see this,
			-- then we need to write a fallback line for the character to
			-- say and include it in twn_fallback_chat.lua
			QUIP_CHITCHAT = {
				[[
					agent:
						!greet
						Please write a custom line for me to say.
				]],
			},
		},

		twn_repeatable_test =
		{
			TITLE = "A test.",

			present_quest =
			{
				INTRODUCE_QUEST = [[
					agent:
						!greet
						Test One! 
						Wanna do a repeatable quest?
				]],
		
				OPT_FUN = "That sounds fun!",
				EXPLANATION = "Great, come back later and I'll tell you how to do it.",
				OPT_OK = "Okay",
				CANCEL = "Nah, I don't think so",
				WHATEVER = "Whatever then, it's not like I care or something",
			},

			do_quest =
			{
				INSTRUCTIONS_QUEST = [[
					agent:
						To Complete the quest, all you need to do is click the "Yes" option.
				]],
		
				OPT_YES = [["Yes"]],
				OPT_CANCEL = "Not right now.",
		
				COMPLETED = [[
					agent:
						!clap
						I knew you could do it!
				]],
		
				CANCEL = "Too hard for you?",
			},
		},

		twn_repeatable_fetch =
		{
			TITLE = "Fetch me something",

			present_quest = 
			{
				INTRODUCE_QUEST = [[
					agent:
						!greet
						Could you do something for me?
						Can you fetch me {request_material#material}?
				]],
		
				TALK_THANKS = "Awesome, looking forward to it",
				OPT_OK = "Okay",
				CANCEL = "Not right now",
		
			},

			do_quest_reminder =
			{
				TALK_REMINDER = [[
					agent:
						!greet
						Don't forget, I need a {request_material#material}!
						Whenever you've got the time
				]]
			},

			do_quest =
			{
				TALK_DELIVERY = [[
					agent:
						Is that {request_material#material} for me?
				]],
		
				OPT_YES = "Yes",
				OPT_NO = "Not right now",
		
				TALK_THANKS = [[
					agent:
						Wonderful, thank you so much!
						Here, take a recipe for {reward#recipe}.
						For your troubles.
						Once you have the ingredients you can build it using the menu on the bottom right corner.
				]],
			},
		},

		twn_repeatable_kill =
		{
			TITLE = "Kill something for me",

			present_quest =
			{
				INTRODUCE_QUEST = [[
					agent:
						!greet
						Can you do me a favor?
						Can you kill {kill_amount} of {target} for me?
				]],
		
				TALK_THANKS = "Thanks!",
		
				OPT_OK = "Okay",
				CANCEL = "Not right now.",
		
			},

			hunt_target =
			{
				TALK_REMINDER = [[
					agent:
						!greet
						Don't forget, I need  you to kill {kill_amount} of {target}!
						So far you've killed {kill_count}.
				]]
			},

			talk_post_hunt =
			{
				TALK_DELIVERY = [[
					agent:
						I hear you killed {kill_amount} of {target}!
						Thanks a lot!
						Here, take a recipe for {reward#recipe}
						As a token of appreciation
						Once you have the ingredients you can build it using the menu on the bottom right corner.
				]],
		
				OPT_YES = "You're welcome",
			},
		},
	},
}
