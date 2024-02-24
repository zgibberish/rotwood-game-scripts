local kassert = require "util.kassert"


-- Add mixin to your class and use to track an entity and automatically clear
-- it when they're removed:
--	 self.owner = self:ChangeTrackedEntity(new_trackedentity, "owner")
-- Useful for owner (SetOwner), target (SetTarget), etc.
local TrackEntity = {}


-- Called when the tracked entity is Removed.
--
-- Default just clears the target. Call this to customize that behaviour, but
-- ensure your implementation calls ChangeTrackedEntity to clear the
-- target!
function TrackEntity:SetOnRemoveTrackedEntityFn(onremovetrackedentity)
	assert(self._onremovetrackedentity == nil, "Calling SetOnRemoveTrackedEntityFn twice may result in failure to remove our event callback from old targets.")
	self._onremovetrackedentity = onremovetrackedentity
	return self
end

-- Update the tracked entity.
--
-- If you call like this:
--	 self.owning_mob = self:ChangeTrackedEntity(new_trackedentity, "owning_mob")
-- Make sure the owning_mob variable name matches the string argument!
function TrackEntity:ChangeTrackedEntity(new_tracked, tracked_key)
	kassert.typeof("string", tracked_key)
	assert(new_tracked == nil or EntityScript.is_instance(new_tracked))

	-- Default implementation makes TrackEntity as effortless as possible. For
	-- more than clearing the entity, call SetOnRemoveTrackedEntityFn.
	self._onremovetrackedentity = self._onremovetrackedentity or function()
		self:ChangeTrackedEntity(nil, tracked_key)
	end

	local old_tracked = self[tracked_key]
	if new_tracked ~= old_tracked then
		if old_tracked then
			self.inst:RemoveEventCallback("onremove", self._onremovetrackedentity, old_tracked)
		end

		self[tracked_key] = new_tracked

		if new_tracked then
			self.inst:ListenForEvent("onremove", self._onremovetrackedentity, new_tracked)
		end
	end
	return new_tracked
end

return TrackEntity
