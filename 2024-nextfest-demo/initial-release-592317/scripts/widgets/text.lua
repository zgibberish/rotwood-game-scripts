local UIHelpers = require "ui/uihelpers"
local Widget = require "widgets/widget"
local emotion = require "defs.emotion"
local fmodtable = require "defs.sound.fmodtable"
local kassert = require "util.kassert"
local kmath = require "util.kmath"
require "util.colorutil"


local Text = Class(Widget, function(self, font, size, text, colour)
	Widget._ctor(self, "Text")

	self.inst.entity:AddTextWidget()

	font = font or FONTFACE.DEFAULT

	self.inst.TextWidget:SetFont(font)
	self.font = font

	self:SetFontSize(size or 60)

	self:SetGlyphColor(colour or { 1, 1, 1, 1 })

	if text ~= nil then
		self:SetText(text)
	end
end)

function Text:OnAddedToScreen(screen)
	local owning_player = self:GetOwningPlayer()
	if owning_player
		and not self._on_input_device_changed -- already applied owner
	then
		self:RefreshText()
	end
end

function Text:SetFont(font)
	self.font = font
	self.inst.TextWidget:SetFont(font)
	return self
end

function Text:__tostring()
	return string.format("%s - %s", self._widgetname, self.text or "")
end

function Text:DebugDraw_AddSection(ui, panel)
	Text._base.DebugDraw_AddSection(self, ui, panel)
	local DebugPickers = require "dbui.debug_pickers"

	ui:Spacing()
	ui:Text("Text")
	ui:Indent() do
		local changed, text = ui:InputText("string", self:GetText())
		if changed then
			self:SetText(text)
		end
		if ui:CollapsingHeader("Text Value") then
			ui:Indent()
			if ui:BeginTable("text values", 2, ui.TableFlags.SizingFixedFit) then
				ui:TableNextRow()
				ui:TableNextColumn()
				ui:Text("GetText()")
				ui:TableNextColumn()
				ui:Text(self:GetText())

				ui:TableNextRow()
				ui:TableNextColumn()
				ui:Text("self.text")
				ui:TableNextColumn()
				ui:Text(self.text)

				ui:TableNextRow()
				ui:TableNextColumn()
				ui:Text("self.formatted_text")
				ui:TableNextColumn()
				ui:Text(self.formatted_text)
			end
			ui:Unindent()
			ui:EndTable()
		end

		if ui:Button("Start Spool") then
			self:Spool(100)
		end
		ui:SameLineWithSpace()
		if ui:Button("Snap Spool to End") then
			self:SnapSpool(1)
		end

		local region_x,region_y = self.inst.TextWidget:GetRegionSize()
		changed, region_x,region_y = ui:DragFloat3("region size", region_x,region_y, 100, 1, 1000, "%.f")
		if changed then
			self:SetRegionSize(region_x,region_y)
		end

		local colour = DebugPickers.Colour(ui, "colour", self.colour)
		if colour then
			self:SetGlyphColor(colour)
		end

		local face, size = DebugPickers.Font(ui, "", self.font, self.size)
		if face then
			self:SetFont(face)
			self:SetFontSize(size)
		end

		local shadow
		changed, shadow = ui:Checkbox("drop shadow", self.drop_shadow)
		if changed then
			self:EnableShadow(shadow)
		end

		-- We don't store this data on each text widget and we don't really
		-- need to. Cache something here so we can modify it.
		self.dbg_data = self.dbg_data or {
			shadow_color = {0,0,0,0},
			shadow_offset = Vector2(1,-1),
		}
		colour, changed = DebugPickers.Colour(ui, "shadow colour", self.dbg_data.shadow_color)
		if colour then
			self.dbg_data.shadow_color = colour
			self:SetShadowColor(colour)
			self:ForceSetText(self.text)
		end

		changed = ui:DragVec2f("shadow offset", self.dbg_data.shadow_offset, 0.1, -10, 10, "%.f")
		if changed then
			local v = self.dbg_data.shadow_offset
			self:SetShadowOffset(v.x,v.y)
			self:ForceSetText(self.text)
		end
	end
	ui:Unindent()
