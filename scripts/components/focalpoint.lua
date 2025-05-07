local easing = require "util.easing"
local iterator = require "util.iterator"
local lume = require "util.lume"
local mapgen = require "defs.mapgen"
local strict = require "util.strict"


local FOCUS_PRESET_DOC <const> = [[Use FocusPresets to tune the StartFocusSource behaviour.
We'll only apply focus pull from a single focus source at a time.
Tuning values:
* priority: Controls which focus source to use. The highest priority wins. Equal priorities use distance.
* weight: The strength of the focus pull. weight of 1 will focus on the source instead of players.
* minrange: Determines how far you must be from the source to pull any focus towards it.
* maxrange: Ramps down how much focus we pull towards the source. At minrange, we pull weight and at maxrange we pull 0. Halfway between, we pull weight/2.
]]
FocusPreset = strict.readonly({
	BOSS = {
		minrange = 10,
		maxrange = 60,
		weight = .5,
		priority = 100
	},
	CONVO = {
		minrange = 10,
		maxrange = 60,
		weight = .5,
		priority = 100
	},
}, "FocusPreset")

local FocalPoint = Class(function(self, inst)
	self.inst = inst
	self.focuses = {}
	self.current_source = nil
	self.explicit_targets = nil

	self._onremovesource = function(source) self:StopFocusSource(source) end

	-- entity edge detection state
	self.edgeDetectEnabled = true
	self.edgeDetectTrackedEntities = {}
	self.edgeDetectCameraZoomDelta = 0
	self.edgeDetectCooldown = 0.0

	-- entity edge detection tuning values
	self.edgeDetectCameraDistanceMax = 54 -- min is default_camera_distance
	self.edgeDetectCameraSafeZone = {default = 0.03, player = 0.1}
	self.edgeDetectCameraSafeZoneBuffer = {default = 0.01, player = 0.05}
	self.edgeDetectCameraDistanceDelta = 1
	self.edgeDetectCameraDistanceTimeout = 0.1

	self.edgeDetectCandidates = {}
	self.edgeDetectCandidateEaseInTime = 3
	self.edgeDetectCandidateWeight = 0
	self.edgeDetectTrackedProxies = {}

	self.newCameraMinSpeed = 16 -- Using NW's new system

	self.distSpeedFactor = 1.5 --DEPRECATED
	self.minSpeed = 4 --DEPRECATED
	inst:StartUpdatingComponent(self)
end)

-- Adds a possible alternate focal target. We'll focus the players and *one* of
-- these focus sources.
--
-- @param source EntityScript An entity.
-- @param focus_tuning table Pass a FocusPreset or a table that looks like one.
function FocalPoint:StartFocusSource(source, focus_tuning)
	local focus = self.focuses[source]

	self.focuses[source] = focus_tuning
	if focus == nil then
		self.inst:ListenForEvent("onremove", self._onremovesource, source)

	elseif deepcompare(focus, focus_tuning) then
		-- No change, so skip update.
		return
	end

	self:OnUpdate(0)
end

function FocalPoint:StopFocusSource(source)
	local focus = self.focuses[source]
	if focus ~= nil then
		self.inst:RemoveEventCallback("onremove", self._onremovesource, source)
		self.focuses[source] = nil

		if self.current_source == source then
			self.current_source = nil
			self:OnUpdate(0)
		end
	end
end

function FocalPoint:ClearFocusSources()
	for source,focus in pairs(self.focuses) do
		self:StopFocusSource(source)
	end
	assert(next(self.focuses) == nil)
end

-- Targets to focus on instead of the player. Can add multiple.
function FocalPoint:AddExplicitTarget(target)
	assert(target ~= nil)
	self.explicit_targets = self.explicit_targets or {}
	self.explicit_targets[target] = true
	return self
end

function FocalPoint:HasExplicitTarget(target)
	return self.explicit_targets and self.explicit_targets[target]
end

function FocalPoint:ClearExplicitTargets()
	self.explicit_targets = nil
end

local to_remove = {}
function FocalPoint:ValidateExplicitTargets()
	if not self.explicit_targets then
		return
	end

	for ent,_ in pairs(self.explicit_targets) do
		if not ent:IsValid() then
			TheLog.ch.FocalPoint:printf("ValidateExplicitTargets: Entity %s GUID %d is no longer valid.", ent.prefab, ent.GUID)
			table.insert(to_remove, ent)
		end
	end
	if #to_remove > 0 then
		for _i,ent in ipairs(to_remove) do
			self.explicit_targets[ent] = nil
		end
		lume.clear(to_remove)
		if lume.count(self.explicit_targets) == 0 then
			self:ClearExplicitTargets()
		end
	end
