local SpecialEventRoom = require("defs.specialeventrooms.specialeventroom")
local lume = require "util.lume"
local Power = require("defs.powers.power")
local fmodtable = require "defs.sound.fmodtable"
local powerutil = require "util.powerutil"
local SGCommon = require("stategraphs/sg_common")

function SpecialEventRoom.AddConversationSpecialEventRoom(id, data)
	if not data.event_type then
		data.event_type = SpecialEventRoom.Types.CONVERSATION
	end
	SpecialEventRoom.AddSpecialEventRoom(SpecialEventRoom.Types.CONVERSATION, id, data)
end

local function SetPlayerStartedEvent(inst, player)
	if not inst.eventhost.components.conversation.temp.used_event then
		inst.eventhost.components.conversation.temp.used_event = {}
	end
	inst.eventhost.components.conversation.temp.used_event[player] = true
end

local function HostAttacksPlayer(inst, player, damage, knockdown)
	local dir = inst.eventhost:GetAngleTo(player)

	inst.eventhost.components.combat:SetBaseDamage(inst, damage)

	-- knockback reactions are only setup for weapons.
	player.sg:GoToState("unsheathe_fast")

	local attack = Attack(inst.eventhost, player)
	attack:SetIgnoresArmour(true)
	attack:SetSkipPowerDamageModifiers(true)
	attack:SetDir(dir)
	if knockdown then
		inst.eventhost.components.combat:DoKnockdownAttack(attack)
	else
		inst.eventhost.components.combat:DoKnockbackAttack(attack)
	end
	SGCommon.Fns.ApplyHitstop(attack, HitStopLevel.HEAVY)

	powerutil.SpawnPowerHitFx("fx_hit_player_round", inst.eventhost, player, 0.5, 0, HitStopLevel.HEAVY)
	SpawnHurtFx(inst.eventhost, player, 0.5, dir, HitStopLevel.HEAVY)
end

SpecialEventRoom.AddConversationSpecialEventRoom("coin_flip_max_health_or_damage",
{
	prefabs = {
		"coinflip_in_heads",
		"coinflip_hold_heads",
		"coinflip_out_heads",
		"coinflip_in_tails",
		"coinflip_hold_tails",
		"coinflip_out_tails",
	},

	prerequisite_fn = function(inst, players)
		-- If any player has already won a coin flip, do not allow this event to show up again.
		for _,player in pairs(players) do
			local health_power = player.components.powermanager:GetPowerByName("max_health_wanderer")
			if health_power ~= nil then
				return false
			end
		end

		return true
	end,

	on_init_fn = function(inst)
		inst.player_choices = {}
	end,

	on_start_fn = function(inst, player)
		inst.eventhost.components.combat:SetBaseDamage(inst, 250)

		SetPlayerStartedEvent(inst, player)

		local rng = inst.components.specialeventroommanager:GetRNG()
		local coin = { "heads", "tails" }
		local coin_flip = rng:PickValue(coin)
		inst.components.specialeventroommanager.mem.coin_flip = coin_flip

		local position = player:GetPosition()

		local coin_prefab = "coinflip_in_"..coin_flip
		local params =
		{
			offy = 5,
		}
		local coin_fx = powerutil.SpawnFxOnEntity(coin_prefab, player, params)

		-- local coin_fx = SpawnPrefab(coin_prefab, inst)
		-- coin_fx.Transform:SetPosition(position.x, position.y + y_offset, position.z)

		coin_fx:ListenForEvent("onremove", function()
			local hold_prefab = "coinflip_hold_"..coin_flip
			local hold_fx = powerutil.SpawnFxOnEntity(hold_prefab, player, params)

			hold_fx:ListenForEvent("onremove", function()
				local out_prefab = "coinflip_out_"..coin_flip
				local out_fx = powerutil.SpawnFxOnEntity(out_prefab, player, params)

				inst.components.specialeventroommanager:FinishEvent(player)
			end)
		end)
	end,

	on_finish_fn = function(inst, player)
		if inst.components.specialeventroommanager.mem.coin_flip == inst.player_choices[player] then
			local pm = player.components.powermanager
			local def = Power.FindPowerByName("max_health_wanderer")
			local power = pm:CreatePower(def)
			pm:AddPower(power)
			
			
			player:DoTaskInTime(0.5, function()
				TheDungeon.HUD:MakePopPower({ target = player, power = "max_health_wanderer", scale = 0.8, size = 75, fade_time = 3, y_offset = 550 })
			end)
		else
			HostAttacksPlayer(inst, player, 250, true)
		end
		inst.components.specialeventroommanager.mem.coin_flip = nil
	end,

	event_triggers =
	{
	}
})

