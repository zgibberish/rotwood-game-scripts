local color = require "math.modules.color"
local easing = require("util.easing")
local ParticleSystemHelper = require "util.particlesystemhelper"

local rundust_prefabs =
{
	treemon_forest = "dust_footstep_run_forest",
	owlitzer_forest = "dust_footstep_run_owlforest",
	kanft_swamp = "dust_footstep_run_swamp",
	thatcher_swamp = "dust_footstep_run_acidswamp",
	sedament_tundra = "dust_footstep_run_forest",
}

local movespeed_emitrate_data =
{
	-- total movespeed %, emit rate
	{100, 	0},
	{110,   1},
	{150, 	1.5},
	{200, 	2.5},
	{250, 	3},
}

local movespeed_scalemult_data =
{
	-- total movespeed %, scale mult
	{100, 	1},
	{200, 	2},
}

-- TODO: someone -- base crit chance is ~1%
-- may want to modify this piecewise fn data to not emit below a certain threshold
-- otherwise, after a buff, the emitter will remain visible
local critchance_emitrate_data =
{
	-- total critchance, emit rate
	{0, 	0},
	{2,		0}, -- TODO: someone adjust this x threshold value
	{50, 	.75},
	{100, 	1},
}

local critchance_scalemult_data =
{
	-- total critchance, emit rate
	{0, 	0.5},
	{100, 	1},
}

local critchance_i_data =
{
	-- crit chance %, bloom amount
	{0,		0},
	{25, 	0.5},
	{50, 	0.75},
	{75, 	0.85},
	{100, 	1},
}

local function StopParticles_MoveSpeed(inst)
	local fxer = inst.components.playerstatsfxer
	local particles = fxer.movespeedparticles.components.particlesystem
	particles:Stop()
end

local function StopParticles_All(inst)
	local fxer = inst.components.playerstatsfxer
	fxer.movespeedparticles.components.particlesystem:Stop()
	fxer.crithandsparticles.components.particlesystem:Stop()
end

local function OnSpeedMultChanged(inst, data)
	local fxer = inst.components.playerstatsfxer
	if data.new >= data.old then
		fxer.movespeed_emitmult_target = data.new
		fxer.movespeed_emitmult_current = data.new
	else
		fxer.movespeed_emitmult_target = data.new
	end
	fxer:CheckIfShouldUpdateMovespeed()
end

local function UpdateMoveSpeedEmitter(inst)
	local fxer = inst.components.playerstatsfxer
	local emitmult = PiecewiseFn(fxer.movespeed_emitmult_current * 100, movespeed_emitrate_data)
	local scalemult = PiecewiseFn(fxer.movespeed_emitmult_current * 100, movespeed_scalemult_data)

	if fxer.rundust_emitter1 ~= nil then
		fxer.rundust_emitter1:SetEmitRateMult(emitmult)
		fxer.rundust_emitter1:SetScaleMult(scalemult)
	end

	if fxer.rundust_emitter2 ~= nil then
		fxer.rundust_emitter2:SetEmitRateMult(emitmult)
		fxer.rundust_emitter2:SetScaleMult(scalemult)
	end

	if fxer.rundust_emitter3 ~= nil then
		-- don't emitrate mult
		fxer.rundust_emitter3:SetScaleMult(scalemult)
	end
end

local function OnLocomote(inst, data)
	local fxer = inst.components.playerstatsfxer
	local particles = fxer.movespeedparticles.components.particlesystem
	if data.move and fxer.movespeed_emitmult_current > 1 then
		UpdateMoveSpeedEmitter(inst)
	else
		particles:Stop()
	end
end

local function OnDodge(inst, data)
	UpdateMoveSpeedEmitter(inst)
end

local function OnDeath(inst, data)
	StopParticles_MoveSpeed(inst)
end

local function OnDodgePst(inst, data)
	StopParticles_MoveSpeed(inst)
end

local function OnAttack(inst, data)
	StopParticles_MoveSpeed(inst)
end


local function OnCritChanceChanged(inst, data)
	local fxer = inst.components.playerstatsfxer
	if data.new >= data.old then
		-- Update hand tinting
		fxer:UpdateTargetCritParameters(data)
		fxer.critchance_color_current = fxer.critchance_color_target
		if inst:IsLocalOrMinimal() then
			inst.AnimState:SetSymbolBloom("base_hand", fxer.critchance_color_target:unpack())
		end

		-- Also update particle fx on the hands
		fxer.critchance_emitmult_current = fxer.critchance_emitmult_target
		fxer.critchance_scalemult_current = fxer.critchance_scalemult_target
		fxer.crithands_emitter1:SetEmitRateMult(fxer.critchance_emitmult_target)
		fxer.crithands_emitter1:SetScaleMult(fxer.critchance_emitmult_target)
	else
		fxer:UpdateTargetCritParameters(data)
		fxer:CheckIfShouldUpdateCrit()
	end
