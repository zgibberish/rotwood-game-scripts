local FollowLabel = require "widgets.ftf.followlabel"


-- TODO(dbriscoe): Should use Label native component instead? See also
-- spawnutil.AddWorldLabel.
local WorldText = Class(function(self, inst)
	self.inst = inst
end)

-- If a positive lifetime is specified, retire the WorldText after that period. Otherwise, it lives until explicitly
-- retired by the client.
function WorldText:Initialize(text, position, size, color, lifetime)
	dbassert(Vector3.is_vec3(position))
	size = size or FONTSIZE.COMMON_OVERLAY
	color = color or WEBCOLORS.WHITE

	self.inst.Transform:SetPosition(position:unpack())
	local followtext = FollowLabel()
		:SetText(text)
	followtext:GetLabelWidget()
		:SetFont(FONTFACE.CODE)
		:SetFontSize(size)
		:SetGlyphColor(color)

	local hud = TheDungeon.HUD
	if hud then
		hud:OverlayElement(followtext)
		-- followtext:SetHUD(hud)
	else
		-- HACK: No hud, then attach to something so we don't barf on destroy.
		TheFrontEnd.sceneroot:AddChild(followtext)
	end

	followtext:SetTarget(self.inst)
	followtext:SetClickable(false)
	followtext:Show()
	self.inst.followtext = followtext

	-- If a lifetime is specified, retire the WorldText after that period. Otherwise, it lives until explicitly
	-- retired by the client.
	if lifetime and 0 < lifetime then
		self.inst:DoTaskInTime(lifetime, function()
			if self.inst:IsValid() then
				self.inst.followtext:Remove()
				self.inst:Remove()
			end
		end)
	end
end

return WorldText
