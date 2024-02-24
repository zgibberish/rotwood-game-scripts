local KnockdownRecovery = require "behaviors.knockdownrecovery"
local RunAway = require "behaviors.runaway"
local RangeAndAttack = require "behaviors.rangeandattack"
local TargetLastAttacker = require "behaviors.targetlastattacker"
local Wander = require "behaviors.wander"
local Leash = require "behaviors.leash"

local combatutil = require "util.combatutil"

local function WantsToEscape(inst)
	local numEnemiesOnMap = TheWorld.components.roomclear and TheWorld.components.roomclear:GetEnemyCount() or 0
	return numEnemiesOnMap > 1 and inst.sg.mem.wants_to_escape
end

local function HasEscapePos(inst)
	local self = inst.brain.brain
	return self.escape_pos ~= nil
end

local function GetEscapePos(inst)
	local self = inst.brain.brain
	return self.escape_pos
end

local function StartEscape(inst)
	if HasEscapePos(inst) then return end
	local pos = combatutil.GetWalkableOffsetPosition(inst:GetPosition(), 15, 20)
	inst.brain.brain:SetEscapePos(pos)
	inst:PushEvent("escape", pos)
end

local BrainMothballTeen = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		KnockdownRecovery(inst),
		TargetLastAttacker(inst),
		--RunAway(inst, 1, 15),
		IfNode(inst, WantsToEscape, "WantsToEscape",
			SequenceNode({
				ActionNode(inst, StartEscape, "StartEscape"),
				Leash(inst, GetEscapePos, 2, 2, false),
			})
		),
		RangeAndAttack(inst, 10, 25, 30),
		Wander(inst),
	}, .1))
end)

function BrainMothballTeen:SetEscapePos(pos)
	self.escape_pos = pos
	self:Reset()
end

function BrainMothballTeen:OnEscaped()
	self.escape_pos = nil
	self:Reset()
end

return BrainMothballTeen
