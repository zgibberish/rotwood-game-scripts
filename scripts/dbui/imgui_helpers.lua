local color = require "math.modules.color"
local enum = require "util.enum"
local kassert = require "util.kassert"
local kstring = require "util.kstring"
local lume = require "util.lume"
local serpent = require "util.serpent"


-- self in here is equivalent to the usual ui elsewhere so we use a local to
-- make it consistent with other code. Call these like ui:SmallTooltipButton()
-- within your normal imgui render code.

-- Make meta keys scale values like they do for ui:DragFloat
-- (ImGui::DragBehaviorT), but for buttons or other modification UI.
function imgui:PickValueMultiplier(small, normal, big)
	small = small or 1
	normal = normal or 10
	big = big or 100
	if TheInput:IsKeyDown(InputConstants.Keys.SHIFT) then
		return big
	elseif TheInput:IsKeyDown(InputConstants.Keys.ALT) then
		return small
	end
	return normal
end

function imgui:PushDisabledStyle()
	local ui = self
	-- Copied from ImguiLuaProxy::Button
	ui:PushStyleColor(ui.Col.Text, { 0.6, 0.6, 0.6, 1.0 })
	ui:PushStyleColor(ui.Col.Button, { 0.2, 0.2, 0.2, 1.0 })
	ui:PushStyleColor(ui.Col.ButtonHovered, { 0.2, 0.2, 0.2, 1.0 })
	ui:PushStyleColor(ui.Col.ButtonActive, { 0.2, 0.2, 0.2, 1.0 })
	return 4
end

function imgui:PopDisabledStyle()
	local ui = self
	ui:PopStyleColor(4)
end

function imgui:PushStyle_RedButton()
	local ui = self
	ui:PushStyleColor(ui.Col.Button, { .75, 0, 0, 1 })
	ui:PushStyleColor(ui.Col.ButtonHovered, { 1, .2, .2, 1 })
	ui:PushStyleColor(ui.Col.ButtonActive, { .95, 0, 0, 1 })
	return 3
end

function imgui:PushStyle_GreenButton()
	local ui = self
	ui:PushStyleColor(ui.Col.Button, { 0, .5, 0, 1 })
	ui:PushStyleColor(ui.Col.ButtonHovered, { .05, .82, .05, 1 })
	ui:PushStyleColor(ui.Col.ButtonActive, { 0, .75, 0, 1 })
	return 3
end


function imgui:SameLineWithSpace(spacing)
	local ui = self
	spacing = spacing or 10
	ui:SameLine(nil, spacing)
end


function imgui:SmallTooltipButton(caption, tooltip, disabled)
	local ui = self
	local pressed = ui:SmallButton(caption, disabled)
	if tooltip and ui:IsItemHovered() then
		ui:BeginTooltip()
		ui:Text(tooltip)
		ui:EndTooltip()
	end
	return pressed
end

-- Pass a table of strings. Makes it easier to format multiline and keep them
-- to reasonable column width.
function imgui:SetTooltipMultiline(t)
	local ui = self
	ui:SetTooltip(table.concat(t, "\n"))
end

-- Convenience for most common tooltip pattern. Accepts a string or a table (for multiline).
function imgui:SetTooltipIfHovered(msg)
	local ui = self
	if ui:IsItemHovered() then
		if type(msg) == "table" then
			ui:SetTooltipMultiline(msg)
		else
			ui:SetTooltip(msg)
		end
	end
end

function imgui:Copy(context, copyable)
	local ui = self
	ui:SetClipboardText(context .. serpent.dump(copyable))
end

function imgui:PasteButton(context, id, tooltip)
	local ui = self
	local clipboard = ui:GetClipboardText()
	local can_paste = kstring.startswith(clipboard, context)
	if not can_paste then
		ui:PushDisabledStyle()
	end
	local paste = ui:Button(ui.icon.paste.. id)
	ui:SetTooltipIfHovered(tooltip or "Paste")
	if not can_paste then
		ui:PopDisabledStyle()
		return nil
	end
	if not paste then
		return nil
	end
	local stripped = clipboard:sub(context:len() + 1)
	local status, pasted = serpent.load(stripped)
	if not status then
		print("Failed to paste:", pasted)
		return nil
	end
	return pasted
