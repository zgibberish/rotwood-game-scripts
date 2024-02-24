-- Look at previous input and complete the likely lua code.
--
require "util"
local kstring = require "util.kstring"


local function _CountOccurrences(str, delimiter)
	local _, num_delimiters = str:gsub(delimiter, '')
	return num_delimiters
end

local LuaCompleter = Class(function(self)
	self:ClearState()
end)

function LuaCompleter:DebugDraw_AddSection(ui, panel)
	ui:Text("LuaCompleter")

	ui:Text("obj_expr: ".. tostring(self.obj_expr))
	ui:Text("obj_deref_expr: ".. tostring(self.obj_deref_expr))
	ui:Text("incomplete_input: ".. tostring(self.incomplete_input))
	if type(self.evaluated_obj) == 'table' then
		ui:Text("evaluated_obj: ")
		ui:SameLineWithSpace()
		panel:AppendTable(ui, self.evaluated_obj, tostring(self.evaluated_obj))
	else
		ui:Text("evaluated_obj: ".. tostring(self.evaluated_obj))
	end
end

function LuaCompleter:ClearState()
	self.incomplete_input = nil
	self.obj_deref_expr = ""
	self.obj_expr = nil
	self.evaluated_obj = nil
end

function LuaCompleter:_GetClosingDelimiters(str)

	-- Closing code assumes we cannot have multiple unclosed delimiters (so we
	-- don't need to deal with nesting) because we won't trigger suggestions if
	-- there are multiple open delimiters because we treat all delimiters as
	-- interchangeable.

	local closing = ""

	-- Close delimiters and parens, get us ready to submit text.

	for i,delimiter in ipairs({'"', "'"}) do
		local num_delimiters = _CountOccurrences(str, delimiter)
		if (num_delimiters % 2 > 0) then
			closing = closing .. delimiter
		end
	end

	local remaining_parens = _CountOccurrences(str, "%{") - _CountOccurrences(str, "%}")
	closing = closing .. string.rep("}", remaining_parens)

	remaining_parens = _CountOccurrences(str, "%(") - _CountOccurrences(str, "%)")
	closing = closing .. string.rep(")", remaining_parens)

	if closing:len() > 0 then
		return closing
	end
end

local function eval_expression(obj_expr)
	-- Lunar instances are userdata we can't iterate for suggestions.
	-- Find the matching class definition (i.e.,
	-- cNetworkLuaProxy::className) that is a table of members.
	local obj = rawget(_G, obj_expr)
	if obj
		-- TheBlah singletons are often userdata that we can't complete, so
		-- only return it if it's a table.
		and type(obj) == 'table'
		then
		return obj
	end
	for capture in obj_expr:gmatch("The(.*)") do
		obj = rawget(_G, capture)
		if obj then
			return obj
		end
	end

	--~ print("Evaluating lua expression:", obj_expr)

	-- Execute some lua code to give us a known variable
	-- (__KLEI_AUTOCOMPLETE) pointing to our object.
	local status, r = pcall( load( "__KLEI_AUTOCOMPLETE=" .. obj_expr ) )
	if status then
		return __KLEI_AUTOCOMPLETE
	end
end

-- For lua autocompletion to be improved, you really need to start knowing
-- about the language that's being autocompleted and the string must be
-- tokenized and fed into a lexer.
--
-- For instance, what should you autocomplete here:
--        print(TheSim:Get<tab>
--
-- Given understanding of the language, we know that the object to get is TheSim and
-- it's the metatable from that to autocomplete from. However, you need to know that
-- "print(" is not part of that object.
--
-- Conversely, if I have "SomeFunction().GetTheSim():Get<tab>" then I need to include
-- "SomeFunction()." as opposed to stripping it off. Again, we're back to understanding
-- the language.
--
-- Something that might work is to cheat by starting from the last token, then iterating
-- backwards evaluating pcalls until you don't get an error or you reach the front of the
-- string.
function LuaCompleter:LuaComplete(str, cursor_pos, is_cursor_at_end)
	if string.find(str, "(", 1, true ) then
		-- Limit completion for functions to closing delimiters to avoid
		-- executing non-idempotent ones.
		local closed = is_cursor_at_end and self:_GetClosingDelimiters(str) or nil
		local candidates = {}
		if closed then
			local long = str .. closed
			table.insert(candidates, {
					word = long:sub(cursor_pos),
					display = closed,
				})
		end
		return candidates
	end

	local obj_expr = nil
	local incomplete_input = str

	local input_len = string.len(str)
	local rev_str = string.reverse(str)
	local idx_dot = string.find(rev_str, ".", 1, true) or input_len
	local idx_colon = string.find(rev_str, ":", 1, true) or input_len
	local idx = math.min(idx_dot, idx_colon)
	if idx < input_len then
		local last_deref = input_len - idx
		obj_expr         = string.sub(str, 1, last_deref)
		incomplete_input = string.sub(str, last_deref + 2)
		-- Capture immediately to allow swapping between . and :
		self.obj_deref_expr = str:sub(1, str:len() - idx + 1) -- must include that last character!
	end

	self.incomplete_input = incomplete_input -- tracked only for debug

	local evaluated_obj = self.evaluated_obj
	if obj_expr then
		-- Don't re-evaluate the same input.
		if self.obj_expr ~= obj_expr then
			self.obj_expr = obj_expr

			evaluated_obj = eval_expression(obj_expr)
			if evaluated_obj then
				self.evaluated_obj = evaluated_obj
				self.evaluated_obj_meta = getmetatable( evaluated_obj )
			end
		end
	else
		-- Only look at globals if there's no prior context.
		evaluated_obj = _G
	end

	local candidates = {}
	self:_AddCandidates(candidates, evaluated_obj, incomplete_input, cursor_pos)
	if self.evaluated_obj_meta then
		self:_AddCandidates(candidates, self.evaluated_obj_meta, incomplete_input, cursor_pos)
	end

	return candidates
end

function LuaCompleter:_AddCandidates(candidates, luacomplete_obj, incomplete_input, cursor_pos)
	if type(luacomplete_obj) == 'table' then
		for k, v in pairs( luacomplete_obj ) do
			if kstring.startswith( k, incomplete_input ) then
				local candidate = self.obj_deref_expr .. k
				if type(v) == 'function' then
					candidate = candidate .. '('
				end
				table.insert(candidates, {
						word = candidate:sub(cursor_pos),
						-- Strip off preceeding object to give more space for
						-- matches. Can't use incomplete_input because it might
						-- be empty.
						display = candidate:gsub("^.*[:.)]", ""),
					})
			end
		end
	end
end

-- Not called with self!
function LuaCompleter._get_display_string(word, data)
	if data and data.candidate.display then
		return data.candidate.display
	end
	return word
end

function LuaCompleter:CreateWordPredictionDictionary(args)
	return {
		name = "lua",
		prefix = "",
		num_chars = 2,
		generate_candidates = function(text, cursor_pos, is_cursor_at_end)
			return self:LuaComplete(text, cursor_pos, is_cursor_at_end)
		end,
		GetDisplayString = self._get_display_string,
	}
end

return LuaCompleter
