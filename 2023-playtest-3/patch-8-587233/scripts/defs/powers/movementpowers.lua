local Power = require("defs.powers.power")
local lume = require "util.lume"
local SGCommon = require "stategraphs.sg_common"
local ParticleSystemHelper = require "util.particlesystemhelper"
local DebugDraw = require "util.debugdraw"


local WIND_EFFECT_ANGLE_RANGE = 22.5

local function SpawnMoveForceFX(inst, pow)
	if inst:IsLocal() then
		ParticleSystemHelper.MakeEventSpawnParticles(inst, { name = "wind_ground_trail", particlefxname = "dust_owlitzer_gust", ischild = true, })
	end
end

local function RemoveMoveForceFX(inst, pow)
	if inst:IsLocal() then
		ParticleSystemHelper.MakeEventStopParticles(inst, { name = "wind_ground_trail", })
	end
end

local function CheckPushSourceValid(pow, inst, source)
	-- Push source somehow not valid anymore; remove this power
	if not source or not source:IsValid() or (source.components.health and not source:IsAlive()) then
		inst.components.pushforce:RemovePushForce(pow.def.name, source, true)
		pow.mem.sources[source.GUID] = nil

		-- Last push source removed; remove the power altogether
		if lume.count(pow.mem.sources) <= 0 then
			inst.components.powermanager:RemovePower(pow.def, true)
		end
		return false
	end
	return true
end

local function CleanupMovementPower(pow, inst)
	if pow.mem.sources then
		for _, source in pairs(pow.mem.sources) do
			inst.components.pushforce:RemovePushForce(pow.def.name, source, true)
		end
	end
	RemoveMoveForceFX(inst, pow)
end

function Power.AddMovementPower(id, data)
	if not data.power_category then
		data.power_category = Power.Categories.SUSTAIN
	end

	if data.clear_on_new_room then
		local previous_trigger = data.event_triggers ~= nil and data.event_triggers["exit_room"] or nil

		if data.event_triggers == nil then
			data.event_triggers = {}
		elseif previous_trigger ~= nil then
			print ("POWER ALREADY HAS AN EXIT ROOM TRIGGER EVENT, ATTEMPTING MERGE")
		end

		data.event_triggers["exit_room"] = function(pow, inst, data)
			if previous_trigger then
				previous_trigger(pow, inst, data)
			end
			inst.components.powermanager:RemovePower(pow.def, true)
		end
	end

	data.power_type = Power.Types.MOVEMENT
	data.show_in_ui = false
	data.can_drop = false

	-- All movement powers require a locomotor. Don't add the power if not present.
	data.prerequisite_fn = function(inst)
		local eligible = false
		if inst.components.locomotor ~= nil then
			eligible = true
		end

		return eligible
	end

	Power.AddPower(Power.Slots.MOVEMENT, id, "movementpowers", data)
end

local function GetPushDistanceMultiplier(inst, x, z, max_distance_sq)
	local distance_to_src_sq = inst:GetDistanceSqToXZ(x, z)

	local dist_mult = math.max(0, 1 - (distance_to_src_sq / max_distance_sq)) -- Decay the force as we get further away from the point.
	dist_mult = dist_mult * dist_mult

	return dist_mult
end

Power.AddPowerFamily("MOVEMENT")

local PRE_SWALLOWED_CANCEL_PUSHBACK = 0.5
local GROAK_SUCK_DISTANCE = 16