SpecialEventRoom.AddConversationSpecialEventRoom("upgrade_random_power",
{
	prefabs = { },

	prerequisite_fn = function(inst, players)
		local eligible_players = {}
		for _,player in pairs(players) do
			if #player.components.powermanager:GetUpgradeablePowers() > 0 then
				table.insert(eligible_players, player)
			end
		end

		return #eligible_players > 0
	end,

	on_init_fn = function(inst)
		inst.player_choices = {}
	end,

	on_start_fn = function(inst, player)
		inst.eventhost.components.combat:SetBaseDamage(inst, 250)

		SetPlayerStartedEvent(inst, player)
		local rng = inst.components.specialeventroommanager:GetRNG()
		local powers = player.components.powermanager:GetUpgradeablePowers()
		local randompower = nil
		if #powers > 0 then
			randompower = rng:PickValue(powers)
			inst.components.specialeventroommanager.mem.selectedpower = randompower
		end
		inst.components.specialeventroommanager:FinishEvent(player)
	end,

	on_finish_fn = function(inst, player)
		-- jbell
		-- currently intentional: if they have no power, they still lose health. Should this character be allowed to punish players for logical mistakes like this?
		-- I think yes, but could easily be convinced no :)
		if inst.components.specialeventroommanager.mem.selectedpower ~= nil then
			player:DoTaskInAnimFrames(10, function()
				TheDungeon.HUD:MakePopPower({ target = player, power_instance = inst.components.specialeventroommanager.mem.selectedpower, scale = 0.8, size = 75, fade_time = 10, x_offset = -500, y_offset = 550 })
				TheDungeon.HUD:MakePopText({ target = player, button = "-->", color = UICOLORS.WHITE, size = 150, fade_time = 8, x_offset = 0, y_offset = 550 })
				player.components.powermanager:UpgradePower(inst.components.specialeventroommanager.mem.selectedpower.def)
				TheDungeon.HUD:MakePopPower({ target = player, power_instance = inst.components.specialeventroommanager.mem.selectedpower, scale = 0.8, size = 75, fade_time = 10, x_offset = 700, y_offset = 550 })
				inst.components.specialeventroommanager.mem.selectedpower = nil
			end)
		end

		HostAttacksPlayer(inst, player, 250)
	end,

	event_triggers =
	{
	}
})
--[[
SpecialEventRoom.AddConversationSpecialEventRoom("lose_power_gain_health",
{
	--TODO: add condition, later dungeon progression
	prefabs = { },

	prerequisite_fn = function(inst, players)
		local eligible_players = {}
		for _,player in pairs(players) do
			if #player.components.powermanager:GetAllPowersInAcquiredOrder() ~= 0 then
				table.insert(eligible_players, player)
			end
		end

		return #eligible_players > 0
	end,

	on_init_fn = function(inst)
		inst.player_choices = {}
	end,

	on_start_fn = function(inst, player)
		SetPlayerStartedEvent(inst, player)
		local powers = player.components.powermanager:GetAllPowersInAcquiredOrder()
		powers = player.components.powermanager:StripUnselectablePowers(powers)

		local function OnDoRemove(power)
			inst.components.specialeventroommanager.mem.selectedpower = power
			inst.components.specialeventroommanager:FinishEvent(player)
		end

		local PowerSelectionScreen = require "screens.dungeon.powerselectionscreen"
		local screen = PowerSelectionScreen(player, powers, PowerSelectionScreen.SelectAction.s.Remove, function(...) OnDoRemove(...) end, true)
		TheFrontEnd:PushScreen(screen)
	end,

	on_finish_fn = function(inst, player)
		if inst.components.specialeventroommanager.mem.selectedpower ~= nil then
			local rarity = inst.components.specialeventroommanager.mem.selectedpower.rarity
			if rarity == Power.Rarity.COMMON then
				local power_heal = Attack(player, player)
				power_heal:SetHeal(250)
				player.components.combat:ApplyHeal(power_heal)

				-- player.components.health:DoDelta(250) --TODO: replace with an "attack"
				player:DoTaskInTime(1.5, function() TheDungeon.HUD:MakePopText({ target = player, button = "Health +250!", color = UICOLORS.HEALTH, fade_time = 3 }) end) --MakeCookingButton({ target = player, button = "Health +250!" }) end)
			elseif rarity == Power.Rarity.EPIC then
				local missing = player.components.health:GetMissing()
				local power_heal = Attack(player, player)
				power_heal:SetHeal(missing)
				player.components.combat:ApplyHeal(power_heal)

				-- player.components.health:DoDelta(missing) --TODO: replace with an "attack"
				player:DoTaskInTime(1.5, function() TheDungeon.HUD:MakePopText({ target = player, button = "Full Heal!", color = UICOLORS.HEALTH, fade_time = 3 }) end)
			elseif rarity == Power.Rarity.LEGENDARY then
				local max = player.components.health:GetMax()
				player.components.health:SetMax(max + 1000)

				local missing = player.components.health:GetMissing()
				local power_heal = Attack(player, player)
				power_heal:SetHeal(missing)
				player.components.combat:ApplyHeal(power_heal)

				-- player.components.health:DoDelta(missing) --TODO: replace with an "attack"
				player:DoTaskInTime(1.5, function() TheDungeon.HUD:MakePopText({ target = player, button = "Max Health +1000!", color = UICOLORS.HEALTH, fade_time = 3 }) end)
				player:DoTaskInTime(3, function() TheDungeon.HUD:MakePopText({ target = player, button = "Full Heal!", color = UICOLORS.HEALTH, fade_time = 3 }) end)
			end
			inst.components.specialeventroommanager.mem.selectedpower = nil
		end
		--TODO: animate focus grab on the power widget
	end,

	event_triggers =
	{
	}
})

SpecialEventRoom.AddConversationSpecialEventRoom("transmute_power",
{
	prefabs = { },

	prerequisite_fn = function(inst, players)
		local eligible_players = {}
		for _,player in pairs(players) do
			if #player.components.powermanager:GetUpgradeablePowers() > 0 then
				table.insert(eligible_players, player)
			end
		end

		return #eligible_players > 0
	end,

	on_init_fn = function(inst)
		inst.player_choices = {}
	end,

	on_start_fn = function(inst, player)
		SetPlayerStartedEvent(inst, player)
		local powers = player.components.powermanager:GetUpgradeablePowers()
		powers = player.components.powermanager:StripUnselectablePowers(powers)

		local function OnDoRemove(power)
			inst.components.specialeventroommanager.mem.selectedpower = power
			inst.components.specialeventroommanager:FinishEvent(player)
		end

		local PowerSelectionScreen = require "screens.dungeon.powerselectionscreen"
		local screen = PowerSelectionScreen(player, powers, PowerSelectionScreen.SelectAction.s.Remove, function(...) OnDoRemove(...) end, true)
		TheFrontEnd:PushScreen(screen)
	end,

	on_finish_fn = function(inst, player)
		if inst.components.specialeventroommanager.mem.selectedpower ~= nil then
			local next_rarity = Power.GetNextRarity(inst.components.specialeventroommanager.mem.selectedpower)

			local powerdropmanager = TheWorld.components.powerdropmanager
			local options = Power.GetAllPowers()
			options = powerdropmanager:FilterByDroppable(options, player)
			options = powerdropmanager:FilterByHas(options, player)
			options = powerdropmanager:FilterByEligible(options, player)

			local newpower = powerdropmanager:GetRandomPowerOfRarity(options, next_rarity)

			local pm = player.components.powermanager
			local power = pm:CreatePower(newpower)
			pm:AddPower(power)

			player:DoTaskInTime(0.5, function() TheDungeon.HUD:MakePopText({ target = player, button = "+"..newpower.pretty.name, color = UICOLORS.HEALTH, fade_time = 3 }) end)
		end
		inst.components.specialeventroommanager.mem.selectedpower = nil
		--TODO: animate focus grab on the power widget
	end,

	event_triggers =
	{
	}
})
--]]
SpecialEventRoom.AddConversationSpecialEventRoom("free_power_epic",
{
	prefabs = { },

	on_init_fn = function(inst)
		inst.player_choices = {}
	end,

	on_start_fn = function(inst, player)
		SetPlayerStartedEvent(inst, player)
		inst.components.specialeventroommanager:FinishEvent(player)
	end,

	on_finish_fn = function(inst, player)
		local powerdropmanager = TheWorld.components.powerdropmanager
		local options = Power.GetAllPowers()
		options = powerdropmanager:FilterByDroppable(options, player)
		options = powerdropmanager:FilterByHas(options, player)
		options = powerdropmanager:FilterByEligible(options, player)
		local newpower = powerdropmanager:GetRandomPowerOfRarity(options, Power.Rarity.EPIC)

		local pm = player.components.powermanager
		local power = pm:CreatePower(newpower)
		pm:AddPower(power)

		player:DoTaskInTime(0.5, function()
			TheDungeon.HUD:MakePopPower({ target = player, power = newpower.name, scale = 0.8, size = 75, fade_time = 3, y_offset = 550 })
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.ui_wanderer_grantRelic)
		end)
	end,

	event_triggers =
	{
	}
})

