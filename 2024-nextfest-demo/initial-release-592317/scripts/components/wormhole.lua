local ParticleSystemHelper = require "util.particlesystemhelper"
local EffectEvents = require "effectevents"
local lume = require "util.lume"

-- Banded data for scaling the FX based on distance, broken up into two FX to retain visual integrity
local smalldata =
{
	-- distance, scale
	{0, 	0.5},
	{1.8, 	0.9},
	{3.2, 	1.15},
	{5.7, 	1.5},
	{9.2, 	1.9},
	{13.2, 	2.3},
	{15, 	2.35},
}
local largedata =
{
	-- distance, scale
	{15, 	1.35},
	{16, 	1.45},
	{19.5, 	1.57},
	{22, 	1.67},
	{25, 	1.8},
	{30, 	1.95},
	{35, 	2.125},
	{40, 	2.25},
	{45, 	2.415},
	{100, 	4}, --just a guess!
}

local function OnTeleportStart(inst)
	inst.Physics:SetEnabled(false)
	inst.HitBox:SetEnabled(false)
	inst:Hide()
	if inst.sg then
		inst.sg:Pause("teleporting")
	end
	inst.AnimState:Pause("teleporting")
	inst:PushEvent("teleport_start")

	-- JAMBELL TODO: Would be nice to help the player execute moves they input while 'in between' -- increase the controlqueuetick count and try to execute their attack on the way out.
	-- if inst.components.playercontroller ~= nil then
	-- 	inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", TELEPORT_DELAY)
	-- 	inst.components.playercontroller:OverrideControlQueueTicks("lightattack", TELEPORT_DELAY)
	-- 	inst.components.playercontroller:OverrideControlQueueTicks("dodge", TELEPORT_DELAY)
	-- 	inst.components.playercontroller:OverrideControlQueueTicks("potion", TELEPORT_DELAY)
	-- end
end

local function OnTeleportEnd(inst)
	inst.Physics:SetEnabled(true)
	inst.HitBox:SetEnabled(true)
	if inst.sg then
		inst.sg:Resume("teleporting")
	end
	inst.AnimState:Resume("teleporting")
	inst:Show()
	inst:PushEvent("teleport_end")

	-- JAMBELL TODO: Would be nice to help the player execute moves they input while 'in between' -- increase the controlqueuetick count and try to execute their attack on the way out.
	-- JAMBELL: Not currently working because TryNextQueuedAction doesn't always seem to respect the state we're in... probably needs more carefully written player stategraphs.
	-- if inst.components.playercontroller ~= nil then
	-- 	SGPlayerCommon.Fns.TryNextQueuedAction(inst)
	-- 	inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
	-- 	inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
	-- 	inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
	-- 	inst.components.playercontroller:OverrideControlQueueTicks("potion", nil)
	-- end
end

local TELEPORT_DELAY = 25
local function OnHitBoxTriggered(inst, data)
	--print("hitboxtriggered")
	local teleported = false
	--local last_tick = TheSim:GetTick()-1
	local teleport_log = inst.components.wormhole.teleport_log
	-- for ent,teleported_tick in pairs(teleport_log) do
	-- 	if (teleported_tick ~= last_tick) and (teleported_tick ~= last_tick+1) then
	-- 		-- They last collided on a tick that wasn't last tick or this tick, so they've stepped off the teleport and back onto it. Teleporting again is OK now!
	-- 		teleport_log[ent] = nil
	-- 		print("resetting")
	-- 	end
	-- end

	local targets = data.targets
	--print(inst.prefab.." can teleport")
	local buffer_tick = TheSim:GetTick() - 30 -- How many ticks ago should the thing have teleported, before we allow a re-teleport trigger on a pair of portals? If this number is too low, they get trapped in infinite teleport hell pretty easily
	for i = 1, #targets do
		if not targets[i]:HasTag("no_teleport") then
			if teleport_log[targets[i]] ~= nil then
				local last_teleported_tick = teleport_log[targets[i]]
				--print("last_teleported_tick ["..targets[i].prefab..":"..targets[i].GUID.."]: ["..last_teleported_tick.."]        buffer_tick: ["..buffer_tick.."]")
				if last_teleported_tick <= buffer_tick then
					--print(last_teleported_tick.." <= "..buffer_tick.."      CLEAR FROM TELEPORT LOG: ["..targets[i].prefab..":"..targets[i].GUID.."]")
					-- They last collided on a tick that wasn't in the last 5 ticks, so they've stepped off the teleport and back onto it. Teleporting again is OK now!
					teleport_log[targets[i]] = nil
					--inst.components.projectilehitbox:RemoveCanTakeControlFunction()
				end
			end

			if teleport_log[targets[i]] == nil and inst.components.wormhole.teleport_forbidden[targets[i]] == nil then
				local next_wormhole = inst.components.wormhole:GetOtherWormhole()
				if next_wormhole ~= nil then
					next_wormhole.components.wormhole:TeleportTarget(targets[i])
					teleported = true

					next_wormhole.components.wormhole.teleport_log[targets[i]] = TheSim:GetTick() + TELEPORT_DELAY
					teleport_log[targets[i]] = TheSim:GetTick()
	--inst.components.projectilehitbox:SetCanTakeControlFunction(function() return false end)
					break
				end
			else
				teleport_log[targets[i]] = TheSim:GetTick() -- This entity is still colliding with this hitbox, so continue pushing forward the 'teleported tick' to prevent re-summons
			end
		end
	end

	if teleported then
		inst.sg:GoToState("teleport")
	end
