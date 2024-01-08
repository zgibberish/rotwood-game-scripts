local EffectEvents = require "effectevents"
local SGCommon = require("stategraphs/sg_common")
local monsterutil = require "util.monsterutil"

local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local function OnHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "uproot",
		hitstoplevel = HitStopLevel.LIGHT,
		set_dir_angle_to_target = true,
		pushback = 0.5,
		combat_attack_fn = "DoKnockbackAttack",
		hitflags = Attack.HitFlags.GROUND,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = -5,
	})
end

local ATTACK_LINE_COOLDOWN = 4
local SHOOT_COOLDOWN = 5

local NUM_ROOTS_NORMAL = 7

local NUM_ROWS_ELITE = 3
local NUM_ROOTS_ELITE = 10

local ELITE_PROJECTILE_COUNT = 6

local function OnDeath(inst)
	inst:PushEvent("treemon_growth_interrupted")

	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, nil, "death_treemon")
	--Spawn loot (lootdropper will attach hitstopper)
	inst.components.lootdropper:DropLoot()
end

local events =
{
}
monsterutil.AddStationaryMonsterCommonEvents(events, { ondeath_fn = OnDeath, })

local states =
{
	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("idle", true)
			inst.sg.statemem.loops = math.min(3, math.random(5))
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.loops > 1 then
					inst.sg.statemem.loops = inst.sg.statemem.loops - 1
				else
					inst.sg:GoToState("behavior1")
				end
			end),
		},
	}),

	State({
		name = "behavior1",
		tags = { "idle" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior1")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	--[[State({
		name = "attack",
		tags = { "attack", "busy" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "attack")
			inst:PushEvent("treemon_growth_interrupted")
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,

		onupdate = function(inst)
			if inst.sg.statemem.angles ~= nil then
				if inst.sg.statemem.delay > 0 then
					inst.sg.statemem.delay = inst.sg.statemem.delay - 1
				else
					inst.sg.statemem.delay = math.max(1, math.random(3) - 1)

					local num = #inst.sg.statemem.angles
					local rnd = math.random(num)
					local angle = inst.sg.statemem.angles[rnd]
					if num > 1 then
						inst.sg.statemem.angles[rnd] = inst.sg.statemem.angles[num]
						inst.sg.statemem.angles[num] = nil
					else
						inst.sg.statemem.angles = nil
					end

					local x, z = inst.Transform:GetWorldXZ()
					local root = SpawnPrefab("treemon_growth_root", inst)
					local dist = 2 + 1 * math.random()
					local x1 = x + dist * math.cos(angle)
					local z1 = z - dist * math.sin(angle)
					root.Transform:SetPosition(x1, 0, z1)
					root.Transform:SetRotation(math.random(360))
					root:Setup(inst)
				end
			end
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.sg.statemem.angles = {}
				inst.sg.statemem.delay = 0
				local num = 7
				local theta0 = math.random() * math.pi * 2
				local delta = math.pi * 2 / num
				local var = delta / 4
				for i = 1, num do
					inst.sg.statemem.angles[i] = theta0 + i * delta - var + 2 * var * math.random()
				end
			end),
			FrameEvent(32, function(inst)
				local random = math.random() * 2
				inst.components.combat:StartCooldown(ATTACK_COOLDOWN + random)
			end),
			FrameEvent(33, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(39, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),]]

	State({
		name = "uproot",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("uproot")
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,

		timeline =
		{
			-- Root attacks come out on frame 11 via event handling to the root objects
			FrameEvent(11, function(inst)
				inst:PushEvent("extruderoot")
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.treemon_root_extrude
				soundutil.PlaySoundData(inst, params)
			end),

			FrameEvent(20, function(inst)
				local random = math.random() * 2
				inst.components.combat:StartCooldown(ATTACK_LINE_COOLDOWN + random)
				inst.sg:AddStateTag("caninterrupt")
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "shoot",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("shoot")
			inst.sg.statemem.target = target
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		timeline =
		{
			FrameEvent(9, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.sg.mem.shooting = false

				-- If target doesn't exist anymore, don't shoot anything
				if not inst.sg.statemem.target then
					return
				end

				-- get the target's position and check if they're to the left or right
				local pos = Vector2(inst.Transform:GetWorldXZ())
				local targetpos = Vector2(inst.sg.statemem.target.Transform:GetWorldXZ())
				local aimright = targetpos.x >= pos.x and true or false

				-- throw bomb
				local bomb = SpawnPrefab("treemon_projectile", inst)
				bomb:Setup(inst)

				local offset = aimright and Vector3(0.5, 4, 0) or Vector3(-0.5, 4, 0)
				bomb.Transform:SetPosition(pos.x + offset.x, offset.y, pos.y + offset.z)

				-- towards a target
				local target_pos = Vector3(targetpos.x, 0, targetpos.y)
				bomb:PushEvent("thrown", target_pos)
				local random = math.random() * 2
				inst.components.combat:StartCooldown(SHOOT_COOLDOWN + random)
			end),
		},
	}),

	State({
		name = "elite_uproot",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("uproot")
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,

		timeline =
		{
			-- Root attacks come out on frame 11 via event handling to the root objects
			FrameEvent(11, function(inst)
				inst:PushEvent("extruderoot")
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.treemon_root_extrude
				soundutil.PlaySoundData(inst, params)
			end),

			FrameEvent(20, function(inst)
				local random = math.random() * 2
				inst.components.combat:StartCooldown(ATTACK_LINE_COOLDOWN + random)
				inst.sg:AddStateTag("caninterrupt")
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "elite_shoot",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("shoot_loop")
			inst.sg.statemem.target = target

			if not inst.sg.mem.shoots then
				inst.sg.mem.shoots = 1
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.mem.shoots < ELITE_PROJECTILE_COUNT then
					inst.sg.mem.shoots = inst.sg.mem.shoots + 1
					inst.sg:GoToState("elite_shoot", inst.sg.statemem.target) -- Loop back until we've done all the shoots
				else
					inst.sg.mem.shoots = nil
					inst.sg:GoToState("idle")
				end
			end),
		},

		timeline =
		{
			FrameEvent(9, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.sg.mem.shooting = false

				-- If target doesn't exist anymore, don't shoot anything
				if not inst.sg.statemem.target then
					return
				end

				-- get the target's position and check if they're to the left or right
				local pos = Vector2(inst.Transform:GetWorldXZ())
				local targetpos = Vector2(inst.sg.statemem.target.Transform:GetWorldXZ())
				local aimright = targetpos.x >= pos.x and true or false

				-- throw bomb
				local bomb = SpawnPrefab("treemon_projectile", inst)
				bomb:Setup(inst)

				local offset = aimright and Vector3(0.5, 4, 0) or Vector3(-0.5, 4, 0)
				bomb.Transform:SetPosition(pos.x + offset.x, offset.y, pos.y + offset.z)

				-- towards a target
				local target_pos = Vector3(targetpos.x, 0, targetpos.y)
				bomb:PushEvent("thrown", target_pos)
				local random = math.random() * 2
				inst.components.combat:StartCooldown(SHOOT_COOLDOWN + random)
			end),
		},
	}),
}

SGCommon.States.AddAttackPre(states, "uproot")
SGCommon.States.AddAttackHold(states, "uproot", {
	onenter_fn = function(inst)
		local target = inst.sg.statemem.target
		if target then
			local x, z = target.Transform:GetWorldXZ()
			inst.sg.statemem.targetpos = {x, z}
		end

		inst.sg.statemem.spawnpts = {}
		inst.sg.statemem.delay = 0

		-- Get the player's position to determine where the line of roots will come out from
		local pos = Vector2(inst.Transform:GetWorldXZ())
		local targetpos = Vector2(inst.sg.statemem.targetpos)
		local dir = targetpos - pos
		dir:Normalize()

		local numroots = NUM_ROOTS_NORMAL
		inst.sg.statemem.rootnum = 1

		for i = 1, numroots do
			-- Add some random offset to each root position so it feels more organic
			local perpvec = Vector2.perpendicular(dir)
			inst.sg.statemem.spawnpts[i] = { pos.x + dir.x * 1.5 * i + perpvec.x * (math.random() * 2 - 1), pos.y + dir.y * 1.5 * i + perpvec.y * (math.random() * 2 - 1) }
		end
	end,

	update_fn = function(inst)
		if inst.sg.statemem.spawnpts ~= nil then
			if inst.sg.statemem.delay > 0 then
				inst.sg.statemem.delay = inst.sg.statemem.delay - 1
			else
				inst.sg.statemem.delay = math.max(1, math.random(3) - 1)

				if inst.sg.statemem.rootnum <= #inst.sg.statemem.spawnpts then
					local x, z = table.unpack(inst.sg.statemem.spawnpts[inst.sg.statemem.rootnum])
					inst.sg.statemem.rootnum = inst.sg.statemem.rootnum + 1

					-- Only spawn if the spawn point is on ground
					local map = TheWorld.Map
					local isPointOnGround = map:IsGroundAtPoint(Vector3(x, 0, z))
					if isPointOnGround then
						local root = SpawnPrefab("treemon_growth_root", inst)
						root.Transform:SetPosition(x, 0, z)
					root:Setup(inst)
					end
				end
			end
		end
	end,
})
SGCommon.States.AddAttackPre(states, "shoot",
{
	onenter_fn = function(inst)
		-- Used to show/hide the pinecone symbol when hit depending on if shooting or not
		inst.sg.mem.shooting = true

		inst.AnimState:ShowSymbol("pinecone")
		inst.AnimState:ShowSymbol("pinecone_hide")
	end,
})
SGCommon.States.AddAttackHold(states, "shoot")

-- Elite Attacks:
SGCommon.States.AddAttackPre(states, "elite_uproot")
SGCommon.States.AddAttackHold(states, "elite_uproot", {
	onenter_fn = function(inst)
		local target = inst.sg.statemem.target
		if target then
			local x, z = target.Transform:GetWorldXZ()
			inst.sg.statemem.targetpos = {x, z}
		end

		inst.sg.statemem.spawnpts = {}
		inst.sg.statemem.delay = 0

		-- Get the player's position to determine where the line of roots will come out from
		local pos = Vector2(inst.Transform:GetWorldXZ())
		local targetpos = Vector2(inst.sg.statemem.targetpos)
		local dir = targetpos - pos
		dir:Normalize()

		local numrows = NUM_ROWS_ELITE -- Amount of rows in one shot
		inst.sg.statemem.rownum = 1

		local numroots = NUM_ROOTS_ELITE -- Amount of roots in one row
		inst.sg.statemem.rootnum = 1


		local angles = { 0, -30, 30 }
		for j = 1, numrows do
			inst.sg.statemem.spawnpts[j] = {}
			local rotated_dir = Vector2.rotate(dir, math.rad(angles[j]))
			for i = 1, numroots do
				-- Add some random offset to each root position so it feels more organic
				local perpvec = Vector2.perpendicular(rotated_dir)
				inst.sg.statemem.spawnpts[j][i] = { pos.x + rotated_dir.x * 2.25 * i + perpvec.x * (math.random() - 0.5), pos.y + rotated_dir.y * 2.25 * i + perpvec.y * (math.random() - 0.5) }
			end
		end
	end,

	update_fn = function(inst)
		if inst.sg.statemem.spawnpts ~= nil then
			if inst.sg.statemem.delay > 0 then
				inst.sg.statemem.delay = inst.sg.statemem.delay - 1
			else
				inst.sg.statemem.delay = math.max(1, math.random(3) - 1)

				local numrows = NUM_ROWS_ELITE -- Amount of rows in one shot
				for j = 1, numrows do
					if inst.sg.statemem.rootnum <= #inst.sg.statemem.spawnpts[j] then
						local x, z = table.unpack(inst.sg.statemem.spawnpts[j][inst.sg.statemem.rootnum])

						-- Only spawn if the spawn point is on ground
						local map = TheWorld.Map
						local isPointOnGround = map:IsGroundAtPoint(Vector3(x, 0, z))
						if isPointOnGround then
							local root = SpawnPrefab("treemon_growth_root", inst)
							root.Transform:SetPosition(x, 0, z)
							root:Setup(inst)
						end
					end
				end
				inst.sg.statemem.rootnum = inst.sg.statemem.rootnum + 1
			end
		end
	end,
})
SGCommon.States.AddAttackHold(states, "elite_shoot")

SGCommon.States.AddAttackPre(states, "elite_shoot",
{
	onenter_fn = function(inst)
		-- Used to show/hide the pinecone symbol when hit depending on if shooting or not
		inst.sg.mem.shooting = true

		inst.AnimState:ShowSymbol("pinecone")
		inst.AnimState:ShowSymbol("pinecone_hide")
	end,
})

SGCommon.States.AddLeftRightHitStates(states, nil,
{
	onenterhit = function(inst, data)

		-- Was it not trying to shoot a projectile? Hide the projectile symbols
		if not inst.sg.mem.shooting then
			inst.AnimState:HideSymbol("pinecone")
			inst.AnimState:HideSymbol("pinecone_hide")
		end

		local t = GetTime()
		if t > (inst.sg.mem.hitleavestime or 0) then
			inst.sg.mem.hitleavestime = t + .75
			inst:SpawnHitLeaves(data.right)
		end
	end
})

SGCommon.States.AddMonsterDeathStates(states)
SGRegistry:AddData("sg_treemon", states)

return StateGraph("sg_treemon", states, events, "idle")
