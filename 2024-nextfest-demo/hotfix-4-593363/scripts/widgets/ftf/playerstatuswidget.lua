local Widget = require("widgets/widget")
local Image = require("widgets/image")
local SegmentedHealthBar = require("widgets/ftf/segmentedhealthbar")
local PlayerPortrait = require("widgets/ftf/playerportrait")
local PlayerUsernameWidget = require("widgets/ftf/playerusernamewidget")
local PlayerTitleWidget = require("widgets/ftf/playertitlewidget")
local PlayerPowersWidget = require("widgets/ftf/playerpowerswidget")
local ShieldPips = require("widgets/shieldpips")
local PotionWidget = require("widgets/ftf/potionwidget")
local Enum = require "util.enum"
local KonjurWidget = require("widgets/ftf/konjurwidget")
local CurrencyPanel = require "widgets.ftf.currencypanel"
local LootStackWidget = require("widgets/ftf/lootstackwidget")
local Text = require("widgets/text")
local easing = require "util.easing"


--- Displays a single player character's portrait, health bar, actions and buffs container

local BG_SCALE = 1

local PlayerStatusWidget = Class(Widget, function(self, owner)
	Widget._ctor(self, "PlayerStatusWidget")

	self:SetOwningPlayer(owner)
	self.owner = owner

	self:SetClickable(false)

	self.root = self:AddChild(Widget("PlayerStatusWidget root"))

	self.bg = self.root:AddChild(Widget())
	self.bg_static = self.bg:AddChild(Image("images/ui_ftf_hud/UI_HUD_BG_root.tex"))
		:SetRegistration("left", "top")
	self.bg_stretch = self.bg:AddChild(Image("images/ui_ftf_hud/UI_HUD_BG_stretch.tex"))
		:SetRegistration("left", "top")
		:LayoutBounds("after", "top", self.bg_static)

	-- Add username
	self.username = self.root:AddChild(PlayerUsernameWidget(self.owner))
		:SetFontSize(20 * HACK_FOR_4K)

	self.player_title = self.username:AddChild(PlayerTitleWidget(self.owner))
		:SetFontSize(20 * HACK_FOR_4K)

	self.health_bar = self.root:AddChild(SegmentedHealthBar(self.owner))
		:SetScale(1.3)

	-- Create portrait
	self.portrait = self.root:AddChild(PlayerPortrait())
		:SetScale(BG_SCALE, BG_SCALE)

	self.shield_pips = self.root:AddChild(ShieldPips(self.owner))
		:SetTheme_UnitFrame()
		:SetScale(BG_SCALE)

	-- Add powers widgets
	self.player_powers = self.root:AddChild(PlayerPowersWidget(self.owner))

	self.potion_widget = self.root:AddChild(PotionWidget(90 * HACK_FOR_4K, self.owner))

	self.konjur = self.root:AddChild(KonjurWidget(30 * HACK_FOR_4K, self.owner))

	self.meta_currency = self.root:AddChild(CurrencyPanel())
		:SetFontSize(50)
		:SetRemoveVPadding()
		:SetPlayer(owner)
		:ModifyTextWidgets(function(widget)
			widget:SetGlyphColor(UICOLORS.LIGHT_TEXT_TITLE)
			widget:SetShadowColor(UICOLORS.BLACK)
			widget:SetShadowOffset(1, -1)
			widget:SetOutlineColor(UICOLORS.BLACK)
			widget:EnableShadow()
			widget:EnableOutline()
		end)

	if TheDungeon:GetDungeonMap():DoesCurrentRoomHaveCombat() then
		self.inst:DoTaskInTime(3, function() self.meta_currency:AlphaTo(0, 1, easing.outExpo, function() self.meta_currency:Hide() end) end)
		self.inst:ListenForEvent("room_complete", function() self.meta_currency:AlphaTo(1, 1, easing.inExpo) end, TheWorld)
	end

	self.waiting_to_join = self.root:AddChild(Widget("Waiting To Join Root"))
		:Hide()

	self.waiting_to_join_outline = self.waiting_to_join:AddChild(Text(FONTFACE.DEFAULT, 60, STRINGS.UI.UNITFRAME.WAITING_TO_JOIN, UICOLORS.BLACK))
		:EnableShadow()
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:EnableOutline()
		:SetOutlineColor(UICOLORS.BLACK)
	self.waiting_to_join_text = self.waiting_to_join:AddChild(Text(FONTFACE.DEFAULT, 60, STRINGS.UI.UNITFRAME.WAITING_TO_JOIN, UICOLORS.LIGHT_TEXT_TITLE))

	self.loot_stack = self.root:AddChild(LootStackWidget(self.owner))
		:SetScale(0.75 * HACK_FOR_4K)

	self.inst:ListenForEvent("layout_mode_changed", function(inst, data)
		TheLog.ch.HUDSpam:print("layout_mode_changed")
		assert(self.LAYOUT_MODES:Contains(data)) -- Should use PlayerStatusWidget, but it doesn't exist yet.
		local layout_fn = self[data]
		if layout_fn then
			layout_fn(self, data)
		end

		for _, child in pairs(self.root:GetChildren()) do
			TheLog.ch.HUDSpam:print(child)
			layout_fn = child[data]
			if layout_fn then
				layout_fn(child, data)
			end
		end
	end)

	local _refresh_frame = function() self:OnCharacterChanged() end
	self.inst:ListenForEvent("charactercreator_load", _refresh_frame, self.owner)
	self.inst:ListenForEvent("player_post_load", _refresh_frame, self.owner)
	self.inst:ListenForEvent("inventorychanged", _refresh_frame, self.owner)
	self.inst:ListenForEvent("update_ui_color", _refresh_frame, self.owner)
	_refresh_frame()

	self.y_anim_scale = -1

	if self.owner:IsSpectating() then
		self:WaitingToJoin()
	end
end)