end

-- Wormhole component for helping manage teleporting networked entities.
local Wormhole = Class(function(self, inst)
	self.inst = inst
	self.inst:StartUpdatingComponent(self)

	self.can_teleport = nil
	self.wormhole_id = nil -- ID to identify the wormhole vs. its counterpart.
	self.other_wormhole = nil -- Reference to the paired wormhole.
	self.teleport_forbidden = {} -- This is a list of things which cannot be teleported.
	self.teleport_log = {} -- Log of entities that stepped on this wormhole to prevent them from teleporting again after re-appearing.

	self.teleport_ent = nil -- Current entity to teleport.

    self.inst:ListenForEvent("hitboxtriggered", OnHitBoxTriggered)
end)

function Wormhole:Setup(owner, id)
	if not owner then return end

	self.wormhole_id = id

	local x, z = owner.Transform:GetWorldXZ()
	self.inst.Transform:SetPosition(x, 0, z)

	-- Put this player into the list so they don't immediately teleport, then in 15 ticks allow them to be teleportable.
	self.teleport_forbidden[owner] = true
	self.inst:DoTaskInTicks(15, function() self.teleport_forbidden[owner] = nil end)
end

function Wormhole:RemoveWormhole()

	if not self.inst:IsLocal() then
		self.inst:TakeControl()
	end

	self.can_teleport = false

	-- Remove pairing with the linked wormhole
	self:UnpairWormhole(self.other_wormhole)

	self.inst:PushEvent("unsummon")
end

function Wormhole:GetOtherWormhole()
	return self.other_wormhole
end

function Wormhole:CanTeleport()
	return self.can_teleport
end

function Wormhole:EnableTeleport(enabled)
	self.can_teleport = enabled
end

function Wormhole:OnNetSerialize()
	local e = self.inst.entity

	-- wormhole_id
	e:SerializeBoolean(self.wormhole_id == 2)

	-- can_teleport
	e:SerializeBoolean(self.can_teleport)

	-- other_wormhole
	local other_wormhole_valid = self.other_wormhole ~= nil and self.other_wormhole:IsValid() and not self.other_wormhole:IsInLimbo()
	e:SerializeBoolean(other_wormhole_valid)
	if other_wormhole_valid then
		e:SerializeEntityID(self.other_wormhole and self.other_wormhole.Network:GetEntityID())
	end
end

-- TODO: Copied from revive component. Consider making this a common function.
local function TryGetEntity(entity_id)
	local guid = TheNet:FindGUIDForEntityID(entity_id)
	if guid and guid ~= 0 and Ents[guid] and Ents[guid]:IsValid() then
		return Ents[guid]
	end
	return nil
end

function Wormhole:OnNetDeserialize()
	local e = self.inst.entity

	-- wormhole_id
	self.wormhole_id = e:DeserializeBoolean() and 2 or 1

	-- can_teleport
	self.can_teleport = e:DeserializeBoolean()

	-- other_wormhole
	local other_wormhole_exists = e:DeserializeBoolean()
	if other_wormhole_exists then
		local ent_id = e:DeserializeEntityID()
		local ent = TryGetEntity(ent_id)
		self.other_wormhole = ent
	end
end

function Wormhole:PairWormhole(other)
	if not other then return end

	if not other:IsLocal() then
		other:TakeControl()
	end

	self.other_wormhole = other
	other.components.wormhole.other_wormhole = self.inst
end

function Wormhole:UnpairWormhole(other)
	self.other_wormhole = nil
	if other then
		if not other:IsLocal() then
			other:TakeControl()
		end

		other.components.wormhole.other_wormhole = nil
	end
end

function Wormhole:TeleportTarget(target)
	local source = self.other_wormhole
	if not source then return end

	self.inst:PushEvent("teleported_to")
	local x,z = self.inst.Transform:GetWorldXZ()
	target.Transform:SetPosition(x,0,z)
	OnTeleportStart(target)

	target:DoTaskInTicks(TELEPORT_DELAY, function()
		OnTeleportEnd(target)

		EffectEvents.MakeEventSpawnEffect(target, { fxname = "fx_portal_pulse_out3" } )
		EffectEvents.MakeEventSpawnEffect(target, { fxname = "fx_portal_pulse_out2" } )
		EffectEvents.MakeEventSpawnEffect(target, { fxname = "fx_portal_pulse_out" } )

		ParticleSystemHelper.MakeOneShotAtPosition(self.inst:GetPosition(), "fx_portal_burst_out", 1, target)

	end)

	ParticleSystemHelper.MakeOneShotAtPosition(source:GetPosition(), "fx_portal_burst_in", 1, target)

	EffectEvents.MakeEventSpawnEffect(target, { fxname = "fx_portal_pulse_in2" } )
	EffectEvents.MakeEventSpawnEffect(target, { fxname = "fx_portal_pulse_in" } )

	source:DoTaskInTicks(14, function()
		FakeBeamFX(source, self.inst, "fx_portal_jump", smalldata, largedata)
	end)
end

function Wormhole:OnUpdate()
	if self.can_teleport then
		self.inst.components.hitbox:PushBeam(-0.5, 0.5, 0.5, HitPriority.MOB_DEFAULT)
	end
end

return Wormhole
