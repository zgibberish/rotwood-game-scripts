local SGCommon = require "stategraphs.sg_common"
local lume = require "util.lume"
local ease = require "util.ease"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local KNOCKBACK_DISTANCE = 1.2
local HITSTUN = 10 -- anim frames

local function OnActiveTrapHitBoxTriggered(inst, data)
	-- Mobs are immune to running into thorns and taking damage. Only damage if knocked down.
	local hit_targets = {}
	for _, target in ipairs(data.targets) do
		if not target:HasTag("mob") or (target.sg and (target.sg:HasStateTag("knockback") or target.sg:HasStateTag("knockdown"))) then
			table.insert(hit_targets, target)
		end
	end

	data.targets = hit_targets

	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = HitStopLevel.MEDIUM,
		set_dir_angle_to_target = true,
		player_damage_mod = 2,
		pushback = KNOCKBACK_DISTANCE,
		force_hit_reaction = true,
		hitflags = Attack.HitFlags.GROUND,
		hitstun_anim_frames = HITSTUN,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 0.5,
	})

	-- Manually pushback boss characters if hit by this
	for _, target in ipairs(hit_targets) do
		if target:HasTag("boss") then
			target.components.pushbacker:DoPushBack(inst, KNOCKBACK_DISTANCE, HitStopLevel.MEDIUM)
		end
	end

	if #hit_targets > 0 then
		inst.sg:GoToState("hit")
	end
end


local DORMANT_TIME = 3
local HITBOX_SIZE <const> = 1.4

local events =
{
}

local states =
{
	State({
		name = "idle",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "idle", true)
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		events =
		{
			EventHandler("attacked", function(inst) inst.sg:GoToState("hit") end),
			EventHandler("hitboxcollided_invincible_target", function(inst, target)
				-- Only hit & retract if hit if the target is invincible (e.g. perfect dodging)
				inst.sg:GoToState("hit")
			end),
			EventHandler("hitboxtriggered", OnActiveTrapHitBoxTriggered),
		},

		onupdate = function(inst)
			inst.components.hitbox:PushBeam(-HITBOX_SIZE, HITBOX_SIZE, HITBOX_SIZE, HitPriority.MOB_DEFAULT)
		end,

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "hit",
		tags = { "hit", "busy" },

		onenter = function(inst, target)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "hit")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("retract")
			end),
		},
	}),

	State({
		name = "retract",
		tags = { "hit", "busy" },

		onenter = function(inst, target)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "retract")
			inst.Physics:SetEnabled(false)
			inst.HitBox:SetHitGroup(HitGroup.NONE)

			--[[if inst.highlightchildren ~= nil then
				for i = 1, #inst.highlightchildren do
					local child = inst.highlightchildren[i]
					child.AnimState:HideLayer("leaves")
					child.AnimState:HideLayer("spikes")
					child.AnimState:HideLayer("spikes_above")
					child.AnimState:HideLayer("spikes_below")
					child.AnimState:HideLayer("vine")
					child.AnimState:HideSymbol("thorns_bloomme")
					child.AnimState:HideSymbol("thorn_vines")
				end
			end]]
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("dormant")
			end),
		},
	}),

	State({
		name = "dormant",
		tags = { "busy" },

		onenter = function(inst, target)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "dormant", true)
			inst.sg:SetTimeout(DORMANT_TIME)
		end,

		ontimeout = function(inst)
			if not inst.sg.mem.is_room_clear then

				-- If something is standing on it, don't extend thorns.
				local pos = inst:GetPosition()
				local target_tags = lume.concat(TargetTagGroups.Players, TargetTagGroups.Enemies)
				local ents = TheSim:FindEntitiesXZ(pos.x, pos.z, HITBOX_SIZE * 2 + 0.2, nil, nil, target_tags)
				local stay_dormant = false
				for _, ent in ipairs(ents) do
					if ent and ent:IsValid() and ent ~= inst then
						stay_dormant = true
					end
				end

				if stay_dormant then
					inst.sg:GoToState("dormant")
				else
					inst.sg:GoToState("return")
				end
			end
		end,
	}),

	State({
		name = "return",
		tags = { "busy" },

		onenter = function(inst, target)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "return")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:SetEnabled(true)
			inst.HitBox:SetHitGroup(HitGroup.NEUTRAL)
			--[[if inst.highlightchildren ~= nil then
				for i = 1, #inst.highlightchildren do
					local child = inst.highlightchildren[i]
					child.AnimState:ShowLayer("leaves")
					child.AnimState:ShowLayer("spikes")
					child.AnimState:ShowLayer("spikes_above")
					child.AnimState:ShowLayer("spikes_below")
					child.AnimState:ShowLayer("vine")
					child.AnimState:ShowSymbol("thorns_bloomme")
					child.AnimState:ShowSymbol("thorn_vines")
				end
			end]]
		end,
	}),
}

return StateGraph("sg_trap_thorns", states, events, "idle")
