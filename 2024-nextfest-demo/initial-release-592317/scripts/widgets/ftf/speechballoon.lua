local Clickable = require "widgets.clickable"
local Image = require "widgets.image"
local Panel = require("widgets/panel")
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local easing = require "util.easing"
local lume = require "util.lume"

------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
--- Displays a single requirement to hire an NPC
----
local HireRequirementRow = Class(Widget, function(self, width, icon, text, complete)
	self:SetHoverSound(nil)
	self:SetGainFocusSound(nil)

	Widget._ctor(self, "HireRequirementRow")

	self.width = width or 600
	self.height = 80
	self.iconSize = self.height - 20 -- Width of the icon on the left
	self.widthLeft = self.iconSize + 20 -- Spacing between the left edge and the text
	self.widthRight = self.height -- Width of the right panel

	self.bg = self:AddChild(Panel("images/ui_ftf_dialog/dialog_requirement_bg.tex"))
		:SetNineSliceCoords(30, 30, 70, 70)
		:SetNineSliceBorderScale(0.5)
		:SetMultColor(HexToRGB(0xF4E1CEFF))
		:SetSize(self.width, self.height)

	self.right = self:AddChild(Panel("images/ui_ftf_dialog/dialog_requirement_right.tex"))
		:SetNineSliceCoords(30, 30, 70, 70)
		:SetNineSliceBorderScale(0.5)
		:SetMultColor(complete and UICOLORS.FOCUS or HexToRGB(0xDFCAB3FF))
		:SetSize(self.widthRight, self.height)
		:LayoutBounds("right", "top", self.bg)

	self.check = self:AddChild(Image("images/ui_ftf_dialog/dialog_requirement_check.tex"))
		:SetMultColor(UICOLORS.BACKGROUND_MID)
		:SetMultColorAlpha(complete and 1 or 0.1)
		:SetSize(self.widthRight, self.height)
		:LayoutBounds("center", "center", self.right)
		:Offset(3, 0)

	self.icon = self:AddChild(Image(icon))
		:SetSize(self.iconSize, self.iconSize)
		:LayoutBounds("left", "center", self.bg)
		:Offset(5, 0)

	self.text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SPEECH_TEXT*0.8, text, UICOLORS.BACKGROUND_MID))
		:LeftAlign()
		:SetAutoSize(self.width - self.widthLeft - self.widthRight - 40 * HACK_FOR_4K)
		:LayoutBounds("after", "center", self.icon)
		:Offset(10, 0)

end)


