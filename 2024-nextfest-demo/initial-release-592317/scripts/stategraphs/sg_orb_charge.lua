local SGCommon = require "stategraphs.sg_common"
local Power = require("defs.powers.power")
local EffectEvents = require "effectevents"

local PULSE_TICKS = 30 * ANIM_FRAMES
local PULSE_COUNT_DEFAULT = 2 -- DEFAULT VALUE, can be set elsewhere on inst.chargepulses
local CHARGE_STACKS_DEFAULT = 2 -- DEFAULT VALUE, can be set elsewhere on inst.chargestacks

local function OnHitBoxTriggered(inst, data)
	for i = 1, #data.targets do
		local v = data.targets[i]
		if inst.components.combat:CanTargetEntity(v) then
			local powermanager = v.components.powermanager
			if powermanager then
				powermanager:AddPower(powermanager:CreatePower(Power.Items.ELECTRIC.charged), inst.chargestacks or CHARGE_STACKS_DEFAULT)
				inst.spawn_charge_applied_fx(v)

				local dir = inst:GetAngleTo(v)
				local attack = Attack(inst, v)
				attack:SetDamage(0)
				attack:SetDir(dir)
				attack:SetHitstunAnimFrames(10)
				attack:DisableDamageNumber()
				inst.components.combat:DoBasicAttack(attack)
			end
		end
	end
end

local events =
{
}

local states =
{
	State({
		name = "electric_orb_pre",
		tags = { },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("electric_orb_pre")
			--JAMBELL TODO: reduce startup time with sloth
			--inst.AnimState:SetFrame(8)
			--print(inst.AnimState:GetCurrentAnimationNumFrames())
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("electric_orb_idle")
			end),
		},
	}),

	State({
		name = "electric_orb_idle",
		tags = { },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("electric_orb_idle", true)
			inst.sg.mem.pulsesleft = inst.chargepulses or PULSE_COUNT_DEFAULT
			inst.sg:SetTimeoutTicks(PULSE_TICKS * inst.sg.mem.pulsesleft)
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(3)
		end,

		timeline =
		{
		},

		onupdate = function(inst)
			if inst.sg:GetTicksInState() % PULSE_TICKS == 0 then
				inst.sg.mem.pulsefx = EffectEvents.MakeEventSpawnEffect(inst, {fxname = "electric_charged_orb_area" })
				inst.sg.mem.pulsefx.AnimState:SetScale(1.75, 1.75)
				inst.components.hitbox:PushCircle(0, 0, 3.5, HitPriority.MOB_DEFAULT)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("electric_orb_pst")
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
		},
	}),

	State({
		name = "electric_orb_pst",
		tags = { },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("electric_orb_pst")
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst:IsValid() then
					inst:Remove()
				end
			end),
		},
	}),
}

return StateGraph("sg_dodge_orb", states, events, "electric_orb_pre")