end

function FocalPoint:GetDefaultCameraDistance()
	return self.default_camera_distance
end

function FocalPoint:SetDefaultCameraDistance(dist)
	self.default_camera_distance = dist
	self:_SetDesiredDistance(dist)
end

function FocalPoint:_SetDesiredDistance(dist)
	self.inst.desired_camera_distance = dist
end

function FocalPoint:_DebugDrawEntityEdgeDetection(sx_left, sx_right, sy_up, sy_down)
	local ui = require "dbui.imgui"
	local screensize = { TheSim:GetScreenSize() } -- rt size, not imgui size
	local function ScreenXYNormalizedToScaled(pn, screenscale)
		return (0.5 + pn[1] * 0.5) * screenscale[1], (0.5 - pn[2] * 0.5) * screenscale[2]
	end

	local sx_left_s = { ScreenXYNormalizedToScaled(sx_left, screensize) }
	local sx_right_s = { ScreenXYNormalizedToScaled(sx_right, screensize) }
	local sy_up_s = { ScreenXYNormalizedToScaled(sy_up, screensize) }
	local sy_down_s = { ScreenXYNormalizedToScaled(sy_down, screensize) }

	-- TODO: victorc - this isn't visually accurate for non-16:9 aspect ratios due to letterboxing
	ui:ScreenLine(sx_left_s, sx_right_s)
	ui:ScreenLine(sy_up_s, sy_down_s)
end