------------------------------------------------------------------------------------------
--- A basic speech balloon. Contains text and a background.
--- Can also include the speaker's name label and an input bar at the bottom
----
local SpeechBalloon = Class(Clickable, function(self)
	self:SetHoverSound(nil)
	self:SetGainFocusSound(nil)

	Clickable._ctor(self, "SpeechBalloon")

	self.horizontalContentPadding = 150
	self.top_padding = 60
	self.bottom_padding = 60
	self.minWidth = 500  -- adapts to TitleText
	self.maxWidth = 1400 -- hard limit
	self.max_text_width = self.maxWidth - self.horizontalContentPadding*2
	self.minHeight = 380

	self.bubble_arrow_size = 100
	self.bubble_arrow_right = true

	self.continueSize = 60

	self:SetNavFocusable(false)

	-- Wrapper around the bubble. Has the floating animation
	self.root = self:AddChild(Widget("SpeechBalloon Root"))
		self.root:SetHoverSound(nil)
		self.root:SetGainFocusSound(nil)
	-- Still contains everything. Has the in/out animations
	self.bubble = self.root:AddChild(Widget("SpeechBalloon Bubble"))
		self.bubble:SetHoverSound(nil)
		self.bubble:SetGainFocusSound(nil)

	-- Displays the dialog's title
	self.name_block = self.bubble:AddChild(Widget("Name Block"))
		:SetHiddenBoundingBox(true) -- ignore overhanging titles
		:Hide()
		:SetHoverSound(nil)
		:SetGainFocusSound(nil)
	self.name_bg = self.name_block:AddChild(Panel("images/ui_ftf_dialog/speech_bubble_nametag.tex"))
		:SetName("Name background")
		:SetNineSliceCoords(20, 0, 180, 100)
	self.name_text = self.name_block:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SPEECH_NAME))
		:SetName("Name text")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()

	-- Displays the actual content of this dialog
	self.content_block = self.bubble:AddChild(Widget("Content Block"))
		:SetHoverSound(nil)
		:SetGainFocusSound(nil)
	self.bubble_arrow = self.content_block:AddChild(Image("images/ui_ftf_dialog/speech_bubble_arrow.tex"))
	self.bubble_bg = self.content_block:AddChild(Panel("images/ui_ftf_dialog/speech_bubble.tex"))
		:SetName("Bubble background")
		:SetNineSliceCoords(128, 0, 162, 380)
	self.contents_column = self.content_block:AddChild(Widget())
		:SetName("Contents column") -- Column containing the text, content_widget and hotkeys
		:SetHoverSound(nil)
		:SetGainFocusSound(nil)
	self.content_text = self.contents_column:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SPEECH_TEXT))
		:SetName("Content text")
		:SetGlyphColor(UICOLORS.SPEECH_TEXT)
		:LeftAlign()
		:SetAutoSize(self.max_text_width)
	-- To display other stuff than text
	self.content_widget = self.contents_column:AddChild(Widget())
		:SetName("Content widget")
		:Hide()
		:SetHoverSound(nil)
		:SetGainFocusSound(nil)
	-- Shows under the text, displaying the available actions
	self.inputs_hint_text = self.contents_column:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SPEECH_HOTKEYS))
		:SetName("Inputs hint string")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:Hide()

	-- Add an arrow indicating if there's more dialogue coming
	self.continue_arrow_container = self.content_block:AddChild(Widget())
		:SetName("Continue arrow container")
		:SetHoverSound(nil)
		:SetGainFocusSound(nil)
	self.continue_arrow_hitbox = self.continue_arrow_container:AddChild(Image("images/global/square.tex"))
		:SetSize(self.continueSize, self.continueSize)
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0)
	self.continue_arrow = self.continue_arrow_container:AddChild(Image("images/ui_ftf_dialog/speech_continue_arrow.tex"))
		:SetName("Continue arrow")
		:SetSize(self.continueSize, self.continueSize)
		:SetHiddenBoundingBox(true)

	-- Animate it
	local speed = 0.24
	local amplitude = -6
	self.continue_arrow:RunUpdater(
		Updater.Loop({
			Updater.Ease(function(v) self.continue_arrow:SetPos(0, v) end, 0, amplitude, speed, easing.inOutQuad),
			Updater.Ease(function(v) self.continue_arrow:SetPos(0, v) end, amplitude, 0, speed, easing.inOutQuad),
			Updater.Ease(function(v) self.continue_arrow:SetPos(0, v) end, 0, amplitude, speed, easing.inOutQuad),
			Updater.Ease(function(v) self.continue_arrow:SetPos(0, v) end, amplitude, 0, speed, easing.inOutQuad),
			Updater.Wait(speed*6)
		}))


	-- For capturing fullscreen clicks
	self.fsonclick = nil
	self.control = Controls.Digital.ACTION
end)

SpeechBalloon.CONTROL_MAP =
{
	{
		control = Controls.Digital.DODGE,
		fn = function(self)
			-- Bit of a hack, we should revise this once the demo is done
			local is_gamepad = ThePlayer.components.playercontroller:GetLastInputDeviceType() == "gamepad"
			if not self:IsEnabled() or not self.focus or is_gamepad then 
				return false 
			end

			if self.fsonclick ~= nil then
				self.fsonclick()
			end
		end,
	}
}

function SpeechBalloon:OnControl(controls, down)
	if not self:IsEnabled() or not self.focus then return false end
	if down and controls:Has(Controls.Digital.MENU_ACCEPT) then
		if self.fsonclick ~= nil then
			self.fsonclick()
			return true
		end
	end
	return SpeechBalloon._base.OnControl(self, controls, down)
end

function SpeechBalloon:GetText()
	return self.content_text:GetText()
end

function SpeechBalloon:GetTextNode()
	return self.content_text.inst.TextWidget
end

-- Sets the dialog text
function SpeechBalloon:SetConvoText(text)
	self.content_text:SetText(text)
	self:_Layout()
	return self
end

function SpeechBalloon:SetPersonalityText(...)
	self.content_text:SetPersonalityText(...)
	self:_Layout()
	return self
end

function SpeechBalloon:SnapSpool()
	self.content_text:SnapSpool()
	return self
end

function SpeechBalloon:PopulateHireRequirements(recipe, player)
	local req = recipe:CanPlayerCraft_Detailed(player)

	for i, ing in pairs(req) do
		self.content_widget:AddChild(HireRequirementRow(nil, ing.def.icon, string.format("%d  %s", ing.needs, ing.def.pretty.name), ing.has_enough))
	end

	-- Layout requirements
	self.content_widget:LayoutChildrenInColumn(10)

	self:_Layout()

	return self
