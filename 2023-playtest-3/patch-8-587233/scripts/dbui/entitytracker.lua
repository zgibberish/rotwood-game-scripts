-- Debug entity tracking behaviour for tools that respond to every world entity.
--
-- For use as a mixin:
-- * must implement IsRelevantEntity.
-- * may implement OnTrackEntity, OnForgetEntity.
local EntityTracker = {}


function EntityTracker:InitTracker()
	if self.inst then
		dbassert(self.inst:IsValid())
		return
	end
	self.inst = CreateEntity("EntityTracker")
		:MakeSurviveRoomTravel()
		:TagAsDebugTool()

	self:ObtainEntityList()

	self._on_entity_spawned = self._on_entity_spawned or function(_, entity)
		if self:WillTrackEntity(entity) then
			self:_TrackEntity(entity)
		end
	end
	self.inst:ListenForEvent("entity_spawned", self._on_entity_spawned, TheGlobalInstance)
end

-- Stop tracking new entities. Doesn't clear historical data for existing
-- entities. Call InitTracker before capturing data to ensure we start
-- again.
function EntityTracker:ShutdownTracker()
	if self.inst then
		self.inst:Remove()
	end
	self.inst = nil
	self.ents_to_track = nil
end



-- Return true if the specified entity or any of its ancestors have the specified tag.
local function AncestorHasTag(inst, tag)
	while inst do
		if inst:HasTag(tag) then
			return true
		end
		inst = inst.entity:GetParent()
	end
	return false
end

local function CanTrackHistory(entity, required_native_components)
	return not entity:HasTag("entityproxy")
		and not AncestorHasTag(entity, "dbg_nohistory")
end

function EntityTracker:WillTrackEntity(entity)
	return CanTrackHistory(entity)
		and self:IsRelevantEntity(entity)
end

function EntityTracker:ObtainEntityList()
	self.ents_to_track = {}
	local proxies_to_spawn = {}

	for _, entity in pairs(Ents) do
		-- don't spawn entities inside an Ents loop
		if self:WillTrackEntity(entity) then
			table.insert(proxies_to_spawn, entity)
		end
	end

	for _, entity in ipairs(proxies_to_spawn) do
		self:_TrackEntity(entity)
	end
end

function EntityTracker:_TrackEntity(inst)
	self.ents_to_track[inst] = inst

	self._onremove = self._onremove or function(entity) self:_ForgetEntity(entity) end
	self.inst:ListenForEvent("onremove", self._onremove, inst)

	if self.OnTrackEntity then
		self:OnTrackEntity(inst)
	end
end

function EntityTracker:_ForgetEntity(inst)
	self.ents_to_track[inst] = nil
	if self.OnForgetEntity then
		self:OnForgetEntity(inst)
	end
end


function EntityTracker:GetTrackedEntities()
	-- Return empty when not initialized to simplify handling in main menu.
	return self.ents_to_track or table.empty
end

return EntityTracker
