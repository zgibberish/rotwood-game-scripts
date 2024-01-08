-- Reference file to see what functions exist on components. 
-- It is not necessary to inherit from component or include this file when creating a component.

local Component = Class(function(self, inst)
	self.inst = inst
end)

function Component:OnLoad(data)
end

-- Return a serializable data table, i.e. no meta-table.
function Component:OnSave()
	return nil
end

function Component:OnRemoveFromEntity()
end

function Component:OnRemoveEntity()
end

function Component:GetDebugString()
end

function Component:OnNetSerialize()
end

function Component:OnNetDeserialize()
end

function Component:OnEntityBecameLocal()
end

function Component:OnEntityBecameRemote()
end

function Component:OnPostSpawn()
end

function Component:OnPostLoadWorld(save_data)
	-- save_data is a table of serializable data representing this component, with no metatable.
end

function Component:LongUpdate()
end

-- EntityScript:StartUpdatingComponent(cmp) must be invoked before this will get called.
function Component:OnUpdate(time_delta)
end

-- EntityScript:StartWallUpdatingComponent(cmp) must be invoked before this will get called.
function Component:OnWallUpdate(time_delta)
end

return Component