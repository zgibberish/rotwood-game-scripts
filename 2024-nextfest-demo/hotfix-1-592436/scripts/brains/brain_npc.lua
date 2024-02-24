local FaceEntity = require "behaviors.faceentity"
local StandStill = require "behaviors.standstill"
local WanderNpc = require "behaviors.wander_npc"

local function GetPlayer(inst)
	local player = inst.components.conversation:GetTarget()
	if player ~= nil then
		return player
	end

	player = inst:GetClosestPlayerInRange(6)
	if player then
		-- Check if player is busy talking to another Npc
		local prompttarget = TheDungeon.HUD:GetPromptTarget()
		local is_available = prompttarget == nil or prompttarget == inst
		if is_available then
			return player
		end
	end
end

local function GetHome(inst)
	local home = inst.components.npc:GetHome()
	if home ~= nil and home.components.npchome ~= nil then
		return home.components.npchome:GetSpawnXZ()
	end
	return home
end

local BrainNpc = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		FaceEntity(inst, GetPlayer),
		WanderNpc(inst, GetHome, inst.tuning.wander_dist),
	}, .5))
end)

return BrainNpc
