local SGCommon = require "stategraphs.sg_common"
local lume = require "util.lume"

local SGBossCommon =
{
	States = {},
	Events = {},
	Fns = {},
}

function SGBossCommon.Fns.OnBossDying(inst, data)
	SGCommon.Fns.OnMonsterDying(inst, data)

	-- Some stategraph event handlers are shared between bosses and non-bosses (e.g. bandicoot & clones).
	-- Check for the boss tag before proceeding with the below boss-specific code.
	if not inst:HasTag("boss") then
		inst.sg:ForceGoToState("death")
		return
	end

	-- Kill all mobs that are alive, clear the encounter
	TheWorld.components.spawncoordinator:SetEncounterCleared()

	-- (TODO: make this not be two separate cinematics?) Cinematic death flow: boss_death_hit_hold -> boss death cinematic.
	if not (inst.components.cineactor and inst.components.cineactor.onevent["dying"]) then
		-- No cinematic or debug spawned; directly go to the death hit state.
		inst.sg:ForceGoToState("death_hit_hold")
	end
end

--------------------------------------------------------------------------
-- AddBossStates
--------------------
-- Possible parameters for 'data':
-- cine_timeline: timeline data to be run during the death_cinematic state.
function SGBossCommon.States.AddBossStates(states, data)

	states[#states + 1] = State({
		name = "dormant_idle",
		tags = { "idle" --[[, dormant]] },

		onenter = function(inst)
			if inst.AnimState:HasAnimation() then
				inst.AnimState:PlayAnimation("dormant_idle", true)
			end
		end,
	})

	-- This state only gets entered via bosses without death cinematics, or debug spawned.
	states[#states + 1] = State({
		name = "death_hit_hold",
		tags = {"death", "busy", "nointerrupt"},
		onenter = function(inst)
			inst.AnimState:PlayAnimation("death_hit_hold")
			inst.sg:SetTimeout(0.5)
		end,
		ontimeout = function(inst)
			inst.sg:GoToState("death_cinematic")
		end,
	})

	states[#states + 1] = State({
		name = "death_cinematic",
		tags = {"death", "busy", "nointerrupt"},
		onenter = function(inst)
			inst.AnimState:PlayAnimation("death")
			-- prevent soft-lock if no state transition and animover event is not triggered
			-- longest death cine is currently ~180 frames
			inst.sg:SetTimeoutAnimFrames(300)
		end,
		timeline = lume.concat(data and data.cine_timeline or {},
		{
		}),
		onupdate = function(inst)
			-- Make sure the boss doesn't move out of bounds.
			local pos = inst:GetPosition()
			local rot = inst.Transform:GetFacingRotation()
			local movedir = Vector3(math.cos(math.rad(rot)), 0, math.sin(math.rad(rot)))
			local PADDING_FROM_EDGE = 4
			local padding = movedir * PADDING_FROM_EDGE
			local testpos = pos + padding
			local isPointOnGround = TheWorld.Map:IsGroundAtPoint(testpos)
			if not isPointOnGround then
				local newPos = TheWorld.Map:FindClosestWalkablePoint(testpos) - padding
				inst.Transform:SetPosition(newPos:Get())
			end
		end,

		ontimeout = function(inst)
			TheLog.ch.StateGraph:printf("Warning: %s Timed out in death_cinematic.  Going to death_idle.", inst)
			inst.sg:GoToState("death_idle")
		end,

		onexit = function(inst)
			-- prevent soft-lock if the animover event isn't received before exiting this state
			if inst.components.health:IsDying() then
				TheLog.ch.StateGraph:printf("Warning: %s Exiting death_cinematic while dying.  Pushing done_dying event now.", inst)
				inst:PushEvent("done_dying")
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				-- Bosses stay on screen after they die, so don't push the "done_dying" event - it will remove them!
				inst:PushEvent("done_dying")

				-- Disable eye bloom
				inst.AnimState:SetSymbolBloom("eye_untex", 0, 0, 0, 0)
			end)
		},
	})

	states[#states + 1] = State({
		name = "death_idle",
		tags = {"death", "busy", "nointerrupt"},
		onenter = function(inst)
			-- prevent soft-lock if the animover event isn't received before entering this state
			if inst.components.health:IsDying() then
				TheLog.ch.StateGraph:printf("Warning: %s Entering death_idle while dying.  Pushing done_dying event now.", inst)
				inst:PushEvent("done_dying")
			end

			inst.HitBox:SetEnabled(false)
			inst.Physics:SetEnabled(false)
			inst.components.lootdropper:DropLoot()
		end,
	})
end

--------------------------------------------------------------------------
local function OnBossDeath(inst)
	if not inst:HasTag("boss") then
		return
	end

	-- Cine will handle death anim and presentation.
	-- Make all players immune to damage - will need to revisit this when we have multiple bosses to fight at the same time.
	for _, player in ipairs(AllPlayers) do
		if player.components.combat then
			player.components.combat:SetDamageReceivedMult("boss_dead", 0)
		end
	end
end

function SGBossCommon.Events.OnBossDeath()
	return EventHandler("death", OnBossDeath)
end

return SGBossCommon
