-- Reference file to see what functions exist on components. See also what's
-- called on components in EntityScript.

local Component = Class(function(self, inst)
	error "Do *NOT* inherit from component or include this file when creating a component."
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

-- Only implement OnNetSerialize if you must sync. Do not include empty implementations.
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

-- Don't return because we shouldn't actually use this file at runtime.
-- return Component
