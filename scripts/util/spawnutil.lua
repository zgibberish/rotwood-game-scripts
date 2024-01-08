local DebugDraw = require "util.debugdraw"
local kassert = require "util.kassert"
local lume = require "util.lume"
local krandom = require "util.krandom"

-- Functions for creating spawners
local spawnutil = {}

-- So we don't remove during PostLoadWorld
function spawnutil.FlagForRemoval(inst)
	inst.persists = false
	inst:DoTaskInTicks(0, inst.Remove)
end

function spawnutil.Spawn(inst, prefab)
	TheLog.ch.Spawn:printf("'%s' SPAWNS: '%s'", tostring(inst), prefab)
	local x, z = inst.Transform:GetWorldXZ()
	local ent = SpawnPrefab(prefab, inst)
	-- Intentionally ignoring snaptogrid here. If you want that snap, handle it
	-- yourself. We generally place spawners carefully and want spawned
	-- entities to match that position precisely.
	ent.Transform:SetPosition(x, 0, z)
	if ent.components.knownlocations ~= nil then
		ent.components.knownlocations:AddLocationXZ("spawnpt", x, z)
	end
	return ent
end

function spawnutil.SetFacing(inst, facing)
	local angle = 0 -- FACING_RIGHT
	if facing == FACING_UP then
		angle = -90
	elseif facing == FACING_LEFT then
		angle = 180
	elseif facing == FACING_DOWN then
		angle = 90
	end

	inst.Transform:SetRotation(angle)
end

function spawnutil.SetupPreviewPhantom(inst, prefab, alpha)
	assert(inst)
	assert(prefab)
	inst.SpawnPreviewPhantom = function(_inst)
		assert(_inst.preview == nil, tostring(_inst))
		_inst.preview = spawnutil.SpawnPreviewPhantom(_inst, prefab, alpha)
	end
	inst._ontogglepreviews = function(source, preview)
		-- If the inst preview state already matches the requested state, return.
		if (inst.preview ~= nil) == preview then
			return
		end

		-- Otherwise effect the requested preview state.
		if preview then
			inst:SpawnPreviewPhantom()
		else
			inst.preview:Remove()
			inst.preview = nil
		end
	end
	inst:ListenForEvent("editableeditor.togglepreviews", inst._ontogglepreviews, TheWorld)
end

-- Better to call SetupPreviewPhantom and let it handle toggling.
function spawnutil.SpawnPreviewPhantom(inst, prefab, alpha, optional_components_to_keep)
	alpha = alpha or 0.25
	TheLog.ch.Spawn:printf("'%s' SPAWNS phantom: '%s'", tostring(inst), prefab)

	local ent = DebugSpawn(prefab, { skipmove = true, })
	ent.persists = false

	-- Remove lots of logic
	TheFocalPoint.components.focalpoint:StopFocusSource(ent) -- for bosses
	ent:Stupify("SpawnPreviewPhantom")
	if ent.sg then
		-- Don't go to any states since they might have expect our object had
		-- other setup applied.
		ent.sg:Pause("SpawnPreviewPhantom")
		ent:Show() -- in case sg was hiding it
	end
	if ent.AnimState then
		ent.AnimState:Pause()
	end
	if ent.components.cineactor then
		ent.components.cineactor:RemoveAllEvents()
	end
	for _,cmp_key in ipairs({ 'Physics', 'HitBox', }) do
		local cmp = ent[cmp_key]
		if cmp then
			cmp:SetEnabled(false)
		end
	end
	if ent.components.offsethitboxes and ent.components.offsethitboxes:Has("flyinghitbox") then
		ent.components.offsethitboxes:SetEnabled("flyinghitbox", false)
	end
	local components = lume.keys(ent.components)
	-- These crash when removed from chemist.
	lume.remove(components, "bloomer")
	lume.remove(components, "coloradder")
	lume.remove(components, "colormultiplier")

	-- optional - keep certain components if needed for other stuff
	for _,v in pairs(optional_components_to_keep or {}) do
		lume.remove(components, v)
	end

	-- no targetting
	ent:RemoveTag("boss")
	ent:RemoveTag("mob")
	-- no interaction
	ent:RemoveTag("interactable")
	ent:AddTag("NOCLICK")

	-- We have to stay a prop so we can later remove ourselves from
	-- PropManager.
	lume.remove(components, "prop")
	if ent.components.prop then
		ent.components.prop:IgnoreEdits()
		ent.components.prop.ListenForEdits = function() end
	end

	for _,cmp_key in ipairs(components) do
		ent:RemoveComponent(cmp_key)
	end
	ent:CancelAllTasks()

	-- Ghost it.
	local colormultiplier = ent.components.colormultiplier or ent:AddComponent("colormultiplier")
	colormultiplier:PushColor("SpawnPreviewPhantom", 1,1,1, alpha)

	-- We're beyond created_by_debugspawn or OnEditorSpawn: we strip off
	-- normally necessary functionality to get a visual.
	ent:PushEvent("debug_spawned_as_preview")

	ent.entity:SetParent(inst.entity)
	-- HACK(dbriscoe): Must wait 2 ticks after creating child. Any less and
	-- *sometimes* child is double offset.
	inst:DoTaskInTicks(2, function(inst_)
		ent.Transform:SetPosition(0,0,0)
		if ent.components.prop and TheWorld.components.propmanager then
			TheWorld.components.propmanager:Debug_ForceUnregisterProp(ent)
		end
	end)

	inst.OnRemoveEntity = function(self)
		self:RemoveEventCallback("editableeditor.togglepreviews", inst._ontogglepreviews)
		if inst.preview then
			inst.preview:Remove()
		end
		inst.preview = nil
	end

	return ent