end

function Text:SetGlyphColor(r,g,b,a)
	if type(r) == "number" then
		if not g then
			-- hex value
			self.colour = {HexToRGBFloats(r)}
		else
		        -- r,g,b,a
			self.colour = {r, g, b, a}
		end
	else
		-- table
		self.colour = r
	end

	self.inst.TextWidget:SetGlyphColor(table.unpack(self.colour))
	return self
end

function Text:ColorTo(from, to, time, easefn, fn)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	local start_colour = from or self.colour
	self.inst.components.uianim:ColorTo(start_colour, to, time, easefn, fn)
	return self
end

-- Call this *before* EnableShadow.
function Text:SetShadowColor( r, g, b, a )
	if type(r) == "table" then
		r,g,b,a = table.unpack(r)
	end
	self.inst.TextWidget:SetShadowColor( r, g, b, a )
	return self
end

function Text:SetOutlineColor( r, g, b, a )
	if type(r) == "table" then
		r,g,b,a = table.unpack(r)
	end
	self.inst.TextWidget:SetOutlineColor( r, g, b, a )
	return self
end

-- Call this *before* EnableShadow.
function Text:SetShadowOffset( dx, dy )
	self.inst.TextWidget:SetShadowOffset( dx, dy )
	return self
end

function Text:GetColour()
	return { table.unpack(self.colour) }
end

function Text:SetHorizontalSqueeze(squeeze)
	self.inst.TextWidget:SetHorizontalSqueeze(squeeze)
	return self
end

function Text:SetFadeAlpha(a, skipChildren)
	if not self.can_fade_alpha then return end

	self.inst.TextWidget:SetGlyphColor(self.colour[1], self.colour[2], self.colour[3], self.colour[4] * a)
	Widget.SetFadeAlpha( self, a, skipChildren )
	return self
end

function Text:SetAlpha(a)
	self.inst.TextWidget:SetGlyphColor(1,1,1, a)
	return self
end

function Text:SetFont(font)
	self.inst.TextWidget:SetFont(font)
	self.font = font
	return self
end

function Text:SetFontSize(sz)
	if LOC then
		sz = sz * LOC.GetTextScale()
	end
	self.inst.TextWidget:SetFontSize(sz)
	self.size = sz
	return self
end

function Text:GetFontSize()
	return self.size
end

function Text:SetRegionSize(w,h)
	self.w = w
	self.h = h
	self.inst.TextWidget:SetRegionSize(w,h)
	return self
end

function Text:ShrinkToFitRegion(should_shrink)
	self.shrink_to_fit_region = true
	self:RefreshText()
	return self
end

function Text:SetSize(w,h)
	return self:SetRegionSize(w,h)
end

function Text:GetRegionSize()
	return self.inst.TextWidget:GetRegionSize()
end

function Text:ResetRegionSize()
	return self.inst.TextWidget:ResetRegionSize()
end

function Text:IgnoreOwningPlayerInputDevice()
	dbassert(self._on_input_device_changed == nil, "Too late, we're already listening. Call before SetText.")
	self.ignore_player_input_changes = true
	return self
end