end

-- Easy copy/paste buttons. If paste is clicked, returns the pasted value.
-- 'context' must be prefixed with "++" and is used to identify the contexts in which clipboard contents may be
-- pasted.
-- If the clipboard has contents that do not match the current context, the Paste button will be disabled.
function imgui:CopyPasteButtons(context, id, copyable)
	assert(context
		and context:len() > 4
		and context:sub(1,2) == "++",
		"Copying tables requires a string to identify the context in which it can be pasted; for safety."
	)
	local ui = self

	if ui:Button(ui.icon.copy.. id) then
		ui:Copy(context, copyable)
	end
	ui:SetTooltipIfHovered("Copy")

	ui:SameLineWithSpace()
	return ui:PasteButton(context, id)
end

function imgui:_CopyPasteButtons(context, id, copyable)
	local ui = self
	local t = ui:CopyPasteButtons(context, id, copyable)
	if t ~= nil then
		return t
	else
		return copyable
	end
end


-- Common widget for inputting filter text.
--
-- Returns nil if user has input no filter.
--
-- Only filter_text is required. Pass unique values for label or hint to ensure
-- unique imgui ids.
function imgui:FilterBar(filter_text, label, hint)
	local ui = self
	hint = hint or "Filter..."
	local id = "##".. hint
	if label then
		id = id .. label
		if kstring.startswith(label, "#") then
			-- Always include the magnifying glass.
			label = ui.icon.search .. label
		end
	else
		label = label or (ui.icon.search .. id)
	end

	local changed, new_v = ui:InputTextWithHint(label, hint, filter_text)
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.remove .. id) then
		changed = true
		new_v = nil
	end
	if changed then
		filter_text = new_v
	end
	return changed, filter_text
end
function imgui:_FilterBar(filter_text, label, hint)
	local ui = self
	local _, new_v = ui:FilterBar(filter_text, label, hint)
	return new_v
end
-- MatchesFilterBar is a convenient and safe way to query against FilterBar.
function imgui:MatchesFilterBar(filter_str, candidate)
	if not filter_str or filter_str:len() == 0 then
		return true
	end
	-- Catch errors due to malformed patterns (probably because user is still typing).
	local ok, found = pcall(string.find, candidate, filter_str)
	if ok then
		return found
	end
	-- Fallback to plaintext search.
	return candidate:find(filter_str, nil, true)
end


-- Accept a float3 sequence and write new values directly to it.
function imgui:DragFloat3List(label, vec, speed, minv, maxv)
	local ui = self
	local changed,nx,ny,nz = ui:DragFloat3(label, vec[1], vec[2], vec[3], speed, minv, maxv)
	if changed then
		vec[1] = nx
		vec[2] = ny
		vec[3] = nz
	end
	return changed, vec
end
-- Accept our Vector3 type and write new values directly to it.
function imgui:DragVec3f(label, vec, speed, minv, maxv)
	local ui = self
	local changed,nx,ny,nz = ui:DragFloat3(label, vec.x, vec.y, vec.z, speed, minv, maxv)
	if changed then
		vec.x = nx
		vec.y = ny
		vec.z = nz
	end
	return changed, vec
end

-- Accept a float2 sequence and write new values directly to it.
function imgui:DragFloat2List(label, vec, speed, minv, maxv)
	local ui = self
	local changed,nx,ny,nz = ui:DragFloat2(label, vec[1], vec[2], speed, minv, maxv)
	if changed then
		vec[1] = nx
		vec[2] = ny
	end
	return changed, vec
end
-- Accept our Vector2 type and write new values directly to it.
function imgui:DragVec2f(label, vec, speed, minv, maxv)
	local ui = self
	local changed,nx,ny,nz = ui:DragFloat2(label, vec.x, vec.y, speed, minv, maxv)
	if changed then
		vec.x = nx
		vec.y = ny
	end
	return changed, vec
end


