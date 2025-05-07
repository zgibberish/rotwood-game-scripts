local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Clickable = require("widgets/clickable")

local easing = require"util.easing"

--------------------------------------------------------------------------------
-- A single ascension level marker to be shown on a horizontal track
-- Has a background, icon on top and status icon below it

local FrenzyLevelWidget = Class(Clickable, function(self, level_icon)
	Clickable._ctor(self, "FrenzyLevelWidget")

	self.width = 78 -- change to desired width and the height will maintain aspect ratio
	self.height = 240 * self.width / 148 -- source texture size
	self.frenzy_icon_size = self.width * 0.86 -- size of the icon within the panel texture
	self.level_icon = level_icon

	-- Hitbox
	self.hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetName("Hitbox")
		:SetSize(self.width, self.height)
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0)

	-- The connector, between this widget and the next one
	self.connector = self:AddChild(Image("images/global/square.tex"))
		:SetName("Connector")
		:SetSize(10, 8)
		:SetMultColor(UICOLORS.DEBUG)
		:Hide()

	-- The part of the widget that scales on focus
	self.scaling_contents = self:AddChild(Widget())
		:SetName("Scaling contents")
		:SetHiddenBoundingBox(true)

	-- Background
	self.panel_bg = self.scaling_contents:AddChild(Image("images/map_ftf/frenzy_level_bg.tex"))
		:SetName("Background")
		:SetSize(self.width, self.height)

	-- Frenzy icon
	self.frenzy_bg = self.scaling_contents:AddChild(Image("images/map_ftf/frenzy_bg.tex"))
		:SetName("Frenzy background")
		:SetSize(self.frenzy_icon_size, self.frenzy_icon_size)
	self.frenzy_icon = self.scaling_contents:AddChild(Image(self.level_icon))
		:SetName("Frenzy icon")
		:SetSize(self.frenzy_icon_size, self.frenzy_icon_size)

	-- The completed icon
	self.completed_icon = self.scaling_contents:AddChild(Image("images/map_ftf/frenzy_level_completed.tex"))
		:SetName("Completed icon")
		:SetSize(50, 50)
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.DEBUG)
		:Hide()

	-- The reward icon
	self.reward_icon = self.scaling_contents:AddChild(Image("images/map_ftf/frenzy_level_reward.tex"))
		:SetName("Reward icon")
		:SetSize(50, 50)
		:SetHiddenBoundingBox(true)
		:Hide()

	self:SetOnHighlight(function(down, hover, selected, focus)
		if hover then
			self.scaling_contents:ScaleTo(nil, 1.1, 0.1)
		else
			self.scaling_contents:ScaleTo(nil, 1, 0.17)
		end
	end)

	self:Layout()
end)

function FrenzyLevelWidget:SetActive(is_active)
	self.is_active = is_active
	return self
end

-- The base level looks a bit different than the others
function FrenzyLevelWidget:SetBaseLevel(is_base_level)
	self.is_base_level = is_base_level

	-- Tweak stuffs!
	self.width = 78 * 1.1
	self.height = self.width -- source texture size for the base level is the same as its height
	self.frenzy_icon_size = self.width * 0.86
	self.hitbox:SetSize(self.width, self.height)
	self.panel_bg:SetTexture("images/map_ftf/frenzy_level1_bg.tex")
		:SetSize(self.width, self.height)
	self.frenzy_bg:SetSize(self.frenzy_icon_size, self.frenzy_icon_size)
	self.frenzy_icon:SetSize(self.frenzy_icon_size, self.frenzy_icon_size)
	self.completed_icon:SetSize(55, 55)

	return self
end

function FrenzyLevelWidget:SetAvailable(is_available)
	self.is_available = is_available
	self.frenzy_icon:SetTexture(self.is_available and self.level_icon or "images/map_ftf/frenzy_unknown.tex")
	self:SetLocked(not is_available)

	return self
end

function FrenzyLevelWidget:SetLimited(is_limited)
	self.is_limited = is_limited
	return self
end

function FrenzyLevelWidget:SetLocked(is_locked)
	self.is_locked = is_locked
	return self
end

-- If it should show the checkmark
function FrenzyLevelWidget:SetCompleted(is_completed)
	self.is_completed = is_completed
	self.completed_icon:SetShown(self.is_completed)

	if not self.is_completed then
		self:SetRewardIcon("images/map_ftf/frenzy_level_reward.tex")
	end

	return self
end

-- If it should show the checkmark
function FrenzyLevelWidget:SetRewardIcon(reward_icon)
	self.reward_icon:SetTexture(reward_icon)
		:Show()
	return self
end

