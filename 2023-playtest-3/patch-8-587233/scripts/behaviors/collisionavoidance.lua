local DebugDraw = require "util.debugdraw"
local EPSILON = require "math.modules.constants".FLT_EPSILON
local lume = require "util.lume"

-- RVO-style (reciprocal velocity obstacle) collision avoidance for entity locomotion
-- Reference: Reciprocal Velocity Obstacles for Real-Time Multi-Agent Navigation
-- by Jur van den Berg, Ming C. Lin, Dinesh Manocha
-- https://gamma.cs.unc.edu/RVO/
-- Main differences from reference:
-- - Candidate velocities are not random and limited to a swept arc of fixed velocities
-- - Non-moving agents (entities) are considered obstacles
-- - Penalty function is customized for this implementation

local CollisionAvoidance = {}

CollisionAvoidance.Enabled = true
CollisionAvoidance.AllowVariableSpeed = true
CollisionAvoidance.VariableSpeedFactor = 0.7
CollisionAvoidance.MinSpeedForVariable = 2
CollisionAvoidance.DebugDraw = false
CollisionAvoidance.DebugText = false
CollisionAvoidance.DebugEntityIsTarget = false

CollisionAvoidanceOptions =
{
	ForceUseWalkSpeed      = 0x0001,
	ReverseOnFullOverlap   = 0x0002,
	IgnoreVariableSpeed    = 0x0004,
}

CollisionAvoidance.DebugDrawFlags =
{
	Radius                = 0x00000001,
	NeighborRegion        = 0x00000002,
	PositionHistory       = 0x00000004,
	CandidateVelocity     = 0x00000008,
	TruncatedVelocity     = 0x00000010,
	EntityRadius          = 0x00000020,
	EntityVelocity        = 0x00000040,
	TestVelocity          = 0x00000080,
	TestCollisionImminent = 0x00000100,
	TestCollisionHit      = 0x00000200,
	TestCollisionMiss     = 0x00000400,
	BestVelocity          = 0x00000800,
	AverageCollisionHit   = 0x00001000,
}

CollisionAvoidance.DebugDrawSettings = {
	["full"] = 0xFFFFFFFF,
	["debugentity"] =
		CollisionAvoidance.DebugDrawFlags.Radius |
		CollisionAvoidance.DebugDrawFlags.NeighborRegion |
		CollisionAvoidance.DebugDrawFlags.PositionHistory |
		CollisionAvoidance.DebugDrawFlags.TruncatedVelocity |
		CollisionAvoidance.DebugDrawFlags.EntityRadius |
		CollisionAvoidance.DebugDrawFlags.EntityVelocity |
		CollisionAvoidance.DebugDrawFlags.TestVelocity |
		CollisionAvoidance.DebugDrawFlags.TestCollisionHit |
		CollisionAvoidance.DebugDrawFlags.BestVelocity |
		CollisionAvoidance.DebugDrawFlags.AverageCollisionHit,
	["normal"] =
		CollisionAvoidance.DebugDrawFlags.Radius |
		CollisionAvoidance.DebugDrawFlags.PositionHistory |
		CollisionAvoidance.DebugDrawFlags.TestCollisionHit |
		CollisionAvoidance.DebugDrawFlags.BestVelocity,
}

local kDebugDrawLifetime = 1 / 60 * 6
local kRoot2 = math.sqrt(2)

