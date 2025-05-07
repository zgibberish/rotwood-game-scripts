---------------------------------------------------------------------------------------
--Custom script for auto-generated prop prefabs
---------------------------------------------------------------------------------------

local lume = require "util.lume"
local spawnutil = require "util.spawnutil"
local monsterutil = require "util.monsterutil"
local Enum = require "util.enum"

-- Spawners are just props. They call into here to add trap behaviour to their
-- existing setup. Currently, we want them to have mostly the same setup.
local PlayerSpawner = {
	default = {},
}

local function OnEditorSpawn(inst, editor)

end

local function OnRemoveEntity(inst)
	TheWorld:PushEvent("unregister_playerspawner", inst)
end

function PlayerSpawner.default.CustomInit(inst, opts)
	if not opts then
		return
	end

	inst:AddComponent("snaptogrid")
	inst.components.snaptogrid:SetDimensions(2, 2, -2)

	inst.OnEditorSpawn = OnEditorSpawn

	if opts.is_invisible then
		local shape = "square"
		if TheDungeon:GetDungeonMap():IsDebugMap() then
			spawnutil.MakeEditable(inst, shape)
		else
			inst:Hide()
		end
		inst.baseanim = shape
	end

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		inst.AnimState:SetMultColor(66/255, 245/255, 230/255, 1)
	end

	TheWorld:PushEvent("register_playerspawner", inst)
	inst.OnRemoveEntity = OnRemoveEntity
end

function PlayerSpawner.PropEdit(editor, ui, params)
	local opts = params.script_args
	params.script_args = opts
end

return PlayerSpawner