function PlayerStatusWidget:OnCharacterChanged()
	self.portrait:Refresh(self.owner)
	self.username:SetOwner(self.owner)
	self.player_title:SetOwner(self.owner)
	self.health_bar:RefreshColor()
	self.player_powers:RefreshPowers()

	if self.owner:IsSpectating() then
		self:WaitingToJoin()
	end

	self.owner:PushEvent("refresh_hud")
end

-- These keys match functions below.
PlayerStatusWidget.LAYOUT_MODES = Enum{
	"TOP_LEFT",
	"TOP_RIGHT",
	"BOTTOM_LEFT",
	"BOTTOM_RIGHT",
}

PlayerStatusWidget.UNIT_FRAME_LAYOUT_ORDER =
{
	[1] = PlayerStatusWidget.LAYOUT_MODES.s.TOP_LEFT,
	[2] = PlayerStatusWidget.LAYOUT_MODES.s.TOP_RIGHT,
	[3] = PlayerStatusWidget.LAYOUT_MODES.s.BOTTOM_LEFT,
	[4] = PlayerStatusWidget.LAYOUT_MODES.s.BOTTOM_RIGHT,
}

function PlayerStatusWidget:SetLayoutMode(mode)
	if mode ~= self.layout_mode then
		self.layout_mode = mode
		self.inst:PushEvent("layout_mode_changed", self.layout_mode)
	end
	self.root_x, self.root_y = 0,0
end

function PlayerStatusWidget:_GetAnimOffscreenY()
	-- Not sure why self has no size. bg has a valid size, so use that.
	local _, h = self.bg:GetSize()
	h = h + 170 -- bg doesn't extend to bottom.
	return self.y_anim_scale * h
end

function PlayerStatusWidget:AnimateIn(force)
	-- Animate into position
	if force then
		self.root:SetPosition(self.root_x, self:_GetAnimOffscreenY())
	end
	self.root:MoveTo(self.root_x, self.root_y, 0.9, easing.outElastic)

	return self