local function CircleCollision(p1, v1, r1, p2, v2, r2)
	local doesIntersect, cx, cy, t = TheSim:CircleCollision(p1.x, p1.y, v1.x, v1.y, r1, p2.x, p2.y, v2.x, v2.y, r2)
	return doesIntersect, Vector2(cx,cy), t

	-- TODO: victorc - to eventually be removed
	-- Lua implementation of CircleCollision
	--[[
	-- put (1) into (2)'s frame of reference to simplify things
	local v1r2 = v1 - v2

	local dist = Vector2.len(p2 - p1)
	local sumRadii = r1 + r2
	dist = dist - sumRadii
	local v1r2mag = Vector2.len(v1r2)
	if v1r2mag < dist then
		return false, Vector2(math.huge, math.huge), math.huge
	end

	local v1r2n = Vector2.normalized(v1r2)
	local c = p2 - p1
	local d = Vector2.dot(v1r2n, c)
	if d <= 0 then
		return false, Vector2(math.huge, math.huge), math.huge
	end

	local cMag = Vector2.len(c)
	local f = cMag * cMag - d * d
	local sumRadiiSquared = sumRadii * sumRadii
	if f >= sumRadiiSquared then
		return false, Vector2(math.huge, math.huge), math.huge
	end

	local t = sumRadiiSquared - f
	if t < 0 then
		return false, Vector2(math.huge, math.huge), math.huge
	end

	local distance = d - math.sqrt(t)
	if v1r2mag < distance then
		return false, Vector2(math.huge, math.huge), math.huge
	end

	local ttc = distance / v1r2mag
	local p1c = p1 + v1r2n * ttc
	local p2p1c = p2 - p1c
	local collisionPoint = p1c + p2p1c * (r1 / sumRadii)
	return true, collisionPoint + v2, ttc
	]]
end

-- returns table of candidate velocities with additional support data
local function GenerateCandidateVelocities(p1, p1Rot, p1Speed, vPref, angleIncrement, count, debugdrawflags)
	local candVels = {}
	candVels[1] = { dir = math.deg(-math.atan(vPref.y, vPref.x)), vel = vPref, speed = p1Speed, angleDiff = 0 } -- lhcs
	for i=1,count do
		for s=0,1 do
			local sign = (s % 2 == 0) and 1 or -1
			local candVel = Vector2.rotate(vPref, -math.rad(sign * i * angleIncrement) ) --lhcs

			-- this is a coarse way to handle stage extents
			-- TODO: victorc - the candidate velocity should still be considered but truncated or considered an obstacle
			if TheWorld.Map:IsWalkableAtXZ(p1.x + candVel.x, p1.y + candVel.y) then
				local candDir = math.deg(-math.atan(candVel.y, candVel.x)) -- lhcs
				if not candVels[candDir] then
					candVels[2+(i-1)*2+s] = { dir = candDir, vel = candVel, speed = p1Speed, angleDiff = DiffAngle(candDir, p1Rot)}
				end
			else
				if CollisionAvoidance.DebugDraw and debugdrawflags & CollisionAvoidance.DebugDrawFlags.TruncatedVelocity ~= 0 then
					DebugDraw.GroundLine(p1.x, p1.y, (p1+candVel).x, (p1+candVel).y, WEBCOLORS.DARKSLATEGRAY, 1, kDebugDrawLifetime)
				end
				if CollisionAvoidance.DebugText then
					TheLog.ch.AI:printf("Cand Vel %d is not on ground: (%1.2f,%1.2f)", i, p1.x + candVel.x, p1.y + candVel.y)
				end

				candVels[2+(i-1)*2+s] = nil
			end
		end
	end
	return candVels
end

local kPenaltyCollisionFactor = 10
-- use various factors to determine penalty for a given candidate velocity
-- lowest penalty will be chosen by collision avoidance algorithm
-- dt - min time between collision avoidance updates (i.e. based on behaviour tree sleep time)
local function CalculatePenalty(lookAheadTime, timeToCollision, prefSpeed, candSpeed, angleDiff, dt)
	-- collision times below nyquist sampling rate are much more at risk of collisions
	timeToCollision = timeToCollision - dt * 2
	timeToCollision = timeToCollision == 0 and EPSILON or timeToCollision

	-- prefer headings that don't deviate as much from current heading
	local angleFactor = 1 - math.cos(math.rad(angleDiff))
	local speedFactor = prefSpeed > 0 and (1 + math.abs(prefSpeed - candSpeed) / prefSpeed * 2.2) or 1

	if timeToCollision > 0 then
		return math.min(kPenaltyCollisionFactor, lookAheadTime / timeToCollision + candSpeed * speedFactor + angleFactor)
	else
		-- negative collision time == time since collision already happened
		return kPenaltyCollisionFactor + prefSpeed / kPenaltyCollisionFactor - timeToCollision * (candSpeed * speedFactor) / (dt * dt) + angleFactor
	end
