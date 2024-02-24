local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Panel = require "widgets/panel"
local WordPredictionWidget = require "widgets/wordpredictionwidget"
local fmodtable = require "defs.sound.fmodtable"

local TextEdit = Class(Text, function(self, font, size, text, colour)
	Text._ctor(self, font or FONTFACE.DEFAULT, size or FONTSIZE.SCREEN_SUBTITLE, text or "", colour or UICOLORS.BACKGROUND_DARK)
	self:SetName("TextEdit")

	self.can_focus_with_nav = true
	self.cursor = 1
	self.lines = 1
	self:SetString(text)
	self.limit = nil
	self.regionlimit = false
	self.editing = false
	self.editing_enter_down = false --track enter key while editing: ignore enter key up if key down wasn't recorded while editing
	self.allow_newline = false
	self.at_line_max = false		-- If the text already has the maximum amount of lines
	self.enable_accept_control = true
	self:SetEditing(false)
	self.validrawkeys = {}
	self.force_edit = false
	self.pasting = false
	self.uppercase = false
	self.pass_controls_to_screen = {}

	self.idle_text_color = {0,0,0,1}
	self.edit_text_color = {0,0,0,1}--{1,1,1,1}

	self.idle_tint = {1,1,1,1}
	self.hover_tint = {1,1,1,1}
	self.selected_tint = {1,1,1,1}

	self:SetGlyphColor(self.idle_text_color[1], self.idle_text_color[2], self.idle_text_color[3], self.idle_text_color[4])

	-- Controller help text strings. You can hide a x_helptext by setting it to
	-- and empty string.
	self.edit_helptext = STRINGS.UI.HELP.CHANGE_TEXT
	self.cancel_helptext = STRINGS.UI.HELP.BACK
	self.apply_helptext = STRINGS.UI.HELP.APPLY

	self.hover_check = true
	--Default cursor colour is WHITE { 1, 1, 1, 1 }

	self.conversions = {} --text character transformations, see OnTextInput

	-- Sets the background and default tint colours
	self:SetDefaultTheme()

	self:StartUpdating()

	self.textinput_sound = fmodtable.Event.ui_keypress

end)

function TextEdit:OnUpdate()
	local x,y = TheFrontEnd:GetUIMousePos()
	if self:CheckHit(x,y) then
		local cursor2 = self:GetCursorAtPoint(x,y,false)
--		print("cursor2:",cursor2)
	end
end

function TextEdit:DebugDraw_AddSection(ui, panel)
	TextEdit._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("TextEdit")
	ui:Indent() do

		ui:Value("cursor pos",               self.cursor)
		ui:Checkbox("regionlimit",           self.regionlimit)
		ui:Checkbox("editing",               self.editing)
		ui:Checkbox("editing_enter_down",    self.editing_enter_down)
		ui:Checkbox("allow_newline",         self.allow_newline)
		ui:Checkbox("enable_accept_control", self.enable_accept_control)
		ui:Checkbox("force_edit",            self.force_edit)
		ui:Checkbox("pasting",               self.pasting)

		ui:ColorEdit4("idle_text_color", table.unpack(self.idle_text_color))
		ui:ColorEdit4("edit_text_color", table.unpack(self.edit_text_color))
		ui:ColorEdit4("idle_tint",       table.unpack(self.idle_tint))
		ui:ColorEdit4("hover_tint",      table.unpack(self.hover_tint))
		ui:ColorEdit4("selected_tint",   table.unpack(self.selected_tint))
	end
	ui:Unindent()
end

function TextEdit:SetLines(lines)
	self.lines = lines
	return self
end

function TextEdit:SetUppercase(all_uppercase)
	self.uppercase = all_uppercase
	return self
end

function TextEdit:SetForceEdit(force)
	self.force_edit = force
	return self
end

function TextEdit:SetString(str, silent)
	local old_cursor = self.cursor
	local old_string = self.current_str or ""
	str = str or ""
	str = self:FormatString(str)
	if str ~= self.current_str then
		self.current_str = str
		self.cursor = self:_ClampToString(self.cursor)
		self:UpdateDisplayString()

		if self.inst.TextWidget:GetLines() > self.lines then
			self.current_str = old_string
			self.cursor = old_cursor
			self:UpdateDisplayString()
		else
			if self.onchange and not silent then
				self.onchange( str )
			end
		end

		self.at_line_max = self.inst.TextWidget:GetLines() >= self.lines
	end

	return self