end


local PlayerStatsFXer = Class(function(self, inst)
	self.inst = inst

	-- MoveSpeed
	--		Components

	local biome = TheDungeon:GetDungeonMap():GetBiomeLocation()
	local rundust_param =
	{
		particlefxname= biome.id ~= nil and rundust_prefabs[biome.id] or "dust_footstep_run_3",
		use_entity_facing=true,
		ischild = true,
	}
	self.movespeedparticles = ParticleSystemHelper.MakeEventSpawnParticles(self.inst, rundust_param)
	self.movespeedparticles.components.particlesystem:Stop()
	self.movespeedparticles.entity:SetParent(inst.entity)

	-- We will scale these at different emit amounts and scale amounts based on speed of the entity.
	self.rundust_emitter1 = self.movespeedparticles.components.particlesystem:GetEmitter(1)
	self.rundust_emitter2 = self.movespeedparticles.components.particlesystem:GetEmitter(2)
	self.rundust_emitter3 = self.movespeedparticles.components.particlesystem:GetEmitter(3)

	local crithands_param =
	{
		followsymbol="armor_hand",
		particlefxname="crit_hands",
		use_entity_facing=true,
		ischild = true,
	}
	self.crithandsparticles = ParticleSystemHelper.MakeEventSpawnParticles(self.inst, crithands_param)
	self.crithandsparticles.components.particlesystem:Stop()
	self.crithands_emitter1 = self.crithandsparticles.components.particlesystem:GetEmitter(1)
	self.crithands_emitter2 = self.crithandsparticles.components.particlesystem:GetEmitter(2)

	-- 		Events
	self.inst:ListenForEvent("speed_mult_changed", OnSpeedMultChanged)
	self.inst:ListenForEvent("locomote", OnLocomote)
	self.inst:ListenForEvent("dodge", OnDodge)
	self.inst:ListenForEvent("death", OnDeath)
	self.inst:ListenForEvent("dodge_pst", OnDodgePst)
	self.inst:ListenForEvent("attack_state_start", OnAttack)

	--		Variables
	self.updating_movespeed = false
	self.fading_movespeed_time = nil
	self.movespeed_emitmult_target = nil
	self.movespeed_emitmult_current = 1

	-- CritChance
	--		Events
	self.inst:ListenForEvent("crit_chance_changed", OnCritChanceChanged)

	--		Variables
	self.updating_critchance = false
	self.fading_critchance_time = nil

	self.critchance_color_target = nil
	self.critchance_color_current = nil

	self.critchance_emitmult_target = nil
	self.critchance_emitmult_current = 1
end)

function PlayerStatsFXer:OnNetSerialize()
	local e = self.inst.entity

	-- movespeed
	e:SerializeBoolean(self.movespeed_emitmult_target ~= nil)
	if self.movespeed_emitmult_target then
		e:SerializeDoubleAs16Bit(self.movespeed_emitmult_target)
	end

	local is_movespeedparticles_stopped = self.movespeedparticles.components.particlesystem:IsStopped()
	e:SerializeBoolean(is_movespeedparticles_stopped)

	-- critchance
	local has_critchance = self.critchance_raw ~= nil
	e:SerializeBoolean(has_critchance)
	if has_critchance then
		-- save this as an integer with 7 bits of precision
		local critchance_packed = math.round(math.clamp(self.critchance_raw * 100, 0, 100))
		e:SerializeUInt(math.tointeger(critchance_packed), 7)
	end
end

