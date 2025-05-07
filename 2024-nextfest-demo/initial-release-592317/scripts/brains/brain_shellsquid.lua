local ChaseAndAttack = require "behaviors.chaseandattack"
local KnockdownRecovery = require "behaviors.knockdownrecovery"
local RangeAndAttack = require "behaviors.rangeandattack"
local StandAndAttack = require "behaviors.standandattack"
local TargetLastAttacker = require "behaviors.targetlastattacker"
local Wander = require "behaviors.wander"



local function FindDashCandidates(inst)
	local x,z = inst.Transform:GetWorldXZ()
	return FindTargetTagGroupEntitiesInRange(x, z, 999, inst.components.combat:GetTargetTags())
end

local function WantsToDash(inst)
	local on_cooldown = inst.components.timer:HasTimer("dash_cd")

	return not on_cooldown
		and #FindDashCandidates(inst) > 0
end

local function GetDashTarget(inst)
	local self = inst.brain.brain
	return self.dash_target
end

local function ChooseDashTarget(inst)
	local possible_targets = FindDashCandidates(inst)
	if #possible_targets > 0 then
		inst.brain.brain:_SetDashData(possible_targets[1])
	end
end

local function DoDashAttack(inst)
	inst:PushEvent("start_dash", GetDashTarget(inst))
end

local function RecentlyHurt(inst)
	return inst.brain.brain:WasRecentlyHurt()
end

local BrainShellsquid = Class(Brain, function(self, inst)
	Brain._ctor(self, inst,
		PriorityNode({
				KnockdownRecovery(inst),
				TargetLastAttacker(inst),
				IfNode(inst, RecentlyHurt, "RecentlyHurt",
					ChaseAndAttack(inst)),
				--~ IfNode(inst, WantsToDash, "WantsToDash",
				--~ 	SequenceNode({
				--~ 			ActionNode(inst, ChooseDashTarget, "ChooseDashTarget"),
				--~ 			IfNode(inst, GetDashTarget, "HasDashTarget",
				--~ 				ActionNode(inst, DoDashAttack, "DoDashAttack"))
				--~ 		})
				--~ 	),
				--~ --~ RangeAndAttack(inst, max_z, min_x, max_x)
				RangeAndAttack(inst, 10, 7, 17),
				Wander(inst),
	}, .1))

	self._on_remove_target = function()
		self:_ResetDashData()
	end
	self._onhealthchanged = function(source, data) self:OnHealthChanged(data) end
	self.inst:ListenForEvent("healthchanged", self._onhealthchanged)
end)


function BrainShellsquid:OnHealthChanged(data)
	if data.old > data.new then
		self.last_hurt_tick = GetTick()
	end
end

local TICKS_FOR_RECENT = 1 * SECONDS
function BrainShellsquid:WasRecentlyHurt()
	local last = self.last_hurt_tick or 0
	return last - GetTick() < TICKS_FOR_RECENT
end

function BrainShellsquid:_ResetDashData()
	self.inst:RemoveEventCallback("onremove", self._on_remove_target, self.dash_target)
	self.dash_target = nil
	self:Reset()
end

function BrainShellsquid:_SetDashData(target)
	self.dash_target = target
	self.inst:ListenForEvent("onremove", self._on_remove_target, self.dash_target)
	self:Reset()
end

return BrainShellsquid
