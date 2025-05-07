local Convo = require "questral.convo"
local Quest = require "questral.quest"
local recipes = require "defs.recipes"
local Consumable = require("defs/consumable")
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require ("strings.strings_npc_potionmaker_dungeon").QUESTS.dgn_business_ventures_potion

local admission_recipe = recipes.ForSlot.PRICE.potion_refill
local limitededition_potion_recipe = recipes.ForSlot.PRICE.limited_potion_refill
local granny_donation_recipe = recipes.ForSlot.PRICE.granny_donation

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGHEST)



local function OnStartCooking(recipe, player)
	-- Don't CraftItemForPlayer because the recipe is the entry cost.
	recipe:TakeIngredientsFromPlayer(player)

	player.components.potiondrinker:RefillPotion()
	TheDungeon:GetDungeonMap():RecordActionInCurrentRoom("travelling_salesman")
end

--hoggins takes a small cut (2%) of your teffra as payment for holding your bag
local function TakeACut(player)
	-- find out what 2% of the players' teffra is
	local cut = math.ceil(quest_helper.GetPlayerKonjur(player) * 0.02)

	if cut < 0 then
		cut = 0
	elseif cut > 20 then --amount stolen caps at 20
		cut = 20
	end

	--take the teffra
	player.components.inventoryhoard:RemoveStackable(Consumable.Items.MATERIALS.konjur, cut)
end

--the player's hunter species will be inserted here at runtime
Q:AddVar("species", "PLACEHOLDER")

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForRole("travelling_salesman")

function Q:Quest_Start()
	-- Set param here to use as "{primary_ingredient_name}" in strings.
	self:SetParam("primary_ingredient_name", quest_helper.GetPrettyRecipeIngredient(admission_recipe))
	self:SetParam("admission_recipe", admission_recipe)
	self:SetParam("limited_potion_refill", limitededition_potion_recipe)
	self:SetParam("granny_donation_recipe", granny_donation_recipe)
end

------OBJECTIVE DECLARATIONS------
Q:AddObjective("bandicoot_swamp") --the one where hoggins takes "a cut" while holding your bag
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
Q:AddObjective("thatcher_swamp")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
Q:AddObjective("owlitzer_forest")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
Q:AddObjective("sedament_tundra") --limited edition potion encounter
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

quest_helper.AddCompleteQuestOnRoomExitObjective(Q)

------CONVERSATIONS AND QUESTS------
--and (quest_helper.GetPlayerKonjur(cx.quest:GetPlayer()) >= 10)
Q:OnAttract("bandicoot_swamp", "giver", function(quest, node, sim)
return TheWorld:IsFlagUnlocked("wf_travelling_salesman") and quest_helper.IsInDungeon("kanft_swamp") end)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings.bandicoot_swamp)
	:Fn(function(cx)
		quest_helper.SetPlayerSpecies(cx)

		local player = cx.quest:GetPlayer()

		local function EndConvo(final_talk)
			cx:Talk(final_talk)
			cx.quest:Complete("bandicoot_swamp")
			cx:End()
		end

		--opt 3A: Player lets Hoggins hold their bag
		local function Opt3A_Response()
			cx:Talk("OPT3A_RESPONSE")

			--hoggins returns your pack, a little lighter (lmao gotchaaa)
			TakeACut(player)

			--check if player has resources to make a potion
			if admission_recipe:CanPlayerCraft(player) then
				--check if player has potion space available
				if player.components.potiondrinker:CanGetMorePotionUses() then
					cx:Talk("OPT3A_RESPONSE_ALT")
					cx:Opt("OPT_4A")
						:MakePositive()
						:Fn(function()
							OnStartCooking(admission_recipe, player)
							EndConvo("OPT4A_RESPONSE")
						end)
					cx:AddEnd("OPT_4B")
						:MakePositive()
						:Fn(function()
							EndConvo("OPT7_RESPONSE")
						end)
				end
			--if player doesnt have the resources to buy a potion or already bought one, give options to just end the convo
			else
				cx:AddEnd("OPT_7")
					:MakePositive()
					:Fn(function()
						EndConvo("OPT7_RESPONSE")
					end)
			end
		end

		--opt 3C: Player refuses to let Hoggins hold their bag
		local function Opt3C_Response()
			--npc response
			cx:Talk("OPT3C_RESPONSE")

			--one last chance to let him hold the bag
			cx:Opt("OPT_6A")
				:MakePositive()
				:Fn(function()
					Opt3A_Response()
				end)
			--end convo option
			cx:AddEnd("OPT_6B")
				:MakePositive()
				:Fn(function()
					EndConvo("OPT6B_RESPONSE")
				end)
		end

		--CONVERSATION PROGRAMMING STARTS HERE--
		--player asks how hoggins ended up in the swamp and he dodges the question to tell you your shoes untied
		cx:Talk("TALK")

		cx:Opt("OPT_2")
			:MakePositive()

		--response to opt 2
		cx:JoinAllOpt_Fn(function()
			cx:Talk("OPT2_RESPONSE")

			--choice responses
			--player lets hoggins hold their bag while they re-tie their shoe
			cx:Opt("OPT_3A")
				:MakePositive()
				:Fn(function()
					Opt3A_Response()
				end)

			--player refuses to let hoggins hold their bag
			cx:Opt("OPT_3C")
				:MakePositive()
				:Fn(function()
					Opt3C_Response()
				end)

			--player asks to just buy a potion
			if admission_recipe:CanPlayerCraft(player) then
				if player.components.potiondrinker:CanGetMorePotionUses() then
					cx:Opt("OPT_3B")
						:MakePositive()
						:Fn(function()
							--hoggins asks if theyre still going to leave their shoe untied
							cx:Talk("OPT3B_RESPONSE")
							OnStartCooking(admission_recipe, player)
							--agree to let hoggins hold your bag
							cx:Opt("OPT_5A")
								:MakePositive()
								:Fn(function()
									Opt3A_Response()
								end)
								--refuse to let hoggins hold your bag
							cx:Opt("OPT_5B")
								:MakePositive()
								:Fn(function()
									Opt3C_Response()
								end)
						end)
				end
			end
		end)
	end)

