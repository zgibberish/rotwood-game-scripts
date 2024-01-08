local SGCommon = require "stategraphs.sg_common"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local LowHealthIndicator = Class(function(self, inst)
	self.inst = inst

	self.fx = nil
	self.flickering = nil

	self._onhealthchanged = function(_inst, is_low_health) self:OnLowHealthChanged(is_low_health) end
	self.inst:ListenForEvent("lowhealthstatechanged", self._onhealthchanged)
end)

local function size_to_anim(draw_size)
	if draw_size < 1.2 then
		return "small"
	elseif draw_size < 1.5 then
		return "medium"
	end
	return "large"
end

function LowHealthIndicator:SpawnLowHealthFx(anim)
	if self.inst:HasTag("player") and self.inst:IsLocal() and self.inst:GetTimeAlive() >= 1 then
		--parameter clamping math
		local health_percent = self.inst.components.health:GetPercent() -- current health %
		local normalized_lowHealthPercent
		if not self.inst.low_health_threshold_pct then
			local _, low_health_threshold_pct = self.inst.components.health:GetLowHealthThreshold() -- low health threshold (in %)
			self.inst.low_health_threshold_pct = low_health_threshold_pct
		end
		normalized_lowHealthPercent = health_percent / self.inst.low_health_threshold_pct -- normalized parameter

		--sound
		--note that this only plays for local players!
		local params = {}
		params.fmodevent = fmodtable.Event.Hit_player_lowHealth
		local handle = soundutil.PlayLocalSoundData(self.inst, params)
		soundutil.SetInstanceParameter(self.inst, handle, "normalized_lowHealthPercent", normalized_lowHealthPercent)
	end

	local fx = SpawnPrefab("fx_low_health_ring", self.inst)
	assert(fx)
	fx.AnimState:PlayAnimation("pre_"..anim)
	fx.AnimState:PushAnimation("loop_"..anim, true)
	fx.entity:SetParent(self.inst.entity)
	return fx
end

local flicker_piecewise_data =
{
	--2 anim frames of each colour.
	0,
	0,
	
	0.25,
	0.25,
	
	.5,
	.5,
	
	.75,
	.75,
	
	1,
	1,

	1,
	1,

	.75,
	.75,
	
	.5,
	.5,
	
	.25,
	.25,
	
	0,
	0,
}
function DoPulse(inst, i, numticks)
	local numticks = 40
	local color = {30/255, 0/255, 0/255} --TODO: make tuning value

	if inst:IsValid() then
		if i < numticks then
			local r, g, b = table.unpack(color)
			local iterator = i % 20
			local intensity = flicker_piecewise_data[iterator+1] --PiecewiseFn(iterator, flicker_piecewise_data)
			inst.components.coloradder:PushColor("LowHealthPulse", (r)*intensity, (g)*intensity, (b)*intensity, (1)*intensity)

			inst:DoTaskInAnimFrames(1, function() --
				DoPulse(inst, i + 1, numticks)
			end)
		else
			inst.components.coloradder:PopColor("LowHealthPulse")
		end
	end
end

function LowHealthIndicator:OnLowHealthChanged(is_low_health)
	local coloradder = self.inst.components.coloradder
	if coloradder == nil then
		self.inst:AddComponent("coloradder")
	end
	if is_low_health then
		if self.fx == nil then
			local draw_size = self.inst.Physics:GetSize()
			self.fx = self:SpawnLowHealthFx(size_to_anim(draw_size))
		end
		if self.flickering == nil then
			DoPulse(self.inst, 0, 20)
			self.flickering = self.inst:DoPeriodicTicksTask(20 * ANIM_FRAMES, function(inst)
				DoPulse(self.inst, 0, 20)
			end)
		end
	else
		if self.fx ~= nil then
			self.fx:Remove()
			self.fx = nil
		end

		if self.flickering ~= nil then
			self.flickering:Cancel()
			self.flickering = nil
		end
	end
end

return LowHealthIndicator