end

function TextEdit:_ClampToString(cursor)
	local len = utf8.len(self.current_str)
	return math.min(cursor or 1, len + 1)
end

function TextEdit:SetAllowNewline(allow_newline)
	self.allow_newline = allow_newline

	-- Must enable the accept control when we're not editing, so the user can
	-- click the control to start editing. But while editing multiline we don't
	-- want the enter key to stop editing.
	self.enable_accept_control = not self.allow_newline or not self.editing
	return self
end

function TextEdit:SetEditing(editing)
	--~ print("TextEdit:SetEditing:", self.editing, "->", editing, self._widgetname, self:GetText())
	if editing and not self.editing then
		self.editing = true
		self.editing_enter_down = false

		self:SetFocus()
		self:StartEditing()
		-- Guarantee that we're highlighted
		self:DoSelectedImage()
		TheInput:EnableDebugToggle(false)

		-- #srosen: This is where we should push whatever text input widget we
		-- have for gamepads.
		-- We probably don't want to set the focus and whatnot here if
		-- controller attached: It screws with textboxes that are child widgets
		-- in scroll lists (and on the lobby screen). Instead, we should go
		-- into "edit mode" by pushing a modal screen, rather than giving this
		-- thing focus and gobbling input.
		--if TheInput:ControllerAttached() then
		--end

		if self.edit_text_color ~= nil then
			self:SetGlyphColor(table.unpack(self.edit_text_color))
		end

		if self.force_edit then
			TheFrontEnd:SetForceProcessTextInput(true, self)
		end

	elseif not editing and self.editing then
		self:StopEditing()
		self.editing = false
		self.editing_enter_down = false

		if self.focus then
			self:DoHoverImage()
		else
			self:DoIdleImage()
		end

		if self.idle_text_color ~= nil then
			self:SetGlyphColor(table.unpack(self.idle_text_color))
		end

		if self.force_edit then
			TheFrontEnd:SetForceProcessTextInput(false, self)
		end

		if self.prediction_widget ~= nil then
			self.prediction_widget:Dismiss()
		end
	end

	-- Update the enable_accept_control flag
	self:SetAllowNewline(self.allow_newline)

	--[[
	if self.editing then
		self.inst.TextWidget:SetCursor(0)
	else
		self.inst.TextWidget:SetCursor(self.cursor)
	end
	self.inst.TextWidget:ShowEditCursor(self.editing)
]]

	self:_TryUpdateTextPrompt()
	return self
end

function TextEdit:OnMouseButton(button, down, x, y)
	if down and button == InputConstants.MouseButtons.LEFT then
		self:SetFocus()
		-- For some reason x,y are often quite different from GetMousePos, so ignore them.
		x,y = TheFrontEnd:GetUIMousePos()
		local cursor = self:GetCursorAtPoint(x, y, false) or 1 -- 1 is beginning
		if cursor >= 1 then
			-- We'll go before clicked character. Doesn't match Win32 text
			-- control behaviour, but necessary to be consistent at ends of
			-- field.
			self.cursor = self:_ClampToString(cursor)
			self:UpdateDisplayString()
		else
			self:GoToEndOfLine()
		end
	end
end

function TextEdit:GoToEndOfLine()
	self.cursor = utf8.len(self.current_str or "") + 1
	self:UpdateDisplayString()
end


function TextEdit:ValidateChar(text)
	local invalidchars = string.char(8, 22, 27)
	if not self.allow_newline then
		invalidchars = invalidchars .. string.char(10, 13)
	end
	return (self.validchars == nil or string.find(self.validchars, text, 1, true))
		and (self.invalidchars == nil or not string.find(self.invalidchars, text, 1, true))
		and not string.find(invalidchars, text, 1, true)
		-- Note: even though text is in utf8, only testing the first bit is enough based on the current exclusion list
end

function TextEdit:ValidatedString(str)
	local res = ""
	for i=1,#str do
		local char = str:sub(i,i)
		if self:ValidateChar(char) then
			res = res .. char
		end
	end
	return res
end

