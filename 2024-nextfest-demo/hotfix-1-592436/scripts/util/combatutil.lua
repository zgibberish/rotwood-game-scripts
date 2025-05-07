local combatutil = {}

function combatutil.StartMeleeAttack(inst)
	inst:PushEvent("attack_start")
	inst.components.hittracker:StartNewAttack(inst.sg.mem.attack_type, inst.sg.statemem.attack_id, true)
	inst.sg:AddStateTag("attack_active")
end

function combatutil.EndMeleeAttack(inst)
	local targetshit = inst.components.hittracker:GetTargetsHit()
	inst.components.hittracker:FinishAttack()
	inst:PushEvent("attack_end", targetshit)
	inst.sg:RemoveStateTag("attack_active")
	inst.sg:AddStateTag("attack_recovery")
end

function combatutil.StartProjectileAttack(inst)
	inst.components.hittracker:StartNewAttack(inst.attacktype, inst.attack_id, false, inst.owner)
end

function combatutil.EndProjectileAttack(inst)
	if inst.components.hittracker then
		inst.components.hittracker:FinishAttack()
	end
	inst.active_powers = {}
end

function combatutil.ActivatePowerForProjectile(projectiles, power)
	if type(projectiles) ~= "table" then
		projectiles = { projectiles }
	end

	for i, proj in ipairs(projectiles) do
		if not proj.active_powers then
			proj.active_powers = {}
		end
		proj.active_powers[power] = true
	end
end

function combatutil.IsPowerActiveForProjectileAttack(attack, power)
	local proj = attack:GetProjectile()
	if not proj or (proj and not proj.active_powers) then
		return false
	end
	return proj.active_powers[power]
end

function combatutil.GetWalkableOffsetPosition(pos, min_offset, max_offset, min_angle, max_angle)
	local x = pos.x
	local z = pos.z
	max_offset = max_offset or min_offset

	min_angle = min_angle or 1
	max_angle = max_angle or 360

	local tries = 100
	for i = 1, tries do
		local angle = math.rad(math.random(min_angle, max_angle))
		local dist_mod = math.random(min_offset, max_offset)

		local randomOffset = { x = math.sin(angle), z = math.cos(angle) }

		local o_x = x + (randomOffset.x * dist_mod)
		local o_z = z + (randomOffset.z * dist_mod)

		if TheWorld.Map:IsWalkableAtXZ(o_x, o_z) then
			return Vector3(o_x, 0, o_z)
		end
	end

	 -- couldn't find an offset, return the position of the original thing
	return pos
end

function combatutil.GetWalkableOffsetPositionFromEnt(ent, ...)
	return combatutil.GetWalkableOffsetPosition(ent:GetPosition(), ...)
end

return combatutil
