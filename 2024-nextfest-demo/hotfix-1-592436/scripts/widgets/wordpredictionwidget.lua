
local Widget = require "widgets/widget"
local Panel = require "widgets/panel"
local ImageButton = require "widgets/imagebutton"
local Button = require "widgets/button"

local WordPredictor = require "util/wordpredictor"

local DEBUG_SHOW_MAX_WITH = false

local FONT_SIZE = 22 * HACK_FOR_4K
local PADDING = 12 * HACK_FOR_4K

local WordPredictionWidget = Class(Widget, function(self, text_edit, max_width, mode)
    Widget._ctor(self, "WordPredictionWidget")

    self.word_predictor = WordPredictor()
	self.text_edit = text_edit

	self.enter_complete = string.match(mode, "enter", 1, true) ~= nil
	self.tab_complete = string.match(mode, "tab", 1, true) ~= nil

	self.sizey = FONT_SIZE + 4 * HACK_FOR_4K
	self.max_width = max_width or 300 * HACK_FOR_4K

	local root = self:AddChild(Widget("wordpredictionwidget_root"))
	root:SetPosition(10 * HACK_FOR_4K, self.sizey*0.5)

    self.backing = root:AddChild(Panel("images/ui_ftf/textedit_bg.tex"))
		:SetNineSliceCoords(21, 17, 80, 82)
		:SetNineSliceBorderScale(0.5)
		:SetMultColor(HexToRGB(0x261E1Dff))

	self.prediction_root = root:AddChild(Widget("prediction_root"))

	self.dismiss_btn = root:AddChild(ImageButton("images/ui_ftf/ButtonClose.tex"))
		:SetOnClick(function() self:Dismiss() end)
		:SetNormalScale(.30 * 2)
		:SetFocusScale(.30 * 2)
		:SetImageNormalColour(UICOLORS.GREY)
		:SetImageFocusColour(UICOLORS.WHITE)
		:SetPosition(-15 * HACK_FOR_4K, 0)
		:SetToolTip(STRINGS.UI.WORDPREDICTIONWIDET.DISMISS)
	self.starting_offset = PADDING

	self:Hide()
end)

function WordPredictionWidget:IsMouseOnly()
	return self.enter_complete == false and self.tab_complete == false
end

function WordPredictionWidget:OnRawKey(key, down)
	if down and key == InputConstants.Keys.BACKSPACE or key == InputConstants.Keys.DELETE then
		self.active_prediction_btn = nil
		self:RefreshPredictions()
		return false  -- do not consume the key press

	elseif self.word_predictor.prediction ~= nil then
		if key == InputConstants.Keys.TAB then
			if self.tab_complete then
				if not down and self.word_predictor.prediction ~= nil then
					self.text_edit:ApplyWordPrediction(self.active_prediction_btn)
					self:RefreshPredictions()
					return true -- consume the tab key
				end
			end
			return false
		elseif key == InputConstants.Keys.ENTER then
			return self.enter_complete
		elseif key == InputConstants.Keys.LEFT and not self:IsMouseOnly() then
			if down and self.active_prediction_btn > 1 then
				self.prediction_btns[self.active_prediction_btn - 1]:Select()
			end
			return true
		elseif key == InputConstants.Keys.RIGHT and not self:IsMouseOnly() then
			if down and self.active_prediction_btn < #self.prediction_btns then
				self.prediction_btns[self.active_prediction_btn + 1]:Select()
			end
			return true
		elseif key == InputConstants.Keys.ESCAPE then
			return true
		end
	end

	return false
end

function WordPredictionWidget:OnControl(controls, down)
    if WordPredictionWidget._base.OnControl(self,controls, down) then return true end

	if self.word_predictor.prediction ~= nil then
		if controls:Has(Controls.Digital.CANCEL) then
			if not down then
				self:Dismiss()
			end
			return true
		elseif controls:Has(Controls.Digital.ACCEPT) then
			if self.enter_complete then
				if not down then
					self.text_edit:ApplyWordPrediction(self.active_prediction_btn)
					self:RefreshPredictions()
				end
				return true
			end
		end
	end

	return false
end

function WordPredictionWidget:ResolvePrediction(prediction_index)
	return self.word_predictor:Apply(prediction_index)
end

function WordPredictionWidget:Dismiss()
	self.word_predictor:Clear()

	self.prediction_btns = {}
	self.active_prediction_btn = nil
	self.prediction_root:KillAllChildren()

	self:Hide()
	self:Disable()
end

function WordPredictionWidget:RefreshPredictions()
	local prev_active_prediction = self.active_prediction_btn ~= nil and self.prediction_btns[self.active_prediction_btn]._widgetname or nil

	self.word_predictor:RefreshPredictions(self.text_edit:GetText(), self.text_edit.cursor - 1)

	self.prediction_btns = {}
	self.active_prediction_btn = nil
	self.prediction_root:KillAllChildren()

	if self.word_predictor.prediction ~= nil then
		self:Show()
		self:Enable()

		local prediction = self.word_predictor.prediction
		local offset = self.starting_offset

		for i, v in ipairs(prediction.matches) do
			local str = self.word_predictor:GetDisplayInfo(i)

			local btn = self.prediction_root:AddChild(Button())
			btn:SetFont(FONTFACE.CODE)
			btn:SetDisabledFont(FONTFACE.BUTTON)
			btn:SetTextColour(UICOLORS.LIGHT_TEXT)
			btn:SetTextFocusColour(UICOLORS.OVERLAY)
			btn:SetTextSelectedColour(UICOLORS.LIGHT_TEXT_SELECTED)
			btn:SetText(str)
			btn:SetTextSize(FONT_SIZE)
			btn.clickoffset = Vector3(0,0,0)

			btn:SetOnClick(function() if self.active_prediction_btn ~= nil then self.text_edit:ApplyWordPrediction(self.active_prediction_btn) end end)
			btn:SetOnSelect(function() if self.active_prediction_btn ~= nil and self.active_prediction_btn ~= i then self.prediction_btns[self.active_prediction_btn]:Unselect() end self.active_prediction_btn = i end)
			btn:SetOnGainFocus(function() btn:Select() end)
			btn.AllowOnControlWhenSelected = true

			if self:IsMouseOnly() then
				btn:SetOnLoseFocus(function() if btn.selected then btn:Unselect() self.active_prediction_btn = nil end end)
			end

			local sx, sy = btn.text:GetRegionSize()
			btn:SetPosition(sx * 0.5 + offset, 1)

			if offset + sx > self.max_width then
				if DEBUG_SHOW_MAX_WITH then
					offset = self.max_width
				end
				btn:Kill()
				--btn:Remove()
				break
			else
				offset = offset + sx + PADDING

				table.insert(self.prediction_btns, btn)
				if prev_active_prediction ~= nil and btn._widgetname == prev_active_prediction then
					self.active_prediction_btn = i
				end
			end
		end

		if self:IsMouseOnly() then
			self.active_prediction_btn = nil
		else
			self.prediction_btns[self.active_prediction_btn or 1]:Select()
		end

		self.backing:SetSize(offset + 5 * HACK_FOR_4K, self.sizey + 4)
			:LayoutBounds("after", "center", self.dismiss_btn)
			:Offset(-10 * HACK_FOR_4K, 0)

	else
		self:Hide()
		self:Disable()
	end
end

return WordPredictionWidget