function Text:SetText(text)
	text = text or ""
	if text ~= self.text then
		self.text = text
		self.inst.TextWidget:SetString(text or "")

		local owning_player = self:GetOwningPlayer()
		if not self.ignore_player_input_changes
			and owning_player
			and not self._on_input_device_changed
		then
			self._on_input_device_changed = function(source, data)
				self:RefreshText()
			end
			self.inst:ListenForEvent("input_device_changed", self._on_input_device_changed, owning_player)
		end

		self.formatted_text = SetFormattedText( self.inst.TextWidget, text, owning_player )

		if self.drop_shadow then
			self.inst.TextWidget:AddMarkup( 0, #self.formatted_text, MARKUP_SHADOW )
		end

		self:UpdateTransform()
		self:InvalidateBBox()

		if self.shrink_to_fit_region then
			local txt_h = self:GetRenderHeight()
			--print("Text:SetText", txt_h, self.h, self:GetFontSize())	-- NW: removed this as it is generating spam in the log. 
			if txt_h > self.h then
				self:SetFontSize(self:GetFontSize()-1)
				self:RefreshText()
			end
		end
	end
	return self
end

function Text:AppendText( text )
	if text and #text > 0 then
		text = ApplyFormatting( self.inst.TextWidget, self.text .. text )
		self.text = text
		self.inst.TextWidget:SetString( self.text )
		if not self.w then
			self:InvalidateBBox()
		end
	end
end

function Text:SetTextRaw( text )
	self.inst.TextWidget:ClearMarkup()
	self.text = text or ""
	self.inst.TextWidget:SetString( self.text )
	if not self.w then
		self:InvalidateBBox()
	end
	return self
end

function Text:SetValue( ... )
	return self:SetText(...)
end

function Text:GetText()
	return self.inst.TextWidget:GetString() or ""
	--	return self.text
end

-- Rarely need to call this because we automatically call when a OwningPlayer's
-- input device changes.
function Text:RefreshText()
	-- Force widget to set text again to ensure input method images are
	-- refreshed.
	local text = self.text
	self.text = nil
	return self:SetText(text)
end

-- shim
function Text:SetString(...)
	OBSOLETE("Text:SetString", "Text.SetText")
	return self:SetText(...)
end

--WARNING: This is not optimized!
-- Recommend to use only in FE menu screens.
-- Causes infinite loop when used with SetRegionSize!
--
-- maxwidth [optional]: max region width, only works when autosizing
-- maxchars [optional]: max chars from original string
-- ellipses [optional]: defaults to "..."
--
-- Works best specifying BOTH maxwidth AND maxchars!
--
-- How to pick non-arbitrary maxchars:
--  1) Call with only maxwidth, and a super long string of dots:
--     e.g. wdgt:SetTruncatedString(".............................", 30)
--  2) Find out how many dots were actually kept:
--     e.g. print(wdgt:GetText():len())
--  3) Use that number as an estimate for maxchars, or round up
--     a little just in case dots aren't the smallest character
function Text:SetTruncatedString(str, maxwidth, maxchars, ellipses)
	str = str ~= nil and str:match("^[^\n\v\f\r]*") or ""
	if #str > 0 then
		if type(ellipses) ~= "string" then
			ellipses = ellipses and "..." or ""
		end
		if maxchars ~= nil and str:utf8len() > maxchars then
			str = str:utf8sub(1, maxchars)
			self.inst.TextWidget:SetString(str..ellipses)
		else
			self.inst.TextWidget:SetString(str)
		end
		if maxwidth ~= nil then
			while self.inst.TextWidget:GetRegionSize() > maxwidth do
				str = str:utf8sub(1, -2)
				self.inst.TextWidget:SetString(str..ellipses)
			end
		end
	else
		self.inst.TextWidget:SetString("")
	end
	return self
end

function Text:SetVAlign(anchor)
	self.inst.TextWidget:SetVAlign(anchor)
	return self
end

function Text:SetHAlign(anchor)
	self.inst.TextWidget:SetHAlign(anchor)
	return self
end

function Text:LeftAlign()
	return self:SetHAlign( ANCHOR_LEFT )
end

function Text:RightAlign()
	return self:SetHAlign( ANCHOR_RIGHT )
end

function Text:TopAlign()
	self:SetVAlign( ANCHOR_TOP )
	return self
end

function Text:BottomAlign()
	self:SetVAlign( ANCHOR_BOTTOM )
	return self
end


function Text:EnableWordWrap(enable)
	self.inst.TextWidget:SetWordWrap(enable)
	return self