Power.AddMovementPower("groak_suck",
{
	power_category = Power.Categories.ALL,
	selectable = false,
	clear_on_new_room = true,
	has_sources = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { speed = 20, swallow_point_offset = {2.5, 0, -1}, swallow_pre_distance = 2, swallow_distance = 0.5 },
	},

	event_triggers =
	{
		--[[["aura_source_added"] = function(pow, inst, source)
		end,]]
		["aura_source_removed"] = function(pow, inst, source)
			inst.components.pushforce:RemovePushForce(pow.def.name, source)

			if not source or not source:IsValid() then
				return
			end

			-- Source has finished swallowing or is interrupted before the entity got swallowed. Cancel out of pre-swallowed.
			if inst.sg:HasStateTag("pre_swallowed") and not source.components.groaksync:IsSucking() then
				SGCommon.Fns.ExitSwallowed(inst, { swallower = source, knockback = PRE_SWALLOWED_CANCEL_PUSHBACK })
			end
		end,
	},

	on_update_fn = function(pow, inst, dt)
		if not inst.components.pushforce or not pow.mem.sources then
			return
		end

		-- Apply movement forces towards sources
		for _, source in pairs(pow.mem.sources) do
			if CheckPushSourceValid(pow, inst, source) then
				-- Check if within swallow range
				local swallow_pt = source.components.groaksync:GetSwallowPoint(pow.persistdata:GetVar("swallow_point_offset"))
				local size = source.Physics:GetSize() -- Need to account for swallower size when calculating distances & offsets.

				--DebugDraw.GroundCircle(swallow_pt.x, swallow_pt.z, pow.persistdata:GetVar("swallow_distance") * size, WEBCOLORS.RED, 2)

				-- Standing to pre-swallowed check:
				if not inst:IsDead() then
					local swallow_pre_distance = pow.persistdata:GetVar("swallow_pre_distance") * size
					local swallow_distance = pow.persistdata:GetVar("swallow_distance") * size
					local inst_size = inst.Physics:GetSize()
					if not inst.sg:HasStateTag("pre_swallowed") and inst:GetDistanceSqToPoint(swallow_pt) <= swallow_pre_distance * swallow_pre_distance and size > inst_size then
						inst:PushEvent("pre_swallowed", { swallower = source }) -- Logic handled in sg_common/sg_player_common OnSwallowed event handler
						return
					-- Pre-swallowed to swallowed check:
					elseif not inst.sg:HasStateTag("swallowed") and inst:GetDistanceSqToPoint(swallow_pt) <= swallow_distance * swallow_distance and size > inst_size then
						inst:PushEvent("swallowed", { swallower = source })
						return
					end
				end

				local source_dir = (swallow_pt - inst:GetPosition()):normalized()
				--DebugDraw.GroundArrow_Vec(inst:GetPosition(), swallow_pt, WEBCOLORS.RED)
				--DebugDraw.GroundDirection_Vec(inst:GetPosition(), source_dir, WEBCOLORS.YELLOW)

				--DebugDraw.GroundArrow_Vec(inst:GetPosition(), inst:GetPosition() + Vector3(inst.Physics:GetVel()):normalized() * 2, WEBCOLORS.GREEN)
				local pullspeed_modifier = inst.sg:HasStateTag("pre_swallowed") and 2 or 1 -- Pull towards the swallower faster if in a swallowed pre state.
				local pullspeed = pow.persistdata:GetVar("speed") * pullspeed_modifier

				local source_x, source_z = source.Transform:GetWorldXZ()
				local dist_mult = GetPushDistanceMultiplier(inst, source_x, source_z, (GROAK_SUCK_DISTANCE * size) ^ 2)

				inst.components.pushforce:AddPushForce(pow.def.name, source, source_dir * pullspeed * dist_mult)
			end
		end
	end,

	on_remove_fn = CleanupMovementPower,
})

Power.AddMovementPower("windy",
{
	power_category = Power.Categories.ALL,
	selectable = false,
	clear_on_new_room = true,
	has_sources = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { speed = 3, swallow_point_offset = {2.5, 0, -1}, swallow_distance = 2 },
	},

	event_triggers =
	{
		--[[["aura_source_added"] = function(pow, inst, source)
		end,]]
		["aura_source_removed"] = function(pow, inst, source)
			inst.components.pushforce:RemovePushForce(pow.def.name, source)
		end,
	},

	--[[on_add_fn = function(pow, inst)
	end,]]

	on_update_fn = function(pow, inst, dt)
		-- Apply movement forces towards sources
		if not inst.components.pushforce then
			return
		end

		-- Which direction is the wind blowing?
		local x_direction = "RIGHT"
		local y_direction --= "UP"

		local x_source = 0
		if x_direction ~= nil then
			x_source = x_direction == "LEFT" and -50 or 50
		end

		local y_source = 0
		if y_direction ~= nil then
			y_source = y_direction == "DOWN" and -50 or 50
		end

		-- Check if within swallow range
		local pt = Vector3(table.unpack(pow.persistdata:GetVar("swallow_point_offset")))
		local facing = x_direction == "LEFT" and -1 or 1
		pt.x = pt.x * facing * 0.75 -- [TODO?] Adjust the multiplier to size so it works nicely at different scales.

		local source_dir = (Vector3(x_source, 0, y_source) - inst:GetPosition()):normalized()
		--DebugDraw.GroundArrow_Vec(inst:GetPosition(), swallow_pt, WEBCOLORS.RED)
		--DebugDraw.GroundDirection_Vec(inst:GetPosition(), source_dir, WEBCOLORS.YELLOW)

		--DebugDraw.GroundArrow_Vec(inst:GetPosition(), inst:GetPosition() + Vector3(inst.Physics:GetVel()):normalized() * 2, WEBCOLORS.GREEN)
		local pullspeed_modifier = inst.sg:HasStateTag("pre_swallowed") and 2 or 1 -- Pull towards the swallower faster if in a swallowed pre state.
		local pullspeed = pow.persistdata:GetVar("speed") * pullspeed_modifier
		inst.components.pushforce:AddPushForce(pow.def.name, nil, source_dir * pullspeed)
	end,

	on_remove_fn = CleanupMovementPower,
})

