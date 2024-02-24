local DungeonSignposts = require "widgets.ftf.dungeonsignposts"
local Widget = require "widgets.widget"


local DungeonHud = Class(Widget, function(self, debug_root)
	Widget._ctor(self, "DungeonHud")

	self._onroomlocked = function() self:Clear() end
	self.inst:ListenForEvent("room_locked", self._onroomlocked, TheWorld)

end)

function DungeonHud:OnRemoveEntity()
	self.inst:RemoveEventCallback("room_locked", self._onroomlocked, TheWorld)
end

function DungeonHud:AttachPlayerToHud(player)
	return self
end

function DungeonHud:DetachPlayerFromHud(player)
	return self
end

function DungeonHud:ShowExitSignposts()
	if self.signpost or not DungeonSignposts.CanShowSignposts() then
		return
	end

	self.signpost = self:AddChild(DungeonSignposts())
		:SetAnchors("left", "center")
		:AnimateIn()
end

function DungeonHud:Clear()
	TheLog.ch.UI:printf("DungeonHud: Clearing map signpost")
	if self.signpost then
		self.signpost:Remove()
		self.signpost = nil
	end
end

return DungeonHud
