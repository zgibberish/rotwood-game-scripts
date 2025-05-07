local InstanceLog = require "util.instancelog"
local lume = require "util.lume"
require "class"


-- Want to create something by mashing together different entities and their
-- anims? Try this.
local AnimPrototyper = Class(function(self, inst)
	self.inst = inst
	assert(DEV_MODE, "Don't ship any creatures with this component.")
end)

local function AddSuffix(t, base_anim, suffix)
	local anim = base_anim .. suffix
	if not t[anim] then
		t[anim] = t[base_anim]
	end
end

-- Remap animations to different body parts. Allows you to use a composite
-- creature with SGCommon's pre/pst features.
-- Format for input:
--
-- config = {
--   	parts = {
--   		body = inst,
--   		face = Another Entity,
--   	},
--   	anim_map = {
--   		roll = "body",
--   		pierce = "face",
--   	},
--   	anim_when_inactive = {
--   		face = {
--   			anim = "evade",
--   			loop = false,
--   			frame = 16, -- setting frame implies pause
--   		},
--   	},
--   }
function AnimPrototyper:HookupAnimationRedirector(config)
	for _,anim in ipairs(lume.keys(config.anim_map)) do
		-- Assume suffixes use the same part unless otherwise specified.
		AddSuffix(config.anim_map, anim, "_pre")
		AddSuffix(config.anim_map, anim, "_hold")
		AddSuffix(config.anim_map, anim, "_loop")
		AddSuffix(config.anim_map, anim, "_pst")
	end
	self.config = config
	self.inst:Debug_WrapNativeComponent("AnimState")
	self.inst.AnimState.PlayAnimation = function(this, anim, loop)
		local target = self:GetPartForAnim(anim)
		for partname,part in pairs(self.config.parts) do
			if target == part then
				local target_animstate = target.AnimState._original or target.AnimState
				assert(target_animstate ~= this, "Calling PlayAnimation or self will infinite loop.")
				target_animstate:Resume()
				target_animstate:PlayAnimation(anim, loop)
				self:Logf("[%s] PlayAnimation '%s'.", partname, anim)

			else
				local when_inactive = self.config.anim_when_inactive[partname]
				if when_inactive then
					assert(when_inactive.anim, "Anim name is required.")
					part.AnimState:PlayAnimation(when_inactive.anim, when_inactive.loop)
					if when_inactive.frame then
						part.AnimState:SetFrame(when_inactive.frame)
						part.AnimState:Pause()
					end
					self:Logf("[%s]  Inactive. Play '%s'.", partname, when_inactive.anim)
				end
			end
		end
	end
end

function AnimPrototyper:GetPartForAnim(anim)
	local partname = self.config.anim_map[anim]
	return self.config.parts[partname] or self.inst
end

function AnimPrototyper:DebugDrawEntity(ui, panel, colors)
	panel:AppendTable(ui, self.config, "config")
	-- TODO: Would be nice to reposition the body parts to make live edit easier.
	self:DebugDraw_Log(ui, panel, colors)
end



-- InstanceLog lets us use self:Logf for logs that show in DebugEntity.
AnimPrototyper:add_mixin(InstanceLog)
return AnimPrototyper