Power.AddMovementPower("owlitzer_transition_attack",
{
	power_category = Power.Categories.ALL,
	selectable = false,
	clear_on_new_room = true,
	has_sources = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { wind_gust_speed = 40 },
	},

	event_triggers =
	{
		["aura_source_added"] = function(pow, inst, source)
			SpawnMoveForceFX(inst, pow)
		end,
		["aura_source_removed"] = function(pow, inst, source)
			inst.components.pushforce:RemovePushForce(pow.def.name, source)
			RemoveMoveForceFX(inst, pow)
		end,
	},

	on_update_fn = function(pow, inst, dt)
		if not inst.components.pushforce or not pow.mem.sources then
			return
		end

		-- Apply movement forces horizontally away from owlitzer towards the sides of the screen.
		for _, owlitzer in pairs(pow.mem.sources) do
			if CheckPushSourceValid(pow, inst, owlitzer) then
				local owlitzer_pos = owlitzer:GetPosition()
				local pos = inst:GetPosition()

				local direction = pos.x < owlitzer_pos.x and -1 or 1

				local source_dir = Vector3.unit_x * direction
				local pushspeed = pow.persistdata:GetVar("wind_gust_speed")

				inst.components.pushforce:AddPushForce(pow.def.name, owlitzer, source_dir * pushspeed)
			end
		end
	end,

	on_remove_fn = CleanupMovementPower,
})

local OWLITZER_GUST_DISTANCE = 40
Power.AddMovementPower("owlitzer_super_flap",
{
	power_category = Power.Categories.ALL,
	selectable = false,
	clear_on_new_room = true,
	has_sources = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { super_flap_speed = 20, wind_gust_speed = 60, fly_by_pre_speed = 5 },
	},

	event_triggers =
	{
		["aura_source_added"] = function(pow, inst, source)
			SpawnMoveForceFX(inst, pow)
		end,
		["aura_source_removed"] = function(pow, inst, source)
			inst.components.pushforce:RemovePushForce(pow.def.name, source)
			RemoveMoveForceFX(inst, pow)
		end,
	},

	on_update_fn = function(pow, inst, dt)
		if not inst.components.pushforce or not pow.mem.sources then
			return
		end

		-- Apply movement forces towards one side of the screen.
		for _, owlitzer in pairs(pow.mem.sources) do
			if CheckPushSourceValid(pow, inst, owlitzer) then
				local facing = owlitzer and owlitzer.Transform:GetFacing() == FACING_LEFT and -1 or 1

				local source_dir = Vector3.unit_x * facing
				local pushspeed = owlitzer.sg.statemem.flap_speed or pow.persistdata:GetVar("super_flap_speed")

				local dist_mult = 1
				if pushspeed == pow.persistdata:GetVar("wind_gust_speed") then
					local size = owlitzer.Physics:GetSize()
					local source_x, source_z = owlitzer.Transform:GetWorldXZ()
					dist_mult = GetPushDistanceMultiplier(inst, source_x, source_z, (OWLITZER_GUST_DISTANCE * size) ^ 2)
				end

				inst.components.pushforce:AddPushForce(pow.def.name, owlitzer, source_dir * pushspeed * dist_mult)
			end
		end
	end,

	on_remove_fn = CleanupMovementPower,
})

