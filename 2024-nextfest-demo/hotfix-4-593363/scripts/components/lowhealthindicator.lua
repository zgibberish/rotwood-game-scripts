local SGCommon = require "stategraphs.sg_common"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local LowHealthIndicator = Class(function(self, inst)
	self.inst = inst

	self.fx = nil
	self.flickering = nil

	self._onhealthchanged = function(_inst, is_low_health) self:OnLowHealthChanged(is_low_health) end
	self.inst:ListenForEvent("lowhealthstatechanged", self._onhealthchanged)

	self._onscale_changed = function(source, new_scale) self:_RescaleFx(new_scale) end
	self.inst:ListenForEvent("scale_changed", self._onscale_changed)
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

function LowHealthIndicator:_RescaleFx(new_scale)
	if self.fx then
		-- Invert the scale so we're unaffected by parent scale. Ensures
		-- indicator is always visible and not *too* visible.
		local s = 1 / new_scale
		self.fx.Transform:SetScale(s, s, s)
	end
end

local flicker_piecewise_data =
{
	0,
	0.02,
	0.05,
	0.11,
	0.18,
	0.27,
	0.36,
	0.46,
	0.56,
	0.66,
	0.75,
	0.83,
	0.9,
	0.95,
	0.99,
	1,
	0.99,
	0.98,
	0.95,
	0.91,
	0.87,
	0.82,
	0.77,
	0.71,
	0.65,
	0.59,
	0.52,
	0.46,
	0.39,
	0.33,
	0.27,
	0.21,
	0.16,
	0.11,
	0.07,
	0.03,
	0.01,
}
function DoPulse(inst, i, numticks)
	numticks = numticks or 40
	local color = {80/255, 0/255, 0/255} --TODO: make tuning value

	if inst:IsValid() then
		if i < numticks then
			local r, g, b = table.unpack(color)
			local iterator = i % #flicker_piecewise_data
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
			self:_RescaleFx(self.inst.Transform:GetScale())
		end
		if self.flickering == nil then
			DoPulse(self.inst, 0, #flicker_piecewise_data)
			self.flickering = self.inst:DoPeriodicTicksTask(#flicker_piecewise_data * ANIM_FRAMES, function(inst)
				DoPulse(self.inst, 0, #flicker_piecewise_data)
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
