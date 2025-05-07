local Power = require "defs.powers"
local SGCommon = require("stategraphs/sg_common")
local SpecialEventRoom = require("defs.specialeventrooms.specialeventroom")
local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local kassert = require "util.kassert"
local lume = require "util.lume"


function SpecialEventRoom.AddMinigameSpecialEventRoom(id, data)
	if not data.event_type then
		data.event_type = SpecialEventRoom.Types.MINIGAME
	end
	SpecialEventRoom.AddSpecialEventRoom(SpecialEventRoom.Types.MINIGAME, id, data)
end

local function SpawnPrefabsInPositionTable(inst, prefab, pos_tbl)
	local prefabs = {}
	local inst_pos = { x=0, y=0, z=0}
	local spawnfunc = function(inst, prefab, rel_position)
		local pfb = SpawnPrefab(prefab, inst)
		if pfb then
			pfb.Transform:SetPosition(inst_pos.x + rel_position[1], inst_pos.y, inst_pos.z + rel_position[2])
			table.insert(prefabs, pfb)
		end
	end
	for k,v in pairs(pos_tbl) do
		spawnfunc(inst, prefab, v)
	end
	return prefabs
end

local function AddDoors(inst)
	-- Temporary for now until door prop exists
	local door_positions = 
	{
		{ 9.5, 	-1.5 },
		{ 9.5,	0.5 },
		{ 9.5, 	1.5 },

		{ -9.5, 	-1.5 },
		{ -9.5,		0.5 },
		{ -9.5, 	1.5 },
	}

	inst.door_prefabs = SpawnPrefabsInPositionTable(inst, "plushies_sm", door_positions)
end

local function AddWalls(inst)
	--JAMBELL: TEMPORARY FOR NOW, until a reliable world/scene exists
	local wall_positions =
	{
		{ 0,	0 },
		{ 3, 	0 },
		{-3, 	0 },
		{ 6, 	0 },
		{ -6, 	0 },
		{ 9, 	0 },

		{ 0,	3.5 },
		{ -3,	3.5 },
		{ 3,	3.5 },
		{ 6,	3.5 },
		{ -6,	3.5 },
		{ 9, 	3.5 },

		{ 0,	-3.5 },
		{ -3,	-3.5 },
		{ 3,	-3.5 },
		{ 6,	-3.5 },
		{ -6,	-3.5 },
		{ 9, 	-3.5 },

		{ 0,	7 },
		{ -3,	7 },
		{ 3,	7 },
		{ 6,	7 },
		{ -6,	7 },
		{ 9, 	7 },

		{ 0,	-7 },
		{ -3,	-7 },
		{ 3,	-7 },
		{ 6,	-7 },
		{ -6,	-7 },
		{ 9, 	-7 },
	}

	inst.wall_prefabs = SpawnPrefabsInPositionTable(inst, "plushies_sm", wall_positions)
end

local function RemoveDoors(inst)
	for _,prefab in pairs(inst.door_prefabs) do
		prefab:Remove()
	end
end