end

function PlayerStatusWidget:AnimateOut(cb)
	-- Animate off screen
	self.root:MoveTo(self.root_x, self:_GetAnimOffscreenY(), 0.2, easing.inQuad, cb)
	return self
end

function PlayerStatusWidget:_SetAlignment(hreg, vreg)
	self:SetAnchors(hreg, vreg)
	-- Do not set our own registration (self:SetRegistration(hreg, vreg)) or
	-- any of our widgets near the edge would move all of our children!

	self.bg:SetRegistration(hreg, vreg)
	self.health_bar:SetRegistration(hreg, vreg)
	self.konjur:SetRegistration(hreg, vreg)
	self.meta_currency:SetRegistration(hreg, vreg)
	self.loot_stack:SetRegistration(hreg, vreg)
	self.player_powers:SetRegistration(hreg, vreg)
	self.portrait:SetRegistration(hreg, vreg)
	self.potion_widget:SetRegistration(hreg, vreg)
	self.shield_pips:SetRegistration(hreg, vreg)
	self.username:SetRegistration(hreg, vreg)
	self.player_title:SetRegistration(hreg, vreg)
	self.waiting_to_join:SetRegistration(hreg, vreg)

	self.bg:SetAnchors(hreg, vreg)
	self.health_bar:SetAnchors(hreg, vreg)
	self.konjur:SetAnchors(hreg, vreg)
	self.meta_currency:SetAnchors(hreg, vreg)
	self.loot_stack:SetAnchors(hreg, vreg)
	self.player_powers:SetAnchors(hreg, vreg)
	self.portrait:SetAnchors(hreg, vreg)
	self.potion_widget:SetAnchors(hreg, vreg)
	self.shield_pips:SetAnchors(hreg, vreg)
	self.username:SetAnchors(hreg, vreg)
	self.player_title:SetAnchors(hreg, vreg)
	self.waiting_to_join:SetAnchors(hreg, vreg)

	self.y_anim_scale = vreg == "top" and 1 or -1
end

function PlayerStatusWidget:WaitingToJoin()
	self.waiting_to_join:Show()
	self.player_powers:Hide()
	self:StartUpdating()
end

function PlayerStatusWidget:OnUpdate()
	if not self.owner:IsSpectating() then
		self.waiting_to_join:Hide()
		self.player_powers:Show()
		self:StopUpdating()
	end
end