end

-- Sets the title to display a string
function SpeechBalloon:SetTitleText(title)
	self.name_text:SetText(title)
	local w, h = self.name_text:GetSize()
	w = w + 120
	h = 100
	self.name_bg:SetSize(w, h)
	self.name_text:LayoutBounds("center", "center", self.name_bg)
	self.name_block:SetShown(title)

	-- Expand width to ensure TitleText widget doesn't hang off right side of speech bubble.
	self.minWidth = lume.clamp(w + self.horizontalContentPadding + 100, self.minWidth, self.maxWidth)

	self:_Layout()
	return self
end

function SpeechBalloon:SetContinueArrowShown(show_arrow)
	self.continue_arrow_container:SetShown(show_arrow)
	return self
end

-- Shows input hints below the text
function SpeechBalloon:SetInputString(text)
	self.inputs_hint_text:SetText(text or "")
		:SetShown(text)
	self:_Layout()
	return self
end

-- Sets what happens when the player clicks anywhere on the screen
function SpeechBalloon:SetFullscreenActionClick(fn)
	self.fsonclick = fn
	self:SetHoverCheck(true)
		:SetFullscreenHit(true)
	return self
end

-- Sets what happens when the player clicks the action bar
function SpeechBalloon:SetActionClick(fn)
	self:SetOnClickFn(fn)
	return self
end

function SpeechBalloon:SetArrowShown(shown, facing_right, offset)
	self.bubble_arrow:SetShown(shown)
	self.bubble_arrow_right = facing_right
	self.bubble_arrowOffset = offset or 0
	dbassert(self.bubble_arrowOffset >= 0, "Are you sure you want a negative offset from the edge?")

	self:_Layout()
	return self
end