end

local function CalculatePenaltyThreshold(prefSpeed, dt)
	return kPenaltyCollisionFactor + (2 * dt * kPenaltyCollisionFactor) / (prefSpeed == 0 and EPSILON or math.abs(prefSpeed))
end


function CollisionAvoidance.SetIgnoreList( inst, list )
	inst.collision_ignore_list = list
end

function CollisionAvoidance.AddIgnoreEnt( inst, ent )
	if not inst.collision_ignore_list then inst.collision_ignore_list = {} end
	if not lume.find(inst.collision_ignore_list, ent) then
		table.insert(inst.collision_ignore_list, ent)
	end
end

-- returns: new direction/heading (degrees), speed multiplier bonus (number), is "bad" velocity (bool)
function CollisionAvoidance.ApplyCollisionAvoidance(inst, prefDir, dt, lookAheadTime, options)
	--TheSim:ProfilerPush("collisionavoidance")
	lookAheadTime = lookAheadTime or 1
	options = options or 0
	local debugdrawflags = CollisionAvoidance.DebugDraw
		and (GetDebugEntity() == inst
			and CollisionAvoidance.DebugDrawSettings["debugentity"]
			or CollisionAvoidance.DebugDrawSettings["normal"])
		or 0
	local debugtext = CollisionAvoidance.DebugText and GetDebugEntity() == inst

	local useWalkSpeed = (options and CollisionAvoidanceOptions.ForceUseWalkSpeed) ~- 0
	local myPrefSpeed = inst.components.locomotor:CanRun() and not useWalkSpeed
		and inst.components.locomotor:GetRunSpeed()
		or inst.components.locomotor:GetWalkSpeed()
	local x, z = inst.Transform:GetWorldXZ()
	local myPos = Vector2(x, z)
	local myPrefVel = Vector2.rotate(Vector2(myPrefSpeed, 0), math.rad(-prefDir)) -- lhcs
	local vx, vy, vz = inst.Physics:GetVel()
	local myVel = Vector2(vx, vz)
	local mySpeedSq = Vector2.len2(myVel)
	local myRadius = inst.Physics:GetSize()
	-- most collision shapes are squares or rounded squares
	local mySafeRadius = kRoot2 * myRadius
	-- define Neighbour Region using avoidDistance radius
	local avoidDistance = math.max(mySafeRadius + myPrefSpeed * lookAheadTime)
	local myRot = inst.Transform:GetRotation()

	if debugtext then
		TheLog.ch.AI:printf("[%1.2f] myVel=%1.2f, %1.2f, %1.2f, myPrefVel=%1.2f,%1.2f currentDir=%1.2f prefDir=%1.2f",
			GetTime(),
			vx, vy, vz,
			myPrefVel.x, myPrefVel.y,
			myRot,
			prefDir)
	end

	if CollisionAvoidance.DebugDraw then
		if debugdrawflags & CollisionAvoidance.DebugDrawFlags.Radius ~= 0 then
			DebugDraw.GroundCircle(x, z, mySafeRadius, WEBCOLORS.BLUE, 1, kDebugDrawLifetime)
		end
		if debugdrawflags & CollisionAvoidance.DebugDrawFlags.NeighborRegion ~= 0 then
			DebugDraw.GroundCircle(x, z, avoidDistance, WEBCOLORS.GRAY, 1, kDebugDrawLifetime)
		end
		if debugdrawflags & CollisionAvoidance.DebugDrawFlags.PositionHistory ~= 0 then
			DebugDraw.GroundTriangle(x, z, 0.25 * myRadius, WEBCOLORS.BLACK, myRot, 30 * kDebugDrawLifetime)
		end
	end

	local tags = { "character", "prop", "mob" }
	local ents = TheSim:FindEntitiesXZ(x, z, avoidDistance, nil, nil, tags)

	local collides_with = inst.Physics:GetCollisionMask()
	local to_ignore = {}
	for _, ent in ipairs(ents) do
		-- pre-cull the list to reduce candidate velocity churn
		local ignorecollision = false
		if ent.Physics ~= nil and ent ~= inst then
			local ent_collision = ent.Physics:GetCollisionGroup()
			local collision_overlap = ent_collision & collides_with
			if collision_overlap == 0 then
				ignorecollision = true
			end
		end
		if ent == inst or ent.Physics == nil or not TheWorld.Map:IsWalkableAtXZ(ent.Transform:GetWorldXZ()) or ignorecollision then
			if CollisionAvoidance.DebugText then
				TheLog.ch.CollisionAvoidance:printf("Culling ent %s prefab=%s", tostring(ent), ent.prefab)
			end
			table.insert(to_ignore, ent)
		else
			if CollisionAvoidance.DebugText then
				TheLog.ch.CollisionAvoidance:printf("Considering ent %s prefab=%s", tostring(ent), ent.prefab)
			end
		end
	end
	if inst.collision_ignore_list then
		for _, ent in ipairs(inst.collision_ignore_list) do
			table.insert(to_ignore, ent)
		end
	end

	for _,ent in ipairs(to_ignore) do
		lume.remove(ents, ent)
	end

	if #ents == 0 then
		if debugtext then
			TheLog.ch.AI:printf("No entities nearby - using preferred dir (%1.2f)", prefDir)
		end
		--TheSim:ProfilerPop()
		return prefDir, 0, false
	end

	local target = inst.components.combat and inst.components.combat:GetTarget() or nil
	if CollisionAvoidance.DebugEntityIsTarget then
		target = GetDebugEntity()
	end

	-- TODO: victorc - adjust generated spread based on other circumstances
	local angleIncrement = 20
	local normalSpeedCount = 5
	local slowSpeedCount = 10
	local candData = GenerateCandidateVelocities(myPos, myRot, myPrefSpeed, myPrefVel, angleIncrement, mySpeedSq >= 0.1 and normalSpeedCount or slowSpeedCount, debugdrawflags)
	if CollisionAvoidance.AllowVariableSpeed
		and (options & CollisionAvoidanceOptions.IgnoreVariableSpeed == 0)
		and myPrefSpeed * CollisionAvoidance.VariableSpeedFactor >= CollisionAvoidance.MinSpeedForVariable then
		local candData2 = GenerateCandidateVelocities(myPos, myRot, myPrefSpeed * CollisionAvoidance.VariableSpeedFactor, myPrefVel * CollisionAvoidance.VariableSpeedFactor, angleIncrement, mySpeedSq >= 0.1 and normalSpeedCount or slowSpeedCount, debugdrawflags)
		candData = table.appendarrays(candData, candData2)
	end

	local movingEntTests = 0
	local movingEntOverlapCount = 0
	local avgCollisionPoint = nil
	local bestCandEntry = nil
	local bestCandPenalty = math.huge
	for i, candEntry in pairs(candData) do
		if candEntry ~= nil then
			local candVel = candEntry.vel
			local candDir = candEntry.dir
			local candAngleDiff = candEntry.angleDiff
			local candPenalty = math.huge
			local candTTC = math.huge -- time to collision for this candidate velocity

			if debugdrawflags & CollisionAvoidance.DebugDrawFlags.CandidateVelocity ~= 0 then
				DebugDraw.GroundLine(myPos.x, myPos.y, myPos.x + candVel.x, myPos.y + candVel.y, WEBCOLORS.WHITE, 1, kDebugDrawLifetime)
			end

			for j, ent in ipairs(ents) do
				if inst ~= ent and target ~= ent and not ent:IsDead() and ent:IsVisible() and ent.Physics then
					--TheSim:ProfilerPush("entDataGather")
					local entX, entZ = ent.Transform:GetWorldXZ()
					local entPos = Vector2(entX, entZ)
					local entVelX, entVelY, entVelZ = ent.Physics:GetVel()
					local entVel = Vector2(entVelX, entVelZ)
					local entRadius = ent.Physics:GetSize()
					local entSafeRadius = kRoot2 * entRadius
					local entSpeedSq = Vector2.len2(entVel)
					--TheSim:ProfilerPop()

					if entSpeedSq > 0 then
						movingEntTests = movingEntTests + 1
					end

					if CollisionAvoidance.DebugDraw then
							if debugdrawflags & CollisionAvoidance.DebugDrawFlags.EntityRadius ~= 0 then
								DebugDraw.GroundCircle(entX, entZ, entSafeRadius, WEBCOLORS.CYAN, 1, kDebugDrawLifetime)
							if entSpeedSq > 0 and debugdrawflags & CollisionAvoidance.DebugDrawFlags.EntityVelocity ~= 0 then
								DebugDraw.GroundLine(entX, entZ, entX + entVel.x, entZ + entVel.y, WEBCOLORS.CYAN, 1, kDebugDrawLifetime)
							end
						end
					end

					-- TODO: victorc - do more tests with this
					-- local testVel = (entSpeedSq >= EPSILON) and ((candVel * 2) - myVel - entVel) or candVel;
					local testWeight = 0.5
					local testVel = (entSpeedSq >= EPSILON) and (candVel * 1 / (EPSILON + testWeight) - myVel + entVel) * testWeight or candVel;
					-- TheSim:ProfilerPush("CircleCollision")
					local doesIntersect, c, t = CircleCollision(myPos, testVel, mySafeRadius, entPos, entVel, entSafeRadius)
					-- TheSim:ProfilerPop("CircleCollision")

					if t <= 0 then
						movingEntOverlapCount = movingEntOverlapCount + 1
						-- remove avgCollisionPoint
						--[[
						if not avgCollisionPoint then
							avgCollisionPoint = c
						else
							avgCollisionPoint = (avgCollisionPoint * (movingEntOverlapCount - 1)) / movingEntOverlapCount + c / movingEntOverlapCount
						end
						]]
					end

					if debugtext then
						TheLog.ch.AI:printf("Col %d-%d dir=%1.2f vel=%1.2f,%1.2f ent=%s collide=%s t=%1.2f p=%1.2f",
							j, i,
							candDir,
							candVel.x, candVel.y,
							ent.prefab,
							tostring(doesIntersect),
							t,
							CalculatePenalty(lookAheadTime, t, myPrefSpeed, candEntry.speed, DiffAngle(candDir, myRot), dt))
					end

					if CollisionAvoidance.DebugDraw then
						if debugdrawflags & CollisionAvoidance.DebugDrawFlags.TestVelocity ~= 0 then
							DebugDraw.GroundLine(myPos.x, myPos.y, myPos.x + testVel.x, myPos.y + testVel.y, WEBCOLORS.LIGHTGRAY, 1, kDebugDrawLifetime)
							DebugDraw.GroundDiamond(myPos.x + testVel.x, myPos.y + testVel.y, 0.25, WEBCOLORS.LIGHTGRAY, 1, kDebugDrawLifetime)
						end

						if doesIntersect then
							local color, lifetime
							if debugdrawflags & CollisionAvoidance.DebugDrawFlags.TestCollisionHit ~= 0 and t <= dt then
								color = t <= 0.0 and WEBCOLORS.RED or WEBCOLORS.ORANGE
								lifetime = t <= 0.0 and kDebugDrawLifetime * 2 or kDebugDrawLifetime
							end
							if debugdrawflags & CollisionAvoidance.DebugDrawFlags.TestCollisionImminent ~= 0 and t > dt then
								color = WEBCOLORS.YELLOW
								lifetime = kDebugDrawLifetime
							end
							if color and lifetime then
								DebugDraw.GroundDiamond(c.x, c.y, 0.5, color, 0, lifetime)
							end
						elseif debugdrawflags & CollisionAvoidance.DebugDrawFlags.TestCollisionMiss ~= 0 then
							DebugDraw.GroundDiamond(myPos.x + testVel.x, myPos.y + testVel.y, 0.5, WEBCOLORS.LIMEGREEN, 0, kDebugDrawLifetime)
						end
					end

					if t < candTTC then
						candTTC = t
						if CalculatePenalty(lookAheadTime, candTTC, myPrefSpeed, candEntry.speed, candAngleDiff, dt) > bestCandPenalty then
							break
						end
					end
				end -- if valid test entity
			end -- for ipairs(ents)

			candPenalty = CalculatePenalty(lookAheadTime, candTTC, myPrefSpeed, candEntry.speed, candAngleDiff, dt)
			if candPenalty < bestCandPenalty then
				bestCandPenalty = candPenalty
				bestCandEntry = candEntry
			end
		end -- if candEntry ~= nil
	end -- for ipairs(candData)

	local isFullOverlap = movingEntTests > 0 and movingEntOverlapCount == movingEntTests
	if debugtext then
		if isFullOverlap then
			TheLog.ch.AI:printf("============================== WARNING: full overlap ==============================")
		end
		TheLog.ch.AI:printf("movingEntTests: %d overlapCount: %d candData Count: %d", movingEntTests, movingEntOverlapCount, #candData)
	end

	local isBadVel = false
	local debugColor = WEBCOLORS.LIMEGREEN
	local penaltyLimit = CalculatePenaltyThreshold(myPrefSpeed, dt)
	if bestCandEntry == nil or bestCandPenalty >= penaltyLimit then
		bestCandEntry = {}

		if (options & CollisionAvoidanceOptions.ReverseOnFullOverlap) ~= 0
			and isFullOverlap
			and avgCollisionPoint then
			local reverseCollisionVel = myPos - avgCollisionPoint
			local reverseCollisionDirRad = -math.atan(reverseCollisionVel.y, reverseCollisionVel.x) --lhcs
			bestCandEntry.vel = Vector2.rotate(Vector2(myPrefSpeed, 0), reverseCollisionDirRad)
			bestCandEntry.dir = math.deg(reverseCollisionDirRad)
			bestCandEntry.speed = myPrefSpeed
		else
			local newHeading = (mySpeedSq <= 0.1 or isFullOverlap) and prefDir or myRot
			bestCandEntry.vel = Vector2.rotate(Vector2(myPrefSpeed, 0), -math.rad(newHeading)) -- lhcs: negation
			bestCandEntry.dir = newHeading
			bestCandEntry.speed = myPrefSpeed
		end
		if debugtext then
			TheLog.ch.AI:print("Can't find good evasive velocity: bestPenalty=%1.2f penaltyLimit=%1.2f", bestCandPenalty, penaltyLimit)
		end
		isBadVel = true
		debugColor = WEBCOLORS.DARKRED
	elseif bestCandPenalty == math.huge then
		debugColor = WEBCOLORS.LIME
	elseif bestCandEntry.speed < myPrefSpeed then
		debugColor = WEBCOLORS.YELLOW
	end

	if debugtext then
		TheLog.ch.AI:printf("Best Dir: %1.2f (preferred=%1.2f) penalty=%1.2f penaltyLimit=%1.2f", bestCandEntry.dir, prefDir, bestCandPenalty, penaltyLimit)
	end

	if CollisionAvoidance.DebugDraw then
		if debugdrawflags & CollisionAvoidance.DebugDrawFlags.BestVelocity ~= 0 then
			DebugDraw.GroundLine(myPos.x, myPos.y, myPos.x + bestCandEntry.vel.x, myPos.y + bestCandEntry.vel.y, debugColor, 4, kDebugDrawLifetime)
		end

		if avgCollisionPoint ~= nil and debugdrawflags & CollisionAvoidance.DebugDrawFlags.AverageCollisionHit ~= 0 then
			DebugDraw.GroundDiamond(avgCollisionPoint.x, avgCollisionPoint.y, 1, isFullOverlap and WEBCOLORS.WHITE or WEBCOLORS.DARKRED, 0, kDebugDrawLifetime)
		end
	end

	--TheSim:ProfilerPop()
	return bestCandEntry.dir, bestCandEntry.speed < myPrefSpeed and -CollisionAvoidance.VariableSpeedFactor or 0, isBadVel
end

function CollisionAvoidance.IsDebugEnabled()
	return CollisionAvoidance.DebugDraw or CollisionAvoidance.DebugText
end


return CollisionAvoidance
