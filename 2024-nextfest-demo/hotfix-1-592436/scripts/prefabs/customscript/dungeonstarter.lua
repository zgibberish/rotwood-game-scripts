require "util.tableutil"


local dungeonstarter = {
	default = {},
}

local function OnEditorSpawn(inst, editor)
end

function dungeonstarter.default.CustomInit(inst, opts)
	assert(opts)
	inst.OnEditorSpawn = OnEditorSpawn
	dungeonstarter.ConfigureDungeonStarter(inst, opts)
end

local function OnRequestRun(inst, player)
	local DungeonSelectionScreen = require "screens.town.dungeonselectionscreen"
	local screen = DungeonSelectionScreen(player)
	TheFrontEnd:PushScreen(screen)
	player.sg:GoToState('idle_accept')
end

local function OnCancelRun(inst, player)
	if player and player:IsLocal() then
		local requestingPlayerID, mode, arenaWorldPrefab, regionID, locationID, seed, altMapGenID, ascensionLevel, seqNr, questParams = TheNet:GetRequestedRunData()
		local playerID = player.Network:GetPlayerID()

		if playerID == requestingPlayerID then
			TheNet:CancelRunRequest(playerID)
		end
	end
	player.sg:GoToState('idle_accept')
end

-- Interaction conditions
local function CanInteractDefault(inst, player, is_focused)
	local playerID, mode, arenaWorldPrefab, regionID, locationID, seed, altMapGenID, ascensionLevel, seqNr, questParams = TheNet:GetRequestedRunData()

	local showbutton = not playerID or TheNet:IsLocalPlayer(playerID)

	return TheWorld:HasTag("town") and showbutton
end

local function CanInteractWaiting(inst, player, is_focused)
	local playerIDToCheck = player.Network:GetPlayerID()

	local requestingPlayerID, mode, arenaWorldPrefab, regionID, locationID, seed, altMapGenID, ascensionLevel, seqNr, questParams = TheNet:GetRequestedRunData()

	local showbutton = not requestingPlayerID or requestingPlayerID == player.Network:GetPlayerID()

	return TheWorld:HasTag("town") and showbutton
end

local function BuildInteractLabel(inst, player)
	if inst.can_head_out then
		return "<p bind='Controls.Digital.ACTION' color=0> " .. STRINGS.UI.ACTIONS.HEAD_OUT
	else
		return "<p bind='Controls.Digital.ACTION' color=0> " .. STRINGS.UI.ACTIONS.CANCEL
	end
end
local function SetInteractableToCancel(inst)
	inst.can_head_out = false
	inst.components.interactable:ForceClearAllInteractions()
end

local function SetInteractableToHeadOut(inst)
	inst.can_head_out = true
	inst.components.interactable:ForceClearAllInteractions()
end

function dungeonstarter.ConfigureDungeonStarter(inst, opts)
	inst:AddComponent("interactable")

	if TheWorld:HasTag("town") then
		inst:AddComponent("startrunportal")
		-- Everyone must stand within this radius
		inst.components.startrunportal.radius = 5.5
		inst:SetStateGraph("sg_flying_machine")

		inst:ListenForEvent("run_requested", function() SetInteractableToCancel(inst) end)
		inst:ListenForEvent("run_cancelled", function() SetInteractableToHeadOut(inst) end)
	end

	inst:AddTag("flitt_chopper")

	inst.can_head_out = true
	inst.components.interactable:SetRadius(3.5)
		:SetInteractStateName("powerup_interact")
		:SetInteractConditionFn(function(_, player, is_focused)
			if inst.can_head_out then
				return CanInteractDefault(inst, player, is_focused)
			else
				return CanInteractWaiting(inst, player, is_focused)
			end
		end)
		:SetOnInteractFn(function(_, player)
			if inst.can_head_out then
				OnRequestRun(inst, player)
			else
				OnCancelRun(inst, player)
			end
		end)
		:SetupForButtonPrompt(BuildInteractLabel)
end

return dungeonstarter
