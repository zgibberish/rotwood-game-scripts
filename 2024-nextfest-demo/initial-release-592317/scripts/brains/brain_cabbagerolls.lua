local ChaseAndAttack = require "behaviors.chaseandattack"
local FaceEntity = require "behaviors.faceentity"
local KnockdownRecovery = require "behaviors.knockdownrecovery"
local Leash = require "behaviors.leash"
local TargetLastAttacker = require "behaviors.targetlastattacker"
local Wander = require "behaviors.wander"

local function CanCombine(inst)
	return inst.components.cabbagerollstracker:CanCombine()
end

local function CanJump(inst)
	return inst.components.cabbagerollstracker:GetNum() == 1
end

local function GetOtherBrain(other)
	return (other:IsLocal() and other.brain ~= nil) and other.brain.brain or nil
end

local function ShouldTryCombine(inst)
	local self = inst.brain.brain
	if self.combinetarget == nil and not inst.components.timer:HasTimer("combine_cd") then
		local target = inst.components.cabbagerollstracker:FindNearest(1, 12)
		if target ~= nil and target:IsValid() and target:CanTakeControl() and target:TryToTakeControl() then
			local targetbrain = GetOtherBrain(target)
			if targetbrain ~= nil and targetbrain.combinetarget == nil then
				self.combinetarget = target
				return true
			end
		end
	end
	return false
end

local function TryCombine(inst)
	local self = inst.brain.brain
	if self.combinetarget then
		if self.combinetarget:IsValid() and self.combinetarget:TryToTakeControl() then
			self.combinetarget:PushEvent("combine_req", inst)
			local targetbrain = GetOtherBrain(self.combinetarget)
			if targetbrain == nil or targetbrain.combinetarget ~= inst then
				self.combinetarget = nil
			end
		else
			self.combinetarget = nil
		end
	end
end

local function IsAttemptingCombine(inst)
	local self = inst.brain.brain
	if self.combinetarget ~= nil then
		if self.combinetarget:IsValid() and self.combinetarget:TryToTakeControl() then
			local targetbrain = GetOtherBrain(self.combinetarget)
			if targetbrain ~= nil and targetbrain.combinetarget == inst then
				return true
			end
		end
		self.combinetarget = nil
	end
	return false
end

local function DoCombineJump(inst)
	local self = inst.brain.brain
	inst:PushEvent("docombine", self.combinetarget)
end

local function GetCombineTarget(inst)
	local self = inst.brain.brain
	return self.combinetarget
end

local function CancelCombineTarget(inst)
	local self = inst.brain.brain
	self.combinetarget = nil
end

local BrainCabbageRolls = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		KnockdownRecovery(inst),
		TargetLastAttacker(inst),
		IfNode(inst, CanCombine, "CanCombine",
			PriorityNode({
				EventNode(self, "combinewait",
					ParallelNodeAny({
						SequenceNode({
							WaitNode(1),
							ActionNode(inst, CancelCombineTarget, "CancelCombineTarget"),
						}),
						FaceEntity(inst, GetCombineTarget),
					})),
				WhileNode(inst, IsAttemptingCombine, "IsAttemptingCombine",
					ParallelNodeAny({
						PriorityNode({
							FailIfSuccessDecorator(
								Leash(inst, GetCombineTarget, 2.8, 2.8, false)),
							IfNode(inst, CanJump, "CanJump",
								ActionNode(inst, DoCombineJump, "DoCombineJump")),
							ParallelNodeAny({
								SequenceNode({
									WaitNode(1),
									ActionNode(inst, CancelCombineTarget, "CancelCombineTarget"),
								}),
								FaceEntity(inst, GetCombineTarget),
							}),
						}, .1),
						SequenceNode({
							WaitNode(5),
							ActionNode(inst, CancelCombineTarget, "CancelCombineTarget"),
						}),
					})),
				IfNode(inst, ShouldTryCombine, "ShouldTryCombine",
					ActionNode(inst, TryCombine, "TryCombine")),
			}, .1)),
		ChaseAndAttack(inst),
		Wander(inst),
	}, .1))

	self.combinetarget = nil
end)

function BrainCabbageRolls:SetCombineTarget(target)
	self.combinetarget = target
	self:Reset()
end

return BrainCabbageRolls
