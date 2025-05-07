local Consumable = require 'defs.consumable'
local Powers = require 'defs.powers'
local Power = require 'defs.powers.power'
local SinglePickup = require "components.singlepickup"
local VendingMachineWares = require "defs.vendingmachine_wares"
local FollowPrompt = require "widgets.ftf.followprompt"
local Text = require "widgets.text"
local Vec3 = require "math.modules.vec3"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

-- On consumption, the host will terminate the pickup before the despawn animation has a chance to
-- propagate to remote clients. To make the despawn animation play on all clients, spawn a brand new
-- pickup locally on each client and force it into the despawn state.
local function PlayDespawnAnimLocally(inst, pickup_prefab, despawn_state)
	if TheNet:IsHost() then
		inst:PushEvent(despawn_state or "despawn")
		return true
	else
		return false
	end
end

local function MakeTextPopup(name, target, text)
	-- TODO @chrisp #vend - copy-pasta from vendingmachine...should centralize style
	local label = Text(FONTFACE.DEFAULT, FONTSIZE.DAMAGENUM_PLAYER, "", UICOLORS.INFO)
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()
		:SetText(text)
	local root = FollowPrompt() -- TODO: Pass player to make button icons match them
		:SetName(name)
	TheDungeon.HUD:AddWorldWidget(root)
	root
		:SetTarget(target)
		:SetRegistration("center", "bottom")
		:SetOffsetFromTarget(Vec3(0, 3, 0))
		:AddChild(label)
	return root
end

local function ExtendSinglePickupWithTextPopup(inst, text)	
	local show_popup_task
	local _on_approach = function(inst, player)
		if inst.popup then
			return
		end
		local ShowPopUp = function()
			inst.popup = MakeTextPopup(inst.prefab..inst.GUID, inst, text)
		end
		local TryShowPopUp = function()
			if not inst.components.warevisualizer or (inst.components.warevisualizer and inst.components.warevisualizer:IsInitialized()) then
				ShowPopUp()
				show_popup_task:Cancel()
				show_popup_task = nil
			end
		end
		if not inst.components.warevisualizer or (inst.components.warevisualizer and inst.components.warevisualizer:IsInitialized()) then
			ShowPopUp()
		else
			show_popup_task = inst:DoPeriodicTicksTask(1, TryShowPopUp)
		end
	end

	local _on_depart = function(inst, player)
		if inst.popup and inst.components.interactable:GetFocusedPlayerCount() == 0 then
			inst.popup:Remove()
			inst.popup = nil
		end
		if show_popup_task then
			show_popup_task:Cancel()
			show_popup_task = nil
		end
	end

	return inst.components.singlepickup
		:SetOnGainFocusFn(_on_approach)
		:SetOnLoseFocusFn(_on_depart)
end