function FocalPoint:_UpdateEntityEdgeDetection(dt, candidate, x, y, z, halfWidth, halfHeight)
	if not self.edgeDetectEnabled or self.inst:GetTimeAlive() < 0.5 then
		return
	elseif self:HasExplicitTarget(candidate) then
		return -- ignore explicit targets; they are meant to be in view
	end

	if self.edgeDetectCooldown == 0 then
		-- At screen extents:
		-- Players will cause the camera to pull back to try and encapsulate them
		-- Tracked entities will display an offscreen indicator
		local is_player = candidate:HasTag("player")
		local profile = is_player and "player" or "default"

		-- for players, detect nearest edge to screen
		-- for others, detect when fully off the screen
		-- use the center point as an extra test when the camera pulls in very close and the dominant bounds are off-screen
		local sx_left = is_player and { TheSim:WorldToScreenXYNormalized(x - halfWidth, y, z) } or { TheSim:WorldToScreenXYNormalized(x + halfWidth, y, z) }
		local sx_right = is_player and { TheSim:WorldToScreenXYNormalized(x + halfWidth, y, z) } or { TheSim:WorldToScreenXYNormalized(x - halfWidth, y, z) }
		local sy_down = is_player and { TheSim:WorldToScreenXYNormalized(x, y - halfHeight, z) } or { TheSim:WorldToScreenXYNormalized(x, y + halfHeight, z) }
		local sy_up = is_player and { TheSim:WorldToScreenXYNormalized(x, y + halfHeight, z) } or { TheSim:WorldToScreenXYNormalized(x, y - halfHeight, z) }
		local s_center = { TheSim:WorldToScreenXYNormalized(x, y, z) }

		-- normalized thresholds for screenspace x,y extents
		local tx = (sy_up[1] >= 0) and sx_right[1] or math.abs(sx_left[1])
		local ty = (sx_left[2] >= 0) and sy_up[2] or math.abs(sy_down[2])

		local debugdraw = false
		if debugdraw then
			self:_DebugDrawEntityEdgeDetection(sx_left, sx_right, sy_down, sy_up)
		end

		local safe_threshold_outer = 1.0 - self.edgeDetectCameraSafeZone[profile] + self.edgeDetectCameraSafeZoneBuffer[profile]
		local safe_threshold_inner = 1.0 - self.edgeDetectCameraSafeZone[profile] - self.edgeDetectCameraSafeZoneBuffer[profile]

		if not TheFrontEnd:GetLetterbox():IsDisplaying()
			and math.max(tx, ty) > safe_threshold_outer
			and math.max(math.abs(s_center[1]), math.abs(s_center[2])) > safe_threshold_outer then
			-- entity is leaving the camera's view
			-- TheLog.ch.Camera:printf("FocalPoint: %s is close to the screen edge threshold %1.2f, t=(%1.2f,%1.2f) c=(%1.2f,%1.2f)", tostring(candidate), safe_threshold_outer, tx, ty, s_center[1], s_center[2])

			if is_player then
				self.edgeDetectCameraZoomDelta = self.edgeDetectCameraZoomDelta + self.edgeDetectCameraDistanceDelta
			end

			if not self.edgeDetectTrackedEntities[candidate] then
				self.edgeDetectTrackedEntities[candidate] = 0

				-- create an offscreen indicator for non-player entities
				if not is_player then
					-- TheLog.ch.Camera:printf("FocalPoint: Entity is off-screen: %s", tostring(candidate))
					if not self.edgeDetectTrackedProxies[candidate] then
						-- removed in _CleanupEntityEdgeDetection
						self.edgeDetectTrackedProxies[candidate] = SpawnPrefab("offscreenentityproxy", self.inst)
					end
					self.edgeDetectTrackedProxies[candidate]:PushEvent("entityoffscreenchanged", {entity=candidate, isVisible=false})
				end
			end
			-- increment a "frame counter" of sorts to smooth out popping in/out of tracked entities
			self.edgeDetectTrackedEntities[candidate] = math.min(self.edgeDetectTrackedEntities[candidate] + 1, 15 * ANIM_FRAMES)
		elseif math.max(tx, ty, math.abs(s_center[1]), math.abs(s_center[2])) < safe_threshold_inner
			and self.edgeDetectTrackedEntities[candidate] and self.edgeDetectTrackedEntities[candidate] > 0 then
			-- entity is back in the camera's view
			--TheLog.ch.Camera:printf("FocalPoint: %s is far from the screen edge s=(%1.2f,%1.2f) t=(%1.2f,%1.2f)", tostring(candidate), (sx_right - sx_left) / 2, (sy_up - sy_down) / 2, tx, ty)

			if is_player then
				self.edgeDetectCameraZoomDelta = self.edgeDetectCameraZoomDelta - self.edgeDetectCameraDistanceDelta
				self.edgeDetectTrackedEntities[candidate] = self.edgeDetectTrackedEntities[candidate] - 1
			else
				self.edgeDetectTrackedEntities[candidate] = self.edgeDetectTrackedEntities[candidate] - 5 * ANIM_FRAMES
			end

			if self.edgeDetectTrackedEntities[candidate] <= 0 then
				self.edgeDetectTrackedEntities[candidate] = nil
				-- TheLog.ch.Camera:printf("Entity is on screen: %s", tostring(candidate))
				local proxy = self.edgeDetectTrackedProxies[candidate]
				if proxy then
					proxy:PushEvent("entityoffscreenchanged", {entity=candidate, isVisible=true})
				end
			end
		-- TODO: This code needs to run when a player dies while the camera is panned far away
		elseif not next(self.edgeDetectTrackedEntities, nil) and TheCamera:GetDistance() > self.default_camera_distance then
			self.edgeDetectCameraZoomDelta = -self.edgeDetectCameraDistanceDelta
		end
	elseif self.edgeDetectCooldown > 0 then
		self.edgeDetectCooldown = math.max(0, self.edgeDetectCooldown - dt)
	end
end

function FocalPoint:_GetCameraDistanceForEntityEdgeDetection()
	if not self.edgeDetectEnabled then
		return
	end

	local newCamDist
	if self.edgeDetectCameraZoomDelta ~= 0 then
		local oldCamDist = TheCamera:GetDistance()
		newCamDist = math.clamp(oldCamDist + self.edgeDetectCameraZoomDelta, self.default_camera_distance, self.edgeDetectCameraDistanceMax)
		self.edgeDetectCameraZoomDelta = 0
		self.edgeDetectCooldown = self.edgeDetectCameraDistanceTimeout
	end

	return newCamDist
end

function FocalPoint:_CleanupEntityEdgeDetection()
	-- clean-up invalid entities and associated edge detection proxies
	for k,v in pairs(self.edgeDetectTrackedEntities) do
		if not k:IsValid() then
			self.edgeDetectTrackedEntities[k] = nil
			if self.edgeDetectTrackedProxies[k] then
				self.edgeDetectTrackedProxies[k]:Remove()
				self.edgeDetectTrackedProxies[k] = nil
			end
		end
	end

	for k,v in pairs(self.edgeDetectCandidates) do
		if not k:IsValid() then
			self.edgeDetectCandidates[k] = nil
		end
	end
end

