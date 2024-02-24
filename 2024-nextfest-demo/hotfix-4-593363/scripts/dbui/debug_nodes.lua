local DataDumper = require "util.datadumper"
local DebugSettings = require "debug.inspectors.debugsettings"
local kassert = require "util.kassert"
local lume = require "util.lume"
local strict = require "util.strict"

-------------------------------------------------------------------
-- A debug node is simply an adapter that returns debug text for
-- a "source" object, which is literally whatever it is you want to
-- be debugging.
-- It also has a notion of child nodes, and a parent node, for easy
-- traversing of data hierarchies.

local DebugNode = Class(function(self, node_name)
	kassert.typeof("string", node_name)
	self.name = node_name

	self.colorscheme = {
		header = {0.68, 0.93, 0.96, 1},
	}

	-- Nodes in DebugNodes support sticky.
	local class_name = self:_GetNodeClassName_Unsafe()
	if class_name then
		-- Nodes could keep data here, but better to put it in their own
		-- self.edit_options where it's easier to clean out individually.
		self.node_edit_options = DebugSettings(class_name .. ".node_edit_options")
			:Option("open_on_game_reset", false)
		if self.node_edit_options.open_on_game_reset then
			self:ReopenNodeAfterReset()
		end
	end
end)
DebugNode.can_reload = true

-- To associate a debug node with an entity/table, set DebugNodeName on them.
-- See GetDebuggerNodeClass in DebugPanel.


-- Is this type of node allowed to be opened right now. Static to check before
-- creating the node.
function DebugNode.CanBeOpened()
	return true
end

local function AddDebugTableButton(ui, panel, t)
	local is_debug_table = t == GetDebugTable()
	if ui:Button("Set Debug Table", nil, nil, is_debug_table) then
		SetDebugTable(t)
	end
	if is_debug_table then
		ui:SameLineWithSpace()
		-- Or GetDebugTable"":Blah to get autocompletion.
		ui:Text("Use GetDebugTable() to access table in console.")
	end
end

local function ShowDebugPanel(node_type, can_toggle, ...)
	local panel = TheFrontEnd:FindOpenDebugPanel(node_type)
	if can_toggle and panel then
		panel.show = false
	elseif node_type.CanBeOpened() then
		panel = TheFrontEnd:CreateDebugPanel(node_type(...))
	end
	return panel
end

-- Call this on the class, not an instance.
-- TODO(dbriscoe): Rename to FindOrCreateNode
function DebugNode:FindOrCreateEditor(...)
	local editor_type = self
	local panel = TheFrontEnd:FindOpenDebugPanel(editor_type)
	if not panel then
		panel = TheFrontEnd:CreateDebugPanel(editor_type())
	end

	if panel then
		local editor = panel:GetNode()
		editor:PostFindOrCreateEditor(...)
		return editor, panel
	end
end
function DebugNode:PostFindOrCreateEditor(...)
	-- Override in children to allow passing initial state to
	-- FindOrCreateEditor.
end

function DebugNode:GetName()
	return self.name
end

function DebugNode:GetUID()
	return self.name -- Unique identifier for ImGUI and equating recent nodes.
end

function DebugNode:GetDesc( sb )
	sb:Append( "NO NODE" )
end

function DebugNode:_GetNodeClassName_Unsafe()
	local DebugNodes = require "dbui.debug_nodes"
	return lume.find(DebugNodes, self.__index)
end

function DebugNode:CanReopenNodeAfterReset()
	return not self.forbid_sticky and self:_GetNodeClassName_Unsafe()
end

function DebugNode:_GetNodeClassName()
	local class_name = self:_GetNodeClassName_Unsafe()
	assert(class_name, "Couldn't find in DebugNodes list.") -- Can be caused by hotloading an editor while it's open.
	return class_name
end

function DebugNode:ReopenNodeAfterReset()
	InstanceParams.dbg = InstanceParams.dbg or {}
	InstanceParams.dbg.open_nodes = InstanceParams.dbg.open_nodes or {}
	InstanceParams.dbg.open_nodes[self:_GetNodeClassName()] = true
end

function DebugNode:WillReopenNodeAfterReset()
	local class_name = self:_GetNodeClassName_Unsafe()
	return (class_name
		and InstanceParams.dbg
		and InstanceParams.dbg.open_nodes
		and InstanceParams.dbg.open_nodes[class_name])
end

