local TRAP_WARNING_FRAMES = 15
local TRAP_TRIGGER_RADIUS = 0.25
local KNOCKBACK_DISTANCE = 1.2
local HITSTUN = 10 -- anim frames

local SGCommon = require "stategraphs.sg_common"

local function OnProximityHitBoxTriggered(inst, data)
	--JAMBELL TODO: use the common hitbox function instead
	local triggered = false
	for i = 1, #data.targets do
		local v = data.targets[i]
		if v.sg then
			v.sg:RemoveStateTag("nointerrupt")
		end

		local attack = Attack(inst, v)
		attack:SetDamage(0)
		attack:DisableDamageNumber()
		attack:SetDir(v.Transform:GetRotation())
		attack:SetHitstunAnimFrames(0)
		attack:SetID("bananapeel")
		attack:SetHitFlags(Attack.HitFlags.GROUND)

		-- Only allow going to the "slip" state if this attack can actually hit the target -- ie, are they flying etc
		if attack:CanHit(v) then
			triggered = true
		end

		attack:SetForceKnockdown(true)
		local old_knockdown_distance = v.knockdown_distance
		if v.components.combat.frontknockbackonly then
			v.knockdown_distance = old_knockdown_distance * -1
			local dir
			if v.Transform:GetFacingRotation() == 0 then
				dir = 180
			else
				dir = 0
			end
			attack:SetDir(dir)
		end

		if data.hitbox then
			attack:SetHitBoxData(data.hitbox)
		end

		inst.components.combat:DoKnockdownAttack(attack)
		v:DoTaskInAnimFrames(15, function()
			if v ~= nil and v:IsValid() then
				v.knockdown_distance = old_knockdown_distance
			end
		end)
	end

	if triggered then
		inst.sg:GoToState("slip")
	end
end

local events =
{
	EventHandler("spawn", function(inst)
		if not inst.sg:HasStateTag("busy") then
			inst.sg:GoToState("spawn")
		end
	end),
}

local states =
{
	State({
		name = "spawn",
		tags = { "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "land")
		end,

		events =
		{
			EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
		}
	}),

	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "idle", true)
		end,

		onupdate = function(inst)
			inst.components.hitbox:PushCircle(0, 0, TRAP_TRIGGER_RADIUS, HitPriority.MOB_DEFAULT)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnProximityHitBoxTriggered),
		},
	}),

	State({
		name = "slip",
		tags = { "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "slip_left")
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst) inst:Remove() end),
		}
	}),

	State({
		name = "init",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.hitbox:SetHitGroup(HitGroup.NONE)
			inst.components.hitbox:SetHitFlags(HitGroup.ALL)
			inst.sg:GoToState("spawn")
		end,

		timeline =
		{
		},

		events =
		{
		}
	}),
}

return StateGraph("sg_trap_bananapeel", states, events, "init")