end

-- shim
function Text:SetWordWrap(enable)
	return self:EnableWordWrap(enable)
end

function Text:EnableWhitespaceWrap(enable)
	self.inst.TextWidget:EnableWhitespaceWrap(enable)
	return self
end


function Text:ApplyMultColor(r,g,b,a)
	local multcolor = type(r) == "number" and { r, g, b, a } or r
	self.inst.TextWidget:SetMultColor(table.unpack(multcolor))
	return self
end

function Text:ApplyAddColor(r,g,b,a)
	local addcolor = type(r) == "number" and { r, g, b, a } or r
	self.inst.TextWidget:SetAddColor(table.unpack(addcolor))
	return self
end

function Text:ApplyHue(hue)
	self.inst.TextWidget:SetHue(hue)
	return self
end

function Text:ApplyBrightness(brightness)
	self.inst.TextWidget:SetBrightness(brightness)
	return self
end

function Text:ApplySaturation(saturation)
	self.inst.TextWidget:SetSaturation(saturation)
	return self
end

function Text:SetBreakLongWords(dobreak)
	dobreak = kmath.use_nil_as_true(dobreak)
	self.inst.TextWidget:SetBreakLongWords(dobreak)
end

function Text:GetBoundingBox()
	if self.w and self.h then
		return -self.w/2,  -self.h/2, self.w/2,  self.h/2
	end

	if self.text and self.text ~= "" then
		local x1, y1, x2, y2 = self.inst.TextWidget:GetRenderBounds()
		return x1, y1, x2, y2
	end

	return 0, 0, 0, 0
end

function Text:EnableOutline( enable )
	enable = kmath.use_nil_as_true(enable)
	self.inst.TextWidget:EnableOutline( enable )
	return self
end

function Text:EnableShadow( enabled )
	enabled = kmath.use_nil_as_true(enabled)
	local changed = self.drop_shadow ~= enabled
	self.drop_shadow = enabled
	if changed and self.text then
		self:ForceSetText( self.text )
	end
	return self
end

function Text:ForceSetText(text)
	self.text = nil
	-- Underlying text actually needs to change or C code will ignore changes.
	self:SetText("")
	self:SetText(text)
end

function Text:OverrideLineHeight( height )
	self.inst.TextWidget:OverrideLineHeight( height )
	return self
end

function Text:SetAutoSize( width )
	self.inst.TextWidget:SetAutoSize( width )
	self:EnableWordWrap(true)
	return self
end

function Text:EnableUnderlines( enabled )
	enabled = kmath.use_nil_as_true(enabled)
	self.inst.TextWidget:EnableUnderlines( enabled )
	return self
end

function Text:SetSDFThreshold( threshold, boldThreshold )
	self.inst.TextWidget:SetSDFThreshold( threshold, boldThreshold or threshold * 0.9 )
	return self
end


function Text:SetDebugRender(val)
	self.inst.TextWidget:SetDebugRender(val)
	return self
end

function Text:GetRenderHeight()
	local x1, y1, x2, y2 = self.inst.TextWidget:GetRenderBounds()
	return math.abs(y2-y1)
end

function Text:SetRawText(text)
    text = text or ""
    if text ~= self.text then
        self.links = nil
        self.text = text
        self.inst.TextWidget:ClearMarkup()
        self.inst.TextWidget:SetString( text )

        self:UpdateTransform()
        self:InvalidateBBox()
    end
    return self
end

function Text:SetCursor(pos)
    self.inst.TextWidget:SetCursor(pos)
    return self
end

function Text:GetCursorAtPoint(x,y, override_line)
    if override_line or self:CheckHit(x,y) then
        x,y = self:TransformFromWorld(x,y)
        local cursor = self.inst.TextWidget:GetCursorAtLocalPoint(x,y, override_line)
        return cursor
    end
end

function Text:GetLines()
	return self.inst.TextWidget:GetLines()
