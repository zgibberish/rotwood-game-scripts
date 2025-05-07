-- Pass in an array of powers
-- Display them in a grid
-- Allow selection of one of the powers
-- Display a confirmation screen on selection
-- Execute code when confirmed

-- Useful for stuff like picking a power to upgrade or remove.

local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Panel = require("widgets/panel")
local Text = require("widgets/text")
local ActionButton = require("widgets/actionbutton")
local PlayerUnitFrames = require("widgets/ftf/playerunitframes")
local PowerConfirmationScreen = require("screens.dungeon.powerconfirmationscreen")
local PowerDescriptionButton = require "widgets.ftf.powerdescriptionbutton"
local fmodtable = require "defs.sound.fmodtable"
local Consumable = require "defs.consumable"
local Power = require "defs.powers.power"


local ConfirmAction = PowerConfirmationScreen.ConfirmAction

---------------- BUTTON

local PowerButton = Class(PowerDescriptionButton, function(self, player)
	PowerDescriptionButton._ctor(self)
	self.player = player

	self:AddPriceDisplay(player)

	self._on_inventory_changed = function()
		self:RefreshCanAfford() -- refresh text colour
	end
	self.inst:ListenForEvent("inventory_stackable_changed", self._on_inventory_changed, self.player)
end)


local function CalcPrice(power, free)
	local price = free and 0 or Power.GetUpgradePrice(power)
	return price
end

-- Accepts power ItemInstance instead of pow since may present unselected powers.
function PowerButton:SetPower(power, free)
	PowerButton._base.SetPower(self, power, false, true)

	self.free = free

	local price = CalcPrice(power, free)
	self:SetPrice(price, free)

	self:RefreshCanAfford()
end

function PowerButton:RefreshCanAfford()
	local price = CalcPrice(self.power, self.free)
	local inventory = self.player.components.inventoryhoard
	local can_afford = inventory:GetStackableCount(Consumable.Items.MATERIALS.konjur) >= price

	if can_afford then
		TheLog.ch.UI:printf("Can Afford Upgrade")
		self:SetSaturation(1)
		self:SetToolTip(nil)
	else
		TheLog.ch.UI:printf("Cannot Afford Upgrade")
		self:SetSaturation(0)
		self:SetToolTip(STRINGS.UI.POWERSELECTIONSCREEN.NOT_ENOUGH)
	end
end

---------------- TITLE

local PowerSelectionTitleWidget = Class(Widget, function(self)
	Widget._ctor(self, "PowerSelectionTitleWidget")

	self.frameContainer = self:AddChild(Widget())
	self.frameLeft = self.frameContainer:AddChild(Panel("images/map_ftf/map_title_frame_left.tex"))
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetNineSliceCoords(100, 42, 150, 58)
		:SetNineSliceBorderScale(0.5)
		:SetSize(300, 200)
	self.frameRight = self.frameContainer:AddChild(Panel("images/map_ftf/map_title_frame_right.tex"))
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetNineSliceCoords(100, 42, 150, 58)
		:SetNineSliceBorderScale(0.5)
		:SetSize(300, 200)

	self.textContent = self:AddChild(Widget())
	self.title = self.textContent:AddChild(Text(FONTFACE.DEFAULT, 60, "", UICOLORS.LIGHT_TEXT_DARK))
end)

function PowerSelectionTitleWidget:SetTitle(title)
	self.title:SetText(title)

	local w, h = self.title:GetSize()
	w = math.max(w, 200) + 130
	h = h + 60

	self.frameLeft:SetSize( w / 2, h)
	self.frameRight:SetSize( w / 2, h)
		:LayoutBounds("after", nil, self.frameLeft)

	self.textContent:LayoutBounds("center", "top", self.frameContainer)
		:Offset(0, -15)

	return self
end

---------------- SCREEN

local PowerSelectionScreen = Class(Screen, function(self, player, powers, action, cb_fn, free, prevent_cancel)
	Screen._ctor(self, "PowerSelectionScreen")
	assert(ConfirmAction:Contains(action), "Use PowerSelectionScreen.SelectAction enum.")
	assert(powers and powers[1])
	self:SetAudioCategory(Screen.AudioCategory.s.PartialOverlay)

	self:SetOwningPlayer(player)

	self.cb_fn = cb_fn
	self.powers = powers
	self.action = action
	self.free = free
	self.prevent_cancel = prevent_cancel

	self.bg = self:AddChild(Image("images/ui_ftf_roombonus/background_gradient.tex"))
		:SetAnchors("fill", "fill")

	self.list_hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetSize(RES_X - 200, RES_Y - 800)
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0)

	local title = STRINGS.UI.POWERSELECTIONSCREEN.TITLE_POWER[action]
	if powers[1].def.power_type == Power.Types.SKILL then
		title = STRINGS.UI.POWERSELECTIONSCREEN.TITLE_SKILL[action]
	end
	self.title = self:AddChild(PowerSelectionTitleWidget())
		:SetTitle(title)

	self.power_container = self:AddChild(Widget("Power Container"))

	self.nav_buttons = self:AddChild(Widget("Nav Buttons"))

	if not self.prevent_cancel then
		self.cancel_button = self.nav_buttons:AddChild(ActionButton())
			:SetSize(BUTTON_W, BUTTON_H)
			:SetText(STRINGS.UI.POWERSELECTIONSCREEN.CANCEL_BUTTON)
			:SetOnClick(function() self:CloseScreen() end)
	end

	self:BuildPowerGrid()

	self.title
		:LayoutBounds("center", "above", self.list_hitbox)
		:Offset(0, 60)
	self.nav_buttons:LayoutBounds("center", "below", self.list_hitbox)
		:Offset(0, -60)

	-- victorc: hack - player status on screen
	self.player_unit_frames = self:AddChild(PlayerUnitFrames())

	-- victorc: hack - player status on screen
	TheDungeon.HUD.player_unit_frames:Hide()