local items = {
	potion_refill_single =
	{
		fn = function(inst)
			inst:AddComponent("warevisualizer")
			inst:SetStateGraph("sg_shopitem")

			-- Re-initialize the state graph to use the alternate animation set.
			inst.sg.mem.use_alternate_anims = true
			inst.sg:GoToState("spawn")

			ExtendSinglePickupWithTextPopup(inst, VendingMachineWares.potion.name)
				:SetCanInteractFn(function(inst, player)
					local potiondrinker = player.components.potiondrinker
					if not potiondrinker then
						return false
					end
					if potiondrinker:GetRemainingPotionUses() > 0 then
						return false, STRINGS.UI.SHOP_ITEM.POTION.ALREADY_OWNED
					end
					return true
				end)
				:SetOnConsumedCallback(function(inst, consuming_player)
					if consuming_player then
						consuming_player.components.potiondrinker:RefillPotion()
					end
					return PlayDespawnAnimLocally(inst)
				end)
		end,
	},

	potion_refill_party =
	{
		fn = function(inst)
			-- TODO: Let everyone refill their potion
		end,
	},

	relic_upgrade_single =
	{
		fn = function(inst)
			inst:SetStateGraph("sg_shopitem")

			ExtendSinglePickupWithTextPopup(inst, VendingMachineWares.upgrade.name)
				:SetCanInteractFn(function(inst, player)
					local powermanager = player.components.powermanager
					local eligible_powers = powermanager:GetUpgradeablePowers()
					if #eligible_powers <= 0 then
						return false, STRINGS.UI.SHOP_ITEM.UPGRADE.NO_UPGRADEABLE_POWERS
					end
					return true
				end)
				:SetOnConsumedCallback(function(inst, consuming_player)
					if consuming_player then
						local powers = consuming_player.components.powermanager:GetUpgradeablePowers()
						local PowerSelectionScreen = require "screens.dungeon.powerselectionscreen"
						local screen = PowerSelectionScreen(
							consuming_player, 
							powers, 
							PowerSelectionScreen.SelectAction.s.Upgrade, 
							function(power)	end, 
							true, -- Free
							true -- Prevent canceling
						)
						TheFrontEnd:PushScreen(screen)
					end
					return PlayDespawnAnimLocally(inst)
				end)
		end,
	},

	relic_upgrade_party =
	{
		fn = function(inst)
			-- TODO: Let everyone upgrade a relic
		end,
	},

	shield_refill_single =
	{
		fn = function(inst)
			ExtendSinglePickupWithTextPopup(inst, VendingMachineWares.shield.name)
				:SetCanInteractFn(function(inst, player)
					local powermanager = player.components.powermanager
					local shield_def = Power.Items.SHIELD.shield
					local shield_power = powermanager:GetPower(shield_def)
					if shield_power and powermanager:GetPowerStacks(shield_def) == shield_power.max_stacks then
						return false, STRINGS.UI.SHOP_ITEM.SHIELD.AT_MAXIMUM
					end
					return true
				end)
				:SetOnConsumedCallback(function(inst, consuming_player)
					if consuming_player then
						local powermanager = consuming_player.components.powermanager
						local shield_def = Power.Items.SHIELD.shield
						local shield_power = powermanager:GetPower(shield_def)

						if shield_power then
							powermanager:SetPowerStacks(shield_def, shield_def.max_stacks)
						else
							local power = powermanager:CreatePower(shield_def)
							powermanager:AddPower(power, shield_def.max_stacks)
						end
					end
				end)
		end,
	},

	shield_refill_party =
	{
		fn = function(inst)
			-- TODO: Give everyone shield
		end,
	},

	corestone_pickup_single =
	{
		fn = function(inst)
			inst:SetStateGraph("sg_shopitem")
			inst.sg.mem.use_alternate_anims = false

			ExtendSinglePickupWithTextPopup(inst, VendingMachineWares.corestone.name)
				:SetOnConsumedCallback(function(inst, consuming_player)
					if consuming_player then
						local item = Consumable.FindItem("konjur_soul_lesser")
						consuming_player:PushEvent("get_loot", { item = item, count = 1 })
						-- this stuff doesn't work
						-- local faction
						-- if consuming_player:IsLocal() then
						-- 	faction = 1
						-- else
						-- 	faction = 2
						-- end
						soundutil.PlayCodeSound(
							consuming_player,
							fmodtable.Event.reward_corestone,
							{
								instigator = consuming_player,
								-- fmodparams = {
								-- 	faction = faction,
								-- },
							})
					end
					return PlayDespawnAnimLocally(inst)
				end)
		end,
	},

	corestone_pickup_party =
	{
		fn = function(inst)

		end,
	},

	power_pickup_single =
	{
		fn = function(inst)		
			local INTERACTOR_KEY <const> = "power_pickup_single"

			local show_popup_task
			local _on_approach = function(inst, player)
				if inst.popup then
					return
				end
				local ShowPopUp = function()
					inst.popup = FollowPrompt(player)
						:SetName("PowerPopup")
					TheDungeon.HUD:AddWorldWidget(inst.popup)
					inst.popup
						:SetTarget(inst)
						:SetRegistration("center", "bottom")
						:SetOffsetFromTarget(Vec3(0, 3, 0))
						:AddChild(VendingMachineWares.MakePowerDetailsWidgetFromPower(inst.components.warevisualizer.power))
				end			
				local TryShowPopUp = function()
					if inst.components.warevisualizer:IsInitialized() then
						ShowPopUp()
						show_popup_task:Cancel()
						show_popup_task = nil
					end
				end				
				if inst.components.warevisualizer:IsInitialized() then
					ShowPopUp()
				else
					show_popup_task = inst:DoPeriodicTicksTask(1, TryShowPopUp)
				end
			end

			local _can_pickup = function(power_pickup, player)
				local assigned_player = power_pickup.components.singlepickup:GetAssignedPlayer()
				if assigned_player and assigned_player ~= player then
					return false, STRINGS.UI.SHOP_ITEM.POWER.NOT_MINE
				end

				if not power_pickup.components.warevisualizer:IsInitialized() then
					return false
				end

				if power_pickup.sg:HasStateTag("busy") then
					return false
				end

				local power_mgr = player.components.powermanager
				local can, reasons = power_mgr:CanPickUpPowerDrop()
				if not can then
					return false, reasons
				end

				local power_def = Powers.FindPowerByName(power_pickup.components.warevisualizer.power)
				if power_mgr:HasPower(power_def) and not power_mgr:CanUpgradePower(power_def) then
					return false, STRINGS.UI.SHOP_ITEM.POWER.FULLY_UPGRADED
				end

				return true
			end

			local _on_depart = function(inst, player)
				if inst.popup and inst.components.interactable:GetFocusedPlayerCount() == 0 then
					inst.popup:Remove()
					inst.popup = nil
				end
				if show_popup_task then
					show_popup_task:Cancel()
					show_popup_task = nil
				end
			end
				
			inst.components.singlepickup
				:SetOnGainFocusFn(_on_approach)
				:SetCanInteractFn(_can_pickup)
				:SetOnLoseFocusFn(_on_depart)
				:SetOnConsumedCallback(function(inst, consuming_player)
					if consuming_player then
						local power_def = Powers.FindPowerByName(inst.components.warevisualizer.power)
						local power_mgr = consuming_player.components.powermanager
						if power_mgr:HasPower(power_def) then
							power_mgr:UpgradePower(power_def)
						else
							power_mgr:AddPower(power_mgr:CreatePower(power_def))
						end
						power_mgr:IncrementPowerDropsPickedUp()
						consuming_player.sg:GoToState("powerup_accept")
					end
					return PlayDespawnAnimLocally(inst)
				end)

			inst:AddComponent("warevisualizer")
			inst:SetStateGraph("sg_shopitem")

			inst:AddComponent("playerhighlight") -- For highlighting which player this is assigned to, if any.

			-- Re-initialize the state graph to use the alternate animation set.
			inst.sg.mem.use_alternate_anims = true
			inst.sg:GoToState("spawn")
		end,
	},

	power_pickup_party =
	{
		fn = function(inst)

		end,
	},

}

return items
