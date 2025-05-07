require "util.tableutil"
local biomes = require "defs.biomes"
local lume = require"util/lume"

-- Enables players to teleport to a specific encounter in order to practice it.

local encounterpractice = {
	default = {},
}

local function OnEditorSpawn(inst, editor)
end

function encounterpractice.default.CustomInit(inst, opts)
	assert(opts)
	inst.OnEditorSpawn = OnEditorSpawn
	encounterpractice.ConfigureEncounterPracticeStation(inst, opts)
end

local function _TryStartSpecificRoom(player, roomtype, location_id)
    local biome_location = biomes.locations[location_id]
    local world = biome_location:Debug_GetRandomRoomWorld(roomtype)

    TheAudio:StopAllSounds() -- Not normal flow, so clean up sounds.

	-- TheNet:RequestRun(playerID, regionID, locationID, seed, altMapGenID, ascension)
		-- Can this support roomtype?
    
	-- TheDungeon.progression.components.runmanager:SetIsPracticeRun(true) -- BAD! This is just here for testing of functionality.

    -- TODO: Is there a non-debug way to do this?
    TheDungeon.components.worldmap:Debug_StartArena(world,
        {
            roomtype = roomtype,
            location = biome_location.id,
            is_terminal = false, -- terminal suppresses resource rooms
        })
end

local function OnRequestRun(inst, player)
	inst:RequestRunFunction(player)
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
		return "<p bind='Controls.Digital.ACTION' color=0> " .. STRINGS.UI.ACTIONS.PRACTICE_FIGHT
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

function encounterpractice.default.GetLocationIDs()
	return lume.sort(lume.keys(biomes.locations))
end

function encounterpractice.ConfigureEncounterPracticeStation(inst, opts)
	inst:AddComponent("interactable")

	if TheWorld:HasTag("town") then
		inst:AddComponent("startrunportal")
		-- Everyone must stand within this radius
		inst.components.startrunportal.radius = 5.5

		inst:ListenForEvent("run_requested", function() SetInteractableToCancel(inst) end)
		inst:ListenForEvent("run_cancelled", function() SetInteractableToHeadOut(inst) end)

		if opts.location_id then
			inst.RequestRunFunction = function(inst, player) _TryStartSpecificRoom(player, "boss", opts.location_id) end
		end
	end

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

function encounterpractice.PropEdit(editor, ui, params)
	local args = params.script_args
	local no_selection = 1
	-- local all_roomtypes = encounterpractice.default.GetRoomTypes()
	-- table.insert(all_roomtypes, no_selection, "")
	-- we can do this later if we want to support more than just hype rooms

	local all_locationids = encounterpractice.default.GetLocationIDs()
	table.insert(all_locationids, no_selection, "")

	local changed, location_id = ui:ComboAsString("Location ID", args.location_id, all_locationids, true) 
	if location_id ~= args.location_id then
		args.location_id = location_id
	end
end

return encounterpractice