function SpeechBalloon:_Layout()

	-- Reset max width
	self.content_text:SetAutoSize(self.max_text_width)
	self.content_text:RefreshText()
	local text_w, text_h = self.content_text:GetSize()

	-- If this text is only two lines, make the text narrower, and maybe into three lines
	if self.content_text:GetLines() == 2 then
		self.content_text:SetAutoSize(self.max_text_width * 0.6)
		if self.content_text:GetLines() == 4 then
			-- This made it too narrow. Revert!
			self.content_text:SetAutoSize(self.max_text_width)
		end
	end
	-- If this text is only one line, make the text narrower, and maybe into two lines
	if self.content_text:GetLines() == 1 then
		self.content_text:SetAutoSize(self.max_text_width * 0.6)
	end

	-- Check if there are custom widgets shown
	self.content_widget:SetShown(self.content_widget:HasChildren())

	-- Update text width
	text_w, text_h = self.content_text:GetSize()

	-- Calculate width and height for the contents
	local spacing_between_text_and_contents = 20
	self.contents_column:LayoutChildrenInColumn(spacing_between_text_and_contents, "left")
	local contents_w, contents_h = self.contents_column:GetSize()
	local height = self.top_padding + contents_h + self.bottom_padding
	height = math.max(self.minHeight, height)
	local width = math.max(self.minWidth, contents_w + self.horizontalContentPadding*2)

	-- If there's a click interaction, make the bubble react to hover
	if self.inputs_hint_text:IsShown() then
		self:SetScales(1, 1.03, 1.1, 0.15)
	else
		-- Remove hover effect
		self:SetScales(1, 1, 1, nil)
	end

	-- Size up the background
	self.bubble_bg:SetSize(width, height)

	self.content_text:LayoutBounds("left", "top", self.bubble_bg)
		:Offset(self.horizontalContentPadding, -self.top_padding)

	-- Layout title label over the content
	self.name_block:LayoutBounds("left", "above", self.bubble_bg)
		:Offset(self.horizontalContentPadding, -20)

	-- Set arrow color and position
	local arrow_size = self.bubble_arrow_size + 150
	local arrow_offset_x = self.bubble_arrow_right and (-arrow_size) or (arrow_size)
	self.bubble_arrow:LayoutBounds(self.bubble_arrow_right and "after" or "before", "below", self.bubble_bg)
		:Offset(arrow_offset_x, 20)

	-- Position continue arrow, then hide it until the speech bubble is complete.
	self.continue_arrow_container:LayoutBounds("right", "bottom", self.bubble_bg)
		:Offset(-80, self.bottom_padding - 10)
		:Hide(0)

	-- Position input block at the bottom (in case the contents don't fill the whole height)
	self.inputs_hint_text:LayoutBounds("left", "bottom", self.bubble_bg)
		:Offset(self.horizontalContentPadding, self.bottom_padding)

	return self
end

function SpeechBalloon:AnimateFloating(speed)
	speed = speed or 0.3
	speed = speed * 4
	local amplitude = 5
	local widgetX, widgetY = self.root:GetPosition()
	self.root:RunUpdater(
		Updater.Loop({
			Updater.Ease(function(v) self.root:SetPosition(widgetX, v) end, widgetY, widgetY + amplitude, speed * 0.8, easing.outQuad),
			Updater.Wait(speed * 0.5),
			Updater.Ease(function(v) self.root:SetPosition(widgetX, v) end, widgetY + amplitude, widgetY - amplitude * 1.2, speed * 1.8, easing.inOutQuad),
			Updater.Wait(speed * 0.2),
			Updater.Ease(function(v) self.root:SetPosition(widgetX, v) end, widgetY - amplitude * 1.2, widgetY + amplitude * 1.3, speed * 1.6, easing.inOutQuad),
			Updater.Wait(speed * 0.4),
			Updater.Ease(function(v) self.root:SetPosition(widgetX, v) end, widgetY + amplitude * 1.3, widgetY - amplitude, speed * 1.7, easing.inOutQuad),
			Updater.Wait(speed * 0.3),
			Updater.Ease(function(v) self.root:SetPosition(widgetX, v) end, widgetY - amplitude, widgetY, speed * 0.8, easing.inQuad),
		})
	)
	return self
end

--- Hide things to be animated in
function SpeechBalloon:PrepareAnimation()

	self.bubble:SetMultColorAlpha(0)
	self.bubble:SetPosition(0, -140)
	self.bubble:SetScale(1, 0.6)
	self.name_block:SetMultColorAlpha(0)
	self.bubble_arrow:SetMultColorAlpha(0)

	return self
end

function SpeechBalloon:AnimateIn(onDoneFn, callbackDelay)
	-- Hide things to be animated in
	self:PrepareAnimation()

	-- Get reference positions
	local name_blockX, name_blockY = self.name_block:GetPosition()
	local bubble_arrowX, bubble_arrowY = self.bubble_arrow:GetPosition()

	-- Setup an animation sequence
	local animationParallel = Updater.Parallel()

	-- Move and fade in the content and the arrow
	animationParallel:Add(Updater.Ease(function(v) self.bubble:SetMultColorAlpha(v) end, 0, 1, 0.2, easing.inOutQuad))
	animationParallel:Add(Updater.Ease(function(v) self.bubble:SetPosition(0, v) end, -70, 0, 0.5, easing.outElasticSpeechBubble))
	animationParallel:Add(Updater.Ease(function(v) self.bubble:SetScale(1, v) end, 0.6, 1, 0.2, easing.inOutQuad))

	if self.name_block:IsShown() then
		animationParallel:Add(Updater.Series{
			Updater.Wait(0.2),
			Updater.Parallel{
				Updater.Ease(function(v) self.name_block:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
				Updater.Ease(function(v) self.name_block:SetPosition(name_blockX, v) end, name_blockY-80, name_blockY, 0.5, easing.outElasticUI),
			}
		})
	end

	animationParallel:Add(Updater.Series{
		Updater.Wait(0.2),
		Updater.Parallel{
			Updater.Ease(function(v) self.bubble_arrow:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
			Updater.Ease(function(v) self.bubble_arrow:SetPosition(bubble_arrowX, v) end, bubble_arrowY+80, bubble_arrowY, 0.5, easing.outElasticUI),
		}
	})

	-- Run the whole animation
	self:RunUpdater(Updater.Series({
		animationParallel,

		-- Wait for a beat
		Updater.Wait(callbackDelay or 0.1),

		-- Then the callback
		Updater.Do(function() if onDoneFn then onDoneFn() end end),
	}))

	return self
end

function SpeechBalloon:CreateAnimateOut()
	return Updater.Parallel({
			-- We no longer animate out. The bubble is removed in one click.
			-- Updater.Ease(function(v) self.bubble:SetMultColorAlpha(v) end, 1,   0, 0.2, easing.inOutQuad),
			-- Updater.Ease(function(v) self.bubble:SetPosition(0, v) end,    0, -70, 0.5, easing.outElasticSpeechBubble),
			-- Updater.Ease(function(v) self.bubble:SetScale(1, v) end,       1, 0.6, 0.2, easing.inOutQuad),
		})
end

return SpeechBalloon