SpecialEventRoom.AddMinigameSpecialEventRoom("dps_check",
{
	score_type = SpecialEventRoom.ScoreType.TIMELEFT,
	score_thresholds = {
		[SpecialEventRoom.RewardLevel.BRONZE] = 5,
		[SpecialEventRoom.RewardLevel.SILVER] = 10,
		[SpecialEventRoom.RewardLevel.GOLD] = 15,
	},

	prefabs = { "cabbageroll" },

	on_init_fn = function(inst)
		-- Spawn a huge cabbageroll and configure it
		inst.roll = SpawnPrefab("cabbageroll", inst)
		inst.roll:Stupify("dps_check minigame")

		inst.roll.AnimState:SetScale(3,3)
		inst.roll.Physics:SetSize(2)
		inst.roll.components.pushbacker.weight = 0
		inst.roll.components.combat:SetHasKnockback(false)
		inst.roll.components.combat:SetHasKnockdown(false)
		inst.roll.Transform:SetPosition(0,0,0)

		-- When it dies, tell the event to finish
		inst.roll:ListenForEvent("death", function()
			inst.components.specialeventroommanager:UpdateBottomHUD("0%")
			inst.completed_timeleft = lume.round(inst.components.specialeventroommanager:GetTimerSecondsRemaining())
			inst.components.specialeventroommanager:ScoreWrapUp()
		end)
	end,

	on_start_fn = function(inst)
		local health = inst.components.specialeventroommanager:ScaleEnemyHealth(3000)
		inst.roll.components.health:SetMax(health, true) -- TODO(jambell): scale based on player's average DPS this run
		inst.roll.components.health:SetCurrent(health, true)

		inst.components.specialeventroommanager:StartTimer(30)
		inst.components.specialeventroommanager:DisplayBottomHUD()
	end,

	on_update_fn = function(inst, event, dt)
		if inst.bottomhud ~= nil then
			inst.components.specialeventroommanager:UpdateBottomHUD(lume.round(inst.roll.components.health:GetPercent()*100).."%")
		end
	end,

	event_triggers =
	{
	}
})

SpecialEventRoom.AddMinigameSpecialEventRoom("dodge_game",
{
	prefabs = { "trap_weed_spikes", "cabbageroll", "blarmadillo", "yammo" },

	score_type = SpecialEventRoom.ScoreType.SCORELEFT,
	score_thresholds = {
		[SpecialEventRoom.RewardLevel.BRONZE] = 3,
		[SpecialEventRoom.RewardLevel.SILVER] = 6,
		[SpecialEventRoom.RewardLevel.GOLD] = 9,
	},

	on_init_fn = function(inst)
		local inst_pos = { x=0, y=0, z=0}
		local pos_tbl =
		{
			{ 0,	0 },
			{ 3, 	0 },
			{-3, 	0 },
			{ 6, 	0 },
			{ -6, 	0 },
			{ 9, 	0 },

			{ 0,	3.5 },
			{ -3,	3.5 },
			{ 3,	3.5 },
			{ 6,	3.5 },
			{ -6,	3.5 },
			{ 9, 	3.5 },

			{ 0,	-3.5 },
			{ -3,	-3.5 },
			{ 3,	-3.5 },
			{ 6,	-3.5 },
			{ -6,	-3.5 },
			{ 9, 	-3.5 },

			{ 0,	7 },
			{ -3,	7 },
			{ 3,	7 },
			{ 6,	7 },
			{ -6,	7 },
			{ 9, 	7 },

			{ 0,	-7 },
			{ -3,	-7 },
			{ 3,	-7 },
			{ 6,	-7 },
			{ -6,	-7 },
			{ 9, 	-7 },
		}

		inst.traps = {}
		local spawnfunc = function(inst, prefab, rel_position)
			local trap = SpawnPrefab(prefab, inst)
			if trap then
				trap.Transform:SetPosition(inst_pos.x + rel_position[1]-1.5, inst_pos.y, inst_pos.z + rel_position[2])
				trap.sg:GoToState("idle")
				inst.traps[trap] = true
			end
		end
		for k,v in pairs(pos_tbl) do
			spawnfunc(inst, "trap_weed_spikes", v)
		end

		inst.enemies = {}
		inst.enemyspawnlocations =
		{
			{-8,  5},
			{-4, -2.5},
			{ 4,  2.5},
			{ 8, -5},
		}

		inst.enemyspawnidx =
		{
			1,
			1,
			1,
			1,
		}
		inst.enemyorder =
		{
			"cabbageroll",
			"cabbageroll",
			"cabbageroll",
			"blarmadillo",
			"yammo",
		}
		inst.spawnenemy = function(inst, prefab, id)
			local enemyprefab = inst.enemyorder[inst.enemyspawnidx[id]]
			kassert.assert_fmt(enemyprefab, "Failed to find an enemy. id=%d spawnidx=%s", id, inst.enemyspawnidx[id])
			local enemy = SpawnPrefab(enemyprefab, inst)
			local pos = inst.enemyspawnlocations[id]
			enemy.Transform:SetPosition(pos[1], 0, pos[2])
			enemy.spawnerid = id

			inst.enemies[enemy] = true

			enemy.components.attacktracker:SetMinimumCooldown(1)
			enemy.components.attacktracker:ModifyAttackCooldowns(.5)
			enemy.components.attacktracker:ModifyAllAttackTimers(0)


			enemy:ListenForEvent("death", function()
				inst:DoTaskInTime(3, function()
					if inst.components.specialeventroommanager:TimerIsRunning() then
						inst.enemies[enemy] = nil
						inst.enemyspawnidx[enemy.spawnerid] = inst.enemyspawnidx[enemy.spawnerid] + 1
						inst.spawnenemy(inst, prefab, id)
					end
				end)
			end)
		end
	end,

	on_start_fn = function(inst)
		inst.components.specialeventroommanager:StartTimer(30)
		inst.components.specialeventroommanager:AddPlayerInvulnerability()
		inst.components.specialeventroommanager:InitializeScores(10)
		inst.components.specialeventroommanager:DisplayScores()
		inst.components.specialeventroommanager:DecrementScoreOnTakeDamage()

		for id,pos in pairs(inst.enemyspawnlocations) do
			inst.spawnenemy(inst, "cabbageroll", id)
		end
	end,

	on_scorewrapup_fn = function(inst)
		for trap,_ in pairs(inst.traps) do
			trap:PushEvent("dormant_start")
		end

		for enemy,_ in pairs(inst.enemies) do
			enemy.components.health:Kill()
		end
	end,

	on_finish_fn = function(inst)
		TheWorld.components.roomlockable:RemoveLock(inst)
		inst.components.specialeventroommanager:RemovePlayerInvulnerability()
	end,

	event_triggers =
	{
	}
})

