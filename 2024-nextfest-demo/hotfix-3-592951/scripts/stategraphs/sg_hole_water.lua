local SGCommon = require "stategraphs.sg_common"
local DebugDraw = require "util.debugdraw"

local events =
{
}

local LAND_DELAY_FRAMES = 2
local LAND_HITSTOP = true
local SPLASH_DELAY_FRAMES = 2
local MOB_KILL_DELAY_FRAMES = 2
local PLAYER_APPEAR_DELAY_FRAMES = 30

local function PlayLandSplash(inst, x, z)
	local splash = SpawnPrefab("fx_splash_2", inst)
	splash.Transform:SetPosition(x, 0, z)
end

local function FindShoreForShotput(shotput)
	--TEMP(jambell): SUPER temporary for now until the 'holes' are not considered walkable space, or another solution. Find a tile which is ground, spawn there.
	local x,z = shotput.Transform:GetWorldXZ()
	local final_x
	local final_z
	local target_pos = {}

	local search_dir = shotput.sg.mem.facing == FACING_LEFT and "right" or "left"

	local check_dist = 20
	--check left
	if search_dir == "left" then
		for i=1,check_dist do
			local tile = TheWorld.Map:GetNamedTileAtXZ(x - i, z)
			-- print("check:", x - i, z)
			if tile ~= "IMPASSABLE" then
				-- print("FOUND")
				final_x = x - i
				final_z = z
				break
			end
		end

	else
		--check right
		for i=1,check_dist do
			local tile = TheWorld.Map:GetNamedTileAtXZ(x + i, z)
			-- print("check:", x - i, z)
			if tile ~= "IMPASSABLE" then
				-- print("FOUND")
				final_x = x + i
				final_z = z
				break
			end
		end
	end

	target_pos.x = final_x
	target_pos.y = 0
	target_pos.z = final_z

	return target_pos
end

local function DamageEntity(inst, target)
	if target:HasTag("player") then
		local power_attack = Attack(inst, target)
		power_attack:SetOverrideDamage(100)
		power_attack:SetIgnoresArmour(true)
		power_attack:SetSource("water")
		power_attack:SetHitstunAnimFrames(10)
		power_attack:InitDamageAmount()

		inst.components.combat:DoPowerAttack(power_attack)

		SGCommon.Fns.BlinkAndFadeColor(target, { 255/255, 50/255, 50/255, 1 }, 8)
	end
end

local function PlaceEntityBack(inst, target, pos)
	target:Show()
	target.Transform:SetPosition(pos.x, pos.y, pos.z)

	inst.sg.mem.drowned[target] = nil
	target.sg.mem.drowning = nil
end

local function DrownPlayer(inst, target)
	-- Grab these in case we need them later and we don't know the lastjumppoint. Probably temp.
	local pos = target:GetPosition()
	local vel_x, vel_y, vel_z = target.Physics:GetVel()

	-- Play a splash where the target landed
	local x = pos.x
	local z = pos.z
	PlayLandSplash(inst, x, z)

	-- Hitstop the target for a few frames so the eye can detect the event, and stop their physics.
	if LAND_HITSTOP then
		target.components.hitstopper:PushHitStop(LAND_DELAY_FRAMES)
	end
	target.Physics:Stop()
	target.sg.mem.drowning = true

	-- After a few frames, hide the target
	inst:DoTaskInAnimFrames(LAND_DELAY_FRAMES, function()
		target:Hide()
	end)

	-- After a few more frames, make a big splash!
	inst:DoTaskInAnimFrames(LAND_DELAY_FRAMES + SPLASH_DELAY_FRAMES, function()
		local bigsplash = SpawnPrefab("water_splash", inst)
		bigsplash.Transform:SetPosition(x, 0, z)
	end)

	local lastpoint = target.sg.mem.lastjumppoint
	if lastpoint == nil then
		-- Make a best guess on their previous position based on their velocity and position
		lastpoint = {}
		lastpoint.x = pos.x + (vel_x * -1 * TICKS)
		lastpoint.y = pos.y + (vel_y * -1 * TICKS)
		lastpoint.z = pos.z + (vel_z * -1 * TICKS)
	end
	-- DebugDraw.GroundPoint(lastpoint.x, lastpoint.z, 1, WEBCOLORS.YELLOW, 1, 3)

	inst:DoTaskInAnimFrames(LAND_DELAY_FRAMES + SPLASH_DELAY_FRAMES + PLAYER_APPEAR_DELAY_FRAMES, function()
		if target:HasTag("player") then
			PlaceEntityBack(inst, target, lastpoint)
			DamageEntity(inst, target)
		end

	end)
end

