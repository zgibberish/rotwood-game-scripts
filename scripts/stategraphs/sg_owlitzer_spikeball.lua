local easing = require("util/easing")
local SGCommon = require("stategraphs/sg_common")
local monsterutil = require "util.monsterutil"

local events =
{
	EventHandler("thrown", function(inst, targetpos) inst.sg:GoToState("thrown", targetpos) end),
	EventHandler("attacked", function(inst, data)
		SGCommon.Fns.OnAttacked(inst, data)

		if not inst:IsValid() or not inst:IsAlive() then
			inst.sg:GoToState("death", data)
		elseif not inst.sg:HasStateTag("nointerrupt") then
			inst.sg:GoToState("hit", data)
		end
	end),
	EventHandler("dying", function(inst, data)
		inst.sg:GoToState("death")
	end),
	EventHandler("death", function(inst, data)
		inst:DelayedRemove()
	end),
}

local function OnRoomComplete(inst)
	inst.components.health:SetCurrent(0)
end

local states =
{
	State({
		name = "init",
		onenter = function(inst)
			inst.HitBox:SetInvincible(true)
			inst.sg:GoToState("idle")

			inst:ListenForEvent("room_complete", function() OnRoomComplete(inst) end, TheWorld)
		end,
	}),

	State({
		name = "idle",
		onenter = function(inst)
			inst.AnimState:PlayAnimation("idle")

			-- Delay this until the next tick, to handle being thrown & due to how the init state works so that they don't hit on the first frame.
			inst.sg.mem.idle_init = inst:DoTaskInTime(0, function()
				inst.HitBox:SetInvincible(false)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.projectilehitbox:SetEnabled(true)
			end)
		end,

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "thrown",
		tags = { "flying", "nointerrupt", "attack" },

		onenter = function(inst, targetpos)
			if inst.sg.mem.idle_init then
				inst.sg.mem.idle_init:Cancel()
				inst.sg.mem.idle_init = nil
			end

			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
			inst.Physics:SetSnapToGround(false)
			inst.Physics:SetEnabled(false)

			targetpos = targetpos or Vector3.zero
			inst.AnimState:PlayAnimation("spin", true)
			inst.AnimState:SetShadowEnabled(false)

			local x, y, z = inst.Transform:GetWorldPosition()
		    local dx = targetpos.x - x
		    local dz = targetpos.z - z
		    local rangesq = dx * dx + dz * dz
		    local maxrange = 20
		    local speed = easing.linear(rangesq, 20, 10, maxrange * maxrange)
		    inst.components.complexprojectile:SetHorizontalSpeed(speed)
		    inst.components.complexprojectile:SetGravity(-40 + math.random() * 2 - 1)
		    inst.components.complexprojectile:Launch(targetpos)
		    inst.components.complexprojectile.onhitfn = function()
				if inst:IsAlive() then
					inst.sg:GoToState("land", targetpos)
				end
			end

			local circle = SpawnPrefab("fx_ground_target_red", inst)
			circle.Transform:SetPosition( targetpos.x, 0, targetpos.z )

			inst.sg.statemem.landing_pos = circle
		end,

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
			if inst.sg.statemem.landing_pos then
				inst.sg.statemem.landing_pos:Remove()
			end
		end,
	}),

	State({
		name = "land",

		onenter = function(inst)
			inst.AnimState:PlayAnimation("land")
			inst.Physics:SetSnapToGround(true)
			inst.Physics:SetEnabled(true)
			inst.AnimState:SetShadowEnabled(true)

			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.projectilehitbox:SetEnabled(true)
			--inst.components.projectilehitbox:SetRepeatTargetDelayTicks(6 * ANIM_FRAMES)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
        name = "hit",
        tags = { "hit", "busy" },

        onenter = function(inst)
            SGCommon.Fns.PlayAnimOnAllLayers(inst, "hit", true)
        end,

        events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
    }),

	State({
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "break", false)
            inst:DoTaskInTime(0, function(xinst)
				-- Need to delay this a frame otherwise it will cause a hard crash when colliding with physics.
				xinst.Physics:SetEnabled(false)
			end)
			inst.HitBox:SetEnabled(false)
			inst.components.projectilehitbox:SetEnabled(false)
			inst.sg:SetTimeoutAnimFrames(60) -- break anim is 20 frames
        end,

		ontimeout = function(inst)
			TheLog.ch.StateGraph:printf("Warning: %s EntityID %d death didn't cleanup -- forcing removal",
				inst, inst:IsNetworked() and inst.Network:GetEntityID() or -1)
			inst:Remove()
		end,

        events =
		{
			EventHandler("animover", function(inst)
				inst:PushEvent("done_dying")
			end),
		},
    }),
}

return StateGraph("sg_owlitzer_spikeball", states, events, "init")