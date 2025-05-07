local lume = require "util.lume"
require "class"


-- Stop player from getting lost behind foreground props by making them
-- invisible. Should do this with a shader instead. That would also allow us to
-- fade an area around the player instead of only the entities what overlaps
-- their position.
local FadeForeground = Class(function(self, inst)
	self.inst = inst
	self.inst:StartWallUpdatingComponent(self)
	self.fading = {}
	self.duration = 1.25
end)

local function should_fade(ent)
	-- HACK(dbriscoe): They follow a naming convention, but we should put a
	-- bool on them somewhere.
	return ent.prefab:find("_fg_", nil, true)
end

function FadeForeground:OnWallUpdate(dt)
	local x,y = TheSim:WorldToScreenXY(self.inst.Transform:GetWorldPosition())
	local to_fade = self:_AccumulateFadeTargets(x, y)
	self:_ApplyFadeToTargets(dt, to_fade)
end

function FadeForeground:_AccumulateFadeTargets(x, y)
	local include_hud = false
	local props_only = true
	local to_fade = TheSim:GetEntitiesAtScreenPoint(x, y, include_hud, props_only)
	to_fade = lume.filter(to_fade, should_fade)
	return to_fade
end

function FadeForeground:_ApplyFadeToTargets(dt, to_fade)
	local fade_in = shallowcopy(self.fading)
	local fade_out = {}
	for i,ent in ipairs(to_fade) do
		fade_in[ent] = nil
		if self.fading[ent] then
			-- Already in fade state, preserve current state.
			fade_out[ent] = self.fading[ent]
		else
			fade_out[ent] = 1
			ent.original_mult_color = {ent.AnimState:GetMultColor()}
		end
		self.fading[ent] = fade_out[ent]
	end

	local fade_delta = dt / self.duration
	self:_ApplyFade(fade_out, -fade_delta)
	-- Don't fade back in because our GetEntitiesAtScreenPoint doesn't seem
	-- very consistent with some fg trees. (forest_fg_tree variation 4)
	--~ self:_ApplyFade(fade_in, fade_delta)

	--~ for ent,fade in pairs(fade_in) do
	--~ 	if fade >= 1 then
	--~ 		self.fading[ent] = nil
	--~ 	end
	--~ end
end

function FadeForeground:_ApplyFade(to_fade, delta)
	for ent,original_fade in pairs(to_fade) do
		local fade = original_fade + delta
		fade = lume.clamp(fade, 0, 1)
		if original_fade ~= fade then
			self.fading[ent] = fade
			local r,g,b,a = table.unpack(ent.original_mult_color)
			a = lume.lerp(0.25, a, fade)
			ent.AnimState:SetMultColor(r,g,b,a)
		end
	end
end

function FadeForeground:DebugDrawEntity(ui, panel, colors)
	self.duration = ui:_SliderFloat("Duration", self.duration, 0.1, 4, "%0.2f seconds")

	panel:AppendTable(ui, self.fading, "self.fading")

	local to_fade = self:_AccumulateFadeTargets(TheSim:WorldToScreenXY(self.inst.Transform:GetWorldPosition()))
	panel:AppendTableInline(ui, to_fade, "On Current Position")
end


return FadeForeground
