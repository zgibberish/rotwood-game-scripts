local lume = require "util.lume"
require "class"

local BlurCoordinator = Class(function(self, inst)
	self.inst = inst
	self.current_params = self:BuildNoBlurParams()
	self.last_params = nil

	self:DisableBlur()
end)

--
-- Fade logic {{{1
--

function BlurCoordinator:FadeTo(ticks, params)
	self:FadeBetween(ticks, self.current_params, params)
end

function BlurCoordinator:FadeBetween(ticks, start_params, stop_params)
	self.curve = nil
	if not stop_params.modename
		and not start_params.modename
	then
		-- Skip fades between two None.
		self:SetBlurFromParams(stop_params)
		return
	end

	self.curve = stop_params and stop_params.curve

	self.last_params = self:_CopyAndValidate(start_params)
	self.dest_params = self:_CopyAndValidate(stop_params)
	if not stop_params.modename then
		self.dest_params.modename = self.last_params.modename
	end
	self.dest_params.radius = self.dest_params.radius or 1

	self.start_ticks = GetTick()
	self.stop_ticks = self.start_ticks + ticks
	self.inst:StartUpdatingComponent(self)
end

function BlurCoordinator:GetProgress()
	local progress = Remap(GetTick(), self.start_ticks, self.stop_ticks, 0, 1)
	if self.curve then
		progress = EvaluateCurve(self.curve, progress)
	end
	return progress
end
function BlurCoordinator:OnUpdate()
	local t = self:GetProgress()
	self:SetLerp(t, self.last_params, self.dest_params)
	if t >= 1 then
		self.inst:StopUpdatingComponent(self)
		self.start_ticks = nil
		self.stop_ticks = nil
	end
end

function BlurCoordinator:SetLerp(t, start_params, stop_params)
	self.current_params.modename = stop_params.modename
	self.current_params.strength = lume.lerp(start_params.strength, stop_params.strength, t)
	self.current_params.blend    = lume.lerp(start_params.blend, stop_params.blend, t)
	self.current_params.radius   = lume.lerp(start_params.radius, stop_params.radius, t)
	self:SetBlurFromParams(self.current_params)
end

function BlurCoordinator:GetDebugString()
	return table.inspect({
		params = self.current_params,
		start = self.start_ticks,
		stop = self.stop_ticks,
		progress = self.start_ticks and self:GetProgress() or nil,
		curve = not not self.curve,
	})
end




--
-- Blur logic {{{1
--

local BlurMode_ordered = {
	"None",
	"Gaussian",
	"Radial",
}

local BlurMode = lume.invert(BlurMode_ordered)

function BlurCoordinator:_SetBlur(modename, strength, blend, radius)
	local mode = BlurMode[modename]
	if blend == 1 then
		mode = nil
		modename = nil
	end
	if mode == BlurMode.Gaussian then
		self:SetGaussianBlur(strength, blend)
	elseif mode == BlurMode.Radial then
		self:SetRadialBlur(strength, blend, radius)
	else
		PostProcessor:DisableBlur()
	end
	self.current_params.modename = modename
	self.current_params.strength = strength
	self.current_params.blend = blend
	self.current_params.radius = radius
end

function BlurCoordinator:SetBlurFromParams(params)
	self:_SetBlur(
		params.modename,
		params.strength,
		params.blend,
		params.radius)
end

function BlurCoordinator:DisableBlur()
	-- Instead of calling DisableBlur directly, build params so current_params
	-- represents the current state.
	self:SetBlurFromParams(self:BuildNoBlurParams())
	assert(self.current_params.modename == nil, "Why do we still have a blur?")
end

-- strength in [0,1]
-- blend in [0,1]
-- radius in [0,0.7] because 1 would be past the edge of the screen
function BlurCoordinator:SetRadialBlur(strength, blend, radius)
	assert(radius)
	PostProcessor:EnableRadialBlur()
	PostProcessor:SetBlurBlend(1 - blend)
	PostProcessor:SetRadialBlurStrength(strength)
	PostProcessor:SetRadialBlurRadius(radius)
end

-- strength in [0,1]
-- blend in [0,1]
function BlurCoordinator:SetGaussianBlur(strength, blend)
	assert(blend)
	PostProcessor:EnableBlur()
	-- Gaussian blur can get pushed further, so give it double the range.
	PostProcessor:SetBlurStrength(strength * 2)
	PostProcessor:SetBlurBlend(1 - blend)
end

local defaults = {
	blend = 0.2,
	radius = 0.5,
	strength = 0.5,
	fade_ticks = 20,
}
local limits = {
	blend = 1,
	radius = 0.7,
	strength = 1,
	fade_ticks = 1000,
}

function BlurCoordinator:BuildNoBlurParams()
	local params = {
		modename = "Gaussian",
		strength = defaults.strength,
		blend = 1,
		radius = defaults.radius,
	}
	dbassert(BlurMode[params.modename])
	return params
end

function BlurCoordinator:_CopyAndValidate(params)
	if params.modename then
		params = deepcopy(params)
		for key,val in pairs(defaults) do
			params[key] = params[key] or val
		end
	else
		params = self:BuildNoBlurParams()
	end
	return params
end

function BlurCoordinator:_RenderSingleBlurUI(ui, id, params)
	local is_editing = false
	local mode = BlurMode[params.modename] or BlurMode.None
	mode = ui:_Combo("Blur mode".. id, mode, BlurMode_ordered)
	if mode == BlurMode.None then
		params.modename = nil
		mode = nil
	else
		params.modename = BlurMode_ordered[mode]
	end

	if mode then
		params.blend = ui:_SliderFloat("Scene blend".. id, params.blend or defaults.blend, 0, limits.blend, "%.2f")
		is_editing = is_editing or ui:IsItemActive()
		if ui:IsItemHovered() then
			ui:SetTooltip("How much of gameworld to see through blur.")
		end
		params.strength = ui:_SliderFloat("Strength".. id, params.strength or defaults.strength, 0, limits.strength, "%.2f")
		is_editing = is_editing or ui:IsItemActive()
		if mode == BlurMode.Radial then
			-- slider for the radius
			params.radius = ui:_SliderFloat("Radius".. id, params.radius or defaults.radius,	0, limits.radius, "%.3f")
			is_editing = is_editing or ui:IsItemActive()
			if ui:IsItemHovered() then
				ui:SetTooltip("Size of unblurred area. 0 = all blurred, 1 = entire screen is unblurred.")
			end
		end
	end

	--~ ui:Value("params".. id, table.inspect(params, { depth = 5, }))
	return is_editing
end

local fade_slider = 0

function BlurCoordinator:RenderFadeUI(ui, params)
	params.start = params.start or {}
	params.stop = params.stop or {}

	params.fade_ticks = ui:_SliderInt("Fade Duration Ticks", params.fade_ticks or defaults.fade_ticks, 0, limits.fade_ticks)

	ui:Text("Fade Start")
	self:_RenderSingleBlurUI(ui, "##start", params.start)
	ui:Text("Fade Stop")
	self:_RenderSingleBlurUI(ui, "##stop", params.stop)

	local changed
	changed, fade_slider = ui:SliderFloat("Preview", fade_slider, 0, 1)
	if changed then
		local start = self:_CopyAndValidate(params.start)
		local stop = self:_CopyAndValidate(params.stop)
		if not params.stop.modename then
			stop.modename = start.modename
		end
		self:SetLerp(fade_slider, start, stop)
	end

	if ui:Button("Test Fade") then
		self:FadeBetween(params.fade_ticks, params.start, params.stop)
	end
	ui:SameLineWithSpace()
	if ui:Button("Clear Blur") then
		self:SetBlurFromParams(self:BuildNoBlurParams())
	end
end

function BlurCoordinator:RenderBlurUI(ui, params)
	local is_editing = self:_RenderSingleBlurUI(ui, "##blur", params)

	if ui:Checkbox("Preview blur", self.preview_blur) then
		self.preview_blur = not self.preview_blur
		if not self.preview_blur then
			self:DisableBlur()
		end
	end
	if self.preview_blur then
		self:SetBlurFromParams(params)
	end

	return self.preview_blur and is_editing
end

function BlurCoordinator:DebugDrawEntity(ui, panel, colors)
	self.dbg_blur_params = self.dbg_blur_params or {}
	self.dbg_blur_params.show_fade = ui:_Checkbox("Fade", self.dbg_blur_params.show_fade)
	if self.dbg_blur_params.show_fade then
		self:RenderFadeUI(ui, self.dbg_blur_params)
	else
		self:RenderBlurUI(ui, self.dbg_blur_params)
	end
end


return BlurCoordinator
