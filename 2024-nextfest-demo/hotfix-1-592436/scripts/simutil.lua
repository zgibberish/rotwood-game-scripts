local lume = require"util.lume"

function ShakeAllCameras(mode, duration, speed, scale, source_or_pt, maxDist)
    for i, v in ipairs(AllPlayers) do
        v:ShakeCamera(mode, duration, speed, scale, source_or_pt, maxDist)
    end
end

local function CheckValidXZByAngle(x, z, angle, radius, test_fn)
	x = x + radius * math.cos(angle)
	z = z - radius * math.sin(angle)
	if test_fn(x, z) then
		return x, z
	end
end

function FindValidXZByFan(x, z, start_angle, radius, attempts, test_fn)
	local x1, z1 = CheckValidXZByAngle(x, z, start_angle, radius, test_fn)
	if x1 ~= nil then
		return x1, z1
	end

	attempts = attempts or 8
	if attempts <= 1 then
		return
	end

	local delta = 2 * math.pi / attempts
	local theta = 0
	for i = 1, (attempts - 1) >> 1 do
		theta = theta + delta
		x1, z1 = CheckValidXZByAngle(x, z, start_angle + theta, radius, test_fn)
		if x1 ~= nil then
			return x1, z1
		end
		x1, z1 = CheckValidXZByAngle(x, z, start_angle - theta, radius, test_fn)
		if x1 ~= nil then
			return x1, z1
		end
	end

	if (attempts & 1) == 0 then
		x1, z1 = CheckValidXZByAngle(x, z, start_angle + math.pi, radius, test_fn)
		if x1 ~= nil then
			return x1, z1
		end
	end
end

local function IsWalkableGroundAtXZ(x, z)
	return TheWorld.Map:IsWalkableAtXZ(x, z)
end

function FindWalkableXZByFan(x, z, start_angle, radius, attempts)
	return FindValidXZByFan(x, z, start_angle, radius, attempts, IsWalkableGroundAtXZ)
end

local inventoryItemAtlasLookup = {}

function RegisterInventoryItemAtlas(atlas, imagename)
	if atlas ~= nil and imagename ~= nil then
		if inventoryItemAtlasLookup[imagename] ~= nil then
			if inventoryItemAtlasLookup[imagename] ~= atlas then
				print("RegisterInventoryItemAtlas: Image '" .. imagename .. "' is already registered to atlas '" .. atlas .."'")
			end
		else
			inventoryItemAtlasLookup[imagename] = atlas
		end
	end
end

function GetInventoryItemAtlas(imagename, no_fallback)
	local atlas = inventoryItemAtlasLookup[imagename]
	if atlas then
		return atlas
	end
	local base_atlas = "images/inventoryimages1.xml"
	local alt_atlas = "images/inventoryimages2.xml"
	atlas = TheSim:AtlasContains(base_atlas, imagename) and base_atlas 
			or (not no_fallback or TheSim:AtlasContains(alt_atlas, imagename)) and alt_atlas
			or nil
	if atlas ~= nil then
		inventoryItemAtlasLookup[imagename] = atlas
	end
	return atlas
end

function FindTargetTagGroupEntitiesInRange(x, z, range, target_tag_group, not_tags)
	if not_tags ~= nil then
		not_tags = lume.concat(not_tags, { "INLIMBO" })
	else
		not_tags = { "INLIMBO" }
	end

	return TheSim:FindEntitiesXZ(x, z, range, nil, not_tags, target_tag_group)
end


function FindFriendliesInRange(x, z, range, not_tags)
	if not_tags ~= nil then
		not_tags = lume.concat(not_tags, { "INLIMBO" })
	else
		not_tags = { "INLIMBO" }
	end

	return TheSim:FindEntitiesXZ(x, z, range, nil, not_tags, TargetTagGroups.Players)
end

function FindEnemiesInRange(x, z, range, not_tags)
	if not_tags ~= nil then
		not_tags = lume.concat(not_tags, { "INLIMBO" })
	else
		not_tags = { "INLIMBO" }
	end

	return TheSim:FindEntitiesXZ(x, z, range, nil, not_tags, TargetTagGroups.Enemies)
end

function IsEntityInTargetTagGroup(ent, tag_group)
	for _, tag in ipairs(tag_group) do
		if ent:HasTag(tag) then
			return true
		end
	end
end
