-- A base component for stacks of values that are applied to a list of
-- children. Use this as a parent class and not directly on entities.
local ValueStacker = Class(function(self, inst)
	self.inst = inst
	self.valuestack = {}
	self.children = {}
	self.parent = nil

	self:_ApplyDefaultState(inst)

	self._onremovesource = function(source) self:_PopStack(source) end
	self._onremovechild = function(child) self.children[child] = nil end
end)

function ValueStacker:OnRemoveEntity()
	self:_SetParent(nil)

	for k in pairs(self.children) do
		self:DetachChild(k)
	end
end

function ValueStacker:OnRemoveFromEntity()
	self:OnRemoveEntity()

	for source in pairs(self.valuestack) do
		if EntityScript.is_instance(source) then
			self.inst:RemoveEventCallback("onremove", self._onremovesource, source)
		end
	end

	self:_ApplyDefaultState(self.inst)
end

function ValueStacker:AttachChild(child)
	if self.children[child] == nil then
		self.children[child] = true

		local comp = self:_GetSelfComponent(child)
		if comp ~= nil then
			comp:_SetParent(self.inst)
		else
			self.inst:ListenForEvent("onremove", self._onremovechild, child)
		end

		self:_UpdateStack()
	end
end

function ValueStacker:DetachChild(child)
	if self.children[child] ~= nil then
		self.children[child] = nil

		local comp = self:_GetSelfComponent(child)
		if comp ~= nil then
			comp:_SetParent(nil)
			comp:_UpdateStack()
		else
			self.inst:RemoveEventCallback("onremove", self._onremovechild, child)
			self:_ApplyDefaultState(child)
		end

		self:_UpdateStack()
	end
end

function ValueStacker:_SetParent(parent)
	local old = self.parent
	if parent ~= old then
		if old ~= nil then
			self.parent = nil
			local comp = self:_GetSelfComponent(old)
			comp:DetachChild(self.inst)
		end
		if parent ~= nil then
			self.parent = parent
			local comp = self:_GetSelfComponent(parent)
			comp:AttachChild(self.inst)
		end
	end
end

-- Pack _PushStack inputs into a table to store on the valuestack. Override in
-- child class to store custom tables on the valuestack (also override _CopyArgs).
function ValueStacker:_Pack(...)
	return { ... }
end

-- Copy PushStack args into t and return whether anything changed.
function ValueStacker:_CopyArgs(t, ...)
	local changed = false
	for i=1,select('#', ...) do
		local val = select(i, ...)
		changed = changed or t[i] ~= val
		t[i] = val
	end
	return changed
end

function ValueStacker:_PushStack(source, ...)
	local t = self.valuestack[source]
	if t == nil then
		self.valuestack[source] = self:_Pack(...)
		if EntityScript.is_instance(source) then
			self.inst:ListenForEvent("onremove", self._onremovesource, source)
		end
	elseif not self:_CopyArgs(t, ...) then
		return
	end
	self:_UpdateStack()
end

function ValueStacker:_PopStack(source)
	if self.valuestack[source] ~= nil then
		if EntityScript.is_instance(source) then
			self.inst:RemoveEventCallback("onremove", self._onremovesource, source)
		end
		self.valuestack[source] = nil

		self:_UpdateStack()
	end
end

function ValueStacker:_UpdateStack()
	if self.parent ~= nil then
		local comp = self:_GetSelfComponent(self.parent)
		comp:_UpdateStack()
	else
		if not self.activetask or self.activetask:IsDone() then
			self.activetask = nil
			if next(self.children) then 
				self.activetask = self.inst:DoTaskInTime(0, function()
					self.activetask = nil
					self:_ApplyStack()
				end)
			else
				self:_ApplyStack()
			end
		end
	end
end

local function unimplemented(fn)
	error("Forgot to implement: ".. fn)
end

-- Child classes should expose a function that calls _PushStack and _PopStack

-- They also need to implement these functions:

function ValueStacker:_GetSelfComponent(inst)
	unimplemented "_GetSelfComponent"
	-- Something like this:
	-- return inst.components.coloradder
end

function ValueStacker:_ApplyDefaultState(inst)
	unimplemented "_ApplyDefaultState"
	-- Apply the "zero" value to inst.
end

function ValueStacker:_ApplyStack()
	unimplemented "_ApplyStack"
	-- Aggregate valuestack and apply it to self and children.
end

return ValueStacker
