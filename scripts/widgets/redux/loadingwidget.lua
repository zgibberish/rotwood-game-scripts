local Image = require("widgets/image")
local Screen = require("widgets/screen")
local Text = require("widgets/text")

local FADE_DURATION = 0.25
---------------------------------------------------------------------------------
-- A screen with a background and text, for when the game is loading stuffs
--
local LoadingWidget = Class(Screen, function(self)
	Screen._ctor(self, "LoadingWidget")

	self.fadeout = 0
	self.enabled = false
	self:Hide()

	self.bg = self:AddChild(Image("images/bg_loading/loading.tex"))
	self.bg:SetAnchors("fill","fill")

	self.loading_widget = self:AddChild(Text(FONTFACE.DEFAULT,60))
		--:SetRegionSize(500,500)
		:SetText("This is a\ntext that is\nleft aligned")
		:SetHAlign(ANCHOR_LEFT)
		:SetPosition(-200,140)

	self.loading_widget:SetPosition(170, 120)
			:SetRegionSize(250, 120)
			:SetHAlign(ANCHOR_LEFT)
			:SetVAlign(ANCHOR_MIDDLE)
			:SetText(STRINGS.UI.NOTIFICATION.LOADING)
			:LayoutBounds("left", "bottom")
			:Offset(30,0)
end)

-- This doesn't do anything currently
function LoadingWidget:ShowNextFrame()
end

function LoadingWidget:SetEnabled(enabled)
	if enabled then
		if not self.enabled then
			self.fadeout = 0
			self.enabled = true
			self:Show()
			self:UpdateVisual()
			self:StartUpdating()
		end
	elseif self.enabled then
		self.fadeout = FADE_DURATION 
	end
end

function LoadingWidget:UpdateVisual(dt)
	dt = dt or 0	
	local level = 1
	if self.fadeout > 0 then
		self.fadeout = self.fadeout - dt
		level = self.fadeout / FADE_DURATION
		if self.fadeout <= 0 then
			self.enabled = false
			self:Hide()
			self:StopUpdating()
		end
	end
	self.loading_widget:SetGlyphColor(243/255, 244/255, 243/255, level)

	-- TODO(dbriscoe): Would be better to make loads hold the last frame so
	-- we can have a clean transition. Or remove world transitions between
	-- dungeon rooms.
	-- Black to match colour before we draw.
	self.bg:SetMultColor(0, 0, 0, level)

	-- it's not animating at the moment
	self.loading_widget:SetText(STRINGS.UI.NOTIFICATION.LOADING.."...")
end

function LoadingWidget:OnUpdate(dt)
	self:UpdateVisual(dt)
end

function LoadingWidget:OnBecomeActive()
	self:SetEnabled(true)
end

return LoadingWidget
