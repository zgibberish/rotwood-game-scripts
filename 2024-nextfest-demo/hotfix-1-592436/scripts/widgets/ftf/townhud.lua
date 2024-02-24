local Button = require "widgets.button"
local CraftButton = require("widgets/ftf/craftbutton")
local HotkeyWidget = require "widgets.hotkeywidget"
local HudButton = require "widgets.ftf.hudbutton"
local InventoryScreen = require "screens.town.inventoryscreen"
local TownHudWidget = require("widgets/ftf/townhudwidget")
local Widget = require("widgets/widget")
local playerutil = require "util.playerutil"


-- The whole hud widget for in town.
local TownHud = Class(Widget, function(self, debug_root)
	Widget._ctor(self, "TownHud")
	self.debug_root = debug_root
end)

function TownHud:OnBecomeActive()
	if self.townHudWidget then
		self.townHudWidget:Refresh()
	end
end

function TownHud:_Init()
	local player = self:GetOwningPlayer()
	dbassert(player)
	self.root = self:AddChild(Widget("TownHud_root"))
		:LayoutBounds("left", "top", self.parent)

	self.townHudWidget = self.root:AddChild(TownHudWidget(self.debug_root))
		:LayoutBounds("center", "top", self.parent)

	-- Add craft button to the bottom right
	self.craftButton = self.root:AddChild(CraftButton(function() self:OnCraftButtonClicked() end))
		:LayoutBounds("right", "bottom", self.parent)
		:Offset(-20, 20)
		:Hide() -- 2023-09-06: Disabling craft menu for network playtest

	self.testButton = self.root:AddChild(Button())
		 :LayoutBounds("right", "bottom", self.parent)
		 :Offset(-20, 20)
		 :SetTextSize(48)

	-- Get a reference to the crafting-details floating panel, and position it on the screen
	self.craftDetailsPanel = self.craftButton:GetDetailsPanel()
		:LayoutBounds("center", "top", self.parent)
		:Offset(0, -150)
		:MemorizePosition()

	self.inventoryButton = self.root:AddChild(self:_CreateInventoryButton())
		:LayoutBounds("left", "bottom", self.parent)
		:Offset(20, 40)
end


function TownHud:AttachPlayerToHud(player)
	--~ TheLog.ch.FrontEnd:print("TownHud:AttachPlayerToHud", player)
	if not self:GetOwningPlayer() then
		-- Only take the first player as the primary owner.
		self:SetOwningPlayer(player)
	end
	if not self.root then
		self:_Init()
	end
	self.townHudWidget:AttachPlayerToHud(player)
	self.craftButton:Refresh()
	return self
end

function TownHud:DetachPlayerFromHud(player)
	self.townHudWidget:DetachPlayerFromHud(player)
	return self
end

function TownHud:GetControlMap()
	if self.craftButton and self.craftButton:IsBarOpen() then
		return self.craftButton:GetControlMap()
	end
end

function TownHud:AnimateIn()
	-- TODO: Could have nicer animation, but this works for now.
	self:Show()
	return self
end

function TownHud:AnimateOut()
	self:Hide()
	return self
end

function TownHud:_CreateInventoryButton()
	local fn = function(device_type, device_id)
		local player = TheInput:GetDeviceOwner(device_type, device_id)
		-- Our UI generally works with mouse, so find a player if there's no mouse user.
		player = player or (device_type == "mouse" and playerutil.GetFirstLocalPlayer())
		if player then
			self:OnInventoryButtonClicked(player)
		end
	end
	local button = Widget("InventoryButton")
	button.btn = button:AddChild(HudButton(360, "images/ui_ftf_shop/hud_button_inventory.tex", UICOLORS.ACTION, fn))
	button.hotkeyWidget = button:AddChild(HotkeyWidget(Controls.Digital.OPEN_INVENTORY, STRINGS.UI.INVENTORYSCREEN.BUTTON_LABEL):SetWidgetSize(32))
		:LayoutBounds("center", "below", button.btn)
		:Offset(0, -10)
	button.hotkeyWidget:SetOnLayoutFn(function()
		button.hotkeyWidget:LayoutBounds("center", "below", button.btn)
			:Offset(0, -10)
	end)
	return button
end

-- Also called by playerhud to handle Controls.Digital.OPEN_CRAFTING hotkey
function TownHud:OnCraftButtonClicked()
	if self.craftButton:IsShown() and self.craftButton:IsEnabled() then
		self.craftButton:ToggleBar()
	end
end

function TownHud:IsCraftMenuOpen()
	return self.craftButton:IsBarOpen()
end

-- Also called by playerhud to handle Controls.Digital.OPEN_INVENTORY hotkey
function TownHud:OnInventoryButtonClicked(player)
	if self.inventoryButton:IsShown() and self.inventoryButton:IsEnabled() then
		TheFrontEnd:PushScreen(InventoryScreen(player))
	end
end

return TownHud