end

function Text:GetVerticalCursorMove(in_offset, move_up)
	return self.inst.TextWidget:GetVerticalCursorMove(in_offset, move_up)
end


local function SplitStringIntoSegments(formatted_str, personality)
	-- Splits a post-formatting string into a table of strings, separated by a 'separator'
	-- So that we can show one line chunk by chunk instead of all at once.
	-- Also stores a table of delays

	local segments = {}
	local delays = {}

	local last_i = 1
	for i = 1, #formatted_str do
		local char = formatted_str:sub(i,i)

		-- Test to see if this char is any of our separators.
		local seg = formatted_str:sub(last_i,i)
		local separator = personality.separator[char]
		if separator then
			-- If it is, split this chunk out and sequence its delay as well.
			last_i = i+1
			table.insert(segments, seg)
			table.insert(delays, separator.delay)
		end

		-- If we're spooling character-by-character, delay for the character.
		-- Otherwise, we'll spool word-by-word, paced by the timing of a Space.
		if personality.spool_by_character then
			if not separator then
				table.insert(segments, seg)
				table.insert(delays, personality.character_delay)
				last_i = i+1
			end
		end
	end

	return segments, delays
end

local default_personality = {
	default_sound_event = fmodtable.Event.test_speech, -- Global default sound event
	character_delay = 0.035,
	spool_by_character = true,
	feeling = emotion.feeling.neutral,
	separator = {
		["!"] = {
			delay = 0.5,
			sound_event = fmodtable.Event.test_speech_exclamation,
		},
		["?"] = {
			delay = 0.5,
			sound_event = fmodtable.Event.test_speech_question,
		},
		[","] = {
			delay = 0.2,
			sound_event = fmodtable.Event.test_speech_comma,
		},
		["."] = {
			delay = 0.3,
			sound_event = fmodtable.Event.test_speech_period,
		},
		[" "] = {
			delay = 0.15,
			-- No sound event for space
		},
	}
}

-- Unspool text character-by-character with customized delays for different chars.
function Text:SetPersonalityText(text, complete_cb, personality)
	assert(text)
	personality = personality or default_personality
	kassert.typeof("table", personality.separator)

	self.formatted_text = nil -- we heavily rely on formatted_text being accurate, so ensure it gets set.

	-- Set the text of the balloon once so the layout is done once, then spool it out over time.
	self:SetText(text) -- Don't use the formatted string, because the formatting doesn't survive.
	assert(self.formatted_text, "Why didn't we update the formatted text? Was SetPersonalityText called with and identical string (use RefreshText instead)? Did SetText change?")
	-- formatted_text has all the markup removed so we can use it to calculate spool progress.
	local full_len = self.formatted_text:len()

	-- Split the formatted string into a sequence of segments+delays.
	-- We'll spool out a segment, then wait that segment's delay, before moving onto the next segment.
	-- Follow this pattern until the entire string is spooled out.
	local segments, delays = SplitStringIntoSegments(self.formatted_text, personality)

	-- Debugging data
	-- local debug_data =
	-- {
	-- 	segments = segments,
	-- 	delays = delays,
	-- 	text = text,
	-- 	full_len = text:len(),
	-- 	formatted_text = self.formatted_text,
	-- 	formatted_len = self.formatted_text:len(),
	-- }
	-- d_view(debug_data)

	self.snap_spool_to_end = nil
	if self.spool_updater then
		self.spool_updater:Stop()
	end
	self.inst.TextWidget:SetSpool(0)

	-- Build up an updater to unspool the text.
	self.spool_updater = Updater.Series()
	local cumulative_string = ""
	local sound_event = default_personality.default_sound_event
	local should_skip_sound = false
	local should_skip_next_sound = false
	for i,seg in ipairs(segments) do
		local delay = delays[i]

		self.spool_updater:Add(Updater.Series({
				-- Print the segment
				Updater.Do(function()
					if self.snap_spool_to_end then
						self.snap_spool_to_end = nil
						self.spool_updater:Stop()
						self.inst.TextWidget:SetSpool(1)
						if complete_cb then
							complete_cb(true)
						end
					else
						cumulative_string = cumulative_string..seg
						local cumulative_len = cumulative_string:len()
						local progress = cumulative_len / full_len
						self.inst.TextWidget:SetSpool(progress)
						--sound
						--print("TODO:luca", "Taste the Feeling", personality.feeling)
						if default_personality.separator[seg] then
							if default_personality.separator[seg].sound_event then
								sound_event = default_personality.separator[seg].sound_event
							else
								should_skip_sound = true
							end
						else
							if personality.feeling == emotion.feeling.happy then
								sound_event = fmodtable.Event.test_speech_happy
							else
								sound_event = fmodtable.Event.test_speech_neutral
							end
						end

						if should_skip_sound then
							should_skip_sound = false
							should_skip_next_sound = true
						elseif should_skip_next_sound then
							should_skip_next_sound = false
						else
							TheFrontEnd:GetSound():PlaySound(sound_event)
						end
						--~ print("Spool text:", cumulative_string)
					end
				end),

				-- Then wait the segment's delay
				Updater.Wait(delay),
				-- Speech naturally gets quieter as a character continues talking, getting maximally quiet at two seconds of continuous play
				-- Every time we hit a delay or break point, we reduce this attenuation accordingly
				TheAudio:SetGlobalParameter("AutoAttenuateTextScroll", (delay * -4)),
		}))
	end
	if complete_cb then
		self.spool_updater:Add(Updater.Series{
				Updater.Do(function()
					complete_cb(false)
				end)
			})
	end

	self:RunUpdater(self.spool_updater)

	return self