function imgui.ConvertRGBFloatsToImU32(r, g, b, a)
	kassert.typeof("number", r, g, b)
	-- See ImGui::ColorConvertFloat4ToU32 and IM_COL32_R_SHIFT
	return RGBFloatsToHex(a, b, g, r)
end

function imgui.ConvertImU32ToRGBFloats(hex)
	kassert.typeof("number", hex)
	-- See ImGui::ColorConvertFloat4ToU32 and IM_COL32_R_SHIFT
	local a, b, g, r = HexToRGBFloats(hex)
	return r, g, b, a
end


-- Edit a color as an object created by the color module.
function imgui:ColorObjEdit(label, c, flags)
	local ui = self

	local r, g, b, a = color.unpack(c)
	local changed
	changed, r, g, b, a = ui:ColorEdit4(label, r, g, b, a, flags)
	if changed then
		c = color(r, g, b, a)
	end
	return changed, c
end
function imgui:_ColorObjEdit(label, c, flags)
	local ui = self
	local changed, newc = ui:ColorObjEdit(label, c, flags)
	return newc
end

-- Edit a color as a hex str. We store them as string so they look like
-- color values in our save data files (the serializer dumps hex numbers as
-- decimal numbers).
--
-- If the color matches the input default value, it will be returned as nil.
function imgui:ColorHexEdit4(label, hex_str, default_hex, flags)
	local ui = self

	default_hex = default_hex or 0xFFFFFFFF
	if type(default_hex) == "string" then
		default_hex = StrToHex(default_hex)
	end
	local c = hex_str and StrToHex(hex_str) or default_hex
	local r, g, b, a = HexToRGBFloats(c)
	local changed
	changed, r, g, b, a = ui:ColorEdit4(label, r, g, b, a, flags)
	if changed then
		local hex = RGBFloatsToHex(r, g, b, a)
		if hex == default_hex then
			hex_str = nil
		else
			hex_str = HexToStr(hex)
		end
	end
	return changed, hex_str
end
function imgui:_ColorHexEdit4(...)
	local ui = self
	local changed, newhex = ui:ColorHexEdit4(...)
	return newhex
end

-- Prefer ColorHexEdit4 for data since it's easier to understand when looking
-- at the savedata.
function imgui:ColorHex4_Int(label, c, flags)
	local ui = self
	local rgba = HexToRGB(c)
	local changed, r,g,b,a = ui:ColorEdit4(label, rgba[1], rgba[2], rgba[3], rgba[4], flags)
	if changed then
		c = RGBFloatsToHex(r, g, b, a)
	end
	return changed, c
end
function imgui:_ColorHex4_Int(...)
	local ui = self
	local changed, newhex = ui:ColorHex4_Int(...)
	return newhex
end


-- Combo, but if you want to store the string value instead of the index.
--
-- Assumes your list is already sorted. The first item is the default so
-- store_first_as_nil is useful to skip storing anything when it's the default
-- (useful for editor combos).
function imgui:ComboAsString(label, current, items, store_first_as_nil, ...)
	local ui = self

	local original = current

	-- Map 'current' to an index of 'items'.
	local current_idx
	if store_first_as_nil and not current then
		current_idx = 1
	else
		current_idx = lume.find(items, current)

		-- If the user-specified current is not in the candidates list, reset the selection to the first element.
		if not current_idx then
			current_idx = 1
			if store_first_as_nil then
				current = nil
			else
				current = items[current_idx]
			end
		end
	end

	local changed, new_idx, closed = ui:Combo(label, current_idx, items, ...)

	-- If the Combo is closed, no other valid info is returned from it.
	if not closed and changed then
		current_idx = new_idx
		if current_idx == 1 and store_first_as_nil then
			current = nil
		else
			current = items[current_idx]
		end
	end

	-- 'current' may have changed due to:
	-- 1) initialization, if it was passed in as nil and store_first_as_nil is off
	-- 2) re-initialization, if it was not found in 'items'
	-- 3) user edit as effected by Combo()
	return current ~= original, current, closed
end

function imgui:_ComboAsString(label, current, items, store_first_as_nil, ...)
	local ui = self
	local changed, closed
	changed, current, closed = ui:ComboAsString(label, current, items, store_first_as_nil, ...)
	return current, closed