end)
PowerSelectionScreen.SelectAction = ConfirmAction

function PowerSelectionScreen.DebugConstructScreen(cls, player)
	local powers = player.components.powermanager:GetUpgradeablePowers()
	if #powers == 0 then
		d_powerup(4)
		c_currencydungeon(300)
		powers = player.components.powermanager:GetUpgradeablePowers()
	end
	return PowerSelectionScreen(player, powers, ConfirmAction.s.Upgrade, function() end)
end

function PowerSelectionScreen:DebugDraw_AddSection(ui, panel)
	PowerSelectionScreen._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("PowerSelectionScreen")
	ui:Indent() do
		local function ForceNumPowers(power_count)
			while #self.powers > power_count do
				table.remove(self.powers)
			end
			local n = power_count - #self.powers
			for i=1,n do
				table.insert(self.powers, self.powers[i])
			end
			self:BuildPowerGrid()
		end
		for i=1,5 do
			local power_count = i * self.btn_column_count
			if ui:Button("Power Count: ".. power_count) then
				ForceNumPowers(power_count)
			end
			ui:SameLineWithSpace()
		end
	end
	ui:Unindent()
end


PowerSelectionScreen.CONTROL_MAP = {
	{
		control = Controls.Digital.CANCEL,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"STRINGS.UI.POWERSELECTIONSCREEN.CANCEL_BUTTON", Controls.Digital.CANCEL))
		end,
		fn = function(self)
			if not self.prevent_cancel then
				self:CloseScreen()
				return true
			end
		end,
	},
}


function PowerSelectionScreen:CloseScreen()
	TheFrontEnd:PopScreen(self)
	-- victorc: hack - player status on screen
	TheDungeon.HUD.player_unit_frames:Show()
	-- TheDungeon.HUD:Show()
end

function PowerSelectionScreen:SetDefaultFocus()
	if self.power_container.children and #self.power_container.children > 0 then
		self.power_container.children[1]:SetFocus()
	else
		if self.cancel_button ~= nil then 
			self.cancel_button:SetFocus()
		end
	end
end

function PowerSelectionScreen:OnSelectPower(power)
	-- show a confirmation screen depending on the action that the player is doing

	local on_confirm_fn = function()
		self:CloseScreen()
		-- do the action that was confirmed
		-- consume the currency that was charged

		if self.cb_fn then
			self.cb_fn(power)
		end

		local price = CalcPrice(power, self.free) --currently this price is the same for remove or upgrade... should that be true?
		local inventory = self.owningplayer.components.inventoryhoard
		-- victorc: hack - local multiplayer, use the same inventory as main player

		if price ~= nil and price > 0 then
			inventory:RemoveStackable(Consumable.Items.MATERIALS.konjur, price)
		end
		if self.action == ConfirmAction.s.Upgrade then
			self.owningplayer.components.powermanager:UpgradePower(power:GetDef())
		elseif self.action == ConfirmAction.s.Remove then
			self.owningplayer.components.powermanager:RemovePower(power:GetDef())
		end
		TheDungeon:GetDungeonMap():RecordActionInCurrentRoom(self.action)
	end

	local canafford = self:CheckCanAfford(self.owningplayer, power)
	local screen = PowerConfirmationScreen(self.owningplayer, power, canafford, self.free, self.action, on_confirm_fn)
	TheFrontEnd:PushScreen(screen)
end

function PowerSelectionScreen:CheckCanAfford(player, power)
	local price = CalcPrice(power, self.free)
	local can_afford = player.components.inventoryhoard:GetStackableCount(Consumable.Items.MATERIALS.konjur) >= price
	return can_afford
end

function PowerSelectionScreen:BuildPowerGrid()

	-- Reset scale before starting
	self.power_container:SetScale(1)
	self.power_container:RemoveAllChildren()

	local padding_h = 70
	local padding_v = 50
	local max_columns = 4

	for i, pow in ipairs(self.powers) do
		local button = self.power_container:AddChild(PowerButton(self.owningplayer))
		button:SetPower(pow.persistdata, self.free)
		button:SetOnClick(function() self:OnSelectPower(pow.persistdata) end)
	end

	-- Layout list
	self.power_container:LayoutInDiagonal(max_columns, padding_h, padding_v)

	-- Check if the list is too large for the available space, and scale it down accordingly
	local list_w, list_h = self.power_container:GetSize()
	local max_w, max_h = self.list_hitbox:GetSize()
	local scale = self.power_container:GetScale()
	if list_w > max_w then
		-- Too wide
		local ratio = max_w / list_w
		self.power_container:SetScale(ratio)
	end
	scale = self.power_container:GetScale()
	list_w, list_h = self.power_container:GetScaledSize()
	if list_h > max_h then
		-- Too tall
		local ratio = max_h / list_h
		self.power_container:SetScale(scale * ratio)
	end

	self.power_container
		:LayoutBounds("center", "center", self.list_hitbox)
end

function PowerSelectionScreen:SetActionUpgrade()
	self.action = ConfirmAction.s.Upgrade
	return self
end

function PowerSelectionScreen:SetActionRemove()
	self.action = ConfirmAction.s.Remove
	return self
end

return PowerSelectionScreen
