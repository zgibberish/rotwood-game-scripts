local Consumable = require 'defs.consumable'
local lume = require "util.lume"
local kstring = require "util.kstring"
require "util.tableutil"

local townpillar = {
	default = {},
}

local function _OpenHeartScreen(inst, player)
	player.components.heartmanager:_OpenHeartScreen()
end

local function OnInteract(inst, player, opts)
	local hearts = inst.components.heartdeposit:GetHeartsForPlayer(player)
	if #hearts > 0 then
		-- if player has any heart, deposit the heart
		local to_deposit = inst.components.heartdeposit:GetBestHeartToDeposit(hearts)
		inst.components.heartdeposit:DepositHeartForPlayer(player, to_deposit)

		inst:PushEvent("deposit_heart")
		player.sg:GoToState('deposit_heart')
	else
		-- if the player doesn't have a heart, open the heart screen
		_OpenHeartScreen(inst, player)
		player.sg:GoToState('idle_accept')
	end
end

local function CanInteract(inst, player, is_focused)
	return player:IsFlagUnlocked("pf_energy_pillar_unlocked") -- only if they've talked to Flitt about the pillar
end

local function BuildInteractLabel(inst, player)
	local hearts = inst.components.heartdeposit:GetHeartsForPlayer(player)
	if #hearts > 0 then
		-- if player has any heart, deposit the heart
		local to_deposit = inst.components.heartdeposit:GetBestHeartToDeposit(hearts)
		local def = Consumable.FindItem(to_deposit.id)
		return STRINGS.UI.HEARTSCREEN.INTERACT.BTN_PLACE_IN_WELL:subfmt({
				heartstone = def.pretty.name,
			})
	else
		-- if the player doesn't have a heart, open the heart screen
		return STRINGS.UI.HEARTSCREEN.INTERACT.BTN_MANAGE_HEARTSTONES
	end
end

local function OnPlayerApproach(inst)
	-- If any nearby player has a heart that can be deposited, open the pillar
	local players = inst.components.playerproxradial:FindPlayersInRange()
	if inst.components.heartdeposit:IsAnyPlayerEligible(players) then
		inst:PushEvent("open_pillar")
	end
end

local function OnPlayerLeave(inst)
	-- If no nearby players have a heart that can be deposited, close the pillar
	local players = inst.components.playerproxradial:FindPlayersInRange()
	if not inst.components.heartdeposit:IsAnyPlayerEligible(players) then
		inst:PushEvent("close_pillar")
	end
end

function townpillar.default.CustomInit(inst, opts)
	assert(opts)
	inst:SetStateGraph("sg_town_pillar")
	townpillar.ConfigureTownPillar(inst, opts)
end

function townpillar.ConfigureTownPillar(inst, opts)
	inst:AddComponent("heartdeposit")

	inst:AddComponent("interactable")

	inst:AddComponent("playerproxradial")
	inst.components.playerproxradial:SetRadius(7)
	inst.components.playerproxradial:SetOnNearFn(OnPlayerApproach)
	inst.components.playerproxradial:SetOnFarFn(OnPlayerLeave)

	inst.entity:AddNetwork()
	inst.Network:SetTypeHostAuth()

	-- collaberative_craft
	inst:AddTag("town_pillar")
	inst:AddTag("large") -- this is for the offscreen indicator to scale correctly

	inst.components.interactable:SetRadius(7)
		:SetInteractStateName("townpillar_interact")
		:SetInteractConditionFn(function(_, player, is_focused) return CanInteract(inst, player, is_focused) end)
		:SetOnInteractFn(function(_, player) OnInteract(inst, player, opts) end)
		:SetupForButtonPrompt(BuildInteractLabel, nil, nil, 6)
end

return townpillar