Power.AddMovementPower("windtotem_wind",
{
	power_category = Power.Categories.ALL,
	selectable = false,
	clear_on_new_room = true,
	has_sources = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { wind_speed = 20 },
	},

	event_triggers =
	{
		["aura_source_added"] = function(pow, inst, source)
			SpawnMoveForceFX(inst, pow)
		end,
		["aura_source_removed"] = function(pow, inst, source)
			inst.components.pushforce:RemovePushForce(pow.def.name, source)
			RemoveMoveForceFX(inst, pow)
		end,
	},

	on_update_fn = function(pow, inst, dt)
		if not inst.components.pushforce or not pow.mem.sources then
			return
		end

		-- Apply movement forces towards one side of the screen.
		for _, wind_spawner in pairs(pow.mem.sources) do
			if CheckPushSourceValid(pow, inst, wind_spawner) then
				local facing = wind_spawner and wind_spawner:IsValid() and wind_spawner.Transform:GetFacing()

				local source_dir = Vector3.zero
				if facing == FACING_LEFT or facing == FACING_RIGHT then
					source_dir = Vector3.unit_x * (facing == FACING_LEFT and -1 or 1)
				else -- FACING_UP or FACING_DOWN
					source_dir = Vector3.unit_z * (facing == FACING_DOWN and -1 or 1)
				end

				local pushspeed = pow.persistdata:GetVar("wind_speed")
				inst.components.pushforce:AddPushForce(pow.def.name, wind_spawner, source_dir * pushspeed)
			end
		end
	end,

	on_remove_fn = CleanupMovementPower,
})

local function IsWithinWindAngle(inst, source)
	if not source.components.attackangle then return true end

	local wind_angle = source.components.attackangle:GetAttackAngle()
	local min_angle = wind_angle - WIND_EFFECT_ANGLE_RANGE
	local max_angle = wind_angle + WIND_EFFECT_ANGLE_RANGE

	--~ DebugDraw.GroundArrow_Vec(source:GetPosition(), source:GetPosition() + Vector3.unit_x:rotate_around_y(-math.rad(min_angle)) * 12, WEBCOLORS.RED)
	--~ DebugDraw.GroundArrow_Vec(source:GetPosition(), source:GetPosition() + Vector3.unit_x:rotate_around_y(-math.rad(max_angle)) * 12, WEBCOLORS.RED)

	return source:IsWithinAngleTo(inst, min_angle, max_angle)
end

local WINDMON_GUST_DISTANCE <const> = 16
Power.AddMovementPower("windmon_gust",
{
	power_category = Power.Categories.ALL,
	selectable = false,
	clear_on_new_room = true,
	has_sources = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { wind_speed = 50 },
	},

	event_triggers =
	{
		["aura_source_added"] = function(pow, inst, source)
			if IsWithinWindAngle(inst, source) then
				SpawnMoveForceFX(inst, pow)
			end
		end,
		["aura_source_removed"] = function(pow, inst, source)
			inst.components.pushforce:RemovePushForce(pow.def.name, source, true)
			RemoveMoveForceFX(inst, pow)
		end,
	},

	on_update_fn = function(pow, inst, dt)
		if not inst.components.pushforce or not pow.mem.sources then
			return
		end

		-- Only apply wind if the target is within the blowing angle range.
		for _, windmon in pairs(pow.mem.sources) do
			if CheckPushSourceValid(pow, inst, windmon) then
				if IsWithinWindAngle(inst, windmon) then
					-- Apply movement in the direction windmon is blowing wind from.
					local source_dir = windmon.components.attackangle:GetAttackDirection()

					local pushspeed = pow.persistdata:GetVar("wind_speed")

					local size = windmon.Physics:GetSize()
					local source_x, source_z = windmon.Transform:GetWorldXZ()
					local dist_mult = GetPushDistanceMultiplier(inst, source_x, source_z, (WINDMON_GUST_DISTANCE * size) ^ 2)

					inst.components.pushforce:AddPushForce(pow.def.name, windmon, source_dir * pushspeed * dist_mult, true) -- This wind source overrides other similar ones instead of stacking.
				end
			end
		end
	end,

	on_remove_fn = CleanupMovementPower,
})

