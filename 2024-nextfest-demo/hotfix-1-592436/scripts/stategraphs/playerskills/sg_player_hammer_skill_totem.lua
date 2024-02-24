local SGCommon = require "stategraphs.sg_common"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local PlayerSkillState = require "playerskillstate"
local Power = require("defs.powers.power")

local events = {}

local function SpendHealth(inst)
	local totem_skill_def = Power.FindPowerByName("hammer_totem")
	local healthtocreate = totem_skill_def.tuning.COMMON.healthtocreate

	local power_attack = Attack(inst, inst)
	power_attack:SetDamage(healthtocreate)
	power_attack:SetIgnoresArmour(true)
	power_attack:SetSkipPowerDamageModifiers(true)
	power_attack:SetSource(totem_skill_def.name)
	power_attack:SetCannotKill(true)
	inst.components.combat:DoPowerAttack(power_attack)
end

local function CreateTotem(inst)
	local x_offset = 3 -- put totem in front of player; facing accounted for in SpawnAtDist
	local totem = SGCommon.Fns.SpawnAtDist(inst, "totem_prototype", x_offset)
	if totem then
		totem:Setup(inst)
		inst.sg.mem.hammerskilltotem = totem
	end
end

local states =
{
	PlayerSkillState({
		name = "skill_hammer_totem",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("skill_self_dmg")
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				if inst.sg.mem.hammerskilltotem ~= nil then
					inst.sg.mem.hammerskilltotem:Teardown()
				end
			end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(-5) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(13, function(inst) inst.Physics:Stop() end),
			FrameEvent(17, SGPlayerCommon.Fns.RemoveBusyState),
			FrameEvent(17, SpendHealth),
			FrameEvent(17, CreateTotem),
		},

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("skill_pst")
			end),
		},

		onexit = function(inst)
		end,
	}),
}

return StateGraph("sg_player_hammer_skill_totem", states, events, "skill_hammer_totem")
