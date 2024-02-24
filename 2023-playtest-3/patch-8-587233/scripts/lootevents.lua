LootEvents = {}

local kLuckyLootDelay = 1 -- seconds to wait for luck wrapper to reveal loot

local function BreakCountIntoPrefabs(loot, amount)
	local current_amount = amount
	local thresholds = loot.components.loot.count_thresholds
	local spawn_amounts = {}

	if thresholds ~= nil and #thresholds > 0 then -- count thresholds have been set up, so let's see how we should break this 'amount' up
		local highest_tier = nil
		while current_amount > 0 do
			-- If we're lower than the lowest configured threshold, just spawn that piece 
			if current_amount <= thresholds[1].count then
				table.insert(spawn_amounts, current_amount)
				current_amount = 0
				break
			else
				for _,tier in pairs(thresholds) do
					if current_amount >= tier.count then
						highest_tier = tier
					else
						break
					end
				end
				if highest_tier.count ~= nil then
					table.insert(spawn_amounts, highest_tier.count)
					current_amount = current_amount - highest_tier.count
				end
			end
		end
	else
		-- We don't have count thresholds, so just spawn a bunch of 1-offs
		for i=1,amount do
			table.insert(spawn_amounts, 1)
			amount = amount - 1
		end
	end
	--debug to see what the split was
	--dumptable(spawn_amounts)
	return spawn_amounts
end

local function PlaceLootInternal(instigator, loot, rot1, rot2)
	local n = #loot
	if n > 0 then
		local x, z = instigator.Transform:GetWorldXZ()
		local delta = (rot2 - rot1) / n
		local var = delta / (n > 1 and 3 or 2)
		rot1 = rot1 + delta * .5
		for i = n, 1, -1 do
			local rnd = math.random(i)
			local rot = rot1 + var * (math.random() * 2 - 1)
			local theta = math.rad(rot)
			local radius = .1 --Just off center in case loot does collide with this inst
			local ent = loot[rnd]
			ent.Transform:SetPosition(x + radius * math.cos(theta), 0, z - radius * math.sin(theta))
			ent.Transform:SetRotation(rot)
			loot[rnd] = loot[i]
			loot[i] = nil
			rot1 = rot1 + delta
		end
	end
end