local ELITE_WINDMON_GUST_DISTANCE <const> = WINDMON_GUST_DISTANCE
Power.AddMovementPower("elite_windmon_gust",
{
	power_category = Power.Categories.ALL,
	selectable = false,
	clear_on_new_room = true,
	has_sources = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { wind_speed = 50 },
	},

	event_triggers =
	{
		["aura_source_added"] = function(pow, inst, source)
			SpawnMoveForceFX(inst, pow)
		end,
		["aura_source_removed"] = function(pow, inst, source)
			inst.components.pushforce:RemovePushForce(pow.def.name, source, true)
			RemoveMoveForceFX(inst, pow)
		end,
	},

	on_update_fn = function(pow, inst, dt)
		if not inst.components.pushforce or not pow.mem.sources then
			return
		end

		for _, windmon in pairs(pow.mem.sources) do
			if CheckPushSourceValid(pow, inst, windmon) then
				-- Apply movement away from windmon.
				local source_dir = windmon.components.attackangle:GetAttackDirection()

				local pushspeed = pow.persistdata:GetVar("wind_speed")

				local size = windmon.Physics:GetSize()
				local source_x, source_z = windmon.Transform:GetWorldXZ()
				local dist_mult = GetPushDistanceMultiplier(inst, source_x, source_z, (ELITE_WINDMON_GUST_DISTANCE * size) ^ 2)

				inst.components.pushforce:AddPushForce(pow.def.name, windmon, source_dir * pushspeed * dist_mult, true) -- This wind source overrides other similar ones instead of stacking.
			end
		end
	end,

	on_remove_fn = CleanupMovementPower,
})

Power.AddMovementPower("player_wind_gust",
{
	power_category = Power.Categories.ALL,
	selectable = true,
	clear_on_new_room = true,
	has_sources = true,

	tuning =
	{
		[Power.Rarity.COMMON] = { wind_speed = 30, effective_ticks = 15, max_distance = 50 },
		[Power.Rarity.EPIC] = { wind_speed = 30, effective_ticks = 25, max_distance = 70 },
		[Power.Rarity.LEGENDARY] = { wind_speed = 35, effective_ticks = 30, max_distance = 100 }, --wind_speed = 60, effective_ticks = 60, max_distance = 150 },
	},

	event_triggers =
	{
		-- FYI: This power is not applied via an aura, so aura applyer event listeners here will never be reached.
	},

	on_add_fn = function(pow, inst)
		pow.mem.ticksremaining = pow.persistdata:GetVar("effective_ticks") -- How many ticks should this wind affect the target for?
		pow.mem.max_push_distance = pow.persistdata:GetVar("max_distance") -- How far is the maximum amount this should be able to push something?
	end,

	on_update_fn = function(pow, inst, dt)
		if not inst.components.pushforce or not pow.mem.sources then
			return
		end

		if pow.mem.activated then
			-- Pushforce needs to be reapplied each tick, it looks like. So here, just keep applying it every frame.
			local dist_mult = GetPushDistanceMultiplier(inst, pow.mem.src_x, pow.mem.src_z, pow.mem.max_push_distance)

			--printf("Player Wind Gust: %s / %s : %s", distance_to_src, pow.mem.max_push_distance, dist_mult)

			inst.components.pushforce:AddPushForce(pow.def.name, pow.mem.src, pow.mem.source_dir * pow.mem.push_speed * dist_mult, true) -- This wind source overrides other similar ones instead of stacking.
		else
			for _, src in pairs(pow.mem.sources) do
				if src and src:IsValid() then
					-- Apply movement in the direction src is blowing wind from.
					local wind_angle = src:GetAngleTo(inst)
					local source_dir = Vector3.unit_x:rotate_around_y(-math.rad(wind_angle))
					--~ DebugDraw.GroundArrow_Vec(inst:GetPosition(), inst:GetPosition() + source_dir * 12, WEBCOLORS.RED)
					local pushspeed = pow.persistdata:GetVar("wind_speed")

					inst.components.pushforce:AddPushForce(pow.def.name, src, source_dir * pushspeed, true) -- This wind source overrides other similar ones instead of stacking.

					-- Set all the information once, and then use it for the lifetime of this power.
					pow.mem.source_dir = source_dir
					pow.mem.wind_angle = wind_angle
					pow.mem.push_speed = pushspeed
					pow.mem.src = src
					pow.mem.src_x, pow.mem.src_z = src.Transform:GetWorldXZ()
					pow.mem.activated = true

					-- Only apply for one source
					break
				else
					-- src somehow not valid anymore; remove this power
					inst.components.powermanager:RemovePower(pow.def)
				end
			end
		end

		pow.mem.ticksremaining = pow.mem.ticksremaining - 1
		if pow.mem.ticksremaining <= 0 then
			pow.mem.activated = false
			inst.components.powermanager:RemovePower(pow.def)
		end
	end,

	on_remove_fn = function(pow, inst)
		inst.components.pushforce:RemovePushForce(pow.def.name, pow.mem.player, true)
		CleanupMovementPower(pow, inst)
	end,
})
