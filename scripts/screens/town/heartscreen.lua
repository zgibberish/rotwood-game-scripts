local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Panel = require("widgets/panel")
local Text = require("widgets/text")
local CheckBox = require "widgets.checkbox"
local ImageButton = require "widgets/imagebutton"
local easing = require "util.easing"
local Power = require "defs.powers"
local Heart = require"defs.hearts"
local lume = require"util.lume"
local itemforge = require"defs/itemforge"

local HEART_SLOTS_ORDERED =
{
	"FOREST",
	"SWAMP",
}

local HeartPowerWidget = Class(Widget, function(self, player, biome, heart, idx)
	Widget._ctor(self)

	self.player = player
	self.biome = biome
	self.heart = heart

	local name = self.heart.name
	local icon = self.heart.icon

	self.icon_bg = self:AddChild(Image("images/ui_ftf/hex_vertical.tex"))
		:SetName("Heart BG: ".. name)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetScale(.7)
	self.icon = self:AddChild(Image(icon))
		:SendToFront()

	local layout = idx == 1 and "before" or "after"

	local heart_levels = self.player.components.heartmanager:GetHeartLevelsForSlot(self.biome)
	local power_def = Power.FindPowerByName("heart_"..name)

	local power = itemforge.CreatePower(power_def, nil, heart_levels[idx] * self.heart.stacks_per_level)

	local desc_width = 800
	local desc_height = 200

	self.desc_bg = self:AddChild(Panel("images/ui_ftf_powers/power_details_no_tail.tex"))
		:SetNineSliceCoords(23, 23, 393, 166)
		:SetMultColor(0x261E1Dff)
		:SetInnerSize(desc_width, desc_height)
		:LayoutBounds(layout, "center", self.icon)

	self.desc_bg_border = self:AddChild(Panel("images/ui_ftf_powers/power_details_no_tail.tex"))
		:SetNineSliceCoords(23, 23, 393, 166)
		:SetMultColor(UICOLORS.KONJUR)
		:SetInnerSize(desc_width+15, desc_height+15)
		:LayoutBounds("center", "center", self.desc_bg)
		:SendToBack()
		-- :Hide()

	self.text_root = self:AddChild(Widget("Text Root"))
	self.title = self.text_root:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_SUBTITLE))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetAutoSize(desc_width)
		:SetText(power_def.pretty.name)

	self.desc = self.text_root:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetAutoSize(desc_width)
		:SetText(Power.GetDescForPower(power))
		:LayoutBounds("center", "below", self.title)

	self.text_root:LayoutBounds("center", "center", self.desc_bg)
end)

function HeartPowerWidget:SetSelected(bool, instant)
	if not self.discovered then return end

	self.selected = bool

	local pres_time = 0.5

	if self.selected then
		self.desc_bg_border:Show()
		if instant then
			self.icon:SetScale(1)
			self:SetSaturation(1)
		else
			self:RunUpdater(Updater.Parallel{
				Updater.Ease(function(v) self.icon:SetScale(v) end, 0.60, 1, pres_time, easing.outElasticUI),
				Updater.Ease(function(v) self:SetSaturation(v) end, 0, 1, pres_time, easing.outElasticUI),
			})
		end
	else
		self.desc_bg_border:Hide()
		if instant then
			self.icon:SetScale(0.60)
			self:SetSaturation(0)
		else
			self:RunUpdater(Updater.Parallel{
				Updater.Ease(function(v) self.icon:SetScale(v) end, 1, 0.60, pres_time, easing.outElasticUI),
				Updater.Ease(function(v) self:SetSaturation(v) end, 1, 0, pres_time, easing.outElasticUI),
			})
		end
	end
end

function HeartPowerWidget:SetDiscovered(bool)
	self.discovered = bool

	if not self.discovered then
		self.desc_bg_border:Hide()
		self.desc_bg:SetMultColorAlpha(0.20)
		self.text_root:SetMultColorAlpha(0.75)
		self.title:SetText("????")
		self.desc:SetText("????")
		self.icon:SetMultColor(0,0,0,1)
		self.icon:SetScale(1)
	end