end

-- World editing setup all of our spawners use.
function spawnutil.MakeEditable(inst, shape)
	if not inst.AnimState then
		inst.entity:AddAnimState()
	end
	inst.AnimState:SetBank("mouseover")
	inst.AnimState:SetBuild("mouseover")
	inst.AnimState:SetMultColor(table.unpack(WEBCOLORS.RED))
	inst.AnimState:PlayAnimation(shape)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(1)
	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
end

function spawnutil.GetEditableAssets()
	return {
		Asset("ANIM", "anim/mouseover.zip"),
	}
end

-- Common setup all of our spawners use.
function spawnutil.CreateBasicSpawner()
	local inst = CreateEntity()

	inst.entity:AddTransform()

	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]

	inst:AddComponent("prop")
	-- The spawner snaps to grid position so what it spawns doesn't need to snap.
	inst:AddComponent("snaptogrid")
	return inst
end


-- Pattern spawners use `{ prefab="crab", x=10, z=20 }` format for pattern
-- placements instead of the format of our prefab _autogen file:
-- `crab = { {x=10, z=20}, ... }`. Copying the autogen format would allow us
-- to copypaste from _propdata files, but it's harder to operate on all the
-- placements. It requires nested loops which make it hard to compare all
-- placements equally (see LimitPatternToClosestN).
function spawnutil.CreatePatternSpawner()
	local inst = CreateEntity()

	inst.entity:AddTransform()

	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]

	inst:AddComponent("prop")
	return inst
end

-- Do not use for logic!
local function ValidatePattern(pattern)
	local first_placement = pattern[1]
	dbassert(first_placement.prefab)
	dbassert(first_placement.v.x)
	dbassert(first_placement.v.z)
	dbassert(not isbadnumber(first_placement.v.x))
	dbassert(not isbadnumber(first_placement.v.z))
	return first_placement.v.z ~= nil
end

function spawnutil.GetPossiblePrefabsFromPatterns(patterns)
	dbassert(ValidatePattern(patterns[1]))
	local prefabs = {}
	for _,pattern in ipairs(patterns) do
		for _,place in ipairs(pattern) do
			prefabs[place.prefab] = true
		end
	end
	return lume.keys(prefabs)
end

function spawnutil.CenterPatternsOnOrigin(patterns)
	-- Center patterns on origin so they will spawn centred on the spawner.
	for _,pat in ipairs(patterns) do
		local sum = Vector3()
		for _,place in ipairs(pat) do
			place.v = Vector3(place.x, 0, place.z)
			place.x = nil
			place.z = nil
			sum = sum + place.v
		end
		sum = sum / #pat
		for _,place in ipairs(pat) do
			place.v = place.v - sum
		end
	end
	return patterns
end

