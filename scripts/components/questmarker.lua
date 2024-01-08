local TYPE_TO_STRING =
{
	[QUEST_IMPORTANCE.s.HIGH] = "main",
	[QUEST_IMPORTANCE.s.DEFAULT] = "secondary",
	["BUSY"] = "busy",
}

local QuestMarker = Class(function(self, inst)
	self.inst = inst
	self.fx = nil
	self.importance = QUEST_IMPORTANCE.s.DEFAULT
	self.players = {}
end)

function QuestMarker:GetAnimString()
	return TYPE_TO_STRING[self.importance]
end

function QuestMarker:GetFX()
	return self.fx
end

function QuestMarker:SpawnMarkerFX()
	self.fx = SpawnPrefab("fx_quest_marker", self.inst)
	assert(self.fx)
	self.fx.AnimState:PlayAnimation("pre_"..self:GetAnimString())
	self.fx.AnimState:PushAnimation("loop_"..self:GetAnimString(), true)
	self.fx.entity:SetParent(self.inst.entity)
end

function QuestMarker:HideFX()
	self.hidden = true
	self.fx.AnimState:PlayAnimation("pst_"..self:GetAnimString())
end

function QuestMarker:ShowFX()
	self.hidden = false
	self.fx.AnimState:PlayAnimation("pre_"..self:GetAnimString())
	self.fx.AnimState:PushAnimation("loop_"..self:GetAnimString(), true)
end

function QuestMarker:DespawnMarkerFX(cb)
	if self.hidden then
		self.inst:Remove()
		if cb then
			cb()
		end
	else
		if self.fx then
			self.inst.despawning = true
			self.fx.AnimState:PlayAnimation("pst_"..self:GetAnimString())
			self.inst:ListenForEvent("animover", function()
				if cb then cb() end
				self.inst:Remove()
			end, self.fx)
		end
	end
end

function QuestMarker:SetBusy()
	self.importance = "BUSY"
	return self
end

function QuestMarker:EvaluateImportance()
	local highest = QUEST_IMPORTANCE.id.LOW

	for player, importance in pairs(self.players) do
		if QUEST_IMPORTANCE.id[importance] > highest then
			self.importance = importance
			highest = QUEST_IMPORTANCE.id[importance]
		end
	end
end

function QuestMarker:IsPlayerTracked(player)
	return self.players[player] ~= nil
end

function QuestMarker:GetNumTrackedPlayers()
	return table.count(self.players)
end

function QuestMarker:AddTrackedPlayer(player, importance)
	self.players[player] = importance
	self:Refresh()
end

function QuestMarker:RemoveTrackedPlayer(player)
	self.players[player] = nil
	self:Refresh()
end

function QuestMarker:Refresh()
	self:EvaluateImportance()

	if self.fx and not self.inst.despawning then
		self.fx.AnimState:PushAnimation("loop_"..self:GetAnimString(), true)
	end

	if not self.fx then
		self:SpawnMarkerFX()
	end
end

function QuestMarker:FollowNPC(npc_inst)
    self.inst.Follower:FollowSymbol(npc_inst.GUID, "head_follow")
    self.inst.Follower:SetOffset(0, -300, 0)

	self.follow_npc = npc_inst
    self.activate_fn = function() self:HideFX() end
    self.deactivate_fn = function() self:ShowFX() end

    self.inst:ListenForEvent("activate_convo_prompt", self.activate_fn, self.follow_npc)
    self.inst:ListenForEvent("deactivate_convo_prompt", self.deactivate_fn, self.follow_npc)
end

function QuestMarker:FollowInteractable(interactable_inst)

	local v_minx, v_miny, v_minz, v_maxx, v_maxy, v_maxz = interactable_inst.entity:GetWorldAABB()

	self.inst.entity:SetParent(interactable_inst.entity)
	self.inst.Transform:SetPosition(0, v_maxy + 1, 0)

    -- self.inst.Follower:FollowSymbol(interactable_inst.GUID, "cryst_pieces")

	self.follow_npc = interactable_inst
end

return QuestMarker
