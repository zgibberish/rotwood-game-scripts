local Consumable = require("defs.consumable")
local Image = require "widgets.image"
local Text = require("widgets/text")
local Widget = require("widgets/widget")

local KonjurWidget =  Class(Widget, function(self, size, owner)
	Widget._ctor(self, "KonjurWidget")

	self.owner = owner
	self.size = size

	self.roomstart_showtime = 5 -- At the start of a room, how long do we show this widget for until it fades out?

	local icon = Consumable.Items.MATERIALS.konjur.icon
	self.icon = self:AddChild(Image(icon))
		:SetSize(self.size, self.size)

	self.text_root = self:AddChild(Widget("Text Root"))
		:LayoutBounds("after", "center", self.icon)
		:Offset(5, 0)

	self.text = self.text_root:AddChild(Text(FONTFACE.DEFAULT, self.size * 0.75, nil, UICOLORS.LIGHT_TEXT_TITLE))
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()

	self.inst:ListenForEvent("inventory_stackable_changed", function(inst, itemdef)
		if itemdef == Consumable.Items.MATERIALS.konjur then
			self:RefreshCount(itemdef)
		end
	end, owner)

	self:RefreshCount(Consumable.Items.MATERIALS.konjur)

	-- Uncomment this to make the konjur widget disappear during combat, and reappear after combat.
	-- Disabling this for now because players frequently want to know their konjur mid-combat for future planning in down times of combat.
	-- self.inst:ListenForEvent("room_locked", function() self:Hide() end, TheWorld)
	-- self.inst:ListenForEvent("enter_room", function()
	-- 	local worldmap = TheDungeon:GetDungeonMap()
	-- 	if worldmap:DoesCurrentRoomHaveCombat() then
	-- 		self.inst:DoTaskInTime(self.roomstart_showtime, function()
	-- 			self:AlphaTo(0, 0.5, easing.outExpo,
	-- 				function()
	-- 					self:Hide()
	-- 				end) end)
	-- 	end
	-- end, owner)
	-- self.inst:ListenForEvent("room_complete", function()
	-- 		self:AlphaTo(1, 0.5, easing.inExpo,
	-- 			function()
	-- 				self:Show()
	-- 			end)
	-- 		end, TheWorld)
end)

function KonjurWidget:RefreshCount(def)
	local konjur = self.owner.components.inventoryhoard:GetStackableCount(def)
	self.text:SetText(konjur)
	self:SetToolTip(string.format(STRINGS.UI.KONJURSOULSWIDGET.NUM, konjur))
end

return KonjurWidget
