local ChaseAndAttack = require "behaviors.chaseandattack"
local RangeAndAttack = require "behaviors.rangeandattack"
local KnockdownRecovery = require "behaviors.knockdownrecovery"
local TargetLastAttacker = require "behaviors.targetlastattacker"
local Wander = require "behaviors.wander"
local Leash = require "behaviors.leash"
local combatutil = require "util.combatutil"
local lume = require"util.lume"
local Power = require"defs.powers"
local shield_def = Power.Items.SHIELD.shield
local jugg_def = Power.Items.STATUSEFFECT.juggernaut

local function GetBuffTarget(inst)
	local self = inst.brain.brain
	return self.buff_target
end

local function HasBuffTarget(inst)
	return GetBuffTarget(inst) ~= nil
end

local function DoBuff(inst)
	inst:PushEvent("dobuff", GetBuffTarget(inst))
end

local function ShouldFight(inst)
	return inst:ShouldFight()
end

local function ShouldBuff(inst)
	return not inst:ShouldFight()
end

local function WantsToBuff(inst)
	local x,z = inst.Transform:GetWorldXZ()
	local ignore_tags = not inst:HasTag("elite") and { "bulbug" } or nil
	local possible_targets = FindTargetTagGroupEntitiesInRange(x, z, 999, inst.components.combat:GetFriendlyTargetTags(), ignore_tags)

	local on_cooldown = inst.components.timer:HasTimer("buff_shield_cd") -- and inst.components.timer:HasTimer("buff_damage_cd")

	return not on_cooldown and (lume.count(possible_targets) > 0 and not (#possible_targets == 1 and possible_targets[1] == inst))
		--and TheWorld.components.roomclear:GetEnemyCount() > 0 -- TODO: ENABLE AFTER TESTING IS DONE SO BULBUG WILL NOT BUFF ENDLESSLY AFTER A WAVE
end

local function FindBuffTarget(inst)
	if HasBuffTarget(inst) then return end
	-- try to find a clump of buffable things, then find a position that's within range of as many of them as possible
	local x,z = inst.Transform:GetWorldXZ()
	local ignore_tags = not inst:HasTag("elite") and { "bulbug" } or nil
	local targets = FindTargetTagGroupEntitiesInRange(x, z, 999, inst.components.combat:GetFriendlyTargetTags(), ignore_tags)

	if #targets == 0 then return end

	local best_shield_target = nil
	local best_shield_count = 0

	-- local best_damage_target = nil
	-- local best_damage_count = 0

	for i, target in ipairs(targets) do
		if target ~= inst or (inst:HasTag("elite") and #targets == 1) or (target == inst and #targets > 1) then
			local tx,tz = target.Transform:GetWorldXZ()
			local possible_targets = FindTargetTagGroupEntitiesInRange(tx, tz, 8, inst.components.combat:GetFriendlyTargetTags(), ignore_tags)

			local shield_count = 0
			for i, tar in ipairs(possible_targets) do
				if not tar.components.powermanager:HasPower(shield_def) or tar.components.powermanager:GetPowerStacks(shield_def) < shield_def.max_stacks then
					shield_count = shield_count + 1
				end
			end

			if shield_count > best_shield_count then
				best_shield_count = shield_count
				best_shield_target = target
			end

			-- local damage_count = 0
			-- for i, tar in ipairs(possible_targets) do
			-- 	if not tar.components.powermanager:HasPower(jugg_def) or tar.components.powermanager:GetPowerStacks(jugg_def) < 50 then
			-- 		damage_count = damage_count + 1
			-- 	end
			-- end

			-- if damage_count > best_damage_count then
			-- 	best_damage_count = damage_count
			-- 	best_damage_target = target
			-- end
		end
	end

	if best_shield_count > 0 and best_shield_target and not inst.components.timer:HasTimer("buff_shield_cd") then
		-- printf("Best Count: %s", best_shield_count)
		inst.brain.brain:SetBuffData(best_shield_target, "shield")
	-- elseif best_damage_count > 0 and best_damage_target and not inst.components.timer:HasTimer("buff_damage_cd") then
	-- 	-- printf("Best Count: %s", best_damage_count)
	-- 	inst.brain.brain:SetBuffData(best_damage_target, "damage")
	end
end

local BrainBulbug = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		KnockdownRecovery(inst),
		TargetLastAttacker(inst),
		IfNode(inst, ShouldBuff, "ShouldBuff",
			PriorityNode({
				IfNode(inst, WantsToBuff, "WantsToBuff",
					SequenceNode({
						ActionNode(inst, FindBuffTarget, "FindBuffTarget"),
						IfNode(inst, HasBuffTarget, "HasBuffTarget",
							SequenceNode({
								Leash(inst, GetBuffTarget, 9, 7, false), -- collision avoidance makes it basically impossible for one creature to approach another
								ActionNode(inst, DoBuff, "DoBuff")
							}))
					})
				),
				RangeAndAttack(inst, 10, 10, 15)
			}, 0.1)),
		IfNode(inst, ShouldFight, "Should Fight",
			ChaseAndAttack(inst)), -- should try to stay away when in buff mode, but attack when alone.
		Wander(inst),
	}, .1))

	self._on_remove_target = function()
		self:ResetBuffData()
	end
end)

function BrainBulbug:ResetBuffData()
	self.inst:RemoveEventCallback("onremove", self._on_remove_target, self.buff_target)
	self.buff_target = nil
	self.buff_type = nil
	self:Reset()
end

function BrainBulbug:SetBuffData(target, buff)
	self.buff_target = target
	self.buff_type = buff
	self.inst:ListenForEvent("onremove", self._on_remove_target, self.buff_target)
	self:Reset()
end

return BrainBulbug
