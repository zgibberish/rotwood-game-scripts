local Power = require("defs.powers.power")
local lume = require "util.lume"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"
local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"
local powerutil = require "util.powerutil"

--local DebugDraw = require "util.debugdraw"

function Power.AddGroakPower(id, data)
	if not data.power_category then
		data.power_category = Power.Categories.SUSTAIN
	end

	data.power_type = Power.Types.MOVEMENT
	data.show_in_ui = false
	data.can_drop = false
	data.stackable = false
	data.selectable = false

	Power.AddPower(Power.Slots.GROAK, id, "groakpowers", data)
end

Power.AddPowerFamily("GROAK", nil, 8)

local function ChewTarget(inst, swallower)
	-- Only apply damage if chewing on an enemy
	if swallower.components.combat:CanTargetEntity(inst) then
		-- For networking have the player damage themselves when chewed.
		if not inst:IsDead() then

			local attacktracker = swallower.components.attacktracker
			local attack = Attack(swallower, inst)

			local attack_data = attacktracker:GetAttackData("swallow")
			local damage_mod = attack_data and attack_data.damage_mod or 1
			attack:SetDamageMod(damage_mod)
			attack:SetHitFxData("fx_hurt_sweat", 0, 0)
			attack:SetForceRemoteHitConfirm(true)

			swallower.components.combat:DoBasicAttack(attack)

			SGCommon.Fns.ApplyHitstop(attack, HitStopLevel.HEAVY)
		end
	end
end

local SPIT_OUT_SPAWN_DISTANCE = 2.5
local SPIT_OUT_ANGLE_RANGE = 90 -- +/-(value * 0.5) for calculations below.

local function SetSwallowExitPosition(inst, swallower, x, z, angle)
	-- Check for the spit out position to see if it's out of bounds.
	local pos = Vector3(x, 0, z)
	if not TheWorld.Map:IsWalkableAtXZ(x, z) then
		local new_pos = TheWorld.Map:FindClosestWalkablePoint(Vector3(x, 0, z))
		pos.x = new_pos.x
		pos.z = new_pos.z
	end

	inst.Transform:SetPosition(pos:unpack())

	-- Flip angle if facing right
	if angle then
		local facing = swallower.Transform:GetFacing() == FACING_LEFT and -1 or 1
		if facing > 0 then
			angle = 180 - angle
		end
		inst.Transform:SetRotation(angle)
	end
end

-- Function for positioning spit out entities & handling recursive swallowing(!)
local function OnSwallowerSpitOut(inst, swallower, data)
	-- Position the swallowed object where the swallower is with an offset, in case the swallower has moved.
	-- (If the swallower has been swallowed, the offset will be set to zero in OnSwallowed.)
	local pos = inst:GetPosition()
	local facing = swallower.Transform:GetFacing() == FACING_LEFT and -1 or 1

	-- Randomly shoot out at an angle from an offset position based on the angle.
	local angle = data and data.angle or (math.random() - 0.5) * SPIT_OUT_ANGLE_RANGE
	local offset_x = math.cos(math.rad(angle)) * SPIT_OUT_SPAWN_DISTANCE
	local offset_z = math.sin(math.rad(angle)) * SPIT_OUT_SPAWN_DISTANCE

	local final_pos_x = pos.x + offset_x * facing
	local final_pos_z = pos.z + offset_z

	SetSwallowExitPosition(inst, swallower, final_pos_x, final_pos_z, angle)

	-- If the entity was swallowing something, set the position of the swallowed entity to be the same position. Othwewise use the saved offset position.
	local swallowed_ent_cmp = inst.components.groaksync
	if swallowed_ent_cmp then
		local swallowed_ents = swallowed_ent_cmp:FindSwallowedEntities()
		local num_swallowed_ents = lume.count(swallowed_ents)
		if num_swallowed_ents > 0 then
			for _, ent in ipairs(swallowed_ents) do
				ent.Transform:SetPosition(inst:GetPosition():Get())
				OnSwallowerSpitOut(ent, inst, data)
			end
		end
	end
end

local SPIT_OUT_PUSHBACK = 2
local PRE_SWALLOWED_CANCEL_PUSHBACK = 0.5

local function SpitOut(inst, swallower, data)
	TheLog.ch.Groak:printf("Spit out! inst: %s (%d), swallower: %s (%d)", inst.prefab, inst.Network:GetEntityID(), swallower and swallower.prefab or "", swallower and swallower.Network:GetEntityID() or "")
	-- Monsters need to face the swallower when spit out in order to have the knockdown move in the right direction.
	if not inst:HasTag("character") and inst.Transform:GetFacing() == swallower.Transform:GetFacing() then
		inst.Transform:FlipFacingAndRotation()
	end

	if data and data.is_timeout then
		-- Face the same direction as Groak; when exiting, exit from the rear...
		local rot = swallower.Transform:GetRotation()
		inst.Transform:SetRotation(rot)
	else
		OnSwallowerSpitOut(inst, swallower, data)
	end

	local def = Power.FindPowerByName("groak_swallowed")
	inst.components.powermanager:RemovePower(def, true)

	local knockback = data and data.knockback or SPIT_OUT_PUSHBACK + (math.random() - 0.5)
	SGCommon.Fns.ExitSwallowed(inst, { swallower = swallower, knockback = knockback, spitout = true })
end

-- TODO: Copied from revive component. Consider making this a common function.
local function TryGetEntity(entity_id)
	local guid = TheNet:FindGUIDForEntityID(entity_id)
	if guid and guid ~= 0 and Ents[guid] and Ents[guid]:IsValid() then
		return Ents[guid]
	end
	return nil