function DebugNode:ToggleReopenNodeAfterReset()
	local want_sticky = not self:WillReopenNodeAfterReset()
	if want_sticky then
		self:ReopenNodeAfterReset()
	else
		InstanceParams.dbg.open_nodes[self:_GetNodeClassName()] = nil
	end
	self.node_edit_options
		:Set("open_on_game_reset", want_sticky)
		:Save()
end


function DebugNode.MakeStaticDebugData(filename)
	return
	{
		file = filename,
		data = require("debug."..filename),
		dirty = false,
		originaldata = nil,
	}
end

function DebugNode:SetStaticData(static)
	self.static = static

	if static.originaldata == nil then
		static.originaldata = deepcopy(static.data)
	end
end

function DebugNode:SaveDebugData()
	if self.static and self.static.dirty then
		TheSim:DevSaveDataFile("scripts/debug/"..self.static.file..".lua", DataDumper(self.static.data, nil, false))
		self.static.originaldata = deepcopy(self.static.data)
		self.static.dirty = false
	end
end

function DebugNode:_RenderTable(ui, panel, t, indent)
	AddDebugTableButton(ui, panel, t)

	ui:Columns(2, "mycolumns3", false)
	local mt = getmetatable(t)
	if mt then
		ui:Text( "getmetatable()" )
		ui:NextColumn()

		if ui:Selectable( mt._class and mt._classname or rawstring(mt), false ) then
			panel:PushNode( panel:CreateDebugNode( mt ))
		end
		ui:NextColumn()
	end
	ui:Columns(1)

	self.all_filter = ui:_FilterBar(self.all_filter, "##filterall", "Filter by key...")
	ui:Text( string.format( "%d fields", table.count( t ) ))
	ui:Separator()

	panel:AppendKeyValues(ui, t, indent, self.all_filter)
end

-- Add to the end of your node to allow inspecting the raw contents of your target.
function DebugNode:AddFilteredAll(ui, panel, target)
	assert(target)
	ui:Spacing()
	if ui:CollapsingHeader("All") then
		self:_RenderTable(ui, panel, target)
	end
end

--------------------------------------------------------------------
-- Whenever attempting to create a panel for the value 'nil'

local DebugNil = Class(DebugNode, function(self)
	DebugNode._ctor(self, "Nil")
	self.forbid_sticky = true -- Not useful to be sticky.
end)

DebugNil.PANEL_WIDTH = 200
DebugNil.PANEL_HEIGHT = 80

function DebugNil:RenderPanel( ui, panel )
	ui:TextColored( RGB(255, 89,  46), "nil" )
end

--------------------------------------------------------------------
-- A debug source for a generic table

local DebugTable = Class(DebugNode, function(self, t, name, offset )
	DebugNode._ctor(self, "DebugTable")
	self.forbid_sticky = true -- Won't know what table we were looking at.
	self.t = t
	self.offset = offset
	self.name = name
	self.menu_param = t
end)

function DebugTable:GetSubject()
	return self.t
end

function DebugTable:GetName()
	return self.name or rawstring(self.t)
end

function DebugTable:GetUID()
	return rawstring(self.t)
end

function DebugTable:RenderPanel( ui, panel )
	if not strict.is_strict(self.t)
		and self.t.RenderDebugUI
	then
		self.t:RenderDebugUI( ui, panel, self.colorscheme )
		ui:Separator()
	end

	self:_RenderTable(ui, panel, self.t, self.offset)
end

--------------------------------------------------------------------
-- Just show a plain old value.

local DebugValue = Class(DebugNode, function(self, value)
	DebugNode._ctor(self, "Debug Value")
	self.forbid_sticky = true -- Won't know what value we were looking at.
	self.value = value
	self.menu_param = value
end)

function DebugValue:RenderPanel( ui, panel )
	ui:TextColored( RGB(85, 204, 204), type(self.value))
	ui:Text( tostring(self.value) )
end

--------------------------------------------------------------------
-- Dynamic, custom inspector

local DebugCustom = Class(DebugNode, function(self, fn)
	DebugNode._ctor(self, "Debug Custom")
	self.fn = fn
end)

function DebugCustom:RenderPanel( ui, panel )
	self:fn( ui, panel )
end

local DebugNodes = {
	DebugNode = DebugNode,
	DebugTable = DebugTable,
	DebugValue = DebugValue,
	DebugNil = DebugNil,
	ShowDebugPanel = ShowDebugPanel,
}
return DebugNodes
