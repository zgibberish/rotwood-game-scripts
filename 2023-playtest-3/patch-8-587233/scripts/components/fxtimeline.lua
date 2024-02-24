local Timeline = require("util/timeline")
local lume = require "util.lume"
require "mathutil"

-- Define the different timeline groups. Used by FxEditor to see what it can
-- edit. This also defines the values passed in above in `timelines`.
local group_def = {
	group_keys = {
		'shift',
		'multiply',
		'add',
	},
	element_keys = {
		shift = {
			'hue',
			'saturation',
			'brightness',
		},
		multiply = {
			'red',
			'green',
			'blue',
			'alpha',
		},
		add = {
			'red',
			'green',
			'blue',
		},
	},
	element_bounds = {
		shift = {
			default = {
				noop = 0.5,
				min = -100,
				max = 100,
			},
			hue = {
				noop = 0.5,
				min = -180,
				max = 180,
			},
		},
		multiply = {
			default = {
				noop = 1,
				min = 0,
				max = 1,
			},
		},
		add = {
			default = {
				noop = 0,
				min = 0,
				max = 1,
			},
		},
	},
	-- Duration is a percentage.
	duration = 100,
}
-- Groups are separate for organizational purposes, but merged into a single
-- timeline. Build the merged keys so we can access them without runtime string
-- building.
group_def.merged_keys = {}
for _,group in ipairs(group_def.group_keys) do
	for _,element in ipairs(group_def.element_keys[group]) do
		local key = ("%s_%s"):format(group, element)
		table.insert(group_def.merged_keys, key)
	end
end
function group_def.get_element_bounds(group_key, element_key)
	local bounds = group_def.element_bounds[group_key]
	bounds = bounds[element_key] or bounds.default
	assert(bounds, ("No bounds defined for %s.%s"):format(group_key, element_key))
	return bounds
end


local FxTimeline = Class(function(self, inst, timelines)
	self.inst = inst
	self._timeline_data = timelines
	self.timeline = Timeline(group_def.duration, group_def.merged_keys, self._timeline_data)
	if self.timeline:has_data() then
		inst:DoPeriodicTask(0, function(inst_)
			self:_Tick(0.1)
		end)
	end
end)

-- Export for editor to access.
FxTimeline.group_def = group_def

local appliers = {
}

function FxTimeline:_Tick()
	local time = self:_get_anim_progress()
	local values = {}
	--~ local msg = ("time: %04.2f"):format(time)
	local i = 1
	for _,group_key in ipairs(group_def.group_keys) do
		--~ msg = msg .. ("\t%s[ "):format(group_key)
		lume.clear(values)
		local has_data = false
		for _,element_key in ipairs(group_def.element_keys[group_key]) do
			--~ msg = msg .. ("%s "):format(element_key:sub(1,1))
			local bounds = group_def.get_element_bounds(group_key, element_key)
			local merged_key = group_def.merged_keys[i]
			local single = self.timeline:get(merged_key)
			local val = bounds.noop
			if single:has_data() then
				local t, event = single:get_progress_for_time(time)
				val = EvaluateCurve(event.curve, t)
				val = lume.lerp(bounds.min, bounds.max, val)
				has_data = true
			end
			table.insert(values, val)
			i = i + 1
		end
		if has_data then
			local fn = appliers[group_key]
			assert(fn, "Forgot to implement applier ".. group_key)
			fn(self, table.unpack(values))
		end
		--~ msg = msg .. (has_data and (lume.reduce(values, function(str, f) return ("%s% 02.1f\t"):format(str, f) end, "]: ")) or "]: skipped")
	end
	--~ print("FxTimeline", msg)
end

function FxTimeline:_get_anim_progress()
	local duration = group_def.duration
	return self.inst.AnimState:GetCurrentAnimationTime() / self.inst.AnimState:GetCurrentAnimationLength() * duration
end

function appliers:shift(hue, saturation, brightness)
	self.inst.AnimState:SetHue(hue / 360)
	self.inst.AnimState:SetSaturation((saturation + 100) / 100)
	self.inst.AnimState:SetBrightness((brightness + 100) / 100)
end

function appliers:multiply(r,g,b,a)
	self.inst.AnimState:SetMultColor(r,g,b,a)
end

function appliers:add(r,g,b,a)
	self.inst.AnimState:SetAddColor(r,g,b,a or 1)
end

return FxTimeline
