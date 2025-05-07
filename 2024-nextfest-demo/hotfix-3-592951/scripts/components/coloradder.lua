local ValueStacker = require "components.valuestacker"
local color = require "math.modules.color"


local ColorAdder = Class(ValueStacker, function(self, inst)
	ValueStacker._ctor(self, inst)
end)

function ColorAdder:PushColor(source, r, g, b, a)
	if r == 0 and g == 0 and b == 0 and a == 0 then
		self:_PopStack(source)
		return
	end
	self:_PushStack(source, r, g, b, a)
end

function ColorAdder:PopColor(source)
	self:_PopStack(source)
end

function ColorAdder:_ApplyDefaultState(inst)
	if inst.AnimState ~= nil then
		inst.AnimState:SetAddColor(0, 0, 0, 0)
		self:_ResetHighlightColor()
	end
end

function ColorAdder:_GetSelfComponent(inst)
	return inst.components.coloradder
end

function ColorAdder:_ApplyStack()
	local r, g, b, a = self:CalculateColorInternal()
	r = math.clamp(r, 0, 1)
	g = math.clamp(g, 0, 1)
	b = math.clamp(b, 0, 1)
	a = math.clamp(a, 0, 1)

	self:ApplyColorInternal(r, g, b, a)
end

function ColorAdder:CalculateColorInternal()
	local r, g, b, a = 0, 0, 0, 0

	for _, v in pairs(self.valuestack) do
		r = r + v[1]
		g = g + v[2]
		b = b + v[3]
		a = a + v[4]
	end

	for k in pairs(self.children) do
		if k.components.coloradder ~= nil then
			local r1, g1, b1, a1 = k.components.coloradder:CalculateColorInternal()
			r = r + r1
			g = g + g1
			b = b + b1
			a = a + a1
		end
	end

	return r, g, b, a
end

function ColorAdder:ApplyColorInternal(r, g, b, a)
	-- repurpose animstate highlight color for local, unsynced use
	-- this will conflict with the prophighlight component, but that is currently only used for building placement
	-- may want to separate these out into "channels" if there is more use like this
	local func = self.inst:IsLocalOrMinimal() and "SetAddColor" or "SetHighlightColor"

	local animstate = self.inst.AnimState
	if animstate ~= nil then
		animstate[func](animstate, r, g, b, a)
	end

	for k in pairs(self.children) do
		if k.components.coloradder ~= nil then
			k.components.coloradder:ApplyColorInternal(r, g, b, a)
		elseif k.AnimState ~= nil then
			k.AnimState[func](k.AnimState, r, g, b, a)
		end
	end
end

function ColorAdder:_ResetHighlightColor()
	if self.inst.AnimState ~= nil then
		self.inst.AnimState:SetHighlightColor() -- clears override
	end

	for k in pairs(self.children) do
		if k.AnimState ~= nil then
			k.AnimState:SetHighlightColor() -- clears override
		end
	end
end

function ColorAdder:OnEntityBecameLocal()
	self:_ResetHighlightColor()
end

function ColorAdder:OnEntityBecameRemote()
	self:_ResetHighlightColor()
end

local debug_color = color(WEBCOLORS.TRANSPARENT_BLACK)
function ColorAdder:DebugDrawEntity(ui, panel, colors)
	local r, g, b, a = self:CalculateColorInternal()
	ui:ColorEdit4("Calculated Internal Color", r, g, b, a)
	r = math.clamp(r, 0, 1)
	g = math.clamp(g, 0, 1)
	b = math.clamp(b, 0, 1)
	a = math.clamp(a, 0, 1)
	ui:ColorEdit4("Current Applied Color", r, g, b, a)

	ui:TextColored(colors.header, "Push color onto stack")
	debug_color = ui:_ColorObjEdit("Color", debug_color)
	if ui:Button("Push Add Color") then
		self:PushColor("DebugDrawEntity", debug_color:unpack())
	end
	ui:SameLineWithSpace()
	if ui:Button("Remove Color") then
		self:PopColor("DebugDrawEntity")
	end
end

return ColorAdder
