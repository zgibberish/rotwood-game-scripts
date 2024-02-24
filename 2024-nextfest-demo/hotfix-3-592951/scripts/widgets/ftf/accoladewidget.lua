local Widget = require "widgets/widget"
local UIAnim = require "widgets/uianim"
local Image = require "widgets/image"

local easing = require "util/easing"

local fmodtable = require "defs/sound/fmodtable"

local AccoladeWidget = Class(Widget, function(self, data)
	Widget._ctor(self, "AccoladeWidget")

	-- Show rolled paper anim over the contents
	self.roll_anim = self:AddChild(UIAnim())
		:SetName("Roll anim")
		:SetBank("ui_scroll")
		:PlayAnimation("downidle_wide")

	self.roll_anim_w, self.roll_anim_h = self.roll_anim:GetScaledSize()

	-- Contains the background and all panel contents.
	-- Gets scissored during in/out animation
	-- The roll anim is shown over this
	self.panel_contents = self:AddChild(Widget())
		:SetName("Panel contents")
		:SendToBack()
		:SetShowDebugBoundingBox(true)

	-- Background for the panel
	self.bg = self.panel_contents:AddChild(Image("images/ui_ftf_dungeon_progress/PanelProgress.tex"))
		:SetName("Background")

	self:PopulatePanelContents()

	self:_SetPaperRollAmount(1)
end)

function AccoladeWidget:AddWidgetToContents(widget)
	return self.panel_contents:AddChild(widget)
end

function AccoladeWidget:PopulatePanelContents()
	-- Calculate sizes
	self.width, self.height = self.bg:GetScaledSize()

	-- Calculate content size for animation
	self.content_width, self.content_height = self.panel_contents:GetSize()

	-- How much of the panel will be scissored in the animation, starting from the bottom
	-- Basically everything except the equipment icons at the top
	self.roll_scissored_height = self.content_height - 40
end

function AccoladeWidget:_SetPaperRollAmount(amount_rolled)
	self.panel_contents:SetScissor(-self.content_width/2, -self.content_height/2 + self.roll_scissored_height*amount_rolled, self.content_width, self.content_height)
	self.roll_anim:LayoutBounds("center", "below", self.panel_contents)
		:Offset(-20, self.roll_anim_h/2)
end

function AccoladeWidget:AnimateIn(time)
	self:RunUpdater(Updater.Series{
		-- Scissor down
		Updater.Parallel{
			Updater.Do(function()
				-- Unroll sound
				self:PlaySpatialSound(fmodtable.Event.endOfRun_rollDown)

				-- Animate rolling
				self.roll_anim:PlayAnimation("rolldown_wide")
					:PushAnimation("downidle_wide", true)
			end),
			Updater.Ease(function(v)
				self:_SetPaperRollAmount(v)
			end, 1, 0, time, easing.outQuad)
		}
	})
end

function AccoladeWidget:AnimateOut(time)
	self:RunUpdater(Updater.Series{
		-- Scissor up
		Updater.Parallel{
			Updater.Do(function()
				-- Roll up sound
				self:PlaySpatialSound(fmodtable.Event.endOfRun_rollUp)

				self.roll_anim:PlayAnimation("rollup_wide")
					:PushAnimation("upidle_wide", true)
			end),
			Updater.Ease(function(v)
				self:_SetPaperRollAmount(v)
			end, 0, 1, time, easing.outQuad)
		},
	})
end

return AccoladeWidget