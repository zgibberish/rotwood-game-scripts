---------------------------------------------------------------------------------------
--Custom script for auto-generated prop prefabs
---------------------------------------------------------------------------------------
local SpecialEventRoom = require("defs.specialeventrooms")

local specialeventroom = {
	default = {}
}

function specialeventroom.default.CollectPrefabs(prefabs, args)
	SpecialEventRoom.CollectPrefabs(prefabs)
end

function specialeventroom.default.CustomInit(inst, opts)
	if TheDungeon:GetDungeonMap():IsDebugMap() then
		return
	end

	inst:AddComponent("specialeventroommanager")

	inst:DoTaskInTicks(5, function()
		inst.components.specialeventroommanager:OnSpawn()
		for _k,v in pairs(Ents) do
			if v ~= inst and v.prefab == "npc_specialeventhost" then
				v.specialeventroommanager = inst
				inst.eventhost = v
				break
			end
		end
		dbassert(inst.eventhost, "[specialeventroom_prefab] No eventhost found.")
	end)
end

return specialeventroom
