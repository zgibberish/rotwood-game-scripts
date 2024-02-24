local DataDumper = require "util.datadumper"
local DebugSettings = require "debug.inspectors.debugsettings"
local EditorBase = require "debug.inspectors.editorbase"
local fileutil = require "util.fileutil"
local iterator = require "util.iterator"
local kassert = require "util.kassert"
local kstring = require "util.kstring"
local lume = require "util.lume"
require "consolecommands"
require "constants"

local DELETE_POPUP =" Confirm delete?"

local PrefabEditorBase = Class(EditorBase, function(self, static)
	EditorBase._ctor(self, static)

	self.prefab_label = "Prefab"
	self.test_label = "Test"
	self.test_enabled = true
	self.component_filter = ""
	self.groupfilter = ""
	self.prefabname = ""
	self.rename = nil
	self.extrainfo_for_delete = ""

	-- Can't name self.edit_options because that exists in some subclasses.
	self.global_edit_options = DebugSettings("editor.global_edit_options")
		:Option("auto_open_prefab_selector", true)

	-- Copy list of other prefabs to allow us to reject duplicate names, but
	-- won't give false positives for names deleted inside this editor.
	local grouplist, groupmap = self:GetGroupList()
	self.other_prefabs = lume.reject(Prefabs,
		function(prefab_obj)
			local prefab = prefab_obj.name
			return self.static.data[prefab] or groupmap[prefab]
		end, true)
	-- Just store prefab names.
	self.other_prefabs = lume.map(self.other_prefabs, function()
		return true
	end)

	self.bad_items = self:GatherErrors()
end)

local title_create_new_prefab = " Enter name for new prefab..."

function PrefabEditorBase:PostFindOrCreateEditor(prefab_to_select)
	if not prefab_to_select then
		return
	end
	self:SelectPrefab(prefab_to_select)
end

-- Call this on child class constructors that want to save the last selected prefab.
function PrefabEditorBase:LoadLastSelectedPrefab(editor_name)
	if self.edit_options == nil then
		self.edit_options = DebugSettings(editor_name .. ".edit_options")
	end

	self.edit_options:Option("prefabname", "")

	self.prefabname = self.edit_options.prefabname
end

function PrefabEditorBase:SaveLastSelectedPrefab(prefabname)
	if not self.edit_options then return end

	self.edit_options:Set("prefabname", prefabname)
	self.edit_options:Save()
end

function PrefabEditorBase:OnActivate()
	if self.want_handle then
		TheInput:SetEditMode(self, true)
	end
	-- Delay this until OnActivate so callers can stuff a prefab in that will
	-- prevent the selector from opening. See FindOrCreateEditor.
	if not self.prefabname or self.prefabname:len() == 0 then
		self.want_immediate_dropdown = self.global_edit_options and self.global_edit_options.auto_open_prefab_selector
	end
end

function PrefabEditorBase:OnDeactivate()
	if self.want_handle then
		TheInput:SetEditMode(self, false)
	end
	if self.handle ~= nil then
		self.handle:Remove()
		self.handle = nil
	end
end

function PrefabEditorBase:Save(force)
	if self.static.dirty then
		if self.PreSave then
			self:PreSave(self.static.data)
		end
		local prefix = ("-- Generated by %s and %s\n"):format(
			self:_GetNodeClassName_Unsafe() or "<unknown editor>",
			self:GetLoaderComment())

		-- remove any entries that existed before but don't anymore
		local name = self:GetLoaderCategory()
		for i,v in pairs(self.static.originaldata) do
			if not self.static.data[i] then
				TheSim:DevRemoveDataFile("scripts/prefabs/autogen/"..name.."/"..i:lower()..".lua")
			end
		end
		-- and save the entries that changed
		for i,v in pairs(self.static.data) do
			if force or not deepcompare(v, self.static.originaldata[i]) then
				v.__displayName = i
				-- Trailing newline to match editorconfig.
				local str = DataDumper(v, nil, false) .. "\n"
				TheSim:DevSaveDataFile("scripts/prefabs/autogen/"..name.."/"..i:lower()..".lua", prefix .. str)
			end
		end

		if self.PostSave then
			self:PostSave(self.static.data)
		end
		self.static.originaldata = deepcopy(self.static.data)
		self.static.dirty = false
	end
end

function PrefabEditorBase:GetLoaderComment()
	local prefab_loader = self.static.file:gsub("_data", "")
	return ("loaded by %s.lua"):format(prefab_loader)