end

function HeartPowerWidget:DoUnlockPres()
	self.icon:SetScale(0.5)
	self.icon:SetRotation(45)
	self.text_root:SetMultColorAlpha(0)

	self:RunUpdater(Updater.Parallel{
		Updater.Ease(function(v) self.icon:SetScale(v) end, 0.5, 1, 1.5, easing.outElasticUI),
		Updater.Ease(function(v) self.icon:SetRotation(v) end, 45, 0, 1.5, easing.outElasticUI),
		Updater.Ease(function(v) self.text_root:SetMultColorAlpha(v) end, 0, 1, 1.5, easing.inCubic),
	})
end

local BiomeGroup = Class(Widget, function(self, player, biome)
	Widget._ctor(self)

	self.player = player
	self.biome = biome
	self.biome_hearts = lume.sort(Heart.GetAllHeartsOfFamily(biome), function(a, b) return a.idx < b.idx end)

	if #self.biome_hearts ~= 2 then
		assert(false, ("[%s] does not have 2 heart powers defined!"):format(biome))
	end

	self.bg = self:AddChild(Image("images/global/square.tex"))
			:Hide()
			:SetMasked()
			:LayoutBounds("center", "center")

	self.containers = self:AddChild(Widget(biome.." Container"))

	self.heart_widgets = {}

	for i = 1, 2 do
		self.heart_widgets[i] = HeartPowerWidget(self.player, self.biome, self.biome_hearts[i], i)
	end

	-- TOGGLE
	self.toggle = CheckBox()
		:SetName("Check box")
		:SetIsSlider(true)
		:SetValue(false, true)
		:SetOnChangedFn(function(toggled) self:OnToggleBiome(toggled) end)

	-- the order in which these are added as children is important to how the widget lays out
	self.containers:AddChild(self.heart_widgets[1]) -- add the first power as a child
	self.containers:AddChild(self.toggle) -- add the toggle as a child
	self.containers:AddChild(self.heart_widgets[2]) -- add the second power as a child
	self.containers:LayoutChildrenInRow(20) -- layout the widgets in a single row
	self.containers:LayoutBounds("center", "center", self.bg)

	self.active_heart = player.components.heartmanager:GetEquippedIdxForSlot(biome)
	self.inactive_heart = self.active_heart == 1 and 2 or 1

	self:RefreshApperance(true)
end)

function BiomeGroup:InitBG(width, height, color)
	self.bg:Show()
	self.bg:SetSize(width, height)
	self.bg:SetMultColor(color)
end

function BiomeGroup:RevealNewPower(idx)
	self:OnToggleBiome(idx == 2)
	self.heart_widgets[idx]:DoUnlockPres()
end

function BiomeGroup:OnToggleBiome(toggled)
	self.active_heart = toggled and 2 or 1
	self.inactive_heart = toggled and 1 or 2

	self:UpdateHeartManager()
	self:RefreshApperance()
end

function BiomeGroup:UpdateHeartManager()
	local heartmanager = self.player.components.heartmanager
	heartmanager:EquipHeart(self.biome, self.active_heart)
end

function BiomeGroup:EnableToggle()
	self.toggle:Show()
end

function BiomeGroup:DisableToggle()
	self.toggle:Hide()
end

function BiomeGroup:RefreshApperance(instant)

	if self.active_heart == 0 then
		-- No heart is active. This means the player has not yet deposited a heart from this biome, and this should be hidden
		self.heart_widgets[1]:SetDiscovered(false)
		self.heart_widgets[2]:SetDiscovered(false)
		self:DisableToggle()
	else
		local heart_levels = self.player.components.heartmanager:GetHeartLevelsForSlot(self.biome)
		local all_discovered = true

		for i, level in ipairs(heart_levels) do
			if level == 0 then
				self.heart_widgets[i]:SetDiscovered(false)
				all_discovered = false
			else
				self.heart_widgets[i]:SetDiscovered(true)
			end
		end

		if not all_discovered then
			self:DisableToggle()
		else
			self:EnableToggle()
			self.toggle:SetValue(self.active_heart == 2, true)
		end

		self.heart_widgets[self.active_heart]:SetSelected(true, instant)
		self.heart_widgets[self.inactive_heart]:SetSelected(false, instant)
	end
