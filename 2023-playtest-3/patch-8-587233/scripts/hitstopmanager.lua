--Use a manager for hit stops to queue them up until post update.
--This ensures stategraph and AnimState are paused after updating
--the same frame.

HitStopLevel =
{
	NONE = 0,
	MINOR = 1,
	LIGHT = 1,
	MEDIUM = 2,
	HEAVY = 3,
	HEAVIER = 5,
	MAJOR = 7,
	KILL = 5,
	MINIBOSSKILL = 10,
	BOSSKILL = 15,
	PLAYERKILL = 25,
}

local HitStopManagerClass = Class(function(self)
	self.queue = {}
	self.requeue = {}
	self.stopped = {}
	self.lastupdatetick = 0
end)


local function AddControlQueueModifier(ent, ticks)
	-- While in hitstop, the player's button presses often get "eaten" in the control queue because the player is paused for so many frames.
	-- This can make it feel like your button presses are not respected.
	-- Here, whenever hitstop is applied to the player, modify the player's control queue a bit to allow those buttons to not be consumed.

	local frames = (ticks * ANIM_FRAMES) -- Convert to anim frames.
	frames = frames * TUNING.player.extra_controlqueueticks_on_hitstop_mult -- Add extra frames to the controlqueue, multiplied by this multiplier
	frames = math.min(frames, TUNING.player.extra_controlqueueticks_on_hitstop_maximum)   -- But cap it at this amount of frames extra, so we don't get MASSIVE mods on heavy hitstop moments.
	frames = math.max(frames, TUNING.player.extra_controlqueueticks_on_hitstop_minimum)
	ent.components.playercontroller:AddGlobalControlQueueTicksModifier(frames, "HitstopManager")

	ent:DoTaskInAnimFrames(frames, function()
		if ent ~= nil and ent:IsValid() then
			ent.components.playercontroller:RemoveGlobalControlQueueTicksModifier("HitstopManager")
		end
	end)
end

local function RemoveControlQueueModifier(ent)
	ent.components.playercontroller:RemoveControlQueueTicksModifier("dodge", "HitstopManager")
end

-- accepts anim frames as input, but internally operates on ticks
function HitStopManagerClass:PushHitStop(ent, frames)
	local ticks = frames * ANIM_FRAMES
	if ticks <= 0 then
		return
	elseif self.requeue[ent] ~= nil then
		self.requeue[ent] = math.max(self.requeue[ent] or 1, ticks - 1)
	elseif self.stopped[ent] ~= nil then
		--advance one frame and stop again
		self.stopped[ent] = 0
		self.requeue[ent] = math.max(self.requeue[ent] or 1, ticks - 1)
	else
		self.queue[ent] = math.max(self.queue[ent] or 1, ticks)
	end

	if ent:HasTag("player") then
		AddControlQueueModifier(ent, frames)
	end
end

function HitStopManagerClass:PostUpdate()
	local tick = GetTick()
	if tick <= self.lastupdatetick then
		return
	end

	local dt = tick - self.lastupdatetick
	self.lastupdatetick = tick

	for k, v in pairs(self.stopped) do
		if v > dt then
			self.stopped[k] = v - dt
		else
			self.stopped[k] = nil
			if k:IsValid() then
				k:Resume()
			end
		end
	end

	for k, v in pairs(self.queue) do
		self.queue[k] = nil
		if k:IsValid() then
			self.stopped[k] = v
			k:Pause()
		end
	end

	for k, v in pairs(self.requeue) do
		self.requeue[k] = nil
		self.queue[k] = v
	end
end

HitStopManager = HitStopManagerClass()