-- * is a valid input char, any other char is formatting.
function TextEdit:SetFormat(format)
	self.format = format
	if format ~= nil then
		self:SetTextLengthLimit(#format)
	end
	return self
end

function TextEdit:FormatString(str)
	if self.format == nil then
		return str
	end
	local unformatted = self:ValidatedString(str)
	local res = ""
	for i=0,#unformatted do
		while #res < #self.format and self.format:sub(#res+1,#res+1) ~= "*" do
			res = res .. self.format:sub(#res+1,#res+1)
		end
		res = res .. unformatted:sub(i,i)
	end
	return res
end

function TextEdit:SetTextConversion(in_char, out_char)
	self.conversions[in_char] = out_char
end

-- NOTE: text is expected to be one char
-- pasting: was from a pasted string, not a keypress, so skip the tab next widget test
function TextEdit:OnTextInput(text)
	if not self.pasting and self.prediction_widget ~= nil and self.prediction_widget:OnTextInput(text) then
		return true
	end

	if not (self.shown and self.editing)
		or (self.limit ~= nil and self:GetText():utf8len() >= self.limit)
		or (not self.pasting and self.nextTextEditWidget ~= nil and text == "\t")
	then
		-- fail if:
		-- * we've reached our limit already
		-- * we pressed tab (checked before text conversion) and tab advances to next widget
		return false
	end

	text = self.conversions[text] or text

	if not self:ValidateChar(text) then
		return false
	end

	self:HandleTextInput(text)
	if self.onchange then
		self.onchange( self.current_str )
	end


	if self.editing and self.prediction_widget ~= nil then
		self.prediction_widget:RefreshPredictions()
	end

	local overflow = self.regionlimit and self.inst.TextWidget:HasOverflow()

	if self.format ~= nil then
		self:SetString(self:FormatString(self:GetText()))
	end

	if self.textinput_sound then
		TheFrontEnd:GetSound():PlaySound(self.textinput_sound)
	end

	return true, overflow
end

function TextEdit:OnProcess()
	self:SetEditing(false)
	TheInput:FlushInput()
	if self.OnTextEntered then
		self:OnTextEntered(self:GetText())
	end
end

function TextEdit:SetOnTabGoToTextEditWidget(texteditwidget)
	if texteditwidget and (type(texteditwidget) == "table" and texteditwidget.is_a and texteditwidget:is_a(TextEdit)) or (type(texteditwidget) == "function") then
		self.nextTextEditWidget = texteditwidget
	end
end

function TextEdit:OnStopForceProcessTextInput()
	if self.editing then
		self:SetEditing(false)

		if self.OnStopForceEdit ~= nil then
			self:OnStopForceEdit()
		end
	end
end

function TextEdit:OnRawKey(key, down)
	if self.editing and self.prediction_widget ~= nil and self.prediction_widget:OnRawKey(key, down) then
		self.editing_enter_down = false
		return true
	end

	if TextEdit._base.OnRawKey(self, key, down) then
		self.editing_enter_down = false
		return true
	end

	if self.editing then
		if down then
			if TheInput:IsPasteKey(key) then
				self.pasting = true
				local clipboard = TheSim:GetClipboardData()
				for i = 1, #clipboard do
					local success, overflow = self:OnTextInput(clipboard:sub(i, i))
					if overflow then
						break
					end
				end
				self.pasting = false
			elseif self.allow_newline and not self.at_line_max and key == InputConstants.Keys.ENTER and down then
				self:OnTextInput("\n")
			elseif key == InputConstants.Keys.BACKSPACE then
				if self.cursor > 1 then
					local new_str = utf8.sub(self.current_str, 1, self.cursor-2) .. utf8.sub(self.current_str, self.cursor)
					if self.cursor <= (utf8.len(self.current_str) + 1) then
						self.cursor = self.cursor - 1
					end
					self:SetString(new_str)
				end
			elseif key == InputConstants.Keys.DELETE or (key == InputConstants.Keys.KP_PERIOD and not TheSim:IsNumLockOn()) then
				if self.cursor <= utf8.len(self.current_str) then
					self:SetString(
						utf8.sub(self.current_str, 1, self.cursor-1)
						..
						utf8.sub(self.current_str, self.cursor+1))
				end
			elseif key == InputConstants.Keys.DOWN or (key == InputConstants.Keys.KP_2 and not TheSim:IsNumLockOn()) then
				local x,y = self.inst.TextWidget:GetCursorPoint()
				y = y - self.inst.TextWidget:GetLineHeight()
				local new_cursor = self.inst.TextWidget:GetCursorAtLocalPoint(x,y, false)
				if new_cursor > 0 then
					self.cursor = new_cursor
				end
			elseif key == InputConstants.Keys.UP or (key == InputConstants.Keys.KP_8 and not TheSim:IsNumLockOn()) then
				local x,y = self.inst.TextWidget:GetCursorPoint()
				y = y + self.inst.TextWidget:GetLineHeight()
				local new_cursor = self.inst.TextWidget:GetCursorAtLocalPoint(x,y, false)
				if new_cursor > 0 then
					self.cursor = new_cursor
				end
			elseif key == InputConstants.Keys.LEFT or (key == InputConstants.Keys.KP_4 and not TheSim:IsNumLockOn()) then
				if TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
					local char = utf8.sub(self.current_str, self.cursor-1, self.cursor-1) or ""
					if (char == " " or char == "\r" or char == "\n") then
						-- left to end of this whitespace
						while self.cursor > 1 and (char == " " or char == "\r" or char == "\n") do
							self.cursor = self.cursor - 1
							char = utf8.sub(self.current_str, self.cursor-1, self.cursor-1) or ""
						end
					end
					-- left to end of non-whitespace
					while self.cursor > 1 and (char ~= " " and char ~= "\r" and char ~= "\n") do
						self.cursor = self.cursor - 1
						char = utf8.sub(self.current_str, self.cursor-1, self.cursor-1) or ""
					end
					self.cursor = math.max(1, self.cursor)
				else
					self.cursor = math.max(1, self.cursor - 1)
				end
			elseif key == InputConstants.Keys.RIGHT or (key == InputConstants.Keys.KP_6 and not TheSim:IsNumLockOn()) then
				if TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
					local len = utf8.len(self.current_str)
					local char = utf8.sub(self.current_str, self.cursor, self.cursor) or ""
					if (char ~= " " and char ~= "\r" and char ~= "\n") then
						-- right to end of non-whitespace
						while self.cursor <= len and (char ~= " " and char ~= "\r" and char ~= "\n") do
							self.cursor = self.cursor + 1
							char = utf8.sub(self.current_str, self.cursor, self.cursor) or ""
						end
					end
					-- right to end of whitespace
					while self.cursor <= len and (char == " " or char == "\r" or char == "\n") do
						self.cursor = self.cursor + 1
						char = utf8.sub(self.current_str, self.cursor, self.cursor) or ""
					end
					self.cursor = self:_ClampToString(self.cursor)
				else
					self.cursor = self:_ClampToString(self.cursor + 1)
				end
			elseif key == InputConstants.Keys.HOME or (key == InputConstants.Keys.KP_7 and not TheSim:IsNumLockOn()) then
				if TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
					-- Ctrl-Home - start of text
					self.cursor = 1
				else
					-- Home - start of line
					local x,y = self.inst.TextWidget:GetCursorPoint()
	        			local cursor = self.inst.TextWidget:GetCursorAtLocalPoint(x - 8192,y, false) or 1
					if cursor >= 1 then
						self.cursor = self:_ClampToString(cursor)
						self:UpdateDisplayString()
					else
						self:GoToEndOfLine()
					end
				end
			elseif key == InputConstants.Keys.END or (key == InputConstants.Keys.KP_1 and not TheSim:IsNumLockOn()) then
				if TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
					-- Ctrl-End - end of text
					local len = utf8.len(self.current_str)
					self.cursor = len + 1
				else
					-- End - end of line
					local x,y = self.inst.TextWidget:GetCursorPoint()
	        			local cursor = self.inst.TextWidget:GetCursorAtLocalPoint(x + 8192,y, false) or 1
					if cursor >= 1 then
						self.cursor = self:_ClampToString(cursor)
						self:UpdateDisplayString()
					else
						self:GoToEndOfLine()
					end
				end
			else
				--print("REGULAR CHARACTER")
			end
			self.editing_enter_down = key == InputConstants.Keys.ENTER
			self:UpdateDisplayString()

		elseif key == InputConstants.Keys.ENTER and not self.focus then
			-- this is a fail safe incase the mouse changes the focus widget while editing the text field. We could look into FrontEnd:LockFocus but some screens require focus to be soft (eg: lobbyscreen's chat)
			if self.editing_enter_down then
				self.editing_enter_down = false
				if not self.allow_newline then
					self:OnProcess()
				end
			end
			return true

		elseif key == InputConstants.Keys.TAB and self.nextTextEditWidget ~= nil then
			self.editing_enter_down = false
			local nextWidg = self.nextTextEditWidget
			if type(nextWidg) == "function" then
				nextWidg = nextWidg()
			end
			if nextWidg ~= nil and type(nextWidg) == "table" and nextWidg.is_a and nextWidg:is_a(TextEdit) then
				self:SetEditing(false)
				nextWidg:SetEditing(true)
			end
			-- self.nextTextEditWidget:OnControl(Controls.Digital.ACCEPT, false)
		else
			self.editing_enter_down = false
		end

		if self.OnTextInputted ~= nil then
			self.OnTextInputted()
		end
		if self.onchange then
			self.onchange( self.current_Str )
		end
	end

	-- gobble up unregistered valid raw keys, or we will engage debug keys!
	return not self.validrawkeys[key]
end

function TextEdit:SetPassControlToScreen(control, pass)
	self.pass_controls_to_screen[control] = pass or nil
end

function TextEdit:ShouldPassControlToScreen(controls)
	for i = 1, controls:GetSize() do
		local control, deviceTypeId = controls:GetControlDetailsAt(i)
		if self.pass_controls_to_screen[control] then
			return true
		end
	end
	return false
end

function TextEdit:OnControl(controls, down)
	if self.editing and self.prediction_widget ~= nil and self.prediction_widget:OnControl(controls, down) then
		return true
	end

	if TextEdit._base.OnControl(self, controls, down) then return true end

	-- gobble up extra controls
	if self.editing and (not controls:Has(Controls.Digital.CANCEL, Controls.Digital.OPEN_DEBUG_CONSOLE, Controls.Digital.ACCEPT)) then
		return not self:ShouldPassControlToScreen(controls)
	end

	if self.editing and not down and controls:Has(Controls.Digital.CANCEL) then
		self:SetEditing(false)
		TheInput:EnableDebugToggle(true)
		return not self:ShouldPassControlToScreen(controls)
	end

	if self.enable_accept_control and not down and controls:Has(Controls.Digital.MENU_ACCEPT) then
		if not self.editing then
			self:SetEditing(true)
			return not self:ShouldPassControlToScreen(controls)
		elseif not controls:IsMouseButton(Controls.Digital.MENU_ACCEPT) then
			-- Ignore mouse ACCEPT since we don't want clicking to reposition
			-- cursor to leave edit mode.

			-- Previously this was being done only in the OnRawKey, but that
			-- doesnt handle controllers very well, this does.
			self:OnProcess()
			return not self:ShouldPassControlToScreen(controls)
		end
	end

	return false
end

function TextEdit:OnRemoved()
	-- self:SetEditing(false) -- Ricardo: I removed this because it was causing images to be changed after removal
	TheInput:EnableDebugToggle(true)
end

function TextEdit:OnFocusMove(dir, down)

	-- Note: It would be nice to call OnProcces() here, but this gets called
	-- when pressing WASD so it won't work.

	-- prevent the focus move while editing the text string
	if self.editing then return true end

	-- otherwise, allow focus to move as normal
	return TextEdit._base.OnFocusMove(self, dir, down)
end

function TextEdit:OnGainHover()
	TextEdit._base.OnGainHover(self)
end

function TextEdit:OnLoseHover()
	TextEdit._base.OnLoseHover(self)
end

function TextEdit:StartEditing()
	TheSim:StartTextInput()
	self:UpdateDisplayString()
	if self.cursor == nil then
		self:GoToEndOfLine()
	end
end

function TextEdit:StopEditing()
	self.cursor = nil
	TheSim:StopTextInput()
	self:UpdateDisplayString()
	if self.onlosefocus then self.onlosefocus() end
end

function TextEdit:OnGainFocus()
	Widget.OnGainFocus(self)

	if not self.editing then
		self:DoHoverImage()
	end
end

function TextEdit:OnLoseFocus()
	Widget.OnLoseFocus(self)

	if not self.editing then
		self:DoIdleImage()
	end
end

--- Prepares the default background and tint colours
-- Called by default on constructor
function TextEdit:SetDefaultTheme()
	-- Set default background tint colours
	self.idle_tint =            HexToRGB(0xF9F0C4FF)
	self.hover_tint =           HexToRGB(0xF9E68BFF)
	self.selected_tint =        HexToRGB(0xEFECDEFF)

	-- Set default text colours
	self.idle_text_color =      UICOLORS.BACKGROUND_MID
	self.edit_text_color =      UICOLORS.BACKGROUND_DARK
	self.prompt_text_color =    HexToRGB(0xAAA383FF)

	-- Set default textures
	self.focusedtex = "images/ui_ftf/textedit_bg.tex"
	self.activetex = "images/ui_ftf/textedit_bg.tex"
	self.unfocusedtex = "images/ui_ftf/textedit_bg.tex"

	-- Set default background
	self.focusimage = self:AddChild(Panel("images/ui_ftf/textedit_bg.tex"))
		:SetNineSliceCoords(21, 17, 80, 82)
		:SendToBack()

	-- Apply idle state
	self:DoIdleImage()
	self:SetGlyphColor(self.idle_text_color)

	return self
end

function TextEdit:SetInventoryTheme()
	-- Set default background tint colours
	self.idle_tint =            HexToRGB(0xFFFFFFff)
	self.hover_tint =           HexToRGB(0xFFFFFFff)
	self.selected_tint =        HexToRGB(0xFFFFFFff)

	-- Set default text colours
	self.idle_text_color =      HexToRGB(0xA59083ff)
	self.edit_text_color =      UICOLORS.BACKGROUND_DARK
	self.prompt_text_color =    HexToRGB(0xA59083ff)

	-- Set default textures
	self.focusedtex = "images/ui_ftf/textedit_bg.tex"
	self.activetex = "images/ui_ftf/textedit_bg.tex"
	self.unfocusedtex = "images/ui_ftf/textedit_bg.tex"

	-- Apply idle state
	self:DoIdleImage()
	self:SetGlyphColor(self.idle_text_color)
	self:SetHAlign(ANCHOR_LEFT)

	return self
end

function TextEdit:SetOnlineJoinTheme()
	-- Set default background tint colours
	self.idle_tint =            UICOLORS.LIGHT_TEXT_TITLE
	self.hover_tint =           UICOLORS.WHITE
	self.selected_tint =        UICOLORS.LIGHT_TEXT_TITLE

	-- Set default text colours
	self.idle_text_color =      UICOLORS.BACKGROUND_LIGHT
	self.edit_text_color =      UICOLORS.BACKGROUND_MID
	self.prompt_text_color =    HexToRGB(0xA59083ff)

	-- Set default textures
	self.focusedtex = "images/ui_ftf_multiplayer/code_input_bg.tex"
	self.activetex = "images/ui_ftf_multiplayer/code_input_bg.tex"
	self.unfocusedtex = "images/ui_ftf_multiplayer/code_input_bg.tex"

	-- Apply idle state
	self:DoIdleImage()
	self:SetGlyphColor(self.idle_text_color)
	self:SetHAlign(ANCHOR_LEFT)

	return self
end

function TextEdit:SetNineSliceCoords(minx, miny, maxx, maxy)
	self.focusimage:SetNineSliceCoords(minx, miny, maxx, maxy)
	return self
end

--- Sets the size of the background panel
-- The text region size inside uses the padding
function TextEdit:SetSize(width, height, paddingXleft, paddingYtop, paddingXright, paddingYbottom)
	if self.focusimage then
		paddingXleft = paddingXleft or 20 * HACK_FOR_4K
		paddingXright = paddingXright or paddingXleft
		paddingYtop = paddingYtop or 10 * HACK_FOR_4K
		paddingYbottom = paddingYbottom or paddingYtop
		height = height or self:GetFontSize() + paddingYtop + paddingYbottom
		self.focusimage:SetSize(width, height)
		self:SetRegionSize(width - paddingXleft - paddingXright, height - paddingYtop - paddingYbottom)
			:LayoutBounds("left", "top", self.focusimage)
			:Offset(paddingXleft, paddingYtop)
	else
		self:SetRegionSize(width, height or self:GetFontSize())
	end
	return self
end

function TextEdit:GetSize()
	if self.focusimage then
		return self.focusimage:GetSize()
	else
		return self:GetRegionSize()
	end
end

function TextEdit:GetBoundingBox()
	if self.focusimage then
		return self.focusimage:GetBoundingBox()
	else
		return Text.GetBoundingBox(self)
	end
end

function TextEdit:DoHoverImage()
	if self.focusimage and self.focusedtex then
		self.focusimage:SetTexture(self.focusedtex)
		self.focusimage:SetMultColor(self.hover_tint[1],self.hover_tint[2],self.hover_tint[3],self.hover_tint[4])
		self:SetGlyphColor(self.edit_text_color)
		if self.prompt then self.prompt:SetGlyphColor(self.edit_text_color) end
	end
end

function TextEdit:DoSelectedImage()
	if self.focusimage and self.activetex then
		self.focusimage:SetTexture(self.activetex)
		self.focusimage:SetMultColor(self.selected_tint[1],self.selected_tint[2],self.selected_tint[3],self.selected_tint[4])
		self:SetGlyphColor(self.edit_text_color)
		if self.prompt then self.prompt:SetGlyphColor(self.edit_text_color) end
	end
end

function TextEdit:DoIdleImage()
	if self.focusimage and self.unfocusedtex then
		self.focusimage:SetTexture(self.unfocusedtex)
		self.focusimage:SetMultColor(self.idle_tint[1],self.idle_tint[2],self.idle_tint[3],self.idle_tint[4])
		self:SetGlyphColor(self.idle_text_color)
		if self.prompt then self.prompt:SetGlyphColor(self.prompt_text_color) end
	end
end

function TextEdit:SetFocusedImage(unfocused, hovered, active)
	self.unfocusedtex = unfocused
	self.focusedtex = hovered
	self.activetex = active

	if self.focusedtex and self.unfocusedtex and self.activetex then
		self.focusimage:SetTexture(self.focus and self.focusedtex or self.unfocusedtex)
		if self.editing then
			self:DoSelectedImage()
		elseif self.focus then
			self:DoHoverImage()
		else
			self:DoIdleImage()
		end
	end
	return self
end

function TextEdit:SetIdleTextColour(r,g,b,a)
	if type(r) == "number" then
		self.idle_text_color = {r, g, b, a}
	else
		self.idle_text_color = r
	end
	if not self.editing then
		self:SetGlyphColor(self.idle_text_color[1], self.idle_text_color[2], self.idle_text_color[3], self.idle_text_color[4])
	end
	return self
end

function TextEdit:SetEditTextColour(r,g,b,a)
	if type(r) == "number" then
		self.edit_text_color = {r, g, b, a}
	else
		self.edit_text_color = r
	end
	if self.editing then
		self:SetGlyphColor(self.edit_text_color[1], self.edit_text_color[2], self.edit_text_color[3], self.edit_text_color[4])
	end
	return self
end

-- function Text:SetFadeAlpha(a, doChildren)
--  if not self.can_fade_alpha then return end

--     self:SetGlyphColour(self.colour[1], self.colour[2], self.colour[3], self.colour[4] * a)
--     Widget.SetFadeAlpha( self, a, doChildren )
-- end

function TextEdit:SetTextLengthLimit(limit)
	self.limit = limit
	return self
end

function TextEdit:EnableRegionSizeLimit(enable)
	self.regionlimit = enable
	return self
end

function TextEdit:SetCharacterFilter(validchars)
	self.validchars = validchars
	return self
end

function TextEdit:SetInvalidCharacterFilter(invalidchars)
	self.invalidchars = invalidchars
	return self
end

-- Unlike GetString() which returns the string stored in the displayed text widget
-- GetLineEditString will return the 'intended' string, even if the display is nulled out (for passwords)
function TextEdit:GetLineEditString()
	return self.inst.TextEdit:GetText()
end

function TextEdit:SetPassword(to)
	self.inst.TextEdit:SetPassword(to)
	return self
end

function TextEdit:SetForceUpperCase(to)
	self.inst.TextEdit:SetForceUpperCase(to)
	return self
end

function TextEdit:EnableScrollEditWindow(enable)
	self.inst.TextWidget:EnableScrollEditWindow(enable)
	return self
end

function TextEdit:SetHelpTextEdit(str)
	if str then
		self.edit_helptext = str
	end
	return self
end

function TextEdit:SetHelpTextCancel(str)
	if str then
		self.cancel_helptext = str
	end
	return self
end

function TextEdit:SetHelpTextApply(str)
	if str then
		self.apply_helptext = str
	end
	return self
end

function TextEdit:HasExclusiveHelpText()
	-- When editing a TextEdit widget, hide the screen's help text
	return self.editing
end

function TextEdit:EnableWordPrediction(layout, dictionary)
	if layout.mode ~= "disabled" then
		if self.prediction_widget == nil then
			self.prediction_widget = self:AddChild(WordPredictionWidget(self, layout.width, layout.mode))
			local sx, sy = self:GetRegionSize()
			local pad_x = layout.pad_x or 0
			local pad_y = layout.pad_y or 5
			self.prediction_widget:SetPosition(-sx*0.5 + pad_x, sy*0.5 + pad_y)
		end
		if dictionary ~= nil then
			self:AddWordPredictionDictionary(dictionary)
		end
	end
end

function TextEdit:AddWordPredictionDictionary(dictionary)
	if self.prediction_widget ~= nil then
		self.prediction_widget.word_predictor:AddDictionary(dictionary)
	end
end

function TextEdit:ApplyWordPrediction(prediction_index)
	if self.prediction_widget ~= nil then
		local new_str, cursor_pos = self.prediction_widget:ResolvePrediction(prediction_index)
		if new_str ~= nil then
			self:SetString(new_str)
			self.cursor = cursor_pos + 1
			self.inst.TextWidget:SetCursor(self.cursor)
			self.prediction_widget:Dismiss()
			return true
		end
	end

	return false
end

-- Ghostly text in the text field that indicates what content goes in the text
-- field. Something to prompt the user for what to write.
--
-- Set this after doing SetRegionSize!
function TextEdit:SetTextPrompt(prompt_text, color)
	color = color or self.prompt_text_color or self.color
	assert(prompt_text)
	self.prompt = self.prompt or self:AddChild(Text(self.font, self.size, nil, color))
	self.prompt:SetText(prompt_text)
		:SetGlyphColor(color)
	self.prompt:SetRegionSize(self:GetRegionSize())
	self.prompt:SetHAlign(ANCHOR_LEFT)
	self.prompt:SetVAlign(ANCHOR_TOP)
	return self
end

function TextEdit:_TryUpdateTextPrompt()
	if self.prompt then
		if self:GetText():len() > 0 or self.editing then
			self.prompt:Hide()
		else
			self.prompt:Show()
		end
	end
end

function TextEdit:SetFn(fn)
	self.onchange = fn
	return self
end

function TextEdit:UpdateDisplayString()

	local str = self.current_str
	if self.uppercase then str = str:upper() end
	self.inst.TextWidget:SetString(str)
	if self.editing or self.focus then
		self.inst.TextWidget:SetCursor(self.cursor)
	else
		self.inst.TextWidget:SetCursor()
	end
	--[[
	-- if we switch to hover vs focus then we can get rid of self.editing and not make external things maintain that
	if self.focus then
	   self.inst.TextWidget:SetCursor(self.cursor)
	else
	   self.inst.TextWidget:SetCursor()
	end
]]
end

function TextEdit:InsertCharacters(str)
	local left = utf8.sub(self.current_str, 1, self.cursor - 1) or ""
	local right = utf8.sub(self.current_str, self.cursor) or ""
	if left and right then
		local new_string = left.. str .. right
		self:SetString(new_string)
		if self.current_str == new_string then
			self.cursor = self.cursor + utf8.len(str)
			self:UpdateDisplayString()
		end
	end
end

function TextEdit:HandleTextInput(text)
	self:InsertCharacters(text)
	self:UpdateDisplayString()
	self:_TryUpdateTextPrompt()
	return true
end

return TextEdit