end

-- Immediately unspool and display all text at once.
function Text:SnapSpool()
	if self.spool_time then
		self:StopUpdating()
		self.inst.TextWidget:SetSpool(1)
		self.spool_time = nil
		self.total_spool_time = nil
	end
	if self.spool_updater then
		self.snap_spool_to_end = true
	end
	return self
end

-- TODO: should we remove this and only use SetPersonalityText?
function Text:Spool(speed)
	local characters = self.inst.TextWidget:GetStringLength()
	if characters > 0 then
		self:StartUpdating()
		speed = speed or 200
		if speed > 0 then
			self.total_spool_time = characters / speed
			self.spool_time = 0
			self.inst.TextWidget:SetSpool(0)
		else
			self.spool_time = nil
			self.total_spool_time = nil
			self:StopUpdating()
			self.inst.TextWidget:SetSpool(1)
		end
	else
		self.inst.TextWidget:SetSpool(1)
	end
	return self
end

function Text:GetSpool()
	return self.inst.TextWidget:GetSpool(1)
end

function Text:UpdateSpool(t)
	local strlen = self.formatted_text:utf8len()
	local oldCount = math.floor(self.inst.TextWidget:GetSpool() * strlen)
	self.inst.TextWidget:SetSpool(t)
	local newCount = math.floor(t * strlen)
	for i = oldCount+1, newCount do
		local char = self.formatted_text:utf8sub(i, i)
		if string.byte(char) > 32 then
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.slideshow_text)
		end
	end
end

function Text:OnUpdate(dt)
	Text._base.OnUpdate(self, dt)
	if self.spool_time then
		self.spool_time = self.spool_time + dt

		if self.spool_time >= self.total_spool_time then
			self.spool_time = nil
			self.total_spool_time = nil
			self:StopUpdating()
			self:UpdateSpool(1)
		else
			local t = self.spool_time / self.total_spool_time
			self:UpdateSpool(t)
		end
	end
end

function Text:SetBrightnessMap(gradient_tex, intensity)
	UIHelpers.SetBrightnessMapNative(self.inst.TextWidget, gradient_tex, intensity)
	return self
end

return Text
