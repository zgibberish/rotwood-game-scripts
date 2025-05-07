local ChaseAndAttack = require "behaviors.chaseandattack"
local KnockdownRecovery = require "behaviors.knockdownrecovery"
local TargetLastAttacker = require "behaviors.targetlastattacker"
local Wander = require "behaviors.wander"
local Leash = require "behaviors.leash"
local combatutil = require "util.combatutil"

local function WantsToHealSelf(inst)
	return inst.components.battoadsync:GetStolenKonjur() > 0 and not inst:IsAirborne()
end

local function GetHealPos(inst)
	local position = inst.components.battoadsync:GetHealPos()
	-- if position then
	-- 	local DebugDraw = require "util.debugdraw"
	-- 	DebugDraw.GroundDiamond(position.x, position.z, 1, WEBCOLORS.CYAN, 0, 1)
	-- end
	return position
end

local function HasHealPos(inst)
	return inst.components.battoadsync:GetHealPos() ~= nil
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
	inst:PushEvent("doheal", inst.components.battoadsync:GetHealPos())
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
	self.inst.components.battoadsync:SetHealPos(nil)
	self:Reset()
end

function BrainBattoad:SetHealTarget(target)
	self.inst.components.battoadsync:SetHealPos(target)
	self:Reset()
end

return BrainBattoad