SpecialEventRoom.AddConversationSpecialEventRoom("free_power_legendary",
{
	prefabs = { },

	on_init_fn = function(inst)
		inst.player_choices = {}
	end,

	on_start_fn = function(inst, player)
		SetPlayerStartedEvent(inst, player)
		inst.components.specialeventroommanager:FinishEvent(player)
	end,

	on_finish_fn = function(inst, player)
		local powerdropmanager = TheWorld.components.powerdropmanager
		local options = Power.GetAllPowers()
		options = powerdropmanager:FilterByDroppable(options, player)
		options = powerdropmanager:FilterByHas(options, player)
		options = powerdropmanager:FilterByEligible(options, player)
		local newpower = powerdropmanager:GetRandomPowerOfRarity(options, Power.Rarity.LEGENDARY)

		local pm = player.components.powermanager
		local power = pm:CreatePower(newpower)
		pm:AddPower(power)

		player:DoTaskInTime(0.5, function()
			TheDungeon.HUD:MakePopPower({ target = player, power = newpower.name, scale = 0.8, size = 75, fade_time = 3, y_offset = 550 })
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.ui_wanderer_grantRelic)
		end)
	end,

	event_triggers =
	{
	}
})

SpecialEventRoom.AddConversationSpecialEventRoom("potion_refill",
{
	prefabs = { },

	prerequisite_fn = function(inst, players)
		local eligible_players = {}
		for _,player in pairs(players) do
			if player.components.potiondrinker:CanGetMorePotionUses() then
				table.insert(eligible_players, player)
			end
		end

		return #eligible_players > 0
	end,

	on_init_fn = function(inst)
		inst.player_choices = {}
	end,

	on_start_fn = function(inst, player)
		SetPlayerStartedEvent(inst, player)
		inst.components.specialeventroommanager:FinishEvent(player)
	end,

	on_finish_fn = function(inst, player)
		player.components.potiondrinker:RefillPotion()

		-- player:DoTaskInTime(0.5, function() TheDungeon.HUD:MakePopText({ target = player, button = "+"..newpower.pretty.name, color = UICOLORS.HEALTH, fade_time = 3 }) end)
	end,

	event_triggers =
	{
	}
})

