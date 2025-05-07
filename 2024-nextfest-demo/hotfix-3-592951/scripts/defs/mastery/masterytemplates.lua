local templates = {}

-- Helper Functions for creating basic Masteries:
templates.AddKillMonsterMastery = function(add_mastery_fn, prefab, num)
	local id = (prefab.."_kill"):lower()

	local data = {
		max_progress = num or 30,
		event_triggers =
		{
			["kill"] = function(mst, inst, data)
				local target = data.attack:GetTarget()
				if target and target.prefab == prefab then
					mst:DeltaProgress(1)
				end
			end,
		},
	}

	add_mastery_fn(id, data)
end

templates.AddFocusKillMonsterMastery = function(add_mastery_fn, prefab, num)
	local id = (prefab.."_kill_focus"):lower()

	local data = {
		max_progress = num or 30,
		event_triggers =
		{
			["kill"] = function(mst, inst, data)
				local target = data.attack:GetTarget()
				if target and target.prefab == prefab then
					if data.attack:GetFocus() then
						mst:DeltaProgress(1)
					end
				end
			end,
		},
	}

	add_mastery_fn(id, data)
end

templates.AddLightAttackKillMonsterMastery = function(add_mastery_fn, prefab)
	local id = (prefab.."_kill_lightattack"):lower()

	local data = {
		on_add_fn = function(mst, inst, is_upgrade)
			mst.mem.targets_health = {}
		end,

		event_triggers =
		{
			["kill"] = function(mst, inst, data)
				local attack = data.attack
				local target = attack:GetTarget()

				if target and target.prefab == prefab then
					if attack:GetID() == "light_attack"	then
						mst:DeltaProgress(1)
					end
				end
			end,
		},
	}

	add_mastery_fn(id, data)
end

templates.AddHeavyAttackKillMonsterMastery = function(add_mastery_fn, prefab)
	local id = (prefab.."_kill_heavyattack"):lower()

	local data = {
		on_add_fn = function(mst, inst, is_upgrade)
			mst.mem.targets_health = {}
		end,

		event_triggers =
		{
			["kill"] = function(mst, inst, data)
				local attack = data.attack
				local target = attack:GetTarget()

				if target and target.prefab == prefab then
					if attack:GetID() == "heavy_attack"	then
						mst:DeltaProgress(1)
					end
				end
			end,
		},
	}

	add_mastery_fn(id, data)
end

templates.AddSkillKillMonsterMastery = function(add_mastery_fn, prefab)
	local id = (prefab.."_kill_skill"):lower()

	local data = {
		on_add_fn = function(mst, inst, is_upgrade)
			mst.mem.targets_health = {}
		end,

		event_triggers =
		{
			["kill"] = function(mst, inst, data)
				local attack = data.attack
				local target = attack:GetTarget()

				if target and target.prefab == prefab then
					if attack:GetID() == "skill" then
						mst:DeltaProgress(1)
					end
				end
			end,
		},
	}

	add_mastery_fn(id, data)
end

templates.AddKillQuicklyMonsterMastery = function(add_mastery_fn, prefab, time)
	local id = (prefab.."_kill_quickly"):lower()

	local data = {
		event_triggers =
		{
			["kill"] = function(mst, inst, data)
				local target = data.attack:GetTarget()
				if target and target.prefab == prefab then
					local target_time = time or 5
					local spawn_time = target.spawntime
					local age = GetTime() - spawn_time

					if age <= target_time then
						mst:DeltaProgress(1)
					end
				end
			end,
		},
	}

	add_mastery_fn(id, data)
end

templates.AddKillWithNoDamageMastery = function(add_mastery_fn, prefab, time)
	local id = (prefab.."_kill_flawless"):lower()

	local data = {
		on_add_fn = function(mst, inst)
			mst.mem.damage_log = {}
		end,

		event_triggers =
		{
			["take_damage"] = function(mst, inst, attack)
				-- Whenever this mob type attacks player, store how much damage it dealt.
				-- Later, check if there is any damage listed. If not, the player killed without receiving damage.

				local attacker = attack:GetAttacker()
				if attacker and attacker.prefab == prefab then
					local damage = attack:GetDamage()
					if mst.mem.damage_log[attacker] then
						mst.mem.damage_log[attacker] = mst.mem.damage_log[attacker] + damage
					else
						mst.mem.damage_log[attacker] = damage
					end
				end
			end,

			["kill"] = function(mst, inst, data)
				local target = data.attack:GetTarget()
				if target and target.prefab == prefab then
					if not mst.mem.damage_log[target] then
						-- We haven't logged any damage from this mob
						mst:DeltaProgress(1)
					end
				end
			end,
		},
	}

	add_mastery_fn(id, data)
end

templates.AddKillOneHitMastery = function(add_mastery_fn, prefab)
	local id = (prefab.."_kill_onehit"):lower()

	local data = {
		on_add_fn = function(mst, inst, is_upgrade)
			mst.mem.targets_health = {}
		end,

		event_triggers =
		{
			["do_damage"] = function(mst, inst, attack)
				local target = attack:GetTarget()

				if target and target.prefab == prefab then
					local health = target.components.health

					if health then
						mst.mem.targets_health[inst] = health:GetCurrent() -- Store their health on this hit, so we can compare later and see if they died in one hit.
					end
				end
			end,

			["kill"] = function(mst, inst, data)
				local target = data.attack:GetTarget()

				if target and target.prefab == prefab then
					if mst.mem.targets_health[inst] and target.components.health then
						local health = mst.mem.targets_health[inst]
						local max_health = target.components.health:GetMax()

						if health == max_health	then
							mst:DeltaProgress(1)
						end
					end
				end
			end,
		},
	}

	add_mastery_fn(id, data)
end

return templates
-- MASTERY IDEAS:

-- General, applicable to any mob
-- Perfect Dodge an attack from [mob]
-- Kill a [mob] using a trap
-- Do an x-hit combo on [mob]
-- Land a critical hit on [mob]
-- Knockdown [mob]


-- Do X in a single run