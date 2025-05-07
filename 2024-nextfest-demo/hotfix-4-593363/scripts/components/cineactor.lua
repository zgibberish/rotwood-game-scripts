local kassert = require "util.kassert"
local kstring = require "util.kstring"
local lume = require "util.lume"
require "class"

local CineActor = Class(function(self, inst)
	self.inst = inst
	self.onevent = {}

	self._oncine_end = function(source, cine_prefab) self:_OnCineEnd(cine_prefab) end
	self.inst:ListenForEvent("cine_end", self._oncine_end)
	self._oncreated_by_debugspawn = function(source) self:RemoveAllEvents() end
	self.inst:ListenForEvent("created_by_debugspawn", self._oncreated_by_debugspawn)
end)

function CineActor:RemoveAllEvents()
	for event_name,ev in pairs(self.onevent) do
		self.inst:RemoveEventCallback(event_name, ev)
	end
	lume.clear(self.onevent)
	if self.intro_handle then
		self.intro_handle:Cancel()
		self.intro_handle = nil
	end
end

function CineActor:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("cine_end", self._oncine_end)
	self:RemoveAllEvents()
end
CineActor.OnRemoveEntity = CineActor.OnRemoveFromEntity


function CineActor:CanPlayerStartCine()
	if not TheNet:IsHost() then
		return false
	end

	-- Only the initial local host player can start a cine.
	for _, player in ipairs(AllPlayers) do
		if player:IsLocal() and player.components.cineactor:IsInCine() then
			return false
		end
	end

	return true
end

function CineActor:IsInCine()
	return self.current_cine ~= nil
end

-- Play an intro immediately after spawn.
function CineActor:QueueIntro(cine_prefab, cine_queue)
	self.intro_handle = self.inst:DoTaskInTime(0, function(inst_)
		self:PlayAsLeadActor(cine_prefab, cine_queue)
		self.intro_handle = nil
	end)
end

function CineActor:PlayAsLeadActor(cine_prefab, cine_queue, is_test)
	if not self.inst:IsLocal() then
		return
	end

	if self.forward_role then
		self.forward_role.components.cineactor:PlayAsLeadActor(cine_prefab, cine_queue)
		return
	end
	if self:IsInCine() then
		TheLog.ch.Cine:printf("'%s' is already acting in '%s', but received request for '%s'.", self.inst, self.current_cine, cine_prefab)
		assert(self.current_cine == cine_prefab, "Shouldn't change cines partway!")
		return
	end
	self._onanimover = nil
	self.current_cine = cine_prefab
	self.cine_queue = cine_queue
	assert(self.inst.sg, "Must have a stategraph to be a cine actor.")

	-- temporarily disabled this assert, as it's breaking the game right now. Powers/Relics crystals are not networked entities.
		--assert(self.inst:IsNetworked(), "Must be a networked entity to be a cine actor.")
	if not self.inst:IsNetworked() then
		print("WARNING: " .. self.inst.prefab .. "should be a networked entity to be a cine actor")
	end

	self.cine_entity = SpawnPrefab(cine_prefab, self.inst)
	if self.cine_entity then
		self.cine_entity:SetupCinematic(self.inst, is_test)
	end

	return self.cine_entity
end

function CineActor:AfterEvent_PlayAsLeadActor(event_name, cine_prefab, cine_queue)
	kassert.typeof("string", event_name, cine_prefab)
	assert(kstring.startswith(cine_prefab, "cine_"), cine_prefab) -- wrong order?
	assert(self.inst.sg, "Must have a stategraph to be a cine actor.")
	assert(self.onevent[event_name] == nil, "Already playing a cinematic on this event.")

	local ev = function(source)
		-- Auto skip if skippable. We'll get an error if it's not skippable,
		-- but if it is then we probably want to allow it.
		if self.cine_entity
			and self.cine_entity.is_skippable
		then
			TheLog.ch.Cine:printf("Received event '%s' while in '%s'. Skipping to play '%s'.", event_name, self.current_cine, cine_prefab)
			self.cine_entity:SkipCinematic()
		end
		self:PlayAsLeadActor(cine_prefab, cine_queue)
	end
	self.inst:ListenForEvent(event_name, ev)
	self.onevent[event_name] = ev
end

function CineActor:ForwardRolesTo(destination)
	assert(not destination or destination.components.cineactor, "Can only forward to cineactor entities.")
	assert(destination ~= self.inst)
	self.forward_role = destination
end

function CineActor:_OnCineEnd(cine_prefab)
	assert(not self.inst:IsLocal() or not self.current_cine or self.current_cine == cine_prefab, "Shouldn't change cines partway!")
	self.current_cine = nil
	self.cine_entity = nil

	-- Play queued cinematics
	if self.cine_queue and #self.cine_queue > 0 then
		local next_cine = self.cine_queue[1]
		table.remove(self.cine_queue, 1)
		self:PlayAsLeadActor(next_cine, self.cine_queue)
		self.inst.sg.statemem.has_queued_cine = true
	end
end

function CineActor:ExitCineOnAnimOver()
	TheLog.ch.Cine:printf("Actor '%s' in '%s' queuing cine exit.", self.inst.prefab, self.current_cine)
	if self._onanimover then
		return
	end
	self._onanimover = function(source)
		self.inst:RemoveEventCallback("animover", self._onanimover)
		self._onanimover = nil
		self.inst:TryExitCineState()
	end
	self.inst:ListenForEvent("animover", self._onanimover)
end

function CineActor:IsWaitingForAnimComplete()
	return not not self._onanimover
end

return CineActor
