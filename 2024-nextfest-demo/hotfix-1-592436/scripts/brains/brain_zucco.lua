local ChaseAndAttack = require "behaviors.chaseandattack"
local KnockdownRecovery = require "behaviors.knockdownrecovery"
local Leash = require "behaviors.leash"
local TargetLastAttacker = require "behaviors.targetlastattacker"
local Wander = require "behaviors.wander"
local krandom = require "util.krandom"
local combatutil = require "util.combatutil"
local lume = require "util.lume"

local function InSneakMode(inst)
	return inst.brain.brain.in_sneak_mode and inst:ShouldHide()
end

local function NotInSneakMode(inst)
	return not InSneakMode(inst)
end

-----------------------------------------------

local function ShouldPlaceTraps(inst)
	local self = inst.brain.brain
	local x,z = inst.Transform:GetWorldXZ()
	local num_traps = FindTargetTagGroupEntitiesInRange(x, z, 100, {"zuccobomb"})

	return lume.count(num_traps) < self.num_traps_to_place
end

local function GetTrapTarget(inst)
	local self = inst.brain.brain

	--if self.traptarget then
	--	local DebugDraw = require "util.debugdraw"
	--	DebugDraw.GroundDiamond(self.traptarget.x, self.traptarget.z, 1, WEBCOLORS.CYAN, 0, 1)
	--end

	return self.traptarget
end

local function HasTrapTarget(inst)
	return GetTrapTarget(inst) ~= nil and not inst.sg:HasStateTag("busy")
end

local function FindTrapTarget(inst)
	if HasTrapTarget(inst) then return end
	local pos = combatutil.GetWalkableOffsetPosition(inst:GetPosition(), 15, 30)
	inst.brain.brain:SetTrapTarget(pos)
end

local function PlaceTrap(inst)
	local self = inst.brain.brain
	inst:PushEvent("placetrap", self.traptarget)
end

-----------------------------------------------

local function ShouldEscape(inst)
	return not ShouldPlaceTraps(inst) and not inst.sg:HasStateTag("busy")
end

local function GetEscapeTarget(inst)
	local self = inst.brain.brain
	return self.escapetarget
end

local function HasEscapeTarget(inst)
	return GetEscapeTarget(inst) ~= nil
end

local function FindEscapeTarget(inst)
	if HasEscapeTarget(inst) then return end

	local sc = TheWorld.components.spawncoordinator
	local spawners = {}
	local x, z = inst.Transform:GetWorldXZ()
	for i, spawner in pairs(sc.spawners) do
		local sx, sz = spawner.Transform:GetWorldXZ()
		if spawner:CanSpawnCreature(inst) and inst:GetDistanceSqTo(spawner) > 5*5 and (math.abs(x-sx) > 10) then
			table.insert(spawners, spawner)
		end
	end
	if #spawners > 0 then
		local target = krandom.PickFromArray(spawners)
		inst.brain.brain:SetEscapeTarget(target)
	end
end

local function DoEscape(inst)
	local self = inst.brain.brain
	inst:PushEvent("doescape", self.escapetarget)
end

local function OnBombExploded(inst, trap)
	local self = inst.brain.brain
	if self and trap then
		if self.placed_traps[trap] then
			self.placed_traps[trap] = nil
		end
	end
end

local BrainZucco = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		KnockdownRecovery(inst),
		TargetLastAttacker(inst),
		IfNode(inst, InSneakMode, "InSneakMode",
			PriorityNode({
				-- place trap
				WhileNode(inst, ShouldPlaceTraps, "ShouldPlaceTraps",
					SequenceNode({
						ActionNode(inst, FindTrapTarget, "FindTrapTarget"),
						IfNode(inst, HasTrapTarget, "HasTrapTarget",
							SequenceNode({
								Leash(inst, GetTrapTarget, 5, 5, false),
								ActionNode(inst, PlaceTrap, "PlaceTrap")
							})
						)
					})),

				-- jump back into bush
				WhileNode(inst, ShouldEscape, "ShouldEscape",
					SequenceNode({
						ActionNode(inst, FindEscapeTarget, "FindEscapeTarget"),
						IfNode(inst, HasEscapeTarget, "HasEscapeTarget",
							SequenceNode({
								Leash(inst, GetEscapeTarget, 3, 3, false),
								ActionNode(inst, DoEscape, "DoEscape")
							})
						)
					})),
			}, 0.5)),
		IfNode(inst, NotInSneakMode, "NotInSneakMode",
			ChaseAndAttack(inst)),
		Wander(inst),
	}, .1))

	self.in_sneak_mode = true
	self.escapetarget = nil
	self.traptarget = nil
	self.num_traps_placed = 0
	self.num_traps_to_place = 2

	-- TODO: move planted bomb tracking into its own generic component that other monsters can use
	self.placed_traps = {}
end)

function BrainZucco:DonePlacingTraps()
	return not ShouldPlaceTraps(self.inst)
end

function BrainZucco:OnSetTrap(trap)
	if trap then
		self.placed_traps[trap] = true
		trap.owner = self.inst
	end
	self.traptarget = nil
	self:Reset()
end

function BrainZucco:SetEscapeTarget(target)
	self.escapetarget = target
	self:Reset()
end

function BrainZucco:SetTrapTarget(target)
	self.traptarget = target
	self:Reset()
end

function BrainZucco:ResetTrapData()
	self.traptarget = nil
	self:Reset()
end

return BrainZucco
