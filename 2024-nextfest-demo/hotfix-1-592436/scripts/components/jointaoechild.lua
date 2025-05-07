-- When this spawns, it checks if it is near any other joint AoEs of the same type.
-- If it is, it joins that joint AoE
-- If it isn't, it creates a JointAoEParent that will manage the AoE until it disappears.

local lume = require "util.lume"
local JointAoEParentPrefab = "jointaoeparent"

local JointAoEChild = Class(function(self, inst)
	self.inst = inst
	self.parent = nil
	self.aoe_data = nil
	self.did_init = false

	self.inst:AddTag("jointaoechild")
end)

function JointAoEChild:Setup( data )
-- hitgroup, hitflags, repeat_target_delay, search_tags
	self.aoe_data = data
	self.did_init = true
end

function JointAoEChild:OnSpawn()
	assert(self.did_init, "Tried to call OnSpawn in JointAoEChild without first calling Setup!")

	local x,z = self.inst.Transform:GetWorldXZ()

	-- capture any other aoes that the player couldn't walk between
	local search_radius = ((self.aoe_data.hitbox_size * 2.5) * self.inst.Transform:GetScale()) + TUNING.PLAYER_HITBOX_SIZE

	local nearby_aoes = TheSim:FindEntitiesXZ(x, z, search_radius, nil, nil, { "jointaoechild" })
	lume.removeall(nearby_aoes, function(aoe) return aoe.prefab ~= self.inst.prefab end)
	lume.remove(nearby_aoes, self.inst)

	-- local DebugDraw = require "util.debugdraw"
	-- DebugDraw.GroundCircle(x,z, search_radius, UICOLORS.RED, 1, 5)

	if #nearby_aoes == 0 then
		self:CreateParent()
	else
		local possible_parents = {}

		for i, aoe in ipairs(nearby_aoes) do
			local parent = aoe.components.jointaoechild:GetParent()
			if not lume.find(possible_parents, parent) then
				table.insert(possible_parents, parent)
			end
		end

		if #possible_parents > 1 then
			table.sort(possible_parents, function(a, b) return a:GetTimeAlive() > b:GetTimeAlive() end)
		end

		local best_parent = possible_parents[1]
		for i = #possible_parents, 2, -1 do
			-- merge parents if you find multiple possible parents
			local parent = possible_parents[i]
			best_parent.components.jointaoeparent:MergeParents(parent)
		end

		if best_parent then
			self:JoinParent(best_parent)
		end
	end
end

function JointAoEChild:PushHitBox()
	if self:GetParent() == nil then return end

	self:GetParent().components.jointaoeparent:PushAoEHitboxFromChild(self.inst)
end

function JointAoEChild:CreateParent()
	-- printf("~~~Couldn't Find Parent! Creating.")
	-- needs to pass in repeat target delay
	local parent = SpawnPrefab(JointAoEParentPrefab)
	parent.components.jointaoeparent:Setup(self.aoe_data)
	self:JoinParent(parent)
end

function JointAoEChild:JoinParent(parent)
	if self.parent then
		self.parent.components.jointaoeparent:RemoveChild(self.inst)
	end

	self.parent = parent
	self.parent.components.jointaoeparent:AddChild(self.inst)
end

function JointAoEChild:GetParent()
	return self.parent
end

return JointAoEChild