SpecialEventRoom.AddMinigameSpecialEventRoom("bomb_game",
{
	prefabs = { "megatreemon_bomb_projectile", "bomb_explosion_scorch_mark" },

	score_type = SpecialEventRoom.ScoreType.SCORELEFT,
	score_thresholds = {
		[SpecialEventRoom.RewardLevel.BRONZE] = 3,
		[SpecialEventRoom.RewardLevel.SILVER] = 6,
		[SpecialEventRoom.RewardLevel.GOLD] = 9,
	},

	on_init_fn = function(inst)
		inst.rng = TheDungeon:GetDungeonMap():GetRNG()
		inst.bomb_arrangements =
		{
			cross =
			{
				{ -4, 0 },
				{ 4,  0 },
				{ 0,  4 },
				{ 0,  -4 },
			},
			x =
			{
				{ -6, -6 },
				{ 6, -6 },
				{ -6, 6 },
				{ 6, 6 },
			},
			line_top =
			{
				{ -6, 3 },
				{ -3, 3 },
				{ 3, 3 },
				{ 6, 3 },
			},
			line_middle =
			{
				{ -6, 0 },
				{ -3, 0 },
				{ 3,  0 },
				{ 6,  0 },
			},
			line_left =
			{
				{ -4,  -6 },
				{ -4,  -3 },
				{ -4,  3 },
				{ -4,  6 },
			},
			line_right =
			{
				{ 4,  -6 },
				{ 4,  -3 },
				{ 4,  3 },
				{ 4,  6 },
			},
		}

		SpawnPrefabsInPositionTable(inst, "bomb_explosion_scorch_mark", inst.bomb_arrangements.cross)
	end,

	on_start_fn = function(inst)
		TheWorld.components.roomlockable:AddLock(inst)

		inst.components.specialeventroommanager:StartTimer(30)
		inst.components.specialeventroommanager:AddPlayerInvulnerability()
		inst.components.specialeventroommanager:InitializeScores(10)
		inst.components.specialeventroommanager:DisplayScores()
		inst.components.specialeventroommanager:DecrementScoreOnTakeDamage()

		local clear_scorch = function(inst, time)
			--TEMP for now
			local near_entities = TheSim:FindEntitiesXZ(0, 0, 10)
			inst:DoTaskInAnimFrames((time) + 30, function(inst)
				for i,ent in ipairs(near_entities) do
					if ent:IsValid() and ent.prefab == "bomb_explosion_scorch_mark" then
						ent:Remove()
					end
				end
			end)
		end
		local spawn_arrangement = function(inst, rel_position)
			local should_clear = true
			local addframes = inst.rng:Boolean() and 3 or 0 -- either throw them sequentially or all at once

			dbassert(#rel_position <= 4, "[bomb_game]: Do not spawn more than 4 bombs in one wave, because then they bleed into the next wave.")
			for k,v in pairs(rel_position) do
				inst:DoTaskInAnimFrames(addframes * k, function(inst)
					if should_clear then
						clear_scorch(inst, addframes * k)
						should_clear = false
					end

					local bomb = SpawnPrefab("megatreemon_bomb_projectile", inst)
					bomb.sg.mem.explodeonland = true
					local x, z = inst.Transform:GetWorldXZ()
					bomb.Transform:SetPosition(x, 0, z)
					local target_pos = Vector3(x + v[1], 0, z + v[2])
					bomb:PushEvent("thrown", target_pos)
				end)
			end
		end

		inst.spawn_arrangement = spawn_arrangement
	end,

	on_update_fn = function(inst)
		if inst.components.specialeventroommanager:GetTimerSecondsPassed() % 2 == 0 then --TODO(jambell) fix onupdate so it doesn't update until event has started
			inst.spawn_arrangement(inst, inst.rng:PickValue(inst.bomb_arrangements))
		end
	end,

	on_finish_fn = function(inst)
		TheWorld.components.roomlockable:RemoveLock(inst)
		inst.components.specialeventroommanager:RemovePlayerInvulnerability()
	end,

	event_triggers =
	{
	}
})

SpecialEventRoom.AddMinigameSpecialEventRoom("hit_streak",
{
	-- TODO:
	-- Instead of timers and flipping back and forth, just spawn cabbage rolls with NO ATTACKS in the attacktracker, so that they'll approach you.
	prefabs = { "treemon", "dummy_bandicoot", "dummy_cabbageroll" },

	score_type = SpecialEventRoom.ScoreType.HIGHSCORE,
	score_thresholds = {
		[SpecialEventRoom.RewardLevel.BRONZE] = 8,
		[SpecialEventRoom.RewardLevel.SILVER] = 15,
		[SpecialEventRoom.RewardLevel.GOLD] = 25,
	},

	on_init_fn = function(inst)
		-- Spawn some dumb enemies to act as timing indicators
		inst.treemontimers = {}
		for i=1,4 do
			local treemon = SpawnPrefab("treemon", inst)
			treemon:Stupify("hit_streak minigame")
			treemon.HitBox:SetEnabled(false)
			treemon.Transform:SetPosition(-4 + ((i-1)*2), 0, 12)
			table.insert(inst.treemontimers, treemon)
		end

		inst.timeridx = 0
		inst.timer_animframes = 0
		inst.timer_colors =
		{
			{ 255/255, 255/255, 255/255 },
			{ 255/255, 255/255, 255/255 },
			{ 255/255, 255/255, 255/255 },
			{ 0/255, 255/255, 0/255 },
		}

		inst.dummyone = SpawnPrefab("dummy_bandicoot", inst)
		inst.dummyone.Transform:SetPosition(-3, 0, 4)

		inst.dummytwo = SpawnPrefab("dummy_bandicoot", inst)
		inst.dummytwo.Transform:SetPosition(-3, 0, -4)

		inst.dummythree = SpawnPrefab("dummy_cabbageroll", inst)
		inst.dummythree.Transform:SetPosition(3, 0, 4)

		inst.dummyfour = SpawnPrefab("dummy_cabbageroll", inst)
		inst.dummyfour.Transform:SetPosition(3, 0, -4)

		inst.dummypairs =
		{
			{ inst.dummyone, inst.dummytwo },
			{ inst.dummythree, inst.dummyfour },
		}

		inst.dummyidx = 1
		for num=1,#inst.dummypairs[2] do -- Disable the second pair
			inst.dummypairs[2][num]:RemoveFromScene()
		end
	end,

	on_start_fn = function(inst)
		--JAMBELL: change slower
		inst.rng = TheDungeon:GetDungeonMap():GetRNG()

		TheWorld.components.roomlockable:AddLock(inst)

		local sre = inst.components.specialeventroommanager
		sre:StartTimer(30)
		sre:AddPlayerInvulnerability()
		sre:InitializeScores()
		sre:DisplayScores()
		sre:AddTemporaryEventListenerToPlayers("hitstreak", function(inst, data)
			if data.hitstreak > sre:GetScore(inst) then
				sre:SetScore(inst, data.hitstreak)
			end
		end)
	end,

	on_update_fn = function(inst)
		-- Working in animframes so that all the units within this function are the same, between this and BlinkAndFadeColor
		inst.timer_animframes = inst.timer_animframes + 0.5
		if inst.timer_animframes >= 15 then

			-- First, manage the timer rolls, to see if this is a step we should change on
			local change = false
			inst.timer_animframes = 0
			inst.timeridx = inst.timeridx + 1
			if inst.timeridx == #inst.treemontimers then
				change = true
			elseif inst.timeridx > #inst.treemontimers then
				inst.timeridx = 1
			end

			-- This is a step we should change on! Do so.
			if change then
				-- Flash the timers and all the dummies
				for i=1,#inst.treemontimers do
					SGCommon.Fns.BlinkAndFadeColor(inst.treemontimers[i], inst.timer_colors[inst.timeridx], 5)
				end
				for i=1,#inst.dummypairs do
					for num=1,#inst.dummypairs[i] do
						SGCommon.Fns.BlinkAndFadeColor(inst.dummypairs[i][num], inst.timer_colors[inst.timeridx], 5)
					end
				end

				-- Increment which dummy pair should be active
				inst.dummyidx = inst.dummyidx + 1
				if inst.dummyidx > #inst.dummypairs then
					inst.dummyidx = 1
				end

				-- Iterate through the dummy pairs, and enable/disable based on whether they should be active or not.
				for i=1,#inst.dummypairs do
					if i == inst.dummyidx then -- This is the active pair
						for num=1,#inst.dummypairs[i] do -- So enable them both
							inst.dummypairs[i][num]:ReturnToScene()
						end
					else -- Inactive pair
						for num=1,#inst.dummypairs[i] do -- So disable them both
							inst.dummypairs[i][num]:RemoveFromScene()
						end
					end
				end
			else
				-- Not a "change" step, so just blink the appropriate timer cabbageroll.
				SGCommon.Fns.BlinkAndFadeColor(inst.treemontimers[inst.timeridx], inst.timer_colors[inst.timeridx], 5)
			end
		end
	end,

	on_scorewrapup_fn = function(inst)
		for _,treemon in ipairs(inst.treemontimers) do
			treemon.components.health:Kill()
		end
	end,

	on_finish_fn = function(inst)
		TheWorld.components.roomlockable:RemoveLock(inst)
		inst.components.specialeventroommanager:RemovePlayerInvulnerability()
		inst.components.specialeventroommanager:RemoveTemporaryEventListenersFromPlayers()
	end,

	event_triggers =
	{
	}
})

SpecialEventRoom.AddMinigameSpecialEventRoom("mini_cabbage_swarm",
{
	prefabs = { "cabbageroll" },

	score_type = SpecialEventRoom.ScoreType.HIGHSCORE,
	score_thresholds = {
		[SpecialEventRoom.RewardLevel.BRONZE] = 80,
		[SpecialEventRoom.RewardLevel.SILVER] = 100,
		[SpecialEventRoom.RewardLevel.GOLD] = 120,
	},

	on_init_fn = function(inst)
		--TODO(jambell) set up an objectpool and configure all the mobs once, which will help with 
		inst:AddComponent("powermanager")

		local def = Power.FindPowerByQualifiedName("pwr_smallify")
		inst.smallify_power = inst.components.powermanager:CreatePower(def)
	end,

	on_start_fn = function(inst)
		inst.rng = TheDungeon:GetDungeonMap():GetRNG()

		TheWorld.components.roomlockable:AddLock(inst)
		inst.components.specialeventroommanager:StartTimer(30)
		inst.components.specialeventroommanager:AddPlayerInvulnerability()
		inst.components.specialeventroommanager:InitializeScores()
		inst.components.specialeventroommanager:DisplayScores()
		inst.components.specialeventroommanager:IncrementScoreOnKill()
		inst.components.specialeventroommanager:DecrementScoreOnTakeDamage(10)
		inst.components.specialeventroommanager:AddTemporaryEventListenerToPlayers("take_damage", function(inst)
			TheDungeon.HUD:MakePopText({ target = inst, button = "-10", color = UICOLORS.HEALTH_LOW, fade_time = 1 })
		end)

		inst.spawner_positions =
		{
			{ -8,  5 },
			{ -8, -5 },
			{  8,  5 },
			{  8, -5 },
		}

		inst.totalrolls = 0
		inst.rolls = {}

		local spawn_wave = function(inst)
			local should_clear = true
			local addframes = inst.rng:Boolean(1) and 2 or 0 -- either throw them sequentially or all at once --JAMBELL: currently always sequential

			for idx, spawner in pairs(inst.spawner_positions) do
				local x,z = spawner[1], spawner[2]

				-- for k,v in pairs(rel_position) do
				for i=1, 3 do
					inst:DoTaskInAnimFrames(addframes * i, function(inst)
						if inst.totalrolls < 25 then
							local roll = SpawnPrefab("cabbageroll", inst)
							roll.components.powermanager:AddPower(inst.smallify_power)
							roll.components.health:SetMax(1, true)
							roll.components.health:SetCurrent(1, true)
							roll.components.attacktracker:SetMinimumCooldown(6)
							roll.components.attacktracker:ModifyAttackCooldowns(1.5)
							roll.components.attacktracker:ModifyAllAttackTimers(1)
							roll:ListenForEvent("death", function()
								inst.rolls[roll] = nil
								inst.totalrolls = inst.totalrolls - 1
							end)

							roll.Transform:SetPosition(x, 0, z)
							-- roll.Transform:SetPosition(x + v[1], 0, z + v[2])
							roll.sg:GoToState("spawn_battlefield", { spawner = inst, dir = x > 0 and 180 or 0 }) --TODO(jambell): change dir randomly
							inst.rolls[roll] = true
							inst.totalrolls = inst.totalrolls + 1
						end
					end)
				end
			end
		end

		inst.spawn_wave = spawn_wave
	end,

	on_update_fn = function(inst)
		local secondspassed = inst.components.specialeventroommanager:GetTimerSecondsPassed()
		if secondspassed % 2 == 0 then --TODO(jambell) fix onupdate so it doesn't update until event has started
			inst.spawn_wave(inst)
		end
	end,

	on_scorewrapup_fn = function(inst)
		for roll,_ in pairs(inst.rolls) do
			roll.components.health:Kill()
		end
	end,

	on_finish_fn = function(inst)
		inst.components.specialeventroommanager:RemovePlayerInvulnerability()
		TheWorld.components.roomlockable:RemoveLock(inst)
	end,

	event_triggers =
	{
	}
})

--IDEAS:
-- crystal chronicles inspired "carry the bucket" where one player needs to carry around an object that creates a safe zone and the others defend them against monster waves
-- smash a beachball around to keep it away from a yammo
-- enemies/projectiles approaching from right moving left forcing you to jump/roll/dodge which would be move mastery challenge. Could even have multiple lanes for multiplayer and get really mario party like