SpecialEventRoom.AddConversationSpecialEventRoom("no_thing",
{
	prefabs = { },

	prerequisite_fn = function(inst, players)
		return false -- jambell: disable for now
	end,

	on_init_fn = function(inst)
		inst.player_choices = {}
	end,

	on_start_fn = function(inst, player)
		inst.components.specialeventroommanager:FinishEvent(player)
	end,

	on_finish_fn = function(inst, player)
	end,

	event_triggers =
	{
	}
})

-- TODO: SOMEONE -- confirm these will support multiplayer if brought back
-- SpecialEventRoom.AddConversationSpecialEventRoom("spin_wheel",
-- {
-- 	prefabs = { "" },

-- 	on_start_fn = function(inst, player)
-- 		inst.player_choices = {}
-- 		inst.rng = inst.components.specialeventroommanager:GetRNG()
-- 		inst.options = {
-- 			--good options
-- 			max_health = function(player)
-- 				print("max_health")
-- 				local pm = player.components.powermanager
-- 				local def = Power.FindPowerByName("max_health")
-- 				local power = pm:CreatePower(def)
-- 				pm:AddPower(power)
-- 			end,

-- 			heal_full = function(player)
-- 				print("heal_full")
-- 				player.components.health:DoDelta(player.components.health:GetMissing())
-- 			end,

-- 			gain_currency = function(player)
-- 				print("gain_currency")
-- 				local Consumable = require'defs.consumable'
-- 				local konjurdef = Consumable.FindItem("konjur")
-- 				local inventory = player.components.inventoryhoard
-- 				inventory:AddStackable(konjurdef, 100)
-- 			end,

-- 			-- add_power = function(player)
-- 			-- choose a random player power and add it
-- 			-- end,

-- 			-- bad options
-- 			damage = function(player)
-- 				print("damage")
-- 				local currenthealth = player.components.health:GetCurrent()
-- 				local damage = math.floor(currenthealth * .25)
-- 				player.components.health:DoDelta(-damage) --TODO: replace with an "attack"
-- 			end,

-- 			-- lose_power = function(player)
-- 			-- pick one of the player's powers and remove it
-- 			-- end,
-- 		}

-- 		inst.components.specialeventroommanager:FinishEvent(player) --TODO: replace with dialog box close send event
-- 	end,

-- 	on_finish_fn = function(inst, player)
-- 		inst.choice = inst.rng:PickValue(inst.options)
-- 		inst.choice(player)
-- 	end,

-- 	event_triggers =
-- 	{
-- 	}
-- })