-- instigator needs a Transform and optionally a hitstopper component
function LootEvents.SpawnLootFromMaterials(instigator, loot, owner, lucky)
	-- takes a table of { material = count } and builds a drop table of { prefab = count } based on the list.
	-- has some special logic to prevent the loot from clumping too much when the loot has count threshold art.
	local facing = instigator.Transform:GetFacing()
	local spawned = {}
	local front, back, any = {}, {}, {}

	for id, count in pairs(loot) do
		local drop_prefab = string.format("drop_%s", id)
		local ent = SpawnPrefab(drop_prefab, instigator)
		table.insert(spawned, ent)

		if count > 1 then
			local spawn_counts = BreakCountIntoPrefabs(ent, count)
			local num_to_spawn = #spawn_counts
			local ents = { ent }

			while #ents < num_to_spawn do
				local split_ent = SpawnPrefab(drop_prefab, instigator)
				table.insert(ents, split_ent)
				table.insert(spawned, split_ent)
			end

			for i, spl in ipairs(ents) do
				spl.components.loot:SetCount(spawn_counts[i])
			end
		end
	end

	for i, ent in ipairs(spawned) do
		if owner then
			ent.components.loot:SetOwner(owner)
			-- Don't add to lootvacuum yet. The owner will ensure the right
			-- person sucks it up.
		end

		if lucky then
			ent.components.loot:MakeLootLucky()
		end

		if ent.autofacing then
			if facing == FACING_LEFT then
				ent.AnimState:SetScale(-1, 1)
			end
		elseif ent.reversefacing then
			if facing == FACING_RIGHT then
				ent.AnimState:SetScale(-1, 1)
			end
		end
		if ent.droppos == "front" then
			front[#front + 1] = ent
		elseif ent.droppos == "back" then
			back[#back + 1] = ent
		else
			any[#any + 1] = ent
		end

		-- test if instigator is in limbo, probably due to networking latency
		if not instigator:IsInLimbo() and instigator.components.hitstopper ~= nil then
			instigator.components.hitstopper:AttachChild(ent)
		end
	end

	--Distribute the loot evenly between front and back
	while #any > 0 do
		local rnd = math.random(#any)
		if #front < #back or (#front == #back and math.random() < .5) then
			front[#front + 1] = any[rnd]
		else
			back[#back + 1] = any[rnd]
		end
		any[rnd] = any[#any]
		any[#any] = nil
	end

	--Now move and rotate all the loot
	local rot = instigator.Transform:GetRotation()
	local spread = 45
	PlaceLootInternal(instigator, front, rot - spread, rot + spread)
	PlaceLootInternal(instigator, back, rot + 180 - spread, rot + 180 + spread)
end

function LootEvents.HandleEventDropLoot(instigator, loot_to_drop, lucky_loot)
	for owner, loot in pairs(loot_to_drop) do
		LootEvents.SpawnLootFromMaterials(instigator, loot, owner)
	end

	if next(lucky_loot) then
		local delayed_spawn = CreateEntity()
		delayed_spawn.entity:AddTransform()
		delayed_spawn:AddComponent("lootdropper")

		local pos = instigator:GetPosition()
		delayed_spawn.Transform:SetPosition(pos.x, 0, pos.z)

		delayed_spawn:DoTaskInTime(kLuckyLootDelay, function()
			local particles = SpawnPrefab("lucky_loot_explosion")
			particles.Transform:SetPosition(pos.x, 0, pos.z)
			particles:DoTaskInTime(1, particles.Remove)

			for owner, loot in pairs(lucky_loot) do
				LootEvents.SpawnLootFromMaterials(delayed_spawn, loot, owner, true)
			end
			delayed_spawn:Remove()
		end)
	end
end

-- This spawns loot for remote players; local players should still spawn local loot via SpawnLootFromMaterials
function LootEvents.MakeEventGenerateLoot(spawningEntity, loot_to_drop, lucky_loot, ignore_post_death)
	-- TheLog.ch.Networking:printf("Sending MakeEventGenerateLoot")
	-- dumptable(loot_to_drop, nil, 3)
	-- dumptable(lucky_loot, nil, 3)
	TheNetEvent:GenerateLoot(spawningEntity.GUID, loot_to_drop, lucky_loot, ignore_post_death)
end

-- This is remotely generated loot, so do the drop "now"
-- Network special case: Remote loot drops are not synchronized due to latency.
-- They may not respect hitstop or spawn in the same spot due to RNG use.
-- The important thing is that it shows and will be collected by the remote entities
-- without need to synchronize all the entities, their movement, etc.
function LootEvents.HandleEventGenerateLoot(spawningEntity, loot_to_drop, lucky_loot, ignore_post_death)
	LootEvents.HandleEventDropLoot(spawningEntity, loot_to_drop, lucky_loot)

	if ignore_post_death then
		return
	end

	-- Try to spawn the local loot since explicit OnDeath events are not triggered via health component sync :/
	-- This can cause another GenerateLoot event to be sent to remote clients, including
	-- the client where the death originally occurred so they can spawn the remote loot too
	-- To keep this from infinitely recurring, loot dropper maintains a list of players processed
	if spawningEntity.components.lootdropper and not spawningEntity.components.lootdropper:HasDropped() then
		spawningEntity.components.lootdropper:OnDeath()
		spawningEntity.components.lootdropper:DropLoot()
	end
end

-- how to only send to host?
function LootEvents.MakeEventRequestSpawnCurrency(deadEntity)
	-- hosts can just handle it directly
	if not TheNet:IsHost() then
		-- TheLog.ch.LootEvents:printf("LootEvents.MakeEventRequestSpawnCurrency guid=%s", tostring(deadEntity.GUID))
		TheNetEvent:RequestSpawnCurrency(deadEntity.GUID)
	else
		LootEvents.HandleEventRequestSpawnCurrency(deadEntity)
	end
end

function LootEvents.HandleEventRequestSpawnCurrency(deadEntity)
	if TheNet:IsHost() and TheWorld and TheWorld.components.konjurrewardmanager ~= nil then
		TheWorld.components.konjurrewardmanager:OnEnemyDeath(deadEntity)
	end
end

function LootEvents.DisplayKonjurAmountInWorld(inst, amount)
	local hud = TheDungeon.HUD
	if hud then
		-- TheLog.ch.LootEvents:printf("Display position: %1.2f,%1.2f,%1.2f", inst:GetPosition():unpack())
		hud:MakePopText(
			{
				target = inst,
				button = string.format(STRINGS.UI.INVENTORYSCREEN.KONJUR, amount),
				color = UICOLORS.KONJUR,
				size = 65,
				fade_time = amount >= 10 and 3 or 1
			})
	end
end

-- owner is a player entity instance -- change to a playerID?
function LootEvents.MakeEventSpawnCurrency(amount, pos, owner, isLucky, showAmount)
	TheNetEvent:SpawnCurrency(amount, pos, owner and owner.GUID or 0, isLucky, showAmount)
end

local DummyKonjurEnt -- reusable, placeholder ent for konjur to utilize loot spawn + placement logic
local TempKonjurDropTable = { konjur = 0 } -- reduce Lua garbage by reusing the table

function LootEvents.HandleEventSpawnCurrency(amount, pos, owner, isLucky, showAmount)
	if not isLucky then
		TempKonjurDropTable["konjur"] = amount
		if not DummyKonjurEnt then
			DummyKonjurEnt = CreateEntity()
				:MakeSurviveRoomTravel()
			DummyKonjurEnt.persists = false
			DummyKonjurEnt.entity:AddTransform()
		else
			DummyKonjurEnt:ReturnToScene()
		end
		DummyKonjurEnt.Transform:SetPosition(pos:unpack())

		-- For one player (power skip, konjur-dropping power, etc), or all?
		if owner then
			LootEvents.SpawnLootFromMaterials(DummyKonjurEnt, TempKonjurDropTable, owner)
		else
			local players = TheNet:GetPlayersOnRoomChange()
			for _i, player in ipairs(players) do
				LootEvents.SpawnLootFromMaterials(DummyKonjurEnt, TempKonjurDropTable, player)
			end
		end

		if showAmount then
			LootEvents.DisplayKonjurAmountInWorld(DummyKonjurEnt, amount)
		end
		DummyKonjurEnt:RemoveFromScene()
	else
		-- can't reuse dummy entity because this lasts more than a frame
		local delayed_spawn = CreateEntity()
		delayed_spawn.entity:AddTransform()
		delayed_spawn.Transform:SetPosition(pos:unpack())

		delayed_spawn:DoTaskInTime(kLuckyLootDelay, function()
			local particles = SpawnPrefab("lucky_loot_explosion")
			particles.Transform:SetPosition(pos:unpack())
			particles:DoTaskInTime(1, particles.Remove)

			-- can't reuse temp table because this task is deferred
			LootEvents.SpawnLootFromMaterials(delayed_spawn, { konjur = amount }, owner, true)
			-- lucky stuff always shows an amount
			LootEvents.DisplayKonjurAmountInWorld(delayed_spawn, amount)
			delayed_spawn:Remove()
		end)
	end
end

return LootEvents