end

function BiomeGroup:SetDefaultFocus()
	if self.toggle:IsShown() then
		self.toggle:SetFocus()
		return true
	end
end

local HeartScreen = Class(Screen, function(self, player, on_close_cb)
	Screen._ctor(self, "HeartScreen")
	self:SetOwningPlayer(player)

	player:UnlockFlag("pf_seen_heart_screen") -- flag used to determine if the player has seen this screen yet
	TheWorld:PushEvent("we_heart_screen_opened") -- used to trigger quest mark updates during tutorial flow

	self.on_close_cb = on_close_cb

	self.darken = self:AddChild(Image("images/ui_ftf_roombonus/background_gradient.tex"))
		:SetAnchors("fill", "fill")
		:SetMultColorAlpha(0)

	----------------------------------------------------------------------------------
	-- Root (allows us to center the two panels in the screen)
	----------------------------------------------------------------------------------

	self.root = self:AddChild(Widget())
		:SetName("Root")

	self.bg = self.root:AddChild(Image("images/bg_popup_flat/popup_flat.tex"))
		:SetName("Dialog background")
		:SetSize(RES_X * .75, RES_Y * .75)

	self.bg_mask = self.root:AddChild(Image("images/bg_popup_flat_inner_mask/popup_flat_inner_mask.tex"))
		:SetName("Dialog background mask")
		:SetSize(RES_X * .75, RES_Y * .75)
		:SetMask()

	self.close_button = self.bg:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetName("Close button")
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		:SetOnClick(function() self:OnCloseButton() end)
		:LayoutBounds("right", "top", self.bg)
		:Offset(-40, 0)

	self.heart_title_bg = self:AddChild(Image("images/ui_ftf_gems/gem_panel_title_bg.tex"))
		:SetName("Heart title bg")
	self.heart_title = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE, STRINGS.UI.HEARTSCREEN.HEARTS_TITLE, UICOLORS.BACKGROUND_DARK))
		:SetName("Heart title")

	self.biome_groups = self.root:AddChild(Widget("Biome Groups"))

	self.biome_widgets = {}

	for i, slot in ipairs(HEART_SLOTS_ORDERED) do
		local biome_group = self.biome_groups:AddChild(BiomeGroup(player, slot))
		local w, h = self.bg_mask:GetSize()
		biome_group:InitBG(w, 275, i%2 == 0 and HexToRGB(0xd6c3abff) or HexToRGB(0xe8d3baff))
		self.biome_widgets[slot] = biome_group
	end

	local w, h = self.heart_title:GetSize()
	self.heart_title_bg:SetSize(w + 150, 120)
		:LayoutBounds("center", "top", self.bg)
		:Offset(0, -30)
	self.heart_title:LayoutBounds("center", "center", self.heart_title_bg)
		:Offset(0, 0)

	self.biome_groups:LayoutBounds("center", "below", self.heart_title_bg)
		:Offset(0, -60)
		:LayoutChildrenInColumn(0)
end)

function HeartScreen:OnCloseButton()
	if self.on_close_cb then
		self.on_close_cb()
	end

	TheFrontEnd:PopScreen(self)
end

function HeartScreen:SetDefaultFocus()
	for i, slot in ipairs(HEART_SLOTS_ORDERED) do
		local biome_group = self.biome_widgets[slot]
		local has_focus = biome_group:SetDefaultFocus()
		if has_focus then
			return true
		end
	end

	self.close_button:SetFocus()
	return true
end

function HeartScreen:RevealNewPower(slot, idx)
	self.biome_widgets[slot]:RevealNewPower(idx)
end

HeartScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.CANCEL,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.CANCEL", Controls.Digital.CANCEL))
		end,
		fn = function(self)
			self:OnCloseButton()
			return true
		end,
	},
}

return HeartScreen
