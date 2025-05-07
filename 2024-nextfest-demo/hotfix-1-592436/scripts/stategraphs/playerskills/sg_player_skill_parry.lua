local SGPlayerCommon = require "stategraphs.sg_player_common"
local SGCommon = require "stategraphs.sg_common"
local fmodtable = require "defs.sound.fmodtable"
local PlayerSkillState = require "playerskillstate"

local PARRY_SUCCESS_LENGTH_FRAMES = 45
local FX_LENGTH_FRAMES = 4
local PARRY_WINDOW_FRAMES = 7

-- TODO:
-- make getting hit not reset your hitstreak

local function DoParry(inst, data)
	if inst.sg.statemem.parrying then
		if inst.sg:GetAnimFramesInState() < 2 then
			inst.AnimState:SetFrame(2)
		end

		-- Hitstop
		local hitstopframes = HitStopLevel.BOSSKILL
		local playerhitstopframes = math.floor(hitstopframes/2)
		local attacker = data.attack:GetAttacker()
		if attacker.components.hitstopper ~= nil then
			attacker.components.hitstopper:PushHitStop(hitstopframes)
		end
		inst.components.hitstopper:PushHitStop(hitstopframes / 2)

		-- Hitshudder
		if attacker.components.hitshudder ~= nil then
			attacker.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_MEDIUM, FX_LENGTH_FRAMES)
		end
		inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_MEDIUM, playerhitstopframes)

		-- Sound
		inst.SoundEmitter:PlaySound(fmodtable.Event.Skill_Parry)

		-- FX
		SGCommon.Fns.BlinkAndFadeColor(inst, { 0, 0.5, 1 }, (FX_LENGTH_FRAMES))
		if attacker.components.coloradder ~= nil then
			-- Some things, like an acid pool's 'jointaoeparent' doesn't have a coloradder. It should flash, but fixing crash for now.
			SGCommon.Fns.BlinkAndFadeColor(attacker, { 0, 0.5, 1 }, (FX_LENGTH_FRAMES))
		end

		-- After we've done hitstopping, on a successful parry hop to the end of the anim to make recovery quicker
		inst:DoTaskInAnimFrames(playerhitstopframes, function(inst)
			if inst ~= nil and inst:IsValid() then
				if inst.AnimState:GetCurrentAnimationFrame() < 10 and inst.sg:HasStateTag("parrying") then -- Don't adjust recovery if we've canceled out of this parry state
					inst.AnimState:SetFrame(10)
				end
			end
		end)

		-- Gameplay / Damage mods, and undoing it
		inst.components.combat:SetCritChanceModifier("skill_parry_success", 1)
		inst:DoTaskInAnimFrames(PARRY_SUCCESS_LENGTH_FRAMES, function(inst)
			if inst ~= nil and inst:IsValid() then
				-- SGCommon.Fns.BlinkAndFadeColor(inst, { .5, .5, .5 }, 4)
				inst.components.combat:RemoveCritChanceModifier("skill_parry_success")
			end
		end)

		inst:PushEvent("parry")

		SGPlayerCommon.Fns.SetCanDodge(inst)
		SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
	else
		if data.attack:IsKnockdown() then
			inst.sg:GoToState("knockdown", data)
		else
			inst.sg:GoToState("knockback", data)
		end
	end
end

local events = {}

local states =
{
	PlayerSkillState({
		name = "skill_parry",
		tags = { "busy", "nointerrupt", "parrying" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation("skill_parry")

			-- inst.HitBox:SetInvincible(true)
			inst.sg.statemem.hitboxsize = inst.HitBox:GetSize()
			inst.sg:SetTimeoutAnimFrames(PARRY_WINDOW_FRAMES)
			inst.sg.statemem.parrying = true

			inst.components.combat:SetDamageReceivedMult("skill_parry", 0)
		end,

		timeline =
		{
			FrameEvent(10, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(14, SGPlayerCommon.Fns.SetCanAttackOrAbility),
		},

		ontimeout = function(inst)
			inst.sg.statemem.parrying = false
			inst.HitBox:SetNonPhysicsRect(inst.sg.statemem.hitboxsize * 2)
			inst.components.combat:RemoveDamageReceivedMult("skill_parry")
			inst.sg:RemoveStateTag("nointerrupt")
		end,

		onexit = function(inst)
			inst.HitBox:SetNonPhysicsRect(inst.sg.statemem.hitboxsize)
			inst.components.combat:RemoveDamageReceivedMult("skill_parry")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("skill_pst")
			end),

			EventHandler("attacked", DoParry),
			EventHandler("knockback", DoParry),
			EventHandler("knockdown", DoParry),
		},
	}),
}

return StateGraph("sg_player_skill_parry", states, events, "skill_parry")
