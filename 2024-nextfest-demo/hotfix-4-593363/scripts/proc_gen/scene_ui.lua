--[[
	This file contains composite widget patterns that were found to be common in SceneGenEditor.
]]
local DebugNodes = require "dbui.debug_nodes"
local Iterator = require "util.iterator"
local Lume = require "util.lume"

UI_FEATURE_INLINE_MANIPULATORS = 1 << 0
UI_FEATURE_ENABLE = 1 << 1
UI_FEATURE_NESTED = 1 << 2
UI_FEATURE_ORDERED = 1 << 3

function PushHeaderColor(ui, color)
	local header_color = {}
	for k, v in pairs(color) do
		header_color[k] = v * 0.7
	end
	local active_color = {}
	for k, v in pairs(color) do
		active_color[k] = v * 0.9
	end
	ui:PushStyleColor(ui.Col.Header, header_color)
	ui:PushStyleColor(ui.Col.HeaderHovered, color)
	ui:PushStyleColor(ui.Col.HeaderActive, active_color)
end

function PopHeaderColor(ui)
	ui:PopStyleColor()
	ui:PopStyleColor()
	ui:PopStyleColor()
end

function PushButtonColor(ui, color)
	local button_color = {}
	for k, v in pairs(color) do
		button_color[k] = v * 0.7
	end
	local active_color = {}
	for k, v in pairs(color) do
		active_color[k] = v * 0.9
	end
	ui:PushStyleColor(ui.Col.Button, button_color)
	ui:PushStyleColor(ui.Col.ButtonHovered, color)
	ui:PushStyleColor(ui.Col.ButtonActive, active_color)
end

function PopButtonColor(ui)
	ui:PopStyleColor()
	ui:PopStyleColor()
	ui:PopStyleColor()
end

---@class ListScheme Customization points for the ListUi composite widget algorithm.
---@field title string CamelCase list name
---@field name string lowercase key under which the list is stored in the SceneGen
---@field element_editor string key to reference the desired editor in DebugNodes for the list element type
---@field browser_context string PrefabBrowserContext.id for the list element type
---@field clipboard_context string Clipboard context id (i.e. ++-prefixed) for cut'n'pasting Elements.
---@field InlineUi function Function to prefix the Element selectable on the same line.
---@field ElementUi function Function to invoke for each element for imgui.
---@field ElementLabel function Function to invoke on each element to get it's display label; defaults to the identity function.
---@field EnableElement function Function to invoke when 'enabled' changes
---@field Construct function Function to create a new element.
---@field Clone function Function to clone an element
---@field features number bitmask of UI_FEATURE_XXXs to control presentation
---@field column_count number Column count of the AutoTables displayed, defaulting to 1.