end

function imgui:Enum(label, current, enum_type, is_optional, ...)
	local ui = self
	local options = enum_type:Ordered() -- assume your order matters
	if is_optional then
		options = lume.clone(options)
		table.insert(options, 1, "")
	end
	return ui:ComboAsString(label, current, options, is_optional, ...)
end

function imgui:_Enum(label, current, enum_type, is_optional, ...)
	local ui = self
	local changed, closed
	changed, current, closed = ui:Enum(label, current, enum_type, is_optional, ...)
	return current, closed
end

imgui.MultiColumnListResult = enum {
	"None",
	"Add",
	"Remove",
	"Edit"
}

-- A list that lets you add/remove items and renders with multiple columns.
-- Define how you render each item in `data` in DrawRow.
-- Use with ui:SetNextColumnItemToFillWidth().
function imgui:MultiColumnList(id, data, columns, DrawRow, MakeRow, OnAddButtonHovered, OnRemoveButtonHovered)
	kassert.equal(id:sub(1,2), '##', 'imgui widget IDs are prefixed with ##.')
	MakeRow = MakeRow or function() return {} end
	kassert.typeof("function", DrawRow, MakeRow)
	local ui = self
	local addrem_btns_w = 55
	local w = ui:GetContentRegionAvail() - addrem_btns_w

	ui:Columns(#columns + 1, nil, false)

	if columns[1].width_pct then
		local offset = 0
		for i,c in ipairs(columns) do
			offset = offset + (w * c.width_pct)
			ui:SetColumnOffset(i, offset)
		end
	end
	-- Setting previous column works better than setting add/remove column
	-- directly.
	ui:SetColumnOffset(#columns, w)

	for _,c in ipairs(columns) do
		if c.name then ui:Text(c.name) end
		ui:NextColumn()
	end
	-- Skip title for add/remove
	ui:NextColumn()

	local result = ui.MultiColumnListResult.id.None

	local changed
	local numrows = #data
	for i,item in ipairs(data) do
		local item_id = id..tostring(i)
		changed, item = DrawRow(ui, i, item_id .. "item", item)
		if changed then
			data[i] = item
			result = ui.MultiColumnListResult.id.Edit
		end

		ui:NextColumn()

		changed = ui:Button(ui.icon.remove .. item_id)
		if ui:IsItemHovered() and OnRemoveButtonHovered then OnRemoveButtonHovered(i) end
		if changed then
			table.remove(data, i)
			result = ui.MultiColumnListResult.id.Remove
		end

		if i == numrows then
			ui:SameLineWithSpace()
			changed = ui:Button(ui.icon.add .. item_id)
			if ui:IsItemHovered() and OnAddButtonHovered then OnAddButtonHovered(i) end
			if changed then
				table.insert(data, MakeRow())
				result = ui.MultiColumnListResult.id.Add
			end
		end

		ui:NextColumn()
	end

	-- If there are no rows yet, explicitly show one Add Item button.
	if numrows == 0 then
		changed = ui:Button(ui.icon.add .. id)
		if ui:IsItemHovered() and OnAddButtonHovered then OnAddButtonHovered(i) end
		if changed then
			table.insert(data, MakeRow())
			result = ui.MultiColumnListResult.id.Add
		end
	end

	ui:Columns()
	return result
end

function imgui:SetNextColumnItemToFillWidth()
	local ui = self
	local pad = 10
	ui:SetNextItemWidth(ui:GetColumnWidth() - pad)
end

local ERROR_MODAL = "Error!"

local last_error_modal_msg
function imgui:OpenErrorModal(error_message)
	local ui = self
	last_error_modal_msg = error_message
	ui:OpenPopup(ERROR_MODAL)
end

function imgui:ErrorModal()
	local ui = self
	if not ui:BeginPopupModal(ERROR_MODAL, false) then
		return
	end
	ui:Text(last_error_modal_msg)
	if ui:Button("Close") then
		last_error_modal_msg = nil
		ui:CloseCurrentPopup()
	end
	ui:EndPopup()
end

-- Present a set of buttons to manipulate an element of a list.
-- If a button is clicked, this function returns an index and a function.
-- The index is the new selection index that will be valid after the function is invoked. Some operations will affect
-- the parent list and so will affect the selection index as well.
-- The function will effect the semantics of the clicked button.
-- If no button is clicked, return nil.
function imgui:ListElementManipulators(context, id, list, index, ctor_fn, copy_fn, ordered)
	local ui = self
	local element = list[index]
	local new_index
	local deferred_fn
	if ui:Button(ui.icon.remove..id) then
		new_index = index
		deferred_fn = function()
			table.remove(list, index)
		end
	end
	ui:SetTooltipIfHovered("Remove")
	if ctor_fn then
		ui:SameLineWithSpace()
		if ui:Button(ui.icon.add..id) then
			new_index = index
			deferred_fn = function()
				new_index = index
				table.insert(list, index, ctor_fn())
			end
		end
		ui:SetTooltipIfHovered("Insert")
	end
	if ordered then
		if index ~= 1 then
			ui:SameLineWithSpace()
			if ui:Button(ui.icon.arrow_up..id) then
				new_index = index - 1
				deferred_fn = function()
					table.remove(list, index)
					table.insert(list, index - 1, element)
				end
			end
			ui:SetTooltipIfHovered("Move Up")
		end
		if index ~= #list then
			ui:SameLineWithSpace()
			if ui:Button(ui.icon.arrow_down..id) then
				new_index = index + 1
				deferred_fn = function()
					table.remove(list, index)
					table.insert(list, index + 1, element)
				end
			end
			ui:SetTooltipIfHovered("Move Down")
		end
	end
	if context then
		ui:SameLineWithSpace()
		if ui:Button("Cut"..id) then
			new_index = index
			deferred_fn = function()
				table.remove(list, index)
				ui:Copy(context, element)
			end
		end
		ui:SameLineWithSpace()
		local pasted_element = ui:CopyPasteButtons(context, id, element)
		if pasted_element then
			new_index = index
			deferred_fn = function()
				xpcall(
					function() list[index] = copy_fn and copy_fn(pasted_element) or pasted_element end,
					function(error_message) ui:OpenErrorModal(error_message) end
				)
			end
		end
	end
	return new_index, deferred_fn
end

-- Organize a variable-length array-like table as a visual table. Contents of each cell are drawn by the client
-- via draw_fn.
function imgui:AutoTable(label, values, draw_fn, preferred_row_count, maximum_column_count)
	local ui = self
	if label and not ui:CollapsingHeader(label) then
		return
	end
	if #values == 0 then
		return
	end
	preferred_row_count = preferred_row_count or 1
	maximum_column_count = maximum_column_count or 3
	local column_count = math.min(maximum_column_count, math.ceil(#values / preferred_row_count))
	local row_count = math.ceil(#values / column_count)
	ui:Columns(column_count)
	for i, value in ipairs(values) do
		draw_fn(i, value)
		if i % row_count == 0 then
			ui:NextColumn()
		end
	end
	ui:Columns()
end

-- Present a radio button interface to multi-select from a list of strings, and persist as a list of strings.
-- Return true on change, false otherwise.
function imgui:FlagRadioButtons(label, all_values, current_values, preferred_row_count, maximum_column_count)
	local ui = self
	local deferred_fn
	local function Draw(i, value)
		local index = current_values and lume(current_values):find(value):result()
		local is_on = index ~= nil
		local id = "##"..label..i
		if ui:RadioButton(value..id, is_on) then
			if is_on then
				deferred_fn = function()
					table.remove(current_values, index)
				end
			else
				deferred_fn = function()
					table.insert(current_values, value)
				end
			end
		end
	end
	ui:AutoTable(label, all_values, Draw, preferred_row_count, maximum_column_count)
	if deferred_fn then
		deferred_fn()
		return true
	end
	return false
end

function imgui:TextTable(label, values, preferred_row_count, maximum_column_count)
	local ui = self
	ui:AutoTable(label, values, function(_, value) ui:Text(value) end, preferred_row_count, maximum_column_count)
end