function FocalPoint:EnableEntityEdgeDetection(enabled)
	if enabled == nil then
		return
	end

	TheLog.ch.Camera:print("FocalPoint: enabled = " .. tostring(enabled))
	if self.edgeDetectEnabled ~= enabled then
		self.edgeDetectEnabled = enabled
		TheLog.ch.Camera:print("FocalPoint: Player Edge Detection", (enabled and "enabled" or "disabled"))
		self:_SetDesiredDistance(self.default_camera_distance)
		self.edgeDetectTrackedEntities = {}
		self.edgeDetectCooldown = 0
		self.edgeDetectCameraZoomDelta = 0
	end
end

-- TODO: victorc - if needed, support a key for add/remove/clear so callers can manage their own sets
function FocalPoint:AddEntityForEdgeDetection(ent)
	self.edgeDetectCandidates[ent] = 0.0
	if TheNet:IsHost() and ent:IsNetworked() then
		TheNet:HostSetFocalPointEntitiesForEdgeDetection(self.edgeDetectCandidates)
	end
end

function FocalPoint:RemoveEntityForEdgeDetection(ent)
	self.edgeDetectCandidates[ent] = nil
	if self.edgeDetectTrackedProxies[ent] then
		self.edgeDetectTrackedProxies[ent]:Remove() -- proxy
		self.edgeDetectTrackedProxies[ent] = nil
	end
	if TheNet:IsHost() and ent:IsNetworked() then
		TheNet:HostSetFocalPointEntitiesForEdgeDetection(self.edgeDetectCandidates)
	end
end

local temp = {}
function FocalPoint:ClientSetEntitiesForEdgeDetection(entities)
	for ent,_ in pairs(entities) do
		if not self.edgeDetectCandidates[ent] then
			self:AddEntityForEdgeDetection(ent)
		end
	end

	for ent,_ in pairs(self.edgeDetectCandidates) do
		if ent:IsNetworked() and not entities[ent] then
			table.insert(temp, ent)
		end
	end

	for _i,ent in ipairs(temp) do
		self:RemoveEntityForEdgeDetection(ent)
	end
	table.clear(temp)
end

-- returns nil if entity is not being tracked for edge detection, otherwise true or false
function FocalPoint:IsEntityOffScreen(ent)
	if self.edgeDetectCandidates[ent] then
		return self.edgeDetectTrackedEntities[ent] ~= nil
	end
	return nil
end

function FocalPoint:ClearEntitiesForEdgeDetection(keep_tags)
	if keep_tags then
		-- TODO: victorc: this code path is untested as it has no use cases
		if type(keep_tags) == "string" then
			keep_tags = {[keep_tags] = true}
		end

		local keep_ents = {}
		local discard_ents = {}
		for tag,_ in pairs(keep_tags) do
			for ent,t in pairs(self.edgeDetectCandidates) do
				if ent:HasTag(tag) then
					keep_ents[ent] = t
				else
					table.insert(discard_ents, ent)
				end
			end
		end
		self.edgeDetectCandidates = keep_ents

		for _i,ent in ipairs(discard_ents) do
			if self.edgeDetectTrackedProxies[ent] then
				self.edgeDetectTrackedProxies[ent]:Remove() -- proxy
				self.edgeDetectTrackedProxies[ent] = nil
				self.edgeDetectTrackedEntities[ent] = nil
			end
		end
	else
		table.clear(self.edgeDetectCandidates)
		for _ent,proxy in pairs(self.edgeDetectTrackedProxies) do
			proxy:Remove()
		end
		table.clear(self.edgeDetectTrackedEntities)
		table.clear(self.edgeDetectTrackedProxies)
	end

	if TheNet:IsHost() then
		TheNet:HostSetFocalPointEntitiesForEdgeDetection(self.edgeDetectCandidates)
	end
end

function FocalPoint:DebugEntityEdgeDetectionStatus()
	print("DebugEntityEdgeDetectionStatus")
	dumptable(self.edgeDetwectTrackedEntities)
end

function FocalPoint:CalculateMoveSpeed(dx)
	return self.distSpeedFactor * (dx ^ 2) + self.minSpeed
end

function FocalPoint:_DebugDrawFocalPointPosition(x, z)
	local ui = require "dbui.imgui"
	local wx, wy, wz = self.inst.Transform:GetWorldPosition()
	ui:WorldLine({wx - 2, wy, wz}, {wx + 2, wy, wz})
	ui:WorldLine({wx, wy, wz - 2}, {wx, wy, wz + 2})
	ui:WorldLine({x - 1, 0, z}, {x + 1, 0, z}, WEBCOLORS.LIME)
	ui:WorldLine({x, 0, z + 1}, {x, 0, z - 1}, WEBCOLORS.LIME)
	ui:WorldLine({wx, wy, wz}, {x, 0, z}, UICOLORS.GREY)