local function DrownShotput(inst, target)
	inst.AnimState:Pause()

	-- Play a splash where the target landed
	local pos = target:GetPosition()
	local x = pos.x
	local z = pos.z
	PlayLandSplash(inst, x, z)

	-- Hitstop the target for a few frames so the eye can detect the event, and stop their physics.
	if LAND_HITSTOP then
		target.components.hitstopper:PushHitStop(LAND_DELAY_FRAMES)
	end
	target.Physics:Stop()
	target.sg.mem.drowning = true

	-- After a few frames, hide the target
	inst:DoTaskInAnimFrames(LAND_DELAY_FRAMES, function()
		target:Hide()
	end)

	-- After a few more frames, make a big splash!
	inst:DoTaskInAnimFrames(LAND_DELAY_FRAMES + SPLASH_DELAY_FRAMES, function()
		local bigsplash = SpawnPrefab("water_splash", inst)
		bigsplash.Transform:SetPosition(x, 0, z)
	end)

	local lastpoint = FindShoreForShotput(target)
	-- DebugDraw.GroundPoint(lastpoint.x, lastpoint.z, 1, WEBCOLORS.YELLOW, 1, 3)

	inst:DoTaskInAnimFrames(LAND_DELAY_FRAMES + SPLASH_DELAY_FRAMES + PLAYER_APPEAR_DELAY_FRAMES, function()
		PlaceEntityBack(inst, target, lastpoint)
		SGCommon.Fns.BlinkAndFadeColor(target, { 255/255, 255/255, 255/255, 1 }, 8)
	end)
end

local function DrownMob(inst, target)
	-- Play a splash where the target landed
	local x, z = target.Transform:GetWorldXZ()
	PlayLandSplash(inst, x, z)

	-- Hitstop the target for a few frames so the eye can detect the event, and stop their physics.
	if LAND_HITSTOP then
		target.components.hitstopper:PushHitStop(LAND_DELAY_FRAMES)
	end
	target.Physics:Stop()
	target.sg.mem.drowning = true

	-- After a few frames, hide the target
	inst:DoTaskInAnimFrames(LAND_DELAY_FRAMES, function()
		target:Hide()
	end)

	-- After a few more frames, make a big splash!
	inst:DoTaskInAnimFrames(LAND_DELAY_FRAMES + SPLASH_DELAY_FRAMES, function()
		local bigsplash = SpawnPrefab("water_splash", inst)
		bigsplash.Transform:SetPosition(x, 0, z)
	end)

	-- Since this is a mob, just kill them
	inst:DoTaskInAnimFrames(LAND_DELAY_FRAMES + SPLASH_DELAY_FRAMES + MOB_KILL_DELAY_FRAMES, function()
		target.components.health:Kill()
	end)
end

local function OnHitBoxTriggered(inst, data)
	if TheDungeon:GetDungeonMap():IsDebugMap() then
		return
	end

	for i = 1, #data.targets do
		local v = data.targets[i]
		if v.sg:HasStateTag("airborne") -- airborne!
			or v.sg:HasStateTag("airborne_high") -- really airborne!
			or v.sg:HasStateTag("flying") -- flying creature
			or inst.sg.mem.drowned[v] ~= nil -- I already drowned this thing
			or v.sg.mem.drowning then -- something else is already drowning this thing
			return
		end

		local drowned = false
		if v:HasTag("player") then
			DrownPlayer(inst, v)
			drowned = true
		elseif v:HasTag("shotput") then
			if v.sg.currentstate.name == "landing" or v.sg.currentstate.name == "grounded" then
				DrownShotput(inst, v)
				drowned = true
			end
		else
			DrownMob(inst, v)
			drowned = true
		end

		if drowned then
			inst.sg.mem.drowned[v] = true
		end
	end
end

local states =
{
	State({
		name = "init",
		tags = { },

		onenter = function(inst)
			if not TheDungeon:GetDungeonMap():IsDebugMap() then
				inst:Hide()
			end

			inst.entity:AddHitBox()
			inst:AddComponent("hitbox")
			inst.components.hitbox:SetUtilityHitbox(true)
			inst.components.hitbox:SetHitGroup(HitGroup.NEUTRAL)
			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS | HitGroup.CREATURES)

			inst:AddComponent("combat")

			inst.sg.mem.drowned = {}

			inst.sg:GoToState("idle")
		end,

		timeline =
		{
		},

		events =
		{

		},
	}),

	State({
		name = "idle",
		tags = { },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "ground_loop", true)
		end,

		onupdate = function(inst)
			inst.components.hitbox:PushBeam(-1.5, 1.5, 1.5, HitPriority.PLAYER_DEFAULT)
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
		},
	}),
}

return StateGraph("sg_hole_water", states, events, "init")
