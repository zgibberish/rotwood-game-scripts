local ValueStacker = require "components.valuestacker"
local color = require "math.modules.color"


local ColorMultiplier = Class(ValueStacker, function(self, inst)
	ValueStacker._ctor(self, inst)
end)

function ColorMultiplier:PushColor(source, r, g, b, a)
	if r == 1 and g == 1 and b == 1 and a == 1 then
		self:_PopStack(source)
		return
	end
	self:_PushStack(source, r, g, b, a)
end

function ColorMultiplier:PopColor(source)
	self:_PopStack(source)
end

function ColorMultiplier:_ApplyDefaultState(inst)
	if inst.AnimState ~= nil then
		inst.AnimState:SetMultColor(1, 1, 1, 1)
		self:_ResetMultHighlightColor()
	end
end

function ColorMultiplier:_GetSelfComponent(inst)
	return inst.components.colormultiplier
end

function ColorMultiplier:_ApplyStack()
	local r, g, b, a = self:CalculateColorInternal()
	r = math.clamp(r, 0, 1)
	g = math.clamp(g, 0, 1)
	b = math.clamp(b, 0, 1)
	a = math.clamp(a, 0, 1)

	self:ApplyColorInternal(r, g, b, a)
end

function ColorMultiplier:CalculateColorInternal()
	local r, g, b, a = 1, 1, 1, 1

	for _, v in pairs(self.valuestack) do
		r = r * v[1]
		g = g * v[2]
		b = b * v[3]
		a = a * v[4]
	end

	for k in pairs(self.children) do
		if k.components.colormultiplier ~= nil then
			local r1, g1, b1, a1 = k.components.colormultiplier:CalculateColorInternal()
			r = r * r1
			g = g * g1
			b = b * b1
			a = a * a1
		end
	end

	return r, g, b, a
end

function ColorMultiplier:ApplyColorInternal(r, g, b, a)
	local func = self.inst:IsLocalOrMinimal() and "SetMultColor" or "SetMultHighlightColor"


	if self.inst.AnimState ~= nil then
		AnimState[func](self.inst.AnimState, r, g, b, a)
	end

	for k in pairs(self.children) do
		if k.components.colormultiplier ~= nil then
			k.components.colormultiplier:ApplyColorInternal(r, g, b, a)
		elseif k.AnimState ~= nil then
			AnimState[func](self.inst.AnimState, r, g, b, a)
		end
	end
end


function ColorMultiplier:_ResetMultHighlightColor()
	if self.inst.AnimState ~= nil then
		self.inst.AnimState:SetMultHighlightColor() -- clears override
	end

	for k in pairs(self.children) do
		if k.AnimState ~= nil then
			k.AnimState:SetMultHighlightColor() -- clears override
		end
	end
end

function ColorMultiplier:OnEntityBecameLocal()
	self:ApplyColorInternal(1,1,1,1)	-- Reset any fading that might have happened
	self:_ResetMultHighlightColor()
end

function ColorMultiplier:OnEntityBecameRemote()
	self:_ResetMultHighlightColor()
end

local debug_color = color(WEBCOLORS.WHITE)
function ColorMultiplier:DebugDrawEntity(ui, panel, colors)
	local r, g, b, a = self:CalculateColorInternal()
	ui:ColorEdit4("Calculated Internal Color", r, g, b, a)
	r = math.clamp(r, 0, 1)
	g = math.clamp(g, 0, 1)
	b = math.clamp(b, 0, 1)
	a = math.clamp(a, 0, 1)
	ui:ColorEdit4("Current Applied Color", r, g, b, a)

	ui:TextColored(colors.header, "Push color onto stack")
	debug_color = ui:_ColorObjEdit("Color", debug_color)
	if ui:Button("Push Mult Color") then
		self:PushColor("DebugDrawEntity", debug_color:unpack())
	end
	ui:SameLineWithSpace()
	if ui:Button("Remove Color") then
		self:PopColor("DebugDrawEntity")
	end
end

return ColorMultiplier