function spawnutil.DrawPatternLocation(inst, patterns, index_to_display)
	inst.pat_edit = inst.pat_edit or {}
	index_to_display = index_to_display or inst.pat_edit.displayed_index or 1
	local colors = {
		WEBCOLORS.SPRINGGREEN,
		WEBCOLORS.YELLOW,
		WEBCOLORS.BISQUE,
		WEBCOLORS.PURPLE,
		WEBCOLORS.LIGHTSKYBLUE,
		WEBCOLORS.LAVENDER,
	}
	local color_map = {}
	local x, z = inst.Transform:GetWorldXZ()
	for i,pat in ipairs(patterns) do
		if i == index_to_display then
			for _,place in ipairs(pat) do
				-- Draw each prefab with a unique colour.
				local c = color_map[place.prefab] or circular_index(colors, lume.count(color_map))
				color_map[place.prefab] = c
				DebugDraw.GroundCircle(x + place.v.x, z + place.v.z, 2, c)
			end
		end
	end
end

local function remove_debug_spawn(inst)
	if inst.pat_edit.spawned then
		local spawned = inst.pat_edit.spawned
		inst.pat_edit.spawned = nil
		for _,ent in ipairs(spawned) do
			ent:Remove()
		end
	end
end
function spawnutil.PatternsEditor(inst, ui, patterns, face_pos, enemies_for_room)
	inst.pat_edit = inst.pat_edit or {
		onremove = function(ent)
			if inst.pat_edit.spawned then
				lume.remove(inst.pat_edit.spawned, ent)
			end
		end,
	}

	ui:Text("Lines to portals show which allow this spawner can activate.")

	local i = inst.pat_edit.displayed_index or 1
	i = ui:_SliderInt("Visualized spawn pattern", i, 1, #patterns)
	inst.pat_edit.displayed_index = i
	if ui:Button("Debug Spawn") then
		-- Debug spawn is useful to set a nice layout for the pattern, save,
		-- and copypaste from the propdata to the prefab's pattern list.
		remove_debug_spawn(inst)
		local pattern = patterns[inst.pat_edit.displayed_index]
		inst.pat_edit.spawned = spawnutil.SpawnPattern(inst, pattern, face_pos)
		for _,ent in ipairs(inst.pat_edit.spawned) do
			inst:ListenForEvent("onremove", inst.pat_edit.onremove, ent)
			if ent.SetBrain then
				ent:SetBrain()
			end
			if not ent.components.prop then
				-- Allow us to drag it around to position it.
				ent:AddComponent("prop")
			end
		end
	end
	if ui:Button("Clear Debug Spawn") then
		remove_debug_spawn(inst)
	end
	if inst.pat_edit.spawned and ui:Button("Print Debug Spawn") then
		local spawn_world_center = inst:GetPosition()
		local pat = {}
		for _,ent in ipairs(inst.pat_edit.spawned) do
			local v = ent:GetPosition() - spawn_world_center
			table.insert(pat, {
					prefab = ent.prefab,
					x = v.x,
					z = v.z,
				})
		end
		if enemies_for_room then
			local enemy_categories = lume.invert(enemies_for_room)
			lume.each(pat, function(v)
				v.prefab = enemy_categories[v.prefab]
			end)
		end
		-- prefabs only use 2 decimal places, so that's good for us too.
		local block = serpent.block(pat, { numformat = "%.3g", })
		print(("Copy and paste this into your spawner patterns (pattern %d):\n\n%s"):format(i, block))
	end
	-- we're not modifying anything important, so return false.
	return false
end

function spawnutil.LimitPatternToValidGround(pattern, spawn_world_center)
	pattern = deepcopy(pattern)
	lume.removeswap(pattern, function(s)
		local pos = spawn_world_center + s.v
		return not TheWorld.Map:IsWalkableAtXZ(pos.x, pos.z)
	end)
	return pattern
end

local function cmp_shortest_v(a, b)
	return a.v:LengthSq() < b.v:LengthSq()
end
function spawnutil.LimitPatternToClosestN(pattern, n)
	kassert.typeof('number', n)
	pattern = deepcopy(pattern)
	table.sort(pattern, cmp_shortest_v)
	while n < #pattern do
		table.remove(pattern)
	end
	return pattern
end

function spawnutil.SpawnPattern(inst, pattern, face_pos)
	dbassert(#pattern > 0, "Was spawner placed outside of world?") -- LimitPatternToValidGround may have removed all
	dbassert(ValidatePattern(pattern))
	local spawned = {}
	local spawn_world_center = inst:GetPosition()
	for _,place in ipairs(pattern) do
		local pos = place.v + spawn_world_center
		if TheWorld.Map:IsWalkableAtXZ(pos.x, pos.z) then
			TheLog.ch.Spawn:printf("'%s' SPAWNS: '%s'", tostring(inst), place.prefab)
			-- Don't push events (like spawnenemy) here. Let caller handle it.
			local ent = SpawnPrefab(place.prefab, inst)
			kassert.assert_fmt(ent, "Invalid prefab %s. Did you run updateprefabs?", place.prefab)
			if ent.components.snaptogrid ~= nil then
				pos.x, pos.y, pos.z = ent.components.snaptogrid:SetNearestGridPos(pos.x, 0, pos.z, false)
			else
				ent.Transform:SetPosition(pos.x, 0, pos.z)
			end
			if face_pos then
				ent:FacePoint(face_pos)
			end
			if ent.components.knownlocations ~= nil then
				ent.components.knownlocations:AddLocationXZ("spawnpt", pos:GetXZ())
			end
			table.insert(spawned, ent)
		end
	end
	return spawned
end

local function OffsetEntityPosition(inst, dx, dy, dz)
	local x,y,z = inst.Transform:GetWorldPosition()
	inst.Transform:SetPosition(x + dx, y + dy, z + dz)
	return inst
end

-- Add Label to existing object.
function spawnutil.AddWorldLabel(inst, text)
	inst.entity:AddLabel()

	inst.Label:SetFontSize(1)
	inst.Label:SetFont(FONTFACE.DEFAULT)
	inst.Label:SetColor(table.unpack(WEBCOLORS.WHITE))
	inst.Label:Enable(true)
	inst.Label:SetText(text)

	return inst
end

-- Labels useful for debug or placeholder.
function spawnutil.SpawnWorldLabel(text, pos)
	assert(pos)
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	spawnutil.AddWorldLabel(inst, text)

	inst.Transform:SetPosition(pos:unpack())

	inst:AddTag("FX")
	--[[Non-networked entity]]
	inst.persists = false

	inst.Offset = OffsetEntityPosition

	return inst
end

-- Function for setting up color properties on charmed prefabs
function spawnutil.ApplyCharmColors(inst, owner, tuning_name)
	local charmed = owner:HasTag("playerminion")
	if charmed and TUNING[owner.prefab] then
		tuning_name = tuning_name and "charm_colors_" .. tuning_name or "charm_colors"
		-- charmed colouring
		local color_add = TUNING[owner.prefab][tuning_name] ~= nil and TUNING[owner.prefab][tuning_name].color_add or TUNING.default_charm_colors.color_add
		local color_mult = TUNING[owner.prefab][tuning_name] ~= nil and TUNING[owner.prefab][tuning_name].color_mult or TUNING.default_charm_colors.color_mult
		local bloom = TUNING[owner.prefab][tuning_name] ~= nil and TUNING[owner.prefab][tuning_name].bloom or TUNING.default_charm_colors.bloom

		inst.components.coloradder:PushColor("charmed", color_add[1], color_add[2], color_add[3], color_add[4])
		inst.components.colormultiplier:PushColor("charmed", color_mult[1], color_mult[2], color_mult[3], color_mult[4])
		inst.components.bloomer:PushBloom("charmed", bloom[1], bloom[2], bloom[3], bloom[4])
	end
end

-- Function for getting a point within the walkable bounds from a percentage of the width & height of the bounds.
function spawnutil.GetStartPointFromWorld(percent_x, percent_z)
	local minx, minz, maxx, maxz = TheWorld.Map:GetWalkableBounds()
	local w, h = maxx - minx, maxz - minz
	local pt = Vector3(minx + w * percent_x, 0, minz + h * percent_z)

	return pt
end

---------------------------------------------------------------------
-- Common initialization function for projectiles
---------------------------------------------------------------------
-- Possible parameters for 'data':
-- name: Assign a name to the object.
-- hits_targets: Flag to enable collision interactions with other objects.
-- hit_group = Assign hit group for the object.
-- hit_flags = Assign hit flags for the object.
-- does_hitstop: Applies hitstop to hit targets.
-- health: The amount of health the projectile has.
-- twofaced: The projectile can face a direction (left or right)
-- bank, build: The animation bank & build files for this object.
-- start_anim: The starting animation to play. The looping parameter is set to true on PlayAnimation()
-- fx_prefab: prefab fx to attach to the object as a child.
-- stategraph: Use a specified stategraph file with this object. Note that the 'name' parameter must also be defined if this is specified.
-- no_healthcomponent: Do not add a health component to this object.

function spawnutil.SetupProjectileCommon(data)
	local fx_prefab = data.fx_prefab and Prefabs[data.fx_prefab]
	local inst = fx_prefab and fx_prefab.fn(data.fx_prefab) or CreateEntity()

	inst:AddTag("projectile")

	-- The below has already been defined in fx_prefab.fn (see MakeAutogenFx() function)
	if not fx_prefab then
		if data.name then
			inst:SetPrefabName(data.name)
		end

		inst.entity:AddTransform()

		if data.bank and data.build then
			inst.entity:AddAnimState()

			inst.AnimState:SetBank(data.bank)
			inst.AnimState:SetBuild(data.build)
			inst.AnimState:SetShadowEnabled(true)

			if data.start_anim then
				inst.AnimState:PlayAnimation(data.start_anim, true)
			end
		end

		inst:AddComponent("bloomer")
		inst:AddComponent("colormultiplier")
		inst:AddComponent("coloradder")

		if data.does_hitstop then
			inst:AddComponent("hitstopper")
		end

		if data.twofaced then
			inst.Transform:SetTwoFaced()
		end

		inst.persists = false
	end

	-- Add sound emitter component if it hasn't been added already.
	if not inst.SoundEmitter then
		inst.entity:AddSoundEmitter()
	end

	-- The following needs to be defined for regular & fx prefabs.
	if data.hits_targets then
		inst.entity:AddHitBox()
		inst:AddComponent("hitbox")
		inst:AddComponent("combat")
		inst:AddComponent("projectilehitbox")

		if data.hit_group then
			inst.components.hitbox:SetHitGroup(data.hit_group)
		end

		if data.hit_flags then
			inst.components.hitbox:SetHitFlags(data.hit_flags)
		end
	end

	if not data.no_healthcomponent then
		-- Some projectiles do not want a health component
		inst:AddComponent("health")
		inst.components.health:SetMax(data.health or 1, true)
	end

	assert(data.stategraph == nil or (data.stategraph and data.name), "SetupProjectileCommon has a stategraph parameter defined, but needs a name parameter defined as well!")
	if data.stategraph then
		inst:SetStateGraph(data.stategraph)
	end

	return inst
end

local function UpdateCheckAlive(inst, updates_before_remove)
	if TheWorld.Map:IsGroundAtXZ(inst.Transform:GetWorldXZ()) then
		inst.removecounter = 0
	elseif inst.removecounter < (updates_before_remove or 1) then
		inst.removecounter = inst.removecounter + 1
	else
		inst:PushEvent("projectileremoved")
		inst.updatecheckalivetask:Cancel()
		inst.updatecheckalivetask = nil
		inst:Hide()
		if inst:IsLocal() then
			inst:Remove()
		end
	end
end

local function OnBulletCollided(inst, other)
	if not inst.bulletcollidedtask then
		inst:Hide()
		inst.bulletcollidedtask = inst:DoTaskInTicks(2, function()
			if inst:IsLocal() then -- do test here just so verbosenetworklogging doesn't get spammed
				inst:Remove()
			end
		end)
		inst:PushEvent("projectileremoved")
	end
end

-- Initialization function for regular projectiles
-- Possible parameters for 'data' (see SetupProjectileCommon for more parameters):
-- physics_size: The physics size of the object.
-- motor_vel: The motor velocity of the object.
-- collision_callback: Function to call when colliding with an object.
-- outofbounds_timeout: Number of times to perform (1 per second) UpdateCheckAlive() before calling Remove(). Set to < 0 to keep alive permanently.

function spawnutil.CreateProjectile(data)
	local inst = spawnutil.SetupProjectileCommon(data)

	MakeProjectilePhysics(inst, data.physics_size or 1)

	if data.motor_vel then
		inst.Physics:SetMotorVel(data.motor_vel)
	end

	inst.Physics:SetCollisionCallback(data.collision_callback or OnBulletCollided)

	inst:AddTag("NOCLICK")

	-- Check to see if a projectile flies out of bounds.
	if data.outofbounds_timeout == nil or data.outofbounds_timeout >= 0 then
		inst.removecounter = 0
		inst.updatecheckalivetask = inst:DoPeriodicTask(1, UpdateCheckAlive, 0, data.outofbounds_timeout)
	end

	return inst
end

function spawnutil.CollectProjectileAssets(assets, prefabs, data)
	table.insert(prefabs, data.fx_prefab)
	return assets, prefabs
end

-- Initialization function for complex projectiles
function spawnutil.CreateComplexProjectile(data)
	local inst = spawnutil.SetupProjectileCommon(data)

	inst:AddComponent("complexprojectile")

	return inst
end

---------------------------------------------------------------------
-- Spawn a prefab in a pattern functions
---------------------------------------------------------------------
-- Return a random offset value from -x to x
local function GetRandomOffset(x)
	return krandom.Float(x * 2) - x
end

local NO_PREFAB_ERROR_MSG = "No prefab specified for pattern spawn."

-----------------------------------------------------------
-- Spawn prefabs at random positions.
-----------------------------------------------------------
-- Data parameters:
-- padding_from_edge - Sets padding from edge when calling TheWorld.Map:GetRandomPointInWalkable()
-- spawn_delay - Time to delay spawning each prefab.
-- spawn_fn - function to run after the prefab is created.
-- avoid_position - {x, z, proximity} if a position candidate is within [proximity] of [x,z], skip that position

function spawnutil.SpawnRandom(prefab_to_spawn, num_to_spawn, data)

	assert(prefab_to_spawn ~= nil, NO_PREFAB_ERROR_MSG)
	local delay = data.spawn_delay or 0

	local current_delay = 0
	for i = 1, num_to_spawn do
		current_delay = current_delay + delay
		TheWorld:DoTaskInTime(current_delay, function(inst)
			local prefab = SpawnPrefab(prefab_to_spawn, data.instigator)

			if prefab then
				-- Find a random walkable position on the map to spawn at
				local pos = TheWorld.Map:GetRandomPointInWalkable(data.padding_from_edge or 0)
				prefab.Transform:SetPosition(pos:Get())

				if data.spawn_fn then
					data.spawn_fn(prefab)
				end
			end
		end)
	end
end

-----------------------------------------------------------
-- Spawn prefabs in a line.
-----------------------------------------------------------
-- Data parameters:
-- start_pt - Vector3 position to spawn the first prefab.
-- angle - Angle, in degrees, of direction of the line in world space. (0 = pointing right)
-- padding - Distance between each spawned prefab.
-- spawn_delay - Time to delay spawning each prefab.
-- random_offset - {x, y} random offset to apply to the spawned prefab, in the direction it's pointing. x = along direction, y = perpendicular to direction.
-- spawn_fn - function to run after the prefab is created.
-- avoid_position - {pos, proximity} if a position candidate is within [proximity] of {x,y,z}, skip that position

function spawnutil.SpawnLine(prefab_to_spawn, num_to_spawn, data)
	assert(prefab_to_spawn ~= nil, NO_PREFAB_ERROR_MSG)

	local start_pos = (data.start_pt or Vector3.zero)

	local angle = math.rad(data.angle or 0)
	local dir = Vector3(math.cos(angle), 0, math.sin(angle))

	local padding = data.padding or 0
	local delay = data.spawn_delay or 0
	local current_delay = 0

	for i = 1, num_to_spawn do
		current_delay = current_delay + delay
		TheWorld:DoTaskInTime(current_delay, function()
			local offset = dir * padding * (i - 1)
			local pos = start_pos + offset

			-- Add some random offset to each prefab position.
			local random_offset_x = GetRandomOffset(data.random_offset and data.random_offset[1] or 0)
			local random_offset_z = GetRandomOffset(data.random_offset and data.random_offset[2] or 0)
			local perpvec = Vector2.perpendicular(Vector2(dir.x, dir.z))

			pos = pos + dir * random_offset_x + Vector3(perpvec.x, 0, perpvec.y) * random_offset_z

			local should_spawn = true
			if data.avoid_position then
				local avoid_pos = data.avoid_position.pos
				local dist = DistSq2D(pos.x, pos.z, avoid_pos.x, avoid_pos.z)
				if dist <= data.avoid_position.proximity then
					should_spawn = false
				end
			end
			if should_spawn then
				local prefab = SpawnPrefab(prefab_to_spawn, data.instigator)

				if prefab then

					prefab.Transform:SetPosition(pos:Get())

					if data.spawn_fn then
						data.spawn_fn(prefab)
					end
				end
			end
		end)
	end
end

-----------------------------------------------------------
-- Spawn prefabs in a cross.
-----------------------------------------------------------
-- Data parameters:
-- center_pt - Vector3 position of the center of the cross.
-- start_percent_a, start_percent_b - Percentage of the length of the a, b lines from the start_pt where the a, b lines start, e.g. 0.5 creates a line centered on the start_pt. Length is calculated as (num_to_spawn - 1) * padding
-- angle_a, angle_b - Angle, in degrees, of direction of the a & b lines in world space. (0 = pointing right).
-- padding_a, padding_b - Distance between each spawned prefab on the a & b lines.
-- spawn_delay - Time to delay spawning each prefab.
-- random_offset - {x, y} random offset to apply to the spawned prefab, in the direction it's pointing. x = along direction, y = perpendicular to direction.
-- spawn_fn - function to run after the prefab is created.
-- avoid_position - {x, z, proximity} if a position candidate is within [proximity] of [x,z], skip that position

function spawnutil.SpawnCross(prefab_to_spawn, num_to_spawn_a, num_to_spawn_b, data)
	assert(prefab_to_spawn ~= nil, NO_PREFAB_ERROR_MSG)
	assert(not(num_to_spawn_a <= 0 and num_to_spawn_b <= 0), "The number of prefabs to spawn is zero!")

	-- Calculate start x, y points
	local start_percent_a, start_percent_b = data.start_percent_a or 0.5, data.start_percent_b or 0.5
	local padding_a, padding_b = data.padding_a or 1, data.padding_b or 1
	local length_a = (num_to_spawn_a - 1) * padding_a
	local length_b = (num_to_spawn_b - 1) * padding_b

	local angle_a = math.rad(data.angle_a or 0)
	local angle_b = math.rad(data.angle_b or 90)

	local dir_a = Vector3(math.cos(angle_a), 0, math.sin(angle_a))
	local dir_b = Vector3(math.cos(angle_b), 0, math.sin(angle_b))

	local center_pos = (data.center_pt or Vector3.zero)
	local start_pos_a = center_pos - dir_a * length_a * start_percent_a
	local start_pos_b = center_pos - dir_b * length_b * start_percent_b

	local delay = data.spawn_delay or 0
	local current_delay = 0

	local function SpawnLineSegment(num_to_spawn, start_pos, dir, padding)
		for i = 1, num_to_spawn do
			current_delay = current_delay + delay
			TheWorld:DoTaskInTime(current_delay, function()
				local offset = dir * padding * (i - 1)
				local pos = start_pos + offset

				-- Add some random offset to each prefab position.
				local random_offset_x = GetRandomOffset(data.random_offset and data.random_offset[1] or 0)
				local random_offset_z = GetRandomOffset(data.random_offset and data.random_offset[2] or 0)
				local perpvec = Vector2.perpendicular(dir)

				pos = pos + dir * random_offset_x + Vector3(perpvec.x, 0, perpvec.y) * random_offset_z

				local should_spawn = true
				if data.avoid_position then
					local dist = DistSq2D(pos.x, pos.z, data.avoid_position.pos.x, data.avoid_position.pos.z)
					if dist <= data.avoid_position.proximity then
						should_spawn = false
					end
				end

				if should_spawn then
					local prefab = SpawnPrefab(prefab_to_spawn, data.instigator)

					if prefab then

						prefab.Transform:SetPosition(pos:Get())

						if data.spawn_fn then
							data.spawn_fn(prefab)
						end
					end
				end
			end)
		end
	end

	-- Spawn line A, then B if delay is active.
	SpawnLineSegment(num_to_spawn_a, start_pos_a, dir_a, padding_a)
	SpawnLineSegment(num_to_spawn_b, start_pos_b, dir_b, padding_b)
end

-----------------------------------------------------------
-- Spawn prefabs at equally distributed points around a circle.
-----------------------------------------------------------
-- Data parameters:
-- start_pt - The center point where all prefabs are equidistant from one another.
-- radius - Distance from the start_pt to spawn prefabs.
-- start_angle - Angle, in degrees, to determine the position of the first prefab to spawn.
-- end_angle - Angle, in degrees, to determine the max angle to spawn prefabs at. Use to spawn things in arcs.
-- spawn_delay - Time to delay spawning each prefab.
-- random_offset - {x, y} random offset to apply to the spawned prefab, in the direction it's pointing. x = along direction, y = perpendicular to direction.
-- spawn_fn - function to run after the prefab is created.
-- avoid_position - {x, z, proximity} if a position candidate is within [proximity] of [x,z], skip that position

function spawnutil.SpawnShape(prefab_to_spawn, num_to_spawn, data)
	assert(prefab_to_spawn ~= nil, NO_PREFAB_ERROR_MSG)

	local center_pos = (data.start_pt or Vector3.zero)
	local radius = data.radius or 0
	local start_angle = math.rad(data.start_angle or 0)
	local current_angle = start_angle

	assert(num_to_spawn > 0, "The number of prefabs to spawn is zero!")
	local angle_delta = math.rad((data.end_angle or 360)/ num_to_spawn)

	local delay = data.spawn_delay or 0
	local current_delay = 0

	for i = 1, num_to_spawn do
		current_delay = current_delay + delay
		TheWorld:DoTaskInTime(current_delay, function()
			local dir = Vector3(math.cos(current_angle), 0, math.sin(current_angle))
			local pos = center_pos + dir * radius

			-- Add some random offset to each prefab position.
			local random_offset_x = GetRandomOffset(data.random_offset and data.random_offset[1] or 0)
			local random_offset_z = GetRandomOffset(data.random_offset and data.random_offset[2] or 0)

			pos.x = pos.x + random_offset_x
			pos.z = pos.z + random_offset_z

			local should_spawn = true
			if data.avoid_position then
				local dist = DistSq2D(pos.x, pos.z, data.avoid_position.pos.x, data.avoid_position.pos.z)
				if dist <= data.avoid_position.proximity then
					should_spawn = false
				end
			end

			if should_spawn then
				local prefab = SpawnPrefab(prefab_to_spawn, data.instigator)

				if prefab then

					prefab.Transform:SetPosition(pos:Get())

					if data.spawn_fn then
						data.spawn_fn(prefab)
					end
				end
			end

			current_angle = current_angle + angle_delta
		end)
	end
end

---------------------------------------------------------------------
-- Common initialization function for AoEs
---------------------------------------------------------------------

local function _setup_aoe(inst, data, owner, ...)
	-- body
	inst.owner = owner

	inst.components.jointaoechild:Setup(data)
	inst.components.jointaoechild:OnSpawn()

	if data.setup_fn then
		data.setup_fn(inst, owner, ...)
	end
end

function spawnutil.SetupAoECommon(data)
	local inst = CreateEntity()

	if data.name then
		inst:SetPrefabName(data.name)
	end

	if data.fx_prefab then
		inst.fx = SpawnPrefab(data.fx_prefab, inst)
		inst.fx.entity:SetParent(inst.entity)
	end

	inst.entity:AddTransform()
	inst.entity:AddHitBox()

	inst:AddComponent("jointaoechild")

	assert(data.stategraph == nil or (data.stategraph and data.name), "SetupAoECommon has a stategraph parameter defined, but needs a name parameter defined as well!")
	if data.stategraph then
		inst:SetStateGraph(data.stategraph)
	end

	inst.persists = false

	inst.Setup = function(inst, data, owner, ...) _setup_aoe(inst, data, owner, ...) end

	return inst
end

return spawnutil
