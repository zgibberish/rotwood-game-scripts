-- Manages a group of JointAoEChild entities
-- Manages the dealing of damage for the group of entities, and treats all of their hitboxes as a single hitbox

local lume = require "util.lume"
local SGCommon = require "stategraphs.sg_common"

local JointAoEParent = Class(function(self, inst)
	self.inst = inst
	self.children = {}
	self.aoe_data = nil
	self.beam = false

	self._on_remove_child = function(source) self:RemoveChild(source) end
	self._on_hitbox_triggered = function(source, data) self:OnHitboxTriggered(data) end

	self.inst:ListenForEvent("room_complete", function()
		for _, child in ipairs(self.children) do
			child:PushEvent("despawn")
		end
	end, TheWorld)
end)

function JointAoEParent:Setup(data)
	self.aoe_data = data
	self.inst.components.hitbox:SetHitGroup(data.hitgroup)
	self.inst.components.hitbox:SetHitFlags(data.hitflags)

	-- Parent needs to be in charge of setting the repeat target delay
	self.inst.components.hitbox:StartRepeatTargetDelayTicks(data.repeat_target_delay)

	self.inst.components.combat:SetBaseDamage("aoe_child", data.base_damage)
	self.inst.components.attacktracker:AddAttack("aoe_attack", { damage_mod = data.damage_mod })

	if data.beam then
		self.beam = true
	end

	self.inst:ListenForEvent("hitboxtriggered", self._on_hitbox_triggered)
end

function JointAoEParent:OnHitboxTriggered(data)
	SGCommon.Events.OnHitboxTriggered(self.inst, data.targets, {
		attackdata_id = "aoe_attack",
		hitstoplevel = HitStopLevel.NONE,
		hitflags = Attack.HitFlags.GROUND,
		set_dir_angle_to_target = true,
		combat_attack_fn = "DoBasicAttack",
		disable_hit_reaction = true,
		hit_fx_offset_x = 0.5,
		hit_target_pst_fn = function(_attacker, target, _attack)
			SGCommon.Fns.BlinkAndFadeColor(target, { 255/255, 50/255, 50/255, 1 }, 8)
		end,
	})
end

function JointAoEParent:PushAoEHitboxFromChild(child)
	if self.beam then
		self.inst.components.hitbox:PushOffsetBeamFromChild(-self.aoe_data.hitbox_size, self.aoe_data.hitbox_size, self.aoe_data.beam_thickness or self.aoe_data.hitbox_size, 0, child, HitPriority.MOB_DEFAULT)
	else
		self.inst.components.hitbox:PushOffsetCircleFromChild(0, 0, self.aoe_data.hitbox_size, 0, child, HitPriority.MOB_DEFAULT)
	end
end

function JointAoEParent:AddChild(child)
	self.inst:ListenForEvent("onremove", self._on_remove_child, child)
	table.insert(self.children, child)
end

function JointAoEParent:RemoveChild(child)
	if not lume.find(self.children, child) then return end

	lume.remove(self.children, child)
	self.inst:RemoveEventCallback("onremove", self._on_remove_child, child)

	if #self.children == 0 then
		-- do you have any children left? If not, remove yourself.
		-- printf("~~~Ran out of children! Removing self.")
		self.inst:Remove()
	end
end

function JointAoEParent:MergeParents(other)
	-- printf("!Merging Two AoE Parents!")
	for _, child in ipairs(other.components.jointaoeparent.children) do
		child.components.jointaoechild:JoinParent(self.inst)
	end
end

return JointAoEParent