end

local SWALLOW_TIMEOUT_TICKS = 480

Power.AddGroakPower("groak_swallowed",
{
	event_triggers =
	{
		["groak_chewed"] = function(pow, inst)
			local swallower = pow.mem.swallower
			if not swallower or not swallower:IsAlive() or not swallower:IsValid() then return end

			ChewTarget(inst, swallower)
		end,

		["groak_spitout"] = function(pow, inst, is_cinematic)
			local swallower = pow.mem.swallower
			if not swallower or not swallower:IsAlive() or not swallower:IsValid() then return end

			local data = {}
			if is_cinematic then
				data =
				{
					knockback = inst.sg.mem.spitout_knockback or 0,
					angle = inst.sg.mem.spitout_angle or 0,
				}
			end

			SpitOut(inst, swallower, data)
		end,
	},

	on_add_fn = function(pow, inst)
		-- Move from persistdata to mem
		pow.mem.swallower = pow.persistdata.source
		pow.persistdata.source = nil

		local swallower = pow.mem.swallower
		if not swallower then return end

		-- For networking, coordinate stuff with the swallower on the player's side.
		inst:Hide()
		inst.Physics:SetEnabled(false)
		inst.HitBox:SetEnabled(false)

		local facing = swallower.Transform:GetFacing() == FACING_LEFT and -1 or 1
		local swallower_pos = swallower:GetPosition()
		inst.Transform:SetPosition(swallower_pos.x + 2 * facing, swallower_pos.y + 1.5, swallower_pos.z)

		inst.sg.mem.isheld = true -- Used to handle player to not transition into death anims for simplier death state handling

		inst:AddTag("notarget") -- Used to prevent enemies targeting & attacking the player while swallowed.

		inst:Pause("swallowed") -- Prevent the entity from performing actions while swallowed.
		inst.sg:Pause("swallowed")

		-- Used for timeout to have the entity exit the groak if still swallowed for whatever reason.
		pow.mem.ticksremaining = SWALLOW_TIMEOUT_TICKS

		-- Used for remote players to stay inside groak while the networking catches up (TODO: find a better solution for this.)
		pow.mem.initial_keep_swallowed_ticks_remaining = 60
	end,

	on_net_serialize_fn = function(pow, e)
		local swallower = pow.mem.swallower
		local has_swallower = swallower and swallower:IsValid()
		e:SerializeBoolean(has_swallower)
		if has_swallower then
			e:SerializeEntityID(swallower.Network:GetEntityID())
		end
	end,

	on_net_deserialize_fn = function(pow, e)
		local has_swallower = e:DeserializeBoolean()
		if has_swallower then
			local ent_id = e:DeserializeEntityID()
			pow.mem.swallower = TryGetEntity(ent_id)
		end
	end,

	on_update_fn = function(pow, inst, dt)
		local swallower = pow.mem.swallower

		pow.mem.initial_keep_swallowed_ticks_remaining = pow.mem.initial_keep_swallowed_ticks_remaining and pow.mem.initial_keep_swallowed_ticks_remaining - 1 or 60

		-- Swallower somehow died/got removed; exit out of being swallowed.
		if not swallower or not swallower:IsAlive() or not swallower:IsValid() or
			(pow.mem.initial_keep_swallowed_ticks_remaining <= 0 and not (swallower.components.groaksync:IsSucking() or swallower.components.groaksync:HasJustSwallowed() or swallower.components.groaksync:IsSwallowing())) then
			inst.components.powermanager:RemovePower(pow.def)

			-- Re-position the entity to where groak's mouth was.
			if swallower then
				local swallower_pos = swallower:GetPosition()
				SetSwallowExitPosition(inst, swallower, swallower_pos.x, swallower_pos.z)
			end

			SGCommon.Fns.ExitSwallowed(inst, { swallower = swallower, knockback = PRE_SWALLOWED_CANCEL_PUSHBACK })
			return
		end

		pow.mem.ticksremaining = pow.mem.ticksremaining and pow.mem.ticksremaining - 1 or SWALLOW_TIMEOUT_TICKS
		if pow.mem.ticksremaining <= 0 then
			TheLog.ch.Groak:printf("Exited Groak via timeout! inst: %s (%d)", inst.prefab, inst.Network:GetEntityID())
			local swallower_pos = swallower:GetPosition()
			local facing = swallower.Transform:GetFacing() == FACING_LEFT and -1 or 1
			SetSwallowExitPosition(inst, swallower, swallower_pos.x - 2 * facing, swallower_pos.z)
			SpitOut(inst, swallower, { is_timeout = true })
		end
	end,

	on_remove_fn = function(pow, inst)
		TheLog.ch.Groak:printf("Groak Swallowed power removed! inst: %s (%d)", inst.prefab, inst.Network:GetEntityID())

		-- If the entity was swallowing something, spit it out.
		local swallowed_ent_cmp = inst.components.groaksync
		if swallowed_ent_cmp then
			local swallowed_ents = swallowed_ent_cmp:FindSwallowedEntities()
			local num_swallowed_ents = lume.count(swallowed_ents)
			if num_swallowed_ents > 0 then
				inst.components.attacktracker:CompleteActiveAttack()
				for _, ent in ipairs(swallowed_ents) do
					if ent.components.groaksync then
						ent.components.groaksync:SetStatusSpitOut()
					end
				end
			end
		end

		inst:Show()
		inst.Physics:SetEnabled(true)
		inst.HitBox:SetEnabled(true)
		inst.sg.mem.isheld = nil
		inst:RemoveTag("notarget")

		inst:Resume("swallowed")
		inst.sg:Resume("swallowed")
	end,
})
