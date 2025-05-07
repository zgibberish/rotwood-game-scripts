local SGPlayerCommon = require "stategraphs.sg_player_common"
local SGCommon = require "stategraphs.sg_common"
local fmodtable = require "defs.sound.fmodtable"
local PlayerSkillState = require "playerskillstate"
local spawnutil = require "util.spawnutil"
local monsterutil = require "util.monsterutil"
local soundutil = require "util.soundutil"

local events = {}

local function CreateStone(inst)
	--Spawn Projectile
	local bullet = SGCommon.Fns.SpawnAtDist(inst, "player_throwstone_projectile", 3)
	bullet:Setup(inst)
	inst:PushEvent("projectile_launched", {bullet})
end

local function ThrowSound(inst)
	local params = {}
	params.fmodevent = fmodtable.Event.Skill_ThrowStone_Toss
	params.sound_max_count = 1
	inst.sg.statemem.throw_sound_handle = soundutil.PlaySoundData(inst, params)
end

local function FoleySounds(inst)
	local foleysounder = inst.components.foleysounder
	local tile_param_index = foleysounder:GetSurfaceAsParameter()

	local params = {}
	params.fmodevent = fmodtable.Event.Skill_ThrowStone_Grab
	params.sound_max_count = 1
	local handle = soundutil.PlaySoundData(inst, params)
	inst.SoundEmitter:SetParameter(handle, "tile_surface", tile_param_index)
end

local states =
{
	PlayerSkillState({
		name = "skill_throwstone",
		tags = { "busy" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation("skill_throw_stone_pre") -- 9 frames
			inst.AnimState:PushAnimation("skill_throw_stone_hold") -- 13 frames
		end,
		timeline =
		{
			FrameEvent(1, FoleySounds),
			FrameEvent(12, function(inst)
				inst.sg:GoToState("skill_throwstone_pst") -- We're not wanting to charge this at the moment, just want to exit from the current hold animation early
			end),
			-- FrameEvent(3, SGPlayerCommon.Fns.SetCanDodge),
		},
		onexit = function(inst) end,
		events =
		{
		},
	}),
	PlayerSkillState({
		name = "skill_throwstone_pst",
		tags = { "busy" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation("skill_throw_stone_pst") -- 15 frames
		end,
		timeline =
		{
			FrameEvent(3, ThrowSound),
			FrameEvent(3, CreateStone),
			FrameEvent(4, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(7, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(8, SGPlayerCommon.Fns.RemoveBusyState),
		},
		onexit = function(inst) end,
		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("skill_pst")
			end),
		},
	}),
}

return StateGraph("sg_player_skill_throwstone", states, events, "skill_throwstone")