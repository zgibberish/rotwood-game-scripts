local POPUP_TITLE = "Prop Refs"

local PropRefsWindow = Class(function(self)
end)

function PropRefsWindow:Open(ui, editor, zone_gen, scene_prop)
	self.editor = editor
	self.zone_gen = zone_gen
	self.scene_prop = scene_prop
	ui:OpenPopup(POPUP_TITLE)
end

-- Build a table with the same hierarchy as a-merge-b but only retain mismatching nodes.
-- For each node, store the mismatched values {a, b} under the key 'mismatch'.
-- Also store a function under the key 'Reset' if b can be reset to a.
local function CollectMismatches(a, b, mismatches)
	if type(a) ~= type(b) then
		mismatches.mismatch = {type(a), type(b)}
		return
	end

	local is_table = type(a) == "table"
	if not is_table then
		if a ~= b then
			mismatches.mismatch = {a, b}
		end
	else
		local all_true = true

		for k, v in pairs(a) do
			mismatches[k] = {}
			CollectMismatches(v, b[k], mismatches[k])
			if mismatches[k].mismatch then
				mismatches[k].Reset = function() 
					b[k] = deepcopy(a[k])
				end
				all_true = false
			end
		end

		for k, v in pairs(b) do
			mismatches[k] = mismatches[k] or {}
			if a[k] == nil then
				mismatches[k].mismatch = {"nil", v}
				mismatches[k].Reset = function() 
					b[k] = nil 
				end
				all_true = false
			end
		end

		if not all_true then
			mismatches.mismatch = {a, b}
			mismatches.Reset = function() 
				b = deepcopy(a) 
			end
		end
	end
end

local function MismatchUi(ui, id, mismatches)
	if not mismatches.mismatch then
		return false
	end
	local dirty = false
	for k, v in pairs(mismatches) do
		if type(v) == "table" and v.mismatch then
			local a = v.mismatch[1]
			local b = v.mismatch[2]
			if v.Reset then
				if ui:Button(ui.icon.undo..id..k) then
					v.Reset()
					dirty = true
				end
				ui:SetTooltipIfHovered("Reset to source value, "..tostring(a))
				ui:SameLineWithSpace()
			end
			if type(a) == "table" and type(b) == "table" then
				if ui:CollapsingHeader(k..id) then
					ui:Indent()
					if MismatchUi(ui, id..k, mismatches[k]) then
						dirty = true
					end
					ui:Unindent()
				end
			else
				ui:Text(k..": ")
				ui:PushStyleColor(ui.Col.Text, WEBCOLORS.GREEN)
				ui:SameLine()
				ui:Text(a)
				ui:PopStyleColor()
				ui:SameLine()
				ui:Text(" ~= ")
				ui:SameLine()
				ui:PushStyleColor(ui.Col.Text, WEBCOLORS.RED)
				ui:Text(b)
				ui:PopStyleColor()
			end
		end
	end
	return dirty
end

function PropRefsWindow:ModalUi(ui, id)
	if not ui:BeginPopupModal(POPUP_TITLE, true) then
		return
	end
	id = id .. "PropRefsWindow"

	ui:Text("Here is a list of all ZoneGens that use ")
	ui:PushStyleColor(ui.Col.Text, WEBCOLORS.YELLOW)
	ui:SameLine()
	ui:Text(self.scene_prop.prop)
	ui:PopStyleColor()
	ui:Text("compared against the version in ")
	ui:PushStyleColor(ui.Col.Text, WEBCOLORS.GREEN)
	ui:SameLine()
	ui:Text(self.zone_gen:GetLabel())
	ui:PopStyleColor()
	ui:SameLine()
	ui:Text(".")
	ui:Text("Only properties that ")
	ui:PushStyleColor(ui.Col.Text, WEBCOLORS.RED)
	ui:SameLine()
	ui:Text("differ")
	ui:PopStyleColor()
	ui:SameLine()
	ui:Text(" are shown.")

	ui:Separator()

	for i, zone_gen in ipairs(self.editor:GetSceneGen().zone_gens) do
		local id = id .. i
		for j, scene_prop in ipairs(zone_gen.scene_props) do
			if scene_prop.prop == self.scene_prop.prop then
				local id = id .. j
				local mismatches = {}
				CollectMismatches(self.scene_prop, scene_prop, mismatches)
				if ui:CollapsingHeader(zone_gen:GetLabel().. " ("..scene_prop:GetLabel()..")" .. id) then
					ui:Indent()
					if MismatchUi(ui, id, mismatches) then
						self.editor.dirty_stuff[zone_gen] = true
					end
					ui:Unindent()
				end
			end
		end
	end

	ui:EndPopup()
end

return PropRefsWindow
