local NpcAutogenData = require "prefabs.npc_autogen_data"
local Quest = require "questral.quest"


local Q = Quest.CreateMainQuest()

-- Main quest always needs a giver, so use the village.
Q:UpdateCast("giver")
	:CastFn(function(quest, root)
		return root:GetCurrentLocation()
	end)


function Q:Quest_Start()
	local qm = self:GetQuestManager()
	local qc = qm:GetQC()

	-- Setup initial npcs so they are automatically cast in quests. Not using
	-- NpcAutogenData since they'll start appearing in save files once we add
	-- to quest system and don't want temp npcs.
	local initial_npcs = {
		"npc_armorsmith",
		"npc_blacksmith",
		"npc_cook",
		"npc_dojo_master",
		"npc_konjurist",
		"npc_market_merchant",
		"npc_potionmaker_dungeon",
		"npc_scout",
		"npc_specialeventhost",
	}
	for _,prefab in ipairs(initial_npcs) do
		-- Getting ensures they exist within the quest system (but not in world).
		local node = qc:GetNpcCastForPrefab(prefab)
		local role = NpcAutogenData[prefab].role
		if role then
			-- For FilterForRole.
			node:SetNpcRole(role)
		end
	end


--[[  _____         _                   ___        _
	  \_   \ _ __  | |_  _ __  ___     / __\_   _ | |_  ___   ___  ___  _ __    ___
	   / /\/| '_ \ | __|| '__|/ _ \   / /  | | | || __|/ __| / __|/ _ \| '_ \  / _ \
	/\/ /_  | | | || |_ | |  | (_) | / /___| |_| || |_ \__ \| (__|  __/| | | ||  __/
	\____/  |_| |_| \__||_|   \___/  \____/ \__,_| \__||___/ \___|\___||_| |_| \___|
]]
	------------------------------------------------------------------------------------------

	qm:SpawnQuest("main_intro_sequence")

	-- TODO(dbriscoe): These should be unlocked by whatever adds scout to town.
	qm:SpawnQuest("twn_chat_scout")
	qm:SpawnQuest("twn_friendly_chats")
	qm:SpawnQuest("twn_tips_scout")

	------------------------------------------------------------------------------------------

--[[
   __                           _  _         __   ___   ___
  /__\  ___   ___  _ __  _   _ (_)| |_    /\ \ \ / _ \ / __\___
 / \// / _ \ / __|| '__|| | | || || __|  /  \/ // /_)// /  / __|
/ _  \|  __/| (__ | |   | |_| || || |_  / /\  // ___// /___\__ \
\/ \_/ \___| \___||_|    \__,_||_| \__| \_\ \/ \/    \____/|___/

]]
	------------------------------------------------------------------------------------------

	-- Teechu/Ulurn
	--    Recruited after you complete your first run (win or lose)
	qm:SpawnQuest("twn_meeting_dojo")

	-- Berna
	--    Recruited after Alphonse is met
	qm:SpawnQuest("intro_meeting_armorsmith")

	-- Glorabelle
	--    Recruited in Owlitzer insert room
	qm:SpawnQuest("intro_meeting_cook")

	-- Hamish
	--    Recruited in Owlitzer forest hype room
	qm:SpawnQuest("intro_meeting_blacksmith")

	------------------------------------------------------------------------------------------

--[[
		___                                                __   ___   ___
	   /   \ _   _  _ __    __ _   ___   ___   _ __     /\ \ \ / _ \ / __\___
	  / /\ /| | | || '_ \  / _` | / _ \ / _ \ | '_ \   /  \/ // /_)// /  / __|
	 / /_// | |_| || | | || (_| ||  __/| (_) || | | | / /\  // ___// /___\__ \
	/___,'   \__,_||_| |_| \__, | \___| \___/ |_| |_| \_\ \/ \/    \____/|___/
						   |___/
]]
	------------------------------------------------------------------------------------------

	-- MYSTERIOUS WANDERER
	qm:SpawnQuest("dgn_mystery")
	---------------------------------------------

	-- ALKI (power upgrader)
	qm:SpawnQuest("dgn_firstmeeting_powerupgrade")

	qm:SpawnQuest("dgn_shop_powerupgrade")
	---------------------------------------------

	-- DOC HOGGINS (dungeon potion seller)
	qm:SpawnQuest("dgn_firstmeeting_potion")
	qm:SpawnQuest("dgn_shop_potion")
	--------------------------------------------

	-- ALPHONSE (dungeon armorsmith)
	--    note that alphonse and nimble cant be accessed until
	--    after the first miniboss
	qm:SpawnQuest("dgn_firstmeeting_armorsmith")
	qm:SpawnQuest("dgn_shop_armorsmith")
	---------------------------------------------

	-- Spawn initial quests and *immediately complete* so we don't ever get
	-- called again.
	self:Complete()
end

return Q