function PlayerStatusWidget:_Layout(anchors, to_middle)
	local to_edge = -to_middle

	-- Do alignment as if it's top-left, but use anchors instead of strings and
	-- to_middle/to_edge instead of negative and we'll automatically remap to
	-- the other corners.

	-- Don't draw too close to screen edges.
	local inset_pad = 25
	-- Prevent gaps around screen edge by starting draw a bit offscreen.
	local offscreen_pad = 5
	-- Not sure how we got this.
	local magic_width = 110

	self:SetPosition(to_edge:scale(offscreen_pad):unpack())
	self:_SetAlignment(anchors.left, anchors.top)

	self.bg:SetScale(BG_SCALE * to_middle.x, BG_SCALE * to_edge.y)

	self.username
		:LayoutBounds(anchors.left, anchors.top, self.bg)
		:Offset(inset_pad * to_middle.x, inset_pad * to_middle.y)
	
	self.player_title
		:LayoutBounds(anchors.center, anchors.below, self.username)
	  	--:Offset(inset_pad * to_middle.x, inset_pad * to_middle.y)
	
	-- TODO(dbriscoe): move shield inside portrait so layout is consistent.
	self.portrait
		:LayoutBounds(anchors.left, nil, self.username)
		:LayoutBounds(nil, anchors.below, self.player_title)
		:Offset(0, 16 * to_middle.y)

	self.shield_pips:RefreshLayout({})

	self.potion_widget
		:LayoutBounds(anchors.left, anchors.bottom, self.bg)
		:Offset(10 * to_edge.x, -100 * to_edge.y)

	self.konjur
		:LayoutBounds(anchors.center, anchors.below, self.potion_widget)
		:Offset(to_middle:scale(10):unpack())

	self.loot_stack
		:LayoutBounds(anchors.after, anchors.center, self.potion_widget)
		:Offset(0, 0)

	self.player_powers
		:LayoutBounds(anchors.after, anchors.top, self.portrait)
		:Offset(8 * to_middle.x, 0)

	self.health_bar
		:LayoutBounds(anchors.after, anchors.top, self.username)
		:Offset(40 * to_middle.x, 0)

	self.waiting_to_join
		:LayoutBounds(anchors.after, anchors.top, self.portrait)
		:Offset(40 * to_middle.x, 0)

	self.health_bar:SetOnSizeChangeFn(function()
		-- Registration needs to be re-applied after the size of the object changes?
		self.health_bar:SetRegistration(anchors.left, anchors.top)
	end)

	local function relayoutfn()
		self.shield_pips
			:LayoutBounds("center", "below", self.portrait)
			:Offset(0, 60)
		local bg_w, bg_h = self.bg_stretch:GetScaledSize()
		local health_w = self.health_bar:GetScaledSize()
		local powers_w = self.player_powers:GetScaledSize()
		local new_width = (math.max(health_w, powers_w) + magic_width) / BG_SCALE

		self.bg_stretch:SetSize(new_width, bg_h)

		-- Registration needs to be re-applied after the size of the object changes?
		self.player_powers:SetRegistration(anchors.left, anchors.top)

		-- May completely change size if we add new currency types.
		self.meta_currency
			:LayoutBounds(anchors.after, anchors.center, self.konjur)
			:Offset(30 * to_middle.x, 0)
	end

	self.inst:ListenForEvent("refresh_hud", relayoutfn, self.owner)

	relayoutfn()
	self.health_bar.on_size_change_fn()
end

function PlayerStatusWidget:TOP_LEFT()
	local identity = {
		above = "above",
		top = "top",
		bottom = "bottom",
		below = "below",

		center = "center",

		before = "before",
		left = "left",
		right = "right",
		after = "after",
	}
	local to_middle = Vector2(1, -1)
	self:_Layout(identity, to_middle)
end


function PlayerStatusWidget:TOP_RIGHT()
	-- Remap the left-based anchors to top right. Hopefully, you never need to
	-- change these.
	local remap = {
		above = "above",
		top = "top",
		bottom = "bottom",
		below = "below",

		center = "center",

		before = "after",
		left = "right",
		right = "left",
		after = "before",
	}
	local to_middle = Vector2(-1, -1)
	self:_Layout(remap, to_middle)
end

function PlayerStatusWidget:BOTTOM_LEFT()
	local remap = {
		above = "below",
		top = "bottom",
		bottom = "top",
		below = "above",

		center = "center",

		before = "before",
		left = "left",
		right = "right",
		after = "after",
	}
	local to_middle = Vector2(1, 1)
	self:_Layout(remap, to_middle)
end

function PlayerStatusWidget:BOTTOM_RIGHT()
	local remap = {
		above = "below",
		top = "bottom",
		bottom = "top",
		below = "above",

		center = "center",

		before = "after",
		left = "right",
		right = "left",
		after = "before",
	}
	local to_middle = Vector2(-1, 1)
	self:_Layout(remap, to_middle)
end

function PlayerStatusWidget:DebugDraw_AddSection(ui, panel)
	PlayerStatusWidget._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("PlayerStatusWidget")
	ui:Indent() do
		if ui:Button("Push refresh_hud") then
			self.inst:PushEvent("refresh_hud")
		end
	end
	ui:Unindent()
end

return PlayerStatusWidget
