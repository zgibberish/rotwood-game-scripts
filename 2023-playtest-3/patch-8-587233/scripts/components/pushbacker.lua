-- TODO: use easing to ease, rather than pop
local lume = require "util.lume"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"
local Weight = require "components.weight"

PushBackWeight =
{
	HEAVY = 0.1, -- does not get pushed very far
	LIGHT = 1.5, -- gets pushed back a lot! be careful using this, because it may not look very good.
}

local PushBacker = Class(function(self, inst)
	self.inst = inst
	self.timetostop = nil
	self.active = false
	self.x_speed = 0
	self.y_speed = 0
	self.pushback_weight = 1
end)

local angle_to_z_modifier =
{
	-- 0-1 value where 0 is 0 degree angle, and 1 is 90 degree angle -----> how much should we push up/down based on that angle
	-- 0 = directly horizontal
	-- 0.5 = 45 degree angle
	-- do not push vertically at all if within a 45 degree cone
	{0.0,	0.0},
	{0.5,	0.0},
	{0.6,	0.5},
	{0.8,   0.75},
	{1.0,   1.0},
}

local relativeweight_to_pushback_multiplier =
{
	[Weight.Status.s.Light] = 2,
	[Weight.Status.s.Normal] = 1,
	[Weight.Status.s.Heavy] = 0.5,
}

function PushBacker:DoPushBack(attacker, modifier, animframes)
	if self.active or modifier == 0 then
		return
	end
	self.active = true

	local dist_modifier = modifier or 1
	local pushbackweight_modifier = self.pushback_weight or 1

	local relativeweight_modifier = 1
	local weight_cmp = self.inst.components.weight
	if weight_cmp then
		relativeweight_modifier = relativeweight_to_pushback_multiplier[weight_cmp:GetStatus()]
	end
	
	local angle
	if attacker ~= nil and attacker:IsValid() then
		angle = self.inst:GetAngleTo(attacker)
	else
		angle = self.inst.Transform:GetFacingRotation()
	end

	-- Calculate how far away from head-on we are -- result in a float 0-1 where 0 is head-on, and 1 is 90 degree angle
	local difference_to_head_on = 0
	if angle >= -90 and angle <= 90 then -- right side
		difference_to_head_on = math.abs(angle)
	elseif (math.abs(angle) >= 90 and math.abs(angle) <= 180) then -- left side, above and below
		difference_to_head_on = 180 - math.abs(angle)
	end
	difference_to_head_on = difference_to_head_on/90 -- map that angle difference from 0-1
	local z_modifier = PiecewiseFn(difference_to_head_on, angle_to_z_modifier)

	local distance = TUNING.PUSHBACK_DISTANCE_DEFAULT * dist_modifier * pushbackweight_modifier * relativeweight_modifier
	local cosangle = math.cos(math.rad(angle))
	local sinangle = math.sin(math.rad(angle))

	self.x_speed = distance * -cosangle
	self.z_speed = distance * sinangle * z_modifier

	self.inst.Physics:Move(self.x_speed, 0, self.z_speed)

	-- sound
	-- 1 is a very noticeable slide, so that's the only thing we're putting sound on for now
	-- if we wanted to be really cheeky this could check for tile type buuuuuut
	if self.inst.SoundEmitter and distance > 1 then
		local params = {}
		params.fmodevent = fmodtable.Event.Pushback_heavy
		params.autostop = true
		params.sound_max_count = 1
		soundutil.PlaySoundData(self.inst, params)
	end

	-- internal system uses time despite being fed hitstun frames
	if animframes then
		self.timetostop = GetTime() + animframes * ANIM_FRAMES * TICKS
	end
	self.inst:StartUpdatingComponent(self)
end

function PushBacker:OnUpdate(dt)
	-- print("PushBacker OnUpdate")
	-- print(self.x_speed)
	-- print(self.z_speed)
	self.x_speed = self.x_speed*0.6
	self.z_speed = self.z_speed*0.6
	self.inst.Physics:Move(self.x_speed, 0, self.z_speed)

	if self.timetostop and GetTime() > self.timetostop then
		self:Stop()
	end
end

function PushBacker:Stop()
	self.inst.Physics:Stop()
	self.active = false
	self.inst:StopUpdatingComponent(self)
	self.timetostop = nil
end

return PushBacker
