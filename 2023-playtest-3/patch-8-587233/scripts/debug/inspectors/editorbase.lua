local DebugNodes = require "dbui.debug_nodes"
local kstring = require "util.kstring"
require "consolecommands"
require "constants"


local EditorBase = Class(DebugNodes.DebugNode, function(self, static)
	DebugNodes.DebugNode._ctor(self, "Editor") -- TODO(dbriscoe): Pass names from editors to ctor
	self.static = static

	if static.originaldata == nil then
		static.originaldata = deepcopy(static.data)
	end
end)

function EditorBase.MakeStaticData(filename)
	return
	{
		file = filename,
		data = require("prefabs."..filename),
		dirty = false,
		originaldata = nil,
	}
end

-- List of prefab names for spawning.
--
-- Excludes group prefabs which you shouldn't spawn.
-- To include unloaded prefabs, call d_allprefabs() first (maybe when your
-- editor loads).
function EditorBase.GetAllPrefabNames()
	local group_prefix = GroupPrefab("")
	local prefab_list = {}
	for key,val in pairs(Prefabs) do
		if not kstring.startswith(key, group_prefix) then
			table.insert(prefab_list, key)
		end
	end
	return prefab_list
end

-- A text field that stores a prefab with a button to pick any prefab.
function EditorBase.PrefabPicker(ui, label, current, store_first_as_nil)
	current = ui:_InputText(label, current, ui.InputTextFlags.CharsNoBlank)

	ui:SameLineWithSpace()
	local popup_name = "Pick##".. label
	if ui:Button(popup_name) then
		ui:OpenPopup(popup_name)
	end
	if ui:BeginPopup(popup_name) then
		local prefab_list = EditorBase.GetAllPrefabNames()
		table.sort(prefab_list)
		local changed, newpick = ui:ComboAsString("Choose a prefab##picker".. label, current, prefab_list, store_first_as_nil, nil, ui:IsWindowAppearing())
		if changed then
			current = newpick
			ui:CloseCurrentPopup()
		end
		ui:EndPopup()
	end
	-- Don't bother returning changed. Calling SetDirty every frame makes code
	-- so much simpler.
	return current
end

function EditorBase:SetDirty()
	self.static.dirty = not deepcompare(self.static.originaldata, self.static.data)
end

function EditorBase:IsDirty()
	return self.static.dirty
end

local function _copytable(src, dest)
	for k in pairs(dest) do
		if src[k] == nil then
			dest[k] = nil
		end
	end
	for k, v in pairs(src) do
		if type(v) == "table" then
			local v1 = dest[k]
			if type(v1) ~= "table" then
				v1 = {}
				dest[k] = v1
			end
			_copytable(v, v1)
		else
			dest[k] = v
		end
	end
end

function EditorBase:Revert()
	if self.static.dirty then
		_copytable(self.static.originaldata, self.static.data)
		self.static.dirty = false
	end
	if self.OnRevert then
		local params = self.static.data[self.prefabname]
		-- params are already reverted. This is so editors can respond to revert.
		self:OnRevert(params)
	end
end


function EditorBase:ValueColored(ui, label, color, val)
	ui:Text(label ..": ")
	ui:SameLine()
	ui:TextColored(color, val)
end

function EditorBase:WarningMsg(ui, header, body)
	ui:TextColored(WEBCOLORS.YELLOW, header)
	ui:TextWrapped(body)
end

function EditorBase:AddTreeNodeEnder(ui)
	ui:Dummy(0, 5)
	ui:TreePop()
end

function EditorBase:AddSectionStarter(ui)
	ui:Spacing()
end

function EditorBase:AddSectionEnder(ui)
	ui:Spacing()
	ui:Separator()
	ui:Spacing()
end

function EditorBase:PushRedButtonColor(ui)
	return ui:PushStyle_RedButton()
end

function EditorBase:PushGreenButtonColor(ui)
	return ui:PushStyle_GreenButton()
end

-- Or call PopStyleColor with the returned count.
function EditorBase:PopButtonColor(ui)
	ui:PopStyleColor(3)
end

function EditorBase:PushRedFrameColor(ui)
	ui:PushStyleColor(ui.Col.FrameBg, { .5, 0, 0, 1 })
	ui:PushStyleColor(ui.Col.FrameBgHovered, { .6, .05, .05, 1 })
	ui:PushStyleColor(ui.Col.FrameBgActive, { .7, 0, 0, 1 })
	return 3
end

function EditorBase:PopFrameColor(ui)
	ui:PopStyleColor(3)
end

function EditorBase:PushRedWindowColor(ui)
	ui:PushStyleColor(ui.Col.TitleBgActive, { .6, .05, .05, 1 })
end

function EditorBase:PopWindowColor(ui)
	ui:PopStyleColor(1)
end


return EditorBase
