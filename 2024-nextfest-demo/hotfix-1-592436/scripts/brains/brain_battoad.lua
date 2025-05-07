local ChaseAndAttack = require "behaviors.chaseandattack"
local KnockdownRecovery = require "behaviors.knockdownrecovery"
local TargetLastAttacker = require "behaviors.targetlastattacker"
local Wander = require "behaviors.wander"
local Leash = require "behaviors.leash"
local combatutil = require "util.combatutil"

local function WantsToHealSelf(inst)
	return inst.components.battoadsync.stolen_konjur > 0 and not inst:IsAirborne()
end

local function GetHealPos(inst)
	local self = inst.brain.brain

	-- if self.heal_target then
	-- 	local DebugDraw = require "util.debugdraw"
	-- 	DebugDraw.GroundDiamond(self.heal_target.x, self.heal_target.z, 1, WEBCOLORS.CYAN, 0, 1)
	-- end

	return self.heal_target
end

local function HasHealPos(inst)
	return GetHealPos(inst) ~= nil
end

local function CanHealSelf(inst)
	-- busy tag makes it so the battoad will not turn around mid-state
	return WantsToHealSelf(inst) and HasHealPos(inst) and not inst.sg:HasStateTag("busy")
end

local function FindHealPos(inst)
	if HasHealPos(inst) then return end
	local pos = combatutil.GetWalkableOffsetPosition(inst:GetPosition(), 20, 30)
	--DebugDraw.GroundPoint(pos, nil, 1, WEBCOLORS.YELLOW, 1, 3)
	inst.brain.brain:SetHealTarget(pos)
end

local function DoHeal(inst)
	local self = inst.brain.brain
	inst:PushEvent("doheal", self.heal_target)
end

local BrainBattoad = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		KnockdownRecovery(inst),
		TargetLastAttacker(inst),
		IfNode(inst, WantsToHealSelf, "WantsToHealSelf",
			SequenceNode({
				ActionNode(inst, FindHealPos, "FindHealPos"),
				IfNode(inst, CanHealSelf, "CanHealSelf",
					SequenceNode({
						Leash(inst, GetHealPos, 6, 6, false),
						ActionNode(inst, DoHeal, "DoHeal")
					})
				)
			})
		),
		ChaseAndAttack(inst),
		Wander(inst),
	}, .1))
end)

function BrainBattoad:OnHealed()
	self.heal_target = nil
	self:Reset()
end

function BrainBattoad:SetHealTarget(target)
	self.heal_target = target
	self:Reset()
end

return BrainBattoad