-- SpecialEventRoom.AddConversationSpecialEventRoom("heal_or_maxhealth",
-- {
-- 	prefabs = { "" },

-- 	on_start_fn = function(inst, player)
-- 		inst.rng = inst.components.specialeventroommanager:GetRNG()
-- 		inst.player_choices = {}
-- 		inst.options = {
-- 			max_health = function(player)
-- 				print("max_health")
-- 				local pm = player.components.powermanager
-- 				local def = Power.FindPowerByName("max_health")
-- 				local power = pm:CreatePower(def)
-- 				pm:AddPower(power)
-- 			end,

-- 			heal = function(player)
-- 				print("heal")
-- 				local maxhealth = player.components.health:GetMax()
-- 				local heal = math.floor(maxhealth * .33)
-- 				player.components.health:DoDelta(heal)
-- 			end,
-- 		}

-- 		-- store the fn the player chose in inst.player_choices[player]
-- 		inst.player_choices[player] = inst.rng:PickValue(inst.options) --TODO get the choice from dialog instead
-- 		inst.components.specialeventroommanager:FinishEvent(player) --TODO: replace with dialog box close send event
-- 	end,

-- 	on_finish_fn = function(inst, player)
-- 		local fn = inst.player_choices[player]
-- 		fn(player)
-- 	end,

-- 	event_triggers =
-- 	{
-- 	}
-- })

-- IDEAS:
-- Spend Health, Upgrade a selected player power
-- Spend Konjur for health, power, etc?
-- Gain konjur+Lose health OR lose konjur
