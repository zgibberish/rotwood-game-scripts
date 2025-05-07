local SGPlayerCommon = require "stategraphs.sg_player_common"
local SGCommon = require "stategraphs.sg_common"
local fmodtable = require "defs.sound.fmodtable"
local PlayerSkillState = require "playerskillstate"
local spawnutil = require "util.spawnutil"
local monsterutil = require "util.monsterutil"

local events = {}

local function CreateBananaPeel(inst)
	local pos = inst:GetPosition()
	local peel = SpawnPrefab("banana_peel")

	local x_offset = inst.Transform:GetFacing() == FACING_LEFT and -2 or 2
	local random_x = math.random(-1, 1) * 0.1
	local random_z = math.random(-1, 1) * 0.25
	peel.Transform:SetPosition(pos.x + x_offset + random_x, pos.y, pos.z + random_z)
	-- added sound events to via embelisher (dany)
	--inst.SoundEmitter:PlaySound(fmodtable.Event.Skill_BananaPeel_Land)
end

local states =
{
	PlayerSkillState({
		name = "skill_bananapeel",
		tags = { "busy" },

		onenter = function(inst)
			local bananapower = inst.components.powermanager:GetPowerByName("bananapeel")
			if bananapower.persistdata.bananas_left > 0 then
				inst.sg:GoToState("skill_bananapeel_eat")
			else
				inst.sg:GoToState("skill_bananapeel_no_eat")
			end
		end,
	}),

	PlayerSkillState({
		name = "skill_bananapeel_eat",
		tags ={ "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("skill_banana_pre")
			inst.AnimState:PushAnimation("skill_banana_front_pst")
		end,

		timeline =
		{
			-- Allow dodge canceling out of the startup, but once the banana has been eaten, don't allow dodging until the peel is down.
			FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(9, SGPlayerCommon.Fns.SetCannotDodge),
			-- added sound events to via embelisher (dany)

			FrameEvent(18, function(inst)
				inst:PushEvent("bananaeat")
				-- added sound events to via embelisher (dany)
			end),

			FrameEvent(30, CreateBananaPeel),
			FrameEvent(31, SGPlayerCommon.Fns.RemoveBusyState)
		},

		onexit = function(inst)

		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("skill_pst")
			end),
		},
	}),

	PlayerSkillState({
		name = "skill_bananapeel_no_eat",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("skill_banana_empty")
		end,

		timeline =
		{
			FrameEvent(10, SGPlayerCommon.Fns.RemoveBusyState)
		},

		onexit = function(inst)

		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("skill_pst")
			end),
		},
	}),
}

return StateGraph("sg_player_skill_bananapeel", states, events, "skill_bananapeel")