end

function FocalPoint:OnUpdate(dt)
	if not TheWorld then
		return
	end

	if TheDungeon.HUD then
		local is_focus_on_hud, reason = TheDungeon.HUD:IsHudSinkingInput()
		if is_focus_on_hud
			and reason == "screen"
		then
			-- Don't let remote players wiggle our view behind screens, because it
			-- makes me nauseous. Only do it for screens because "prompt" would
			-- prevent conversation camera movement.
			return
		end
	end

	-- Weighted center of all players and interested entities
	local relevant_ents = {}
	local n = 0 -- number of entities to average out a calculated position

	for _i,v in ipairs(AllPlayers) do
		local is_relevant = (not v:IsDead()
			and not v:IsInLimbo()
			and (not TheWorld:HasTag("town") or v:IsLocal()) -- ignore remotes in town
			and (not TheWorld:GetCurrentRoomType() == mapgen.roomtypes.RoomType.s.market or v:IsLocal())) -- ignore remotes in market
		if is_relevant then
			relevant_ents[v] = v:IsDead() and 0 or 1
			n = n + (v:IsDead() and 0 or 1)
		end
	end

	self:ValidateExplicitTargets()
	if self.explicit_targets then
		relevant_ents = {}
		n = 0
		for ent in pairs(self.explicit_targets) do
			-- TODO(dbriscoe): I think we can assign a weight here since offsets are scaled below.
			local weight = 1
			relevant_ents[ent] = weight
			n = n + weight
		end
	end

	for ent,t in pairs(self.edgeDetectCandidates) do
		if ent:IsValid() and not relevant_ents[ent] then
			if t < self.edgeDetectCandidateEaseInTime then
				local contribution = easing.outExpo(t, 0, self.edgeDetectCandidateWeight, self.edgeDetectCandidateEaseInTime)
				relevant_ents[ent] = contribution
				n = n + contribution
			else
				relevant_ents[ent] = self.edgeDetectCandidateWeight
				n = n + self.edgeDetectCandidateWeight
			end
			self.edgeDetectCandidates[ent] = t + dt
		end
	end

	local x, z = 0, 0
	local dist = self.default_camera_distance

	if n > 0 then
		for ent,t in pairs(relevant_ents) do
			local x1, y1, z1 = ent.Transform:GetWorldPosition()
			x = x + x1 * t
			z = z + z1 * t

			local minx,miny,minz,maxx,maxy,maxz = ent.entity:GetWorldAABB()
			local halfWidth = (maxx - minx) / 2
			local halfHeight = (maxy - miny) / 2
			y1 = y1 + halfHeight
			self:_UpdateEntityEdgeDetection(dt, ent, x1, y1, z1, halfWidth, halfHeight)
		end
		x = x / n
		z = z / n
		dist = self:_GetCameraDistanceForEntityEdgeDetection()
	end
	self:_CleanupEntityEdgeDetection()

	--Focus sources
	if next(self.focuses) ~= nil then
		local bestfocus, bestx, bestz, bestsource
		local bestdistsq = math.huge
		local bestpriority = -math.huge
		for k, v in pairs(self.focuses) do
			if v.priority >= bestpriority then
				local x1, z1 = k.Transform:GetWorldXZ()
				local distsq = DistSq2D(x, z, x1, z1)
				if distsq < v.maxrange * v.maxrange and (v.priority > bestpriority or distsq < bestdistsq) then
					bestfocus = v
					bestsource = k
					bestx, bestz = x1, z1
					bestdistsq = distsq
					bestpriority = v.priority
				end
			end
		end

		if bestfocus ~= nil then
			local weight = bestfocus.weight
			if bestdistsq > bestfocus.minrange * bestfocus.minrange then
				weight = weight * (bestfocus.maxrange - math.sqrt(bestdistsq)) / (bestfocus.maxrange - bestfocus.minrange)
			end
			weight = math.clamp(weight, 0, 1)
			local weight1 = 1 - weight
			x = x * weight1 + bestx * weight
			z = z * weight1 + bestz * weight
		end

		self.current_source = bestsource
	end

	--Camera limits
	-- TODO(roomtravel): instead of nil check, prevent us from updating while world doesn't exist
	if TheWorld and TheWorld.components.cameralimits then
		x, z = TheWorld.components.cameralimits:ApplyLimits(x, z)
	end

	local old_dist = self.inst.desired_camera_distance
	if dist and old_dist ~= dist then
		self:_SetDesiredDistance(dist)
		--TheLog.ch.Camera:printf("FocalPoint: Camera Distance %0.2f -> %0.2f ", old_dist, dist)
	end

	if n >= 1 and self.inst:GetTimeAlive() >= 0.5 then
		local targetPosition = Vector3(x,0,z)
		local lastPosition = Vector3({self.inst.Transform:GetWorldPosition()})

		local newPosition = lastPosition + ((targetPosition - lastPosition) * math.min(dt * self.newCameraMinSpeed, 1.0))
		self.inst.Transform:SetPosition(newPosition.x, newPosition.y, newPosition.z)

		-- victorc: this code broke because lume.approximately had a critical error comparing differing signed values
		-- NW: This code is unstable, it will sometimes explode in networked games and result in HUGE camera speeds:
		--local delta = targetPosition - lastPosition
		--local dist_diff = Vector3.len(delta)
		--if lume.approximately(dist_diff, 0, math.max(self.minSpeed * dt, 0.001)) then
		--	self.inst.Transform:SetPosition(x, 0, z)
		--else
		--	local speed = self:CalculateMoveSpeed(dist_diff)
		--	local dir = delta / dist_diff
		--	local newPosition = lastPosition + dir * (speed * dt)
		--	self.inst.Transform:SetPosition(newPosition.x, newPosition.y, newPosition.z)
		--end
	else
		self.inst.Transform:SetPosition(x, 0, z)
	end
	-- self:_DebugDrawFocalPointPosition(x, z)