end

function PrefabEditorBase:GetLoaderCategory()
	return self.static.file:gsub("_autogen_data", "")
end


function PrefabEditorBase:Test(prefab, params, count)
	if self.want_handle and not self.handle then
		local dbg_prefab = "debug_draggable"
		TheSim:LoadPrefabs({ dbg_prefab })
		self.handle = SpawnPrefab(dbg_prefab, TheDebugSource)
		self.handle.persists = false
		if GetDebugPlayer() then
			self.handle.Transform:SetPosition(GetDebugPlayer().Transform:GetWorldPosition())
		end
		self.handle:ListenForEvent("onremove", function()
			self.handle = nil
		end)
		self:SetupHandle(self.handle)
	end
	if self.want_spawn_target then
		self.last_spawn_pos = self:GetLastSpawnPosition()
	end
end

-- Indicate that this editor wants the object handle. Handle is created on
-- demand. Callers must call some base implementations in their corresponding
-- overrides:
--   PrefabEditorBase._base.OnDeactivate(self)
--   PrefabEditorBase._base.Test(self, prefab, params)
function PrefabEditorBase:WantHandle()
	self.want_handle = true
	self.handle = nil
end

function PrefabEditorBase:SetupHandle(handle)
	-- Subclasses that called WantHandle() can define SetupHandle to add
	-- DoPeriodicTask task to the handle so it moves their objects around. See
	-- FxEditor.
end

-- Simplest use of the handle -- get a spawn point.
function PrefabEditorBase:GetHandlePosition()
	return self.handle.Transform:GetWorldPosition()
end

-- For things that have their own handles and you just want a spawn point.
function PrefabEditorBase:WantSpawnPosition()
	-- Define GetLastSpawnPosition to use WantSpawnPosition: It should return
	-- the position of the spawned object or nil.
	kassert.typeof("function", self.GetLastSpawnPosition)

	self.want_spawn_target = true

	self.spawn_targets = {
		"player",
		"origin",
		"last",
	}
	self.spawn_targets_pretty = {
		"Player Position",
		"World Origin",
		"Last Spawn Location",
	}
	self.spawn_targets_fn = {
		player = function()
			return GetDebugPlayer():GetPosition()
		end,
		origin = function()
			return Vector3()
		end,
		last = function()
			-- Call GetLastSpawnPosition again in case the user moved it. Keep
			-- last_spawn_pos incase it was removed.
			return self:GetLastSpawnPosition() or self.last_spawn_pos or Vector3()
		end,
	}
	self.spawn_targets_by_name = lume.invert(self.spawn_targets)
	self.spawn_at = self.spawn_targets_by_name.player
end

-- Be sure to call this before removing your spawned object to ensure we can
-- get the most recent position.
function PrefabEditorBase:GetSpawnPosition()
	assert(self.spawn_at)
	assert(self.want_spawn_target, "Call WantSpawnPosition in ctor to use GetSpawnPosition.")
	local spawn_label = self.spawn_targets[self.spawn_at]
	-- Once we have a good spawn location, default to it.
	self.spawn_at = self.spawn_targets_by_name.last
	return self.spawn_targets_fn[spawn_label]()
end

-- Subclasses can implement to support error display. Return a table that will
-- be passed into RenderErrors.
function PrefabEditorBase:GatherErrors()
end
function PrefabEditorBase:RenderErrors(ui, bad_items)
	-- Default implementation with clickable labels for each error.
	-- Return a table of prefabnames to error messages in GatherErrors:
	-- { yammo_drop = "Drop is too yellow." }
	ui:TextColored(WEBCOLORS.YELLOW,( "Broken %ss"):format(self.prefab_label))
	local colw = ui:GetColumnWidth()
	ui:Columns(2, nil, false)
	ui:SetColumnOffset(1, colw * 0.25)
	for name,reason in iterator.sorted_pairs(bad_items) do
		kassert.typeof("string", name, reason) -- see above comment for what to return in GatherErrors
		if ui:Selectable(name, false) then
			if self.static.data[name] then
				self:SelectPrefab(name)
			else
				ui:OpenPopup(title_create_new_prefab)
				self.rename = name
			end
		end
		ui:NextColumn()
		ui:Text(reason)
		ui:NextColumn()
	end
	ui:Columns()
end