function PlayerStatsFXer:OnNetDeserialize()
	local e = self.inst.entity

	-- movespeed
	assert(self.movespeedparticles)

	local has_movespeed_emitmult_target = e:DeserializeBoolean()
	if has_movespeed_emitmult_target then
		local movespeed_emitmult_target_new = e:DeserializeDoubleAs16Bit()

		if movespeed_emitmult_target_new ~= self.movespeed_emitmult_target then
			local data = { new = movespeed_emitmult_target_new, old = self.movespeed_emitmult_target or movespeed_emitmult_target_new }
			OnSpeedMultChanged(self.inst, data)
		end
	end

	local is_movespeedparticles_stopped_new = e:DeserializeBoolean()
	local is_movespeedparticles_stopped_old = self.movespeedparticles.components.particlesystem:IsStopped()

	if is_movespeedparticles_stopped_new ~= is_movespeedparticles_stopped_old then
		if is_movespeedparticles_stopped_new then
			StopParticles_MoveSpeed(self.inst)
		else
			UpdateMoveSpeedEmitter(self.inst)
		end
	end

	-- critchance
	local has_critchance = e:DeserializeBoolean()
	if has_critchance then
		local critchance_raw_new = e:DeserializeUInt(7) / 100
		local data =
		{
			new = critchance_raw_new,
			old = self.critchance_raw or critchance_raw_new,
		}
		OnCritChanceChanged(self.inst, data)
	end
end

local CRITCHANCE_FADE_TIME = 0.25
local MOVESPEED_FADE_TIME = 0.5

local CRITCOLOR_MIN = color.new(242/255, 117/255, 253/255, 1)
local CRITCOLOR_MAX = color.new(226/255, 29/255, 153/255, 1)

function PlayerStatsFXer:UpdateTargetCritParameters(data)
	self.critchance_raw = math.clamp(data.new, 0, 1)
	self.critchance_color_target = color.lerp(CRITCOLOR_MIN, CRITCOLOR_MAX, math.clamp(data.new, 0, 1)) -- was data.new/100
	self.critchance_color_target[4] = PiecewiseFn(data.new * 100, critchance_i_data)

	self.critchance_emitmult_target = PiecewiseFn(data.new * 100, critchance_emitrate_data)
	self.critchance_scalemult_target = PiecewiseFn(data.new * 100, critchance_scalemult_data)
end

function PlayerStatsFXer:CheckIfShouldUpdateCrit()
	if self.critchance_color_target ~= self.critchance_color_current
		and self.critchance_emitmult_target ~= self.critchance_emitmult_current then
			self.inst:StartUpdatingComponent(self)
			self.updating_critchance = true
	end
end

function PlayerStatsFXer:CheckIfShouldUpdateMovespeed()
	if self.movespeed_emitmult_target ~= self.movespeed_emitmult_current then
		self.inst:StartUpdatingComponent(self)
		self.updating_movespeed = true
	end
end

function PlayerStatsFXer:OnUpdate(dt)
	local should_update = false
	if self.updating_critchance then
		local t = (self.fading_critchance_time or 0) + dt
		self.fading_critchance_time = t

		local current = self.critchance_color_current or color.new()
		local current_emitmult = self.critchance_emitmult_current or 0
		local current_scalemult = self.critchance_scalemult_current or 0

		local target = self.critchance_color_target
		local target_emitmult = self.critchance_emitmult_target
		local target_scalemult = self.critchance_scalemult_target

		local s = math.min(t / CRITCHANCE_FADE_TIME, 1)
		self.critchance_color_current = color.lerp(current, target, s)

		if self.inst:IsLocalOrMinimal() then
			self.inst.AnimState:SetSymbolBloom("base_hand", self.critchance_color_current:unpack())
		end

		local lerped_emitmult = easing.linear(t, current_emitmult, target_emitmult - current_emitmult, CRITCHANCE_FADE_TIME)
		self.crithands_emitter1:SetEmitRateMult(lerped_emitmult)
		local lerped_scalemult = easing.linear(t, current_scalemult, target_scalemult - current_scalemult, CRITCHANCE_FADE_TIME)
		self.crithands_emitter1:SetScaleMult(lerped_scalemult)

		if self.fading_critchance_time >= CRITCHANCE_FADE_TIME then
			self.updating_critchance = false
			self.fading_critchance_time = nil
			self.critchance_color_target = nil
			self.critchance_emitmult_current = nil
			self.critchance_raw = nil
		else
			should_update = true
		end
	end

	if self.updating_movespeed then
		local t = (self.fading_movespeed_time or 0) + dt
		self.fading_movespeed_time = t
		local lerped_emitmult = easing.linear(t, self.movespeed_emitmult_current, self.movespeed_emitmult_target - self.movespeed_emitmult_current, MOVESPEED_FADE_TIME)
		self.movespeed_emitmult_current = lerped_emitmult

		if self.fading_movespeed_time >= MOVESPEED_FADE_TIME then
			self.updating_movespeed = false
			self.fading_movespeed_time = nil
			self.movespeed_emitmult_target = nil
		else
			should_update = true
		end
	end

	if not should_update then
		self.inst:StopUpdatingComponent(self)
	end
end

return PlayerStatsFXer
