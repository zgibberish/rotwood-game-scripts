local Consumable = require "defs.consumable"
local Text = require "widgets/text"
local Widget = require "widgets.widget"
require "class"

local widget_order =
{
	"konjur_soul_lesser",
	-- "konjur_heart",
	--"glitz"
}

local CurrencyPanel = Class(Widget, function(self)
	Widget._ctor(self, "CurrencyPanel")
	self.pretty = {
		konjur_soul_lesser = STRINGS.UI.INVENTORYSCREEN.KONJUR_SOUL_LESSER,
		-- konjur_heart = STRINGS.UI.INVENTORYSCREEN.KONJUR_HEART,
		--glitz = STRINGS.UI.INVENTORYSCREEN.GLITZ,
	}

	self.padding = {
		w = 40,
		h = 20,
	}

	self.widgets = {}

	for _, currency_kind in ipairs(widget_order) do
		local pretty_str = self.pretty[currency_kind]
		self.widgets[currency_kind] = self:AddChild(Text(FONTFACE.DEFAULT, 50, pretty_str, UICOLORS.KONJUR))
			:SetToolTip(string.format(STRINGS.TOWN.HUD.KONJUR_TT, STRINGS.ITEMS.MATERIALS[currency_kind].name, STRINGS.ITEMS.MATERIALS[currency_kind].desc))
	end
end)

function CurrencyPanel:SetPlayer(player)
	self.player = player
	self:Refresh()

	self.inst:ListenForEvent("inventory_stackable_changed", function(inst, itemdef)
		if itemdef.tags['currency'] and table.find(widget_order, itemdef.name) then
			self:Refresh()
		end
	end, player)

	self.inst:ListenForEvent("unlock_consumable", function(inst, consumable)
		if table.find(widget_order, consumable) then
			self:Refresh()
		end
	end, player)

	return self
end

function CurrencyPanel:SetFontSize(size)
	for _,w in pairs(self.widgets) do
		w:SetFontSize(size)
	end
	return self
end

function CurrencyPanel:ModifyTextWidgets(fn)
	for _,w in pairs(self.widgets) do
		fn(w)
	end
	return self
end

function CurrencyPanel:SetBgColor(...)
	return self
end

function CurrencyPanel:SetRemoveVPadding()
	self.padding.h = 0
	return self
end

function CurrencyPanel:Refresh()
	for currency, widget in pairs(self.widgets) do
		-- don't show non-serialized currencies in HUD for remote players
		local item = self.player.components.inventoryhoard:GetSlotItems(Consumable.Slots.MATERIALS)[currency]
		if not self.player.components.unlocktracker:IsConsumableUnlocked(currency) or
			(not self.player:IsLocal() and (not item or not item:HasTag("netserialize"))) then
			widget:Hide()
		else
			widget:Show()
		end
	end

	local konjurW, konjurH = 0,0
	for currency_kind,currency_widget in pairs(self.widgets) do
		-- Update konjur count
		local mat_def = Consumable.Items.MATERIALS[currency_kind]
		local currency_count = self.player.components.inventoryhoard:GetStackableCount(mat_def) or 0
		currency_widget:SetText(string.format(self.pretty[currency_kind], currency_count))

		-- Update konjur background size
		local w,h = currency_widget:GetSize()
		konjurW = konjurW + w
		konjurH = math.max(konjurH, h)
	end

	self:LayoutChildrenInRow(20)

	self.player:PushEvent("refresh_hud")
end

return CurrencyPanel