function FrenzyLevelWidget:RefreshColors()
	if self.is_active then
		-- All the levels up to, and including the selected one
		-- If selected is 3, then levels 1, 2 and 3 are active
		-- Looks yellow and selected
		self.panel_bg:SetMultColor(HexToRGB(0xFFB229FF))
		self.frenzy_bg:SetMultColor(UICOLORS.BLACK)
		self.frenzy_icon:SetMultColor(HexToRGB(0xFFCB27FF))
		self.connector:SetMultColor(UICOLORS.BLACK)
		self.completed_icon:SetMultColor(UICOLORS.BLACK)
		if self.is_base_level then
			self.panel_bg:SetTexture("images/map_ftf/frenzy_level1_bg_selected.tex")
		else
			self.panel_bg:SetTexture("images/map_ftf/frenzy_level_bg_selected.tex")
		end
	elseif self.is_available then
		-- Levels the player has unlocked and can select, but hasn't
		-- Looks light brown
		self.panel_bg:SetMultColor(HexToRGB(0x886F63FF))
		self.frenzy_bg:SetMultColor(HexToRGB(0x46362FFF))
		self.frenzy_icon:SetMultColor(HexToRGB(0xB39B8CFF))
		self.connector:SetMultColor(HexToRGB(0xB39B8CFF))
		self.completed_icon:SetMultColor(HexToRGB(0x352827FF))
	self.panel_bg:SetTexture("images/map_ftf/frenzy_level_bg.tex")
	elseif self.is_limited then
		-- Levels the player has unlocked but can't select
		-- because party members haven't unlocked them yet
		-- Looks darker brown, like the locked ones
		self.panel_bg:SetMultColor(HexToRGB(0x745C50FF))
		self.frenzy_bg:SetMultColor(HexToRGB(0x6E584EFF))
		self.frenzy_icon:SetMultColor(HexToRGB(0x886F63FF))
		self.connector:SetMultColor(HexToRGB(0x886F63FF))
		self.completed_icon:SetMultColor(HexToRGB(0x352827FF))
	self.panel_bg:SetTexture("images/map_ftf/frenzy_level_bg.tex")
	elseif self.is_locked then
		-- Levels the player hasn't unlocked yet
		-- Looks dark brown, and shows a reward icon
		self.panel_bg:SetMultColor(HexToRGB(0x745C50FF))
		self.frenzy_bg:SetMultColor(HexToRGB(0x6E584EFF))
		self.frenzy_icon:SetMultColor(HexToRGB(0x886F63FF))
		self.connector:SetMultColor(HexToRGB(0x886F63FF))
		self.completed_icon:SetMultColor(HexToRGB(0x352827FF))
	self.panel_bg:SetTexture("images/map_ftf/frenzy_level_bg.tex")
	end

	-- Animate the icon if not
	if self.is_active
	and self.reward_icon:IsShown()
	and not self.reward_animation
	then
		print("Start Reward Animation")
		self.reward_animation = self.reward_icon:RunUpdater(Updater.Series{ 
	        Updater.Loop{
	            Updater.Ease(function(deg)
					self.reward_icon:SetRotation(deg)
	            end, 0, 10, 1.25, easing.inElastic),
	            Updater.Ease(function(deg)
					self.reward_icon:SetRotation(deg)
	            end, 10, 0, 1.25, easing.outElastic),
	        }
	    })
	end
	-- Stop the animation if not active
	if not self.is_active
	and self.reward_icon:IsShown()
	and self.reward_animation
	then
		self.reward_animation:Stop()
		self.reward_animation = nil
		self.reward_icon:SetRotation(0)
	end

	return self
end

-- How wide the connector needs to be, to the right of this widget
function FrenzyLevelWidget:ShowConnector(max_w)
	self.max_w = max_w
	self.connector_w = self.max_w - self.width
	self.connector:SetSize(self.connector_w, 12)
		:Show()
	self:Layout()
	return self
end

function FrenzyLevelWidget:Layout()

	self.frenzy_bg:LayoutBounds(nil, "top", self.panel_bg)
		:Offset(0, -self.width*0.05)
	self.frenzy_icon:LayoutBounds("center", "center", self.frenzy_bg)
	self.connector:LayoutBounds("after", "center", self.hitbox)
		:Offset(-10, 0)
	if self.is_base_level then
		-- The base level shows the icons on the top right instead of the lower panel
		self.completed_icon:LayoutBounds("center", "center", self.panel_bg)
			:Offset(0, 2)
		self.reward_icon:LayoutBounds("center", "center", self.panel_bg)
			:Offset(0, 2)
	else
		self.completed_icon:LayoutBounds("center", "center", self.panel_bg)
			:Offset(0, -29)
		self.reward_icon:LayoutBounds("center", "center", self.panel_bg)
			:Offset(0, -29)
	end

	return self
end

return FrenzyLevelWidget