function PrefabEditorBase:AppendPrefabAsset(prefab, asset)
	if softresolvefilepath(asset.file) == nil then
		return false
	end

	prefab = Prefabs[prefab]

	if #prefab.assets > 0 then
		for i = 1, #prefab.assets do
			if deepcompare(prefab.assets[i], asset) then
				--Already exists, don't need to append
				return
			end
		end
		prefab.assets[#prefab.assets + 1] = asset
	else
		--Must replace the EMPTY table (see prefabs.lua)
		prefab.assets = { asset }
	end

	if not ShouldIgnoreResolve(asset.file, asset.type) then
		RegisterPrefabsResolveAssets(prefab, asset)
	end
	TheSim:DevAppendPrefabAsset(prefab.name, asset)
	return true
end

function PrefabEditorBase:AppendPrefabDep(prefab, dep)
	if Prefabs[dep] == nil then
		return false
	end

	prefab = Prefabs[prefab]

	if #prefab.deps > 0 then
		for i = 1, #prefab.deps do
			if prefab.deps[i] == dep then
				--Already exists, don't need to append
				return
			end
		end
		prefab.deps[#prefab.deps + 1] = dep
	else
		--Must replace the EMPTY table (see prefabs.lua)
		prefab.deps = { dep }
	end

	TheSim:DevAppendPrefabDep(prefab.name, dep)
	return true
end

function PrefabEditorBase:GetGroupList()
	local groupmap = { [""] = true }
	for _, params in pairs(self.static.data) do
		if params.group ~= nil then
			groupmap[params.group] = true
		end
	end
	local grouplist = {}
	for groupname in pairs(groupmap) do
		grouplist[#grouplist + 1] = groupname
	end
	table.sort(grouplist)
	groupmap[""] = nil
	return grouplist, groupmap
end

function PrefabEditorBase:GetPrefabList(groupfilter)
	local prefablist = { "" }
	for name, params in pairs(self.static.data) do
		if not groupfilter or (string.len(groupfilter) == 0 or params.group == groupfilter) then
			prefablist[#prefablist + 1] = name
		end
	end
	table.sort(prefablist)
	return prefablist
end

function PrefabEditorBase:IsExistingPrefabName(prefab, is_group_okay)
	local grouplist, groupmap = self:GetGroupList()
	if is_group_okay and groupmap[prefab] then
		return false
	end
	return (self.static.data[prefab]
		or self.other_prefabs[prefab]
		or groupmap[prefab]) and true
end

function PrefabEditorBase:RenderGroupSelection(ui)
	--Group filter selection
	local grouplist, groupmap = self:GetGroupList()
	local groupidx = table.arrayfind(grouplist, self.groupfilter)
	local newgroupidx = ui:_Combo("Group Filter", groupidx or 1, grouplist)
	if newgroupidx ~= groupidx then
		self.groupfilter = grouplist[newgroupidx] or ""
		if self.groupfilter:len() > 0 then
			-- Changed to a group that almost certainly doesn't contain the
			-- current prefab. To prevent any current data from applying to the
			-- wrong prefab, clear the selection.
			self:ClearPrefabSelection()
		end
	end
end

function PrefabEditorBase:ClearPrefabSelection()
	self.prefabname = nil
	self:PrefabDropdownChanged(self.prefabname)
end

function PrefabEditorBase:SelectPrefab(new_prefab)
	assert(self.static.data[new_prefab], "Trying to exist nonexistent prefab. If new, create it first.")
	self.prefabname = new_prefab
	self:PrefabDropdownChanged(self.prefabname)
end

function PrefabEditorBase:OnPrefabDropdownChanged(new_prefab_name)
	self.prefabname = new_prefab_name

	self:SaveLastSelectedPrefab(new_prefab_name)
end

function PrefabEditorBase:PrefabDropdownChanged(current_prefabname)
	self.duplicate_group_warning = nil
	if self.OnPrefabDropdownChanged then
		self:OnPrefabDropdownChanged(current_prefabname)
	end
	self.bad_items = self:GatherErrors()
end

function PrefabEditorBase:PrefabSelector(ui, label, current_prefabname, groupfilter, not_main_prefab)
	local prefablist = self:GetPrefabList(groupfilter)
	local want_immediate_dropdown = self.want_immediate_dropdown
	self.want_immediate_dropdown = nil
	return self:_PrefabListSelector(ui, label, current_prefabname, prefablist, want_immediate_dropdown, not_main_prefab)
end

function PrefabEditorBase:AutogenPrefabSelector(ui, autogen_data, label, current_prefabname, groupfilter)
	if groupfilter then
		autogen_data = lume.filter(autogen_data, function(p)
			return p.group == groupfilter
		end, true)
	end
	local prefablist = lume.keys(autogen_data)
	table.sort(prefablist)
	return self:_PrefabListSelector(ui, label, current_prefabname, prefablist)
end

function PrefabEditorBase:_PrefabListSelector(ui, label, current_prefabname, prefablist, want_immediate_dropdown, not_main_prefab)
	assert(#prefablist > 0)
	local changed
	local store_first_as_nil = true
	changed, current_prefabname = ui:ComboAsString(label, current_prefabname, prefablist, store_first_as_nil, nil, want_immediate_dropdown)
	if changed and not not_main_prefab then
		self:PrefabDropdownChanged(current_prefabname)
	end
	return current_prefabname, changed
end

function PrefabEditorBase:RenderPrefabSelection(ui)
	self.prefabname = self:PrefabSelector(ui, self.prefab_label, self.prefabname, self.groupfilter)
	ui:SameLineWithSpace(20)
	if ui:Button(ui.icon.playback_step_fwd .."##PrefabSelector", ui.icon.width) then
		self:_SelectNextPrefab()
	end
	if ui:IsItemHovered() then
		ui:SetTooltip(("Select the next %s in the list."):format(self.prefab_label))
	end
	ui:SameLineWithSpace()
	self.global_edit_options:Toggle(ui, "Expand on open", "auto_open_prefab_selector")
	if ui:IsItemHovered() then
		ui:SetTooltipMultiline({
			"Focus dropdown on open so you can immediately start typing.",
			"If an item is auto-selected, the dropdown won't open.",
		})
	end
end


-- Example implementation:
--  function PrefabEditorBase:ApplyNameRestrictions(new_name)
--  	local prefix = "cine_"
--  	if not kstring.startswith(new_name, prefix) then
--  		return prefix .. new_name
--  	end
--  	-- Return nothing if the name is fine.
--  end

-- Wrapper to keep it simple for clients.
local function RenameTextCallback(self, flags, key, str)
	local prefix = GroupPrefab("")
	if kstring.startswith(str, prefix) then
		-- Prefabs names must not conflict with group names.
		return str:sub(prefix:len())
	end
	if self.ApplyNameRestrictions then
		return self:ApplyNameRestrictions(str)
	end
	-- Don't return anything to keep the current string.
end

function PrefabEditorBase:RenderNamingPopup(ui, title, initial_name, label, confirm_label)
	confirm_label = confirm_label or label
	if ui:Button(label .."...") then
		ui:OpenPopup(title)
		self.rename = initial_name
	end
	local selected_name
	if ui:BeginPopupModal(title, true, ui.WindowFlags.AlwaysAutoResize) then
		ui:Dummy(0, 5)
		ui:Dummy(5, 0)
		ui:SameLine()

		ui:SetDefaultKeyboardFocus()
		local hit_enter, newprefab = ui:InputText("##rename",
			self.rename,
			imgui.InputTextFlags.CharsNoBlank | imgui.InputTextFlags.EnterReturnsTrue | imgui.InputTextFlags.AutoSelectAll | imgui.InputTextFlags.CallbackAlways,
			RenameTextCallback, self)
		if newprefab ~= nil then
			self.rename = newprefab:lower()
		end
		ui:SameLineWithSpace()

		local invalidName = not fileutil.IsValidFilename(self.rename)
		local renameused = self.rename ~= initial_name and self:IsExistingPrefabName(self.rename)
		local renamebtndisabled = renameused or invalidName or string.len(self.rename) <= 0
		if (ui:Button(confirm_label, nil, nil, renamebtndisabled) or hit_enter) and not renamebtndisabled then
			ui:CloseCurrentPopup()
			selected_name = self.rename
			-- Clear it to be tidy, but if user clicked the x to close, we
			-- won't get here.
			self.rename = nil
		end

		ui:SameLine()
		ui:Dummy(5, 0)

		if renameused then
			ui:Dummy(5, 0)
			ui:SameLine()
			ui:PushStyleColor(ui.Col.Text, { 1, 0, 0, 1 })
			ui:Text("This name is already in use")
			ui:PopStyleColor(1)
		end
		if invalidName and string.len(self.rename) > 0 then
			ui:SameLineWithSpace()
			ui:PushStyleColor(ui.Col.Text, { 1, 0, 0, 1 })
			ui:Text("Invalid name - only Alphanumeric characters, spaces, dashes, underscores, and dots are allowed")
			ui:PopStyleColor(1)
		end

		ui:Dummy(0, 5)
		ui:EndPopup()
	end
	return selected_name
end

function PrefabEditorBase:RenderPanel( ui, panel )

	if self.bad_items and next(self.bad_items) then
		self:RenderErrors(ui, self.bad_items)
		self:AddSectionEnder(ui)
	end

	self:RenderGroupSelection(ui)

	self:AddSectionEnder(ui)

	--New
	local newname = self:RenderNamingPopup(ui, title_create_new_prefab, "", "New", "Create")
	if newname then
		self.static.data[newname] = {}
		if string.len(self.groupfilter) > 0 then
			self.static.data[newname].group = self.groupfilter
		end
		self:SelectPrefab(newname)

		self:SetDirty()
	end

	ui:SameLineWithSpace()

	--[[if self:IsDirty() then
		self:SetHeaderColor( { .8, .05, .05, 1 } )
	else
	self.headerColorRequested = nil
		self:ClearHeaderColor()
	end]]

	--Save/Load
	self:PushRedButtonColor(ui)
	if ui:Button("Revert All", nil, nil, not self:IsDirty()) then
		self:Revert()
	end
	ui:SameLineWithSpace()
	if ui:Button("Save All", nil, nil, not self:IsDirty()) then
		self:Save()
		self.bad_items = self:GatherErrors()
	end
	self:PopButtonColor(ui)

	self:AddSectionEnder(ui)

	self:RenderPrefabSelection(ui)

	local params = self.static.data[self.prefabname]
	if params ~= nil then
		ui:Spacing()

		--Clone
		newname = self:RenderNamingPopup(ui, " Enter name for clone...", self.prefabname.."_copy", "Clone")
		if newname then
			local oldname = self.prefabname
			params = deepcopy(params)
			self.static.data[newname] = params
			self:SelectPrefab(newname)
			self:AfterDuplicate(oldname, newname)

			self:SetDirty()
		end

		ui:SameLineWithSpace()

		--Rename
		newname = self:RenderNamingPopup(ui, " Enter new name...", self.prefabname, "Rename")
		if newname then
			if newname ~= self.prefabname then
				local oldname = self.prefabname
				self:BeforeRename(oldname, newname)
				self.static.data[newname] = params
				self.static.data[oldname] = nil
				self:SelectPrefab(newname)
				self:AfterRename(oldname, newname)

				self:SetDirty()
			end
		end

		ui:SameLineWithSpace()

		--Delete
		if ui:Button("Delete") then
			ui:OpenPopup(DELETE_POPUP)
		end

		if self.want_handle and self.handle then
			ui:SameLine_RightAligned(105)
			local changed, want_visible = ui:Checkbox("Show Handle", self.handle:IsVisible())
			ui:SetTooltipIfHovered("Uncheck to hide the red circle handle, but you won't be able to drag the item around.")
			if changed then
				if want_visible then
					self.handle:Show()
				else
					self.handle:Hide()
				end
			end
		end

		ui:Spacing()

		--Test
		self:PushGreenButtonColor(ui)
		if self.test_enabled then
			if self.test_label and ui:Button(self.test_label) then
				self:Test(self.prefabname, params, self.test_count)
			end
		else
			ui:PushDisabledStyle()
			if self.test_label then
				ui:Button(self.test_label)
			end
			ui:PopDisabledStyle()
		end

		if self.test_count then
			ui:SameLineWithSpace()
			ui:PushItemWidth(math.max(20, 100))
			local changed, newcount = ui:DragInt("# to spawn", self.test_count)
			if changed then
				self.test_count = newcount
			end
			ui:PopItemWidth()
		end

		if self.BatchModify then
			ui:SameLineWithSpace()
			if ui:Button("Batch Modify") then
				self:BatchModify(self.static.data)
				self:SetDirty()
			end
		end
		self:PopButtonColor(ui)

		if self.want_spawn_target then
			ui:SameLineWithSpace()
			ui:PushItemWidth(-1)
			ui:Text("at")
			ui:SameLineWithSpace()
			self.spawn_at = ui:_Combo("##Test Spawn Location", self.spawn_at or 1, self.spawn_targets_pretty)
			ui:PopItemWidth()
		end

		ui:Spacing()

		if ui:TreeNode("Group (optional)") then
			--Group name
			local _, newgroup = ui:InputText("##group", params.group, imgui.InputTextFlags.CharsNoBlank)
			if newgroup ~= nil then
				self.duplicate_group_warning = nil
				if string.len(newgroup) == 0 then
					newgroup = nil
				end
				if self:IsExistingPrefabName(newgroup, true) then
					self.duplicate_group_warning = "Cannot use '%s' as a group name because it's already a prefab or group name."
					self.duplicate_group_warning = self.duplicate_group_warning:format(newgroup)
					-- The last value of params.group is the same but with one missing char.
					newgroup = newgroup .."_group"
				end
				if params.group ~= newgroup then
					params.group = newgroup
					self:SetDirty()
					if string.len(self.groupfilter) > 0 and newgroup ~= nil then
						self.groupfilter = newgroup
					end
				end
			end
			if self.duplicate_group_warning then
				ui:Indent(5)
				self:WarningMsg(ui, "Warning", self.duplicate_group_warning)
				ui:Unindent(5)
			end

			self:AddTreeNodeEnder(ui)
		end

		self:AddSectionEnder(ui)

		self:AddEditableOptions(ui, params)
	end

	if ui:BeginPopupModal(DELETE_POPUP, false, ui.WindowFlags.AlwaysAutoResize) then
		self:PushRedButtonColor(ui)
		ui:Spacing()
		ui:SameLineWithSpace(20)
		ui:Text(self.extrainfo_for_delete:format(self.prefabname))
		if ui:Button("Delete##confirm") then
			ui:CloseCurrentPopup()
			self:BeforeDelete(self.prefabname)
			self.static.data[self.prefabname] = nil
			self.prefabname = ""
			self:SetDirty()
		end
		self:PopButtonColor(ui)
		ui:SameLineWithSpace()
		if ui:Button("Cancel##delete") then
			ui:CloseCurrentPopup()
		end
		ui:SameLineWithSpace(20)
		ui:Spacing()
		ui:EndPopup()
	end
end

function PrefabEditorBase:BeforeRename(oldname, newname)
	-- For child classes to override to respond to renames.
end

function PrefabEditorBase:AfterRename(oldname, newname)
	-- For child classes to override to cleanup after renames.
end

function PrefabEditorBase:AfterDuplicate(oldname, newname)
	-- For child classes to override to cleanup after duplication.
end

function PrefabEditorBase:BeforeDelete(oldname)
	-- For child classes to override to respond to deletes.
end

function PrefabEditorBase:_SelectNextPrefab()
	local prefabs = self:GetPrefabList(self.groupfilter)
	local idx = lume.find(prefabs, self.prefabname) or 1
	idx = idx + 1
	local choice = prefabs[idx]
	if choice then
		return self:SelectPrefab(choice)
	end
end

function PrefabEditorBase:Button_CopyToGroup(ui, label_fmt, param_names)
	local label = label_fmt:format(self.prefabname, self.groupfilter)
	if self.groupfilter:len() > 0 and ui:Button(label) then
		print("Button_CopyToGroup", label)
		local prefabs = self:GetPrefabList(self.groupfilter)
		self:CopyParamsToPrefabs(self.prefabname, prefabs, param_names)
		return true
	end
end
function PrefabEditorBase:CopyParamsToPrefabs(src_prefab_name, dest_prefab_names, param_names)
	print("CopyParamsToPrefabs", src_prefab_name, table.inspect(param_names))
	local src = self.static.data[src_prefab_name]
	for _,prefab_name in ipairs(dest_prefab_names) do
		local prefab = self.static.data[prefab_name]
		if prefab then
			print("", prefab_name)
			for _,p in ipairs(param_names) do
				prefab[p] = deepcopy(src[p])
			end
		end
	end
	self:SetDirty()
end


-- Don't submit this code uncommented. Don't want the button unless a coder is
-- using it.
--~ function PrefabEditorBase:BatchModify(prefabs)
--~ 	print(table.inspect(prefabs))
--~ 	for prefab_name,prefab in pairs(prefabs) do
--~ 		-- Modify prefabs here. You must F6 *and* close the Inspector for your
--~ 		-- changes to be applied (or Ctrl-R).
--~ 	end
--~ 	self:SetDirty()
--~ end

return PrefabEditorBase
