local Consumable = require 'defs.consumable'
local Powers = require 'defs.powers'
local Power = require 'defs.powers.power'
local SinglePickup = require "components.singlepickup"
local VendingMachineWares = require "defs.vendingmachine_wares"
local FollowPrompt = require "widgets.ftf.followprompt"
local Text = require "widgets.text"
local Vec3 = require "math.modules.vec3"

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
	local root = FollowPrompt(name)
	TheDungeon.HUD:AddWorldWidget(root)
	root
		:SetTarget(target)
		:SetOffsetFromTarget(Vec3(0, 5, 0))
		:AddChild(label)
	return root
end

local function ExtendInteractableWithTextPopup(inst, text)
	local _on_approach = function(inst, player)
		if not inst.popup then
			inst.popup = MakeTextPopup(inst.prefab..inst.GUID, inst, text)
		end
	end

	local _on_depart = function(inst, player)
		if inst.popup then
			inst.popup:Remove()
			inst.popup = nil
		end
	end

	return inst.components.interactable:SetupForButtonPrompt(SinglePickup.BUTTON_LABEL, _on_approach, _on_depart)
end

local items = {
	potion_refill_single =
	{
		fn = function(inst)
			ExtendInteractableWithTextPopup(inst, VendingMachineWares.potion.name)
				:SetInteractConditionFn(function(inst, player)
					local potiondrinker = player.components.potiondrinker
					return potiondrinker ~= nil and potiondrinker:GetRemainingPotionUses() <= 0
				end)

			inst:AddComponent("warevisualizer")
			inst:SetStateGraph("sg_shopitem")

			-- Re-initialize the state graph to use the alternate animation set.
			inst.sg.mem.use_alternate_anims = true
			inst.sg:GoToState("spawn")

			inst.components.interactable:SetInteractConditionFn(function(inst, player)
				local potiondrinker = player.components.potiondrinker
				return potiondrinker ~= nil and potiondrinker:GetRemainingPotionUses() <= 0
			end)

			inst.components.singlepickup:SetOnConsumedCallback(function(inst, consuming_player)
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

			ExtendInteractableWithTextPopup(inst, VendingMachineWares.upgrade.name)
				:SetInteractConditionFn(function(inst, player)
					local powermanager = player.components.powermanager
					local eligible_powers = powermanager:GetUpgradeablePowers()
					return #eligible_powers > 0
				end)

			inst.components.singlepickup:SetOnConsumedCallback(function(inst, consuming_player)
				if consuming_player then
					local powers = consuming_player.components.powermanager:GetUpgradeablePowers()
					local PowerSelectionScreen = require "screens.dungeon.powerselectionscreen"
					local screen = PowerSelectionScreen(
						consuming_player, 
						powers, 
						PowerSelectionScreen.SelectAction.s.Upgrade, 
						function(power)	end, 
						true
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
			ExtendInteractableWithTextPopup(inst, VendingMachineWares.shield.name)
				:SetInteractConditionFn(function(inst, player)
					local powermanager = player.components.powermanager
					local shield_def = Power.Items.SHIELD.shield
					local shield_power = powermanager:GetPower(shield_def)

					if shield_power and powermanager:GetPowerStacks(shield_def) == shield_power.max_stacks then
						return false
					else
						return true
					end
				end)

			inst.components.singlepickup:SetOnConsumedCallback(function(inst, consuming_player)
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
			ExtendInteractableWithTextPopup(inst, VendingMachineWares.corestone.name)

			inst:SetStateGraph("sg_shopitem")
			inst.sg.mem.use_alternate_anims = false			

			inst.components.singlepickup:SetOnConsumedCallback(function(inst, consuming_player)
				if consuming_player then
					local item = Consumable.FindItem("konjur_soul_lesser")
					consuming_player:PushEvent("get_loot", { item = item, count = 1 })
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
			local _on_approach = function(inst, player)
				if inst.popup then
					return
				end
				inst.popup = FollowPrompt("PowerPopup")
				TheDungeon.HUD:AddWorldWidget(inst.popup)
				inst.popup
					:SetTarget(inst)
					:SetOffsetFromTarget(Vec3(0, 6.25, 0))
					:AddChild(VendingMachineWares.MakePowerDetailsWidgetFromPower(inst.components.warevisualizer.power))
			end

			local _on_depart = function(inst, player)
				if inst.popup then
					inst.popup:Remove()
					inst.popup = nil
				end
			end

			inst.components.interactable:SetupForButtonPrompt(SinglePickup.BUTTON_LABEL, _on_approach, _on_depart)

			inst:AddComponent("warevisualizer")
			inst:SetStateGraph("sg_shopitem")

			-- Re-initialize the state graph to use the alternate animation set.
			inst.sg.mem.use_alternate_anims = true
			inst.sg:GoToState("spawn")

			inst.components.singlepickup:SetOnConsumedCallback(function(inst, consuming_player)
				if consuming_player then
					local power_def = Powers.FindPowerByName(inst.components.warevisualizer.power)
					local power_mgr = consuming_player.components.powermanager
					power_mgr:AddPower(power_mgr:CreatePower(power_def))
					consuming_player.sg:GoToState("powerup_accept")
				end
				return PlayDespawnAnimLocally(inst)
			end)
		end,
	},

	power_pickup_party =
	{
		fn = function(inst)

		end,
	},

}

return items