Q:OnAttract("owlitzer_forest", "giver", function(quest, node, sim)
return TheWorld:IsFlagUnlocked("wf_travelling_salesman") and quest_helper.IsInDungeon("owlitzer_forest") and limitededition_potion_recipe:CanPlayerCraft(cx.quest:GetPlayer()) end)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings.sedament_tundra)
	:Fn(function(cx)
		quest_helper.SetPlayerSpecies(cx)
		
		local player = quest_helper.GetPlayer(cx)

		local function ConvoEnd(final_talk)
			cx:Talk(final_talk)
			cx.quest:Complete("owlitzer_forest")
			cx:End()
		end

		local clicked_1A = false

		local function OptMenu()
			if clicked_1A == false then
				cx:Opt("OPT_1A")
					:MakePositive()
					:Fn(function()
						clicked_1A = true
						cx:Talk("OPT1A_RESPONSE")
						OptMenu()
					end)
			end

			--buy the "limited edition" potion
			cx:Opt("OPT_1B")
				:MakePositive()
				:Fn(function()
					--check if player has resources to make a potion
					if limitededition_potion_recipe:CanPlayerCraft(player) then
						--check if player has potion space available
						if player.components.potiondrinker:CanGetMorePotionUses() then
							OnStartCooking(limitededition_potion_recipe, player)
							ConvoEnd("OPT1B_RESPONSE")
						else
							ConvoEnd("OPT1B_RESPONSE_ALT_NOFUNDS")
						end
					else
						ConvoEnd("OPT1B_RESPONSE_ALT_NOSPACE")
					end
				end)

			--buy a regular potion (option only appears if you can get a regular potion)
			if admission_recipe:CanPlayerCraft(player) then
				--check if player has potion space available
				if player.components.potiondrinker:CanGetMorePotionUses() then
					cx:Opt("OPT_1C")
						:MakePositive()
						:Fn(function()
							OnStartCooking(admission_recipe, player)
							ConvoEnd("OPT1C_RESPONSE")
						end)
				end
			end

			--refuse both regular and limited edition potion
			cx:Opt("OPT_1D")
				:MakePositive()
				:Fn(function()
					local function OPT2B(btn_text)
						cx:AddEnd(btn_text)
						:MakePositive()
						:Fn(function()
							ConvoEnd("OPT2B_RESPONSE")
						end)
					end

					--hoggins is gonna try to win you over one last time
					cx:Talk("OPT1D_RESPONSE")

					--buy a potion last minute (option only appears if you can get a potion)
					if player.components.potiondrinker:CanGetMorePotionUses() then
						--check if player has potion space available
						if limitededition_potion_recipe:CanPlayerCraft(player) then
							cx:Opt("OPT_2A")
								:MakePositive()
								:Fn(function()
									OnStartCooking(limitededition_potion_recipe, player)
									ConvoEnd("OPT2A_RESPONSE")
								end)
							--refusal button if you have both space and money
							OPT2B("OPT_2B")
						else
							--refusal button if you have space but no money
							OPT2B("OPT_2B_NOFUNDS")
						end						
					else
						--refusal button if you have no space
						OPT2B("OPT_2B_NOSPACE")
					end
				end)
		end

		cx:Talk("TALK")
		OptMenu()
	end)

return Q
