require "mathutil"

local EntityOcclusion = Class(function(self, inst)
	self.inst = inst
	self.occludedTime = 0
	self.occlusiontags = {}
	self.occludedAreaThreshold = 0.8
	self.occlusionTimeThreshold = 0.6
	self.occlusionTestRange = 10
	self.occlusionEntTrim = 0.5
	self.updatePeriod = 0.1
	self.updateAccumulator = 0

	inst:StartWallUpdatingComponent(self)
end)

-- Entity occlusion detection based on entity AABB overlaps in screen space
function EntityOcclusion:_Evaluate(dt, testEnt)
	local minx, miny, minz, maxx, maxy, maxz = testEnt.entity:GetWorldAABB()
	-- trim lower extents of entity AABB (i.e. the lower torso of a player) from calculation
	miny = miny + (maxy - miny) * self.occlusionEntTrim

	local ps1 = { TheSim:WorldToScreenXY(minx, miny, minz) }
	local ps2 = { TheSim:WorldToScreenXY(maxx, maxy, maxz) }
	-- screen projection changes the AABB extents and coordinate space, so they need to be re-sorted
	local psMin = { math.min(ps1[1], ps2[1]), math.min(ps1[2], ps2[2]) }
	local psMax = { math.max(ps1[1], ps2[1]), math.max(ps1[2], ps2[2]) }
	local psArea = (psMax[1] - psMin[1]) * (psMax[2] - psMin[2])

	local px, pz = testEnt.Transform:GetWorldXZ()
	local ents = TheSim:FindEntitiesXZ(px, pz, self.occlusionTestRange, nil, nil, self.occludertags)
	local occluderCount = 0
	for i,ent in ipairs(ents) do
		local ex, ez = ent.Transform:GetWorldXZ()
		if ez < pz then
			minx, miny, minz, maxx, maxy, maxz = ent.entity:GetWorldAABB()
			local es1 = { TheSim:WorldToScreenXY(minx, miny, minz) }
			local es2 = { TheSim:WorldToScreenXY(maxx, maxy, maxz) }
			local esMin = { math.min(es1[1], es2[1]), math.min(es1[2], es2[2]) }
			local esMax = { math.max(es1[1], es2[1]), math.max(es1[2], es2[2]) }

			if psMin[1] <= esMax[1] and esMin[1] < psMax[1] and esMin[2] < psMax[2] and psMin[2] <= esMax[2] then
				local overlap = { IntersectRect(psMin[1], psMin[2], psMax[1], psMax[2], esMin[1], esMin[2], esMax[1], esMax[2]) }
				local overlapArea = (overlap[3] - overlap[1]) * (overlap[4] - overlap[2])

				-- Require a percentage of area coverage for a minimum time to trigger an occlusion "status"
				-- Once an ent/player is considered occluded, any area coverage will continue signaling occlusion
				-- This is done to reduce pulsing of UI which can be visually distracting
				if overlapArea >= self.occludedAreaThreshold * psArea then
					occluderCount = occluderCount + 1
					self.occludedTime = self.occludedTime and self.occludedTime + dt or 0.0

					if self.occludedTime >= self.occlusionTimeThreshold then
						testEnt:PushEvent("occluded", self.occludedTime)
					end
				else
					if self.occludedTime and self.occludedTime  >= self.occlusionTimeThreshold then
						occluderCount = occluderCount + 1
						self.occludedTime = self.occludedTime + dt
						testEnt:PushEvent("occluded", self.occludedTime)
					end
				end
			end
		end
	end

	if occluderCount == 0 then
		self.occludedTime = nil
	end
end

function EntityOcclusion:SetOccluderTags(tags)
	if type(tags) == "string" then
		self.occludertags = {tags}
	else
		self.occludertags = tags
	end
end

function EntityOcclusion:OnWallUpdate(dt)
	self.updateAccumulator = self.updateAccumulator + dt
	if self.updateAccumulator >= self.updatePeriod then
		self.updateAccumulator = self.updateAccumulator - self.updatePeriod
		if not self.inst:IsDead() then
			self:_Evaluate(self.updatePeriod, self.inst)
		end
	end
end

return EntityOcclusion