end

function FocalPoint:_MakePresetsEditable()
	assert(getmetatable(FocusPreset) ~= nil, "Don't call more than once.")
	local old_presets = FocusPreset
	FocusPreset = deepcopyskipmeta(FocusPreset)
	-- Hookup new focus preset table to existing focuses.
	for key,val in pairs(self.focuses) do
		local focus_name = lume.find(old_presets, val)
		if focus_name then
			self.focuses[key] = FocusPreset[focus_name]
		end
	end
end

function FocalPoint:DebugDrawEntity(ui, panel, colors)
	ui:TextColored(colors.header, "Debug String")
	ui:Text(self:GetDebugString())
	ui:Separator()
	panel:AppendTable(ui, self.explicit_targets, "self.explicit_targets")
	panel:AppendTable(ui, self.focuses, "self.focuses")

	if ui:CollapsingHeader("FocusPreset") then
		ui:Indent() do
			if ui:CollapsingHeader("Help") then
				ui:TextWrapped(FOCUS_PRESET_DOC)
			end
			local is_editable = getmetatable(FocusPreset) == nil
			if ui:Button("Make FocusPreset Editable", nil, nil, is_editable) then
				self:_MakePresetsEditable()
			end
			local to_pop = 0
			if not is_editable then
				to_pop = ui:PushDisabledStyle()
			end

			local ranges = {
				minrange = { 0, 60, "%i m", },
				maxrange = { 0, 60, "%i m", },
				priority = { 1, 1000, },
			}
			for key,p in iterator.sorted_pairs(FocusPreset) do
				ui:Text(key)
				for label,range in pairs(ranges) do
					local changed, val = ui:SliderInt(label .."##".. key, p[label], table.unpack(range))
					if changed and is_editable then
						p[label] = val
					end
				end
				local changed, val = ui:SliderFloat("weight##".. key, p.weight, 0, 1)
				if changed and is_editable then
					p.weight = val
				end
				if p.minrange > p.maxrange then
					ui:TextColored(WEBCOLORS.YELLOW, "minrange must be less than maxrange.")
				end
			end

			ui:PopStyleColor(to_pop)
		end ui:Unindent()
	end
end

function FocalPoint:GetDebugString()
	local str = "explicit_targets:"
	for k, v in pairs(self.explicit_targets or {}) do
		str = str..string.format("\n   %s", tostring(k))
	end
	str = str .. "\nfocuses:"
	for k, v in pairs(self.focuses) do
		str = str..string.format("\n   %s %s, Range=(%s, %s), Weight=%s, Priority=%s", k == self.current_source and "->" or "   ", tostring(k), v.minrange, v.maxrange, v.weight, v.priority)
	end
	return str
end

return FocalPoint
