local ValueStacker = require "components.valuestacker"
local color = require "math.modules.color"
local kassert = require "util.kassert"
require "mathutil"


local Bloomer = Class(ValueStacker, function(self, inst)
	ValueStacker._ctor(self, inst)
end)

function Bloomer:_Pack(r, g, b, a)
	-- Store a named table so we can use r=nil for alpha-only bloom.
	return { r = r, g = g, b = b, a = a }
end

function Bloomer:_CopyArgs(bloom, r, g, b, a)
	local changed = r ~= bloom.r or g ~= bloom.g or b ~= bloom.b or a ~= bloom.a
	bloom.r, bloom.g, bloom.b, bloom.a = r, g, b, a
	return changed
end

function Bloomer:PushBloom(source, r, g, b, a)
	if a == nil then
		-- Only apply alpha bloom. We use r=nil as an indicator that it's an alpha bloom.
		a = r
		r = nil
	end
	if a <= 0 or (r == 0 and g == 0 and b == 0) then
		self:PopBloom(source)
		return
	end
	self:_PushStack(source, r, g, b, a)
end

-- Fade alpha over the duration seconds.
-- curve: a function from ease.lua or curve from curve_autogen_data.
function Bloomer:PushFadingBloom(curve, duration, source, r, g, b, a)
	assert(a, "PushFadingBloom requires rgba. Set rgb=0 if you want no glow colour.")
	if self.fade_task then
		self.fade_task:Cancel()
	end
	local fn = curve
	if type(fn) ~= "function" then
		fn = function(p)
			return EvaluateCurve(curve, p)
		end
	end
	local total_ticks = duration * SECONDS
	local elapsed_ticks = 0
	self.fade_task = self.inst:DoPeriodicTicksTask(0, function(inst_)
		local t = elapsed_ticks / total_ticks
		local v = fn(t)
		self:PushBloom(source, r, g, b, a * v)
		elapsed_ticks = elapsed_ticks + 1
		if t > 1 then
			self.fade_task:Cancel()
		end
	end)
end

function Bloomer:PopBloom(source)
	self:_PopStack(source)
end

-- Set symbol/layer targets and we'll bloom those instead of the root. Assuming
-- that it doesn't make sense to bloom both.
function Bloomer:ChangeTarget(targets)
	assert(not targets
		or targets.symbols
		or targets.layers,
		"You must specify a targets!")
	kassert.assert_fmt(#self.valuestack == 0, "Warning: Changing targets on '%s' while stack had %i entries.", self.inst, #self.valuestack)

	self.targets = targets
end

function Bloomer:_ApplyDefaultState(inst)
	if inst.AnimState ~= nil then
		inst.AnimState:SetBloom(0)
	end
end

function Bloomer:_GetSelfComponent(inst)
	return inst.components.bloomer
end

function Bloomer:_ApplyStack()
	local r, g, b, a, maxa = self:CalculateBloomInternal()
	local intensity = math.min(1, maxa)
	if a > 0 then
		r = math.clamp(r / a, 0, 1)
		g = math.clamp(g / a, 0, 1)
		b = math.clamp(b / a, 0, 1)
		self:ApplyBloomInternal(self.targets, r, g, b, intensity)
	else
		self:ApplyBloomInternal(self.targets, intensity)
	end
end

function Bloomer:CalculateBloomInternal()
	local r, g, b, a, maxa = 0, 0, 0, 0, 0

	for _, v in pairs(self.valuestack) do
		if v.r ~= nil then
			r = r + v.r * v.a
			g = g + v.g * v.a
			b = b + v.b * v.a
			a = a + v.a
		end
		maxa = math.max(maxa, v.a)
	end

	for k in pairs(self.children) do
		if k.components.bloomer ~= nil then
			local r1, g1, b1, a1, maxa1 = k.components.bloomer:CalculateBloomInternal()
			r = r + r1
			g = g + g1
			b = b + b1
			a = a + a1
			maxa = math.max(maxa, maxa1)
		end
	end

	return r, g, b, a, maxa
end

function Bloomer:SetBloomOnEnt(inst, targets, ...)
	if inst.AnimState == nil then
		return
	end

	if targets then
		if targets.symbols ~= nil then
			for symbol in pairs(targets.symbols) do
				inst.AnimState:SetSymbolBloom(symbol, ...)
			end
		end
		if targets.layers ~= nil then
			for layer in pairs(targets.layers) do
				inst.AnimState:SetLayerBloom(layer, ...)
			end
		end
	else
		inst.AnimState:SetBloom(...)
	end
end

function Bloomer:ApplyBloomInternal(targets, r, g, b, a)
	-- Note: r is the alpha if the other values are nil.

	self:SetBloomOnEnt(self.inst, targets, r, g, b, a)

	for k in pairs(self.children) do
		if k.components.bloomer ~= nil then
			k.components.bloomer:ApplyBloomInternal(targets, r, g, b, a)
		elseif k.AnimState ~= nil then
			self:SetBloomOnEnt(k, targets, r, g, b, a)
		end
	end
end

local debug_color = color(WEBCOLORS.WHITE)
local debug_target_name
local debug_target_type
function Bloomer:DebugDrawEntity(ui, panel, colors)
	local r, g, b, a, maxa = self:CalculateBloomInternal()
	ui:ColorEdit4("Calculated Internal Bloom", r, g, b, a)
	ui:SliderFloat("maxa", maxa, 0, 2)
	local intensity = math.min(1, maxa)
	r = math.clamp(r / a, 0, 1)
	g = math.clamp(g / a, 0, 1)
	b = math.clamp(b / a, 0, 1)
	ui:ColorEdit4("Current Applied Bloom", r, g, b, intensity)

	ui:TextColored(colors.header, "Push bloom onto stack")
	debug_color = ui:_ColorObjEdit("Bloom", debug_color)
	if ui:Button("Add Bloom") then
		self:PushBloom("DebugDrawEntity", debug_color:unpack())
	end
	ui:SameLineWithSpace()
	if ui:Button("Remove Bloom") then
		self:PopBloom("DebugDrawEntity")
	end

	-- Not sure why this doesn't seem to work.
	--~ ui:Value("Targets", table.inspect(self.targets))
	--~ debug_target_type = ui:_ComboAsString("##Target Type", debug_target_type, { "Layer", "Symbol", })
	--~ local changed, newtarget = ui:InputTextWithHint("Target", "Press Enter to apply", debug_target_name, ui.InputTextFlags.EnterReturnsTrue)
	--~ if changed then
	--~ 	debug_target_name = newtarget
	--~ 	local targets = {}
	--~ 	if newtarget:len() == 0 then
	--~ 		targets = nil
	--~ 	elseif debug_target_type == "Layer" then
	--~ 		targets.layers = { debug_target_name }
	--~ 	else
	--~ 		targets.symbols = { debug_target_name }
	--~ 	end
	--~ 	self:ChangeTarget(targets)
	--~ end
end

return Bloomer