---Present a list-like table as a series of Selectables that open when selected to present the
---ElementUi as specified ih the ListScheme.
---@param editor table Bookkeeping.
---@param context table Persistent state.
---@param ui table imgui.
---@param id string imgui id (i.e. ##-prefixed) uniquely identifying this context.
---@param scheme ListScheme Customization points of the widget.
function ListUi(editor, context, ui, id, scheme)
	-- Fill in defaults for properties that were not provided by client.
	scheme.features = scheme.features or 0
	scheme.ElementLabel = scheme.ElementLabel or function(element) return element end
	scheme.column_count = scheme.column_count or 1

	if not ui:CollapsingHeader(scheme.title .. id) then
		return
	end

	id = id .. scheme.title
	ui:Indent()

	context[scheme.name] = context[scheme.name] or {}
	local list = context[scheme.name]

	-- scheme.name is plural. Strip off the 's'.
	local pluralization_char_count = scheme.name:sub(#scheme.name - 1) == "es"
		and 2
		or 1
	local selected_key = "selected_" .. string.sub(scheme.name, 1, #scheme.name - pluralization_char_count)
	local inline_manipulators = (scheme.features & UI_FEATURE_INLINE_MANIPULATORS) ~= 0

	local deferred_fn

	local is_nested = (scheme.features & UI_FEATURE_NESTED) ~= 0
	local is_ordered = (scheme.features & UI_FEATURE_ORDERED) ~= 0

	local function AutoTable(id, label, list)
		local function ElementUi(i, element)
			local id = id .. i

			if is_nested then
				ui:Indent()
			end

			local same_line = false

			-- Present the list element manipulators in a line in the current context.
			-- Suppress element ui if so specified. Generally, element ui is suppressed
			-- if the manipulators are inline preceding the element.
			local function ListElementManipulators(suppress_element_ui)
				local new_selected, manip_fn = ui:ListElementManipulators(
					scheme.clipboard_context,
					id,
					list,
					i,
					scheme.Construct,
					scheme.Clone,
					is_ordered
				)
				if manip_fn then
					deferred_fn = manip_fn
				end

				if scheme.element_editor then
					ui:SameLineWithSpace()
					if ui:Button(ui.icon.folder .. id) then
						DebugNodes[scheme.element_editor]:FindOrCreateEditor(scheme.ElementLabel(element))
					end
					ui:SetTooltipIfHovered("Open in " .. scheme.element_editor)
				end

				if new_selected and editor[selected_key] == i then
					editor[selected_key] = new_selected
				end

				local element_fn = not suppress_element_ui
					and scheme.ElementUi
					and scheme.ElementUi(ui, id, element)
				if element_fn then
					deferred_fn = manip_fn
				end
			end

			-- If the client has inline ui, present that first.
			if scheme.InlineUi then
				same_line = scheme.InlineUi(ui, id, element, i)
			end

			-- Now do list element manipulators inline if so specified.
			if inline_manipulators then
				ListElementManipulators(true)
				same_line = true
			end

			-- Enabled feature as an inline checkbox.
			if (scheme.features & UI_FEATURE_ENABLE) ~= 0 then
				if same_line then
					ui:SameLineWithSpace()
				end
				local changed, new_enabled = ui:Checkbox(id, element.enabled)
				ui:SetTooltipIfHovered("Enabled")
				same_line = true
				if changed then
					element.enabled = new_enabled
					if scheme.EnableElement then
						scheme.EnableElement(element, i, new_enabled)
					end
				end
			end

			-- Present the element itself.
			if same_line then
				ui:SameLineWithSpace()
			end
			local label = "[" .. i .. "] " .. scheme.ElementLabel(element)

			-- If it has any editable properties, make it a Selectable.
			if scheme.ElementUi or not inline_manipulators then
				local changed, selected = ui:Selectable(
					label .. id,
					editor[selected_key] == i
				)
				if changed then
					editor[selected_key] = selected and i or nil
				end

				-- If it is currently selected, present its editable properties.
				if editor[selected_key] == i then
					ui:Indent()
					if inline_manipulators then
						assert(scheme.ElementUi)
						scheme.ElementUi(ui, id, element)
					else
						ListElementManipulators(false)
					end
					ui:Unindent()
				end

			-- If the element has no editable properties, just present it as text.
			else
				ui:Text(label)
			end

			if is_nested then
				ui:Unindent()
			end
		end
		ui:AutoTable(label, list, ElementUi, nil, scheme.column_count)
	end

	-- If the target table is a dict of lists, then present each key as a collapsible with
	-- an editable list beneath.
	if is_nested then
		Lume(list):keys():sort():each(function(key)
			AutoTable(id .. key, key, list[key])
		end)
	-- Otherwise just present the list as editable.
	else
		AutoTable(id, nil, list)
	end

	if deferred_fn then
		deferred_fn()
	end

	-- TODO @chrisp #scenegen - nested tables should remove their empty categories

	local same_line = false

	-- Add.
	if scheme.browser_context or scheme.Construct then
		if ui:Button(ui.icon.add .. id) then
			if scheme.browser_context then
				editor.browser:Open(ui, scheme.browser_context)
			elseif scheme.Construct then
				table.insert(list, scheme.Construct())
			end
		end
		ui:SetTooltipIfHovered("Add " .. scheme.title)
		same_line = true
	end

	-- Paste.
	-- Disallowed for nested tables as we wouldn't know which category to paste into.
	if scheme.clipboard_context and not is_nested then
		if same_line then
			ui:SameLineWithSpace()
		end
		local pasted = ui:PasteButton(scheme.clipboard_context, id .. "Paste", "Paste " .. scheme.title)
		if pasted then
			if scheme.Clone then
				pasted = scheme.Clone(pasted)
			end
			table.insert(list, pasted)
		end
	end

	ui:Unindent()
end

-- Display a table via imgui.
function ShowTable(ui, t, id)
	for key, value in Iterator.sorted_pairs(t) do
		if type(value) == "table" then
			local empty = next(value) == nil
			if empty then
				ui:Text(key.." (EMPTY)")
			elseif not empty and ui:CollapsingHeader(key..id) then
				ui:Indent()
				ShowTable(ui, value, id..key)
				ui:Unindent()
			end
		elseif type(value) == "number" and math.type(value) == "float" then
			ui:Value(key, value, "%0.3f")
	 	else
			ui:Value(key, value)
		end
	end
end
