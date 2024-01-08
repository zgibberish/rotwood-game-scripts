local ChaseAndAttack = require "behaviors.chaseandattack"
local KnockdownRecovery = require "behaviors.knockdownrecovery"
local TargetLastAttacker = require "behaviors.targetlastattacker"
local Wander = require "behaviors.wander"
local combatutil = require "util.combatutil"
local lume = require"util.lume"

local healseed_tag = {"healingseed"}

local function CanHeal(inst)
	local x,z = inst.Transform:GetWorldXZ()
	local possible_targets = FindTargetTagGroupEntitiesInRange(x, z, 30, inst.components.combat:GetFriendlyTargetTags())
	local seeds = FindTargetTagGroupEntitiesInRange(x, z, 100, healseed_tag)
	local ready_targets = 0

	-- Check to see if any other gourdos are currently creating a seed so we dont create more than needed
	for _, ent in pairs(possible_targets) do
		if (ent ~= inst and not ent.sg:HasStateTag("castingseed")) then
			ready_targets = ready_targets + 1
		end
	end

	local seedcount = lume.count(seeds)
	if (seedcount >= 1) then -- let the timer run only if there are no seeds
		local cooldown = 16 - TheNet:GetNrPlayersOnRoomChange() -- slightly speed up timer based on number of players
		inst.components.timer:StartTimer("buff_cd", cooldown, true)
	end

	return not inst.components.timer:HasTimer("buff_cd")
		and ready_targets >= 1
		and not TheWorld.components.roomclear:IsRoomComplete() -- do not summon healing seeds after everything is dead, important for Charmed Gourdos
end

local function DoHeal(inst)
	local target = nil
	local x,z = inst.Transform:GetWorldXZ()
	local possible_targets = FindTargetTagGroupEntitiesInRange(x, z, 60, inst.components.combat:GetFriendlyTargetTags())
	if lume.count(possible_targets) > 1 then
		local lowest_health = 1
		for _, ent in pairs(possible_targets) do
			if ent ~= nil and ent ~= inst and ent:IsValid() then
				local health = ent.components.health:GetPercent()
				if health < lowest_health then
					target = ent
					lowest_health = health
				end
			end
		end
		if target then
			inst:PushEvent("doheal", { target = target, pos = combatutil.GetWalkableOffsetPosition(target:GetPosition(), 1, 2) })
		end
	end
end

local BrainGourdo = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		KnockdownRecovery(inst),
		TargetLastAttacker(inst),
		IfNode(inst, CanHeal, "CanHeal",
			ActionNode(inst, DoHeal, "DoHeal")
		),
		ChaseAndAttack(inst),
		Wander(inst),
	}, .1))
end)

return BrainGourdo
